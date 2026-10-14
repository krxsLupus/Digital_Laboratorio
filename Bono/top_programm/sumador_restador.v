module sumador_restador (
    input  wire [3:0] A,
    input  wire [3:0] B,
    input  wire       negA,
    input  wire       negB,
    output wire [5:0] R
);
    wire [5:0] A_xor = {2'b00, A} ^ {6{negA}};
    wire [5:0] B_xor = {2'b00, B} ^ {6{negB}};
    assign R = A_xor + B_xor + negA + negB;

endmodule