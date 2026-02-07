; ==========================================================================
; TRAIL CURSOR & GAME INITIALIZATION ($CBFE-$CE61)
; ==========================================================================
;
; MOVE_TRAIL_CURSOR ($CBFE):
;   Advances the trail cursor along the trail buffer.
;   Moves 2 entries per frame (6 bytes), chasing the player.
;   If cursor catches up (buffer exhausted): set collision flag.
;
; NEW_GAME_INIT ($CC40):
;   Resets all game state for a new game:
;     level = 0, score = 0, lives = 3
;   Falls through to LEVEL_INIT.
;
; LEVEL_INIT ($CC5A):
;   Sets up a new level:
;     1. Set timer to 176 ($B0)
;     2. Clear game state flags
;     3. Clear screen memory and shadow grid
;     4. Load field color from LEVEL_COLORS[$CDAB + level & 0x0F]
;     5. Draw border rectangle ($CE62)
;     6. Set player to X=2, Y=18 (top-left corner)
;     7. Init chasers from $CD92 positions, masked by $CD9B activation
;     8. Init sparks from $CD72 positions + random offset, masked by $CD82
;     9. Calculate initial percentage (border cells only = 0%)
;
; SPARK_INIT ($CCBE):
;   For each spark (0-7): if activation mask bit is set, spawn at
;   base position + random offset (X += rand()&7, Y += (rand()&7)*2).
;   Initial direction: (rand() & 3) * 2 + 1 = random diagonal.
;
; CHASER_INIT ($CD2C):
;   Chaser 1: X=64, Y=18, dir=0 (right) — top border
;   Chaser 2: X=64, Y=93, dir=4 (left) — bottom border
;
; DATA TABLES:
;   $CD72 (16 bytes): Spark base positions (8 sparks x 2: X, Y)
;   $CD82 (16 bytes): Spark activation masks per level
;   $CD92 (9 bytes):  Chaser initial positions
;   $CD9B (16 bytes): Chaser activation masks per level
;   $CDAB (16 bytes): Level color table (attribute bytes)
;     Raw: 70 68 58 60 68 78 68 70 60 58 78 68 70 50 58 68
;     All BRIGHT=1, INK=0. PAPER encodes the field color.
;

;

; --- Move trail cursor ---
MOVE_TRAIL_CURSOR:	LD	A,(IX+0)	; cbfe  dd 7e 00	]~.
	OR	A		; cc01  b7		7
	RET	Z		; cc02  c8		H
	LD	HL,STATE_FLAGS	; cc03  21 c8 b0	!H0
	SET	6,(HL)		; cc06  cb f6		Kv
	LD	L,(IX+3)	; cc08  dd 6e 03	]n.
	LD	H,(IX+4)	; cc0b  dd 66 04	]f.
	INC	HL		; cc0e  23		#
	INC	HL		; cc0f  23		#
	INC	HL		; cc10  23		#
	LD	A,(HL)		; cc11  7e		~
	OR	A		; cc12  b7		7
	JR	Z,XCC1C		; cc13  28 07		(.
	INC	HL		; cc15  23		#
	INC	HL		; cc16  23		#
	INC	HL		; cc17  23		#
	LD	A,(HL)		; cc18  7e		~
	OR	A		; cc19  b7		7
	JR	NZ,XCC22	; cc1a  20 06		 .
XCC1C:	LD	HL,STATE_FLAGS	; cc1c  21 c8 b0	!H0
	SET	0,(HL)		; cc1f  cb c6		KF
	RET			; cc21  c9		I
;
XCC22:	LD	(IX+0),A	; cc22  dd 77 00	]w.
	INC	HL		; cc25  23		#
	LD	A,(HL)		; cc26  7e		~
	LD	(IX+1),A	; cc27  dd 77 01	]w.
	DEC	HL		; cc2a  2b		+
	LD	(IX+3),L	; cc2b  dd 75 03	]u.
	LD	(IX+4),H	; cc2e  dd 74 04	]t.
	RET			; cc31  c9		I
;
	DB	0DDH,7EH,2,3CH				; cc32 ]~.<
	DW	X07FE		; cc36   fe 07      ~.
;
	DB	38H,2,3EH,3,0DDH,77H,2			; cc38 8.>.]w.
	DW	X3EC9		; cc3f   c9 3e      I>
