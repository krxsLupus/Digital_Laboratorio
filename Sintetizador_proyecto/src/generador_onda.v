// ============================================================================
// MÓDULO GENERADOR DE FORMAS DE ONDA DIGITALES: Onda Cuadrada, Sierra y Triangular
// ============================================================================

module generador_onda (
    input  wire [31:0] fase,     // Fase de 32 bits proveniente del acumulador
    input  wire [1:0]  sel_onda, // Selector de onda: 0=Cuadrada, 1=Sierra, 2=Triangular
    output reg  [7:0]  onda_out  // Muestra de amplitud de 8 bits enviada al DAC
);

    // ------------------------------------------------------------------------
    // EXTRACTOR DE FASE con los 8 bits más significativos
    // ------------------------------------------------------------------------
    // Los 8 MSB recorren los valores 0 a 255 de forma lineal durante cada período
    wire [7:0] sierra = fase[31:24];
    
    // ------------------------------------------------------------------------
    // LÓGICA COMBINACIONAL DE GENERACIÓN DE ONDA
    // ------------------------------------------------------------------------
    always @(*) begin
        case (sel_onda)
            // 0: ONDA CUADRADA (Basada en el bit de signo / MSB)
            2'd0: onda_out = (fase[31]) ? 8'd255 : 8'd0;
            
            // 1: ONDA DIENTE DE SIERRA (Rampa lineal ascendente directa)
            2'd1: onda_out = sierra;
            
            // 2: ONDA TRIANGULAR (Inversión de bits en el semiciclo negativo)
            2'd2: onda_out = (fase[31]) ? ~sierra : sierra;
            
            // Caso por defecto (resguardo/silencio)
            default: onda_out = 8'd0;
        endcase
    end

endmodule