; ==========================================================================
; SPRITE & FONT DATA ($F000-$FFFF)
; ==========================================================================
;
; ENTITY SPRITES ($F000-$F2FF):
;   Each entity has 256 bytes = 8 alignment variants x 32 bytes.
;   Each variant: 8 rows x 4 bytes (mask1, data1, mask2, data2).
;   Composited via: screen = (screen AND mask) OR data.
;
;   $F000: Player — hollow circle outline
;   $F100: Chaser — pac-man eye shape
;   $F200: Trail Cursor — checkerboard pattern
;
; GAME FONT ($F700-$F9FF):
;   96 characters x 8 bytes = 768 bytes.
;   Full printable ASCII range (space through tilde).
;   Wider/bolder glyphs than standard ZX ROM font.
;   Used for: game over text, start screen, general text.
;
; HUD FONT ($FA00-$FAFF):
;   32 characters x 8 bytes = 256 bytes.
;   Rendered double-height (8x16) by $D386.
;   Limited charset: 0-9, space, %, S, c, o, r, e, L, v, l, i, s, T, m
;   Just enough for "Score", "Level", "Time", "Lives", numbers, "%".
;
; CELL MASK TABLE ($FB00, 4 bytes):
;   $C0, $30, $0C, $03 — selects which 2-bit cell within a byte.
;   Index = X & 3.
;
; ROW POINTER TABLE ($FC00+):
;   Pre-computed screen line addresses for game field rows.
;   Avoids recomputing the ZX Spectrum's non-linear row layout each time.
;


; --- Player sprite data ---
SPRITE_PLAYER:
	RST	38H		; f000  ff		.
	NOP			; f001  00		.
	RST	38H		; f002  ff		.
	NOP			; f003  00		.
	JP	XFF3C		; f004  c3 3c ff	C<.
;
	NOP			; f007  00		.
	ADD	A,C		; f008  81		.
	LD	B,D		; f009  42		B
	RST	38H		; f00a  ff		.
	NOP			; f00b  00		.
	ADD	A,C		; f00c  81		.
	LD	B,D		; f00d  42		B
	RST	38H		; f00e  ff		.
	NOP			; f00f  00		.
	ADD	A,C		; f010  81		.
	LD	B,D		; f011  42		B
	RST	38H		; f012  ff		.
	NOP			; f013  00		.
	ADD	A,C		; f014  81		.
	LD	B,D		; f015  42		B
	RST	38H		; f016  ff		.
	NOP			; f017  00		.
	JP	XFF3C		; f018  c3 3c ff	C<.
;
	NOP			; f01b  00		.
	RST	38H		; f01c  ff		.
	NOP			; f01d  00		.
	RST	38H		; f01e  ff		.
	NOP			; f01f  00		.
	RST	38H		; f020  ff		.
	NOP			; f021  00		.
	RST	38H		; f022  ff		.
	NOP			; f023  00		.
;
	DB	0E1H,1EH				; f024 a.
	DW	X00FF		; f026   ff 00      ..
	DW	X21C0		; f028   c0 21      @!
	DW	X00FF		; f02a   ff 00      ..
	DW	X21C0		; f02c   c0 21      @!
	DW	X00FF		; f02e   ff 00      ..
;
	DB	0C0H					; f030 @
;
	LD	HL,X00FF	; f031  21 ff 00	!..
	RET	NZ		; f034  c0		@
	LD	HL,X00FF	; f035  21 ff 00	!..
	POP	HL		; f038  e1		a
	LD	E,0FFH		; f039  1e ff		..
	NOP			; f03b  00		.
	RST	38H		; f03c  ff		.
	NOP			; f03d  00		.
	RST	38H		; f03e  ff		.
	NOP			; f03f  00		.
	RST	38H		; f040  ff		.
	NOP			; f041  00		.
	RST	38H		; f042  ff		.
	NOP			; f043  00		.
	RET	P		; f044  f0		p
	RRCA			; f045  0f		.
	RST	38H		; f046  ff		.
	NOP			; f047  00		.
	RET	PO		; f048  e0		`
	DJNZ	XF0CA		; f049  10 7f		..
	ADD	A,B		; f04b  80		.
	RET	PO		; f04c  e0		`
	DJNZ	XF0CE		; f04d  10 7f		..
	ADD	A,B		; f04f  80		.
	RET	PO		; f050  e0		`
	DJNZ	XF0D2		; f051  10 7f		..
	ADD	A,B		; f053  80		.
	RET	PO		; f054  e0		`
	DJNZ	XF0D6		; f055  10 7f		..
	ADD	A,B		; f057  80		.
	RET	P		; f058  f0		p
	RRCA			; f059  0f		.
	RST	38H		; f05a  ff		.
	NOP			; f05b  00		.
	RST	38H		; f05c  ff		.
	NOP			; f05d  00		.
	RST	38H		; f05e  ff		.
	NOP			; f05f  00		.
	RST	38H		; f060  ff		.
	NOP			; f061  00		.
	RST	38H		; f062  ff		.
	NOP			; f063  00		.
	RET	M		; f064  f8		x
	RLCA			; f065  07		.
	LD	A,A		; f066  7f		.
	ADD	A,B		; f067  80		.
	RET	P		; f068  f0		p
	EX	AF,AF'		; f069  08		.
	CCF			; f06a  3f		?
	LD	B,B		; f06b  40		@
	RET	P		; f06c  f0		p
	EX	AF,AF'		; f06d  08		.
	CCF			; f06e  3f		?
	LD	B,B		; f06f  40		@
	RET	P		; f070  f0		p
	EX	AF,AF'		; f071  08		.
	CCF			; f072  3f		?
	LD	B,B		; f073  40		@
	RET	P		; f074  f0		p
	EX	AF,AF'		; f075  08		.
	CCF			; f076  3f		?
	LD	B,B		; f077  40		@
	RET	M		; f078  f8		x
	RLCA			; f079  07		.
	LD	A,A		; f07a  7f		.
	ADD	A,B		; f07b  80		.
	RST	38H		; f07c  ff		.
	NOP			; f07d  00		.
	RST	38H		; f07e  ff		.
XF07F:	NOP			; f07f  00		.
	RST	38H		; f080  ff		.
	NOP			; f081  00		.
	RST	38H		; f082  ff		.
	NOP			; f083  00		.
	CALL	M,X3F03		; f084  fc 03 3f	|.?
	RET	NZ		; f087  c0		@
	RET	M		; f088  f8		x
XF089:	INC	B		; f089  04		.
	RRA			; f08a  1f		.
	JR	NZ,XF085	; f08b  20 f8		 x
XF08D:	INC	B		; f08d  04		.
	RRA			; f08e  1f		.
	JR	NZ,XF089	; f08f  20 f8		 x
	INC	B		; f091  04		.
	RRA			; f092  1f		.
	JR	NZ,XF08D	; f093  20 f8		 x
XF095:	INC	B		; f095  04		.
	RRA			; f096  1f		.
	JR	NZ,XF095	; f097  20 fc		 |
	INC	BC		; f099  03		.
	CCF			; f09a  3f		?
	RET	NZ		; f09b  c0		@
	RST	38H		; f09c  ff		.
	NOP			; f09d  00		.
	RST	38H		; f09e  ff		.
	NOP			; f09f  00		.
	RST	38H		; f0a0  ff		.
	NOP			; f0a1  00		.
	RST	38H		; f0a2  ff		.
	NOP			; f0a3  00		.
	CP	1		; f0a4  fe 01		~.
	RRA			; f0a6  1f		.
	RET	PO		; f0a7  e0		`
	CALL	M,X0F02		; f0a8  fc 02 0f	|..
	DJNZ	XF0A9		; f0ab  10 fc		.|
XF0AD:	LD	(BC),A		; f0ad  02		.
	RRCA			; f0ae  0f		.
	DJNZ	XF0AD		; f0af  10 fc		.|
XF0B1:	LD	(BC),A		; f0b1  02		.
	RRCA			; f0b2  0f		.
	DJNZ	XF0B1		; f0b3  10 fc		.|
	LD	(BC),A		; f0b5  02		.
	RRCA			; f0b6  0f		.
XF0B7:	DJNZ	XF0B7		; f0b7  10 fe		.~
	LD	BC,XE01F	; f0b9  01 1f e0	..`
	RST	38H		; f0bc  ff		.
	NOP			; f0bd  00		.
	RST	38H		; f0be  ff		.
XF0BF:	NOP			; f0bf  00		.
	RST	38H		; f0c0  ff		.
	NOP			; f0c1  00		.
	RST	38H		; f0c2  ff		.
	NOP			; f0c3  00		.
	RST	38H		; f0c4  ff		.
	NOP			; f0c5  00		.
	RRCA			; f0c6  0f		.
	RET	P		; f0c7  f0		p
	CP	1		; f0c8  fe 01		~.
XF0CA:	RLCA			; f0ca  07		.
	EX	AF,AF'		; f0cb  08		.
	CP	1		; f0cc  fe 01		~.
XF0CE:	RLCA			; f0ce  07		.
	EX	AF,AF'		; f0cf  08		.
	CP	1		; f0d0  fe 01		~.
XF0D2:	RLCA			; f0d2  07		.
	EX	AF,AF'		; f0d3  08		.
	CP	1		; f0d4  fe 01		~.
XF0D6:	RLCA			; f0d6  07		.
	EX	AF,AF'		; f0d7  08		.
	RST	38H		; f0d8  ff		.
	NOP			; f0d9  00		.
	RRCA			; f0da  0f		.
	RET	P		; f0db  f0		p
	RST	38H		; f0dc  ff		.
	NOP			; f0dd  00		.
	RST	38H		; f0de  ff		.
	NOP			; f0df  00		.
	RST	38H		; f0e0  ff		.
XF0E1:	NOP			; f0e1  00		.
	RST	38H		; f0e2  ff		.
	NOP			; f0e3  00		.
	RST	38H		; f0e4  ff		.
	NOP			; f0e5  00		.
	ADD	A,A		; f0e6  87		.
	LD	A,B		; f0e7  78		x
	RST	38H		; f0e8  ff		.
	NOP			; f0e9  00		.
	INC	BC		; f0ea  03		.
	ADD	A,H		; f0eb  84		.
	RST	38H		; f0ec  ff		.
	NOP			; f0ed  00		.
	INC	BC		; f0ee  03		.
	ADD	A,H		; f0ef  84		.
	RST	38H		; f0f0  ff		.
	NOP			; f0f1  00		.
	INC	BC		; f0f2  03		.
	ADD	A,H		; f0f3  84		.
	RST	38H		; f0f4  ff		.
	NOP			; f0f5  00		.
	INC	BC		; f0f6  03		.
	ADD	A,H		; f0f7  84		.
	RST	38H		; f0f8  ff		.
	NOP			; f0f9  00		.
	ADD	A,A		; f0fa  87		.
	LD	A,B		; f0fb  78		x
	RST	38H		; f0fc  ff		.
	NOP			; f0fd  00		.
	RST	38H		; f0fe  ff		.
XF0FF:	NOP			; f0ff  00		.

; --- Chaser sprite data ---
SPRITE_CHASER:
	RST	38H		; f100  ff		.
	NOP			; f101  00		.
	RST	38H		; f102  ff		.
	NOP			; f103  00		.
	JP	XFF3C		; f104  c3 3c ff	C<.
;
	NOP			; f107  00		.
;
	DB	81H,72H					; f108 .r
	DW	X00FF		; f10a   ff 00      ..
