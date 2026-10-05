module bin_bcd(
    input wire [3:0] mag,   // Magnitud absoluta
    output wire [3:0] decenas,
    output wire [3:0] unidades
);

    assign decenas  = (mag >= 4'd10) ? 4'd1 : 4'd0;
    assign unidades = (mag >= 4'd10) ? (mag - 4'd10) : mag;

endmodule