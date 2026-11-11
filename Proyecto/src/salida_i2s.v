// Etapa de salida de audio:
//   ganancia automatica segun voces activas -> margen -> saturacion a 16 bits
//   -> eco -> volumen -> transmisor I2S (MAX98357A).
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
// 1. Ganancia por forma de onda: ahora se aplica POR VOZ dentro de banco_notas (la
//    sierra x1.5; cuadrada, triangular y seno x1), porque las capas del secuenciador
//    pueden sonar a la vez con ondas distintas. Es equivalente al esquema anterior
//    (triangular/seno x4 con reserva 4 == x1 con reserva 2).
//
// 2. Margen: 2 pasos de 6 dB (>>> 2) ANTES de saturar a 16 bits, para que ni una sola
//    nota ni un acorde recorten. Si quieres mas volumen, pon RESERVA = 1 (+6 dB, pero
//    empieza a recortar con acordes grandes); si oyes recorte, subelo.
//
// 3. Eco (a 24.4 kHz) y volumen maestro al final: 0 = silencio, 7 = maximo; cada
//    nivel menos baja 6 dB. El volumen NO cambia el recorte: eso lo decide RESERVA.
module salida_i2s #(
    parameter integer RESERVA = 2           // pasos de 6 dB de margen antes de saturar
)(
    input  wire               clk,
    input  wire               rst,
    input  wire signed [20:0] suma,       // mezcla de banco_notas (+ metronomo)
    input  wire [11:0]        activas,
    input  wire [2:0]         volumen,    
    // Parámetros del Eco
    input  wire [3:0]         eco_t,
    input  wire [3:0]         eco_fb,
    input  wire [3:0]         eco_mix,
    input  wire               eco_ena,    // SW2 del DIP para encender/apagar
    output wire signed [15:0] scope_x,    // mezcla seca (para el osciloscopio VGA)
    output wire               scope_tick, // 1 ciclo por muestra (48.8 kHz)
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

    wire signed [30:0] producto = suma * $signed({1'b0, mult});   // 21 b x 10 b con signo
    reg  signed [20:0] suma_n = 21'sd0;
    always @(posedge clk) suma_n <= producto >>> 8;

    // --- 1. Margen y saturación a 16 bits (señal seca) ---
    // El margen se resta aqui, antes de saturar: si se restara despues del
    // limite de 16 bits, la onda ya iria recortada.
    wire signed [20:0] con_reserva = suma_n >>> RESERVA;

    reg signed [15:0] x_seco = 16'sd0;
    always @(posedge clk) begin
        if (con_reserva > 21'sd32767)       x_seco <= 16'sh7FFF;
        else if (con_reserva < -21'sd32768) x_seco <= 16'sh8000;
        else                                x_seco <= con_reserva[15:0];
    end

    assign scope_x    = x_seco;
    assign scope_tick = tick_fs;

    // --- 2. Cadena de Efectos (Eco a 24.4 kHz) ---
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

    // --- 3. Volumen maestro y salida ---
    wire [2:0] desplaz = 3'd7 - volumen;                       // volumen 7 -> 0, 1 -> 6
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
