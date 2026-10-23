`timescale 1ns/1ps

module tb_teclado_4x3;

    localparam integer CLK_FREQ  = 100_000;
    localparam integer T_CLK     = 1_000_000_000 / CLK_FREQ;
    localparam integer T_REBOTE  = 700_000;
    localparam integer T_PRESION = 40_000_000;
    localparam integer T_SOLTAR  = 40_000_000;

    reg clk = 1'b0, rst = 1'b1;
    always #(T_CLK/2) clk = ~clk;

    // Modelo del teclado 4x3
    reg        presionada = 1'b0;
    reg  [1:0] f, c;
    wire [3:0] rows;
    wire [2:0] cols = (presionada && rows[f] === 1'b0) ? ~(3'b001 << c) : 3'b111;

    wire [3:0] key_code;
    wire       key_valid;

    teclado_4x3 #(.CLK_FREQ(CLK_FREQ)) dut (
        .clk(clk), .rst(rst), .cols(cols), .rows(rows),
        .key_code(key_code), .key_valid(key_valid)
    );

    task presionar(input [1:0] fila, input [1:0] col);
        integer i;
        begin
            f = fila; c = col;
            for (i = 0; i < 5; i = i + 1) begin
                presionada = 1'b1; #(T_REBOTE);
                presionada = 1'b0; #(T_REBOTE);
            end
            presionada = 1'b1; #(T_PRESION);
            presionada = 1'b0; #(T_SOLTAR);
        end
    endtask

    reg [3:0] esperado [0:11];
    initial begin
        esperado[0] = 1;  esperado[1] = 2;  esperado[2] = 3;
        esperado[3] = 4;  esperado[4] = 5;  esperado[5] = 6;
        esperado[6] = 7;  esperado[7] = 8;  esperado[8] = 9;
        esperado[9] = 10; esperado[10] = 0; esperado[11] = 11;
    end

    integer pulsos = 0, errores = 0;
    reg [3:0] ultimo = 4'hx;
    reg       kv_ant = 1'b0;
    always @(posedge clk) begin
        kv_ant <= key_valid;
        if (key_valid) begin pulsos = pulsos + 1; ultimo = key_code; end
        if (key_valid && kv_ant) begin
            $display("FALLO: key_valid dura mas de un ciclo");
            errores = errores + 1;
        end
    end

    integer k, previos, fila, col;
    initial begin
        #(10 * T_CLK) rst = 1'b0;
        #(5_000_000);

        for (k = 0; k < 12; k = k + 1) begin
            previos = pulsos;
            fila = k / 3;
            col  = k % 3;
            presionar(fila[1:0], col[1:0]);
            if (pulsos != previos + 1 || ultimo !== esperado[k]) begin
                $display("FALLO fila=%0d col=%0d: pulsos=%0d (esp. 1), codigo=%0d (esp. %0d)",
                         fila, col, pulsos - previos, ultimo, esperado[k]);
                errores = errores + 1;
            end else
                $display("OK    fila=%0d col=%0d -> key_code=%0d", fila, col, ultimo);
        end

        if (errores == 0 && pulsos == 12) $display("TODAS LAS PRUEBAS OK (12 teclas, 12 pulsos)");
        else                              $display("ERRORES: %0d, pulsos=%0d", errores, pulsos);
        $finish;
    end

endmodule