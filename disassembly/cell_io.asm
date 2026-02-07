; ==========================================================================
; CELL READ/WRITE & BORDER DRAWING ($CE62-$CF00)
; ==========================================================================
;
; These routines handle reading and writing the 2-bit packed game cells.
; Each cell is 2x2 pixels in a 128x128 grid.
;
; DRAW_BORDER_RECT ($CE62):
;   Draws the game field border rectangle at the start of each level.
;
; COORDS_TO_ADDR ($CE8A):
;   Converts game coordinates to bitmap screen address.
;   Input: E=game X, D=game Y
;   Output: HL=bitmap address of top pixel row
;   Algorithm: pixelY = Y*2, pixelX = X*2, compute ZX screen address.
;
; WRITE_CELL_BOTH ($CE9F):
;   Writes cell to BOTH bitmap ($4000) and shadow grid ($6000).
;   Used for: border, claimed, empty.
;
; WRITE_CELL_BMP ($CEAE):
;   Writes cell to bitmap ONLY, not shadow.
;   Used for: trail cells and spark rendering.
;   This is how trail is "invisible" to sparks/chasers reading shadow.
;
; READ_CELL_BMP ($CEDE):
;   Reads cell value from bitmap. Returns visual state (includes trail).
;
; READ_CELL_SHADOW ($CEF3):
;   Reads cell value from shadow grid. Trail appears as empty.
;   Used by spark movement and chaser wall-following.
;
; Cell encoding (2-bit values):
;   0 = empty   (pattern $00/$00)
;   1 = claimed  (pattern $55/$00 — checkerboard)
;   2 = trail   (pattern $AA/$55 — dense checker)
;   3 = border  (pattern $FF/$FF — solid)
;
; Mask table at $FB00: $C0, $30, $0C, $03 (cell position within byte)
;

;

; --- Draw border rect ---
DRAW_BORDER_RECT:	LD	DE,X1202	; ce62  11 02 12	...
XCE65:	CALL	WRITE_CELL_BOTH		; ce65  cd 9f ce	M.N
	INC	E		; ce68  1c		.
	LD	A,E		; ce69  7b		{
	CP	7DH		; ce6a  fe 7d		~}
	JR	NZ,XCE65	; ce6c  20 f7		 w
XCE6E:	CALL	WRITE_CELL_BOTH		; ce6e  cd 9f ce	M.N
	INC	D		; ce71  14		.
	LD	A,D		; ce72  7a		z
	CP	5DH		; ce73  fe 5d		~]
	JR	NZ,XCE6E	; ce75  20 f7		 w
