module encoder_ky040 (
    input  wire       clk,       // 50 MHz
    input  wire       rst,       // Activo en alto
    input  wire       pin_a,     // CLK
    input  wire       pin_b,     // DT
    output reg  [1:0] sel_onda   // 0=Cuadrada, 1=Sierra, 2=Triangular
);

    // 1. Divisor de reloj: genera un pulso (tick) cada ~1 milisegundo
    reg [15:0] timer = 16'd0;
    wire tick = (timer == 16'd49999);
    
    always @(posedge clk) begin
        if (tick) timer <= 16'd0;
        else      timer <= timer + 1'b1;
    end

    // 2. Registros de desplazamiento (Shift Registers) para historial de 4ms
    reg [3:0] hist_a = 4'b1111;
    reg [3:0] hist_b = 4'b1111;
    
    always @(posedge clk) begin
        if (tick) begin
            hist_a <= {hist_a[2:0], pin_a};
            hist_b <= {hist_b[2:0], pin_b};
        end
    end

    // 3. Señales limpias: solo cambian si las 4 muestras son idénticas
    reg a_limpio = 1'b1;
    reg b_limpio = 1'b1;
    
    always @(posedge clk) begin
        if (hist_a == 4'b0000)      a_limpio <= 1'b0;
        else if (hist_a == 4'b1111) a_limpio <= 1'b1;
        
        if (hist_b == 4'b0000)      b_limpio <= 1'b0;
        else if (hist_b == 4'b1111) b_limpio <= 1'b1;
    end

    // 4. Detección de flanco de bajada y dirección con señales filtradas
    reg a_prev = 1'b1;
    always @(posedge clk) begin
        a_prev <= a_limpio;
    end
    
    wire a_falling = (a_prev == 1'b1 && a_limpio == 1'b0);

    always @(posedge clk) begin
        if (rst) begin
            sel_onda <= 2'd0;
        end else if (a_falling) begin
            if (b_limpio == a_limpio) begin
                // Giro horario
                if (sel_onda < 2'd2) sel_onda <= sel_onda + 1'b1;
                else                 sel_onda <= 2'd0;
            end else begin
                // Giro antihorario
                if (sel_onda > 2'd0) sel_onda <= sel_onda - 1'b1;
                else                 sel_onda <= 2'd2;
            end
        end
    end

endmodule