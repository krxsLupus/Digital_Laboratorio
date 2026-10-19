`timescale 1ns / 1ps

module generador_PWM_tb;

    // --- Parámetros de simulación ---
    // Simulamos a la frecuencia real de 50 MHz (Reloj de 20 ns)
    parameter CLK_FREQ   = 50_000_000; 
    localparam CLK_PERIOD = 20; // 20 ns = 1 / 50 MHz

    // --- Señales de prueba (Entradas = reg, Salidas = wire) ---
    reg clk;
    reg rst;
    reg [3:0] sw;

    wire servo_pwm;

    // --- Instancia del Módulo Bajo Prueba (DUT) ---
    generador_PWM #(
        .CLK_FREQ(CLK_FREQ)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sw(sw),
        .servo_pwm(servo_pwm)
    );

    // --- Generación del Reloj (50 MHz) ---
    always begin
        #(CLK_PERIOD / 2) clk = ~clk; // Conmuta cada 10 ns
    end

    // --- Secuencia de Estímulos ---
    initial begin
        // Configuración para guardar ondas (Icarus Verilog / GTKWave)
        $dumpfile("generador_PWM_tb.vcd");
        $dumpvars(0, generador_PWM_tb);

        // 1. Estado inicial
        clk = 1'b0;
        rst = 1'b1; // Inicia en Reset
        sw  = 4'd0;

        // Esperar 100 ns en reset
        #100;
        rst = 1'b0; // Liberar reset
        $display("[%0t ns] Reset liberado. Iniciando prueba con pos = 0 (sw = 0000)...", $time);

        // 2. Probar pos = 0 (Ancho de pulso esperado: 1 ms | Periodo: 20 ms)
        // Esperamos 22 ms para ver al menos un ciclo completo de PWM
        #22_000_000;

        // 3. Probar pos = 8 (Valor intermedio, pulso esperado: ~1.53 ms)
        sw = 4'd8;
        $display("[%0t ns] Cambiando a pos = 8 (sw = 1000)...", $time);
        #22_000_000;

        // 4. Probar pos = 15 (Ancho de pulso esperado: 2 ms)
        sw = 4'd15;
        $display("[%0t ns] Cambiando a pos = 15 (sw = 1111)...", $time);
        #22_000_000;

        // Finalizar la simulación
        $display("[%0t ns] Simulación completada con éxito.", $time);
        $finish;
    end

endmodule