# Asignaciones de pines - Slave: REMIX (placa 21eda, Cyclone IV EP4CE6E22) - version combinada
# Uso: con el proyecto abierto en Quartus, Tools > Tcl Scripts (o la consola Tcl):
#   source pines_sintetizador.tcl
# Luego revisa el Pin Planner (columna Location) y recompila.

# ---------------------------------------------------------------
# 1. Estandar de I/O: los bancos de la placa se alimentan a 3.3 V
# ---------------------------------------------------------------
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
foreach p {clk rst cols_tec[*] rows_tec[*] pin_a pin_b vol_a vol_b oct_sube_n oct_baja_n env_a env_b env_btn pedal sw_eco sw_seq_a_n sw_seq_b_n i2s_bclk i2s_lrclk i2s_din seg[*] dig[*] led_sel[*] led_oct[*] vga_hs vga_vs vga_r vga_g vga_b} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to $p
}

# ---------------------------------------------------------------
# 2. Reloj y reset de la placa
# ---------------------------------------------------------------
set_location_assignment PIN_23 -to clk          ;# oscilador de 50 MHz
set_location_assignment PIN_90 -to rst          ;# boton K2 (activo en bajo)

# ---------------------------------------------------------------
# 3. Teclado matricial 4x3 con diodos (header de expansion)
#    Las columnas llevan resistencia pull-down externa de 10 kohm a GND.
# ---------------------------------------------------------------
set_location_assignment PIN_49 -to rows_tec[0]  ;# header pin 15
set_location_assignment PIN_44 -to rows_tec[1]  ;# header pin 13
set_location_assignment PIN_42 -to rows_tec[2]  ;# header pin 11
set_location_assignment PIN_39 -to rows_tec[3]  ;# header pin 7
set_location_assignment PIN_34 -to cols_tec[0]  ;# header pin 5
set_location_assignment PIN_32 -to cols_tec[1]  ;# header pin 3
set_location_assignment PIN_30 -to cols_tec[2]  ;# header pin 1
foreach c {cols_tec[0] cols_tec[1] cols_tec[2]} {
    set_instance_assignment -name WEAK_PULL_UP_RESISTOR OFF -to $c
}

# ---------------------------------------------------------------
# 4. Encoders KY-040 (alimentarlos con 3.3 V) y pulsadores (header de expansion)
#    GND del header: pines 10, 17, 25, 26
# ---------------------------------------------------------------
set_location_assignment PIN_28 -to pin_a        ;# header pin 2   encoder de onda: CLK
set_location_assignment PIN_31 -to pin_b        ;# header pin 4   encoder de onda: DT
set_location_assignment PIN_33 -to vol_a        ;# header pin 6   encoder de volumen: CLK
set_location_assignment PIN_38 -to vol_b        ;# header pin 8   encoder de volumen: DT
set_location_assignment PIN_52 -to env_a        ;# header pin 19  encoder de parametros: CLK
set_location_assignment PIN_54 -to env_b        ;# header pin 21  encoder de parametros: DT
set_location_assignment PIN_50 -to env_btn      ;# header pin 16  encoder de parametros: SW (GND en el pin 25)

# Pulsadores de octava: entre el pin y GND (GND en el header pin 10). Usan el pull-up interno.
set_location_assignment PIN_43 -to oct_sube_n   ;# header pin 12  octava arriba
set_location_assignment PIN_46 -to oct_baja_n   ;# header pin 14  octava abajo
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to oct_sube_n
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to oct_baja_n
# El KY-040 ya trae pull-ups en su modulo; el interno ayuda si el cable queda flotando
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to env_btn

# ---------------------------------------------------------------
# 5. Salida I2S al MAX98357A (header de expansion, GND en el pin 26)
# ---------------------------------------------------------------
set_location_assignment PIN_51 -to i2s_bclk     ;# header pin 20  -> BCLK del modulo
set_location_assignment PIN_53 -to i2s_lrclk    ;# header pin 22  -> LRC  del modulo
set_location_assignment PIN_55 -to i2s_din      ;# header pin 24  -> DIN  del modulo

