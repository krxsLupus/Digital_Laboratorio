module sumador1b (
    input wire a, 
    input wire b, 
    input wire carryIn,
    output wire suma, 
    output wire carryOut
);

    assign suma = a ^ b ^ carryIn;
    assign carryOut = (carryIn & (a ^ b)) | (a & b);

endmodule

