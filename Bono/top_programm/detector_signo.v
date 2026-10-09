module detector_signo (
    input  wire [5:0] R,       // R[5] = signo, complemento a 2
    output wire       signo,   // 0: Positivo (+), 1: Negativo (-)
    output wire [4:0] mag      // Magnitud absoluta (0..30) para el display
);

    assign signo = R[5];

    // Si es negativo se toma el complemento a 2; si es positivo queda igual
    assign mag = signo ? (~R[4:0] + 1'b1) : R[4:0];

endmodule