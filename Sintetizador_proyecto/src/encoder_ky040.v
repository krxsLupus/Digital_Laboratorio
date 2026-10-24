// ============================================================================
// CONTROLADOR DE ENCODER ROTATIVO KY-040 CON FILTRO DE HISTÉRESIS Y SELECCIÓN CÍCLICA
// ============================================================================

module encoder_ky040 (
    input  wire       clk,        // Reloj principal a 50 MHz
    input  wire       rst,        // Reset síncrono, activo en alto
    input  wire       pin_a,      // Canal A (CLK del encoder)
    input  wire       pin_b,      // Canal B (DT del encoder)
    output reg  [1:0] sel_onda    // Selector de onda: 0=Cuadrada, 1=Sierra, 2=Triangular
);

    // ------------------------------------------------------------------------
    // DIVISOR DE RELOJ - GENERADOR DE TICK (1 ms)
    // ------------------------------------------------------------------------
    reg [15:0] timer = 16'd0;
    
    // Genera un pulso en alto de 1 ciclo cuando el contador alcanza 49,999
    wire tick = (timer == 16'd49999);
    
    always @(posedge clk) begin
        if (tick) 
            timer <= 16'd0;
        else      
            timer <= timer + 1'b1;
    end

    // ------------------------------------------------------------------------
    // REGISTROS DE DESPLAZAMIENTO
    // ------------------------------------------------------------------------
    reg [3:0] hist_a = 4'b1111;
    reg [3:0] hist_b = 4'b1111;
    
    // Desplaza e introduce el estado actual de los pines en cada tick de 1 ms
    always @(posedge clk) begin
        if (tick) begin
            hist_a <= {hist_a[2:0], pin_a};
            hist_b <= {hist_b[2:0], pin_b};
        end
    end

    // ------------------------------------------------------------------------
    // FILTRADO DE REBOTES POR CONSENSO 
    // ------------------------------------------------------------------------
    reg a_limpio = 1'b1;
    reg b_limpio = 1'b1;
    
    always @(posedge clk) begin
        // Cambia el estado filtrado solo si las 4 muestras son idénticas
        if (hist_a == 4'b0000)      a_limpio <= 1'b0;
        else if (hist_a == 4'b1111) a_limpio <= 1'b1;
        
        if (hist_b == 4'b0000)      b_limpio <= 1'b0;
        else if (hist_b == 4'b1111) b_limpio <= 1'b1;
    end

    // ------------------------------------------------------------------------
    // DETECCIÓN DE FLANCO Y CONTROL DE DIRECCIÓN
    // ------------------------------------------------------------------------
    reg a_prev = 1'b1;
    
    // Registro para detectar transiciones en la señal limpia del canal A
    always @(posedge clk) begin
        a_prev <= a_limpio;
    end
    
    // Pulso de 1 ciclo en el flanco de bajada de a_limpio (transición 1 -> 0)
    wire a_falling = (a_prev == 1'b1 && a_limpio == 1'b0);

    // Lógica del contador circular de 3 estados
    always @(posedge clk) begin
        if (rst) begin
            sel_onda <= 2'd0; // Estado por defecto: Onda Cuadrada
        end else if (a_falling) begin
            if (b_limpio == a_limpio) begin
                // Giro Horario: incrementa hasta 2 y reinicia a 0
                if (sel_onda < 2'd2) 
                    sel_onda <= sel_onda + 1'b1;
                else                 
                    sel_onda <= 2'd0;
            end else begin
                // Giro Antihorario: decrementa hasta 0 y salta a 2
                if (sel_onda > 2'd0) 
                    sel_onda <= sel_onda - 1'b1;
                else                 
                    sel_onda <= 2'd2;
            end
        end
    end

endmodule