;
	DB	81H,7AH					; f10c .z
	DW	X00FF		; f10e   ff 00      ..
;
	DB	81H,7EH					; f110 .~
	DW	X00FF		; f112   ff 00      ..
;
	DB	81H,7EH					; f114 .~
	DW	X00FF		; f116   ff 00      ..
	DW	X3CC3		; f118   c3 3c      C<
	DW	X00FF		; f11a   ff 00      ..
	DW	X00FF		; f11c   ff 00      ..
	DW	X00FF		; f11e   ff 00      ..
	DW	X00FF		; f120   ff 00      ..
	DW	X00FF		; f122   ff 00      ..
;
	DB	0E1H,1EH				; f124 a.
	DW	X00FF		; f126   ff 00      ..
	DW	X39C0		; f128   c0 39      @9
	DW	X00FF		; f12a   ff 00      ..
	DW	X3DC0		; f12c   c0 3d      @=
	DW	X00FF		; f12e   ff 00      ..
	DW	X3FC0		; f130   c0 3f      @?
	DW	X00FF		; f132   ff 00      ..
	DW	X3FC0		; f134   c0 3f      @?
	DW	X00FF		; f136   ff 00      ..
;
	DB	0E1H,1EH				; f138 a.
	DW	X00FF		; f13a   ff 00      ..
	DW	X00FF		; f13c   ff 00      ..
	DW	X00FF		; f13e   ff 00      ..
	DW	X00FF		; f140   ff 00      ..
	DW	X00FF		; f142   ff 00      ..
	DW	X0FF0		; f144   f0 0f      p.
	DW	X00FF		; f146   ff 00      ..
;
	DB	0E0H,1CH,7FH,80H,0E0H,1EH,7FH,80H	; f148 `...`...
	DB	0E0H,1FH,7FH,80H,0E0H,1FH,7FH,80H	; f150 `...`...
	DW	X0FF0		; f158   f0 0f      p.
	DW	X00FF		; f15a   ff 00      ..
	DW	X00FF		; f15c   ff 00      ..
	DW	X00FF		; f15e   ff 00      ..
	DW	X00FF		; f160   ff 00      ..
	DW	X00FF		; f162   ff 00      ..
;
	DB	0F8H,7,7FH,80H				; f164 x...
	DW	X0EF0		; f168   f0 0e      p.
;
	DB	3FH,40H					; f16a ?@
	DW	X0FF0		; f16c   f0 0f      p.
;
	DB	3FH,40H					; f16e ?@
	DW	X0FF0		; f170   f0 0f      p.
;
	DB	3FH,0C0H				; f172 ?@
	DW	X0FF0		; f174   f0 0f      p.
;
	DB	3FH,0C0H,0F8H,7,7FH,80H			; f176 ?@x...
	DW	X00FF		; f17c   ff 00      ..
	DW	X00FF		; f17e   ff 00      ..
	DW	X00FF		; f180   ff 00      ..
	DW	X00FF		; f182   ff 00      ..
	DW	X03FC		; f184   fc 03      |.
;
	DB	3FH,0C0H,0F8H,7,1FH,20H,0F8H,7		; f186 ?@x.. x.
	DB	1FH,0A0H,0F8H,7,1FH,0E0H,0F8H,7		; f18e . x..`x.
	DB	1FH,0E0H				; f196 .`
	DW	X03FC		; f198   fc 03      |.
;
	DB	3FH,0C0H				; f19a ?@
	DW	X00FF		; f19c   ff 00      ..
	DW	X00FF		; f19e   ff 00      ..
	DW	X00FF		; f1a0   ff 00      ..
	DW	X00FF		; f1a2   ff 00      ..
	DW	X01FE		; f1a4   fe 01      ~.
;
	DB	1FH,0E0H				; f1a6 .`
	DW	X03FC		; f1a8   fc 03      |.
;
	DB	0FH,90H					; f1aa ..
	DW	X03FC		; f1ac   fc 03      |.
;
	DB	0FH,0D0H				; f1ae .P
	DW	X03FC		; f1b0   fc 03      |.
	DB	0FH					; f1b2 .
	DW	XFCF0		; f1b3   f0 fc      p|
;
	DB	3,0FH					; f1b5 ..
	DW	XFEF0		; f1b7   f0 fe      p~
;
	DB	1,1FH,0E0H				; f1b9 ..`
	DW	X00FF		; f1bc   ff 00      ..
	DW	X00FF		; f1be   ff 00      ..
	DW	X00FF		; f1c0   ff 00      ..
	DW	X00FF		; f1c2   ff 00      ..
;
	DB	0FFH					; f1c4 .
;
	NOP			; f1c5  00		.
	RRCA			; f1c6  0f		.
	RET	P		; f1c7  f0		p
	CP	1		; f1c8  fe 01		~.
	RLCA			; f1ca  07		.
	RET	Z		; f1cb  c8		H
	CP	1		; f1cc  fe 01		~.
	RLCA			; f1ce  07		.
	RET	PE		; f1cf  e8		h
	CP	1		; f1d0  fe 01		~.
	RLCA			; f1d2  07		.
	RET	M		; f1d3  f8		x
	CP	1		; f1d4  fe 01		~.
	RLCA			; f1d6  07		.
	RET	M		; f1d7  f8		x
	RST	38H		; f1d8  ff		.
	NOP			; f1d9  00		.
	RRCA			; f1da  0f		.
	RET	P		; f1db  f0		p
	RST	38H		; f1dc  ff		.
	NOP			; f1dd  00		.
	RST	38H		; f1de  ff		.
	NOP			; f1df  00		.
	RST	38H		; f1e0  ff		.
	NOP			; f1e1  00		.
	RST	38H		; f1e2  ff		.
	NOP			; f1e3  00		.
	RST	38H		; f1e4  ff		.
	NOP			; f1e5  00		.
	ADD	A,A		; f1e6  87		.
	LD	A,B		; f1e7  78		x
	RST	38H		; f1e8  ff		.
	NOP			; f1e9  00		.
	INC	BC		; f1ea  03		.
	CALL	PO,X00FF	; f1eb  e4 ff 00	d..
	INC	BC		; f1ee  03		.
	CALL	P,X00FF		; f1ef  f4 ff 00	t..
	INC	BC		; f1f2  03		.
	CALL	M,X00FF		; f1f3  fc ff 00	|..
	INC	BC		; f1f6  03		.
	CALL	M,X00FF		; f1f7  fc ff 00	|..
	ADD	A,A		; f1fa  87		.
	LD	A,B		; f1fb  78		x
	RST	38H		; f1fc  ff		.
	NOP			; f1fd  00		.
	RST	38H		; f1fe  ff		.
XF1FF:	NOP			; f1ff  00		.

; --- Cursor sprite data ---
SPRITE_CURSOR:
	RST	38H		; f200  ff		.
	NOP			; f201  00		.
	RST	38H		; f202  ff		.
	NOP			; f203  00		.
	JP	XFF3C		; f204  c3 3c ff	C<.
;
	NOP			; f207  00		.
;
	DB	81H,6AH					; f208 .j
	DW	X00FF		; f20a   ff 00      ..
;
	DB	81H,56H					; f20c .V
	DW	X00FF		; f20e   ff 00      ..
;
	DB	81H,6AH					; f210 .j
	DW	X00FF		; f212   ff 00      ..
;
	DB	81H,56H					; f214 .V
	DW	X00FF		; f216   ff 00      ..
	DW	X3CC3		; f218   c3 3c      C<
	DW	X00FF		; f21a   ff 00      ..
	DW	X00FF		; f21c   ff 00      ..
	DW	X00FF		; f21e   ff 00      ..
	DW	X00FF		; f220   ff 00      ..
	DW	X00FF		; f222   ff 00      ..
;
	DB	0E1H,1EH				; f224 a.
	DW	X00FF		; f226   ff 00      ..
	DW	X35C0		; f228   c0 35      @5
	DW	X00FF		; f22a   ff 00      ..
	DW	X2BC0		; f22c   c0 2b      @+
	DW	X00FF		; f22e   ff 00      ..
	DW	X35C0		; f230   c0 35      @5
	DW	X00FF		; f232   ff 00      ..
	DW	X2BC0		; f234   c0 2b      @+
	DW	X00FF		; f236   ff 00      ..
;
	DB	0E1H,1EH				; f238 a.
	DW	X00FF		; f23a   ff 00      ..
	DW	X00FF		; f23c   ff 00      ..
	DW	X00FF		; f23e   ff 00      ..
	DW	X00FF		; f240   ff 00      ..
	DW	X00FF		; f242   ff 00      ..
	DW	X0FF0		; f244   f0 0f      p.
	DW	X00FF		; f246   ff 00      ..
;
	DB	0E0H,1AH,7FH,80H,0E0H,15H,7FH,80H	; f248 `...`...
	DB	0E0H,1AH,7FH,80H,0E0H,15H,7FH,80H	; f250 `...`...
	DW	X0FF0		; f258   f0 0f      p.
	DW	X00FF		; f25a   ff 00      ..
	DW	X00FF		; f25c   ff 00      ..
	DW	X00FF		; f25e   ff 00      ..
	DW	X00FF		; f260   ff 00      ..
	DW	X00FF		; f262   ff 00      ..
;
	DB	0F8H,7,7FH,80H				; f264 x...
	DW	X0DF0		; f268   f0 0d      p.
;
	DB	3FH,40H					; f26a ?@
	DW	X0AF0		; f26c   f0 0a      p.
;
	DB	3FH,0C0H				; f26e ?@
	DW	X0DF0		; f270   f0 0d      p.
;
	DB	3FH,40H					; f272 ?@
	DW	X0AF0		; f274   f0 0a      p.
;
	DB	3FH,0C0H,0F8H,7,7FH,80H			; f276 ?@x...
	DW	X00FF		; f27c   ff 00      ..
	DW	X00FF		; f27e   ff 00      ..
	DW	X00FF		; f280   ff 00      ..
	DW	X00FF		; f282   ff 00      ..
	DW	X03FC		; f284   fc 03      |.
;
	DB	3FH,0C0H,0F8H,6,1FH,0A0H,0F8H,5		; f286 ?@x.. x.
	DB	1FH,60H,0F8H,6,1FH,0A0H,0F8H,5		; f28e .`x.. x.
	DB	1FH,60H					; f296 .`
	DW	X03FC		; f298   fc 03      |.
;
	DB	3FH,0C0H				; f29a ?@
	DW	X00FF		; f29c   ff 00      ..
	DW	X00FF		; f29e   ff 00      ..
	DW	X00FF		; f2a0   ff 00      ..
	DW	X00FF		; f2a2   ff 00      ..
	DW	X01FE		; f2a4   fe 01      ~.
;
	DB	1FH,0E0H				; f2a6 .`
	DW	X03FC		; f2a8   fc 03      |.
;
	DB	0FH,50H					; f2aa .P
	DW	X02FC		; f2ac   fc 02      |.
	DB	0FH					; f2ae .
	DW	XFCB0		; f2af   b0 fc      0|
;
	DB	3,0FH,50H				; f2b1 ..P
	DW	X02FC		; f2b4   fc 02      |.
	DB	0FH					; f2b6 .
	DW	XFEB0		; f2b7   b0 fe      0~
;
	DB	1,1FH,0E0H				; f2b9 ..`
	DW	X00FF		; f2bc   ff 00      ..
	DW	X00FF		; f2be   ff 00      ..
	DW	X00FF		; f2c0   ff 00      ..
