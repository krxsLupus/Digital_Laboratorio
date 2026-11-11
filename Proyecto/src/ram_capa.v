// Memoria de una capa del secuenciador: 64 pasos x 12 notas.
// Un puerto de escritura y uno de lectura con direcciones distintas; la lectura es
// sincrona (1 ciclo de retardo), asi Quartus la pone en un bloque M9K en vez de
// gastar ~770 flip-flops por capa.
module ram_capa (
    input  wire        clk,
    input  wire        we,
    input  wire [5:0]  wa,
    input  wire [11:0] wd,
    input  wire [5:0]  ra,
    output reg  [11:0] rd
);
    reg [11:0] m [0:63];

    integer q;
    initial begin
        for (q = 0; q < 64; q = q + 1) m[q] = 12'd0;
    end

    always @(posedge clk) begin
        if (we) m[wa] <= wd;
        rd <= m[ra];
    end
endmodule
