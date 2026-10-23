module servo_top #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire       clk,
    input  wire       rst,       // Pin 90
    input  wire [3:0] sw,        // Pines 64, 60, 59, 58
    output wire       servo_pwm, // Pin 49
    output reg  [6:0] seg,       // Pines 119 al 127
    output reg  [3:0] dig        // Pines 128, 129, 132, 133
);

    // =====================
    // 1. LÓGICA DEL MOTOR
    // =====================
    localparam PERIODO     = CLK_FREQ / 50;        // 20 ms
    localparam TON_MIN     = CLK_FREQ / 1000;      // 1 ms
    localparam TON_MAX     = CLK_FREQ / 500;       // 2 ms
    localparam PASO        = (TON_MAX - TON_MIN) / 15; 

    reg [19:0] contador_periodo = 20'd0;
    wire [19:0] t_on;

    always @(posedge clk) begin
        if (!rst) begin
            contador_periodo <= 20'd0;
        end else begin
            if (contador_periodo >= PERIODO - 1)
                contador_periodo <= 20'd0;
            else
                contador_periodo <= contador_periodo + 1'b1;
        end
    end

    assign t_on = TON_MIN + (sw * PASO);
    assign servo_pwm = (contador_periodo < t_on);


    // ==================
    // 2. Switch a Ánguloy
    // ==================
    wire [7:0] angulo = sw * 8'd12; // 0-15 ---> 0-180
    wire [3:0] centenas, decenas, unidades;
    wire [6:0] seg_c, seg_d, seg_u;

    // modulos display
    bin_bcd_8bit u_bcd_conv (
        .bin(angulo),
        .centenas(centenas),
        .decenas(decenas),
        .unidades(unidades)
    );
     
    bcd_7s u_disp_c (.digito(centenas), .seg(seg_c));
    bcd_7s u_disp_d (.digito(decenas),  .seg(seg_d));
    bcd_7s u_disp_u (.digito(unidades), .seg(seg_u));

    reg [15:0] clk_div = 16'd0;
    always @(posedge clk) begin
        clk_div <= clk_div + 1'b1;
    end

    wire [1:0] sel_disp = clk_div[15:14];

    always @(*) begin
        case (sel_disp)
            2'b00: begin
                dig = 4'b1110; 
                seg = seg_u;
            end
            2'b01: begin
                dig = 4'b1101; 
                seg = seg_d;
            end
            2'b10: begin
                dig = 4'b1011; 
                seg = (centenas == 4'd0) ? 7'b111_1111 : seg_c;
            end
            default: begin
                dig = 4'b1111; 
                seg = 7'b111_1111;
            end
        endcase
    end

endmodule