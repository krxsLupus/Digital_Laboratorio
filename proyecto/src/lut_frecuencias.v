module lut_frecuencias(
    input  wire [3:0]  nota_idx,
    output reg  [31:0] incremento
);
    // Calculado para Reloj = 50 MHz y Acumulador = 32 bits
    always @(*) begin
        case(nota_idx)
            4'd0:  incremento = 32'd22473; // 261.63 Hz (Do)
            4'd1:  incremento = 32'd23809; // 277.18 Hz (Do#)
            4'd2:  incremento = 32'd25225; // 293.66 Hz (Re)
            4'd3:  incremento = 32'd26725; // 311.13 Hz (Re#)
            4'd4:  incremento = 32'd28314; // 329.63 Hz (Mi)
            4'd5:  incremento = 32'd29998; // 349.23 Hz (Fa)
            4'd6:  incremento = 32'd31782; // 369.99 Hz (Fa#)
            4'd7:  incremento = 32'd33672; // 392.00 Hz (Sol)
            4'd8:  incremento = 32'd35673; // 415.30 Hz (Sol#)
            4'd9:  incremento = 32'd37795; // 440.00 Hz (La)
            4'd10: incremento = 32'd40042; // 466.16 Hz (La#)
            4'd11: incremento = 32'd42423; // 493.88 Hz (Si)
            default: incremento = 32'd22473;
        endcase
    end
endmodule