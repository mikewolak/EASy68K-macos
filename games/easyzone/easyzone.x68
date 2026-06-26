*************************************************************************************
*														*
*	BATTLEZONE type game for the EASy68k simulator	2007/03/26. V1.89			*
*														*
*	Game controls. Use [E] and [D] for left forward and reverse and [I] and		*
*	[K] for right forward and reverse, [SPACE] to fire. Use [P] to start a		*
*	a game. [3] may be used to toggle between the green 2D and the red/blue		*
*	3D view. Note the 3D glasses should have the red lens on the left side.		*
*	The F2, F3 and F4	keys can be used to select a screen size of 640 x 480,	*
*	800 x 600 and 1024 x 768 respectively.							*
*														*
*	The 3D view has been changed to make the objects appear behind the screen	*
*	and may need further tweaking. This seems to work better with LCD monitors	*
*	than CRT types.											*
*														*
*	So far there is the game over attract mode, where the player and the enemy	*
*	are moved as if a game were in progress. There is the high score table		*
*	attract mode that displays the top ten highest scores and the flying logo	*
*	attract screen that shows a static environment and the EASY ZONE logo		*
*	vanishing into the distance.									*
*														*
*	New for V1.5x is the super tank enemy vehicle. This can move twice as fast	*
*	as the player's vehicle but is worth twice the score of the standard tank.	*
*														*
*	As in the original the score still rolls over to 0,000 at 9,999,000		*
*														*
*	Added a sound effect queue so that sounds always play, even if a little		*
*	late sometimes. Sounds include player and enemy fire, player and enemy		*
*	explode, object hit, radar ping, collision, new enemy warning and bonus		*
*	life earned.											*
*														*
*	The F2, F3 and F4	keys can be used to select a screen size of 640 x 480,	*
*	800 x 600 and 1024 x 768 respectively.							*
*														*
*	This version for Sim68K 3.6 beta or later							*
*														*
*	More 68000 and other projects can be found on my website at ..			*
*														*
*	 http://members.lycos.co.uk/leeedavison/index.html					*
*														*
*	mail : leeedavison@lycos.co.uk								*
*														*
*************************************************************************************
*

	ORG	$1000

start
	BSR		Initialise			* go setup game stuff

	MOVEQ		#17,d1			* enable double buffering
	MOVEQ		#92,d0			* set draw mode
	TRAP		#15

	MOVEQ		#10,d1			* OR mode drawing, this helps on two ways.
							* first it emulates a vector display where
							* the vectors that cross can bright up the
							* intersection and second it means we can
							* forget depth sorting of objects
	MOVEQ		#92,d0			* set draw mode
	TRAP		#15

	MOVE.w	#$FF00,d1			* clear screen
	MOVEQ		#11,d0			* position cursor
	TRAP		#15

* main loop. everything is done in this loop, the overall speed of the game is set by
* waiting for a fixed time to pass at the end of the loop

loop
	MOVEQ		#94,d0			* copy screen buffer to main
	TRAP		#15

	MOVEQ		#8,d0				* get time in 1/100 ths seconds
	TRAP		#15

	MOVE.l	d1,-(sp)			* push time on the stack

	BSR		g_controls			* go check the game controls
	BSR		update_env			* go update the environment
	BSR		timeout			* go handle the timeout counter
	BSR		e_movement			* go see if the enemy moved
	BSR		p_controls			* go see if the player moved
	BSR		saucer_motion		* go move the saucer
	BSR		f_movement			* go see if the fire objects moved
	BSR		Update_stars		* go update the volcano star data

	BSR.s		draw_env			* go draw the environment
	BSR.s		play_sound			* handle the sound queue

* now wait for a while. even with drawing the background, animating the volcano, working
* out which of all the objects are visible, translating them from 3D to 2D and drawing
* them, even drawing them twice in 3D view mode, there is still spare time, on a 1.5GHz
* PC, as can be seen by running without the delay, but is set like this to simulate the
* original BATTLEZONE type environment more closely

	MOVE.l	(sp)+,d7			* restore time in 1/100 ths from stack
wait_100ms
	MOVEQ		#8,d0				* get time in 1/100 ths seconds
	TRAP		#15

	SUB.l		d7,d1				* subtract previous time from current time
	CMP.b		#$09,d1			* compare with 9/100ths
	BMI.s		wait_100ms			* loop if time not up yet

* if you want to see how fast it can go comment out the BMI.s above

	BRA		loop				* loop forever


*************************************************************************************
*
* check the queue and play any outstanding sounds. this routine, together with the
* add_sound routine, forms a 7 sound FIFO ring buffer which is way more than should
* ever be needed

sounds	EQU	$07				* number of sounds in queue

play_sound
	MOVE.w	queue_read(a3),d2		* get the queue read index
	CMP.w		queue_write(a3),d2	* compare with the queue write index
	BEQ.s		play_exit			* no sounds queued so just exit

	LEA		queue_snd(a3),a0		* set the pointer to the sound queue

	MOVE.b	(a0,d2.w),d1		* get the sound index
	MOVEQ		#72,d0			* play sound from sound memory
	TRAP		#15

	TST.b		d0				* test the return code
	BEQ.s		play_exit			* just exit if sound didn't play

							* else the sound played so dump it from
							* the queue
	ADDQ.w	#1,d2				* increment the read index
	AND.w		#sounds,d2			* only sounds+1 positions in the queue
	MOVE.w	d2,queue_read(a3)		* save the queue read index
play_exit
	RTS


*************************************************************************************
*
* add a sound to the queue if there is room. sound index is in d1.b. though the queue
* is 8 bytes long only 7 are in use at any one time so the need to keep a count of
* how many items are in the queue is avoided

add_sound
	MOVE.w	d1,-(sp)			* save vehicle index
	TST.w		game_mode(a3)		* test game mode
	BNE.s		add_exit			* if not playing the game don't add the
							* sound to the queue

	MOVE.w	d0,d1				* copy sound
	MOVE.w	queue_write(a3),d2	* get the queue write index
	MOVE.w	d2,d0				* copy it
	ADDQ.w	#1,d2				* increment it
	AND.w		#sounds,d2			* only sounds+1 positions in the buffer
	CMP.w		queue_read(a3),d2		* compare with the queue read index
	BEQ.s		add_exit			* no queue space so just exit

	MOVE.w	d2,queue_write(a3)	* save the new queue write index

	LEA		queue_snd(a3),a0		* set the pointer to the sound queue
	MOVE.b	d1,(a0,d0.w)		* save the sound index
add_exit
	MOVE.w	(sp)+,d1			* restore vehicle index
	RTS


*************************************************************************************
*
* draw the environment. this routine simply draws the screen for the mode, inputs are
* handled by other routines. there are five game modes ..
*
* playing		where the player has control of the viewpoint vehicle and attempts
*			to kill the other, program controlled, vehicle
* game over		where both vehicles are controlled by the program to simulate game
*			play
* high score	where a list of the the highest scores and the players initials are
*			displayed
* logo		where, with the game environment as a backgroung, the game logo is
*			made to fly off into the distance
* enter name	where a high scoring player is invited to add their initials to the
*			score to appear on the high score table

draw_env
	MOVE.w	#$FF00,d1			* clear the screen buffer
	MOVEQ		#11,d0			* position cursor
	TRAP		#15

	MOVE.w	game_mode(a3),d0		* get game mode
	LEA		mode_type(pc),a1		* set pointer to mode type table
	JMP		(a1,d0.w)			* go do mode display vector

mode_type
g_playing		EQU	*-mode_type
	BRA.w		mode_play			* game playing
g_over		EQU	*-mode_type
	BRA.w		mode_over			* game over
g_hiscore		EQU	*-mode_type
	BRA.w		mode_hiscore		* high score table
g_logo		EQU	*-mode_type
	BRA.w		mode_logo			* flying logo
g_ename		EQU	*-mode_type
*##	BRA.w		mode_enter			* high score name entry


*------------------------------------------------------------------------------------
*
* display the high score name entry page

mode_enter
	BSR		draw_scores			* draw the score and high score
	MOVE.w	#m_gscore-m_enemy,d0	* set "GREAT SCORE" offset
	BSR		draw_message		* display the message
	MOVE.w	#m_enter-m_enemy,d0	* set "ENTER YOUR INITIALS" offset
	BSR		draw_message		* display the message
	MOVE.w	#m_change-m_enemy,d0	* set "CHANGE LETTER WITH LEFT HAND CONTROLLER"
							* offset
	BSR		draw_message		* display the message
	MOVE.w	#m_select-m_enemy,d0	* set "SELECT LETTER WITH FIRE BUTTON" offset
	BSR		draw_message		* display the message

	LEA		char_set(pc),a1		* get pointer to the character set table
	MOVE.l	hi_name(a3),a0		* get the high score name pointer

	MOVE.w	#$FFD0,d1			* set name start x co-ordinate
	MOVE.w	#$FF80,d2			* set name start y co-ordinate
	MOVEQ		#86,d0			* set move to x,y
	BSR		display_vector		* display the vector

	MOVEQ		#3,d7				* set character count
	MOVEQ		#0,d6				* clear character index
next_i_char
	CMP.w		hi_index(a3),d6		* compare index with high score entry index
	BNE.s		get_i_char			* if not current entry character just get it

* else the current entry character is being displayed so alternate it between a "_"
* character and the selected character

	MOVEQ		#$4C,d0			* assume character off, use underline
	BTST.b	#2,game_count+1(a3)	* test game count
	BEQ.s		no_i_char			* if bit clear skip character get

get_i_char
	MOVE.b	(a0,d6.w),d0		* get character from score initials
no_i_char
	MOVE.w	(a1,d0.w),d0		* get offset to character
	LEA		(a1,d0.w),a4		* set vector pointer to character

	BSR		do_vector			* go draw the character
	ADDQ.w	#1,d6				* increment index
	DBF		d7,next_i_char		* loop for next character

	RTS


*------------------------------------------------------------------------------------
*
* game over mode. draw the environment then draw the "GAME OVER" and "PRESS START"
* messages

mode_over
	BSR.s		mode_play			* go draw the environment/scores/radar etc
	MOVE.w	#m_gameover-m_enemy,d0	* set "GAME OVER" offset
	BSR		draw_message		* go display the message

	BTST.b	#2,game_count+1(a3)	* test game count bit
	BEQ.s		made_by			* skip press start message if bit off

	MOVE.w	#m_start-m_enemy,d0	* set "PRESS START" offset
	BSR		draw_message		* go display the message and return

made_by
	MOVE.w	#$01,vector_s(a3)		* set binary scale to 2
	MOVE.w	#m_made-m_enemy,d0	* set "V189 LD 2007" offset
	BRA		draw_message		* go display message and return


*------------------------------------------------------------------------------------
*
* play game mode, draw the environment then the bits that only appear during game
* play

mode_play
	BSR.s		display_env			* draw the environment
	BSR		draw_scores			* draw the score and high score
	BSR		draw_radar			* draw the radar and enemy position messages
	BSR		p_boom			* draw the crack if the player is exploding
	BSR		draw_tanks			* draw the tanks for the player lives

	TST.w		v_o_start+v_blocked(a3)	* test blocked flag
	BEQ.s		not_blocked			* if free to move skip message

	BTST.b	#2,game_count+1(a3)	* test game count
	BNE.s		not_blocked			* if bit off skip message

	MOVE.w	#m_motion-m_enemy,d0	* set "MOTION BLOCKED .." offset
	BRA		draw_message		* go display message and return

not_blocked
	RTS


