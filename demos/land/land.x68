*************************************************************************************
*														*
*	A fractal landscape generator. V1.02				2/10/2008		*
*														*
*	Once the landscape is finished, hitting [S] will open a save dialog to		*
*	allow the file to be saved before generating a new landscape.			*
*														*
*	The F2, F3 and F4	keys can be used to select a screen size of 640 x 480,	*
*	800 x 600 and 1024 x 768 respectively and generate a new landscape.		*
*														*
*	Hitting any other key will just generate a new landscape.				*
*														*
*														*
*	This version for Sim68K 3.6 or later							*
*														*
*	More 68000 and other projects can be found on my website at ..			*
*														*
*	 http://mycorner.no-ip.org/index.html							*
*														*
*	mail : leeedavison@googlemail.com								*
*														*
*************************************************************************************

* first some constants

level_max	EQU 254				* the highest level
level_water	EQU  20				* water level. where the blue ends in the
							* palette

roughness	EQU 461				* terrain roughness = 1.8*256 The bigger
							* this value the rougher is the terrain.
							* The range of this value should be between
							* 1 x 256 and 5 x 256

*************************************************************************************
*
* the code

	ORG		$1000

start
	BSR		Initialise			* go setup everything

* main loop

loop
	BSR.s		screen_size			* test and handle widow size changes

	MOVEQ		#7,d0				* read the key status
	TRAP		#15

	TST.b		d1				* test the result
	BEQ.s		loop				* if no key waiting go wait some more

	MOVEQ		#5,d0				* read a key
	TRAP		#15

	ANDI.b	#$DF,d1			* ensure upper case
	CMP.b		#'S',d1			* compare with [S]ave
	BNE.s		no_save			* if not [S]ave skip the image save

	BSR		save_image			* save the landscape image
no_save
	MOVE.w	#$FF00,d1			* clear screen
	MOVEQ		#11,d0			* position cursor
	TRAP		#15

	BSR		clear_land			* clear the landscape array
	BSR		make_land			* make the new land
	BRA.s		loop				* run again


*************************************************************************************
*
* check the [F2], [F3] and [F4] keys. set the screen size to 640 x 480, 800 x 600 or
* 1024 x 768 if the corresponding key has been pressed

screen_size
	MOVE.l	#$71007273,d1		* [F2], [], [F3] and [F4] keys
	MOVEQ		#19,d0			* check for keypress
	TRAP		#15

	MOVE.l	d1,d2				* copy result
	BEQ.s		notscreen			* skip screen size if no F key

	MOVE.l	#$028001E0,d1		* set 640 x 480
	TST.l		d2				* test result
	BMI		setscreen			* if F2 go set window size

	MOVE.l	#$03200258,d1		* set 800 x 600
	TST.w		d2				* test result
	BMI		setscreen			* if F3 go set window size

							* else was F4 so ..
	MOVE.l	#$04000300,d1		* set 1024 x 768
setscreen
	CMP.l		screen_width(a3),d1	* compare with current screen size
	BEQ.s		notscreen			* if already set skip setting it now

screenset
	MOVE.l	d1,screen_width(a3)	* save the window size
	MOVEQ 	#33,d0			* get/set window size
	TRAP		#15
							* the size has changed so make a new landscape
	BSR		clear_land			* clear the landscape array
	BRA		make_land			* make the new land and return

notscreen
	RTS


*************************************************************************************


	INCLUDE	"save.x68"
							* the image save routines

*************************************************************************************
*
* create the new landscape. fill in the four corners of the landscape with random
* values and then go generate the new landscape. Once this is done raise everything
* below the water level up to the water level

