// Secuenciador con capas acumulables (loop), grabacion en vivo.
//
// Controles: dos interruptores (toggle) a GND. Cerrado = 1.
//     sw_b sw_a   modo
//       0    0    STOP   : nada suena del loop, el contador vuelve al paso 0
//       0    1    PLAY   : el loop suena (si no hay nada grabado suena el metronomo)
//       1    1    REC    : el loop suena y lo que toques se graba en una capa nueva
//       1    0    CLEAR  : mantenido 1 s borra todas las capas
//     El orden STOP - PLAY - REC - CLEAR es un codigo Gray: de un modo al vecino
//     solo hay que mover UN interruptor, y PLAY <-> REC no pasa por STOP ni CLEAR.
//     CLEAR solo borra si se queda 1 s, asi que pasar de largo por esa posicion no borra nada.
//
// Una grabacion = una capa, dure lo que dure:
//   * Un compas son 16 pasos (semicorcheas, 4 tiempos). Una capa puede ocupar 1, 2 o
//     4 compases (16, 32 o 64 pasos): su largo es el del compas donde esta su ultima
//     nota. Tocar mas alla del compas 1 NO crea otra capa: la capa se alarga.
//   * Al pasar a REC la grabacion arranca en el inicio del loop (paso 0), no en mitad.
//     Mientras esperas ese inicio ya suena lo grabado y el metronomo.
//   * Durante REC el contador de pasos corre hasta 64 (4 compases) y vuelve a 0. Al
//     salir de REC el loop dura lo que la capa mas larga; las mas cortas se repiten.
//   * Las notas se cuantizan al paso MAS CERCANO. Una tecla mantenida llena todos los
//     pasos que cruza (la duracion queda grabada).
//   * Cada vez que entras a REC se usa una capa nueva (hasta 4). Las anteriores suenan
//     mientras grabas. La capa que se esta grabando se oye al volver a PLAY. Con las 4
//     capas llenas, REC sigue anadiendo notas a la ultima.
//
// Parametros por capa: al empezar a grabar una capa se copian la forma de onda, la
// octava y el ADSR que tienes puestos (p_onda, p_oct, p_a..p_r) y esa capa suena SIEMPRE
// con ellos, aunque despues los cambies. fuentes_voz los aplica a cada voz.
//
// Metronomo: un clic cada negra (el primero de cada compas, mas agudo) durante REC y
// durante PLAY mientras no haya nada grabado.
// Una nota mantenida varios pasos suena continua. Solo la nota que TERMINA calla el
// ultimo 1/8 de su paso. (Dos toques separados de la misma nota en pasos seguidos se
// graban como una nota larga: se guarda que la tecla esta pulsada en cada paso.)
module secuenciador #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer DEB_MS   = 20,        // antirrebote de los interruptores
    parameter integer CLEAR_MS = 1000       // tiempo en CLEAR para borrar
)(
    input  wire               clk,
    input  wire               rst,          // activo en alto
    input  wire               sw_a_n,       // interruptor A (0 = cerrado)
    input  wire               sw_b_n,       // interruptor B (0 = cerrado)
    input  wire [11:0]        teclas,       // teclado fisico, ya con antirrebote
    input  wire [3:0]         bpm_idx,      // 0..15 -> 60 + 10*idx BPM
    // Parametros actuales (se copian a la capa al empezar a grabarla)
    input  wire [1:0]         p_onda,
    input  wire [1:0]         p_oct,
    input  wire [3:0]         p_a,
    input  wire [3:0]         p_d,
    input  wire [3:0]         p_s,
    input  wire [3:0]         p_r,
    // Salidas por capa (capa 0 en los bits menos significativos)
    output wire [47:0]        gate_capas,   // notas que pide cada capa (4 x 12)
    output wire [7:0]         capa_onda,    // 4 x 2
    output wire [7:0]         capa_oct,     // 4 x 2
    output wire [15:0]        capa_a,       // 4 x 4
    output wire [15:0]        capa_d,
    output wire [15:0]        capa_s,
    output wire [15:0]        capa_r,
    output wire signed [19:0] click,        // metronomo (a sumar con la mezcla)
    output wire [3:0]         paso,         // paso dentro del compas 0..15
    output wire [2:0]         capas,        // capas con contenido 0..4
    output wire               corriendo,    // 1 en PLAY y REC
    // Indicadores de modo (LEDs externos, se encienden con 1)
    output wire               led_play,     // fijo mientras el loop corre
    output wire               led_rec,      // parpadea esperando el inicio del loop; fijo grabando
    output wire               led_clear     // fijo en CLEAR hasta que termina el borrado
);

    localparam integer NCAPAS = 4;

    // ---------------- Interruptores: sincronizar + antirrebote ----------------
    localparam integer DEB_LIM = DEB_MS * (CLK_FREQ / 1000);
    localparam integer DEB_W   = $clog2(DEB_LIM + 1);

    wire [1:0] crudo = {~sw_b_n, ~sw_a_n};          // 1 = cerrado
    reg  [1:0] s1 = 2'b00, s2 = 2'b00;
    reg  [1:0] ultimo  = 2'b00;
    reg  [1:0] modo    = 2'b00;                     // estable
    reg  [DEB_W-1:0] cnt_deb = 0;

    always @(posedge clk) begin
        s1 <= crudo;
        s2 <= s1;
        if (rst) begin
            ultimo  <= 2'b00;
            modo    <= 2'b00;
            cnt_deb <= 0;
        end else if (s2 != ultimo) begin
            ultimo  <= s2;                          // cambio: empezar a contar de nuevo
            cnt_deb <= 0;
        end else if (s2 != modo) begin
            if (cnt_deb == DEB_LIM - 1) begin
                modo    <= s2;
                cnt_deb <= 0;
            end else
                cnt_deb <= cnt_deb + 1'b1;
        end
    end

    localparam [1:0] M_STOP = 2'b00, M_PLAY = 2'b01, M_REC = 2'b11, M_CLEAR = 2'b10;

    assign corriendo = (modo == M_PLAY) || (modo == M_REC);
    wire   grabando  = (modo == M_REC);

    // Al salir de REC se sigue 'grabando' hasta el siguiente instante de cuantizacion
    // (como mucho medio paso), para no perder la ultima nota si sueltas el interruptor
    // justo despues de tocarla. 'grab_ef' es el REC efectivo.
    reg  grab_ant  = 1'b0;
    reg  armada    = 1'b0;            // REC ya paso por el paso 0: se graba
    reg  cerrando  = 1'b0;
    wire sale      = grab_ant && !grabando && armada;      // un ciclo: acaba de salir de REC
    wire grab_ef   = grabando || cerrando || sale;

    // ---------------- Tempo: ciclos por paso (semicorchea) ----------------
    // ciclos = CLK_FREQ * 60 / (4 * BPM) = CLK_FREQ * 15 / BPM
    reg [23:0] periodo = 24'd0;
    
    // Funcion para aislar la matematica de 32 bits y forzar el truncamiento a 24 bits sin advertencias
    function [23:0] calc_periodo(input integer bpm);
        calc_periodo = (CLK_FREQ * 15) / bpm;
    endfunction

    always @(posedge clk) begin
        case (bpm_idx)
            4'd0:    periodo <= calc_periodo(60);
            4'd1:    periodo <= calc_periodo(70);
            4'd2:    periodo <= calc_periodo(80);
            4'd3:    periodo <= calc_periodo(90);
            4'd4:    periodo <= calc_periodo(100);
            4'd5:    periodo <= calc_periodo(110);
            4'd6:    periodo <= calc_periodo(120);
            4'd7:    periodo <= calc_periodo(130);
            4'd8:    periodo <= calc_periodo(140);
            4'd9:    periodo <= calc_periodo(150);
            4'd10:   periodo <= calc_periodo(160);
            4'd11:   periodo <= calc_periodo(170);
            4'd12:   periodo <= calc_periodo(180);
            4'd13:   periodo <= calc_periodo(190);
            4'd14:   periodo <= calc_periodo(200);
            default: periodo <= calc_periodo(210);
        endcase
    end

    reg [23:0] mitad = 24'd0;      // instante de cuantizacion dentro del paso
    reg [23:0] corte = 24'd0;      // desde aqui el paso calla (ultimo 1/8)
    always @(posedge clk) begin
        mitad <= periodo >> 1;
        corte <= periodo - (periodo >> 3);
    end

    // ---------------- Estado de las capas ----------------
    reg [2:0]  usadas   = 3'd0;            // capas con contenido
    reg [1:0]  capa_rec = 2'd0;            // capa en la que se graba
    reg [23:0] lmask_v  = 24'd0;           // por capa: 15, 31 o 63 (ultimo paso de su loop)
    assign capas = usadas;

    // Ultimo paso del loop en PLAY: el de la capa mas larga (minimo 1 compas)
    reg [5:0] lmask_loop;
    integer   l;
    always @(*) begin
        lmask_loop = 6'd15;
        for (l = 0; l < NCAPAS; l = l + 1)
            if (l < usadas) lmask_loop = lmask_loop | lmask_v[6*l +: 6];
    end

    // ---------------- Contador de paso (0..63) ----------------
    // En REC (ya armado) corre hasta 63 para poder grabar hasta 4 compases; si no, da
    // la vuelta en el ultimo paso del loop.
    reg [23:0] fase   = 24'd0;
    reg [5:0]  paso_r = 6'd0;
    wire [5:0] lim = (grab_ef && armada) ? 6'd63 : lmask_loop;
    assign paso = paso_r[3:0];

    always @(posedge clk) begin
        if (rst || !corriendo) begin
            fase   <= 24'd0;
            paso_r <= 6'd0;
        end else if (fase >= periodo - 24'd1) begin
            fase   <= 24'd0;
            paso_r <= (paso_r >= lim) ? 6'd0 : (paso_r + 6'd1);
        end else
            fase <= fase + 24'd1;
    end

    wire a_mitad = corriendo && (fase == mitad);

    // REC se arma al llegar al inicio del loop (antes de su instante de cuantizacion)
    always @(posedge clk) begin
        if (rst || !grab_ef)                         armada <= 1'b0;
        else if (paso_r == 6'd0 && fase < mitad)     armada <= 1'b1;
    end

    wire rec = grab_ef && armada;

    always @(posedge clk) begin
        if (rst || !corriendo || grabando)  cerrando <= 1'b0;
        else if (sale)                      cerrando <= !a_mitad;  // sigue hasta escribir la ultima nota
        else if (a_mitad)                   cerrando <= 1'b0;      // ya se escribio
    end

    // ---------------- Borrado (CLEAR mantenido) ----------------
    localparam integer CLR_LIM = CLEAR_MS * (CLK_FREQ / 1000);
    localparam integer CLR_W   = $clog2(CLR_LIM + 1);
    reg [CLR_W-1:0] cnt_clr = 0;
    reg             borrar  = 1'b0;

    always @(posedge clk) begin
        borrar <= 1'b0;
        if (rst || modo != M_CLEAR)
            cnt_clr <= 0;
        else if (cnt_clr < CLR_LIM) begin
            cnt_clr <= cnt_clr + 1'b1; // Se mantiene 1'b1 porque CLR_W es parametrizable
            if (cnt_clr == CLR_LIM - 1) borrar <= 1'b1;
        end
    end

    // ---------------- LEDs de modo ----------------
    reg [24:0] cnt_parp = 25'd0;                     // bit 24: ~1.5 Hz a 50 MHz
    always @(posedge clk) cnt_parp <= cnt_parp + 25'd1;

    assign led_play  = corriendo;
    assign led_rec   = grabando && (armada || cnt_parp[24]);
    assign led_clear = (modo == M_CLEAR) && (cnt_clr < CLR_LIM);

    // ---------------- Captura de lo que se toca ----------------
    // 'cap' junta todas las teclas vistas desde la mitad del paso anterior.
    reg  [11:0] cap = 12'd0;
    wire [11:0] tocado = cap | teclas;

    always @(posedge clk) begin
        if (rst || !rec)  cap <= 12'd0;
        else if (a_mitad) cap <= teclas;
        else              cap <= tocado;
    end

    // ---------------- Memorias (una por capa) y parametros ----------------
    wire [12*NCAPAS-1:0] rd_v;
    reg                  limpiando = 1'b0;      // barrido que pone a 0 una capa nueva
    reg  [5:0]           cnt_limp  = 6'd0;

    wire entra_rec   = grabando && !grab_ant;
    wire nueva       = (usadas < NCAPAS);
    wire [1:0] capa_nueva = nueva ? usadas[1:0] : 2'd3;           // llenas: se sigue en la ultima
    wire escribe     = a_mitad && rec && !entra_rec && !limpiando && (tocado != 12'd0);

    wire [11:0] rd_rec = rd_v[12*capa_rec +: 12];
    wire [5:0]  wa     = limpiando ? cnt_limp : paso_r;
    wire [11:0] wd     = limpiando ? 12'd0 : (rd_rec | tocado);

    genvar g;
    generate
        for (g = 0; g < NCAPAS; g = g + 1) begin : cp
            wire propia = grab_ef && (capa_rec == g);
            // Con un solo puerto de lectura se lee el paso actual (fase < 5) y luego el
            // siguiente (fase >= 5); asi se sabe si la nota CONTINUA en el paso que viene.
            wire        ver_sig = (fase >= 24'd5);
            wire [5:0]  ra_cur  = paso_r & lmask_v[6*g +: 6];
            wire [5:0]  ra_sig  = (paso_r + 6'd1) & lmask_v[6*g +: 6];
            wire [5:0]  ra      = propia ? paso_r : (ver_sig ? ra_sig : ra_cur);
            ram_capa u_ram (
                .clk (clk),
                .we  ((capa_rec == g) && (limpiando || escribe)),
                .wa  (wa),
                .wd  (wd),
                .ra  (ra),
                .rd  (rd_v[12*g +: 12])
            );

            reg [11:0] cur = 12'd0, sig = 12'd0, gate_r = 12'd0;
            always @(posedge clk) begin
                if (fase == 24'd3) cur <= rd_v[12*g +: 12];     // lectura del paso actual
                if (fase == 24'd8) sig <= rd_v[12*g +: 12];     // lectura del paso siguiente
                // La capa que se esta grabando no suena mientras se graba (suena en PLAY).
                // Una nota que sigue en el paso siguiente NO se corta (no hay re-ataque);
                // solo se calla el ultimo 1/8 de las notas que terminan. Durante los
                // primeros ciclos del paso (la RAM aun lee) se mantiene el valor anterior.
                if (rst || !corriendo || (g >= usadas) || propia)
                    gate_r <= 12'd0;
                else if (fase > 24'd4)
                    gate_r <= cur & ((fase < corte) ? 12'hFFF : sig);
            end
            assign gate_capas[12*g +: 12] = gate_r;
        end
    endgenerate

    // Parametros de cada capa
    reg [7:0]  c_onda = 8'd0, c_oct = 8'd0;
    reg [15:0] c_a = 16'd0, c_d = 16'd0, c_s = 16'd0, c_r = 16'd0;
    assign capa_onda = c_onda;
    assign capa_oct  = c_oct;
    assign capa_a    = c_a;
    assign capa_d    = c_d;
    assign capa_s    = c_s;
    assign capa_r    = c_r;

    // Largo (en pasos) que necesita el paso actual: 16, 32 o 64
    wire [5:0] lm_nuevo = (paso_r <= 6'd15) ? 6'd15 : (paso_r <= 6'd31) ? 6'd31 : 6'd63;

    always @(posedge clk) begin
        grab_ant <= grabando;
        if (rst || borrar) begin
            usadas    <= 3'd0;
            capa_rec  <= 2'd0;
            lmask_v   <= 24'd0;
            limpiando <= 1'b0;
            cnt_limp  <= 6'd0;
        end else begin
            if (entra_rec) begin
                capa_rec <= capa_nueva;
                if (nueva) begin
                    limpiando <= 1'b1;
                    cnt_limp  <= 6'd0;
                    lmask_v[6*capa_nueva +: 6] <= 6'd0;
                    c_onda[2*capa_nueva +: 2]  <= p_onda;
                    c_oct [2*capa_nueva +: 2]  <= p_oct;
                    c_a   [4*capa_nueva +: 4]  <= p_a;
                    c_d   [4*capa_nueva +: 4]  <= p_d;
                    c_s   [4*capa_nueva +: 4]  <= p_s;
                    c_r   [4*capa_nueva +: 4]  <= p_r;
                end
            end else if (limpiando) begin
                cnt_limp <= cnt_limp + 6'd1;
                if (cnt_limp == 6'd63) limpiando <= 1'b0;
            end

            if (escribe) begin
                // la capa se alarga hasta el compas de su ultima nota
                lmask_v[6*capa_rec +: 6] <=
                    ((usadas == {1'b0, capa_rec}) ? 6'd0 : lmask_v[6*capa_rec +: 6]) | lm_nuevo;
                if (usadas == {1'b0, capa_rec}) usadas <= usadas + 3'd1;
            end
        end
    end

    // ---------------- Metronomo ----------------
    // Un clic de 10 ms cada negra (cada 4 pasos); el del paso 0 de cada compas es mas agudo.
    localparam integer CLICK_CICLOS = CLK_FREQ / 100;
    localparam signed [19:0] CLICK_AMP = 20'sd10240;

    wire metro   = corriendo && (grabando || usadas == 3'd0);
    wire clic_on = metro && (paso_r[1:0] == 2'b00) && (fase < CLICK_CICLOS);
    wire tono    = (paso_r[3:0] == 4'd0) ? fase[13] : fase[14];   // ~3 kHz / ~1.5 kHz a 50 MHz

    assign click = !clic_on ? 20'sd0 : (tono ? CLICK_AMP : -CLICK_AMP);

endmodule