; ==========================================================================
; PLAYER MOVEMENT & DRAWING ($C7B5-$CA42)
; ==========================================================================
;
; PLAYER_MOVEMENT ($C7B5):
;   Main entry point, called once per frame from main loop.
;   IX points to $B0E1 (player flags).
;   Reads keyboard input, determines movement based on current mode.
;
; Axis Priority System:
;   When multiple directional keys are pressed, prevents diagonal movement.
;   Player flags bit 0 (axis):
;     1 = last move was horizontal -> try vertical first, then horizontal
;     0 = last move was vertical -> try horizontal first, then vertical
;   This creates smooth corner navigation.
;
; NOT-DRAWING MODE ($C7D2):
;   Player walks along the border (value 3).
;   - Target = border: move there
;   - Target = empty AND fire pressed: enter drawing mode
;     * Save current position as drawing start
;     * Set drawing flag (bit 7) and fast mode (bit 4)
;     * Mark target as trail (value 2), record in trail buffer
;   - Otherwise: cannot move
;
; DRAWING MODE ($C89D):
;   Player cuts through empty space leaving a trail.
;   Speed control: if fire held, skip movement on odd frames (half speed).
;   - Target = empty: move there, mark as trail
;   - Target = border: end drawing, set fill-complete flag (bit 6)
;   - Target = trail/claimed: cannot move (no crossing own trail)
;
; FILL DIRECTION ($C921):
;   Determines which side of the trail to flood fill.
;   Case A (turns): sum direction changes; positive=right, negative=left
;   Case B (straight horizontal): Y < 55 -> fill up, Y >= 55 -> fill down
;   Case C (straight vertical): X < 63 -> fill left, X >= 63 -> fill right
;   Then seeds flood fill from each trail point, offset perpendicular.
;   After fill: convert trail to border, clear trail buffer, recalc %.
;

;

