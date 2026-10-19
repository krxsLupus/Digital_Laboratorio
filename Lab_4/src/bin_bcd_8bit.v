module bin_bcd_8bit(
    input  wire [7:0] bin,
    output wire [3:0] centenas,
    output wire [3:0] decenas,
    output wire [3:0] unidades
);

    // Como el máximo es 180, las centenas solo pueden ser 0 o 1.
    assign centenas = (bin >= 8'd100) ? 4'd1 : 4'd0;
    
    // Resto para calcular decenas y unidades
    wire [7:0] resto = (bin >= 8'd100) ? (bin - 8'd100) : bin;

    assign decenas = (resto >= 8'd90) ? 4'd9 :
                     (resto >= 8'd80) ? 4'd8 :
                     (resto >= 8'd70) ? 4'd7 :
                     (resto >= 8'd60) ? 4'd6 :
                     (resto >= 8'd50) ? 4'd5 :
                     (resto >= 8'd40) ? 4'd4 :
                     (resto >= 8'd30) ? 4'd3 :
                     (resto >= 8'd20) ? 4'd2 :
                     (resto >= 8'd10) ? 4'd1 : 4'd0;

    assign unidades = (resto - (decenas * 8'd10));

endmodule