`timescale 1ns/1ps
// Testbench autoverificable de envelope_adsr.
// Trabaja en "ticks" (no en tiempo real): el tick se genera cada 4 ciclos de reloj
// y se cuentan los pasos que tarda cada tramo, comparandolos con lo que
// predice lut_tiempos (tolerancia de +-3 ticks por los pasos de transicion).
//
// Uso en Questa:  vsim work.tb_envelope ; run -all
module tb_envelope;

    parameter integer A_IDX = 5;     //  40 ms
    parameter integer D_IDX = 4;     //  20 ms
    parameter integer S_IDX = 8;     //  nivel 8/16 = 0.5
    parameter integer R_IDX = 6;     //  80 ms
    parameter integer TOL   = 3;

    reg  clk = 0;
    reg  rst = 1;
    reg  gate = 0;
    reg  [1:0] div = 0;
    wire tick = (div == 2'd3);
    always #10 clk = ~clk;
    always @(posedge clk) div <= div + 1'b1;

    wire [23:0] inc_a, inc_d, inc_r;
    reg  [23:0] sus_lvl;
    lut_tiempos u_la (.idx(A_IDX[3:0]), .inc(inc_a));
    lut_tiempos u_ld (.idx(D_IDX[3:0]), .inc(inc_d));
    lut_tiempos u_lr (.idx(R_IDX[3:0]), .inc(inc_r));

    wire [8:0] env;
    wire       idle;
    envelope_adsr uut (
        .clk(clk), .rst(rst), .tick(tick), .gate(gate),
        .inc_a(inc_a), .inc_d(inc_d), .inc_r(inc_r), .sus_lvl(sus_lvl),
        .env(env), .idle(idle)
    );

    localparam [23:0] MAXL = 24'd8388608;
    localparam [2:0] S_IDLE = 0, S_ATK = 1, S_DEC = 2, S_SUS = 3, S_REL = 4;

    integer errores = 0;
    integer n, esperado, lvl_prev, i;

    // Avanza hasta el siguiente tick (el DUT ya lo proceso al volver)
    task tick_step;
        begin
            @(posedge clk);
            while (!tick) @(posedge clk);
            #1;
        end
    endtask

    task run_until;
        input [2:0] objetivo;
        input integer maxt;
        output integer pasos;
        begin
            pasos = 0;
            while (uut.st != objetivo && pasos < maxt) begin
                tick_step;
                pasos = pasos + 1;
            end
        end
    endtask

    task check;
        input integer got;
        input integer exp;
        input [8*24-1:0] nombre;
        begin
            if (got < exp - TOL || got > exp + TOL) begin
                $display("FALLA  %0s: %0d ticks, esperado %0d +-%0d", nombre, got, exp, TOL);
                errores = errores + 1;
            end else
                $display("ok     %0s: %0d ticks (esperado %0d)", nombre, got, exp);
        end
    endtask

    task check_cond;
        input cond;
        input [8*40-1:0] nombre;
        begin
            if (!cond) begin $display("FALLA  %0s", nombre); errores = errores + 1; end
            else       $display("ok     %0s", nombre);
        end
    endtask

    function integer ceil_div;
        input integer a;
        input integer b;
        begin ceil_div = (a + b - 1) / b; end
    endfunction

    initial begin
        sus_lvl = (S_IDX == 15) ? MAXL : (S_IDX << 19);
        repeat (8) @(posedge clk);
        rst = 0;
        tick_step; tick_step;
        check_cond(uut.st == S_IDLE && idle && env == 0, "reposo: IDLE, env = 0");

        // ---------- ciclo completo A-D-S-R ----------
        gate = 1;
        run_until(S_DEC, 500000, n);
        check(n, 1 + ceil_div(MAXL, inc_a), "ataque");
        check_cond(env == 256, "fin de ataque: env = 256");

        run_until(S_SUS, 500000, n);
        check(n, ceil_div(MAXL - sus_lvl, inc_d), "decay");
        check_cond(uut.lvl == sus_lvl, "fin de decay: nivel = S");

        for (i = 0; i < 200; i = i + 1) tick_step;
        check_cond(uut.st == S_SUS && uut.lvl == sus_lvl, "sustain estable 200 ticks");

        gate = 0;
        run_until(S_IDLE, 500000, n);
        check(n, 1 + ceil_div(sus_lvl, inc_r), "release");
        check_cond(env == 0 && idle, "fin de release: env = 0, IDLE");

        // ---------- soltar a mitad del ataque ----------
        gate = 1;
        for (i = 0; i < ceil_div(MAXL, inc_a) / 2; i = i + 1) tick_step;   // mitad del ataque
        lvl_prev = uut.lvl;
        check_cond(uut.st == S_ATK && lvl_prev > 0 && lvl_prev < MAXL, "a mitad de ataque");
        gate = 0;
        tick_step;
        check_cond(uut.st == S_REL && uut.lvl == lvl_prev, "release arranca desde el nivel actual");
        run_until(S_IDLE, 500000, n);
        check(n, ceil_div(lvl_prev, inc_r), "release parcial");

        // ---------- retrigger durante el release (sin saltar a 0) ----------
        gate = 1;
        for (i = 0; i < ceil_div(MAXL, inc_a) / 2; i = i + 1) tick_step;  // sube a mitad de ataque
        gate = 0;
        for (i = 0; i < ceil_div(MAXL, inc_r) / 8; i = i + 1) tick_step;  // baja un poco
        lvl_prev = uut.lvl;
        check_cond(uut.st == S_REL && lvl_prev > 0, "en release con nivel > 0");
        gate = 1;
        tick_step;
        check_cond(uut.st == S_ATK && uut.lvl == lvl_prev, "retrigger: ATK desde el nivel actual");
        tick_step;
        check_cond(uut.lvl > lvl_prev, "retrigger: el nivel sigue subiendo");

        // ---------- cambio de S en sustain: transicion sin saltos ----------
        run_until(S_SUS, 500000, n);
        if (sus_lvl > 4 * inc_d) begin                       // hay margen para bajar S
            sus_lvl = sus_lvl / 2;
            lvl_prev = uut.lvl;
            tick_step;
            check_cond(lvl_prev - uut.lvl == inc_d, "S baja: desliza a razon inc_d");
            for (i = 0; i < 400000; i = i + 1) tick_step;
            check_cond(uut.lvl == sus_lvl, "S baja: converge al nuevo nivel");
        end else
            $display("omitido S baja (S demasiado cerca de 0)");

        // ---------- S = 1.0: DEC pasa de largo ----------
        gate = 0;
        run_until(S_IDLE, 500000, n);
        sus_lvl = MAXL;
        gate = 1;
        run_until(S_DEC, 500000, n);
        tick_step;
        check_cond(uut.st == S_SUS && uut.lvl == MAXL, "S = 1.0: DEC -> SUS inmediato");

        $display("");
        if (errores == 0) $display("tb_envelope: TODO OK");
        else              $display("tb_envelope: %0d FALLAS", errores);
        $finish;
    end

endmodule
