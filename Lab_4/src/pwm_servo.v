module pwm_servo #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [3:0] pos,
    output reg        pwm = 1'b0
);

    localparam integer PERIODO = CLK_FREQ / 50;        
    localparam integer CNT_W   = $clog2(PERIODO);      

    reg  [CNT_W-1:0] contador = 0;
    reg  [3:0]       pos_r    = 4'd0;
    wire [CNT_W-1:0] t_on;

    codificador_pos #(.CLK_FREQ(CLK_FREQ), .W(CNT_W)) u_cod (
        .pos (pos_r),
        .t_on(t_on)
    );

    // Comparador de reinicio
    wire fin_periodo = (contador == PERIODO - 1);

    // Contador de periodo
    always @(posedge clk) begin
        if (rst || fin_periodo) contador <= 0;
        else                    contador <= contador + 1'b1;
    end

    // Posicion actualiza al iniciar periodo
    always @(posedge clk) begin
        if (rst)              pos_r <= 4'd0;
        else if (fin_periodo) pos_r <= pos;
    end

    // Comparador PWM 
    always @(posedge clk) begin
        if (rst) pwm <= 1'b0;
        else     pwm <= (contador < t_on);
    end

endmodule
