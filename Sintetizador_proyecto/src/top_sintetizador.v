// Top de ejemplo: teclado 4x3 + encoder KY-040 + generador de notas + VGA + displays.
// Salida de audio: dac[7:0] (R-2R de 8 bits).
module top_sintetizador (
    input  wire       clk,       // 50 MHz
    input  wire       rst,       // boton de reset, activo en bajo
    input  wire [2:0] cols_tec,  // columnas del teclado (con pull-up)
    output wire [3:0] rows_tec,  // filas del teclado
    input  wire       pin_a,     // encoder CLK
    input  wire       pin_b,     // encoder DT
    output wire [7:0] dac,       // al DAC R-2R (dac[7] = MSB)
    output reg  [6:0] seg,
    output reg  [3:0] dig,
    output wire       vga_hs,
    output wire       vga_vs,
    output wire       vga_r,
    output wire       vga_g,
    output wire       vga_b
);

    wire rst_h = ~rst;           // reset interno activo en alto

    // 1. Teclado
    wire [3:0] key_code;
    wire       key_valid;
    wire       key_down;

    teclado_4x3 #(.CLK_FREQ(50_000_000), .DEB_MS(10)) u_teclado (
        .clk       (clk),
        .rst       (rst_h),
        .cols      (cols_tec),
        .rows      (rows_tec),
        .key_code  (key_code),
        .key_valid (key_valid),
        .key_down  (key_down)
    );

    // 2. Encoder: elige la forma de onda
    wire [1:0] sel_onda;

    encoder_ky040 u_encoder (
        .clk      (clk),
        .rst      (rst_h),
        .pin_a    (pin_a),
        .pin_b    (pin_b),
        .sel_onda (sel_onda)
    );

    // 3. Generador de notas
    wire [7:0] onda_out;
    wire [3:0] nota_idx;

    generador_notas u_notas (
        .clk        (clk),
        .rst        (rst_h),
        .key_code   (key_code),
        .key_down   (key_down),
        .sel_onda   (sel_onda),
        .onda_out   (onda_out),
        .nota_idx   (nota_idx)
    );

    assign dac = onda_out;

    // 4. Displays: tecla en el digito 0, forma de onda en el digito 3
    reg [15:0] clk_div = 16'd0;
    always @(posedge clk) clk_div <= clk_div + 1'b1;

    wire [1:0] sel_disp = clk_div[15:14];
    reg  [3:0] digito_mostrar;
    wire [6:0] seg_decodificado;

    bcd_7s u_disp (
        .digito (digito_mostrar),
        .seg    (seg_decodificado)
    );

    always @(*) begin
        case (sel_disp)
            2'b00: begin
                dig = 4'b1110;
                digito_mostrar = key_code;
                seg = seg_decodificado;
            end
            2'b11: begin
                dig = 4'b0111;
                digito_mostrar = {2'b00, sel_onda};
                seg = seg_decodificado;
            end
            default: begin
                dig = 4'b1111;
                digito_mostrar = 4'd0;
                seg = 7'b1111111;
            end
        endcase
    end

    // 5. VGA (dibuja la forma de onda seleccionada)
    wire       video_on;
    wire [9:0] p_x;
    wire [9:0] p_y;
    wire [2:0] rgb;

    vga_sync u_vga_sync (
        .clk      (clk),
        .hsync    (vga_hs),
        .vsync    (vga_vs),
        .video_on (video_on),
        .p_x      (p_x),
        .p_y      (p_y)
    );

    vga_draw u_vga_draw (
        .x        (p_x),
        .y        (p_y),
        .video_on (video_on),
        .sel_onda (sel_onda),
        .rgb      (rgb)
    );

    assign vga_r = rgb[2];
    assign vga_g = rgb[1];
    assign vga_b = rgb[0];

endmodule
