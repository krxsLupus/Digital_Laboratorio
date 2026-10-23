// Escaneo de teclado matricial 4x3 (estilo telefónico, 12 teclas: 1-9,0,*,#).
// Adaptado de teclado.v (4x4) a 3 columnas en vez de 4.
// La FPGA maneja las 4 filas (rows, salida, activa en bajo, 'bz en las
// inactivas) y lee las 3 columnas (cols, entrada). Las columnas necesitan
// pull-up (interno de la FPGA o resistencias externas a 3.3V): sin eso,
// una entrada en alta impedancia no se puede leer como "1" de forma
// confiable, y el teclado parecería no reaccionar.
//
// Mapa de teclas (key_code):
//   fila0: 1 2 3      fila1: 4 5 6
//   fila2: 7 8 9      fila3: *=10 0 #=11

module teclado_4x3 #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer DEB_MS   = 10
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] cols,                 // C1, C2, C3 (con pull-up)
    output wire [3:0] rows,                 // R1..R4
    output reg  [3:0] key_code = 4'd0,      // 0-9, 10='*', 11='#'
    output wire       key_valid
);

    localparam integer TICK_DIV = CLK_FREQ / 1000;
    localparam integer TICK_W   = (TICK_DIV > 1) ? $clog2(TICK_DIV) : 1;
    reg [TICK_W-1:0] cnt_tick = 0;
    reg              tick     = 1'b0;

    always @(posedge clk) begin
        if (rst || cnt_tick == TICK_DIV - 1) cnt_tick <= 0;
        else                                 cnt_tick <= cnt_tick + 1'b1;
        tick <= !rst && (cnt_tick == TICK_DIV - 1);
    end

    // Sincronizador de entradas asíncronas (el teclado es externo)
    reg [2:0] cols_s1 = 3'b111;
    reg [2:0] cols_s2 = 3'b111;
    always @(posedge clk) begin
        cols_s1 <= cols;
        cols_s2 <= cols_s1;
    end

    reg [1:0] row_idx = 2'd0;
    assign rows[0] = (row_idx == 2'd0) ? 1'b0 : 1'bz;
    assign rows[1] = (row_idx == 2'd1) ? 1'b0 : 1'bz;
    assign rows[2] = (row_idx == 2'd2) ? 1'b0 : 1'bz;
    assign rows[3] = (row_idx == 2'd3) ? 1'b0 : 1'bz;

    wire       hay_tecla = (cols_s2 != 3'b111);
    reg  [1:0] col_idx;
    always @(*) begin
        if      (!cols_s2[0]) col_idx = 2'd0;
        else if (!cols_s2[1]) col_idx = 2'd1;
        else                  col_idx = 2'd2;   // solo quedan 3 columnas
    end

    wire [3:0] pos_now = {row_idx, col_idx};
    reg  [3:0] valor;
    always @(*) begin
        case (pos_now)
            4'b00_00: valor = 4'd1;   4'b00_01: valor = 4'd2;   4'b00_10: valor = 4'd3;
            4'b01_00: valor = 4'd4;   4'b01_01: valor = 4'd5;   4'b01_10: valor = 4'd6;
            4'b10_00: valor = 4'd7;   4'b10_01: valor = 4'd8;   4'b10_10: valor = 4'd9;
            4'b11_00: valor = 4'd10;  // *
            4'b11_01: valor = 4'd0;
            4'b11_10: valor = 4'd11; // #
            default:  valor = 4'd0;  // col_idx=3 no existe en 4x3; no debería ocurrir
        endcase
    end

    reg [3:0] pos_prev           = 4'd0;
    reg [3:0] estable            = 4'd0;
    reg       presionada_estable = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            row_idx            <= 2'd0;
            estable            <= 4'd0;
            presionada_estable <= 1'b0;
        end else if (tick) begin
            if (hay_tecla) begin
                if (!presionada_estable) begin
                    if (estable == 4'd0) begin
                        pos_prev <= pos_now;
                        estable  <= 4'd1;
                    end else if (pos_now != pos_prev) begin
                        estable  <= 4'd0;
                    end else if (estable == DEB_MS) begin
                        key_code           <= valor;
                        presionada_estable <= 1'b1;
                    end else begin
                        estable  <= estable + 1'b1;
                    end
                end
            end else begin
                presionada_estable <= 1'b0;
                estable            <= 4'd0;
                row_idx            <= row_idx + 1'b1;
            end
        end
    end

    reg presionada_ant = 1'b0;
    always @(posedge clk) presionada_ant <= presionada_estable;
    assign key_valid = presionada_estable & ~presionada_ant;

endmodule