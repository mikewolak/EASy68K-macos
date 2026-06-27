*-----------------------------------------------------------------
* EASy68K Hardware demo  —  Knight Rider + 32-bit hex counter
*
* Open  Window > Hardware.  In the (red) "Auto Interval" box pick an
* IRQ, set the mSec rate and press Start.  The timer interrupt then:
*   - sweeps a smooth "Knight Rider" light across the 8 LEDs (FF8010)
*   - advances a 32-bit HEX COUNTER shown on the eight 7-seg digits
* Flip SWITCH 7 (leftmost) ON for FAST, OFF for SLOW.
* Hold PUSH BUTTON 0 (rightmost) to reset the counter.
*-----------------------------------------------------------------
SEG7    EQU     $00FF8000      digit n at SEG7 + 2*n  (digit 0 = MS nibble)
LEDS    EQU     $00FF8010      8 LEDs
SWTCH   EQU     $00FF8020      8 switches
BTNS    EQU     $00FF8030      8 push buttons (active low)

        ORG     $0
        DC.L    $00009000      * initial SSP
        DC.L    START          * reset PC
        ORG     $64            * IRQ1..IRQ7 autovectors -> common ISR
        DC.L    ISR
        DC.L    ISR
        DC.L    ISR
        DC.L    ISR
        DC.L    ISR
        DC.L    ISR
        DC.L    ISR

        ORG     $1000
START
        MOVE.W  #$2000,SR      * supervisor, interrupt mask 0 (allow IRQs)
        CLR.L   COUNT
        CLR.W   TICK
        MOVE.W  #0,POS         * Knight Rider position 0..7
        MOVE.W  #1,DIR         * direction +1 / -1
        MOVE.B  #$01,LEDS      * LED0 on to start
MAIN
* push button 0 (active low) resets the counter
        MOVE.B  BTNS,D0
        BTST    #0,D0
        BNE     SHOW
        CLR.L   COUNT
SHOW
* display COUNT (32 bits) on the 8 seven-seg digits, MS nibble first
        MOVE.L  COUNT,D1
        LEA     SEG7,A0
        LEA     SEGTAB,A1
        MOVE.W  #7,D2
DLOOP
        ROL.L   #4,D1          * next nibble into the low 4 bits
        MOVE.L  D1,D3
        AND.W   #$0F,D3
        MOVE.B  0(A1,D3.W),(A0)
        ADDQ.L  #2,A0
        DBRA    D2,DLOOP
        BRA     MAIN

*---- timer ISR: advance Knight Rider + counter at switch-selected rate ----
ISR
        MOVEM.L D0-D2,-(SP)
        ADDQ.W  #1,TICK
        MOVE.W  #4,D0          * SLOW: advance every 4 ticks
        MOVE.B  SWTCH,D1
        BTST    #7,D1          * switch 7 ON -> FAST
        BEQ     CHKT
        MOVE.W  #1,D0
CHKT
        CMP.W   TICK,D0        * if divisor > tick, not yet
        BHI     IEND
        CLR.W   TICK
        MOVE.W  POS,D1         * advance with bounce
        ADD.W   DIR,D1
        CMP.W   #7,D1
        BLT     NOHI
        MOVE.W  #7,D1
        MOVE.W  #-1,DIR
NOHI    TST.W   D1
        BGE     NOLO
        MOVE.W  #0,D1
        MOVE.W  #1,DIR
NOLO    MOVE.W  D1,POS
        MOVEQ   #1,D2          * head LED = 1 << pos
        LSL.B   D1,D2
        MOVE.B  D2,LEDS
        ADDQ.L  #1,COUNT
IEND
        MOVEM.L (SP)+,D0-D2
        RTE

SEGTAB  DC.B  $3F,$06,$5B,$4F,$66,$6D,$7D,$07
        DC.B  $7F,$6F,$77,$7C,$39,$5E,$79,$71
        DS.W    0
COUNT   DS.L    1
TICK    DS.W    1
POS     DS.W    1
DIR     DS.W    1
        END     START
