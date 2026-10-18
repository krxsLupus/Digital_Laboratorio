# Laboratorio 3

Calculadora de suma y resta de dos números de 4 bits (A y B) con visualización en displays de 7 segmentos. El sistema se divide en los siguientes módulos de Verilog:

| Módulo             | Función                                                                 |
|--------------------|-------------------------------------------------------------------------|
| `sumador_restador` | Suma o resta A y B según `Op`, entregando un resultado de 5 bits (`S`). |
| `detector_signo`   | Obtiene el signo, la señal de error (desbordamiento) y la magnitud.     |
| `bin_bcd`          | Separa la magnitud en decenas y unidades (BCD).                         |
| `bcd_7s`           | Convierte un dígito BCD en el patrón de los segmentos a-g.              |
| `top_calculadora`  | Une todos los módulos y multiplexa los displays en la FPGA.             |

## Primer bloque (Sumador / restador)
Para el primer bloque, el sumador/restador de 4 bits, se debe diseñar un circuito que reciba dos números de 4 bits, A y B, y una señal de control, Op, que permita identificar si la operación a realizar es una suma o una resta, para entregar el resultado de la operación, S:
*  **Op = 0:** El circuito realiza S = A + B (suma).
*  **Op = 1:** El circuito realiza S = A + (~B + 1) (Resta).

```
module sumador_restador (
    input  wire [3:0] A,
    input  wire [3:0] B,
    input  wire       Op,   
    output wire [4:0] S     //5 bits: el más significativo es el signo, los otros 4 son el resultado
);
    wire [3:0] B_xor; //nueva variable para guardar el complemento a 1 de B

    assign B_xor = B ^ {4{Op}}; //complemento a 1 de B con Op

    assign S = A + B_xor + Op; //suma de A y B o su complemento a 1 y +1 si Op = 1

endmodule
```

Cada bit de B se pasa por una XOR con `Op`: si `Op = 0`, B queda igual, y si `Op = 1`, se obtiene su complemento a 1. Después, `Op` también se suma como acarreo de entrada, lo que completa el complemento a 2 en la resta. La suma se hace con 5 bits, por lo que el bit más significativo de `S` (`S[4]`) es el **acarreo de salida** de la operación, y no un bit de signo como tal. Su significado depende de `Op`:

| `Op`          | Operación realizada | Significado de `S[4]`                                              | `S[3:0]`                                                        |
|---------------|---------------------|--------------------------------------------------------------------|-----------------------------------------------------------------|
| 0 (suma)      | S = A + B           | 1 si A + B > 15 (el resultado no cabe en 4 bits: desbordamiento)    | Los 4 bits menos significativos de la suma                      |
| 1 (resta)     | S = A + ~B + 1 = A − B + 16 | 1 si A ≥ B (resultado no negativo), 0 si A < B (resultado negativo) | A − B si A ≥ B, o el complemento a 2 de \|A − B\| si A < B |

Es decir, en la resta el acarreo funciona de forma invertida respecto al signo: `S[4] = 1` indica resultado positivo (o cero) y `S[4] = 0` indica resultado negativo. El signo real se obtiene en el siguiente bloque (`detector_signo`) combinando `S[4]` con `Op`.

Con este código generamos el sumador/restador, a continuación se adjunta la evidencia de funcionamiento haciendo uso de GTKWave:

<img width="1586" height="181" alt="image" src="https://github.com/user-attachments/assets/a7a05965-8fba-41f8-9d66-0180e332fe81" />


Como se puede ver, en la simulación se plantearon 4 casos críticos: la suma, la resta con resultado positivo, la resta con resultado negativo y la suma con resultado mayor a 4 bits.

En los resultados de la simulación, el primer dígito hexadecimal corresponde a `S[4]` (el acarreo, 0 o 1) y el segundo dígito corresponde a `S[3:0]`. Según lo explicado antes, en la suma `S[4] = 1` solo aparece cuando hay desbordamiento, y en la resta `S[4] = 1` indica resultado positivo y `S[4] = 0` resultado negativo. En este último caso, `S[3:0]` contiene el complemento a 2 de la magnitud del resultado.

Para mayor comodidad, se adjuntan también los resultados en binario:

<img width="1586" height="181" alt="image" src="https://github.com/user-attachments/assets/33880e2c-9d3b-443d-80ce-2281ca70cfbf" />


Para el cuarto caso, el resultado de la suma es 17, que en binario supera la cantidad de bits asignada a la respuesta (4 bits, máximo 15). La solución que se plantea en este caso, es identificar el desbordamiento haciendo uso de Op y del acarreo S[4]: en caso de que Op = 0 (suma) y S[4] = 1, se activará la señal de error.

## Segundo y tercer bloque (Detector de signo y calculador de magnitud)

Para el detector de signo se implementó la solución al desbordamiento planteada en el apartado anterior, por lo que, además de realizar la detección de signo, también se producirá la señal de error en caso de identificar el desbordamiento.
```
module detector_signo (
    input  wire [4:0] S,       // S[4] = acarreo, S[3:0] = resultado
    input  wire       Op,      
    output wire       signo,   // 0: Positivo (+), 1: Negativo (-)
    output wire       error,   // 1: Desbordamiento Error de representación
    output wire [3:0] mag      // Magnitud absoluta para el display
);

    // En resta es 0 si S[4]==1, 1 si S[4]==0
    assign signo = Op ? ~S[4] : 1'b0; //condicional q permite ver si se asigna 0 (+) o 1 (-)

    assign error = ~Op & S[4]; //el error solo da 1 si se trata de una suma (Op=0) y hay acarreo

    assign mag = (signo) ? (~S[3:0] + 1'b1) : S[3:0]; //se asigna la magnitud del complemento a 2 si
//el signo es negativo o se deja igual si es positivo

endmodule
```
Este módulo genera tres salidas a partir de `S` y `Op`:

* **`signo`:** en la suma (`Op = 0`) siempre es 0 (positivo). En la resta (`Op = 1`) es `~S[4]`, es decir, 1 (negativo) cuando no hubo acarreo, que corresponde al caso A < B.
* **`error`:** vale 1 únicamente en una suma (`Op = 0`) con acarreo (`S[4] = 1`), que es el desbordamiento descrito en el bloque anterior.
* **`mag`:** si el resultado es negativo, se vuelve a aplicar el complemento a 2 sobre `S[3:0]` para recuperar la magnitud absoluta; si es positivo, se deja `S[3:0]` sin cambios. En caso de desbordamiento, `mag` conserva los 4 bits menos significativos de la suma (por ejemplo, 17 se muestra como 1) y se enciende el LED de error.

Una vez implementado este bloque, y combinándolo con el anterior, se obtiene la siguiente simulación en GTKWave:

<img width="1593" height="251" alt="image" src="https://github.com/user-attachments/assets/775abdab-244f-4377-9d52-1ba6dcc7be04" />

En la simulación, se identifica claramente el caso de desbordamiento, y se representa el valor de Error = 1.

## Cuarto bloque (Conversor binario a BCD)

La magnitud (`mag`, de 0 a 15) debe mostrarse en dos displays, uno para las decenas y otro para las unidades. Como `mag` solo puede valer entre 0 y 15, las decenas únicamente pueden ser 0 o 1, por lo que no se necesita un algoritmo de conversión completo y basta con una comparación:

```
module bin_bcd(
    input wire [3:0] mag,   // Magnitud absoluta
    output wire [3:0] decenas,
    output wire [3:0] unidades
);

    assign decenas  = (mag >= 4'd10) ? 4'd1 : 4'd0;
    assign unidades = (mag >= 4'd10) ? (mag - 4'd10) : mag;

endmodule
```

Si `mag >= 10`, las decenas valen 1 y las unidades son `mag - 10`; en caso contrario, las decenas valen 0 y las unidades son `mag`.

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

## Integración en FPGA: reloj y multiplexado del display (`top_calculadora`)

El módulo `top_calculadora` conecta todos los bloques anteriores y es el que se implementa en la FPGA. Sus entradas son los switches de A (4 bits), B (4 bits) y `Op` (0: suma, 1: resta), y sus salidas son el bus de segmentos `seg[6:0]`, la selección de dígito `dig[3:0]` y el LED de error `led_error`. El flujo de datos es:

`A, B, Op` → `sumador_restador` → `detector_signo` → `bin_bcd` → `bcd_7s` (decenas y unidades) → multiplexado de displays.

En la tarjeta FPGA los displays de 7 segmentos comparten **un único bus de segmentos (`seg[6:0]`, a-g)**, y cada display se habilita con una línea propia (`dig[3:0]`). Esto significa que, en un instante dado, solo se puede mostrar un dígito. Para ver los tres dígitos (unidades, decenas y signo) al mismo tiempo se usa **multiplexado en el tiempo**, y para eso se necesita el reloj `clk`.

### Función del reloj (`clk`)

La entrada `clk` es el reloj de la FPGA (50 MHz). No participa en la operación aritmética, que es completamente combinacional, sino únicamente en el refresco de los displays. Se usa un contador libre de 17 bits que se incrementa en cada flanco de subida:

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
```

- **Resultado negativo (`signo_net = 1`):** `7'b011_1111` enciende únicamente el segmento central `g` (`seg[6] = 0`), formando el signo "-".
- **Resultado positivo (`signo_net = 0`):** `7'b111_1111` mantiene todos los segmentos apagados, así que no se muestra nada.

### LED de error

El LED de desbordamiento no depende del multiplexado: `led_error` se conecta directamente a la señal `error_net` del módulo `detector_signo` (`assign led_error = error_net;`), por lo que se enciende de forma permanente mientras hay un desbordamiento en una suma.

## Simulación en Digital

Además de la descripción en Verilog, se hizo una versión del sistema como diagrama de bloques en el simulador **Digital** (archivo `Bono_diagrama.dig`). Esta versión es una variante con operandos con signo: en lugar de usar la señal `Op` del sumador/restador de Verilog, cada número de entrada tiene un valor de 4 bits (**A** y **B**) y un interruptor de signo (**negA** y **negB**) que indica si el operando es negativo. Así, el circuito calcula `±A ± B` y muestra el resultado con su signo en los displays de 7 segmentos.

<img width="1920" height="1080" alt="Captura de pantalla de 2026-10-18 13-13-41" src="https://github.com/user-attachments/assets/e1e2598f-b2a2-4dfd-a307-5762f0e32e36" />

El diagrama se puede leer de izquierda a derecha en las siguientes etapas:

1. **Extensión y signo de los operandos.** A y B (4 bits) se extienden a 6 bits con ceros en los bits más significativos. Cada operando pasa por una compuerta XOR con su interruptor de signo (negA / negB) replicado en los 6 bits, y luego por un sumador que le suma ese mismo bit de signo. Esto es exactamente el complemento a 2 (`~X + 1`) cuando el operando es negativo, y deja el valor igual cuando es positivo. El resultado son dos números con signo en complemento a 2 de 6 bits.
2. **Suma de los operandos.** Un tercer bloque **Suma** suma los dos números con signo. El bit 5 del resultado es el bit de signo de la operación y los bits 0-4 contienen el valor en complemento a 2.
3. **Cálculo de la magnitud (valor absoluto).** Los bits 0-4 pasan por otra XOR controlada por el bit de signo y un último sumador que le suma dicho bit, de modo que si el resultado es negativo se vuelve a aplicar el complemento a 2 para obtener su magnitud. Es el equivalente en hardware del cálculo de `mag` del módulo `detector_signo`.
4. **Conversión a BCD.** La magnitud entra al bloque externo `bin_bcd`, que la separa en **decenas** y **unidades**.
5. **Decodificación y visualización.** Cada dígito BCD pasa por un bloque externo `bcd_7s`, cuya salida de 7 bits (segmentos a-g) se conecta a su display de 7 segmentos. El bit de signo del resultado se invierte con una compuerta NOT y se lleva al display correspondiente al signo.

A diferencia de la FPGA, en la simulación en Digital no se usa reloj ni multiplexado: cada decodificador se conecta directamente a su display, lo cual es suficiente para verificar la lógica de signo, magnitud, BCD y segmentos. La implementación final para la tarjeta es la descrita en Verilog en las secciones anteriores, donde la operación se selecciona con `Op` y el multiplexado lo hace `top_calculadora`.
