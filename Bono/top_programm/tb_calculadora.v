`timescale 1ns/1ps
module tb_calculadora;
    reg  [3:0] A, B;
    reg        negA, negB;
    wire [5:0] R;
    wire       signo;
    wire [4:0] mag;
    wire [3:0] dec, uni;

    sumador_restador u1 (.A(A), .B(B), .negA(negA), .negB(negB), .R(R));
    detector_signo   u2 (.R(R), .signo(signo), .mag(mag));
    bin_bcd          u3 (.mag(mag), .decenas(dec), .unidades(uni));

    integer a, b, m, esperado, errs;

    // Top completo con pulsadores
    reg clk = 0;
    always #10 clk = ~clk;
    reg k2 = 1, k3 = 1, k4 = 1, k5 = 1;
    reg [3:0] tA = 4'd9, tB = 4'd5;
    wire [6:0] seg;
    wire [3:0] dig;
    wire led_signo;
    top_calculadora dut (.clk(clk), .A(tA), .B(tB),
        .btn_ApB(k2), .btn_AmB(k3), .btn_nApB(k4), .btn_nAmB(k5),
        .seg(seg), .dig(dig), .led_signo(led_signo));

    task pulsa(input integer boton);
        begin
            case (boton)
                2: k2 = 0;
                3: k3 = 0;
                4: k4 = 0;
                5: k5 = 0;
            endcase
            #100;
            k2 = 1; k3 = 1; k4 = 1; k5 = 1;
            #100;
        end
    endtask

    initial begin
        errs = 0;
        for (m = 0; m < 4; m = m + 1)
            for (a = 0; a < 16; a = a + 1)
                for (b = 0; b < 16; b = b + 1) begin
                    A = a; B = b; negA = m[1]; negB = m[0];
                    #1;
                    esperado = (m[1] ? -a : a) + (m[0] ? -b : b);
                    if (signo !== (esperado < 0) ||
                        (dec * 10 + uni) !== ((esperado < 0) ? -esperado : esperado) ||
                        dec > 3 || uni > 9) begin
                        errs = errs + 1;
                        $display("ERROR modo=%0d A=%0d B=%0d esperado=%0d signo=%b dec=%0d uni=%0d",
                                 m, a, b, esperado, signo, dec, uni);
                    end
                end
        $display("Exhaustivo: 1024 combinaciones, errores = %0d", errs);

        // Botones -> modo (9 y 5)
        #50;
        if (dut.modo !== 2'b00) begin errs = errs + 1; $display("ERROR modo inicial"); end
        pulsa(3); if (dut.modo !== 2'b01 || led_signo !== 1'b1) begin errs = errs + 1; $display("ERROR K3: modo=%b led=%b", dut.modo, led_signo); end  // 9-5=+4
        pulsa(4); if (dut.modo !== 2'b10 || led_signo !== 1'b0) begin errs = errs + 1; $display("ERROR K4: modo=%b led=%b", dut.modo, led_signo); end  // -9+5=-4
        pulsa(5); if (dut.modo !== 2'b11 || led_signo !== 1'b0) begin errs = errs + 1; $display("ERROR K5: modo=%b led=%b", dut.modo, led_signo); end  // -9-5=-14
        pulsa(2); if (dut.modo !== 2'b00 || led_signo !== 1'b1) begin errs = errs + 1; $display("ERROR K2: modo=%b led=%b", dut.modo, led_signo); end  // 9+5=+14
        $display("Botones: errores totales = %0d", errs);
        $finish;
    end
endmodule