;
	DB	0,32H,0C1H,0B0H,21H,0,0,22H		; cc41 .2A0!.."
	DW	BASE_SCORE		; cc49   c3 b0      C0
;
	DB	3EH,3,32H,0C2H,0B0H			; cc4b >.2B0
	DW	X7ACD		; cc50   cd 7a      Mz
	DW	XCDD2		; cc52   d2 cd      RM
	DB	95H					; cc54 .
	DW	XCDD2		; cc55   d2 cd      RM
	DW	UPDATE_LIVES_DISPLAY		; cc57   b0 d2      0R
;
	DB	0C9H					; cc59 I
;

; --- Level init ---
LEVEL_INIT:	LD	A,0B0H		; cc5a  3e b0		>0
	LD	(GAME_TIMER),A	; cc5c  32 c0 b0	2@0
	LD	A,0		; cc5f  3e 00		>.
	LD	(STATE_FLAGS),A	; cc61  32 c8 b0	2H0
	LD	(TRAIL_FRAME_CTR),A	; cc64  32 e8 b0	2h0
	CALL	XCE19		; cc67  cd 19 ce	M.N
	LD	A,(LEVEL_NUM)	; cc6a  3a c1 b0	:A0
	AND	0FH		; cc6d  e6 0f		f.
	LD	E,A		; cc6f  5f		_
	LD	D,0		; cc70  16 00		..
	LD	HL,LEVEL_COLORS	; cc72  21 ab cd	!+M
	ADD	HL,DE		; cc75  19		.
	LD	A,(HL)		; cc76  7e		~
	CALL	PROCESS_ATTR_COLOR		; cc77  cd 07 bc	M.<
	LD	HL,XB0EF	; cc7a  21 ef b0	!o0
	BIT	7,(HL)		; cc7d  cb 7e		K~
	CALL	NZ,XCD5C	; cc7f  c4 5c cd	D\M
	LD	(FIELD_COLOR),A	; cc82  32 ec b0	2l0
	LD	BC,X0400	; cc85  01 00 04	...
	LD	DE,X1420	; cc88  11 20 14	. .
	CALL	FILL_ATTR_RECT		; cc8b  cd f6 ba	Mv:
	CALL	DRAW_BORDER_RECT		; cc8e  cd 62 ce	MbN
	CALL	CALC_PERCENTAGE		; cc91  cd 80 c7	M.G
	CALL	UPDATE_LEVEL_DISPLAY		; cc94  cd 95 d2	M.R
XCC97:	CALL	UPDATE_TIMER_BAR		; cc97  cd c1 d2	MAR
	HALT			; cc9a  76		v
;
	JR	C,XCC97		; cc9b  38 fa		8z
	LD	HL,X1202	; cc9d  21 02 12	!..
	LD	(PLAYER_XY),HL	; cca0  22 03 b0	".0
	LD	A,0		; cca3  3e 00		>.
	LD	(PLAYER_FLAGS),A	; cca5  32 e1 b0	2a0
	LD	HL,X0000	; cca8  21 00 00	!..
	LD	(TRAIL_CURSOR),HL	; ccab  22 72 b0	"r0
	LD	HL,SPARK_ARRAY	; ccae  21 97 b0	!.0
	LD	B,8		; ccb1  06 08		..
XCCB3:	PUSH	BC		; ccb3  c5		E
	LD	B,4		; ccb4  06 04		..
