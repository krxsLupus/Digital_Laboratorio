`timescale 1ns / 1ps

module sumador_tb;

    // Registros para controlar las entradas de prueba
    reg a;
    reg b;
    reg cin;

    // Cables para leer las salidas del módulo
    wire suma;
    wire cout;

    // Instancia del sumador (UUT: Unit Under Test)
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