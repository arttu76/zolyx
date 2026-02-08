; ==========================================================================
; CHASER WALL-FOLLOWING MOVEMENT ($CB03-$CBFD)
; ==========================================================================
;
; Chasers patrol the border and claimed edges using a wall-following
; algorithm. They NEVER enter empty space.
;
; --------------------------------------------------------------------------
; DATA STRUCTURE
; --------------------------------------------------------------------------
; Each chaser has a 37-byte data block, pointed to by IX:
;
;   IX+0: X position       (game coordinates, range 2..125)
;   IX+1: Y position       (game coordinates, range 18..93)
;   IX+2: (unused / old position for sprite restore)
;   IX+3: Direction         (0=right, 2=down, 4=left, 6=up -- cardinal only)
;   IX+4: Wall-following side flag
;            bit 0 = 0: wall is on the LEFT  (chaser prefers turning RIGHT)
;            bit 0 = 1: wall is on the RIGHT (chaser prefers turning LEFT)
;   IX+5..IX+36: Sprite background save buffer (32 bytes)
;
; --------------------------------------------------------------------------
; DIRECTION ENCODING & TABLE
; --------------------------------------------------------------------------
; Direction values: 0=right, 2=down, 4=left, 6=up
; These are doubled for table indexing: value * 2 = byte offset into DIR_TABLE
;
; DIR_TABLE at $B0D1 holds 8 pairs of (dx, dy) signed bytes:
;   Index 0: Right  (+1,  0)    Index 1: Down-Right (+1, +1)
;   Index 2: Down   ( 0, +1)    Index 3: Down-Left  (-1, +1)
;   Index 4: Left   (-1,  0)    Index 5: Up-Left    (-1, -1)
;   Index 6: Up     ( 0, -1)    Index 7: Up-Right   (+1, -1)
;
; Only cardinal directions (0, 2, 4, 6) are used by chasers.
;
; --------------------------------------------------------------------------
; SHADOW GRID ($6000+)
; --------------------------------------------------------------------------
; The game maintains two copies of the playfield bitmap:
;   $4000-$57FF: Main bitmap (visual) -- contains trail cells (value 2)
;   $6000-$77FF: Shadow grid          -- trail cells appear as EMPTY (value 0)
;
; Chasers read the SHADOW grid (SET 5,H converts $4xxx -> $6xxx), so they
; cannot see the player's trail. This means trail cells look like empty
; space to chasers, and chasers will never follow or collide with trail
; on a grid-reading basis.
;
; See: cell_io.asm -- WRITE_CELL_BMP writes only to bitmap (trail),
;      WRITE_CELL_BOTH writes to both bitmap and shadow (border/claimed).
;
; --------------------------------------------------------------------------
; SELF-MODIFYING CODE
; --------------------------------------------------------------------------
; Three bytes at $CB00-$CB02 (in movement_collision.asm, just before this
; routine) are used as storage for the three look-ahead cell values:
;   XCB00: cell value of the FORWARD-LEFT  neighbor
;   XCB01: cell value of the FORWARD       neighbor
;   XCB02: cell value of the FORWARD-RIGHT neighbor
;
; These addresses are NOP instructions in the binary ($00) but are written
; to by LD (XCB00),A / LD (XCB01),A / LD (XCB02),A during Step 1. They
; are then read back as data during Steps 2 and 3. This is a common Z80
; trick to avoid allocating RAM variables -- the code itself IS the storage.
;
; --------------------------------------------------------------------------
; CELL VALUES
; --------------------------------------------------------------------------
;   0 = empty    (nothing there, open space)
;   1 = claimed  (filled/captured territory)
;   2 = trail    (player's active trail -- but reads as 0 in shadow!)
;   3 = border   (game boundary or wall edge)
;
; Chasers only care about "border" (value 3) for wall-following. Claimed
; cells (value 1) are also solid but are not borders -- chasers treat them
; the same as empty for wall-following purposes. In practice chasers
; patrol border cells and newly claimed edges which become border=3.
;
; --------------------------------------------------------------------------
; ALGORITHM OVERVIEW (per frame, per chaser)
; --------------------------------------------------------------------------
;
; Step 1 -- Look-ahead ($CB03-$CB72):
;   Compute three positions relative to current facing direction:
;     Forward-Left  = direction rotated 90 degrees counter-clockwise
;                     computed as (dir - 2) AND 7, then doubled for table
;     Forward       = current direction
;                     computed as dir AND 7, then doubled for table
;     Forward-Right = direction rotated 90 degrees clockwise
;                     computed as (dir + 2) AND 7, then doubled for table
;   For each: add the dx/dy from the direction table to current position,
;   convert to screen address, switch to shadow grid, read cell value.
;   Results stored at self-modifying addresses XCB00/XCB01/XCB02.
;
; Step 2 -- Update wall-side flag ($CB75-$CB8C):
;   Adapts which side the chaser considers "the wall":
;     - If cellLeft == BORDER and cellRight == BORDER: wallSide = 1
;       (surrounded on both sides -- keep current preference or set right)
;     - If cellRight != EMPTY and cellRight == BORDER: wallSide = 1
;       (wall appeared on right side)
;     - If cellRight == EMPTY: wallSide = 0
;       (no wall on right, so wall must be on left)
;   This lets the chaser dynamically switch which wall it hugs when it
;   encounters corners, T-junctions, or open areas.
;
; Step 3 -- Determine turn ($CB96-$CBDD):
;   Based on the wallSide flag, choose a turning action:
;
;   wallSide = 0 (wall on left, prefer hugging right wall):
;     Priority 1: cellRight == BORDER? -> turn right  (turn = +2)
;     Priority 2: cellFwd   == BORDER? -> go straight (turn =  0)
;     Priority 3: cellLeft  == BORDER? -> turn left   (turn = -2 = $FE)
;     Fallback:   no border found      -> U-turn      (turn = -4 = $FC)
;
;   wallSide = 1 (wall on right, prefer hugging left wall):
;     Priority 1: cellLeft  == BORDER? -> turn left   (turn = -2 = $FE)
;     Priority 2: cellFwd   == BORDER? -> go straight (turn =  0)
;     Priority 3: cellRight == BORDER? -> turn right  (turn = +2)
;     Fallback:   no border found      -> U-turn      (turn = -4 = $FC)
;
;   The "turn" value is added to the current direction and masked to 0-7.
;
; Step 4 -- Apply direction and move ($CBDE-$CBFA):
;   new_dir = (current_dir + turn) AND 7
;   Store new direction, then look up dx/dy from direction table,
;   add to current X/Y position, and store new position.
;
; --------------------------------------------------------------------------
; EXTERNAL ROUTINES CALLED
; --------------------------------------------------------------------------
;   COORDS_TO_ADDR ($CE8A) -- see cell_io.asm
;     Entry: E = game X coordinate, D = game Y coordinate
;     Exit:  HL = bitmap screen address ($4xxx range)
;     Preserves: E (game X), A' (saved/restored via EX AF,AF')
;
;   READ_CELL_BMP ($CEDE) -- see cell_io.asm
;     Entry: HL = screen address pointing to cell, E = game X
;     Exit:  A = cell value (0-3), extracted from packed 2-bit bitmap
;     The routine reads the byte at (HL), shifts based on X position
;     within the byte (4 cells per byte), and returns the 2-bit value.
;
; --------------------------------------------------------------------------
; ENTRY/EXIT CONTRACT
; --------------------------------------------------------------------------
;   Entry: IX = pointer to chaser data block (37 bytes)
;   Exit:  Chaser's X, Y, direction updated in the IX data block
;          Returns immediately (RET Z) if chaser is inactive (X == 0)
;   Clobbers: A, B, D, E, H, L, AF' (via COORDS_TO_ADDR)
;