XCE77:	CALL	WRITE_CELL_BOTH		; ce77  cd 9f ce	M.N
	DEC	E		; ce7a  1d		.
	LD	A,E		; ce7b  7b		{
	CP	2		; ce7c  fe 02		~.
	JR	NZ,XCE77	; ce7e  20 f7		 w
XCE80:	CALL	WRITE_CELL_BOTH		; ce80  cd 9f ce	M.N
	DEC	D		; ce83  15		.
	LD	A,D		; ce84  7a		z
	CP	12H		; ce85  fe 12		~.
	JR	NZ,XCE80	; ce87  20 f7		 w
	RET			; ce89  c9		I
;

; --- Coords to addr ---
COORDS_TO_ADDR:	EX	AF,AF'		; ce8a  08		.
	LD	A,D		; ce8b  7a		z
	ADD	A,A		; ce8c  87		.
	ADD	A,A		; ce8d  87		.
	LD	L,A		; ce8e  6f		o
	ADC	A,0FCH		; ce8f  ce fc		N|
	SUB	L		; ce91  95		.
	LD	H,A		; ce92  67		g
	LD	A,E		; ce93  7b		{
	RRA			; ce94  1f		.
	RRA			; ce95  1f		.
	AND	3FH		; ce96  e6 3f		f?
	ADD	A,(HL)		; ce98  86		.
	INC	HL		; ce99  23		#
	LD	H,(HL)		; ce9a  66		f
	LD	L,A		; ce9b  6f		o
	LD	A,E		; ce9c  7b		{
	EX	AF,AF'		; ce9d  08		.
	RET			; ce9e  c9		I
;

; --- Write cell both ---
WRITE_CELL_BOTH:	PUSH	DE		; ce9f  d5		U
	LD	A,3		; cea0  3e 03		>.
	CALL	XCEB1		; cea2  cd b1 ce	M1N
	SET	5,H		; cea5  cb ec		Kl
	LD	A,3		; cea7  3e 03		>.
	CALL	XCEB4		; cea9  cd b4 ce	M4N
	POP	DE		; ceac  d1		Q
	RET			; cead  c9		I
;

; --- Write cell bitmap ---
WRITE_CELL_BMP:	INC	E		; ceae  1c		.
	DEC	E		; ceaf  1d		.
	RET	Z		; ceb0  c8		H
XCEB1:	CALL	COORDS_TO_ADDR		; ceb1  cd 8a ce	M.N
XCEB4:	ADD	A,A		; ceb4  87		.
	LD	BC,CELL_PATTERNS	; ceb5  01 c9 b0	.I0
	ADD	A,C		; ceb8  81		.
	LD	C,A		; ceb9  4f		O
	ADC	A,B		; ceba  88		.
	SUB	C		; cebb  91		.
	LD	B,A		; cebc  47		G
	LD	A,E		; cebd  7b		{
	AND	3		; cebe  e6 03		f.
	LD	E,A		; cec0  5f		_
	LD	D,0FBH		; cec1  16 fb		.{
	LD	A,(DE)		; cec3  1a		.
	CPL			; cec4  2f		/
	AND	(HL)		; cec5  a6		&
	LD	(HL),A		; cec6  77		w
	LD	A,(BC)		; cec7  0a		.
	EX	DE,HL		; cec8  eb		k
	AND	(HL)		; cec9  a6		&
	EX	DE,HL		; ceca  eb		k
	OR	(HL)		; cecb  b6		6
	LD	(HL),A		; cecc  77		w
	INC	BC		; cecd  03		.
	INC	H		; cece  24		$
	LD	A,(DE)		; cecf  1a		.
	CPL			; ced0  2f		/
	AND	(HL)		; ced1  a6		&
	LD	(HL),A		; ced2  77		w
	LD	A,(BC)		; ced3  0a		.
	EX	DE,HL		; ced4  eb		k
	AND	(HL)		; ced5  a6		&
	EX	DE,HL		; ced6  eb		k
	OR	(HL)		; ced7  b6		6
	LD	(HL),A		; ced8  77		w
	DEC	H		; ced9  25		%
	RET			; ceda  c9		I
;
XCEDB:	CALL	COORDS_TO_ADDR		; cedb  cd 8a ce	M.N

; --- Read cell bitmap ---
READ_CELL_BMP:	LD	B,(HL)		; cede  46		F
	LD	A,E		; cedf  7b		{
	AND	3		; cee0  e6 03		f.
	NEG			; cee2  ed 44		mD
	ADD	A,3		; cee4  c6 03		F.
	JR	Z,XCEEF		; cee6  28 07		(.
XCEE8:	SRL	B		; cee8  cb 38		K8
	SRL	B		; ceea  cb 38		K8
	DEC	A		; ceec  3d		=
	JR	NZ,XCEE8	; ceed  20 f9		 y
XCEEF:	LD	A,B		; ceef  78		x
	AND	3		; cef0  e6 03		f.
	RET			; cef2  c9		I
;

; --- Read cell shadow ---
READ_CELL_SHADOW:
	DB	0CDH,8AH				; cef3 M.
	DW	XCBCE		; cef5   ce cb      NK
	DW	XCDEC		; cef7   ec cd      lM
	DB	0DEH					; cef9 ^
	DW	XC9CE		; cefa   ce c9      NI
;
XCEFC:	DB	0					; cefc .
;
XCEFD:	NOP			; cefd  00		.
XCEFE:	NOP			; cefe  00		.
XCEFF:	NOP			; ceff  00		.
;
	ORG	0CF01H
;
