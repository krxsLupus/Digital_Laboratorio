module sumador_restador4b (
    input wire [3:0] a,
    input wire [3:0] b,
    input wire sel,
    output wire [3:0] resultado,
    output wire carryOut
);

    wire [3:0] bXor;

    // XOR:  b invertido si sel = 1, igual si sel = 0 
    assign bXor[0] = b[0] ^ sel;
    assign bXor[1] = b[1] ^ sel;
    assign bXor[2] = b[2] ^ sel;
    assign bXor[3] = b[3] ^ sel;

    // sumador de 4 bits
    sumador4b sum_rest_inst (
        .a(a),
        .b(bXor),
        .carryIn(sel),        // se suma el 1 para el complemento a 2
        .suma(resultado),
        .carryOut(carryOut)
    );

endmodule