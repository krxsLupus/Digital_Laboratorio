module sumador4b (
    input wire [3:0] a,
    input wire [3:0] b,
    input wire carryIn,
    output wire [3:0] suma,
    output wire carryOut
);

    wire carry0, carry1, carry2;

    sumador1b bit0 (.a(a[0]), .b(b[0]), .carryIn(carryIn), .suma(suma[0]), .carryOut(carry0));
    sumador1b bit1 (.a(a[1]), .b(b[1]), .carryIn(carry0), .suma(suma[1]), .carryOut(carry1));
    sumador1b bit2 (.a(a[2]), .b(b[2]), .carryIn(carry1), .suma(suma[2]), .carryOut(carry2));
    sumador1b bit3 (.a(a[3]), .b(b[3]), .carryIn(carry2), .suma(suma[3]), .carryOut(carryOut));

endmodule