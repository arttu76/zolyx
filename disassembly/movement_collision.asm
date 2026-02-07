; ==========================================================================
; MOVEMENT HELPERS & COLLISION DETECTION ($CA43-$CB02)
; ==========================================================================
;
; TRY_HORIZONTAL ($CA43):
;   Reads input bits 3 (right) and 4 (left).
;   If both or neither pressed: return no movement.
;   Computes new X = current ± 1, clamped to [2, 125].
;   Sets direction: 0 (right) or 4 (left).
;   SET 0,(IX+0) marks axis as horizontal.
;
; TRY_VERTICAL ($CA6F):
;   Reads input bits 1 (down) and 2 (up).
;   If both or neither pressed: return no movement.
;   Computes new Y = current ± 1, clamped to [18, 93].
;   Sets direction: 2 (down) or 6 (up).
;   RES 0,(IX+0) marks axis as vertical.
;
; TRAIL CURSOR ACTIVATION ($CA9B):
;   When trail frame counter reaches 72 ($48):
;     - Activate trail cursor at first trail buffer entry
;     - Cursor advances 2 entries per frame, chasing from behind
;     - If cursor catches player (buffer exhausted): set collision
;
; CHECK_COLLISIONS ($CAA9):
;   Checks player position against all active enemies.
;   Collision threshold: |player.X - enemy.X| < 2 AND |player.Y - enemy.Y| < 2
;   Checks: both chasers, then all 8 sparks.
;   Sets bit 0 of $B0C8 on collision.
;

;

; --- Try horizontal ---
TRY_HORIZONTAL:	LD	A,C		; ca43  79		y
	AND	18H		; ca44  e6 18		f.
	RET	Z		; ca46  c8		H
	CP	18H		; ca47  fe 18		~.
	RET	Z		; ca49  c8		H
	LD	A,E		; ca4a  7b		{
	BIT	4,C		; ca4b  cb 61		Ka
	JR	Z,XCA52		; ca4d  28 03		(.
	DEC	A		; ca4f  3d		=
	LD	B,4		; ca50  06 04		..
XCA52:	BIT	3,C		; ca52  cb 59		KY
	JR	Z,XCA59		; ca54  28 03		(.
	INC	A		; ca56  3c		<
	LD	B,0		; ca57  06 00		..
XCA59:	CP	2		; ca59  fe 02		~.
	JR	NC,XCA5F	; ca5b  30 02		0.
	LD	A,2		; ca5d  3e 02		>.
XCA5F:	CP	7EH		; ca5f  fe 7e		~~
	JR	C,XCA65		; ca61  38 02		8.
	LD	A,7DH		; ca63  3e 7d		>}
XCA65:	LD	(IX+1),B	; ca65  dd 70 01	]p.
	SET	0,(IX+0)	; ca68  dd cb 00 c6	]K.F
	CP	E		; ca6c  bb		;
	LD	E,A		; ca6d  5f		_
	RET			; ca6e  c9		I
;

; --- Try vertical ---
TRY_VERTICAL:	LD	A,C		; ca6f  79		y
	AND	6		; ca70  e6 06		f.
	RET	Z		; ca72  c8		H
	CP	6		; ca73  fe 06		~.
	RET	Z		; ca75  c8		H
	LD	A,D		; ca76  7a		z
	BIT	2,C		; ca77  cb 51		KQ
	JR	Z,XCA7E		; ca79  28 03		(.
	DEC	A		; ca7b  3d		=
	LD	B,6		; ca7c  06 06		..
XCA7E:	BIT	1,C		; ca7e  cb 49		KI
	JR	Z,XCA85		; ca80  28 03		(.
	INC	A		; ca82  3c		<
	LD	B,2		; ca83  06 02		..
XCA85:	CP	12H		; ca85  fe 12		~.
	JR	NC,XCA8B	; ca87  30 02		0.
	LD	A,12H		; ca89  3e 12		>.
XCA8B:	CP	5EH		; ca8b  fe 5e		~^
	JR	C,XCA91		; ca8d  38 02		8.
	LD	A,5DH		; ca8f  3e 5d		>]
XCA91:	LD	(IX+1),B	; ca91  dd 70 01	]p.
	RES	0,(IX+0)	; ca94  dd cb 00 86	]K..
	CP	D		; ca98  ba		:
	LD	D,A		; ca99  57		W
	RET			; ca9a  c9		I
