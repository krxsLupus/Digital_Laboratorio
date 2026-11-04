`timescale 1ns/1ps
// Testbench para ver la forma de onda de CADA tecla por separado y la SUMA de todas.
//
// Para cada forma de onda (o solo una, con el parametro ONDA):
//   fase A: las teclas se pulsan de una en una (Do, Do#, Re, ... Si), SOLO_MS cada una.
//           Asi cada voz se ve sola, sin las demas.
//   fase B: las 12 teclas pulsadas a la vez, JUNTAS_MS. Se ven las 12 voces y su suma.
//
// Senales (todas salen de banco_notas, antes de ganancias y volumen):
//   v_do ... v_si   onda de cada tecla, con signo, -128..127 (0 si la tecla no esta pulsada)
//   suma            salida real de banco_notas (la que usa el resto del sistema)
//   suma_ideal      la misma suma calculada de golpe (onda x envolvente de cada voz),
//                   para compararla con 'suma' (va unos 16 ciclos de reloj atrasada: es normal)
//
// Con ADSR: entre tecla y tecla hay un silencio GAP_MS que deja terminar el release
// (5 ms como minimo), si no la cola de la nota anterior se mezclaria con la siguiente.
// Por cada tecla se imprime el pico que alcanza 'suma' en los primeros 100 us
// (% del pico de la nota): sin ADSR eso era ~100 %, con ataque de 1 ms es ~10 %.
//
// Uso en Questa:  vsim -voptargs=+acc work.tb_voces ; do tb_voces.do ; run -all
module tb_voces;

    parameter integer ONDA      = 4;    // 0 cuadrada, 1 sierra, 2 triangular, 3 seno, 4 = las cuatro
    parameter integer SOLO_MS   = 4;    // cada tecla sola (> 1 periodo del Do: 3.8 ms)
    parameter integer JUNTAS_MS = 8;    // las 12 juntas
    parameter integer GAP_MS    = 6;    // silencio entre teclas (> release)
    parameter integer A_IDX = 0;        // ataque 1 ms
    parameter integer D_IDX = 0;
    parameter integer S_IDX = 15;       // sustain 1.0 (sin decay)
    parameter integer R_IDX = 2;        // release 5 ms

    reg         clk = 0;
    reg         rst = 1;
    reg  [11:0] teclas = 12'd0;
    reg  [1:0]  sel_onda = 2'd0;
    wire signed [19:0] suma;
    wire [11:0] activas;

    always #10 clk = ~clk;              // 50 MHz

    banco_notas uut (
        .clk(clk), .rst(rst), .teclas(teclas), .sel_onda(sel_onda),
        .a_idx(A_IDX[3:0]), .d_idx(D_IDX[3:0]), .s_idx(S_IDX[3:0]), .r_idx(R_IDX[3:0]),
        .activas(activas), .suma(suma)
    );

    // ---------------- Onda de cada tecla (muestra con signo de cada voz) ----------------
    wire signed [7:0] v_do     = uut.voces[7:0];   // Do
    wire signed [7:0] v_do_s   = uut.voces[15:8];   // Do#
    wire signed [7:0] v_re     = uut.voces[23:16];   // Re
    wire signed [7:0] v_re_s   = uut.voces[31:24];   // Re#
    wire signed [7:0] v_mi     = uut.voces[39:32];   // Mi
    wire signed [7:0] v_fa     = uut.voces[47:40];   // Fa
    wire signed [7:0] v_fa_s   = uut.voces[55:48];   // Fa#
    wire signed [7:0] v_sol    = uut.voces[63:56];   // Sol
    wire signed [7:0] v_sol_s  = uut.voces[71:64];   // Sol#
    wire signed [7:0] v_la     = uut.voces[79:72];   // La
    wire signed [7:0] v_la_s   = uut.voces[87:80];   // La#
    wire signed [7:0] v_si     = uut.voces[95:88];   // Si

    // Suma de las 12 voces calculada en un solo paso (cada onda x su envolvente, 0..256)
    integer q;
    reg signed [31:0] s_tmp;
    always @(*) begin
        s_tmp = 0;
        for (q = 0; q < 12; q = q + 1)
            s_tmp = s_tmp + $signed(uut.voces[8*q +: 8]) * $signed({1'b0, uut.env[9*q +: 9]});
    end
    wire signed [19:0] suma_ideal = s_tmp[19:0];

    // Comprobacion: 'suma' (una vez actualizada) debe coincidir con 'suma_ideal' tomada al
    // inicio de la pasada de 15 ciclos. Se tolera una diferencia pequena porque una onda
    // puede cambiar 1 LSB mientras el lazo serie recorre las voces.
    reg signed [19:0] ref_ideal = 20'sd0;
    integer n_cmp = 0, n_bad = 0, dif;
    always @(posedge clk) begin
        if (uut.k == 4'd1) ref_ideal <= suma_ideal;
        if (uut.k == 4'd0 && !rst) begin
            dif = suma - ref_ideal;
            if (dif < 0) dif = -dif;
            n_cmp = n_cmp + 1;
            if (dif > 768) n_bad = n_bad + 1;
        end
    end

    // Pico de |suma| en la nota completa y en sus primeros 100 us
    integer abs_s, pico_ini, pico_tot;
    reg     en_medida = 0, en_ini = 0;
    always @(posedge clk) begin
        abs_s = (suma < 0) ? -suma : suma;
        if (en_medida && abs_s > pico_tot) pico_tot = abs_s;
        if (en_ini    && abs_s > pico_ini) pico_ini = abs_s;
    end

    // ---------------- Secuencia ----------------
    integer o, o_ini, o_fin, k;

    initial begin
        if (ONDA == 4) begin o_ini = 0;     o_fin = 3;     end
        else           begin o_ini = ONDA;  o_fin = ONDA;  end

        repeat (10) @(posedge clk);
        rst = 0;

        for (o = o_ini; o <= o_fin; o = o + 1) begin
            sel_onda = o[1:0];
            teclas   = 12'd0;
            #50_000;                                    // 50 us en silencio (reinicia las fases)

            $display("%0d ns: onda %0d - teclas de una en una (%0d ms cada una)", $time, o, SOLO_MS);
            for (k = 0; k < 12; k = k + 1) begin
                teclas = 12'd1 << k;
                pico_ini = 0; pico_tot = 0; en_medida = 1; en_ini = 1;
                #100_000;                               // primeros 100 us
                en_ini = 0;
                #(SOLO_MS * 1_000_000 - 100_000);
                en_medida = 0;
                $display("   tecla %0d: pico = %0d, en los primeros 100 us = %0d%%", k, pico_tot, (pico_tot == 0) ? 0 : (100 * pico_ini / pico_tot));
                teclas = 12'd0;
                #(GAP_MS * 1_000_000);                  // deja terminar el release
            end

            teclas = 12'd0;
            #(GAP_MS * 1_000_000);

            $display("%0d ns: onda %0d - las 12 teclas juntas (%0d ms)", $time, o, JUNTAS_MS);
            teclas = 12'hFFF;
            #(JUNTAS_MS * 1_000_000);
            teclas = 12'd0;
            #(GAP_MS * 1_000_000);
        end

        teclas = 12'd0;
        #50_000;
        $display("suma vs suma_ideal: %0d comparaciones, %0d fuera de tolerancia", n_cmp, n_bad);
        $display("%0d ns: fin", $time);
        $stop;
    end

endmodule
