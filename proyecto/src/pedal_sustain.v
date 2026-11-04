// Pedal de sustain (como el CC64 de MIDI).
//
// Entra 'teclas' (ya sin rebotes) y el pedal; sale 'gate', que va a la envolvente
// de cada voz en lugar de 'teclas'.
//   Pedal suelto : gate = teclas (soltar la tecla inicia el release de inmediato).
//   Pedal abajo  : toda nota que se pulse queda con gate = 1 aunque se suelte la
//                  tecla; la envolvente sigue su curso (ataque, decay y se queda
//                  en el nivel S). Volver a pulsar una nota sostenida no la ataca
//                  de nuevo.
//   Soltar el pedal: las notas cuya tecla ya estaba suelta pasan a release.
//
// 'hold' recuerda lo que estaba sonando en el ciclo anterior: es la realimentacion
// registrada de 'gate', no hay lazo combinacional.
module pedal_sustain #(
    parameter integer ACTIVO_BAJO = 1     // 1: el pedal esta abajo cuando la entrada vale 0
)(
    input  wire        clk,
    input  wire        rst,               // activo en alto
    input  wire        pedal,             // entrada fisica (asincrona)
    input  wire [11:0] teclas,
    output wire [11:0] gate
);

    // Sincronizador de 2 FF, iniciado en "pedal suelto"
    reg p1 = (ACTIVO_BAJO != 0);
    reg p2 = (ACTIVO_BAJO != 0);
    always @(posedge clk) begin
        p1 <= pedal;
        p2 <= p1;
    end
    wire pedal_abajo = (ACTIVO_BAJO != 0) ? ~p2 : p2;

    reg [11:0] hold = 12'd0;
    assign gate = teclas | ({12{pedal_abajo}} & hold);

    always @(posedge clk) begin
        if (rst) hold <= 12'd0;
        else     hold <= gate;            // con pedal suelto esto es igual a 'teclas': se borra solo
    end

endmodule