;
	DW	X00FF		; f2c2   ff 00      ..
;
	DB	0FFH					; f2c4 .
;
	NOP			; f2c5  00		.
	RRCA			; f2c6  0f		.
	RET	P		; f2c7  f0		p
	CP	1		; f2c8  fe 01		~.
	RLCA			; f2ca  07		.
	XOR	B		; f2cb  a8		(
	CP	1		; f2cc  fe 01		~.
	RLCA			; f2ce  07		.
	LD	E,B		; f2cf  58		X
	CP	1		; f2d0  fe 01		~.
	RLCA			; f2d2  07		.
	XOR	B		; f2d3  a8		(
	CP	1		; f2d4  fe 01		~.
	RLCA			; f2d6  07		.
	LD	E,B		; f2d7  58		X
	RST	38H		; f2d8  ff		.
	NOP			; f2d9  00		.
	RRCA			; f2da  0f		.
	RET	P		; f2db  f0		p
	RST	38H		; f2dc  ff		.
	NOP			; f2dd  00		.
	RST	38H		; f2de  ff		.
	NOP			; f2df  00		.
	RST	38H		; f2e0  ff		.
	NOP			; f2e1  00		.
	RST	38H		; f2e2  ff		.
	NOP			; f2e3  00		.
	RST	38H		; f2e4  ff		.
	NOP			; f2e5  00		.
	ADD	A,A		; f2e6  87		.
	LD	A,B		; f2e7  78		x
	RST	38H		; f2e8  ff		.
	NOP			; f2e9  00		.
	INC	BC		; f2ea  03		.
	CALL	NC,X00FF	; f2eb  d4 ff 00	T..
	INC	BC		; f2ee  03		.
	XOR	H		; f2ef  ac		,
	RST	38H		; f2f0  ff		.
	NOP			; f2f1  00		.
	INC	BC		; f2f2  03		.
	CALL	NC,X00FF	; f2f3  d4 ff 00	T..
	INC	BC		; f2f6  03		.
	XOR	H		; f2f7  ac		,
	RST	38H		; f2f8  ff		.
	NOP			; f2f9  00		.
	ADD	A,A		; f2fa  87		.
	LD	A,B		; f2fb  78		x
	RST	38H		; f2fc  ff		.
	NOP			; f2fd  00		.
	RST	38H		; f2fe  ff		.
	NOP			; f2ff  00		.
	RST	38H		; f300  ff		.
	NOP			; f301  00		.
	RST	38H		; f302  ff		.
	NOP			; f303  00		.
	CP	A		; f304  bf		?
	LD	B,B		; f305  40		@
	RST	38H		; f306  ff		.
	NOP			; f307  00		.
	RST	38H		; f308  ff		.
	NOP			; f309  00		.
	RST	38H		; f30a  ff		.
	NOP			; f30b  00		.
	PUSH	HL		; f30c  e5		e
	LD	A,(DE)		; f30d  1a		.
	RST	38H		; f30e  ff		.
	NOP			; f30f  00		.
	RST	20H		; f310  e7		g
	JR	XF312		; f311  18 ff		..
;
	NOP			; f313  00		.
	RST	38H		; f314  ff		.
	NOP			; f315  00		.
	RST	38H		; f316  ff		.
	NOP			; f317  00		.
;
	DB	0DFH,20H				; f318 _ 
	DW	X00FF		; f31a   ff 00      ..
	DW	X00FF		; f31c   ff 00      ..
	DW	X00FF		; f31e   ff 00      ..
	DW	X00FF		; f320   ff 00      ..
	DW	X00FF		; f322   ff 00      ..
;
	DB	0DFH,20H				; f324 _ 
	DW	X00FF		; f326   ff 00      ..
	DW	X00FF		; f328   ff 00      ..
	DW	X00FF		; f32a   ff 00      ..
;
	DB	0F2H,0DH				; f32c r.
	DW	X00FF		; f32e   ff 00      ..
	DW	X0CF3		; f330   f3 0c      s.
	DW	X00FF		; f332   ff 00      ..
	DW	X00FF		; f334   ff 00      ..
	DW	X00FF		; f336   ff 00      ..
	DW	X10EF		; f338   ef 10      o.
	DW	X00FF		; f33a   ff 00      ..
	DW	X00FF		; f33c   ff 00      ..
	DW	X00FF		; f33e   ff 00      ..
	DW	X00FF		; f340   ff 00      ..
	DW	X00FF		; f342   ff 00      ..
	DW	X10EF		; f344   ef 10      o.
	DW	X00FF		; f346   ff 00      ..
	DW	X00FF		; f348   ff 00      ..
	DW	X00FF		; f34a   ff 00      ..
;
	DB	0F9H,6,7FH,80H,0F9H,6			; f34c y...y.
	DW	X00FF		; f352   ff 00      ..
	DW	X00FF		; f354   ff 00      ..
	DW	X00FF		; f356   ff 00      ..
	DW	X08F7		; f358   f7 08      w.
	DW	X00FF		; f35a   ff 00      ..
	DW	X00FF		; f35c   ff 00      ..
	DW	X00FF		; f35e   ff 00      ..
	DW	X00FF		; f360   ff 00      ..
	DW	X00FF		; f362   ff 00      ..
	DW	X08F7		; f364   f7 08      w.
	DW	X00FF		; f366   ff 00      ..
	DW	X00FF		; f368   ff 00      ..
	DW	X00FF		; f36a   ff 00      ..
	DW	X03FC		; f36c   fc 03      |.
	DW	X40BF		; f36e   bf 40      ?@
	DW	X03FC		; f370   fc 03      |.
	DW	X00FF		; f372   ff 00      ..
	DW	X00FF		; f374   ff 00      ..
	DW	X00FF		; f376   ff 00      ..
;
	DB	0FBH,4					; f378 {.
	DW	X00FF		; f37a   ff 00      ..
	DW	X00FF		; f37c   ff 00      ..
	DW	X00FF		; f37e   ff 00      ..
	DW	X00FF		; f380   ff 00      ..
	DW	X00FF		; f382   ff 00      ..
;
	DB	0FBH,4					; f384 {.
	DW	X00FF		; f386   ff 00      ..
	DW	X00FF		; f388   ff 00      ..
	DW	X00FF		; f38a   ff 00      ..
	DW	X01FE		; f38c   fe 01      ~.
;
	DB	5FH,0A0H				; f38e _ 
	DW	X01FE		; f390   fe 01      ~.
;
	DB	7FH,80H					; f392 ..
	DW	X00FF		; f394   ff 00      ..
	DW	X00FF		; f396   ff 00      ..
	DW	X02FD		; f398   fd 02      }.
	DW	X00FF		; f39a   ff 00      ..
	DW	X00FF		; f39c   ff 00      ..
	DW	X00FF		; f39e   ff 00      ..
	DW	X00FF		; f3a0   ff 00      ..
	DW	X00FF		; f3a2   ff 00      ..
	DW	X02FD		; f3a4   fd 02      }.
	DW	X00FF		; f3a6   ff 00      ..
	DW	X00FF		; f3a8   ff 00      ..
	DW	X00FF		; f3aa   ff 00      ..
	DW	X00FF		; f3ac   ff 00      ..
;
	DB	2FH,0D0H				; f3ae /P
	DW	X00FF		; f3b0   ff 00      ..
;
XF3B2:	DB	3FH,0C0H				; f3b2 ?@
	DW	X00FF		; f3b4   ff 00      ..
	DW	X00FF		; f3b6   ff 00      ..
	DW	X01FE		; f3b8   fe 01      ~.
	DW	X00FF		; f3ba   ff 00      ..
	DW	X00FF		; f3bc   ff 00      ..
	DW	X00FF		; f3be   ff 00      ..
	DW	X00FF		; f3c0   ff 00      ..
	DW	X00FF		; f3c2   ff 00      ..
	DW	X01FE		; f3c4   fe 01      ~.
	DW	X00FF		; f3c6   ff 00      ..
	DW	X00FF		; f3c8   ff 00      ..
	DW	X00FF		; f3ca   ff 00      ..
	DW	X00FF		; f3cc   ff 00      ..
;
	DB	97H,68H					; f3ce .h
	DW	X00FF		; f3d0   ff 00      ..
;
	DB	9FH,60H					; f3d2 .`
	DW	X00FF		; f3d4   ff 00      ..
	DW	X00FF		; f3d6   ff 00      ..
	DW	X00FF		; f3d8   ff 00      ..
;
	DB	7FH,80H					; f3da ..
	DW	X00FF		; f3dc   ff 00      ..
	DW	X00FF		; f3de   ff 00      ..
	DW	X00FF		; f3e0   ff 00      ..
	DW	X00FF		; f3e2   ff 00      ..
	DW	X00FF		; f3e4   ff 00      ..
;
	DB	7FH,80H					; f3e6 ..
	DW	X00FF		; f3e8   ff 00      ..
	DW	X00FF		; f3ea   ff 00      ..
	DW	X00FF		; f3ec   ff 00      ..
	DW	X34CB		; f3ee   cb 34      K4
	DW	X00FF		; f3f0   ff 00      ..
;
	DB	0CFH,30H				; f3f2 O0
	DW	X00FF		; f3f4   ff 00      ..
	DW	X00FF		; f3f6   ff 00      ..
	DW	X00FF		; f3f8   ff 00      ..
	DW	X40BF		; f3fa   bf 40      ?@
	DW	X00FF		; f3fc   ff 00      ..
;
	DB	0FFH					; f3fe .
;
	ORG	0F501H
;
	DB	27H,0,6AH,6,0,2FH,0			; f501 '.j../.
	DW	X0560		; f508   60 05      `.
;
	DB	0,34H,0					; f50a .4.
	DW	X04C7		; f50d   c7 04      G.
;
	DB	0,37H,0,80H,4,0,34H,0			; f50f .7....4.
	DW	X04C7		; f517   c7 04      G.
;
	DB	0,2FH,0					; f519 ./.
	DW	X0560		; f51c   60 05      `.
;
	DB	0,27H,0,6AH,6,0,2FH,0			; f51e .'.j../.
	DW	X0560		; f526   60 05      `.
;
	DB	0,34H,0					; f528 .4.
	DW	X04C7		; f52b   c7 04      G.
;
	DB	0,2FH,0					; f52d ./.
	DW	X0560		; f530   60 05      `.
;
	DB	0,27H,0,6AH,6,0,4EH,0			; f532 .'.j..N.
	DB	26H,3,0,37H,0,80H,4,1			; f53a &..7....
	DB	42H,0					; f542 B.
	DW	X03C4		; f544   c4 03      D.
;
	DB	0,69H,0					; f546 .i.
	DW	X04C7		; f549   c7 04      G.
;
	DB	0,27H,0,6AH,6				; f54b .'.j.
;
	NOP			; f550  00		.
	CPL			; f551  2f		/
	NOP			; f552  00		.
	LD	H,B		; f553  60		`
	DEC	B		; f554  05		.
	NOP			; f555  00		.
	INC	(HL)		; f556  34		4
	NOP			; f557  00		.
	RST	0		; f558  c7		G
	INC	B		; f559  04		.
	NOP			; f55a  00		.
	SCF			; f55b  37		7
	NOP			; f55c  00		.
	ADD	A,B		; f55d  80		.
	INC	B		; f55e  04		.
	NOP			; f55f  00		.
	INC	(HL)		; f560  34		4
	NOP			; f561  00		.
	RST	0		; f562  c7		G
	INC	B		; f563  04		.
	NOP			; f564  00		.
	CPL			; f565  2f		/
	NOP			; f566  00		.
	LD	H,B		; f567  60		`
	DEC	B		; f568  05		.
	NOP			; f569  00		.
	DAA			; f56a  27		'
	NOP			; f56b  00		.
	LD	L,D		; f56c  6a		j
	LD	B,0		; f56d  06 00		..
	INC	HL		; f56f  23		#
	NOP			; f570  00		.
	SCF			; f571  37		7
	RLCA			; f572  07		.
	NOP			; f573  00		.
	DEC	E		; f574  1d		.
	NOP			; f575  00		.
	SBC	A,D		; f576  9a		.
	EX	AF,AF'		; f577  08		.
	NOP			; f578  00		.
	INC	HL		; f579  23		#
	NOP			; f57a  00		.
	SCF			; f57b  37		7
	RLCA			; f57c  07		.
	NOP			; f57d  00		.
	INC	D		; f57e  14		.
	NOP			; f57f  00		.
	LD	L,D		; f580  6a		j
	LD	B,1		; f581  06 01		..
	LD	HL,XC400	; f583  21 00 c4	!.D
	INC	BC		; f586  03		.
	LD	BC,X0042	; f587  01 42 00	.B.
	CALL	NZ,X0003	; f58a  c4 03 00	D..
	INC	E		; f58d  1c		.
	NOP			; f58e  00		.
	RRA			; f58f  1f		.
	ADD	HL,BC		; f590  09		.
	NOP			; f591  00		.
	DEC	E		; f592  1d		.
	NOP			; f593  00		.
	SBC	A,D		; f594  9a		.
	EX	AF,AF'		; f595  08		.
	NOP			; f596  00		.
	LD	H,D		; f597  62		b
	NOP			; f598  00		.
	JP	P,XFF0C		; f599  f2 0c ff	r..
	NOP			; f59c  00		.
	DAA			; f59d  27		'
	NOP			; f59e  00		.
	LD	L,D		; f59f  6a		j
	LD	B,0		; f5a0  06 00		..
	CPL			; f5a2  2f		/
	NOP			; f5a3  00		.
	LD	H,B		; f5a4  60		`
	DEC	B		; f5a5  05		.
	NOP			; f5a6  00		.
	INC	(HL)		; f5a7  34		4
	NOP			; f5a8  00		.
	RST	0		; f5a9  c7		G
	INC	B		; f5aa  04		.
	NOP			; f5ab  00		.
	SCF			; f5ac  37		7
	NOP			; f5ad  00		.
	ADD	A,B		; f5ae  80		.
	INC	B		; f5af  04		.
	NOP			; f5b0  00		.
	INC	(HL)		; f5b1  34		4
	NOP			; f5b2  00		.
	RST	0		; f5b3  c7		G
	INC	B		; f5b4  04		.
	NOP			; f5b5  00		.
	CPL			; f5b6  2f		/
	NOP			; f5b7  00		.
	LD	H,B		; f5b8  60		`
	DEC	B		; f5b9  05		.
	NOP			; f5ba  00		.
	DAA			; f5bb  27		'
	NOP			; f5bc  00		.
	LD	L,D		; f5bd  6a		j
	LD	B,0		; f5be  06 00		..
	CPL			; f5c0  2f		/
	NOP			; f5c1  00		.
	LD	H,B		; f5c2  60		`
XF5C3:	DEC	B		; f5c3  05		.
	NOP			; f5c4  00		.
	INC	(HL)		; f5c5  34		4
	NOP			; f5c6  00		.
	RST	0		; f5c7  c7		G
	INC	B		; f5c8  04		.
	NOP			; f5c9  00		.
	CPL			; f5ca  2f		/
	NOP			; f5cb  00		.
	LD	H,B		; f5cc  60		`
	DEC	B		; f5cd  05		.
	NOP			; f5ce  00		.
	DAA			; f5cf  27		'
	NOP			; f5d0  00		.
	LD	L,D		; f5d1  6a		j
	LD	B,0		; f5d2  06 00		..
	LD	C,(HL)		; f5d4  4e		N
	NOP			; f5d5  00		.
	LD	H,3		; f5d6  26 03		&.
	NOP			; f5d8  00		.
	SCF			; f5d9  37		7
	NOP			; f5da  00		.
	ADD	A,B		; f5db  80		.
	INC	B		; f5dc  04		.
	LD	BC,X0042	; f5dd  01 42 00	.B.
	CALL	NZ,X0003	; f5e0  c4 03 00	D..
	LD	L,C		; f5e3  69		i
	NOP			; f5e4  00		.
	RST	0		; f5e5  c7		G
	INC	B		; f5e6  04		.
	NOP			; f5e7  00		.
	DAA			; f5e8  27		'
	NOP			; f5e9  00		.
	LD	L,D		; f5ea  6a		j
	LD	B,0		; f5eb  06 00		..
	CPL			; f5ed  2f		/
	NOP			; f5ee  00		.
	LD	H,B		; f5ef  60		`
	DEC	B		; f5f0  05		.
	NOP			; f5f1  00		.
	INC	(HL)		; f5f2  34		4
	NOP			; f5f3  00		.
	RST	0		; f5f4  c7		G
	INC	B		; f5f5  04		.
	NOP			; f5f6  00		.
	SCF			; f5f7  37		7
	NOP			; f5f8  00		.
	ADD	A,B		; f5f9  80		.
	INC	B		; f5fa  04		.
	NOP			; f5fb  00		.
	INC	(HL)		; f5fc  34		4
	NOP			; f5fd  00		.
	RST	0		; f5fe  c7		G
XF5FF:	INC	B		; f5ff  04		.
	NOP			; f600  00		.
	CPL			; f601  2f		/
	NOP			; f602  00		.
	LD	H,B		; f603  60		`
	DEC	B		; f604  05		.
	NOP			; f605  00		.
	DAA			; f606  27		'
	NOP			; f607  00		.
	LD	L,D		; f608  6a		j
	LD	B,0		; f609  06 00		..
	CPL			; f60b  2f		/
	NOP			; f60c  00		.
	LD	H,B		; f60d  60		`
	DEC	B		; f60e  05		.
	NOP			; f60f  00		.
	INC	(HL)		; f610  34		4
	NOP			; f611  00		.
	RST	0		; f612  c7		G
	INC	B		; f613  04		.
	NOP			; f614  00		.
	CPL			; f615  2f		/
	NOP			; f616  00		.
	LD	H,B		; f617  60		`
	DEC	B		; f618  05		.
	NOP			; f619  00		.
	LD	H,D		; f61a  62		b
	NOP			; f61b  00		.
	LD	L,D		; f61c  6a		j
	LD	B,0FFH		; f61d  06 ff		..
	NOP			; f61f  00		.
;
	ORG	0F708H
;
	LD	H,B		; f708  60		`
	LD	H,B		; f709  60		`
	LD	H,B		; f70a  60		`
	LD	H,B		; f70b  60		`
	LD	H,B		; f70c  60		`
	NOP			; f70d  00		.
	LD	H,B		; f70e  60		`
	NOP			; f70f  00		.
	LD	L,H		; f710  6c		l
	LD	L,H		; f711  6c		l
	LD	L,H		; f712  6c		l
	NOP			; f713  00		.
;
	ORG	0F718H
;
	DB	36H,36H,7FH,36H,7FH,36H,36H,0		; f718 66.6.66.
	DB	18H,3EH,58H,3CH,1AH,7CH,18H,0		; f720 .>X<.|..
	DB	0,63H,66H,0CH,18H,33H,63H,0		; f728 .cf..3c.
	DB	1CH,36H,1CH,3BH,6EH,66H,3BH,0		; f730 .6.;nf;.
	DB	30H,30H,60H				; f738 00`
;
	ORG	0F740H
;
	DB	18H					; f740 .
	DB	'0```0'					; f741
	DB	18H,0,60H,30H,18H,18H,18H,30H		; f746 ..`0...0
	DW	X0060		; f74e   60 00      `.
;
	DB	0,36H,1CH,7FH,1CH,36H			; f750 .6...6
;
	ORG	0F759H
;
	DB	18H,18H,7EH,18H,18H,0			; f759 ..~...
;
	ORG	0F765H
;
	DB	30H,30H,60H				; f765 00`
;
	ORG	0F76BH
;
	DB	7EH					; f76b ~
;
	ORG	0F775H
;
	DB	60H					; f775 `
	DW	X0060		; f776   60 00      `.
;
	DB	3,6,0CH,18H,30H,60H,40H,0		; f778 ....0`@.
	DB	'>cgksc>'				; f780
	DB	0					; f787 .
	DB	'0p0000x'				; f788
	DB	0,3CH,66H,6,3CH,60H,60H,7EH		; f78f .<f.<``~
	DB	0,3CH,66H,6,1CH,6			; f797 .<f...
;
	LD	H,(HL)		; f79d  66		f
	INC	A		; f79e  3c		<
	NOP			; f79f  00		.
	LD	C,1EH		; f7a0  0e 1e		..
	LD	(HL),66H	; f7a2  36 66		6f
	LD	A,A		; f7a4  7f		.
	LD	B,6		; f7a5  06 06		..
	NOP			; f7a7  00		.
	LD	A,(HL)		; f7a8  7e		~
	LD	H,B		; f7a9  60		`
	LD	H,B		; f7aa  60		`
	LD	A,H		; f7ab  7c		|
	LD	B,66H		; f7ac  06 66		.f
	INC	A		; f7ae  3c		<
;
	DB	0					; f7af .
	DB	'<f`|ff<'				; f7b0
XF7B7:	DB	0,7EH,6,6,0CH,18H,18H			; f7b7 .~.....
;
	JR	XF7C0		; f7be  18 00		..
;
Xf7c0:	DB	'<ff<ff<'				; f7c0
	DB	0,3CH,66H,66H,3EH,6,66H,3CH		; f7c7 .<ff>.f<
	DB	0					; f7cf .
;
	ORG	0F7D2H
;
	DB	60H					; f7d2 `
	DW	X0060		; f7d3   60 00      `.
	DB	60H					; f7d5 `
	DW	X0060		; f7d6   60 00      `.
;
;
	ORG	0F7DAH
;
	DB	30H,30H,0,30H,30H			; f7da 00.00
	DW	X0C60		; f7df   60 0c      `.
;
	DB	18H					; f7e1 .
;
	JR	NC,XF844	; f7e2  30 60		0`
	JR	NC,XF7FE	; f7e4  30 18		0.
	INC	C		; f7e6  0c		.
XF7E7:	NOP			; f7e7  00		.
	NOP			; f7e8  00		.
	NOP			; f7e9  00		.
	LD	A,(HL)		; f7ea  7e		~
	NOP			; f7eb  00		.
	NOP			; f7ec  00		.
	LD	A,(HL)		; f7ed  7e		~
	NOP			; f7ee  00		.
	NOP			; f7ef  00		.
	LD	H,B		; f7f0  60		`
	JR	NC,XF80B	; f7f1  30 18		0.
	INC	C		; f7f3  0c		.
	JR	XF826		; f7f4  18 30		.0
;
	LD	H,B		; f7f6  60		`
	NOP			; f7f7  00		.
	INC	A		; f7f8  3c		<
	LD	H,(HL)		; f7f9  66		f
	LD	H,(HL)		; f7fa  66		f
	INC	C		; f7fb  0c		.
	JR	XF7FE		; f7fc  18 00		..
;
XF7FE:	JR	XF800		; f7fe  18 00		..
;
Xf800:	DB	'>cooo`>'				; f800
	DB	0					; f807 .
	DB	'<ff'					; f808
Xf80b:	DB	'~fff'					; f80b
	DB	0					; f80f .
	DB	'|ff|ff|'				; f810
	DB	0					; f817 .
	DB	'<f```f<'				; f818
	DB	0					; f81f .
	DB	'|fffff'				; f820
Xf826:	DB	'|'					; f826
	DB	0					; f827 .
	DB	'~``|``~'				; f828
	DB	0					; f82f .
	DB	'~``|```'				; f830
	DB	0					; f837 .
	DB	'<f``nf<'				; f838
	DB	0					; f83f .
	DB	'fff~'					; f840
Xf844:	DB	'fff'					; f844
	DB	0					; f847 .
	DB	'x00000x'				; f848
	DB	0,6,6,6,6,66H,66H,3CH			; f84f .....ff<
	DB	0					; f857 .
	DB	'fflxlff'				; f858
	DB	0					; f85f .
	DB	'``````~'				; f860
	DB	0,63H,77H,7FH,7FH,6BH,63H,63H		; f867 .cw..kcc
	DB	0					; f86f .
	DB	'cs{ogcc'				; f870
	DB	0,1CH					; f877 ..
	DB	'6ccc6'					; f879
;
	INC	E		; f87e  1c		.
;
	DB	0					; f87f .
	DB	'|ff|```'				; f880
	DB	0,1CH					; f887 ..
	DB	'6ccm6'					; f889
	DB	1BH,0					; f88e ..
	DB	'|ff|lff'				; f890
	DB	0,3CH,66H,60H,3CH,6,66H,3CH		; f897 .<f`<.f<
	DB	0,7EH,18H,18H,18H,18H,18H,18H		; f89f .~......
	DB	0					; f8a7 .
	DB	'ffffff<'				; f8a8
	DB	0					; f8af .
	DB	'fffff<'				; f8b0
	DB	18H,0,63H,63H,63H,6BH,7FH,77H		; f8b6 ..ccck.w
	DB	63H,0,63H,36H,1CH,1CH,36H,63H		; f8be c.c6..6c
	DB	63H,0,66H,66H,66H,3CH,18H,18H		; f8c6 c.fff<..
	DB	18H,0,7FH,3,6,0CH,18H,30H		; f8ce .......0
	DB	7FH,0					; f8d6 ..
;
	ORG	0F8DAH
;
	DB	2,4,8,50H,20H				; f8da ...P 
;
	ORG	0F8E1H
;
	DB	42H,24H					; f8e1 B$
XF8E3:	DB	18H,18H,24H,42H,0,0CH,1CH,3CH		; f8e3 ..$B...<
	DB	7CH,3CH,1CH,0CH,0,18H,3CH,7EH		; f8eb |<....<~
	DB	18H,18H,18H,18H,0			; f8f3 .....
;
	ORG	0F8FFH
;
XF8FF:	DB	7FH					; f8ff .
	DB	'`px|xp`'				; f900
	DB	0					; f907 .
;
	NOP			; f908  00		.
	NOP			; f909  00		.
;
	DB	3CH,6,3EH,66H,3EH,0			; f90a <.>f>.
	DB	'``|fff|'				; f910
	DB	0					; f917 .
;
	NOP			; f918  00		.
	NOP			; f919  00		.
;
	DB	3CH,66H,60H,66H,3CH,0,6,6		; f91a <f`f<...
	DB	3EH,66H,66H,66H,3EH			; f922 >fff>
;
	ORG	0F92AH
;
	DB	3CH,66H,7EH,60H,3CH,0			; f92a <f~`<.
	DB	'8l`x```'				; f930
	DB	0					; f937 .
;
	NOP			; f938  00		.
	NOP			; f939  00		.
;
	DB	3EH,66H,66H,3EH,6			; f93a >ff>.
	DB	'|``lvfff'				; f93f
	DB	0					; f947 .
	DW	X0060		; f948   60 00      `.
;
	DB	60H,60H,60H,60H				; f94a ````
	DW	X0060		; f94e   60 00      `.
;
	DB	6,0,6					; f950 ...
;
	LD	B,6		; f953  06 06		..
;
	DB	'ff<``flxlf'				; f955
	DB	0					; f95f .
	DB	'```````'				; f960
	DB	0					; f967 .
;
	NOP			; f968  00		.
	NOP			; f969  00		.
;
	DB	36H,7FH,6BH,6BH,63H			; f96a 6.kkc
;
	ORG	0F972H
;
	DB	7CH,66H,66H,66H,66H,0			; f972 |ffff.
;
	ORG	0F97AH
;
	DB	3CH,66H,66H,66H,3CH			; f97a <fff<
;
	ORG	0F982H
;
	DB	'|ff|``'				; f982
	DB	0					; f988 .
;
	NOP			; f989  00		.
;
	DB	3EH,66H,66H,3EH,7,6			; f98a >ff>..
;
	ORG	0F992H
;
	DB	3CH,66H,60H,60H				; f992 <f``
	DW	X0060		; f996   60 00      `.
;
;
	ORG	0F99AH
;
	DB	3CH,60H,3CH,6,7CH,0			; f99a <`<.|.
	DB	'00|006'				; f9a0
	DB	1CH,0					; f9a6 ..
;
	ORG	0F9AAH
;
	DB	66H,66H,66H,66H,3EH			; f9aa ffff>
;
	ORG	0F9B2H
;
	DB	66H,66H,66H,3CH,18H,0			; f9b2 fff<..
;
	ORG	0F9BAH
;
	DB	63H,6BH,6BH,7FH,36H,0			; f9ba ckk.6.
;
	ORG	0F9C2H
;
	DB	63H,36H,1CH,36H,63H			; f9c2 c6.6c
;
	ORG	0F9CAH
;
	DB	66H,66H,66H				; f9ca fff
;
	LD	A,6		; f9cd  3e 06		>.
XF9CF:	LD	A,H		; f9cf  7c		|
	NOP			; f9d0  00		.
	NOP			; f9d1  00		.
	LD	A,(HL)		; f9d2  7e		~
	INC	C		; f9d3  0c		.
	JR	XFA06		; f9d4  18 30		.0
;
	DB	7EH,0,18H,18H,18H,18H,7EH,3CH		; f9d6 ~.....~<
	DB	18H					; f9de .
;
	ORG	0F9E3H
;
	DB	18H,18H,0				; f9e3 ...
;
	ORG	0F9E8H
;
	DB	1CH,22H,49H,51H,49H,22H,1CH		; f9e8 ."IQI".
;
	ORG	0F9F8H
;
	DB	7FH,7FH,7FH,7FH,7FH,7FH,7FH		; f9f8 .......
XF9FF:	DB	0					; f9ff .

; --- HUD font ---
Xfa00:	DB	'<fffff'				; fa00
Xfa06:	DB	'<'					; fa06
	DB	0,18H,38H,18H,18H,18H,18H,7EH		; fa07 ..8....~
	DB	0,3CH,66H,6,3CH,60H,60H,7EH		; fa0f .<f.<``~
	DB	0,3CH,66H,6,1CH,6,66H,3CH		; fa17 .<f...f<
	DB	0,0EH					; fa1f ..
;
	LD	E,36H		; fa21  1e 36		.6
	LD	H,(HL)		; fa23  66		f
	LD	A,A		; fa24  7f		.
	LD	B,6		; fa25  06 06		..
	NOP			; fa27  00		.
	LD	A,(HL)		; fa28  7e		~
	LD	H,B		; fa29  60		`
	LD	H,B		; fa2a  60		`
	LD	A,H		; fa2b  7c		|
	LD	B,66H		; fa2c  06 66		.f
	INC	A		; fa2e  3c		<
;
	DB	0					; fa2f .
	DB	'<f`|ff<'				; fa30
	DB	0,7EH,6,6,0CH,18H,18H,18H		; fa37 .~......
	DB	0					; fa3f .
	DB	'<ff<ff<'				; fa40
	DB	0,3CH,66H,66H,3EH,6,66H,3CH		; fa47 .<ff>.f<
	DB	0					; fa4f .
;
	ORG	0FA59H
;
	DB	63H,66H,0CH,18H,33H,63H,0,3CH		; fa59 cf..3c.<
	DB	66H,60H,3CH,6,66H,3CH,0			; fa61 f`<.f<.
;
	ORG	0FA6AH
;
	DB	3CH,66H					; fa6a <f
;
XFA6C:	LD	H,B		; fa6c  60		`
	LD	H,(HL)		; fa6d  66		f
	INC	A		; fa6e  3c		<
;
	ORG	0FA72H
;
	DB	3CH,66H,66H,66H,3CH			; fa72 <fff<
;
	ORG	0FA7AH
;
	DB	3CH,66H,60H,60H,60H			; fa7a <f```
;
XFA7F:	NOP			; fa7f  00		.
	NOP			; fa80  00		.
	NOP			; fa81  00		.
	INC	A		; fa82  3c		<
	LD	H,(HL)		; fa83  66		f
	LD	A,(HL)		; fa84  7e		~
	LD	H,B		; fa85  60		`
	INC	A		; fa86  3c		<
	NOP			; fa87  00		.
;
	DB	'``````~'				; fa88
	DB	0					; fa8f .
;
	NOP			; fa90  00		.
	NOP			; fa91  00		.
;
	DB	66H,66H,66H,3CH,18H,0			; fa92 fff<..
	DB	'0000000'				; fa98
	DB	0					; fa9f .
;
	JR	XFAA2		; faa0  18 00		..
;
XFAA2:	JR	C,XFABC		; faa2  38 18		8.
	JR	XFABE		; faa4  18 18		..
;
	DB	3CH					; faa6 <
;
	ORG	0FAAAH
;
	DB	3EH,60H,3CH,6,7CH			; faaa >`<.|
;
	NOP			; faaf  00		.
	RST	38H		; fab0  ff		.
	JR	XFACB		; fab1  18 18		..
;
	DB	18H,18H,18H,18H,0			; fab3 .....
;
	ORG	0FABAH
;
	DB	6CH,0FEH				; faba l~
;
XFABC:	SUB	0D6H		; fabc  d6 d6		VV
XFABE:	ADD	A,0		; fabe  c6 00		F.
	NOP			; fac0  00		.
	DEC	C		; fac1  0d		.
	LD	DE,X0509	; fac2  11 09 05	...
	DEC	B		; fac5  05		.
	ADD	HL,DE		; fac6  19		.
	NOP			; fac7  00		.
	NOP			; fac8  00		.
	ADC	A,H		; fac9  8c		.
	LD	D,B		; faca  50		P
XFACB:	LD	D,B		; facb  50		P
	SUB	B		; facc  90		.
	DJNZ	XFADB		; facd  10 0c		..
	NOP			; facf  00		.
	NOP			; fad0  00		.
	ADD	HL,DE		; fad1  19		.
	DEC	D		; fad2  15		.
	DEC	D		; fad3  15		.
	DEC	D		; fad4  15		.
	DEC	D		; fad5  15		.
	ADD	HL,DE		; fad6  19		.
	NOP			; fad7  00		.
	NOP			; fad8  00		.
	RET	NC		; fad9  d0		P
	DJNZ	XFA6C		; fada  10 90		..
	DJNZ	XFAEE		; fadc  10 10		..
	CALL	C,X0000		; fade  dc 00 00	\..
	LD	B,9		; fae1  06 09		..
	ADD	HL,BC		; fae3  09		.
	ADD	HL,BC		; fae4  09		.
	ADD	HL,BC		; fae5  09		.
	LD	B,0		; fae6  06 00		..
	NOP			; fae8  00		.
;
	DB	'HP`PH'					; fae9
Xfaee:	DB	'H'					; faee
	DB	0,3CH,42H,81H,81H,81H,81H,42H		; faef .<B....B
	DB	3CH,3CH,42H,99H				; faf7 <<B.
	DW	XBDBD		; fafb   bd bd      ==
;
	DB	99H					; fafd .
;
XFAFE:	LD	B,D		; fafe  42		B
XFAFF:	INC	A		; faff  3c		<

; --- Cell mask table ---
CELL_MASK_TABLE:
	RET	NZ		; fb00  c0		@
	JR	NC,XFB0F	; fb01  30 0c		0.
	INC	BC		; fb03  03		.
;
	ORG	0FB08H
;
	DB	80H,40H,20H,10H,8,4,2			; fb08 .@ ....
;
XFB0F:	LD	BC,X0000	; fb0f  01 00 00	...
;
	ORG	0FC01H
;
	DB	40H					; fc01 @
;
	NOP			; fc02  00		.
	LD	B,C		; fc03  41		A
	NOP			; fc04  00		.
	LD	B,D		; fc05  42		B
	NOP			; fc06  00		.
	LD	B,E		; fc07  43		C
	NOP			; fc08  00		.
	LD	B,H		; fc09  44		D
	NOP			; fc0a  00		.
	LD	B,L		; fc0b  45		E
	NOP			; fc0c  00		.
	LD	B,(HL)		; fc0d  46		F
	NOP			; fc0e  00		.
;
	DB	'G @ A B C D E F G@@'			; fc0f
Xfc22:	DB	'@A@B@C@D@E@F@G`@`A`B`C`D`E`F`G'	; fc22
XFC40:	DB	80H,40H,80H,41H,80H,42H,80H,43H		; fc40 .@.A.B.C
	DB	80H,44H,80H,45H,80H,46H,80H,47H		; fc48 .D.E.F.G
	DB	0A0H,40H,0A0H,41H,0A0H,42H,0A0H,43H	; fc50  @ A B C
	DB	0A0H,44H,0A0H,45H,0A0H,46H,0A0H,47H	; fc58  D E F G
	DW	X40C0		; fc60   c0 40      @@
	DW	X41C0		; fc62   c0 41      @A
	DW	X42C0		; fc64   c0 42      @B
	DW	X43C0		; fc66   c0 43      @C
	DW	X44C0		; fc68   c0 44      @D
	DW	X45C0		; fc6a   c0 45      @E
	DW	X46C0		; fc6c   c0 46      @F
	DW	X47C0		; fc6e   c0 47      @G
;
	DB	0E0H,40H,0E0H,41H,0E0H,42H,0E0H,43H	; fc70 `@`A`B`C
	DB	0E0H,44H				; fc78 `D
XFC7A:	DB	0E0H,45H,0E0H,46H,0E0H			; fc7a `E`F`
;
	LD	B,A		; fc7f  47		G
	NOP			; fc80  00		.
	LD	C,B		; fc81  48		H
	NOP			; fc82  00		.
	LD	C,C		; fc83  49		I
	NOP			; fc84  00		.
	LD	C,D		; fc85  4a		J
	NOP			; fc86  00		.
	LD	C,E		; fc87  4b		K
	NOP			; fc88  00		.
	LD	C,H		; fc89  4c		L
	NOP			; fc8a  00		.
	LD	C,L		; fc8b  4d		M
	NOP			; fc8c  00		.
	LD	C,(HL)		; fc8d  4e		N
	NOP			; fc8e  00		.
;
	DB	'O H I J K L M N O@H@I@J@K@L@M@N@'	; fc8f
	DB	'O'					; fcaf
Xfcb0:	DB	'`H`I`J`K`L`M`N`O'			; fcb0
	DB	80H					; fcc0 .
;
	LD	C,B		; fcc1  48		H
	ADD	A,B		; fcc2  80		.
	LD	C,C		; fcc3  49		I
	ADD	A,B		; fcc4  80		.
	LD	C,D		; fcc5  4a		J
	ADD	A,B		; fcc6  80		.
	LD	C,E		; fcc7  4b		K
	ADD	A,B		; fcc8  80		.
	LD	C,H		; fcc9  4c		L
	ADD	A,B		; fcca  80		.
	LD	C,L		; fccb  4d		M
	ADD	A,B		; fccc  80		.
	LD	C,(HL)		; fccd  4e		N
	ADD	A,B		; fcce  80		.
	LD	C,A		; fccf  4f		O
	AND	B		; fcd0  a0		 
	LD	C,B		; fcd1  48		H
	AND	B		; fcd2  a0		 
	LD	C,C		; fcd3  49		I
	AND	B		; fcd4  a0		 
	LD	C,D		; fcd5  4a		J
	AND	B		; fcd6  a0		 
	LD	C,E		; fcd7  4b		K
	AND	B		; fcd8  a0		 
	LD	C,H		; fcd9  4c		L
	AND	B		; fcda  a0		 
	LD	C,L		; fcdb  4d		M
	AND	B		; fcdc  a0		 
	LD	C,(HL)		; fcdd  4e		N
	AND	B		; fcde  a0		 
	LD	C,A		; fcdf  4f		O
	RET	NZ		; fce0  c0		@
	LD	C,B		; fce1  48		H
	RET	NZ		; fce2  c0		@
	LD	C,C		; fce3  49		I
	RET	NZ		; fce4  c0		@
	LD	C,D		; fce5  4a		J
	RET	NZ		; fce6  c0		@
	LD	C,E		; fce7  4b		K
	RET	NZ		; fce8  c0		@
	LD	C,H		; fce9  4c		L
	RET	NZ		; fcea  c0		@
	LD	C,L		; fceb  4d		M
	RET	NZ		; fcec  c0		@
	LD	C,(HL)		; fced  4e		N
	RET	NZ		; fcee  c0		@
	LD	C,A		; fcef  4f		O
XFCF0:	RET	PO		; fcf0  e0		`
	LD	C,B		; fcf1  48		H
	RET	PO		; fcf2  e0		`
	LD	C,C		; fcf3  49		I
	RET	PO		; fcf4  e0		`
	LD	C,D		; fcf5  4a		J
	RET	PO		; fcf6  e0		`
	LD	C,E		; fcf7  4b		K
	RET	PO		; fcf8  e0		`
	LD	C,H		; fcf9  4c		L
	RET	PO		; fcfa  e0		`
	LD	C,L		; fcfb  4d		M
	RET	PO		; fcfc  e0		`
	LD	C,(HL)		; fcfd  4e		N
	RET	PO		; fcfe  e0		`
XFCFF:	LD	C,A		; fcff  4f		O
	NOP			; fd00  00		.
	LD	D,B		; fd01  50		P
	NOP			; fd02  00		.
	LD	D,C		; fd03  51		Q
	NOP			; fd04  00		.
	LD	D,D		; fd05  52		R
	NOP			; fd06  00		.
	LD	D,E		; fd07  53		S
	NOP			; fd08  00		.
	LD	D,H		; fd09  54		T
	NOP			; fd0a  00		.
	LD	D,L		; fd0b  55		U
	NOP			; fd0c  00		.
	LD	D,(HL)		; fd0d  56		V
	NOP			; fd0e  00		.
;
	DB	'W P Q R S T U V W@P@Q@R@S@T@U@V@'	; fd0f
	DB	'W`P`Q`R`S`T`U`V`W'			; fd2f
	DB	80H,50H,80H,51H,80H,52H,80H,53H		; fd40 .P.Q.R.S
	DB	80H,54H,80H,55H,80H,56H,80H,57H		; fd48 .T.U.V.W
	DB	0A0H,50H,0A0H,51H,0A0H,52H,0A0H,53H	; fd50  P Q R S
	DB	0A0H,54H,0A0H,55H,0A0H,56H,0A0H,57H	; fd58  T U V W
	DB	0C0H,50H,0C0H,51H,0C0H,52H,0C0H,53H	; fd60 @P@Q@R@S
	DB	0C0H,54H,0C0H,55H,0C0H,56H,0C0H,57H	; fd68 @T@U@V@W
	DB	0E0H,50H,0E0H,51H,0E0H,52H,0E0H,53H	; fd70 `P`Q`R`S
	DB	0E0H,54H,0E0H,55H,0E0H,56H,0E0H,57H	; fd78 `T`U`V`W
;
	ORG	0FDFDH
;
XFDFD:	JP	XBB51		; fdfd  c3 51 bb	CQ;
;
	DB	0FDH,0FDH	; fe00  fd fd		}}
