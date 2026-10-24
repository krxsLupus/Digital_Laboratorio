// ============================================================================
// MÓDULO PRINCIPAL: SINTETIZADOR DE AUDIO CON SALIDA DAC, DISPLAY Y VGA
// Descripción: Integra teclado 4x3, encoder KY-040, generador de notas, 
//              multiplexado de 7 segmentos y controlador de video VGA.
// ============================================================================
module top_sintetizador (
    input  wire       clk,        // Reloj principal del sistema a 50 MHz
    input  wire       rst,        // Botón de reset físico, activo en bajo
    input  wire [2:0] cols_tec,   // Columnas del teclado matricial con pull-up
    output wire [3:0] rows_tec,   // Filas del teclado matricial
    input  wire       pin_a,      // Canal CLK del encoder rotativo KY-040
    input  wire       pin_b,      // Canal DT del encoder rotativo KY-040
    output wire [7:0] dac,        // Salida de audio de 8 bits hacia red R-2R (MSB = dac[7])
    output reg  [6:0] seg,        // Segmentos a-g del display de 7 segmentos
    output reg  [3:0] dig,        // Habilitación de dígitos, activo en bajo
    output wire       vga_hs,     // Sincronismo horizontal VGA
    output wire       vga_vs,     // Sincronismo vertical VGA
    output wire       vga_r,      // Canal Rojo VGA 
    output wire       vga_g,      // Canal Verde VGA 
    output wire       vga_b       // Canal Azul VGA
);

    wire rst_h = ~rst;           // reset interno activo en alto

    // ------------------------------------------------------------------------
    // CONTROLADOR DE TECLADO MATRICIAL 4x3
    // ------------------------------------------------------------------------
    wire [3:0] key_code;          // Código numérico de la tecla detectada
    wire       key_valid;         // Pulso indicador de lectura válida de tecla
    wire       key_down;          // Flag de tecla actualmente presionada

    teclado_4x3 #(
        .CLK_FREQ(50_000_000),    // Frecuencia del reloj de entrada (50 MHz)
        .DEB_MS(10)               // Tiempo de antirrebote en milisegundos
    ) u_teclado (
        .clk       (clk),
        .rst       (rst_h),
        .cols      (cols_tec),
        .rows      (rows_tec),
        .key_code  (key_code),
        .key_valid (key_valid),
        .key_down  (key_down)
    );

    // ------------------------------------------------------------------------
    // CONTROLADOR DE ENCODER ROTATIVO KY-040
    // ------------------------------------------------------------------------
    wire [1:0] sel_onda;          // Selector de forma de onda

    encoder_ky040 u_encoder (
        .clk      (clk),
        .rst      (rst_h),
        .pin_a    (pin_a),
        .pin_b    (pin_b),
        .sel_onda (sel_onda)
    );

   // ------------------------------------------------------------------------
    // GENERADOR DE TONOS
    // ------------------------------------------------------------------------
    wire [7:0] onda_out;          // Muestra de audio digital generada de 8 bits
    wire [3:0] nota_idx;          // Índice de la nota generada

    generador_notas u_notas (
        .clk        (clk),
        .rst        (rst_h),
        .key_code   (key_code),
        .key_down   (key_down),
        .sel_onda   (sel_onda),
        .onda_out   (onda_out),
        .nota_idx   (nota_idx)
    );

    // Asignación directa de la muestra digital al puerto de salida hacia el DAC R-2R
    assign dac = onda_out;

    // ------------------------------------------------------------------------
    // MULTIPLEXADO Y CONTROL DE DISPLAYS DE 7 SEGMENTOS
    // ------------------------------------------------------------------------
    reg [15:0] clk_div = 16'd0;   // Divisor de frecuencia por contador

    // Incrementa el contador con cada ciclo del reloj principal
    always @(posedge clk) begin
        clk_div <= clk_div + 1'b1;
    end

    wire [1:0] sel_disp = clk_div[15:14]; // Usa los 2 MSB para alternar el dígito activo
    reg  [3:0] digito_mostrar;           // Valor BCD a enviar al decodificador
    wire [6:0] seg_decodificado;         // Patrón de segmentos devuelto por el decodificador

    // Instancia del decodificador BCD a 7 segmentos
    bcd_7s u_disp (
        .digito (digito_mostrar),
        .seg    (seg_decodificado)
    );

    // Lógica combinacional de multiplexado de pantallas
    always @(*) begin
        case (sel_disp)
            2'b00: begin
                dig = 4'b1110;             // Activa el Dígito 0
                digito_mostrar = key_code; // Muestra la tecla presionada
                seg = seg_decodificado;
            end
            2'b11: begin
                dig = 4'b0111;             // Activa el Dígito 3
                digito_mostrar = {2'b00, sel_onda}; // Muestra la onda seleccionada
                seg = seg_decodificado;
            end
            default: begin
                dig = 4'b1111;             // Desactiva todos los dígitos
                digito_mostrar = 4'd0;
                seg = 7'b1111111;          // Apaga los segmentos
            end
        endcase
    end

    // ------------------------------------------------------------------------
    // CONTROLADOR DE GRÁFICOS VGA
    // ------------------------------------------------------------------------
    wire       video_on;          // Indicador de zona activa de renderizado
    wire [9:0] p_x;               // Coordenada X actual del píxel
    wire [9:0] p_y;               // Coordenada Y actual del píxel
    wire [2:0] rgb;               // Vector de color {R, G, B}

    // Generador de tiempos y señales de sincronismo VGA
    vga_sync u_vga_sync (
        .clk      (clk),
        .hsync    (vga_hs),
        .vsync    (vga_vs),
        .video_on (video_on),
        .p_x      (p_x),
        .p_y      (p_y)
    );

    // Generador del patrón gráfico de la forma de onda
    vga_draw u_vga_draw (
        .x        (p_x),
        .y        (p_y),
        .video_on (video_on),
        .sel_onda (sel_onda),
        .rgb      (rgb)
    );

    // Asignación de componentes de color a los pines de salida VGA
    assign vga_r = rgb[2];
    assign vga_g = rgb[1];
    assign vga_b = rgb[0];

endmodule