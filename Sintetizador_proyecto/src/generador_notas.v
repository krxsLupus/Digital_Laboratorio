// ============================================================================
// MÓDULO GENERADOR DE NOTAS - NÚCLEO SINTETIZADOR DDS
// Descripción: Integra decodificación de notas, LUT de frecuencias, 
//              acumulador de fase y generador de formas de onda.
// ============================================================================

module generador_notas (
    input  wire       clk,        // Reloj del sistema a 50 MHz
    input  wire       rst,        // Reset general del sistema, activo en alto
    input  wire [3:0] key_code,   // Código de tecla del teclado (0-9, 10='*', 11='#')
    input  wire       key_down,   // Nivel alto mientras la tecla siga presionada
    input  wire [1:0] sel_onda,   // Tipo de onda: 0=Cuadrada, 1=Sierra, 2=Triangular
    output wire [7:0] onda_out,   // Muestra de amplitud digital de 8 bits para el DAC
    output wire [3:0] nota_idx    // Índice de nota (0..11) para visualización externa
);

    // ------------------------------------------------------------------------
    // CONEXIONES INTERNAS 
    // ------------------------------------------------------------------------
    wire [31:0] incremento; // Valor de paso de fase obtenido de la LUT
    wire [31:0] fase;       // Valor acumulado de fase instantánea de 32 bits

    // ------------------------------------------------------------------------
    // DECODIFICADOR DE TECLA A ÍNDICE DE NOTA
    // ------------------------------------------------------------------------
    // Mapea la tecla del teclado a un tono dentro de la escala musical
    nota_decoder u_dec (
        .key_code (key_code),
        .nota_idx (nota_idx)
    );

    // ------------------------------------------------------------------------
    // LOOK-UP TABLE DE FRECUENCIAS
    // ------------------------------------------------------------------------
    // Retorna la constante de incremento de fase asociada a la nota deseada
    lut_frecuencias u_lut (
        .nota_idx   (nota_idx),
        .incremento (incremento)
    );

    // ------------------------------------------------------------------------
    // ACUMULADOR DE FASE
    // ------------------------------------------------------------------------
    // Suma continuamente 'incremento' al contador de fase en cada pulso de reloj.
    // El reset se activa con el rst global O cuando no hay tecla presionada (~key_down).
    acumulador_fase u_acc (
        .clk        (clk),
        .rst        (rst | ~key_down), // Mantiene la fase en 0 mientras no haya pulso de tecla
        .incremento (incremento),
        .fase       (fase)
    );

    // ------------------------------------------------------------------------
    // GENERADOR DE FORMA DE ONDA
    // ------------------------------------------------------------------------
    // Mapea la fase lineal acumulada al perfil de amplitud de la onda seleccionada
    generador_onda u_gen (
        .fase     (fase),
        .sel_onda (sel_onda),
        .onda_out (onda_out)
    );

endmodule