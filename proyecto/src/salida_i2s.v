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
    input  wire               clk,        // 50 MHz
    input  wire               rst,        // activo en alto
    input  wire signed [19:0] suma,       // mezcla de banco_notas (0 = silencio)
    input  wire [11:0]        activas,    // voces sonando (para contar cuantas son)
    input  wire [1:0]         sel_onda,   // 0 cuadrada, 1 sierra, 2 triangular, 3 seno
    input  wire [2:0]         volumen,    // 0 = silencio ... 7 = maximo
    output wire               i2s_bclk,
    output wire               i2s_lrclk,
    output wire               i2s_din
);

    // --- 0. Ganancia automatica por numero de teclas ---
    reg [3:0] n_teclas;
    integer   j;
    always @(*) begin
        n_teclas = 4'd0;
        for (j = 0; j < 12; j = j + 1)
            n_teclas = n_teclas + activas[j];
    end

    reg [8:0] mult_obj;                   // ganancia objetivo: 256 / raiz(n), en 1/256
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
            default:    mult_obj = 9'd74;     // 12
        endcase
    end

    // Deslizamiento: 1/256 por muestra de audio (256 -> 74 en ~3.7 ms)
    reg [9:0] fs_cnt = 10'd0;
    always @(posedge clk) fs_cnt <= fs_cnt + 1'b1;
    wire tick_fs = (fs_cnt == 10'd1023);

    reg [8:0] mult = 9'd256;
    always @(posedge clk) begin
        if (rst)
            mult <= 9'd256;
        else if (tick_fs) begin
            if (mult < mult_obj)      
                mult <= mult + 1'b1;          // Sube lento (evita pops en colas de release)
            else if (mult > mult_obj) begin
                // Baja MUY rápido (pasos de a 8) para hacerle espacio inmediato a los nuevos acordes
                if (mult - mult_obj > 9'd8) mult <= mult - 4'd8; 
                else                        mult <= mult_obj;
            end
        end
    end

    wire signed [29:0] producto = suma * $signed({1'b0, mult});   // 20 b x 10 b con signo
    reg  signed [19:0] suma_n = 20'sd0;                           // suma normalizada
    always @(posedge clk)
        suma_n <= producto >>> 8;

    // --- 1. Ganancia por forma de onda ---
    // 26 bits: 12 voces (+-393216) x4 cabe de sobra.
    wire signed [25:0] s        = suma_n;                       // extension de signo
    wire signed [25:0] x_sierra = s + (s >>> 1);                // x1.5
    wire signed [25:0] x_tri    = s <<< 2;                      // x4
    wire signed [25:0] x_seno   = s <<< 2;                      // x4

    reg signed [25:0] ganada = 26'sd0;
    always @(posedge clk) begin
        case (sel_onda)
            2'd0:    ganada <= s;
            2'd1:    ganada <= x_sierra;
            2'd2:    ganada <= x_tri;
            default: ganada <= x_seno;
        endcase
    end

    // --- 2. Volumen y saturacion a 16 bits ---
    // Tope de volumen por onda: el nivel 7 del encoder corresponde al nivel mas
    // alto que todavia no recorta con acordes (medido con 300 acordes aleatorios
    // por cada n). 'reserva' son los pasos de 6 dB que se restan a todos los niveles:
    //     cuadrada 2 | sierra 2 | triangular 4 | seno 4
    // Si quieres mas volumen, baja el numero de la onda (cada 1 = +6 dB, pero
    // empieza a recortar con acordes grandes); si oyes recorte, subelo.
    // Con suma = 0 (sin teclas) se envia 0 exacto: una muestra constante distinta
    // de 0 pondria un nivel DC en el parlante.
    reg [2:0] reserva;
    always @(*) begin
        case (sel_onda)
            2'd0:    reserva = 3'd2;      // cuadrada
            2'd1:    reserva = 3'd2;      // sierra
            2'd2:    reserva = 3'd4;      // triangular
            default: reserva = 3'd4;      // seno
        endcase
    end

    wire [3:0] desplaz = {1'b0, 3'd7 - volumen} + {1'b0, reserva};   // 0..10
    wire signed [25:0] atenuada = (volumen == 3'd0) ? 26'sd0 : (ganada >>> desplaz);

    reg signed [15:0] muestra = 16'sd0;
    always @(posedge clk) begin
        if (rst)
            muestra <= 16'sd0;
        else if (atenuada > 26'sd32767)
            muestra <= 16'sh7FFF;
        else if (atenuada < -26'sd32768)
            muestra <= 16'sh8000;
        else
            muestra <= atenuada[15:0];
    end

    // --- 3. Transmisor I2S (la misma muestra en izquierda y derecha) ---
    i2s_tx u_i2s (
        .clk    (clk),
        .rst    (rst),
        .sample (muestra),
        .bclk   (i2s_bclk),
        .lrclk  (i2s_lrclk),
        .sdata  (i2s_din)
    );

endmodule
