; ==========================================================================
; SPARK DIAGONAL MOVEMENT ($D18A-$D279)
; ==========================================================================
;
; Sparks bounce diagonally through empty space.
; Direction encoding (diagonal only): 1=DR, 3=DL, 5=UL, 7=UR
;
; MOVE_SPARK ($D18A):
;   1. Check current cell in shadow grid:
;      - If claimed: spark dies (KILL_SPARK), +50 points
;   2. Compute target position using direction deltas
;   3. Check target cell in shadow grid:
;      - If empty: move there (trail reads as empty in shadow!)
;      - If border: try bounce sequence:
;        a. CW 90° (dir+2) at $D1D9
;        b. CCW 90° (dir-2) at $D208
;        c. 180° (dir+4) at $D237
;        d. All blocked: stay put
;      - If claimed: spark dies
;   4. Set bit 7 of $B0C8 on bounce (sound trigger at $D1D7)
;
; KILL_SPARK ($D267):
;   Sets X position to 0 (inactive marker).
;   Awards 50 points: LD DE,$0032, ADD to base score.
;   Spark is permanently removed for the remainder of the level.
;
; Trail interaction:
;   Shadow grid does NOT contain trail. Sparks see trail as empty and
;   pass through freely. Trail collision is detected separately by
;   the main loop's trail collision check ($C467).
;

;

; --- Move spark ---
MOVE_SPARK:	LD	A,(IX+0)	; d18a  dd 7e 00	]~.
	OR	A		; d18d  b7		7
	RET	Z		; d18e  c8		H
	LD	E,(IX+0)	; d18f  dd 5e 00	]^.
	LD	(IX+2),E	; d192  dd 73 02	]s.
	LD	D,(IX+1)	; d195  dd 56 01	]V.
	LD	(IX+3),D	; d198  dd 72 03	]r.
	CALL	COORDS_TO_ADDR		; d19b  cd 8a ce	M.N
	SET	5,H		; d19e  cb ec		Kl
	CALL	READ_CELL_BMP		; d1a0  cd de ce	M^N
	OR	A		; d1a3  b7		7
	JP	NZ,KILL_SPARK	; d1a4  c2 67 d2	BgR
	LD	A,(IX+4)	; d1a7  dd 7e 04	]~.
	ADD	A,A		; d1aa  87		.
	LD	E,A		; d1ab  5f		_
	LD	D,0		; d1ac  16 00		..
	LD	HL,DIR_TABLE	; d1ae  21 d1 b0	!Q0
	ADD	HL,DE		; d1b1  19		.
	LD	A,(HL)		; d1b2  7e		~
	ADD	A,(IX+0)	; d1b3  dd 86 00	]..
	LD	E,A		; d1b6  5f		_
	INC	HL		; d1b7  23		#
	LD	A,(HL)		; d1b8  7e		~
	ADD	A,(IX+1)	; d1b9  dd 86 01	]..
	LD	D,A		; d1bc  57		W
	CALL	COORDS_TO_ADDR		; d1bd  cd 8a ce	M.N
	SET	5,H		; d1c0  cb ec		Kl
	CALL	READ_CELL_BMP		; d1c2  cd de ce	M^N
	OR	A		; d1c5  b7		7
	JR	NZ,XD1CF	; d1c6  20 07		 .
	LD	(IX+0),E	; d1c8  dd 73 00	]s.
	LD	(IX+1),D	; d1cb  dd 72 01	]r.
	RET			; d1ce  c9		I
