module control_termico (
    input wire [3:0] t,      // Temperatura medida
    input wire [3:0] l,      // Temperatura objetivo
    input wire sel,          // señal control seleccionada
    output wire perfectLed,  // salida Condición ideal
    output wire processLed,  // salida Fabricación (R < 0)
    output wire burnLed      // salida Quemado (R > 0)
);

    wire [3:0] r;            // Resultado
    wire carryOut;           // Carry Out

    // sumador/restador de 4 bits
    sumador_restador4b calc_temp_inst (
        .a(t),
        .b(l),
        .sel(sel),
        .resultado(r),
        .carryOut(carryOut)
    );

    // Lógica para encender LEDs según el teória:

    // R = 0: Condición ideal. El resultado de la resta es 0.
    assign perfectLed = (~r[3] & ~r[2] & ~r[1] & ~r[0]); 

    // R < 0: En proceso. Si el Carry Out es 0, el resultado es < 0.
    assign processLed = ~carryOut;

    // R > 0: Quemado. Si el Carry Out es 1 y no es condición ideal (R!=0).
    assign burnLed = carryOut & ~perfectLed;

endmodule