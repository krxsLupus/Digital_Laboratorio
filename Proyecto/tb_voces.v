`timescale 1ns/1ps
// Testbench para ver la forma de onda de CADA tecla por separado y la SUMA de todas.
//
// Para cada forma de onda (o solo una, con el parametro ONDA):
//   fase A: las teclas se pulsan de una en una (Do, Do#, Re, ... Si), SOLO_MS cada una.
//           Asi cada voz se ve sola, sin las demas.
//   fase B: las 12 teclas pulsadas a la vez, JUNTAS_MS. Se ven las 12 voces y su suma.
//
// Senales (todas salen de banco_notas, antes de ganancias y volumen):
//   v_do ... v_si   onda de cada voz ya multiplicada por su envolvente, con signo, -128..127
//                   (0 cuando la voz esta apagada)
//   suma            salida real de banco_notas (la que usa el resto del sistema)
//   suma_ideal      la misma suma calculada de golpe, para compararla con 'suma'
//                   (suma va unos 14 ciclos de reloj atrasada: es normal; con la sierra
//                   suma = 1.5 x suma_ideal, porque banco_notas aplica x1.5 a esa onda)
//
// Uso en Questa:  vsim -voptargs=+acc work.tb_voces ; do tb_voces.do ; run -all
module tb_voces;

    parameter integer ONDA      = 4;    // 0 cuadrada, 1 sierra, 2 triangular, 3 seno, 4 = las cuatro
    parameter integer SOLO_MS   = 4;    // cada tecla sola (> 1 periodo del Do: 3.8 ms)
    parameter integer JUNTAS_MS = 8;    // las 12 juntas
    parameter integer OCTAVA    = 1;    // 0 = Do3, 1 = Do4, 2 = Do5, 3 = Do6

    reg         clk = 0;
    reg         rst = 1;
    reg  [11:0] teclas = 12'd0;
    reg  [1:0]  sel_onda = 2'd0;
    wire signed [20:0] suma;

    always #10 clk = ~clk;              // 50 MHz

    wire [11:0] activas;

    // Envolvente casi plana: ataque 1 ms, decay 1 ms, sustain 1.0, release 5 ms (minimo de banco_notas)
    banco_notas uut (
        .clk(clk), .rst(rst), .teclas(teclas),
        .onda_v({12{sel_onda}}), .oct_v({12{OCTAVA[1:0]}}),
        .a_v({12{4'd0}}), .d_v({12{4'd0}}), .s_v({12{4'd15}}), .r_v({12{4'd0}}),
        .activas(activas), .suma(suma)
    );

    // ---------------- Onda de cada tecla (muestra con signo de cada voz) ----------------
    wire signed [7:0] v_do = ($signed(uut.voces[7:0]) * $signed({1'b0, uut.env[8:0]})) >>> 8;   // Do (tecla 0)
    wire signed [7:0] v_mi = ($signed(uut.voces[15:8]) * $signed({1'b0, uut.env[17:9]})) >>> 8;   // Mi (tecla 1)
    wire signed [7:0] v_sol_s = ($signed(uut.voces[23:16]) * $signed({1'b0, uut.env[26:18]})) >>> 8;   // Sol# (tecla 2)
    wire signed [7:0] v_do_s = ($signed(uut.voces[31:24]) * $signed({1'b0, uut.env[35:27]})) >>> 8;   // Do# (tecla 3)
    wire signed [7:0] v_fa = ($signed(uut.voces[39:32]) * $signed({1'b0, uut.env[44:36]})) >>> 8;   // Fa (tecla 4)
    wire signed [7:0] v_la = ($signed(uut.voces[47:40]) * $signed({1'b0, uut.env[53:45]})) >>> 8;   // La (tecla 5)
    wire signed [7:0] v_re = ($signed(uut.voces[55:48]) * $signed({1'b0, uut.env[62:54]})) >>> 8;   // Re (tecla 6)
    wire signed [7:0] v_fa_s = ($signed(uut.voces[63:56]) * $signed({1'b0, uut.env[71:63]})) >>> 8;   // Fa# (tecla 7)
    wire signed [7:0] v_la_s = ($signed(uut.voces[71:64]) * $signed({1'b0, uut.env[80:72]})) >>> 8;   // La# (tecla 8)
    wire signed [7:0] v_re_s = ($signed(uut.voces[79:72]) * $signed({1'b0, uut.env[89:81]})) >>> 8;   // Re# (tecla 9)
    wire signed [7:0] v_sol = ($signed(uut.voces[87:80]) * $signed({1'b0, uut.env[98:90]})) >>> 8;   // Sol (tecla 10)
    wire signed [7:0] v_si = ($signed(uut.voces[95:88]) * $signed({1'b0, uut.env[107:99]})) >>> 8;   // Si (tecla 11)

    // Suma de las 12 voces calculada en un solo paso (cada voz x256, igual que banco_notas;
    // difiere un poco de 'suma' por el redondeo de la envolvente)
    wire signed [20:0] suma_ideal = (v_do + v_mi + v_sol_s + v_do_s + v_fa + v_la + v_re + v_fa_s + v_la_s + v_re_s + v_sol + v_si) * 256;

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
            #8_000_000;                                 // 8 ms en silencio (las voces terminan su release)

            $display("%0d ns: onda %0d - teclas de una en una (%0d ms cada una)", $time, o, SOLO_MS);
            for (k = 0; k < 12; k = k + 1) begin
                teclas = 12'd1 << k;
                #(SOLO_MS * 1_000_000);
            end

            teclas = 12'd0;
            #8_000_000;

            $display("%0d ns: onda %0d - las 12 teclas juntas (%0d ms)", $time, o, JUNTAS_MS);
            teclas = 12'hFFF;
            #(JUNTAS_MS * 1_000_000);
        end

        teclas = 12'd0;
        #8_000_000;
        $display("%0d ns: fin", $time);
        $stop;
    end

endmodule
