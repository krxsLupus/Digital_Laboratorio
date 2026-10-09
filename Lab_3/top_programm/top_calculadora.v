module top_calculadora (
    input wire clk, 
    input wire [3:0] A, 
    input wire [3:0] B, 
    input wire btn_sum,   // Pulsador para modo suma
    input wire btn_sub,   // Pulsador para modo resta
    output reg [6:0] seg, 
    output reg [3:0] dig, 
    output wire led_error, 	
    output wire led_signo
);

        reg Op_reg = 1'b0;

    
    always @(posedge clk) begin
        if (~btn_sum) 
            Op_reg <= 1'b0; // Cambiar a suma
        else if (~btn_sub) 
            Op_reg <= 1'b1; // Cambiar a resta
    end

    wire [4:0] S_raw;
    wire signo_net;
    wire error_net;
    wire [3:0] mag_net;
    wire [3:0] decenas_bcd;
    wire [3:0] unidades_bcd;

    wire [6:0] seg_unidades;
    wire [6:0] seg_decenas;
    wire [6:0] seg_signo;

    sumador_restador u_sum_rest (
        .A(A),
        .B(B),
        .Op(Op_reg),
        .S(S_raw)
    );

    detector_signo u_det_signo (
        .S(S_raw),
        .Op(Op_reg),
        .signo(signo_net),
        .error(error_net),
        .mag(mag_net)
    );

    bin_bcd u_bin_bcd (
        .mag(mag_net),
        .decenas(decenas_bcd),
        .unidades(unidades_bcd)
    );

    bcd_7s u_disp_unidades (
        .digito(unidades_bcd),
        .seg(seg_unidades)
    );

    bcd_7s u_disp_decenas (
        .digito(decenas_bcd),
        .seg(seg_decenas)
    );

    assign seg_signo = (signo_net) ? 7'b011_1111 : 7'b111_1111;
    assign led_error = ~error_net;
    assign led_signo = ~signo_net; // Se enciende = 0 si el signo es negativo

    reg [16:0] clk_div = 17'd0;
     
    always @(posedge clk) begin
        clk_div <= clk_div + 1'b1;
    end

    wire [1:0] selector_display = clk_div[16:15];

    always @(*) begin
        case (selector_display)
            2'b00: begin
                dig = 4'b1110; 
                seg = seg_unidades;
            end
            2'b01: begin
                dig = 4'b1101; 
                seg = seg_decenas;
            end
            2'b10: begin
                dig = 4'b1011; 
                seg = seg_signo;
            end
            2'b11: begin
                dig = 4'b0111; 
                seg = 7'b111_1111;
            end
            default: begin
                dig = 4'b1111;
                seg = 7'b111_1111;
            end
        endcase
    end
endmodule