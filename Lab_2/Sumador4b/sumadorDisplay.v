module sumadorDisplay (
    input  [3:0] sw_a,     // Entradas desde DIP switches
    input  [3:0] sw_b,     
    input        sw_carryIn,
    output [6:0] display,  // Pines hacia el display de 7 segmentos
	 output [3:0] dig_sel,
    output       led_carryOut  // LED para el carryOut
);
    wire [3:0] w_suma;
	 assign dig_sel = 4'b1110;

    sumador4b uut_adder (
        .a(sw_a),
        .b(sw_b),
        .carryIn(sw_carryIn),
        .suma(w_suma),
        .carryOut(led_carryOut)
    );

    hex7seg uut_display (
        .num(w_suma),
        .seg(display)
    );
endmodule