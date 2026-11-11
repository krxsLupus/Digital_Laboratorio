// Control de parametros: un encoder (valor) + un pulsador (elige el parametro).
//
// Cada pulsacion de 'btn' pasa al parametro siguiente, en este orden:
//   0 A (ataque)   1 D (decay)   2 S (sustain)   3 R (release)
//   4 T (tiempo del eco)   5 FB (realimentacion del eco)   6 MIX (mezcla del eco)
//   7 BPM (tempo del secuenciador: 60 + 10 * valor)
// El encoder sube / baja el valor del parametro elegido (0..15, sin dar la vuelta).
//   led_sel : LED del parametro elegido (one-hot, bit 0 = A ... bit 6 = MIX)
//   valor   : valor del parametro elegido (para el display)
// led_sel: bit 0 = A ... bit 7 = BPM.
// rev_mix no se usa (no hay reverb): queda en 0.
module ctrl_param #(
    parameter integer ACTIVO_BAJO = 1       // 1: el pulsador vale 0 al pulsarlo
)(
    input  wire       clk,
    input  wire       rst,                  // activo en alto
    input  wire       enc_a,
    input  wire       enc_b,
    input  wire       btn,
    output reg  [3:0] a_idx   = 4'd3,       // 10 ms
    output reg  [3:0] d_idx   = 4'd8,       // 250 ms
    output reg  [3:0] s_idx   = 4'd12,      // 0.75
    output reg  [3:0] r_idx   = 4'd8,       // 250 ms
    output reg  [3:0] eco_t   = 4'd7,       // ~125 ms
    output reg  [3:0] eco_fb  = 4'd6,       // ~0.35
    output reg  [3:0] eco_mix = 4'd0,       // arranca limpio
    output reg  [3:0] bpm_idx = 4'd4,       // 100 BPM
    output wire [3:0] rev_mix,
    output wire [7:0] led_sel,              // one-hot para 8 LEDs
    output reg  [3:0] valor
);

    assign rev_mix = 4'd0;

    // Encoder (antirrebote + direccion) y pulsador (antirrebote)
    wire enc_up, enc_down;
    encoder_core u_enc (
        .clk   (clk),
        .rst   (rst),
        .pin_a (enc_a),
        .pin_b (enc_b),
        .up    (enc_up),
        .down  (enc_down)
    );

    wire btn_pulso;
    boton_pulso #(.ACTIVO_BAJO(ACTIVO_BAJO)) u_btn (
        .clk   (clk),
        .rst   (rst),
        .btn   (btn),
        .pulso (btn_pulso)
    );

    // Parametro elegido: 0..7
    reg [2:0] sel = 3'd0;
    assign led_sel = 8'b00000001 << sel;

    always @(posedge clk) begin
        if (rst)             sel <= 3'd0;
        else if (btn_pulso)  sel <= sel + 1'b1;          // 0..7 y vuelve a 0
    end

    // Valor del parametro elegido, para el display
    always @(*) begin
        case (sel)
            3'd0:    valor = a_idx;
            3'd1:    valor = d_idx;
            3'd2:    valor = s_idx;
            3'd3:    valor = r_idx;
            3'd4:    valor = eco_t;
            3'd5:    valor = eco_fb;
            3'd6:    valor = eco_mix;
            default: valor = bpm_idx;     // 7
        endcase
    end

    // Un paso del encoder sobre un valor de 4 bits, sin pasar de 0 ni de 15
    function [3:0] paso;
        input [3:0] v;
        input       sube;
        begin
            if (sube) paso = (v == 4'd15) ? v : (v + 1'b1);
            else      paso = (v == 4'd0)  ? v : (v - 1'b1);
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            a_idx   <= 4'd3;
            d_idx   <= 4'd8;
            s_idx   <= 4'd12;
            r_idx   <= 4'd8;
            eco_t   <= 4'd7;
            eco_fb  <= 4'd6;
            eco_mix <= 4'd0;
            bpm_idx <= 4'd4;
        end else if (enc_up || enc_down) begin
            case (sel)
                3'd0:    a_idx   <= paso(a_idx,   enc_up);
                3'd1:    d_idx   <= paso(d_idx,   enc_up);
                3'd2:    s_idx   <= paso(s_idx,   enc_up);
                3'd3:    r_idx   <= paso(r_idx,   enc_up);
                3'd4:    eco_t   <= paso(eco_t,   enc_up);
                3'd5:    eco_fb  <= paso(eco_fb,  enc_up);
                3'd6:    eco_mix <= paso(eco_mix, enc_up);
                default: bpm_idx <= paso(bpm_idx, enc_up);
            endcase
        end
    end

endmodule
