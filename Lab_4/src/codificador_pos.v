module codificador_pos #(
    parameter CLK_FREQ = 50_000_000, 
    parameter W        = 20            
)(
    input  wire [3:0]   pos,
    output wire [W-1:0] t_on           
);

    localparam integer T_MIN = CLK_FREQ / 1000;            
    localparam integer T_MAX = CLK_FREQ / 500;             
    localparam integer PASO  = (T_MAX - T_MIN) / 15;      

    assign t_on = (pos == 4'd15) ? T_MAX : (T_MIN + pos * PASO);

endmodule
