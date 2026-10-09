module bin_bcd(
    input  wire [4:0] mag,       // Magnitud absoluta (0..30)
    output wire [3:0] decenas,   // 0..3
    output wire [3:0] unidades   // 0..9
);

    assign decenas = (mag >= 5'd30) ? 4'd3 :
                     (mag >= 5'd20) ? 4'd2 :
                     (mag >= 5'd10) ? 4'd1 : 4'd0;

    wire [4:0] base = (mag >= 5'd30) ? 5'd30 :
                      (mag >= 5'd20) ? 5'd20 :
                      (mag >= 5'd10) ? 5'd10 : 5'd0;

    wire [4:0] resto = mag - base;
    assign unidades = resto[3:0];

endmodule