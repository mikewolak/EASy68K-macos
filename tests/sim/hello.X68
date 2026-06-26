*-----------------------------------------------------------
* Title      : Hello World
* Written by : port test
*-----------------------------------------------------------
        ORG    $1000
START:                  ; first instruction of program
        LEA     MSG,A1      ; address of message
        MOVE.B  #14,D0      ; task 14 display null-terminated string
        TRAP    #15         ; call I/O
        MOVE.B  #9,D0       ; task 9 terminate
        TRAP    #15
MSG     DC.B    'Hello, world!',0
        END    START
