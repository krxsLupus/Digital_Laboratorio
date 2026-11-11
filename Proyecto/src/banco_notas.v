// Banco de 12 voces: una por nota, todas pueden sonar a la vez (polifonia).
//
// Version optimizada en area (mismos puertos que la anterior):
//   * Los 12 acumuladores de fase siguen en paralelo (corren a 50 MHz).
//   * La envolvente ADSR es SERIAL: un solo datapath recorre las 12 voces, una por
//     ciclo, justo despues de cada 'tick' (1 vez por muestra de audio, 1024 ciclos).
//     El estado (st, lvl) de cada voz se guarda en registros por voz. Solo hay 3
//     lut_tiempos en total (antes 36) y un solo juego de sumadores/comparadores.
//   * Un solo generador_onda, compartido: la mezcla ya visita una voz por ciclo.
//   * Los incrementos de fase por nota son constantes (antes: 12 ROM de lut_frecuencias).
//   * Mezcla: seleccion -> forma de onda -> multiplicador (DSP) -> acumulacion.
module banco_notas (
    input  wire               clk,         // 50 MHz
    input  wire               rst,         // activo en alto
    input  wire [11:0]        teclas,      // bit n = nota n pulsada (gate de la envolvente)
    input  wire [23:0]        onda_v,      // 2 bits por voz: 0 cuadrada, 1 sierra, 2 triangular, 3 seno
    input  wire [23:0]        oct_v,       // 2 bits por voz: 0 = Do3, 1 = Do4, 2 = Do5, 3 = Do6
    input  wire [47:0]        a_v,         // 4 bits por voz: ataque
    input  wire [47:0]        d_v,         //                 decay
    input  wire [47:0]        s_v,         //                 sustain
    input  wire [47:0]        r_v,         //                 release
    output wire [11:0]        activas,     // bit n = voz n sonando (tecla o cola de release)
    output reg  signed [20:0] suma = 21'sd0 // mezcla de las voces (cada una x256); 0 = silencio
);

    // ---------------- Reloj de la envolvente: una vez por muestra de audio ----------------
    reg [9:0] fs_cnt = 10'd0;
    always @(posedge clk) fs_cnt <= fs_cnt + 1'b1;
    wire tick = (fs_cnt == 10'd1023);

    // Registro de entrada para cortar la ruta critica externa
    reg [11:0] teclas_reg = 12'd0;
    always @(posedge clk) begin
        if (rst) teclas_reg <= 12'd0;
        else     teclas_reg <= teclas;
    end

    // ---------------- Incremento de fase por nota (50 MHz, acumulador de 32 bits) ----------------
    // Valores identicos a los de lut_frecuencias.v (mismo orden de indices).
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
    localparam [23:0] MAXL   = 24'd8388608;                 // 1.0 = 2^23

    // ---------------- Estado por voz: fase, estado ADSR y nivel ----------------
    wire [383:0] fase_v;      // 12 x 32
    wire [35:0]  st_v;        // 12 x 3
    wire [287:0] lvl_v;       // 12 x 24
    wire [11:0]  idle_v;

    // Se escribe desde el datapath serial de la envolvente (mas abajo)
    reg         s2_v = 1'b0;          // hay un resultado listo para guardar
    reg  [3:0]  s2_i = 4'd0;          // a que voz pertenece
    reg  [2:0]  n_st;                 // siguiente estado   (logica combinacional)
    reg  [23:0] n_lvl;                // siguiente nivel    (logica combinacional)

    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : voz
            localparam [31:0] INC0 = f_inc(i);

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

            // Cambio de octava (INC0 es constante: cada rama es un desplazamiento fijo)
            wire [1:0]  v_oct = oct_v[2*i +: 2];
            wire [31:0] inc   = (v_oct == 2'd0) ? (INC0 >> 1) :
                                (v_oct == 2'd1) ?  INC0       :
                                (v_oct == 2'd2) ? (INC0 << 1) :
                                                  (INC0 << 2);

            // La fase se mantiene en 0 mientras la voz esta apagada
            acumulador_fase u_acc (
                .clk        (clk),
                .rst        (rst | idle_v[i]),
                .incremento (inc),
                .fase       (fase_v[32*i +: 32])
            );
        end
    endgenerate

    assign activas = ~idle_v;

    // ---------------- Envolvente serial ----------------
    // Tras cada 'tick' se procesan las voces 0..11, una por ciclo, en 3 etapas:
    //   etapa 0: contador de voz (seq_i)
    //   etapa 1: se leen estado, nivel, gate y parametros de la voz seq_i
    //   etapa 2: salida de las lut_tiempos registrada
    //   escritura: se calcula el siguiente (st, lvl) y se guarda en la voz s2_i
    reg        seq_act = 1'b0;
    reg  [3:0] seq_i   = 4'd0;

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

    // Etapa 1: lectura de la voz seleccionada
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
        q1_r    <= (r_v[seq_i*4 +: 4] < 4'd2) ? 4'd2 : r_v[seq_i*4 +: 4];   // release minimo 5 ms
    end

    // Tablas de tiempo: UNA copia cada una, compartida por las 12 voces
    wire [23:0] inc_a_w, inc_d_w, inc_r_w;
    lut_tiempos u_la (.idx(q1_a), .inc(inc_a_w));
    lut_tiempos u_ld (.idx(q1_d), .inc(inc_d_w));
    lut_tiempos u_lr (.idx(q1_r), .inc(inc_r_w));

    // Etapa 2: tablas registradas
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
        q2_sus   <= (q1_s == 4'd15) ? 24'd8388608 : {1'b0, q1_s, 19'd0};   // S/16 de 2^23; 15 = 1.0
    end

    // Calculo del siguiente estado (misma logica que envelope_adsr.v)
    wire [24:0] lvl_up_a = {1'b0, q2_lvl} + {1'b0, q2_inc_a};
    wire [24:0] dec_tgt  = {1'b0, q2_sus} + {1'b0, q2_inc_d};   // si lvl <= esto, el proximo paso llega a S
    wire [24:0] sus_up   = {1'b0, q2_lvl} + {1'b0, q2_inc_d};
    wire [23:0] lvl_dn_d = q2_lvl - q2_inc_d;
    wire [23:0] lvl_dn_r = q2_lvl - q2_inc_r;
    wire [23:0] dif_dn   = q2_lvl - q2_sus;
    wire [23:0] dif_up   = q2_sus - q2_lvl;

    always @(*) begin
        n_st  = q2_st;
        n_lvl = q2_lvl;
        case (q2_st)
            S_IDLE: begin
                n_lvl = 24'd0;
                if (q2_gate) n_st = S_ATK;
            end

            S_ATK: begin
                if (!q2_gate) n_st = S_REL;
                else if (lvl_up_a >= {1'b0, MAXL}) begin
                    n_lvl = MAXL;
                    n_st  = S_DEC;
                end else
                    n_lvl = lvl_up_a[23:0];
            end

            S_DEC: begin
                if (!q2_gate) n_st = S_REL;
                else if ({1'b0, q2_lvl} <= dec_tgt) begin
                    n_lvl = q2_sus;
                    n_st  = S_SUS;
                end else
                    n_lvl = lvl_dn_d;
            end

            S_SUS: begin
                if (!q2_gate) n_st = S_REL;
                else if (q2_lvl > q2_sus)                       // S bajo: baja suave
                    n_lvl = (dif_dn <= q2_inc_d) ? q2_sus : lvl_dn_d;
                else if (q2_lvl < q2_sus)                       // S subio: sube suave
                    n_lvl = (dif_up <= q2_inc_d) ? q2_sus : sus_up[23:0];
            end

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

    // ---------------- Mezcla secuencial ----------------
    // k recorre 0..15. Las voces 0..11 se seleccionan en k = 0..11 y avanzan por:
    //   A: seleccion (fase, envolvente, tipo de onda, idle)
    //   B: forma de onda (generador unico) -> muestra con signo
    //   C: multiplicador DSP (onda x envolvente) + ganancia de la sierra
    //   D: acumulacion; en la ultima voz se carga 'suma'
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
        a_ph    <= fase_v[ki*32 + 23 +: 9];       // solo se usan fase[31:23]
        a_e     <= lvl_v [ki*24 + 15 +: 9];       // env = lvl[23:15] (0..256)
        a_w     <= onda_v[ki*2 +: 2];
        a_idle  <= idle_v[ki];
    end

    // Etapa B: un unico generador de onda
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
        // 0..255 sin signo -> -128..127 con signo; voz apagada, 0 exacto
        v_reg   <= a_idle ? 8'sd0 : {~onda_w[7], onda_w[6:0]};
        e_reg   <= a_e;
        w_reg   <= a_w;
    end

    // Etapa C: multiplicador (hardware DSP de 9 bits)
    (* multstyle = "dsp" *) wire signed [17:0] mult = v_reg * $signed({1'b0, e_reg});
    wire signed [17:0] mult_g = (w_reg == 2'd1) ? (mult + (mult >>> 1)) : mult;   // sierra x1.5

    reg               c_val = 1'b0, c_first = 1'b0, c_last = 1'b0;
    reg signed [17:0] prod  = 18'sd0;

    always @(posedge clk) begin
        c_val   <= b_val;
        c_first <= b_first;
        c_last  <= b_last;
        prod    <= mult_g;
    end

    // Etapa D: acumulacion
    reg signed [20:0] acc = 21'sd0;
    wire signed [20:0] sum_n = (c_first ? 21'sd0 : acc) + {{3{prod[17]}}, prod};

    always @(posedge clk) begin
        if (rst) begin
            acc  <= 21'sd0;
            suma <= 21'sd0;
        end else if (c_val) begin
            acc <= sum_n;
            if (c_last) suma <= sum_n;                 // suma completa
        end
    end

endmodule