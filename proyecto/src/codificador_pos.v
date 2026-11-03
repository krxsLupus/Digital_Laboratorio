// Maps a 4-bit position command to a 1-2 ms servo pulse at 50 Hz.
module codificador_pos #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer W = 20
)(
    input  wire [3:0]   pos,
    output wire [W-1:0] t_on
);
    localparam integer T_MIN = CLK_FREQ / 1000; // 1 ms
    localparam integer T_MAX = CLK_FREQ / 500;  // 2 ms
    localparam integer PASO  = (T_MAX - T_MIN) / 15;
    wire [31:0] t_on_full = (pos == 4'd15) ? T_MAX : (T_MIN + pos * PASO);
    assign t_on = t_on_full[W-1:0];
endmodule