; ======================================================================
; STEP 1: LOOK-AHEAD -- Read three neighboring cells
; ======================================================================
; We probe three cells relative to the chaser's current facing direction:
;   Forward-Left, Forward, and Forward-Right.
; The results are stored at XCB00, XCB01, XCB02 respectively.
; All reads use the SHADOW grid ($6xxx) so trail is invisible.
; ======================================================================

; --- Move chaser ---
; Entry: IX points to 37-byte chaser data structure
; Exit:  Position and direction updated in IX block
MOVE_CHASER:	LD	A,(IX+0)	; cb03  dd 7e 00	]~.	; A = chaser's X position
	OR	A		; cb06  b7		7	; test if X == 0
	RET	Z		; cb07  c8		H	; if X is 0, chaser is inactive -- bail out immediately

; ----------------------------------------------------------------------
; STEP 1a: Probe the FORWARD-LEFT cell
; ----------------------------------------------------------------------
; Forward-Left direction = (current_dir - 2) AND 7
; This is a 90-degree counter-clockwise rotation from facing direction.
; Example: if facing Right (0), forward-left is Up (6).
; Example: if facing Down (2), forward-left is Right (0).

	LD	A,(IX+3)	; cb08  dd 7e 03	]~.	; A = current direction (0/2/4/6)
	ADD	A,0FEH		; cb0b  c6 fe		F~	; A = dir + $FE = dir - 2 (subtract 2 to rotate CCW)
	AND	7		; cb0d  e6 07		f.	; A = (dir - 2) AND 7 -- wrap to 0-7 range
	ADD	A,A		; cb0f  87		.	; A = A * 2 -- each direction table entry is 2 bytes (dx,dy)
	LD	E,A		; cb10  5f		_	; E = table offset for forward-left direction
	LD	D,0		; cb11  16 00		..	; D = 0 -- DE is now a 16-bit offset
	LD	HL,DIR_TABLE	; cb13  21 d1 b0	!Q0	; HL = base address of direction delta table ($B0D1)
	ADD	HL,DE		; cb16  19		.	; HL = address of (dx, dy) pair for forward-left direction
	LD	A,(IX+0)	; cb17  dd 7e 00	]~.	; A = chaser's current X position
	ADD	A,(HL)		; cb1a  86		.	; A = X + dx (move one cell in forward-left direction)
	LD	E,A		; cb1b  5f		_	; E = target X coordinate for the probe
	INC	HL		; cb1c  23		#	; HL now points to dy byte in the direction table
	LD	A,(IX+1)	; cb1d  dd 7e 01	]~.	; A = chaser's current Y position
	ADD	A,(HL)		; cb20  86		.	; A = Y + dy (move one cell in forward-left direction)
	LD	D,A		; cb21  57		W	; D = target Y coordinate for the probe
	CALL	COORDS_TO_ADDR		; cb22  cd 8a ce	M.N	; convert (E=X, D=Y) to screen address in HL ($4xxx range)
	SET	5,H		; cb25  cb ec		Kl	; flip bit 5 of H: converts $4xxx -> $6xxx (shadow grid!)
	CALL	READ_CELL_BMP		; cb27  cd de ce	M^N	; read 2-bit cell value from shadow grid at HL. A = 0/1/2/3
	LD	(XCB00),A	; cb2a  32 00 cb	2.K	; store forward-left cell value at self-modifying address $CB00

