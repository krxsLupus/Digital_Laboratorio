module top_visualizer (
    input clk,             // Base clock from FPGA (e.g., 50MHz)
    input [3:0] rows,      // Connected to Row 1, Row 2, Row 3, Row 4
    output reg [2:0] cols, // Connected to Column 0, Column 1, Column 2
    output [6:0] seg,      // 7-segment LED output
    output [3:0] dig       // 7-segment digit enabler
);

    // 1. Clock Divider for Scanning (~760 Hz)
    // We slow down the clock so the mechanical switch has time to settle (built-in debounce)
    reg [15:0] scan_cnt = 0;
    wire scan_tick = (scan_cnt == 16'd0);
    
    always @(posedge clk) begin
        scan_cnt <= scan_cnt + 1'b1;
    end

    // 2. Column Sweeper (State Machine)
    reg [1:0] col_idx = 0;
    
    always @(posedge clk) begin
        if (scan_tick) begin
            col_idx <= (col_idx == 2) ? 0 : col_idx + 1;
            
            // Send a LOW signal to one column at a time
            case (col_idx)
                0: cols <= 3'b110; // Activate Column 0
                1: cols <= 3'b101; // Activate Column 1
                2: cols <= 3'b011; // Activate Column 2
                default: cols <= 3'b111;
            endcase
        end
    end

    // 3. Row Reader & Decoder
    reg [3:0] key_val = 0; // Stores the current pressed key
    
    always @(posedge clk) begin
        if (scan_tick) begin
            // Check Row 1
            if (~rows[0]) begin 
                if (cols == 3'b110) key_val <= 4'd1;
                if (cols == 3'b101) key_val <= 4'd2;
                if (cols == 3'b011) key_val <= 4'd3;
            end
            // Check Row 2
            else if (~rows[1]) begin 
                if (cols == 3'b110) key_val <= 4'd4;
                if (cols == 3'b101) key_val <= 4'd5;
                if (cols == 3'b011) key_val <= 4'd6;
            end
            // Check Row 3
            else if (~rows[2]) begin 
                if (cols == 3'b110) key_val <= 4'd7;
                if (cols == 3'b101) key_val <= 4'd8;
                if (cols == 3'b011) key_val <= 4'd9;
            end
            // Check Row 4
            else if (~rows[3]) begin 
                if (cols == 3'b110) key_val <= 4'hA; // * mapped to A
                if (cols == 3'b101) key_val <= 4'd0; // 0 mapped to 0
                if (cols == 3'b011) key_val <= 4'hB; // # mapped to B
            end
        end
    end

    // 4. Instantiate your existing 7-segment decoder
    bcd_7s display (
        .digito(key_val),
        .seg(seg)
    );

    // Turn on only the first digit of the display (assuming active low)
    assign dig = 4'b1110; 

endmodule