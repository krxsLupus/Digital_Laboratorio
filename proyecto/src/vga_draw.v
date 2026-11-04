module vga_draw(
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire       video_on,
    input  wire [1:0] sel_onda,
    output reg  [2:0] rgb      // Formato simple 3 bits: {R, G, B}
);
    // Usamos los bits bajos de X para generar un ciclo matemático
    wire [8:0] fase = x[8:0]; 
    reg  [9:0] y_onda;

    // 512 pixeles por ciclo: fase[8] = semiciclo, fase[7] = espejo, fase[6:1] = indice
    wire [5:0] idx_seno = fase[7] ? ~fase[6:1] : fase[6:1];
    wire [6:0] mag_seno;
    seno_lut u_seno (.idx(idx_seno), .mag(mag_seno));

    always @(*) begin
        case(sel_onda)
            // Cuadrada: Arriba en la primera mitad, abajo en la segunda
            2'd0: y_onda = (fase < 256) ? 140 : 340; 
            // Sierra: Rampa descendente (la pantalla crece hacia abajo)
            2'd1: y_onda = 396 - (fase[7:0]);        
            // Triangular: Rampa que sube y baja
            2'd2: y_onda = (fase[8] == 0) ? (140 + fase[7:0]) : (396 - fase[7:0]); 
            // Seno: cuarto de ciclo de seno_lut reflejado (centro en y = 268, igual que la triangular)
            2'd3: y_onda = fase[8] ? (10'd268 + mag_seno) : (10'd268 - mag_seno);
        endcase
    end

    // Dibuja una línea de 5 píxeles de grosor alrededor del valor de la onda
    wire trazo_activo = (y >= y_onda - 2) && (y <= y_onda + 2);

    always @(*) begin
        if (~video_on)        rgb = 3'b000; // Fuera de pantalla (negro)
        else if (trazo_activo)rgb = 3'b010; // Trazo de la onda (verde)
        else                  rgb = 3'b000; // Fondo de pantalla (negro)
    end
endmodule