`timescale 1ns/1ps
module tb_pwm_servo;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [3:0] pos = 4'd0;
    wire pwm;
    integer cycles;
    integer high_count;

    always #10 clk = ~clk;

    // 50 kHz model clock => 1,000-cycle PWM period, high interval about 50-100 cycles.
    pwm_servo #(.CLK_FREQ(50_000)) dut (
        .clk(clk), .rst(rst), .pos(pos), .pwm(pwm)
    );

    initial begin
        $dumpfile("tb_pwm_servo.vcd");
        $dumpvars(0, tb_pwm_servo);
        repeat (3) @(posedge clk);
        rst <= 1'b0;
        pos <= 4'd0;
        repeat (1100) @(posedge clk);
        high_count = 0;
        for (cycles = 0; cycles < 1000; cycles = cycles + 1) begin
            @(posedge clk);
            if (pwm) high_count = high_count + 1;
        end
        if (high_count < 45 || high_count > 60) begin
            $display("FAIL: position 0 expected about 50 high cycles, got %0d", high_count);
            $finish;
        end
        pos <= 4'd15;
        repeat (1100) @(posedge clk);
        high_count = 0;
        for (cycles = 0; cycles < 1000; cycles = cycles + 1) begin
            @(posedge clk);
            if (pwm) high_count = high_count + 1;
        end
        if (high_count < 90 || high_count > 110) begin
            $display("FAIL: position 15 expected about 100 high cycles, got %0d", high_count);
            $finish;
        end
        $display("PASS: servo PWM smoke test; min=%0d max=%0d cycles", 50, 100);
        $finish;
    end
endmodule
