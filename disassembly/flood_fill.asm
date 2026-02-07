; ==========================================================================
; SCANLINE FLOOD FILL ALGORITHM ($CF01-$D077)
; ==========================================================================
;
; Triggered when the player's trail reaches a border cell.
; Uses an explicit stack at $9400 (pointer via self-modifying code at $CEFF).
;
; Algorithm:
;   1. Pop seed coordinate (X, Y) from stack
;   2. Scan left to find leftmost empty cell in row
;   3. Scan right to find rightmost empty cell in row
;   4. Fill entire horizontal run with CLAIMED (value 1, $55/$00)
;   5. For the row above and row below:
;      - Scan for new empty segments adjacent to the filled run
;      - Push seed coordinates for each new segment
;   6. Repeat until stack is empty
;
; Writes to BOTH bitmap and shadow grid via WRITE_CELL_BOTH ($CE9F),
; ensuring claimed areas are visible to all entities.
;
; The fill is seeded from multiple points along the trail (one per trail
; segment, offset perpendicular to the trail direction). This ensures
; the entire enclosed area is filled even with complex trail shapes.
;

;
	ORG	0CF01H
;

; --- Flood fill ---
FLOOD_FILL:
	DB	87H,4FH,6,0,21H,0C9H,0B0H,9		; cf01 .O..!I0.
	DB	7EH,32H					; cf09 ~2
	DW	XCEFC		; cf0b   fc ce      |N
;
	DB	23H,7EH,32H,0FDH			; cf0d #~2}
	DW	X21CE		; cf11   ce 21      N!
;
	DB	0,94H,22H,0FFH				; cf13 ..".
	DW	X3ECE		; cf17   ce 3e      N>
;
	DB	0,32H					; cf19 .2
	DW	XCEFE		; cf1b   fe ce      ~N
	DW	X34CD		; cf1d   cd 34      M4
	DW	X3ACF		; cf1f   cf 3a      O:
	DW	XCEFE		; cf21   fe ce      ~N
;
	DB	3DH,0F8H,32H				; cf23 =x2
	DW	XCEFE		; cf26   fe ce      ~N
;
	DB	2AH,0FFH				; cf28 *.
	DW	X2BCE		; cf2a   ce 2b      N+
