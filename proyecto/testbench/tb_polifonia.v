`timescale 1ns/1ps
// Testbench de polifonia: para cada forma de onda pulsa 1, 2, 3 ... 12 teclas
// (sumando una tecla en cada paso) y mide cuando aparecen problemas.
//
// Mide, por cada combinacion (onda, numero de teclas):
//   pico |suma|     salida de banco_notas. Si pasa de n*32768 hay desborde de la suma.
//   pico |ganada|   despues de la ganancia por onda, antes del volumen.
//   % recortado     porcentaje de muestras que saturan a 16 bits con el volumen
//                   elegido (parametro VOLUMEN).
//   max volumen sin recorte: el volumen mas alto (1..7) con el que ese pico no recorta.
//
// Orden de las teclas: Do, Mi, Sol, Si, Re, Fa, La, Do#, Re#, Fa#, Sol#, La#
// (primero un acorde mayor, que es lo que se toca normalmente).
//
// Con ADSR: se fija ataque 1 ms, sustain 1.0 (sin decay) y se deja SETTLE_US para que
// terminen el ataque y el deslizamiento de la ganancia automatica antes de medir,
// asi se mide el pico en regimen (el peor caso de recorte).
//
// Uso en Questa:  vsim -voptargs=+acc work.tb_polifonia ; do tb_polifonia.do ; run -all
module tb_polifonia;

    parameter integer ONDA    = 4;     // 0 cuadrada, 1 sierra, 2 triangular, 3 seno, 4 = las cuatro
    parameter integer VOLUMEN = 4;      // nivel de volumen a evaluar (0..7)
    parameter integer MEAS_US = 4000;   // tiempo medido por paso: > 1 periodo del Do (3.8 ms)
    parameter integer SETTLE_US = 3000; // espera antes de medir: ataque (1 ms) + ganancia automatica (~4 ms max)

    reg         clk = 0;
    reg         rst = 1;
    reg  [11:0] teclas = 12'd0;
    reg  [1:0]  sel_onda = 2'd0;
    wire signed [19:0] suma;
    wire [11:0] activas;
    wire [2:0]  vol = VOLUMEN;
    wire        bclk, lrclk, din;

    always #10 clk = ~clk;              // 50 MHz

    banco_notas uut (
        .clk(clk), .rst(rst), .teclas(teclas), .sel_onda(sel_onda),
        .a_idx(4'd0), .d_idx(4'd0), .s_idx(4'd15), .r_idx(4'd2),     // A 1 ms, S = 1.0, R 5 ms
        .activas(activas), .suma(suma)
    );

    salida_i2s u_audio (
        .clk(clk), .rst(rst), .suma(suma), .activas(activas), .sel_onda(sel_onda),
        .volumen(vol),
        .i2s_bclk(bclk), .i2s_lrclk(lrclk), .i2s_din(din)
    );

    // Senales internas de salida_i2s, para verlas en la onda
    wire signed [25:0] ganada   = u_audio.ganada;
    wire signed [25:0] atenuada = u_audio.atenuada;
    wire signed [15:0] muestra  = u_audio.muestra;

    // ---------------- Orden de las teclas ----------------
    function [11:0] mascara;
        input integer n;                // numero de teclas pulsadas
        integer j;
        begin
            mascara = 12'd0;
            for (j = 0; j < n; j = j + 1) begin
                case (j)
                    0:  mascara = mascara | 12'b000000000001;   // Do
                    1:  mascara = mascara | 12'b000000010000;   // Mi
                    2:  mascara = mascara | 12'b000010000000;   // Sol
                    3:  mascara = mascara | 12'b100000000000;   // Si
                    4:  mascara = mascara | 12'b000000000100;   // Re
                    5:  mascara = mascara | 12'b000000100000;   // Fa
                    6:  mascara = mascara | 12'b001000000000;   // La
                    7:  mascara = mascara | 12'b000000000010;   // Do#
                    8:  mascara = mascara | 12'b000000001000;   // Re#
                    9:  mascara = mascara | 12'b000001000000;   // Fa#
                    10: mascara = mascara | 12'b000100000000;   // Sol#
                    11: mascara = mascara | 12'b010000000000;   // La#
                endcase
            end
        end
    endfunction

    // ---------------- Estadisticas ----------------
    reg  medir = 0;
    integer max_suma, max_ganada, n_total, n_recorte;
    integer abs_suma, abs_ganada;

    always @(posedge clk) begin
        if (medir) begin
            abs_suma   = (suma   < 0) ? -suma   : suma;
            abs_ganada = (ganada < 0) ? -ganada : ganada;
            if (abs_suma   > max_suma)   max_suma   = abs_suma;
            if (abs_ganada > max_ganada) max_ganada = abs_ganada;
            n_total = n_total + 1;
            if (atenuada > 32767 || atenuada < -32768) n_recorte = n_recorte + 1;
        end
    end

    // Volumen maximo (1..7) con el que un pico de 'max_ganada' cabe en 16 bits.
    // Con volumen v la muestra es ganada >> (7 - v + reserva).
    function integer vol_sin_recorte;
        input integer pico;
        input integer reserva;
        integer v;
        begin
            vol_sin_recorte = 0;                         // 0 = ni con volumen 1 cabe
            for (v = 1; v <= 7; v = v + 1)
                if ((pico >> (7 - v + reserva)) <= 32767) vol_sin_recorte = v;
        end
    endfunction

    // ---------------- Secuencia ----------------
    integer onda, n, o_ini, o_fin;
    reg [8*10-1:0] nombre;

    initial begin
        $display("");
        $display("Volumen evaluado = %0d | cada paso mide %0d us", VOLUMEN, MEAS_US);
        $display("onda        teclas  pico|suma|  limite_suma  pico|ganada|  recorte(%%)  vol_max_sin_recorte");
        $display("----------  ------  ----------  -----------  ------------  ----------  -------------------");

        repeat (10) @(posedge clk);
        rst = 0;

        if (ONDA == 4) begin o_ini = 0;    o_fin = 3;    end
        else           begin o_ini = ONDA; o_fin = ONDA; end

        for (onda = o_ini; onda <= o_fin; onda = onda + 1) begin
            case (onda)
                0: nombre = "cuadrada";
                1: nombre = "sierra";
                2: nombre = "triangular";
                3: nombre = "seno";
            endcase

            // Soltar todas las teclas para reiniciar las fases, y cambiar de onda
            teclas   = 12'd0;
            sel_onda = onda[1:0];
            #10_000_000;                                // 10 ms de silencio: termina el release (5 ms)

            for (n = 1; n <= 12; n = n + 1) begin
                teclas = mascara(n);
                #(SETTLE_US * 1000);

                max_suma = 0; max_ganada = 0; n_total = 0; n_recorte = 0;
                medir = 1;
                #(MEAS_US * 1000);
                medir = 0;

                $display("%-10s  %6d  %10d  %11d  %12d  %9.2f%%  %0d%s",
                         nombre, n, max_suma, n * 32768, max_ganada,
                         100.0 * n_recorte / n_total,
                         vol_sin_recorte(max_ganada, u_audio.reserva),
                         (max_suma > n * 32768) ? "   <-- DESBORDE DE LA SUMA" : "");
            end
        end

        teclas = 12'd0;
        #10_000_000;
        $display("");
        $display("Fin. vol_max_sin_recorte = 0 significa que recorta incluso con volumen 1.");
        $stop;
    end

endmodule