; ----------------------------------------------------------------------
; STEP 1b: Probe the FORWARD cell
; ----------------------------------------------------------------------
; Forward direction = current_dir AND 7 (unchanged)
; This is the cell directly ahead of the chaser.

	LD	A,(IX+3)	; cb2d  dd 7e 03	]~.	; A = current direction (0/2/4/6)
	AND	7		; cb30  e6 07		f.	; A = dir AND 7 -- ensure 0-7 range (should already be, but safe)
	ADD	A,A		; cb32  87		.	; A = A * 2 -- byte offset into direction table
	LD	E,A		; cb33  5f		_	; E = table offset for forward direction
	LD	D,0		; cb34  16 00		..	; D = 0 -- DE is 16-bit offset
	LD	HL,DIR_TABLE	; cb36  21 d1 b0	!Q0	; HL = direction delta table base ($B0D1)
	ADD	HL,DE		; cb39  19		.	; HL = address of (dx, dy) pair for forward direction
	LD	A,(IX+0)	; cb3a  dd 7e 00	]~.	; A = chaser's current X position
	ADD	A,(HL)		; cb3d  86		.	; A = X + dx (one cell forward)
	LD	E,A		; cb3e  5f		_	; E = target X for forward probe
	INC	HL		; cb3f  23		#	; advance to dy byte
	LD	A,(IX+1)	; cb40  dd 7e 01	]~.	; A = chaser's current Y position
	ADD	A,(HL)		; cb43  86		.	; A = Y + dy (one cell forward)
	LD	D,A		; cb44  57		W	; D = target Y for forward probe
	CALL	COORDS_TO_ADDR		; cb45  cd 8a ce	M.N	; convert (E=X, D=Y) to screen address in HL
	SET	5,H		; cb48  cb ec		Kl	; switch to shadow grid ($4xxx -> $6xxx)
	CALL	READ_CELL_BMP		; cb4a  cd de ce	M^N	; read cell value from shadow grid. A = 0/1/2/3
	LD	(XCB01),A	; cb4d  32 01 cb	2.K	; store forward cell value at self-modifying address $CB01

