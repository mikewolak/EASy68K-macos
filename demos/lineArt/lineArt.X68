*-----------------------------------------------------------
* Program Number: v3.0
* Written by    : Chuck Kelly
* Date Created  : April 18, 2011
* Description   : Line Art
* A simple demonstration of graphics in EASy68K.
*-----------------------------------------------------------
    ORG	$1000

START
    move.l  color,d1    starting color
    move.b  #80,d0
    trap    #15         set line color

* Generate random numbers for line start
* Uses timer as random number generator. This may not be the best way to
* generate a random number but it is good enough for this demonstration.
* Trap code 8 returns time in hundredths of a second since midnight in D1.L

	move.b	#8,d0
	trap	#15
	and.l	#$5FFFFF,d1	prevent overflow in divu
	divu	#300,d1	    time count / 300
	clr.w   d1
	swap	d1	        swap upper and lower words of D1 to put remainder in low word
	addq.w	#1,d1	    d1.w contains number from 1 to 300

    move.l  d1,d2       d1 is X1 d2 is Y1
    move.l  d1,d3
    add.l   #100,d3     X2
    move.l  d3,d4       Y2

    while <t> do.s          ***** INFINITE LOOP ***** 
        move.b  #84,d0
        trap    #15         draw line from X1,Y1 to X2,Y2
        add.w   dx1,d1
        if.w d1 <lt> #0 or.w d1 <ge> width then.s  ; if X1 off screen
            move.w  dx1,d0
            neg.w   d0      change direction of X1
            move.w  d0,dx1
            if.w d1 <ge> width then.s
                move.w  width,d1
            endi
        endi
        add.w   dy1,d2
        if.w d2 <lt> #0 or.w d2 <ge> height then.s ; if Y1 off screen
            move.w  dy1,d0
            neg.w   d0      change direction of Y1
            move.w  d0,dy1
            if.w d2 <ge> height then.s
                move.w  height,d2
            endi
        endi
        add.w   dx2,d3
        if.w d3 <lt> #0 or.w d3 <ge> width then.s  ; if X2 off screen
            move.w  dx2,d0
            neg.w   d0      change direction of X2
            move.w  d0,dx2
            if.w d3 <ge> width then.s
                move.w  width,d3
            endi
        endi
        add.w   dy2,d4
        if.w d4 <lt> #0 or.w d4 <ge> height then.s ; if Y2 off screen
            move.w  dY2,d0
            neg.w   d0      change direciton of Y2
            move.w  d0,dY2
            if.w d4 <ge> height then.s
                move.w  height,d4
            endi
        endi

        * Cycle through the colors in a pleasing order.
        * The colors are represented as amount of Blue,Green,Red from 00 to $FF
        * The color cycle is
        * 000000 - 0000FF       Black to Red
        * 0000FF - 00FFFF       Red to Yellow
        * 00FFFF - 00FF00       Yellow to Green
        * 00FF00 - FFFF00       Green to Aqua
        * FFFF00 - FF0000       Aqua to Blue
        * FF0000 - FF00FF       Blue to Fuchsia
        * FF00FF - 0000FF       Fuchsia to Red (Repeats starting at Red to Yellow)

        move.w  d1,-(sp)        save X1
        move.l  color,d1        
        if.l d1 <lo> #$0000FF then.s
            add.l   #1,d1
        else
            if.b d1 <eq> #$ff and.l d1 <lo> #$00ffff then.s
                add.l   #$100,d1
            else.s
                if.b d1 <ne> #0 and.l d1 <ls> #$00ffff then.s
                    sub.b   #1,d1
                else
                    if.w d1 <hs> #$ff00 and.l d1 <lo> #$ffff00 then.s
                        add.l   #$10000,d1
                    else.s
                        if.l d1 <hs> #$ff0000 and.w d1 <hi> #$00ff then.s
                            sub.w   #$100,d1
                        else
                            if.l d1 <hs> #$ff0000 and.l d1 <lo> #$ff00ff then.s
                                add.b   #$1,d1
                            else
                                if.l d1 <hs> #$100ff then.s
                                    sub.l   #$10000,d1
                                endi
                            endi
                        endi
                    endi
                endi
            endi
        endi
        move.l  d1,color
        move.b  #80,d0
        trap    #15         set line color

        move.b  #23,d0      delay
        move.l  #1,d1       1/100 second delay
        trap    #15

        add.w   #1,count
        if.w count <hs> #2000 then.s    if 2000 lines drawn
            clr.w   count
            move.b  #11,d0      clear screen
            move.w  #$ff00,d1
            trap    #15
        endi 

        move.b	#33,d0		get window size
        clr.l   d1
        trap	#15
        move.w  d1,height
        swap    d1
        move.w  d1,width
        move.w  (sp)+,d1    restore X1
    endw
    STOP    #$2000

dx1     dc.w    7           X1 movement
dy1     dc.w    3           Y1 movement
dx2     dc.w    1           X2 movement
dy2     dc.w    5           Y2 movement
color   dc.l    0           current color (Starts at Black)
count   dc.w    0           count of lines

width   dc.w    1024
height  dc.w    768

        END START








*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
