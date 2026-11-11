# Vista de ondas para tb_polifonia (en Questa:  do tb_polifonia.do)
quietly delete wave *
add wave -radix unsigned  sim:/tb_polifonia/sel_onda
add wave -radix binary    sim:/tb_polifonia/teclas
add wave -radix decimal -format analog-step -height 70 -min -600000 -max 600000 sim:/tb_polifonia/suma
add wave -radix decimal -format analog-step -height 70 -min -32768  -max 32767  sim:/tb_polifonia/muestra
add wave -radix decimal sim:/tb_polifonia/atenuada
wave zoom full
