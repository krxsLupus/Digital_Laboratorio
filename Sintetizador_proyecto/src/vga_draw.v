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

    always @(*) begin
        case(sel_onda)
            // Cuadrada: Arriba en la primera mitad, abajo en la segunda
            2'd0: y_onda = (fase < 256) ? 140 : 340; 
            // Sierra: Rampa descendente (la pantalla crece hacia abajo)
            2'd1: y_onda = 396 - (fase[7:0]);        
            // Triangular: Rampa que sube y baja
            2'd2: y_onda = (fase[8] == 0) ? (140 + fase[7:0]) : (396 - fase[7:0]); 
            default: y_onda = 240; // Línea central plana
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