// ============================================================================
// MÓDULO TRANSMISOR DE AUDIO DIGITAL PROTOCOLO I2S SOLO EMISIÓN / MASTER
// Descripción: Serializa muestras de audio de 16 bits con signo hacia el 
//              amplificador DAC MAX98357A (64 BCLKs por trama de audio stereo).
// ============================================================================

module i2s_tx (
    input  wire        clk,      // Reloj principal del sistema a 50 MHz
    input  wire        rst,      // Reset, activo en alto
    input  wire signed [15:0] sample, // Muestra de audio de 16 bits en complemento a dos
    output reg         bclk  = 1'b0, // Reloj de bit serie (3.125 MHz)
    output reg         lrclk = 1'b0, // Reloj de trama/canal (48.828 kHz: 0=Izquierdo, 1=Derecho)
    output reg         sdata = 1'b0  // Línea de datos serie de audio (DIN)
);

    // ------------------------------------------------------------------------
    // REGISTROS DE CONTROL Y TEMPORIZACIÓN
    // ------------------------------------------------------------------------
    reg [2:0]  div   = 3'd0;     // Divisor de reloj, genera toggle de bclk cada 8 ciclos
    reg [5:0]  k     = 6'd0;     // Contador de posiciones dentro de la trama (0..63)
    reg [31:0] shreg = 32'd0;    // Registro de desplazamiento para serializar 32 bits
    reg [15:0] s_reg = 16'd0;    // Buffer para retener la muestra durante el canal derecho

    // ------------------------------------------------------------------------
    // LÓGICA DE CONTROL Y GENERACIÓN DE SEÑALES I2S
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            div   <= 3'd0;
            bclk  <= 1'b0;  
            lrclk <= 1'b0;
            sdata <= 1'b0;
            k     <= 6'd0;
            shreg <= 32'd0;
            s_reg <= 16'd0;
        end else begin
            div <= div + 1'b1;
            
            // Genera el reloj BCLK dividiendo clk entre 16
            if (div == 3'd7) begin
                bclk <= ~bclk; // Conmuta el estado de BCLK
                
                // Transición ejecutada únicamente en el FLANCO DE BAJADA de BCLK
                if (bclk) begin
                    // Control de canal LRCK: 0 para bits 0..31 (Izquierdo), 1 para bits 32..63 (Derecho)
                    lrclk <= (k >= 6'd32);
                    
                    // Transmite siempre el bit más significativo actual del registro de desplazamiento
                    sdata <= shreg[31];
                    
                    if (k == 6'd0) begin
                        // Inicio de trama (Canal Izquierdo): Carga muestra fresca + 16 ceros de relleno
                        shreg <= {sample, 16'd0};
                        s_reg <= sample; // Congela la muestra para mantener simetría stereo
                    end else if (k == 6'd32) begin
                        // Mitad de trama (Canal Derecho): Carga la muestra retenida + ceros
                        shreg <= {s_reg, 16'd0};
                    end else begin
                        // En cualquier otro ciclo, desplaza los bits 1 posición a la izquierda
                        shreg <= {shreg[30:0], 1'b0};
                    end
                    
                    // Incrementa el contador de pulso de bit en la trama (mod 64 automático en 6 bits)
                    k <= k + 1'b1;
                end
            end
        end
    end

endmodule
