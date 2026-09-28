# Sumador/Restador de 4 Bits y Control Térmico de Caldera en FPGA

## Descripción del Proyecto
Esta parte del proyecto implementa un sumador/restador de 4 bits (`sumador_restador4b`) en Verilog. Basado en el sumador jerárquico `sumador4b` del mismo laboratorio y se le añade cuatro compuertas XOR y una señal de control `sel`. Con `sel = 0` calcula $A + B$ y con `sel = 1` calcula $A - B$ mediante complemento a 2.

Sobre este bloque se construye el reto de diseño (sobre el control térmico de una caldera industrial). El sistema `control_termico` calcula $R = T - L$ con el sumador/restador y enciende uno de tres LED según el signo de $R$, usando únicamente lógica combinacional adicional y sin comparadores dedicados. El diseño está pensado para la tarjeta Altera/Intel Cyclone IV EP4CE10E22C8N.

## Descripción de Hardware del Sumador/Restador

### Fundamento
En 4 bits, el negativo de $B$ es $16 - B$. Como $16 - B = (15 - B) + 1$ y $15 - B$ es la inversión bit a bit de $B$, entonces:

$$A - B = A + (\sim B + 1)$$

La compuerta XOR deja pasar el bit si su otra entrada vale 0 y lo invierte si vale 1. Cada bit de $B$ pasa por una XOR controlada por `sel`, luego el circuito obtiene $B$ o $\sim B$. La misma señal `sel` entra al carry out inicial del primer sumador de 1 bit y aporta $+1$ del complemento a 2.

| sel | Entrada `b` del sumador | `carryIn` | Operación |
|:---:|:-----------------------:|:---------:|:---------:|
| 0   | `b`                     | 0         | $A + B$   |
| 1   | `~b`                    | 1         | $A - B$   |


### Interpretación de `carryOut` en la resta
Con `sel = 1` el sumador de 4 bits calcula: suma de 5 bits $A + \sim B + 1 = 16 + (A - B)$. El bit 4 de esa suma es el `carryOut`, por lo que vale 1 cuando $A \geq B$.

| Caso    | `carryOut` | `resultado`                                        |
|:-------:|:----------:|----------------------------------------------------|
| $A < B$ | 0          | $16 - (B - A)$, complemento a 2 de $B - A$         |
| $A = B$ | 1          | `0000`                                             |
| $A > B$ | 1          | $A - B$                                            |

Con $A = B$ el `carryOut` vale 1, así que ese bit no distingue entre cero y positivo. Para separarlos se revisa si `resultado` es `0000`. El bit `resultado[3]` tampoco sirve igno cuancomo sdo los operandos se interpretan sin signo: $15 - 0$ da `1111` y es positivo.

Ejemplos verificados en simulación:

| Operación | `a`    | `b`    | `resultado` | `carryOut` | Lectura                |
|:---------:|:------:|:------:|:-----------:|:----------:|------------------------|
| $9 - 4$   | `1001` | `0100` | `0101` (5)  | 1          | positivo               |
| $7 - 5$   | `0111` | `0101` | `0010` (2)  | 1          | positivo               |
| $5 - 5$   | `0101` | `0101` | `0000` (0)  | 1          | cero                   |
| $3 - 7$   | `0011` | `0111` | `1100` (12) | 0          | $-4$ en complemento a 2 |
| $0 - 15$  | `0000` | `1111` | `0001` (1)  | 0          | $-15$ en complemento a 2 |

## Reto de Diseño: Control Térmico de Caldera

### Especificación
| Señal         | Tipo    | Descripción                                        |
|:--------------|:--------|:---------------------------------------------------|
| `t[3:0]`      | entrada | Temperatura medida                                 |
| `l[3:0]`      | entrada | Temperatura objetivo                               |
| `sel`         | entrada | Modo del sumador/restador (1 = resta $T - L$)      |
| `processLed`  | salida  | $R < 0$, producto en fabricación                   |
| `perfectLed`  | salida  | $R = 0$, condición ideal                           |
| `burnLed`     | salida  | $R > 0$, producto quemado                          |
| `r[3:0]`      | salida  | Resultado del restador (para display y pruebas)    |
| `carryOut`    | salida  | Carry Out del restador (para LED y pruebas)          |

