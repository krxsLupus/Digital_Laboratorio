module controlTermicoDisplay (
    input  [3:0] sw_t,         // Temperatura medida desde DIP switches
    input  [3:0] sw_l,         // Temperatura objetivo desde DIP switches
    input        sw_sel,       // Selector: 1 = resta (T - L), 0 = suma (T + L)
    output [6:0] display,      // Pines hacia el display de 7 segmentos
    output [3:0] dig_sel,
    output       led_carryOut, // LED para el carryOut
    output       led_perfect,  // LED condición ideal (R = 0)
    output       led_process,  // LED en fabricación (R < 0)
    output       led_burn      // LED producto quemado (R > 0)
);
    wire [3:0] w_r;
    assign dig_sel = 4'b1110;

    control_termico uut_control (
        .t(sw_t),
        .l(sw_l),
        .sel(sw_sel),
        .perfectLed(led_perfect),
        .processLed(led_process),
        .burnLed(led_burn),
        .r(w_r),
        .carryOut(led_carryOut)
    );

    hex7seg uut_display (
        .num(w_r),
        .seg(display)
    );
endmodule
