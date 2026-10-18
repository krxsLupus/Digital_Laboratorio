# Laboratorio 3

Calculadora de dos números de 4 bits (A y B) que realiza las cuatro combinaciones de suma y resta con signo: **A + B, A − B, −A + B y −A − B**. El resultado (de −30 a +30) se muestra en displays de 7 segmentos, con el signo en un display aparte. El sistema se divide en los siguientes módulos de Verilog:

| Módulo             | Función                                                                                   |
|--------------------|-------------------------------------------------------------------------------------------|
| `sumador_restador` | Aplica el signo a cada operando (`negA`, `negB`) y los suma. Entrega `R` en complemento a 2 de 6 bits. |
| `detector_signo`   | Obtiene el signo de `R` y su magnitud (valor absoluto).                                   |
| `bin_bcd`          | Separa la magnitud (0 a 30) en decenas y unidades (BCD).                                  |
| `bcd_7s`           | Convierte un dígito BCD en el patrón de los segmentos a-g.                                |
| `top_calculadora`  | Selecciona el modo con pulsadores, une todos los módulos y multiplexa los displays en la FPGA. |

## Primer bloque (Sumador / restador)
Para el primer bloque se diseñó un circuito que recibe dos números de 4 bits, A y B, y dos señales de control, `negA` y `negB`, que indican si cada operando se toma con signo negativo. De esta forma, una sola estructura permite realizar las cuatro operaciones:

| `negA` | `negB` | Operación |
|--------|--------|-----------|
| 0      | 0      | A + B     |
| 0      | 1      | A − B     |
| 1      | 0      | −A + B    |
| 1      | 1      | −A − B    |

```
module sumador_restador (
    input  wire [3:0] A,
    input  wire [3:0] B,
    input  wire       negA,   // 1: se usa -A
    input  wire       negB,   // 1: se usa -B
    output wire [5:0] R       // complemento a 2 de 6 bits (rango -30..+30)
);
    // Se extiende a 6 bits para que -30 (-A-B con A=B=15) quepa con signo
    wire [5:0] A_xor = {2'b00, A} ^ {6{negA}};  // complemento a 1 de A si negA
    wire [5:0] B_xor = {2'b00, B} ^ {6{negB}};  // complemento a 1 de B si negB

    // +negA y +negB completan el complemento a 2 de cada operando
    assign R = A_xor + B_xor + negA + negB;

endmodule
```

El funcionamiento es el siguiente:

1. Cada operando se extiende a 6 bits con dos ceros a la izquierda. Esto es necesario porque el valor más negativo posible, −A − B con A = B = 15, es −30, que no cabe en 5 bits con signo. Con 6 bits en complemento a 2 el rango es −32..+31, que cubre todo el rango −30..+30.
2. Cada operando se pasa por una XOR con su señal de signo replicada en los 6 bits: si `negX = 0` queda igual, y si `negX = 1` se obtiene su complemento a 1.
3. Los términos `+ negA` y `+ negB` de la suma completan el complemento a 2 (`~X + 1`) de los operandos negativos.

El resultado `R` queda en complemento a 2 de 6 bits: `R[5]` es el bit de signo (1 si el resultado es negativo) y, cuando es negativo, `R[4:0]` contiene el complemento a 2 de su magnitud. Como el resultado máximo en valor absoluto es 30, con 6 bits no puede ocurrir desbordamiento y no se necesita una señal de error.

A continuación se adjunta la evidencia de funcionamiento haciendo uso de GTKWave. Se plantearon casos para los cuatro modos con un par de valores intermedios (A = 9, B = 5) y con los valores extremos (A = B = 15):

<img width="1920" height="1080" alt="Captura de pantalla de 2026-10-18 14-37-27" src="https://github.com/user-attachments/assets/fdbc1de7-6039-462d-9dd4-7308d6031d93" />

Para mayor comodidad, se adjuntan también los resultados en binario:

<img width="1920" height="1080" alt="Captura de pantalla de 2026-10-18 14-36-41" src="https://github.com/user-attachments/assets/bfb8961d-2233-4740-9ff3-f4f52a2f46af" />


Los valores esperados de `R` para estos casos son:

| A  | B  | `negA` `negB` | Operación | Valor | `R` (binario) | `R` (hex) |
|----|----|---------------|-----------|-------|---------------|-----------|
| 9  | 5  | 0 0           | A + B     | +14   | `001110`      | `0E`      |
| 9  | 5  | 0 1           | A − B     | +4    | `000100`      | `04`      |
| 9  | 5  | 1 0           | −A + B    | −4    | `111100`      | `3C`      |
| 9  | 5  | 1 1           | −A − B    | −14   | `110010`      | `32`      |
| 15 | 15 | 0 0           | A + B     | +30   | `011110`      | `1E`      |
| 15 | 15 | 0 1           | A − B     | 0     | `000000`      | `00`      |
| 15 | 15 | 1 0           | −A + B    | 0     | `000000`      | `00`      |
| 15 | 15 | 1 1           | −A − B    | −30   | `100010`      | `22`      |

## Segundo y tercer bloque (Detector de signo y calculador de magnitud)

El detector de signo toma el resultado `R` y entrega el signo y la magnitud absoluta que se mostrará en el display.

```
module detector_signo (
    input  wire [5:0] R,       // R[5] = signo, complemento a 2
    output wire       signo,   // 0: Positivo (+), 1: Negativo (-)
    output wire [4:0] mag      // Magnitud absoluta (0..30) para el display
);

    assign signo = R[5];

    // Si es negativo se toma el complemento a 2; si es positivo queda igual
    assign mag = signo ? (~R[4:0] + 1'b1) : R[4:0];

endmodule
```

* **`signo`:** al estar `R` en complemento a 2, el signo es directamente su bit más significativo, `R[5]`.
* **`mag`:** si el resultado es negativo, se vuelve a aplicar el complemento a 2 sobre `R[4:0]` para recuperar la magnitud; si es positivo, se deja igual. La magnitud llega hasta 30, por lo que ocupa 5 bits.

Combinando este bloque con el anterior, se obtiene la siguiente simulación en GTKWave:

<img width="1920" height="1080" alt="Captura de pantalla de 2026-10-18 14-34-21" src="https://github.com/user-attachments/assets/1b3b83b3-4077-4061-9a1c-b6409f6617d1" />

## Cuarto bloque (Conversor binario a BCD)

La magnitud (`mag`, de 0 a 30) debe mostrarse en dos displays, uno para las decenas y otro para las unidades. Como las decenas solo pueden valer 0, 1, 2 o 3, no se necesita un algoritmo de conversión completo y basta con comparar la magnitud contra 10, 20 y 30:

```
module bin_bcd(
    input  wire [4:0] mag,       // Magnitud absoluta (0..30)
    output wire [3:0] decenas,   // 0..3
    output wire [3:0] unidades   // 0..9
);

    assign decenas = (mag >= 5'd30) ? 4'd3 :
                     (mag >= 5'd20) ? 4'd2 :
                     (mag >= 5'd10) ? 4'd1 : 4'd0;

    wire [4:0] base = (mag >= 5'd30) ? 5'd30 :
                      (mag >= 5'd20) ? 5'd20 :
                      (mag >= 5'd10) ? 5'd10 : 5'd0;

    wire [4:0] resto = mag - base;
    assign unidades = resto[3:0];

endmodule
```

Las decenas son el mayor múltiplo de 10 que no supera la magnitud (`base` es ese múltiplo, 0, 10, 20 o 30), y las unidades son el resto `mag - base`, que siempre queda entre 0 y 9.

Con los casos de prueba anteriores, la cadena completa (`detector_signo` y `bin_bcd`) debe dar:

| Valor | `signo` | `mag` | `decenas` | `unidades` |
|-------|---------|-------|-----------|------------|
| +14   | 0       | 14    | 1         | 4          |
| +4    | 0       | 4     | 0         | 4          |
| −4    | 1       | 4     | 0         | 4          |
| −14   | 1       | 14    | 1         | 4          |
| +30   | 0       | 30    | 3         | 0          |
| 0     | 0       | 0     | 0         | 0          |
| −30   | 1       | 30    | 3         | 0          |

## Quinto bloque (Decodificador BCD a 7 segmentos)

Cada dígito BCD (decenas y unidades) se convierte al patrón de segmentos con el módulo `bcd_7s`, que implementa una ecuación booleana por segmento con el orden `seg[6]=g, seg[5]=f, seg[4]=e, seg[3]=d, seg[2]=c, seg[1]=b, seg[0]=a`:

```
module bcd_7s(
    input wire [3:0] digito,   // Digito a convertir (0 a 9)
    output wire [6:0] seg      // Salidas: seg[6]=g, seg[5]=f, ..., seg[0]=a
);

    assign seg[6] = (~digito[3] & ~digito[2] & ~digito[1]) | (digito[2] & digito[1] & digito[0]);  // g
    assign seg[5] = (~digito[3] & ~digito[2] & digito[0]) | (~digito[2] & digito[1]) | (digito[1] & digito[0]);    // f
    assign seg[4] = (digito[2] & ~digito[1]) | digito[0];  // e   
    assign seg[3] = (digito[2] & ~digito[1] & ~digito[0]) | (digito[2] & digito[1] & digito[0]) | (~digito[3] & ~digito[2] & ~digito[1] & digito[0]);    // d 
    assign seg[2] = (~digito[2] & digito[1] & ~digito[0]); // c  
    assign seg[1] = (digito[2] & ~digito[1] & digito[0]) | (digito[2] & digito[1] & ~digito[0]);   // b
    assign seg[0] = (digito[2] & ~digito[1] & ~digito[0]) | (~digito[3] & ~digito[2] & ~digito[1] & digito[0]); // a

endmodule
```

La lógica es **activa en bajo**: un segmento se enciende cuando su bit vale `0`. Por ejemplo, para el dígito 0 el segmento `g` vale 1 (apagado) y los demás segmentos valen 0 (encendidos).

## Integración en FPGA: `top_calculadora`

El módulo `top_calculadora` conecta todos los bloques anteriores y es el que se implementa en la FPGA. Sus entradas son los switches de A (4 bits) y B (4 bits), cuatro pulsadores para elegir la operación y el reloj; sus salidas son el bus de segmentos `seg[6:0]`, la selección de dígito `dig[3:0]` y el LED de signo `led_signo`. El flujo de datos es:

`A, B, modo` → `sumador_restador` → `detector_signo` → `bin_bcd` → `bcd_7s` (decenas y unidades) → multiplexado de displays.

### Selección de la operación (pulsadores)

La operación se elige con cuatro pulsadores, que se guardan en el registro `modo = {negA, negB}`:

| Pulsador | Pin     | Operación | `modo` |
|----------|---------|-----------|--------|
| K2       | PIN_90  | A + B     | `00`   |
| K3       | PIN_91  | A − B     | `01`   |
| K4       | PIN_87  | −A + B    | `10`   |
| K5       | PIN_86  | −A − B    | `11`   |

```
reg [1:0] modo = 2'b00;

always @(posedge clk) begin
    if      (~btn_ApB)  modo <= 2'b00;
    else if (~btn_AmB)  modo <= 2'b01;
    else if (~btn_nApB) modo <= 2'b10;
    else if (~btn_nAmB) modo <= 2'b11;
end
```

- Los pulsadores son **activos en bajo** (valen 0 al presionarlos), por eso se usa `~btn`.
- El modo **se queda guardado** hasta la siguiente pulsación, así que no hace falta mantener el botón presionado. Al iniciar, el modo es A + B.
- Si se presionan varios pulsadores a la vez, tiene prioridad el primero de la lista (K2 sobre K3, K3 sobre K4, y así sucesivamente).
- `modo[1]` se conecta a `negA` y `modo[0]` a `negB` del `sumador_restador`.

### Función del reloj (`clk`)

La entrada `clk` es el reloj de la FPGA (50 MHz) y se usa para dos cosas: muestrear los pulsadores en el registro `modo` y generar el refresco de los displays. La aritmética en sí es completamente combinacional.

En la tarjeta FPGA los displays de 7 segmentos comparten **un único bus de segmentos (`seg[6:0]`, a-g)**, y cada display se habilita con una línea propia (`dig[3:0]`). Esto significa que, en un instante dado, solo se puede mostrar un dígito. Para ver los tres dígitos (unidades, decenas y signo) al mismo tiempo se usa **multiplexado en el tiempo**. Para ello se usa un contador libre de 17 bits que se incrementa en cada flanco de subida:

```
reg [16:0] clk_div = 17'd0;

always @(posedge clk) begin
    clk_div <= clk_div + 1'b1;
end

wire [1:0] selector_display = clk_div[16:15];
```

Los 2 bits más significativos del contador (`clk_div[16:15]`) forman el selector que recorre los 4 displays. Como `selector_display` cambia cada 2^15 ciclos de reloj, cada display permanece activo ≈ 0,66 ms y el ciclo completo de los 4 displays dura 2^17 ciclos:

```
f_refresco = 50 MHz / 2^17 ≈ 381 Hz por display
```

A esta frecuencia el ojo humano no percibe el parpadeo (persistencia de la visión), por lo que parece que los displays están encendidos todo el tiempo.

