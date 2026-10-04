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