;
	DB	0FDH,0FDH	; fe02  fd fd		}}
;
	DB	0FDH,0FDH	; fe04  fd fd		}}
;
	DB	0FDH,0FDH	; fe06  fd fd		}}
;
	DB	0FDH,0FDH	; fe08  fd fd		}}
;
	DB	0FDH,0FDH	; fe0a  fd fd		}}
;
	DB	0FDH,0FDH	; fe0c  fd fd		}}
;
	DB	0FDH,0FDH	; fe0e  fd fd		}}
;
	DB	0FDH,0FDH	; fe10  fd fd		}}
;
	DB	0FDH,0FDH	; fe12  fd fd		}}
;
	DB	0FDH,0FDH	; fe14  fd fd		}}
;
	DB	0FDH,0FDH	; fe16  fd fd		}}
;
	DB	0FDH,0FDH	; fe18  fd fd		}}
;
	DB	0FDH,0FDH	; fe1a  fd fd		}}
;
	DB	0FDH,0FDH	; fe1c  fd fd		}}
;
	DB	0FDH,0FDH	; fe1e  fd fd		}}
;
	DB	0FDH,0FDH	; fe20  fd fd		}}
;
	DB	0FDH,0FDH	; fe22  fd fd		}}
;
	DB	0FDH,0FDH	; fe24  fd fd		}}
