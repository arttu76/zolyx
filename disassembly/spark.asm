; ==========================================================================
; SPARK DIAGONAL MOVEMENT ($D18A-$D279)
; ==========================================================================
;
; Sparks are diagonal-only enemies that bounce around the empty interior of
; the game field. They exist to threaten the player's trail: if the player
; is drawing and a spark crosses the trail, the player dies (detected
; separately by the main loop at $C467, not here). Sparks themselves die
; instantly (+50 points) when they move into a claimed or border cell.
;
; --------------------------------------------------------------------------
; DIRECTION ENCODING
; --------------------------------------------------------------------------
; Sparks use odd-numbered directions from the shared 8-direction system:
;   1 = Down-Right (+1, +1)
;   3 = Down-Left  (-1, +1)
;   5 = Up-Left    (-1, -1)
;   7 = Up-Right   (+1, -1)
;
; The direction table at DIR_TABLE ($B0D1) holds 8 entries of 2 bytes each
; (dx, dy as signed values). Entry index = direction * 2. Because sparks
; only use odd directions, they always move diagonally.
;
; --------------------------------------------------------------------------
; SPARK DATA STRUCTURE (5 bytes per spark, 8 sparks at $B097-$B0BE)
; --------------------------------------------------------------------------
;   IX+0 = X position (0 means spark is inactive/dead)
;   IX+1 = Y position
;   IX+2 = old X (saved before move, used for erase in rendering)
;   IX+3 = old Y (saved before move, used for erase in rendering)
;   IX+4 = direction (1, 3, 5, or 7)
;
; Spark addresses: $B097, $B09C, $B0A1, $B0A6, $B0AB, $B0B0, $B0B5, $B0BA
; (each 5 bytes apart).
;
; --------------------------------------------------------------------------
; SHADOW GRID AND TRAIL INTERACTION
; --------------------------------------------------------------------------
; The game maintains two copies of the playfield:
;   - Bitmap at $4000: contains all cells including trail (cell value 2)
;   - Shadow grid at $6000: identical except trail is NOT written here
;
; Sparks read from the SHADOW grid (SET 5,H flips $4xxx to $6xxx).
; This means sparks see trail cells as empty and pass right through them.
; Trail-spark collision is handled separately by the main loop ($C467),
; which checks if any spark occupies a trail cell.
;
; --------------------------------------------------------------------------
; BOUNCE ALGORITHM
; --------------------------------------------------------------------------
; When a spark hits a non-empty cell (border = value 3), it attempts to
; bounce in the following priority order:
;
;   1. Clockwise 90 degrees:       new_dir = (dir + 2) AND 7
;      Example: going Down-Right (1) -> try Down-Left (3)
;   2. Counter-clockwise 90 degrees: new_dir = (dir - 2) AND 7
;      (implemented as (dir + 4 - 2) = (dir - 2), via SUB 4 then undo)
;      Wait, actually: at step 2, the direction was already changed to
;      (dir+2) in step 1. So SUB 4 from (dir+2) gives (dir-2).
;      Example: was originally Down-Right (1), step 1 set it to 3,
;      SUB 4 gives 3-4 = -1 AND 7 = 7 = Up-Right
;   3. Reverse 180 degrees:         new_dir = (current_dir - 2) AND 7
;      At this point current_dir is (original-2), so SUB 2 gives
;      (original-4) = (original+4) AND 7 = 180 degree reversal.
;      Example: was originally Down-Right (1), direction is now 7 (Up-Right),
;      SUB 2 gives 5 = Up-Left, which is 180 from original.
;   4. All directions blocked: stay put (return without moving).
;
; This creates natural-looking bouncing behavior off walls and corners.
;
; --------------------------------------------------------------------------
; SOUND TRIGGER
; --------------------------------------------------------------------------
; When a bounce occurs, bit 7 of STATE_FLAGS ($B0C8) is set. The main
; loop's sound routine reads this flag to play the spark bounce sound
; effect, then clears the flag.
;
; --------------------------------------------------------------------------
; CALLING CONVENTION
; --------------------------------------------------------------------------
; MOVE_SPARK ($D18A):
;   Entry: IX = pointer to 5-byte spark data structure
;   Exit:  Spark position updated (or spark killed if it hit a solid cell)
;          Registers: AF, BC, DE, HL modified
;   Called from: main loop ($C4ED-$C520) for each of the 8 sparks
;
; KILL_SPARK ($D267):
;   Entry: IX = pointer to spark data structure
;   Exit:  IX+0 set to 0 (inactive), IX+2 set to 0, base score += 50
;          Registers: AF, DE, HL modified
;   Called from: MOVE_SPARK when spark hits claimed cell (value 1) or
;                border cell (value 3 is NOT a kill - 3 triggers bounce;
;                actually value 1 = claimed, value 2 = trail, value 3 = border;
;                any non-zero value that isn't 3 = kill, value 3 = bounce)
;
; COORDS_TO_ADDR ($CE8A) - see cell_io.asm:
;   Entry: E = game X, D = game Y
;   Exit:  HL = bitmap address for that cell's top pixel row
;
; READ_CELL_BMP ($CEDE) - see cell_io.asm:
;   Entry: HL = bitmap address (from COORDS_TO_ADDR)
;   Exit:  A = cell value (0=empty, 1=claimed, 2=trail, 3=border)
;
; DIR_TABLE ($B0D1) - see game_variables.asm:
;   8 entries x 2 bytes: [dx, dy] as signed bytes for each direction 0-7
;

;

; ==========================================================================
; MOVE_SPARK - Move one spark diagonally, bouncing off walls
; ==========================================================================
; Called once per frame for each active spark. IX points to the spark's
; 5-byte data block. If X position (IX+0) is 0, the spark is inactive
; and we return immediately.
; ==========================================================================

; --- Move spark ---
MOVE_SPARK:	LD	A,(IX+0)	; d18a  dd 7e 00	]~.	; A = spark X position
	OR	A		; d18d  b7		7	; test if X is zero (inactive spark)
	RET	Z		; d18e  c8		H	; if X=0, spark is dead/inactive -- skip it

