// Cuarto de ciclo de seno: 64 muestras, amplitud 0..127.
// mag(i) = round(127.5 * sin((i + 0.5) * pi / 128)), i = 0..63
// El 'case' se sintetiza como logica combinacional (no necesita memoria).
module seno_lut (
    input  wire [5:0] idx,
    output reg  [6:0] mag
);

(* ramstyle = "M9K" *) reg [7:0] mi_memoria [0:255];
    always @(*) begin
        case (idx)
            6'd0: mag = 7'd2;
            6'd1: mag = 7'd5;
            6'd2: mag = 7'd8;
            6'd3: mag = 7'd11;
            6'd4: mag = 7'd14;
            6'd5: mag = 7'd17;
            6'd6: mag = 7'd20;
            6'd7: mag = 7'd23;
            6'd8: mag = 7'd26;
            6'd9: mag = 7'd29;
            6'd10: mag = 7'd32;
            6'd11: mag = 7'd36;
            6'd12: mag = 7'd39;
            6'd13: mag = 7'd41;
            6'd14: mag = 7'd44;
            6'd15: mag = 7'd47;
            6'd16: mag = 7'd50;
            6'd17: mag = 7'd53;
            6'd18: mag = 7'd56;
            6'd19: mag = 7'd59;
            6'd20: mag = 7'd61;
            6'd21: mag = 7'd64;
            6'd22: mag = 7'd67;
            6'd23: mag = 7'd70;
            6'd24: mag = 7'd72;
            6'd25: mag = 7'd75;
            6'd26: mag = 7'd77;
            6'd27: mag = 7'd80;
            6'd28: mag = 7'd82;
            6'd29: mag = 7'd84;
            6'd30: mag = 7'd87;
            6'd31: mag = 7'd89;
            6'd32: mag = 7'd91;
            6'd33: mag = 7'd93;
            6'd34: mag = 7'd96;
            6'd35: mag = 7'd98;
            6'd36: mag = 7'd100;
            6'd37: mag = 7'd101;
            6'd38: mag = 7'd103;
            6'd39: mag = 7'd105;
            6'd40: mag = 7'd107;
            6'd41: mag = 7'd109;
            6'd42: mag = 7'd110;
            6'd43: mag = 7'd112;
            6'd44: mag = 7'd113;
            6'd45: mag = 7'd115;
            6'd46: mag = 7'd116;
            6'd47: mag = 7'd117;
            6'd48: mag = 7'd118;
            6'd49: mag = 7'd120;
            6'd50: mag = 7'd121;
            6'd51: mag = 7'd122;
            6'd52: mag = 7'd122;
            6'd53: mag = 7'd123;
            6'd54: mag = 7'd124;
            6'd55: mag = 7'd125;
            6'd56: mag = 7'd125;
            6'd57: mag = 7'd126;
            6'd58: mag = 7'd126;
            6'd59: mag = 7'd127;
            6'd60: mag = 7'd127;
            6'd61: mag = 7'd127;
            6'd62: mag = 7'd127;
            6'd63: mag = 7'd127;
            default: mag = 7'd0;
        endcase
    end
endmodule