XCCB6:	LD	(HL),0		; ccb6  36 00		6.
	INC	HL		; ccb8  23		#
	DJNZ	XCCB6		; ccb9  10 fb		.{
	CALL	PRNG		; ccbb  cd e4 d3	MdS

; --- Spark init ---
SPARK_INIT:
	AND	3		; ccbe  e6 03		f.
	ADD	A,A		; ccc0  87		.
	ADD	A,1		; ccc1  c6 01		F.
	LD	(HL),A		; ccc3  77		w
	INC	HL		; ccc4  23		#
	POP	BC		; ccc5  c1		A
	DJNZ	XCCB3		; ccc6  10 eb		.k
	LD	A,(LEVEL_NUM)	; ccc8  3a c1 b0	:A0
	CP	10H		; cccb  fe 10		~.
	JR	C,XCCD1		; cccd  38 02		8.
	LD	A,0FH		; cccf  3e 0f		>.
XCCD1:	LD	E,A		; ccd1  5f		_
	LD	D,0		; ccd2  16 00		..
	LD	HL,SPARK_ACTIVATION	; ccd4  21 82 cd	!.M
	ADD	HL,DE		; ccd7  19		.
	LD	C,(HL)		; ccd8  4e		N
	LD	B,8		; ccd9  06 08		..
	LD	DE,SPARK_POSITIONS	; ccdb  11 72 cd	.rM
	LD	HL,SPARK_ARRAY	; ccde  21 97 b0	!.0
XCCE1:	RLC	C		; cce1  cb 01		K.
	JR	C,XCCEE		; cce3  38 09		8.
	INC	HL		; cce5  23		#
	INC	HL		; cce6  23		#
	INC	HL		; cce7  23		#
	INC	HL		; cce8  23		#
	INC	HL		; cce9  23		#
	INC	DE		; ccea  13		.
	INC	DE		; cceb  13		.
	JR	XCD0B		; ccec  18 1d		..
;
XCCEE:	CALL	PRNG		; ccee  cd e4 d3	MdS
	AND	7		; ccf1  e6 07		f.
	EX	DE,HL		; ccf3  eb		k
	ADD	A,(HL)		; ccf4  86		.
	EX	DE,HL		; ccf5  eb		k
;
	DB	13H					; ccf6 .
	DB	'w##w+'					; ccf7
	DW	XE4CD		; ccfc   cd e4      Md
	DW	XE6D3		; ccfe   d3 e6      Sf
;
;
	RLCA			; cd00  07		.
	EX	DE,HL		; cd01  eb		k
	ADD	A,(HL)		; cd02  86		.
	EX	DE,HL		; cd03  eb		k
	INC	DE		; cd04  13		.
;
	DB	'w##w##'				; cd05
;
XCD0B:	DJNZ	XCCE1		; cd0b  10 d4		.T
	LD	A,(LEVEL_NUM)	; cd0d  3a c1 b0	:A0
	CP	10H		; cd10  fe 10		~.
	JR	C,XCD16		; cd12  38 02		8.
	LD	A,0FH		; cd14  3e 0f		>.
XCD16:	LD	E,A		; cd16  5f		_
	LD	D,0		; cd17  16 00		..
	LD	HL,CHASER_ACTIVATION	; cd19  21 9b cd	!.M
	ADD	HL,DE		; cd1c  19		.
	LD	C,(HL)		; cd1d  4e		N
	LD	HL,XB0F1	; cd1e  21 f1 b0	!q0
	BIT	7,(HL)		; cd21  cb 7e		K~
	JR	NZ,XCD27	; cd23  20 02		 .
	LD	C,0		; cd25  0e 00		..
XCD27:	LD	B,2		; cd27  06 02		..
	LD	HL,CHASER1_DATA	; cd29  21 28 b0	!(0

; --- Chaser init ---
CHASER_INIT:
	LD	DE,CHASER_POSITIONS	; cd2c  11 92 cd	..M
XCD2F:	RLC	C		; cd2f  cb 01		K.
	JR	C,XCD3C		; cd31  38 09		8.
	LD	(HL),0		; cd33  36 00		6.
	LD	A,25H		; cd35  3e 25		>%
	INC	DE		; cd37  13		.
	INC	DE		; cd38  13		.
	INC	DE		; cd39  13		.
	JR	XCD4B		; cd3a  18 0f		..
;
XCD3C:	LD	A,(DE)		; cd3c  1a		.
	LD	(HL),A		; cd3d  77		w
	INC	HL		; cd3e  23		#
	INC	DE		; cd3f  13		.
	LD	A,(DE)		; cd40  1a		.
	LD	(HL),A		; cd41  77		w
	INC	HL		; cd42  23		#
	INC	HL		; cd43  23		#
	INC	DE		; cd44  13		.
	LD	A,(DE)		; cd45  1a		.
	LD	(HL),A		; cd46  77		w
	INC	HL		; cd47  23		#
	INC	DE		; cd48  13		.
	LD	A,21H		; cd49  3e 21		>!
XCD4B:	ADD	A,L		; cd4b  85		.
	LD	L,A		; cd4c  6f		o
	ADC	A,H		; cd4d  8c		.
	SUB	L		; cd4e  95		.
	LD	H,A		; cd4f  67		g
	DJNZ	XCD2F		; cd50  10 dd		.]
	LD	BC,X000E	; cd52  01 0e 00	...
	LD	DE,X0208	; cd55  11 08 02	...
	CALL	XD3F3		; cd58  cd f3 d3	MsS
	RET			; cd5b  c9		I
;
XCD5C:	PUSH	HL		; cd5c  e5		e
	LD	L,A		; cd5d  6f		o
	AND	0C0H		; cd5e  e6 c0		f@
	LD	H,A		; cd60  67		g
	LD	A,L		; cd61  7d		}
	RRA			; cd62  1f		.
	RRA			; cd63  1f		.
	RRA			; cd64  1f		.
	AND	7		; cd65  e6 07		f.
	OR	H		; cd67  b4		4
	LD	H,A		; cd68  67		g
	LD	A,L		; cd69  7d		}
	RLA			; cd6a  17		.
	RLA			; cd6b  17		.
	RLA			; cd6c  17		.
	AND	38H		; cd6d  e6 38		f8
	OR	H		; cd6f  b4		4
	POP	HL		; cd70  e1		a
	RET			; cd71  c9		I
