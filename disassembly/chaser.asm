; ==========================================================================
; CHASER WALL-FOLLOWING MOVEMENT ($CB03-$CBFD)
; ==========================================================================
;
; Chasers patrol the border and claimed edges using a wall-following
; algorithm. They NEVER enter empty space.
;
; Data structure (37 bytes per chaser, pointed to by IX):
;   IX+0: X position
;   IX+1: Y position
;   IX+2: (unused / old position for sprite restore)
;   IX+3: Direction (0, 2, 4, or 6 — cardinal only)
;   IX+4: Wall-following side flag (bit 0: 0=wall on left, 1=wall on right)
;   IX+5..IX+36: Sprite background save buffer (32 bytes)
;
; Algorithm per frame:
;
; Step 1 — Look-ahead ($CB03-$CB72):
;   Compute three positions relative to current direction:
;     Forward-Left  = (dir - 2) & 7
;     Forward       = dir
;     Forward-Right = (dir + 2) & 7
;   Read cell values from grid for each. Results stored at
;   self-modifying addresses $CB00/$CB01/$CB02.
;
; Step 2 — Update wall-side flag ($CB75-$CB8C):
;   If cellLeft is border: wallSide = 1 (wall now on right)
;   If cellRight is empty: wallSide = 0 (wall now on left)
;
; Step 3 — Determine turn ($CB96-$CBDD):
;   wallSide=0 (wall on left, prefer right):
;     cellRight=BORDER -> turn right (+2)
;     cellFwd=BORDER   -> go straight (0)
;     cellLeft=BORDER  -> turn left (-2)
;     all non-border   -> U-turn (-4)
;   wallSide=1 (wall on right, prefer left):
;     cellLeft=BORDER  -> turn left (-2)
;     cellFwd=BORDER   -> go straight (0)
;     cellRight=BORDER -> turn right (+2)
;     all non-border   -> U-turn (-4)
;
; Step 4 — Apply and move ($CBDE-$CBFA):
;   new_dir = (current_dir + turn) & 7
;   Move one cell in new direction.
;


; --- Move chaser ---
MOVE_CHASER:	LD	A,(IX+0)	; cb03  dd 7e 00	]~.
	OR	A		; cb06  b7		7
	RET	Z		; cb07  c8		H
	LD	A,(IX+3)	; cb08  dd 7e 03	]~.
	ADD	A,0FEH		; cb0b  c6 fe		F~
	AND	7		; cb0d  e6 07		f.
	ADD	A,A		; cb0f  87		.
	LD	E,A		; cb10  5f		_
	LD	D,0		; cb11  16 00		..
	LD	HL,DIR_TABLE	; cb13  21 d1 b0	!Q0
	ADD	HL,DE		; cb16  19		.
	LD	A,(IX+0)	; cb17  dd 7e 00	]~.
	ADD	A,(HL)		; cb1a  86		.
	LD	E,A		; cb1b  5f		_
	INC	HL		; cb1c  23		#
	LD	A,(IX+1)	; cb1d  dd 7e 01	]~.
	ADD	A,(HL)		; cb20  86		.
	LD	D,A		; cb21  57		W
	CALL	COORDS_TO_ADDR		; cb22  cd 8a ce	M.N
	SET	5,H		; cb25  cb ec		Kl
	CALL	READ_CELL_BMP		; cb27  cd de ce	M^N
	LD	(XCB00),A	; cb2a  32 00 cb	2.K
	LD	A,(IX+3)	; cb2d  dd 7e 03	]~.
	AND	7		; cb30  e6 07		f.
	ADD	A,A		; cb32  87		.
	LD	E,A		; cb33  5f		_
	LD	D,0		; cb34  16 00		..
	LD	HL,DIR_TABLE	; cb36  21 d1 b0	!Q0
	ADD	HL,DE		; cb39  19		.
	LD	A,(IX+0)	; cb3a  dd 7e 00	]~.
	ADD	A,(HL)		; cb3d  86		.
	LD	E,A		; cb3e  5f		_
	INC	HL		; cb3f  23		#
	LD	A,(IX+1)	; cb40  dd 7e 01	]~.
	ADD	A,(HL)		; cb43  86		.
	LD	D,A		; cb44  57		W
	CALL	COORDS_TO_ADDR		; cb45  cd 8a ce	M.N
	SET	5,H		; cb48  cb ec		Kl
	CALL	READ_CELL_BMP		; cb4a  cd de ce	M^N
	LD	(XCB01),A	; cb4d  32 01 cb	2.K
	LD	A,(IX+3)	; cb50  dd 7e 03	]~.
	ADD	A,2		; cb53  c6 02		F.
	AND	7		; cb55  e6 07		f.
	ADD	A,A		; cb57  87		.
	LD	E,A		; cb58  5f		_
	LD	D,0		; cb59  16 00		..
	LD	HL,DIR_TABLE	; cb5b  21 d1 b0	!Q0
	ADD	HL,DE		; cb5e  19		.
	LD	A,(IX+0)	; cb5f  dd 7e 00	]~.
	ADD	A,(HL)		; cb62  86		.
	LD	E,A		; cb63  5f		_
	INC	HL		; cb64  23		#
	LD	A,(IX+1)	; cb65  dd 7e 01	]~.
	ADD	A,(HL)		; cb68  86		.
	LD	D,A		; cb69  57		W
	CALL	COORDS_TO_ADDR		; cb6a  cd 8a ce	M.N
	SET	5,H		; cb6d  cb ec		Kl
	CALL	READ_CELL_BMP		; cb6f  cd de ce	M^N
	LD	(XCB02),A	; cb72  32 02 cb	2.K
	LD	A,(XCB00)	; cb75  3a 00 cb	:.K
	CP	3		; cb78  fe 03		~.
	JR	Z,XCB90		; cb7a  28 14		(.
	LD	A,(XCB02)	; cb7c  3a 02 cb	:.K
	OR	A		; cb7f  b7		7
	JR	Z,XCB8C		; cb80  28 0a		(.
	CP	3		; cb82  fe 03		~.
	JR	Z,XCB90		; cb84  28 0a		(.
	SET	0,(IX+4)	; cb86  dd cb 04 c6	]K.F
	JR	XCB90		; cb8a  18 04		..
;
XCB8C:	RES	0,(IX+4)	; cb8c  dd cb 04 86	]K..
XCB90:	BIT	0,(IX+4)	; cb90  dd cb 04 46	]K.F
	JR	NZ,XCBBB	; cb94  20 25		 %
	LD	A,(XCB02)	; cb96  3a 02 cb	:.K
	CP	3		; cb99  fe 03		~.
	JR	NZ,XCBA1	; cb9b  20 04		 .
	LD	A,2		; cb9d  3e 02		>.
	JR	XCBDE		; cb9f  18 3d		.=
