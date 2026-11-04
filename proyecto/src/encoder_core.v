// Nucleo de un encoder KY-040: antirrebote (4 muestras de 1 ms) y direccion.
// Da un pulso de 1 ciclo en 'up' (giro horario) o en 'down' (antihorario) por
// cada paso. Misma logica que encoder_ky040 / encoder_volumen, sin el contador.
module encoder_core (
    input  wire clk,       // 50 MHz
    input  wire rst,       // activo en alto
    input  wire pin_a,     // CLK
    input  wire pin_b,     // DT
    output reg  up   = 1'b0,
    output reg  down = 1'b0
);

    reg [15:0] timer = 16'd0;
    wire tick = (timer == 16'd49999);
    always @(posedge clk) begin
        if (tick) timer <= 16'd0;
        else      timer <= timer + 1'b1;
    end

    reg [3:0] hist_a = 4'b1111;
    reg [3:0] hist_b = 4'b1111;
    always @(posedge clk) begin
        if (tick) begin
            hist_a <= {hist_a[2:0], pin_a};
            hist_b <= {hist_b[2:0], pin_b};
        end
    end

    reg a_limpio = 1'b1;
    reg b_limpio = 1'b1;
    always @(posedge clk) begin
        if (hist_a == 4'b0000)      a_limpio <= 1'b0;
        else if (hist_a == 4'b1111) a_limpio <= 1'b1;
        if (hist_b == 4'b0000)      b_limpio <= 1'b0;
        else if (hist_b == 4'b1111) b_limpio <= 1'b1;
    end

    reg a_prev = 1'b1;
    always @(posedge clk) a_prev <= a_limpio;
    wire a_falling = (a_prev == 1'b1 && a_limpio == 1'b0);

    always @(posedge clk) begin
        up   <= 1'b0;
        down <= 1'b0;
        if (!rst && a_falling) begin
            if (b_limpio == a_limpio) up   <= 1'b1;    // horario
            else                      down <= 1'b1;    // antihorario
        end
    end

endmodule
