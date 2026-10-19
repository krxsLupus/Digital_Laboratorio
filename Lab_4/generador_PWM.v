module generador_PWM #(
    parameter CLK_FREQ = 50_000_000 // Frecuencia del reloj por defecto (50 MHz)
)(
    input wire clk,
    input wire rst,
    input wire [3:0] sw,   

    output wire servo_pwm
);

    localparam PERIODO     = CLK_FREQ / 50;        // Cuentas para 20 ms (1/50 seg)
    localparam TON_MIN     = CLK_FREQ / 1000;      // Cuentas para 1 ms (1/1000 seg)
    localparam TON_MAX     = CLK_FREQ / 500;       // Cuentas para 2 ms (1/500 seg)
    localparam PASO        = (TON_MAX - TON_MIN) / 15; // Incremento por cada paso de sw

    reg [19:0] contador_periodo;
    wire [19:0] t_on;


    always @(posedge clk) begin
        if (rst) begin
            contador_periodo <= 20'd0;  // Si rst = '1' el contador vuelve a 0
        end else begin
            if (contador_periodo >= PERIODO - 1)
                contador_periodo <= 20'd0;
            else
                contador_periodo <= contador_periodo + 1'b1;
        end
    end

    // Mapeo de sw[3:0] a tiempo en alto (cuentas)
    assign t_on = TON_MIN + (sw * PASO);

    // Comparador PWM
    assign servo_pwm = (contador_periodo < t_on);

endmodule