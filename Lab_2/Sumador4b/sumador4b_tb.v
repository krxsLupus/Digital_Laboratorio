`timescale 1ns/1ps

module sumador4b_tb;
    reg [3:0] a, b;
    reg carryIn;
    wire [3:0] suma;
    wire carryOut;

    sumador4b uut (
        .a(a), .b(b), .carryIn(carryIn), .suma(suma), .carryOut(carryOut)
    );

    initial begin
        $dumpfile("simulacion.vcd");
        $dumpvars(0, sumador4b_tb);
        // 1+2+0=3
        a = 4'b0001; b = 4'b0010; carryIn = 0; #20;
        // 2+3+0=5
        a = 4'b0010; b = 4'b0011; carryIn = 0; #20;
        // 3+5+0=8
        a = 4'b0011; b = 4'b0101; carryIn = 0; #20;
        // 5+6+0=11
        a = 4'b0101; b = 4'b0110; carryIn = 0; #20;
        // 6+8+0=14
        a = 4'b0110; b = 4'b1000; carryIn = 0; #20;
        // 8+10+0=18
        a = 4'b1000; b = 4'b1010; carryIn = 0; #20;
        // 10+13=23
        a = 4'b1010; b = 4'b1101; carryIn = 0; #20;

        // 6+8+1=15
        a = 4'b0110; b = 4'b1000; carryIn = 1; #20;
        // 8+10+1=19
        a = 4'b1000; b = 4'b1010; carryIn = 1; #20;
        // 15+13+1=29
        a = 4'b1111; b = 4'b1101; carryIn = 1; #20;
        
    end
endmodule
