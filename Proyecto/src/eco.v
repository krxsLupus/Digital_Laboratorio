module eco (
    input  wire        clk,
    input  wire        rst,
    input  wire        en_24k,     // Pulso activo a 24.414 kHz
    input  wire signed [15:0] x,   // Señal seca decimada
    input  wire [3:0]  d_idx,      // Parámetro Tiempo (T)
    input  wire [3:0]  fb_idx,     // Parámetro Feedback
    input  wire [3:0]  mix_idx,    // Parámetro Mezcla
    output reg  signed [15:0] wet = 16'sd0  // Salida húmeda
);

    // RAM M9K: forzar el uso de bloques de memoria dedicados
    // En las FPGAs de Altera/Intel, las memorias se inicializan en 0 por defecto tras la configuración.
    (* ramstyle = "M9K, no_rw_check" *) reg signed [17:0] ram [0:6143];

    // Se eliminó el bloque initial con el bucle for que causaba el error de >5000 iteraciones

    reg  [12:0] wr_ptr = 13'd0;
    wire [12:0] D = (d_idx + 13'd1) * 13'd381;
    wire [12:0] rd_ptr = (wr_ptr >= D) ? (wr_ptr - D) : (13'd6144 + wr_ptr - D);

    reg signed [17:0] r_val = 18'sd0;
    always @(posedge clk) r_val <= ram[rd_ptr];

    // Constantes con tamaño y signo explícito para evitar truncamientos y mezclas
    wire signed [17:0] fb_k  = $signed({14'b0, fb_idx})  * 18'sd15;
    wire signed [17:0] mix_k = $signed({14'b0, mix_idx}) * 18'sd17;

    // Uso forzado de bloques DSP para las multiplicaciones
    (* multstyle = "dsp" *) wire signed [35:0] fb_mult = r_val * fb_k;
    
    // Almacenar el cálculo completo y luego truncar explícitamente los bits deseados
    wire signed [35:0] fb_trunc_36 = (fb_mult < 0) ? ((fb_mult + 36'sd255) >>> 8) : (fb_mult >>> 8);
    wire signed [17:0] fb_trunc = fb_trunc_36[17:0]; 

    // Extensión de signo explícita para la suma (16 bits + 18 bits = 19 bits)
    wire signed [18:0] w_sum = $signed({x[15], x[15], x[15], x}) + $signed({fb_trunc[17], fb_trunc});
    wire signed [17:0] w_val = (w_sum >  19'sd131071) ? 18'sd131071 :
                               (w_sum < -19'sd131072) ? -18'sd131072 :
                                                         w_sum[17:0];

    (* multstyle = "dsp" *) wire signed [35:0] wet_full = (r_val * mix_k) >>> 8;

    always @(posedge clk) begin
        if (en_24k) ram[wr_ptr] <= w_val;
    end

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 13'd0;
            wet    <= 16'sd0;
        end else if (en_24k) begin
            if      (wet_full >  36'sd32767)  wet <= 16'sd32767;
            else if (wet_full < -36'sd32768)  wet <= -16'sd32768;
            else                              wet <= wet_full[15:0];

            wr_ptr <= (wr_ptr == 13'd6143) ? 13'd0 : (wr_ptr + 13'd1); // Incremento con tamaño 13 bits
        end
    end
endmodule