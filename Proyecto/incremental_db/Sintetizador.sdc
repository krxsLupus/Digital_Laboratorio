# Sintetizador.sdc
# Restricciones de tiempo para top_sintetizador (Cyclone IV E, reloj de 50 MHz en PIN_23)

# 1. Reloj principal: 50 MHz -> periodo de 20 ns
create_clock -name clk -period 20.000 [get_ports clk]

# 2. Incertidumbre de reloj (jitter, ruido). Quartus la calcula solo.
derive_clock_uncertainty

# 3. Entradas externas: todas menos clk.
#    Incluye rst, columnas del teclado (cols_tec), encoders (pin_a/b, vol_a/b,
#    env_a/b), pulsadores (env_btn, oct_sube_n, oct_baja_n) y switches (pedal,
#    sw_eco, sw_seq_a_n, sw_seq_b_n).
#    Son senales humanas/mecanicas, sin relacion de fase con clk, y entran por
#    sincronizadores de 2 FF o se muestrean cada 1 ms.
#    Se les da un set_input_delay (para que el Timing Analyzer las considere
#    restringidas) y ademas un false path (para que no se analicen).
set entradas_async [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay -clock clk 0 $entradas_async
set_false_path -from $entradas_async

# 4. Salidas externas: todas.
#    Incluye rows_tec, seg, dig, led_sel, led_oct, i2s_bclk, i2s_lrclk, i2s_din
#    y las senales VGA. Ninguna tiene un requisito de fase respecto a clk que
#    valga la pena verificar aqui (I2S ~3 MHz, VGA, LEDs y displays tolerantes).
set_output_delay -clock clk 0 [all_outputs]
set_false_path -to [all_outputs]
