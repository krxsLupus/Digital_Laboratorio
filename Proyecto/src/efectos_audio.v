// Eco a 24.4 kHz alrededor del modulo 'eco' (la entrada se decima a la mitad
// promediando dos muestras, y el resultado se interpola de vuelta a 48.8 kHz).
module efectos_audio (
    input  wire        clk,
    input  wire        rst,
    input  wire        en_48k,     // Tick a 48.8 kHz desde salida_i2s
    input  wire signed [15:0] x,   // Senal seca a 48.8 kHz
    input  wire [3:0]  eco_t,
    input  wire [3:0]  eco_fb,
    input  wire [3:0]  eco_mix,
    output reg  signed [15:0] y = 16'sd0   // Salida mixta final a 48.8 kHz
);

    reg paridad = 1'b0;
    reg signed [15:0] x_prev       = 16'sd0;
    reg signed [15:0] x_decimado   = 16'sd0;
    wire en_24k = (en_48k && paridad);

    // Conexion del eco
    wire signed [15:0] wet_eco;
    eco u_eco (
        .clk(clk),
        .rst(rst),
        .en_24k(en_24k),
        .x(x_decimado),
        .d_idx(eco_t),
        .fb_idx(eco_fb),
        .mix_idx(eco_mix),
        .wet(wet_eco)
    );

    reg signed [15:0] wet_prev   = 16'sd0;
    reg signed [15:0] wet_actual = 16'sd0;

    // Sumas con extension de signo explicita para que el compilador no recorte a 16 bits primero
    wire signed [16:0] x_suma   = $signed({x[15], x}) + $signed({x_prev[15], x_prev});
    wire signed [16:0] wet_suma = $signed({wet_prev[15], wet_prev}) + $signed({wet_actual[15], wet_actual});
    
    // Interpolacion usando slice [16:1] equivalente a >>> 1 pero forzando 16 bits sin warnings
    wire signed [15:0] wet_interpolado = wet_suma[16:1];

    // Extension de signo a 18 bits para la mezcla, de modo que encaje exacto en la funcion sat16
    wire signed [17:0] mezcla_a = $signed({x[15], x[15], x}) + $signed({wet_actual[15], wet_actual[15], wet_actual});
    wire signed [17:0] mezcla_b = $signed({x[15], x[15], x}) + $signed({wet_interpolado[15], wet_interpolado[15], wet_interpolado});

    always @(posedge clk) begin
        if (rst) begin
            paridad    <= 1'b0;
            x_prev     <= 16'sd0;
            x_decimado <= 16'sd0;
            wet_prev   <= 16'sd0;
            wet_actual <= 16'sd0;
            y          <= 16'sd0;
        end else if (en_48k) begin
            paridad <= ~paridad;

            if (!paridad) begin
                // Fase 1: guardar la muestra impar y entregar el wet del calculo anterior
                x_prev <= x;
                y <= sat16(mezcla_a);
            end else begin
                // Fase 2: promediar (decimar), activar el eco a 24k e interpolar
                x_decimado <= x_suma[16:1]; // Evita warning por usar 'x_suma >>> 1'
                wet_prev   <= wet_actual;
                wet_actual <= wet_eco;      // esta actualizacion ocurre gracias a en_24k
                y <= sat16(mezcla_b);
            end
        end
    end

    function signed [15:0] sat16 (input signed [17:0] val);
        begin
            if (val > 18'sd32767)       sat16 = 16'sd32767;
            else if (val < -18'sd32768) sat16 = -16'sd32768;
            else                        sat16 = val[15:0];
        end
    endfunction
endmodule