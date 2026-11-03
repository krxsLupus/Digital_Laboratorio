// First integration top for Slave: REMIX.
// NOTE: assign all physical pins in Quartus only after verifying your board schematic.
module top_remix (
    input  wire       CLK_50,
    input  wire       RESET_N,
    input  wire [3:0] KEY_COL,
    output wire [3:0] KEY_ROW,
    input  wire [7:0] SW,
    output wire [7:0] LED,
    output wire       SERVO_PWM
);
    wire rst = ~RESET_N;

    wire [3:0] key_code;
    wire       key_valid;
    reg  [3:0] note_index = 4'd0;
    reg        note_selected = 1'b0;

    wire [1:0] wave_sel = SW[2:1];
    wire       note_on  = SW[0] & note_selected;
    wire [3:0] servo_pos = SW[6:3];
    wire [7:0] audio_sample;

    teclado #(
        .CLK_FREQ(50_000_000),
        .DEB_MS(10)
    ) u_teclado (
        .clk(CLK_50),
        .rst(rst),
        .cols(KEY_COL),
        .rows(KEY_ROW),
        .key_code(key_code),
        .key_valid(key_valid)
    );

    // The repository keypad maps keys 1..9, A, B, C to codes 1..12.
    // Codes 1..12 select C4..B4, respectively. Other keys are ignored here.
    always @(posedge CLK_50) begin
        if (rst) begin
            note_index    <= 4'd0;
            note_selected <= 1'b0;
        end else if (key_valid && key_code >= 4'd1 && key_code <= 4'd12) begin
            note_index    <= key_code - 4'd1;
            note_selected <= 1'b1;
        end
    end

    synth_voice #(.CLK_FREQ(50_000_000)) u_voice (
        .clk(CLK_50),
        .rst(rst),
        .note_on(note_on),
        .note_index(note_index),
        .wave_sel(wave_sel),
        .audio_sample(audio_sample)
    );

    // Servo PWM is independent from the synthesizer. Start with an external
    // servo power supply and common ground before attaching a real servo.
    pwm_servo #(.CLK_FREQ(50_000_000)) u_servo (
        .clk(CLK_50),
        .rst(rst),
        .pos(servo_pos),
        .pwm(SERVO_PWM)
    );

    // Debug LEDs: [3:0] selected note, [5:4] waveform, [6] note gate,
    // [7] oscillator's most-significant sample bit. This is not an audio output.
    assign LED[3:0] = note_selected ? note_index : 4'hF;
    assign LED[5:4] = wave_sel;
    assign LED[6]   = note_on;
    assign LED[7]   = audio_sample[7];
endmodule
