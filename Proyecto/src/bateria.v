// Bateria sintetizada: 5 sonidos de percusion, sin muestras (todo se genera).
//
//   trig[0] bombo         seno con barrido de ~140 Hz a ~45 Hz, se apaga en ~120 ms
//   trig[1] caja          rafaga de ruido (~130 ms de cola) + tono triangular de 185 Hz
//   trig[2] hi-hat cerr.  ruido agudo muy corto (~35 ms)
//   trig[3] hi-hat abier. ruido agudo largo (~250 ms); el hi-hat cerrado lo corta
//   trig[4] platillo      ruido agudo con algo de cuerpo y cola larga (~0.5 s)
//
// Cada sonido se dispara con el FLANCO DE SUBIDA de su entrada: tocar la tecla da un
// golpe, mantenerla no repite. El "ruido" es un LFSR de 32 bits (periodo de 86 s, no
// suena a tono); el agudo del hi-hat y del platillo sale de restar muestras de ruido
// consecutivas (filtro pasa-altos de un polo).
//
// Todo se actualiza una vez por muestra de audio (48.828 kHz) y las 6 multiplicaciones
// (onda x envolvente) las hace UN solo multiplicador, una por ciclo despues de cada tick.
// 'salida' va en la misma escala que una voz de banco_notas (onda x env, +-32768 por
// sonido) para sumarse a la mezcla en salida_i2s.
module bateria (
    input  wire               clk,        // 50 MHz
    input  wire               rst,        // activo en alto
    input  wire [4:0]         trig,       // 0 bombo, 1 caja, 2 hi-hat cerrado, 3 hi-hat abierto, 4 platillo
    output reg  signed [19:0] salida = 20'sd0
);

    // ---------------- Tick de muestra (48.828 kHz) ----------------
    reg [9:0] fs_cnt = 10'd0;
    always @(posedge clk) fs_cnt <= fs_cnt + 1'b1;
    wire tick = (fs_cnt == 10'd1023);

    // ---------------- Disparos: flanco de subida, memorizado hasta el tick ----------------
    reg [4:0] trig_q = 5'd0;
    reg [4:0] pend   = 5'd0;
    wire [4:0] subida = trig & ~trig_q;
    wire [4:0] go     = pend | subida;                 // lo que arranca en este tick

    always @(posedge clk) begin
        trig_q <= trig;
        if (rst || tick) pend <= 5'd0;
        else             pend <= pend | subida;
    end

    // ---------------- Ruido: LFSR de 32 bits (x^32 + x^22 + x^2 + x + 1) ----------------
    reg [31:0] lfsr = 32'hACE1_2468;
    always @(posedge clk) lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};

    reg signed [7:0] nz      = 8'sd0;                  // ruido blanco, una muestra por tick
    reg signed [7:0] nz_prev = 8'sd0;
    wire signed [8:0] h9 = nz - nz_prev;               // pasa-altos: x[n] - x[n-1]
    wire signed [7:0] h8 = h9[8:1];                    // +-127
    wire signed [7:0] c8 = (h8 >>> 1) + (nz >>> 2);    // platillo: agudo + algo de cuerpo (+-96)

    // ---------------- Envolventes: caida exponencial, 1.0 = 2^23 ----------------
    // a - (a >> k): constante de tiempo 2^k muestras (k = 12 -> 84 ms). Por debajo de
    // 2^16 (-42 dB respecto de 1.0, ya inaudible) se corta a 0.
    function [23:0] dec;
        input [23:0] a;
        input integer k;
        begin
            dec = (a < 24'h010000) ? 24'd0 : (a - (a >> k));
        end
    endfunction

    localparam [23:0] UNO = 24'h800000;

    reg [23:0] ak  = 24'd0, pk = 24'd0, fk = 24'd0;    // bombo: amplitud, nivel de tono, fase
    reg [23:0] an  = 24'd0, at = 24'd0, ft = 24'h400000;   // caja: ruido, tono, fase del tono
    reg [23:0] ahc = 24'd0, aho = 24'd0, acr = 24'd0;  // hi-hat cerrado / abierto / platillo

    always @(posedge clk) begin
        if (rst) begin
            ak <= 24'd0; pk <= 24'd0; fk <= 24'd0;
            an <= 24'd0; at <= 24'd0; ft <= 24'h400000;
            ahc <= 24'd0; aho <= 24'd0; acr <= 24'd0;
            nz <= 8'sd0; nz_prev <= 8'sd0;
        end else if (tick) begin
            nz      <= $signed(lfsr[15:8] ^ 8'h80);
            nz_prev <= nz;

            // Bombo: la frecuencia baja con pk (inc = 15500 + pk/256 -> ~45 Hz al final)
            if (go[0]) begin ak <= UNO; pk <= UNO; fk <= 24'd0; end
            else begin
                ak <= dec(ak, 11);
                pk <= dec(pk, 11);
                fk <= fk + 24'd15500 + {8'd0, pk[23:8]};
            end

            // Caja: ruido + tono triangular de 185 Hz (inc = 63566)
            if (go[1]) begin an <= UNO; at <= UNO; ft <= 24'h400000; end
            else begin
                an <= dec(an, 11);
                at <= dec(at, 10);
                ft <= ft + 24'd63566;
            end

            // Hi-hat cerrado corta al abierto
            if (go[2])      ahc <= UNO; else ahc <= dec(ahc, 9);
            if (go[3])      aho <= UNO;
            else if (go[2]) aho <= 24'd0;
            else            aho <= dec(aho, 12);

            // Platillo
            if (go[4]) acr <= UNO; else acr <= dec(acr, 13);
        end
    end

    // ---------------- Ondas ----------------
    wire [7:0] seno_o;
    generador_onda u_sen (.fase({fk, 8'd0}), .sel_onda(2'd3), .onda_out(seno_o));
    wire signed [7:0] v_k = {~seno_o[7], seno_o[6:0]};

    wire [7:0] tri_u = ft[23] ? ~ft[22:15] : ft[22:15];
    wire signed [7:0] v_t = {~tri_u[7], tri_u[6:0]};

    // ---------------- Un multiplicador, 6 terminos ----------------
    reg       run = 1'b0;
    reg [2:0] k   = 3'd0;
    always @(posedge clk) begin
        if (rst) begin run <= 1'b0; k <= 3'd0; end
        else if (tick) begin run <= 1'b1; k <= 3'd0; end
        else if (run) begin
            if (k == 3'd5) run <= 1'b0;
            else           k   <= k + 3'd1;
        end
    end

    reg signed [7:0] va;
    reg        [8:0] ea;
    always @(*) begin
        case (k)
            3'd0:    begin va = v_k; ea = ak [23:15]; end     // bombo
            3'd1:    begin va = nz;  ea = an [23:15]; end     // caja: ruido
            3'd2:    begin va = v_t; ea = at [23:15]; end     // caja: tono
            3'd3:    begin va = h8;  ea = ahc[23:15]; end     // hi-hat cerrado
            3'd4:    begin va = h8;  ea = aho[23:15]; end     // hi-hat abierto
            default: begin va = c8;  ea = acr[23:15]; end     // platillo
        endcase
    end

    reg               s1_ok = 1'b0;
    reg  [2:0]        s1_k  = 3'd0;
    reg signed [7:0]  s1_v  = 8'sd0;
    reg        [8:0]  s1_e  = 9'd0;
    reg               s2_ok = 1'b0;
    reg  [2:0]        s2_k  = 3'd0;
    reg signed [17:0] prod  = 18'sd0;
    (* multstyle = "dsp" *) wire signed [17:0] mult = s1_v * $signed({1'b0, s1_e});

    reg signed [19:0] acc = 20'sd0;
    reg signed [19:0] term;
    always @(*) begin
        case (s2_k)
            3'd0:    term = {{2{prod[17]}}, prod} <<< 1;     // bombo x2
            3'd2:    term = {{2{prod[17]}}, prod} >>> 1;     // tono de la caja a la mitad
            3'd3, 3'd4, 3'd5: term = {{2{prod[17]}}, prod} <<< 1;   // hi-hats y platillo x2 (el ruido agudo es debil)
            default: term = {{2{prod[17]}}, prod};
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            s1_ok <= 1'b0; s2_ok <= 1'b0; acc <= 20'sd0; salida <= 20'sd0;
        end else begin
            s1_ok <= run;   s1_k <= k;   s1_v <= va;   s1_e <= ea;
            s2_ok <= s1_ok; s2_k <= s1_k; prod <= mult;
            if (s2_ok) begin
                if (s2_k == 3'd5) salida <= acc + term;       // suma completa
                else              acc    <= (s2_k == 3'd0) ? term : (acc + term);
            end
        end
    end

endmodule
