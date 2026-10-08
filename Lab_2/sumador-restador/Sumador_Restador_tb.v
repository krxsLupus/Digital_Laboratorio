`timescale 1ns / 1ps

module tb_sumador_restador4b;

    // Entradas al módulo bajo prueba (DUT)
    reg [3:0] a;
    reg [3:0] b;
    reg sel;

    // Salidas del módulo bajo prueba
    wire [3:0] resultado;
    wire carryOut;

    // Instancia del módulo a probar (Device Under Test)
    sumador_restador4b dut (
        .a(a),
        .b(b),
        .sel(sel),
        .resultado(resultado),
        .carryOut(carryOut)
    );

    initial begin
        // Generación de archivo VCD para visualizar formas de onda (Icarus / GTKWave)
        $dumpfile("tb_sumador_restador4b.vcd");
        $dumpvars(0, tb_sumador_restador4b);

        // Impresión en consola al cambiar cualquier señal
        $monitor("t=%0t ns | sel=%b | a=%d (%b) | b=%d (%b) || res=%d (%b) | carryOut=%b", 
                 $time, sel, a, a, b, b, resultado, resultado, carryOut);

        // -------------------------------------------------------------
        // 1. PRUEBAS DE SUMA (sel = 0)
        // -------------------------------------------------------------
        sel = 1'b0;

        // Caso 1: Suma simple sin acarreo (5 + 3 = 8)
        a = 4'd5; b = 4'd3; #10;

        // Caso 2: Cero más cero (0 + 0 = 0)
        a = 4'd0; b = 4'd0; #10;

        // Caso 3: Suma que genera desbordamiento de 4 bits (15 + 1 = 0, CarryOut = 1)
        a = 4'd15; b = 4'd1; #10;

        // -------------------------------------------------------------
        // 2. PRUEBAS DE RESTA (sel = 1)
        // -------------------------------------------------------------
        sel = 1'b1;

        // Caso 4: Resta con resultado positivo (9 - 4 = 5, CarryOut = 1 indica R >= 0)
        a = 4'd9; b = 4'd4; #10;

        // Caso 5: Resta con resultado igual a cero (6 - 6 = 0, CarryOut = 1)
        a = 4'd6; b = 4'd6; #10;

        // Caso 6: Resta con resultado negativo (3 - 5 = -2 en C2: 4'b1110 = 14, CarryOut = 0)
        a = 4'd3; b = 4'd5; #10;

        // Caso 7: Resta dando -1 (0 - 1 = -1 en C2: 4'b1111 = 15, CarryOut = 0)
        a = 4'd0; b = 4'd1; #10;

        $display("\nPruebas finalizadas con éxito.");
    end

endmodule