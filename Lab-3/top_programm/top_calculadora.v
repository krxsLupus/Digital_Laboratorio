module top_calculadora (
    input  wire       clk,           // Reloj de la FPGA (ej: 50 MHz en PIN_23)
    input  wire [3:0] A,             // Entrada A (4 switches)
    input  wire [3:0] B,             // Entrada B (4 switches)
    input  wire       Op,            // Switch de Operación (0: Suma, 1: Resta)
    output reg  [6:0] seg,           // Bus ÚNICO de segmentos a-g (PIN_127 al 119)
    output reg  [3:0] dig,           // Selección de dígito (PIN_133, 135, 136, 137)
    output wire       led_error      // LED de desbordamiento/error
);

    wire [4:0] S_raw;
    wire       signo_net;
    wire       error_net;
    wire [3:0] mag_net;
    wire [3:0] decenas_bcd;
    wire [3:0] unidades_bcd;

    wire [6:0] seg_unidades;
    wire [6:0] seg_decenas;
    wire [6:0] seg_signo;

    sumador_restador u_sum_rest (
        .A(A),
        .B(B),
        .Op(Op),
        .S(S_raw)
    );

    detector_signo u_det_signo (
        .S(S_raw),
        .Op(Op),
        .signo(signo_net),
        .error(error_net),
        .mag(mag_net)
    );

    bin_bcd u_bin_bcd (
        .mag(mag_net),
        .decenas(decenas_bcd),
        .unidades(unidades_bcd)
    );

    // Decodificador de 7 Segmentos para Unidades
    bcd_7s u_disp_unidades (
        .digito(unidades_bcd),
        .seg(seg_unidades)
    );

    // Decodificador de 7 Segmentos para Decenas
    bcd_7s u_disp_decenas (
        .digito(decenas_bcd),
        .seg(seg_decenas)
    );

    // Generación del patrón del segmento para el Signo ('-' si es negativo, apaga todo si positivo)
    assign seg_signo = (signo_net) ? 7'b011_1111 : 7'b111_1111;
    assign led_error = error_net;
	 
	 
    reg [16:0] clk_div = 17'd0;
    
    // Contado constante para reducir los 50MHz a ~380Hz de refresco por display
    always @(posedge clk) begin
        clk_div <= clk_div + 1'b1;
    end

    wire [1:0] selector_display = clk_div[16:15]; // Usamos los 2 bits más significativos

    // Máquina de multiplexado: conmuta rápidamente qué datos y qué display activar
    always @(*) begin
        case (selector_display)
            2'b00: begin
                dig = 4'b1110;          // Activa Display 1 (Unidades)
                seg = seg_unidades;
            end
            2'b01: begin
                dig = 4'b1101;          // Activa Display 2 (Decenas)
                seg = seg_decenas;
            end
            2'b10: begin
                dig = 4'b1011;          // Activa Display 3 (Signo)
                seg = seg_signo;
            end
            2'b11: begin
                dig = 4'b0111;          // Display 4 (Apagado / No usado)
                seg = 7'b111_1111;
            end
            default: begin
                dig = 4'b1111;
                seg = 7'b111_1111;
            end
        endcase
    end

endmodule