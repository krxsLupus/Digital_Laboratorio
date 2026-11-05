// Etapa de salida de audio:
//   ganancia automatica segun teclas pulsadas -> ganancia por forma de onda
//   -> volumen -> saturacion a 16 bits -> transmisor I2S (MAX98357A).
//
// 0. Ganancia automatica: cuantas mas voces suenan a la vez, mas grande es la
//    suma y antes recorta. Se multiplica la suma por 1/raiz(n), con n = voces
//    activas (teclas pulsadas + colas de release del ADSR). La ganancia no salta:
//    se desliza hacia su valor objetivo 1 paso por muestra de audio, para que
//    al entrar o salir una voz no haya un escalon de nivel en las demas.
//    Con n = 1 la ganancia es exactamente 1, asi que una sola nota
//    suena igual que antes. Con acordes el nivel total se mantiene parecido
//    (n voces independientes suman ~ raiz(n) en nivel) y el pico queda unas
//    1.5 veces el de una sola nota en vez de n veces.
//        n:      1    2    3    4    5    6    7    8    9   10   11   12
//        x256: 256  181  148  128  114  105   97   91   85   81   77   74
//
// 1. Ganancia por forma de onda: con la misma amplitud pico, la sierra y la
//    triangular tienen menos potencia que la cuadrada y un parlante pequeno las
//    reproduce peor. Se compensa asi (ajustalas de oido):
//        cuadrada x1 | sierra x1.5 | triangular x4 | seno x4
//
// 2. Volumen (entrada 'volumen', del encoder_volumen): pasos de 6 dB.
//        0 = silencio, 7 = maximo SIN RECORTE de la onda elegida (el tope se
//        ajusta por onda con 'reserva'); cada nivel menos baja 6 dB.
module salida_i2s (
    input  wire               clk,
    input  wire               rst,
    input  wire signed [19:0] suma,       
    input  wire [11:0]        activas,    
    input  wire [1:0]         sel_onda,   
    input  wire [2:0]         volumen,    
    // Parámetros del Eco
    input  wire [3:0]         eco_t,
    input  wire [3:0]         eco_fb,
    input  wire [3:0]         eco_mix,
    input  wire               eco_ena,    // SW2 del DIP para encender/apagar
    output wire               i2s_bclk,
    output wire               i2s_lrclk,
    output wire               i2s_din
);

    // --- 0. Ganancia automática con Slew-Rate Asimétrico (Bugfix) ---
    reg [3:0] n_teclas;
    integer   j;
    always @(*) begin
        n_teclas = 4'd0;
        for (j = 0; j < 12; j = j + 1) n_teclas = n_teclas + activas[j];
    end

    reg [8:0] mult_obj;
    always @(*) begin
        case (n_teclas)
            4'd0, 4'd1: mult_obj = 9'd256;
            4'd2:       mult_obj = 9'd181;
            4'd3:       mult_obj = 9'd148;
            4'd4:       mult_obj = 9'd128;
            4'd5:       mult_obj = 9'd114;
            4'd6:       mult_obj = 9'd105;
            4'd7:       mult_obj = 9'd97;
            4'd8:       mult_obj = 9'd91;
            4'd9:       mult_obj = 9'd85;
            4'd10:      mult_obj = 9'd81;
            4'd11:      mult_obj = 9'd77;
            default:    mult_obj = 9'd74;
        endcase
    end

    reg [9:0] fs_cnt = 10'd0;
    always @(posedge clk) fs_cnt <= fs_cnt + 1'b1;
    wire tick_fs = (fs_cnt == 10'd1023); // Pulso a 48.8 kHz

    reg [8:0] mult = 9'd256;
    always @(posedge clk) begin
        if (rst) mult <= 9'd256;
        else if (tick_fs) begin
            if (mult < mult_obj)      
                mult <= mult + 1'b1; // Sube lento para evitar pops en el release
            else if (mult > mult_obj) begin
                // Baja rápido (ataque) para acomodar acordes instantáneamente
                if (mult - mult_obj > 9'd8) mult <= mult - 4'd8; 
                else                        mult <= mult_obj;
            end
        end
    end

    wire signed [29:0] producto = suma * $signed({1'b0, mult});
    reg  signed [19:0] suma_n = 20'sd0;
    always @(posedge clk) suma_n <= producto >>> 8;

    // --- 1. Ganancia por forma de onda ---
    wire signed [25:0] s        = suma_n;
    wire signed [25:0] x_sierra = s + (s >>> 1);
    wire signed [25:0] x_tri    = s <<< 2;
    wire signed [25:0] x_seno   = s <<< 2;

    reg signed [25:0] ganada = 26'sd0;
    always @(posedge clk) begin
        case (sel_onda)
            2'd0:    ganada <= s;
            2'd1:    ganada <= x_sierra;
            2'd2:    ganada <= x_tri;
            default: ganada <= x_seno;
        endcase
    end

    // --- 2. Saturación temprana a 16 bits (Señal Seca) ---
    reg signed [15:0] x_seco = 16'sd0;
    always @(posedge clk) begin
        if (ganada > 26'sd32767)       x_seco <= 16'sh7FFF;
        else if (ganada < -26'sd32768) x_seco <= 16'sh8000;
        else                           x_seco <= ganada[15:0];
    end

    // --- 3. Cadena de Efectos (Eco a 24.4 kHz) ---
    wire signed [15:0] y_mix;
    wire [3:0] mix_efectivo = eco_ena ? eco_mix : 4'd0; // Bypass por hardware

    efectos_audio u_efectos (
        .clk     (clk),
        .rst     (rst),
        .en_48k  (tick_fs),
        .x       (x_seco),
        .eco_t   (eco_t),
        .eco_fb  (eco_fb),
        .eco_mix (mix_efectivo),
        .y       (y_mix)
    );

    // --- 4. Volumen Maestro y Salida ---
    reg [2:0] reserva;
    always @(*) begin
        case (sel_onda)
            2'd0, 2'd1: reserva = 3'd2;
            default:    reserva = 3'd4;
        endcase
    end

    wire [3:0] desplaz = {1'b0, 3'd7 - volumen} + {1'b0, reserva};
    wire signed [15:0] atenuada = (volumen == 3'd0) ? 16'sd0 : (y_mix >>> desplaz);

    i2s_tx u_i2s (
        .clk    (clk),
        .rst    (rst),
        .sample (atenuada),
        .bclk   (i2s_bclk),
        .lrclk  (i2s_lrclk),
        .sdata  (i2s_din)
    );
endmodule
