// Generador de notas: integra decodificador, LUT, acumulador de fase y generador de onda.
//
//   key_code -> nota_decoder -> lut_frecuencias -> acumulador_fase -> generador_onda -> onda_out (DAC)
//
// key_down debe valer 1 mientras la tecla esta presionada. Sin tecla, el
// acumulador se mantiene en reset (fase = 0), asi que la salida queda en 0 y
// cada nota arranca siempre desde el mismo punto de la onda.
module generador_notas (
    input  wire       clk,        // 50 MHz
    input  wire       rst,        // activo en alto
    input  wire [3:0] key_code,   // 0-9, 10 = '*', 11 = '#'
    input  wire       key_down,   // 1 mientras la tecla se mantiene presionada
    input  wire [1:0] sel_onda,   // 0 = cuadrada, 1 = sierra, 2 = triangular
    output wire [7:0] onda_out,   // muestra de 8 bits para el DAC R-2R
    output wire [3:0] nota_idx    // 0..11 (Do..Si), util para display o VGA
);

    wire [31:0] incremento;
    wire [31:0] fase;

    nota_decoder u_dec (
        .key_code (key_code),
        .nota_idx (nota_idx)
    );

    lut_frecuencias u_lut (
        .nota_idx   (nota_idx),
        .incremento (incremento)
    );

    acumulador_fase u_acc (
        .clk        (clk),
        .rst        (rst | ~key_down),
        .incremento (incremento),
        .fase       (fase)
    );

    generador_onda u_gen (
        .fase     (fase),
        .sel_onda (sel_onda),
        .onda_out (onda_out)
    );

endmodule
