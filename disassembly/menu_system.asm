; ==========================================================================
; MENU SYSTEM & STARTUP CODE ($B100-$BA67)
; ==========================================================================
;
; The SNA snapshot's return address is $B134 (MENU_LOOP), the main menu
; animation loop. The menu system handles:
;   - Title screen display and animation
;   - "New Game" option -> jumps to $CC40 (NEW_GAME_INIT)
;   - Demo mode / attract screen
;
; Key entry points:
;   $B134  Menu animation loop (SNA return address on stack)
;   $B2DF  "New Game" handler: CALL $C03E then CALL $C371
;

	CP	0FFH		; b101  fe ff		~.
	JR	Z,XB10C		; b103  28 07		(.
	DEC	HL		; b105  2b		+
	LD	A,H		; b106  7c		|
	OR	L		; b107  b5		5
	JR	NZ,XB0FC	; b108  20 f2		 r
	LD	E,0FFH		; b10a  1e ff		..
XB10C:	LD	A,E		; b10c  7b		{
	LD	(XB26D),A	; b10d  32 6d b2	2m2
	DI			; b110  f3		s
	LD	A,0C3H		; b111  3e c3		>C
	LD	(XFDFD),A	; b113  32 fd fd	2}}
	LD	HL,XBB51	; b116  21 51 bb	!Q;
	LD	(XFDFE),HL	; b119  22 fe fd	"~}
	LD	A,0FEH		; b11c  3e fe		>~
	LD	I,A		; b11e  ed 47		mG
	IM	2		; b120  ed 5e		m^
	EI			; b122  fb		{
	XOR	A		; b123  af		/
	OUT	(0FEH),A	; b124  d3 fe		S~
	LD	HL,XB192	; b126  21 92 b1	!.1
	CALL	STRING_RENDERER		; b129  cd 26 bc	M&<
XB12C:	CALL	XB26E		; b12c  cd 6e b2	Mn2
	LD	A,E		; b12f  7b		{
	OR	A		; b130  b7		7
	JR	NZ,XB12C	; b131  20 f9		 y
XB133:	HALT			; b133  76		v
;

; --- Menu animation loop ---
MENU_LOOP:
	CALL	XB1B0		; b134  cd b0 b1	M01
	LD	HL,XB1AF	; b137  21 af b1	!/1
	INC	(HL)		; b13a  34		4
	LD	A,(HL)		; b13b  7e		~
	CP	38H		; b13c  fe 38		~8
	JR	C,XB142		; b13e  38 02		8.
	LD	A,0		; b140  3e 00		>.
XB142:	LD	(HL),A		; b142  77		w
	SRL	A		; b143  cb 3f		K?
	SRL	A		; b145  cb 3f		K?
	SRL	A		; b147  cb 3f		K?
	INC	A		; b149  3c		<
	OR	40H		; b14a  f6 40		v@
	LD	BC,X1700	; b14c  01 00 17	...
	LD	DE,X0120	; b14f  11 20 01	. .
	CALL	FILL_ATTR_RECT		; b152  cd f6 ba	Mv:
	CALL	XB26E		; b155  cd 6e b2	Mn2
	LD	A,E		; b158  7b		{
	CP	1		; b159  fe 01		~.
	JP	Z,XB16A		; b15b  ca 6a b1	Jj1
	CP	2		; b15e  fe 02		~.
	JP	Z,XB16A		; b160  ca 6a b1	Jj1
	CP	4		; b163  fe 04		~.
	JP	Z,XB16A		; b165  ca 6a b1	Jj1
	JR	XB133		; b168  18 c9		.I
;
XB16A:	LD	HL,XB294	; b16a  21 94 b2	!.2
	BIT	0,E		; b16d  cb 43		KC
	JR	NZ,XB17B	; b16f  20 0a		 .
	LD	HL,XB299	; b171  21 99 b2	!.2
	BIT	1,E		; b174  cb 4b		KK
	JR	NZ,XB17B	; b176  20 03		 .
	LD	HL,XB29E	; b178  21 9e b2	!.2
XB17B:	LD	B,5		; b17b  06 05		..
	LD	DE,XBACE	; b17d  11 ce ba	.N:
	LD	IX,XBAE2	; b180  dd 21 e2 ba	]!b:
XB184:	LD	A,(HL)		; b184  7e		~
	LD	(DE),A		; b185  12		.
	LD	(IX+0),A	; b186  dd 77 00	]w.
	INC	HL		; b189  23		#
	INC	DE		; b18a  13		.
	INC	IX		; b18b  dd 23		]#
	DJNZ	XB184		; b18d  10 f5		.u
	JP	XB2A3		; b18f  c3 a3 b2	C#2
;
XB192:	DB	1EH,47H,1FH,3AH,17H			; b192 .G.:.
	DB	'Press N, Space or Fire.'		; b197
	DB	0					; b1ae .
XB1AF:	DB	35H					; b1af 5
;
XB1B0:	LD	HL,XB24A	; b1b0  21 4a b2	!J2
	DEC	(HL)		; b1b3  35		5
	LD	A,(HL)		; b1b4  7e		~
	AND	7		; b1b5  e6 07		f.
	RET	NZ		; b1b7  c0		@
	LD	A,(HL)		; b1b8  7e		~
	SRL	A		; b1b9  cb 3f		K?
	SRL	A		; b1bb  cb 3f		K?
	SRL	A		; b1bd  cb 3f		K?
	CP	6		; b1bf  fe 06		~.
	JR	C,XB1DD		; b1c1  38 1a		8.
	CP	1FH		; b1c3  fe 1f		~.
	RET	NZ		; b1c5  c0		@
	LD	(HL),38H	; b1c6  36 38		68
	CALL	PRNG		; b1c8  cd e4 d3	MdS
	AND	0FH		; b1cb  e6 0f		f.
	ADD	A,A		; b1cd  87		.
	LD	E,A		; b1ce  5f		_
	LD	D,0		; b1cf  16 00		..
	LD	HL,XB24D	; b1d1  21 4d b2	!M2
	ADD	HL,DE		; b1d4  19		.
	LD	DE,XB24B	; b1d5  11 4b b2	.K2
	LDI			; b1d8  ed a0		m 
	LDI			; b1da  ed a0		m 
	RET			; b1dc  c9		I
