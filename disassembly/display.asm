; ==========================================================================
; SCORE DISPLAY, TIMER BAR & TEXT RENDERING ($D27A-$D3C3)
; ==========================================================================
;
; HUD LAYOUT (rows 0-3, above the game field):
;   Row 0-1: "Score XXXXX   Level XX   Lives X" (double-height HUD font)
;   Row 2-3: "Time" + timer bar + "XXX%"
;
; UPDATE_SCORE_DISPLAY ($D27A):
;   Computes display_score = base_score + (rawPercent + fillPercent) * 4
;   Renders as 5 decimal digits using HUD font.
;
; UPDATE_LEVEL_DISPLAY ($D295):
;   Renders level number + 1 (1-based for display).
;
; UPDATE_PERCENT_DISPLAY ($D2A3):
;   Renders filled percentage with "%" suffix.
;
; UPDATE_LIVES_DISPLAY ($D2B0):
;   Renders lives count.
;
; UPDATE_TIMER_BAR ($D2C1):
;   Animated XOR pixel bar. Width = timer value pixels.
;   13 pixels tall at Y=17-29, starting at X=40.
;   Returns carry=1 if bar position != timer (still animating).
;
; DISPLAY_5DIGIT ($D315):
;   Converts 16-bit HL to 5 decimal digits, renders with HUD font.
;
; DISPLAY_2DIGIT ($D341) / DISPLAY_3DIGIT ($D34E):
;   Converts 8-bit A to 2 or 3 decimal digits.
;
; HUD_STRING_RENDER ($D36E):
;   Renders string using double-height HUD font ($FA00).
;   Limited charset: 0-9, space, %, S, c, o, r, e, L, v, l, i, s, T, m
;
; HUD_CHAR_RENDER ($D386):
;   Renders single 8x16 character. Each font byte is written twice
;   (doubled vertically) to create the double-height effect.
;

;

; --- Update score ---
UPDATE_SCORE_DISPLAY:	LD	HL,X0006	; d27a  21 06 00	!..
	LD	(SCORE_DISPLAY_POS),HL	; d27d  22 12 d3	".S
	LD	A,(FILL_PERCENT)	; d280  3a c6 b0	:F0
	LD	HL,RAW_PERCENT	; d283  21 c5 b0	!E0
	ADD	A,(HL)		; d286  86		.
	LD	L,A		; d287  6f		o
	LD	H,0		; d288  26 00		&.
	ADD	HL,HL		; d28a  29		)
	ADD	HL,HL		; d28b  29		)
	LD	DE,(BASE_SCORE)	; d28c  ed 5b c3 b0	m[C0
	ADD	HL,DE		; d290  19		.
;
	DW	X15CD		; d291   cd 15      M.
	DW	XC9D3		; d293   d3 c9      SI
;

; --- Update level ---
UPDATE_LEVEL_DISPLAY:	LD	HL,X0014	; d295  21 14 00	!..
	LD	(SCORE_DISPLAY_POS),HL	; d298  22 12 d3	".S
	LD	A,(LEVEL_NUM)	; d29b  3a c1 b0	:A0
	INC	A		; d29e  3c		<
	CALL	DISPLAY_2DIGIT		; d29f  cd 41 d3	MAS
	RET			; d2a2  c9		I
;

; --- Update percent ---
UPDATE_PERCENT_DISPLAY:	LD	HL,X021C	; d2a3  21 1c 02	!..
	LD	(SCORE_DISPLAY_POS),HL	; d2a6  22 12 d3	".S
	LD	A,(FILL_PERCENT)	; d2a9  3a c6 b0	:F0
	CALL	DISPLAY_3DIGIT		; d2ac  cd 4e d3	MNS
	RET			; d2af  c9		I
;

; --- Update lives ---
UPDATE_LIVES_DISPLAY:	LD	HL,X001F	; d2b0  21 1f 00	!..
	LD	(SCORE_DISPLAY_POS),HL	; d2b3  22 12 d3	".S
	LD	A,(LIVES)	; d2b6  3a c2 b0	:B0
	LD	IX,SCORE_DISPLAY_POS	; d2b9  dd 21 12 d3	]!.S
	CALL	HUD_CHAR_RENDER		; d2bd  cd 86 d3	M.S
	RET			; d2c0  c9		I
;