### Lógica de decisión
`t` y `l` se interpretan como números sin signo de 0 a 15. Sea `cero = ~(r[3] | r[2] | r[1] | r[0])`. Las salidas son:

$$processLed = sel \cdot \overline{carryOut}$$

$$perfectLed = sel \cdot carryOut \cdot cero$$

$$burnLed = sel \cdot carryOut \cdot \overline{cero}$$

| sel | carryOut | cero | processLed | perfectLed | burnLed | Condición            |
|:---:|:--------:|:----:|:----------:|:----------:|:-------:|:---------------------|
| 0   | X        | X    | 0          | 0          | 0       | Modo suma, LED apagados |
| 1   | 0        | 0    | 1          | 0          | 0       | $T < L$              |
| 1   | 1        | 1    | 0          | 1          | 0       | $T = L$              |
| 1   | 1        | 0    | 0          | 0          | 1       | $T > L$              |

La combinación `sel = 1`, `carryOut = 0`, `cero = 1` no ocurre, porque con $T < L$ el resultado está entre 1 y 15. En el modo resta las tres condiciones son excluyentes y se cubren todos los casos, así que siempre hay exactamente un LED encendido.

### Diseño
1. Sin comparadores dedicados. La comparación sale de `carryOut` y de un NOR de cuatro entradas sobre `r`. Los operadores `<` y `==` aparecen solo en el testbench. (inspirados en el modelo comparador propuesto por el profesor)
2. LED apagados con `sel = 0`. En modo suma el sumador calcula $T + L$ y esa cantidad no dice nada sobre el proceso. Sin la compuerta `sel`, al sumar $0 + 0$ se encendían `processLed` y `perfectLed` a la vez, y en total 256 de las 256 combinaciones de `t` y `l` dejaban algún LED encendido.
3. `r` y `carryOut` como salidas adicionales. Se quería mostrar el resultado en el display y el Carry Out en un LED sin duplicar el restador.
4. Lectura del display en resta. Si $T < L$, el display muestra $16 - (L - T)$ en hexadecimal (por ejemplo, $3 - 7$ muestra `C`, que es $-4$ en complemento a 2). En este caso el LED `processLed` confirma que el resultado es negativo.
5. Límite del diseño. Con operandos sin signo el rango es 0 a 15. Si el sensor entregara temperaturas con signo, la comparación necesitaría además la bandera de desbordamiento del complemento a 2.

## Interfaz Física
El módulo de nivel superior `controlTermicoDisplay` usa los mismos switches y el mismo display que `sumadorDisplay`:

* Entradas DIP Switches: ocho interruptores ingresan $T$ (`sw_t`) y $L$ (`sw_l`) en binario. Un interruptor adicional (`sw_sel`) selecciona suma (0) o resta (1).
* Salida de Resultado en Display: `r` se decodifica a hexadecimal con `hex7seg.v` y se muestra en el primer dígito del display.
* Salida de Carry Out LED: `led_carryOut` muestra el `carryOut` del sumador/restador. En suma indica que el resultado supera 15 (se suman 16 al valor del display). En resta indica $T \geq L$.
* Salidas de Estado LED: `led_process`, `led_perfect` y `led_burn` indican $R < 0$, $R = 0$ y $R > 0$. Solo se encienden con `sw_sel = 1`.