;
	DB	0FDH,0FDH	; fe26  fd fd		}}
;
	DB	0FDH,0FDH	; fe28  fd fd		}}
;
	DB	0FDH,0FDH	; fe2a  fd fd		}}
;
	DB	0FDH,0FDH	; fe2c  fd fd		}}
;
	DB	0FDH,0FDH	; fe2e  fd fd		}}
;
	DB	0FDH,0FDH	; fe30  fd fd		}}
;
	DB	0FDH,0FDH	; fe32  fd fd		}}
;
	DB	0FDH,0FDH	; fe34  fd fd		}}
;
	DB	0FDH,0FDH	; fe36  fd fd		}}
;
	DB	0FDH,0FDH	; fe38  fd fd		}}
;
	DB	0FDH,0FDH	; fe3a  fd fd		}}
;
	DB	0FDH,0FDH	; fe3c  fd fd		}}
;
	DB	0FDH,0FDH	; fe3e  fd fd		}}
;
	DB	0FDH,0FDH	; fe40  fd fd		}}
;
	DB	0FDH,0FDH	; fe42  fd fd		}}
;
	DB	0FDH,0FDH	; fe44  fd fd		}}
;
	DB	0FDH,0FDH	; fe46  fd fd		}}
;
	DB	0FDH,0FDH	; fe48  fd fd		}}
