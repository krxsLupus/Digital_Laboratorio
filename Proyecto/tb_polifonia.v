`timescale 1ns/1ps
// Testbench de polifonia: para cada forma de onda pulsa 1, 2, 3 ... 12 teclas
// (sumando una tecla en cada paso) y mide cuando aparecen problemas.
//
// Mide, por cada combinacion (onda, numero de teclas):
//   pico |suma|     salida de banco_notas. Si pasa de n*32768 hay desborde de la suma.
//   pico |norm|    despues de la ganancia automatica (1/raiz(n)), antes del margen.
//   % recortado     porcentaje de muestras que saturan a 16 bits con el volumen
//                   elegido (parametro VOLUMEN).
//   reserva_min     margen minimo (pasos de 6 dB) con el que ese pico no recorta; debe ser
//                   <= RESERVA de salida_i2s (2).
//
// Orden de las teclas (por nota; la posicion en el teclado sale de lut_frecuencias):
// Do, Mi, Sol, Si, Re, Fa, La, Do#, Re#, Fa#, Sol#, La#
// (primero un acorde mayor, que es lo que se toca normalmente).
//
// Uso en Questa:  vsim -voptargs=+acc work.tb_polifonia ; do tb_polifonia.do ; run -all
module tb_polifonia;

    parameter integer OCTAVA  = 1;      // 0..3 (1 = tabla original)
    parameter integer VOLUMEN = 7;      // volumen maestro (no influye en el recorte)
    parameter integer MEAS_US = 4000;   // tiempo medido por paso: > 1 periodo del Do (3.8 ms)
    parameter integer SETTLE_US = 3000; // espera antes de medir en cada paso (ataque 1 ms + decay)

    reg         clk = 0;
    reg         rst = 1;
    reg  [11:0] teclas = 12'd0;
    reg  [1:0]  sel_onda = 2'd0;
    wire signed [20:0] suma;
    wire [2:0]  vol = VOLUMEN;
    wire [1:0]  oct_tb = OCTAVA;
    wire [11:0] activas;
    wire        bclk, lrclk, din;

    always #10 clk = ~clk;              // 50 MHz

    // Envolvente casi plana para medir: ataque 1 ms, decay 1 ms, sustain 15/16, release 1 ms.
    // Los picos medidos son por tanto ~94 % del peor caso (la envolvente llega a 1.0 un instante).
    // Todas las voces con los mismos parametros (se replican a las 12 voces).
    banco_notas uut (
        .clk(clk), .rst(rst), .teclas(teclas),
        .onda_v({12{sel_onda}}), .oct_v({12{oct_tb}}),
        .a_v({12{4'd0}}), .d_v({12{4'd0}}), .s_v({12{4'd15}}), .r_v({12{4'd0}}),
        .activas(activas), .suma(suma)
    );

    salida_i2s u_audio (
        .clk(clk), .rst(rst), .suma(suma), .activas(activas),
        .volumen(vol),
        .eco_t(4'd0), .eco_fb(4'd0), .eco_mix(4'd0), .eco_ena(1'b0),
        .i2s_bclk(bclk), .i2s_lrclk(lrclk), .i2s_din(din)
    );

    // Senales internas de salida_i2s, para verlas en la onda
    // 'atenuada' = valor antes de saturar a 16 bits (ya con el margen RESERVA).
    // Si pasa de +-32767 esa muestra se recorta.
    wire signed [20:0] ganada   = u_audio.suma_n;       // tras la ganancia automatica
    wire signed [20:0] atenuada = u_audio.con_reserva;
    wire signed [15:0] muestra  = u_audio.x_seco;

    // ---------------- Orden de las teclas ----------------
    function [11:0] mascara;
        input integer n;                // numero de teclas pulsadas
        integer j;
        begin
            mascara = 12'd0;
            for (j = 0; j < n; j = j + 1) begin
                case (j)
                    0:  mascara = mascara | 12'b000000000001;   // Do   (tecla 0)
                    1:  mascara = mascara | 12'b000000000010;   // Mi   (tecla 1)
                    2:  mascara = mascara | 12'b010000000000;   // Sol  (tecla 10)
                    3:  mascara = mascara | 12'b100000000000;   // Si   (tecla 11)
                    4:  mascara = mascara | 12'b000001000000;   // Re   (tecla 6)
                    5:  mascara = mascara | 12'b000000010000;   // Fa   (tecla 4)
                    6:  mascara = mascara | 12'b000000100000;   // La   (tecla 5)
                    7:  mascara = mascara | 12'b000000001000;   // Do#  (tecla 3)
                    8:  mascara = mascara | 12'b001000000000;   // Re#  (tecla 9)
                    9:  mascara = mascara | 12'b000010000000;   // Fa#  (tecla 7)
                    10: mascara = mascara | 12'b000000000100;   // Sol# (tecla 2)
                    11: mascara = mascara | 12'b000100000000;   // La#  (tecla 8)
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

    // Margen minimo ('reserva', pasos de 6 dB) con el que un pico de 'max_ganada' cabe en 16 bits.
    // (El volumen maestro se aplica despues de saturar, asi que ya no influye en el recorte.)
    function integer reserva_minima;
        input integer pico;
        integer r;
        begin
            reserva_minima = 8;                          // 8 = ni con reserva 7 cabe
            for (r = 7; r >= 0; r = r - 1)
                if ((pico >> r) <= 32767) reserva_minima = r;
        end
    endfunction

    // ---------------- Secuencia ----------------
    integer onda, n;
    reg [8*10-1:0] nombre;

    initial begin
        $display("");
        $display("Volumen evaluado = %0d | cada paso mide %0d us", VOLUMEN, MEAS_US);
        $display("onda        teclas  pico|suma|  limite_suma  pico|norm|   recorte(%%)  reserva_min");
        $display("----------  ------  ----------  -----------  ------------  ----------  -------------------");

        repeat (10) @(posedge clk);
        rst = 0;

        for (onda = 0; onda < 4; onda = onda + 1) begin
            case (onda)
                0: nombre = "cuadrada";
                1: nombre = "sierra";
                2: nombre = "triangular";
                3: nombre = "seno";
            endcase

            // Soltar todas las teclas para reiniciar las fases, y cambiar de onda
            teclas   = 12'd0;
            sel_onda = onda[1:0];
            #8_000_000;                                 // 5 ms de silencio (las voces terminan su release)

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
                         reserva_minima(max_ganada),
                         (max_suma > n * 32768) ? "   <-- DESBORDE DE LA SUMA" : "");
            end
        end

        teclas = 12'd0;
        #8_000_000;
        $display("");
        $display("Fin. Si reserva_min > RESERVA de salida_i2s (2), esa combinacion recorta.");
        $stop;
    end

endmodule
