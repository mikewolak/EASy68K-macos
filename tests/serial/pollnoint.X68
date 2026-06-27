*-----------------------------------------------------------------
* Polled serial, NO interrupts, NO ISR vector installed.
* Sets the IRQ mask to 0 (interrupts allowed) but never enables any
* serial interrupt. If a stale serial IRQ leaked in from a previous
* run it would vector through an empty $68 and crash; a clean SIMHALT
* with the PING data proves the original polled paradigm is intact.
*-----------------------------------------------------------------
        ORG     $1000
START
        LEA     PORT,A1
        MOVE.L  #40,D0          * initComm cid 0
        TRAP    #15
        MOVE.L  #41,D0          * setParams 9600,N,8,1
        MOVE.L  #7,D1
        TRAP    #15
        MOVE.W  #$2000,SR       * mask 0: IRQs allowed, but none are enabled
        MOVE.L  #25,D5          * poll 25 times
LOOP
        MOVE.L  #42,D0          * readComm cid 0 (polled)
        MOVE.L  #16,D1
        LEA     BUFFER,A1
        TRAP    #15
        TST.B   D1
        BEQ     SKIP
        LEA     BUFFER,A1
        MOVE.B  #14,D0          * print what we polled
        TRAP    #15
SKIP
        MOVE.L  #80000,D6
DLY     SUBQ.L  #1,D6
        BNE     DLY
        SUBQ.L  #1,D5
        BNE     LOOP
        LEA     OK,A1
        MOVE.B  #13,D0
        TRAP    #15
        MOVE.B  #9,D0           * normal terminate
        TRAP    #15
        SIMHALT
PORT    DC.B    '/tmp/e68serial',0
OK      DC.B    ' [HALTED CLEANLY, NO SPURIOUS IRQ]',0
        DS.W    0
BUFFER  DS.B    20
        END     START
