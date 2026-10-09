module top_calculadora (
    input wire clk,
    input wire [3:0] A,
    input wire [3:0] B,
    input wire btn_ApB,    // K2 (PIN_90): A + B
    input wire btn_AmB,    // K3 (PIN_91): A - B
    input wire btn_nApB,   // K4 (PIN_87): -A + B
    input wire btn_nAmB,   // K5 (PIN_86): -A - B
    output reg [6:0] seg,
    output reg [3:0] dig,
    output wire led_signo
);

    // modo = {negA, negB}: 00 A+B | 01 A-B | 10 -A+B | 11 -A-B
    reg [1:0] modo = 2'b00;

    // Pulsadores activos en bajo; el modo se queda guardado hasta la siguiente pulsación
    always @(posedge clk) begin
        if      (~btn_ApB)  modo <= 2'b00;
        else if (~btn_AmB)  modo <= 2'b01;
        else if (~btn_nApB) modo <= 2'b10;
        else if (~btn_nAmB) modo <= 2'b11;
    end

    wire [5:0] R_raw;
    wire signo_net;
    wire [4:0] mag_net;
    wire [3:0] decenas_bcd;
    wire [3:0] unidades_bcd;

    wire [6:0] seg_unidades;
    wire [6:0] seg_decenas;
    wire [6:0] seg_signo;

    sumador_restador u_sum_rest (
        .A(A),
        .B(B),
        .negA(modo[1]),
        .negB(modo[0]),
        .R(R_raw)
    );

    detector_signo u_det_signo (
        .R(R_raw),
        .signo(signo_net),
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
    assign led_signo = ~signo_net; // Se enciende (= 0) si el signo es negativo

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