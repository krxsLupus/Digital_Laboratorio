module generador_onda(
    input  wire [31:0] fase,
    input  wire [1:0]  sel_onda, // 0 cuadrada, 1 sierra, 2 triangular, 3 seno
    output reg  [7:0]  onda_out
);
    wire [7:0] cuadrada = fase[31] ? 8'd255 : 8'd0;
    wire [7:0] sierra   = fase[31:24];

    // Triangular optimizada: asegura simetria exacta en los extremos (0 a 255) sin offset.
    wire [7:0] tri_base   = fase[30:23];
    wire [7:0] triangular = fase[31] ? ~tri_base : tri_base;

    // Seno: un cuarto de ciclo en la LUT, reflejado
    wire [5:0] idx_seno = fase[30] ? ~fase[29:24] : fase[29:24];
    wire [6:0] mag_seno;
    
    // Nota: Asegúrate de que seno_lut también tenga (* romstyle = "M9K" *) internamente.
    seno_lut u_seno (.idx(idx_seno), .mag(mag_seno));
    
    wire [7:0] seno = fase[31] ? (8'd128 - mag_seno) : (8'd128 + mag_seno);

    always @(*) begin
        case (sel_onda)
            2'd0: onda_out = cuadrada;
            2'd1: onda_out = sierra;
            2'd2: onda_out = triangular;
            2'd3: onda_out = seno;
        endcase
    end
endmodule