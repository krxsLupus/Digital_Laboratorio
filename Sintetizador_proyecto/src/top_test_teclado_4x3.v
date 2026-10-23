module top_test_teclado_4x3 (
    input  wire       clk,       // 50 MHz
    input  wire       rst,       // Botón de reset (con ~rst adentro)
    input  wire [2:0] cols_tec,  // Columnas del teclado
    output wire [3:0] rows_tec,  // Filas del teclado
    input  wire       pin_a,     // Encoder CLK (PIN_28)
    input  wire       pin_b,     // Encoder DT  (PIN_31)
    output reg  [6:0] seg,       // Segmentos compartidos
    output reg  [3:0] dig,       // Habilitador de cada dígito (activo en bajo)
    // Puertos VGA
    output wire       vga_hs,
    output wire       vga_vs,
    output wire       vga_r,
    output wire       vga_g,
    output wire       vga_b
);

    // ==========================================
    // 1. Instancia del Teclado
    // ==========================================
    wire [3:0] key_code;
    wire       key_valid;

    teclado_4x3 #(
        .CLK_FREQ(50_000_000),
        .DEB_MS(10)
    ) u_teclado (
        .clk       (clk),
        .rst       (~rst),
        .cols      (cols_tec),
        .rows      (rows_tec),
        .key_code  (key_code),
        .key_valid (key_valid)
    );

    // ==========================================
    // 2. Instancia del Encoder KY-040
    // ==========================================
    wire [1:0] sel_onda; // Salida de 0 a 2
    
    encoder_ky040 u_encoder (
        .clk      (clk),
        .rst      (~rst),
        .pin_a    (pin_a),
        .pin_b    (pin_b),
        .sel_onda (sel_onda)
    );

    // ==========================================
    // 3. Multiplexación de Displays
    // ==========================================
    reg [15:0] clk_div = 16'd0;
    always @(posedge clk) begin
        clk_div <= clk_div + 1'b1;
    end
    
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

    // ==========================================
    // 4. Controlador VGA
    // ==========================================
    wire video_on;
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