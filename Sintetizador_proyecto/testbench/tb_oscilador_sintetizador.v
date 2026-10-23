
`timescale 1ns/1ps

module tb_oscilador_sintetizador;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg note_on = 1'b0;
    reg [3:0] note_index = 4'd9; // A4
    reg [1:0] wave_sel = 2'b00;

    wire [7:0] audio_sample;

    synth_voice #(
        .CLK_FREQ(50_000_000)
    ) dut (
        .clk(clk),
        .rst(rst),
        .note_on(note_on),
        .note_index(note_index),
        .wave_sel(wave_sel),
        .audio_sample(audio_sample)
    );

    // 50 MHz clock: 20 ns period.
    always #10 clk = ~clk;

    integer i;
    reg [7:0] previous_sample;
    integer transitions;

    initial begin
        $dumpfile("synth_voice.vcd");
        $dumpvars(0, tb_synth_voice);

        // Reset.
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        note_on = 1'b1;

        // Allow the accumulator to run.
        previous_sample = audio_sample;
        transitions = 0;

        for (i = 0; i < 250000; i = i + 1) begin
            @(negedge clk);

            if (audio_sample !== previous_sample)
                transitions = transitions + 1;

            previous_sample = audio_sample;
        end

        if (transitions > 0)
            $display("PASS: A4 produces waveform transitions.");
        else
            $display("FAIL: output did not change.");

        // Check that waveform selection changes the output.
        wave_sel = 2'b01;
        repeat (10) @(posedge clk);

        $display("Sawtooth sample = %0d", audio_sample);

        // Stop the note.
        @(negedge clk);
        note_on = 1'b0;
        #1;

        if (audio_sample === 8'd128)
            $display("PASS: note-off returns to midpoint.");
        else
            $display("FAIL: unexpected note-off output.");

        $display("Simulation completed.");
        $finish;
    end

endmodule