# ---------------------------------------------------------------
# 6. Interruptores DIP de la placa (SW DIP-8, con pull-up de 4.7 kohm; ON = 0)
# ---------------------------------------------------------------
set_location_assignment PIN_58 -to pedal        ;# SW1: pedal de sustain (ON = pedal abajo)
set_location_assignment PIN_59 -to sw_eco       ;# SW2: eco (ON = eco encendido)

# Interruptores del secuenciador (toggle de 2 posiciones entre el pin y GND; GND = header pin 26 o 17)
#   A cerrado = PLAY | A y B cerrados = REC | solo B cerrado = CLEAR (mantener 1 s) | ninguno = STOP
set_location_assignment PIN_89 -to sw_seq_a_n   ;# header pin 27  (necesita pull-up EXTERNO de 10k a 3.3 V)
set_location_assignment PIN_88 -to sw_seq_b_n   ;# header pin 28  (necesita pull-up EXTERNO de 10k a 3.3 V)

# LEDs externos de modo del secuenciador (pin -> 330 ohm -> LED -> GND; se encienden con 1)
set_location_assignment PIN_110 -to led_seq_play   ;# verde: el loop corre (PLAY/REC)
set_location_assignment PIN_106 -to led_seq_rec    ;# rojo: parpadea esperando el inicio, fijo grabando
set_location_assignment PIN_105 -to led_seq_clear  ;# amarillo: modo CLEAR

# ---------------------------------------------------------------
# 7. LED de la placa (D3..D14, anodo a 3.3 V: se encienden con 0)
# ---------------------------------------------------------------
set_location_assignment PIN_72 -to led_sel[0]   ;# D3   parametro A
set_location_assignment PIN_73 -to led_sel[1]   ;# D4   parametro D
set_location_assignment PIN_74 -to led_sel[2]   ;# D5   parametro S
set_location_assignment PIN_80 -to led_sel[3]   ;# D6   parametro R
set_location_assignment PIN_83 -to led_sel[4]   ;# D7   eco: tiempo
set_location_assignment PIN_84 -to led_sel[5]   ;# D8   eco: realimentacion
set_location_assignment PIN_77 -to led_sel[6]   ;# D9   eco: mezcla
set_location_assignment PIN_76 -to led_sel[7]   ;# D10  tempo (BPM)
set_location_assignment PIN_75 -to led_oct[0]   ;# D11  octava 3
set_location_assignment PIN_71 -to led_oct[1]   ;# D12  octava 4
set_location_assignment PIN_70 -to led_oct[2]   ;# D13  octava 5
set_location_assignment PIN_69 -to led_oct[3]   ;# D14  octava 6

# ---------------------------------------------------------------
# 8. Displays de 7 segmentos (4 digitos, catodo comun multiplexado)
# ---------------------------------------------------------------
set_location_assignment PIN_127 -to seg[0]
set_location_assignment PIN_126 -to seg[1]
set_location_assignment PIN_125 -to seg[2]
set_location_assignment PIN_124 -to seg[3]
set_location_assignment PIN_121 -to seg[4]
set_location_assignment PIN_120 -to seg[5]
set_location_assignment PIN_119 -to seg[6]
set_location_assignment PIN_128 -to dig[0]
set_location_assignment PIN_129 -to dig[1]
set_location_assignment PIN_132 -to dig[2]
set_location_assignment PIN_133 -to dig[3]

# ---------------------------------------------------------------
# 9. VGA
# ---------------------------------------------------------------
set_location_assignment PIN_142 -to vga_hs
set_location_assignment PIN_143 -to vga_vs
set_location_assignment PIN_2   -to vga_r
set_location_assignment PIN_1   -to vga_g
set_location_assignment PIN_144 -to vga_b

# ---------------------------------------------------------------
# 10. Pines sin usar como entradas en alta impedancia
# ---------------------------------------------------------------
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"

export_assignments
