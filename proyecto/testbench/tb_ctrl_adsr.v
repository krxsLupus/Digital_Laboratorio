`timescale 1ns/1ps
// Testbench de ctrl_adsr: giro del encoder (sube/baja, topes) y pulsador de seleccion.
// Uso en Questa:  vsim work.tb_ctrl_adsr ; run -all
module tb_ctrl_adsr;
    reg clk = 0, rst = 1, enc_a = 1, enc_b = 1, btn = 1;   // pulsador activo en bajo
    wire [3:0] a_idx, d_idx, s_idx, r_idx, valor;
    wire [1:0] sel;
    always #10 clk = ~clk;

    ctrl_adsr #(.ACTIVO_BAJO(1)) uut (
        .clk(clk), .rst(rst), .enc_a(enc_a), .enc_b(enc_b), .btn(btn),
        .a_idx(a_idx), .d_idx(d_idx), .s_idx(s_idx), .r_idx(r_idx), .sel(sel), .valor(valor)
    );

    integer errores = 0, i;
    task check;
        input cond;
        input [8*40-1:0] nombre;
        begin
            if (!cond) begin $display("FALLA  %0s", nombre); errores = errores + 1; end
            else       $display("ok     %0s", nombre);
        end
    endtask

    // Un paso horario: B baja antes que A (b_limpio == a_limpio en el flanco de A)
    task paso_horario;
        begin
            enc_b = 0; #6_000_000; enc_a = 0; #6_000_000;
            enc_b = 1; #6_000_000; enc_a = 1; #6_000_000;
        end
    endtask
    // Un paso antihorario: A baja antes que B
    task paso_antihorario;
        begin
            enc_a = 0; #6_000_000; enc_b = 0; #6_000_000;
            enc_a = 1; #6_000_000; enc_b = 1; #6_000_000;
        end
    endtask
    task pulsar;
        begin btn = 0; #15_000_000; btn = 1; #15_000_000; end
    endtask

    initial begin
        repeat (10) @(posedge clk); rst = 0;
        #12_000_000;
        check(a_idx == 3 && d_idx == 8 && s_idx == 12 && r_idx == 8 && sel == 0, "valores iniciales A3 D8 S12 R8");

        paso_horario;
        check(a_idx == 4 && d_idx == 8, "horario sube A (sel = A)");
        paso_antihorario; paso_antihorario;
        check(a_idx == 2, "antihorario baja A");

        pulsar;
        check(sel == 1 && valor == d_idx, "pulsador: sel = D");
        paso_horario;
        check(d_idx == 9 && a_idx == 2, "el encoder edita D");

        pulsar; pulsar;
        check(sel == 3 && valor == r_idx, "dos pulsaciones: sel = R");
        pulsar;
        check(sel == 0, "sel vuelve a A");

        // topes: A baja hasta 0 y se queda
        for (i = 0; i < 4; i = i + 1) paso_antihorario;
        check(a_idx == 0, "tope inferior en 0");

        // rebote del pulsador: 3 rebotes cortos no deben contar
        btn = 0; #50_000; btn = 1; #50_000; btn = 0; #50_000; btn = 1; #20_000_000;
        check(sel == 0, "rebotes cortos ignorados");

        $display("");
        if (errores == 0) $display("tb_ctrl_adsr: TODO OK"); else $display("tb_ctrl_adsr: %0d FALLAS", errores);
        $finish;
    end
endmodule