;
XCBA1:	LD	A,(XCB01)	; cba1  3a 01 cb	:.K
	CP	3		; cba4  fe 03		~.
	JR	NZ,XCBAC	; cba6  20 04		 .
	LD	A,0		; cba8  3e 00		>.
	JR	XCBDE		; cbaa  18 32		.2
;
XCBAC:	LD	A,(XCB00)	; cbac  3a 00 cb	:.K
	CP	3		; cbaf  fe 03		~.
	JR	NZ,XCBB7	; cbb1  20 04		 .
	LD	A,0FEH		; cbb3  3e fe		>~
	JR	XCBDE		; cbb5  18 27		.'
;
XCBB7:	LD	A,0FCH		; cbb7  3e fc		>|
	JR	XCBDE		; cbb9  18 23		.#
;
XCBBB:	LD	A,(XCB00)	; cbbb  3a 00 cb	:.K
	CP	3		; cbbe  fe 03		~.
	JR	NZ,XCBC6	; cbc0  20 04		 .
	LD	A,0FEH		; cbc2  3e fe		>~
	JR	XCBDE		; cbc4  18 18		..
;
XCBC6:	LD	A,(XCB01)	; cbc6  3a 01 cb	:.K
	CP	3		; cbc9  fe 03		~.
	JR	NZ,XCBD1	; cbcb  20 04		 .
	LD	A,0		; cbcd  3e 00		>.
	JR	XCBDE		; cbcf  18 0d		..
;
XCBD1:	LD	A,(XCB02)	; cbd1  3a 02 cb	:.K
	CP	3		; cbd4  fe 03		~.
	JR	NZ,XCBDC	; cbd6  20 04		 .
	LD	A,2		; cbd8  3e 02		>.
	JR	XCBDE		; cbda  18 02		..
;
XCBDC:	LD	A,0FCH		; cbdc  3e fc		>|
XCBDE:	ADD	A,(IX+3)	; cbde  dd 86 03	]..
	LD	(IX+3),A	; cbe1  dd 77 03	]w.
	ADD	A,A		; cbe4  87		.
	AND	0FH		; cbe5  e6 0f		f.
	LD	E,A		; cbe7  5f		_
	LD	D,0		; cbe8  16 00		..
	LD	HL,DIR_TABLE	; cbea  21 d1 b0	!Q0
	ADD	HL,DE		; cbed  19		.
	LD	A,(IX+0)	; cbee  dd 7e 00	]~.
	ADD	A,(HL)		; cbf1  86		.
	LD	(IX+0),A	; cbf2  dd 77 00	]w.
	INC	HL		; cbf5  23		#
	LD	A,(IX+1)	; cbf6  dd 7e 01	]~.
	ADD	A,(HL)		; cbf9  86		.
	LD	(IX+1),A	; cbfa  dd 77 01	]w.
	RET			; cbfd  c9		I
;
