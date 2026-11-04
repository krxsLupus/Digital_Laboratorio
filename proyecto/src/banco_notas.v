// Banco de 12 voces: una por nota, todas pueden sonar a la vez (polifonia).
//
// Cada voz tiene su acumulador de fase, su generador de onda (la forma la elige
// sel_onda, igual para todas) y su envolvente ADSR. La fase solo se reinicia
// cuando la voz esta apagada (envolvente en IDLE), asi sigue corriendo durante
// el release. Los parametros A, D, S y R (indices de 4 bits) son comunes a las 12.
// Las voces se suman de una en una: onda x envolvente, acumulado en 20 bits.
// La ganancia por onda, el volumen y la conversion a I2S los hace salida_i2s.
module banco_notas (
    input  wire               clk,         // 50 MHz
    input  wire               rst,         // activo en alto
    input  wire [11:0]        teclas,      // bit n = nota n pulsada (gate de la envolvente)
    input  wire [1:0]         sel_onda,    // 0 cuadrada, 1 sierra, 2 triangular, 3 seno
    input  wire [3:0]         a_idx,       // ataque   (indice de lut_tiempos)
    input  wire [3:0]         d_idx,       // decay    (indice de lut_tiempos)
    input  wire [3:0]         s_idx,       // sustain  (0..15; 15 = nivel 1.0)
    input  wire [3:0]         r_idx,       // release  (indice de lut_tiempos, minimo 2 = 5 ms)
    output wire [11:0]        activas,     // bit n = voz n sonando (tecla o cola de release)
    output reg  signed [19:0] suma = 20'sd0   // mezcla de las voces (cada una x256); 0 = silencio
);

    // ---------------- Reloj de la envolvente: una vez por muestra de audio ----------------
    reg [9:0] fs_cnt = 10'd0;                       // 50 MHz / 1024 = 48.828 kHz (igual que el I2S)
    always @(posedge clk) fs_cnt <= fs_cnt + 1'b1;
    wire tick = (fs_cnt == 10'd1023);

    // ---------------- Parametros ADSR (compartidos por las 12 voces) ----------------
    wire [3:0]  r_c = (r_idx < 4'd2) ? 4'd2 : r_idx;   // release minimo 5 ms: evita el click al soltar
    wire [23:0] inc_a, inc_d, inc_r;
    lut_tiempos u_la (.idx(a_idx), .inc(inc_a));
    lut_tiempos u_ld (.idx(d_idx), .inc(inc_d));
    lut_tiempos u_lr (.idx(r_c),   .inc(inc_r));
    wire [23:0] sus_lvl = (s_idx == 4'd15) ? 24'd8388608 : {1'b0, s_idx, 19'd0};   // S/16 de 2^23; 15 = 1.0

    // ---------------- 12 voces ----------------
    wire [95:0]  voces;     // 12 muestras de 8 bits con signo, centradas en 0
    wire [107:0] env;       // 12 envolventes de 9 bits (0..256)

    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : voz
            localparam [3:0] IDX = i;
            wire [31:0] inc;
            wire [31:0] fase;
            wire [7:0]  onda;
            wire [8:0]  e;
            wire        idle;

            lut_frecuencias u_lut (.nota_idx(IDX), .incremento(inc));

            envelope_adsr u_env (
                .clk     (clk),
                .rst     (rst),
                .tick    (tick),
                .gate    (teclas[i]),
                .inc_a   (inc_a),
                .inc_d   (inc_d),
                .inc_r   (inc_r),
                .sus_lvl (sus_lvl),
                .env     (e),
                .idle    (idle)
            );

            // La fase se mantiene en 0 mientras la voz esta apagada
            acumulador_fase u_acc (
                .clk        (clk),
                .rst        (rst | idle),
                .incremento (inc),
                .fase       (fase)
            );

            generador_onda u_gen (
                .fase     (fase),
                .sel_onda (sel_onda),
                .onda_out (onda)
            );

            assign activas[i]       = ~idle;
            assign env[9*i +: 9]    = e;
            // 0..255 sin signo -> -128..127 con signo; voz apagada, 0 exacto
            assign voces[8*i +: 8]  = idle ? 8'h00 : {~onda[7], onda[6:0]};
        end
    endgenerate

    // ---------------- Suma secuencial ----------------
    // Un multiplicador (9x9) y un sumador, una voz por ciclo, con un registro de
    // pipeline entre el producto y la suma (15 ciclos por muestra):
    //   k = 0       : acc <= 0
    //   k = 1..12   : prod <= onda[k-1] * env[k-1]
    //   k = 2..13   : acc  <= acc + prod
    //   k = 14      : suma <= acc
    // Con env = 256 el producto es onda x 256, igual que antes del ADSR.
    reg  [3:0]         k    = 4'd0;
    reg  signed [19:0] acc  = 20'sd0;
    reg  signed [17:0] prod = 18'sd0;

    wire [3:0] idx = (k >= 4'd1 && k <= 4'd12) ? (k - 4'd1) : 4'd0;
    wire signed [7:0]  v = voces[idx*8 +: 8];
    wire        [8:0]  e = env[idx*9 +: 9];
    wire signed [17:0] mult = v * $signed({1'b0, e});          // 8 b con signo x 9 b: +-32768

    always @(posedge clk) begin
        if (rst) begin
            k    <= 4'd0;
            acc  <= 20'sd0;
            prod <= 18'sd0;
            suma <= 20'sd0;
        end else begin
            k    <= (k == 4'd14) ? 4'd0 : (k + 1'b1);
            prod <= mult;
            if (k == 4'd0)
                acc <= 20'sd0;
            else if (k >= 4'd2 && k <= 4'd13)
                acc <= acc + {{2{prod[17]}}, prod};
            else if (k == 4'd14)
                suma <= acc;                                    // suma completa
        end
    end

endmodule
