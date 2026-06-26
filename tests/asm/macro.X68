        ORG     $2000
PRINT   MACRO
        LEA     \1,A1
        MOVE.B  #14,D0
        TRAP    #15
        ENDM
START:
        PRINT   MSG
        MOVE.B  #9,D0
        TRAP    #15
MSG     DC.B    'Hi',0
        END     START
