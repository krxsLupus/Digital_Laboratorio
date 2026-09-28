module sumador (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire suma,
    output wire cout
);

    assign suma = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));

endmodule