; --------------------------------------------------------------------------
; STEP 1: Save current position as "old position" for erase later
; --------------------------------------------------------------------------
; The rendering system needs to know where the spark WAS so it can erase
; the old sprite before drawing at the new position.
; --------------------------------------------------------------------------

	LD	E,(IX+0)	; d18f  dd 5e 00	]^.	; E = current X position
	LD	(IX+2),E	; d192  dd 73 02	]s.	; save X into oldX (IX+2) for erase
	LD	D,(IX+1)	; d195  dd 56 01	]V.	; D = current Y position
	LD	(IX+3),D	; d198  dd 72 03	]r.	; save Y into oldY (IX+3) for erase

; --------------------------------------------------------------------------
; STEP 2: Check the cell at current position in the SHADOW grid
; --------------------------------------------------------------------------
; Even though the spark is currently here, the cell beneath it may have
; changed since last frame (e.g., a flood fill just claimed it). If so,
; the spark must die immediately before attempting to move.
; --------------------------------------------------------------------------

	CALL	COORDS_TO_ADDR		; d19b  cd 8a ce	M.N	; convert (E=X, D=Y) to HL=bitmap address
	SET	5,H		; d19e  cb ec		Kl	; flip HL from $4xxx to $6xxx (shadow grid)
	CALL	READ_CELL_BMP		; d1a0  cd de ce	M^N	; A = cell value at shadow grid position
	OR	A		; d1a3  b7		7	; test if cell is empty (A=0)
	JP	NZ,KILL_SPARK	; d1a4  c2 67 d2	BgR	; if non-zero: cell was claimed/filled under us -- spark dies!

; --------------------------------------------------------------------------
; STEP 3: Compute target position from current direction
; --------------------------------------------------------------------------
; Look up (dx, dy) from DIR_TABLE using the spark's direction value.
; Direction is stored as 1/3/5/7. The table has 2 bytes per entry, so
; we multiply direction by 2 to get the byte offset into the table.
; Then add dx to X and dy to Y to get the target cell coordinates.
; --------------------------------------------------------------------------

	LD	A,(IX+4)	; d1a7  dd 7e 04	]~.	; A = spark direction (1, 3, 5, or 7)
	ADD	A,A		; d1aa  87		.	; A = direction * 2 (table offset, each entry is 2 bytes)
	LD	E,A		; d1ab  5f		_	; E = table offset (low byte)
	LD	D,0		; d1ac  16 00		..	; D = 0 (high byte of offset)
	LD	HL,DIR_TABLE	; d1ae  21 d1 b0	!Q0	; HL = base address of direction delta table ($B0D1)
	ADD	HL,DE		; d1b1  19		.	; HL = address of (dx, dy) pair for this direction
	LD	A,(HL)		; d1b2  7e		~	; A = dx (signed: -1, 0, or +1)
	ADD	A,(IX+0)	; d1b3  dd 86 00	]..	; A = currentX + dx = targetX
	LD	E,A		; d1b6  5f		_	; E = targetX
	INC	HL		; d1b7  23		#	; advance to dy byte in table
	LD	A,(HL)		; d1b8  7e		~	; A = dy (signed: -1, 0, or +1)
	ADD	A,(IX+1)	; d1b9  dd 86 01	]..	; A = currentY + dy = targetY
	LD	D,A		; d1bc  57		W	; D = targetY

