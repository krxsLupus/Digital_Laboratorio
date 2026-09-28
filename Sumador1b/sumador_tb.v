//test bench del sumador de 1bit en vscode, genera un archivo para poder visualizar todo en GTKwave

`timescale 1ns / 1ps

module sumador_tb;
    reg a;
    reg b;
    reg cin;
    wire suma;
    wire cout;

    sumador uut (
        .a(a),
        .b(b),
        .cin(cin),
        .suma(suma),
        .cout(cout)
    );

    initial begin
        // Crear archivo de ondas para GTKWave
        $dumpfile("sumador.vcd");
        $dumpvars(0, sumador_tb);

        // Probar las 8 combinaciones posibles con retardos de 10ns (#10)
        a = 0; b = 0; cin = 0; #10;
        a = 0; b = 0; cin = 1; #10;
        a = 0; b = 1; cin = 0; #10;
        a = 0; b = 1; cin = 1; #10;
        a = 1; b = 0; cin = 0; #10;
        a = 1; b = 0; cin = 1; #10;
        a = 1; b = 1; cin = 0; #10;
        a = 1; b = 1; cin = 1; #10;

        $finish;
    end

endmodule
