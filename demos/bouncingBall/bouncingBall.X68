*-----------------------------------------------------------
* Program Number: v1.0
* Written by    : Chuck Kelly
* Date Created  : April-10-2005
* Description   : Bouncing Ball
*
* Modified Oct-4-2008
*     Changed to use trap task 23 (Delay)
* The graphics resolution is 640 x 480 with 0,0 at the top left.
*  (see help for information on graphics and sound)
*-----------------------------------------------------------
	ORG	$800

BLACK	EQU	$00000000
MAROON	EQU	$00000080
GREEN	EQU	$00008000
OLIVE	EQU	$00008080
NAVY	EQU	$00800000
PURPLE	EQU	$00800080
TEAL	EQU	$00808000
GRAY	EQU	$00808080
RED		EQU	$000000FF
LIME	EQU	$0000FF00
YELLOW	EQU	$0000FFFF
BLUE	EQU	$00FF0000
FUCHSIA	EQU	$00FF00FF
AQUA	EQU	$00FFFF00
LTGRAY	EQU	$00C0C0C0
WHITE	EQU	$00FFFFFF

DIAMETER	EQU	40
RADIUS	EQU	20
GROUND	EQU	439
MAX_X	EQU	639-DIAMETER
MAX_Y	EQU	GROUND-DIAMETER

START
	move.l	#8,d5		delta X
	move.l	#1,d6		delta Y

	lea		FillColor,A2


loop
	move.l	X1,d1		X1
	move.l	Y1,d2		Y1
	move.l	X2,d3		X2
	move.l	Y2,d4		Y2

	add.l	d5,d3		X2 += dX
	add.l	d5,d1		X1 += dX
	if <mi> then.s
		clr.l	d1				X1 = 0
		move.l	#DIAMETER,d3	X2 = DIAMETER
		neg.l	d5
	endi
	if.l d1 <hs> #MAX_X then.s
		move.l	#MAX_X,d1
		move.l	#MAX_X+DIAMETER,d3
		neg.l	d5
	endi

	add.l	d6,d4		Y2 += dY
	add.l	d6,d2		Y1 += dY
	if <mi> then.s				if hit ceiling
		clr.l	d2				Y1 = 0
		move.l	#DIAMETER,d4	Y2 = DIAMETER
		neg.l	d6
	endi
	if.l d2 <hs> #MAX_Y then.s	if hit ground
		move.l	#MAX_Y,d2
		move.l	#MAX_Y+DIAMETER,d4
		sub.l	#3,d6			remove some energy
		if <mi> then.s
			move.l	#15,d2				restart ball
			move.l	#15+DIAMETER,d4
			clr.l	RippleDiam
			adda.l	#4,A2		next color
			if.l A2 <HS> #LastColor then.s
				lea	FillColor,A2	restart colors
			endi
		else
			neg.l	d6
			move.l	d1,RippleX
			move.l	#8,RippleDiam
		endi
	endi
	move.l	d1,X1
	move.l	d2,Y1
	move.l	d3,X2
	move.l	d4,Y2

	move.l	#AQUA,d1	set pen color
	move.b	#80,d0
	trap	#15

	move.l	(A2),d1		fill color
	move.b	#81,d0
	trap	#15			set fill color

	move.l	X1,d1
	move.b	#88,d0
	trap	#15			draw filled ellipse


	move.b	#23,d0		delay for 3/100 sec (33 fps)
	move.l	#3,d1
	trap	#15
	
	add.l	#1,d6		gravity

* Draw Ripple
	move.l	(A2),d1		set pen color
	move.b	#80,d0
	trap	#15

	move.l	RippleDiam,d0
	if <ne> then.s
		move.l	RippleX,d1		X1
		add.l	#RADIUS,d1		center of ripple
		sub.l	d0,d1			X1 -= RippleDiam
		move.l	RippleX,d3		X2
		add.l	d0,d3			X2 += RippleDiam
		lsr.l	#3,d0			RippleDiam /= 8
		move.l	#GROUND,d2		Y1
		sub.l	d0,d2			Y1 -= RippleDiam
		move.l	#GROUND,D4		y2
		add.l	d0,d4			Y2 += RippleDiam
		move.b	#91,d0
		trap	#15				draw ripple
		add.l	#2,RippleDiam
	endi

	bra		loop	***** INFINITE LOOP *****

	STOP	#$2000

X1			DC.L	20		
Y1			DC.L	15		
X2			DC.L	20+DIAMETER		
Y2			DC.L	15+DIAMETER	
RippleX		DC.L	20
RippleDiam	DC.L	0	
FillColor	DC.L	MAROON
			DC.L	GREEN
			DC.L	OLIVE
			DC.L	NAVY
			DC.L	PURPLE
			DC.L	TEAL
			DC.L	RED
			DC.L	LIME
			DC.L	YELLOW
			DC.L	BLUE
			DC.L	FUCHSIA
LastColor:

	END	START



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