; --------------------------------------------------------------------------
; STEP 4: Check the target cell in the shadow grid
; --------------------------------------------------------------------------
; If target is empty (0): move there. If border (3): bounce.
; If claimed (1) or trail-in-shadow (shouldn't happen): spark dies.
; --------------------------------------------------------------------------

	CALL	COORDS_TO_ADDR		; d1bd  cd 8a ce	M.N	; convert (E=targetX, D=targetY) to HL=bitmap addr
	SET	5,H		; d1c0  cb ec		Kl	; flip to shadow grid ($6xxx)
	CALL	READ_CELL_BMP		; d1c2  cd de ce	M^N	; A = cell value at target position in shadow
	OR	A		; d1c5  b7		7	; test if target cell is empty
	JR	NZ,XD1CF	; d1c6  20 07		 .	; if non-zero: target is occupied -- handle bounce or death

; --------------------------------------------------------------------------
; Target cell is empty -- move the spark there
; --------------------------------------------------------------------------

	LD	(IX+0),E	; d1c8  dd 73 00	]s.	; update spark X to targetX
	LD	(IX+1),D	; d1cb  dd 72 01	]r.	; update spark Y to targetY
	RET			; d1ce  c9		I	; done -- spark moved successfully
;

; ==========================================================================
; BOUNCE HANDLER - Target cell was not empty
; ==========================================================================
; A still holds the cell value from READ_CELL_BMP.
; Cell value 3 = border wall -> attempt to bounce.
; Any other non-zero value (1 = claimed) -> spark dies.
; Note: trail (value 2) never appears in the shadow grid, so we only
; encounter 0 (empty), 1 (claimed), or 3 (border) here.
; ==========================================================================

XD1CF:	CP	3		; d1cf  fe 03		~.	; is target cell a border wall? (value 3)
	JP	NZ,KILL_SPARK	; d1d1  c2 67 d2	BgR	; if not border (must be claimed=1): spark dies!

; --------------------------------------------------------------------------
; BOUNCE ATTEMPT 1: Try clockwise 90-degree turn (dir + 2) AND 7
; --------------------------------------------------------------------------
; Set the sound trigger flag first -- any bounce makes a sound, even if
; the first attempt fails and a later one succeeds.
; --------------------------------------------------------------------------

	LD	HL,STATE_FLAGS	; d1d4  21 c8 b0	!H0	; HL = address of game state flags byte ($B0C8)
	SET	7,(HL)		; d1d7  cb fe		K~	; set bit 7: spark bounce sound trigger

	LD	A,(IX+4)	; d1d9  dd 7e 04	]~.	; A = current direction
	ADD	A,2		; d1dc  c6 02		F.	; A = direction + 2 (rotate 90 degrees clockwise)
	AND	7		; d1de  e6 07		f.	; A = A AND 7 (wrap around: 0-7 range)
	LD	(IX+4),A	; d1e0  dd 77 04	]w.	; store new direction (tentatively)

; --- Look up the delta for the new CW direction and compute target ---

	ADD	A,A		; d1e3  87		.	; A = new_direction * 2 (table byte offset)
	LD	E,A		; d1e4  5f		_	; E = table offset (low byte)
	LD	D,0		; d1e5  16 00		..	; D = 0 (high byte)
	LD	HL,DIR_TABLE	; d1e7  21 d1 b0	!Q0	; HL = direction delta table base
	ADD	HL,DE		; d1ea  19		.	; HL = pointer to (dx, dy) for new direction
	LD	A,(HL)		; d1eb  7e		~	; A = dx for CW direction
	ADD	A,(IX+0)	; d1ec  dd 86 00	]..	; A = currentX + dx = candidate targetX
	LD	E,A		; d1ef  5f		_	; E = candidate targetX
	INC	HL		; d1f0  23		#	; advance to dy
	LD	A,(HL)		; d1f1  7e		~	; A = dy for CW direction
	ADD	A,(IX+1)	; d1f2  dd 86 01	]..	; A = currentY + dy = candidate targetY
	LD	D,A		; d1f5  57		W	; D = candidate targetY

