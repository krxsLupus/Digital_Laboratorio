# Asignaciones de pines - Slave: REMIX (placa 21eda, Cyclone IV EP4CE1'E22)

set_global_assignment -name DEVICE EP4CE10E22C8

# ---------------------------------------------------------------
# 2. Estandar de I/O: los bancos de la placa se alimentan a 3.3 V
# ---------------------------------------------------------------
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
foreach p {clk rst cols_tec[*] rows_tec[*] pin_a pin_b dac[*] seg[*] dig[*] vga_hs vga_vs vga_r vga_g vga_b} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to $p
}

# ---------------------------------------------------------------
# 3. DAC R-2R de 8 bits en pines libres del header de 2x14
#    (dac[7] = MSB). No usan teclado, encoder, DIP, displays ni VGA.
# ---------------------------------------------------------------
set_location_assignment PIN_54 -to {dac[7]}
set_location_assignment PIN_53 -to {dac[6]}
set_location_assignment PIN_52 -to {dac[5]}
set_location_assignment PIN_51 -to {dac[4]}
set_location_assignment PIN_50 -to {dac[3]}
set_location_assignment PIN_43 -to {dac[2]}
set_location_assignment PIN_38 -to {dac[1]}
set_location_assignment PIN_33 -to {dac[0]}

# ---------------------------------------------------------------
# 4. Pull-ups internos para las columnas del teclado
# ---------------------------------------------------------------
foreach c {cols_tec[0] cols_tec[1] cols_tec[2]} {
    set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to $c
}

# ---------------------------------------------------------------
# 5. Pines sin usar como entradas en alta impedancia, para no
#    manejar DIP, LEDs ni botones conectados a ellos
# ---------------------------------------------------------------
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"

export_assignments
