        ORG     $1000
START:
        MOVE.W  #10,D0
        FOR.W   D1 = #0 TO #5 DO.S
          ADD.W   D1,D0
        ENDF
        IF.W    D0 <GT> #20 THEN.S
          MOVE.W  #1,D2
        ELSE.S
          MOVE.W  #0,D2
        ENDI
        WHILE.W D0 <NE> #0 DO.S
          SUB.W   #1,D0
        ENDW
        SIMHALT
        END     START
