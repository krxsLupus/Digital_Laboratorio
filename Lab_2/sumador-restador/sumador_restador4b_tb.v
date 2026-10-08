`timescale 1ns/1ps

module sumador_restador4b_tb;
    reg [3:0] a, b;
    reg sel;
    wire [3:0] resultado;
    wire carryOut;

    // Modelo de referencia (solo en el testbench, no forma parte del diseño)
    reg [3:0] esperado;
    reg carryEsperado;
    integer i, j, k, errores;

    sumador_restador4b uut (
        .a(a), .b(b), .sel(sel), .resultado(resultado), .carryOut(carryOut)
    );

    initial begin
        $dumpfile("simulacion_restador.vcd");
        $dumpvars(0, sumador_restador4b_tb);
        $monitor("Tiempo = %0d ns | sel = %b, a = %2d, b = %2d | resultado = %2d, carryOut = %b",
                 $time, sel, a, b, resultado, carryOut);

        // Parte 1: casos dirigidos (formas de onda)
        // Suma (sel = 0)
        sel = 0;
        // 3+5=8
        a = 4'b0011; b = 4'b0101; #20;
        // 9+7=16 (acarreo)
        a = 4'b1001; b = 4'b0111; #20;
        // 15+15=30 (acarreo)
        a = 4'b1111; b = 4'b1111; #20;

        // Resta (sel = 1)
        sel = 1;
        // 9-4=5
        a = 4'b1001; b = 4'b0100; #20;
        // 7-5=2 (ejemplo de la guía)
        a = 4'b0111; b = 4'b0101; #20;
        // 5-5=0
        a = 4'b0101; b = 4'b0101; #20;
        // 3-7=-4 (1100 en complemento a 2, ejemplo de la guía)
        a = 4'b0011; b = 4'b0111; #20;
        // 0-15=-15 (0001 en complemento a 2)
        a = 4'b0000; b = 4'b1111; #20;
        // 15-0=15
        a = 4'b1111; b = 4'b0000; #20;

        // Parte 2: verificación exhaustiva de las 512 combinaciones (a, b, sel)
        $monitoroff;
        errores = 0;
        for (k = 0; k < 2; k = k + 1) begin
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    sel = k;
                    a = i;
                    b = j;
                    #10;
                    if (sel) begin
                        esperado = i - j;                  // resta módulo 16
                        carryEsperado = (i >= j);          // carryOut = 1 si a >= b
                    end else begin
                        {carryEsperado, esperado} = i + j; // suma con acarreo
                    end
                    if (resultado !== esperado || carryOut !== carryEsperado) begin
                        errores = errores + 1;
                        $display("ERROR sel=%b a=%0d b=%0d -> resultado=%0d carryOut=%b (esperado %0d, %b)",
                                 sel, a, b, resultado, carryOut, esperado, carryEsperado);
                    end
                end
            end
        end

        $display("Fin de la simulacion: %0d errores en 512 pruebas", errores);
        $finish;
    end

endmodule
