# Sumador de 1 Bit en FPGA

## Descripción del Proyecto
Este proyecto implementa un sumador de 1 bit (`sumador`) utilizando Verilog HDL. El diseño está concebido para ser sintetizado y validado físicamente en una tarjeta de desarrollo FPGA Altera/Intel Cyclone IV (modelo **EP4CE10E22C8N**). El sistema realiza la suma aritmética de dos operandos de 1 bit ($A$ y $B$) junto con un acarreo de entrada ($Cin$), generando un bit de resultado ($Suma$) y un bit indicador de acarreo de salida ($Cout$).

## Interfaz Física: Entradas y Salidas
Para la interacción física con el circuito lógico, el diseño mapea las señales directamente a los periféricos integrados en la tarjeta de desarrollo (DIP switches y LEDs), permitiendo comprobar visualmente las 8 combinaciones posibles de la tabla de verdad en tiempo real:

* **Entradas DIP Switches:** Se utilizan 3 interruptores DIP (o botones) para ingresar individualmente los estados lógicos de los operandos $A$, $B$ y el acarreo inicial $Cin$. Esta configuración permite manipular los sumandos en tiempo real.
* **Salida de Suma (LED D1):** Un LED dedicado representa el bit de resultado $Suma$ (peso binario $2^0$). Se enciende cuando la suma de los tres bits de entrada da como resultado un número impar de unos (resultado 1 o 3).
* **Salida de Acarreo Cout (LED D2):** Un segundo LED independiente representa el bit de acarreo de salida $Cout$ (peso binario $2^1$). Se enciende cuando la suma de las entradas es igual o superior a 2 en decimal ($10_2$).

## Estructura de Módulos
* `sumador.v`: Módulo principal que contiene la lógica combinacional del sumador completo mediante asignaciones continuas con ecuaciones booleanas:
  $$Suma = A \oplus B \oplus Cin$$,
  $$Cout = (A \cdot B) + (Cin \cdot (A \oplus B))$$
* `sumador_tb.v`: Banco de pruebas (*testbench*) utilizado para la verificación funcional mediante simulación, el cual secuencia las 8 combinaciones posibles y genera el archivo de ondas de tiempos (`sumador.vcd`).

## Mapeo de Pines (Pin Planner)
Las señales están asignadas específicamente para el encapsulado **EQFP-144** de la FPGA Cyclone IV:

| Señal en Verilog | Función Física | Pin Asignado |
| :--- | :--- | :--- |
| `a` | Entrada $A$ (DIP Switch 1) | `PIN_58` |
| `b` | Entrada $B$ (DIP Switch 2) | `PIN_59` |
| `cin` | Acarreo de Entrada $Cin$ (DIP Switch 3) | `PIN_60` |
| `suma` | Bit de Suma (LED D1) | `PIN_84` |
| `cout` | Bit de Acarreo $Cout$ (LED D2) | `PIN_85` |

## Evidencias de Simulación
Se realizó la verificación lógica del comportamiento del módulo mediante Icarus Verilog y la visualización de formas de onda en GTKWave. En la siguiente simulación se observa la respuesta en el tiempo de las salidas $Suma$ y $Cout$ frente a la secuencia completa de combinaciones de entrada:

<img width="1598" height="217" alt="image" src="https://github.com/user-attachments/assets/cb392d20-1ce5-4a3b-a464-db1502776250" />
