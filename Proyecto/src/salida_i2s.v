// Etapa de salida del audio.
// La senal pasa por ganancia automatica segun las voces activas, margen, saturacion a 16 bits,
// eco, volumen y al final el transmisor I2S que habla con el MAX98357A.
//
// 0. Ganancia automatica
//    Mientras mas voces suenan a la vez mas grande es la suma y antes recorta.
//    Por eso se multiplica la suma por 1 entre raiz de n, donde n son las voces activas,
//    contando teclas pulsadas y colas de release de la ADSR.
//    La ganancia no salta de golpe, se desliza hacia su valor objetivo para que al entrar o salir una voz
//    las demas no sufran un escalon de volumen.
//    Con n igual a 1 la ganancia es exactamente 1, asi que una sola nota suena igual que sin esto.
//    Con acordes el nivel total se mantiene parecido, porque n voces independientes suman mas o menos raiz de n en nivel,
//    y el pico queda en unas 1.5 veces el de una nota sola en vez de n veces.
//        n       1    2    3    4    5    6    7    8    9   10   11   12
//        x256  256  181  148  128  114  105   97   91   85   81   77   74
//
// 1. Ganancia por forma de onda
//    Ya no se hace aqui, se aplica por voz dentro de banco_notas con cuadrada por 0.5, sierra por 0.625,
//    triangular por 1.5 y seno por 2. Se hace ahi porque las capas del secuenciador pueden sonar
//    a la vez con ondas distintas.
//
// 2. Margen
//    Se bajan 2 pasos de 6 dB (desplazar 2 bits) antes de saturar a 16 bits, para que ni una nota sola ni un acorde recorten.
//    Si quieres mas volumen pon RESERVA en 1, que sube 6 dB pero empieza a recortar con acordes grandes.
//    Si escuchas recorte, subelo.
//
// 3. Eco y volumen maestro al final
//    El eco trabaja a 24.4 kHz. En el volumen 0 es silencio y 7 es el maximo, cada nivel menos baja 6 dB.
//    El volumen no cambia el recorte, eso lo decide RESERVA.
module salida_i2s #(
    parameter integer RESERVA = 2           // pasos de 6 dB de margen antes de saturar
)(
    input  wire               clk,
    input  wire               rst,
    input  wire signed [20:0] suma,       // mezcla de banco_notas mas el metronomo
    input  wire [11:0]        activas,
    input  wire signed [19:0] bat,        // bateria, se suma despues de la ganancia automatica
    input  wire [2:0]         volumen,
    // Parametros del eco
    input  wire [3:0]         eco_t,
    input  wire [3:0]         eco_fb,
    input  wire [3:0]         eco_mix,
    input  wire               eco_ena,    // el SW2 del DIP prende y apaga el eco
    output wire signed [15:0] scope_x,    // mezcla seca, va al osciloscopio VGA
    output wire               scope_tick, // un ciclo por muestra, a 48.8 kHz
    output wire               i2s_bclk,
    output wire               i2s_lrclk,
    output wire               i2s_din
);

    // Paso 0, ganancia automatica
    // Baja rapido y sube lento, un slew rate asimetrico que arregla un bug de pops
    // Primero se cuentan las voces activas
    reg [3:0] n_teclas;
    integer   j;
    always @(*) begin
        n_teclas = 4'd0;
        for (j = 0; j < 12; j = j + 1) n_teclas = n_teclas + activas[j];
    end

    // Tabla con el multiplicador objetivo segun cuantas voces hay, sobre 256
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
    wire tick_fs = (fs_cnt == 10'd1023); // un pulso por muestra, a 48.8 kHz

    // La ganancia real va persiguiendo al objetivo una vez por muestra
    reg [8:0] mult = 9'd256;
    always @(posedge clk) begin
        if (rst) mult <= 9'd256;
        else if (tick_fs) begin
            if (mult < mult_obj)
                mult <= mult + 1'b1; // sube lento para que no haya pops al soltar notas
            else if (mult > mult_obj) begin
                // baja rapido para acomodar un acorde de golpe
                if (mult - mult_obj > 9'd8) mult <= mult - 4'd8;
                else                        mult <= mult_obj;
            end
        end
    end

    wire signed [30:0] producto = suma * $signed({1'b0, mult});   // 21 bits por 10 bits con signo
    reg  signed [20:0] suma_n = 21'sd0;
    always @(posedge clk) suma_n <= producto >>> 8;

    // Paso 1, margen y saturacion a 16 bits de la senal seca
    // El margen se quita aqui, antes de saturar, porque si se hiciera despues del limite de 16 bits
    // la onda ya estaria recortada
    wire signed [20:0] suma_t      = suma_n + {bat[19], bat};
    wire signed [20:0] con_reserva = suma_t >>> RESERVA;

    reg signed [15:0] x_seco = 16'sd0;
    always @(posedge clk) begin
        if (con_reserva > 21'sd32767)       x_seco <= 16'sh7FFF;
        else if (con_reserva < -21'sd32768) x_seco <= 16'sh8000;
        else                                x_seco <= con_reserva[15:0];
    end

    assign scope_x    = x_seco;
    assign scope_tick = tick_fs;

    // Paso 2, cadena de efectos con el eco a 24.4 kHz
    wire signed [15:0] y_mix;
    wire [3:0] mix_efectivo = eco_ena ? eco_mix : 4'd0; // el bypass solo pone la mezcla en 0, la memoria del eco sigue corriendo

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

    // Paso 3, volumen maestro y salida
    wire [2:0] desplaz = 3'd7 - volumen;                       // con volumen 7 no se desplaza nada y con 1 se desplaza 6
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
