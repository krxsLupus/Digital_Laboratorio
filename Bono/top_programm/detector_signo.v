module detector_signo (
    input  wire [5:0] R,       
    output wire       signo,   // 0: +, 1: -
    output wire [4:0] mag      
);

    assign signo = R[5];
    assign mag = signo ? (~R[4:0] + 1'b1) : R[4:0];

endmodule