// ============================================================================
// MÓDULO DE ESCANEO Y DECODIFICACIÓN DE TECLADO MATRICIAL 4x3 CON ANTIRREBOTE
// ============================================================================

module teclado_4x3 #(
    parameter integer CLK_FREQ = 50_000_000,  // Frecuencia del reloj de entrada (Hz)
    parameter integer DEB_MS   = 10          // Tiempo de filtro antirrebote (ms)
)(
    input  wire       clk,                    // Reloj principal del sistema
    input  wire       rst,                    // Reset síncrono, activo en alto
    input  wire [2:0] cols,                   // Columnas C1..C3 
    output wire [3:0] rows,                   // Filas R1..R4, salida tri-state, activa en bajo
    output reg  [3:0] key_code = 4'd0,        // Código de la tecla (0-9, 10='*', 11='#')
    output wire       key_valid,              // Pulso de 1 ciclo al validar la pulsación
    output wire       key_down                // Nivel alto continuo mientras la tecla esté presionada
);

    // ------------------------------------------------------------------------
    // GENERADOR DE TICK DE 1 ms
    // ------------------------------------------------------------------------
    localparam integer TICK_DIV = CLK_FREQ / 1000;              // Ciclos necesarios para 1 ms
    localparam integer TICK_W   = (TICK_DIV > 1) ? $clog2(TICK_DIV) : 1; // Ancho del contador
    
    reg [TICK_W-1:0] cnt_tick = 0;
    reg              tick     = 1'b0;

    // cnt_tick cuenta 1ms y cada 1ms tick se vuelve 1 durante un ciclo de reloj: 20ns
    always @(posedge clk) begin
        if (rst || cnt_tick == TICK_DIV - 1) 
            cnt_tick <= 0;
        else 
            cnt_tick <= cnt_tick + 1'b1;
            
        // Genera un pulso de '1' durante 1 ciclo cada 1 ms
        tick <= !rst && (cnt_tick == TICK_DIV - 1);
    end

    // ------------------------------------------------------------------------
    // SINCRONIZADOR DE ENTRADAS: Doble Flip-Flop para prevenir Metaestabilidad
    // ------------------------------------------------------------------------
    reg [2:0] cols_s1 = 3'b111;
    reg [2:0] cols_s2 = 3'b111;
    
    always @(posedge clk) begin
        cols_s1 <= cols;
        cols_s2 <= cols_s1; // Usado internamente como la lectura estable de las columnas
    end

    // ------------------------------------------------------------------------
    // MANEJO DE FILAS
    // ------------------------------------------------------------------------
    reg [1:0] row_idx = 2'd0; // Índice de la fila en escaneo de 0 a 3

    // La fila activa se pone en '0' lógico; las inactivas se dejan en alta impedancia 'Z'
    assign rows[0] = (row_idx == 2'd0) ? 1'b0 : 1'bz;
    assign rows[1] = (row_idx == 2'd1) ? 1'b0 : 1'bz;
    assign rows[2] = (row_idx == 2'd2) ? 1'b0 : 1'bz;
    assign rows[3] = (row_idx == 2'd3) ? 1'b0 : 1'bz;

    // ------------------------------------------------------------------------
    // DECODIFICACIÓN DE COLUMNA Y MAPEO DE TECLA
    // ------------------------------------------------------------------------
    // Hay tecla presionado si alguna columna fue arrastrada a cero por la fila activa
    wire hay_tecla = (cols_s2 != 3'b111);
    reg  [1:0] col_idx;

    // Codificador de prioridad para detectar cuál columna está en nivel bajo ('0')
    always @(*) begin
        if      (!cols_s2[0]) col_idx = 2'd0;
        else if (!cols_s2[1]) col_idx = 2'd1;
        else                  col_idx = 2'd2; // Columna 2 si ninguna de las anteriores es '0'
    end

    // Vector de coordenadas combinadas {fila, columna}
    wire [3:0] pos_now = {row_idx, col_idx};
    reg  [3:0] valor;

    // Tabla de conversión de posición física a valor numérico
    always @(*) begin
        case (pos_now)
            4'b00_00: valor = 4'd1;   4'b00_01: valor = 4'd2;   4'b00_10: valor = 4'd3;  // Fila 0
            4'b01_00: valor = 4'd4;   4'b01_01: valor = 4'd5;   4'b01_10: valor = 4'd6;  // Fila 1
            4'b10_00: valor = 4'd7;   4'b10_01: valor = 4'd8;   4'b10_10: valor = 4'd9;  // Fila 2
            4'b11_00: valor = 4'd10;  4'b11_01: valor = 4'd0;   4'b11_10: valor = 4'd11; // Fila 3 (*, 0, #)
            default:  valor = 4'd0;   // Caso de resguardo para combinaciones no usadas
        endcase
    end

    // ------------------------------------------------------------------------
    // MAQUINA DE ESTADOS Y FILTRO ANTIRREBOTE
    // ------------------------------------------------------------------------
    reg [3:0] pos_prev           = 4'd0; // Almacena la última posición muestreada
    reg [3:0] estable            = 4'd0; // Contador de ms con lectura estable
    reg       presionada_estable = 1'b0; // Estado filtrado de la tecla

    always @(posedge clk) begin
        if (rst) begin
            row_idx            <= 2'd0;
            estable            <= 4'd0;
            presionada_estable <= 1'b0;
        end else if (tick) begin // Las transiciones ocurren solo en ticks de 1 ms
            if (hay_tecla) begin
                if (!presionada_estable) begin
                    if (estable == 4'd0) begin
                        pos_prev <= pos_now; // Captura la posición inicial
                        estable  <= 4'd1;
                    end else if (pos_now != pos_prev) begin
                        estable  <= 4'd0;    // Rebote o cambio de tecla detectado: reinicia
                    end else if (estable == DEB_MS) begin
                        key_code           <= valor; // Registra el valor decodificado
                        presionada_estable <= 1'b1;  // Valida el estado de tecla presionada
                    end else begin
                        estable  <= estable + 1'b1;  // Incrementa el tiempo de estabilidad
                    end
                end
            end else begin
                // No hay tecla en esta fila: limpia banderas y pasa a escanear la siguiente fila
                presionada_estable <= 1'b0;
                estable            <= 4'd0;
                row_idx            <= row_idx + 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // DETECTOR DE FLANCO Y SALIDAS DE ESTADO
    // ------------------------------------------------------------------------
    reg presionada_ant = 1'b0;

    always @(posedge clk) begin
        presionada_ant <= presionada_estable; // Registro del ciclo anterior
    end

    // Genera un único pulso en '1' cuando la pulsación se valida por primera vez
    assign key_valid = presionada_estable & ~presionada_ant;

    // Transmite directamente el estado de pulsación estable
    assign key_down  = presionada_estable;

endmodule