; ----------------------------------------------------------------------
; STEP 1c: Probe the FORWARD-RIGHT cell
; ----------------------------------------------------------------------
; Forward-Right direction = (current_dir + 2) AND 7
; This is a 90-degree clockwise rotation from facing direction.
; Example: if facing Right (0), forward-right is Down (2).
; Example: if facing Down (2), forward-right is Left (4).

	LD	A,(IX+3)	; cb50  dd 7e 03	]~.	; A = current direction (0/2/4/6)
	ADD	A,2		; cb53  c6 02		F.	; A = dir + 2 (rotate 90 degrees clockwise)
	AND	7		; cb55  e6 07		f.	; A = (dir + 2) AND 7 -- wrap to 0-7 range
	ADD	A,A		; cb57  87		.	; A = A * 2 -- byte offset into direction table
	LD	E,A		; cb58  5f		_	; E = table offset for forward-right direction
	LD	D,0		; cb59  16 00		..	; D = 0 -- DE is 16-bit offset
	LD	HL,DIR_TABLE	; cb5b  21 d1 b0	!Q0	; HL = direction delta table base ($B0D1)
	ADD	HL,DE		; cb5e  19		.	; HL = address of (dx, dy) for forward-right direction
	LD	A,(IX+0)	; cb5f  dd 7e 00	]~.	; A = chaser's current X position
	ADD	A,(HL)		; cb62  86		.	; A = X + dx (one cell in forward-right direction)
	LD	E,A		; cb63  5f		_	; E = target X for forward-right probe
	INC	HL		; cb64  23		#	; advance to dy byte
	LD	A,(IX+1)	; cb65  dd 7e 01	]~.	; A = chaser's current Y position
	ADD	A,(HL)		; cb68  86		.	; A = Y + dy (one cell in forward-right direction)
	LD	D,A		; cb69  57		W	; D = target Y for forward-right probe
	CALL	COORDS_TO_ADDR		; cb6a  cd 8a ce	M.N	; convert (E=X, D=Y) to screen address in HL
	SET	5,H		; cb6d  cb ec		Kl	; switch to shadow grid ($4xxx -> $6xxx)
	CALL	READ_CELL_BMP		; cb6f  cd de ce	M^N	; read cell value from shadow grid. A = 0/1/2/3
	LD	(XCB02),A	; cb72  32 02 cb	2.K	; store forward-right cell value at self-modifying address $CB02

; ======================================================================
; STEP 2: UPDATE WALL-SIDE FLAG
; ======================================================================
; The wall-side flag (IX+4, bit 0) tracks which side the chaser considers
; to be "the wall" it should hug:
;   bit 0 = 0: wall is on the LEFT  -> chaser prefers turning RIGHT
;   bit 0 = 1: wall is on the RIGHT -> chaser prefers turning LEFT
;
; This flag is dynamically updated based on what the look-ahead found:
;
; Decision tree:
;   1. If forward-left cell is BORDER (3):
;      -> There's solid wall on our left. Skip to step 3 (keep current flag).
;         Jump to XCB90.
;   2. Else check forward-right:
;      a. If forward-right is EMPTY (0):
;         -> No wall on our right side. Set flag = 0 (wall on left).
;            Jump to XCB8C which does RES 0,(IX+4).
;      b. If forward-right is BORDER (3):
;         -> Wall appeared on our right side. Skip to step 3.
;            Jump to XCB90.
;      c. If forward-right is CLAIMED (1):
;         -> Something solid-ish on our right. Set flag = 1 (wall on right).
;            Falls through to SET 0,(IX+4) then jumps to XCB90.
; ======================================================================

	LD	A,(XCB00)	; cb75  3a 00 cb	:.K	; A = forward-left cell value (from self-modifying storage)
	CP	3		; cb78  fe 03		~.	; is the forward-left cell a BORDER?
	JR	Z,XCB90		; cb7a  28 14		(.	; YES: border on our left -- skip flag update, go to step 3
	LD	A,(XCB02)	; cb7c  3a 02 cb	:.K	; A = forward-right cell value
	OR	A		; cb7f  b7		7	; test if forward-right is EMPTY (value 0)
	JR	Z,XCB8C		; cb80  28 0a		(.	; YES: right side is empty -> set wallSide=0 (wall on left)
	CP	3		; cb82  fe 03		~.	; is the forward-right cell a BORDER?
	JR	Z,XCB90		; cb84  28 0a		(.	; YES: border on right -- skip flag update, go to step 3
	SET	0,(IX+4)	; cb86  dd cb 04 c6	]K.F	; right cell is claimed (1) or trail-as-0 -- set wallSide=1 (wall on right)
	JR	XCB90		; cb8a  18 04		..	; jump to step 3 (wall-side flag test)
;
; --- Set wall-side to LEFT (clear bit 0) ---
; Reached when forward-right cell is empty: no wall on right, so the wall
; must be on the left side. Chaser will prefer turning right (away from wall).
XCB8C:	RES	0,(IX+4)	; cb8c  dd cb 04 86	]K..	; wallSide = 0 (wall on left, prefer right turns)

; ======================================================================
; STEP 3: DETERMINE TURN DIRECTION
; ======================================================================
; Based on the wallSide flag, we choose which neighboring border to
; turn toward. The chaser always tries to hug the wall on its preferred
; side. If no border is found in any direction, it U-turns.
;
; Turn values (added to current direction in Step 4):
;   +2   = turn right (clockwise 90 degrees)
;    0   = go straight (no turn)
;   $FE  = -2 = turn left (counter-clockwise 90 degrees)
;   $FC  = -4 = U-turn (reverse direction, 180 degrees)
; ======================================================================

; --- Check wall-side flag ---
XCB90:	BIT	0,(IX+4)	; cb90  dd cb 04 46	]K.F	; test wallSide flag: is wall on the right?
	JR	NZ,XCBBB	; cb94  20 25		 %	; if bit 0 = 1 (wall on right): jump to left-hugging logic

