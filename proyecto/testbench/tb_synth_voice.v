`timescale 1ns/1ps
module tb_synth_voice;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg note_on = 1'b0;
    reg [3:0] note_index = 4'd9; // A4
    reg [1:0] wave_sel = 2'b00;
    wire [7:0] audio_sample;
    integer rising_edges = 0;

    always #10 clk = ~clk; // 50 MHz

    synth_voice #(.CLK_FREQ(50_000_000)) dut (
        .clk(clk), .rst(rst), .note_on(note_on),
        .note_index(note_index), .wave_sel(wave_sel),
        .audio_sample(audio_sample)
    );

    always @(posedge audio_sample[7]) rising_edges = rising_edges + 1;

    initial begin
        $dumpfile("tb_synth_voice.vcd");
        $dumpvars(0, tb_synth_voice);
        repeat (5) @(posedge clk);
        rst <= 1'b0;
        #1;
        if (audio_sample !== 8'd128) begin
            $display("FAIL: note-off sample is not centered at 128");
            $finish;
        end
        note_on <= 1'b1;
        repeat (500000) @(posedge clk); // 10 ms at 50 MHz
        if (rising_edges < 3 || rising_edges > 5) begin
            $display("FAIL: expected around 4-5 rising edges at A4, got %0d", rising_edges);
            $finish;
        end
        wave_sel <= 2'b01;
        repeat (100) @(posedge clk);
        if (audio_sample === 8'd128) begin
            $display("FAIL: sawtooth output unexpectedly stayed at midpoint");
            $finish;
        end
        note_on <= 1'b0;
        repeat (2) @(posedge clk);
        #1;
        if (audio_sample !== 8'd128) begin
            $display("FAIL: note-off did not return sample to 128");
            $finish;
        end
        $display("PASS: synth_voice smoke test; A4 transitions observed=%0d", rising_edges);
        $finish;
    end
endmodule