### Selección del dígito y los segmentos

Un bloque combinacional (`always @(*)`) conmuta, según `selector_display`, qué display se activa (`dig`) y qué patrón de segmentos se coloca en el bus compartido (`seg`):

| `selector_display` | `dig`  | Display activo       | Patrón en `seg`                      |
|--------------------|--------|----------------------|--------------------------------------|
| `00`               | `1110` | Display 1 (unidades) | `seg_unidades` (salida de `bcd_7s`)  |
| `01`               | `1101` | Display 2 (decenas)  | `seg_decenas` (salida de `bcd_7s`)   |
| `10`               | `1011` | Display 3 (signo)    | `seg_signo`                          |
| `11`               | `0111` | Display 4 (no usado) | `7'b111_1111` (todo apagado)         |

Tanto las líneas `dig` como los segmentos son **activos en bajo**: un display se habilita con un `0` en su línea de `dig` (por eso solo hay un cero en cada patrón) y un segmento se enciende cuando su bit vale `0`.

### Visualización del signo

El signo no necesita un decodificador, ya que solo se muestra el símbolo "-" cuando el resultado es negativo:

```
assign seg_signo = (signo_net) ? 7'b011_1111 : 7'b111_1111;
assign led_signo = ~signo_net; // Se enciende (= 0) si el signo es negativo
```

- **Resultado negativo (`signo_net = 1`):** `7'b011_1111` enciende únicamente el segmento central `g` (`seg[6] = 0`), formando el signo "-".
- **Resultado positivo (`signo_net = 0`):** `7'b111_1111` mantiene todos los segmentos apagados, así que no se muestra nada.
- **LED de signo:** `led_signo` también es activo en bajo, por lo que se enciende cuando el resultado es negativo. No depende del multiplexado.

## Simulación en Digital

Además de la descripción en Verilog, el sistema se modeló y simuló como un diagrama de bloques en el simulador **Digital** (archivo `Bono_diagrama.dig`). Cada número de entrada tiene un valor de 4 bits (**A** y **B**) y un interruptor de signo (**negA** y **negB**), los mismos que recibe el módulo `sumador_restador`. Así, el circuito calcula `±A ± B` y muestra el resultado con su signo en los displays de 7 segmentos.

<img width="1920" height="1080" alt="Captura de pantalla de 2026-10-18 13-13-41" src="https://github.com/user-attachments/assets/8373b2a3-25b4-40b4-90ed-95093c7b3655" />

El diagrama se puede leer de izquierda a derecha en las siguientes etapas:

1. **Extensión y signo de los operandos.** A y B (4 bits) se extienden a 6 bits con ceros en los bits más significativos. Cada operando pasa por una compuerta XOR con su interruptor de signo (negA / negB) replicado en los 6 bits, y luego por un sumador que le suma ese mismo bit de signo. Esto es exactamente el complemento a 2 (`~X + 1`) cuando el operando es negativo, y deja el valor igual cuando es positivo. El resultado son dos números con signo en complemento a 2 de 6 bits.
2. **Suma de los operandos.** Un tercer bloque **Suma** suma los dos números con signo. El bit 5 del resultado es el bit de signo de la operación y los bits 0-4 contienen el valor en complemento a 2. En Verilog, estas tres sumas se escriben en una sola expresión: `R = A_xor + B_xor + negA + negB`.
3. **Cálculo de la magnitud (valor absoluto).** Los bits 0-4 pasan por otra XOR controlada por el bit de signo y un último sumador que le suma dicho bit, de modo que si el resultado es negativo se vuelve a aplicar el complemento a 2 para obtener su magnitud. Es el equivalente en hardware del cálculo de `mag` del módulo `detector_signo`.
4. **Conversión a BCD.** La magnitud entra al bloque externo `bin_bcd`, que la separa en **decenas** y **unidades**.
5. **Decodificación y visualización.** Cada dígito BCD pasa por un bloque externo `bcd_7s`, cuya salida de 7 bits (segmentos a-g) se conecta a su display de 7 segmentos. El bit de signo del resultado se invierte con una compuerta NOT y se lleva al display correspondiente al signo.

A diferencia de la FPGA, en la simulación en Digital no se usa reloj, multiplexado ni pulsadores: `negA` y `negB` se mueven directamente con interruptores y cada decodificador se conecta directamente a su display, lo cual es suficiente para verificar la lógica de signo, magnitud, BCD y segmentos.
