*************************************************************************************
*														*
*	The save routines include file for the landscape generator. V1.02	2/10/2008	*
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
*
* the image is saved as a 256 colour bitmap file

* first the bitmap file header which is made up as follows
*
*	dc.b	'BM'					* *.bmp file header signature bytes
*	dc.l	size					* the total size of the file
*	dc.w	reserved				* usually zero
*	dc.w	reserved				* usually zero
*	dc.l	offset				* the offset to the start of the image data
*							* from the start of the file

* then the bitmap image header which is made up as follows
*
*	dc.l	header_size				* should be 40
*	dc.l	im_width				* image width in pixels
*	dc.l	im_height				* image height in pixels
*	dc.w	bitplanes				* number of planes, should be 1
*	dc.w	im_depth				* number of bits per pixel, should be one
*							* of 1, 4 8 or 24
*	dc.l	compression				* type of compression, should be zero, no
*							* compression
*	dc.l	im_size				* size of the image data in bytes. if there
*							* is no compression this can be set to zero
*	dc.l	im_x_ppm				* x resolution in pixels per meter
*	dc.l	im_y_ppm				* y resolution in pixels per meter
*	dc.l	colours_used			* number of colours used, usually zero
*	dc.l	colours_important			* number of important colours, usually zero

* then the palette, this is a black and white image. palette colours are BBGGRR00
*
*	dc.l	$00000000				* black
*	dc.l	$FFFFFF00				* white

* and finally the image data. this is the image line by line from the bottom to the
* top with each line padded to fit a whole number of 32 bits. a 1 bit is white, a 0
* bit is black. here is an example for a 40 x 10 monochrome bitmap that says 'Hello'

*	dc.l	$FFFFFFFF,$FF000000		* bottom row
*	dc.l	$E230C183,$8F000000
*	dc.l	$F76FF7EF,$77000000
*	dc.l	$F760F7EF,$77000000
*	dc.l	$F06EF7EF,$77000000
*	dc.l	$F771F7EF,$8F000000
*	dc.l	$F77FF7EF,$FF000000
*	dc.l	$E23FE7CF,$FF000000
*	dc.l	$FFFFFFFF,$FF000000
*	dc.l	$FFFFFFFF,$FF000000		* top row

* which, ignoring the unused bits, expands to ... ['##' = 0, '..' = 1]

*	................................................................................
*	......######..######....########....##########....##########......######........
*	........##......##....##................##............##........##......##......
*	........##......##....##########........##............##........##......##......
*	........##########....##......##........##............##........##......##......
*	........##......##......######..........##............##..........######........
*	........##......##......................##............##........................
*	......######..######..................####..........####........................
*	................................................................................
*	................................................................................


*************************************************************************************
*
* strings used by the save image routines

save_title
	dc.b	'Save image',0			* save title
file_list
	dc.b	'*.bmp',0				* file type list

	ds.w	0					* ensure even


*************************************************************************************
*
* save the image

save_image
	TST.w		i_xsize(a3)			* test the rendered image x size
	BMI.s		no_image_save		* if no image just exit

	MOVE.l	a3,-(sp)			* save the variables base pointer
	LEA		save_title(pc),a1		* set the request title string pointer
	LEA		file_list(pc),a2		* set the file types list pointer
	LEA		filename_buffer(a3),a3	* set the file name buffer pointer
	MOVEQ		#1,d1				* file save
	MOVE.b	#0,(a3)			* ensure null source file
	MOVEQ		#58,d0			* file I/O
	TRAP		#15

	MOVEA.l	a3,a1				* copy the file name pointer
	MOVEA.l	(sp)+,a3			* restore the variables pointer
	TST.l		d1				* did the user hit save
	BEQ.s		no_image_save		* if not do no output exit

	MOVEQ		#52,d0			* else open new file
	TRAP		#15

	TST.w		d0				* test open result
	BNE.s		exit_image_save		* if error just exit

	MOVE.l	d1,file_id(a3)		* save the file id
	BSR.s		output_image		* save the output file
	MOVE.l	file_id(a3),d1		* get the file id
	MOVEQ		#56,d0			* close the file
	TRAP		#15

	RTS

exit_image_save
	MOVEQ		#50,d0			* else close all files
	TRAP		#15