;
	DB	0FDH,0FDH	; fe4a  fd fd		}}
;
	DB	0FDH,0FDH	; fe4c  fd fd		}}
;
	DB	0FDH,0FDH	; fe4e  fd fd		}}
;
	DB	0FDH,0FDH	; fe50  fd fd		}}
;
	DB	0FDH,0FDH	; fe52  fd fd		}}
;
	DB	0FDH,0FDH	; fe54  fd fd		}}
;
	DB	0FDH,0FDH	; fe56  fd fd		}}
;
	DB	0FDH,0FDH	; fe58  fd fd		}}
;
	DB	0FDH,0FDH	; fe5a  fd fd		}}
;
	DB	0FDH,0FDH	; fe5c  fd fd		}}
;
	DB	0FDH,0FDH	; fe5e  fd fd		}}
;
	DB	0FDH,0FDH	; fe60  fd fd		}}
;
	DB	0FDH,0FDH	; fe62  fd fd		}}
;
	DB	0FDH,0FDH	; fe64  fd fd		}}
;
	DB	0FDH,0FDH	; fe66  fd fd		}}
;
	DB	0FDH,0FDH	; fe68  fd fd		}}
;
	DB	0FDH,0FDH	; fe6a  fd fd		}}
;
	DB	0FDH,0FDH	; fe6c  fd fd		}}