;
XCA9B:	LD	HL,X9000	; ca9b  21 00 90	!..
	LD	(XB075),HL	; ca9e  22 75 b0	"u0
	LD	E,(HL)		; caa1  5e		^
	INC	HL		; caa2  23		#
	LD	D,(HL)		; caa3  56		V
	EX	DE,HL		; caa4  eb		k
	LD	(TRAIL_CURSOR),HL	; caa5  22 72 b0	"r0
	RET			; caa8  c9		I
;

; --- Check collisions ---
CHECK_COLLISIONS:	LD	HL,(CHASER1_DATA)	; caa9  2a 28 b0	*(0
	LD	DE,(PLAYER_XY)	; caac  ed 5b 03 b0	m[.0
	LD	A,H		; cab0  7c		|
	SUB	D		; cab1  92		.
	JP	P,XCAB7		; cab2  f2 b7 ca	r7J
	NEG			; cab5  ed 44		mD
XCAB7:	CP	2		; cab7  fe 02		~.
	JR	NC,XCAC8	; cab9  30 0d		0.
	LD	A,L		; cabb  7d		}
	SUB	E		; cabc  93		.
	JP	P,XCAC2		; cabd  f2 c2 ca	rBJ
	NEG			; cac0  ed 44		mD
XCAC2:	CP	2		; cac2  fe 02		~.
	JR	NC,XCAC8	; cac4  30 02		0.
	SCF			; cac6  37		7
	RET			; cac7  c9		I
;
XCAC8:	LD	HL,(CHASER2_DATA)	; cac8  2a 4d b0	*M0
	LD	A,H		; cacb  7c		|
	SUB	D		; cacc  92		.
	JP	P,XCAD2		; cacd  f2 d2 ca	rRJ
	NEG			; cad0  ed 44		mD
XCAD2:	CP	2		; cad2  fe 02		~.
	JR	NC,XCAE3	; cad4  30 0d		0.
	LD	A,L		; cad6  7d		}
	SUB	E		; cad7  93		.
	JP	P,XCADD		; cad8  f2 dd ca	r]J
	NEG			; cadb  ed 44		mD
XCADD:	CP	2		; cadd  fe 02		~.
	JR	NC,XCAE3	; cadf  30 02		0.
	SCF			; cae1  37		7
	RET			; cae2  c9		I
;
XCAE3:	LD	HL,(TRAIL_CURSOR)	; cae3  2a 72 b0	*r0
	LD	A,H		; cae6  7c		|
	SUB	D		; cae7  92		.
	JP	P,XCAED		; cae8  f2 ed ca	rmJ
	NEG			; caeb  ed 44		mD
XCAED:	CP	2		; caed  fe 02		~.
	JR	NC,XCAFE	; caef  30 0d		0.
	LD	A,L		; caf1  7d		}
	SUB	E		; caf2  93		.
	JP	P,XCAF8		; caf3  f2 f8 ca	rxJ
	NEG			; caf6  ed 44		mD
XCAF8:	CP	2		; caf8  fe 02		~.
	JR	NC,XCAFE	; cafa  30 02		0.
	SCF			; cafc  37		7
	RET			; cafd  c9		I
;
XCAFE:	OR	A		; cafe  b7		7
	RET			; caff  c9		I
;
XCB00:	NOP			; cb00  00		.
XCB01:	NOP			; cb01  00		.
XCB02:	NOP			; cb02  00		.
