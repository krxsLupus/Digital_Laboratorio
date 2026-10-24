// ============================================================================
// MÓDULO ACUMULADOR DE FASE
// Descripción: Genera la rampa de fase digital de 32 bits incrementando
//              su valor en cada ciclo de reloj según el paso especificado.
// ============================================================================

module acumulador_fase (
    input  wire        clk,        // Reloj del sistema a 50 MHz
    input  wire        rst,        // Reset, activo en alto, o cuando ~key_down
    input  wire [31:0] incremento, // Palabra de sintonía de frecuencia 
    output reg  [31:0] fase        // Valor instantáneo de la fase de 0 a 2^32 - 1
);

    // Registro secuencial sensible al flanco de subida del reloj
    always @(posedge clk) begin
        if (rst) begin
            // Fuerza la fase a 0 si hay reset o no hay tecla presionada
            fase <= 32'd0;
        end else begin
            // Suma acumulativa con desbordamiento automático en 2^32
            fase <= fase + incremento;
        end
    end

endmodule