;
	DB	0FDH,0FDH	; fe6e  fd fd		}}
;
	DB	0FDH,0FDH	; fe70  fd fd		}}
;
	DB	0FDH,0FDH	; fe72  fd fd		}}
;
	DB	0FDH,0FDH	; fe74  fd fd		}}
;
	DB	0FDH,0FDH	; fe76  fd fd		}}
;
	DB	0FDH,0FDH	; fe78  fd fd		}}
;
	DB	0FDH,0FDH	; fe7a  fd fd		}}
;
	DB	0FDH,0FDH	; fe7c  fd fd		}}
;
	DB	0FDH,0FDH	; fe7e  fd fd		}}
;
	DB	0FDH,0FDH	; fe80  fd fd		}}
;
	DB	0FDH,0FDH	; fe82  fd fd		}}
;
	DB	0FDH,0FDH	; fe84  fd fd		}}
;
	DB	0FDH,0FDH	; fe86  fd fd		}}
;
	DB	0FDH,0FDH	; fe88  fd fd		}}
;
	DB	0FDH,0FDH	; fe8a  fd fd		}}
;
	DB	0FDH,0FDH	; fe8c  fd fd		}}
;
	DB	0FDH,0FDH	; fe8e  fd fd		}}
;
	DB	0FDH,0FDH	; fe90  fd fd		}}
;
	DB	0FDH,0FDH	; fe92  fd fd		}}
;
	DB	0FDH,0FDH	; fe94  fd fd		}}
;
	DB	0FDH,0FDH	; fe96  fd fd		}}
;
	DB	0FDH,0FDH	; fe98  fd fd		}}
;
	DB	0FDH,0FDH	; fe9a  fd fd		}}
;
	DB	0FDH,0FDH	; fe9c  fd fd		}}
;
	DB	0FDH,0FDH	; fe9e  fd fd		}}
;
	DB	0FDH,0FDH	; fea0  fd fd		}}
;
	DB	0FDH,0FDH	; fea2  fd fd		}}
;
	DB	0FDH,0FDH	; fea4  fd fd		}}
;
	DB	0FDH,0FDH	; fea6  fd fd		}}
;
	DB	0FDH,0FDH	; fea8  fd fd		}}
;
	DB	0FDH,0FDH	; feaa  fd fd		}}
;
	DB	0FDH,0FDH	; feac  fd fd		}}
;
	DB	0FDH,0FDH	; feae  fd fd		}}
;
XFEB0:	DB	0FDH,0FDH	; feb0  fd fd		}}
;
	DB	0FDH,0FDH	; feb2  fd fd		}}
;
	DB	0FDH,0FDH	; feb4  fd fd		}}
;
	DB	0FDH,0FDH	; feb6  fd fd		}}
;
	DB	0FDH,0FDH	; feb8  fd fd		}}
;
	DB	0FDH,0FDH	; feba  fd fd		}}
;
	DB	0FDH,0FDH	; febc  fd fd		}}
;
	DB	0FDH,0FDH	; febe  fd fd		}}
;
	DB	0FDH,0FDH	; fec0  fd fd		}}
;
	DB	0FDH,0FDH	; fec2  fd fd		}}
;
	DB	0FDH,0FDH	; fec4  fd fd		}}
;
	DB	0FDH,0FDH	; fec6  fd fd		}}
;
	DB	0FDH,0FDH	; fec8  fd fd		}}
;
	DB	0FDH,0FDH	; feca  fd fd		}}
;
	DB	0FDH,0FDH	; fecc  fd fd		}}
;
	DB	0FDH,0FDH	; fece  fd fd		}}
;
	DB	0FDH,0FDH	; fed0  fd fd		}}
;
	DB	0FDH,0FDH	; fed2  fd fd		}}
;
	DB	0FDH,0FDH	; fed4  fd fd		}}
;
	DB	0FDH,0FDH	; fed6  fd fd		}}
;
	DB	0FDH,0FDH	; fed8  fd fd		}}
;
	DB	0FDH,0FDH	; feda  fd fd		}}
;
	DB	0FDH,0FDH	; fedc  fd fd		}}
;
	DB	0FDH,0FDH	; fede  fd fd		}}
;
	DB	0FDH,0FDH	; fee0  fd fd		}}
;
	DB	0FDH,0FDH	; fee2  fd fd		}}
;
	DB	0FDH,0FDH	; fee4  fd fd		}}
;
	DB	0FDH,0FDH	; fee6  fd fd		}}
;
	DB	0FDH,0FDH	; fee8  fd fd		}}
;
	DB	0FDH,0FDH	; feea  fd fd		}}
;
	DB	0FDH,0FDH	; feec  fd fd		}}
;
	DB	0FDH,0FDH	; feee  fd fd		}}
;
XFEF0:	DB	0FDH,0FDH	; fef0  fd fd		}}
;
	DB	0FDH,0FDH	; fef2  fd fd		}}
;
	DB	0FDH,0FDH	; fef4  fd fd		}}
;
	DB	0FDH,0FDH	; fef6  fd fd		}}
;
	DB	0FDH,0FDH	; fef8  fd fd		}}
;
XFEFA:	DB	0FDH,0FDH	; fefa  fd fd		}}
;
	DB	0FDH,0FDH	; fefc  fd fd		}}
;
XFEFE:	DB	0FDH,0FDH	; fefe  fd fd		}}
;
	DB	0FDH,0		; ff00  fd 00		}.
;
	ORG	0FF0CH
;
XFF0C:	NOP			; ff0c  00		.
XFF0D:	NOP			; ff0d  00		.
;
	ORG	0FF18H
;
	DW	X0DF3		; ff18   f3 0d      s.
	DW	X0BCE		; ff1a   ce 0b      N.
;
	CALL	PO,XCE50	; ff1c  e4 50 ce	dPN
	DEC	BC		; ff1f  0b		.
	PUSH	HL		; ff20  e5		e
	LD	D,B		; ff21  50		P
	INC	E		; ff22  1c		.
	RLA			; ff23  17		.
	CALL	C,XCE0A		; ff24  dc 0a ce	\.N
	DEC	BC		; ff27  0b		.
	EX	DE,HL		; ff28  eb		k
	LD	D,B		; ff29  50		P
	LD	D,17H		; ff2a  16 17		..
	CALL	C,XD70A		; ff2c  dc 0a d7	\.W
	JR	XFF4B		; ff2f  18 1a		..