; --- Player movement ---
PLAYER_MOVEMENT:	LD	IX,PLAYER_FLAGS	; c7b5  dd 21 e1 b0	]!a0
	CALL	READ_KEYBOARD		; c7b9  cd 68 ba	Mh:
	LD	DE,(PLAYER_XY)	; c7bc  ed 5b 03 b0	m[.0
	BIT	7,(IX+0)	; c7c0  dd cb 00 7e	]K.~
	JP	NZ,XC889	; c7c4  c2 89 c8	B.H
	BIT	0,(IX+0)	; c7c7  dd cb 00 46	]K.F
	JR	NZ,XC82B	; c7cb  20 5e		 ^
	CALL	TRY_HORIZONTAL		; c7cd  cd 43 ca	MCJ
	JR	Z,XC7FA		; c7d0  28 28		((
	CALL	XCEDB		; c7d2  cd db ce	M[N
	CP	3		; c7d5  fe 03		~.
	JP	Z,XC8FA		; c7d7  ca fa c8	JzH
	OR	A		; c7da  b7		7
	JR	NZ,XC7F6	; c7db  20 19		 .
	BIT	0,C		; c7dd  cb 41		KA
	JR	Z,XC7F6		; c7df  28 15		(.
	LD	HL,(PLAYER_XY)	; c7e1  2a 03 b0	*.0
	LD	(DRAW_START),HL	; c7e4  22 e4 b0	"d0
	SET	7,(IX+0)	; c7e7  dd cb 00 fe	]K.~
	RES	5,(IX+0)	; c7eb  dd cb 00 ae	]K..
	SET	4,(IX+0)	; c7ef  dd cb 00 e6	]K.f
	JP	XC8FA		; c7f3  c3 fa c8	CzH
;
XC7F6:	LD	DE,(PLAYER_XY)	; c7f6  ed 5b 03 b0	m[.0
XC7FA:	CALL	TRY_VERTICAL		; c7fa  cd 6f ca	MoJ
	JP	Z,XC8E9		; c7fd  ca e9 c8	JiH
	CALL	XCEDB		; c800  cd db ce	M[N
	CP	3		; c803  fe 03		~.
	JP	Z,XC8FA		; c805  ca fa c8	JzH
	OR	A		; c808  b7		7
	JR	NZ,XC824	; c809  20 19		 .
	BIT	0,C		; c80b  cb 41		KA
	JR	Z,XC824		; c80d  28 15		(.
	SET	7,(IX+0)	; c80f  dd cb 00 fe	]K.~
	SET	5,(IX+0)	; c813  dd cb 00 ee	]K.n
	SET	4,(IX+0)	; c817  dd cb 00 e6	]K.f
	LD	HL,(PLAYER_XY)	; c81b  2a 03 b0	*.0
	LD	(DRAW_START),HL	; c81e  22 e4 b0	"d0
	JP	XC8FA		; c821  c3 fa c8	CzH
;
XC824:	LD	DE,(PLAYER_XY)	; c824  ed 5b 03 b0	m[.0
	JP	XC8E9		; c828  c3 e9 c8	CiH
;
XC82B:	CALL	TRY_VERTICAL		; c82b  cd 6f ca	MoJ
	JR	Z,XC858		; c82e  28 28		((
	CALL	XCEDB		; c830  cd db ce	M[N
	CP	3		; c833  fe 03		~.
	JP	Z,XC8FA		; c835  ca fa c8	JzH
	OR	A		; c838  b7		7
	JR	NZ,XC854	; c839  20 19		 .
	BIT	0,C		; c83b  cb 41		KA
	JR	Z,XC854		; c83d  28 15		(.
	LD	HL,(PLAYER_XY)	; c83f  2a 03 b0	*.0
	LD	(DRAW_START),HL	; c842  22 e4 b0	"d0
	SET	7,(IX+0)	; c845  dd cb 00 fe	]K.~
	RES	5,(IX+0)	; c849  dd cb 00 ae	]K..
	SET	4,(IX+0)	; c84d  dd cb 00 e6	]K.f
	JP	XC8FA		; c851  c3 fa c8	CzH
;
XC854:	LD	DE,(PLAYER_XY)	; c854  ed 5b 03 b0	m[.0
XC858:	CALL	TRY_HORIZONTAL		; c858  cd 43 ca	MCJ
	JP	Z,XC8E9		; c85b  ca e9 c8	JiH
	CALL	XCEDB		; c85e  cd db ce	M[N
	CP	3		; c861  fe 03		~.
	JP	Z,XC8FA		; c863  ca fa c8	JzH
	OR	A		; c866  b7		7
	JR	NZ,XC882	; c867  20 19		 .
	BIT	0,C		; c869  cb 41		KA
	JR	Z,XC882		; c86b  28 15		(.
	SET	7,(IX+0)	; c86d  dd cb 00 fe	]K.~
	SET	5,(IX+0)	; c871  dd cb 00 ee	]K.n
	SET	4,(IX+0)	; c875  dd cb 00 e6	]K.f
	LD	HL,(PLAYER_XY)	; c879  2a 03 b0	*.0
	LD	(DRAW_START),HL	; c87c  22 e4 b0	"d0
	JP	XC8FA		; c87f  c3 fa c8	CzH
;
XC882:	LD	DE,(PLAYER_XY)	; c882  ed 5b 03 b0	m[.0
	JP	XC8E9		; c886  c3 e9 c8	CiH
;
XC889:	BIT	0,C		; c889  cb 41		KA
	JR	NZ,XC891	; c88b  20 04		 .
	RES	4,(IX+0)	; c88d  dd cb 00 a6	]K.&
XC891:	BIT	4,(IX+0)	; c891  dd cb 00 66	]K.f
	JR	Z,XC89D		; c895  28 06		(.
	LD	A,(FRAME_CTR)	; c897  3a c7 b0	:G0
	RRA			; c89a  1f		.
	JR	C,XC8E9		; c89b  38 4c		8L
XC89D:	CALL	TRY_HORIZONTAL		; c89d  cd 43 ca	MCJ
	JR	Z,XC8C3		; c8a0  28 21		(!
	CALL	XCEDB		; c8a2  cd db ce	M[N
	OR	A		; c8a5  b7		7
	JR	Z,XC8FA		; c8a6  28 52		(R
	CP	3		; c8a8  fe 03		~.
	JR	NZ,XC8BF	; c8aa  20 13		 .
	SET	5,H		; c8ac  cb ec		Kl
	CALL	READ_CELL_BMP		; c8ae  cd de ce	M^N
	CP	3		; c8b1  fe 03		~.
	JR	NZ,XC8BF	; c8b3  20 0a		 .
	RES	7,(IX+0)	; c8b5  dd cb 00 be	]K.>
	SET	6,(IX+0)	; c8b9  dd cb 00 f6	]K.v
	JR	XC8FA		; c8bd  18 3b		.;
;
XC8BF:	LD	DE,(PLAYER_XY)	; c8bf  ed 5b 03 b0	m[.0
XC8C3:	CALL	TRY_VERTICAL		; c8c3  cd 6f ca	MoJ
	JR	Z,XC8E9		; c8c6  28 21		(!
	CALL	XCEDB		; c8c8  cd db ce	M[N
	OR	A		; c8cb  b7		7
	JR	Z,XC8FA		; c8cc  28 2c		(,
	CP	3		; c8ce  fe 03		~.
	JR	NZ,XC8E5	; c8d0  20 13		 .
	SET	5,H		; c8d2  cb ec		Kl
	CALL	READ_CELL_BMP		; c8d4  cd de ce	M^N
	CP	3		; c8d7  fe 03		~.
	JR	NZ,XC8E5	; c8d9  20 0a		 .
	RES	7,(IX+0)	; c8db  dd cb 00 be	]K.>
	SET	6,(IX+0)	; c8df  dd cb 00 f6	]K.v
	JR	XC8FA		; c8e3  18 15		..
;
XC8E5:	LD	DE,(PLAYER_XY)	; c8e5  ed 5b 03 b0	m[.0
XC8E9:	BIT	7,(IX+0)	; c8e9  dd cb 00 7e	]K.~
	RET	Z		; c8ed  c8		H
	LD	HL,TRAIL_FRAME_CTR	; c8ee  21 e8 b0	!h0
	INC	(HL)		; c8f1  34		4
	LD	A,(HL)		; c8f2  7e		~
	CP	48H		; c8f3  fe 48		~H
	RET	NZ		; c8f5  c0		@
	CALL	XCA9B		; c8f6  cd 9b ca	M.J
	RET			; c8f9  c9		I
;
XC8FA:	LD	(PLAYER_XY),DE	; c8fa  ed 53 03 b0	mS.0
	BIT	7,(IX+0)	; c8fe  dd cb 00 7e	]K.~
	JR	Z,FILL_DIRECTION		; c902  28 1d		(.
	LD	HL,(TRAIL_WRITE_PTR)	; c904  2a e6 b0	*f0
	LD	(HL),E		; c907  73		s
	INC	HL		; c908  23		#
	LD	(HL),D		; c909  72		r
	INC	HL		; c90a  23		#
	LD	A,(IX+1)	; c90b  dd 7e 01	]~.
	LD	(HL),A		; c90e  77		w
	INC	HL		; c90f  23		#
	LD	(HL),0		; c910  36 00		6.
	LD	(TRAIL_WRITE_PTR),HL	; c912  22 e6 b0	"f0
	LD	HL,TRAIL_FRAME_CTR	; c915  21 e8 b0	!h0
	INC	(HL)		; c918  34		4
	LD	A,(HL)		; c919  7e		~
	CP	48H		; c91a  fe 48		~H
	JR	NZ,FILL_DIRECTION	; c91c  20 03		 .
	CALL	XCA9B		; c91e  cd 9b ca	M.J

; --- Fill direction ---
FILL_DIRECTION:	BIT	6,(IX+0)	; c921  dd cb 00 76	]K.v
	RET	Z		; c925  c8		H
	RES	6,(IX+0)	; c926  dd cb 00 b6	]K.6
	LD	A,2		; c92a  3e 02		>.
	BIT	4,(IX+0)	; c92c  dd cb 00 66	]K.f
	JR	Z,XC934		; c930  28 02		(.
	LD	A,1		; c932  3e 01		>.
XC934:	LD	(FILL_CELL_VAL),A	; c934  32 e3 b0	2c0
	LD	HL,X9000	; c937  21 00 90	!..
XC93A:	LD	A,(HL)		; c93a  7e		~
	OR	A		; c93b  b7		7
	JR	Z,XC956		; c93c  28 18		(.
	LD	E,A		; c93e  5f		_
	INC	HL		; c93f  23		#
	LD	D,(HL)		; c940  56		V
	INC	HL		; c941  23		#
	INC	HL		; c942  23		#
	PUSH	HL		; c943  e5		e
	CALL	COORDS_TO_ADDR		; c944  cd 8a ce	M.N
	LD	A,3		; c947  3e 03		>.
	CALL	XCEB4		; c949  cd b4 ce	M4N
	SET	5,H		; c94c  cb ec		Kl
	LD	A,3		; c94e  3e 03		>.
	CALL	XCEB4		; c950  cd b4 ce	M4N
	POP	HL		; c953  e1		a
	JR	XC93A		; c954  18 e4		.d
;
XC956:	LD	A,(X9002)	; c956  3a 02 90	:..
	LD	C,A		; c959  4f		O
	LD	A,(IX+1)	; c95a  dd 7e 01	]~.
	SUB	C		; c95d  91		.
	JP	Z,XC9CF		; c95e  ca cf c9	JOI
;
	DB	6,0,21H,2,90H,4EH,23H,7EH		; c961 ..!..N#~
	DB	0B7H,28H,1AH,23H,23H,7EH,91H,28H	; c969 7(.##~.(
	DB	0EH					; c971 .
	DW	X06FE		; c972   fe 06      ~.
;
	DB	20H,4,3EH				; c974  .>
	DW	X18FE		; c977   fe 18      ~.
	DB	6					; c979 .
	DW	XFAFE		; c97a   fe fa      ~z
;
	DB	20H,2,3EH,2,80H,47H,4EH,23H		; c97c  .>..GN#
	DB	18H					; c984 .
	DW	XDDE2		; c985   e2 dd      b]
;
	DB	7EH,1,91H,28H,0EH			; c987 ~..(.
	DW	X06FE		; c98c   fe 06      ~.
;
	DB	20H,4,3EH				; c98e  .>
	DW	X18FE		; c991   fe 18      ~.
	DB	6					; c993 .
	DW	XFAFE		; c994   fe fa      ~z
;
	DB	20H,2,3EH,2,80H,47H,17H,9FH		; c996  .>..G..
	DB	87H,87H,0C6H,2,4FH,21H,0,90H		; c99e ..F.O!..
;
XC9A6:	LD	A,(HL)		; c9a6  7e		~
	OR	A		; c9a7  b7		7
	JR	Z,XCA29		; c9a8  28 7f		(.
;
	DB	'_#V#~#'				; c9aa
	DB	0C5H					; c9b0 E
	DW	X81E5		; c9b1   e5 81      e.
;
	DB	87H,0E6H,0FH,21H			; c9b3 .f.!
	DW	DIR_TABLE		; c9b7   d1 b0      Q0
;
	DB	85H,6FH,8CH,95H,67H,7BH,86H,5FH		; c9b9 .o..g{._
	DB	23H,7AH,86H,57H,3AH			; c9c1 #z.W:
	DW	FILL_CELL_VAL		; c9c6   e3 b0      c0
	DW	X01CD		; c9c8   cd 01      M.
	DW	XE1CF		; c9ca   cf e1      Oa
;
	DB	0C1H					; c9cc A
;
	JR	XC9A6		; c9cd  18 d7		.W
;
XC9CF:	DB	79H					; c9cf y
	DW	X02E6		; c9d0   e6 02      f.
;
	DB	20H					; c9d2  
XC9D3:	DB	2BH,3AH,1,90H				; c9d3 +:..
	DW	X37FE		; c9d7   fe 37      ~7
;
	DB	9FH,87H,3CH,4FH				; c9d9 ..<O
;
	LD	A,(X9002)	; c9dd  3a 02 90	:..
	LD	B,A		; c9e0  47		G
	LD	HL,X9000	; c9e1  21 00 90	!..
	LD	A,(HL)		; c9e4  7e		~
;
	DB	'7'+80h					; c9e5 7
	DB	'(A_'					; c9e6
Xc9e9:	DB	'#~'					; c9e9
	DB	81H					; c9eb .
	DW	X2357		; c9ec   57 23      W#
;
	DB	7EH,23H					; c9ee ~#
	DW	X20B8		; c9f0   b8 20      8 
	DW	XC5F1		; c9f2   f1 c5      qE
;
	DB	0E5H,3AH				; c9f4 e:
	DW	FILL_CELL_VAL		; c9f6   e3 b0      c0
	DW	X01CD		; c9f8   cd 01      M.
	DW	XE1CF		; c9fa   cf e1      Oa
;
	DB	0C1H,18H,0E5H,3AH,0,90H			; c9fc A.e:..
	DW	X3FFE		; ca02   fe 3f      ~?
;
	DB	9FH,87H,3CH,4FH,3AH,2,90H,47H		; ca04 ..<O:..G
	DB	21H,0,90H,7EH,0B7H,28H,16H,81H		; ca0c !..~7(..
	DB	'_#V#~#'				; ca14
	DW	X20B8		; ca1a   b8 20      8 
	DW	XC5F2		; ca1c   f2 c5      rE
;
	DB	0E5H,3AH				; ca1e e:
	DW	FILL_CELL_VAL		; ca20   e3 b0      c0
	DW	X01CD		; ca22   cd 01      M.
	DW	XE1CF		; ca24   cf e1      Oa
;
	DB	0C1H,18H,0E6H				; ca26 A.f
;
XCA29:	LD	HL,X9000	; ca29  21 00 90	!..
	LD	(TRAIL_WRITE_PTR),HL	; ca2c  22 e6 b0	"f0
	LD	(HL),0		; ca2f  36 00		6.
	INC	HL		; ca31  23		#
	LD	(HL),0		; ca32  36 00		6.
	CALL	XCE44		; ca34  cd 44 ce	MDN
	CALL	CALC_PERCENTAGE		; ca37  cd 80 c7	M.G
	LD	A,0		; ca3a  3e 00		>.
	LD	(TRAIL_FRAME_CTR),A	; ca3c  32 e8 b0	2h0
XCA3F:	LD	(TRAIL_CURSOR),A	; ca3f  32 72 b0	2r0
	RET			; ca42  c9		I
;