;
	DB	56H,2BH,5EH,22H,0FFH			; cf2c V+^".
	DW	X18CE		; cf31   ce 18      N.
	DW	XCDE9		; cf33   e9 cd      iM
	DB	0DBH					; cf35 [
	DW	XB7CE		; cf36   ce b7      N7
;
	DB	0C0H,0D5H,7BH,1FH,1FH,0E6H,3FH,4FH	; cf38 @U{..f?O
	DB	7AH,3CH,0FEH,60H,3FH,0DEH,0,87H		; cf40 z<~`?^..
	DB	87H,6FH,0CEH,0FCH,95H,67H,79H,86H	; cf48 .oN|.gy.
	DB	23H,66H,6FH,0E5H,7AH,0D6H,1,0CEH	; cf50 #foezV.N
	DB	0,87H,87H,6FH,0CEH,0FCH,95H,67H		; cf58 ...oN|.g
	DB	79H,86H,23H,66H,6FH,0E5H,7AH,87H	; cf60 y.#foez.
	DB	87H,6FH,0CEH,0FCH,95H,67H,79H,86H	; cf68 .oN|.gy.
	DB	23H,66H,6FH,0DDH,0E1H,0FDH,0E1H,7BH	; cf70 #fo]a}a{
	DB	0E6H,3,4FH,6,0FBH,0AH,47H,0EH		; cf78 f.O.{.G.
	DB	3,78H,0A6H,20H,49H,3AH,0FCH,0CEH	; cf80 .x& I:|N
	DB	0A0H,0B6H,77H,24H,3AH,0FDH,0CEH,0A0H	; cf88  6w$:}N 
	DB	0B6H,77H,25H,0DDH,7EH,0,0A0H,20H	; cf90 6w%]~.  
	DB	0DH,0CBH,41H,28H,0BH,0CBH,81H,15H	; cf98 .KA(.K..
	DB	0CDH,67H,0D0H,14H,18H,2,0CBH,0C1H	; cfa0 MgP...KA
	DB	0FDH,7EH,0,0A0H,20H,0DH,0CBH,49H	; cfa8 }~.  .KI
	DB	28H,0BH,0CBH,89H,14H,0CDH,67H,0D0H	; cfb0 (.K..MgP
	DB	15H,18H,2,0CBH,0C9H,1CH,0FAH,0CEH	; cfb8 ...KI.zN
	DB	0CFH,0CBH,8,0CBH,8,30H,0BAH,23H		; cfc0 OK.K.0:#
	DB	0DDH,23H,0FDH,23H,18H,0B3H,0D1H,1DH	; cfc8 ]#}#.3Q.
	DB	0F8H,0CDH,0DBH,0CEH,0B7H,0C0H,7BH,1FH	; cfd0 xM[N7@{.
	DB	1FH,0E6H,3FH,4FH,7AH,3CH,0FEH,60H	; cfd8 .f?Oz<~`
	DB	3FH					; cfe0 ?
;
	SBC	A,0		; cfe1  de 00		^.
	ADD	A,A		; cfe3  87		.
	ADD	A,A		; cfe4  87		.
	LD	L,A		; cfe5  6f		o
	ADC	A,0FCH		; cfe6  ce fc		N|
	SUB	L		; cfe8  95		.
	LD	H,A		; cfe9  67		g
	LD	A,C		; cfea  79		y
	ADD	A,(HL)		; cfeb  86		.
	INC	HL		; cfec  23		#
	LD	H,(HL)		; cfed  66		f
	LD	L,A		; cfee  6f		o
	PUSH	HL		; cfef  e5		e
	LD	A,D		; cff0  7a		z
	SUB	1		; cff1  d6 01		V.
	ADC	A,0		; cff3  ce 00		N.
	ADD	A,A		; cff5  87		.
	ADD	A,A		; cff6  87		.
	LD	L,A		; cff7  6f		o
	ADC	A,0FCH		; cff8  ce fc		N|
	SUB	L		; cffa  95		.
	LD	H,A		; cffb  67		g
	LD	A,C		; cffc  79		y
	ADD	A,(HL)		; cffd  86		.
	INC	HL		; cffe  23		#
	LD	H,(HL)		; cfff  66		f
	LD	L,A		; d000  6f		o
	PUSH	HL		; d001  e5		e
	LD	A,D		; d002  7a		z
	ADD	A,A		; d003  87		.
	ADD	A,A		; d004  87		.
	LD	L,A		; d005  6f		o
	ADC	A,0FCH		; d006  ce fc		N|
	SUB	L		; d008  95		.
	LD	H,A		; d009  67		g
	LD	A,C		; d00a  79		y
	ADD	A,(HL)		; d00b  86		.
	INC	HL		; d00c  23		#
	LD	H,(HL)		; d00d  66		f
	LD	L,A		; d00e  6f		o
	POP	IX		; d00f  dd e1		]a
	POP	IY		; d011  fd e1		}a
	LD	A,E		; d013  7b		{
	AND	3		; d014  e6 03		f.
	LD	C,A		; d016  4f		O
	LD	B,0FBH		; d017  06 fb		.{
	LD	A,(BC)		; d019  0a		.
	LD	B,A		; d01a  47		G
	LD	C,3		; d01b  0e 03		..
XD01D:	LD	A,B		; d01d  78		x
	AND	(HL)		; d01e  a6		&
	RET	NZ		; d01f  c0		@
	LD	A,(XCEFC)	; d020  3a fc ce	:|N
	AND	B		; d023  a0		 
	OR	(HL)		; d024  b6		6
	LD	(HL),A		; d025  77		w
	INC	H		; d026  24		$
	LD	A,(XCEFD)	; d027  3a fd ce	:}N
	AND	B		; d02a  a0		 
	OR	(HL)		; d02b  b6		6
	LD	(HL),A		; d02c  77		w
	DEC	H		; d02d  25		%
	LD	A,(IX+0)	; d02e  dd 7e 00	]~.
	AND	B		; d031  a0		 
	JR	NZ,XD041	; d032  20 0d		 .
	BIT	0,C		; d034  cb 41		KA
	JR	Z,XD043		; d036  28 0b		(.
	RES	0,C		; d038  cb 81		K.
	DEC	D		; d03a  15		.
	CALL	XD067		; d03b  cd 67 d0	MgP
	INC	D		; d03e  14		.
	JR	XD043		; d03f  18 02		..
;
XD041:	SET	0,C		; d041  cb c1		KA
XD043:	LD	A,(IY+0)	; d043  fd 7e 00	}~.
	AND	B		; d046  a0		 
	JR	NZ,XD056	; d047  20 0d		 .
	BIT	1,C		; d049  cb 49		KI
	JR	Z,XD058		; d04b  28 0b		(.
	RES	1,C		; d04d  cb 89		K.
	INC	D		; d04f  14		.
	CALL	XD067		; d050  cd 67 d0	MgP
	DEC	D		; d053  15		.
	JR	XD058		; d054  18 02		..
;
XD056:	SET	1,C		; d056  cb c9		KI
XD058:	DEC	E		; d058  1d		.
	RET	M		; d059  f8		x
	RLC	B		; d05a  cb 00		K.
	RLC	B		; d05c  cb 00		K.
	JR	NC,XD01D	; d05e  30 bd		0=
	DEC	HL		; d060  2b		+
	DEC	IX		; d061  dd 2b		]+
	DEC	IY		; d063  fd 2b		}+
	JR	XD01D		; d065  18 b6		.6
;
XD067:	PUSH	HL		; d067  e5		e
	LD	HL,(XCEFF)	; d068  2a ff ce	*.N
	LD	(HL),E		; d06b  73		s
	INC	HL		; d06c  23		#
	LD	(HL),D		; d06d  72		r
	INC	HL		; d06e  23		#
	LD	(XCEFF),HL	; d06f  22 ff ce	".N
	LD	HL,XCEFE	; d072  21 fe ce	!~N
	INC	(HL)		; d075  34		4
	POP	HL		; d076  e1		a
	RET			; d077  c9		I
;