;

; --- Spark positions ---
SPARK_POSITIONS:	DB	1DH,21H,3DH,21H,5DH,21H			; cd72 .!=!]!
;
	DEC	E		; cd78  1d		.
	DEC	(HL)		; cd79  35		5
	LD	E,L		; cd7a  5d		]
	DEC	(HL)		; cd7b  35		5
	DEC	E		; cd7c  1d		.
;
	DB	'I=I]I'					; cd7d

; --- Spark activation ---
Xcd82:	DB	'@'					; cd82
	DB	18H,0A2H,5AH				; cd83 ."Z
;
	CP	D		; cd86  ba		:
	CP	L		; cd87  bd		=
	DB	0FDH,0FFH	; cd88  fd ff		}.
;
	ORG	0CD92H
;

; --- Chaser positions ---
CHASER_POSITIONS:	DB	40H,12H,0,40H,5DH,4,0			; cd92 @..@]..
;
	ORG	0CD9BH
;

; --- Chaser activation ---
CHASER_ACTIVATION:	ADD	A,B		; cd9b  80		.
	ADD	A,B		; cd9c  80		.
	ADD	A,B		; cd9d  80		.
	ADD	A,B		; cd9e  80		.
	ADD	A,B		; cd9f  80		.
	ADD	A,B		; cda0  80		.
	RET	NZ		; cda1  c0		@
	RET	NZ		; cda2  c0		@
	RET	NZ		; cda3  c0		@
	RET	NZ		; cda4  c0		@
	RET	NZ		; cda5  c0		@
	RET	NZ		; cda6  c0		@
	RET	NZ		; cda7  c0		@
	RET	NZ		; cda8  c0		@
	RET	NZ		; cda9  c0		@
	RET	NZ		; cdaa  c0		@
;

; --- Level colors ---
Xcdab:	DB	'phX`hx'				; cdab
Xcdb1:	DB	'h'					; cdb1
Xcdb2:	DB	'p`'					; cdb2
Xcdb4:	DB	'Xx'					; cdb4
Xcdb6:	DB	'hpPXhp'				; cdb6
;
XCDBC:	LD	IX,XFC40	; cdbc  dd 21 40 fc	]!@|
	LD	B,50H		; cdc0  06 50		.P
	LD	DE,X0000	; cdc2  11 00 00	...
XCDC5:	PUSH	BC		; cdc5  c5		E
	LD	L,(IX+0)	; cdc6  dd 6e 00	]n.
XCDC9:	LD	H,(IX+1)	; cdc9  dd 66 01	]f.
	LD	B,20H		; cdcc  06 20		. 
	LD	C,0C0H		; cdce  0e c0		.@
XCDD0:	LD	A,(HL)		; cdd0  7e		~
	AND	C		; cdd1  a1		!
