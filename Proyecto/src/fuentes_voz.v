// Reparte los parametros (onda, octava, ADSR) entre las 12 voces.
//
// Cada nota (voz) puede ser pedida por varias fuentes a la vez: el teclado en vivo
// (parametros actuales) y las 4 capas del secuenciador (cada una con los suyos).
// Una voz solo puede sonar con un juego de parametros, asi que gana una fuente:
//     teclado en vivo > capa 3 > capa 2 > capa 1 > capa 0
// La voz conserva los parametros de su ultima fuente mientras no la pida nadie, para que
// la cola de release suene con el mismo timbre. Capas distintas con notas distintas
// suenan cada una con sus parametros; solo si dos fuentes piden LA MISMA nota a la vez
// suena una sola vez, con la fuente de mayor prioridad.
module fuentes_voz (
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] gate_vivo,        // teclado (ya con pedal)
    input  wire [47:0] gate_capas,       // secuenciador: 4 capas x 12 notas
    // Parametros en vivo
    input  wire [1:0]  v_onda,
    input  wire [1:0]  v_oct,
    input  wire [3:0]  v_a, v_d, v_s, v_r,
    // Parametros de cada capa (capa 0 en los bits bajos)
    input  wire [7:0]  c_onda,
    input  wire [7:0]  c_oct,
    input  wire [15:0] c_a, c_d, c_s, c_r,
    // Hacia banco_notas
    output wire [11:0] gate,
    output wire [23:0] onda_v,           // 2 bits por voz
    output wire [23:0] oct_v,            // 2 bits por voz
    output wire [47:0] a_v, d_v, s_v, r_v // 4 bits por voz
);

    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : voz
            wire g0 = gate_vivo[i];
            wire g1 = gate_capas[i];
            wire g2 = gate_capas[12 + i];
            wire g3 = gate_capas[24 + i];
            wire g4 = gate_capas[36 + i];

            reg [2:0] own_r = 3'd0;      // 0 = vivo, 1..4 = capa 0..3
            reg [2:0] own_n;
            always @(*) begin
                if      (g0) own_n = 3'd0;
                else if (g4) own_n = 3'd4;
                else if (g3) own_n = 3'd3;
                else if (g2) own_n = 3'd2;
                else if (g1) own_n = 3'd1;
                else         own_n = own_r;
            end
            always @(posedge clk) begin
                if (rst) own_r <= 3'd0;
                else     own_r <= own_n;
            end

            assign gate[i] = g0 | g1 | g2 | g3 | g4;

            reg [1:0] o, c;
            reg [3:0] a, d, s, r;
            always @(*) begin
                case (own_n)
                    3'd1:    begin o = c_onda[1:0]; c = c_oct[1:0]; a = c_a[3:0];   d = c_d[3:0];   s = c_s[3:0];   r = c_r[3:0];   end
                    3'd2:    begin o = c_onda[3:2]; c = c_oct[3:2]; a = c_a[7:4];   d = c_d[7:4];   s = c_s[7:4];   r = c_r[7:4];   end
                    3'd3:    begin o = c_onda[5:4]; c = c_oct[5:4]; a = c_a[11:8];  d = c_d[11:8];  s = c_s[11:8];  r = c_r[11:8];  end
                    3'd4:    begin o = c_onda[7:6]; c = c_oct[7:6]; a = c_a[15:12]; d = c_d[15:12]; s = c_s[15:12]; r = c_r[15:12]; end
                    default: begin o = v_onda;      c = v_oct;      a = v_a;        d = v_d;        s = v_s;        r = v_r;        end
                endcase
            end

            assign onda_v[2*i +: 2] = o;
            assign oct_v [2*i +: 2] = c;
            assign a_v   [4*i +: 4] = a;
            assign d_v   [4*i +: 4] = d;
            assign s_v   [4*i +: 4] = s;
            assign r_v   [4*i +: 4] = r;
        end
    endgenerate

endmodule
