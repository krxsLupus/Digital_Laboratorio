// Banco de 12 voces, una por nota, y todas pueden sonar a la vez.
//
// Esta version esta pensada para gastar poca area y tiene los mismos puertos que la anterior.
// Los 12 acumuladores de fase siguen en paralelo porque corren a 50 MHz.
// La envolvente ADSR es serial, un solo circuito recorre las 12 voces una por ciclo
// justo despues de cada tick, o sea una vez por muestra de audio (1024 ciclos).
// El estado de cada voz (st y lvl) vive en registros propios.
// Asi solo hacen falta 3 lut_tiempos en vez de 36 y un solo juego de sumadores y comparadores.
// El generador de onda tambien es uno solo, como la mezcla ya visita una voz por ciclo se comparte sin problema.
// Los incrementos de fase por nota son constantes, ya no hay 12 ROM de lut_frecuencias.
// La mezcla va en cuatro pasos, seleccion de la voz, forma de onda, multiplicador DSP y acumulacion.
module banco_notas (
    input  wire               clk,         // 50 MHz
    input  wire               rst,         // activo en alto
    input  wire [11:0]        teclas,      // bit n en 1 es nota n pulsada, es el gate de la envolvente
    input  wire [23:0]        onda_v,      // 2 bits por voz, 0 cuadrada, 1 sierra, 2 triangular, 3 seno
    input  wire [23:0]        oct_v,       // 2 bits por voz, 0 es Do3, 1 es Do4, 2 es Do5, 3 es Do6
    input  wire [47:0]        a_v,         // 4 bits por voz, ataque
    input  wire [47:0]        d_v,         // decay
    input  wire [47:0]        s_v,         // sustain
    input  wire [47:0]        r_v,         // release
    output wire [11:0]        activas,     // bit n en 1 es voz n sonando, ya sea tecla o cola de release
    output reg  signed [20:0] suma = 21'sd0 // mezcla de las voces, cada una multiplicada por 256, 0 es silencio
);

    // Reloj de la envolvente
    // Esto cuenta 1024 ciclos y da un tick por muestra de audio, 50 MHz entre 1024 son 48.8 kHz
    reg [9:0] fs_cnt = 10'd0;
    always @(posedge clk) fs_cnt <= fs_cnt + 1'b1;
    wire tick = (fs_cnt == 10'd1023);

    // Registro a la entrada para acortar el camino critico que viene de afuera
    reg [11:0] teclas_reg = 12'd0;
    always @(posedge clk) begin
        if (rst) teclas_reg <= 12'd0;
        else     teclas_reg <= teclas;
    end

    // Incremento de fase de cada nota
    // La frecuencia sale de inc por 50 MHz entre 2 elevado a 32, por eso 22473 da un Do4 de 261 Hz
    // Los indices no van en orden cromatico, siguen como estan cableadas las teclas
    // Son los mismos valores que tenia lut_frecuencias en el mismo orden
    function [31:0] f_inc;
        input integer n;
        begin
            case (n)
                0:  f_inc = 32'd22473;
                1:  f_inc = 32'd28314;
                2:  f_inc = 32'd35673;
                3:  f_inc = 32'd23809;
                4:  f_inc = 32'd29998;
                5:  f_inc = 32'd37795;
                6:  f_inc = 32'd25225;
                7:  f_inc = 32'd31782;
                8:  f_inc = 32'd40042;
                9:  f_inc = 32'd26725;
                10: f_inc = 32'd33672;
                11: f_inc = 32'd42423;
                default: f_inc = 32'd22473;
            endcase
        end
    endfunction

    localparam [2:0]  S_IDLE = 3'd0, S_ATK = 3'd1, S_DEC = 3'd2, S_SUS = 3'd3, S_REL = 3'd4;
    localparam [23:0] MAXL   = 24'd8388608;                 // el nivel 1.0 es 2 a la 23

    // Estado de cada voz, su fase, en que etapa de la ADSR va y su nivel
    wire [383:0] fase_v;      // 12 por 32 bits
    wire [35:0]  st_v;        // 12 por 3 bits
    wire [287:0] lvl_v;       // 12 por 24 bits
    wire [11:0]  idle_v;

    // Estas senales las escribe el circuito serial de la envolvente que esta mas abajo
    reg         s2_v = 1'b0;          // hay un resultado listo para guardar
    reg  [3:0]  s2_i = 4'd0;          // a que voz le toca
    reg  [2:0]  n_st;                 // siguiente estado, sale de logica combinacional
    reg  [23:0] n_lvl;                // siguiente nivel, tambien combinacional

    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : voz
            localparam [31:0] INC0 = f_inc(i);

            // Cada voz guarda su estado y su nivel, solo se actualizan cuando el circuito serial llega a ella
            reg [2:0]  st_r  = S_IDLE;
            reg [23:0] lvl_r = 24'd0;
            always @(posedge clk) begin
                if (rst) begin
                    st_r  <= S_IDLE;
                    lvl_r <= 24'd0;
                end else if (s2_v && (s2_i == i)) begin
                    st_r  <= n_st;
                    lvl_r <= n_lvl;
                end
            end
            assign st_v [3*i  +: 3 ] = st_r;
            assign lvl_v[24*i +: 24] = lvl_r;
            assign idle_v[i]         = (st_r == S_IDLE);

            // Cambio de octava
            // Como INC0 es constante cada rama es un desplazamiento fijo y no cuesta casi nada
            wire [1:0]  v_oct = oct_v[2*i +: 2];
            wire [31:0] inc   = (v_oct == 2'd0) ? (INC0 >> 1) :
                                (v_oct == 2'd1) ?  INC0       :
                                (v_oct == 2'd2) ? (INC0 << 1) :
                                                  (INC0 << 2);

            // La fase se queda en 0 mientras la voz esta apagada
            // Asi cada nota siempre arranca desde el mismo punto de la onda
            acumulador_fase u_acc (
                .clk        (clk),
                .rst        (rst | idle_v[i]),
                .incremento (inc),
                .fase       (fase_v[32*i +: 32])
            );
        end
    endgenerate

    assign activas = ~idle_v;

    // Envolvente serial
    // Despues de cada tick se procesan las voces de la 0 a la 11, una por ciclo, en tres pasos
    // El primero es el contador de voz seq_i
    // El segundo lee estado, nivel, gate y parametros de la voz que toca
    // El tercero deja registrada la salida de las lut_tiempos
    // Al final se calcula el siguiente st y lvl y se guardan en la voz s2_i
    reg        seq_act = 1'b0;
    reg  [3:0] seq_i   = 4'd0;

    // Cuando llega el tick arranca la pasada y seq_i recorre las 12 voces
    always @(posedge clk) begin
        if (rst) begin
            seq_act <= 1'b0;
            seq_i   <= 4'd0;
        end else if (tick) begin
            seq_act <= 1'b1;
            seq_i   <= 4'd0;
        end else if (seq_act) begin
            if (seq_i == 4'd11) seq_act <= 1'b0;
            else                seq_i   <= seq_i + 4'd1;
        end
    end

    // Primer paso, se lee la voz seleccionada
    reg        s1_v = 1'b0;
    reg  [3:0] s1_i = 4'd0;
    reg  [2:0]  q1_st   = 3'd0;
    reg  [23:0] q1_lvl  = 24'd0;
    reg         q1_gate = 1'b0;
    reg  [3:0]  q1_a = 4'd0, q1_d = 4'd0, q1_s = 4'd0, q1_r = 4'd2;

    always @(posedge clk) begin
        s1_v    <= seq_act && !rst;
        s1_i    <= seq_i;
        q1_st   <= st_v   [seq_i*3  +: 3 ];
        q1_lvl  <= lvl_v  [seq_i*24 +: 24];
        q1_gate <= teclas_reg[seq_i];
        q1_a    <= a_v    [seq_i*4  +: 4 ];
        q1_d    <= d_v    [seq_i*4  +: 4 ];
        q1_s    <= s_v    [seq_i*4  +: 4 ];
        q1_r    <= (r_v[seq_i*4 +: 4] < 4'd2) ? 4'd2 : r_v[seq_i*4 +: 4];   // release minimo de 5 ms para que no suene un click al soltar
    end

    // Tablas de tiempo, una sola copia de cada una y las comparten las 12 voces
    wire [23:0] inc_a_w, inc_d_w, inc_r_w;
    lut_tiempos u_la (.idx(q1_a), .inc(inc_a_w));
    lut_tiempos u_ld (.idx(q1_d), .inc(inc_d_w));
    lut_tiempos u_lr (.idx(q1_r), .inc(inc_r_w));

    // Segundo paso, aqui se registra lo que salio de las tablas
    reg  [2:0]  q2_st   = 3'd0;
    reg  [23:0] q2_lvl  = 24'd0;
    reg         q2_gate = 1'b0;
    reg  [23:0] q2_inc_a = 24'd0, q2_inc_d = 24'd0, q2_inc_r = 24'd0, q2_sus = 24'd0;

    always @(posedge clk) begin
        s2_v     <= s1_v && !rst;
        s2_i     <= s1_i;
        q2_st    <= q1_st;
        q2_lvl   <= q1_lvl;
        q2_gate  <= q1_gate;
        q2_inc_a <= inc_a_w;
        q2_inc_d <= inc_d_w;
        q2_inc_r <= inc_r_w;
        q2_sus   <= (q1_s == 4'd15) ? 24'd8388608 : {1'b0, q1_s, 19'd0};   // el sustain es S entre 16 de 2 a la 23, y el 15 se toma como 1.0
    end

    // Calculo del siguiente estado, es la misma logica que tiene envelope_adsr.v
    // Las sumas llevan un bit de mas para detectar cuando se pasa del limite
    wire [24:0] lvl_up_a = {1'b0, q2_lvl} + {1'b0, q2_inc_a};
    wire [24:0] dec_tgt  = {1'b0, q2_sus} + {1'b0, q2_inc_d};   // si el nivel es menor o igual a esto el proximo paso ya llega al sustain
    wire [24:0] sus_up   = {1'b0, q2_lvl} + {1'b0, q2_inc_d};
    wire [23:0] lvl_dn_d = q2_lvl - q2_inc_d;
    wire [23:0] lvl_dn_r = q2_lvl - q2_inc_r;
    wire [23:0] dif_dn   = q2_lvl - q2_sus;
    wire [23:0] dif_up   = q2_sus - q2_lvl;

    always @(*) begin
        n_st  = q2_st;
        n_lvl = q2_lvl;
        case (q2_st)
            // Apagada, el nivel se queda en 0 hasta que llegue una tecla
            S_IDLE: begin
                n_lvl = 24'd0;
                if (q2_gate) n_st = S_ATK;
            end

            // Ataque, sube hasta 1.0 y despues pasa al decay
            S_ATK: begin
                if (!q2_gate) n_st = S_REL;
                else if (lvl_up_a >= {1'b0, MAXL}) begin
                    n_lvl = MAXL;
                    n_st  = S_DEC;
                end else
                    n_lvl = lvl_up_a[23:0];
            end

            // Decay, baja hasta el nivel de sustain
            S_DEC: begin
                if (!q2_gate) n_st = S_REL;
                else if ({1'b0, q2_lvl} <= dec_tgt) begin
                    n_lvl = q2_sus;
                    n_st  = S_SUS;
                end else
                    n_lvl = lvl_dn_d;
            end

            // Sustain, se queda en su nivel mientras sigas pulsando
            S_SUS: begin
                if (!q2_gate) n_st = S_REL;
                else if (q2_lvl > q2_sus)                       // si bajaste S el nivel baja suave
                    n_lvl = (dif_dn <= q2_inc_d) ? q2_sus : lvl_dn_d;
                else if (q2_lvl < q2_sus)                       // si subiste S el nivel sube suave
                    n_lvl = (dif_up <= q2_inc_d) ? q2_sus : sus_up[23:0];
            end

            // Release, baja hasta 0 y la voz queda apagada
            // Si vuelves a pulsar en mitad del release arranca el ataque desde el nivel actual
            S_REL: begin
                if (q2_gate) n_st = S_ATK;
                else if (q2_lvl <= q2_inc_r) begin
                    n_lvl = 24'd0;
                    n_st  = S_IDLE;
                end else
                    n_lvl = lvl_dn_r;
            end

            default: n_st = S_IDLE;
        endcase
    end

    // Mezcla secuencial
    // k cuenta de 0 a 15 y las voces de la 0 a la 11 se seleccionan cuando k vale lo mismo que su numero
    // Cada voz pasa por cuatro etapas
    // La A selecciona fase, envolvente, tipo de onda e idle
    // La B genera la forma de onda con un solo generador y da una muestra con signo
    // La C multiplica onda por envolvente con el DSP y aplica la ganancia de cada onda
    // La D acumula y en la ultima voz carga suma
    reg  [3:0] k = 4'd0;
    always @(posedge clk) begin
        if (rst) k <= 4'd0;
        else     k <= k + 4'd1;
    end

    wire [3:0] ki = (k > 4'd11) ? 4'd0 : k;

    // Etapa A
    reg        a_val = 1'b0, a_first = 1'b0, a_last = 1'b0;
    reg  [8:0] a_ph  = 9'd0;
    reg  [8:0] a_e   = 9'd0;
    reg  [1:0] a_w   = 2'd0;
    reg        a_idle = 1'b1;

    always @(posedge clk) begin
        a_val   <= (k <= 4'd11) && !rst;
        a_first <= (k == 4'd0);
        a_last  <= (k == 4'd11);
        a_ph    <= fase_v[ki*32 + 23 +: 9];       // del generador solo se usan los bits 31 a 23 de la fase
        a_e     <= lvl_v [ki*24 + 15 +: 9];       // la envolvente son los bits 23 a 15 del nivel, va de 0 a 256
        a_w     <= onda_v[ki*2 +: 2];
        a_idle  <= idle_v[ki];
    end

    // Etapa B, un unico generador de onda para todas las voces
    wire [7:0] onda_w;
    generador_onda u_gen (
        .fase     ({a_ph, 23'd0}),
        .sel_onda (a_w),
        .onda_out (onda_w)
    );

    reg               b_val = 1'b0, b_first = 1'b0, b_last = 1'b0;
    reg signed [7:0]  v_reg = 8'sd0;
    reg        [8:0]  e_reg = 9'd0;
    reg        [1:0]  w_reg = 2'd0;

    always @(posedge clk) begin
        b_val   <= a_val;
        b_first <= a_first;
        b_last  <= a_last;
        // La onda sale de 0 a 255 sin signo y se pasa a -128 a 127 con signo
        // Si la voz esta apagada se manda un 0 exacto
        v_reg   <= a_idle ? 8'sd0 : {~onda_w[7], onda_w[6:0]};
        e_reg   <= a_e;
        w_reg   <= a_w;
    end

    // Etapa C, multiplicador de 9 bits en un bloque DSP
    (* multstyle = "dsp" *) wire signed [17:0] mult = v_reg * $signed({1'b0, e_reg});
	// Ganancia segun la forma de onda para que todas suenen mas o menos parejo
	// Los valores se ajustaron a oido, no son una medida exacta de volumen
	// Cuadrada por 0.5, sierra por 0.625, triangular por 1.5 y seno por 2
	 wire signed [17:0] mult_g =
		(w_reg == 2'd0) ? (mult >>> 1)                 :   // cuadrada por 0.5
		(w_reg == 2'd1) ? ((mult >>> 1) + (mult >>> 3)) :  // sierra por 0.625
		(w_reg == 2'd2) ? (mult + (mult >>> 1))        :   // triangular por 1.5
                      (mult <<< 1);                    // seno por 2
    reg               c_val = 1'b0, c_first = 1'b0, c_last = 1'b0;
    reg signed [17:0] prod  = 18'sd0;

    always @(posedge clk) begin
        c_val   <= b_val;
        c_first <= b_first;
        c_last  <= b_last;
        prod    <= mult_g;
    end

    // Etapa D, acumulacion
    // La primera voz arranca la suma desde 0 y la ultima deja el resultado en suma
    reg signed [20:0] acc = 21'sd0;
    wire signed [20:0] sum_n = (c_first ? 21'sd0 : acc) + {{3{prod[17]}}, prod};

    always @(posedge clk) begin
        if (rst) begin
            acc  <= 21'sd0;
            suma <= 21'sd0;
        end else if (c_val) begin
            acc <= sum_n;
            if (c_last) suma <= sum_n;                 // ya estan sumadas las 12 voces
        end
    end

endmodule
