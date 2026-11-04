# Sintetizador.sdc
# Restricciones de tiempo para top_sintetizador (Cyclone IV E, reloj de 50 MHz en PIN_23)

# 1. Reloj principal: 50 MHz -> periodo de 20 ns
create_clock -name clk -period 20.000 [get_ports clk]

# 2. Incertidumbre de reloj (jitter, ruido). Quartus la calcula solo.
derive_clock_uncertainty

# 3. Entradas externas: reset, columnas del teclado y los dos encoders.
#    Son señales humanas/mecanicas, sin relacion de fase con clk.
set_false_path -from [get_ports {rst cols_tec[*] pin_a pin_b vol_a vol_b}]

# 4. Salidas externas: filas del teclado, displays, I2S y VGA.
#    Ninguna tiene un requisito de fase respecto a clk que valga la pena
#    verificar aqui (I2S ~3 MHz, VGA y displays tolerantes).
set_false_path -to [get_ports {rows_tec[*] seg[*] dig[*] i2s_bclk i2s_lrclk i2s_din vga_hs vga_vs vga_r vga_g vga_b}]