make_land
	BSR		random_n			* generate the next random number

	MOVEQ		#0,d0				* clear longword
	MOVE.b	PRNlword(a3),d0		* get the level
	MOVE.w	d0,-(sp)			* level
	MOVE.w	#0,-(sp)			* y
	MOVE.w	#0,-(sp)			* x
	BSR		set_point			* set the level
	ADDQ.w	#6,sp				* dump the values

	MOVEQ		#0,d0				* clear longword
	MOVE.b	PRNlword+1(a3),d0		* get the level
	MOVE.w	d0,-(sp)			* level
	MOVE.w	ysize(a3),d0		* get y size
	SUBQ.w	#1,d0				* calculate y end
	MOVE.w	d0,-(sp)			* push it
	MOVE.w	#0,-(sp)			* x
	BSR		set_point			* set the level
	ADDQ.w	#6,sp				* dump the values

	MOVEQ		#0,d0				* clear longword
	MOVE.b	PRNlword+2(a3),d0		* get the level
	MOVE.w	d0,-(sp)			* level
	MOVE.w	#0,-(sp)			* y
	MOVE.w	xsize(a3),d0		* get x size
	SUBQ.w	#1,d0				* calculate x end
	MOVE.w	d0,-(sp)			* push it
	BSR		set_point			* set the level
	ADDQ.w	#6,sp				* dump the values

	MOVEQ		#0,d0				* clear longword
	MOVE.b	PRNlword+3(a3),d0		* get the level
	MOVE.w	d0,-(sp)			* level
	MOVE.w	ysize(a3),d0		* get y size
	SUBQ.w	#1,d0				* calculate y end
	MOVE.w	d0,-(sp)			* push it
	MOVE.w	xsize(a3),d0		* get x size
	SUBQ.w	#1,d0				* calculate x end
	MOVE.w	d0,-(sp)			* push it
	BSR		set_point			* set the level
	ADDQ.w	#6,sp				* dump the values

	MOVE.w	ysize(a3),d0		* get y size
	SUBQ.w	#1,d0				* calculate y end
	MOVE.w	d0,-(sp)			* push it
	MOVE.w	xsize(a3),d0		* get x size
	SUBQ.w	#1,d0				* calculate x end
	MOVE.w	d0,-(sp)			* push it
	MOVE.l	#0,-(sp)			* min x,y
	BSR		four_box			* recursive generate the landscape
	ADDQ.w	#8,sp				* dump the values

* bring all the low points up to water level

	MOVE.w	xsize(a3),d7		* get the x_size
	MULU.w	ysize(a3),d7		* * the y_size
	SUBQ.l	#1,d7				* adjust for loop type

	MOVEQ		#level_water,d1		* set the water level
level_loop
	MOVE.b	(a6,d7.l),d0		* get the level
	CMP.b		d1,d0				* compare with the water level
	BCC.s		above_water			* if >= water level skip level set

	MOVE.b	d1,(a6,d7.l)		* set the level
above_water
	DBF		d7,level_loop		* loop if more to do

* now swallow any waiting key pressed during the land generation

	MOVEQ		#7,d0				* read key status
	TRAP		#15

	TST.b		d1				* test the result
	BEQ.s		exit_make_land		* if no key just return

	MOVEQ		#5,d0				* else read a key
	TRAP		#15

exit_make_land
	RTS


*************************************************************************************
*
* generate a new level at this point based on the average level of the previous and
* next points

new_lev_xa	EQU  4				* previous x
new_lev_ya	EQU  6				* previous y

new_lev_x	EQU  8				* this x
new_lev_y	EQU 10				* this y

new_lev_xb	EQU 12				* next x
new_lev_yb	EQU 14				* next y

new_level
	MOVE.w	new_lev_x(sp),d1		* get this x
	MOVE.w	new_lev_y(sp),d2		* get this y

	MOVE.w	d2,-(sp)			* save this y
	MOVE.w	d1,-(sp)			* save this x
	BSR		get_point			* get the level at point x,y
	ADDQ.w	#4,sp				* dump the values

	TST.b		d0				* test the level
	BNE		exit_new_level		* if already done then just exit

	MOVE.w	new_lev_xa(sp),d1		* get previous x
	MOVE.w	new_lev_ya(sp),d2		* get previous y

	MOVE.w	new_lev_xb(sp),d3		* get next x
	MOVE.w	new_lev_yb(sp),d4		* get next y

	MOVE.w	d3,d5				* copy next x
	SUB.w		d1,d5				* subtract previous x

	MOVE.w	d4,d6				* copy next y
	SUB.w		d2,d6				* subtract previous y

	ADD.w		d5,d6				* calculate the distance
	MULU.w	#roughness,d6		* * roughness
	ASR.l		#8,d6				* shift out the fractional part

	MOVE.w	d2,-(sp)			* set previous y as y
	MOVE.w	d1,-(sp)			* set previous x as x
	BSR		get_point			* get the level at point x,y
	ADDQ.w	#4,sp				* dump the values
	MOVE.w	d0,d5				* copy the level

	MOVE.w	d4,-(sp)			* set next y as y
	MOVE.w	d3,-(sp)			* set next x as x
	BSR		get_point			* get the level at point x,y
	ADDQ.w	#4,sp				* dump the values
	ADD.w		d0,d5				* add the level

	MOVE.w	d6,d2				* copy the random word range
	BSR		rand_pm_d2			* generate a random number in the range
							* +/-(d2.w - 1), returned in d0.w
	ADD.w		d0,d5				* add to the level
	ASR.w		#1,d5				* / 2
	BGT.s		not_too_small		* if not too small skip adjust

	MOVEQ		#1,d5				* make byte = $01
	BRA.s		not_too_big			* go save it