no_image_save
	RTS


*************************************************************************************
*
* output an image in .bmp format to an already open file

output_image
	LEA		bmp_header(pc),a1		* point to the bitmap header

* now get the x and y, width and height, sizes and write them to the header

	MOVE.w	i_xsize(a3),d0		* get the end x co-ordinate
	MOVE.w	d0,d3				* copy the x size
	ROR.w		#8,d0				* swap the bytes to little endian
	MOVE.w	d0,bmp_img_width(a1)	* save the image width to the header

	MOVE.w	i_ysize(a3),d0		* get the end y co-ordinate
	MOVE.w	d0,d2				* copy the y size
	ROR.w		#8,d0				* swap the bytes to little endian
	MOVE.w	d0,bmp_img_height(a1)	* save the image height to the header

* now calculate the number of bytes per line needed, this is always a whole number of
* longwords

	ADD.w		#3,d3				* exceede the next longword boundary
	AND.w		#-4,d3			* mask the longword byte value

* now calculate the bitmap image data size and save it and then calculate the bitmap
* total file size

	MULU.w	d3,d2				* multiply the height by the bytes per line
	MOVE.l	d2,-(sp)			* save the bitmap image data size

	MOVE.l	#1024,d0			* get the palette size
	ADD.l		#head_size,d0		* add the header size
	ADD.l		d2,d0				* add the data size

* now save the bitmap image data size to the header

	ROR.w		#8,d2				* swap the bytes to little endian
	SWAP		d2				* swap the words to little endian
	ROR.w		#8,d2				* swap the bytes to little endian
	MOVE.l	d2,bmp_img_size(a1)	* save the bitmap image size to the header

* now save the bitmap total file size to the header

	ROR.w		#8,d0				* swap the bytes to little endian
	SWAP		d0				* swap the words to little endian
	ROR.w		#8,d0				* swap the bytes to little endian
	MOVE.l	d0,bmp_size(a1)		* save the bitmap total size to the header

* while the pointer is still set, save the bitmap header to the bitmap file

	MOVE.l	file_id(a3),d1		* get the bitmap file id
	MOVE.l	#head_size,d2		* set the header length
	MOVEQ		#54,d0			* write the header bytes to the file
	TRAP		#15

* now save the palette to the bitmap file

	MOVE.l	#1024,d2			* set the palette length
	LEA		palette+1(pc),a1		* point to the palette for the bitmap
	MOVEQ		#54,d0			* write the palette bytes to the file
	TRAP		#15

* now save the bitmap image data to the file

	MOVE.l	(sp)+,d2			* get the bitmap image data size back
	LEA		i_buffer(a3),a1		* point to the bitmap image data
	MOVE.l	file_id(a3),d1		* get the file id
	MOVEQ		#54,d0			* write file bytes
	TRAP		#15

	RTS


*************************************************************************************
*
* a bitmap header that the correct values can be plugged into. note that values in
* the header are all little endian.

bmp_header
	dc.b	'BM'					* .bmp file header signature bytes
bmp_size					EQU	*-bmp_header
	dc.l	0					* the total size of the file
	dc.w	0					* reserved, usually zero
	dc.w	0					* reserved, usually zero
bmp_start					EQU	*-bmp_header
	dc.l	$36040000				* the offset to the start of the image data
							* from the start of the file
* now the image header

	dc.l	$28000000				* image header size
bmp_img_width				EQU	*-bmp_header
	dc.l	0					* image width in pixels
bmp_img_height				EQU	*-bmp_header
	dc.l	0					* image height in pixels
	dc.w	$0100					* number of planes, should be 1
	dc.w	$0800					* number of bits per pixel, should be one
							* of 1, 4 8 or 24
	dc.l	0					* type of compression, should be zero, no
							* compression
bmp_img_size				EQU	*-bmp_header
	dc.l	0					* size of the image data in bytes. if there
							* is no compression this can be set to zero
	dc.l	0					* x resolution in pixels per meter
	dc.l	0					* y resolution in pixels per meter
	dc.l	0					* number of colours used, usually zero
	dc.l	0					* number of important colours, usually zero
head_size	EQU *-bmp_header


*************************************************************************************