; --- Update timer bar ---
UPDATE_TIMER_BAR:	LD	HL,TIMER_BAR_POS	; d2c1  21 bf b0	!?0
	LD	A,(GAME_TIMER)	; d2c4  3a c0 b0	:@0
	CP	(HL)		; d2c7  be		>
	RET	Z		; d2c8  c8		H
	JR	C,XD2CF		; d2c9  38 04		8.
	INC	(HL)		; d2cb  34		4
	LD	A,(HL)		; d2cc  7e		~
	JR	XD2D1		; d2cd  18 02		..
;
XD2CF:	LD	A,(HL)		; d2cf  7e		~
	DEC	(HL)		; d2d0  35		5
XD2D1:	ADD	A,28H		; d2d1  c6 28		F(
	LD	B,A		; d2d3  47		G
	RRA			; d2d4  1f		.
	RRA			; d2d5  1f		.
	RRA			; d2d6  1f		.
	AND	1FH		; d2d7  e6 1f		f.
	LD	C,A		; d2d9  4f		O
	LD	A,B		; d2da  78		x
	AND	7		; d2db  e6 07		f.
	ADD	A,8		; d2dd  c6 08		F.
	LD	E,A		; d2df  5f		_
	LD	D,0FBH		; d2e0  16 fb		.{
	LD	IX,XFC22	; d2e2  dd 21 22 fc	]!"|
	LD	B,0DH		; d2e6  06 0d		..
XD2E8:	LD	A,(IX+0)	; d2e8  dd 7e 00	]~.
	ADD	A,C		; d2eb  81		.
	LD	L,A		; d2ec  6f		o
	LD	H,(IX+1)	; d2ed  dd 66 01	]f.
	LD	A,(DE)		; d2f0  1a		.
	XOR	(HL)		; d2f1  ae		.
	LD	(HL),A		; d2f2  77		w
	INC	IX		; d2f3  dd 23		]#
	INC	IX		; d2f5  dd 23		]#
	DJNZ	XD2E8		; d2f7  10 ef		.o
	LD	A,(TIMER_BAR_POS)	; d2f9  3a bf b0	:?0
	CP	28H		; d2fc  fe 28		~(
	LD	A,44H		; d2fe  3e 44		>D
	JR	NC,XD304	; d300  30 02		0.
	LD	A,42H		; d302  3e 42		>B
XD304:	CALL	PROCESS_ATTR_COLOR		; d304  cd 07 bc	M.<
	LD	BC,X0205	; d307  01 05 02	...
	LD	DE,X0216	; d30a  11 16 02	...
	CALL	FILL_ATTR_RECT		; d30d  cd f6 ba	Mv:
	SCF			; d310  37		7
	RET			; d311  c9		I
;

; --- Score display pos ---
SCORE_DISPLAY_POS:	NOP			; d312  00		.
;
	ORG	0D314H
;
	DB	38H					; d314 8
;

; --- Display 5 digits ---
DISPLAY_5DIGIT:	LD	IX,SCORE_DISPLAY_POS	; d315  dd 21 12 d3	]!.S
	LD	DE,X2710	; d319  11 10 27	..'
	CALL	XD335		; d31c  cd 35 d3	M5S
	LD	DE,X03E8	; d31f  11 e8 03	.h.
	CALL	XD335		; d322  cd 35 d3	M5S
	LD	DE,X0064	; d325  11 64 00	.d.
	CALL	XD335		; d328  cd 35 d3	M5S
	LD	DE,X000A	; d32b  11 0a 00	...
	CALL	XD335		; d32e  cd 35 d3	M5S
	LD	A,L		; d331  7d		}
	JP	HUD_CHAR_RENDER		; d332  c3 86 d3	C.S
