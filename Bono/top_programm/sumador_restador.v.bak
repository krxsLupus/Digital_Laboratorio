module sumador_restador (
    input  wire [3:0] A,
    input  wire [3:0] B,
    input  wire       Op,   
    output wire [4:0] S     //5 bits: el más significativo es el signo, los otros 4 son el resultado
);
    wire [3:0] B_xor; //nueva variable para guardar el complemento a 1 de B

    assign B_xor = B ^ {4{Op}}; //complemento a 1 de B con Op

    assign S = A + B_xor + Op; //suma de A y B o su complemento a 1 y +1 si Op = 1

endmodule