not_too_small
	CMP.w		#level_max,d5		* compare with max
	BLE.s		not_too_big			* if not too big skip adjust

	MOVE.w	#level_max,d5		* make byte = max
not_too_big
	MOVE.w	new_lev_x(sp),d1		* get this x
	MOVE.w	new_lev_y(sp),d2		* get this y

	MOVE.w	d5,-(sp)			* level
	MOVE.w	d2,-(sp)			* y
	MOVE.w	d1,-(sp)			* x
	BSR		set_point			* set the level
	ADDQ.w	#6,sp				* dump the values
exit_new_level
	RTS


*************************************************************************************
*
* set the level at point x,y and draw it on the screen

set_point_x	EQU 4+16				* point x co-ordinate
set_point_y	EQU 6+16				* point y co-ordinate
set_point_l	EQU 8+16				* point level

set_point
	MOVEM.l	d1-d4,-(sp)			* save the registers

	MOVE.w	set_point_y(sp),d1	* get the y co-ordinate
	MULU.w	xsize(a3),d1		* * the x size
	MOVEQ		#0,d2				* clear longword
	MOVE.w	set_point_x(sp),d2	* get the x co-ordinate
	ADD.l		d2,d1				* calculate the offset
	MOVE.w	set_point_l(sp),d0	* get the level
	MOVE.b	d0,(a6,d1.l)		* set the value at x,y

	ASL.w		#2,d0				* * 4 bytes per longword colour
	MOVE.l	(a5,d0.w),d1		* get the colour from the palette

	MOVEQ		#80,d0			* set the pen colour
	TRAP		#15

	MOVE.w	set_point_x(sp),d1	* get the x co-ordinate
	MOVE.w	ysize(a3),d2		* get the y size
	SUBQ.w	#1,d2				* calculat the y end
	SUB.w		set_point_y(sp),d2	* subtract the y co-ordinate

	MOVEQ		#82,d0			* draw a pixel
	TRAP		#15

	MOVEM.l	(sp)+,d1-d4			* restore the registers
	RTS


*************************************************************************************
*
* get the level at point x,y. return the level in d0

get_point_x	EQU 4+8				* point x co-ordinate
get_point_y	EQU 6+8				* point y co-ordinate

get_point
	MOVEM.l	d1-d2,-(sp)			* save the registers

	MOVE.w	get_point_y(sp),d1	* get the y co-ordinate
	MULU.w	xsize(a3),d1		* * the x size
	MOVEQ		#0,d2				* clear longword
	MOVE.w	get_point_x(sp),d2	* get the x co-ordinate
	ADD.l		d2,d1				* calculate the offset
	MOVEQ		#0,d0				* clear the longword
	MOVE.b	(a6,d1.l),d0		* get the value at x,y

	MOVEM.l	(sp)+,d1-d2			* restore the registers
	RTS


*************************************************************************************
*
* fill in the middle point and do the four sub boxes

four_box_x1	EQU  4				* box x1
four_box_y1	EQU  6				* box y1
four_box_x2	EQU  8				* box x2
four_box_y2	EQU 10				* box y2


four_box
	MOVE.w	four_box_x1(sp),d1	* get x1
	MOVE.w	four_box_y1(sp),d2	* get y1
	MOVE.w	four_box_x2(sp),d3	* get x2
	MOVE.w	four_box_y2(sp),d4	* get y2

	MOVE.w	d3,d5				* copy x2
	SUB.w		d1,d5				* subtract x1

	CMPI.w	#1,d5				* compare dx with 1
	BGT.s		do_this_box			* if > 1 go do boxes

							* else dx <= 1
	MOVE.w	d4,d6				* copy y2
	SUB.w		d2,d6				* subtract y1

	CMPI.w	#1,d6				* compare dy with 1
	BLE		exit_four_box		* if dy <= 1 just exit