;
XD335:	LD	A,0FFH		; d335  3e ff		>.
XD337:	INC	A		; d337  3c		<
	SBC	HL,DE		; d338  ed 52		mR
	JR	NC,XD337	; d33a  30 fb		0{
	ADD	HL,DE		; d33c  19		.
	CALL	HUD_CHAR_RENDER		; d33d  cd 86 d3	M.S
	RET			; d340  c9		I
;

; --- Display 2 digits ---
DISPLAY_2DIGIT:	LD	IX,SCORE_DISPLAY_POS	; d341  dd 21 12 d3	]!.S
	LD	E,0AH		; d345  1e 0a		..
	CALL	XD360		; d347  cd 60 d3	M`S
	CALL	HUD_CHAR_RENDER		; d34a  cd 86 d3	M.S
	RET			; d34d  c9		I
;

; --- Display 3 digits ---
DISPLAY_3DIGIT:	LD	IX,SCORE_DISPLAY_POS	; d34e  dd 21 12 d3	]!.S
	LD	E,64H		; d352  1e 64		.d
	CALL	XD360		; d354  cd 60 d3	M`S
	LD	E,0AH		; d357  1e 0a		..
	CALL	XD360		; d359  cd 60 d3	M`S
	CALL	HUD_CHAR_RENDER		; d35c  cd 86 d3	M.S
	RET			; d35f  c9		I
;
XD360:	LD	C,0FFH		; d360  0e ff		..
XD362:	INC	C		; d362  0c		.
	SUB	E		; d363  93		.
	JR	NC,XD362	; d364  30 fc		0|
	ADD	A,E		; d366  83		.
	PUSH	AF		; d367  f5		u
	LD	A,C		; d368  79		y
	CALL	HUD_CHAR_RENDER		; d369  cd 86 d3	M.S
	POP	AF		; d36c  f1		q
	RET			; d36d  c9		I
;

; --- HUD string render ---
HUD_STRING_RENDER:	LD	IX,SCORE_DISPLAY_POS	; d36e  dd 21 12 d3	]!.S
	LD	A,(HL)		; d372  7e		~
	LD	(IX+0),A	; d373  dd 77 00	]w.
	INC	HL		; d376  23		#
	LD	A,(HL)		; d377  7e		~
	LD	(IX+1),A	; d378  dd 77 01	]w.
	INC	HL		; d37b  23		#
XD37C:	LD	A,(HL)		; d37c  7e		~
	INC	HL		; d37d  23		#
	CP	0FFH		; d37e  fe ff		~.
	RET	Z		; d380  c8		H
	CALL	HUD_CHAR_RENDER		; d381  cd 86 d3	M.S
	JR	XD37C		; d384  18 f6		.v
;

; --- HUD char render ---
HUD_CHAR_RENDER:	PUSH	BC		; d386  c5		E
	PUSH	DE		; d387  d5		U
	PUSH	HL		; d388  e5		e
	LD	L,A		; d389  6f		o
	LD	H,0		; d38a  26 00		&.
	ADD	HL,HL		; d38c  29		)
	ADD	HL,HL		; d38d  29		)
	ADD	HL,HL		; d38e  29		)
	LD	DE,HUD_FONT	; d38f  11 00 fa	..z
	ADD	HL,DE		; d392  19		.
	EX	DE,HL		; d393  eb		k
	LD	A,(IX+1)	; d394  dd 7e 01	]~.
	ADD	A,A		; d397  87		.
	ADD	A,A		; d398  87		.
	ADD	A,A		; d399  87		.
	ADD	A,A		; d39a  87		.
	LD	L,A		; d39b  6f		o
	LD	A,0FCH		; d39c  3e fc		>|
	ADC	A,0		; d39e  ce 00		N.
	LD	H,A		; d3a0  67		g
	LD	B,8		; d3a1  06 08		..
XD3A3:	LD	A,(IX+0)	; d3a3  dd 7e 00	]~.
	ADD	A,(HL)		; d3a6  86		.
	INC	HL		; d3a7  23		#
	PUSH	HL		; d3a8  e5		e
	LD	H,(HL)		; d3a9  66		f
	LD	L,A		; d3aa  6f		o
	LD	A,(DE)		; d3ab  1a		.
	INC	DE		; d3ac  13		.
	BIT	7,(IX+2)	; d3ad  dd cb 02 7e	]K.~
	JR	Z,XD3B4		; d3b1  28 01		(.
	CPL			; d3b3  2f		/
XD3B4:	LD	(HL),A		; d3b4  77		w
	INC	H		; d3b5  24		$
	LD	(HL),A		; d3b6  77		w
	POP	HL		; d3b7  e1		a
	INC	HL		; d3b8  23		#
	INC	HL		; d3b9  23		#
	INC	HL		; d3ba  23		#
	DJNZ	XD3A3		; d3bb  10 e6		.f
	INC	(IX+0)		; d3bd  dd 34 00	]4.
	POP	HL		; d3c0  e1		a
	POP	DE		; d3c1  d1		Q
	POP	BC		; d3c2  c1		A
	RET			; d3c3  c9		I
;