;
XB1DD:	LD	C,A		; b1dd  4f		O
	ADD	A,A		; b1de  87		.
	ADD	A,C		; b1df  81		.
	LD	C,A		; b1e0  4f		O
	ADD	A,A		; b1e1  87		.
	ADD	A,C		; b1e2  81		.
	LD	E,A		; b1e3  5f		_
	LD	D,0		; b1e4  16 00		..
	LD	HL,XB214	; b1e6  21 14 b2	!.2
	ADD	HL,DE		; b1e9  19		.
	LD	A,(XB24C)	; b1ea  3a 4c b2	:L2
	ADD	A,A		; b1ed  87		.
	LD	E,A		; b1ee  5f		_
	LD	A,0		; b1ef  3e 00		>.
	ADC	A,0		; b1f1  ce 00		N.
	LD	D,A		; b1f3  57		W
	LD	IX,ROW_PTR_TABLE	; b1f4  dd 21 00 fc	]!.|
	ADD	IX,DE		; b1f8  dd 19		].
	EX	DE,HL		; b1fa  eb		k
	LD	A,(XB24B)	; b1fb  3a 4b b2	:K2
	LD	C,A		; b1fe  4f		O
	LD	B,9		; b1ff  06 09		..
XB201:	LD	A,C		; b201  79		y
	ADD	A,(IX+0)	; b202  dd 86 00	]..
	LD	L,A		; b205  6f		o
	LD	H,(IX+1)	; b206  dd 66 01	]f.
	LD	A,(DE)		; b209  1a		.
	XOR	(HL)		; b20a  ae		.
	LD	(HL),A		; b20b  77		w
	INC	DE		; b20c  13		.
	INC	IX		; b20d  dd 23		]#
	INC	IX		; b20f  dd 23		]#
	DJNZ	XB201		; b211  10 ee		.n
	RET			; b213  c9		I
;
XB214:	NOP			; b214  00		.
;
	ORG	0B218H
;
	DB	4					; b218 .
;
	ORG	0B220H
;
	DB	0EH,0AH,0EH				; b220 ...
;
	ORG	0B226H
;
	DB	4,4,15H,0,11H,0,15H,4			; b226 ........
	DB	4,4,4,15H,0,11H,0			; b22e .......
;
	DEC	D		; b235  15		.
	INC	B		; b236  04		.
	INC	B		; b237  04		.
	NOP			; b238  00		.
	NOP			; b239  00		.
	NOP			; b23a  00		.
	LD	C,0AH		; b23b  0e 0a		..
	LD	C,0		; b23d  0e 00		..
;
	ORG	0B245H
;
	DB	4					; b245 .
;
	ORG	0B24AH
;
XB24A:	DB	0AH					; b24a .
XB24B:	DB	1BH					; b24b .
XB24C:	DB	34H					; b24c 4
XB24D:	DB	0,1CH,1,1CH,5,2BH,4,34H			; b24d .....+.4
	DB	6,4CH,0CH,4CH,0FH,1CH,12H,1CH		; b255 .L.L....
	DB	15H,0CH,19H,14H,1CH,4,1EH,1CH		; b25d ........
	DB	1FH,2CH,1BH,34H,16H,3CH,11H,3CH		; b265 .,.4.<.<
