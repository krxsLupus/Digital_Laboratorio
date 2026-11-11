// Top: 12 pulsadores en matriz 4x3 con diodos (polifonico) + encoder KY-040
// + salida I2S (MAX98357A) + VGA + displays + ADSR por voz + pedal de sustain
// + eco + octavas con dos pulsadores.
module top_sintetizador (
    input  wire       clk,       // 50 MHz
    input  wire       rst,       // boton de reset, activo en bajo
    input  wire [2:0] cols_tec,  // columnas de la matriz (con pull-down externo de 10 kohm)
    output wire [3:0] rows_tec,  // filas de la matriz
    input  wire       pin_a,     // encoder CLK
    input  wire       pin_b,     // encoder DT
    input  wire       vol_a,     // encoder de volumen CLK
    input  wire       vol_b,     // encoder de volumen DT
    input  wire       env_a,     // encoder de parametros (ADSR + Eco) CLK
    input  wire       env_b,     // encoder de parametros (ADSR + Eco) DT
    input  wire       env_btn,   // pulsador: elige el parametro (A, D, S, R, T, FB, MIX)
    output wire [7:0] led_sel,   // LED del parametro elegido (D3..D10 de la placa, se enciende con 0)
    input  wire       oct_sube_n, // pulsador octava arriba (a GND al pulsar)
    input  wire       oct_baja_n, // pulsador octava abajo  (a GND al pulsar)
    output wire [3:0] led_oct,   // LED de la octava 3..6 (D11..D14 de la placa, se enciende con 0)
    input  wire       pedal,     // pedal de sustain: interruptor SW1 del DIP (ON = pedal abajo)
    input  wire       sw_eco,    // eco: interruptor SW2 del DIP (ON = eco encendido)
    input  wire       sw_seq_a_n, // secuenciador: interruptor A (a GND = cerrado)
    input  wire       sw_seq_b_n, // secuenciador: interruptor B (a GND = cerrado)
    output wire       led_seq_play,  // LED externo: loop corriendo (se enciende con 1)
    output wire       led_seq_rec,   // LED externo: grabando (parpadea = esperando el inicio)
    output wire       led_seq_clear, // LED externo: modo CLEAR
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
    wire [11:0] gate_vivo;

    pedal_sustain #(.ACTIVO_BAJO(1)) u_pedal (
        .clk    (clk),
        .rst    (rst_h),
        .pedal  (pedal),
        .teclas (teclas),
        .gate   (gate_vivo)
    );

    // 2b. Parametros ADSR y Eco: un encoder + un pulsador
    wire [3:0] a_idx, d_idx, s_idx, r_idx;
    wire [3:0] eco_t, eco_fb, eco_mix, rev_mix, bpm_idx;
    wire [3:0] val_par; // El valor a mostrar en el display
    wire [7:0] led_param;

    ctrl_param #(.ACTIVO_BAJO(1)) u_ctrl_param (
        .clk     (clk),
        .rst     (rst_h),
        .enc_a   (env_a),
        .enc_b   (env_b),
        .btn     (env_btn),
        .a_idx   (a_idx),
        .d_idx   (d_idx),
        .s_idx   (s_idx),
        .r_idx   (r_idx),
        .eco_t   (eco_t),
        .eco_fb  (eco_fb),
        .eco_mix (eco_mix),
        .bpm_idx (bpm_idx),
        .rev_mix (rev_mix),
        .led_sel (led_param),
        .valor   (val_par)
    );

    // Los LED de la placa se encienden con 0 (anodo a 3,3 V)
    assign led_sel = ~led_param;

    // 2c. Octava: dos pulsadores (arriba / abajo), 0 = Do3 ... 3 = Do6
    wire [1:0] oct;

    botones_octava #(.INICIAL(2'd1)) u_oct (
        .clk        (clk),
        .rst        (rst_h),
        .btn_sube_n (oct_sube_n),
        .btn_baja_n (oct_baja_n),
        .oct        (oct)
    );

    assign led_oct = ~(4'b0001 << oct);

    // 2d. Secuenciador: graba lo que tocas en capas (loop de 1, 2 o 4 compases).
    //     Cada capa guarda la onda, la octava y el ADSR que tenias al empezar a grabarla.
    wire [47:0] gate_capas;
    wire [7:0]  capa_onda, capa_oct;
    wire [15:0] capa_a, capa_d, capa_s, capa_r;
    wire signed [19:0] click;
    wire [3:0] paso_seq;
    wire [2:0] capas_seq;
    wire       seq_corre;

    secuenciador #(.CLK_FREQ(50_000_000)) u_seq (
        .clk        (clk),
        .rst        (rst_h),
        .sw_a_n     (sw_seq_a_n),
        .sw_b_n     (sw_seq_b_n),
        .teclas     (teclas),
        .bpm_idx    (bpm_idx),
        .p_onda     (sel_onda),
        .p_oct      (oct),
        .p_a        (a_idx),
        .p_d        (d_idx),
        .p_s        (s_idx),
        .p_r        (r_idx),
        .gate_capas (gate_capas),
        .capa_onda  (capa_onda),
        .capa_oct   (capa_oct),
        .capa_a     (capa_a),
        .capa_d     (capa_d),
        .capa_s     (capa_s),
        .capa_r     (capa_r),
        .click      (click),
        .paso       (paso_seq),
        .capas      (capas_seq),
        .corriendo  (seq_corre),
        .led_play   (led_seq_play),
        .led_rec    (led_seq_rec),
        .led_clear  (led_seq_clear)
    );

    // 2e. Cada nota toma sus parametros de la fuente que la pide (teclado o capa)
    wire [11:0] gate;
    wire [23:0] onda_v, oct_v;
    wire [47:0] a_v, d_v, s_v, r_v;

    fuentes_voz u_fuentes (
        .clk        (clk),
        .rst        (rst_h),
        .gate_vivo  (gate_vivo),
        .gate_capas (gate_capas),
        .v_onda     (sel_onda),
        .v_oct      (oct),
        .v_a        (a_idx),
        .v_d        (d_idx),
        .v_s        (s_idx),
        .v_r        (r_idx),
        .c_onda     (capa_onda),
        .c_oct      (capa_oct),
        .c_a        (capa_a),
        .c_d        (capa_d),
        .c_s        (capa_s),
        .c_r        (capa_r),
        .gate       (gate),
        .onda_v     (onda_v),
        .oct_v      (oct_v),
        .a_v        (a_v),
        .d_v        (d_v),
        .s_v        (s_v),
        .r_v        (r_v)
    );

    // --- PIPELINE REGISTERS FOR TIMING CLOSURE ---
    reg [11:0] gate_reg;
    reg [23:0] onda_v_reg, oct_v_reg;
    reg [47:0] a_v_reg, d_v_reg, s_v_reg, r_v_reg;

    always @(posedge clk) begin
        if (rst_h) begin
            gate_reg   <= 12'd0;
            onda_v_reg <= 24'd0;
            oct_v_reg  <= 24'd0;
            a_v_reg    <= 48'd0;
            d_v_reg    <= 48'd0;
            s_v_reg    <= 48'd0;
            r_v_reg    <= 48'd0;
        end else begin
            gate_reg   <= gate;
            onda_v_reg <= onda_v;
            oct_v_reg  <= oct_v;
            a_v_reg    <= a_v;
            d_v_reg    <= d_v;
            s_v_reg    <= s_v;
            r_v_reg    <= r_v;
        end
    end

    // 3. Banco de 12 voces con mezcla, octava y envolvente ADSR por voz
    wire signed [20:0] suma;
    wire [11:0] activas;

    banco_notas u_banco (
        .clk      (clk),
        .rst      (rst_h),
        .teclas   (gate_reg),      // Modificado para usar registro
        .onda_v   (onda_v_reg),    // Modificado para usar registro
        .oct_v    (oct_v_reg),     // Modificado para usar registro
        .a_v      (a_v_reg),       // Modificado para usar registro
        .d_v      (d_v_reg),       // Modificado para usar registro
        .s_v      (s_v_reg),       // Modificado para usar registro
        .r_v      (r_v_reg),       // Modificado para usar registro
        .activas  (activas),
        .suma     (suma)
    );

    // 4. Etapa de salida: ganancia, ADSR, eco a 24k, volumen, saturacion e I2S
    wire [2:0] volumen;

    encoder_volumen u_vol (
        .clk   (clk),
        .rst   (rst_h),
        .pin_a (vol_a),
        .pin_b (vol_b),
        .nivel (volumen)
    );

    // Sincronizador simple para el switch del Eco (evita metaestabilidad)
    reg sw_eco_s1 = 1'b1, sw_eco_s2 = 1'b1;
    always @(posedge clk) begin
        sw_eco_s1 <= sw_eco;
        sw_eco_s2 <= sw_eco_s1;
    end

    // Instancia actualizada con los puertos de Efectos
    // Mezcla + metronomo (12 sierras maximo = +-589824, el clic suma 10240: cabe en 21 bits)
    wire signed [20:0] suma_mix = suma + click;

    wire signed [15:0] scope_x;      // mezcla seca hacia el osciloscopio VGA
    wire               scope_tick;   // 1 ciclo por muestra (48.8 kHz)

    salida_i2s u_audio (
        .clk       (clk),
        .rst       (rst_h),
        .suma      (suma_mix),
        .activas   (activas),
        .volumen   (volumen),
        .eco_t     (eco_t),
        .eco_fb    (eco_fb),
        .eco_mix   (eco_mix),
        .eco_ena   (~sw_eco_s2), // DIP en ON (0) = eco encendido
        .scope_x   (scope_x),
        .scope_tick(scope_tick),
        .i2s_bclk  (i2s_bclk),
        .i2s_lrclk (i2s_lrclk),
        .i2s_din   (i2s_din)
    );

    // 5. Displays: nota mas grave pulsada en el digito 0 (0-9, A = La#, b = Si),
    //    volumen en el digito 1, valor de parametro activo en digito 2, onda en digito 3.
    //    La octava se ve en los LED D11..D14.
    //    Digito 0 sin teclas y con el secuenciador en PLAY/REC: numero de paso (0-F).
    //    teclas[n] va en el orden fisico del teclado; 'cromatica' lo reordena por
    //    altura de la nota (bit 0 = Do, 1 = Do#, 2 = Re, ... 11 = Si) para
    //    encontrar la mas grave.
    wire [11:0] cromatica = {teclas[11], teclas[8], teclas[5], teclas[2],     // Si, La#, La, Sol#
                             teclas[10], teclas[7], teclas[4], teclas[1],     // Sol, Fa#, Fa, Mi
                             teclas[9],  teclas[6], teclas[3], teclas[0]};    // Re#, Re, Do#, Do
    reg [3:0] nota_baja;
    always @(*) begin
        casez (cromatica)
            12'b????_????_???1: nota_baja = 4'd0;
            12'b????_????_??10: nota_baja = 4'd1;
            12'b????_????_?100: nota_baja = 4'd2;
            12'b????_????_1000: nota_baja = 4'd3;
            12'b????_???1_0000: nota_baja = 4'd4;
            12'b????_??10_0000: nota_baja = 4'd5;
            12'b????_?100_0000: nota_baja = 4'd6;
            12'b????_1000_0000: nota_baja = 4'd7;
            12'b???1_0000_0000: nota_baja = 4'd8;
            12'b??10_0000_0000: nota_baja = 4'd9;
            12'b?100_0000_0000: nota_baja = 4'd10;
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
                // Con teclas pulsadas: la nota mas grave. Sin teclas y con el loop
                // corriendo: el paso (0-F). Parado: apagado.
                digito_mostrar = hay_tecla ? nota_baja : paso_seq;
                seg = (hay_tecla || seq_corre) ? seg_decodificado : 7'b1111111;
            end
            2'b01: begin                       // digito 1: volumen 0-7
                dig = 4'b1101;
                digito_mostrar = {1'b0, volumen};
                seg = seg_decodificado;
            end
            2'b10: begin                       // digito 2: valor del parametro elegido (hex)
                dig = 4'b1011;
                digito_mostrar = val_par;      // Viene de ctrl_param
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

    // 6. VGA (osciloscopio de la mezcla real + parametros)
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
        .clk       (clk),
        .rst       (rst_h),
        .x         (p_x),
        .y         (p_y),
        .video_on  (video_on),
        .en_48k    (scope_tick),
        .muestra   (scope_x),
        .a_idx     (a_idx),
        .d_idx     (d_idx),
        .s_idx     (s_idx),
        .r_idx     (r_idx),
        .eco_t     (eco_t),
        .eco_fb    (eco_fb),
        .eco_mix   (eco_mix),
        .bpm_idx   (bpm_idx),
        .led_param (led_param),
        .rgb       (rgb)
    );

    assign vga_r = rgb[2];
    assign vga_g = rgb[1];
    assign vga_b = rgb[0];

endmodule