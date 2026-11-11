// Envolvente ADSR de una voz.
//
// Nivel de 24 bits, 1.0 = 2^23. Todo avanza un paso por cada pulso 'tick'
// (una vez por muestra de audio, 48.828 kHz). La salida 'env' (0..256) es el
// factor por el que banco_notas multiplica la onda: 256 = ganancia 1.0.
//
//   IDLE : voz apagada (nivel 0). Con gate pasa a ATK.
//   ATK  : sube inc_a por tick hasta 1.0 -> DEC.
//   DEC  : baja inc_d por tick hasta sus_lvl -> SUS.
//   SUS  : se queda en sus_lvl (si S cambia, se desliza hacia el nuevo valor
//          a razon inc_d, sin saltos).
//   REL  : baja inc_r por tick hasta 0 -> IDLE.
//
// Soltar la tecla en cualquier estado pasa a REL desde el nivel actual. Pulsarla
// de nuevo durante REL pasa a ATK desde el nivel actual (no desde 0), asi no hay
// salto de nivel al repetir una nota.
module envelope_adsr (
    input  wire        clk,
    input  wire        rst,        // activo en alto
    input  wire        tick,       // un pulso por muestra de audio
    input  wire        gate,       // tecla pulsada (o mantenida por el pedal)
    input  wire [23:0] inc_a,      // incremento de ataque por tick
    input  wire [23:0] inc_d,      // decremento de decay por tick
    input  wire [23:0] inc_r,      // decremento de release por tick
    input  wire [23:0] sus_lvl,    // nivel de sustain (0 .. 2^23)
    output wire [8:0]  env,        // 0..256
    output wire        idle        // 1 = voz apagada (se puede resetear su fase)
);

    localparam [2:0] S_IDLE = 3'd0, S_ATK = 3'd1, S_DEC = 3'd2, S_SUS = 3'd3, S_REL = 3'd4;
    localparam [23:0] MAXL = 24'd8388608;               // 1.0

    reg [2:0]  st  = S_IDLE;
    reg [23:0] lvl = 24'd0;

    // Sumas con un bit mas para detectar el desborde / el cruce del objetivo
    wire [24:0] lvl_up_a  = {1'b0, lvl} + {1'b0, inc_a};
    wire [24:0] dec_tgt   = {1'b0, sus_lvl} + {1'b0, inc_d};   // si lvl <= esto, el proximo paso llega a S
    wire [24:0] sus_up    = {1'b0, lvl} + {1'b0, inc_d};

    always @(posedge clk) begin
        if (rst) begin
            st  <= S_IDLE;
            lvl <= 24'd0;
        end else if (tick) begin
            case (st)
                S_IDLE: begin
                    lvl <= 24'd0;
                    if (gate) st <= S_ATK;
                end

                S_ATK: begin
                    if (!gate) st <= S_REL;
                    else if (lvl_up_a >= {1'b0, MAXL}) begin
                        lvl <= MAXL;
                        st  <= S_DEC;
                    end else
                        lvl <= lvl_up_a[23:0];
                end

                S_DEC: begin
                    if (!gate) st <= S_REL;
                    else if ({1'b0, lvl} <= dec_tgt) begin
                        lvl <= sus_lvl;
                        st  <= S_SUS;
                    end else
                        lvl <= lvl - inc_d;
                end

                S_SUS: begin
                    if (!gate) st <= S_REL;
                    else if (lvl > sus_lvl)                              // S bajo: baja suave
                        lvl <= ((lvl - sus_lvl) <= inc_d) ? sus_lvl : (lvl - inc_d);
                    else if (lvl < sus_lvl)                              // S subio: sube suave
                        lvl <= ((sus_lvl - lvl) <= inc_d) ? sus_lvl : sus_up[23:0];
                end

                S_REL: begin
                    if (gate) st <= S_ATK;
                    else if (lvl <= inc_r) begin
                        lvl <= 24'd0;
                        st  <= S_IDLE;
                    end else
                        lvl <= lvl - inc_r;
                end

                default: st <= S_IDLE;
            endcase
        end
    end

    assign env  = lvl[23:15];          // 2^23 >> 15 = 256
    assign idle = (st == S_IDLE);

endmodule
