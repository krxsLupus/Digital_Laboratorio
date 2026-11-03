// Digital oscillator for Slave: REMIX.
// Sample output is unsigned 8-bit audio centered at 128 when note_on=0.
// CLK_FREQ defaults to the board's 50 MHz oscillator.
module synth_voice #(
    parameter integer CLK_FREQ = 50_000_000
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       note_on,
    input  wire [3:0] note_index, // 0=C4, 1=C#4, ... 11=B4
    input  wire [1:0] wave_sel,   // 00 square, 01 saw, 10 triangle, 11 narrow pulse
    output reg  [7:0] audio_sample
);
    reg [31:0] phase_acc = 32'd0;
    reg [31:0] phase_inc;

    // Return the 32-bit phase increment for a frequency specified in mHz.
    // phase_inc = frequency * 2^32 / sample_clock_frequency.
    function [31:0] make_phase_inc;
        input [31:0] freq_millihz;
        reg [63:0] numerator;
        reg [63:0] denominator;
        begin
            numerator   = freq_millihz * 64'd4294967296;
            denominator = CLK_FREQ * 64'd1000;
            make_phase_inc = numerator / denominator;
        end
    endfunction

    always @(*) begin
        case (note_index)
            4'd0:  phase_inc = make_phase_inc(32'd261630); // C4  261.63 Hz
            4'd1:  phase_inc = make_phase_inc(32'd277180); // C#4 277.18 Hz
            4'd2:  phase_inc = make_phase_inc(32'd293660); // D4  293.66 Hz
            4'd3:  phase_inc = make_phase_inc(32'd311130); // D#4 311.13 Hz
            4'd4:  phase_inc = make_phase_inc(32'd329630); // E4  329.63 Hz
            4'd5:  phase_inc = make_phase_inc(32'd349230); // F4  349.23 Hz
            4'd6:  phase_inc = make_phase_inc(32'd369990); // F#4 369.99 Hz
            4'd7:  phase_inc = make_phase_inc(32'd392000); // G4  392.00 Hz
            4'd8:  phase_inc = make_phase_inc(32'd415300); // G#4 415.30 Hz
            4'd9:  phase_inc = make_phase_inc(32'd440000); // A4  440.00 Hz
            4'd10: phase_inc = make_phase_inc(32'd466160); // A#4 466.16 Hz
            4'd11: phase_inc = make_phase_inc(32'd493880); // B4  493.88 Hz
            default: phase_inc = make_phase_inc(32'd261630);
        endcase
    end

    always @(posedge clk) begin
        if (rst || !note_on)
            phase_acc <= 32'd0;
        else
            phase_acc <= phase_acc + phase_inc;
    end

    always @(*) begin
        if (!note_on) begin
            audio_sample = 8'd128;
        end else begin
            case (wave_sel)
                2'b00: audio_sample = phase_acc[31] ? 8'd240 : 8'd16;
                2'b01: audio_sample = phase_acc[31:24];
                2'b10: audio_sample = phase_acc[31] ? ~phase_acc[30:23] : phase_acc[30:23];
                2'b11: audio_sample = (phase_acc[31:28] < 4'd2) ? 8'd240 : 8'd16;
                default: audio_sample = 8'd128;
            endcase
        end
    end
endmodule
