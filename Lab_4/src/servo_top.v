module servo_top #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [3:0] sw,
    output wire servo_pwm,
	 output reg  [6:0] seg,
	 output reg  [3:0] dig
);

    // Sincronizadores 
    reg [3:0] sw_s1  = 4'd0;
    reg [3:0] sw_s2  = 4'd0;
    reg       rst_s1 = 1'b1;
    reg       rst_s2 = 1'b1;

    always @(posedge clk) begin
        sw_s1  <= sw;
        sw_s2  <= sw_s1;
        rst_s1 <= rst;
        rst_s2 <= rst_s1;
    end

    pwm_servo #(.CLK_FREQ(CLK_FREQ)) u_pwm (
        .clk(clk),
        .rst(~rst_s2),
        .pos(sw_s2),
        .pwm(servo_pwm)
    );
	 
	 
    wire [7:0] angulo = sw_s2 * 8'd12;
    wire [3:0] centenas, decenas, unidades;
    wire [6:0] seg_c, seg_d, seg_u;

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