;
XD1CF:	CP	3		; d1cf  fe 03		~.
	JP	NZ,KILL_SPARK	; d1d1  c2 67 d2	BgR
	LD	HL,STATE_FLAGS	; d1d4  21 c8 b0	!H0
	SET	7,(HL)		; d1d7  cb fe		K~
	LD	A,(IX+4)	; d1d9  dd 7e 04	]~.
	ADD	A,2		; d1dc  c6 02		F.
	AND	7		; d1de  e6 07		f.
	LD	(IX+4),A	; d1e0  dd 77 04	]w.
	ADD	A,A		; d1e3  87		.
	LD	E,A		; d1e4  5f		_
	LD	D,0		; d1e5  16 00		..
	LD	HL,DIR_TABLE	; d1e7  21 d1 b0	!Q0
	ADD	HL,DE		; d1ea  19		.
	LD	A,(HL)		; d1eb  7e		~
	ADD	A,(IX+0)	; d1ec  dd 86 00	]..
	LD	E,A		; d1ef  5f		_
	INC	HL		; d1f0  23		#
	LD	A,(HL)		; d1f1  7e		~
	ADD	A,(IX+1)	; d1f2  dd 86 01	]..
	LD	D,A		; d1f5  57		W
	CALL	COORDS_TO_ADDR		; d1f6  cd 8a ce	M.N
	SET	5,H		; d1f9  cb ec		Kl
	CALL	READ_CELL_BMP		; d1fb  cd de ce	M^N
	OR	A		; d1fe  b7		7
	JR	NZ,XD208	; d1ff  20 07		 .
	LD	(IX+0),E	; d201  dd 73 00	]s.
	LD	(IX+1),D	; d204  dd 72 01	]r.
	RET			; d207  c9		I
;
XD208:	LD	A,(IX+4)	; d208  dd 7e 04	]~.
	SUB	4		; d20b  d6 04		V.
	AND	7		; d20d  e6 07		f.
	LD	(IX+4),A	; d20f  dd 77 04	]w.
	ADD	A,A		; d212  87		.
	LD	E,A		; d213  5f		_
	LD	D,0		; d214  16 00		..
	LD	HL,DIR_TABLE	; d216  21 d1 b0	!Q0
	ADD	HL,DE		; d219  19		.
	LD	A,(HL)		; d21a  7e		~
	ADD	A,(IX+0)	; d21b  dd 86 00	]..
	LD	E,A		; d21e  5f		_
	INC	HL		; d21f  23		#
	LD	A,(HL)		; d220  7e		~
	ADD	A,(IX+1)	; d221  dd 86 01	]..
	LD	D,A		; d224  57		W
	CALL	COORDS_TO_ADDR		; d225  cd 8a ce	M.N
	SET	5,H		; d228  cb ec		Kl
	CALL	READ_CELL_BMP		; d22a  cd de ce	M^N
	OR	A		; d22d  b7		7
	JR	NZ,XD237	; d22e  20 07		 .
	LD	(IX+0),E	; d230  dd 73 00	]s.
	LD	(IX+1),D	; d233  dd 72 01	]r.
	RET			; d236  c9		I
;
XD237:	LD	A,(IX+4)	; d237  dd 7e 04	]~.
	SUB	2		; d23a  d6 02		V.
	AND	7		; d23c  e6 07		f.
	LD	(IX+4),A	; d23e  dd 77 04	]w.
	ADD	A,A		; d241  87		.
	LD	E,A		; d242  5f		_
	LD	D,0		; d243  16 00		..
	LD	HL,DIR_TABLE	; d245  21 d1 b0	!Q0
	ADD	HL,DE		; d248  19		.
	LD	A,(HL)		; d249  7e		~
	ADD	A,(IX+0)	; d24a  dd 86 00	]..
	LD	E,A		; d24d  5f		_
	INC	HL		; d24e  23		#
	LD	A,(HL)		; d24f  7e		~
	ADD	A,(IX+1)	; d250  dd 86 01	]..
	LD	D,A		; d253  57		W
	CALL	COORDS_TO_ADDR		; d254  cd 8a ce	M.N
	SET	5,H		; d257  cb ec		Kl
	CALL	READ_CELL_BMP		; d259  cd de ce	M^N
	OR	A		; d25c  b7		7
	JR	NZ,XD266	; d25d  20 07		 .
	LD	(IX+0),E	; d25f  dd 73 00	]s.
	LD	(IX+1),D	; d262  dd 72 01	]r.
	RET			; d265  c9		I
;
XD266:	RET			; d266  c9		I
;

; --- Kill spark ---
KILL_SPARK:	LD	(IX+0),0	; d267  dd 36 00 00	]6..
	LD	(IX+2),0	; d26b  dd 36 02 00	]6..
	LD	HL,(BASE_SCORE)	; d26f  2a c3 b0	*C0
	LD	DE,X0032	; d272  11 32 00	.2.
	ADD	HL,DE		; d275  19		.
	LD	(BASE_SCORE),HL	; d276  22 c3 b0	"C0
	RET			; d279  c9		I
;
