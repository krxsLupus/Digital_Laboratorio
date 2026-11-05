module generador_onda(
    input  wire [31:0] fase,
    input  wire [1:0]  sel_onda, // Controlado por el KY-040: 0 cuadrada, 1 sierra, 2 triangular, 3 seno
    output reg  [7:0]  onda_out
);
    // 1. Cuadrada: Rango completo 0 a 255
    wire [7:0] cuadrada = (fase[31]) ? 8'd255 : 8'd0;

    // 2. Diente de sierra: Rango completo 0 a 255
    wire [7:0] sierra = fase[31:24];

    // 3. Triangular con ganancia (x1.5) y saturación(Corregida)
    // Usamos el MSB (31) para saber si sube o baja.
    // Multiplicamos por 2 desplazando un bit (fase[30:24] << 1) para aprovechar todo el rango.
    wire [7:0] tri_base = {fase[30:24], 1'b0}; // Corrige el salto del MSB
    wire [7:0] triangular = (fase[31]) ? ~tri_base : tri_base;
    wire [8:0] tri_ganancia = triangular + (triangular >> 1); // x1.5
    wire [7:0] tri_saturada = (tri_ganancia > 9'd255) ? 8'd255 : tri_ganancia[7:0];
    
    // Ganancia Triangular: Multiplicamos por 1.5 aprox y saturamos en 255 para engordarla
    wire [8:0] tri_ganancia = triangular + (triangular >> 1);
    wire [7:0] tri_saturada = (tri_ganancia > 9'd255) ? 8'd255 : tri_ganancia[7:0];

    // 4. Seno con ganancia (x2) y saturación
    wire [7:0] seno_puro = fase[31] ? (8'd128 - mag_seno) : (8'd128 + mag_seno);
    wire signed [9:0] seno_centrado = $signed({2'b00, seno_puro}) - 10'sd128;
    wire signed [9:0] seno_amplificado = seno_centrado <<< 1; // x2
    wire [7:0] seno_saturado = (seno_amplificado > 10'sd127) ? 8'd255 :
                           (seno_amplificado < -10'sd128) ? 8'd0 :
                           $unsigned(seno_amplificado + 10'sd128);

    
    
    // Sumamos al centro (128)
    wire [7:0] seno_puro = fase[31] ? (8'd128 - mag_seno) : (8'd128 + mag_seno);
    
    // Ganancia Seno: Aplicamos una ganancia del doble (<< 1) centrada en 128
    // Usamos variables con signo para el cálculo de saturación
    wire signed [9:0] seno_centrado = $signed({2'b00, seno_puro}) - 10'sd128;
    wire signed [9:0] seno_amplificado = seno_centrado <<< 1; // Multiplicar por 2
    
    // Saturación (*clipping*) rígida a los límites de 8 bits (0 a 255)
    wire [7:0] seno_saturado;
    assign seno_saturado = (seno_amplificado > 10'sd127)  ? 8'd255 :
                           (seno_amplificado < -10'sd128) ? 8'd0   :
                           $unsigned(seno_amplificado + 10'sd128);

    // 5. Multiplexor de salida
    always @(*) begin
        case(sel_onda)
            2'd0: onda_out = cuadrada;      
            2'd1: onda_out = sierra;        
            2'd2: onda_out = tri_saturada;  // Triangular con ganancia
            2'd3: onda_out = seno_saturado; // Senoidal con ganancia
        endcase
    end
endmodule


/* module generador_onda(
    input  wire [31:0] fase,
    input  wire [1:0]  sel_onda, // Controlado por el KY-040: 0 cuadrada, 1 sierra, 2 triangular, 3 seno
    output reg  [7:0]  onda_out
);
    // Tomamos los 8 bits más altos del acumulador (0 a 255)
    wire [7:0] sierra = fase[31:24];

    // Triangular de rango completo (0 a 255): usa los 8 bits siguientes al MSB.
    wire [7:0] tri_base = fase[30:23];

    // Seno: se guarda solo un cuarto de ciclo (seno_lut) y se refleja.
    //   fase[31]  = semiciclo (0 positivo, 1 negativo)
    //   fase[30]  = segundo cuarto del semiciclo -> se recorre la tabla al reves
    //   fase[29:24] = indice dentro del cuarto
    wire [5:0] idx_seno = fase[30] ? ~fase[29:24] : fase[29:24];
    wire [6:0] mag_seno;
    seno_lut u_seno (.idx(idx_seno), .mag(mag_seno));
    wire [7:0] seno = fase[31] ? (8'd128 - mag_seno) : (8'd128 + mag_seno);  // 1..255, centro 128

    always @(*) begin
        case(sel_onda)
            2'd0: onda_out = (fase[31]) ? 8'd255 : 8'd0;        // Cuadrada
            2'd1: onda_out = sierra;                            // Diente de sierra
            2'd2: onda_out = (fase[31]) ? ~tri_base : tri_base; // Triangular
            2'd3: onda_out = seno;                              // Sinusoidal
        endcase
    end
endmodule */