; ----------------------------------------------------------------------
; WALL ON LEFT (wallSide=0): Prefer turning RIGHT
; ----------------------------------------------------------------------
; When the wall is on our left, we prefer to stay close to the right wall.
; Priority order: right -> straight -> left -> U-turn
; This creates RIGHT-HAND wall-following behavior.
; ----------------------------------------------------------------------

	LD	A,(XCB02)	; cb96  3a 02 cb	:.K	; A = forward-right cell value
	CP	3		; cb99  fe 03		~.	; is forward-right a BORDER?
	JR	NZ,XCBA1	; cb9b  20 04		 .	; NO: skip -- try going straight instead
	LD	A,2		; cb9d  3e 02		>.	; YES: turn RIGHT (turn = +2, clockwise 90 degrees)
	JR	XCBDE		; cb9f  18 3d		.=	; jump to Step 4 to apply the turn
;
; Forward-right was not border. Try going straight.
XCBA1:	LD	A,(XCB01)	; cba1  3a 01 cb	:.K	; A = forward cell value
	CP	3		; cba4  fe 03		~.	; is the cell directly ahead a BORDER?
	JR	NZ,XCBAC	; cba6  20 04		 .	; NO: skip -- try turning left
	LD	A,0		; cba8  3e 00		>.	; YES: go STRAIGHT (turn = 0, no direction change)
	JR	XCBDE		; cbaa  18 32		.2	; jump to Step 4 to apply (no) turn
;
; Forward was not border either. Try turning left.
XCBAC:	LD	A,(XCB00)	; cbac  3a 00 cb	:.K	; A = forward-left cell value
	CP	3		; cbaf  fe 03		~.	; is the cell to the forward-left a BORDER?
	JR	NZ,XCBB7	; cbb1  20 04		 .	; NO: skip -- no border in any direction, must U-turn
	LD	A,0FEH		; cbb3  3e fe		>~	; YES: turn LEFT (turn = -2 = $FE, counter-clockwise 90 degrees)
	JR	XCBDE		; cbb5  18 27		.'	; jump to Step 4 to apply the turn
;
; No border found in any of the three forward directions.
; The chaser is surrounded by empty/claimed cells on three sides.
; Only option: reverse direction (U-turn).
XCBB7:	LD	A,0FCH		; cbb7  3e fc		>|	; U-TURN (turn = -4 = $FC, reverse 180 degrees)
	JR	XCBDE		; cbb9  18 23		.#	; jump to Step 4 to apply the turn

; ----------------------------------------------------------------------
; WALL ON RIGHT (wallSide=1): Prefer turning LEFT
; ----------------------------------------------------------------------
; When the wall is on our right, we prefer to stay close to the left wall.
; Priority order: left -> straight -> right -> U-turn
; This creates LEFT-HAND wall-following behavior.
; ----------------------------------------------------------------------

