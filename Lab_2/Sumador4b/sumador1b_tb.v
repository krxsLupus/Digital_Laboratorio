`timescale 1ns/1ps

module sumador1b_tb;

    reg a;
    reg b;
    reg carryIn;

    wire suma;
    wire carryOut;

    sumador1b uut (
        .a(a),
        .b(b),
        .carryIn(carryIn),
        .suma(suma),
        .carryOut(carryOut)
    );

    initial begin
        $monitor("Tiempo = %0t ns | a = %b, b = %b, carryIn = %b | suma = %b, carryOut = %b", $time, a, b, carryIn, suma, carryOut);

        a = 0; b = 0; carryIn = 0; #10;
        a = 0; b = 0; carryIn = 1; #10;
        a = 0; b = 1; carryIn = 0; #10;
        a = 0; b = 1; carryIn = 1; #10;
        a = 1; b = 0; carryIn = 0; #10;
        a = 1; b = 0; carryIn = 1; #10;
        a = 1; b = 1; carryIn = 0; #10;
        a = 1; b = 1; carryIn = 1; #10;

        $finish;
    end

endmodule