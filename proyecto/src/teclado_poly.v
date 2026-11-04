// Escaner de matriz 4x3 CON DIODOS: detecta varias teclas a la vez.
//
// Polaridad (ACTIVO_ALTO = 1, la que se usa con diodos 1N4148):
//   La FPGA sube UNA fila a 1 (3,3 V) y deja las otras en alta impedancia.
//   Las columnas llevan una resistencia pull-down EXTERNA (10 kohm a GND).
//   Un 1 en una columna = pulsador de esa fila y esa columna presionado.
//   Cada diodo va con el ANODO hacia la fila y el CATODO (banda) hacia la columna.
//   Un pulsador presionado deja la columna en ~2,7 V (3,3 V menos la caida del
//   diodo), muy por encima del minimo de 1,7 V para leer un 1.
//
// Con ACTIVO_ALTO = 0 funciona al reves (fila a 0, columnas con pull-up, diodos
// con el catodo hacia la fila), pero un 1N4148 deja la columna cerca de 0,5 V y
// el margen frente al umbral de 0,8 V es muy justo.
//
// Los diodos evitan las lecturas fantasma: cada tecla se lee por separado
// aunque haya varias pulsadas.
//
// Salida: teclas[n] = 1 mientras la nota n esta pulsada (ya sin rebotes),
// con n = fila*3 + columna:
//   fila 0: Do  Do#  Re      fila 1: Re#  Mi  Fa
//   fila 2: Fa# Sol  Sol#    fila 3: La  La#  Si
module teclado_poly #(
    parameter integer CLK_FREQ    = 50_000_000,
    parameter integer DEB_MS      = 5,        // tiempo que debe durar un cambio para aceptarlo
    parameter integer ACTIVO_ALTO = 1         // 1: fila activa en 1, tecla = 1 | 0: fila activa en 0, tecla = 0
)(
    input  wire        clk,
    input  wire        rst,                   // activo en alto
    input  wire [2:0]  cols,                  // columnas (con pull-down externo si ACTIVO_ALTO = 1)
    output wire [3:0]  rows,                  // nivel activo en la fila escaneada, alta impedancia en las demas
    output wire [11:0] teclas                 // bit n = nota n pulsada
);

    // Nivel de la fila activa; las columnas en reposo valen lo contrario
    localparam ACT = (ACTIVO_ALTO != 0) ? 1'b1 : 1'b0;

    // Cada fila se mantiene 20 us antes de leerla, para que las columnas se
    // estabilicen. Un barrido completo de 4 filas dura 80 us.
    localparam integer STEP_CLKS = CLK_FREQ / 50000;
    localparam integer STEP_W    = $clog2(STEP_CLKS + 1);
    localparam integer SCAN_CLKS = 4 * STEP_CLKS;
    localparam integer DEB_SCANS = (DEB_MS * (CLK_FREQ / 1000)) / SCAN_CLKS;  // 62 con 5 ms
    localparam integer DEB_W     = $clog2(DEB_SCANS + 1);

    reg  [STEP_W-1:0] cnt = 0;
    wire tick = (cnt == STEP_CLKS - 1);

    always @(posedge clk) begin
        if (rst || tick) cnt <= 0;
        else             cnt <= cnt + 1'b1;
    end

    // Sincronizador de las columnas (entradas asincronas), iniciado en reposo
    reg [2:0] c1 = {3{~ACT}};
    reg [2:0] c2 = {3{~ACT}};
    always @(posedge clk) begin
        c1 <= cols;
        c2 <= c1;
    end

    // 1 donde hay pulsador presionado, sea cual sea la polaridad
    wire [2:0] c_pulsada = c2 ^ {3{~ACT}};

    // Fila activa
    reg [1:0] row_idx = 2'd0;
    assign rows[0] = (row_idx == 2'd0) ? ACT : 1'bz;
    assign rows[1] = (row_idx == 2'd1) ? ACT : 1'bz;
    assign rows[2] = (row_idx == 2'd2) ? ACT : 1'bz;
    assign rows[3] = (row_idx == 2'd3) ? ACT : 1'bz;

    // Lectura cruda: al final de cada paso se guardan las 3 columnas de la fila activa
    reg [11:0] raw = 12'd0;
    reg        scan_done = 1'b0;     // 1 ciclo despues de leer la fila 3 (raw ya esta completo)

    always @(posedge clk) begin
        scan_done <= 1'b0;
        if (rst) begin
            row_idx <= 2'd0;
            raw     <= 12'd0;
        end else if (tick) begin
            case (row_idx)
                2'd0: raw[2:0]     <= c_pulsada;
                2'd1: raw[5:3]     <= c_pulsada;
                2'd2: raw[8:6]     <= c_pulsada;
                default: raw[11:9] <= c_pulsada;
            endcase
            if (row_idx == 2'd3) scan_done <= 1'b1;
            row_idx <= row_idx + 1'b1;
        end
    end

    // Antirrebote por tecla: el cambio solo se acepta si la lectura cruda
    // difiere del estado filtrado durante DEB_SCANS barridos seguidos.
    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : deb
            reg               ok = 1'b0;     // estado filtrado de esta tecla
            reg [DEB_W-1:0]   n  = 0;
            assign teclas[i] = ok;

            always @(posedge clk) begin
                if (rst) begin
                    ok <= 1'b0;
                    n  <= 0;
                end else if (scan_done) begin
                    if (raw[i] == ok) begin
                        n <= 0;
                    end else if (n == DEB_SCANS - 1) begin
                        ok <= raw[i];
                        n  <= 0;
                    end else begin
                        n <= n + 1'b1;
                    end
                end
            end
        end
    endgenerate

endmodule
