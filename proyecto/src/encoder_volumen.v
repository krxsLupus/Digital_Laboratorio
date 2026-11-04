// Encoder KY-040 para el volumen: 0 = silencio, 1..7 = de bajo a fuerte.
// Giro horario sube, antihorario baja. Se detiene en los extremos (no da la vuelta).
// Mismo antirrebote que encoder_ky040 (4 muestras de 1 ms).
module encoder_volumen #(
    parameter [2:0] INICIAL = 3'd6      // un nivel (6 dB) por debajo del maximo
)(
    input  wire       clk,      // 50 MHz
    input  wire       rst,      // activo en alto
    input  wire       pin_a,    // CLK
    input  wire       pin_b,    // DT
    output reg  [2:0] nivel = INICIAL
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
        if (rst) begin
            nivel <= INICIAL;
        end else if (a_falling) begin
            if (b_limpio == a_limpio) begin
                if (nivel < 3'd7) nivel <= nivel + 1'b1;   // horario: sube
            end else begin
                if (nivel > 3'd0) nivel <= nivel - 1'b1;   // antihorario: baja
            end
        end
    end

endmodule
