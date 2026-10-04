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

Al tener signo implícito, en los resultados de la simulación se evidencia el primer dígito hexadecimal como el indicador de signo (0 o 1), y el segundo dígito representa el resultado de la operación, en caso de ser positivo, o el complemento a 2, en caso de ser negativo.

Para mayor comodidad, se adjunta también los resultados en binario:

<img width="1586" height="181" alt="image" src="https://github.com/user-attachments/assets/33880e2c-9d3b-443d-80ce-2281ca70cfbf" />


Para el cuarto caso, 

