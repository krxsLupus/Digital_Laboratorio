# Laboratorio 2 - Parte 2: Sumador/Restador de 4 bits y Reto de Diseño

## 1. Objetivos
* Implementar un circuito restador usando complemento a 2.
* Reutilizar un sumador de 4 bits para operaciones de resta.
* Aprender a verificar y validar el funcionamiento del diseño en un entorno de simulación, identificando y corrigiendo errores antes de la implementación física en hardware.

## 2. Marco Teórico
En sistemas digitales, las operaciones aritméticas con números negativos requieren una representación eficiente. El complemento a 2 permite codificar números positivos y negativos, y convertir restas en sumas mediante la fórmula $A-B = A + (\sim B + 1)$, donde $\sim B$ es la inversión bit a bit. 

A nivel de circuito digital, esto se logra utilizando compuertas XOR:
* Cuando la señal de control = 1, las compuertas XOR actúan como un interruptor que invierte los bits de B (complemento a 1).
* Al conectar = 1 al acarreo inicial (`Cin`), se suma el 1 faltante, logrando el complemento a 2.
* El acarreo final (`Co`) indica el signo: si es 1 el resultado es positivo, y si es 0 el resultado es negativo (en complemento a 2).

## 3. Etapa de Diseño del Sistema (Preinforme)
### Reto de Diseño: Control Térmico de Proceso en Caldera Industrial
Se diseñó un sistema digital de seguridad que compara la temperatura actual ($T$) con una temperatura objetivo ($L$) realizando la operación obligatoria $R = T - L$. 

El sistema utiliza lógica combinacional sobre los bits de salida del sumador/restador para determinar el estado sin usar comparadores dedicados:
* **Producto en condición ideal ($R = 0$):** Se enciende `PERFECT_LED`. Se detecta aplicando una compuerta NOR a los 4 bits del resultado $R$.
* **Producto en fabricación ($R < 0$):** Se enciende `PROCESS_LED`. Se detecta negando el acarreo de salida (`~carryOut`).
* **Producto quemado ($R > 0$):** Se enciende `BURN_LED`. Se detecta si hay acarreo de salida positivo y el resultado no es cero.

(Logrado gracías al circuito comparador que el Profe realizó en clase dando el guiño sutil a la solución de este reto).
