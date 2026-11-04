// Control de los parametros ADSR con un encoder y un pulsador.
//   pulsador : cambia el parametro seleccionado (A -> D -> S -> R -> A ...)
//   encoder  : horario sube, antihorario baja (0..15, se detiene en los extremos)
// 'sel' dice cual parametro se esta editando (para los LEDs) y 'valor' es su valor
// actual (para el display).
module ctrl_adsr #(
    parameter integer ACTIVO_BAJO = 1,          // 1: el pulsador da 0 al presionarlo
    parameter [3:0] A_INI = 4'd3,               //  10 ms
    parameter [3:0] D_INI = 4'd8,               // 250 ms
    parameter [3:0] S_INI = 4'd12,              // 12/16 del nivel maximo
    parameter [3:0] R_INI = 4'd8                // 250 ms
)(
    input  wire       clk,       // 50 MHz
    input  wire       rst,       // activo en alto
    input  wire       enc_a,     // encoder CLK
    input  wire       enc_b,     // encoder DT
    input  wire       btn,       // pulsador de seleccion
    output wire [3:0] a_idx,
    output wire [3:0] d_idx,
    output wire [3:0] s_idx,
    output wire [3:0] r_idx,
    output reg  [1:0] sel = 2'd0,          // 0 = A, 1 = D, 2 = S, 3 = R
    output wire [3:0] valor                // valor del parametro seleccionado
);

    wire up, down;
    encoder_core u_enc (.clk(clk), .rst(rst), .pin_a(enc_a), .pin_b(enc_b), .up(up), .down(down));

    // ---- Pulsador: sincronizador + antirrebote de ~10 ms ----
    reg s1 = (ACTIVO_BAJO != 0), s2 = (ACTIVO_BAJO != 0);
    always @(posedge clk) begin
        s1 <= btn;
        s2 <= s1;
    end

    reg        estable = (ACTIVO_BAJO != 0);
    reg [19:0] cnt     = 20'd0;
    always @(posedge clk) begin
        if (s2 == estable)
            cnt <= 20'd0;
        else if (cnt == 20'd499_999) begin
            estable <= s2;
            cnt     <= 20'd0;
        end else
            cnt <= cnt + 1'b1;
    end

    wire pulsado = (ACTIVO_BAJO != 0) ? ~estable : estable;
    reg  pulsado_prev = 1'b0;
    always @(posedge clk) pulsado_prev <= pulsado;
    wire btn_press = pulsado & ~pulsado_prev;

    // ---- Parametros ----
    reg [15:0] par = {R_INI, S_INI, D_INI, A_INI};     // {R, S, D, A}

    always @(posedge clk) begin
        if (rst) begin
            par <= {R_INI, S_INI, D_INI, A_INI};
            sel <= 2'd0;
        end else begin
            if (btn_press) sel <= sel + 1'b1;
            if (up   && par[sel*4 +: 4] != 4'd15) par[sel*4 +: 4] <= par[sel*4 +: 4] + 1'b1;
            if (down && par[sel*4 +: 4] != 4'd0)  par[sel*4 +: 4] <= par[sel*4 +: 4] - 1'b1;
        end
    end

    assign a_idx = par[3:0];
    assign d_idx = par[7:4];
    assign s_idx = par[11:8];
    assign r_idx = par[15:12];
    assign valor = par[sel*4 +: 4];

endmodule
