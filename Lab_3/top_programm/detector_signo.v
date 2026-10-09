module detector_signo (
    input  wire [4:0] S,       // S[4] = acarreo, S[3:0] = resultado
    input  wire       Op,      
    output wire       signo,   // 0: Positivo (+), 1: Negativo (-)
    output wire       error,   // 1: Desbordamiento Error de representación
    output wire [3:0] mag      // Magnitud absoluta para el display
);

    // En resta es 0 si S[4]==1, 1 si S[4]==0
    assign signo = Op ? ~S[4] : 1'b0; //condicional q permite ver si se asigna 0 (+) o 1 (-)

    assign error = ~Op & S[4]; //el error solo da 1 si se trata de una suma (Op=0) y hay acarreo

    assign mag = (signo) ? (~S[3:0] + 1'b1) : S[3:0]; //se asigna la magnitud del complemento a 2 si
//el signo es negativo o se deja igual si es positivo

endmodule