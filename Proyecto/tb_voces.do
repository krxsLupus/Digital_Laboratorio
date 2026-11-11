# Vista de ondas para tb_voces (en Questa:  do tb_voces.do)
quietly delete wave *
add wave -label onda -radix unsigned sim:/tb_voces/sel_onda
add wave -label teclas -radix binary sim:/tb_voces/teclas

# Onda de cada tecla por separado (en orden de nota, de Do a Si)
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label Do sim:/tb_voces/v_do
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label Do# sim:/tb_voces/v_do_s
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label Re sim:/tb_voces/v_re
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label Re# sim:/tb_voces/v_re_s
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label Mi sim:/tb_voces/v_mi
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label Fa sim:/tb_voces/v_fa
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label Fa# sim:/tb_voces/v_fa_s
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label Sol sim:/tb_voces/v_sol
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label Sol# sim:/tb_voces/v_sol_s
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label La sim:/tb_voces/v_la
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label La# sim:/tb_voces/v_la_s
add wave -group "Teclas por separado" -radix decimal -format analog-step -height 36 -min -128 -max 127 -label Si sim:/tb_voces/v_si

# La suma de todas, aparte y mas grande
add wave -divider "Suma de las 12 voces"
add wave -radix decimal -format analog-step -height 140 -min -600000 -max 600000 -label "suma (banco_notas)" sim:/tb_voces/suma
add wave -radix decimal -format analog-step -height 70 -min -600000 -max 600000 -label "suma_ideal" sim:/tb_voces/suma_ideal

wave zoom full
