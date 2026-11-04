# Asignaciones de pines - Slave: REMIX (placa 21eda, Cyclone IV EP4CE6E22)
# Uso: con el proyecto abierto en Quartus, Tools > Tcl Scripts (o la consola Tcl):
#   source pines_sintetizador.tcl
# Luego revisa el Pin Planner (columna Location) y recompila.

# ---------------------------------------------------------------
# 1. Dispositivo (opcional): la placa trae EP4CE6E22C8N
#    (o EP4CE10E22C8N, segun el chip). Descomenta la linea que corresponda.
# ---------------------------------------------------------------
# set_global_assignment -name DEVICE EP4CE6E22C8

# ---------------------------------------------------------------
# 2. Estandar de I/O: los bancos de la placa se alimentan a 3.3 V
# ---------------------------------------------------------------
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
foreach p {clk rst cols_tec[*] rows_tec[*] pin_a pin_b vol_a vol_b i2s_bclk i2s_lrclk i2s_din seg[*] dig[*] vga_hs vga_vs vga_r vga_g vga_b} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to $p
}

# ---------------------------------------------------------------
# 3. Salida I2S al MAX98357A, en pines libres del header de expansión 2x14.
#    header pin 26 es GND, justo al lado: usalo como tierra de las señales.
# ---------------------------------------------------------------
set_location_assignment PIN_51 -to i2s_bclk    ;# header pin 20  -> BCLK del modulo
set_location_assignment PIN_53 -to i2s_lrclk   ;# header pin 22  -> LRC  del modulo
set_location_assignment PIN_55 -to i2s_din     ;# header pin 24  -> DIN  del modulo

# Encoder de volumen (header pins 6 y 8; GND en el pin 10; alimentalo con 3.3 V)
set_location_assignment PIN_33 -to vol_a       ;# header pin 6  -> CLK
set_location_assignment PIN_38 -to vol_b       ;# header pin 8  -> DT

# ---------------------------------------------------------------
# 4. Columnas del teclado: SIN pull-up interno.
#    Con ACTIVO_ALTO = 1 las columnas llevan una resistencia pull-down externa
#    de 10 kohm a GND. Si quedara activo el pull-up interno de una corrida
#    anterior de este script, formaria un divisor con la resistencia y las
#    columnas no leerian bien en reposo; por eso se pone OFF de forma explicita.
# ---------------------------------------------------------------
foreach c {cols_tec[0] cols_tec[1] cols_tec[2]} {
    set_instance_assignment -name WEAK_PULL_UP_RESISTOR OFF -to $c
}

# ---------------------------------------------------------------
# 5. Pines sin usar como entradas en alta impedancia, para no
#    manejar DIP, LEDs ni botones conectados a ellos
# ---------------------------------------------------------------
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"

export_assignments
