module nota_decoder(
    input  wire [3:0] key_code,
    output reg  [3:0] nota_idx
);
    // Mapeo: 1=Do, 2=Do#, 3=Re, 4=Re#, 5=Mi, 6=Fa, 7=Fa#, 8=Sol, 9=Sol#, *=La, 0=La#, #=Si
    always @(*) begin
        case(key_code)
            4'd1:  nota_idx = 4'd0;  // Do  (C4)
            4'd2:  nota_idx = 4'd1;  // Do# 
            4'd3:  nota_idx = 4'd2;  // Re  (D4)
            4'd4:  nota_idx = 4'd3;  // Re# 
            4'd5:  nota_idx = 4'd4;  // Mi  (E4)
            4'd6:  nota_idx = 4'd5;  // Fa  (F4)
            4'd7:  nota_idx = 4'd6;  // Fa# 
            4'd8:  nota_idx = 4'd7;  // Sol (G4)
            4'd9:  nota_idx = 4'd8;  // Sol#
            4'd10: nota_idx = 4'd9;  // La  (A4)  <- Tecla *
            4'd0:  nota_idx = 4'd10; // La#       <- Tecla 0
            4'd11: nota_idx = 4'd11; // Si  (B4)  <- Tecla #
            default: nota_idx = 4'd0;
        endcase
    end
endmodule