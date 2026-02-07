; ==========================================================================
; SPRITE DRAWING ROUTINES ($D078-$D189)
; ==========================================================================
;
; DRAW_MASKED_SPRITE ($D078):
;   Draws an 8x8 pixel sprite using AND-mask + OR-data compositing.
;   Each sprite row is 4 bytes: mask1, data1, mask2, data2
;   (2 bytes wide to handle sub-pixel alignment).
;   For each pixel row:
;     screen_byte = (screen_byte AND mask) OR data
;   This allows transparent pixels (mask=FF, data=00) and opaque
;   pixels (mask=00, data=sprite_bits).
;
; SAVE_SPRITE_BG ($D0AC):
;   Saves the 32 bytes of screen bitmap under a sprite's position.
;   Stored in the entity's data structure (offset +5 for chasers).
;
; RESTORE_SPRITE_BG ($D0E5):
;   Restores saved background, effectively erasing the sprite.
;   Called at the start of each frame before entities are redrawn.
;
; Each entity (player, chasers, trail cursor) has 8 pre-shifted
; alignment variants of its sprite at $F000/$F100/$F200.
; The variant is selected based on the entity's sub-pixel X position.
;

;

; --- Draw masked sprite ---
DRAW_MASKED_SPRITE:	LD	A,(HL)		; d078  7e		~
	OR	A		; d079  b7		7
	RET	Z		; d07a  c8		H
	INC	HL		; d07b  23		#
	INC	HL		; d07c  23		#
	ADD	A,A		; d07d  87		.
	SUB	3		; d07e  d6 03		V.
	RRCA			; d080  0f		.
	RRCA			; d081  0f		.
	RRCA			; d082  0f		.
	AND	0E0H		; d083  e6 e0		f`
	LD	E,A		; d085  5f		_
	LD	A,(HL)		; d086  7e		~
	INC	HL		; d087  23		#
	INC	HL		; d088  23		#
	INC	HL		; d089  23		#
	ADD	A,0F0H		; d08a  c6 f0		Fp
	LD	D,A		; d08c  57		W
	LD	B,8		; d08d  06 08		..
XD08F:	LD	A,(HL)		; d08f  7e		~
	INC	HL		; d090  23		#
	PUSH	HL		; d091  e5		e
	LD	H,(HL)		; d092  66		f
	LD	L,A		; d093  6f		o
	LD	A,(DE)		; d094  1a		.
	INC	DE		; d095  13		.
	AND	(HL)		; d096  a6		&
	EX	DE,HL		; d097  eb		k
	OR	(HL)		; d098  b6		6
	EX	DE,HL		; d099  eb		k
	LD	(HL),A		; d09a  77		w
	INC	HL		; d09b  23		#
	INC	DE		; d09c  13		.
	LD	A,(DE)		; d09d  1a		.
	INC	DE		; d09e  13		.
	AND	(HL)		; d09f  a6		&
	EX	DE,HL		; d0a0  eb		k
	OR	(HL)		; d0a1  b6		6
	EX	DE,HL		; d0a2  eb		k
	LD	(HL),A		; d0a3  77		w
	INC	DE		; d0a4  13		.
	POP	HL		; d0a5  e1		a
	INC	HL		; d0a6  23		#
	INC	HL		; d0a7  23		#
	INC	HL		; d0a8  23		#
	DJNZ	XD08F		; d0a9  10 e4		.d
	RET			; d0ab  c9		I
;

; --- Save sprite bg ---
SAVE_SPRITE_BG:	LD	A,(HL)		; d0ac  7e		~
	OR	A		; d0ad  b7		7
	RET	Z		; d0ae  c8		H
;
	DB	'_#V####{'				; d0af
	DB	87H					; d0b7 .
	DW	X03D6		; d0b8   d6 03      V.
;
	DB	1FH,1FH,1FH,0E6H,1FH,4FH,7AH,87H	; d0ba ...f.Oz.
	DW	X03D6		; d0c2   d6 03      V.
;
	DB	87H,5FH,0CEH,0FCH,93H,57H		; d0c4 ._N|.W
	DW	X06EB		; d0ca   eb 06      k.
;
	DB	8,79H,86H,23H,0E5H,66H,6FH		; d0cc .y.#efo
	DW	X73EB		; d0d3   eb 73      ks
;
	DB	23H,72H,23H,1AH,77H,23H,13H,1AH		; d0d5 #r#.w#..
	DB	77H,23H					; d0dd w#
	DW	XE1EB		; d0df   eb e1      ka
;
	DB	23H,10H					; d0e1 #.
	DW	XC9E9		; d0e3   e9 c9      iI
;
;

; --- Restore sprite bg ---
RESTORE_SPRITE_BG:	LD	A,(HL)		; d0e5  7e		~
	OR	A		; d0e6  b7		7
	RET	Z		; d0e7  c8		H
	LD	DE,X0005	; d0e8  11 05 00	...
	ADD	HL,DE		; d0eb  19		.
	LD	BC,X08FF	; d0ec  01 ff 08	...
XD0EF:	LD	E,(HL)		; d0ef  5e		^
	INC	HL		; d0f0  23		#
	LD	D,(HL)		; d0f1  56		V
	INC	HL		; d0f2  23		#
	LDI			; d0f3  ed a0		m 
	LDI			; d0f5  ed a0		m 
	DJNZ	XD0EF		; d0f7  10 f6		.v
	RET			; d0f9  c9		I
;
	DB	7EH					; d0fa ~
	DW	XC8B7		; d0fb   b7 c8      7H
;
	DB	1					; d0fd .
XD0FE:	DB	0,0CH,87H				; d0fe ...
	DW	X03D6		; d101   d6 03      V.
	DW	X3FCB		; d103   cb 3f      K?
	DW	X03E6		; d105   e6 03      f.
;
	DB	28H,0BH					; d107 (.
	DW	X38CB		; d109   cb 38      K8
	DW	X19CB		; d10b   cb 19      K.
	DW	X38CB		; d10d   cb 38      K8
	DW	X19CB		; d10f   cb 19      K.
;
	DB	3DH,20H					; d111 = 
	DW	XC5F5		; d113   f5 c5      uE
;
	DB	11H,5,0,19H,1,0FFH,3,5EH		; d115 .......^
	DB	23H,56H,23H				; d11d #V#
	DW	XA0ED		; d120   ed a0      m 
	DW	XA0ED		; d122   ed a0      m 
;
	DB	10H,0F6H,0C1H,5EH,23H,56H,23H,7EH	; d124 .vA^#V#~
	DB	0B0H,12H,23H,13H,7EH			; d12c 0.#.~
	DW	X12B1		; d131   b1 12      1.
;
	DB	'#^#V#~'				; d133
	DB	0B0H,12H,23H,13H,7EH			; d139 0.#.~
;
	OR	C		; d13e  b1		1
	LD	(DE),A		; d13f  12		.
	INC	HL		; d140  23		#
	LD	BC,X03FF	; d141  01 ff 03	...
XD144:	LD	E,(HL)		; d144  5e		^
	INC	HL		; d145  23		#
	LD	D,(HL)		; d146  56		V
	INC	HL		; d147  23		#
	LDI			; d148  ed a0		m 
	LDI			; d14a  ed a0		m 
	DJNZ	XD144		; d14c  10 f6		.v
	RET			; d14e  c9		I
;
XD14F:	LD	A,B		; d14f  78		x
	LD	B,10H		; d150  06 10		..
	LD	HL,X0000	; d152  21 00 00	!..
XD155:	RL	C		; d155  cb 11		K.
	RLA			; d157  17		.
	ADC	HL,HL		; d158  ed 6a		mj
	SBC	HL,DE		; d15a  ed 52		mR
XD15C:	CCF			; d15c  3f		?
	JR	NC,XD170	; d15d  30 11		0.
XD15F:	DJNZ	XD155		; d15f  10 f4		.t
	JP	XD172		; d161  c3 72 d1	CrQ
;
XD164:	RL	C		; d164  cb 11		K.
	RLA			; d166  17		.
	ADC	HL,HL		; d167  ed 6a		mj
	OR	A		; d169  b7		7
	ADC	HL,DE		; d16a  ed 5a		mZ
	JR	C,XD15F		; d16c  38 f1		8q
	JR	Z,XD15C		; d16e  28 ec		(l
XD170:	DJNZ	XD164		; d170  10 f2		.r
XD172:	RL	C		; d172  cb 11		K.
	RLA			; d174  17		.
	LD	B,A		; d175  47		G
	RET			; d176  c9		I
;
	DB	78H,6,0FH,21H,0,0			; d177 x..!..
	DW	X21CB		; d17d   cb 21      K!
;
	DB	17H,30H,1,19H,29H,10H,0F7H		; d17f .0..).w
	DW	XF0B7		; d186   b7 f0      7p
;
	DB	19H,0C9H				; d188 .I
;