XCBBB:	LD	A,(XCB00)	; cbbb  3a 00 cb	:.K	; A = forward-left cell value
	CP	3		; cbbe  fe 03		~.	; is forward-left a BORDER?
	JR	NZ,XCBC6	; cbc0  20 04		 .	; NO: skip -- try going straight instead
	LD	A,0FEH		; cbc2  3e fe		>~	; YES: turn LEFT (turn = -2 = $FE, counter-clockwise 90 degrees)
	JR	XCBDE		; cbc4  18 18		..	; jump to Step 4 to apply the turn
;
; Forward-left was not border. Try going straight.
XCBC6:	LD	A,(XCB01)	; cbc6  3a 01 cb	:.K	; A = forward cell value
	CP	3		; cbc9  fe 03		~.	; is the cell directly ahead a BORDER?
	JR	NZ,XCBD1	; cbcb  20 04		 .	; NO: skip -- try turning right
	LD	A,0		; cbcd  3e 00		>.	; YES: go STRAIGHT (turn = 0, no direction change)
	JR	XCBDE		; cbcf  18 0d		..	; jump to Step 4 to apply (no) turn
;
; Forward was not border either. Try turning right.
XCBD1:	LD	A,(XCB02)	; cbd1  3a 02 cb	:.K	; A = forward-right cell value
	CP	3		; cbd4  fe 03		~.	; is the cell to the forward-right a BORDER?
	JR	NZ,XCBDC	; cbd6  20 04		 .	; NO: skip -- no border found, must U-turn
	LD	A,2		; cbd8  3e 02		>.	; YES: turn RIGHT (turn = +2, clockwise 90 degrees)
	JR	XCBDE		; cbda  18 02		..	; jump to Step 4 to apply the turn
;
; No border found in any of the three forward directions.
; The chaser must reverse direction.
XCBDC:	LD	A,0FCH		; cbdc  3e fc		>|	; U-TURN (turn = -4 = $FC, reverse 180 degrees)

; ======================================================================
; STEP 4: APPLY DIRECTION CHANGE AND MOVE ONE CELL
; ======================================================================
; A contains the turn delta: +2 (right), 0 (straight), $FE (-2, left),
; or $FC (-4, U-turn).
;
; We add this to the current direction and mask to 0-7 to get the new
; direction. Then we look up the (dx, dy) from the direction table and
; add it to the chaser's current position to move one cell.
;
; Note: direction is stored as 0/2/4/6 in IX+3, but the AND 7 and
; ADD A,A below handle the full 0-7 range. The doubled value (0-14)
; is masked to 0-15 ($0F) to index the 16-byte direction table, which
; wraps correctly for 8 directions.
; ======================================================================

XCBDE:	ADD	A,(IX+3)	; cbde  dd 86 03	]..	; A = turn_delta + current_direction
	LD	(IX+3),A	; cbe1  dd 77 03	]w.	; store new direction in chaser data (may have high bits, but AND below fixes it)
	ADD	A,A		; cbe4  87		.	; A = new_dir * 2 (byte offset into DIR_TABLE, each entry is 2 bytes)
	AND	0FH		; cbe5  e6 0f		f.	; A = (new_dir * 2) AND $0F -- mask to 0-15, wrapping the 8-entry table
	LD	E,A		; cbe7  5f		_	; E = direction table offset
	LD	D,0		; cbe8  16 00		..	; D = 0 -- DE is 16-bit table offset
	LD	HL,DIR_TABLE	; cbea  21 d1 b0	!Q0	; HL = direction delta table base address ($B0D1)
	ADD	HL,DE		; cbed  19		.	; HL = address of (dx, dy) pair for the new direction
	LD	A,(IX+0)	; cbee  dd 7e 00	]~.	; A = chaser's current X position
	ADD	A,(HL)		; cbf1  86		.	; A = X + dx -- new X position (move one cell in new direction)
	LD	(IX+0),A	; cbf2  dd 77 00	]w.	; store new X position in chaser data block
	INC	HL		; cbf5  23		#	; advance HL to the dy byte in direction table
	LD	A,(IX+1)	; cbf6  dd 7e 01	]~.	; A = chaser's current Y position
	ADD	A,(HL)		; cbf9  86		.	; A = Y + dy -- new Y position (move one cell in new direction)
	LD	(IX+1),A	; cbfa  dd 77 01	]w.	; store new Y position in chaser data block
	RET			; cbfd  c9		I	; return -- chaser has moved one cell
;
