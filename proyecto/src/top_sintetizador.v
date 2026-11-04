// Top: 12 pulsadores en matriz 4x3 con diodos (polifonico) + encoder KY-040
// + salida I2S (MAX98357A) + VGA + displays.
module top_sintetizador (
    input  wire       clk,       // 50 MHz
    input  wire       rst,       // boton de reset, activo en bajo
    input  wire [2:0] cols_tec,  // columnas de la matriz (con pull-down externo de 10 kohm)
    output wire [3:0] rows_tec,  // filas de la matriz
    input  wire       pin_a,     // encoder CLK
    input  wire       pin_b,     // encoder DT
    input  wire       vol_a,     // encoder de volumen CLK
    input  wire       vol_b,     // encoder de volumen DT
    input  wire       env_a,     // encoder de parametros ADSR CLK
    input  wire       env_b,     // encoder de parametros ADSR DT
    input  wire       env_btn,   // pulsador: elige el parametro (A, D, S, R)
    output wire [3:0] led_sel,   // LED del parametro elegido (activo en alto)
    input  wire       pedal,     // pedal de sustain: interruptor SW1 del DIP (abajo = ON con pull-up)
    output wire       i2s_bclk,  // al pin BCLK del MAX98357A
    output wire       i2s_lrclk, // al pin LRC  del MAX98357A
    output wire       i2s_din,   // al pin DIN  del MAX98357A
    output reg  [6:0] seg,
    output reg  [3:0] dig,
    output wire       vga_hs,
    output wire       vga_vs,
    output wire       vga_r,
    output wire       vga_g,
    output wire       vga_b
);

    wire rst_h = ~rst;           // reset interno activo en alto

    // 1. Matriz de pulsadores: teclas[n] = nota n pulsada (varias a la vez)
    wire [11:0] teclas;

    // ACTIVO_ALTO = 1: fila activa en 1 y tecla pulsada = 1 en la columna
    teclado_poly #(.CLK_FREQ(50_000_000), .DEB_MS(5), .ACTIVO_ALTO(1)) u_teclado (
        .clk    (clk),
        .rst    (rst_h),
        .cols   (cols_tec),
        .rows   (rows_tec),
        .teclas (teclas)
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

    // 2a. Pedal de sustain: mantiene las notas aunque se suelte la tecla.
    //     'gate' (no 'teclas') es lo que ve la envolvente de cada voz.
    //     ACTIVO_BAJO = 1: el interruptor del DIP da 0 al cerrarse (pull-up de 4.7 kohm en la placa).
    wire [11:0] gate;

    pedal_sustain #(.ACTIVO_BAJO(1)) u_pedal (
        .clk    (clk),
        .rst    (rst_h),
        .pedal  (pedal),
        .teclas (teclas),
        .gate   (gate)
    );

    // 2b. Parametros ADSR: un encoder + un pulsador (ver ctrl_adsr)
    wire [3:0] a_idx, d_idx, s_idx, r_idx;
    wire [1:0] sel_par;
    wire [3:0] val_par;

    ctrl_adsr #(.ACTIVO_BAJO(1)) u_ctrl_adsr (
        .clk   (clk),
        .rst   (rst_h),
        .enc_a (env_a),
        .enc_b (env_b),
        .btn   (env_btn),
        .a_idx (a_idx),
        .d_idx (d_idx),
        .s_idx (s_idx),
        .r_idx (r_idx),
        .sel   (sel_par),
        .valor (val_par)
    );

    assign led_sel = 4'b0001 << sel_par;      // si tus LEDs son activos en bajo: ~(4'b0001 << sel_par)

    // 3. Banco de 12 voces con mezcla y envolvente ADSR por voz
    wire signed [19:0] suma;
    wire [11:0] activas;

    banco_notas u_banco (
        .clk      (clk),
        .rst      (rst_h),
        .teclas   (gate),
        .sel_onda (sel_onda),
        .a_idx    (a_idx),
        .d_idx    (d_idx),
        .s_idx    (s_idx),
        .r_idx    (r_idx),
        .activas  (activas),
        .suma     (suma)
    );

    // 4. Etapa de salida: ganancia por onda, volumen, saturacion e I2S -> MAX98357A
    wire [2:0] volumen;

    encoder_volumen u_vol (
        .clk   (clk),
        .rst   (rst_h),
        .pin_a (vol_a),
        .pin_b (vol_b),
        .nivel (volumen)
    );

    salida_i2s u_audio (
        .clk       (clk),
        .rst       (rst_h),
        .suma      (suma),
        .activas   (activas),
        .sel_onda  (sel_onda),
        .volumen   (volumen),
        .i2s_bclk  (i2s_bclk),
        .i2s_lrclk (i2s_lrclk),
        .i2s_din   (i2s_din)
    );

    // 5. Displays: nota mas grave pulsada en el digito 0 (0-9, A = Fa# ... b = Si),
    //    volumen en el digito 1, parametro ADSR elegido en el digito 2, forma de onda en el digito 3
    reg [3:0] nota_baja;
    always @(*) begin
        casez (teclas)
            12'b????_????_???1: nota_baja = 4'd0;
            12'b????_????_??10: nota_baja = 4'd4;
            12'b????_????_?100: nota_baja = 4'd8;
            12'b????_????_1000: nota_baja = 4'd1;
            12'b????_???1_0000: nota_baja = 4'd5;
            12'b????_??10_0000: nota_baja = 4'd9;
            12'b????_?100_0000: nota_baja = 4'd2;
            12'b????_1000_0000: nota_baja = 4'd6;
            12'b???1_0000_0000: nota_baja = 4'd10;
            12'b??10_0000_0000: nota_baja = 4'd3;
            12'b?100_0000_0000: nota_baja = 4'd7;
            12'b1000_0000_0000: nota_baja = 4'd11;
            default:            nota_baja = 4'd0;
        endcase
    end
    wire hay_tecla = |teclas;

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
                digito_mostrar = nota_baja;
                seg = hay_tecla ? seg_decodificado : 7'b1111111;
            end
            2'b01: begin                       // digito 1: volumen 0-7
                dig = 4'b1101;
                digito_mostrar = {1'b0, volumen};
                seg = seg_decodificado;
            end
            2'b10: begin                       // digito 2: valor del parametro ADSR elegido (hex)
                dig = 4'b1011;
                digito_mostrar = val_par;
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

    // 6. VGA (dibuja la forma de onda seleccionada)
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
