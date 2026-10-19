# Generador PWM para servomotor (`generador_PWM`)

Módulo en Verilog que genera la señal PWM de control de un servomotor MG996R a partir de un selector de 4 bits. La posición se elige con `sw[3:0]` (16 posiciones) y el módulo entrega un pulso de **1 ms a 2 ms** dentro de un periodo fijo de **20 ms (50 Hz)**.

## Archivos

| Archivo | Descripción |
|---|---|
| `generador_PWM.v` | Módulo de diseño (DUT) |
| `generador_PWM_tb.v` | Testbench |<img width="1920" height="1080" alt="generador" src="https://github.com/user-attachments/assets/ab8d014d-0789-4d6d-b8a1-52ce4dfab321" />


## Interfaz

| Puerto | Dir. | Ancho | Descripción |
|---|---|---|---|
| `clk` | in | 1 | Reloj del sistema (por defecto 50 MHz) |
| `rst` | in | 1 | Reset síncrono, activo en alto. Pone el contador en 0 |
| `sw` | in | 4 | Posición del servo (0 a 15) |
| `servo_pwm` | out | 1 | Señal PWM hacia el servo |

**Parámetro:** `CLK_FREQ` (por defecto `50_000_000`). Todos los tiempos se calculan a partir de él, por lo que el módulo se adapta a otro reloj cambiando solo este valor.

## Funcionamiento

### Señal de control del servo

Un servo estándar espera un pulso cada 20 ms. El ancho del pulso define el ángulo: aproximadamente 1 ms corresponde a un extremo del recorrido y 2 ms al otro.

### Constantes (`localparam`)

Con `CLK_FREQ = 50 MHz` (Tclk = 20 ns):

| Constante | Fórmula | Valor | Equivale a |
|---|---|---|---|
| `PERIODO` | `CLK_FREQ / 50` | 1 000 000 | 20 ms |
| `TON_MIN` | `CLK_FREQ / 1000` | 50 000 | 1 ms |
| `TON_MAX` | `CLK_FREQ / 500` | 100 000 | 2 ms |
| `PASO` | `(TON_MAX - TON_MIN) / 15` | 3 333 | ≈ 66,66 µs por paso |

### Contador de periodo

`contador_periodo` (20 bits) cuenta ciclos de reloj desde 0 hasta `PERIODO - 1` y vuelve a 0, completando un periodo de 20 ms. Con `rst = 1` se reinicia a 0. Cuenta hasta 999 999, que cabe en 20 bits (máximo 1 048 575).

### Tiempo en alto

```verilog
assign t_on = TON_MIN + (sw * PASO);
```

El selector `sw` escala linealmente el ancho del pulso entre 1 ms y 2 ms en 16 pasos (15 intervalos).

### Comparador PWM

```verilog
assign servo_pwm = (contador_periodo < t_on);
```

La salida está en alto mientras el contador sea menor que `t_on` y en bajo el resto del periodo. Como `t_on` es combinacional, un cambio en `sw` modifica el ancho del pulso en el periodo siguiente al cambio, o en el actual si el contador aún no ha alcanzado `t_on`.

### Tabla de posiciones (50 MHz)

| `sw` | `t_on` (cuentas) | Ancho de pulso |
|---|---|---|
| 0 (`0000`) | 50 000 | 1,0000 ms |
| 8 (`1000`) | 76 664 | 1,5333 ms |
| 15 (`1111`) | 99 995 | 1,9999 ms |

> **Nota sobre la resolución:** `PASO` se calcula con división entera (50 000 / 15 = 3 333,33 → 3 333). Por eso `sw = 15` produce 99 995 cuentas (1,9999 ms) y no exactamente 2 ms. El error es de 5 cuentas (100 ns), despreciable para un servo, pero conviene tenerlo presente al medir.

## Simulación (testbench)

El testbench `generador_PWM_tb.v` instancia el módulo con `CLK_FREQ = 50 MHz` (reloj de 20 ns, conmutando cada 10 ns) y aplica la siguiente secuencia:

| Etapa | Tiempo | Estímulo | Ancho de pulso esperado |
|---|---|---|---|
| 1 | 0 – 100 ns | `rst = 1`, `sw = 0000` | — (reset) |
| 2 | 100 ns – 22 ms | `rst = 0`, `sw = 0000` | 1 ms |
| 3 | 22 ms – 44 ms | `sw = 1000` (8) | ≈ 1,533 ms |
| 4 | 44 ms – 66 ms | `sw = 1111` (15) | ≈ 2 ms (1,9999 ms) |

Cada etapa dura 22 ms para que quepa al menos un periodo completo de 20 ms con el nuevo valor de `sw`. Los cambios de `sw` ocurren cuando el pulso del periodo en curso ya terminó, por lo que no se generan pulsos cortados. El tiempo total simulado es de unos 66 ms (≈ 3,3 millones de ciclos de reloj).

Durante el reset el contador vale 0, así que `servo_pwm` ya está en alto desde el inicio (0 < `t_on`). Esto es normal: el primer pulso arranca en el instante 0 en lugar de esperar a que se libere el reset.

El testbench imprime mensajes con `$display` al liberar el reset, en cada cambio de `sw` y al terminar.

### Resultados

Vista completa (0 – 66 ms), con los tres anchos de pulso:

<img width="1920" height="1080" alt="generador" src="https://github.com/user-attachments/assets/c55e2c6c-0b61-438a-94ac-8d719a743d4d" />

Detalle del pulso con `sw = 0` (1 ms de 20 ms):

<img width="1920" height="1080" alt="Pulso_pos0" src="https://github.com/user-attachments/assets/b6c254fc-3a37-4129-9fa7-79e64cb15356" />

Detalle del pulso con `sw = 8` (≈ 1,53 ms):

<img width="1920" height="1080" alt="pulso_pos8" src="https://github.com/user-attachments/assets/0b5db23c-b497-420e-a800-ecd4f4f9d7e7" />

Detalle del pulso con `sw = 15` (≈ 2 ms):

<img width="1920" height="1080" alt="pulso_pos15" src="https://github.com/user-attachments/assets/7c436c8e-f343-4bb9-8e05-070d1c943f49" />

Con los cursores se puede medir el ancho de cada pulso y comprobar que coincide con la tabla de posiciones.