*------------------------------------------------------------------------------------
*
* flying logo mode. draw the environment but omit the player explosion animation, lives
* remaining indication (there aren't any anyway) and the "MOTION BLOCKED.." message
* other routines are modified to omit other parts of the environment during the flying
* logo mode such as shells and the enemy vehicle

mode_logo
	BSR.s		display_env			* draw the environment
	BSR		draw_scores			* draw the score and high score
	BSR		draw_radar			* draw the radar and enemy position messages

	MOVE.w	#$01,vector_s(a3)		* set binary scale to 2
	MOVE.w	#m_made-m_enemy,d0	* set "V189 LD 2007" offset
	BRA		draw_message		* go display message


*------------------------------------------------------------------------------------
*
* display the environment

* translate and draw the view objects. for a 2D view the offset is zeroed and one
* rendering of the scene, as seen from the player's viewpoint, is done in green.

display_env
	BTST.b	#0,viewmode(a3)		* test view mode flag
	BNE.s		threedview			* branch if 3D view mode

							* else set everything for 2D
	MOVE.l	#$00FF00,colourmask(a3)	* set mono colourmask
	MOVEQ		#0,d2				* clear eye x offset
	MOVEQ		#0,d3				* clear eye y offset
	MOVEQ		#0,d4				* clear eye orientation offset
	BRA.s		flatview			* go do the 2D view

* the player has chosen to view the world in 3D so set a +/- y  and orientation
* offset considering the player's current orientation then set it and draw the left
* eye view then negate it and draw the right eye view. red/blue left/right glasses
* are needed to see the 3D image correctly

threedview
	MOVE.l	#$0000FF,colourmask(a3)	* set right colourmask
	MOVE.w	#v_o_start,d1		* index to player object
	BSR		sincos			* get scaled sin(v_orient) in d2,
							* cos(v_orient) in d3
	ASR.w		#2,d2				* x / 4 = x offset for right eye
	ASR.w		#2,d3				* y / 4 = y offset for right eye
	MOVEQ		#-2,d4			* set orientation offset for right eye
	BSR.s		flatview			* save offsets and draw the objects

	MOVE.l	#$FF0000,colourmask(a3)	* set left colourmask
	MOVE.w	eye_osetx(a3),d2		* get x offset for right eye
	MOVE.w	eye_osety(a3),d3		* get y offset for right eye
	MOVE.w	eye_orent(a3),d4		* get eye orientation offset
	NEG.w		d2				* - x offset
	NEG.w		d3				* - y offset
	NEG.w		d4				* - orientation offset

flatview
	MOVE.w	d2,eye_osetx(a3)		* save x offset for 3D/flat view
	MOVE.w	d3,eye_osety(a3)		* save y offset for 3D/flat view
	MOVE.w	d4,eye_orent(a3)		* save orientation offset for 3D/flat view

	BSR		Draw_background		* draw the background
	BSR		Draw_stars			* draw the volcano stars
	BRA		Draw_list			* translate and draw the objects


*------------------------------------------------------------------------------------
*
* display the high score table

mode_hiscore
	BSR		draw_scores			* draw the score and high score
	MOVE.w	#m_hiscores-m_enemy,d0	* set "HIGH SCORES" offset
	BSR		draw_message		* display the message

	MOVE.w	#$FF78,d1			* set x co-ordinate
	MOVEQ		#$0078,d2			* set y co-ordinate
	MOVEQ		#86,d0			* set move to x,y
	BSR		display_vector		* display the vector

	LEA		h_sc_nam(a3),a0		* set high score names pointer
	LEA		char_set(pc),a1		* get pointer to character set table
	LEA		h_score(a3),a2		* set high score pointer

	MOVEQ		#9,d7				* set loop count, 10 scores to do
lp_hiscore
	MOVE.w	(a2),d0			* get high score
	MOVE.w	d7,-(sp)			* save loop count

	MOVEM.l	a0-a2,-(sp)			* save the pointers
	BSR		draw_word			* display d0.w as a leading zero supressed word
	MOVE.w	#m_1000s-m_enemy,d0	* set "000 " offset
	BSR		draw_message		* go display message
	MOVEM.l	(sp)+,a0-a2			* restore the pointers

							* now draw the high score initials
	MOVEQ		#3,d6				* set character count
i_loop
	MOVE.b	(a0)+,d0			* get byte from score initials
	MOVE.w	(a1,d0.w),d0		* get the offset to the character
	LEA		(a1,d0.w),a4		* set the vector pointer to the character
	BSR		do_vector			* go draw the character

	DBF		d6,i_loop			* decrement and loop for the next character

	CMPI.w	#$100,(a2)+			* compare the score with 100,000
	BCS.s		no_100k_tank		* if score < 100,000 skip drawing tank emblem

	LEA		t_outline(pc),a4		* point to tank outline
	BSR		do_vector			* go draw the outline

	MOVEQ		#-$39,d1			* set x offset for tank outline
	ADD.w		local_x(a3),d1		* add local x co-ordinate
	MOVE.w	local_y(a3),d2		* get y co-ordinate
	MOVEQ		#86,d0			* set move to x,y
	BSR		display_vector		* display the vector
no_100k_tank
	MOVE.w	#$FEE0,d1			* set x offset for next line
	MOVEQ		#-$28,d2			* set y offset for next line
	ADD.w		local_x(a3),d1		* add x co-ordinate to x offset
	ADD.w		local_y(a3),d2		* add y co-ordinate to y offset
	MOVEQ		#86,d0			* set move to x,y
	BSR		display_vector		* display the vector

	MOVE.w	(sp)+,d7			* restore loop count
	DBF		d7,lp_hiscore		* decrement count and loop for next high score

	MOVE.w	#m_bonus-m_enemy,d0	* set "BONUS TANK AT " offset
	BSR		draw_message		* go display message

	MOVEQ		#-$30,d1			* set x offset for 2 blanked '0's
	ADD.w		local_x(a3),d1		* add x co-ordinate to x offset
	MOVE.w	local_y(a3),d2		* get y co-ordinate
	MOVEQ		#86,d0			* set move to x,y
	BSR		display_vector		* display the vector

	MOVEQ		#$15,d0			* set first bonus score value
	BSR		draw_word			* display d0.w as a leading zero supressed word

	MOVE.w	#m_1000-m_enemy,d0	* set "000 AND 100000" offset
	BRA		draw_message		* go display the message and return


*************************************************************************************
*
* decrement the game count and trigger events on game counter timeout. this ensures
* that the game over, display high score table and enter name modes will eventually
* move on to the next mode

timeout
	SUBQ.w	#1,game_count(a3)		* decrement game count. this is used for
							* things like flashing messages and game
							* idle timeouts
	BEQ.s		handle_zero			* go handle a decrement to zero

	RTS

handle_zero
	MOVE.w	game_mode(a3),d0		* get game mode
	LEA		tout_type(pc),a1		* pointer to timeout type table
	JMP		(a1,d0.w)			* go do mode timeout

* time out table, jumps to longword entry point depending on mode

tout_type
	RTS						* game playing just return
	NOP						* padding

	BRA.w		tout_over			* game over timeout

	BRA.w		tout_hiscore		* show high score table timeout

	RTS						* flying logo just return
	NOP						* padding

*##	BRA.w		tout_ent_hisc		* enter high score timeout


*------------------------------------------------------------------------------------
*
* enter high score name timeout. just change the mode to display high score table and
* set a 15 second timeout

tout_ent_hisc
	MOVE.w	#150,game_count(a3)	* set 15 second timeout
	MOVE.w	#g_hiscore,game_mode(a3)
							* set show high score table mode
	RTS


*------------------------------------------------------------------------------------
*
* game over timeout. reset the counter for 15 seconds and change the mode to display
* the high score table

tout_over
	MOVEQ		#0,d0				* clear longword
	MOVE.w	#f_o_last,d1		* index to last weapon fire object
f_o_clr_l
	MOVE.w	d0,f_count(a3,d1.w)	* clear weapon fire object counter
	SUB.w		#f_o_size,d1		* decrement fire object index
	CMP.w		#f_o_start,d1		* compare index with first object
	BPL.s		f_o_clr_l			* loop if more fire objects to clear

	MOVE.w	#150,game_count(a3)	* set 15 second timeout
	MOVE.w	#g_hiscore,game_mode(a3)
							* set show high score table mode
	RTS


*------------------------------------------------------------------------------------
*
* display high score table timeout. just reset the logo position and change the mode
* to flying logo

tout_hiscore
	MOVE.w	#$0000,logo_x(a3)		* set flying logo x co-ordinate
	MOVE.w	#$FF00,m_alt(a3)		* set flying logo altitude
	MOVE.w	#g_logo,game_mode(a3)	* set flying logo mode
	RTS


*************************************************************************************
*
* update the environment. all those little things that change over time are lumped
* in here

update_env
	MOVEQ		#0,d1				* get current window size
	MOVEQ		#33,d0			* set/get output window size
	TRAP		#15

	MOVE.l	d1,scr_x(a3)		* save screen x and y size
	LSR.l		#1,d1				* make centre values
	MOVE.l	d1,scr_x_c(a3)		* save screen x and y centre

	LSR.w		vert_offs(a3)		* decrease the vertical offset or just leave
							* it at zero. this restores the bounce from
							* a collision or explosion

	MOVE.w	#v_o_last,d1		* index to last vehicle
v_f_loop
	MOVE.w	v_f_count(a3,d1.w),d0	* get vehicle fire counter
	BEQ.s		no_dec_vf			* skip decrement if timed out

	SUBQ.w	#1,d0				* decrement vehicle fire counter
	MOVE.w	d0,v_f_count(a3,d1.w)	* save vehicle fire counter
no_dec_vf

	SUB.w		#v_o_size,d1		* decrement vehicle index
	CMP.w		#v_o_start,d1		* compare with first
	BPL.s		v_f_loop			* loop if more to do

	TST.w		game_mode(a3)		* test game mode
	BNE.s		no_game_over		* if not playing skip end game

	TST.w		p_lives(a3)			* test player lives
	BNE.s		no_game_over		* if lives left skip end game

* the player is dead, kill the sound queue and initialise the saucer then check the
* player's score against those in the high score table to see if the player is worthy
* of inclusion

	BSR		init_saucer			* initialise saucer
	MOVE.w	queue_write(a3),queue_read(a3)
							* copy the sound queue write index to the sound
							* queue read index, kill the sound queue

	LEA		h_sc_nam-4(a3),a0		* set high score name pointer
	LEA		h_score-2(a3),a2		* set high score pointer

	MOVE.w	p_score(a3),d2		* get player score
	MOVEQ		#9,d7				* set loop count, 10 scores to do
hiscore_ck_lp
	ADDQ.l	#4,a0				* increment high score name pointer
	ADDQ.l	#2,a2				* increment high score pointer

	CMP.w		(a2),d2			* compare high score with player score
	BHI.s		is_hiscore			* if more go enter high score in table

	DBF		d7,hiscore_ck_lp		* loop for next if not all done

* the player's score was not worthy of inclusion in the table so return to game over mode
* and set the timout for 60 seconds

	MOVE.w	#g_over,game_mode(a3)	* set game over mode
	MOVE.w	#600,game_count(a3)	* set 60 second timeout
no_game_over
	RTS


*------------------------------------------------------------------------------------
*
* the player's score is worthy of inclusion in the high score table so shuffle the
* score into place shfting the lower scores down and set the enter high score name
* mode

is_hiscore
	MOVE.l	a0,hi_name(a3)		* save the high score name pointer
	MOVE.l	#$16000000,d3		* set the longword to "A   "
	MOVE.w	d3,hi_index(a3)		* clear high score entry index
hiscore_sw_lp
	MOVE.l	(a0),d0			* get current high score name
	MOVE.l	d3,(a0)+			* save previous name as current
	MOVE.l	d0,d3				* copy name

	MOVE.w	(a2),d1			* get current high score
	MOVE.w	d2,(a2)+			* save previous score as current
	MOVE.w	d1,d2				* copy score

	DBF		d7,hiscore_sw_lp		* loop for next if not all done

	MOVE.w	#g_ename,game_mode(a3)	* set enter high score name mode
	MOVE.w	#600,game_count(a3)	* set 60 second timeout
	RTS


*************************************************************************************
*
* add d0 to player score and do the bonus tank calculation. this is a BCD add as we
* don't want the score in hex and it's easier than doing hex to decimal conversion
* at display time

add_player
	TST.w		game_mode(a3)		* test the game mode
	BNE.s		add_p_exit			* if not playing don't add to score

	MOVE.w	p_score(a3),d1		* get current score
	LEA		p_score+2(a3),a0		* pointer to player score low byte + 1
	LEA		p_temp(a3),a1		* pointer to temp word

	MOVE.w	d0,(a1)+			* save word to add and increment pointer
	ABCD.b	d0,d0				* clear X flag
	ABCD.b	-(a1),-(a0)			* add low bytes
	ABCD.b	-(a1),-(a0)			* add high bytes
	MOVE.w	p_score(a3),d0		* get updated score score
	CMP.w		#$100,d1			* compare current score with 100,000
	BCC.s		add_p_exit			* exit if current score >= 100,000

	CMP.w		#$100,d0			* compare updated score with 100,000
	BCC.s		add_bonus			* add bonus if updated score >= 100,000

	CMP.w		#$15,d1			* compare current score with 15,000
	BCC.s		add_p_exit			* exit if current score >= 15,000

	CMP.w		#$15,d0			* compare updated score with 15,000
	BCS.s		add_p_exit			* exit if updated score < 15,000

add_bonus
	ADDQ.w	#1,p_lives(a3)		* add bonus tank

	MOVEQ		#s_bonus,d0			* index to bonus tank sound
	BRA		add_sound			* add the sound to the queue and return

add_p_exit
	RTS


*************************************************************************************
*
* movement values. there are eight 'legal' movement values

move_rr	EQU	%0001<<1			* reverse right
move_fr	EQU	%0010<<1			* forward right
move_rl	EQU	%0100<<1			* reverse left
move_re	EQU	%0101<<1			* reverse
move_sl	EQU	%0110<<1			* spin left
move_fl	EQU	%1000<<1			* forward left
move_sr	EQU	%1001<<1			* spin right
move_fo	EQU	%1010<<1			* forward


*************************************************************************************
*
* enemy motion. "it wanders lonely as a cloud..." and the radar spins. when you shoot
* it it will explode. now includes super tank motion

e_movement
	MOVE.w	#v_o_start+v_o_size,d1	* index to enemy object
	TST.w		v_expsn(a3,d1.w)		* test explosion flag
	BEQ.s		e_do_move			* not exploding so go do motion

* else the enemy is exploding so animate the explosion parts. explosion parts are much
* like the volcano stars except they move in three dimensions not two and they have a
* rotational component

	MOVEQ		#$00,d3			* default flag explosion done

	MOVEQ		#$0A,d2			* set index to last explosion object
	LEA		ex_object(a3),a1		* set pointer to explosion object list
expn_loop
	MOVE.w	ex_z(a1,d2.w),d0		* get explosion part z co-ordinate
	BMI.s		next_expsn			* if object below the horizon go do next

	MOVE.w	ex_dx(a1,d2.w),d0		* get explosion part delta x
	ADD.w		d0,ex_x(a1,d2.w)		* add to explosion part x co-ordinate

	MOVE.w	ex_dy(a1,d2.w),d0		* get explosion part delta y
	ADD.w		d0,ex_y(a1,d2.w)		* add to explosion part y co-ordinate

	MOVE.w	ex_dz(a1,d2.w),d0		* get explosion part delta z
	CMP.w		#$FF85,d0			* compare with max fall velocity
	BLT.s		no_accle			* skip acceleration if falling at max velocity

	SUBQ.w	#4,ex_dz(a1,d2.w)		* else accelerate downwards
no_accle
	ADD.w		d0,d0				* * 2
	ADD.w		d0,d0				* * 4
	ADD.w		d0,ex_z(a1,d2.w)		* add to explosion part z co-ordinate

	MOVEQ		#3,d0				* set mimimum explosion part spin rate - 8 bit
	ADD.b		d2,d0				* add index as specific part spin
	ADD.b		d0,d0				* * 2
	ADD.b		d0,d0				* * 4
	ADD.b		d0,ex_o(a1,d2.w)		* add to explosion part orientation

	MOVEQ		#-1,d3			* flag explosion not done
next_expsn
	SUBQ.w	#2,d2				* decrement index to previous object
	BPL.s		expn_loop			* loop if more to do

	MOVE.w	d3,v_expsn(a3,d1)		* save enemy explosion flag
	BNE.s		expsn_exit			* exit if explosion not ended

* else the explosion ended so now add the object value to the player score

	MOVEQ		#5,d0				* 5,000 for a missile
	CMP.w		#obj_miss,v_o_type(a3,d1.w)
							* compare enemy with missile
	BEQ.s		add_value			* if missile go add value if missile

	MOVEQ		#2,d0				* 2,000 for a supertank
	CMP.w		#obj_stnk,v_o_type(a3,d1.w)
							* compare enemy with supertank
	BEQ.s		add_value			* if supertank go add value if missile

	MOVEQ		#1,d0				* 1,000 for a tank
add_value
	MOVE.w	#-1,v_o_type(a3,d1.w)	* clear the enemy object number
	BRA		add_player			* add value to player score and return

expsn_exit
	RTS

* else the enemy vehicle just moves

e_do_move
	TST.w		v_o_type(a3,d1.w)		* test the enemy object number
	BMI		new_enemy			* if none present spawn new enemy and return

	SUB.b		#$07,e_radar(a3)		* else animate the enemy tank radar
*##	BRA		v_movement			* go do vehicle movement


*************************************************************************************
*
* vehicle movement. move the vehicle according to the vehicle motion word, timeout
* count and target bearing. if timed out chose a new direction and timeout, if
* collision with anything chose a new reversed direction and timeout. If forward
* motion sometimes track the other vehicle. enter with d1.w = vehicle object index

v_movement
	MOVEQ		#0,d6				* clear the collision flag
	MOVEQ		#-8,d0			* mask game over
	AND.w		game_mode(a3),d0		* AND with game mode
	BNE.s		v_move_exit			* if not playing the game or not in game over
							* mode don't move anything

	MOVE.w	v_xcoord(a3,d1.w),t_xcoord(a3)
							* copy vehicle x co-ordinate to temp
	MOVE.w	v_ycoord(a3,d1.w),t_ycoord(a3)
							* copy vehicle y co-ordinate to temp

	MOVE.w	v_motion(a3,d1.w),d2	* get vehicle motion word
	AND.w		#move_re,d2			* mask reverse bits
	BEQ.s		v_move_forw			* branch if neither reverse bits set

* motion is reverse or reverse turn. this is the easy bit, just do the move and check for
* collisions, if it collided undo the move. after the move see if the timer has expired
* and if it has do a short forward move

	SUBQ.b	#2,v_anim_c(a3,d1.w)	* decrement vehicle anim counter
	MOVE.w	v_motion(a3,d1.w),d2	* get vehicle motion word
	LEA		movetable(pc),a0		* get movement table base address
	JSR		(a0,d2.w)			* do vehicle movement vector
	BSR		chk_v_colsn			* check for collisions
	MOVE.w	d6,v_blocked(a3,d1.w)	* save blocked flag
	BEQ.s		v_move_done			* if no collision go see if move complete

* else there was a collision with something so restore the previous vehicle position

	MOVE.w	t_xcoord(a3),v_xcoord(a3,d1.w)
							* copy temp back to vehicle x co-ordinate
	MOVE.w	t_ycoord(a3),v_ycoord(a3,d1.w)
							* copy temp back to vehicle y co-ordinate

* the vehicle was turning or moving backward so reverse the direction of motion but keep
* the direction of rotation the same

	MOVE.w	v_motion(a3,d1.w),d2	* get vehicle motion word
	EOR.w		#move_re,d2			* toggle reverse bits
	ADD.w		d2,d2				* move the reverse bits to the forward bits
	MOVE.w	d2,v_motion(a3,d1.w)	* save vehicle motion word

	MOVEQ		#$1F,d0			* set timeout mask
	AND.b		PRNlword(a3),d0		* AND random timeout with mask
	ADDQ.w	#8,d0				* plus a minimum
	MOVE.b	d0,v_mot_time(a3,d1.w)	* set vehicle motion timeout byte
	RTS

v_move_done
	SUBQ.b	#1,v_mot_time(a3,d1.w)	* decrement vehicle motion timeout byte
	BPL.s		v_move_exit			* if timer not expired just exit

* done reverse turning, now go forward a bit before turning back towards the other
* vehicle

	MOVE.w	#move_fo,v_motion(a3,d1.w)
							* set vehicle motion word forward
	MOVE.w	v_orient(a3,d1.w),d2	* get vehicle orientation word
	MOVE.w	d2,v_target(a3,d1.w)	* set vehicle target orientation word
	MOVE.b	#$34,v_mot_time(a3,d1.w)
							* set vehicle motion timeout byte
v_move_exit
	RTS


*------------------------------------------------------------------------------------
*
* else motion is forward, first check if target orientation is within field of view

v_move_forw
	MOVE.w	v_orient(a3,d1.w),d3	* get vehicle orientation word
	SUB.w		v_target(a3,d1.w),d3	* subtract vehicle target orientation
	AND.w		#$1FF,d3			* make in range $000 to $1FF
	ADD.w		#$FF00,d3			* set top bits clear if -ve, set if +ve
	EOR.w		#$FF00,d3			* toggle bits to correct state

	MOVEQ		#move_sr,d2			* set for spin deocil
	MOVE.w	d3,d0				* copy difference between current orientation
							* and target orientation
	BPL.s		rot_deocil			* branch if result was +ve

	NEG.w		d0				* else make ABS(result) ..
	MOVEQ		#move_sl,d2			* .. and spin widdershins
rot_deocil
	CMP.w		v_foview(a3,d1.w),d0	* compare ABS(result) with field of view
	BCC.s		v_offset			* if ABS(result) >= capture angle, target
							* orientation is outside the field of view
							* so just spin toward it

* else the target orientation is within the field of view

	AND.w		#move_fo,d2			* turn spin into rotate
	TST.w		d0				* test ABS(diff) between current orientation
							* and target orientation
	BNE.s		v_offset			* if not directly ahead go rotate left or right

	MOVEQ		#move_fo,d2			* else make the motion straight ahead
v_offset
	CMP.w		#obj_stnk,v_o_type(a3,d1.w)
							* compare the vehicle with the super tank type
	BNE.s		v_m_tank			* if not a supertank skip the extra move

	MOVE.w	#move_re,d0			* set reverse mask
	AND.w		d2,d0				* mask move vector
	BNE.s		v_m_tank			* if reversing skip the extra move

	MOVE.w	d2,-(sp)			* save the movement vector
	LEA		movetable(pc),a0		* get movement table base address
	JSR		(a0,d2.w)			* do the vehicle movement vector
	BSR		chk_v_colsn			* check for collisions
	MOVE.w	(sp)+,d2			* restore the movement vector

	MOVE.w	d6,v_blocked(a3,d1.w)	* save the blocked flag
	BNE.s		v_m_collided		* if collision go undo move

	MOVEQ		#move_fo,d2			* make the motion straight ahead
							* else update the vehicle temporary position
	MOVE.w	v_xcoord(a3,d1.w),t_xcoord(a3)
							* copy vehicle x co-ordinate to temp
	MOVE.w	v_ycoord(a3,d1.w),t_ycoord(a3)
							* copy vehicle y co-ordinate to temp

v_m_tank
	LEA		movetable(pc),a0		* get movement table base address
	JSR		(a0,d2.w)			* do the vehicle movement vector
	BSR		chk_v_colsn			* check for collisions
	MOVE.w	d6,v_blocked(a3,d1.w)	* save the blocked flag
	BEQ.s		v_no_move			* if no collision just exit

* else the vehicle collided with something so undo the move

v_m_collided
	MOVE.w	t_xcoord(a3),v_xcoord(a3,d1.w)
							* copy temp back to vehicle x co-ordinate
	MOVE.w	t_ycoord(a3),v_ycoord(a3,d1.w)
							* copy temp back to vehicle y co-ordinate

	TST.w		d7				* test the collision index, will be -ve if it
							* was the other vehicle
	BMI.s		v_no_move			* don't back off if it was the other vehicle


*------------------------------------------------------------------------------------
*
* else it was a collision with the scenery so back up a bit

	MOVEQ		#$3F,d0			* set timeout mask
	MOVEQ		#move_rr,d3			* set direction, reverse right
	BTST.b	#6,game_count+1(a3)	* test game count, need random 0/1
	BNE.s		set_timeout			* if 1 keep right

							* else ..
	MOVEQ		#move_rl,d3			* set direction, reverse left
set_timeout
	MOVE.w	d3,v_motion(a3,d1.w)	* set vehicle motion word
	AND.b		PRNlword(a3),d0		* AND random timeout with mask
	ADDQ.b	#8,d0				* plus a minimum
	MOVE.b	d0,v_mot_time(a3,d1.w)	* set vehicle motion timeout byte

v_no_move
	MOVE.w	d1,-(sp)			* save vehicle index
	BSR		v_fire			* make vehicle fire if possible
	MOVE.w	(sp)+,d1			* restore vehicle index
	SUBQ.b	#1,v_mot_time(a3,d1.w)	* decrement vehicle motion timeout byte
	BPL		v_move_exit			* if motion timer not expired just exit


*------------------------------------------------------------------------------------
*
* else motion is forward and the motion timer has expired

	CMP.w		#v_o_start,d1		* test the vehicle index
	BEQ.s		v_hunting			* if it's the player always go hunt

	TST.w		game_mode(a3)		* test game mode
	BNE.s		v_wander			* if not playing the game wander about all of
							* the time

	TST.b		p_score(a3)			* test player score 100s
	BNE.s		v_hunting			* if the player score >=100,000 then go hunt
							* the player every time

	BTST.b	#5,game_count+1(a3)	* test game count
	BEQ.s		v_hunting			* if b5 was 0 go hunt 50% of the time

	MOVE.w	p_score(a3),d0		* get the player score, always < $100
	BEQ.s		v_wander			* if score = $00 wander all of the time

	SUBQ.w	#3,d0				* subtract start lives count
	ADD.w		p_lives(a3),d0		* add number of lives remaining
	BNE.s		v_hunting			* if score > lives lost go hunt the player


*------------------------------------------------------------------------------------
*
* run away from the other vehicle, try to stay moving at 90 degrees to it

v_runaway
	BSR		gen_prng			* call the PRNG code
	MOVEQ		#move_re,d0			* set to back up a bit
	MOVEQ		#$10,d3			* set vehicle motion timeout byte
	MOVEQ		#$07,d2			* mask for 0 to 7
	AND.w		PRNlword(a3),d2		* mask random word
	BEQ.s		v_save_tam			* 1/8th of the time just back up a bit

							* else target to 1/4 circle from other vehicle
	BNE		bear_v0_v1			* calculate the angle between objects
	EOR.w		#40,d0			* shift 1/4 circle
	MOVE.w	d0,v_target(a3,d1.w)	* set vehicle target orientation
	MOVEQ		#move_fo,d0			* set move forward
	MOVE.w	#$60,v_foview(a3,d1.w)	* save vehicle field of view
	MOVEQ		#$20,d3			* set vehicle motion timeout byte
v_save_tam
	MOVE.b	d3,v_mot_time(a3,d1.w)	* save vehicle motion timeout byte
	MOVE.w	d0,v_motion(a3,d1.w)	* save vehicle motion word
	RTS


*------------------------------------------------------------------------------------
*
* else the vehicle was turning/moving forward and had completed the move so vary the
* target heading and wait a bit

v_wander
	BSR		gen_prng			* call the PRNG code
	MOVEQ		#$1E,d0			* set angle mask
	AND.w		PRNlword(a3),d0		* mask random angle
	BTST.b	#6,game_count+1(a3)	* test counted 0/1
	BNE.s		v_reverse			* branch half the time

	NEG.w		d0				* negate target orientation offset
v_reverse
	ADD.w		d0,v_target(a3,d1.w)	* add to vehicle target orientation
	MOVE.w	#move_fo,v_motion(a3,d1.w)
							* set vehicle motion word to forward
	MOVEQ		#$50,d3			* set long motion timeout value
	BRA.s		v_set_fam			* go set new field of view and motion time


*------------------------------------------------------------------------------------
*
* hunt the other vehicle

v_hunting
	BSR		bear_v0_v1			* calculate the angle between objects
	MOVE.w	d0,v_target(a3,d1.w)	* save vehicle target orientation
	MOVE.w	#move_fo,v_motion(a3,d1.w)
							* set vehicle motion word to forward
	MOVEQ		#$04,d3			* set motion timeout for a short move


*------------------------------------------------------------------------------------
*
* set new motion time and decrement the field of view

v_set_fam
	MOVE.b	d3,v_mot_time(a3,d1.w)	* save vehicle motion timeout byte
v_dec_fov
	SUB.w		#2,v_foview(a3,d1.w)	* decrement field of view
	BMI.s		v_res_fov			* do reset if -ve

	BHI.s		v_save_exit			* skip reset if still +ve and not zero

v_res_fov
	MOVE.w	#$24,v_foview(a3,d1.w)	* save vehicle field of view
v_save_exit
	RTS


*************************************************************************************
*
* check for vehicle collisions with other vehicles and then each world object in
* turn. enter with d1.w = vehicle index
*
* this routine returns d6.l = 0 for no collision and d6.l = -1 if a collision was
* detected. if there was a collision detected then d7.w is -2 for a collision with
* the other vehicle or positive for a collision with an environment object

chk_v_colsn
	MOVE.w	v_xcoord(a3,d1.w),d2	* get vehicle x co-ordinate
	MOVE.w	v_ycoord(a3,d1.w),d3	* get vehicle y co-ordinate

	MOVEQ		#-2,d7			* set world object index for pre increment
	MOVE.w	#v_o_last,d0		* index to last vehicle
chk_vv_loop
	CMP.w		d0,d1				* compare other vehicle with vehicle index
	BEQ.s		chk_v_next			* if this is us go check next

	TST.w		v_o_type(a3,d0.w)		* test other object number
	BMI.s		chk_v_next			* skip check if no object

	TST.w		v_expsn(a3,d0.w)		* is the other vehicle exploding
	BNE.s		chk_v_next			* skip check if exploding

	MOVE.w	v_xcoord(a3,d0.w),d4	* get other vehicle x co-ordinate
	MOVE.w	v_ycoord(a3,d0.w),d5	* get other vehicle y co-ordinate

	SUB.w		d2,d4				* calculate delta x from vehicle
	SUB.w		d3,d5				* calculate delta y from vehicle

	MULS.w	d4,d4				* x^2
	MULS.w	d5,d5				* y^2
	ADD.l		d5,d4				* now = x^2 + y^2

	CMP.l		#$A1C44,d4			* compare with collision distance, $32E^2
	BCS.s		v_colsn			* if closer away than minimum limit go flag
							* collision

chk_v_next
	SUB.w		#v_o_size,d0		* index to previous vehicle
	CMP.w		#v_o_start,d0		* compare with first
	BPL.s		chk_vv_loop			* loop if more to do


*------------------------------------------------------------------------------------
*
* entry point to check for vehicle collisions with each world object in turn. enter
* with d1.w = vehicle index

chk_w_colsn
	MOVE.w	v_xcoord(a3,d1.w),d2	* get vehicle x co-ordinate
	MOVE.w	v_ycoord(a3,d1.w),d3	* get vehicle y co-ordinate

	MOVEQ		#$00,d6			* flag no collision
	MOVEQ		#-2,d7			* set world object index for pre increment
v_colsn_loop
	ADDQ.w	#2,d7				* increment world object index to next object
	TST.w		(a6,d7.w)			* test for end of the world object list
	BMI.s		end_v_colsn			* if all done exit the loop with the collision
							* flag clear

	MOVE.w	obj_x(a6,d7.w),d4		* get world object x co-ordinate
	MOVE.w	obj_y(a6,d7.w),d5		* get world object y co-ordinate

	SUB.w		d2,d4				* calculate delta x from vehicle
	SUB.w		d3,d5				* calculate delta y from vehicle

	MULS.w	d4,d4				* x^2
	MULS.w	d5,d5				* y^2
	ADD.l		d5,d4				* now = x^2 + y^2

	CMP.l		#$A1C44,d4			* compare with collision distance, $32E^2
	BCC.s		v_colsn_loop		* loop if further away than minimum limit

v_colsn
	MOVEQ		#-1,d6			* else there was a collision so set the flag
end_v_colsn
	RTS


*************************************************************************************
*
* get the player to enter up to four initials. use [E] and [D] keys to change the
* character and [spacebar] to enter the character. available characters, in order,
* are 'ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789'

p_hiscore
	MOVE.l	#'E D ',d1			* keys [E], [D] and [SPACE]
	MOVEQ		#19,d0			* check for keypress
	TRAP		#15

	MOVE.l	hi_lastk(a3),d0		* get last keys pressed
	MOVE.l	d1,hi_lastk(a3)		* save these as last keys

	EOR.l		d1,d0				* set keys that have changed
	AND.l		d1,d0				* clear keys that are released

	MOVE.w	hi_index(a3),d2		* get high score entry index
	MOVE.l	hi_name(a3),a0		* get the high score name pointer

	TST.b		d0				* test [SPACE] key
	BMI.s		press_space			* branch if [SPACE] pressed

	TST.w		d0				* test [D] key
	BMI.s		press_d			* branch if [D] pressed

	TST.l		d0				* test [E] key
	BMI.s		press_e			* branch if [E] pressed

	MOVE.l	d1,d0				* copy current keys
	SWAP		d0				* [E] key to low word
	AND.w		d1,d0				* mask for [E] and [D]
	BMI.s		p_k_exit			* exit if both keys pressed

	TST.w		d1				* test [D] key
	BMI.s		hold_d			* branch if [D] held

	TST.l		d1				* test [E] key
	BMI.s		hold_e			* branch if [E] held

p_k_exit
	RTS


*------------------------------------------------------------------------------------
*
* [SPACE] key pressed, if not the last character set "A" as the start point for the
* next character else, if it was the last character, change mode to display high
* score table

press_space
	MOVEQ		#$16,d0			* default to "A" for new character
	ADDQ.w	#1,d2				* increment it
	CMP.w		#4,d2				* compare with max+1
	BNE.s		p_space_e			* exit if not all done

* name entry is complete, now skip to show high score table

	MOVE.w	#150,game_count(a3)	* set 15 second timeout
	MOVE.w	#g_hiscore,game_mode(a3)
							* set show high score table mode
	MOVEQ		#0,d2				* clear high score name index
	MOVE.b	(a0,d2.w),d0		* get indexed character
p_space_e
	MOVE.w	d2,hi_index(a3)		* save/clear high score entry index
	MOVE.b	d0,(a0,d2.w)		* set indexed character
	RTS


*------------------------------------------------------------------------------------
*
* [D] key held, check the held count and, if it's expired, act as if the [D] key was
* just pressed

hold_d
	MOVEQ		#3,d0				* set mask
	AND.w		game_count(a3),d0		* test for $00 end
	BNE.s		exit_p_d			* if not end skip [D] key pressed


*------------------------------------------------------------------------------------
*
* [D] key pressed

press_d
	MOVE.b	(a0,d2.w),d0		* get indexed character
	SUBQ.b	#2,d0				* decrement it to the previous character
	BPL.s		no_n_wrap			* branch if in range " " to "Z"

	MOVEQ		#$48,d0			* else change to "Z"
no_n_wrap
	MOVE.b	d0,(a0,d2.w)		* save indexed character
	MOVE.w	#599,game_count(a3)	* reset 59.9 second timeout, this ensures
							* all the characters are visible if you hold
							* a key down
exit_p_d
	RTS


*------------------------------------------------------------------------------------
*
* [E] key held, check the held count and, if it's expired, act as if the [E] key was
* just pressed

hold_e
	MOVEQ		#3,d0				* set mask
	AND.w		game_count(a3),d0		* test for $00 end
	BNE.s		exit_p_d			* if not end skip [E] key pressed


*------------------------------------------------------------------------------------
*
* [E] key pressed

press_e
	MOVE.b	(a0,d2.w),d0		* get indexed character
	ADDQ.b	#2,d0				* increment it to the next character
	CMP.b		#$4A,d0			* compare with "Z"+1
	BMI.s		no_n_wrap			* branch if in range " " to "Z"

	MOVEQ		#$00,d0			* else change to " "
	BRA.s		no_n_wrap			* go save indexed character and reset timer


*************************************************************************************
*
* the player is controled by the motion subroutine, assuming the player isn't
* exploding

m_control
	MOVE.w	#v_o_start,d1		* index to player object
	TST.w		v_expsn(a3,d1.w)		* test player object exploding
	BNE		no_collision		* don't move if the player is exploding

	PEA		bounce_player(pc)		* return to end of p_movement
	BRA		v_movement			* allow machine move the player


*------------------------------------------------------------------------------------
*
* player controls. the routine used depends on the game mode. in play mode the
* player controls are active, in game over mode player control is passed to the
* vehicle movement subroutine. In high score and logo modes the controls are inactive
* and in enter name mode the controls are used to enter the player's initials

p_controls
	MOVE.w	game_mode(a3),d0		* get game mode
	LEA		p_mode(pc),a1		* pointer to player mode table
	JMP		(a1,d0.w)			* go do mode display vector

* control mode branch table

p_mode
	BRA.w		p_movement			* allow player control
	BRA.w		m_control			* allow machine control of player
	RTS						* show high scores just return
	NOP						* padding
	RTS						* flying logo just return
	NOP						* padding
	BRA.w		p_hiscore			* player entering high score name


*------------------------------------------------------------------------------------
*
* player object motion. two tracks move the vehicle, the left track is controlled
* using the E and D keys, the right track using the I and K keys. use the spacebar
* to fire

p_movement
	MOVE.w	#v_o_start,d1		* index to player object
	TST.w		v_expsn(a3,d1.w)		* test vehicle exploding
	BNE.s		no_collision		* don't move if vehicle exploding

	BSR		p_fire			* go see if player fired
	MOVE.w	v_xcoord(a3,d1.w),t_xcoord(a3)
							* copy vehicle x co-ordinate to temp
	MOVE.w	v_ycoord(a3,d1.w),t_ycoord(a3)
							* copy vehicle y co-ordinate to temp

	MOVE.l	#'EDIK',d1			* keys left and right forward/reverse
	MOVEQ		#19,d0			* check for keypress
	TRAP		#15

	MOVEQ		#$06,d2			* mask for b2,b1
	LSR.w		#6,d1				* 'IK' bits to b2,b1
	AND.w		d1,d2				* copy masked bits to d2
	SWAP		d1				* 'ED' bits to lower word
	LSR.w		#4,d1				* 'ED' bits to b4,b3
	AND.w		#$18,d1			* mask 'ED' bits
	OR.w		d2,d1				* OR in 'IK' bits
	MOVE.w	d1,d2				* copy the result

	MOVE.w	#v_o_start,d1		* index to player object
	LEA		movetable(pc),a0		* get table base address
	JSR		(a0,d2.w)			* do vehicle movement vector
	BSR		chk_v_colsn			* check for collisions
bounce_player
	MOVE.w	d6,v_blocked(a3,d1.w)	* save blocked flag
	BEQ.s		no_collision		* branch if no collision

* the player collided with something so the temporary (x,y), which was copied from the
* player (x,y) before the move, should be copied back to the player (x,y)

	MOVE.w	t_xcoord(a3),v_xcoord(a3,d1.w)
							* copy temp to vehicle x co-ordinate
	MOVE.w	t_ycoord(a3),v_ycoord(a3,d1.w)
							* copy temp to vehicle y co-ordinate

* just making the player object stop is not very realistic so make the vehicle appear
* to bounce by offsetting the display but only if it's a new collision

	TST.w		vert_offs(a3)		* test vertical offset
	BNE.s		collision_done		* don't set it if bouncing already

	MOVE.w	#$00FF,vert_offs(a3)	* set the vertical offset

* add a noise to emphasise the impact. again this is only to be triggered if it's a
* new collision and we're playing a game

	MOVEQ		#s_crash,d0			* index to crash sound
	BSR		add_sound			* add the sound to the queue

* there's been a collision and we may still be bouncing from the last collision so
* increment the screen desplacement so the bounce will be extended for one more go
* round. this means the player has to release the controls for the collision to end

collision_done
	ADD.w		#1,vert_offs(a3)		* ensure vertical offset won't reach zero
							* until the collision is over
no_collision
	RTS


*************************************************************************************
*
* code/branch table for vehicle motion. some entries have been changed so that a
* double key press for one track is ignored instead of halting the vehicle

							* edik   motion
movetable						* ----   ------
	RTS						* 0000 - stationary
	BRA.s		right_reverse		* 0001 - reverse right
	BRA.s		right_forward		* 0010 - forward right
	RTS						* 0011 - illegal
	BRA.s		left_reverse		* 0100 - reverse left
	BRA.s		reverse			* 0101 - reverse
	BRA.s		left_spin			* 0110 - spin left
	BRA.s		left_reverse		* 0111 - reverse left, was illegal
	BRA.s		left_forward		* 1000 - forward left
	BRA.s		right_spin			* 1001 - spin right
	BRA.s		forward			* 1010 - forward
	BRA.s		left_forward		* 1011 - forward left, was illegal
	RTS						* 1100 - illegal
	BRA.s		right_reverse		* 1101 - reverse right, was illegal
	BRA.s		right_forward		* 1110 - forward right, was illegal
	RTS						* 1111 - illegal


*------------------------------------------------------------------------------------
*
* spin the vehicle to the right, no movement

right_spin
	SUBQ.w	#2,v_orient(a3,d1.w)	* subtract 1 degree from vehicle orientation
	RTS


*------------------------------------------------------------------------------------
*
* spin the vehicle to the left, no movement

left_spin
	ADDQ.w	#2,v_orient(a3,d1.w)	* add 1 degree to vehicle orientation
	RTS


*------------------------------------------------------------------------------------
*
* track right while backing up

right_reverse
	SUBQ.w	#1,v_orient(a3,d1.w)	* subtract 1/2 degree from vehicle orientation
	BRA.s		sub_half			* subtract 3/4 unit from vehicle position &
							* return

*------------------------------------------------------------------------------------
*
* track left while moving forward

right_forward
	ADDQ.w	#1,v_orient(a3,d1.w)	* add 1/2 degree to vehicle orientation
	BRA.s		add_half			* add 3/4 unit to vehicle position & return


*------------------------------------------------------------------------------------
*
* track left while backing up

left_reverse
	ADDQ.w	#1,v_orient(a3,d1.w)	* add 1/2 degree to vehicle orientation
	BRA.s		sub_half			* subtract 3/4 unit from vehicle position &
							* return

*------------------------------------------------------------------------------------
*
* track right while moving forward

left_forward
	SUBQ.w	#1,v_orient(a3,d1.w)	* subtract 1/2 degree from vehicle orientation
	BRA.s		add_half			* add 3/4 unit to vehicle position & return


*------------------------------------------------------------------------------------
*
* back up quickly

reverse
	BSR.s		sub_half			* subtract 3/4 unit from vehicle position
	BRA.s		sub_again			* subtract 3/4 unit from vehicle position


*------------------------------------------------------------------------------------
*
* move forward quickly

forward
	BSR.s		add_half			* add 3/4 unit to vehicle position
	BRA.s		add_again			* add 3/4 unit to vehicle position


*------------------------------------------------------------------------------------
*
* move the vehicle forward, takes into account the vehicle's orientation
* vehicle x = vehicle x + cos(p) * scale, vehicle y = vehicle y - sin(p) * scale

add_half
	BSR		sincos			* get scaled sin(v_orient) in d2,
							* cos(v_orient) in d3
add_again
	ADD.w		d3,v_xcoord(a3,d1.w)	* add COS(dir) to x co-ordinate
	SUB.w		d2,v_ycoord(a3,d1.w)	* subtract SIN(dir) from y co-ordinate
	RTS


*------------------------------------------------------------------------------------
*
* move the vehicle backward, takes into account the vehicle's orientation
* vehicle x = vehicle x - cos(p) * scale, vehicle y = vehicle y + sin(p) * scale

sub_half
	BSR		sincos			* get scaled sin(v_orient) in d2,
							* cos(v_orient) in d3
sub_again
	SUB.w		d3,v_xcoord(a3,d1.w)	* subtract COS(dir) from x co-ordinate
	ADD.w		d2,v_ycoord(a3,d1.w)	* add SIN(dir) to y co-ordinate
	RTS


*************************************************************************************
*
* spawn a new enemy. pick a random direction and find a spot 3/4 or 3/8 of the width
* of the world away from the player

new_enemy
	MOVE.w	#v_o_start+v_o_size,d1	* index to enemy object
	MOVEQ		#0,d0				* clear longword
	MOVE.w	d0,e_warning(a3)		* clear enemy warning sounded flag
	MOVE.w	d0,v_expsn(a3,d1.w)	* clear enemy vehicle explosion flag

	MOVE.w	#obj_tank,d2		* default to tank object

	TST.w		game_mode(a3)		* test the game mode
	BEQ.s		new_game_e			* if playing game go select game enemy

							* else the game is not playing so set the super
							* tank one eighth of the time

	BSR		gen_prng			* call the PRNG code
	MOVEQ		#7,d0				* set mask for 1 of 8
	AND.w		PRNlword(a3),d0		* mask random value
	BNE.s		new_tank			* set tank object

	BRA.s		new_stank			* else set new super tank
	
new_game_e
	CMP.w		#$5,p_score(a3)		* compare 5000 with player score
	BCS.s		new_tank			* if < 5000 go set tank

new_stank
	MOVE.w	#obj_stnk,d2		* else set super tank object
new_tank
	MOVE.w	d2,v_o_type(a3,d1.w)	* set enemy object number
	MOVE.b	#obj_rdar,er_obj(a3)	* initialise enemy radar object

	MOVE.w	PRNlword+2(a3),d0		* get random word
	MOVE.w	d0,v_orient(a3,d1.w)	* save enemy orientation

	MOVE.b	#1,v_mot_time(a3,d1.w)	* set enemy motion timeout byte
	MOVEQ		#$0F,d0			* set min angle mask
	TST.w		game_mode(a3)		* test the game mode
	BNE.s		new_e_mask			* branch if not playing game

* the higher the player's score and the less times the player has been killed the
* further from line of sight the enemy can appear

	MOVEQ		#$3F,d0			* set max angle mask
	MOVE.w	p_score(a3),d2		* get player score
	CMP.w		#$100,d2			* compare player score with 100,000
	BCC.s		new_e_mask			* if score >= 100,000 go spawn a new enemy at
							* an angle within the mask set by d0

	MOVEQ		#$0F,d0			* set min angle mask
	SUB.w		#3,d2				* - original lives count from score
	ADD.w		p_lives(a3),d2		* effectively subtract from player lives
	BMI.s		new_e_mask			* if lost more than scored go spawn a new enemy
							* at an angle within the mask set by d0

	ASR.w		#1,d2				* angle per 2,000 scored
	BEQ.s		new_e_mask			* if scored 1,000 > lost go spawn...

	MOVEQ		#$1F,d0			* set angle mask
	SUBQ.w	#1,d2				* angle per 2,000 scored
	BEQ.s		new_e_mask			* if scored 3,000 > lost go spawn...

	MOVEQ		#$2F,d0			* else set angle mask

* pick a new enemy at an angle within the mask set by d0

new_e_mask
	MOVE.w	d0,p_temp(a3)		* save angle mask
new_e_loop
	BSR		gen_prng			* call the PRNG code
	AND.w		PRNlword(a3),d0		* mask random angle
	BTST.b	#0,PRNlword+2(a3)		* test random 0/1
	BNE.s		new_e_left			* half the time the enemy comes from the left

	NEG.w		d0				* else toggle byte, and half the time the enemy
							* comes from the right
new_e_left
	ADD.w		v_o_start+v_orient(a3),d0
							* add player object orientation
	MOVE.w	d0,d5				* save new angle
	BSR		cos_d0			* get COS(d0) in d0
	MOVE.w	d0,d3				* copy it
	ASR.w		#2,d0				* / 4
	SUB.w		d0,d3				* make 3/4 cos

	MOVE.w	d5,d0				* get new angle back
	BSR		sin_d0			* get SIN(d0) in d0
	MOVE.w	d0,d2				* copy it
	ASR.w		#2,d0				* / 4
	SUB.w		d0,d2				* make 3/4 sin

	CMP.b		#obj_miss,v_o_type(a3,d1.w)
							* compare enemy object number with missile
	BEQ.s		new_e_far			* branch if missile

	BTST.b	#1,PRNlword+2(a3)		* test another random 0/1
	BNE.s		new_e_far			* half the time the enemy comes from far away

							* half the time the enemy is closer
	MOVEQ		#1,d0				* set shift count
	ASR.w		d0,d2				* make 3/8 sin
	ASR.w		d0,d3				* make 3/8 cos
new_e_far
	ADD.w		v_o_start+v_xcoord(a3),d3
							* add player x co-ordinate to cos
	ADD.w		v_o_start+v_ycoord(a3),d2
							* add player y co-ordinate to sin
	MOVE.w	d3,v_xcoord(a3,d1.w)	* save new enemy x co-ordinate
	MOVE.w	d2,v_ycoord(a3,d1.w)	* save new enemy y co-ordinate

	MOVE.w	p_temp(a3),d0		* restore angle mask
	BSR		chk_w_colsn			* check for collision with world objects
							* enter with index to vehicle in d1.w
	TST.l		d6				* test blocked flag
	BNE		new_e_loop			* if collision go try again

*##	CMP.b		#obj_miss,v_o_type(a3,d1.w)
*##							* compare enemy object number with missile
*##	BNE.s		exit_new_e			* branch if no missile

*##	BSR		player2enemy		* calculate angle from player to enemy
*##	MOVE.w	d0,e_orient(a3)		* save enemy orientation, point at player
*##exit_new_e
	MOVE.w	#$40,v_f_count(a3,d1.w)	* set vehicle fire counter
	RTS


*************************************************************************************
*
* move saucer or do saucer destruction intensity

saucer_motion
	MOVE.w	saucer_d(a3),d0		* get saucer destruction flag
	BEQ.s		saucer_no_boom		* if not saucer destruction go move saucer

							* do saucer destruction intensity animation
	LEA		saucer_not_done(pc),a1	* get pointer to table
	MOVE.w	(a1,d0.w),d0		* get saucer intensity modifier
	MOVE.w	d0,saucer_i(a3)		* save saucer destruction intensity
	SUBQ.w	#2,saucer_d(a3)		* decrement saucer destruction flag
	BNE.s		saucer_not_done		* if destruction not all done just exit

							* else set new saucer x,y co-ordinates and
							* wait a random length of time
	BSR		gen_prng			* call the PRNG code
	MOVE.l	PRNlword(a3),d0		* get random words
	MOVE.w	d0,saucer_x(a3)		* save new saucer x co-ordinate
	SWAP		d0				* get high word
	MOVE.w	d0,saucer_y(a3)		* save new saucer y co-ordinate
	BSR		gen_prng			* call the PRNG code again
	MOVEQ		#60,d0			* clear high word, set minimum 'dead' time
	OR.b		PRNlword(a3),d0		* OR in a random byte
	MOVE.l	d0,saucer_f(a3)		* clear the saucer flag and save the saucer
							* direction life
saucer_not_done
	RTS

* saucer destruction intensity table. does a bright flash then fades away

	dc.w	$C0,$B0,$B0,$A0,$A0,$90,$90,$80
	dc.w	$80,$70,$70,$60,$60,$50,$50,$40
	dc.w	$40,$30,$30,$20,$20,$10,$10,$00
	dc.w	$10,$10,$20,$20,$30,$30,$40,$40

* not saucer destruction so, if the saucer exists, just move it

saucer_no_boom
	ADDQ.w	#7,saucer_o(a3)		* increment saucer orientation
	TST.w		saucer_f(a3)		* test the saucer flag
	BNE.s		saucer_nospawn		* if saucer skip spawn new

* possibly spawn new saucer. new saucers are only spawned once the player score has
* reached 2000 and the saucer direction life has expired. this means there will be a
* random delay between one saucer deing destroyed and the next saucer appearing

	TST.w		saucer_l(a3)		* test the saucer direction life
	BNE.s		saucer_move			* if not timed out just move the saucer

	CMP.w		#$2,p_score(a3)		* compare 2000 with player score
	BCS.s		no_saucer			* if < 2000 skip spawn new saucer

	MOVEQ		#1,d0				* set saucer present
	MOVE.w	d0,saucer_f(a3)		* save saucer present flag

	MOVEQ		#s_saucer,d0		* index to saucer appear sound
	BSR		add_sound			* add the sound to the queue

saucer_nospawn
	TST.w		saucer_l(a3)		* test the saucer direction life
	BNE.s		saucer_move			* if not timed out skip get new direction

							* timed out so make a new direction
no_saucer
	BSR		gen_prng			* call the PRNG code
	MOVE.l	PRNlword(a3),d0		* get random bytes
	EXT.w		d0				* make word
	MOVE.w	d0,saucer_dx(a3)		* save new saucer delta x
	SWAP		d0				* get high word byte
	EXT.w		d0				* make word
	MOVE.w	d0,saucer_dy(a3)		* save new saucer delta y
	MOVEQ		#4,d0				* set minimum direction life
	OR.b		PRNlword(a3),d0		* get random byte
	LSR.b		#1,d0				* / 2
	MOVE.w	d0,saucer_l(a3)		* save saucer direction life
saucer_move
	MOVE.w	saucer_dx(a3),d0		* get saucer delta x
	ADD.w		d0,saucer_x(a3)		* add saucer delta x to saucer x co-ordinate
	MOVE.w	saucer_dy(a3),d0		* get saucer delta y
	ADD.w		d0,saucer_y(a3)		* add saucer delta y to saucer y co-ordinate
	SUBQ.w	#1,saucer_l(a3)		* decrement saucer direction life
	RTS


*************************************************************************************
*
* move the weapons fire objects. loop through each object for each object, while it
* is in flight, loop through the delta move four times and on each loop check for
* collisions with all the world objects, the vehicle objects and any extras
*
* the reason the weapons fire objects are moved through four small deltas for each
* frame is that doing the movement all in one go would leave gaps larger than the
* contact diameter between each instance of the object. this would mean that the
* objects could effectively pass through something that was on their line of flight
* but fell in a gap. doing the four small deltas means that the contact areas overlap
* so nothing is missed

f_movement
	MOVE.w	#f_o_last,d1		* index to last weapons fire object
f_move_loop
	MOVE.w	#3,p_temp(a3)		* save delta loop count
f_delta_loop
	TST.w		f_count(a3,d1.w)		* test fire object counter
	BEQ		end_f_move			* exit if fire object not in flight

	SUBQ.w	#1,f_count(a3,d1.w)	* else decrement fire object counter
	MOVE.w	f_delta_x(a3,d1.w),d0	* get fire object delta x
	ADD.w		d0,f_xcoord(a3,d1.w)	* add to fire object x co-ordinate
	MOVE.w	f_delta_y(a3,d1.w),d0	* get fire object delta y
	ADD.w		d0,f_ycoord(a3,d1.w)	* add to fire object y co-ordinate

* now test for collisions, first with the vehicles

	MOVE.w	f_xcoord(a3,d1.w),d2	* get fire object x co-ordinate
	MOVE.w	f_ycoord(a3,d1.w),d3	* get fire object y co-ordinate

	MOVE.w	#v_o_last,d0		* index to last vehicle
f2v_col_loop
	TST.w		v_o_type(a3,d0.w)		* get vehicle object type flag
	BMI.s		f2v_next			* if no object go do next

	TST.w		v_expsn(a3,d0.w)		* get vehicle explosion flag
	BNE.s		f2v_next			* if vehicle exploding go do next

	MOVE.w	f_xcoord(a3,d0.w),d4	* get vehicle x co-ordinate
	MOVE.w	f_ycoord(a3,d0.w),d5	* get vehicle y co-ordinate

	SUB.w		d2,d4				* calculate delta x from fire object
	SUB.w		d3,d5				* calculate delta y from fire object

	MULS.w	d4,d4				* x^2
	MULS.w	d5,d5				* y^2
	ADD.l		d5,d4				* now = x^2 + y^2

	CMP.l		#$10000,d4			* compare with collision distance, $100^2
	BCC.s		f2v_next			* if not closer than minimum limit do next

	MOVE.w	d1,-(sp)			* else save fire object index
	PEA		f_move_next(pc)		* set return address
	BRA		v_go_boom			* go kill vehicle

f2v_next
	SUB.w		#v_o_size,d0		* decrement vehicle index
	CMP.w		#v_o_start,d0		* compare with first
	BPL.s		f2v_col_loop		* loop for next fire object

* now test for collisions with the saucer

	TST.w		saucer_f(a3)		* test the saucer flag
	BEQ.s		f_colsn_world		* if no saucer go do world list

	TST.w		saucer_d(a3)		* test the saucer destruction flag
	BNE.s		f_colsn_world		* if saucer destruction go do world list

	MOVE.w	saucer_x(a3),d4		* get saucer x co-ordinate
	MOVE.w	saucer_y(a3),d5		* get saucer y co-ordinate

	SUB.w		d2,d4				* calculate delta x from fire object
	SUB.w		d3,d5				* calculate delta y from fire object

	MULS.w	d4,d4				* x^2
	MULS.w	d5,d5				* y^2
	ADD.l		d5,d4				* now = x^2 + y^2

	CMP.l		#$10000,d4			* compare with collision distance, $100^2
	BCC.s		f_colsn_world		* if not closer than minimum limit go do world

	MOVE.w	d1,-(sp)			* else save fire object index
	PEA		f_move_next(pc)		* set return address
	BRA		s_go_boom			* go kill saucer

* now test for collisions with the world objects

f_colsn_world
	MOVEQ		#-2,d7			* set world object index for pre increment
f_colsn_loop
	ADDQ.w	#2,d7				* increment world object index to next object
	TST.w		(a6,d7.w)			* test for end of the world object list
	BMI.s		end_f_colsn			* if all done exit the loop with the collision
							* flag clear

	MOVE.w	f_xcoord(a3,d1.w),d4	* get fire object x co-ordinate
	MOVE.w	f_ycoord(a3,d1.w),d5	* get fire object y co-ordinate

	SUB.w		obj_x(a6,d7.w),d4		* calculate delta x from fire object
	SUB.w		obj_y(a6,d7.w),d5		* calculate delta y from fire object

	MULS.w	d4,d4				* x^2
	MULS.w	d5,d5				* y^2
	ADD.l		d5,d4				* now = x^2 + y^2

	ASR.l		#1,d4				* / 2. the largest effective contact radius is
							* $1FFE4 so doing this / 2 shifts that to $FFF2
							* and that fits in one word. so a table of
							* sizes can be a word instead of a longword
							* table
	SWAP		d4				* swap high word to low word
	TST.w		d4				* test what was the high word
	BNE.s		f_colsn_loop		* loop if further away than minimum limit

	SWAP		d4				* swap low word back
	CMP.w		obj_s(a6,d7.w),d4		* compare with object size
	BCC.s		f_colsn_loop		* loop if further away than object size

							* else there's a collision with a world object
	MOVE.w	d1,-(sp)			* save fire object index
	MOVEQ		#s_hit,d0			* index to world object hit by fire sound
	BSR		add_sound			* add the sound to the queue

f_move_next
	MOVE.w	(sp)+,d1			* restore fire object index
	MOVE.w	#0,f_count(a3,d1.w)	* clear fire object counter

end_f_colsn
	SUBQ.w	#1,p_temp(a3)		* decrement loop count
	BPL		f_delta_loop		* loop if remaining delta

end_f_move
	SUB.w		#f_o_size,d1		* decrement fire object index
	CMP.w		#f_o_start,d1		* compare index with first object
	BPL		f_move_loop			* loop for next fire object

	RTS


*************************************************************************************
*
* gather flying logo and handle animation

* set game over mode

end_logo
	MOVE.w	#600,game_count(a3)	* set 60 second timeout
	MOVE.w	#g_over,game_mode(a3)	* set game over mode
	RTS

gather_logo
	MOVE.w	logo_x(a3),d7		* get flying logo x co-ordinate
	CMP.w		#$7F00,d7			* compare flying logo x co-ordinate with $7F00
	BCC.s		end_logo			* if >= $7F00 go end logo

* insert "EASY" & "ZONE" logo objects into the object list. the logo is always inserted
* as if the player orientation is $000 so it always appears to be flying directly away
* from view no matter which way the player is oriented

	MOVEM.w	d2-d3,-(sp)			* save player orientation SIN/COS
	MOVE.w	eye_orent(a3),d0		* get orientation offset for 3D effect
	BSR		cos_d0			* get COS(d0) in d0
	MOVE.w	d0,d2				* copy cos(offset)

	MOVE.w	eye_orent(a3),d0		* get orientation offset for 3D effect
	BSR		sin_d0			* get SIN(d0) in d0
	MOVE.w	d0,d3				* copy sin(offset)

	MOVE.w	eye_osetx(a3),d4		* get eye x offset
	ADD.w		logo_x(a3),d4		* add logo x co-ordinate
	MOVE.w	eye_osety(a3),d5		* get eye y offset

	MOVE.w	d4,d0				* copy eye x offset
	MOVE.w	d5,d1				* copy eye y offset

							* x' = x * cos(p) - y * sin(p)
	MULS.w	d2,d0				* cos * x offset
	MULS.w	d3,d1				* sin * y offset
	SUB.l		d1,d0				* = x * cos - y * sin
	SWAP		d0				* only need x high word
	ADD.w		d0,d0				* scale translated x offset

							* y' = x * sin(p) + y * cos(p)
	MULS.w	d3,d4				* sin * x offset
	MULS.w	d2,d5				* cos * y offset
	ADD.l		d4,d5				* = x * sin + y * cos
	SWAP		d5				* only need y high word
	ADD.w		d5,d5				* scale translated y offset

	MOVE.w	d0,d4				* copy translated x offset
	MOVEM.w	(sp)+,d2-d3			* restore player orientation SIN/COS

	MOVE.w	v_o_start+v_orient(a3),d0
							* get player orientation
	LSR.w		#1,d0				* make 8 bit for display
	AND.w		#$FF,d0			* clear top byte of word

	CMP.w		#$0200,d7			* compare flying logo x co-ordinate with $0200
	BCS.s		no_zone			* if < $0200 don't add "ZONE" to the list

	OR.w		#obj_zone<<8,d0		* OR in "ZONE" number
	MOVE.w	d0,(a5,d6.w)		* save object number and orientation

	MOVE.w	d4,list_obj_x(a5,d6.w)	* save object translated x co-ordinate
	MOVE.w	d5,list_obj_y(a5,d6.w)	* save object translated y co-ordinate
	ADDQ		#2,d6				* increment write index to next list object

	AND.w		#$FF,d0			* clear top byte of word
no_zone
	OR.w		#obj_easy<<8,d0		* OR in "EASY" number
	MOVE.w	d0,(a5,d6.w)		* save object number and orientation

	MOVE.w	d4,list_obj_x(a5,d6.w)	* save object translated x co-ordinate
	MOVE.w	d5,list_obj_y(a5,d6.w)	* save object translated y co-ordinate
	ADDQ		#2,d6				* increment write index to next list object

	ADD.w		#$68,logo_x(a3)		* increment flying logo x co-ordinate
	ADD.w		#$14,m_alt(a3)		* increment flying logo altitude

	RTS


*************************************************************************************
*
* gather the saucer

gather_saucer
	TST.w		saucer_f(a3)		* test saucer flag
	BEQ.s		saucer_exit			* if no saucer just exit

	MOVE.w	saucer_o(a3),d0		* get saucer orientation
	LSR.w		#1,d0				* make 8 bit for display
	MOVE.w	d0,-(sp)			* put on stack
	MOVE.b	#obj_sacr,(sp)		* save saucer type, high byte only
	MOVE.w	(sp)+,(a5,d6.w)		* save saucer type and orientation
	MOVE.w	saucer_x(a3),d4		* get saucer x co-ordinate
	MOVE.w	saucer_y(a3),d5		* get saucer y co-ordinate
	BRA		test_object			* go test the object and add to list if visible

saucer_exit
	RTS


*************************************************************************************
*
* gather any enemy parts. either the enemy vehicle or the explosion parts if the
* enemy vehicle is exploding

gather_enemy
	MOVE.w	#v_o_start+v_o_size,d1	* index to enemy object
	TST.w		v_expsn(a3,d1.w)		* test explosion flag
	BNE.s		gather_expsn		* if exploding go gather explosion parts

							* else gather enemy
	TST.w		v_o_type(a3,d1.w)		* test enemy object type
	BMI.s		g_nme_exit			* exit if no enemy

	MOVE.w	v_orient(a3,d1.w),d0	* get enemy vehicle orientation
	LSR.w		#1,d0				* make 8 bit for display
	MOVE.w	d0,-(sp)			* put on stack
	MOVE.b	v_o_type+1(a3,d1.w),(sp)
							* save enemy vehicle type, high byte only
	MOVE.w	(sp)+,(a5,d6.w)		* save enemy number and orientation
	MOVE.w	v_xcoord(a3,d1.w),d4	* get enemy x co-ordinate
	MOVE.w	v_ycoord(a3,d1.w),d5	* get enemy y co-ordinate
	BRA		test_object			* go test the object and add to list if visible

gather_expsn
	MOVEQ		#$0A,d1			* set index to last explosion object
	LEA		ex_object(a3),a1		* set pointer to explosion object list
g_expn_loop
	MOVE.w	ex_z(a1,d1.w),d0		* get explosion part z co-ordinate
	BMI.s		g_next_expsn		* if object below the horizon go do next

	MOVE.w	v_o_start+v_o_size+v_o_type(a3),d0
							* get enemy vehicle object number
	ADD.b		#obj_expn-obj_tank,d0	* add offset from enemy object to explosion
							* part

	ADD.b		d1,d0				* add explosion object index
	MOVE.b	d0,(a5,d6.w)		* save explosion object number
	MOVE.b	ex_o(a1,d1.w),1(a5,d6.w)
							* save explosion object orientation

	MOVE.w	ex_x(a1,d1.w),d4		* get explosion object x co-ordinate
	MOVE.w	ex_y(a1,d1.w),d5		* get explosion object y co-ordinate
	BSR		test_object			* go test the object and add to list if visible

g_next_expsn
	SUBQ.w	#2,d1				* decrement index to previous object
	BPL		g_expn_loop			* loop if more to do

g_nme_exit
	RTS


*************************************************************************************
*
* initialise vehicle object explosion animation and sound

v_go_boom
	MOVE.w	d0,d1				* copy vehicle object index
	CMP.w		#v_o_start,d1		* is it the player vehicle object
	BEQ.s		p_go_boom			* if so go kill player

	CMP.w		#v_o_start+v_o_size,d1	* is it the enemy vehicle object
	BEQ		e_go_boom			* if so go kill enemy

	RTS


*************************************************************************************
*
* initialise saucer object explosion animation and sound

s_go_boom
	MOVE.w	#$40,saucer_d(a3)		* set saucer destruction flag
	MOVEQ		#s_recuas,d0		* index to saucer hit sound
	BSR		add_sound			* add the sound to the queue

	MOVEQ		#3,d0				* 3,000 for the saucer
	CMP.w		v_o_start+v_f_obj(a3),d1
							* is it the player who killed the saucer
	BEQ		add_player			* if so add value to player score and return

	RTS


*************************************************************************************
*
* initialise player explosion animation and sound

p_go_boom
	MOVE.w	queue_write(a3),queue_read(a3)
							* copy the sound queue write index to the sound
							* queue read index, kill the sound queue

	MOVEQ		#s_pxpsn,d0			* index to enemy explosion sound
	BSR		add_sound			* add the sound to the queue

	MOVE.w	#$03FF,vert_offs(a3)	* set the vertical offset, bounce the player
	MOVE.w	#s_crack_e,v_o_start+v_expsn(a3)
							* set player object explosion flag
	RTS


*************************************************************************************
*
* animate player explosion. the player explosion flag is used as the index and starts
* just past the end and works back to the beginning. when it gets to zero all the
* stages are done so the routine quits

p_boom
	MOVE.w	#v_o_start,d1		* index to player object
	MOVE.w	v_expsn(a3,d1.w),d0	* get player explosion flag
	BEQ.s		boom_exit			* if not exploding just exit

	SUBQ.w	#2,d0				* decrement player explosion flag
	MOVE.w	d0,v_expsn(a3,d1.w)	* save player explosion flag
	BEQ.s		p_boom_done			* if all done go do new player/game over

	LEA		s_crack(pc),a4		* get pointer to top of crack routine
	LEA		(a4,d0.w),a4		* get pointer to wanted start point
	BRA		do_vector			* go draw the crack

p_boom_done
	TST.w		p_lives(a3)			* test player lives count
	BEQ.s		new_player			* if already zero skip decrement

	SUBQ.w	#1,p_lives(a3)		* else decrement the player lives count

* now clear the enemy object and spawn a new player

new_player
	BSR		gen_prng			* call the PRNG code

	MOVE.w	PRNlword(a3),d0		* get word from result
	MOVE.w	d0,v_xcoord(a3,d1.w)	* save new player x co-ordinate

	MOVE.w	PRNlword+2(a3),d0		* get word from result
	MOVE.w	d0,v_ycoord(a3,d1.w)	* save new player y co-ordinate

	BSR		chk_v_colsn			* check for collisions with the environment
							* and other vehicles
	TST.w		d6				* test blocked flag
	BNE.s		new_player			* if collision go try again

	BSR		gen_prng			* call the PRNG code
	MOVE.w	PRNlword(a3),v_orient(a3,d1.w)
							* save word as new player orientation
	MOVEQ		#0,d0				* clear longword
	MOVE.w	d0,v_o_type(a3,d1.w)	* set the player vehicle object type
	MOVE.w	d0,v_motion(a3,d1.w)	* clear new player motion
	MOVE.w	d0,v_mot_time(a3,d1.w)	* clear new player motion time
boom_exit
	RTS


*************************************************************************************
*
* initialise enemy explosion parts. start all the parts where the enemy vehicle was
* and set them up to explode outwards. random velocities/trajectories are not used
* as they often don't look random or impressive

e_go_boom
	MOVEQ		#s_expsn,d0			* index to enemy explosion sound
	BSR		add_sound			* add the sound to the queue

	MOVEQ		#$0A,d2			* set index to last explosion object
	LEA		ex_table(pc),a0		* set pointer to explosion object table
	LEA		ex_object(a3),a1		* set pointer to explosion object list

e_go_loop
	MOVE.w	v_xcoord(a3,d1.w),ex_x(a1,d2.w)
							* save enemy x co-ordinate as explosion part
							* x co-ordinate
	MOVE.w	v_ycoord(a3,d1.w),ex_y(a1,d2.w)
							* save enemy y co-ordinate as explosion part
							* y co-ordinate
	MOVE.w	#0,ex_z(a1,d2.w)		* clear explosion part z co-ordinate

	MOVE.w	et_dx(a0,d2.w),ex_dx(a1,d2.w)
							* save table delta x as explosion part delta x
	MOVE.w	et_dy(a0,d2.w),ex_dy(a1,d2.w)
							* save table delta y as explosion part delta y
	MOVE.w	et_dz(a0,d2.w),ex_dz(a1,d2.w)
							* save table delta z as explosion part delta z

	BSR		gen_prng			* call the PRNG code
	MOVE.b	PRNlword(a3),ex_o(a1,d2.w)
							* save byte as explosion part orientation

	SUBQ.w	#2,d2				* decrement index to previous object
	BPL		e_go_loop			* loop if more to do

	MOVE.w	#-1,v_expsn(a3,d1.w)	* set enemy explosion flag
	RTS


*************************************************************************************
*
* gather fire objects. setup for fire objects and add to the object list

gather_fos
	MOVE.w	#f_o_last,d1		* index to last weapons fire object
g_fos_loop
	TST.w		f_count(a3,d1.w)		* test fire object counter
	BEQ.s		end_g_fos			* exit if not in flight

	MOVE.w	f_orient(a3,d1.w),d0	* get fire object orientation
	LSR.w		#1,d0				* make 8 bit for display
	MOVE.w	d0,-(sp)			* put on stack
	MOVE.b	f_o_type+1(a3,d1.w),(sp)
							* save in fire object type, high byte only
	MOVE.w	(sp)+,(a5,d6.w)		* save fire object number and orientation
	MOVE.w	f_xcoord(a3,d1.w),d4	* get fire object x co-ordinate
	MOVE.w	f_ycoord(a3,d1.w),d5	* get fire object y co-ordinate
	BSR		test_object			* go test the object and add to list if visible
end_g_fos
	SUB.w		#f_o_size,d1		* decrement fire object index
	CMP.w		#f_o_start,d1		* compare index with first object
	BPL.s		g_fos_loop			* loop for next fire object

	RTS


*************************************************************************************
*
* see if vehicle can fire. enter with d1.w = index to vehicle object

v_fire
	TST.w		v_f_count(a3,d1.w)	* test vehicle object fire counter
	BNE.s		exit_v_fire			* exit if not timed out

	MOVE.w	v_f_obj(a3,d1.w),d3	* get vehicle fire object index
	TST.w		f_count(a3,d3.w)		* test fire object counter
	BNE.s		exit_v_fire			* exit if fire object in flight

	MOVE.w	#v_o_last,d2		* set index to last vehicle
v_fire_loop
	CMP.w		d2,d1				* compare other vehicle with this vehicle
	BEQ.s		v_fire_next			* go do next if other vehicle is this vehicle

	TST.b		v_o_type(a3,d2.w)		* test enemy object type
	BMI.s		v_fire_next			* if no object go do next vehicle

	TST.w		v_expsn(a3,d2.w)		* test other vehicle exploding flag
	BNE.s		v_fire_next			* go do next if other vehicle exploding

	BSR		player2enemy		* calculate angle to other vehicle
	SUB.w		v_orient(a3,d1.w),d0	* subtract vehicle orientation
	AND.w		#$1FF,d0			* keep in range $000 to $1FF
	ADD.w		#$FF00,d0			* set top bits clear if -ve, set if +ve
	EOR.w		#$FF00,d0			* toggle bits to correct state
	BPL.s		v_targ_right		* branch if other vehicle to right

	NEG.w		d0				* else make +ve
v_targ_right
	CMP.w		#$02,d0			* compare with $02
	BCS.s		spawn_f			* if < $02 from centre go fire

v_fire_next
	SUB.w		#v_o_size,d2		* decrement other vehicle index
	CMP.w		#v_o_start,d2		* compare with first
	BPL.s		v_fire_loop			* loop if more to do

exit_v_fire
	RTS


*------------------------------------------------------------------------------------
*
* spawn fire object. generate a new fire object if a combatant has fired. will not
* spawn if there is already a fire object in flight. enter with d1.w = index to
* vehicle

spawn_fire
	MOVE.w	v_f_obj(a3,d1.w),d3	* get vehicle fire object index
	TST.w		f_count(a3,d3.w)		* test fire object counter
	BNE.s		exit_f_spawn		* exit if fire object in flight

spawn_f
	MOVE.w	#$007F,f_count(a3,d3.w)	* else set fire object range counter
	MOVE.w	#obj_shel,f_o_type(a3,d3.w)
							* set fire object type

	MOVE.w	v_orient(a3,d1.w),d0	* get vehicle orientation
	MOVE.w	d0,f_orient(a3,d3.w)	* save fire object orientation
	BSR		sin_d0			* get SIN(d0) in d0
	ASR.w		#7,d0				* * 2 and move to low byte
	NEG.w		d0				* - SIN(dir)
	MOVE.w	d0,f_delta_y(a3,d3.w)	* save -SIN(dir) as delta y
	MOVE.w	v_ycoord(a3,d1.w),f_ycoord(a3,d3.w)
							* copy object y co-ordinate to fire object
	ADD.w		d0,f_ycoord(a3,d3.w)	* add -SIN(dir) to y co-ordinate

	MOVE.w	v_orient(a3,d1.w),d0	* get vehicle orientation
	BSR		cos_d0			* get COS(d0) in d0
	ASR.w		#7,d0				* * 2 and move to low byte
	MOVE.w	d0,f_delta_x(a3,d3.w)	* save +COS(dir) as delta x
	MOVE.w	v_xcoord(a3,d1.w),f_xcoord(a3,d3.w)
							* copy object x co-ordinate to fire object
	ADD.w		d0,f_xcoord(a3,d3.w)	* add +COS(dir) to x co-ordinate

	MOVEQ		#s_pshot,d0			* set player shot noise
	CMP.w		#v_o_start,d1		* is it the player
	BEQ		add_sound			* if so add the player fire sound to the queue
							* and return

	MOVEQ		#s_eshot,d0			* else set enemy shot noise
	BRA		add_sound			* add the vehicle fire sound to the queue
							* and return

exit_f_spawn
	RTS


*************************************************************************************
*
* see if the player can fire

p_fire
	MOVE.l	#$20,d1			* [SPACE] key
	MOVEQ		#19,d0			* check for keypress
	TRAP		#15

	MOVE.w	d1,d0				* copy [SPACE] key result
	MOVE.w	#v_o_start,d1		* restore index to player object
	MOVE.w	lastSPACE(a3),d2		* get last [SPACE] key result
	MOVE.w	d0,lastSPACE(a3)		* save this result as last
	EOR.w		d0,d2				* compare this with last
	AND.w		d0,d2				* mask for just pressed
	BNE.s		spawn_fire			* if so go create player fire object

	RTS

*************************************************************************************
*
* calculate the bearing between vehicle object 0 and vehicle object 1 from the
* viewpoint of vehicle object d1.w

bear_v0_v1
	MOVE.w	#v_o_start,d2		* other index to player
	CMP.w		d2,d1				* compare with this vehicle object
	BNE.s		player2enemy		* calculate the angle between objects

	MOVE.w	#v_o_start+v_o_size,d2	* else other index to enemy


*------------------------------------------------------------------------------------
*
* calculate the bearing between vehicle d1.w and vehicle d2.w.

player2enemy
	MOVE.w	v_xcoord(a3,d1.w),d4	* get vehicle d1 x co-ordinate
	MOVE.w	v_ycoord(a3,d1.w),d5	* get vehicle d1 y co-ordinate

	SUB.w		v_xcoord(a3,d2.w),d4	* calculate delta x from vehicle d2 
	SUB.w		v_ycoord(a3,d2.w),d5	* calculate delta y from vehicle d2 

	MOVE.w	d4,e_temp_x(a3)		* save delta x
	MOVE.w	d5,e_temp_y(a3)		* save delta y


*------------------------------------------------------------------------------------
*
* calculate angle given the delta x,y, enter with delta x in d4 and delta y in d5

delta_2_bear
	MOVE.l	d1,-(sp)			* save object index
	MOVEQ		#$00,d1			* clear delta x and delta y -ve flag
	TST.w		d4				* test delta x
	BPL.s		deltax_pl			* branch if +ve

	NEG.w		d4				* else do ABS(delta x)
	MOVEQ		#$02,d1			* flag delta x -ve
deltax_pl
	TST.w		d5				* test delta y
	BPL.s		deltay_pl			* branch if +ve

	NEG.w		d5				* else do ABS(delta y)
	ADD.w		#$04,d1			* flag delta y -ve
deltay_pl
	MOVEQ		#$40,d0			* set result to 1/8th circle line, and clear
							* high word
	CMP.w		d5,d4				* compare delta y with delta x
	BEQ.s		dy_eq_dx			* skip atn(a) if on the 1/8th circle line

	BCS.s		dy_gt_dx			* branch if delta y > delta x

							* else delta x > delta y
	PEA		dy_eq_dx(pc)		* set return to go sort result
	BRA.s		arctan			* do atn(dy/dx) subroutine

							* delta x < delta y
dy_gt_dx
	EXG		d4,d5				* swap dx and dy
	BSR.s		arctan			* do atn(dx/dy)
	NEG.b		d0				* -ve value
	ADD.b		#$80,d0			* subtract from 1/4 circle

							* here d1 gives the signs of the two deltas
							* of object (x,y) - player (x,y)
							*
							*		delta x	delta y
							*		--------	--------
							* d1 = $00	positive	positive
							* d1 = $02	negative	positive
							* d1 = $04	positive	negative
							* d1 = $06	negative	negative

							* delta x = delta y
dy_eq_dx
	LEA	quadrants(pc),a0			* get base
	JMP	(a0,d1.w)				* do vector

quadrants
	BRA.s		dxp_dyp			* $00 dx +ve, dy +ve, reflect x, add half
	BRA.s		dxn_dyp			* $02 dx -ve, dy +ve, exit
	BRA.s		dxp_dyn			* $04 dx +ve, dy -ve, add half
							* $06 dx -ve, dy -ve, reflect x
	NEG.w		d0				* reflect in x axis
dxn_dyp
	MOVE.l	(sp)+,d1			* restore object index
	RTS

dxp_dyp
	NEG.w		d0				* reflect in x axis
dxp_dyn
	EOR.w		#$0100,d0			* shift half circle
	MOVE.l	(sp)+,d1			* restore object index
	RTS


*************************************************************************************
*
* get arctan(a) from the table. we know here that d4 > d5 so the DIVU will never
* overflow

arctan
	LEA		atn_tab(pc),a0		* point to atn(a) table
	MOVE.w	d5,d0				* copy dy to low word, high word clear
	SWAP		d0				* move word to high word
	DIVU.w	d4,d0				* do dy/dx
	MOVE.w	d0,-(sp)			* save to stack
	MOVEQ		#0,d0				* clear high byte
	MOVE.b	(sp)+,d0			* return high byte as low byte
	MOVE.b	(a0,d0.w),d0		* get atn(a)
	RTS


*************************************************************************************
*
* check the [F2], [F3] and [F4] keys. set the screen size to 640 x 480, 800 x 600 or
* 1024 x 768 if the corresponding key has been pressed, then check the [3] and [P]
* keys. if [3] has just been pressed then toggle the viewmode between 3D or flat
* view. if [P] has been pressed then enter play mode

g_controls
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
	CMP.l		scr_x(a3),d1		* compare with current screen size
	BEQ.s		notscreen			* if already set skip setting it now

	MOVEQ		#33,d0			* set window size
	TRAP		#15

notscreen
	MOVE.l	#'PP33',d1			* [P]lay and 3D key
	MOVEQ		#19,d0			* check for keypress
	TRAP		#15

	MOVE.w	d1,d0				* copy [3] key result
	EOR.w		d1,last3key(a3)		* compare with last
	BEQ.s		notogglemode		* branch if not just pressed

	AND.w		d0,d1				* make sure just pressed
	ADD.b		d1,viewmode(a3)		* toggle view mode
notogglemode
	MOVE.w	d0,last3key(a3)		* save this result as last

	SWAP		d1				* get [P] key result
	MOVE.w	lastPkey(a3),d0		* get last [P] key result
	MOVE.w	d1,lastPkey(a3)		* save this result as last
	BEQ.s		notoggleplay		* if not pressed skip game start

	MOVEQ		#$0C,d0			* mask for game over/high score/logo
	AND.w		game_mode(a3),d0		* mask modes
	BEQ.s		notoggleplay		* if not game over/high score/logo mode skip
							* game start

	EOR.w		d1,d2				* compare with last
	BEQ.s		notoggleplay		* if not just pressed skip game start

	MOVE.w	queue_write(a3),queue_read(a3)
							* copy the sound queue write index to the sound
							* queue read index to kill the sound queue

	MOVEQ		#g_playing,d0		* set game mode / clear d0
	MOVE.l	d0,f_count(a3)		* clear player/enemy shells
	MOVE.w	d0,saucer_f(a3)		* clear the saucer flag
	MOVE.w	d0,game_mode(a3)		* enable play mode
	MOVE.w	d0,p_score(a3)		* clear player score
	MOVE.w	#3,p_lives(a3)		* give the player three lives
	MOVE.w	#v_o_start+v_o_size,d2	* index to enemy object
	MOVE.w	#-1,v_o_type(a3,d2.w)	* clear the enemy object number
	MOVE.w	#$0000,e_warning(a3)	* clear enemy warning sounded flag
	MOVE.w	#v_o_start,d1		* index to player object
	BRA		new_player			* spawn new player and return

notoggleplay
	RTS


*************************************************************************************
*
* setup stuff. load the sounds, set the variable space base pointer, clear the
* variable memory, set the PRNG seed or it will just produce zero, set the
* environment table base pointer, set game over mode and timeout, initialise the
* volcano stars and the high score table

Initialise
	BSR.s		init_sounds			* initialise sounds
	BSR.s		init_vars			* initialise variables
	BSR.s		init_vehicles		* initialise vehicles
	BSR		init_saucer			* initialise saucer
	BSR		Clear_stars			* clear the volcano stars
	BSR		set_hiscores		* setup the high score table
	RTS


*------------------------------------------------------------------------------------
*
* clear the variables memory

init_vars
	LEA		LAB_VARS(pc),a3		* get pointer to variables

							* clear all the variable memory
	MOVEQ		#0,d0				* clear longword
	MOVEQ		#st_intens,d1		* set start index
init_m_loop
	MOVE.w	d0,(a3,d1.w)		* clear variable memory word
	ADDQ.w	#2,d1				* increment index
	CMP.w		#vars_end,d1		* compare with end+1
	BNE.s		init_m_loop			* loop if not all clear

	MOVE.l	#$8C9F53D0,PRNlword(a3)	* set PRNG seed. this can be any value
							* except zero, changing this will produce
							* a different start point for the generator

	LEA		world_objcts(pc),a6	* pointer to world object list, used by
							* world environment routines
	MOVE.b	#obj_rdar,er_obj(a3)	* set radar object, used to render tank radar

	MOVE.w	#g_over,game_mode(a3)	* set game over mode
	MOVE.w	#600,game_count(a3)	* set 60 second timeout
	RTS


*------------------------------------------------------------------------------------
*
* read all of the sounds into the sound memory

init_sounds
	LEA		effsounds(pc),a2		* get sound table address
	MOVEQ		#71,d0			* load sound to sound memory
	MOVEQ		#0,d1				* index to start

init_sound
	MOVE.w	(a2,d1.w),d2		* get sample name offset
	BMI.s		init_s_done			* exit loop if end marker
	
	LEA		(a2,d2.w),a1		* get sample name pointer
	TRAP		#15

	ADDQ.w	#2,d1				* index to next sound
	BRA.s		init_sound			* loop for next

init_s_done	
	RTS


*------------------------------------------------------------------------------------
*
* initialise all the vehicles, set the type to none

init_vehicles
	MOVE.w	#v_o_last,d1		* index to last vehicle
	MOVE.w	#f_o_last,d2		* index to last fire object
	MOVE.w	#-1,d3			* set flag value
init_v_loop
	MOVE.w	d3,v_o_type(a3,d1.w)	* set no vehicle object type
	MOVE.w	d2,v_f_obj(a3,d1.w)	* set vehicle fire object
	MOVE.w	#-1,v_f_snd(a3,d1.w)	* set vehicle fire sound
	MOVE.w	#-1,v_e_snd(a3,d1.w)	* set vehicle explosion sound

	SUB.w		#f_o_size,d2		* decrement fire object index
	SUB.w		#v_o_size,d1		* decrement vehicle index
	CMP.w		#v_o_start,d1		* compare with first
	BPL.s		init_v_loop			* loop if more to do

	MOVE.w	#0,v_o_start+v_o_type(a3)
							* set player type to tank

	RTS


*------------------------------------------------------------------------------------
*
* initialise saucer variables

init_saucer
	MOVEQ		#0,d0				* clear longword
	MOVE.w	d0,saucer_f(a3)		* clear saucer flag
	MOVE.w	d0,saucer_d(a3)		* saucer destruction flag
	MOVE.w	d0,saucer_i(a3)		* saucer destruction intensity

	BSR		gen_prng			* call the PRNG code
	MOVEQ		#4,d0				* clear high word, set minimum direction life
	OR.b		PRNlword(a3),d0		* get random byte
	LSR.b		#1,d0				* / 2
	MOVE.w	d0,saucer_l(a3)		* save saucer direction life

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

gen_prng
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
* star update routine. this routine spawns new stars if there are extinguished stars
* and updates the position and velocity of the current stars. much use is made of the
* random number generator to spawn new stars.

Update_stars
	MOVEQ		#4*st_size,d6		* set star structure size * 4
Update_loop
	MOVE.w	st_intens(a3,d6.w),d0	* get star intensity
	BNE.s		St_visible			* branch if star visible

	BSR		gen_prng			* call the PRNG code
	MOVE.b	PRNlword(a3),d0		* get byte from result
	AND.b		#$07,d0			* mask 1 of 8
	BNE.s		St_do_next			* no new star 7/8 ths of the time

	MOVE.w	#$00F8,d1			* maximum intensity
	MOVE.w	d1,st_intens(a3,d6.w)	* save star intensity

	BSR		gen_prng			* call the PRNG code
	MOVE.b	PRNlword(a3),d1		* get byte from result
	AND.w		#3,d1				* mask 0 to 3
	ADDQ.w	#1,d1				* make 1 - 4
	BSR		gen_prng			* call the PRNG code
	MOVE.b	PRNlword(a3),d0		* get byte from result
	BPL.s		St_goright			* branch if b7 was zero

	NEG.w		d1				* else make delta x left
St_goright
	MOVE.w	d1,st_deltax(a3,d6.w)	* save star delta x

	BSR		gen_prng			* call the PRNG code
	MOVE.b	PRNlword(a3),d1		* get byte from result
	AND.w		#7,d1				* mask 0 to 7
	ADDQ.w	#5,d1				* make 5 - 12
	MOVE.w	d1,st_deltay(a3,d6.w)	* save star delta y
	MOVEQ		#$5E,d0			* set start y co-ordinate
St_gone
	MOVE.w	d0,st_ycoord(a3,d6.w)	* save star y co-ordinate
	MOVEQ		#0,d0				* clear register
	MOVE.w	d0,st_xcoord(a3,d6.w)	* clear star x co-ordinate
	BRA.s		St_do_next			* go do next star

St_visible
	SUBQ.w	#8,d0				* decrement star intensity
	MOVE.w	d0,st_intens(a3,d6.w)	* save star intensity
	BEQ.s		St_gone			* if star extinguished go clear (x,y)

	MOVE.w	st_deltay(a3,d6.w),d0	* get star delta y
	SUBQ.w	#1,d0				* decrement star delta y
	MOVE.w	d0,st_deltay(a3,d6.w)	* save new star delta y
	ADD.w		st_ycoord(a3,d6.w),d0	* add star y co-ordinate
	BPL.s		St_insky			* branch if star is above horizon

	MOVEQ		#0,d0				* clear register
	MOVE.w	d0,st_intens(a3,d6.w)	* turn star off
	BRA.s		St_gone			* go clear (x,y)

* star is above the horizon

St_insky
	MOVE.w	d0,st_ycoord(a3,d6.w)	* save star y co-ordinate

	MOVE.w	st_deltax(a3,d6.w),d0	* get star delta x
	ADD.w		st_xcoord(a3,d6.w),d0	* add star x co-ordinate
	MOVE.w	d0,st_xcoord(a3,d6.w)	* save star x co-ordinate

St_do_next
	SUB.w		#st_size,d6			* decrement index
	BPL		Update_loop			* loop if not all done

	RTS


*************************************************************************************
*
* star draw routine. first checks that the volcano is visible at all, this prevents
* the stars being drawn when the volcano is behind the player. then checks each star
* in turn and draws it if it's visible

Draw_stars
	MOVE.w	v_o_start+v_orient(a3),d0
							* get player orientation
	MOVE.w	eye_orent(a3),d3		* get orientation offset
	ADD.w		d3,d3				* * 2, the background is a 1/8th circle view
	ADD.w		d3,d0				* add offset to player orientation
	AND.w		#$01FF,d0			* mask circle
	CMP.w		#$0110,d0			* compare with $0110 degrees
	BCC.s		volc_done			* exit if >= $0110, no stars visible

	CMP.w		#$0072,d0			* compare with $0072 degrees
	BCS.s		volc_done			* exit if < $0072, no stars visible

* display the volcano stars, first calculate the x co-ordinate offset from the player
* orientation

	LSL.w		#3,d0				* player orientation * 8
	SUB.w		#$060A,d0			* subtract volcano x co-ordinate offset
	MOVE.w	d0,local_x(a3)		* save local x co-ordinate

* the y co-ordinate is normally zero except after a collision when it's displaced. this
* displacement is 1/16th of the foreground displacement because the background is that
* much further away

	MOVE.w	vert_offs(a3),d2		* get the vertical offset
	LSR.w		#4,d2				* / 16 as background doesn't bounce much
	NEG.w		d2				* make -ve
	MOVE.w	d2,local_y(a3)		* save local y co-ordinate

* now draw each star realtive to the local x,y co-ordinates

	MOVEQ		#4*st_size,d6		* set star structure size * 4
Draw_loop
	MOVEQ		#0,d1				* clear longword
	MOVE.w	st_intens(a3,d6.w),d1	* get star intensity
	BEQ.s		St_invisible		* branch if star not visible

	BTST.b	#0,viewmode(a3)		* test view mode flag
	BEQ.s		color_stars			* branch if not 3D view mode

	MOVE.w	d1,d2				* copy colour word
	SWAP		d1				* shift to high word, set for red
	MOVE.w	d2,d1				* copy colour word, set for blue
	AND.l		colourmask(a3),d1		* mask red/green/blue
color_stars
	MOVEQ		#80,d0			* set pen colour to star colour
	TRAP		#15

no_colour
	MOVE.w	local_x(a3),d1		* get local screen x co-ordinate
	ADD.w		st_xcoord(a3,d6.w),d1	* add star x co-ordinate

	MOVE.w	local_y(a3),d2		* get local screen y co-ordinate
	ADD.w		st_ycoord(a3,d6.w),d2	* add star y co-ordinate

	MOVEQ		#87,d0			* draw rectangle, make the stars 2 x 2 pixels
	BSR		disp_vector			* display the vector, don't set local (x,y)
St_invisible
	SUB.w		#st_size,d6			* decrement index
	BPL		Draw_loop			* loop if not all done

volc_done
	RTS


*************************************************************************************
*
* star clear routine. initialise the stars as memory isn't always $00000000 when you
* expect it to be

Clear_stars
	MOVEQ		#0,d0				* clear register
	MOVEQ		#4*st_size,d6		* set star structure size * 4
Clear_loop
	MOVE.w	d0,st_intens(a3,d6.w)	* clear the star intensity
	SUB.w		#st_size,d6			* decrement index
	BPL		Clear_loop			* loop if not all done

	RTS


*************************************************************************************
*
* copy the high score name list to the high score name table and set all the high
* score scores to 5,000

set_hiscores
	LEA		t_pre_hisc(pc),a0		* set high score name source pointer
	LEA		h_sc_nam(a3),a1		* set high score name destination pointer
	LEA		h_score(a3),a2		* set high score pointer
	MOVEQ		#5,d0				* all scores to 5,000

	MOVEQ		#9,d7				* set high score count
set_hisc_loop
	MOVE.w	d0,(a2)+			* set score
	MOVE.l	(a0)+,(a1)+			* copy name
	DBF		d7,set_hisc_loop		* loop if not all done

	RTS


*************************************************************************************
*
* set the 2D/3D colour from the colour mask

set_3D_colour
	MOVEM.l	d0/d2,-(sp)			* save d0 and d2
	MOVE.w	d1,d2				* copy colour word
	SWAP		d1				* shift to high word, set red
	MOVE.w	d2,d1				* copy colour word and ..
	MOVE.b	d1,-(sp)			* move low byte to stack ..
	MOVE.w	(sp)+,d1			* .. and back to word high byte
	CLR.b		d1				* clear low byte
	OR.w		d2,d1				* copy colour word, set blue
	AND.l		colourmask(a3),d1		* mask red/green/blue
	MOVEQ		#80,d0			* set pen colour
	TRAP		#15

	MOVEM.l	(sp)+,d0/d2			* restore d0 and d2
	RTS


*************************************************************************************
*
* draw the Battlezone background. the background is 4096 pixels wide but only the
* three possibly visible 512 pixel wide tiles are rendered

Draw_background
	MOVEQ		#$60,d1			* set dark pen
	BSR		set_3D_colour		* set the 3D colour

* first work out where the third tile will end and move the graphics cursor there. also
* work out which of the tiles is the first one to be drawn

	MOVE.w	v_o_start+v_orient(a3),d1
							* get player orientation
	MOVE.w	eye_orent(a3),d3		* get orientation offset
	ADD.w		d3,d3				* * 2
	ADD.w		d3,d1				* add offset to player orientation
	AND.w		#$01FF,d0			* mask circle
	LSL.w		#3,d1				* player orientation * 8

	MOVE.w	d1,d6				* copy 16th

	MOVE.w	d6,-(sp)			* save to stack
	MOVE.b	(sp)+,d6			* return high byte as low byte

	AND.w		#$0E,d6			* mask for 1 of 8 backgrounds
	EOR.w		#$0E,d6			* invert result, index to first tile

	AND.w		#$01FF,d1			* mask for 16ths
	OR.w		#$0200,d1			* + 512
	MOVE.w	vert_offs(a3),d2		* get the vertical offset
	LSR.w		#4,d2				* / 16 as background doesn't bounce much
	NEG.w		d2				* make -ve

	MOVEQ		#86,d0			* move to end of horizon line
	BSR		display_vector		* initialise horizon

* now draw the horizon back to the origin of the first tile

	SUB.w		#1536,d1			* 3 * 512 pixel wide tiles to draw
	MOVEQ		#85,d0			* set draw to x,y

	BSR		display_vector		* draw horizon

* now draw the three tiles

	BSR.s		do_background		* do first background tile
	BSR.s		do_background		* do second background tile
	NOP						* now do third background tile and return


*************************************************************************************
*
* draw background tile. setup (a4) to point to the needed tile, increment and mask
* the tile index and then go draw the tile

do_background
	LEA		background(pc),a4		* get pointer to background data
	MOVE.w	(a4,d6.w),d5		* get offset to background
	LEA		(a4,d5.w),a4		* get background start
	ADDQ.w	#2,d6				* increment to next background
	AND.w		#$0E,d6			* mask for 1 of 8 backgrounds

	dc.w		$303C				* skip restore vector address. this makes the
							* next line MOVE.w #$285F,d0 which is faster
							* than branching round it

*************************************************************************************
*
* vector subroutine return code. if a vector subroutine is called the address for this
* code is pushed on the stack

op_rtsvec
	MOVE.l	(sp)+,a4			* restore the vector pointer

* evaluate the next vector command. the command is pointed to by (a4) and execution
* will continue until an RTSL of HALT command is encountered. this is a subset of the
* battlezone AVG command set

do_vector
	MOVE.w	(a4)+,d0			* get word
	MOVE.w	d0,d4				* copy to y2
	MOVE.w	d0,-(sp)			* save to stack
	MOVE.b	(sp)+,d0			* return high byte as low byte
	LSR.w		#4,d0				* make d0 vector opcode
	AND.w		#$000E,d0			* d0 is now 2 * opcode

	LEA		vector_base(pc),a5	* get base of vector subroutines
	JMP		(a5,d0.w)			* do vector

* centre routine. return the cursor to the screen centre

op_cntr
	MOVEQ		#0,d1				* set x co-ordinate to screen centre
	MOVEQ		#0,d2				* set y co-ordinate to screen centre

	MOVEQ		#86,d0			* set move to x,y

op_vector
	PEA		do_vector(pc)		* return to do next
	BRA		display_vector		* display the vector

* short vector routine. co-ordinates are five bit twos complement numbers and should
* be multiplied by two to get the effective length

op_svec
	MOVE.w	d4,d3				* copy co-ordinate to x2
	MOVEQ		#0,d1				* clear longword
	MOVE.w	d4,d1				* copy for intensity
	MOVE.b	d1,-(sp)			* move low byte to stack ..
	MOVE.w	(sp)+,d1			* .. and back to word high byte
							* intensity to b15, b14 and b13

	MOVE.w	#$FFE0,d0			* set mask for 5 to 16 bit sign extend

	LSR.w		#7,d4				* shift y co-ordinate to low byte * 2
	AND.w		#$003E,d4			* mask y co-ordinate bits
	ADD.w		d0,d4				* set top bits clear if -ve, set if +ve
	EOR.w		d0,d4				* toggle bits to correct state

	ADD.w		d3,d3				* x co-ordinate * 2
	AND.w		#$003E,d3			* mask x co-ordinate bits
	ADD.w		d0,d3				* set top bits clear if -ve, set if +ve
	EOR.w		d0,d3				* toggle bits to correct state

	BRA.s		vector_scale		* go draw vector

* AVG vector command branch table

vector_base
	BRA.s		op_vctr			* $00 branch to vector routine
	BRA.s		op_halt			* $02 branch to halt routine
	BRA.s		op_svec			* $04 branch to short vector routine
	BRA.s		do_vector			* $06 nop
	BRA.s		op_cntr			* $08 branch to centre subroutine
	BRA.s		op_call			* $0A branch to call subroutine
	BRA.s		op_rtsl			* $0C branch to return subroutine
	BRA.s		op_jump			* $0E branch to jump

* halt routine. in this case just quit processing vectors

op_halt

* return routine. either quit processing vectors or go do the vector subroutine
* return code above

op_rtsl
	RTS

* call vector subroutine, push the vector pointer and then the vector subroutine
* address as the return address then do jump to vector address

op_call
	MOVE.l	a4,-(sp)			* save the vector pointer
	PEA		op_rtsvec(pc)		* push vector return code as return address

* jump to vector, the address is a thirteen bit twos complement address

op_jump
	MOVE.w	#$F000,d0			* set mask for 13 to 16 bit sign extend

	AND.w		#$1FFF,d4			* mask address
	ADD.w		d0,d4				* set top bits clear if -ve, set if +ve
	EOR.w		d0,d4				* toggle bits to correct state
	LEA		(a4,d4.w),a4		* calculate new address
	BRA.s		do_vector			* go do new vector

* vector routine. co-ordinates are thirteen bit twos complement numbers

op_vctr
	MOVE.w	#$F000,d0			* set mask for 13 to 16 bit sign extend

	AND.w		#$1FFF,d4			* mask y co-ordinate
	ADD.w		d0,d4				* set top bits clear if -ve, set if +ve
	EOR.w		d0,d4				* toggle bits to correct state

	MOVEQ		#0,d1				* clear longword
	MOVE.w	(a4)+,d1			* get second word
	MOVE.w	d1,d3				* copy to x2

	AND.w		#$1FFF,d3			* mask x co-ordinate
	ADD.w		d0,d3				* set top bits clear if -ve, set if +ve
	EOR.w		d0,d3				* toggle bits to correct state

vector_scale
	MOVE.w	vector_s(a3),d0		* get binary scale
	ASR.w		d0,d3				* scale x co-ordinate
	ASR.w		d0,d4				* scale y co-ordinate

	ADD.w		local_x(a3),d3		* add x co-ordinate to vector x co-ordinate
	ADD.w		local_y(a3),d4		* add y co-ordinate to vector y co-ordinate

	MOVEQ		#86,d0			* set move to x,y

	AND.w		#$E000,d1			* d1 is now 2 * intensity
	BEQ.s		vector_move			* if zero intensity just do move

	LSR.w		#8,d1				* else shift the value to the low byte ..
	BSR		set_3D_colour		* .. and set the 3D colour
	MOVEQ		#85,d0			* set draw to x,y
vector_move
	MOVE.w	d4,d2				* copy y co-ordinate
	MOVE.w	d3,d1				* copy x co-ordinate

	BRA		op_vector			* go display vector and do next


*************************************************************************************
*
* display vector and do next. takes the vector, scales the x and y to the current
* screen size - does axis inversion if needed - and then displays it. set up the
* graphics function in d0, x co-ordinate in d1.w and y co-ordinate in d2.w

display_vector
	MOVE.w	d1,local_x(a3)		* save as new local x co-ordinate
	MOVE.w	d2,local_y(a3)		* save as new local y co-ordinate

disp_vector
	MOVEM.w	d1-d4,-(sp)			* save registers

	MOVEQ		#10,d3			* set shift count for / 1024

	MULS.w	scr_x(a3),d1		* x * screen x
	ASR.l		d3,d1				* / 1024
	ADD.w		scr_x_c(a3),d1		* + x centre

	MULS.w	scr_x(a3),d2		* y * screen x
	ASR.l		d3,d2				* / 1024
	NEG.w		d2				* y = 0 is top of screen remember
	ADD.w		scr_y_c(a3),d2		* + y centre

	MOVE.w	d1,d3				* copy x co-ordinate
	ADDQ.w	#1,d3				* make a small square

	MOVE.w	d2,d4				* copy y co-ordinate
	ADDQ.w	#1,d4				* make a small square

	TRAP		#15				* do move or draw
	MOVEM.w	(sp)+,d1-d4			* restore registers
	RTS


*************************************************************************************
*
* get scaled sin(v_orient) in d2, cos(v_orient) in d3. enter with d1.w = vehicle
* index

sincos
	MOVE.w	v_orient(a3,d1.w),d0	* get vehicle orientation
	BSR.s		sin_d0			* get SIN(d0) in d0
	MOVEQ		#9,d2				* shift count
	ASR.w		d2,d0				* / 2 and move to low byte
	MOVE.w	d0,d2				* copy it
	ASR.w		#1,d0				* / 4
	ADD		d0,d2				* add 1/4 to 1/2

	MOVE.w	v_orient(a3,d1.w),d0	* get vehicle orientation
	BSR.s		cos_d0			* get COS(d0) in d0
	MOVEQ		#9,d3				* shift count
	ASR.w		d3,d0				* / 2 and move to low byte
	MOVE.w	d0,d3				* copy it
	ASR.w		#1,d0				* / 4
	ADD		d0,d3				* add 1/4 to 1/2
	RTS


*************************************************************************************
*
* get COS(d0) in d0. d0 is a nine bit value representing a full circle with the value
* increasing as you turn widdershins

cos_d0
	ADD.w		#$0080,d0			* add 1/4 rotation


*------------------------------------------------------------------------------------
*
* get SIN(d0) in d0. d0 is a nine bit value representing a full circle with the value
* increasing as you turn widdershins

sin_d0
	BTST		#8,d0				* test angle sign
	BEQ.s		cossin_d0			* just get SIN/COS and return if +ve

	BSR.s		cossin_d0			* else get SIN/COS
	NEG.w		d0				* now do twos complement
	RTS

* get d0 from SIN/COS table

cossin_d0
	TST.b		d0				* test for >= $80
	BPL.s		a_was_less			* branch if < 1/4 circle

	NEG.b		d0				* wrap $81 to $FF to $7F to $01
a_was_less
	AND.w		#$00FF,d0			* ensure word high byte clear
	ADD.w		d0,d0				* * 2 bytes per word value
	LEA		sin_cos(pc),a0		* get table base address
	MOVE.w	(a0,d0.w),d0		* get SIN/COS value
	RTS


*************************************************************************************
*
* gather the visible objects then translate and draw them

Draw_list
	BSR		Gather_objects		* gather the objects to be displayed
	MOVEQ		#0,d7				* clear list index
dlist_loop
	MOVE.w	(a5,d7.w),d0		* get object number/orientation from the list
	BMI.s		list_drawn			* exit loop if all done

	BSR.s		ThreeDto2D			* translate the object points list from 3D
							* x,y,z to 2D x,y then draw the object

	ADDQ.w	#2,d7				* increment list index to next object
	BRA		dlist_loop			* loop always

list_drawn
	RTS


*************************************************************************************
*
* translate the object points list from 3D x,y,z to 2D x,y then draw the object.
* enters with the object number/orientation in d0.w

ThreeDto2D
	NEG.w		d0				* make the orientation -ve
	ADD.w		d0,d0				* * 2 to give nine bit value
	ADD.w		v_o_start+v_orient(a3),d0
							* subtract from player object orientation
	ADD.w		eye_orent(a3),d0		* add orientation offset to player orientation

	EOR.w		#$0100,d0			* rotate 1/2 circle

	MOVE.w	d0,d2				* copy angle
	BSR		sin_d0			* get SIN(d0) in d0
	MOVE.w	d0,d3				* save sin(p) in d3

	MOVE.w	d2,d0				* restore angle
	BSR		cos_d0			* get COS(d0) in d0
	NEG.w		d0				* negate it
	MOVE.w	d0,d2				* save -cos(p) in d2

* check if the object is the saucer, if it is see if it's destroyed and if so do the
* saucer destruction brightness modulation

	CMP.b		#obj_sacr,(a5,d7.w)	* compare saucer object with object number
	BNE.s		distance_mod		* if not saucer go set distance brightness

	TST.w		saucer_d(a3)		* test saucer destruction flag
	BEQ.s		distance_mod		* if not destruction go set distance brightness

	MOVE.w	saucer_i(a3),d4		* get saucer destruction intensity
	BRA.s		intensity_mod		* go set intensity modulation

* now set the intensity modifier according to the distance away the object is. this is
* a kludge as it only takes one axis into consideration

distance_mod
	MOVE.w	list_obj_x(a5,d7.w),d4	* get object translated x co-ordinate
	MOVE.w	d4,-(sp)			* save to stack
	MOVE.b	(sp)+,d4			* return high byte as low byte
							* shift intensity to low byte
	AND.w		#$00F0,d4			* mask for high bits
intensity_mod
	MOVE.w	d4,intens_mod(a3)		* copy translated x co-ordinate as intensity,
							* this makes more distant objects dimmer

	MOVEQ		#0,d6				* clear high byte
	MOVE.b	(a5,d7.w),d6		* get object number from list
	LEA		obj_points(pc),a4		* get pointer to object co-ordinates table base
	MOVE.w	(a4,d6.w),d5		* get offset to object points
	LEA		cord_tables(pc),a4	* get pointer to object co-ordinates base
	LEA		(a4,d5.w),a4		* pointer to object of interest

	LEA		twoD_obj_x(a3),a2		* pointer to converted co-ordinates table

* p = point : o = object : w = world : s = screen

* pz' = pz						* translate to player orientation
* px' = px * cos(p) - py * sin(p)		* d2 = cos(p) : d4 = x co-ordinate
* py' = px * sin(p) + py * cos(p)		* d3 = sin(p) : d5 = y co-ordinate

* now check to see if the part has a vertical offset. if so get it and save it for later

	MOVE.w	m_alt(a3),d4		* get flying logo vertical offset
	CMP.w		#obj_easy,d6		* compare object number with "EASY" object
	BEQ.s		skip_vert_off		* if "EASY" object keep this offset

	CMP.w		#obj_zone,d6		* compare object number with "ZONE" object
	BEQ.s		skip_vert_off		* if "ZONE" object keep this offset

	MOVEQ		#0,d4				* default to zero vertical offset
	CMP.w		#obj_expn,d6		* compare object number with fragment minimum
	BCS.s		skip_vert_off		* if less than min don't get vertical offset

	CMP.w		#obj_tanr,d6		* compare object number with fragment max+1
	BCC.s		skip_vert_off		* if greater than max don't get vertical offset

* else it's an explosion fragment so work out which one and get its height

	LEA		ex_object(a3),a1		* set pointer to explosion object list
	SUB.b		#obj_expn-obj_tank,d6	* subtract offset from enemy object to
							* explosion piece from the object number
	SUB.w		v_o_start+v_o_size+v_o_type(a3),d6
							* subtract the enemy object number
	MOVE.w	ex_z(a1,d6.w),d4		* get the explosion part z co-ordinate
skip_vert_off
	MOVE.w	d4,vert_objt(a3)		* save as object offset

	MOVE.w	(a4)+,d6			* get number of points
loop_ThreeDto2D
	MOVE.w	0(a4),d4			* get object point x co-ordinate
	MOVE.w	2(a4),d5			* get object point y co-ordinate

							* px' = px * cos(p) - py * sin(p)
	MULS.w	d2,d4				* x co-ordinate * cos(p)
	MULS.w	d3,d5				* y co-ordinate * sin(p)
	MOVE.l	d4,d0				* copy x * cos(p)
	SUB.l		d5,d0				* = x * cos(p) - y * sin(p)
	SWAP		d0				* only need high word

	MOVE.w	(a4)+,d4			* get object point x co-ordinate again
	MOVE.w	(a4)+,d5			* get object point y co-ordinate again

							* py' = px * sin(p) + py * cos(p)
	MULS.w	d3,d4				* x co-ordinate * sin(p)
	MULS.w	d2,d5				* y co-ordinate * cos(p)
	MOVE.l	d4,d1				* copy x * sin(p)
	ADD.l		d5,d1				* = x * sin(p) + y * cos(p)
	SWAP		d1				* only need high word

* wz = pz + oz					* translate to world co-ordinates
* wx = px + ox = d0
* wy = py + oy = d1

	ADD.w		list_obj_x(a5,d7.w),d0	* add object origin x co-ordinate
	BNE.s		no_adj4zero			* branch if d0 not zero

	ADDQ.w	#1,d0				* else move point a bit
no_adj4zero
	SUB.w		list_obj_y(a5,d7.w),d1	* add object origin y co-ordinate

* sx = scale * wy / wx				* translate and scale from world ..
* sy = scale * wz / wx				* .. co-ordinates to screen co-ordinates

	MULS.w	#-1024,d1			* multiply and make longword
	DIVS.w	d0,d1				* d1 is now screen x
	MOVE.w	d1,(a2)			* save point x co-ordinate

	MOVE.w	(a4)+,d1			* get point z co-ordinate
	SUB.w		vert_offs(a3),d1		* add the vertical offset

	ADD.w		vert_objt(a3),d1		* add the object offset

	MULS.w	#1024,d1			* multiply and make longword
	DIVS.w	d0,d1				* d1 is now screen y
	MOVE.w	d1,list_obj_x(a2)		* save point y co-ordinate

	ADDQ		#2,a2				* increment converted point index
	DBF		d6,loop_ThreeDto2D	* decrement and loop for next


*------------------------------------------------------------------------------------
*
* now draw the object from the translated 2D object points list

	MOVEQ		#0,d6				* clear high byte
	MOVE.b	(a5,d7.w),d6		* get object number from list

	LEA		obj_verts(pc),a4		* get pointer to vertex table base
	MOVE.w	(a4,d6.w),d6		* get offset to object vertex list
	LEA		vert_tables(pc),a4	* get pointer to object vertex base
	LEA		(a4,d6.w),a4		* pointer to object of interest

	LEA		twoD_obj_x(a3),a2		* pointer to converted co-ordinates table

	LEA		vertex_type(pc),a1	* pointer to vertex type table

* interpret next byte from object

vdo_next
	MOVEQ		#0,d0				* clear longword
	MOVE.b	(a4)+,d0			* get next byte from object
	CMP.b		#$FF,d0			* compare with end marker
	BEQ.s		exit_obj_draw		* if end marker go exit

	MOVE.w	d0,d3				* copy parameter byte
	AND.b		#7,d0				* mask instruction bits
	ASL.b		#2,d0				* * 4 bytes per vector
	JMP		(a1,d0.w)			* go do vertex type vector

exit_obj_draw
	RTS

* vetrex type branch table

vertex_type
	BRA.w		draw_star			* draw star
	BRA.w		set_intens			* set intensity
	BRA.w		move_vector			* move vector, just move on absolute xy display
	BRA.w		move_vector			* set origin
	BRA.w		vector_draw			* draw vector
	BRA.w		vdo_next			* draw shell explosion object - not used
	BRA.w		vdo_next			* do next
	BRA.w		vdo_next			* do next

* draw vector star

draw_star
	MOVEQ		#86,d0			* set move to x,y
	BSR.s		vect_get			* do vector
	MOVEQ		#85,d0			* set draw to x,y
	BSR		disp_vector			* display vector
	BRA.s		vdo_next			* interpret next byte from object

* set vertex intensity

set_intens
	AND.w		#$F8,d3			* mask intensity bits
	SUB.w		intens_mod(a3),d3		* subtract intensity modifier
	BCS.s		too_dim			* if underflowed go set intensity to $30

	CMP.w		#$20,d3			* compare with minimum
	BCC.s		not_too_dim			* if >= minimum just save it

too_dim
	MOVE.w	#$20,d3			* else set intensity to $20
not_too_dim
	MOVEQ		#0,d1				* clear colour longword
	MOVE.w	d3,d1				* copy colour word
	SWAP		d1				* shift to high word
	MOVE.w	d3,d1				* copy colour word - again
	MOVE.b	d1,-(sp)			* move low byte to stack ..
	MOVE.w	(sp)+,d1			* .. and back to word high byte
	CLR.b		d1				* clear low byte
	OR.w		d3,d1				* copy colour word - yet again
	AND.l		colourmask(a3),d1		* mask red/green/blue
	MOVEQ		#80,d0			* set pen colour
	TRAP		#15

	BRA		vdo_next			* interpret next byte from object

* do move vector

move_vector
	MOVEQ		#86,d0			* set move to x,y
	BSR.s		vect_get			* get vector and add draw it
	BRA.s		vdo_next			* interpret next byte from object

* do draw vector

vector_draw
	MOVEQ		#85,d0			* set draw to x,y
	BSR.s		vect_get			* get vector and add draw it
	BRA.s		vdo_next			* interpret next byte from object

* get vector and add draw it

vect_get
	LSR.w		#2,d3				* / 4, 2 bytes per co-ordinate
	AND.w		#-2,d3			* mask parameter bits

	MOVE.w	(a2,d3.w),d1		* get 2D x co-ordinate
	MOVE.w	list_obj_x(a2,d3.w),d2	* get 2D y co-ordinate

	BRA		disp_vector			* display vector and return


*************************************************************************************
*
* collect objects from the world and add them to the list if they are visible
* note a6 points to the world object list

Gather_objects
	MOVEQ		#0,d6				* clear list index
	LEA		list_objct(a3),a5		* pointer to visible object list

	MOVE.w	v_o_start+v_orient(a3),d0
							* get player object orientation
	ADD.w		eye_orent(a3),d0		* add orientation offset to player orientation
	MOVE.w	d0,d1				* copy it
	BSR		cos_d0			* get COS(d0) in d0
	MOVE.w	d0,d2				* copy it

	MOVE.w	d1,d0				* get player object orientation copy
	BSR		sin_d0			* get SIN(d0) in d0
	MOVE.w	d0,d3				* copy it

	PEA		gather_start(pc)		* either way return here
	MOVE.w	game_mode(a3),d0		* get game mode
	EOR.w		#g_logo,d0			* compare with logo mode
	BEQ		gather_logo			* if logo mode go gather the logo parts

	BSR		gather_saucer		* go test the saucer and add to list if visible
	BSR		gather_enemy		* go test the enemy and add to list if visible
	BRA		gather_fos			* go test the fire objects and add if visible

gather_start
	MOVEQ		#0,d7				* clear object index
gather_loop
	MOVE.w	(a6,d7.w),d0		* get world object number
	TST.w		d0				* set the flags
	BMI.s		gather_exit			* exit loop if end marker

	MOVE.w	d0,(a5,d6.w)		* save object number and orientation

	MOVE.w	obj_x(a6,d7.w),d4		* get world object x co-ordinate
	MOVE.w	obj_y(a6,d7.w),d5		* get world object y co-ordinate
	BSR.s		test_object			* go test the object and add to list if visible

	ADDQ		#2,d7				* increment read index to next world object
	BRA.s		gather_loop			* loop for next

gather_exit
	MOVE.w	d0,(a5,d6.w)		* mark list end
	RTS


*************************************************************************************
*
* test object and add to list if visible, enter with the objext x,y in d4,d5. this
* now does a proper radial distance check so distant items no longer pop in when on
* the edge of the field of view

test_object
	MOVEM.w	d1-d2,-(sp)			* save registers
	SUB.w		v_o_start+v_xcoord(a3),d4
							* calculate delta x from player
	SUB.w		v_o_start+v_ycoord(a3),d5
							* calculate delta y from player

	MOVE.w	d4,d0				* copy delta x
	MOVE.w	d5,d1				* copy delta y

	MULS.w	d0,d0				* x^2
	MULS.w	d1,d1				* y^2
	ADD.l		d1,d0				* now = x^2 + y^2

	CMP.l		#$3B190000,d0		* compare with maximum distance, $7B00^2
	BCC		test_obj_exit		* go do next if further away than maximum limit

* the minimum distance check is still needed to remove items we can pass through in some
* way. this is needed to prevent the code from trying to draw the object from the inside
* with the hazzards of a (much) later divide by zero error. by removing the object if it
* gets too close neatly avoids the need to check for, or trap, /0

	CMP.l		#$51000,d0			* compare with minimum distance, $240^2
	BCS		test_obj_exit		* go do next if too close to player

* done the distance discard now add the viewpoint offset. this prevents one of the two
* eye views from being removed but the other one included by the distance discard

	ADD.w		eye_osetx(a3),d4		* add eye offset to x co-ordinate
	ADD.w		eye_osety(a3),d5		* add eye offset to y co-ordinate

	MOVE.w	d4,d0				* copy delta x
	MOVE.w	d5,d1				* copy delta y

							* x' = x * cos(p) - y * sin(p)
	MULS.w	d2,d0				* cos * delta x
	MULS.w	d3,d1				* sin * delta y
	SUB.l		d1,d0				* = x * cos - y * sin
	ADD.l		d0,d0				* scale translated delta x
	SWAP		d0				* only need high word
	TST.w		d0				* test word sign
	BMI.s		test_obj_exit		* skip add to list if behind player

							* y' = x * sin(p) + y * cos(p)
	MULS.w	d3,d4				* sin * delta x
	MULS.w	d2,d5				* cos * delta y
	MOVE.l	d4,d1				* copy x * sin
	ADD.l		d5,d1				* = x * sin + y * cos
	ADD.l		d1,d1				* scale translated delta y
	SWAP		d1				* only need high word

	MOVE.w	d1,d5				* copy translated delta y
	BPL.s		dontnegate			* branch if +ve

	NEG.w		d5				* do ABS() translated y co-ordinate
dontnegate
	CMP.w		d5,d0				* compare with translated x co-ordinate
	BMI.s		test_obj_exit		* skip add if outside +/- 45 degree view

							* object is within the field of view so add
							* it to the list

	MOVE.w	d0,list_obj_x(a5,d6.w)	* save object translated x co-ordinate
	MOVE.w	d1,list_obj_y(a5,d6.w)	* save object translated y co-ordinate
	MOVE.b	(a5,d6.w),d0		* get object number
	ADDQ.w	#2,d6				* increment write index to next list object

	CMP.b		#obj_tank,d0		* compare with tank object
	BNE.s		test_obj_exit		* if not tank object skip add radar

	MOVE.w	er_obj(a3),(a5,d6.w)	* save radar number and orientation

* as the radar dish on the enemy tank is mounted at an offset from the origin this (x,y)
* offset has to be recalculated every time to take into account the enemy tank
* orientation as seen from the player's viewpoint

	MOVEQ		#0,d0				* clear longword
	MOVE.b	-1(a5,d6.w),d0		* get enemy orientation
	ADD.w		d0,d0				* make 9 bit
	NEG.w		d0				* make -ve

	ADD.w		v_o_start+v_orient(a3),d0
							* add player object orientation
	ADD.w		eye_orent(a3),d0		* add player orientation offset

	MOVE.w	d0,d1				* save player/enemy orientation difference
	BSR		cos_d0			* get COS(d0) in d0
	NEG.w		d0				* -cos(p)
	ASR.w		#7,d0				* scale it
	ADD.w		list_obj_x-2(a5,d6.w),d0
							* add enemy tank translated x co-ordinate
	MOVE.w	d0,list_obj_x(a5,d6.w)	* save object translated x co-ordinate

	MOVE.w	d1,d0				* get player/enemy orientation difference back
	BSR		sin_d0			* get SIN(d0) in d0
	NEG.w		d0				* -cos(p)
	ASR.w		#7,d0				* scale it
	ADD.w		list_obj_y-2(a5,d6.w),d0
							* add enemy tank translated y co-ordinate
	MOVE.w	d0,list_obj_y(a5,d6.w)	* save object translated y co-ordinate

	ADDQ		#2,d6				* increment write index to next list object
test_obj_exit
	MOVEM.w	(sp)+,d1-d2			* restore registers
	RTS


*************************************************************************************
*
* draw vector message, message index is in d0

draw_message
	MOVE.w	d0,d4				* copy message index
	LEA		m_enemy(pc),a0		* get message table base address
	LEA		(a0,d0.w),a0		* get message base address

	MOVE.w	(a0)+,d1			* get message x co-ordinate
	MOVE.w	(a0)+,d2			* get message y co-ordinate
	MOVE.w	d1,d0				* copy message x co-ordinate
	OR.w		d2,d0				* OR message y co-ordinate
	BEQ.s		m_nostart			* if x,y = 0,0 skip start set

	MOVEQ		#86,d0			* set move to x,y
	BSR		display_vector		* display the vector

m_nostart
	CMP.w		#m_gameover-m_enemy,d4	* compare index with motion blocked message
	BCC.s		m_scale1			* if greater skip set scale

	MOVEQ		#$01,d1			* set binary scale to 2
	MOVE.w	d1,vector_s(a3)		* save binary scale
m_scale1
	LEA		char_set(pc),a1		* get pointer to character set table
m_loop
	MOVEQ		#$7F,d0			* set mask
	AND.b		(a0),d0			* get and mask byte from message

	MOVE.w	(a1,d0.w),d0		* get offset to character
	LEA		(a1,d0.w),a4		* set vector pointer to character

	BSR		do_vector			* go draw the character

	MOVE.b	(a0)+,d0			* get byte from message again
	BPL.s		m_loop			* loop if not end marker

	MOVEQ		#$00,d1			* set binary scale to 1
	MOVE.w	d1,vector_s(a3)		* save binary scale
	RTS


*************************************************************************************
*
* draw the scores

draw_scores
	MOVE.l	#$00FF00,colourmask(a3)	* set 2D colourmask for the scores
	MOVE.w	#m_score-m_enemy,d0	* set "SCORE .." offset
	BSR		draw_message		* go display message

	BSR.s		shift_1000s			* add display shift for 1000's
	MOVE.w	p_score(a3),d0		* get player score
	BSR.s		draw_word			* display d0.w as leading zero supressed bytes

	MOVE.w	#m_hiscore-m_enemy,d0	* set "HIGH .." offset
	BSR		draw_message		* go display message

	MOVEQ		#$01,d1			* set binary scale to 2
	MOVE.w	d1,vector_s(a3)		* save binary scale

	BSR.s		shift_1000s			* add display shift for 1000's

	MOVE.w	h_score(a3),d0		* get high score
	BSR.s		draw_word			* display d0.w as leading zero supressed bytes

	MOVEQ		#$00,d1			* set binary scale to 1
	MOVE.w	d1,vector_s(a3)		* save binary scale
	RTS


*************************************************************************************
*
* add offset for 1000's score digits

shift_1000s
	MOVE.w	#$FF58,d1			* set message x co-ordinate
	MOVEQ		#$00,d2			* set message y co-ordinate
	MOVE.w	vector_s(a3),d0		* get binary scale
	ASR.w		d0,d1				* scale x co-ordinate
	ASR.w		d0,d2				* scale y co-ordinate
	ADD.w		local_x(a3),d1		* add x co-ordinate to vector x co-ordinate
	ADD.w		local_y(a3),d2		* add y co-ordinate to vector y co-ordinate
	MOVEQ		#86,d0			* set move to x,y
	BRA		display_vector		* display the vector and return


*************************************************************************************
*
* draw d0.w as two leading zero supressed bytes

draw_word
	MOVEQ		#$03,d7			* set count, 4 digits
	MOVEQ		#$00,d6			* flag leading zero supress
next_digit
	ROL.w		#4,d0				* shift next nibble to low nibble

	MOVE.w	d0,-(sp)			* save value
	JSR		draw_hex			* display d0 as leading zero supressed a hex
							* digit, return d6 <> 0 if non zero

	MOVE.w	(sp)+,d0			* restore value
	SUBQ.w	#$01,d7			* decrement count
	BNE.s		not_last			* branch if not last digit

	MOVEQ		#-1,d6			* unsupress last digit
not_last
	TST.b		d7				* test count
	BPL.s		next_digit			* loop if more to do

	RTS


*************************************************************************************
*
* display d0 as leading zero supressed a hex digit, d6 is the supressed zero flag so
* only display "0" if d6 <> 0, return d6 <> 0 if non zero

draw_hex
	AND.w		#$000F,d0			* mask low nibble
	ADD.w		d0,d0				* * 2 for character table
	TST.b		d6				* test leading zero flag
	BNE.s		always_show			* if zero not supressed go show it

	TST.b		d0				* else test low nibble
	BEQ.s		always_hide			* go do " " if zero

always_show
	MOVEQ		#-1,d6			* flag not zero supressed
	ADDQ.w	#$02,d0			* shift offset past " "
always_hide
	LEA		char_set(pc),a1		* get pointer to character set table

	MOVE.w	(a1,d0.w),d0		* get offset to character
	LEA		(a1,d0.w),a4		* set vector pointer to character

	BRA		do_vector			* go draw the character and return


*************************************************************************************
*
* draws a small tank outline for each player life remaining including the current one

draw_tanks
	MOVE.w	p_lives(a3),d7		* get lives count
	BEQ.s		tank_done			* if no tanks just exit

	MOVE.w	#$20<<2,d1			* set first tank outline x co-ordinate
	MOVE.w	#$5A<<2,d2			* set first tank outline y co-ordinate
	MOVEQ		#86,d0			* set move to x,y
	BSR		display_vector		* display the vector

	SUBQ.w	#1,d7				* adjust for DBF loop
tank_loop
	LEA		t_outline(pc),a4		* point to tank outline
	BSR		do_vector			* go draw the outline

	DBF		d7,tank_loop		* decrement and loop if more to do

tank_done
	RTS


*************************************************************************************
*
* draws the radar outline, the radar sweep arm, the enemy 'pip', the gunsight and the
* enemy position messages. also does the radar sounds if playing the game

draw_radar
	LEA		obj_radar(pc),a4		* point to radar outline
	BSR		do_vector			* go draw the outline

	MOVEQ		#-$0F,d0			* set radar increment
	ADD.w		p_radar(a3),d0		* add player radar orientation
	AND.w		#$01FF,d0			* mask to 9 bit
	MOVE.w	d0,p_radar(a3)		* save new player radar orientation

	BSR		sin_d0			* get SIN(d0) in d0
	MOVE.w	d0,d1				* copy radar sweep arm x co-ordinate
	NEG.w		d1				* change sign

	MOVE.w	p_radar(a3),d0		* get player radar orientation back
	BSR		cos_d0			* get COS(d0) in d0
	MOVE.w	d0,d2				* copy radar sweep arm y co-ordinate

	MOVEQ		#$09,d0			* set scale
	ASR.w		d0,d1				* scale radar sweep arm x co-ordinate
	ASR.w		d0,d2				* scale radar sweep arm y co-ordinate
	ADD.w		#$013C,d2			* add y offset
	MOVEQ		#85,d0			* set draw to x,y
	BSR		display_vector		* display the vector

	
	MOVE.w	#v_o_start,d1		* index to player object
	MOVE.w	#v_o_start+v_o_size,d2	* index to enemy object
	TST.b		v_o_type(a3,d2.w)		* test the enemy object number
	BMI		no_target			* skip drawing the pip if no enemy

	TST.w		v_expsn(a3,d2.w)		* test enemy explosion flag
	BNE		no_target			* skip drawing the pip if exploding

	BSR		player2enemy		* calculate angle from player to enemy
	SUB.w		v_orient(a3,d1.w),d0	* subtract player orientation, d0 is now the
							* bearing to the enemy relative to the player
							* viewpoint
	AND.w		#$01FF,d0			* mask to 9 bit
	MOVE.w	d0,p_temp(a3)		* save relative enemy bearing
	SUB.w		p_radar(a3),d0		* subtract player radar bearing, d0 is now the
							* bearing to the enemy relative to the player
							* radar viewpoint
	AND.w		#$01FF,d0			* mask to 9 bit
	CMP.w		#$11,d0			* compare with pip window max
	BCC.s		no_pip			* don't bright up pip if >= pip window max

	TST.w		radar_pip(a3)		* test that we didn't hit it last go
	BMI.s		no_pip			* don't bright up pip if pip bright

	MOVE.w	#$F000,radar_pip(a3)	* set radar 'pip' intensity
no_pip
	MOVE.w	e_temp_x(a3),d2		* get delta x
	MOVE.w	e_temp_y(a3),d1		* get delta y

	MULS.w	d2,d2				* x^2
	MULS.w	d1,d1				* y^2
	ADD.l		d1,d2				* now = x^2 + y^2

	CMP.l		#$40000000,d2		* compare with maximum distance, $8000^2
	BCS.s		draw_pip			* if in range go draw radar 'pip'

							* .. else enemy is out of range
	MOVE.w	#$0000,e_warning(a3)	* clear enemy warning sounded flag
	BRA		no_target			* skip drawing the radar 'pip'

draw_pip
	TST.w		e_warning(a3)		* test enemy warning sounded flag
	BNE.s		no_warning			* skip warning if warning already sounded

	MOVE.w	#$7800,radar_pip(a3)	* set radar 'pip' intensity so new enemy is
							* always immediately visible on radar
	MOVEQ		#s_warn,d0			* index to new enemy warning sound
	MOVE.w	d0,e_warning(a3)		* flag enemy warning sounded
	BSR		add_sound			* add the sound to the queue

* now find the distance from the player to the enemy. x^2 + y^2 is in d2 so find the
* root of d2

no_warning
	MOVEQ		#0,d0				* clear remainder
	MOVEQ		#0,d3				* clear root
	MOVEQ		#$0F,d7			* 16 pairs of bits to
root_e1
	ADD.l		d2,d2				* shift highest bit of number ..
	ADDX.l	d0,d0				* .. into remainder .. never overflows
	ADD.l		d3,d3				* root = root * 2 .. never overflows

	ADD.l		d2,d2				* shift highest bit of number ..
	ADDX.l	d0,d0				* .. into remainder .. never overflows

	MOVE.l	d3,d4				* copy root
	ADD.l		d4,d4				* 2n
	ADDQ.l	#1,d4				* 2n+1

	CMP.l		d4,d0				* compare 2n+1 to remainder
	BCS.s		root_ns			* skip sub if remainder smaller

	SUB.l		d4,d0				* subtract temp from remainder
	ADDQ.l	#1,d3				* increment root
root_ns
	DBF		d7,root_e1			* loop if not all done

	MOVEQ		#0,d1				* clear longword
	MOVE.w	radar_pip(a3),d1		* get radar pip intensity
	MOVEQ		#80,d0			* set pen colour
	TRAP		#15

	MOVE.w	p_temp(a3),d0		* restore relative enemy bearing
	BSR		sin_d0			* get SIN(d0) in d0
	MOVE.w	d0,d1				* copy radar sweep arm x co-ordinate
	NEG.w		d1				* change sign

	MOVE.w	p_temp(a3),d0		* restore relative enemy bearing
	BSR		cos_d0			* get COS(d0) in d0
	MOVE.w	d0,d2				* copy radar sweep arm y co-ordinate

	MOVEQ		#$08,d0			* set scale
	ASR.w		d0,d1				* scale pip x co-ordinate
	ASR.w		d0,d2				* scale pip y co-ordinate

	MULS.w	d3,d1				* scale pip x co-ordinate to enemy distance
	MULS.w	d3,d2				* scale pip y co-ordinate to enemy distance

	SWAP		d1				* get high word of scaled x result
	SWAP		d2				* get high word of scaled y result

	ADD.w		#$013C,d2			* add y offset to radar centre
	MOVEQ		#86,d0			* set move to x,y
	BSR		display_vector		* display the vector

	MOVEQ		#85,d0			* set draw to x,y, just do a spot
	BSR		display_vector		* display the vector

	MOVEQ		#-8,d0			* mask game over
	AND.w		game_mode(a3),d0		* AND with game mode
	BNE		skip_gunsight		* if not playing the game or not in game over
							* mode don't display the radar messages or draw
							* the gunsight

							* flash "ENEMY IN RANGE" messages
	BTST.b	#1,game_count+1(a3)	* test game count
	BEQ.s		no_range			* skip display if range not on

	MOVE.w	#m_range-m_enemy,d0	* set "ENEMY IN RANGE" offset
	BSR		draw_message		* go display message
no_range
	MOVE.w	#$FF00,d7			* set to - half circle
	ADD.w		p_temp(a3),d7		* add relative enemy bearing
	MOVE.w	d7,d6				* copy it
	BPL.s		not_neg_bear		* skip ABS() if +ve

	NEG.w		d6				* do ABS(bearing)
not_neg_bear
	CMP.w		#$E0,d6			* compare with visible arc
	BCC.s		end_range			* skip "enemy to .." if visible

	MOVE.w	#m_enemy-m_enemy,d0	* set "ENEMY TO .." offset
	BSR		draw_message		* go display message

	MOVE.w	#m_rear-m_enemy,d0	* set "REAR" offset
	CMP.w		#$40,d6			* compare with rear quater
	BCS.s		yes_range			* if behind go display message

	MOVE.w	#m_left-m_enemy,d0	* set "LEFT" offset
	TST.w		d7				* test for left/right
	BMI.s		yes_range			* if to right go display message

	MOVE.w	#m_right-m_enemy,d0	* set "RIGHT" offset
yes_range
	BSR		draw_message		* go display message
end_range
	CMPI.w	#$F000,radar_pip(a3)	* compare pip with max brightness
	BNE.s		no_ping			* skip radar ping if not newly swept over

	MOVEQ		#s_ping,d0			* set index to radar ping sound
	BSR		add_sound			* add the sound to the queue
no_ping
	LEA		g_target(pc),a4		* default to gunsight with target
	CMP.w		#$FE,d6			* compare with in sights
	BCC.s		is_target			* skip clearing sights if there

no_target
	LEA		g_notarget(pc),a4		* else set gunsight with no target
is_target
	MOVEQ		#-8,d0			* mask game over
	AND.w		game_mode(a3),d0		* AND with game mode
	BNE.s		skip_gunsight		* if not playing the game or not in game over
							* mode don't draw the gunsight

	MOVE.w	v_o_start+v_f_obj(a3),d0
							* get player fire object index
	TST.w		f_count(a3,d0.w)		* test player fire object counter
	BEQ.s		draw_gunsight		* go draw gunsight if not firing

	MOVEQ		#1,d0				* set for game count mask
	AND.w		game_count(a3),d0		* test gunsight flash
	BEQ.s		skip_gunsight		* if count bit zero skip gunsight draw

draw_gunsight
	BSR		do_vector			* go draw the gunsight
skip_gunsight
	TST.w		radar_pip(a3)		* test radar 'pip' intensity
	BEQ.s		no_dec_pip			* branch if extinguished

	SUB.w		#$0800,radar_pip(a3)	* else decrement brightness
no_dec_pip
	RTS


*************************************************************************************
*
* messages

m_enemy
	dc.w	$FE48,$0128		* X,Y co-ordinates
	dc.b	$1E,$30,$1E,$2E	* "ENEMY TO "
	dc.b	$46,$00,$3C,$32	*
	dc.b	$80,$80		*
m_left
	dc.w	$0000,$0000		* X,Y co-ordinates
	dc.b	$2C,$1E,$20,$BC	* "LEFT"
m_right
	dc.w	$0000,$0000		* X,Y co-ordinates
	dc.b	$38,$26,$22,$24	* "RIGHT"
	dc.b	$BC,$80		*
m_rear
	dc.w	$0000,$0000		* X,Y co-ordinates
	dc.b	$38,$1E,$16,$B8	* "REAR"
m_initials
	dc.w	$001C,$0068		* X,Y co-ordinates
	dc.b	$1E,$30,$3C,$1E	* "ENTER YOUR INITIALS"
	dc.b	$38,$00,$46,$32	*
	dc.b	$3E,$38,$00,$26	*
	dc.b	$30,$26,$3C,$26	*
	dc.b	$16,$2C,$BA,$80	*
m_hiscore
	dc.w	$0080,$0118		* X,Y co-ordinates
	dc.b	$24,$26,$22,$24	* "HIGH SCORE      000"
	dc.b	$00,$3A,$1A,$32	*
	dc.b	$38,$1E,$00,$00	*
	dc.b	$00,$00,$00,$00	*
	dc.b	$02,$02,$82,$80	*
m_range
	dc.w	$FE48,$0168		* X,Y co-ordinates
	dc.b	$1E,$30,$1E,$2E	* "ENEMY IN RANGE"
	dc.b	$46,$00,$26,$30	*
	dc.b	$00,$38,$16,$30	*
	dc.b	$22,$9E		*
m_motion
	dc.w	$FE48,$0148		* X,Y co-ordinates
	dc.b	$2E,$32,$3C,$26	* "MOTION BLOCKED BY OBJECT"
	dc.b	$32,$30,$00,$18	*
	dc.b	$2C,$32,$1A,$2A	*
	dc.b	$1E,$1C,$00,$18	*
	dc.b	$46,$00,$32,$18	*
	dc.b	$28,$1E,$1A,$BC	*
m_gameover
	dc.w	$FF90,$0060		* X,Y co-ordinates
	dc.b	$22,$16,$2E,$1E	* "GAME OVER"
	dc.b	$00,$32,$40,$1E	*
	dc.b	$B8,$80		*
m_start
	dc.w	$FF78,$0000		* X,Y co-ordinates
	dc.b	$34,$38,$1E,$3A	* "PRESS START"
	dc.b	$3A,$00,$3A,$3C	*
	dc.b	$16,$38,$BC,$80	*
m_score
	dc.w	$0080,$0140		* X,Y co-ordinates
	dc.b	$3A,$1A,$32,$38	* "SCORE     000"
	dc.b	$1E,$00,$00,$00	*
	dc.b	$00,$00,$02,$02	*
	dc.b	$82,$80		*
m_hiscores
	dc.w	$FF90,$00A0		* X,Y co-ordinates
	dc.b	$24,$26,$22,$24	* "HIGH SCORES"
	dc.b	$00,$3A,$1A,$32	*
	dc.b	$38,$1E,$BA,$80	*
m_1000s
	dc.w	$0000,$0000		* X,Y co-ordinates
	dc.b	$02,$02,$02,$80	* "000 "
m_gscore
	dc.w	$FF7C,$0060		* X,Y co-ordinates
	dc.b	$22,$38,$1E,$16	* "GREAT SCORE"
	dc.b	$3C,$00,$3A,$1A	*
	dc.b	$32,$38,$9E,$80	*
m_enter
	dc.w	$FF1C,$0020		* X,Y co-ordinates
	dc.b	$1E,$30,$3C,$1E	* "ENTER YOUR INITIALS"
	dc.b	$38,$00,$46,$32	*
	dc.b	$3E,$38,$00,$26	*
	dc.b	$30,$26,$3C,$26	*
	dc.b	$16,$2C,$BA,$80	*
m_change
	dc.w	$FE2C,$0000		* X,Y co-ordinates
	dc.b	$1A,$24,$16,$30	* "CHANGE LETTER WITH LEFT HAND CONTROLLER"
	dc.b	$22,$1E,$00,$2C	*
	dc.b	$1E,$3C,$3C,$1E	*
	dc.b	$38,$00,$42,$26	*
	dc.b	$3C,$24,$00,$2C	*
	dc.b	$1E,$20,$3C,$00	*
	dc.b	$24,$16,$30,$1C	*
	dc.b	$00,$1A,$32,$30	*
	dc.b	$3C,$38,$32,$2C	*
	dc.b	$2C,$1E,$B8,$80	*
m_select
	dc.w	$FE98,$FFE0		* X,Y co-ordinates
	dc.b	$3A,$1E,$2C,$1E	* "SELECT LETTER WITH FIRE BUTTON"
	dc.b	$1A,$3C,$00,$2C	*
	dc.b	$1E,$3C,$3C,$1E	*
	dc.b	$38,$00,$42,$26	*
	dc.b	$3C,$24,$00,$20	*
	dc.b	$26,$38,$1E,$00	*
	dc.b	$18,$3E,$3C,$3C	*
	dc.b	$32,$B0		*
m_bonus
	dc.w	$FEA0,$FEE8		* X,Y co-ordinates
	dc.b	$18,$32,$30,$3E	* "BONUS TANK AT "
	dc.b	$3A,$00,$3C,$16	*
	dc.b	$30,$2A,$00,$16	*
	dc.b	$3C,$80		*
m_1000
	dc.w	$0000,$0000		* X,Y co-ordinates
	dc.b	$02,$02,$02,$00	* "000 AND 100000"
	dc.b	$16,$30,$1C,$00	*
	dc.b	$04,$02,$02,$02	*
	dc.b	$02,$82		*
m_made
	dc.w	$FFB8,$FEE0		; X,Y co-ordinates
	dc.b	$40,$04,$12,$14	; "V189 LD 2007"
	dc.b	$00,$2C,$1C,$00	;
	dc.b	$06,$02,$02,$90	;

	ds.w	0			* ensure even address


*************************************************************************************
*
* SIN/COS table, returns values between $0000 and $7FFF. the last value should be
* $8000 but that can cause an overflow in the word length calculations and it's
* easier to fudge the table a bit. no one will ever notice.

sin_cos
	dc.w	$0000,$0192,$0324,$04B6,$0648,$07D9,$096B,$0AFB
	dc.w	$0C8C,$0E1C,$0FAB,$113A,$12C8,$1455,$15E2,$176E
	dc.w	$18F9,$1A83,$1C0C,$1D93,$1F1A,$209F,$2224,$23A7
	dc.w	$2528,$26A8,$2827,$29A4,$2B1F,$2C99,$2E11,$2F87
	dc.w	$30FC,$326E,$33DF,$354E,$36BA,$3825,$398D,$3AF3
	dc.w	$3C57,$3DB8,$3F17,$4074,$41CE,$4326,$447B,$45CD
	dc.w	$471D,$486A,$49B4,$4AFB,$4C40,$4D81,$4EC0,$4FFB
	dc.w	$5134,$5269,$539B,$54CA,$55F6,$571E,$5843,$5964
	dc.w	$5A82,$5B9D,$5CB4,$5DC8,$5ED7,$5FE4,$60EC,$61F1
	dc.w	$62F2,$63EF,$64E9,$65DE,$66CF,$67BD,$68A7,$698C
	dc.w	$6A6E,$6B4B,$6C24,$6CF9,$6DCA,$6E97,$6F5F,$7023
	dc.w	$70E3,$719E,$7255,$7308,$73B6,$7460,$7505,$75A6
	dc.w	$7642,$76D9,$776C,$77FB,$7885,$790A,$798A,$7A06
	dc.w	$7A7D,$7AEF,$7B5D,$7BC6,$7C2A,$7C89,$7CE4,$7D3A
	dc.w	$7D8A,$7DD6,$7E1E,$7E60,$7E9D,$7ED6,$7F0A,$7F38
	dc.w	$7F62,$7F87,$7FA7,$7FC2,$7FD9,$7FEA,$7FF6,$7FFE
	dc.w	$7FFF


*************************************************************************************
*
* arctangent table. returns the effective angle of the dx/dy ratio for scaled values
* of dx/dy of up to 0.99609375 or 255/256. this is only 1/8th of a full circle but
* it is easy to rotate and reflect these values to cover the other 7/8ths

atn_tab
	dc.b	$00,$00,$01,$01,$01,$02,$02,$02,$03,$03,$03,$03,$04,$04,$04,$05
	dc.b	$05,$05,$06,$06,$06,$07,$07,$07,$08,$08,$08,$09,$09,$09,$0A,$0A
	dc.b	$0A,$0A,$0B,$0B,$0B,$0C,$0C,$0C,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0F
	dc.b	$0F,$0F,$10,$10,$10,$11,$11,$11,$12,$12,$12,$12,$13,$13,$13,$14
	dc.b	$14,$14,$15,$15,$15,$15,$16,$16,$16,$17,$17,$17,$18,$18,$18,$18
	dc.b	$19,$19,$19,$1A,$1A,$1A,$1A,$1B,$1B,$1B,$1C,$1C,$1C,$1C,$1D,$1D
	dc.b	$1D,$1E,$1E,$1E,$1E,$1F,$1F,$1F,$1F,$20,$20,$20,$21,$21,$21,$21
	dc.b	$22,$22,$22,$22,$23,$23,$23,$23,$24,$24,$24,$24,$25,$25,$25,$26
	dc.b	$26,$26,$26,$27,$27,$27,$27,$28,$28,$28,$28,$29,$29,$29,$29,$2A
	dc.b	$2A,$2A,$2A,$2A,$2B,$2B,$2B,$2B,$2C,$2C,$2C,$2C,$2D,$2D,$2D,$2D
	dc.b	$2E,$2E,$2E,$2E,$2E,$2F,$2F,$2F,$2F,$30,$30,$30,$30,$30,$31,$31
	dc.b	$31,$31,$32,$32,$32,$32,$32,$33,$33,$33,$33,$33,$34,$34,$34,$34
	dc.b	$34,$35,$35,$35,$35,$35,$36,$36,$36,$36,$36,$37,$37,$37,$37,$37
	dc.b	$38,$38,$38,$38,$38,$39,$39,$39,$39,$39,$39,$3A,$3A,$3A,$3A,$3A
	dc.b	$3B,$3B,$3B,$3B,$3B,$3B,$3C,$3C,$3C,$3C,$3C,$3D,$3D,$3D,$3D,$3D
	dc.b	$3D,$3E,$3E,$3E,$3E,$3E,$3E,$3F,$3F,$3F,$3F,$3F,$3F,$40,$40,$40


*************************************************************************************
*
* eight background tiles. these are used to render the mountains, including the
* volcano outline, and the Earth in the sky. They are infinitely far away and you
* will never reach them no matter how long you drive for

background
	dc.w	backg_00-background		* background tile $00
	dc.w	backg_02-background		* background tile $02
	dc.w	backg_04-background		* background tile $04
	dc.w	backg_06-background		* background tile $06
	dc.w	backg_08-background		* background tile $08
	dc.w	backg_0A-background		* background tile $0A
	dc.w	backg_0C-background		* background tile $0C
	dc.w	backg_0E-background		* background tile $0E

* background tile $00

backg_00
	dc.w	$0040,$0000,$1FE0,$6020,$5C18,$0028,$6050,$0000
	dc.w	$6020,$1FE0,$6020,$0020,$7FC0,$1FC0,$0000,$0040
	dc.w	$6080,$1FC0,$6040,$0000,$0020,$0020,$7FC0,$0020
	dc.w	$1FE0,$1FE0,$6040,$1FF0,$6040,$1FF0,$6060,$00A0
	dc.w	$0030,$1FF4,$E005,$5AE0,$5AFC,$5AFA,$1FFD,$FFF4
	dc.w	$0003,$FFF4,$1FF7,$E00C,$1FFD,$E00C,$0003,$E00C
	dc.w	$0009,$E00C,$46E3,$46E0,$46FE,$000C,$FFF5,$0003
	dc.w	$5FF3,$1FFC,$5FF1,$5C5B,$1FF5,$5FFB,$1FF3,$5FFE
	dc.w	$1FF1,$4006,$0003,$001B,$5EA0,$1FFF,$A006,$000B
	dc.w	$A006,$1FFF,$BFFC,$0002,$BFFF,$4A09,$1FFD,$BFFD
	dc.w	$0003,$A001,$0001,$BFFD,$43A0,$0001,$4001,$1F6A
	dc.w	$0007,RTSL

* background tile $02

backg_02
	dc.w	$0000,$0020,$0030,$6040,$1FD0,$6020,$0030,$1FE0
	dc.w	$1FF0,$6020,$0020,$6040,$1FC0,$60A0,$0020,$7F80
	dc.w	$0020,$7FE0,$1FE0,$1FC0,$1FE0,$6060,$0000,$0080
	dc.w	$0020,$60A0,$1FE0,$0000,RTSL

* background tile $04

backg_04
	dc.w	$0020,$0000,$0000,$6040,$1FE0,$0000,$0020,$7FC0
	dc.w	$0000,$0040,$0020,$6040,$1FE0,$1FC0,$1FE0,$6060
	dc.w	$0020,$6020,$0020,$7FC0,$0000,$6020,$1FE0,$6020
	dc.w	$0010,$6020,$1FF0,$6020,$1FE0,$7FA0,$0020,$0060
	dc.w	$0020,$6040,$1FE0,$6040,$0010,$1FA0,$1FF0,$6020
	dc.w	$0010,$6020,$1FD0,$0000,$0008,$6060,$0018,$7FC0
	dc.w	$0010,$6020,$1FF0,$6040,$1FE8,$7FE0,$0028,$7FE0
	dc.w	$1FF0,$0040,$0000,$6020,$1FE0,$0000,RTSL

* background tile $06

backg_06
	dc.w	$0020,$0000,$1FE0,$6040,$0020,$1FC0,$1FE0,$6080
	dc.w	$0000,$00A0,$0020,$6060,$1FE0,$6020,$0020,$1FE0
	dc.w	$0020,$6020,$1FC0,$6020,$0000,$0020,$0040,$7FC0
	dc.w	$1FE0,$0020,$0020,$6020,$1FE0,$6020,$1FE0,$0000
	dc.w	RTSL

* background tile $08

backg_08
	dc.w	$0020,$0000,$0020,$6040,$1FC0,$6020,$0000,$0020
	dc.w	$0040,$7FC0,$1FE0,$0020,$0010,$6020,$1FD0,$6060
	dc.w	$0000,$0080,$0020,$60A0,$1FE0,$0000,RTSL

* background tile $0A

backg_0A
	dc.w	$0020,$0000,$0000,$6040,$1FE0,$60E0,$0030,$7FE0
	dc.w	$1FE0,$7FC0,$1FF0,$0060,$0040,$6060,$1FD8,$6040
	dc.w	$5418,$0060,$6040,$1FF9,$6003,$0005,$6005,$1FFA
	dc.w	$6003,$0008,$6005,$1FA0,$0000,RTSL

* background tile $0C

backg_0C
	dc.w	$0060,$0000,$1FA0,$6040,$0040,$6060,$1FC0,$6040
	dc.w	$0000,$0040,$0040,$7F80,$1FE0,$0040,$0020,$6040
	dc.w	$1FC0,$6080,$0020,$1FC0,$0010,$6040,$1FD0,$6020
	dc.w	$0030,$1FE0,$1FD0,$6060,RTSL

* background tile $0E

backg_0E
	dc.w	$0000,$00C0,$0020,$60E0,$1FE0,$6040,$0010,$1FE0
	dc.w	$0030,$6040,$1FC0,$0000,RTSL


*************************************************************************************
*
* vector character set

RTSL	EQU	$C000			* return from vector subroutine
JSRL	EQU	$A000-2		* vector subroutine call
JMPL	EQU	$E000-2		* vector jump
MASK	EQU	$1FFF			* address mask

char_a
	dc.w	$48C0,$44C4,$5CC4,$58C0,$4418,$40C8,$5C04,RTSL
char_b
	dc.w	$4CC0,$40C6,$5EC2,$5EC0,$5EDE,$40DA,$4006,$5EC2
	dc.w	$5EC0,$5EDE,$40DA,((char_sp-*)&MASK)+JMPL
char_c
	dc.w	$4CC0,$40C8,$5418,((char_ul-*)&MASK)+JMPL
char_d
	dc.w	$4CC0,$40C4,$5CC4,$5CC0,$5CDC,$40DC
	dc.w	((char_sp-*)&MASK)+JMPL
char_e
	dc.w	$40C8,$4018
char_f
	dc.w	$4CC0,$40C8,$5A1E,$40DA
char_x6
	dc.w	$5A0C,RTSL
char_g
	dc.w	$4CC0,$40C8,$5CC0,$5C1C,$40C4,$5CC0
	dc.w	((char_x3-*)&MASK)+JMPL
char_h
	dc.w	$4CC0,$5A00,$40C8,$4600,((char_x4-*)&MASK)+JMPL
char_i
	dc.w	$40C8,$4C18
char_x9
	dc.w	$40C8,$401C
char_xb
	dc.w	$54C0,$4008,RTSL
char_j
	dc.w	$4400,$5CC4,$40C4,((char_x5-*)&MASK)+JMPL
char_k
	dc.w	$4CC0,$4006,$5ADA,$5AC6,$4006,RTSL
char_l
	dc.w	$4C00,$54C0,((char_ul-*)&MASK)+JMPL
char_m
	dc.w	$4CC0,$5CC4,$44C4,((char_x4-*)&MASK)+JMPL
char_n
	dc.w	$4CC0,$54C8,((char_x5-*)&MASK)+JMPL
char_o
	dc.w	$4CC0,$40C8,$54C0
char_x3
	dc.w	$40D8
char_sp
	dc.w	$400C,RTSL
char_p
	dc.w	$4CC0,$40C8,$5AC0,$40D8,((char_x6-*)&MASK)+JMPL
char_q
	dc.w	$4CC0,$40C8,$58C0,$5CDC,$40DC,$4404,$5CC4
	dc.w	((char_x7-*)&MASK)+JMPL
char_r
	dc.w	$4CC0,$40C8,$5AC0,$40D8,$4002,$5AC6
	dc.w	((char_x7-*)&MASK)+JMPL
char_s
	dc.w	$40C8,$46C0,$40D8,$46C0,$40C8
	dc.w	((char_x8-*)&MASK)+JMPL
char_t
	dc.w	$4C00,((char_x9-*)&MASK)+JMPL
char_u
	dc.w	$4C00,$54C0,$40C8
char_x5
	dc.w	$4CC0
char_x8
	dc.w	$5404,RTSL
char_v
	dc.w	$4C00,$54C4,$4CC4,((char_x8-*)&MASK)+JMPL
char_w
	dc.w	$4C00,$54C0,$44C4,$5CC4,((char_x5-*)&MASK)+JMPL
char_x
	dc.w	$4CC8,$4018,$54C8,((char_xa-*)&MASK)+JMPL
char_y
	dc.w	$4004,$48C0,$44DC,$4008,$5CDC,$5808,RTSL
char_z
	dc.w	$4C00,$40C8,$54D8,((char_ul-*)&MASK)+JMPL
char_on
	dc.w	$4C04,((char_xb-*)&MASK)+JMPL
char_tw
	dc.w	$4C00,$40C8,$5AC0,$40D8,$5AC0
char_ul
	dc.w	$40C8
char_x7
	dc.w	$4004,RTSL
char_th
	dc.w	$4C00
char_x1
	dc.w	$40C8,$54C0,$40D8,$4600,$40C8,$5A04,RTSL
char_fo
	dc.w	$4C00,$5AC0,$40C8,$4600,((char_x4-*)&MASK)+JMPL
char_si
	dc.w	$4600,$40C8,$5AC0,$40D8,$4CC0,$540C,RTSL
char_se
	dc.w	$4C00
char_x2
	dc.w	$40C8
char_x4
	dc.w	$54C0
char_xa
	dc.w	$4004,RTSL
char_ei
	dc.w	$4CC0,((char_x1-*)&MASK)+JMPL
char_ni
	dc.w	$4608,$40D8,$46C0,((char_x2-*)&MASK)+JMPL

* character subroutine addresses table

char_set
	dc.w	char_sp-char_set			* " "		$00
	dc.w	char_o-char_set			* "0"		$02
	dc.w	char_on-char_set			* "1"		$04
	dc.w	char_tw-char_set			* "2"		$06
	dc.w	char_th-char_set			* "3"		$08
	dc.w	char_fo-char_set			* "4"		$0A
	dc.w	char_s-char_set			* "5"		$0C
	dc.w	char_si-char_set			* "6"		$0E
	dc.w	char_se-char_set			* "7"		$10
	dc.w	char_ei-char_set			* "8"		$12
	dc.w	char_ni-char_set			* "9"		$14
	dc.w	char_a-char_set			* "A"		$16
	dc.w	char_b-char_set			* "B"		$18
	dc.w	char_c-char_set			* "C"		$1A
	dc.w	char_d-char_set			* "D"		$1C
	dc.w	char_e-char_set			* "E"		$1E
	dc.w	char_f-char_set			* "F"		$20
	dc.w	char_g-char_set			* "G"		$22
	dc.w	char_h-char_set			* "H"		$24
	dc.w	char_i-char_set			* "I"		$26
	dc.w	char_j-char_set			* "J"		$28
	dc.w	char_k-char_set			* "K"		$2A
	dc.w	char_l-char_set			* "L"		$2C
	dc.w	char_m-char_set			* "M"		$2E
	dc.w	char_n-char_set			* "N"		$30
	dc.w	char_o-char_set			* "O"		$32
	dc.w	char_p-char_set			* "P"		$34
	dc.w	char_q-char_set			* "Q"		$36
	dc.w	char_r-char_set			* "R"		$38
	dc.w	char_s-char_set			* "S"		$3A
	dc.w	char_t-char_set			* "T"		$3C
	dc.w	char_u-char_set			* "U"		$3E
	dc.w	char_v-char_set			* "V"		$40
	dc.w	char_w-char_set			* "W"		$42
	dc.w	char_x-char_set			* "X"		$44
	dc.w	char_y-char_set			* "Y"		$46
	dc.w	char_z-char_set			* "Z"		$48
	dc.w	char_sp-char_set			* " "		$4A
	dc.w	char_ul-char_set			* "_"		$4C
	dc.w	char_cc-char_set			* "(c)"	$4E
	dc.w	char_pp-char_set			* "(p)"	$50

char_br
	dc.w	$4200,$48C0,$42C4,$5EC4,$58C0,$5EDC,$42DC,RTSL
char_cc
	dc.w	((char_br-*)&MASK)+JSRL,$0001,$000B,$40DD,$47C0
	dc.w	$40C3,$1FED,$000D,RTSL
char_pp
	dc.w	((char_br-*)&MASK)+JSRL,$0001,$0005,$47C0,$40C3
	dc.w	$5DC0,$40DD,$1FF3,$0013,RTSL


*************************************************************************************
*
* preset high score table initials

t_pre_hisc
	dc.l	$2C1E1E00				* "LEE "
	dc.l	$48321E00				* "ZOE "
	dc.l	$34383220				* "PROF"
	dc.l	$1E1C3800				* "EDR "
	dc.l	$181E162A				* "BEAK"
	dc.l	$16441E2C				* "AXEL"
	dc.l	$30324032				* "NOVO"
	dc.l	$1C163020				* "DANF"
	dc.l	$301E262C				* "NEIL"
	dc.l	$281E1C00				* "JED "


*************************************************************************************
*
* tank outline for lives remeining

t_outline
	dc.w	$43DD,$0003,$C009,$0006,$C003,$1FF7,$C024,$5DDD
	dc.w	$0000,$DFDC,$4609,$0000,$C015,$1FFD,$C000,$0000
	dc.w	$DFF7,$1FF7,$001B,RTSL


*************************************************************************************
*
* progressive screen cracks drawn when the player dies. sequence is crack 7, crack
* 7/6, crack 7/6/5 ... crack 7/6/5/4/3/2/1/0

* screen crack 7

s_crack_7
	dc.w	$8040,$0032,$1F9C,$0000,$DFB5,$1F9C,$0023,$0064
	dc.w	$C028,$0064,$DF9C,$0019,$00FA,$1F83,$DF6A,$1FCE
	dc.w	$C064,RTSL

* screen crack 6

s_crack_6
	dc.w	((s_crack_7-*)&MASK)+JSRL
	dc.w	$0000,$C050,$1FCE,$1F24,$1FCE,$C041,$0096,$1F9C
	dc.w	$1FD3,$C000,$0091,$1FE7,$002D,$DF6A,$001E,$00E1
	dc.w	$1FB5,$DFB5,$0019,$00FA,$005F,$C00A,$1FA1,$1FF6
	dc.w	$003C,$C064,RTSL

* screen crack 5

s_crack_5
	dc.w	((s_crack_6-*)&MASK)+JSRL
	dc.w	$003C,$C064,$002D,$1F9C,$1F97,$C000,$1FF6,$1EED
	dc.w	$005F,$DF97,$1F83,$1F88,$000A,$DFCE,$1FF6,$0032
	dc.w	$1F88,$DF7E,$1FBA,$0131,$1FFB,$DFA6,$1F9C,$00BE
	dc.w	$1F74,$C02D,$00F0,$006E,$1FD8,$C000,RTSL

* screen crack 4

s_crack_4
	dc.w	((s_crack_5-*)&MASK)+JSRL
	dc.w	$0000,$C069,$1F38,$1F29,$1F6A,$DFB0,$0186,$1F65
	dc.w	$1FCE,$C000,$0032,$0000,$0019,$DFAB,$0127,$0078
	dc.w	$0073,$DF88,$000F,$00AF,$1F7E,$DFC9,$1FE7,$01E0
	dc.w	$0000,$C046,$0069,$1F3D,$1FC4,$C019,$0055,$C04B
	dc.w	RTSL

* screen crack 3

s_crack_3
	dc.w	((s_crack_4-*)&MASK)+JSRL
	dc.w	$0041,$DFF1,$1FD8,$0032,$1FE7,$DFDD,$1E2F,$1FD8
	dc.w	$0064,$C069,$1F60,$1FB0,$003C,$DFE7,$1FC4,$DFF6
	dc.w	$1EA2,$1F06,$003C,$DFDD,$1FC4,$DFD8,$0190,$1F8D
	dc.w	$1FE2,$DFDD,RTSL

* screen crack 2

s_crack_2
	dc.w	((s_crack_3-*)&MASK)+JSRL
	dc.w	$1FBA,$C032,$001E,$1F9C,$0028,$C032,$1FEC,$01DB
	dc.w	$1FCE,$DFCE,$0258,$0087,$1FCE,$C00F,$1EAC,$000F
	dc.w	$1F92,$C05F,RTSL

* screen crack 1

s_crack_1
	dc.w	((s_crack_2-*)&MASK)+JSRL
	dc.w	$004B,$C073,$1F8D,$1FA6,$0028,$DFE7,$1FBA,$1D21
	dc.w	$1FF1,$DFBF,RTSL

* screen crack 0

s_crack_0
	dc.w	((s_crack_1-*)&MASK)+JSRL
	dc.w	$002D,$DFAB,$1FA1,$0032,$0032,$C023,$1FF1,$0357
	dc.w	$003C,$DFE2,$001E,$C050,RTSL

* screen crack subroutine calls

s_crack	EQU	*-2
	dc.w	((s_crack_0-*)&MASK)+JMPL	* screen crack 0
	dc.w	((s_crack_0-*)&MASK)+JMPL	* screen crack 0
	dc.w	((s_crack_0-*)&MASK)+JMPL	* screen crack 0
	dc.w	((s_crack_0-*)&MASK)+JMPL	* screen crack 0
	dc.w	((s_crack_0-*)&MASK)+JMPL	* screen crack 0
	dc.w	((s_crack_1-*)&MASK)+JMPL	* screen crack 1
	dc.w	((s_crack_2-*)&MASK)+JMPL	* screen crack 2
	dc.w	((s_crack_3-*)&MASK)+JMPL	* screen crack 3
	dc.w	((s_crack_4-*)&MASK)+JMPL	* screen crack 4
	dc.w	((s_crack_5-*)&MASK)+JMPL	* screen crack 5
	dc.w	((s_crack_6-*)&MASK)+JMPL	* screen crack 6
	dc.w	((s_crack_7-*)&MASK)+JMPL	* screen crack 7
s_crack_e	EQU	*-s_crack


*************************************************************************************
*
* gunsight, no target

g_notarget
	dc.w	$8040,$1F51,$0000,$0064,$6000,$0019,$1FB5,$1FE7
	dc.w	$6000,$0000,$6096,$0019,$6000,$0064,$0000,$0019
	dc.w	$6000,$0000,$7F6A,$1FE7,$6000,$0019,$004B,$0064
	dc.w	$6000,RTSL

* gunsight, target

g_target
	dc.w	$8040,$1F51,$0000,$0064,$E000,$0028,$6000,$0000
	dc.w	$1FDD,$1FD8,$FFD8,$0000,$E096,$0028,$FFD8,$0046
	dc.w	$0000,$0028,$E028,$0000,$FF6A,$1FD8,$E028,$0000
	dc.w	$0023,$0028,$6000,$0064,$E000,RTSL


*************************************************************************************
*
* radar outline

obj_radar
	dc.w	$8040,$013C,$0044,$40FC,$1FC4,$1FC4,$5CE0,$0044
	dc.w	$1FC4,$40FC,$0000,$0044,$0034,$BFDC,$0008,$0024
	dc.w	$44E0,$1FF0,$0024,$1FCC,$BFDC,RTSL


*************************************************************************************
*
* BATTLEZONE world objects. this is the arrangement of cubes and pyramids that you
* have to drive around

* object x co-ordinates

obj_x	EQU -$2A
	dc.w	$2000,$0000,$0000,$4000,$8000,$8000,$8000,$4000
	dc.w	$3000,$C000,$F700,$C800,$D800,$9400,$9800,$E800
	dc.w	$7000,$7800,$4000,$2400,$2C00

* object type and orientation

world_objcts
	dc.b	obj_tpmd,$00			* tall pyramid
	dc.b	obj_scbe,$10			* short cube
	dc.b	obj_tpmd,$20			* tall pyramid
	dc.b	obj_scbe,$40			* short cube
	dc.b	obj_tpmd,$18			* tall pyramid
	dc.b	obj_pmid,$28			* pyramid
	dc.b	obj_cube,$30			* cube
	dc.b	obj_pmid,$38			* pyramid
	dc.b	obj_cube,$40			* cube
	dc.b	obj_scbe,$48			* short cube
	dc.b	obj_tpmd,$50			* tall pyramid
	dc.b	obj_pmid,$58			* pyramid
	dc.b	obj_cube,$60			* cube
	dc.b	obj_scbe,$68			* short cube
	dc.b	obj_tpmd,$70			* tall pyramid
	dc.b	obj_pmid,$78			* pyramid
	dc.b	obj_cube,$80			* cube
	dc.b	obj_scbe,$88			* short cube
	dc.b	obj_tpmd,$90			* tall pyramid
	dc.b	obj_pmid,$98			* pyramid
	dc.b	obj_cube,$A0			* cube
	dc.w	-1					* end marker

* object y co-ordinates

obj_y	EQU *-world_objcts
	dc.w	$2000,$4000,$8000,$8000,$8000,$4000,$0000,$0000
	dc.w	$5000,$1800,$4400,$4000,$8C00,$0C00,$E800,$E400
	dc.w	$9C00,$CC00,$B400,$BC00,$F400

* object sizes

obj_s	EQU *-world_objcts
	dc.w	$8000,$0000,$8000,$0000,$8000,$FFFF,$FFFF,$FFFF
	dc.w	$FFFF,$0000,$8000,$FFFF,$FFFF,$0000,$8000,$FFFF
	dc.w	$FFFF,$0000,$8000,$FFFF,$FFFF


*************************************************************************************
*
* object descriptions. these are all the objects you will see in the environment
* each object is described by a series of 3D co-ordinates from it's origin and a
* list of vertex instructions describing how to join the dots to render the object

* object list vertex pointers

obj_verts
obj_scbe	EQU	*-obj_verts
	dc.w	vert_cube-vert_tables		* short cube
obj_tank	EQU	*-obj_verts
	dc.w	vert_tank-vert_tables		* tank
obj_stnk	EQU	*-obj_verts
	dc.w	vert_super-vert_tables		* super tank
obj_shel	EQU	*-obj_verts
	dc.w	vert_shell-vert_tables		* shell
obj_tpmd	EQU	*-obj_verts
	dc.w	vert_pmid-vert_tables		* tall pyramid
obj_pmid	EQU	*-obj_verts
	dc.w	vert_pmid-vert_tables		* pyramid
obj_cube	EQU	*-obj_verts
	dc.w	vert_cube-vert_tables		* cube
obj_rdar	EQU	*-obj_verts
	dc.w	vert_radar-vert_tables		* tank radar dish
obj_miss	EQU	*-obj_verts
	dc.w	vert_miss-vert_tables		* missile
obj_expn	EQU	*-obj_verts
	dc.w	vert_radar-vert_tables		* tank fragment 0
	dc.w	vert_frag_0-vert_tables		* tank fragment 1
	dc.w	vert_frag_1-vert_tables		* tank fragment 2
	dc.w	vert_frag_2-vert_tables		* tank fragment 3
	dc.w	vert_frag_1-vert_tables		* tank fragment 4
	dc.w	vert_frag_0-vert_tables		* tank fragment 5
	dc.w	vert_frag_0-vert_tables		* tank fragment 6
	dc.w	vert_frag_1-vert_tables		* missile fragment 0
	dc.w	vert_frag_6-vert_tables		* missile fragment 1
	dc.w	vert_frag_0-vert_tables		* missile fragment 2
	dc.w	vert_frag_8-vert_tables		* missile fragment 3
	dc.w	vert_frag_0-vert_tables		* missile fragment 4
	dc.w	vert_frag_6-vert_tables		* missile fragment 5
obj_tanr	EQU	*-obj_verts
	dc.w	vert_track-vert_tables		* rear track anim 0
	dc.w	vert_track-vert_tables		* rear track anim 1
	dc.w	vert_track-vert_tables		* rear track anim 2
	dc.w	vert_track-vert_tables		* rear track anim 3
obj_tanf	EQU	*-obj_verts
	dc.w	vert_track-vert_tables		* front track anim 0
	dc.w	vert_track-vert_tables		* front track anim 1
	dc.w	vert_track-vert_tables		* front track anim 2
	dc.w	vert_track-vert_tables		* front track anim 3
	dc.w	vert_expsn-vert_tables		* shell explosion
obj_sacr	EQU	*-obj_verts
	dc.w	vert_sauc-vert_tables		* saucer
obj_easy	EQU	*-obj_verts
	dc.w	vert_easy-vert_tables		* "EASY"
obj_zone	EQU	*-obj_verts
	dc.w	vert_zone-vert_tables		* "ZONE"
	dc.w	vert_shadw-vert_tables		* missile shadow 0
	dc.w	vert_shadw-vert_tables		* missile shadow 1
	dc.w	vert_shadw-vert_tables		* missile shadow 2
	dc.w	vert_shadw-vert_tables		* missile shadow 3
	dc.w	vert_shadw-vert_tables		* missile shadow 4
	dc.w	vert_shadw-vert_tables		* missile shadow 5
	dc.w	vert_shadw-vert_tables		* missile shadow 6
	dc.w	vert_shadw-vert_tables		* missile shadow 7

* object list points pointers

obj_points
	dc.w	cord_scube-cord_tables		* short cube
	dc.w	cord_tank-cord_tables		* tank
	dc.w	cord_super-cord_tables		* super tank
	dc.w	cord_shell-cord_tables		* shell
	dc.w	cord_tpmid-cord_tables		* tall pyramid
	dc.w	cord_pmid-cord_tables		* pyramid
	dc.w	cord_cube-cord_tables		* cube
	dc.w	cord_radar-cord_tables		* tank radar dish
	dc.w	cord_miss-cord_tables		* missile
	dc.w	cord_radar-cord_tables		* tank fragment 0
	dc.w	cord_frag_0-cord_tables		* tank fragment 1
	dc.w	cord_frag_1-cord_tables		* tank fragment 2
	dc.w	cord_frag_2-cord_tables		* tank fragment 3
	dc.w	cord_frag_1-cord_tables		* tank fragment 4
	dc.w	cord_frag_0-cord_tables		* tank fragment 5
	dc.w	cord_frag_0-cord_tables		* tank fragment 6
	dc.w	cord_frag_1-cord_tables		* missile fragment 0
	dc.w	cord_frag_6-cord_tables		* missile fragment 1
	dc.w	cord_frag_0-cord_tables		* missile fragment 2
	dc.w	cord_frag_8-cord_tables		* missile fragment 3
	dc.w	cord_frag_0-cord_tables		* missile fragment 4
	dc.w	cord_frag_6-cord_tables		* missile fragment 5
	dc.w	cord_rear_0-cord_tables		* rear track anim 0
	dc.w	cord_rear_1-cord_tables		* rear track anim 1
	dc.w	cord_rear_2-cord_tables		* rear track anim 2
	dc.w	cord_rear_3-cord_tables		* rear track anim 3
	dc.w	cord_front_0-cord_tables	* front track anim 0
	dc.w	cord_front_1-cord_tables	* front track anim 1
	dc.w	cord_front_2-cord_tables	* front track anim 2
	dc.w	cord_front_3-cord_tables	* front track anim 3
	dc.w	cord_expsn-cord_tables		* shell explosion
	dc.w	cord_sauc-cord_tables		* saucer
	dc.w	cord_easy-cord_tables		* "EASY"
	dc.w	cord_zone-cord_tables		* "ZONE"
	dc.w	cord_shadw_0-cord_tables	* missile shadow 0
	dc.w	cord_shadw_1-cord_tables	* missile shadow 1
	dc.w	cord_shadw_2-cord_tables	* missile shadow 2
	dc.w	cord_shadw_3-cord_tables	* missile shadow 3
	dc.w	cord_shadw_4-cord_tables	* missile shadow 4
	dc.w	cord_shadw_5-cord_tables	* missile shadow 5
	dc.w	cord_shadw_6-cord_tables	* missile shadow 6
	dc.w	cord_shadw_7-cord_tables	* missile shadow 7


*************************************************************************************
*
* object vertex and co-ordinate tables. some objects share vertex tables as they only
* differ in their co-ordinates, e.g. the short and tall pyramids

* pyramid vertex table
* tall pyramid vertex table

vert_tables						* vertex pointers are offset from this base

vert_pmid
	dc.b	$03,$A1,$24,$0C,$04,$1C,$24,$14
	dc.b	$1C,$12,$0C,$FF

* pyramid co-ordinates table

cord_tables						* coordinate pointers are offset from this base

cord_pmid
	dc.w	$04
	dc.w	$FE00,$FE00,$FEC0
	dc.w	$FE00,$0200,$FEC0
	dc.w	$0200,$0200,$FEC0
	dc.w	$0200,$FE00,$FEC0
	dc.w	$0000,$0000,$0140

* tall pyramid co-ordinates table

cord_tpmid
	dc.w	$04
	dc.w	$FCE0,$FCE0,$FEC0
	dc.w	$FCE0,$0320,$FEC0
	dc.w	$0320,$0320,$FEC0
	dc.w	$0320,$FCE0,$FEC0
	dc.w	$0000,$0000,$0190

* cube vertex table
* short cube vertex table

vert_cube
	dc.b	$03,$A1,$0C,$14,$1C,$04,$24,$2C
	dc.b	$34,$3C,$24,$2A,$0C,$12,$34,$3A
	dc.b	$1C,$FF

* cube co-ordinates table

cord_cube
	dc.w	$07
	dc.w	$FE00,$FE00,$FEC0
	dc.w	$FE00,$0200,$FEC0
	dc.w	$0200,$0200,$FEC0
	dc.w	$0200,$FE00,$FEC0
	dc.w	$FE00,$FE00,$0140
	dc.w	$FE00,$0200,$0140
	dc.w	$0200,$0200,$0140
	dc.w	$0200,$FE00,$0140

* short cube co-ordinates table

cord_scube
	dc.w	$07
	dc.w	$FD80,$FD80,$FEC0
	dc.w	$FD80,$0280,$FEC0
	dc.w	$0280,$0280,$FEC0
	dc.w	$0280,$FD80,$FEC0
	dc.w	$FD80,$FD80,$FFD8
	dc.w	$FD80,$0280,$FFD8
	dc.w	$0280,$0280,$FFD8
	dc.w	$0280,$FD80,$FFD8

* tank vertex table

vert_tank
	dc.b	$BB,$A1,$B4,$62,$6C,$72,$A4,$94
	dc.b	$7C,$74,$8C,$84,$9C,$AC,$8C,$7A
	dc.b	$84,$9A,$94,$A2,$AC,$1B,$04,$24
	dc.b	$3C,$34,$14,$1C,$3C,$5C,$54,$34
	dc.b	$2C,$4C,$54,$6C,$4C,$44,$5C,$64
	dc.b	$44,$24,$2C,$0C,$14,$0A,$04,$FF

* tank co-ordinates table

cord_tank
	dc.w	$17
	dc.w	$FD20,$FE00,$FEC0
	dc.w	$FD20,$0200,$FEC0
	dc.w	$03C8,$0200,$FEC0
	dc.w	$03C8,$FE00,$FEC0
	dc.w	$FC00,$FDC8,$FF30
	dc.w	$FC00,$0238,$FF30
	dc.w	$04E0,$0238,$FF30
	dc.w	$04E0,$FDC8,$FF30
	dc.w	$FD58,$FEA8,$FF88
	dc.w	$FD58,$0158,$FF88
	dc.w	$02A8,$0158,$FF88
	dc.w	$02A8,$FEA8,$FF88
	dc.w	$FE00,$FF58,$0030
	dc.w	$FE00,$00A8,$0030
	dc.w	$FF80,$FFD8,$FFF8
	dc.w	$FF80,$0028,$FFF8
	dc.w	$0080,$0028,$FFD0
	dc.w	$0080,$FFD8,$FFD0
	dc.w	$0460,$0028,$FFF8
	dc.w	$0460,$0028,$FFD0
	dc.w	$0460,$FFD8,$FFF8
	dc.w	$0460,$FFD8,$FFD0
	dc.w	$FE00,$0000,$0030
	dc.w	$FE00,$0000,$0050

* shell vertex table

vert_shell
	dc.b	$03,$E1,$24,$0C,$04,$1C,$24,$14
	dc.b	$1C,$12,$0C,$FF

* shell co-ordinates table

cord_shell
	dc.w	$05
	dc.w	$FFD8,$FFD8,$FFD0
	dc.w	$FFD8,$FFD8,$FFF8
	dc.w	$FFD8,$0028,$FFF8
	dc.w	$FFD8,$0028,$FFD0
	dc.w	$0050,$0000,$FFE4

* rear track anim 0 vertex table
* rear track anim 1 vertex table
* rear track anim 2 vertex table
* rear track anim 3 vertex table
* front track anim 0 vertex table
* front track anim 1 vertex table
* front track anim 2 vertex table
* front track anim 3 vertex table

vert_track
	dc.b	$03,$81,$0C,$12,$1C,$22,$2C,$FF

* rear track anim 0 co-ordinates table

cord_rear_0
	dc.w	$06
	dc.w	$FC4C,$FDD8,$FF14
	dc.w	$FC4C,$0228,$FF14
	dc.w	$FCB4,$FDE8,$FEEC
	dc.w	$FCB4,$0218,$FEEC
	dc.w	$FD20,$FDFC,$FEC4
	dc.w	$FD20,$0204,$FEC4

* rear track anim 1 co-ordinates table

cord_rear_1
	dc.w	$06
	dc.w	$FC34,$FDD4,$FF1C
	dc.w	$FC34,$022C,$FF1C
	dc.w	$FC9C,$FDE4,$FEF4
	dc.w	$FC9C,$021C,$FEF4
	dc.w	$FD04,$FDF8,$FECC
	dc.w	$FD04,$0208,$FECC

* rear track anim 2 co-ordinates table

cord_rear_2
	dc.w	$06
	dc.w	$FC18,$FDCC,$FF28
	dc.w	$FC18,$0234,$FF28
	dc.w	$FC80,$FDE0,$FF00
	dc.w	$FC80,$0220,$FF00
	dc.w	$FCE8,$FDF0,$FED8
	dc.w	$FCE8,$0210,$FED8

* rear track anim 3 co-ordinates table

cord_rear_3
	dc.w	$06
	dc.w	$FC00,$FDC8,$FF30
	dc.w	$FC00,$0238,$FF30
	dc.w	$FC68,$FDDC,$FF08
	dc.w	$FC68,$0224,$FF08
	dc.w	$FCD0,$FDEC,$FEE0
	dc.w	$FCD0,$0214,$FEE0

* front track anim 0 co-ordinates table

cord_front_0
	dc.w	$06
	dc.w	$04E0,$FDC8,$FF30
	dc.w	$04E0,$0238,$FF30
	dc.w	$0480,$FDDC,$FF08
	dc.w	$0480,$0224,$FF08
	dc.w	$0420,$FDEC,$FEE0
	dc.w	$0420,$0214,$FEE0

* front track anim 1 co-ordinates table

cord_front_1
	dc.w	$06
	dc.w	$04C8,$FDCC,$FF28
	dc.w	$04C8,$0234,$FF28
	dc.w	$0468,$FDE0,$FF00
	dc.w	$0468,$0220,$FF00
	dc.w	$0408,$FDF0,$FED8
	dc.w	$0408,$0210,$FED8

* front track anim 2 co-ordinates table

cord_front_2
	dc.w	$06
	dc.w	$04B0,$FDD4,$FF1C
	dc.w	$04B0,$022C,$FF1C
	dc.w	$0450,$FDE4,$FEF4
	dc.w	$0450,$021C,$FEF4
	dc.w	$03F0,$FDF8,$FECC
	dc.w	$03F0,$0208,$FECC

* front track anim 3 co-ordinates table

cord_front_3
	dc.w	$06
	dc.w	$0498,$FDD8,$FF14
	dc.w	$0498,$0228,$FF14
	dc.w	$0438,$FDE8,$FEEC
	dc.w	$0438,$0218,$FEEC
	dc.w	$03D8,$FDFC,$FEC4
	dc.w	$03D8,$0204,$FEC4

* explosion vertex table

vert_expsn
	dc.b	$03,$05,$FF,$FF

* explosion co-ordinates table

cord_expsn
	dc.w	$01
	dc.w	$0000,$0000,$0000

* tank fragment 3 vertex table

vert_frag_2
	dc.b	$03,$A1,$0C,$14,$1C,$04,$24,$2C
	dc.b	$0C,$2A,$14,$1A,$24,$32,$64,$54
	dc.b	$3C,$34,$4C,$44,$5C,$6C,$4C,$3A
	dc.b	$44,$5A,$54,$62,$6C,$FF

* tank fragment 3 co-ordinates table

cord_frag_2
	dc.w	$0E
	dc.w	$FDB4,$FEA8,$FF6C
	dc.w	$FDB4,$0158,$FF6C
	dc.w	$024C,$0158,$FE18
	dc.w	$024C,$FEA8,$FE18
	dc.w	$FEF0,$FF58,$FFD0
	dc.w	$FEF0,$00A8,$FFD0
	dc.w	$0000,$FFD8,$FF44
	dc.w	$0000,$0028,$FF44
	dc.w	$00B4,$0028,$FEE0
	dc.w	$00B4,$FFD8,$FEE0
	dc.w	$0438,$0028,$FE0C
	dc.w	$0410,$0028,$FDE8
	dc.w	$0438,$FFD8,$FE0C
	dc.w	$0410,$FFD8,$FDE8

* tank fragment 1 vertex table
* tank fragment 5 vertex table
* tank fragment 6 vertex table
* missile fragment 2 vertex table
* missile fragment 4 vertex table

vert_frag_0
	dc.b	$03,$A1,$1C,$2C,$14,$04,$0C,$14
	dc.b	$2C,$24,$0C,$22,$1C,$FF

* tank fragment 1 co-ordinates table
* tank fragment 5 co-ordinates table
* tank fragment 6 co-ordinates table
* missile fragment 2 co-ordinates table
* missile fragment 4 co-ordinates table

cord_frag_0
	dc.w	$06
	dc.w	$00DC,$0000,$FEF0
	dc.w	$FEC0,$FFB0,$FF44
	dc.w	$0154,$0050,$FFA0
	dc.w	$FF48,$0000,$FE9C
	dc.w	$FF84,$FFB0,$FF00
	dc.w	$FF8C,$0050,$FF30

* tank fragment 2 vertex table
* tank fragment 4 vertex table
* missile fragment 0 vertex table

vert_frag_1
	dc.b	$03,$A1,$0C,$14,$1C,$04,$24,$34
	dc.b	$3C,$2C,$24,$2A,$0C,$3A,$14,$1A
	dc.b	$34,$FF

* tank fragment 2 co-ordinates table
* tank fragment 4 co-ordinates table
* missile fragment 0 co-ordinates table

cord_frag_1
	dc.w	$08
	dc.w	$FF10,$FF88,$FEC0
	dc.w	$FE88,$0040,$FEE8
	dc.w	$02D0,$00A0,$FE80
	dc.w	$0280,$FF88,$FEC0
	dc.w	$FFD8,$FFC0,$FFB0
	dc.w	$0000,$0020,$FFC4
	dc.w	$0038,$FF60,$FF38
	dc.w	$0078,$00C8,$FF10

* missile fragment 1 vertex table
* missile fragment 5 vertex table

vert_frag_6
	dc.b	$0B,$A1,$14,$1C,$3C,$34,$2C,$24
	dc.b	$04,$0C,$2C,$32,$14,$FF

* missile fragment 1 co-ordinates table
* missile fragment 5 co-ordinates table

cord_frag_6
	dc.w	$08
	dc.w	$FED4,$FFB8,$FF48
	dc.w	$FF18,$FF58,$FF48
	dc.w	$FF18,$FEF0,$FF14
	dc.w	$FED4,$FEF0,$FEE4
	dc.w	$FFA0,$00A8,$FF34
	dc.w	$0028,$000C,$FF40
	dc.w	$0028,$FEFC,$FEBC
	dc.w	$FFA0,$FF18,$FE6C

* missile fragment 3 vertex table

vert_frag_8
	dc.b	$03,$A1,$14,$0C,$1C,$04,$0C,$12
	dc.b	$1C,$FF

* missile fragment 3 co-ordinates table

cord_frag_8
	dc.w	$04
	dc.w	$FFB0,$FFF4,$FEE0
	dc.w	$01D8,$0070,$FE50
	dc.w	$0320,$FFD4,$000C
	dc.w	$0058,$FFF0,$FEF4

* tank radar dish vertex table

vert_radar
	dc.b	$03,$A1,$0C,$14,$1C,$04,$24,$2C
	dc.b	$34,$3C,$24,$3A,$1C,$FF

* tank radar dish co-ordinates table

cord_radar
	dc.w	$08
	dc.w	$0000,$FFB0,$0050
	dc.w	$0050,$FF60,$0064
	dc.w	$0050,$FF60,$0078
	dc.w	$0000,$FFB0,$008C
	dc.w	$0000,$0050,$0050
	dc.w	$0050,$00A0,$0064
	dc.w	$0050,$00A0,$0078
	dc.w	$0000,$0050,$008C

* missile vertex table

vert_miss
	dc.b	$6B,$A1,$64,$34,$04,$0C,$3C,$44
	dc.b	$4C,$54,$5C,$34,$3C,$64,$44,$14
	dc.b	$1C,$4C,$64,$54,$24,$2C,$5C,$64
	dc.b	$C3,$E1,$BC,$B4,$C4,$CC,$BC,$CA
	dc.b	$B4,$0A,$A1,$14,$1A,$24,$2A,$04
	dc.b	$93,$9C,$A4,$AC,$94,$74,$7C,$84
	dc.b	$8C,$74,$7A,$9C,$A2,$84,$8A,$AC
	dc.b	$FF,$FF

* missile co-ordinates table

cord_miss
	dc.w	$19
	dc.w	$FE80,$0090,$0000
	dc.w	$FE80,$0048,$0030
	dc.w	$FE80,$FFB8,$0030
	dc.w	$FE80,$FF70,$0000
	dc.w	$FE80,$FFB8,$FFD0
	dc.w	$FE80,$0048,$FFD0
	dc.w	$FFA0,$0120,$0000
	dc.w	$FFA0,$00C0,$0060
	dc.w	$FFA0,$FF40,$0060
	dc.w	$FFA0,$FEE0,$0000
	dc.w	$FFA0,$FF40,$FFA0
	dc.w	$FFA0,$00C0,$FFA0
	dc.w	$0480,$0000,$0000
	dc.w	$0570,$0000,$0000
	dc.w	$FF70,$FF70,$FF58
	dc.w	$FF70,$0090,$FF58
	dc.w	$0090,$0090,$FF58
	dc.w	$0090,$FF70,$FF58
	dc.w	$FFD0,$FFD0,$FFA4
	dc.w	$FFD0,$0030,$FFA4
	dc.w	$0030,$0030,$FFAC
	dc.w	$0030,$FFD0,$FFAC
	dc.w	$FFA0,$0000,$0060
	dc.w	$0210,$0048,$0030
	dc.w	$0210,$FFB8,$0030
	dc.w	$0030,$0000,$0090

* saucer vertex table

vert_sauc
	dc.b	$83,$A1,$44,$4C,$84,$54,$5C,$84
	dc.b	$64,$6C,$84,$74,$7C,$84,$03,$3C
	dc.b	$7C,$44,$04,$0C,$4C,$54,$14,$1C
	dc.b	$5C,$64,$24,$2C,$6C,$74,$34,$3C
	dc.b	$32,$2C,$22,$1C,$12,$0C,$FF,$FF

* saucer co-ordinates table

cord_sauc
	dc.w	$11
	dc.w	$FF10,$0000,$FFFFFFD8+$C0
	dc.w	$FF60,$00A0,$FFFFFFD8+$C0
	dc.w	$0000,$00F0,$FFFFFFD8+$C0
	dc.w	$00A0,$00A0,$FFFFFFD8+$C0
	dc.w	$00F0,$0000,$FFFFFFD8+$C0
	dc.w	$00A0,$FF60,$FFFFFFD8+$C0
	dc.w	$0000,$FF10,$FFFFFFD8+$C0
	dc.w	$FF60,$FF60,$FFFFFFD8+$C0
	dc.w	$FC40,$0000,$00000050+$C0
	dc.w	$FD58,$02A8,$00000050+$C0
	dc.w	$0000,$03C0,$00000050+$C0
	dc.w	$02A8,$02A8,$00000050+$C0
	dc.w	$03C0,$0000,$00000050+$C0
	dc.w	$02A8,$FD58,$00000050+$C0
	dc.w	$0000,$FC40,$00000050+$C0
	dc.w	$FD58,$FD58,$00000050+$C0
	dc.w	$0000,$0000,$00000118+$C0

* super tank vertex table

vert_super
	dc.b	$03,$A1,$0C,$24,$04,$1C,$14,$2C
	dc.b	$1C,$12,$0C,$22,$2C,$4B,$54,$34
	dc.b	$74,$6C,$4C,$44,$3C,$34,$5C,$64
	dc.b	$44,$62,$6C,$72,$5C,$9B,$B4,$AC
	dc.b	$A4,$84,$7C,$94,$8C,$84,$7A,$9C
	dc.b	$B2,$94,$8A,$AC,$BA,$E1,$C4,$9A
	dc.b	$A4,$FF

* super tank co-ordinates table

cord_super
	dc.w	$19
	dc.w	$05B0-$130,$0170,$FEC0
	dc.w	$FE38-$130,$0228,$FEC0
	dc.w	$FE38-$130,$FDD8,$FEC0
	dc.w	$05B0-$130,$FE90,$FEC0
	dc.w	$FE38-$130,$01C8,$FFA4
	dc.w	$FE38-$130,$FE38,$FFA4
	dc.w	$0448-$130,$0000,$FEEC
	dc.w	$FEF0-$130,$0110,$FF8C
	dc.w	$FE38-$130,$0110,$FFA4
	dc.w	$FE38-$130,$FEF0,$FFA4
	dc.w	$FEF0-$130,$FEF0,$FF8C
	dc.w	$FEF0-$130,$00B8,$002C
	dc.w	$FE38-$130,$00B8,$002C
	dc.w	$FE38-$130,$FF48,$002C
	dc.w	$FEF0-$130,$FF48,$002C
	dc.w	$0500-$130,$0058,$FFD4
	dc.w	$0058-$130,$0058,$FFD4
	dc.w	$0058-$130,$FFA8,$FFD4
	dc.w	$0500-$130,$FFA8,$FFD4
	dc.w	$0500-$130,$0058,$0000
	dc.w	$FFA8-$130,$0058,$0000
	dc.w	$FFA8-$130,$FFA8,$0000
	dc.w	$0500-$130,$FFA8,$0000
	dc.w	$FE38-$130,$0000,$002C
	dc.w	$FE38-$130,$0000,$0114

* "EASY" vertex table

vert_easy
	dc.b	$03,$A1,$0C,$14,$1C,$24,$2C,$34
	dc.b	$3C,$44,$04,$6A,$74,$7C,$84,$6C
	dc.b	$5A,$64,$4C,$54,$5C,$8C,$94,$9C
	dc.b	$A4,$AC,$5C,$8A,$B4,$BC,$C4,$CC
	dc.b	$D4,$8C,$FF,$FF

* "EASY" co-ordinates table

cord_easy
	dc.w	$1A
	dc.w	$0038,$03B6,$0008
	dc.w	$0070,$0226,$000E
	dc.w	$00A8,$0316,$0016
	dc.w	$00E0,$0316,$001C
	dc.w	$0118,$0276,$0024
	dc.w	$0150,$0316,$002A
	dc.w	$0190,$0316,$0032
	dc.w	$01C8,$0226,$0038
	dc.w	$0200,$03B6,$0040
	dc.w	$0038,$0226,$0008
	dc.w	$00A8,$0136,$0016
	dc.w	$0038,$0046,$0008
	dc.w	$0200,$0136,$0040
	dc.w	$00E0,$0186,$001C
	dc.w	$0100,$0136,$0020
	dc.w	$00E0,$00E6,$001C
	dc.w	$0150,$0136,$002A
	dc.w	$0038,$FDC6,$0008
	dc.w	$0190,$FF06,$0032
	dc.w	$0200,$FDC6,$0040
	dc.w	$0200,$0046,$0040
	dc.w	$00A8,$FF06,$0016
	dc.w	$0118,$FCD6,$0024
	dc.w	$0200,$FC4A,$0040
	dc.w	$0190,$FD08,$0032
	dc.w	$0200,$FDC6,$0040
	dc.w	$0118,$FD3A,$0024

* "ZONE" vertex table

vert_zone
	dc.b	$0B,$A1,$04,$2C,$24,$1C,$14,$0C
	dc.b	$1C,$3C,$34,$0C,$4A,$44,$5C,$54
	dc.b	$4C,$72,$B4,$BC,$C4,$64,$6C,$74
	dc.b	$7C,$84,$8C,$94,$9C,$A4,$AC,$B4
	dc.b	$FF,$FF

* "ZONE" co-ordinates table

cord_zone
	dc.w	$19
	dc.w	$FE00,$04B0,$FFC0
	dc.w	$FE00,$0230,$FFC0
	dc.w	$FE70,$0370,$FFCE
	dc.w	$FFC8,$0230,$FFF8
	dc.w	$FFC8,$04B0,$FFF8
	dc.w	$FF58,$0370,$FFEA
	dc.w	$FE00,$0050,$FFC0
	dc.w	$FFC8,$0050,$FFF8
	dc.w	$FE70,$0190,$FFCE
	dc.w	$FE70,$00F0,$FFCE
	dc.w	$FF58,$00F0,$FFEA
	dc.w	$FF58,$0190,$FFEA
	dc.w	$FE00,$0000,$FFC0
	dc.w	$FEE8,$FF60,$FFDC
	dc.w	$FE00,$FD80,$FFC0
	dc.w	$FE38,$FBF0,$FFC8
	dc.w	$FE70,$FCE0,$FFCE
	dc.w	$FEB0,$FCE0,$FFD6
	dc.w	$FEE8,$FC40,$FFDC
	dc.w	$FF20,$FCE0,$FFE4
	dc.w	$FF58,$FCE0,$FFEA
	dc.w	$FF90,$FBF0,$FFF2
	dc.w	$FFC8,$FD80,$FFF8
	dc.w	$FEE8,$FE20,$FFDC
	dc.w	$FFC8,$0000,$FFF8

* shadow 0 vertex table
* shadow 1 vertex table
* shadow 2 vertex table
* shadow 3 vertex table
* shadow 4 vertex table
* shadow 5 vertex table
* shadow 6 vertex table
* shadow 7 vertex table

vert_shadw
	dc.b	$3B,$A1,$00,$08,$10,$18,$20,$28
	dc.b	$30,$38,$FF,$FF

* shadow 0 co-ordinates table

cord_shadw_0
	dc.w	$08
	dc.w	$08
	dc.w	$0000,$0034,$FF4C
	dc.w	$0024,$0024,$FF4C
	dc.w	$0034,$0000,$FF4C
	dc.w	$0024,$FFDC,$FF4C
	dc.w	$0000,$FFCC,$FF4C
	dc.w	$FFDC,$FFDC,$FF4C
	dc.w	$FFCC,$0000,$FF4C
	dc.w	$FFDC,$0024,$FF4C

* shadow 1 co-ordinates table

cord_shadw_1
	dc.w	$08
	dc.w	$0000,$0064,$FF38
	dc.w	$0048,$0048,$FF38
	dc.w	$0064,$0000,$FF38
	dc.w	$0048,$FFB8,$FF38
	dc.w	$0000,$FF9C,$FF38
	dc.w	$FFB8,$FFB8,$FF38
	dc.w	$FF9C,$0000,$FF38
	dc.w	$FFB8,$0048,$FF38

* shadow 2 co-ordinates table

cord_shadw_2
	dc.w	$08
	dc.w	$0000,$0098,$FF24
	dc.w	$006C,$006C,$FF24
	dc.w	$0098,$0000,$FF24
	dc.w	$006C,$FF94,$FF24
	dc.w	$0000,$FF68,$FF24
	dc.w	$FF94,$FF94,$FF24
	dc.w	$FF68,$0000,$FF24
	dc.w	$FF94,$006C,$FF24

* shadow 3 co-ordinates table

cord_shadw_3
	dc.w	$08
	dc.w	$0000,$00C8,$FF10
	dc.w	$0090,$0090,$FF10
	dc.w	$00C8,$0000,$FF10
	dc.w	$0090,$FF70,$FF10
	dc.w	$0000,$FF38,$FF10
	dc.w	$FF70,$FF70,$FF10
	dc.w	$FF38,$0000,$FF10
	dc.w	$FF70,$0090,$FF10

* shadow 4 co-ordinates table

cord_shadw_4
	dc.w	$08
	dc.w	$0000,$00FC,$FEFC
	dc.w	$00B0,$00B0,$FEFC
	dc.w	$00FC,$0000,$FEFC
	dc.w	$00B0,$FF50,$FEFC
	dc.w	$0000,$FF04,$FEFC
	dc.w	$FF50,$FF50,$FEFC
	dc.w	$FF04,$0000,$FEFC
	dc.w	$FF50,$00B0,$FEFC

* shadow 5 co-ordinates table

cord_shadw_5
	dc.w	$08
	dc.w	$0000,$012C,$FEE8
	dc.w	$00D4,$00D4,$FEE8
	dc.w	$012C,$0000,$FEE8
	dc.w	$00D4,$FF2C,$FEE8
	dc.w	$0000,$FED4,$FEE8
	dc.w	$FF2C,$FF2C,$FEE8
	dc.w	$FED4,$0000,$FEE8
	dc.w	$FF2C,$00D4,$FEE8

* shadow 6 co-ordinates table

cord_shadw_6
	dc.w	$08
	dc.w	$0000,$0160,$FED4
	dc.w	$0108,$0108,$FED4
	dc.w	$0160,$0000,$FED4
	dc.w	$0108,$FEF8,$FED4
	dc.w	$0000,$FEA0,$FED4
	dc.w	$FEF8,$FEF8,$FED4
	dc.w	$FEA0,$0000,$FED4
	dc.w	$FEF8,$0108,$FED4

* shadow 7 co-ordinates table

cord_shadw_7
	dc.w	$08
	dc.w	$0000,$0190,$FEC0
	dc.w	$011C,$011C,$FEC0
	dc.w	$0190,$0000,$FEC0
	dc.w	$011C,$FEE4,$FEC0
	dc.w	$0000,$FE70,$FEC0
	dc.w	$FEE4,$FEE4,$FEC0
	dc.w	$FE70,$0000,$FEC0
	dc.w	$FEE4,$011C,$FEC0


*************************************************************************************
*
* explosion parts tables. these are used to set the initial delta x, delta y and delta
* z of explosion parts. this, fixed, table is used as using random values often does
* not look random or impressive

ex_table

* explosion parts delta x

et_dx		EQU	*-ex_table
	dc.w	$FF88,$FF88,$0014,$00C8,$0000,$FF60

* explosion parts delta y

et_dy		EQU	*-ex_table
	dc.w	$0078,$0000,$FFEC,$00C8,$FF60,$FF60

* explosion parts delta z

et_dz		EQU	*-ex_table
	dc.w	$0037,$0028,$0046,$0058,$0028,$0042


*************************************************************************************
*
* sound effects for the game. player shot and enemy shot need to be samples $0000 and
* $0002 respectively, other than that there are no restrictions. odd numbered sounds
* have not been used to make programming easier. the 128 sound limit this imposes
* should not be a problem

effsounds
s_pshot	EQU	*-effsounds
	dc.w	ss_pshot-effsounds		* player shot
s_eshot	EQU	*-effsounds
	dc.w	ss_eshot-effsounds		* enemy shot
s_crash	EQU	*-effsounds
	dc.w	ss_crash-effsounds		* collision noise
s_ping	EQU	*-effsounds
	dc.w	ss_ping-effsounds			* radar noise
s_warn	EQU	*-effsounds
	dc.w	ss_warning-effsounds		* enemy warning
s_pxpsn	EQU	*-effsounds
	dc.w	ss_pxplosion-effsounds		* player explosion
s_expsn	EQU	*-effsounds
	dc.w	ss_explosion-effsounds		* enemy explosion
s_hit		EQU	*-effsounds
	dc.w	ss_hit-effsounds			* shell object hit
s_bonus	EQU	*-effsounds
	dc.w	ss_bonus-effsounds		* bonus tank
s_saucer	EQU	*-effsounds
	dc.w	ss_saucer-effsounds		* saucer appears
s_recuas	EQU	*-effsounds
	dc.w	ss_recuas-effsounds		* saucer vanishes
	dc.w	-1					* end marker

ss_pshot
	dc.b	'shot_p.wav',$00			* player shot
ss_eshot
	dc.b	'shot_e.wav',$00			* enemy shot
ss_crash
	dc.b	'bop.wav',$00			* collision noise
ss_ping
	dc.b	'ping.wav',$00			* radar noise
ss_warning
	dc.b	'warning.wav',$00			* enemy warning
ss_pxplosion
	dc.b	'pxplosion.wav',$00		* player explosion
ss_explosion
	dc.b	'explosion.wav',$00		* enemy explosion
ss_hit
	dc.b	'hit.wav',$00			* shell object hit
ss_bonus
	dc.b	'bonus.wav',$00			* bonus tank
ss_saucer
	dc.b	'pihw.wav',$00			* saucer appears
ss_recuas
	dc.b	'whip.wav',$00			* saucer destroyed
	ds.w	0	


*************************************************************************************
*
* variables used

LAB_VARS						* points to variables base

	OFFSET	0				* going to use relative addressing

* there are five volcano stars indexed as 0 to 4. intensity also sets the colour.
* delta y is 5 to 12 and decremented each loop to simulate acceleration due to
* gravity. delta x is -4 to +4 but not 0. -ve values are to the left. (x,y) are the
* 2D co-ordinate pair, the horizon is the lower y limit

st_intens	ds.w	1				* volcano star intensity
st_deltax	ds.w	1				* volcano star delta x
st_deltay	ds.w	1				* volcano star delta y
st_xcoord	ds.w	1				* volcano star x co-ordinate
st_ycoord	ds.w	1				* volcano star y co-ordinate

st_size						* size for one star's data
		ds.b	st_size*4			* make room for 4 more stars

* vehicle objects

v_o_start						* offset to start of vehicle objects

v_orient	EQU	*-v_o_start
		ds.w	1				* vehicle orientation
v_o_type	EQU	*-v_o_start
		ds.w	1				* vehicle object type
v_xcoord	EQU	*-v_o_start
		ds.w	1				* vehicle x co-ordinate
v_ycoord	EQU	*-v_o_start
		ds.w	1				* vehicle y co-ordinate
v_motion	EQU	*-v_o_start
		ds.w	1				* vehicle motion word
v_mot_time	EQU	*-v_o_start
		ds.w	1				* vehicle motion timeout counter
v_blocked	EQU	*-v_o_start
		ds.w	1				* vehicle motion blocked flag
v_f_count	EQU	*-v_o_start
		ds.w	1				* vehicle fire timer
v_f_obj	EQU	*-v_o_start
		ds.w	1				* vehicle fire object
v_f_snd	EQU	*-v_o_start
		ds.w	1				* vehicle fire sound
v_expsn	EQU	*-v_o_start
		ds.w	1				* vehicle explosion flag
v_e_snd	EQU	*-v_o_start
		ds.w	1				* vehicle explosion sound
v_anim_c	EQU	*-v_o_start
		ds.w	1				* vehicle animation counter
v_target	EQU	*-v_o_start
		ds.w	1				* vehicle target orientation
v_foview	EQU	*-v_o_start
		ds.w	1				* vehicle field of view

v_o_size	EQU	*-v_o_start			* vehicle object size

		ds.b	v_o_size*3			* reserve space for 3 other vehicle objects

v_o_last	EQU	*-v_o_size			* start of last vehicle object

* weapons fire objects

f_o_start						* offset to start of weapons fire objects

f_orient	EQU	*-f_o_start
		ds.w	1				* fire orientation
f_o_type	EQU	*-f_o_start
		ds.w	1				* fire object type
f_xcoord	EQU	*-f_o_start
		ds.w	1				* fire x co-ordinate
f_ycoord	EQU	*-f_o_start
		ds.w	1				* fire y co-ordinate
f_count	EQU	*-f_o_start
		ds.w	1				* fire flight counters
f_delta_x	EQU	*-f_o_start
		ds.w	1				* fire delta x
f_delta_y	EQU	*-f_o_start
		ds.w	1				* fire delta y

f_o_size	EQU	*-f_o_start			* weapons fire object size

		ds.b	f_o_size*3			* reserve space for 3 other fire object

f_o_last	EQU	*-f_o_size			* start of last weapons fire object


ex_object	ds.w	42				* explosion object tables

* values for the explosion part structures

ex_x		EQU		$00			* explosion part x co-ordinate
ex_y		EQU		$0C			* explosion part y co-ordinate
ex_z		EQU		$18			* explosion part z co-ordinate
ex_o		EQU		$24			* explosion part orientation

ex_dx		EQU		$30			* explosion part delta x
ex_dy		EQU		$3C			* explosion part delta y
ex_dz		EQU		$48			* explosion part delta z

p_temp	ds.w	1				* temporary word
t_xcoord	ds.w	1				* temporary x co-ordinate
t_ycoord	ds.w	1				* temporary y co-ordinate

p_lives	ds.w	1				* player lives count
p_radar	ds.w	1				* player radar orientation - 8 bit only
radar_pip	ds.w	1				* radar pip intensity

p_score	ds.w	1				* player score
h_score	ds.w	10				* high score table start
h_sc_nam	ds.l	10				* high score names table start

er_obj	ds.b	1				* enemy radar object number, always $0D
e_radar	ds.b	1				* enemy radar orientation - 8 bit only

e_warning	ds.w	1				* enemy warning sounded flag
e_temp_x	ds.w	1				* temporary enemy x co-ordinate
e_temp_y	ds.w	1				* temporary enemy y co-ordinate

logo_x	ds.w	1				* flying logo x co-ordinate
m_alt		ds.w	1				* flying logo altitude

eye_osetx	ds.w	1				* eye viewpoint x offset
eye_osety	ds.w	1				* eye viewpoint y offset
eye_orent	ds.w	1				* eye viewpoint orientation offset

colourmask	ds.l	1				* colourmask longword
intens_mod	ds.w	1				* intensity modifier

PRNlword	ds.l	1				* PRNG seed long word

list_objct	ds.w	$1C				* room for 28 objects
list_obj_x	EQU	*-list_objct
	ds.w	$1C					* room for 28 object x co-ordinates
list_obj_y	EQU	*-list_objct
	ds.w	$1C					* room for 28 object y co-ordinates

twoD_obj_x	ds.w	$1C				* room for 28 object x co-ordinates
twoD_obj_y	ds.w	$1C				* room for 28 object y co-ordinates

vector_s	ds.w	1				* binary vector scale

local_x	ds.w	1				* local screen x co-ordinate offset
local_y	ds.w	1				* local screen y co-ordinate offset

vert_offs	ds.w	1				* display offset for collisions
vert_objt	ds.w	1				* object offset for explosions

viewmode	ds.w	1				* playfield view mode
last3key	ds.w	1				* last 3 key flag
lastPkey	ds.w	1				* last P key flag
lastSPACE	ds.w	1				* last SPACE key flag

game_mode	ds.w	1				* play, high score or attract mode
game_count	ds.w	1				* counter incremented once per main loop

hi_name	ds.l	1				* high score name entry pointer
hi_lastk	ds.l	1				* high score name entry lask keys
hi_index	ds.w	1				* high score name entry index

queue_read	ds.w	1				* sound queue read index
queue_write	ds.w	1				* sound queue write index
queue_snd	ds.b	16				* sound queue

		ds.w	0

scr_x		ds.w	1				* screen x size
scr_y		ds.w	1				* screen y size
scr_x_c	ds.w	1				* screen x centre
scr_y_c	ds.w	1				* screen y centre

saucer_x	ds.w	1				* saucer x co-ordinate
saucer_y	ds.w	1				* saucer y co-ordinate

saucer_dx	ds.w	1				* saucer delta x
saucer_dy	ds.w	1				* saucer delta y

saucer_f	ds.w	1				* saucer flag
saucer_l	ds.w	1				* saucer direction life timer
saucer_o	ds.w	1				* saucer orientation
saucer_d	ds.w	1				* saucer destruction flag
saucer_i	ds.w	1				* saucer destruction intensity

vars_end						* end of variables

	END	start