; --- Check if the CW bounce target is free ---

	CALL	COORDS_TO_ADDR		; d1f6  cd 8a ce	M.N	; convert candidate target to screen address
	SET	5,H		; d1f9  cb ec		Kl	; flip to shadow grid
	CALL	READ_CELL_BMP		; d1fb  cd de ce	M^N	; A = cell value at CW bounce target
	OR	A		; d1fe  b7		7	; is it empty?
	JR	NZ,XD208	; d1ff  20 07		 .	; if not empty: CW bounce failed, try CCW

; --- CW bounce target is empty -- move there ---

	LD	(IX+0),E	; d201  dd 73 00	]s.	; update spark X to CW target X
	LD	(IX+1),D	; d204  dd 72 01	]r.	; update spark Y to CW target Y
	RET			; d207  c9		I	; done -- spark bounced CW successfully
;

; ==========================================================================
; BOUNCE ATTEMPT 2: Try counter-clockwise 90-degree turn
; ==========================================================================
; The direction was already changed to (original + 2) in attempt 1.
; To get CCW from the original: (original - 2) AND 7.
; Since current = original + 2, we need current - 4:
;   (original + 2) - 4 = original - 2 (mod 8)
; ==========================================================================

XD208:	LD	A,(IX+4)	; d208  dd 7e 04	]~.	; A = current dir (which is original+2 from attempt 1)
	SUB	4		; d20b  d6 04		V.	; A = (original+2) - 4 = original - 2 (CCW 90 degrees)
	AND	7		; d20d  e6 07		f.	; wrap to 0-7 range
	LD	(IX+4),A	; d20f  dd 77 04	]w.	; store CCW direction (tentatively)

; --- Look up the delta for the CCW direction and compute target ---

	ADD	A,A		; d212  87		.	; A = new_direction * 2 (table byte offset)
	LD	E,A		; d213  5f		_	; E = table offset
	LD	D,0		; d214  16 00		..	; D = 0
	LD	HL,DIR_TABLE	; d216  21 d1 b0	!Q0	; HL = direction delta table base
	ADD	HL,DE		; d219  19		.	; HL = pointer to (dx, dy) for CCW direction
	LD	A,(HL)		; d21a  7e		~	; A = dx for CCW direction
	ADD	A,(IX+0)	; d21b  dd 86 00	]..	; A = currentX + dx = candidate targetX
	LD	E,A		; d21e  5f		_	; E = candidate targetX
	INC	HL		; d21f  23		#	; advance to dy
	LD	A,(HL)		; d220  7e		~	; A = dy for CCW direction
	ADD	A,(IX+1)	; d221  dd 86 01	]..	; A = currentY + dy = candidate targetY
	LD	D,A		; d224  57		W	; D = candidate targetY

; --- Check if the CCW bounce target is free ---

	CALL	COORDS_TO_ADDR		; d225  cd 8a ce	M.N	; convert to screen address
	SET	5,H		; d228  cb ec		Kl	; flip to shadow grid
	CALL	READ_CELL_BMP		; d22a  cd de ce	M^N	; A = cell value at CCW bounce target
	OR	A		; d22d  b7		7	; is it empty?
	JR	NZ,XD237	; d22e  20 07		 .	; if not empty: CCW bounce also failed, try 180

; --- CCW bounce target is empty -- move there ---

	LD	(IX+0),E	; d230  dd 73 00	]s.	; update spark X to CCW target X
	LD	(IX+1),D	; d233  dd 72 01	]r.	; update spark Y to CCW target Y
	RET			; d236  c9		I	; done -- spark bounced CCW successfully
;

; ==========================================================================
; BOUNCE ATTEMPT 3: Try 180-degree reversal
; ==========================================================================
; Current direction is (original - 2) from attempt 2.
; To get 180 from original: (original + 4) AND 7.
; Since current = original - 2, we need current + 6 = current - 2 (mod 8):
;   (original - 2) - 2 = original - 4 = original + 4 (mod 8)
; So SUB 2 from the current direction gives the 180-degree reversal.
; ==========================================================================