do_this_box
	MOVE.w	d1,d5				* copy x1
	ADD.w		d3,d5				* add x2
	ADDQ.w	#1,d5				* round up
	ASR.w		#1,d5				* / 2 = x

	MOVE.w	d2,d6				* copy y1
	ADD.w		d4,d6				* add y2
	ADDQ.w	#1,d6				* round up
	ASR.w		#1,d6				* / 2 = y

	MOVEM.w	d1-d6,-(sp)			* save x1,y1 x2,y2 and x,y

	MOVE.w	d2,-(sp)			* y1
	MOVE.w	d3,-(sp)			* x2
	MOVE.w	d2,-(sp)			* y1
	MOVE.w	d5,-(sp)			* x
	MOVE.w	d2,-(sp)			* y1
	MOVE.w	d1,-(sp)			* x1
	BSR		new_level			* go get the new colour
	LEA		12(sp),sp			* dump the values
	MOVEM.w	(sp),d1-d6			* restore x1,y1 x2,y2 and x,y

	MOVE.w	d4,-(sp)			* y2
	MOVE.w	d1,-(sp)			* x1
	MOVE.w	d6,-(sp)			* y
	MOVE.w	d1,-(sp)			* x1
	MOVE.w	d2,-(sp)			* y1
	MOVE.w	d1,-(sp)			* x1
	BSR		new_level			* go get the new colour
	LEA		12(sp),sp			* dump the values
	MOVEM.w	(sp),d1-d6			* restore x1,y1 x2,y2 and x,y

	MOVE.w	d4,-(sp)			* y2
	MOVE.w	d3,-(sp)			* x2
	MOVE.w	d4,-(sp)			* y2
	MOVE.w	d5,-(sp)			* x
	MOVE.w	d4,-(sp)			* y2
	MOVE.w	d1,-(sp)			* x1
	BSR		new_level			* go get the new colour
	LEA		12(sp),sp			* dump the values
	MOVEM.w	(sp),d1-d6			* restore x1,y1 x2,y2 and x,y

	MOVE.w	d4,-(sp)			* y2
	MOVE.w	d3,-(sp)			* x2
	MOVE.w	d6,-(sp)			* y
	MOVE.w	d3,-(sp)			* x2
	MOVE.w	d2,-(sp)			* y1
	MOVE.w	d3,-(sp)			* x2
	BSR		new_level			* go get the new colour
	LEA		12(sp),sp			* dump the values
	MOVEM.w	(sp),d1-d6			* restore x1,y1 x2,y2 and x,y

	MOVE.w	d6,-(sp)			* y
	MOVE.w	d5,-(sp)			* x
	BSR		get_point			* get the level at point x,y
	ADDQ.w	#4,sp				* dump the values

	TST.b		d0				* test the level
	BNE.s		skip_mid_point		* if already done then skip it

	MOVE.w	d2,-(sp)			* y1
	MOVE.w	d1,-(sp)			* x1
	BSR		get_point			* get the level at point x,y
	ADDQ.w	#4,sp				* dump the values

	MOVE.l	d0,d7				* copy the level

	MOVE.w	d2,-(sp)			* y1
	MOVE.w	d3,-(sp)			* x2
	BSR		get_point			* get the level at point x,y
	ADDQ.w	#4,sp				* dump the values

	ADD.l		d0,d7				* add the level to the total

	MOVE.w	d4,-(sp)			* y2
	MOVE.w	d1,-(sp)			* x1
	BSR		get_point			* get the level at point x,y
	ADDQ.w	#4,sp				* dump the values

	ADD.l		d0,d7				* add the level to the total

	MOVE.w	d4,-(sp)			* y2
	MOVE.w	d3,-(sp)			* x2
	BSR		get_point			* get the level at point x,y
	ADDQ.w	#4,sp				* dump the values

	ADD.l		d0,d7				* add the level to the total
	ADDQ.w	#2,d7				* round up
	ASR.w		#2,d7				* / 4 to get the average level

	MOVE.w	d7,-(sp)			* level
	MOVE.w	d6,-(sp)			* y
	MOVE.w	d5,-(sp)			* x
	BSR		set_point			* set the level
	ADDQ.w	#6,sp				* dump the values

