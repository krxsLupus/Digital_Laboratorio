// Antirrebote de un pulsador: da un pulso de un ciclo de reloj cuando la
// pulsacion lleva DEB_MS estable.
//   ACTIVO_BAJO = 1: pulsado = 0 (pulsador a GND, con pull-up)
//   ACTIVO_BAJO = 0: pulsado = 1
module boton_pulso #(
    parameter integer CLK_FREQ    = 50_000_000,
    parameter integer DEB_MS      = 10,
    parameter integer ACTIVO_BAJO = 1
)(
    input  wire clk,
    input  wire rst,          // activo en alto
    input  wire btn,          // entrada fisica (asincrona)
    output reg  pulso = 1'b0
);

    localparam integer LIM = DEB_MS * (CLK_FREQ / 1000);
    localparam integer W   = $clog2(LIM + 1);

    reg [1:0]   s   = 2'b00;       // sincronizador (1 = pulsado)
    reg         est = 1'b0;        // estado filtrado (1 = pulsado)
    reg [W-1:0] cnt = 0;

    wire pulsado = (ACTIVO_BAJO != 0) ? ~btn : btn;

    always @(posedge clk) begin
        s     <= {s[0], pulsado};
        pulso <= 1'b0;
        if (rst) begin
            est <= 1'b0;
            cnt <= 0;
        end else if (s[1] == est) begin
            cnt <= 0;
        end else if (cnt == LIM - 1) begin
            est <= s[1];
            cnt <= 0;
            if (s[1]) pulso <= 1'b1;      // se acaba de pulsar
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

endmodule
