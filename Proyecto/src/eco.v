// Eco con una linea de retardo en RAM que trabaja a 24.414 kHz.
// La entrada llega ya decimada desde efectos_audio y la salida se interpola alla de vuelta a 48.8 kHz.
// Lo que sale por wet es solo la parte con eco, la senal seca se suma afuera.
module eco (
    input  wire        clk,
    input  wire        rst,
    input  wire        en_24k,     // pulso activo a 24.414 kHz
    input  wire signed [15:0] x,   // senal seca decimada
    input  wire [3:0]  d_idx,      // parametro de tiempo
    input  wire [3:0]  fb_idx,     // parametro de feedback
    input  wire [3:0]  mix_idx,    // parametro de mezcla
    output reg  signed [15:0] wet = 16'sd0  // salida humeda, solo el eco
);

    // Memoria de 6144 posiciones de 18 bits en bloques M9K
    // Se fuerza el uso de memoria dedicada y no de registros, que saldrian carisimos
    // En las FPGA de Altera e Intel la memoria arranca en 0 despues de configurar, asi que no hace falta limpiarla
    (* ramstyle = "M9K, no_rw_check" *) reg signed [17:0] ram [0:6143];

    // Se quito el bloque initial con el for porque daba error por pasar de 5000 iteraciones

    // Puntero de escritura y de lectura
    // El de lectura va D posiciones atras del de escritura y da la vuelta como un buffer circular
    // D es el retardo en muestras, (T mas 1) por 381, o sea pasos de unos 15.6 ms
    reg  [12:0] wr_ptr = 13'd0;
    wire [12:0] D = (d_idx + 13'd1) * 13'd381;
    wire [12:0] rd_ptr = (wr_ptr >= D) ? (wr_ptr - D) : (13'd6144 + wr_ptr - D);

    reg signed [17:0] r_val = 18'sd0;
    always @(posedge clk) r_val <= ram[rd_ptr];

    // Coeficientes con tamano y signo explicitos para que no haya truncamientos raros
    // El feedback es fb por 15 entre 256, maximo 0.88, y la mezcla es mix por 17 entre 256, maximo 0.99
    wire signed [17:0] fb_k  = $signed({14'b0, fb_idx})  * 18'sd15;
    wire signed [17:0] mix_k = $signed({14'b0, mix_idx}) * 18'sd17;

    // Las multiplicaciones van a bloques DSP
    (* multstyle = "dsp" *) wire signed [35:0] fb_mult = r_val * fb_k;

    // Se guarda la cuenta completa y despues se recortan los bits que interesan
    // Para los negativos se suma 255 antes de desplazar y asi se trunca hacia cero
    wire signed [35:0] fb_trunc_36 = (fb_mult < 0) ? ((fb_mult + 36'sd255) >>> 8) : (fb_mult >>> 8);
    wire signed [17:0] fb_trunc = fb_trunc_36[17:0];

    // Lo que se escribe en la RAM es la entrada mas el feedback, con extension de signo explicita
    // y saturado a 18 bits para que no se desborde
    wire signed [18:0] w_sum = $signed({x[15], x[15], x[15], x}) + $signed({fb_trunc[17], fb_trunc});
    wire signed [17:0] w_val = (w_sum >  19'sd131071) ? 18'sd131071 :
                               (w_sum < -19'sd131072) ? -18'sd131072 :
                                                         w_sum[17:0];

    // Salida humeda, lo leido de la RAM por el nivel de mezcla
    (* multstyle = "dsp" *) wire signed [35:0] wet_full = (r_val * mix_k) >>> 8;

    // La escritura va en su propio bloque para que la herramienta la reconozca como RAM
    always @(posedge clk) begin
        if (en_24k) ram[wr_ptr] <= w_val;
    end

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 13'd0;
            wet    <= 16'sd0;
        end else if (en_24k) begin
            // la salida se satura a 16 bits
            if      (wet_full >  36'sd32767)  wet <= 16'sd32767;
            else if (wet_full < -36'sd32768)  wet <= -16'sd32768;
            else                              wet <= wet_full[15:0];

            wr_ptr <= (wr_ptr == 13'd6143) ? 13'd0 : (wr_ptr + 13'd1); // el puntero da la vuelta al llegar al final
        end
    end
endmodule
