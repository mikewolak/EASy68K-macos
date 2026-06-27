*-----------------------------------------------------------------
* Serial RX interrupt test
* Enables serial-RX interrupts (autovector level 2), opens a serial
* port, then spins. Incoming bytes fire the ISR, which reads them
* (readComm) and prints them (task 14). Proves TRAP 121 + the IRQ.
*-----------------------------------------------------------------
        ORG     $0
        DC.L    $00009000          * initial SSP
        DC.L    START              * initial PC
        ORG     $68                * autovector level 2 = vector 26
        DC.L    ISR

        ORG     $1000
START
        LEA     PORT,A1            * open serial port (cid 0, task 40)
        MOVE.L  #40,D0
        TRAP    #15

        MOVE.L  #41,D0             * set params (cid 0, task 41): 9600,N,8,1
        MOVE.L  #7,D1
        TRAP    #15

        MOVE.L  #121,D0            * enable serial-RX interrupt, level 2
        MOVE.B  #1,D1              * function = enable
        MOVE.B  #2,D2             * source = serial RX
        MOVE.B  #2,D3             * IRQ level 2
        TRAP    #15

        LEA     MSG,A1            * banner
        MOVE.B  #14,D0
        TRAP    #15

        MOVE.W  #$2000,SR         * supervisor, interrupt mask 0 (allow IRQs)
WAIT    BRA     WAIT             * ISR services received data

*---- ISR: read available bytes and print them ----
ISR
        MOVEM.L D0-D3/A1,-(SP)
        MOVE.L  #42,D0           * readComm (cid 0, task 42)
        MOVE.L  #16,D1           * up to 16 bytes
        LEA     BUFFER,A1
        TRAP    #15
        TST.B   D1               * D1 = bytes read
        BEQ     ISRX
        LEA     BUFFER,A1
        MOVE.B  #14,D0           * print string (no CRLF)
        TRAP    #15
ISRX
        MOVEM.L (SP)+,D0-D3/A1
        RTE

PORT    DC.B    '/tmp/e68serial',0
MSG     DC.B    'SERIAL IRQ ARMED: ',0
        DS.W    0
BUFFER  DS.B    20
        END     START