XCDD2:	JR	Z,XCDD5		; cdd2  28 01		(.
XCDD4:	INC	DE		; cdd4  13		.
XCDD5:	RRC	C		; cdd5  cb 09		K.
	RRC	C		; cdd7  cb 09		K.
	JR	NC,XCDD0	; cdd9  30 f5		0u
	INC	L		; cddb  2c		,
	DJNZ	XCDD0		; cddc  10 f2		.r
	LD	BC,X0004	; cdde  01 04 00	...
	ADD	IX,BC		; cde1  dd 09		].
	POP	BC		; cde3  c1		A
	DJNZ	XCDC5		; cde4  10 df		._
	EX	DE,HL		; cde6  eb		k
	RET			; cde7  c9		I
;
XCDE8:	LD	IX,XFC40	; cde8  dd 21 40 fc	]!@|
XCDEC:	LD	B,50H		; cdec  06 50		.P
	LD	DE,X0000	; cdee  11 00 00	...
XCDF1:	PUSH	BC		; cdf1  c5		E
	LD	L,(IX+0)	; cdf2  dd 6e 00	]n.
	LD	H,(IX+1)	; cdf5  dd 66 01	]f.
	LD	B,20H		; cdf8  06 20		. 
	LD	C,0C0H		; cdfa  0e c0		.@
XCDFC:	LD	A,(HL)		; cdfc  7e		~
	AND	C		; cdfd  a1		!
	JR	Z,XCE06		; cdfe  28 06		(.
	XOR	55H		; ce00  ee 55		nU
	AND	C		; ce02  a1		!
	JR	NZ,XCE06	; ce03  20 01		 .
	INC	DE		; ce05  13		.
XCE06:	RRC	C		; ce06  cb 09		K.
	RRC	C		; ce08  cb 09		K.
XCE0A:	JR	NC,XCDFC	; ce0a  30 f0		0p
	INC	L		; ce0c  2c		,
	DJNZ	XCDFC		; ce0d  10 ed		.m
	LD	BC,X0004	; ce0f  01 04 00	...
	ADD	IX,BC		; ce12  dd 09		].
	POP	BC		; ce14  c1		A
	DJNZ	XCDF1		; ce15  10 da		.Z
	EX	DE,HL		; ce17  eb		k
	RET			; ce18  c9		I
;
XCE19:	LD	IX,XFC40	; ce19  dd 21 40 fc	]!@|
	LD	B,0A0H		; ce1d  06 a0		. 
XCE1F:	PUSH	BC		; ce1f  c5		E
	LD	L,(IX+0)	; ce20  dd 6e 00	]n.
	LD	H,(IX+1)	; ce23  dd 66 01	]f.
	LD	B,20H		; ce26  06 20		. 
XCE28:	LD	(HL),0		; ce28  36 00		6.
	INC	L		; ce2a  2c		,
	DJNZ	XCE28		; ce2b  10 fb		.{
	LD	L,(IX+0)	; ce2d  dd 6e 00	]n.
	LD	H,(IX+1)	; ce30  dd 66 01	]f.
	SET	5,H		; ce33  cb ec		Kl
	LD	B,20H		; ce35  06 20		. 
XCE37:	LD	(HL),0		; ce37  36 00		6.
	INC	L		; ce39  2c		,
	DJNZ	XCE37		; ce3a  10 fb		.{
	INC	IX		; ce3c  dd 23		]#
	INC	IX		; ce3e  dd 23		]#
	POP	BC		; ce40  c1		A
	DJNZ	XCE1F		; ce41  10 dc		.\
	RET			; ce43  c9		I
;
XCE44:	LD	IX,XFC40	; ce44  dd 21 40 fc	]!@|
	LD	B,0A0H		; ce48  06 a0		. 
XCE4A:	LD	L,(IX+0)	; ce4a  dd 6e 00	]n.
	LD	H,(IX+1)	; ce4d  dd 66 01	]f.
XCE50:	LD	E,L		; ce50  5d		]
	LD	D,H		; ce51  54		T
	SET	5,D		; ce52  cb ea		Kj
	PUSH	BC		; ce54  c5		E
	LD	BC,X0020	; ce55  01 20 00	. .
	LDIR			; ce58  ed b0		m0
	POP	BC		; ce5a  c1		A
	INC	IX		; ce5b  dd 23		]#
	INC	IX		; ce5d  dd 23		]#
	DJNZ	XCE4A		; ce5f  10 e9		.i
	RET			; ce61  c9		I
;