XB26D:	DB	0FFH					; b26d .
;
XB26E:	LD	E,0		; b26e  1e 00		..
	LD	HL,XB26D	; b270  21 6d b2	!m2
	BIT	0,(HL)		; b273  cb 46		KF
	JR	Z,XB281		; b275  28 0a		(.
	LD	BC,X001F	; b277  01 1f 00	...
	IN	A,(C)		; b27a  ed 78		mx
	RRA			; b27c  1f		.
	RRA			; b27d  1f		.
	AND	4		; b27e  e6 04		f.
	LD	E,A		; b280  5f		_
XB281:	LD	BC,X7FFE	; b281  01 fe 7f	.~.
	IN	A,(C)		; b284  ed 78		mx
	CPL			; b286  2f		/
	BIT	0,A		; b287  cb 47		KG
	JR	Z,XB28D		; b289  28 02		(.
	SET	1,E		; b28b  cb cb		KK
XB28D:	BIT	3,A		; b28d  cb 5f		K_
	JR	Z,XB293		; b28f  28 02		(.
	SET	0,E		; b291  cb c3		KC
XB293:	RET			; b293  c9		I
;
XB294:	DB	29H,28H,11H,1AH,3BH			; b294 )(..;
XB299:	DB	29H,28H,11H,1AH				; b299 )(..
	DB	'8'					; b29d
Xb29e:	DB	'A@CBD'					; b29e
;
XB2A3:	CALL	XB378		; b2a3  cd 78 b3	Mx3
XB2A6:	LD	BC,X050A	; b2a6  01 0a 05	...
	LD	DE,X0D0C	; b2a9  11 0c 0d	...
	LD	A,68H		; b2ac  3e 68		>h
	CALL	DRAW_BORDERED_RECT		; b2ae  cd 70 bf	Mp?
	LD	HL,XB2F4	; b2b1  21 f4 b2	!t2
	CALL	STRING_RENDERER		; b2b4  cd 26 bc	M&<
XB2B7:	LD	HL,XB337	; b2b7  21 37 b3	!73
	CALL	XBF18		; b2ba  cd 18 bf	M.?
XB2BD:	CALL	XBF3A		; b2bd  cd 3a bf	M:?
	JR	NC,XB2BD	; b2c0  30 fb		0{
	CALL	XBF61		; b2c2  cd 61 bf	Ma?
	LD	A,(XBDF6)	; b2c5  3a f6 bd	:v=
	ADD	A,A		; b2c8  87		.
	LD	E,A		; b2c9  5f		_
	LD	D,0		; b2ca  16 00		..
	LD	HL,XB2D5	; b2cc  21 d5 b2	!U2
	ADD	HL,DE		; b2cf  19		.
	LD	E,(HL)		; b2d0  5e		^
	INC	HL		; b2d1  23		#
	LD	D,(HL)		; b2d2  56		V
	EX	DE,HL		; b2d3  eb		k
	JP	(HL)		; b2d4  e9		i
;
XB2D5:	DB	0DFH					; b2d5 _
	DW	X92B2		; b2d6   b2 92      2.
;
	DB	0B4H,2FH				; b2d8 4/
	DW	X89B9		; b2da   b9 89      9.
	DW	XE8B7		; b2dc   b7 e8      7h
	DW	XCDB2		; b2de   b2 cd      2M
;
	DB	3EH,0C0H				; b2e0 >@
	DW	X71CD		; b2e2   cd 71      Mq
	DW	XC3C3		; b2e4   c3 c3      CC
	DB	0A6H					; b2e6 &
	DW	XCDB2		; b2e7   b2 cd      2M
;
	DB	3EH,0C0H				; b2e9 >@
	DW	X37CD		; b2eb   cd 37      M7
	DW	XCDD4		; b2ed   d4 cd      TM
	DB	78H					; b2ef x
	DW	XC3B3		; b2f0   b3 c3      3C
;
	DB	0A6H					; b2f2 &
;
	OR	D		; b2f3  b2		2
XB2F4:	LD	E,0E8H		; b2f4  1e e8		.h
	RRA			; b2f6  1f		.
	LD	D,B		; b2f7  50		P
;
	DB	5					; b2f8 .
	DB	'~~Options:'				; b2f9
	DB	1DH,7EH,7EH,7EH,1EH,68H,1FH,60H		; b303 .~~~.h.`
	DB	8					; b30b .
	DB	'New Game'				; b30c
	DB	1FH					; b314 .
	DW	X0A60		; b315   60 0a      `.
;
	DB	'Scores'				; b317
	DB	1FH					; b31d .
	DW	X0C60		; b31e   60 0c      `.
;
	DB	4BH,65H,79H,73H,1FH,60H,0EH		; b320 Keys.`.
	DB	'Setup'					; b327
	DB	1FH,60H,10H				; b32c .`.
	DB	'Freebie'				; b32f
	DB	0					; b336 .
XB337:	DB	0AH,8,0CH,0AH,0AH,0CH,0AH,0CH		; b337 ........
	DB	0CH,0AH,0EH,0CH,0AH,10H,0CH,0FFH	; b33f ........
;
XB347:	NOP			; b347  00		.
;
	ORG	0B349H
;
	DB	0CH,0DH,0EH,0FH,10H,0AH,0		; b349 .......
;
	ORG	0B354H
;
	DB	0AH,0AH,0AH,11H,10H,12H,10H,13H		; b354 ........
	DB	0AH,0,0,0AH,0AH,0AH,11H,14H		; b35c ........
	DB	12H,10H,15H,0AH,0			; b364 .....
	DW	X00FF		; b369   ff 00      ..
;
	DB	2,16H,14H,17H,10H			; b36b .....
	DW	X1CFF		; b370   ff 1c      ..
;
	DB	2					; b372 .
;
	ORG	0B376H
;
	DB	0BH,0FFH				; b376 ..
;
XB378:	LD	HL,X4000	; b378  21 00 40	!.@
	LD	(HL),0		; b37b  36 00		6.
	LD	DE,X4001	; b37d  11 01 40	..@
	LD	BC,X182F	; b380  01 2f 18	./.
	LDIR			; b383  ed b0		m0
	LD	HL,XB347	; b385  21 47 b3	!G3
	CALL	HUD_STRING_RENDER		; b388  cd 6e d3	MnS
	LD	HL,XB36A	; b38b  21 6a b3	!j3
	CALL	HUD_STRING_RENDER		; b38e  cd 6e d3	MnS
	LD	HL,XB371	; b391  21 71 b3	!q3
	CALL	HUD_STRING_RENDER		; b394  cd 6e d3	MnS
	XOR	A		; b397  af		/
	LD	(TIMER_BAR_POS),A	; b398  32 bf b0	2?0
	LD	(GAME_TIMER),A	; b39b  32 c0 b0	2@0
XB39E:	LD	BC,X0000	; b39e  01 00 00	...
	LD	DE,X0420	; b3a1  11 20 04	. .
	LD	A,45H		; b3a4  3e 45		>E
	CALL	PROCESS_ATTR_COLOR		; b3a6  cd 07 bc	M.<
	CALL	FILL_ATTR_RECT		; b3a9  cd f6 ba	Mv:
	LD	BC,X021C	; b3ac  01 1c 02	...
	LD	DE,X0204	; b3af  11 04 02	...
	LD	A,47H		; b3b2  3e 47		>G
	CALL	PROCESS_ATTR_COLOR		; b3b4  cd 07 bc	M.<
	CALL	FILL_ATTR_RECT		; b3b7  cd f6 ba	Mv:
	LD	BC,X0400	; b3ba  01 00 04	...
	LD	DE,X1420	; b3bd  11 20 14	. .
	LD	A,(FIELD_COLOR)	; b3c0  3a ec b0	:l0
	CALL	PROCESS_ATTR_COLOR		; b3c3  cd 07 bc	M.<
	CALL	FILL_ATTR_RECT		; b3c6  cd f6 ba	Mv:
	LD	A,(TIMER_BAR_POS)	; b3c9  3a bf b0	:?0
	CP	28H		; b3cc  fe 28		~(
	LD	A,44H		; b3ce  3e 44		>D
	JR	NC,XB3D4	; b3d0  30 02		0.
	LD	A,42H		; b3d2  3e 42		>B
XB3D4:	CALL	PROCESS_ATTR_COLOR		; b3d4  cd 07 bc	M.<
	LD	BC,X0205	; b3d7  01 05 02	...
	LD	DE,X0216	; b3da  11 16 02	...
	CALL	FILL_ATTR_RECT		; b3dd  cd f6 ba	Mv:
	RET			; b3e0  c9		I
;
XB3E1:	DB	1FH,10H,0EH,3EH,7EH			; b3e1 ...>~
;
XB3E6:	NOP			; b3e6  00		.
;
	ORG	0B3F4H
;
XB3F4:	NOP			; b3f4  00		.
;
XB3F5:	DB	1EH					; b3f5 .
	DW	X1FE8		; b3f6   e8 1f      h.
;
	DB	8,0AH,1CH,4				; b3f8 ....
	DB	'~A New High Score'			; b3fc
	DB	1DH,1CH,4,7EH,1EH,68H,1FH,70H		; b40d ...~.h.p
	DB	14H,98H,99H,9AH,9BH,9CH,9DH,1FH		; b415 ........
	DB	10H,0CH					; b41d ..
	DB	'Please Enter Your Name'		; b41f
	DB	0,1EH					; b435 ..
	DW	X1FE8		; b437   e8 1f      h.
;
	DB	8,7,1CH,6				; b439 ....
	DB	'~High Scores'				; b43d
	DB	1DH,1CH,6,7EH,1EH,68H,1FH,1CH		; b449 ...~.h..
	DB	15H					; b451 .
	DB	'Return to Main Menu'			; b452
	DB	0,1FH,28H,8				; b465 ..(.
	DB	'(Standard Game)'			; b469
	DB	0,1FH,28H,8				; b478 ..(.
	DB	'(Customized Game)'			; b47c
	DB	0,1,15H,15H				; b48d ....
	DW	X01FF		; b491   ff 01      ..
;
	DB	1,7,11H,15H,10H,3EH,68H			; b493 .....>h
	DW	X70CD		; b49a   cd 70      Mp
	DW	X21BF		; b49c   bf 21      ?!
	DB	36H					; b49e 6
	DW	XCDB4		; b49f   b4 cd      4M
	DB	26H					; b4a1 &
	DW	X3ABC		; b4a2   bc 3a      <:
	DW	XB0F0		; b4a4   f0 b0      p0
;
	DB	21H,66H					; b4a6 !f
	DW	XCBB4		; b4a8   b4 cb      4K
;
	DB	7FH,28H,3,21H,79H			; b4aa .(.!y
	DW	XCDB4		; b4af   b4 cd      4M
;
	DB	26H,0BCH,6,0AH,21H,8DH,0C1H,3AH		; b4b1 &<..!.A:
	DB	0F0H,0B0H,0CBH,7FH,28H,4,11H,0AAH	; b4b9 p0K.(..*
	DB	0,19H,3EH,14H				; b4c1 ..>.
XB4C5:	DB	90H,0DDH,77H,1,0DDH,36H,0,10H		; b4c5 .]w.]6..
	DB	0E5H,0CDH,26H,0BCH,0E1H,11H,0FH,0	; b4cd eM&<a...
	DB	19H,0DDH,36H,0,80H,0C5H,5EH,23H		; b4d5 .]6..E^#
	DB	56H,23H,0E5H,0EBH,0CDH,0D8H,0BBH,0E1H	; b4dd V#ekMX;a
	DB	0C1H,10H,0DBH,21H,8EH,0B4H,0CDH,18H	; b4e5 A.[!.4M.
	DB	0BFH,0CDH,3AH,0BFH,30H,0FBH,0CDH,61H	; b4ed ?M:?0{Ma
	DB	0BFH,0CDH,3EH,0C0H,0C3H,0B7H,0B2H	; b4f5 ?M>@C72
;
XB4FC:	LD	IX,XC18D	; b4fc  dd 21 8d c1	]!.A
	LD	B,0AH		; b500  06 0a		..
	LD	A,(XB0F0)	; b502  3a f0 b0	:p0
	BIT	7,A		; b505  cb 7f		K.
	JR	Z,XB50E		; b507  28 05		(.
	LD	DE,X00AA	; b509  11 aa 00	.*.
	ADD	IX,DE		; b50c  dd 19		].
XB50E:	LD	L,(IX+0FH)	; b50e  dd 6e 0f	]n.
	LD	H,(IX+10H)	; b511  dd 66 10	]f.
	LD	DE,(BASE_SCORE)	; b514  ed 5b c3 b0	m[C0
	OR	A		; b518  b7		7
;
	DW	X52ED		; b519   ed 52      mR
;
	DB	38H,8,11H,11H,0				; b51b 8....
;
	ADD	IX,DE		; b520  dd 19		].
	DJNZ	XB50E		; b522  10 ea		.j
	RET			; b524  c9		I
;
	DW	X05C5		; b525   c5 05      E.
;
	DB	28H,1EH,78H,87H,87H,87H,87H,80H		; b527 (.x.....
	DB	4FH,6,0,21H,36H,0C2H,3AH		; b52f O..!6B:
	DW	XB0F0		; b536   f0 b0      p0
	DW	X7FCB		; b538   cb 7f      K.
;
	DB	28H,4,11H,0AAH,0,19H			; b53a (..*..
	DW	X21EB		; b540   eb 21      k!
	DW	XFFEF		; b542   ef ff      o.
	DB	19H					; b544 .
	DW	XB8ED		; b545   ed b8      m8
;
	DB	1,1,0AH,11H,15H,0CH,3EH,68H		; b547 ......>h
	DW	X70CD		; b54f   cd 70      Mp
	DW	X21BF		; b551   bf 21      ?!
	DW	XB3F5		; b553   f5 b3      u3
	DW	X26CD		; b555   cd 26      M&
	DW	XCDBC		; b557   bc cd      <M
	DB	8CH					; b559 .
	DW	XC1B5		; b55a   b5 c1      5A
;
	DB	3EH,0AH,90H,47H,87H,87H,87H,87H		; b55c >..G....
	DB	80H,5FH,16H,0				; b564 ._..
;
	LD	HL,XC18D	; b568  21 8d c1	!.A
	ADD	HL,DE		; b56b  19		.
	LD	A,(XB0F0)	; b56c  3a f0 b0	:p0
	BIT	7,A		; b56f  cb 7f		K.
	JR	Z,XB577		; b571  28 04		(.
	LD	DE,X00AA	; b573  11 aa 00	.*.
	ADD	HL,DE		; b576  19		.
XB577:	EX	DE,HL		; b577  eb		k
	LD	HL,XB3E6	; b578  21 e6 b3	!f3
	LD	BC,X000F	; b57b  01 0f 00	...
	LDIR			; b57e  ed b0		m0
	EX	DE,HL		; b580  eb		k
	LD	DE,(BASE_SCORE)	; b581  ed 5b c3 b0	m[C0
	LD	(HL),E		; b585  73		s
;
	DB	23H,72H					; b586 #r
	DW	X3ECD		; b588   cd 3e      M>
	DB	0C0H					; b58a @
	DW	XDDC9		; b58b   c9 dd      I]
;
	DB	21H,0A9H				; b58d !)
	DW	X0EBC		; b58f   bc 0e      <.
;
	DB	41H,21H,14H,10H,6,0AH,22H,0A9H		; b591 A!....")
	DW	X79BC		; b599   bc 79      <y
	DW	X5BFE		; b59b   fe 5b      ~[
;
	DB	30H,10H,0CDH				; b59d 0.M
	DW	XBCB5		; b5a0   b5 bc      5<
	DB	7DH					; b5a2 }
	DW	X10C6		; b5a3   c6 10      F.
;
	DB	6FH,0CH,10H				; b5a5 o..
	DW	X24EE		; b5a8   ee 24      n$
;
	DB	24H,2EH,14H,18H,0E6H,0AFH,32H,0F4H	; b5aa $...f/2t
	DB	0B3H,21H,0E6H,0B3H,36H,0		; b5b2 3!f36.
	DW	X86CD		; b5b8   cd 86      M.
	DW	XCDB6		; b5ba   b6 cd      6M
;
	DB	8DH,0B6H,0EH,0,0CDH			; b5bc .6..M
;
	RST	30H		; b5c1  f7		w
	CP	L		; b5c2  bd		=
	CALL	XBE41		; b5c3  cd 41 be	MA>
XB5C6:	CALL	XBEBA		; b5c6  cd ba be	M:>
	LD	HL,XBB4F	; b5c9  21 4f bb	!O;
	SET	7,(HL)		; b5cc  cb fe		K~
XB5CE:	BIT	7,(HL)		; b5ce  cb 7e		K~
	JR	NZ,XB5CE	; b5d0  20 fc		 |
	LD	C,80H		; b5d2  0e 80		..
	CALL	XBDF7		; b5d4  cd f7 bd	Mw=
	LD	HL,(XBDF0)	; b5d7  2a f0 bd	*p=
	LD	(XBDEE),HL	; b5da  22 ee bd	"n=
	LD	C,0		; b5dd  0e 00		..
	CALL	XBDF7		; b5df  cd f7 bd	Mw=
	CALL	XBE41		; b5e2  cd 41 be	MA>
	LD	A,(XBDF2)	; b5e5  3a f2 bd	:r=
	RRC	A		; b5e8  cb 0f		K.
	JR	NC,XB5C6	; b5ea  30 da		0Z
	LD	BC,(XBDEE)	; b5ec  ed 4b ee bd	mKn=
	LD	A,B		; b5f0  78		x
	SUB	7CH		; b5f1  d6 7c		V|
	JR	C,XB5C6		; b5f3  38 d1		8Q
	SRL	A		; b5f5  cb 3f		K?
	SRL	A		; b5f7  cb 3f		K?
	SRL	A		; b5f9  cb 3f		K?
	SRL	A		; b5fb  cb 3f		K?
	CP	3		; b5fd  fe 03		~.
	JR	NC,XB5C6	; b5ff  30 c5		0E
	LD	B,A		; b601  47		G
	LD	A,C		; b602  79		y
	SUB	10H		; b603  d6 10		V.
	JR	C,XB5C6		; b605  38 bf		8?
	SRL	A		; b607  cb 3f		K?
	SRL	A		; b609  cb 3f		K?
	SRL	A		; b60b  cb 3f		K?
	SRL	A		; b60d  cb 3f		K?
	CP	0AH		; b60f  fe 0a		~.
	JR	NC,XB5C6	; b611  30 b3		03
	LD	C,A		; b613  4f		O
	LD	A,B		; b614  78		x
	ADD	A,A		; b615  87		.
	ADD	A,A		; b616  87		.
	ADD	A,B		; b617  80		.
	ADD	A,A		; b618  87		.
	ADD	A,C		; b619  81		.
	CP	1DH		; b61a  fe 1d		~.
	JR	NC,XB5C6	; b61c  30 a8		0(
	CP	1CH		; b61e  fe 1c		~.
	JR	Z,XB67A		; b620  28 58		(X
	CP	1BH		; b622  fe 1b		~.
	JR	Z,XB654		; b624  28 2e		(.
	CP	1AH		; b626  fe 1a		~.
	JR	NZ,XB62C	; b628  20 02		 .
	LD	A,0DFH		; b62a  3e df		>_
XB62C:	ADD	A,41H		; b62c  c6 41		FA
	LD	C,A		; b62e  4f		O
	LD	A,(XB3F4)	; b62f  3a f4 b3	:t3
	CP	0DH		; b632  fe 0d		~.
	JR	NC,XB5C6	; b634  30 90		0.
	LD	E,A		; b636  5f		_
	LD	D,0		; b637  16 00		..
	INC	A		; b639  3c		<
	LD	(XB3F4),A	; b63a  32 f4 b3	2t3
	LD	HL,XB3E6	; b63d  21 e6 b3	!f3
	ADD	HL,DE		; b640  19		.
	LD	(HL),C		; b641  71		q
	INC	HL		; b642  23		#
	LD	(HL),0		; b643  36 00		6.
	CALL	XB686		; b645  cd 86 b6	M.6
	CALL	XB68D		; b648  cd 8d b6	M.6
	CALL	XBB11		; b64b  cd 11 bb	M.;
	CALL	XBAA9		; b64e  cd a9 ba	M):
	JP	XB5C6		; b651  c3 c6 b5	CF5
;
XB654:	LD	A,(XB3F4)	; b654  3a f4 b3	:t3
	OR	A		; b657  b7		7
	JP	Z,XB5C6		; b658  ca c6 b5	JF5
	DEC	A		; b65b  3d		=
	LD	(XB3F4),A	; b65c  32 f4 b3	2t3
	LD	E,A		; b65f  5f		_
	LD	D,0		; b660  16 00		..
	LD	HL,XB3E6	; b662  21 e6 b3	!f3
	ADD	HL,DE		; b665  19		.
	LD	(HL),0		; b666  36 00		6.
	LD	(XB3F4),A	; b668  32 f4 b3	2t3
	CALL	XB686		; b66b  cd 86 b6	M.6
	CALL	XB68D		; b66e  cd 8d b6	M.6
	CALL	XBB11		; b671  cd 11 bb	M.;
	CALL	XBAA9		; b674  cd a9 ba	M):
	JP	XB5C6		; b677  c3 c6 b5	CF5
;
XB67A:	CALL	XB686		; b67a  cd 86 b6	M.6
	LD	A,7EH		; b67d  3e 7e		>~
	CALL	XBCB5		; b67f  cd b5 bc	M5<
	CALL	XBB11		; b682  cd 11 bb	M.;
	RET			; b685  c9		I
;
XB686:	LD	HL,XB3E1	; b686  21 e1 b3	!a3
	CALL	STRING_RENDERER		; b689  cd 26 bc	M&<
	RET			; b68c  c9		I
;
XB68D:	LD	A,7FH		; b68d  3e 7f		>.
	CALL	XBCB5		; b68f  cd b5 bc	M5<
	LD	A,7EH		; b692  3e 7e		>~
	CALL	XBCB5		; b694  cd b5 bc	M5<
	RET			; b697  c9		I
;
	DB	1EH					; b698 .
	DW	X1FE8		; b699   e8 1f      h.
;
	DB	40H,5,1CH,6				; b69b @...
	DB	'~Setup Menu'				; b69f
	DB	1DH,1CH,8,7EH,1EH,68H,1FH,48H		; b6aa ...~.h.H
	DB	7,53H,6FH,75H,6EH,64H,1FH,0AAH		; b6b2 .Sound.*
	DB	7,59H,65H,73H,1FH,0D8H,7,4EH		; b6ba .Yes.X.N
	DB	6FH,1FH,48H,9				; b6c2 o.H.
	DB	'Colou'					; b6c6
Xb6cb:	DB	'r'					; b6cb
	DB	1FH					; b6cc .
;
	XOR	D		; b6cd  aa		*
	ADD	HL,BC		; b6ce  09		.
	LD	E,C		; b6cf  59		Y
	LD	H,L		; b6d0  65		e
	LD	(HL),E		; b6d1  73		s
	RRA			; b6d2  1f		.
	RET	C		; b6d3  d8		X
	ADD	HL,BC		; b6d4  09		.
	LD	C,(HL)		; b6d5  4e		N
	LD	L,A		; b6d6  6f		o
	RRA			; b6d7  1f		.
	LD	C,B		; b6d8  48		H
;
	DB	0BH					; b6d9 .
	DB	'Inverse Screen'			; b6da
	DB	1FH,0AAH,0BH,59H,65H,73H,1FH,0D8H	; b6e8 .*.Yes.X
	DB	0BH,4EH,6FH,1FH,48H,0DH			; b6f0 .No.H.
	DB	'Customize game'			; b6f6
	DB	1FH,0AAH,0DH,59H,65H,73H,1FH,0D8H	; b704 .*.Yes.X
	DB	0DH,4EH,6FH,1FH,48H,0FH			; b70c .No.H.
	DB	'Chasers'				; b712
	DB	1FH,0AAH,0FH,59H,65H,73H,1FH		; b719 .*.Yes.
;
	RET	C		; b720  d8		X
	RRCA			; b721  0f		.
	LD	C,(HL)		; b722  4e		N
	LD	L,A		; b723  6f		o
	RRA			; b724  1f		.
	LD	C,B		; b725  48		H
;
	DB	11H					; b726 .
	DB	'Timer Speed:'				; b727
	DB	1FH,48H,13H,46H,61H,73H,74H,1FH		; b733 .H.Fast.
	DB	88H,13H,4DH,65H,64H,1FH			; b73b ..Med.
	DW	X13C8		; b741   c8 13      H.
;
	DB	53H,6CH,6FH,77H,1FH,48H,15H		; b743 Slow.H.
	DB	'Return to Main Menu'			; b74a
	DB	0					; b75d .
XB75E:	DB	18H,7,2,1DH,7,2,18H,9			; b75e ........
	DB	2,1DH,9,2,18H,0BH,2,1DH			; b766 ........
	DB	0BH,2,18H,0DH,2,1DH,0DH,2		; b76e ........
	DB	18H,0FH,2,1DH,0FH,2,0DH,13H		; b776 ........
	DB	2,15H,13H,2,1DH,13H,2,8			; b77e ........
	DB	15H,17H					; b786 ..
	DW	X01FF		; b788   ff 01      ..
;
	DB	8,5,11H,17H,12H,3EH,68H			; b78a .....>h
	DW	X70CD		; b791   cd 70      Mp
	DW	X21BF		; b793   bf 21      ?!
	DB	98H					; b795 .
	DW	XCDB6		; b796   b6 cd      6M
;
	DB	26H,0BCH				; b798 &<
;
XB79A:	LD	B,5		; b79a  06 05		..
	LD	HL,XB0ED	; b79c  21 ed b0	!m0
	LD	IX,XBCA9	; b79f  dd 21 a9 bc	]!)<
XB7A3:	LD	A,B		; b7a3  78		x
	ADD	A,A		; b7a4  87		.
	NEG			; b7a5  ed 44		mD
	ADD	A,11H		; b7a7  c6 11		F.
	LD	(XBCAA),A	; b7a9  32 aa bc	2*<
	LD	(IX+0),0C4H	; b7ac  dd 36 00 c4	]6.D
	LD	A,9EH		; b7b0  3e 9e		>.
	BIT	0,(HL)		; b7b2  cb 46		KF
	JR	Z,XB7B7		; b7b4  28 01		(.
	INC	A		; b7b6  3c		<
XB7B7:	PUSH	AF		; b7b7  f5		u
	CALL	XBCB5		; b7b8  cd b5 bc	M5<
	LD	(IX+0),0ECH	; b7bb  dd 36 00 ec	]6.l
	POP	AF		; b7bf  f1		q
	NEG			; b7c0  ed 44		mD
	ADD	A,3DH		; b7c2  c6 3d		F=
	CALL	XBCB5		; b7c4  cd b5 bc	M5<
	INC	HL		; b7c7  23		#
	DJNZ	XB7A3		; b7c8  10 d9		.Y
	LD	(IX+1),13H	; b7ca  dd 36 01 13	]6..
XB7CE:	LD	B,3		; b7ce  06 03		..
XB7D0:	LD	A,3		; b7d0  3e 03		>.
	SUB	B		; b7d2  90		.
	LD	C,A		; b7d3  4f		O
	RRCA			; b7d4  0f		.
	RRCA			; b7d5  0f		.
	ADD	A,6CH		; b7d6  c6 6c		Fl
	LD	(IX+0),A	; b7d8  dd 77 00	]w.
	LD	A,(XB0F2)	; b7db  3a f2 b0	:r0
	CP	C		; b7de  b9		9
	LD	A,9EH		; b7df  3e 9e		>.
	JR	NZ,XB7E4	; b7e1  20 01		 .
	INC	A		; b7e3  3c		<
XB7E4:	CALL	XBCB5		; b7e4  cd b5 bc	M5<
	DJNZ	XB7D0		; b7e7  10 e7		.g
XB7E9:	LD	HL,XB75E	; b7e9  21 5e b7	!^7
	CALL	XBF18		; b7ec  cd 18 bf	M.?
XB7EF:	CALL	XBF3A		; b7ef  cd 3a bf	M:?
	JR	NC,XB7EF	; b7f2  30 fb		0{
	CALL	XBF61		; b7f4  cd 61 bf	Ma?
	LD	A,(XBDF6)	; b7f7  3a f6 bd	:v=
	CP	0AH		; b7fa  fe 0a		~.
	JR	NC,XB838	; b7fc  30 3a		0:
	CP	8		; b7fe  fe 08		~.
	JR	C,XB809		; b800  38 07		8.
	LD	HL,XB0F0	; b802  21 f0 b0	!p0
	BIT	0,(HL)		; b805  cb 46		KF
	JR	Z,XB7E9		; b807  28 e0		(`
XB809:	LD	E,A		; b809  5f		_
	SRL	E		; b80a  cb 3b		K;
	LD	D,0		; b80c  16 00		..
	LD	HL,XB0ED	; b80e  21 ed b0	!m0
	ADD	HL,DE		; b811  19		.
	RRCA			; b812  0f		.
	CCF			; b813  3f		?
	SBC	A,A		; b814  9f		.
	LD	(HL),A		; b815  77		w
	LD	A,(XBDF6)	; b816  3a f6 bd	:v=
	CP	6		; b819  fe 06		~.
	JP	C,XB79A		; b81b  da 9a b7	Z.7
	CP	8		; b81e  fe 08		~.
	JP	NC,XB79A	; b820  d2 9a b7	R.7
	LD	HL,XB0F3	; b823  21 f3 b0	!s0
	LD	DE,XB0F1	; b826  11 f1 b0	.q0
	LD	B,2		; b829  06 02		..
XB82B:	LD	C,(HL)		; b82b  4e		N
	LD	A,(DE)		; b82c  1a		.
	EX	DE,HL		; b82d  eb		k
	LD	(HL),C		; b82e  71		q
	LD	(DE),A		; b82f  12		.
	EX	DE,HL		; b830  eb		k
	INC	HL		; b831  23		#
	INC	DE		; b832  13		.
	DJNZ	XB82B		; b833  10 f6		.v
	JP	XB79A		; b835  c3 9a b7	C.7
;
XB838:	CP	0DH		; b838  fe 0d		~.
	JR	NC,XB84C	; b83a  30 10		0.
	LD	HL,XB0F0	; b83c  21 f0 b0	!p0
	BIT	0,(HL)		; b83f  cb 46		KF
	JP	Z,XB7E9		; b841  ca e9 b7	Ji7
	SUB	0AH		; b844  d6 0a		V.
	LD	(XB0F2),A	; b846  32 f2 b0	2r0
	JP	XB79A		; b849  c3 9a b7	C.7
;
XB84C:	CALL	RESTORE_RECT		; b84c  cd 3e c0	M>@
	CALL	RESTORE_RECT		; b84f  cd 3e c0	M>@
	CALL	XB39E		; b852  cd 9e b3	M.3
	LD	A,(XB0F2)	; b855  3a f2 b0	:r0
	ADD	A,A		; b858  87		.
	ADD	A,A		; b859  87		.
	ADD	A,0AH		; b85a  c6 0a		F.
	LD	(TIMER_SPEED),A	; b85c  32 ea b0	2j0
	JP	XB2A6		; b85f  c3 a6 b2	C&2
;
	DB	1EH					; b862 .
	DW	X1FE8		; b863   e8 1f      h.
;
	DB	8,7,1CH,3				; b865 ....
	DB	'~Keys Menu'				; b869
	DB	1DH,1CH,9,7EH,1EH,68H,1FH,20H		; b873 ...~.h. 
	DB	0FH					; b87b .
	DB	'Alter Keys'				; b87c
	DB	1FH,20H,10H				; b886 . .
	DB	'Kempston Joystick'			; b889
	DB	1FH,20H,11H				; b89a . .
	DB	'Sinclair Joystick'			; b89d
	DB	1FH,20H,12H				; b8ae . .
	DB	'Protek Joystick'			; b8b1
	DB	1FH,20H,13H				; b8c0 . .
	DB	'Return to Main Menu'			; b8c3
	DB	1FH,28H,9,4CH,65H,66H,74H,1FH		; b8d6 .(.Left.
	DB	28H,0AH					; b8de (.
	DB	'Rig'					; b8e0
Xb8e3:	DB	'ht'					; b8e3
	DB	1FH,28H,0BH,55H,70H,1FH,28H,0CH		; b8e5 .(.Up.(.
XB8ED:	DB	44H,6FH,77H,6EH,1FH,28H,0DH,46H		; b8ed Down.(.F
	DB	69H,72H,65H,1FH,0CH,15H			; b8f5 ire...
	DB	'(Break for default keys)'		; b8fb
	DB	0					; b913 .
Xb914:	DB	'          '				; b914
	DB	0					; b91e .
XB91F:	DB	1,0FH,14H,1,10H,14H,1,11H		; b91f ........
	DB	14H,1,12H,14H,1,13H,14H			; b927 .......
	DW	X01FF		; b92e   ff 01      ..
;
	DB	1,7,11H,14H,10H,3EH,68H			; b930 .....>h
	DW	X70CD		; b937   cd 70      Mp
	DW	X21BF		; b939   bf 21      ?!
;
	DB	62H,0B8H				; b93b b8
	DW	X26CD		; b93d   cd 26      M&
	DW	XCDBC		; b93f   bc cd      <M
;
	DB	14H,0BAH				; b941 .:
;
XB943:	LD	HL,XB91F	; b943  21 1f b9	!.9
	CALL	XBF18		; b946  cd 18 bf	M.?
XB949:	CALL	XBF3A		; b949  cd 3a bf	M:?
	CALL	XB9DC		; b94c  cd dc b9	M\9
	JR	NC,XB949	; b94f  30 f8		0x
	CALL	XBF61		; b951  cd 61 bf	Ma?
	LD	A,(XBDF6)	; b954  3a f6 bd	:v=
	CP	4		; b957  fe 04		~.
	JP	Z,XB9D6		; b959  ca d6 b9	JV9
	OR	A		; b95c  b7		7
	JR	NZ,XB9B7	; b95d  20 58		 X
	CALL	XB9FD		; b95f  cd fd b9	M}9
	LD	HL,XBACE	; b962  21 ce ba	!N:
	LD	(HL),0FFH	; b965  36 ff		6.
	LD	DE,XBACF	; b967  11 cf ba	.O:
	LD	BC,X0004	; b96a  01 04 00	...
	LDIR			; b96d  ed b0		m0
	LD	B,5		; b96f  06 05		..
	LD	DE,X0950	; b971  11 50 09	.P.
	LD	HL,XBACE	; b974  21 ce ba	!N:
XB977:	PUSH	BC		; b977  c5		E
	PUSH	DE		; b978  d5		U
	PUSH	HL		; b979  e5		e
	LD	(XBCA9),DE	; b97a  ed 53 a9 bc	mS)<
XB97E:	CALL	XBA35		; b97e  cd 35 ba	M5:
	LD	A,D		; b981  7a		z
	OR	A		; b982  b7		7
	JR	NZ,XB97E	; b983  20 f9		 y
XB985:	CALL	XBA35		; b985  cd 35 ba	M5:
	LD	A,D		; b988  7a		z
	CP	1		; b989  fe 01		~.
	JR	NZ,XB985	; b98b  20 f8		 x
	LD	A,E		; b98d  7b		{
	LD	B,5		; b98e  06 05		..
	LD	HL,XBACE	; b990  21 ce ba	!N:
XB993:	CP	(HL)		; b993  be		>
	JR	Z,XB97E		; b994  28 e8		(h
	INC	HL		; b996  23		#
	DJNZ	XB993		; b997  10 fa		.z
	POP	HL		; b999  e1		a
	LD	(HL),A		; b99a  77		w
	INC	HL		; b99b  23		#
	PUSH	HL		; b99c  e5		e
	LD	HL,XC2E1	; b99d  21 e1 c2	!aB
	CALL	XBB3B		; b9a0  cd 3b bb	M;;
	CALL	STRING_RENDERER		; b9a3  cd 26 bc	M&<
	POP	HL		; b9a6  e1		a
	POP	DE		; b9a7  d1		Q
	INC	D		; b9a8  14		.
	POP	BC		; b9a9  c1		A
	DJNZ	XB977		; b9aa  10 cb		.K
	LD	A,19H		; b9ac  3e 19		>.
	CALL	FRAME_DELAY		; b9ae  cd 48 bb	MH;
	CALL	XBAA9		; b9b1  cd a9 ba	M):
	JP	XB943		; b9b4  c3 43 b9	CC9
;
XB9B7:	PUSH	AF		; b9b7  f5		u
	CALL	XB9FD		; b9b8  cd fd b9	M}9
	POP	AF		; b9bb  f1		q
	DEC	A		; b9bc  3d		=
	LD	C,A		; b9bd  4f		O
	ADD	A,A		; b9be  87		.
	ADD	A,A		; b9bf  87		.
	ADD	A,C		; b9c0  81		.
	LD	E,A		; b9c1  5f		_
	LD	D,0		; b9c2  16 00		..
	LD	HL,XBAD3	; b9c4  21 d3 ba	!S:
	ADD	HL,DE		; b9c7  19		.
	LD	DE,XBACE	; b9c8  11 ce ba	.N:
	LD	BC,X0005	; b9cb  01 05 00	...
	LDIR			; b9ce  ed b0		m0
	CALL	XBA14		; b9d0  cd 14 ba	M.:
	JP	XB943		; b9d3  c3 43 b9	CC9
;
XB9D6:	CALL	RESTORE_RECT		; b9d6  cd 3e c0	M>@
	JP	XB2B7		; b9d9  c3 b7 b2	C72
;
XB9DC:	PUSH	AF		; b9dc  f5		u
	CALL	XBA9D		; b9dd  cd 9d ba	M.:
	JR	C,XB9FB		; b9e0  38 19		8.
	LD	HL,XBAE2	; b9e2  21 e2 ba	!b:
	LD	DE,XBACE	; b9e5  11 ce ba	.N:
	LD	BC,X0005	; b9e8  01 05 00	...
	LDIR			; b9eb  ed b0		m0
	CALL	XB9FD		; b9ed  cd fd b9	M}9
	CALL	XBA14		; b9f0  cd 14 ba	M.:
XB9F3:	CALL	XBA9D		; b9f3  cd 9d ba	M.:
	JR	NC,XB9F3	; b9f6  30 fb		0{
	CALL	XBAA9		; b9f8  cd a9 ba	M):
XB9FB:	POP	AF		; b9fb  f1		q
	RET			; b9fc  c9		I
;
XB9FD:	LD	B,5		; b9fd  06 05		..
	LD	DE,X0950	; b9ff  11 50 09	.P.
XBA02:	PUSH	BC		; ba02  c5		E
	PUSH	DE		; ba03  d5		U
	LD	(XBCA9),DE	; ba04  ed 53 a9 bc	mS)<
	LD	HL,XB914	; ba08  21 14 b9	!.9
	CALL	STRING_RENDERER		; ba0b  cd 26 bc	M&<
	POP	DE		; ba0e  d1		Q
	INC	D		; ba0f  14		.
	POP	BC		; ba10  c1		A
	DJNZ	XBA02		; ba11  10 ef		.o
	RET			; ba13  c9		I
;
XBA14:	LD	B,5		; ba14  06 05		..
	LD	DE,X0950	; ba16  11 50 09	.P.
	LD	HL,XBACE	; ba19  21 ce ba	!N:
XBA1C:	PUSH	BC		; ba1c  c5		E
	PUSH	DE		; ba1d  d5		U
	LD	(XBCA9),DE	; ba1e  ed 53 a9 bc	mS)<
	LD	A,(HL)		; ba22  7e		~
	INC	HL		; ba23  23		#
	PUSH	HL		; ba24  e5		e
	LD	HL,XC2E1	; ba25  21 e1 c2	!aB
	CALL	XBB3B		; ba28  cd 3b bb	M;;
	CALL	STRING_RENDERER		; ba2b  cd 26 bc	M&<
	POP	HL		; ba2e  e1		a
	POP	DE		; ba2f  d1		Q
	INC	D		; ba30  14		.
	POP	BC		; ba31  c1		A
	DJNZ	XBA1C		; ba32  10 e8		.h
	RET			; ba34  c9		I
;
XBA35:	LD	HL,XBABC	; ba35  21 bc ba	!<:
	LD	B,8		; ba38  06 08		..
	LD	DE,X0000	; ba3a  11 00 00	...
XBA3D:	PUSH	BC		; ba3d  c5		E
	LD	C,(HL)		; ba3e  4e		N
	INC	HL		; ba3f  23		#
	LD	B,(HL)		; ba40  46		F
	INC	HL		; ba41  23		#
	IN	A,(C)		; ba42  ed 78		mx
	CPL			; ba44  2f		/
	LD	C,A		; ba45  4f		O
	LD	B,5		; ba46  06 05		..
XBA48:	SRL	C		; ba48  cb 39		K9
	JR	NC,XBA53	; ba4a  30 07		0.
	BIT	7,D		; ba4c  cb 7a		Kz
	JR	NZ,XBA64	; ba4e  20 14		 .
	LD	E,D		; ba50  5a		Z
	SET	7,D		; ba51  cb fa		Kz
XBA53:	INC	D		; ba53  14		.
	DJNZ	XBA48		; ba54  10 f2		.r
	LD	A,D		; ba56  7a		z
	ADD	A,3		; ba57  c6 03		F.
	LD	D,A		; ba59  57		W
	POP	BC		; ba5a  c1		A
	DJNZ	XBA3D		; ba5b  10 e0		.`
	BIT	7,D		; ba5d  cb 7a		Kz
	LD	D,0		; ba5f  16 00		..
	RET	Z		; ba61  c8		H
	INC	D		; ba62  14		.
	RET			; ba63  c9		I
;
XBA64:	POP	BC		; ba64  c1		A
	LD	D,2		; ba65  16 02		..
	RET			; ba67  c9		I
;