;
	INC	BC		; ff31  03		.
	LD	A,(DE)		; ff32  1a		.
	INC	BC		; ff33  03		.
	IN	A,(2)		; ff34  db 02		[.
	LD	A,H		; ff36  7c		|
	JR	C,XFF0D		; ff37  38 d4		8T
	INC	BC		; ff39  03		.
	LD	C,L		; ff3a  4d		M
	NOP			; ff3b  00		.
XFF3C:	BIT	2,D		; ff3c  cb 52		KR
	DEC	(HL)		; ff3e  35		5
	NOP			; ff3f  00		.
	JP	Z,X0C52		; ff40  ca 52 0c	JR.
	LD	(BC),A		; ff43  02		.
	LD	E,H		; ff44  5c		\
	LD	C,0C0H		; ff45  0e c0		.@
	LD	D,A		; ff47  57		W
	LD	(HL),C		; ff48  71		q
	LD	C,0F3H		; ff49  0e f3		.s
XFF4B:	DEC	C		; ff4b  0d		.
	LD	HL,CHECK_PAUSE	; ff4c  21 17 c6	!.F
	LD	E,0B7H		; ff4f  1e b7		.7
	ADC	A,B		; ff51  88		.
	HALT			; ff52  76		v
;
	DEC	DE		; ff53  1b		.
	INC	BC		; ff54  03		.
	INC	DE		; ff55  13		.
	NOP			; ff56  00		.
	LD	A,0		; ff57  3e 00		>.
;
	DB	'<BB~BB'				; ff59
XFF5F:	DB	0					; ff5f .
;
	NOP			; ff60  00		.
;
	DB	'|B|BB|'				; ff61
	DB	0					; ff67 .
;
	NOP			; ff68  00		.
;
	DB	'<B@@B<'				; ff69
	DB	0					; ff6f .
;
XFF70:	NOP			; ff70  00		.
;
	DB	'xDBBDx'				; ff71
	DB	0					; ff77 .
;
	NOP			; ff78  00		.
;
	DB	'~@|@@~'				; ff79
XFF7F:	DB	0					; ff7f .
;
	NOP			; ff80  00		.
;
	DB	'~@|@@@'				; ff81
	DB	0					; ff87 .
;
	NOP			; ff88  00		.
;
	DB	'<B@NB<'				; ff89
	DB	0					; ff8f .
;
	NOP			; ff90  00		.
;
	DB	'BB~BBB'				; ff91
	DB	0					; ff97 .
;
	NOP			; ff98  00		.
;
	DB	3EH,8,8,8,8,3EH				; ff99 >....>
;
	ORG	0FFA1H
;
	LD	(BC),A		; ffa1  02		.
	LD	(BC),A		; ffa2  02		.
	LD	(BC),A		; ffa3  02		.
	LD	B,D		; ffa4  42		B
	LD	B,D		; ffa5  42		B
	INC	A		; ffa6  3c		<
	NOP			; ffa7  00		.
	NOP			; ffa8  00		.
;
	DB	'DHpHDB'				; ffa9
	DB	0					; ffaf .
;
	NOP			; ffb0  00		.
;
	DB	'@@@@@~'				; ffb1
XFFB7:	DB	0					; ffb7 .
;
	NOP			; ffb8  00		.
;
	DB	'BfZBBB'				; ffb9
XFFBF:	DB	0					; ffbf .
;
	NOP			; ffc0  00		.
;
	DB	'BbRJFB'				; ffc1
	DB	0					; ffc7 .
;
	NOP			; ffc8  00		.
;
	DB	'<BBBB<'				; ffc9
	DB	0					; ffcf .
;
	NOP			; ffd0  00		.
;
	DB	'|BB|@@'				; ffd1
	DB	0					; ffd7 .
;
	NOP			; ffd8  00		.
;
	DB	'<BBRJ<'				; ffd9
	DB	0					; ffdf .
;
	NOP			; ffe0  00		.
;
	DB	'|B'					; ffe1
Xffe3:	DB	'B|DB'					; ffe3
	DB	0					; ffe7 .
;
	NOP			; ffe8  00		.
;
	DB	3CH					; ffe9 <
;
	LD	B,B		; ffea  40		@
	INC	A		; ffeb  3c		<
	LD	(BC),A		; ffec  02		.
	LD	B,D		; ffed  42		B
	INC	A		; ffee  3c		<
XFFEF:	NOP			; ffef  00		.
;
	ORG	0FFF1H
;
XFFF1:	CP	10H		; fff1  fe 10		~.
	DJNZ	X0005		; fff3  10 10		..
	DJNZ	X0007		; fff5  10 10		..
	NOP			; fff7  00		.
;
	ORG	0FFF9H
;
	LD	B,D		; fff9  42		B
XFFFA:	LD	B,D		; fffa  42		B
	LD	B,D		; fffb  42		B
	LD	B,D		; fffc  42		B
XFFFD:	LD	B,D		; fffd  42		B
XFFFE:	INC	A		; fffe  3c		<
;
;	Miscellaneous equates
;
;  These are addresses referenced in the code but
;  which are in the middle of a multibyte instruction
;  or are addresses outside the initialized space
;
X0000	EQU	0
X0003	EQU	3
X0004	EQU	4
X0005	EQU	5
X0006	EQU	6
X0007	EQU	7
X0009	EQU	9
X000A	EQU	0AH
X000E	EQU	0EH
X000F	EQU	0FH
X0011	EQU	11H
X0014	EQU	14H
X0018	EQU	18H
X001F	EQU	1FH
X0020	EQU	20H
X0032	EQU	32H
X0042	EQU	42H
X005A	EQU	5AH
X005C	EQU	5CH
X0060	EQU	60H
X0064	EQU	64H
X0080	EQU	80H
X00AA	EQU	0AAH
X00B0	EQU	0B0H
X00BC	EQU	0BCH
X00BE	EQU	0BEH
X00BF	EQU	0BFH
X00C0	EQU	0C0H
X00C8	EQU	0C8H
X00CD	EQU	0CDH
X00D5	EQU	0D5H
X00E2	EQU	0E2H
X00E4	EQU	0E4H
X00E8	EQU	0E8H
X00EA	EQU	0EAH
X00F0	EQU	0F0H
X00F6	EQU	0F6H
X00FD	EQU	0FDH
X00FE	EQU	0FEH
X00FF	EQU	0FFH
X0120	EQU	120H
X018C	EQU	18CH
X01CD	EQU	1CDH
X01D4	EQU	1D4H
X01D5	EQU	1D5H
X01D6	EQU	1D6H
X01F0	EQU	1F0H
X01FE	EQU	1FEH
X01FF	EQU	1FFH
X0204	EQU	204H
X0205	EQU	205H
X0208	EQU	208H
X0216	EQU	216H
X021C	EQU	21CH
X025C	EQU	25CH
X0280	EQU	280H
X02BC	EQU	2BCH
X02C0	EQU	2C0H
X02E6	EQU	2E6H
X02FC	EQU	2FCH
X02FD	EQU	2FDH
X0351	EQU	351H
X0352	EQU	352H
X035C	EQU	35CH
X03B0	EQU	3B0H
X03C4	EQU	3C4H
X03CD	EQU	3CDH
X03D6	EQU	3D6H
X03E6	EQU	3E6H
X03E8	EQU	3E8H
X03FC	EQU	3FCH
X03FE	EQU	3FEH
X03FF	EQU	3FFH
X0400	EQU	400H
X0420	EQU	420H
X0454	EQU	454H
X045C	EQU	45CH
X04C7	EQU	4C7H
X0500	EQU	500H
X0509	EQU	509H
X050A	EQU	50AH
X0510	EQU	510H
X055C	EQU	55CH
X0560	EQU	560H
X05C5	EQU	5C5H
X060F	EQU	60FH
X06B2	EQU	6B2H
X06EB	EQU	6EBH
X06F1	EQU	6F1H
X06FC	EQU	6FCH
X06FE	EQU	6FEH
X0710	EQU	710H
X07C0	EQU	7C0H
X07D0	EQU	7D0H
X07E8	EQU	7E8H
X07F0	EQU	7F0H
X07FE	EQU	7FEH
X085B	EQU	85BH
X08C0	EQU	8C0H
X08E8	EQU	8E8H
X08F7	EQU	8F7H
X08FF	EQU	8FFH
X0906	EQU	906H
X0907	EQU	907H
X0908	EQU	908H
X090D	EQU	90DH
X0950	EQU	950H
X09FE	EQU	9FEH
X0A05	EQU	0A05H
X0A09	EQU	0A09H
X0A60	EQU	0A60H
X0AF0	EQU	0AF0H
X0B08	EQU	0B08H
X0BCE	EQU	0BCEH
X0C52	EQU	0C52H
X0C60	EQU	0C60H
X0CF3	EQU	0CF3H
X0D0C	EQU	0D0CH
X0DF0	EQU	0DF0H
X0DF3	EQU	0DF3H
X0EBC	EQU	0EBCH
X0EF0	EQU	0EF0H
X0F02	EQU	0F02H
X0FF0	EQU	0FF0H
X1050	EQU	1050H
X10BB	EQU	10BBH
X10C6	EQU	10C6H
X10D5	EQU	10D5H
X10EF	EQU	10EFH
X10FE	EQU	10FEH
X11C5	EQU	11C5H
X1202	EQU	1202H
X1208	EQU	1208H
X12B1	EQU	12B1H
X13C8	EQU	13C8H
X1420	EQU	1420H
X15C4	EQU	15C4H
X15CD	EQU	15CDH
X1700	EQU	1700H
X182F	EQU	182FH
X18C0	EQU	18C0H
X18CB	EQU	18CBH
X18CD	EQU	18CDH
X18CE	EQU	18CEH
X18FE	EQU	18FEH
X19CB	EQU	19CBH
X1AB6	EQU	1AB6H
X1AC5	EQU	1AC5H
X1ACB	EQU	1ACBH
X1CFF	EQU	1CFFH
X1EC6	EQU	1EC6H
X1EEA	EQU	1EEAH
X1EF2	EQU	1EF2H
X1EFF	EQU	1EFFH
X1FC0	EQU	1FC0H
X1FCC	EQU	1FCCH
X1FE8	EQU	1FE8H
X1FF0	EQU	1FF0H
X1FFE	EQU	1FFEH
X20B5	EQU	20B5H
X20B7	EQU	20B7H
X20B8	EQU	20B8H
X20C0	EQU	20C0H
X20CD	EQU	20CDH
X215B	EQU	215BH
X21BA	EQU	21BAH
X21BC	EQU	21BCH
X21BF	EQU	21BFH
X21C0	EQU	21C0H
X21CB	EQU	21CBH
X21CE	EQU	21CEH
X21D0	EQU	21D0H
X21EB	EQU	21EBH
X21EE	EQU	21EEH
X21FA	EQU	21FAH
X21FE	EQU	21FEH
X22BB	EQU	22BBH
X22EF	EQU	22EFH
X2357	EQU	2357H
X24EE	EQU	24EEH
X26CD	EQU	26CDH
X2710	EQU	2710H
X29EB	EQU	29EBH
X2BC0	EQU	2BC0H
X2BCE	EQU	2BCEH
X2BFE	EQU	2BFEH
X2FB1	EQU	2FB1H
X30B8	EQU	30B8H
X30BF	EQU	30BFH
X30CA	EQU	30CAH
X30E7	EQU	30E7H
X30FE	EQU	30FEH
X30FF	EQU	30FFH
X31F0	EQU	31F0H
X32C3	EQU	32C3H
X32FF	EQU	32FFH
X33F0	EQU	33F0H
X34CB	EQU	34CBH
X34CD	EQU	34CDH
X35B2	EQU	35B2H
X35C0	EQU	35C0H
X37AF	EQU	37AFH
X37CD	EQU	37CDH
X37FE	EQU	37FEH
X38CB	EQU	38CBH
X39C0	EQU	39C0H
X3ABC	EQU	3ABCH
X3AC0	EQU	3AC0H
X3ACF	EQU	3ACFH
X3AEB	EQU	3AEBH
X3AF0	EQU	3AF0H
X3BCB	EQU	3BCBH
X3CC3	EQU	3CC3H
X3CF0	EQU	3CF0H
X3DC0	EQU	3DC0H
X3DF0	EQU	3DF0H
X3EC9	EQU	3EC9H
X3ECD	EQU	3ECDH
X3ECE	EQU	3ECEH
X3ED1	EQU	3ED1H
X3EE4	EQU	3EE4H
X3EED	EQU	3EEDH
X3EF3	EQU	3EF3H
X3EFF	EQU	3EFFH
X3F03	EQU	3F03H
X3FC0	EQU	3FC0H
X3FCB	EQU	3FCBH
X3FE7	EQU	3FE7H
X3FF0	EQU	3FF0H
X3FFE	EQU	3FFEH
X40BF	EQU	40BFH
X40C0	EQU	40C0H
X40CA	EQU	40CAH
X41C0	EQU	41C0H
X42C0	EQU	42C0H
X43C0	EQU	43C0H
X43ED	EQU	43EDH
X44C0	EQU	44C0H
X45C0	EQU	45C0H
X46C0	EQU	46C0H
X47C0	EQU	47C0H
X48CD	EQU	48CDH
X4CCD	EQU	4CCDH
X50D5	EQU	50D5H
X50E9	EQU	50E9H
X5EED	EQU	5EEDH
X5FD5	EQU	5FD5H
X60D6	EQU	60D6H
X61CD	EQU	61CDH
X6FBC	EQU	6FBCH
X70CD	EQU	70CDH
X71CD	EQU	71CDH
X73EB	EQU	73EBH
X76CB	EQU	76CBH
X77B2	EQU	77B2H
X78C0	EQU	78C0H
X78CD	EQU	78CDH
X78ED	EQU	78EDH
X79BC	EQU	79BCH
X7ACD	EQU	7ACDH
X7BB2	EQU	7BB2H
X7EC0	EQU	7EC0H
X7ECB	EQU	7ECBH
X7FC0	EQU	7FC0H
X7FCB	EQU	7FCBH
X81E5	EQU	81E5H
X86CD	EQU	86CDH
X89B9	EQU	89B9H
X92B2	EQU	92B2H
XA0C8	EQU	0A0C8H
XA0ED	EQU	0A0EDH
XA9CD	EQU	0A9CDH
XB0AB	EQU	0B0ABH
XB0B0	EQU	0B0B0H
XB0B5	EQU	0B0B5H
XB0BA	EQU	0B0BAH
XB0F3	EQU	0B0F3H
XBB97	EQU	0BB97H
XBBCB	EQU	0BBCBH
XBEBF	EQU	0BEBFH
XBEF7	EQU	0BEF7H
XC3B3	EQU	0C3B3H
XC6CB	EQU	0C6CBH
XC8D6	EQU	0C8D6H
XC9CE	EQU	0C9CEH
XCBB2	EQU	0CBB2H
XCBB4	EQU	0CBB4H
XCBCE	EQU	0CBCEH
XCDF9	EQU	0CDF9H
XD51F	EQU	0D51FH
XDEA6	EQU	0DEA6H
XF085	EQU	0F085H
XF0A9	EQU	0F0A9H
XF312	EQU	0F312H
XFADB	EQU	0FADBH
XFAE7	EQU	0FAE7H
ROW_PTR_TABLE	EQU	0FC00H
XFDFE	EQU	0FDFEH
XFDFF	EQU	0FDFFH
;
	END
;


