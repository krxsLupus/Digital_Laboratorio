# Sumador Jerárquico de 4 Bits en FPGA

## Descripción del Proyecto
Este proyecto implementa un sumador jerárquico completo de 4 bits (`sumador4b`) utilizando Verilog HDL. El diseño está concebido para ser sintetizado y validado físicamente en una tarjeta de desarrollo FPGA Altera/Intel Cyclone IV (modelo **EP4CE10E22C8N**). El sistema realiza la suma aritmética de dos palabras binarias de 4 bits ($A$ y $B$) junto con un acarreo de entrada ($Cin$), generando un resultado de 4 bits y un bit indicador de desbordamiento o acarreo de salida ($Cout$).

## Interfaz Física: Entradas y Salidas
Para la interacción física con el algoritmo, el diseño mapea las señales lógicas a los periféricos integrados en la tarjeta de desarrollo, logrando una demostración visual e inmediata de la aritmética binaria:

* **Entradas DIP Switches:** Se utilizan 8 interruptores DIP para ingresar los operandos $A$ y $B$ en formato binario puro. Un interruptor o botón adicional se destina para el acarreo inicial ($Cin$). Esta configuración permite alterar los sumandos en tiempo real y observar el comportamiento de las compuertas lógicas sin necesidad de simulaciones por software.
* **Salida de Suma Display de 7 Segmentos:** El resultado de la suma de 4 bits (valores del 0 al 15) se decodifica a formato hexadecimal (0-F) mediante el módulo `hex7seg.v`. Este valor se visualiza en el primer dígito del display de 7 segmentos multiplexado de la placa, proporcionando una lectura clara y directa del resultado.
* **Salida de Acarreo LED:** El bit de $Cout$, que representa un peso decimal de 16, se visualiza mediante un LED independiente. Este indicador se enciende cuando la suma de los operandos supera el valor de $15_{10}$ (por ejemplo, al sumar $8 + 10 = 2$ en el display, con el LED encendido indicando $+16$).

## Estructura de Módulos
* `sumador4b.v`: Módulo central que contiene la lógica jerárquica de la suma.
* `hex7seg.v`: Decodificador combinacional que convierte el resultado binario de 4 bits en las señales necesarias para iluminar los segmentos correspondientes del display (formato hexadecimal).
* `sumadorDisplay.v`: Módulo de nivel superior (wrapper) que instancia el sumador y el decodificador, interconectando las señales internas con los pines físicos de la FPGA, incluyendo la señal constante requerida para habilitar el transistor del dígito correcto del display.

## Mapeo de Pines (Pin Planner)
Las señales están asignadas específicamente para el encapsulado **EQFP-144** de la Cyclone IV.

| Señal en Verilog | Función Física | Pin Asignado |
| :--- | :--- | :--- |
| `sw_a[0]` | Entrada A0 (DIP Switch 1) | `PIN_58` |
| `sw_a[1]` | Entrada A1 (DIP Switch 2) | `PIN_59` |
| `sw_a[2]` | Entrada A2 (DIP Switch 3) | `PIN_60` |
| `sw_a[3]` | Entrada A3 (DIP Switch 4) | `PIN_64` |
| `sw_b[0]` | Entrada B0 (DIP Switch 5) | `PIN_65` |
| `sw_b[1]` | Entrada B1 (DIP Switch 6) | `PIN_66` |
| `sw_b[2]` | Entrada B2 (DIP Switch 7) | `PIN_67` |
| `sw_b[3]` | Entrada B3 (DIP Switch 8) | `PIN_68` |
| `sw_cin` | Acarreo de Entrada Cin (Botón/Switch) | `PIN_88` |
| `led_cout` | Acarreo de Salida Cout (LED D1) | `PIN_84` |
| `display[0]` | Segmento **a** | `PIN_128` |
| `display[1]` | Segmento **b** | `PIN_121` |
| `display[2]` | Segmento **c** | `PIN_125` |
| `display[3]` | Segmento **d** | `PIN_129` |
| `display[4]` | Segmento **e** | `PIN_132` |
| `display[5]` | Segmento **f** | `PIN_126` |
| `display[6]` | Segmento **g** | `PIN_124` |
| `dig_sel[0]` | Habilitador Dígito 1 (Display Multiplexado)| `PIN_133` |

## Evidencias de Simulación
Se realizó la verificación lógica del comportamiento del algoritmo sumador realizado. En la siguiente imagen se observa el correcto funcionamiento del algoritmo, sumando las entradas A y B. En el caso en que la suma produce un acarreo, al valor mostrado en la salida se deben sumar 16 (representados por el bit de acarreo en la pocisión 5):

![Ondas de simulación del sumador de 4 bits](img/onda_sumador.png)
