# Laboratorio 3
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
Con este código generamos el sumador/restador, a continuación se adjunta la evidencia de funcionamiento haciendo uso de GTKWave:

<img width="1586" height="181" alt="image" src="https://github.com/user-attachments/assets/a7a05965-8fba-41f8-9d66-0180e332fe81" />


Como se puede ver, en la simulación se plantearon 4 casos críticos: la suma, la resta con resultado positivo, la resta con resultado negativo y la suma con resultado mayor a 4 bits.

Al tener signo implícito, en los resultados de la simulación se evidencia el primer dígito hexadecimal como el indicador de signo (0 o 1), y el segundo dígito representa el resultado de la operación, en caso de ser positivo, o el complemento a 2 de dicho resultado, en caso de ser negativo.

Para mayor comodidad, se adjuntan también los resultados en binario:

<img width="1586" height="181" alt="image" src="https://github.com/user-attachments/assets/33880e2c-9d3b-443d-80ce-2281ca70cfbf" />


Para el cuarto caso, el resultado de la suma es 17, que en binario supera la cantidad de bits asignada a la respuesta. La solución que se plantea en este caso, es identificar el desbordamiento del S haciendo uso de Op y el bit de signo, en caso de que Op = 0 (suma) y el bit de signo S[4] = 1, se producirá un mensaje de error.

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
Una vez implementado este bloque, y combinándolo con el anterior, se obtiene la siguiente simulación en GTKWave:

<img width="1593" height="251" alt="image" src="https://github.com/user-attachments/assets/775abdab-244f-4377-9d52-1ba6dcc7be04" />

En la simulación, se identifica claramente el caso de desbordamiento, y se representa el valor de Error = 1.

## Simulación en Digital

Además de la descripción en Verilog, el sistema se modeló y simuló como un diagrama de bloques en el simulador **Digital** (archivo `Bono_diagrama.dig`). En esta versión el circuito acepta operandos con signo: cada número de entrada tiene un valor de 4 bits (**A** y **B**) y un interruptor de signo (**negA** y **negB**) que indica si el operando es negativo. Así, el circuito calcula `±A ± B` y muestra el resultado con su signo en los displays de 7 segmentos.

<img width="1920" height="1080" alt="Captura de pantalla de 2026-10-18 13-13-41" src="https://github.com/user-attachments/assets/12d1bc5f-2de5-4503-b8cd-73dec64fae73" />

El diagrama se puede leer de izquierda a derecha en las siguientes etapas:

1. **Extensión y signo de los operandos.** A y B (4 bits) se extienden a 6 bits con ceros en los bits más significativos. Cada operando pasa por una compuerta XOR con su interruptor de signo (negA / negB) replicado en los 6 bits, y luego por un sumador que le suma ese mismo bit de signo. Esto es exactamente el complemento a 2 (`~X + 1`) cuando el operando es negativo, y deja el valor igual cuando es positivo. El resultado son dos números con signo en complemento a 2 de 6 bits.
2. **Suma de los operandos.** Un tercer bloque **Suma** suma los dos números con signo. El bit 5 del resultado es el bit de signo de la operación y los bits 0-4 contienen el valor en complemento a 2.
3. **Cálculo de la magnitud (valor absoluto).** Los bits 0-4 pasan por otra XOR controlada por el bit de signo y un último sumador que le suma dicho bit, de modo que si el resultado es negativo se vuelve a aplicar el complemento a 2 para obtener su magnitud. Es el equivalente en hardware del cálculo de `mag` del módulo `detector_signo`.
4. **Conversión a BCD.** La magnitud entra al bloque externo `bin_bcd`, que la separa en **decenas** y **unidades** (los mismos módulos descritos en Verilog, importados como "Archivo externo").
5. **Decodificación y visualización.** Cada dígito BCD pasa por un decodificador `bcd_7s`, cuya salida de 7 bits (segmentos a-g) se conecta a su display de 7 segmentos. El bit de signo del resultado se invierte con una compuerta NOT y se lleva al display correspondiente al signo. La entrada inferior derecha controla la alimentación común de los displays.

Con esto se verifica el funcionamiento completo de la cadena *operandos → suma/resta → signo y magnitud → BCD → 7 segmentos* antes de llevarla a la FPGA, donde el mismo flujo se implementa con los módulos `sumador_restador`, `detector_signo`, `bin_bcd`, `bcd_7s` y `top_calculadora`.