XD237:	LD	A,(IX+4)	; d237  dd 7e 04	]~.	; A = current dir (which is original-2 from attempt 2)
	SUB	2		; d23a  d6 02		V.	; A = (original-2) - 2 = original + 4 mod 8 (180 reversal)
	AND	7		; d23c  e6 07		f.	; wrap to 0-7 range
	LD	(IX+4),A	; d23e  dd 77 04	]w.	; store reversed direction (tentatively)

; --- Look up the delta for the reversed direction and compute target ---

	ADD	A,A		; d241  87		.	; A = new_direction * 2 (table byte offset)
	LD	E,A		; d242  5f		_	; E = table offset
	LD	D,0		; d243  16 00		..	; D = 0
	LD	HL,DIR_TABLE	; d245  21 d1 b0	!Q0	; HL = direction delta table base
	ADD	HL,DE		; d248  19		.	; HL = pointer to (dx, dy) for reversed direction
	LD	A,(HL)		; d249  7e		~	; A = dx for reversed direction
	ADD	A,(IX+0)	; d24a  dd 86 00	]..	; A = currentX + dx = candidate targetX
	LD	E,A		; d24d  5f		_	; E = candidate targetX
	INC	HL		; d24e  23		#	; advance to dy
	LD	A,(HL)		; d24f  7e		~	; A = dy for reversed direction
	ADD	A,(IX+1)	; d250  dd 86 01	]..	; A = currentY + dy = candidate targetY
	LD	D,A		; d253  57		W	; D = candidate targetY

; --- Check if the 180-degree target is free ---

	CALL	COORDS_TO_ADDR		; d254  cd 8a ce	M.N	; convert to screen address
	SET	5,H		; d257  cb ec		Kl	; flip to shadow grid
	CALL	READ_CELL_BMP		; d259  cd de ce	M^N	; A = cell value at reversed target
	OR	A		; d25c  b7		7	; is it empty?
	JR	NZ,XD266	; d25d  20 07		 .	; if not empty: ALL four directions blocked!

; --- 180-degree target is empty -- move there ---

	LD	(IX+0),E	; d25f  dd 73 00	]s.	; update spark X to reversed target X
	LD	(IX+1),D	; d262  dd 72 01	]r.	; update spark Y to reversed target Y
	RET			; d265  c9		I	; done -- spark reversed 180 degrees
;

; ==========================================================================
; ALL DIRECTIONS BLOCKED - Spark cannot move
; ==========================================================================
; This is the rare case where empty space has been filled in around the
; spark on all four diagonal sides simultaneously. The spark simply stays
; in place. Its direction remains set to the 180-degree value from attempt
; 3, so on the next frame it will try that direction first. In practice,
; this is extremely rare because the spark would need to be boxed in by
; claimed cells on all four diagonals at once. The spark is NOT killed --
; it waits and may be freed if the player dies and the field resets.
; ==========================================================================

XD266:	RET			; d266  c9		I	; do nothing -- spark stays put, direction = 180 from original
;

; ==========================================================================
; KILL_SPARK - Deactivate spark and award 50 points
; ==========================================================================
; Called when a spark's current or target cell is a claimed cell (value 1).
; This happens when the player's flood fill claims the cell the spark is
; sitting on, or when the spark tries to move into a newly claimed cell.
;
; Entry: IX = pointer to spark data structure
; Exit:  IX+0 = 0 (marks spark as inactive)
;        IX+2 = 0 (clear old X so rendering doesn't erase a stale position)
;        BASE_SCORE ($B0C3) incremented by 50 ($0032)
;
; The spark is permanently dead for the remainder of this level.
; New sparks are only spawned at level initialization.
; ==========================================================================

; --- Kill spark ---
KILL_SPARK:	LD	(IX+0),0	; d267  dd 36 00 00	]6..	; set X = 0: marks spark as inactive
	LD	(IX+2),0	; d26b  dd 36 02 00	]6..	; set oldX = 0: prevents stale erase
	LD	HL,(BASE_SCORE)	; d26f  2a c3 b0	*C0	; HL = current base score (16-bit, little-endian)
	LD	DE,X0032	; d272  11 32 00	.2.	; DE = 50 decimal ($0032) -- points for killing a spark
	ADD	HL,DE		; d275  19		.	; HL = base_score + 50
	LD	(BASE_SCORE),HL	; d276  22 c3 b0	"C0	; store updated base score back to memory
	RET			; d279  c9		I	; return to caller (main loop continues with next spark)
;
