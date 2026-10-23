module generador_onda(
    input  wire [31:0] fase,
    input  wire [1:0]  sel_onda, // Controlado por el KY-040
    output reg  [7:0]  onda_out
);
    // Tomamos los 8 bits más altos del acumulador (0 a 255)
    wire [7:0] sierra = fase[31:24];
    
    always @(*) begin
        case(sel_onda)
            2'd0: onda_out = (fase[31]) ? 8'd255 : 8'd0;       // Cuadrada (0 o Máximo según el bit de signo)
            2'd1: onda_out = sierra;                           // Diente de sierra (rampa lineal)
            2'd2: onda_out = (fase[31]) ? ~sierra : sierra;    // Triangular (rampa que sube y baja)
            default: onda_out = 8'd0;
        endcase
    end
endmodule