## Estructura de Módulos
* `sumador1b.v` y `sumador4b.v`: sumador completo de 1 bit y sumador de 4 bits en cascada (parte 1 del laboratorio).
* `sumador_restador4b.v`: sumador/restador de 4 bits. Cuatro XOR sobre `b` y `sel` como Carry Out inicial de `sumador4b`.
* `control_termico.v`: instancia el sumador/restador y decodifica su resultado en los tres LED de estado.
* `hex7seg.v`: decodificador de 4 bits a display de 7 segmentos (hexadecimal, activo en bajo).
* `controlTermicoDisplay.v`: módulo de nivel superior. Conecta `control_termico` y `hex7seg` con los pines de la tarjeta.
* `sumador_restador4b_tb.v` y `control_termico_tb.v`: testbenches con casos dirigidos y verificación exhaustiva.

## Mapeo de Pines (Pin Planner)
Las asignaciones de switches, display y `led_carryOut` son las de `sumadorDisplay` en `sumador_4b.qsf`.

| Señal en Verilog | Función Física                       | Pin Asignado |
|:-----------------|:-------------------------------------|:-------------|
| `sw_t[0]`        | Temperatura medida T0 (DIP Switch)   | `PIN_68`     |
| `sw_t[1]`        | Temperatura medida T1 (DIP Switch)   | `PIN_67`     |
| `sw_t[2]`        | Temperatura medida T2 (DIP Switch)   | `PIN_66`     |
| `sw_t[3]`        | Temperatura medida T3 (DIP Switch)   | `PIN_65`     |
| `sw_l[0]`        | Temperatura objetivo L0 (DIP Switch) | `PIN_64`     |
| `sw_l[1]`        | Temperatura objetivo L1 (DIP Switch) | `PIN_60`     |
| `sw_l[2]`        | Temperatura objetivo L2 (DIP Switch) | `PIN_59`     |
| `sw_l[3]`        | Temperatura objetivo L3 (DIP Switch) | `PIN_58`     |
| `sw_sel`         | Selector suma/resta (Switch)         | `PIN_89`     |
| `led_carryOut`   | Carry Out de salida (LED D1)           | `PIN_84`     |
| `led_process`    | Producto en fabricación (LED)        | `PIN_83`     |
| `led_perfect`    | Condición ideal (LED)                | `PIN_80`     |
| `led_burn`       | Producto quemado (LED)               | `PIN_77`     |
| `display[0]`     | Segmento a                       | `PIN_128`    |
| `display[1]`     | Segmento b                       | `PIN_121`    |
| `display[2]`     | Segmento c                       | `PIN_125`    |
| `display[3]`     | Segmento d                       | `PIN_129`    |
| `display[4]`     | Segmento e                       | `PIN_132`    |
| `display[5]`     | Segmento f                       | `PIN_126`    |
| `display[6]`     | Segmento g                       | `PIN_124`    |
| `dig_sel[0]`     | Habilitador Dígito 1                 | `PIN_133`    |
| `dig_sel[1]`     | Habilitador Dígito 2                 | `PIN_135`    |
| `dig_sel[2]`     | Habilitador Dígito 3                 | `PIN_136`    |
| `dig_sel[3]`     | Habilitador Dígito 4                 | `PIN_137`    |

## Evidencias de Simulación
Ambos testbenches ejecutan dos etapas. La primera aplica casos dirigidos, cada uno durante 20 ns, y produce las formas de onda. La segunda recorre las 512 combinaciones posibles de operandos y `sel`, y compara cada salida con un modelo de referencia escrito con operadores aritméticos (`+`, `-`, `<`, `==`) dentro del testbench.

### Sumador/restador
De 0 a 60 ns el circuito suma (`sel = 0`) y de 60 a 180 ns resta (`sel = 1`). En $9 + 7$ el resultado es 0 con `carryOut = 1`, es decir, 16. En $3 - 7$ el resultado es 12 con `carryOut = 0`, es decir, $-4$.

### Control térmico
Los primeros dos casos ($5 - 9$ y $0 - 15$) encienden `processLed`. Los dos siguientes ($9 - 9$ y $0 - 0$) encienden `perfectLed`. Los dos siguientes ($12 - 9$ y $15 - 0$) encienden `burnLed`. Con `sel = 0`, incluso en $0 + 0$, los tres LED permanecen apagados.
