// Osciloscopio de captura para el VGA: guarda 640 muestras de la mezcla real (despues
// de la ganancia automatica, antes del eco y del volumen) y las dibuja como un trazo.
//
// Por que no se ve borroso: se hace UNA captura cada REFRESCO cuadros, disparada en el
// cruce por cero ascendente de la propia mezcla, y esa captura se MANTIENE quieta en
// pantalla hasta la siguiente. Antes la imagen se movia entre cuadros y el ojo promediaba
// varias fases distintas. Si no hay disparo (silencio, o un acorde sin cruce limpio) se
// captura igual al llegar el siguiente cuadro (disparo automatico, como un osciloscopio).
//
// Doble buffer: se escribe en un banco mientras el otro se muestra; el cambio de banco
// solo ocurre al inicio del cuadro, asi nunca hay un cuadro a medio actualizar.
// Cada columna guarda {minimo, maximo} entre la muestra anterior y la actual, para que
// los flancos verticales (cuadrada, sierra) se dibujen continuos.
//
// Escala vertical: valor = muestra >>> SHIFT, limitado a +-127 pixeles. SHIFT = 7: una
// nota sola llega a +-64 px y un acorde de 3 notas a ~+-110 px sin recortar.
module vga_scope #(
    parameter integer N        = 640,   // columnas = muestras capturadas
    parameter integer SHIFT    = 7,
    parameter integer REFRESCO = 3,     // cuadros por captura (60 / REFRESCO Hz)
    parameter integer DECIM    = 1,     // 1 = cada muestra de 48.8 kHz; 2 = una de cada 2 ...
    parameter integer TH       = 128    // histeresis del disparo (escala de 16 bits)
)(
    input  wire               clk,
    input  wire               rst,           // activo en alto
    input  wire               en_48k,        // una muestra nueva (48.8 kHz)
    input  wire signed [15:0] muestra,
    input  wire [9:0]         x,             // columna que se esta pintando
    input  wire [9:0]         y,
    output reg  [7:0]         s_hi = 8'd128, // extremos de la columna x (128 = centro)
    output reg  [7:0]         s_lo = 8'd128  // mas arriba en pantalla = valor mayor
);

    // ---------------- Muestra -> 1..255 (128 = 0) ----------------
    wire signed [15:0] esc = muestra >>> SHIFT;
    wire [7:0] v = (esc >  16'sd127) ? 8'd255 :
                   (esc < -16'sd127) ? 8'd1   : (esc[7:0] + 8'd128);

    // ---------------- Disparo: cruce por cero ascendente con histeresis ----------------
    reg abajo = 1'b0;
    always @(posedge clk) begin
        if (rst)                           abajo <= 1'b0;
        else if (en_48k) begin
            if (muestra < -TH)             abajo <= 1'b1;
            else if (muestra >= 16'sd0)    abajo <= 1'b0;
        end
    end
    wire trig = en_48k && abajo && (muestra >= 16'sd0);

    // ---------------- Inicio de cuadro ----------------
    wire fs_lvl = (x == 10'd0) && (y == 10'd0);
    reg  fs_d = 1'b0;
    always @(posedge clk) fs_d <= fs_lvl;
    wire inicio = fs_lvl && !fs_d;

    // ---------------- Maquina de captura ----------------
    localparam [1:0] S_IDLE = 2'd0, S_ARM = 2'd1, S_CAP = 2'd2, S_DONE = 2'd3;
    reg [1:0] st     = S_IDLE;
    reg [9:0] wptr   = 10'd0;
    reg       wbank  = 1'b0;           // banco en el que se escribe
    reg       dbank  = 1'b1;           // banco que se muestra
    reg [3:0] fr_cnt = 4'd0;
    reg [7:0] dec    = 8'd0;
    reg [7:0] prev_v = 8'd128;

    wire toma     = en_48k && (dec == DECIM - 1);
    wire escribe  = toma && ((st == S_CAP) || (st == S_ARM && trig));

    wire [7:0] p    = (wptr == 10'd0) ? v : prev_v;
    wire [7:0] w_hi = (v > p) ? v : p;
    wire [7:0] w_lo = (v > p) ? p : v;

    always @(posedge clk) begin
        if (rst) begin
            st <= S_IDLE; wptr <= 10'd0; wbank <= 1'b0; dbank <= 1'b1;
            fr_cnt <= 4'd0; dec <= 8'd0; prev_v <= 8'd128;
        end else begin
            if (en_48k) dec <= (dec == DECIM - 1) ? 8'd0 : dec + 1'b1;

            if (escribe) begin
                prev_v <= v;
                if (st == S_ARM) st <= S_CAP;
                if (wptr == N - 1) st <= S_DONE;
                else               wptr <= wptr + 1'b1;
            end

            if (inicio) begin                      // estas asignaciones ganan a las de arriba
                fr_cnt <= (fr_cnt == REFRESCO - 1) ? 4'd0 : fr_cnt + 1'b1;
                if (st == S_DONE) begin
                    dbank <= wbank;                // la captura terminada pasa a pantalla
                    wbank <= ~wbank;
                    st    <= S_IDLE;
                end
                if (fr_cnt == 4'd0 && (st == S_IDLE || st == S_DONE)) begin
                    st   <= S_ARM;
                    wptr <= 10'd0;
                end else if (st == S_ARM) begin
                    st   <= S_CAP;                 // disparo automatico: no llego disparo
                end
            end
        end
    end

    // ---------------- Memoria: 2 bancos x 1024 palabras de {min, max} ----------------
    reg [15:0] mem [0:2047];
    integer q;
    initial begin
        for (q = 0; q < 2048; q = q + 1) mem[q] = 16'h8080;
    end

    always @(posedge clk) begin
        if (escribe) mem[{wbank, wptr}] <= {w_lo, w_hi};
    end

    always @(posedge clk) begin
        {s_lo, s_hi} <= mem[{dbank, x}];       // lectura sincrona: dato valido 1 ciclo despues
    end

endmodule
