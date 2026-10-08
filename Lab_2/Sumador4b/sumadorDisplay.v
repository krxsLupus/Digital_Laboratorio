module sumadorDisplay (
    input  [3:0] sw_a,         // DIP Switches 1 a 4
    input  [3:0] sw_b,         // DIP Switches 5 a 8
    input        sel,          // Selector (0 = Suma, 1 = Resta)
    output [6:0] display,      // Segmentos A-G
    output [3:0] dig_sel,      // Selección del dígito activo
    output       led_carryOut, // LED indicador para acarreo
    output [3:0] resultado_led // Salida hacia los LEDs físicos
);

    wire [3:0] w_resultado;

    assign dig_sel = 4'b1110;
    assign resultado_led = ~w_resultado; // Inversión para LEDs con lógica Active-LOW

    sumador_restador4b uut_adder (
        .a(sw_a),
        .b(sw_b),
        .sel(sel),
        .resultado(w_resultado),
        .carryOut(led_carryOut)
    );

    hex7seg uut_display (
        .num(w_resultado),
        .seg(display)
    );

endmodule