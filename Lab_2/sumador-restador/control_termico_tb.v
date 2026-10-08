`timescale 1ns/1ps

module control_termico_tb;
    reg [3:0] t, l;
    reg sel;
    wire perfectLed, processLed, burnLed;
    wire [3:0] r;
    wire carryOut;

    // Modelo de referencia (solo en el testbench, no forma parte del diseño)
    reg [2:0] esperado;      // {processLed, perfectLed, burnLed}
    integer i, j, k, errores;

    control_termico uut (
        .t(t), .l(l), .sel(sel),
        .perfectLed(perfectLed), .processLed(processLed), .burnLed(burnLed),
        .r(r), .carryOut(carryOut)
    );

    initial begin
        $dumpfile("simulacion_control.vcd");
        $dumpvars(0, control_termico_tb);
        $monitor("Tiempo = %0d ns | sel = %b, t = %2d, l = %2d | r = %2d, carryOut = %b | process = %b, perfect = %b, burn = %b",
                 $time, sel, t, l, r, carryOut, processLed, perfectLed, burnLed);

        // Parte 1: casos dirigidos (formas de onda)
        sel = 1;
        // T < L: 5 - 9 = -4 -> en proceso
        t = 4'd5;  l = 4'd9;  #20;
        // T < L: 0 - 15 = -15 -> en proceso
        t = 4'd0;  l = 4'd15; #20;
        // T = L: 9 - 9 = 0 -> condición ideal
        t = 4'd9;  l = 4'd9;  #20;
        // T = L: 0 - 0 = 0 -> condición ideal
        t = 4'd0;  l = 4'd0;  #20;
        // T > L: 12 - 9 = 3 -> quemado
        t = 4'd12; l = 4'd9;  #20;
        // T > L: 15 - 0 = 15 -> quemado
        t = 4'd15; l = 4'd0;  #20;
        // Modo suma (sel = 0): ningún LED debe encenderse
        sel = 0;
        // 0 + 0 = 0
        t = 4'd0;  l = 4'd0;  #20;
        // 9 + 7 = 16
        t = 4'd9;  l = 4'd7;  #20;

        // Parte 2: verificación exhaustiva de las 512 combinaciones (t, l, sel)
        $monitoroff;
        errores = 0;
        for (k = 0; k < 2; k = k + 1) begin
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    sel = k;
                    t = i;
                    l = j;
                    #10;
                    if (!sel)         esperado = 3'b000;
                    else if (i < j)   esperado = 3'b100;
                    else if (i == j)  esperado = 3'b010;
                    else              esperado = 3'b001;
                    if ({processLed, perfectLed, burnLed} !== esperado) begin
                        errores = errores + 1;
                        $display("ERROR sel=%b t=%0d l=%0d -> process=%b perfect=%b burn=%b (esperado %b)",
                                 sel, t, l, processLed, perfectLed, burnLed, esperado);
                    end
                end
            end
        end

        $display("Fin de la simulacion: %0d errores en 512 pruebas", errores);
        $finish;
    end

endmodule
