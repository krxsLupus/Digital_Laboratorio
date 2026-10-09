module sumador_restador (
    input  wire [3:0] A,
    input  wire [3:0] B,
    input  wire       negA,   // 1: se usa -A
    input  wire       negB,   // 1: se usa -B
    output wire [5:0] R       // complemento a 2 de 6 bits (rango -30..+30)
);
    // Se extiende a 6 bits para que -30 (-A-B con A=B=15) quepa con signo
    wire [5:0] A_xor = {2'b00, A} ^ {6{negA}};  // complemento a 1 de A si negA
    wire [5:0] B_xor = {2'b00, B} ^ {6{negB}};  // complemento a 1 de B si negB

    // +negA y +negB completan el complemento a 2 de cada operando
    assign R = A_xor + B_xor + negA + negB;

endmodule