// Dos pulsadores (subir / bajar octava) con antirrebote.
//   Cada pulsador va entre el pin de la FPGA y GND (activo en bajo); el pin usa el
//   pull-up interno de la FPGA, asi que no hace falta resistencia externa.
//   oct: 0 = Do3 (131 Hz) | 1 = Do4 (262 Hz) | 2 = Do5 (523 Hz) | 3 = Do6 (1047 Hz)
//   No da la vuelta: en el extremo, seguir pulsando no hace nada.
module botones_octava #(
    parameter [1:0] INICIAL = 2'd1          // octava al encender (1 = la de siempre, Do4)
)(
    input  wire       clk,                  // 50 MHz
    input  wire       rst,                  // activo en alto
    input  wire       btn_sube_n,           // 0 = pulsado
    input  wire       btn_baja_n,           // 0 = pulsado
    output reg  [1:0] oct = INICIAL
);

    // Una muestra por milisegundo
    reg [15:0] timer = 16'd0;
    wire tick = (timer == 16'd49999);
    always @(posedge clk) begin
        if (tick) timer <= 16'd0;
        else      timer <= timer + 1'b1;
    end

    // Sincronizador de las entradas
    reg [1:0] s_sube = 2'b11, s_baja = 2'b11;
    always @(posedge clk) begin
        s_sube <= {s_sube[0], btn_sube_n};
        s_baja <= {s_baja[0], btn_baja_n};
    end

    // Antirrebote: el estado solo cambia si la entrada difiere 10 ms seguidos
    reg       est_sube = 1'b1, est_baja = 1'b1;     // 1 = suelto
    reg [3:0] cnt_sube = 4'd0, cnt_baja = 4'd0;
    reg       p_sube = 1'b0, p_baja = 1'b0;         // pulso de 1 ciclo al pulsar

    always @(posedge clk) begin
        p_sube <= 1'b0;
        p_baja <= 1'b0;
        if (rst) begin
            est_sube <= 1'b1; est_baja <= 1'b1;
            cnt_sube <= 4'd0; cnt_baja <= 4'd0;
        end else if (tick) begin
            if (s_sube[1] == est_sube) cnt_sube <= 4'd0;
            else if (cnt_sube == 4'd9) begin
                est_sube <= s_sube[1];
                cnt_sube <= 4'd0;
                if (!s_sube[1]) p_sube <= 1'b1;
            end else cnt_sube <= cnt_sube + 1'b1;

            if (s_baja[1] == est_baja) cnt_baja <= 4'd0;
            else if (cnt_baja == 4'd9) begin
                est_baja <= s_baja[1];
                cnt_baja <= 4'd0;
                if (!s_baja[1]) p_baja <= 1'b1;
            end else cnt_baja <= cnt_baja + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst)                         oct <= INICIAL;
        else if (p_sube && oct != 2'd3)  oct <= oct + 1'b1;
        else if (p_baja && oct != 2'd0)  oct <= oct - 1'b1;
    end

endmodule
