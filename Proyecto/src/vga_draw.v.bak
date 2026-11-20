// Dibujo VGA: osciloscopio de la mezcla real (centro de pantalla) + HUD (arriba).
// rgb va REGISTRADO y solo se actualiza cuando el dato de la memoria del osciloscopio ya
// es valido (2o ciclo de cada pixel de 25 MHz), asi la salida cambia una vez por pixel y
// sin glitches combinacionales.
module vga_draw(
    input  wire        clk,         // 50 MHz
    input  wire        rst,         // activo en alto
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire        video_on,
    // Osciloscopio
    input  wire        en_48k,      // una muestra nueva (salida_i2s: scope_tick)
    input  wire signed [15:0] muestra, // mezcla seca (salida_i2s: scope_x)
    // Parametros para el HUD
    input  wire [3:0]  a_idx, d_idx, s_idx, r_idx,
    input  wire [3:0]  eco_t, eco_fb, eco_mix, bpm_idx,
    input  wire [7:0]  led_param,   // parametro elegido, one-hot
    output reg  [2:0]  rgb          // {R, G, B}
);

    wire [7:0] s_hi, s_lo;
    vga_scope u_scope (
        .clk(clk), .rst(rst), .en_48k(en_48k), .muestra(muestra),
        .x(x), .y(y), .s_hi(s_hi), .s_lo(s_lo)
    );

    // valor v (1..255, 128 = centro) -> fila y = 396 - v ; el trazo mide +-2 px
    wire [9:0] y_top = 10'd396 - {2'b00, s_hi};
    wire [9:0] y_bot = 10'd396 - {2'b00, s_lo};
    wire trazo_activo = (y + 10'd2 >= y_top) && (y <= y_bot + 10'd2);

    wire       hud_hit;
    wire [2:0] hud_rgb;
    vga_hud u_hud (
        .x(x), .y(y),
        .a(a_idx), .d(d_idx), .s(s_idx), .r(r_idx),
        .t(eco_t), .fb(eco_fb), .mix(eco_mix), .bpm(bpm_idx),
        .sel(led_param),
        .hit(hud_hit), .rgb(hud_rgb)
    );

    reg [2:0] rgb_n;
    always @(*) begin
        if (~video_on)         rgb_n = 3'b000;
        else if (hud_hit)      rgb_n = hud_rgb;
        else if (trazo_activo) rgb_n = 3'b010;   // mezcla en verde
        else                   rgb_n = 3'b000;
    end

    // x cambia cada 2 ciclos de clk; la memoria responde 1 ciclo despues de recibir x.
    reg [9:0] x_d = 10'd0;
    reg       valido = 1'b0;
    always @(posedge clk) begin
        x_d    <= x;
        valido <= (x != x_d);        // 1 en el 2o ciclo de cada columna
        if (valido) rgb <= rgb_n;
    end
endmodule
