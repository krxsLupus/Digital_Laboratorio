module vga_sync(
    input  wire clk,       // Reloj base de 50 MHz
    output reg  hsync,     // Sincronismo horizontal
    output reg  vsync,     // Sincronismo vertical
    output wire video_on,  // 1 cuando estamos en la zona visible
    output wire [9:0] p_x, // Coordenada X (0-639)
    output wire [9:0] p_y  // Coordenada Y (0-479)
);
    // Generador de Pixel Clock (25 MHz)
    reg p_tick = 0;
    always @(posedge clk) p_tick <= ~p_tick;

    // Parámetros VGA 640x480 @ 60Hz
    localparam HD = 640, HF = 16, HB = 48, HR = 96, HMAX = 799;
    localparam VD = 480, VF = 10, VB = 33, VR = 2,  VMAX = 524;

    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    always @(posedge clk) begin
        if (p_tick) begin
            if (h_count == HMAX) begin
                h_count <= 0;
                if (v_count == VMAX) v_count <= 0;
                else                 v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (p_tick) begin
            hsync <= ~(h_count >= (HD + HF) && h_count < (HD + HF + HR));
            vsync <= ~(v_count >= (VD + VF) && v_count < (VD + VF + VR));
        end
    end

    assign video_on = (h_count < HD) && (v_count < VD);
    assign p_x = h_count;
    assign p_y = v_count;
endmodule