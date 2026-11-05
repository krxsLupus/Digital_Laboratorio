module eco (
    input  wire        clk,
    input  wire        rst,
    input  wire        en_24k,     // Pulso activo a 24.414 kHz
    input  wire signed [15:0] x,   // Señal seca decimada
    input  wire [3:0]  d_idx,      // Parámetro Tiempo (T)
    input  wire [3:0]  fb_idx,     // Parámetro Feedback
    input  wire [3:0]  mix_idx,    // Parámetro Mezcla
    output reg  signed [15:0] wet  // Salida húmeda
);

    // RAM M9K (18 bits para evitar desbordes en realimentación interna)
    (* ramstyle = "M9K" *) reg signed [17:0] ram [0:6143];
    
    // Inicialización a 0 para evitar estallidos al encender
    integer i;
    initial begin
        for (i = 0; i < 6144; i = i + 1) ram[i] = 18'd0;
    end

    reg [12:0] wr_ptr = 13'd0;
    wire [12:0] rd_ptr;
    
    // El tamaño del retraso D (en muestras). d_idx = 0 no está permitido, sumamos 1.
    wire [12:0] D = (d_idx + 13'd1) * 13'd381; // Pasos de ~15.6 ms
    assign rd_ptr = (wr_ptr >= D) ? (wr_ptr - D) : (13'd6144 + wr_ptr - D);

    // Constantes escaladas (sobre 256)
    wire signed [17:0] fb_k  = {14'd0, fb_idx} * 18'd15;  // max ~0.88
    wire signed [17:0] mix_k = {14'd0, mix_idx} * 18'd17; // max ~0.99

    reg signed [17:0] r_val;
    reg signed [35:0] fb_mult;
    reg signed [17:0] fb_truncado;
    reg signed [17:0] w_val;

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 13'd0;
            wet <= 16'd0;
        end else if (en_24k) begin
            r_val = ram[rd_ptr];
            
            // Producto de feedback con truncado estricto hacia cero
            fb_mult = r_val * fb_k;
            if (fb_mult < 0) 
                fb_truncado = (fb_mult + 36'd255) >>> 8;
            else 
                fb_truncado = fb_mult >>> 8;

            // Señal a escribir en RAM (saturada a 18 bits)
            w_val = x + fb_truncado;
            if (w_val > 18'sd131071) w_val = 18'sd131071;
            else if (w_val < -18'sd131072) w_val = -18'sd131072;
            
            ram[wr_ptr] <= w_val;
            
            // Calcular salida húmeda (saturada a 16 bits)
            wet <= (r_val * mix_k) >>> 8;

            // Avanzar puntero circular
            if (wr_ptr == 13'd6143) wr_ptr <= 13'd0;
            else wr_ptr <= wr_ptr + 1'b1;
        end
    end
endmodule