skip_mid_point
	MOVE.w	d6,-(sp)			* y
	MOVE.w	d5,-(sp)			* x
	MOVE.w	d2,-(sp)			* y1
	MOVE.w	d1,-(sp)			* x1
	BSR		four_box			* recursive box x1,y1 to x,y
	ADDQ.w	#8,sp				* dump the values
	MOVEM.w	(sp),d1-d6			* restore x1,y1 x2,y2 and x,y

	MOVE.w	d4,-(sp)			* y2
	MOVE.w	d5,-(sp)			* x
	MOVE.w	d6,-(sp)			* y
	MOVE.w	d1,-(sp)			* x1
	BSR		four_box			* recursive box x1,y to x,y2
	ADDQ.w	#8,sp				* dump the values
	MOVEM.w	(sp),d1-d6			* restore x1,y1 x2,y2 and x,y

	MOVE.w	d6,-(sp)			* y
	MOVE.w	d3,-(sp)			* x2
	MOVE.w	d2,-(sp)			* y1
	MOVE.w	d5,-(sp)			* x
	BSR		four_box			* recursive box x,y1 to x2,y
	ADDQ.w	#8,sp				* dump the values
	MOVEM.w	(sp),d1-d6			* restore x1,y1 x2,y2 and x,y

	MOVE.w	d4,-(sp)			* y2
	MOVE.w	d3,-(sp)			* x2
	MOVE.w	d6,-(sp)			* y
	MOVE.w	d5,-(sp)			* x
	BSR		four_box			* recursive box x,y to x2,y2
	ADDQ.w	#8,sp				* dump the values
	MOVEM.w	(sp)+,d1-d6			* restore x1,y1 x2,y2 and x,y
exit_four_box
	RTS


*************************************************************************************
*
* setup stuff

Initialise
	LEA		variables(pc),a3		* get the variables base address

	MOVEQ		#8,d0				* get time in 1/100 ths seconds
	TRAP		#15

	EORI.l	#$DEADBEEF,d1		* EOR with the initial PRNG seed, this must
							* result in any value but zero
	MOVE.l	d1,PRNlword(a3)		* save the initial PRNG seed

	LEA		i_buffer(a3),a6		* a6 points to the image buffer
	LEA		palette(pc),a5		* a5 points to the palette

	MOVE.l	#$028001E0,d1		* set default window size to 640 x 480
	BRA		screenset			* go set the screen size


*************************************************************************************
*
* clear the landscape image

clear_land
	MOVE.w	xsize(a3),d7		* get the x_size
	MULU.w	ysize(a3),d7		* * the y_size
	SUBQ.l	#4,d7				* adjust for loop type

	MOVEQ		#0,d0				* clear the longword
fill_loop
	MOVE.l	d0,(a6,d7.l)		* fill the longword
	SUBQ.l	#4,d7				* decrement byte count in longwords
	BPL.s		fill_loop			* loop if more to do

	RTS


*************************************************************************************
*
* generate a random value in d0.w in range -(d2.w - 1) to +(d2.w - 1)

rand_pm_d2
	BSR.s		random_n			* generate a random number
	MOVE.w	PRNlword(a3),d0		* get a random word
	EXT.l		d0				* make into longword. doing this instead of
							* just getting a longword ensures that the
							* following DIVS never overflows
	DIVS.w	d2,d0				* divide by range
	SWAP		d0				* use the signed remainder
	RTS


*************************************************************************************
*
* This is the code that generates the pseudo random sequence. A seed word located in
* PRNlword(a3) is loaded into a register before being operated on to generate the
* next number in the sequence. This number is then saved as the seed for the next
* time it's called.
*
* This code is adapted from the 32 bit version of RND(n) used in EhBASIC68. Taking
* the 19th next number is slower but helps to hide the shift and add nature of this
* generator as can be seen from analysing the output.

random_n
	MOVEM.l	d0-d2,-(sp)			* save d0, d1 and d2
	MOVE.l	PRNlword(a3),d0		* get current seed longword
	MOVEQ		#$AF-$100,d1		* set EOR value
	MOVEQ		#18,d2			* do this 19 times
Ninc0
	ADD.l		d0,d0				* shift left 1 bit
	BCC.s		Ninc1				* if bit not set skip feedback

	EOR.b		d1,d0				* do Galois LFSR feedback
Ninc1
	DBF		d2,Ninc0			* loop

	MOVE.l	d0,PRNlword(a3)		* save back to seed longword
	MOVEM.l	(sp)+,d0-d2			* restore d0, d1 and d2

	RTS


*************************************************************************************
*
* the palette for the landscape. a byte shifted copy of this is included in the
* bitmap header in the save routines.

