module bcd_7s(
    input wire [3:0] digito,   // Digito a convertir (0 a 9)
    output wire [6:0] seg      // Salidas: seg[6]=g, seg[5]=f, ..., seg[0]=a
);

    assign seg[6] = (~digito[3] & ~digito[2] & ~digito[1]) | (digito[2] & digito[1] & digito[0]);  // g
    assign seg[5] = (~digito[3] & ~digito[2] & digito[0]) | (~digito[2] & digito[1]) | (digito[1] & digito[0]);    // f
    assign seg[4] = (digito[2] & ~digito[1]) | digito[0];  // e   
    assign seg[3] = (digito[2] & ~digito[1] & ~digito[0]) | (digito[2] & digito[1] & digito[0]) | (~digito[3] & ~digito[2] & ~digito[1] & digito[0]);    // d 
    assign seg[2] = (~digito[2] & digito[1] & ~digito[0]); // c  
    assign seg[1] = (digito[2] & ~digito[1] & digito[0]) | (digito[2] & digito[1] & ~digito[0]);   // b
    assign seg[0] = (digito[2] & ~digito[1] & ~digito[0]) | (~digito[3] & ~digito[2] & ~digito[1] & digito[0]); // a

endmodule