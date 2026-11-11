module acumulador_fase(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] incremento,
    output reg  [31:0] fase
);
    always @(posedge clk) begin
        if (rst) begin
            fase <= 32'd0;
        end else begin
            fase <= fase + incremento;
        end
    end
endmodule