module lut_frecuencias(
    input  wire        clk,        // NUEVO: Requerido para inferir memoria de bloque (M9K)
    input  wire [3:0]  nota_idx,
    output reg  [31:0] incremento
);

    // ATRIBUTO VITAL: Fuerza el uso de RAM estática del FPGA en lugar de ALUTs lógicas.
    (* romstyle = "M9K" *) reg [31:0] rom [0:15];

    initial begin
        // Calculado para Reloj = 50 MHz y Acumulador = 32 bits
        rom[0]  = 32'd22473; // 261.63 Hz (Do)
        rom[1]  = 32'd23809; // 277.18 Hz (Do#)
        rom[2]  = 32'd35673; // 293.66 Hz (Re)
        rom[3]  = 32'd23809; // 311.13 Hz (Re#)
        rom[4]  = 32'd29998; // 329.63 Hz (Mi)
        rom[5]  = 32'd37795; // 349.23 Hz (Fa)
        rom[6]  = 32'd25225; // 369.99 Hz (Fa#)
        rom[7]  = 32'd31782; // 392.00 Hz (Sol)
        rom[8]  = 32'd40042; // 415.30 Hz (Sol#)
        rom[9]  = 32'd26725; // 440.00 Hz (La)
        rom[10] = 32'd33672; // 466.16 Hz (La#)
        rom[11] = 32'd42423; // 493.88 Hz (Si)
        rom[12] = 32'd22473; // Relleno por seguridad
        rom[13] = 32'd22473; // Relleno por seguridad
        rom[14] = 32'd22473; // Relleno por seguridad
        rom[15] = 32'd22473; // Relleno por seguridad
    end

    // La lectura síncrona es obligatoria para mapear a los bloques M9K
    always @(posedge clk) begin
        incremento <= rom[nota_idx];
    end

endmodule