palette
	dc.l	$000000,$FF0000,$FF0000,$FF0000,$FF0000,$FF0000,$FF0000,$FF0000
	dc.l	$FF0000,$FF0000,$FF0000,$FF0000,$FF0000,$FF0000,$FF0000,$FF0000
	dc.l	$FF0000,$FF0000,$FF0000,$FF0000,$FF0000,$00A400,$00A200,$00A000
	dc.l	$009E00,$009C00,$009A00,$009800,$009600,$009400,$009200,$009000
	dc.l	$008E00,$008C00,$008A00,$008800,$008600,$008400,$008200,$008000
	dc.l	$007E00,$007C00,$007A00,$007800,$007600,$007400,$007200,$007000
	dc.l	$006E00,$006C00,$006A00,$006800,$006600,$006400,$006200,$006000
	dc.l	$015E00,$015C00,$025A00,$025800,$035600,$035400,$035200,$045100
	dc.l	$045000,$044F03,$054E05,$054B08,$05480B,$06460D,$064410,$064113
	dc.l	$073F15,$073C18,$07391B,$08371D,$083420,$083123,$092F25,$092C28
	dc.l	$09292B,$0A272D,$0A2430,$0B2133,$0B1F35,$0B1C38,$0B1C3A,$0B1D3C
	dc.l	$0B1E3E,$0B1E40,$0C1E42,$0C1F44,$0C2046,$0C2048,$0C2049,$0C214A
	dc.l	$0C224B,$0C224C,$0C224D,$0C234E,$0C244F,$0C2450,$0C2451,$0C2552
	dc.l	$0C2653,$0C2654,$0C2655,$0C2756,$0C2857,$0C2858,$0C2859,$0C295A
	dc.l	$0C2A5B,$0C2A5C,$0C2A5D,$0C2B5E,$0C2C5F,$0C2C60,$0C2C61,$0C2D62
	dc.l	$0C2E63,$0C2E64,$0C2E65,$0C2F66,$0C3067,$0C3068,$0C3069,$0C316A
	dc.l	$0C326B,$0C326C,$0C326D,$0C336E,$0C346F,$0C3470,$0C3471,$0C3572
	dc.l	$0C3673,$0D3674,$0D3675,$0D3776,$0D3877,$0E3878,$0E3879,$0E397A
	dc.l	$0E3A7B,$0F3A7C,$0F3A7D,$0F3B7E,$0F3C7F,$103C80,$143E80,$184180
	dc.l	$1C4480,$204680,$244880,$284B80,$2C4E80,$305080,$345280,$385580
	dc.l	$3C5880,$405A80,$445C80,$485F80,$4C6280,$506480,$546680,$586980
	dc.l	$5C6C80,$606E80,$647080,$667281,$677383,$697584,$6A7685,$6C7887
	dc.l	$6D7A88,$6F7B89,$707D8B,$727E8C,$73808D,$75828F,$768390,$788591
	dc.l	$7A8693,$7B8894,$7D8A95,$7E8B97,$808D98,$818E99,$83909B,$84929C
	dc.l	$86939D,$87959F,$8996A0,$8A98A1,$8C9AA3,$8E9BA4,$8F9DA5,$919EA7
	dc.l	$92A0A8,$94A2A9,$95A3AB,$97A5AC,$98A6AD,$9AA8AF,$9BAAB0,$9DABB1
	dc.l	$9EADB3,$A0AEB4,$A2B0B5,$A3B2B7,$A5B3B8,$A6B5B9,$A8B6BB,$A9B8BC
	dc.l	$ABBABD,$ACBBBF,$AEBDC0,$AFBEC1,$B1C0C3,$B2C2C4,$B4C3C5,$B6C5C7
	dc.l	$B7C6C8,$B9C8C9,$BACACB,$BCCBCC,$BDCDCD,$BFCECF,$C0D0D0,$C2D2D1
	dc.l	$C3D3D3,$C5D5D4,$C6D6D5,$C8D8D7,$CADAD8,$CBDBD9,$CDDDDB,$CEDEDC
	dc.l	$D0E0DD,$D1E2DF,$D3E3E0,$D4E5E1,$D6E6E3,$D7E8E4,$D9EAE5,$DAEBE7
	dc.l	$DCEDE8,$DEEEE9,$DFF0EB,$E1F2EC,$E2F3ED,$E4F5EF,$E5F6F0,$FFFFFF

	dc.w	$0000					* terminating $00 byte for .bmp palette


*************************************************************************************
*
* variables

variables

	OFFSET	0				* going to use relative addressing

PRNlword
	ds.l	1					* PRNG seed long word

i_size
screen_width
i_xsize
xsize	ds.w	1					* window x size
i_ysize
ysize	ds.w	1					* window y size

filename_buffer
	ds.b	$100					* save file name buffer
file_id
	ds.l	1					* file id

i_buffer						* the rest of RAM is the image buffer


*************************************************************************************

	END		start

*************************************************************************************

