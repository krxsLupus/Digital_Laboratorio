// HUD de parametros para el VGA: ADSR, eco (retardo, realimentacion, mezcla) y BPM.
// Dos columnas, 4 filas por columna. Cada campo: etiqueta (3 caracteres), valor
// (3 caracteres) y una barra de 16 pasos. El parametro elegido en ctrl_param
// (sel, one-hot) lleva la etiqueta en amarillo.
//   Izquierda: A, D, S, R      Derecha: DLY, FB, MIX, BPM
// Campo de 216 px: etiqueta (3 car.), espacio, valor (3 car.), barra de 96 px.
// Valores: indice 0..15 en decimal (el display de 7 segmentos lo muestra en hex).
// BPM: valor real, 60 + 10 * indice.
// Puramente combinacional: vga_draw registra la salida.
module vga_hud (
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [3:0] a, d, s, r,
    input  wire [3:0] t, fb, mix, bpm,
    input  wire [7:0] sel,          // one-hot: bit 0 = A ... bit 7 = BPM
    output reg        hit,          // 1 = este pixel lo pinta el HUD
    output reg  [2:0] rgb
);

    localparam [9:0] X_IZQ = 10'd16, X_DER = 10'd336, ANCHO = 10'd216;

    // ---------------- Fila (y) ----------------
    reg       yin;
    reg [1:0] rr;
    reg [9:0] gy;                           // 0..15 dentro de la fila
    always @(*) begin
        yin = 1'b1; rr = 2'd0; gy = 10'd0;
        if      (y >= 10'd16 && y < 10'd32) begin rr = 2'd0; gy = y - 10'd16; end
        else if (y >= 10'd40 && y < 10'd56) begin rr = 2'd1; gy = y - 10'd40; end
        else if (y >= 10'd64 && y < 10'd80) begin rr = 2'd2; gy = y - 10'd64; end
        else if (y >= 10'd88 && y < 10'd104) begin rr = 2'd3; gy = y - 10'd88; end
        else yin = 1'b0;
    end

    // ---------------- Columna (x) ----------------
    wire in_izq = (x >= X_IZQ) && (x < X_IZQ + ANCHO);
    wire in_der = (x >= X_DER) && (x < X_DER + ANCHO);
    wire [9:0] xo = in_der ? (x - X_DER) : (x - X_IZQ);   // 0..199 dentro del campo
    wire [2:0] p  = {in_der, rr};                         // parametro 0..7

    // ---------------- Valor del parametro ----------------
    reg [3:0] val;
    always @(*) begin
        case (p)
            3'd0: val = a;   3'd1: val = d;   3'd2: val = s;   3'd3: val = r;
            3'd4: val = t;   3'd5: val = fb;  3'd6: val = mix; default: val = bpm;
        endcase
    end

    // BPM = 60 + 10*idx: BPM/10 = 6 + idx (6..21)
    wire [4:0] bpm10 = {1'b0, bpm} + 5'd6;
    wire [1:0] bpm_c = (bpm10 >= 5'd20) ? 2'd2 : (bpm10 >= 5'd10) ? 2'd1 : 2'd0;
    wire [4:0] bpm_d = bpm10 - ((bpm_c == 2'd2) ? 5'd20 : (bpm_c == 2'd1) ? 5'd10 : 5'd0);

    // Codigos de caracter: 0-9 digitos | 10 A | 11 B | 12 D | 13 F | 14 I | 15 M
    //                       16 P | 17 R | 18 S | 19 T | 20 X | 21 L | 22 Y | 31 espacio
    localparam [4:0] C_A=5'd10, C_B=5'd11, C_D=5'd12, C_F=5'd13, C_I=5'd14, C_M=5'd15,
                     C_P=5'd16, C_R=5'd17, C_S=5'd18, C_T=5'd19, C_X=5'd20, C_L=5'd21,
                     C_Y=5'd22, C_SP=5'd31;

    wire [3:0] ci = xo[7:4];                // caracter 0..5 (cada uno 16 px)

    reg [4:0] ch;
    always @(*) begin
        ch = C_SP;
        if (ci < 3'd3) begin                // etiqueta
            case (p)
                3'd0: ch = (ci == 0) ? C_A : C_SP;
                3'd1: ch = (ci == 0) ? C_D : C_SP;
                3'd2: ch = (ci == 0) ? C_S : C_SP;
                3'd3: ch = (ci == 0) ? C_R : C_SP;
                3'd4: ch = (ci == 0) ? C_D : (ci == 1) ? C_L : C_Y;
                3'd5: ch = (ci == 0) ? C_F : (ci == 1) ? C_B : C_SP;
                3'd6: ch = (ci == 0) ? C_M : (ci == 1) ? C_I : C_X;
                default: ch = (ci == 0) ? C_B : (ci == 1) ? C_P : C_M;
            endcase
        end else if (p == 3'd7) begin       // BPM: 3 digitos
            ch = (ci == 3'd4) ? ((bpm_c == 0) ? C_SP : {3'b000, bpm_c[0] ? 2'd1 : 2'd2}) :
                 (ci == 3'd5) ? {1'b0, bpm_d} :
                 (ci == 3'd6) ? 5'd0 : C_SP;
        end else begin                      // indice 0..15: 2 digitos sin cero a la izquierda
            if (ci == 3'd5)      ch = (val >= 4'd10) ? 5'd1 : C_SP;
            else if (ci == 3'd6) ch = {1'b0, (val >= 4'd10) ? (val - 4'd10) : val};
        end
    end

    // ---------------- Fuente 8x8 (bit 7 = pixel de la izquierda) ----------------
    reg [7:0] fila_g;
    always @(*) begin
        case ({ch, gy[3:1]})
            // 0
            {5'd0,3'd0}: fila_g=8'h3C; {5'd0,3'd1}: fila_g=8'h66; {5'd0,3'd2}: fila_g=8'h6E; {5'd0,3'd3}: fila_g=8'h76;
            {5'd0,3'd4}: fila_g=8'h66; {5'd0,3'd5}: fila_g=8'h66; {5'd0,3'd6}: fila_g=8'h3C;
            // 1
            {5'd1,3'd0}: fila_g=8'h18; {5'd1,3'd1}: fila_g=8'h38; {5'd1,3'd2}: fila_g=8'h18; {5'd1,3'd3}: fila_g=8'h18;
            {5'd1,3'd4}: fila_g=8'h18; {5'd1,3'd5}: fila_g=8'h18; {5'd1,3'd6}: fila_g=8'h7E;
            // 2
            {5'd2,3'd0}: fila_g=8'h3C; {5'd2,3'd1}: fila_g=8'h66; {5'd2,3'd2}: fila_g=8'h06; {5'd2,3'd3}: fila_g=8'h0C;
            {5'd2,3'd4}: fila_g=8'h18; {5'd2,3'd5}: fila_g=8'h30; {5'd2,3'd6}: fila_g=8'h7E;
            // 3
            {5'd3,3'd0}: fila_g=8'h3C; {5'd3,3'd1}: fila_g=8'h66; {5'd3,3'd2}: fila_g=8'h06; {5'd3,3'd3}: fila_g=8'h1C;
            {5'd3,3'd4}: fila_g=8'h06; {5'd3,3'd5}: fila_g=8'h66; {5'd3,3'd6}: fila_g=8'h3C;
            // 4
            {5'd4,3'd0}: fila_g=8'h0C; {5'd4,3'd1}: fila_g=8'h1C; {5'd4,3'd2}: fila_g=8'h3C; {5'd4,3'd3}: fila_g=8'h6C;
            {5'd4,3'd4}: fila_g=8'h7E; {5'd4,3'd5}: fila_g=8'h0C; {5'd4,3'd6}: fila_g=8'h0C;
            // 5
            {5'd5,3'd0}: fila_g=8'h7E; {5'd5,3'd1}: fila_g=8'h60; {5'd5,3'd2}: fila_g=8'h7C; {5'd5,3'd3}: fila_g=8'h06;
            {5'd5,3'd4}: fila_g=8'h06; {5'd5,3'd5}: fila_g=8'h66; {5'd5,3'd6}: fila_g=8'h3C;
            // 6
            {5'd6,3'd0}: fila_g=8'h1C; {5'd6,3'd1}: fila_g=8'h30; {5'd6,3'd2}: fila_g=8'h60; {5'd6,3'd3}: fila_g=8'h7C;
            {5'd6,3'd4}: fila_g=8'h66; {5'd6,3'd5}: fila_g=8'h66; {5'd6,3'd6}: fila_g=8'h3C;
            // 7
            {5'd7,3'd0}: fila_g=8'h7E; {5'd7,3'd1}: fila_g=8'h06; {5'd7,3'd2}: fila_g=8'h0C; {5'd7,3'd3}: fila_g=8'h18;
            {5'd7,3'd4}: fila_g=8'h30; {5'd7,3'd5}: fila_g=8'h30; {5'd7,3'd6}: fila_g=8'h30;
            // 8
            {5'd8,3'd0}: fila_g=8'h3C; {5'd8,3'd1}: fila_g=8'h66; {5'd8,3'd2}: fila_g=8'h66; {5'd8,3'd3}: fila_g=8'h3C;
            {5'd8,3'd4}: fila_g=8'h66; {5'd8,3'd5}: fila_g=8'h66; {5'd8,3'd6}: fila_g=8'h3C;
            // 9
            {5'd9,3'd0}: fila_g=8'h3C; {5'd9,3'd1}: fila_g=8'h66; {5'd9,3'd2}: fila_g=8'h66; {5'd9,3'd3}: fila_g=8'h3E;
            {5'd9,3'd4}: fila_g=8'h06; {5'd9,3'd5}: fila_g=8'h0C; {5'd9,3'd6}: fila_g=8'h38;
            // A
            {C_A,3'd0}: fila_g=8'h18; {C_A,3'd1}: fila_g=8'h3C; {C_A,3'd2}: fila_g=8'h66; {C_A,3'd3}: fila_g=8'h66;
            {C_A,3'd4}: fila_g=8'h7E; {C_A,3'd5}: fila_g=8'h66; {C_A,3'd6}: fila_g=8'h66;
            // B
            {C_B,3'd0}: fila_g=8'h7C; {C_B,3'd1}: fila_g=8'h66; {C_B,3'd2}: fila_g=8'h66; {C_B,3'd3}: fila_g=8'h7C;
            {C_B,3'd4}: fila_g=8'h66; {C_B,3'd5}: fila_g=8'h66; {C_B,3'd6}: fila_g=8'h7C;
            // D
            {C_D,3'd0}: fila_g=8'h78; {C_D,3'd1}: fila_g=8'h6C; {C_D,3'd2}: fila_g=8'h66; {C_D,3'd3}: fila_g=8'h66;
            {C_D,3'd4}: fila_g=8'h66; {C_D,3'd5}: fila_g=8'h6C; {C_D,3'd6}: fila_g=8'h78;
            // F
            {C_F,3'd0}: fila_g=8'h7E; {C_F,3'd1}: fila_g=8'h60; {C_F,3'd2}: fila_g=8'h60; {C_F,3'd3}: fila_g=8'h78;
            {C_F,3'd4}: fila_g=8'h60; {C_F,3'd5}: fila_g=8'h60; {C_F,3'd6}: fila_g=8'h60;
            // I
            {C_I,3'd0}: fila_g=8'h3C; {C_I,3'd1}: fila_g=8'h18; {C_I,3'd2}: fila_g=8'h18; {C_I,3'd3}: fila_g=8'h18;
            {C_I,3'd4}: fila_g=8'h18; {C_I,3'd5}: fila_g=8'h18; {C_I,3'd6}: fila_g=8'h3C;
            // M
            {C_M,3'd0}: fila_g=8'h63; {C_M,3'd1}: fila_g=8'h77; {C_M,3'd2}: fila_g=8'h7F; {C_M,3'd3}: fila_g=8'h6B;
            {C_M,3'd4}: fila_g=8'h63; {C_M,3'd5}: fila_g=8'h63; {C_M,3'd6}: fila_g=8'h63;
            // P
            {C_P,3'd0}: fila_g=8'h7C; {C_P,3'd1}: fila_g=8'h66; {C_P,3'd2}: fila_g=8'h66; {C_P,3'd3}: fila_g=8'h7C;
            {C_P,3'd4}: fila_g=8'h60; {C_P,3'd5}: fila_g=8'h60; {C_P,3'd6}: fila_g=8'h60;
            // R
            {C_R,3'd0}: fila_g=8'h7C; {C_R,3'd1}: fila_g=8'h66; {C_R,3'd2}: fila_g=8'h66; {C_R,3'd3}: fila_g=8'h7C;
            {C_R,3'd4}: fila_g=8'h6C; {C_R,3'd5}: fila_g=8'h66; {C_R,3'd6}: fila_g=8'h66;
            // S
            {C_S,3'd0}: fila_g=8'h3C; {C_S,3'd1}: fila_g=8'h66; {C_S,3'd2}: fila_g=8'h60; {C_S,3'd3}: fila_g=8'h3C;
            {C_S,3'd4}: fila_g=8'h06; {C_S,3'd5}: fila_g=8'h66; {C_S,3'd6}: fila_g=8'h3C;
            // T
            {C_T,3'd0}: fila_g=8'h7E; {C_T,3'd1}: fila_g=8'h18; {C_T,3'd2}: fila_g=8'h18; {C_T,3'd3}: fila_g=8'h18;
            {C_T,3'd4}: fila_g=8'h18; {C_T,3'd5}: fila_g=8'h18; {C_T,3'd6}: fila_g=8'h18;
            // X
            {C_X,3'd0}: fila_g=8'h66; {C_X,3'd1}: fila_g=8'h66; {C_X,3'd2}: fila_g=8'h3C; {C_X,3'd3}: fila_g=8'h18;
            {C_X,3'd4}: fila_g=8'h3C; {C_X,3'd5}: fila_g=8'h66; {C_X,3'd6}: fila_g=8'h66;
            // L
            {C_L,3'd0}: fila_g=8'h60; {C_L,3'd1}: fila_g=8'h60; {C_L,3'd2}: fila_g=8'h60; {C_L,3'd3}: fila_g=8'h60;
            {C_L,3'd4}: fila_g=8'h60; {C_L,3'd5}: fila_g=8'h60; {C_L,3'd6}: fila_g=8'h7E;
            // Y
            {C_Y,3'd0}: fila_g=8'h66; {C_Y,3'd1}: fila_g=8'h66; {C_Y,3'd2}: fila_g=8'h3C; {C_Y,3'd3}: fila_g=8'h18;
            {C_Y,3'd4}: fila_g=8'h18; {C_Y,3'd5}: fila_g=8'h18; {C_Y,3'd6}: fila_g=8'h18;
            default: fila_g = 8'h00;        // espacio y ultima fila de cada glifo
        endcase
    end

    wire pix_txt = fila_g[~xo[3:1]];        // columna 0 = bit 7

    // ---------------- Barra: 16 pasos de 6 px (0..90 px de relleno) ----------------
    wire [9:0] bx     = xo - 10'd120;
    wire [9:0] relleno = {2'b00, val, 2'b00} + {3'b000, val, 1'b0};   // val * 6
    wire en_barra = (xo >= 10'd120) && (xo < 10'd216) && (gy >= 10'd4) && (gy < 10'd12);
    wire barra_llena = (bx < relleno);

    wire elegido = |(sel & (8'd1 << p));

    always @(*) begin
        hit = 1'b0;
        rgb = 3'b000;
        if (yin && (in_izq || in_der)) begin
            if (xo < 10'd112) begin
                if (pix_txt) begin
                    hit = 1'b1;
                    rgb = (elegido && ci < 3'd3) ? 3'b110 : 3'b111;   // etiqueta amarilla si esta elegido
                end
            end else if (en_barra) begin
                hit = 1'b1;
                rgb = barra_llena ? 3'b010 : 3'b001;
            end
        end
    end

endmodule
