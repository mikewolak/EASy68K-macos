        ORG     $1000
START:  MOVE.L  #7,D2
        MOVE.L  #6,D3
        MULU    D3,D2
        MOVE.L  D2,D1
        MOVE.B  #3,D0
        TRAP    #15
        MOVE.B  #9,D0
        TRAP    #15
        END     START
