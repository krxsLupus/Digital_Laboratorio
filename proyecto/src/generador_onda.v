module generador_onda(
    input  wire [31:0] fase,
    input  wire [1:0]  sel_onda, // Controlado por el KY-040: 0 cuadrada, 1 sierra, 2 triangular, 3 seno
    output reg  [7:0]  onda_out
);
    // Tomamos los 8 bits más altos del acumulador (0 a 255)
    wire [7:0] sierra = fase[31:24];

    // Triangular de rango completo (0 a 255): usa los 8 bits siguientes al MSB.
    wire [7:0] tri_base = fase[30:23];

    // Seno: se guarda solo un cuarto de ciclo (seno_lut) y se refleja.
    //   fase[31]  = semiciclo (0 positivo, 1 negativo)
    //   fase[30]  = segundo cuarto del semiciclo -> se recorre la tabla al reves
    //   fase[29:24] = indice dentro del cuarto
    wire [5:0] idx_seno = fase[30] ? ~fase[29:24] : fase[29:24];
    wire [6:0] mag_seno;
    seno_lut u_seno (.idx(idx_seno), .mag(mag_seno));
    wire [7:0] seno = fase[31] ? (8'd128 - mag_seno) : (8'd128 + mag_seno);  // 1..255, centro 128

    always @(*) begin
        case(sel_onda)
            2'd0: onda_out = (fase[31]) ? 8'd255 : 8'd0;        // Cuadrada
            2'd1: onda_out = sierra;                            // Diente de sierra
            2'd2: onda_out = (fase[31]) ? ~tri_base : tri_base; // Triangular
            2'd3: onda_out = seno;                              // Sinusoidal
        endcase
    end
endmodule
