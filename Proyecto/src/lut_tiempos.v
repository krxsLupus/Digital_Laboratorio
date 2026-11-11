// Tabla de tiempos para el ADSR: indice de 4 bits -> incremento por tick.
//
// La envolvente es un nivel de 24 bits donde 1.0 = 2^23. Se actualiza una vez por
// muestra de audio (50 MHz / 1024 = 48.828 kHz), asi que
//     inc = 2^23 / (T * 48828.125)
// es lo que hay que sumar (o restar) en cada tick para recorrer la escala completa
// 0 -> 1.0 (o 1.0 -> 0) en T segundos. Escala logaritmica, 1 ms .. 3 s.
// El tiempo real para un tramo parcial (p.ej. decaer solo hasta el nivel S) es
// proporcional a la distancia recorrida.
module lut_tiempos (
    input  wire [3:0]  idx,
    output reg  [23:0] inc
);
    always @(*) begin
        case (idx)
            4'd0:  inc = 24'd171799;  // 1 ms (1.0 ms reales)
            4'd1:  inc = 24'd85899;  // 2 ms (2.0 ms reales)
            4'd2:  inc = 24'd34360;  // 5 ms (5.0 ms reales)
            4'd3:  inc = 24'd17180;  // 10 ms (10.0 ms reales)
            4'd4:  inc = 24'd8590;  // 20 ms (20.0 ms reales)
            4'd5:  inc = 24'd4295;  // 40 ms (40.0 ms reales)
            4'd6:  inc = 24'd2147;  // 80 ms (80.0 ms reales)
            4'd7:  inc = 24'd1145;  // 150 ms (150.0 ms reales)
            4'd8:  inc = 24'd687;  // 250 ms (250.1 ms reales)
            4'd9:  inc = 24'd429;  // 400 ms (400.5 ms reales)
            4'd10:  inc = 24'd286;  // 600 ms (600.7 ms reales)
            4'd11:  inc = 24'd191;  // 900 ms (899.5 ms reales)
            4'd12:  inc = 24'd132;  // 1300 ms (1301.5 ms reales)
            4'd13:  inc = 24'd95;  // 1800 ms (1808.4 ms reales)
            4'd14:  inc = 24'd72;  // 2400 ms (2386.1 ms reales)
            4'd15:  inc = 24'd57;  // 3000 ms (3014.0 ms reales)
            default: inc = 24'd171800;
        endcase
    end
endmodule
