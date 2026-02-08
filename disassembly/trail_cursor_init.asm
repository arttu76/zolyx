; ==========================================================================
; TRAIL CURSOR & GAME INITIALIZATION ($CBFE-$CE61)
; ==========================================================================
;
; This file contains the trail cursor movement logic, the new-game and
; new-level initialization routines, spark and chaser spawning, percentage
; counting subroutines, screen/shadow clearing, and related data tables.
;
; --------------------------------------------------------------------------
; MOVE_TRAIL_CURSOR ($CBFE):
;   Advances the trail cursor along the trail buffer ($9000 region).
;   The trail buffer stores 3 bytes per waypoint: X, Y, direction.
;   This routine is called once per frame from the main loop ($C527).
;   It advances 2 entries per call (6 bytes total), chasing the player's
;   drawing trail from behind.
;
;   The trail cursor is an enemy entity: if it catches up to the player
;   (buffer exhausted / next entry is zero), it sets the collision flag
;   (bit 0 of STATE_FLAGS at $B0C8), which triggers player death on the
;   next main loop check.
;
;   Entry:  IX = pointer to trail cursor data structure at $B072
;             IX+0 = cursor X position (0 = inactive)
;             IX+1 = cursor Y position
;             IX+3,IX+4 = 16-bit pointer into trail buffer ($9000 area)
;   Exit:   Trail cursor position updated; STATE_FLAGS may be modified
;   Clobbers: A, HL, flags
;
; --------------------------------------------------------------------------
; NEW_GAME_INIT ($CC40):
;   Resets all game state for a brand new game:
;     level = 0, score = 0, lives = 3
;   Falls through to LEVEL_INIT.
;   (Note: The code from $CC32-$CC59 is shown here as raw DB bytes because
;    the disassembler could not fully resolve this section. It includes
;    the new-game init logic for resetting score and lives.)
;
; --------------------------------------------------------------------------
; LEVEL_INIT ($CC5A):
;   Sets up everything needed for a new level. Called both at game start
;   and after completing a level (from $C374/LEVEL_START). Steps:
;     1. Set game timer to 176 ticks ($B0)
;     2. Clear state flags and trail frame counter
;     3. Clear screen bitmap ($4000) and shadow grid ($6000) via XCE19
;     4. Look up field color from LEVEL_COLORS[$CDAB + (level & 0x0F)]
;     5. Process attribute color for possible monochrome TV adaptation
;     6. Fill the game field attribute area with the level color
;     7. Draw the border rectangle via DRAW_BORDER_RECT ($CE62)
;     8. Calculate initial filled percentage (border-only = 0%)
;     9. Update level number display in HUD
;    10. Sync the timer bar display (animated, waits until bar matches)
;    11. Set player start position to X=2, Y=18 (top-left corner)
;    12. Clear player flags and trail cursor
;    13. Clear all 8 spark slots, then spawn sparks per level mask
;    14. Spawn chasers per level mask
;    15. Update the score/percentage display
;
; --------------------------------------------------------------------------
; SPARK_INIT ($CCBE):
;   For each of the 8 sparks: if the activation mask bit (from the
;   SPARK_ACTIVATION table at $CD82, indexed by level) is set, spawn
;   the spark at its base position (from SPARK_POSITIONS at $CD72) plus
;   a random offset:
;     X += PRNG() & 7          (0-7 pixel random jitter)
;     Y += (PRNG() & 7) * 2    (0-14 pixel random jitter, even only)
;   Initial diagonal direction: (PRNG() & 3) * 2 + 1 = 1, 3, 5, or 7
;   These map to DR, DL, UL, UR respectively.
;
; --------------------------------------------------------------------------
; CHASER_INIT ($CD2C):
;   Up to 2 chasers. Their initial positions are hard-coded in the
;   CHASER_POSITIONS table at $CD92:
;     Chaser 1: X=64 ($40), Y=18 ($12), dir=0 (right) -- top border center
;     Chaser 2: X=64 ($40), Y=93 ($5D), dir=4 (left)  -- bottom border center
;   Activation is controlled by CHASER_ACTIVATION table at $CD9B:
;     Levels 0-5:  $80 = bit 7 only = chaser 1 only
;     Levels 6-15: $C0 = bits 7+6    = both chasers
;   Special check: $B0F1 bit 7 gates chaser spawning entirely (related
;   to demo/attract mode -- if bit 7 is clear, no chasers spawn).
;
; --------------------------------------------------------------------------
; XCD5C: COLOR ATTRIBUTE REARRANGEMENT
;   A helper that rearranges the bits of a ZX Spectrum attribute byte.
;   Swaps the INK and PAPER color fields, preserving BRIGHT and FLASH.
;   Used when the $B0EF flag indicates monochrome/alternate color mode.
;   Entry: A = attribute byte
;   Exit:  A = attribute with INK and PAPER swapped
;
; --------------------------------------------------------------------------
; XCDBC: COUNT NON-EMPTY CELLS (bitmap version)
;   Scans the game field bitmap at $4000 via the row pointer table at
;   $FC40. Counts all non-zero 2-bit cells (anything that isn't empty).
;   Used for the "filled percentage" calculation.
;   Entry: none
;   Exit:  HL = count of non-empty cells
;
; --------------------------------------------------------------------------
; XCDE8: COUNT SPECIFIC CELLS (filtered version)
;   Similar to XCDBC but applies an XOR $55 filter to detect a specific
;   cell pattern. Used for counting "claimed" cells specifically (value 1,
;   pattern $55/$00). A cell is counted only if it's non-zero AND becomes
;   zero after XOR with $55 -- i.e., it matches $55 exactly.
;   Entry: none
;   Exit:  HL = count of matching cells
;
; --------------------------------------------------------------------------
; XCE19: CLEAR SCREEN AND SHADOW
;   Clears both the bitmap ($4000) and shadow grid ($6000) for the entire
;   game field. Iterates 160 ($A0) rows via the row pointer table at $FC40.
;   Each row: clear 32 bytes at the bitmap address, then clear 32 bytes
;   at the corresponding shadow address (bit 5 of H flipped to reach $6000).
;
; --------------------------------------------------------------------------
; XCE44: COPY BITMAP TO SHADOW
;   Copies the bitmap ($4000) to the shadow grid ($6000) for all 160 rows.
;   Uses LDIR for a 32-byte block copy per row. Called after the flood fill
;   to sync the shadow with the newly-claimed areas.
;
; --------------------------------------------------------------------------
; DATA TABLES:
;   $CD72 (16 bytes): Spark base positions (8 sparks x 2 bytes: X, Y)
;     Positions form a 3x3 grid minus the center:
;       Top row:    (29,33) (61,33) (93,33)
;       Middle row: (29,53)         (93,53)
;       Bottom row: (29,73) (61,73) (93,73)
;
;   $CD82 (16 bytes): Spark activation masks per level
;     Level 0: $40 (1 spark), Level 1: $18 (2 sparks), ...
;     Levels 7+: $FF (all 8 sparks). Bits are rotated left via RLC C
;     in the init loop; bit 7 -> carry -> first spark.
;
;   $CD92 (9 bytes):  Chaser initial positions (2 chasers x 3: X, Y, dir)
;     Chaser 1: $40,$12,$00 (X=64, Y=18, dir=Right)
;     Chaser 2: $40,$5D,$04 (X=64, Y=93, dir=Left)
;     Plus trailing zero padding byte.
;
;   $CD9B (16 bytes): Chaser activation masks per level
;     Levels 0-5: $80 (1 chaser), Levels 6-15: $C0 (2 chasers)
;
;   $CDAB (16 bytes): Level color table (attribute bytes)
;     Raw: 70 68 58 60 68 78 68 70 60 58 78 68 70 50 58 68
;     All have BRIGHT=1 (bit 6 set), INK=0 (black).
;     PAPER color encodes the field background color for each level:
;       Level 0: $70 = white paper
;       Level 1: $68 = yellow paper
;       Level 2: $58 = cyan paper
;       Level 3: $60 = green paper
;       etc. (cycles every 16 levels)
;


; ==========================================================================
; MOVE_TRAIL_CURSOR ($CBFE)
; ==========================================================================
; Called from main loop at $C527 via:
;   LD IX,TRAIL_CURSOR ($B072)
;   CALL MOVE_TRAIL_CURSOR
;
; The trail cursor chases the player along their drawing trail. It reads
; the trail buffer at $9000 (3 bytes per entry: X, Y, direction) and
; advances its position 2 entries per frame. When the buffer runs out
; (next X byte is zero), the cursor has caught the player and a collision
; flag is set, killing the player.
;
; IX register layout (TRAIL_CURSOR structure at $B072):
;   IX+0 = X position (0 means cursor is inactive/not spawned)
;   IX+1 = Y position
;   IX+2 = (unused padding / sprite type)
;   IX+3 = low byte of trail buffer read pointer
;   IX+4 = high byte of trail buffer read pointer
; --------------------------------------------------------------------------

MOVE_TRAIL_CURSOR:
	LD	A,(IX+0)	; cbfe  dd 7e 00	; Load trail cursor X position
	OR	A		; cc01  b7		; Test if X is zero
	RET	Z		; cc02  c8		; If X=0, cursor is inactive -- do nothing, return

	; --- Cursor is active: set the "cursor moving" sound flag ---
	LD	HL,STATE_FLAGS	; cc03  21 c8 b0	; Point HL to game state flags byte ($B0C8)
	SET	6,(HL)		; cc06  cb f6		; Set bit 6 = "trail cursor is moving" (triggers sound in main loop)

	; --- Advance to next trail buffer entry (1st of 2 per frame) ---
	; The trail buffer pointer (IX+3/IX+4) currently points to the LAST
	; entry we consumed. We advance by 3 bytes to reach the next entry.
	LD	L,(IX+3)	; cc08  dd 6e 03	; Load low byte of trail buffer read pointer
	LD	H,(IX+4)	; cc0b  dd 66 04	; Load high byte of trail buffer read pointer
	INC	HL		; cc0e  23		; Skip past byte 0 (X) of current entry
	INC	HL		; cc0f  23		; Skip past byte 1 (Y) of current entry
	INC	HL		; cc10  23		; Skip past byte 2 (direction) -- HL now points to next entry's X

	; --- Check if the first new entry is valid ---
	LD	A,(HL)		; cc11  7e		; Read X byte of the next trail entry
	OR	A		; cc12  b7		; Test if this X is zero (end of recorded trail)
	JR	Z,XCC1C	; cc13  28 07		; If zero: trail exhausted, jump to collision handler

	; --- First entry is valid; advance to the second entry (2 per frame) ---
	INC	HL		; cc15  23		; Skip byte 0 (X) of entry we just checked
	INC	HL		; cc16  23		; Skip byte 1 (Y)
	INC	HL		; cc17  23		; Skip byte 2 (direction) -- HL now points to 2nd new entry's X

	; --- Check if the second new entry is valid ---
	LD	A,(HL)		; cc18  7e		; Read X byte of the second trail entry
	OR	A		; cc19  b7		; Test if this X is zero
	JR	NZ,XCC22	; cc1a  20 06		; If non-zero: both entries valid, jump to update cursor position

	; ---------------------------------------------------------------
	; TRAIL EXHAUSTED: Cursor has caught up with the player.
	; This means the player was too slow and the cursor consumed all
	; trail entries. Set bit 0 of STATE_FLAGS (collision detected),
	; which the main loop ($C553) checks to trigger player death.
	; ---------------------------------------------------------------
XCC1C:	LD	HL,STATE_FLAGS	; cc1c  21 c8 b0	; Point HL to game state flags ($B0C8)
	SET	0,(HL)		; cc1f  cb c6		; Set bit 0 = "collision detected" -> player dies
	RET			; cc21  c9		; Return (cursor has caught the player)

; ---------------------------------------------------------------
; UPDATE CURSOR POSITION from the trail buffer entry.
; At this point:
;   A = X coordinate from the trail entry we're moving to
;   HL = pointer to that entry's X byte in the trail buffer
; We update the cursor's screen position and save the new buffer pointer.
; ---------------------------------------------------------------
XCC22:	LD	(IX+0),A	; cc22  dd 77 00	; Store new X position into cursor structure
	INC	HL		; cc25  23		; Advance HL to the Y byte of this trail entry
	LD	A,(HL)		; cc26  7e		; Read Y coordinate from trail buffer
	LD	(IX+1),A	; cc27  dd 77 01	; Store new Y position into cursor structure
	DEC	HL		; cc2a  2b		; Back up HL to point at the X byte again (current entry start)
	LD	(IX+3),L	; cc2b  dd 75 03	; Save low byte of trail buffer pointer
	LD	(IX+4),H	; cc2e  dd 74 04	; Save high byte of trail buffer pointer
	RET			; cc31  c9		; Return -- cursor position updated for this frame


; ==========================================================================
; NEW GAME INITIALIZATION ($CC32-$CC59)
; ==========================================================================
; This region contains the NEW_GAME_INIT code that resets the game for a
; brand new game start. The disassembler rendered it as raw data bytes
; because the entry point alignment was ambiguous during static analysis.
;
; The logic it performs (reconstructed from the TypeScript reimplementation
; and cross-referencing with game_variables.asm):
;   - LD A,(IX+2) / CP 7 / JR C,+2 / LD A,3 / LD (IX+2),A
;     (clamp lives to max 3 if > 7, or set initial lives = 3)
;   - LD A,$3E / ... (possibly score reset continuation)
;   - LD A,0 / LD ($B0C1),A   -- set LEVEL_NUM = 0
;   - LD HL,0 / LD ($B0C3),HL -- set BASE_SCORE = 0
;   - LD A,3 / LD ($B0C2),A   -- set LIVES = 3
;   - CALL $CD7A (unknown helper, possibly related to input setup)
;   - Various display update calls
;   - Falls through to LEVEL_INIT at $CC5A
; --------------------------------------------------------------------------

	DB	0DDH,7EH,2,3CH				; cc32  ]~.<  ; LD A,(IX+2) / INC A
	DW	X07FE		; cc36   fe 07      ~.		; CP 7

	DB	38H,2,3EH,3,0DDH,77H,2			; cc38  8.>.]w. ; JR C,+2 / LD A,3 / LD (IX+2),A
	DW	X3EC9		; cc3f   c9 3e      I>		; RET / LD A,...

	DB	0,32H,0C1H,0B0H,21H,0,0,22H		; cc41  .2A0!.." ; LD A,0 / LD ($B0C1),A / LD HL,0 / LD (...),
	DW	BASE_SCORE		; cc49   c3 b0      C0	; target = BASE_SCORE ($B0C3)

	DB	3EH,3,32H,0C2H,0B0H			; cc4b  >.2B0   ; LD A,3 / LD ($B0C2),A  [lives=3]
	DW	X7ACD		; cc50   cd 7a      Mz		; CALL $CD7A
	DW	XCDD2		; cc52   d2 cd      RM		; JP NC,...
	DB	95H					; cc54  .
	DW	XCDD2		; cc55   d2 cd      RM
	DW	UPDATE_LIVES_DISPLAY		; cc57   b0 d2      0R	; CALL UPDATE_LIVES_DISPLAY ($D2B0)

	DB	0C9H					; cc59  I	; RET (or fall-through end marker)


; ==========================================================================
; LEVEL INIT ($CC5A)
; ==========================================================================
; Called from:
;   $C374 (LEVEL_START) -- at start of a new level
;   NEW_GAME_INIT falls through here after resetting score/lives
;
; Sets up the game field, spawns entities, and prepares all state for
; a new level. The level number at $B0C1 determines which color, which
; sparks, and which chasers are active.
; --------------------------------------------------------------------------

LEVEL_INIT:
	LD	A,0B0H		; cc5a  3e b0		; A = 176 = initial timer value ($B0 = 176 decimal)
	LD	(GAME_TIMER),A	; cc5c  32 c0 b0	; Store 176 into game timer at $B0C0

	; --- Clear all game state flags ---
	LD	A,0		; cc5f  3e 00		; A = 0
	LD	(STATE_FLAGS),A	; cc61  32 c8 b0	; Clear state flags ($B0C8): no collision, no timer expired, etc.
	LD	(TRAIL_FRAME_CTR),A	; cc64  32 e8 b0	; Clear trail frame counter ($B0E8): cursor won't activate until 72 frames of drawing

	; --- Clear screen bitmap and shadow grid ---
	CALL	XCE19		; cc67  cd 19 ce	; Clear entire game field on both bitmap ($4000) and shadow ($6000)
					;			; See XCE19 below: zeroes 160 rows x 32 bytes on each buffer

	; --- Look up level color from table ---
	LD	A,(LEVEL_NUM)	; cc6a  3a c1 b0	; Load current level number (0-based) from $B0C1
	AND	0FH		; cc6d  e6 0f		; Mask to 0-15 (level colors cycle every 16 levels)
	LD	E,A		; cc6f  5f		; E = level & 0x0F (index into color table)
	LD	D,0		; cc70  16 00		; D = 0 (DE = 16-bit index for table offset)
	LD	HL,LEVEL_COLORS	; cc72  21 ab cd	; HL = base address of level color table ($CDAB)
	ADD	HL,DE		; cc75  19		; HL = LEVEL_COLORS + (level & 0x0F)
	LD	A,(HL)		; cc76  7e		; A = attribute byte for this level (e.g., $70 = bright white paper)

	; --- Process attribute for possible monochrome adaptation ---
	CALL	PROCESS_ATTR_COLOR		; cc77  cd 07 bc	; Remap attribute if $B0EE bit 7 is set (monochrome TV mode)
					;			; See utilities.asm $BC07: may swap INK/PAPER for readability

	; --- Check if INK/PAPER should be swapped ($B0EF flag) ---
	LD	HL,XB0EF	; cc7a  21 ef b0	; Point to flag byte $B0EF
	BIT	7,(HL)		; cc7d  cb 7e		; Test bit 7: is alternate color mode enabled?
	CALL	NZ,XCD5C	; cc7f  c4 5c cd	; If set: call XCD5C to swap INK/PAPER fields in the attribute byte
					;			; This ensures contrast on black & white TVs

	; --- Store the final field color attribute ---
	LD	(FIELD_COLOR),A	; cc82  32 ec b0	; Save processed attribute to $B0EC (used throughout the level)

	; --- Fill the game field area with the level color attribute ---
	; FILL_ATTR_RECT params: B=start row, C=start col, D=height, E=width, A=attr
	LD	BC,X0400	; cc85  01 00 04	; B=4 (start at attribute row 4), C=0 (start at column 0)
	LD	DE,X1420	; cc88  11 20 14	; D=20 (height: 20 char rows = rows 4-23), E=32 (full width)
	CALL	FILL_ATTR_RECT		; cc8b  cd f6 ba	; Fill the entire field attribute area with the level color
					;			; See utilities.asm $BAF6: fills D rows x E cols starting at (B,C)

	; --- Draw the border rectangle around the game field ---
	CALL	DRAW_BORDER_RECT		; cc8e  cd 62 ce	; Draw border cells from (2,18) clockwise around the field perimeter
					;			; See cell_io.asm $CE62: uses WRITE_CELL_BOTH to write to bitmap+shadow

	; --- Calculate the initial filled percentage (border only) ---
	CALL	CALC_PERCENTAGE		; cc91  cd 80 c7	; Count filled cells, compute percentage. At level start this will be
					;			; 0% because only border cells exist (they're subtracted out)

	; --- Update the HUD level display ---
	CALL	UPDATE_LEVEL_DISPLAY		; cc94  cd 95 d2	; Render "Level XX" in the HUD (display.asm $D295)
					;			; Displays (level + 1) since levels are 0-based internally

	; --- Animate the timer bar to its starting position ---
	; The timer bar is animated: it grows/shrinks toward the actual timer value.
	; This loop waits until the bar display matches the real timer value (176).
XCC97:	CALL	UPDATE_TIMER_BAR		; cc97  cd c1 d2	; Update timer bar by 1 pixel. Returns carry=1 if still animating
	HALT			; cc9a  76		; Wait for next vertical blank (50Hz frame sync)

	JR	C,XCC97		; cc9b  38 fa		; If carry set: bar hasn't finished animating yet, keep looping
					;			; Once carry is clear, bar matches timer and we proceed

	; --- Set player starting position ---
	LD	HL,X1202	; cc9d  21 02 12	; H=$12 (Y=18), L=$02 (X=2) = top-left corner of the border
	LD	(PLAYER_XY),HL	; cca0  22 03 b0	; Store player position at $B003-$B004 (X=2, Y=18)

	; --- Clear player flags ---
	LD	A,0		; cca3  3e 00		; A = 0
	LD	(PLAYER_FLAGS),A	; cca5  32 e1 b0	; Clear all player flags ($B0E1): not drawing, no direction, no fire

	; --- Deactivate trail cursor ---
	LD	HL,X0000	; cca8  21 00 00	; HL = 0
	LD	(TRAIL_CURSOR),HL	; ccab  22 72 b0	; Set trail cursor X=0 (inactive), Y=0 at $B072-$B073

	; =================================================================
	; SPARK INITIALIZATION LOOP
	; =================================================================
	; First pass: clear all 8 spark data slots and assign random
	; diagonal directions. Each spark slot is 5 bytes:
	;   +0 = X (0=inactive), +1 = Y, +2 = old X, +3 = old Y, +4 = direction
	; The loop zeroes bytes 0-3 (position), then sets byte 4 (direction)
	; to a random diagonal: (PRNG & 3) * 2 + 1 = {1,3,5,7}
	; Direction 1=Down-Right, 3=Down-Left, 5=Up-Left, 7=Up-Right
	; -----------------------------------------------------------------

	LD	HL,SPARK_ARRAY	; ccae  21 97 b0	; HL points to start of spark array at $B097
	LD	B,8		; ccb1  06 08		; B = 8 (loop counter: 8 sparks to initialize)

XCCB3:	PUSH	BC		; ccb3  c5		; Save outer loop counter on stack
	LD	B,4		; ccb4  06 04		; B = 4 (inner loop: clear 4 bytes of this spark slot: X, Y, oldX, oldY)

XCCB6:	LD	(HL),0		; ccb6  36 00		; Clear current byte to zero
	INC	HL		; ccb8  23		; Advance to next byte
	DJNZ	XCCB6		; ccb9  10 fb		; Decrement B; if not zero, loop back to clear next byte
					;			; After this inner loop, HL points to byte +4 (direction byte)

	CALL	PRNG		; ccbb  cd e4 d3	; Get a pseudo-random number in A
					;			; See effects.asm $D3E4: uses R register XOR'd with memory

; --- Set random diagonal direction for this spark ---
; (Code continues immediately into SPARK_INIT which uses the random value)
SPARK_INIT:
	AND	3		; ccbe  e6 03		; Mask to 0-3 (4 possible diagonal directions)
	ADD	A,A		; ccc0  87		; Double it: A = 0, 2, 4, or 6
	ADD	A,1		; ccc1  c6 01		; Add 1: A = 1, 3, 5, or 7 (the 4 diagonal directions)
					;			; 1=DR(+1,+1) 3=DL(-1,+1) 5=UL(-1,-1) 7=UR(+1,-1)
	LD	(HL),A		; ccc3  77		; Store direction into spark's byte +4
	INC	HL		; ccc4  23		; Advance HL to the start of the next spark slot
	POP	BC		; ccc5  c1		; Restore outer loop counter
	DJNZ	XCCB3		; ccc6  10 eb		; Decrement B (spark count); loop back for next spark

	; =================================================================
	; SPARK ACTIVATION & POSITION ASSIGNMENT
	; =================================================================
	; Now we go through all 8 sparks again, using the level-specific
	; activation mask to decide which sparks actually get spawned.
	; Active sparks get their base position (from SPARK_POSITIONS table)
	; plus a random offset. Inactive sparks keep X=0 (inactive).
	; -----------------------------------------------------------------

	; --- Determine activation mask for current level ---
	LD	A,(LEVEL_NUM)	; ccc8  3a c1 b0	; Load level number
	CP	10H		; cccb  fe 10		; Compare with 16
	JR	C,XCCD1		; cccd  38 02		; If level < 16, use it directly
	LD	A,0FH		; cccf  3e 0f		; If level >= 16, clamp to 15 (table only has 16 entries)
XCCD1:	LD	E,A		; ccd1  5f		; E = clamped level index
	LD	D,0		; ccd2  16 00		; D = 0 (DE = 16-bit index)
	LD	HL,SPARK_ACTIVATION	; ccd4  21 82 cd	; HL = base of spark activation mask table ($CD82)
	ADD	HL,DE		; ccd7  19		; HL = table entry for this level
	LD	C,(HL)		; ccd8  4e		; C = activation bitmask (bit 7 = spark 0, bit 6 = spark 1, etc.)

	LD	B,8		; ccd9  06 08		; B = 8 (process all 8 sparks)
	LD	DE,SPARK_POSITIONS	; ccdb  11 72 cd	; DE = base of spark position table ($CD72)
	LD	HL,SPARK_ARRAY	; ccde  21 97 b0	; HL = base of spark data array ($B097)

	; --- Loop through each spark, checking its activation bit ---
XCCE1:	RLC	C		; cce1  cb 01		; Rotate C left: bit 7 goes into carry, other bits shift up
					;			; Carry = 1 means this spark should be activated
	JR	C,XCCEE		; cce3  38 09		; If carry set: spark is active, jump to position assignment

	; --- This spark is NOT active: skip its data slots ---
	INC	HL		; cce5  23		; Skip spark byte +0 (X, already 0 = inactive)
	INC	HL		; cce6  23		; Skip byte +1 (Y)
	INC	HL		; cce7  23		; Skip byte +2 (old X)
	INC	HL		; cce8  23		; Skip byte +3 (old Y)
	INC	HL		; cce9  23		; Skip byte +4 (direction) -- HL now at next spark slot
	INC	DE		; ccea  13		; Skip position table X byte
	INC	DE		; cceb  13		; Skip position table Y byte -- DE at next spark's base position
	JR	XCD0B		; ccec  18 1d		; Jump to bottom of loop (skip the spawn code)

	; --- This spark IS active: assign position = base + random offset ---
XCCEE:	CALL	PRNG		; ccee  cd e4 d3	; Get random number in A (for X offset)
	AND	7		; ccf1  e6 07		; Mask to 0-7: random X offset
	EX	DE,HL		; ccf3  eb		; Swap DE<->HL: HL now points to spark position table entry
	ADD	A,(HL)		; ccf4  86		; A = base_X + random_offset (from SPARK_POSITIONS table)
	EX	DE,HL		; ccf5  eb		; Swap back: HL = spark array, DE = position table

	; The following bytes encode:
	;   INC DE         -- advance past the X byte in position table
	;   LD (HL),A      -- store computed X into spark +0
	;   INC HL         -- advance to spark +1 (Y)
	;   INC HL         -- advance to spark +2 (old X)
	;   LD (HL),A      -- store X also as old X (for erasure on first frame)
	;   DEC HL         -- back to spark +1 (Y position)
	;   CALL PRNG      -- get another random number (for Y offset)
	;   AND 7          -- mask to 0-7
	DB	13H					; ccf6  .	; INC DE (skip base X in position table)
	DB	'w##w+'					; ccf7		; LD (HL),A / INC HL / INC HL / LD (HL),A / DEC HL
	DW	XE4CD		; ccfc   cd e4      Md	; CALL PRNG ($D3E4)
	DW	XE6D3		; ccfe   d3 e6      Sf	; AND 7 (partially encoded)

	; --- Compute Y position: base_Y + (random & 7) * 2 ---
	; The random value (0-7) is doubled via RLCA, giving even offsets 0-14.
	; This keeps Y positions aligned to 2-pixel cell boundaries.
	RLCA			; cd00  07		; A = (PRNG & 7) * 2 (rotate left = multiply by 2)
	EX	DE,HL		; cd01  eb		; Swap: HL = position table, DE = spark array
	ADD	A,(HL)		; cd02  86		; A = base_Y + random Y offset (from SPARK_POSITIONS)
	EX	DE,HL		; cd03  eb		; Swap back: HL = spark array, DE = position table
	INC	DE		; cd04  13		; Advance DE past the Y byte in position table

	; The following bytes encode:
	;   LD (HL),A      -- store computed Y into spark +1
	;   INC HL         -- advance to +2 (old X)
	;   INC HL         -- advance to +3 (old Y)
	;   LD (HL),A      -- store Y also as old Y
	;   INC HL         -- advance to +4 (direction, already set from first pass)
	;   INC HL         -- advance to start of next spark slot
	DB	'w##w##'				; cd05	; LD (HL),A / INC HL x2 / LD (HL),A / INC HL x2

	; --- Bottom of spark activation loop ---
XCD0B:	DJNZ	XCCE1		; cd0b  10 d4		; Decrement B; if sparks remain, loop back


	; =================================================================
	; CHASER ACTIVATION & POSITION ASSIGNMENT
	; =================================================================
	; Determine how many chasers are active based on the level-specific
	; activation mask from CHASER_ACTIVATION ($CD9B).
	; -----------------------------------------------------------------

	; --- Get chaser activation mask for this level ---
	LD	A,(LEVEL_NUM)	; cd0d  3a c1 b0	; Load level number
	CP	10H		; cd10  fe 10		; Compare with 16
	JR	C,XCD16		; cd12  38 02		; If level < 16, use directly
	LD	A,0FH		; cd14  3e 0f		; Clamp to 15 if >= 16 (table has 16 entries)
XCD16:	LD	E,A		; cd16  5f		; E = clamped level index
	LD	D,0		; cd17  16 00		; DE = 16-bit index
	LD	HL,CHASER_ACTIVATION	; cd19  21 9b cd	; HL = chaser activation mask table ($CD9B)
	ADD	HL,DE		; cd1c  19		; HL = table entry for this level
	LD	C,(HL)		; cd1d  4e		; C = chaser activation bitmask
					;			; $80 = chaser 1 only, $C0 = both chasers

	; --- Check if chasers should be enabled at all ---
	; $B0F1 bit 7 is a flag that gates chaser spawning. When clear (e.g.,
	; during attract/demo mode), no chasers spawn regardless of level mask.
	LD	HL,XB0F1	; cd1e  21 f1 b0	; Point to chaser enable flag
	BIT	7,(HL)		; cd21  cb 7e		; Test bit 7: are chasers globally enabled?
	JR	NZ,XCD27	; cd23  20 02		; If set: chasers allowed, skip to init
	LD	C,0		; cd25  0e 00		; If clear: force mask to 0 (no chasers spawn)

XCD27:	LD	B,2		; cd27  06 02		; B = 2 (loop counter: process 2 potential chasers)
	LD	HL,CHASER1_DATA	; cd29  21 28 b0	; HL = start of chaser 1 data structure ($B028)


; ==========================================================================
; CHASER INIT ($CD2C)
; ==========================================================================
; For each of the 2 possible chasers:
;   - Rotate activation mask C left; carry = this chaser's activation bit
;   - If inactive: set X=0 (slot disabled), skip 3 position bytes, then
;     advance HL past the 37-byte chaser structure
;   - If active: copy X, Y, direction from CHASER_POSITIONS table into
;     the chaser data structure, then advance HL
;
; Chaser data structure (37 bytes each, starting at $B028 / $B04D):
;   +0  = X position (0 = inactive)
;   +1  = Y position
;   +2  = (sprite type / unused)
;   +3  = direction (0=R, 2=D, 4=L, 6=U for wall-following)
;   +4  = wall-following side marker
;   +5..+36 = saved sprite background (32 bytes)
;
; CHASER_POSITIONS table at $CD92 (3 bytes each):
;   Chaser 1: X=$40(64), Y=$12(18), dir=$00(right) -- top border, heading right
;   Chaser 2: X=$40(64), Y=$5D(93), dir=$04(left) -- bottom border, heading left
; --------------------------------------------------------------------------

CHASER_INIT:
	LD	DE,CHASER_POSITIONS	; cd2c  11 92 cd	; DE = base of chaser position table ($CD92)

XCD2F:	RLC	C		; cd2f  cb 01		; Rotate mask left: bit 7 -> carry = this chaser's activation
	JR	C,XCD3C		; cd31  38 09		; If carry set: chaser is active, jump to assign position

	; --- This chaser is NOT active ---
	LD	(HL),0		; cd33  36 00		; Set chaser X = 0 (marks slot as inactive)
	LD	A,25H		; cd35  3e 25		; A = $25 = 37 (size of chaser data structure)
					;			; We'll add this to HL below to skip to the next chaser
	INC	DE		; cd37  13		; Skip position table byte 0 (X)
	INC	DE		; cd38  13		; Skip position table byte 1 (Y)
	INC	DE		; cd39  13		; Skip position table byte 2 (direction) -- DE at next chaser's data
	JR	XCD4B		; cd3a  18 0f		; Jump to advance HL past this chaser's structure

	; --- This chaser IS active: copy position from table ---
XCD3C:	LD	A,(DE)		; cd3c  1a		; A = chaser X from position table
	LD	(HL),A		; cd3d  77		; Store X into chaser +0
	INC	HL		; cd3e  23		; Advance to chaser +1
	INC	DE		; cd3f  13		; Advance position table to Y byte
	LD	A,(DE)		; cd40  1a		; A = chaser Y from position table
	LD	(HL),A		; cd41  77		; Store Y into chaser +1
	INC	HL		; cd42  23		; Advance to chaser +2 (sprite type, skip it)
	INC	HL		; cd43  23		; Advance to chaser +3 (direction)
	INC	DE		; cd44  13		; Advance position table to direction byte
	LD	A,(DE)		; cd45  1a		; A = chaser initial direction from position table
	LD	(HL),A		; cd46  77		; Store direction into chaser +3
	INC	HL		; cd47  23		; Advance to chaser +4 (now past the fields we needed to set)
	INC	DE		; cd48  13		; Advance DE past direction byte to next chaser in table
	LD	A,21H		; cd49  3e 21		; A = $21 = 33 (remaining bytes in the 37-byte structure)
					;			; We already advanced HL by 4 (X, Y, skip, dir), so 37-4=33

	; --- Advance HL to the start of the next chaser's data structure ---
	; This is a 16-bit addition: HL = HL + A
	; Using the standard Z80 idiom: L += A, then propagate carry into H.
XCD4B:	ADD	A,L		; cd4b  85		; A = L + offset
	LD	L,A		; cd4c  6f		; L = new low byte
	ADC	A,H		; cd4d  8c		; A = H + carry from the addition
	SUB	L		; cd4e  95		; A = H + carry (subtract L back out to isolate H adjustment)
	LD	H,A		; cd4f  67		; H = adjusted high byte
					;			; HL now points to the next chaser's data structure

	DJNZ	XCD2F		; cd50  10 dd		; Decrement B; if chasers remain, loop back

	; --- Final display update: render score area ---
	; CALL XD3F3: updates the HUD attribute area for the score region
	; Parameters: B=row offset, C=col offset, D=height, E=width
	LD	BC,X000E	; cd52  01 0e 00	; B=0, C=14 (column 14 in attr space, relates to HUD positioning)
	LD	DE,X0208	; cd55  11 08 02	; D=8, E=2 (height=8 pixel rows, width=2 chars)
	CALL	XD3F3		; cd58  cd f3 d3	; Update HUD attribute cycling/rendering (effects.asm $D3F3)
	RET			; cd5b  c9		; Return -- level initialization complete!


; ==========================================================================
; XCD5C: SWAP INK AND PAPER IN ATTRIBUTE BYTE
; ==========================================================================
; Called from LEVEL_INIT when $B0EF bit 7 is set (alternate display mode).
; Rearranges the ZX Spectrum attribute byte so that INK and PAPER color
; fields are swapped. This is used for accessibility on monochrome displays.
;
; ZX Spectrum attribute byte format:
;   bit 7     = FLASH
;   bit 6     = BRIGHT
;   bits 5-3  = PAPER color (0-7)
;   bits 2-0  = INK color (0-7)
;
; This routine extracts PAPER -> puts it in INK position,
; and INK -> puts it in PAPER position, preserving FLASH+BRIGHT.
;
; Entry: A = original attribute byte
;        HL is pushed/restored internally
; Exit:  A = attribute with INK and PAPER swapped
; --------------------------------------------------------------------------

XCD5C:	PUSH	HL		; cd5c  e5		; Save HL (caller needs it preserved)
	LD	L,A		; cd5d  6f		; L = original attribute byte (save a copy)

	; --- Extract FLASH+BRIGHT bits (bits 7-6) ---
	AND	0C0H		; cd5e  e6 c0		; A = attribute & $C0 (keep only FLASH + BRIGHT)
	LD	H,A		; cd60  67		; H = FLASH + BRIGHT bits

	; --- Extract PAPER (bits 5-3) and shift right by 3 to get value 0-7 ---
	LD	A,L		; cd61  7d		; A = original attribute
	RRA			; cd62  1f		; Shift right 1 (bit 3 -> bit 2, bit 4 -> bit 3, bit 5 -> bit 4)
	RRA			; cd63  1f		; Shift right 2 (original bit 3 now in bit 1)
	RRA			; cd64  1f		; Shift right 3 (original bits 5-3 now in bits 2-0)
	AND	7		; cd65  e6 07		; Mask to 3 bits: this is the PAPER color value (0-7)
	OR	H		; cd67  b4		; Combine with FLASH+BRIGHT: A = FLASH+BRIGHT+new_INK(=old PAPER)
	LD	H,A		; cd68  67		; H = accumulated result so far

	; --- Extract INK (bits 2-0) and shift left by 3 into PAPER position ---
	LD	A,L		; cd69  7d		; A = original attribute
	RLA			; cd6a  17		; Shift left 1 (bit 0 -> bit 1)
	RLA			; cd6b  17		; Shift left 2 (bit 0 -> bit 2)
	RLA			; cd6c  17		; Shift left 3 (original bits 2-0 now in bits 5-3 = PAPER position)
	AND	38H		; cd6d  e6 38		; Mask to bits 5-3 only: this is old INK in the PAPER field
	OR	H		; cd6f  b4		; Combine everything: FLASH+BRIGHT + new_INK(old PAPER) + new_PAPER(old INK)

	POP	HL		; cd70  e1		; Restore HL
	RET			; cd71  c9		; Return with swapped attribute in A


; ==========================================================================
; DATA TABLE: SPARK BASE POSITIONS ($CD72)
; ==========================================================================
; 8 sparks x 2 bytes (X, Y). These define the center of each spark's
; spawn zone. A random offset is added during init:
;   actual_X = base_X + (PRNG & 7)       -- 0 to 7 pixels right
;   actual_Y = base_Y + (PRNG & 7) * 2   -- 0 to 14 pixels down
;
; The positions form a 3-row x 3-column grid (with center missing):
;   Row 1 (Y=$21=33): X=$1D(29), $3D(61), $5D(93)  -- 3 sparks
;   Row 2 (Y=$35=53): X=$1D(29),          $5D(93)   -- 2 sparks (no center)
;   Row 3 (Y=$49=73): X=$1D(29), $3D(61), $5D(93)  -- 3 sparks
; --------------------------------------------------------------------------

SPARK_POSITIONS:
	DB	1DH,21H,3DH,21H,5DH,21H			; cd72  ; Sparks 0,1,2: (29,33)(61,33)(93,33) -- top row
;
	DEC	E		; cd78  1d		; $1D = Spark 3 base X = 29 (middle-left)
	DEC	(HL)		; cd79  35		; $35 = Spark 3 base Y = 53
	LD	E,L		; cd7a  5d		; $5D = Spark 4 base X = 93 (middle-right)
	DEC	(HL)		; cd7b  35		; $35 = Spark 4 base Y = 53
	DEC	E		; cd7c  1d		; $1D = Spark 5 base X = 29 (bottom-left)
;
	; Note: The disassembler interpreted these data bytes as instructions
	; because they happen to be valid Z80 opcodes. They are actually just
	; raw position data: $49=73(Y), $3D=61(X), $49=73(Y), $5D=93(X), $49=73(Y)
	DB	'I=I]I'					; cd7d  ; Sparks 5(Y),6(X,Y),7(X,Y): (29,73)(61,73)(93,73) -- bottom row


; ==========================================================================
; DATA TABLE: SPARK ACTIVATION MASKS ($CD82)
; ==========================================================================
; 16 bytes, one per level (levels 0-15; higher levels clamp to index 15).
; Each byte is a bitmask controlling which of the 8 sparks are active.
; Bits are consumed via RLC C in the init loop at $CCE1:
;   Bit 7 (first rotated out) = Spark 0
;   Bit 6 = Spark 1
;   Bit 5 = Spark 2
;   ...
;   Bit 0 (last rotated out) = Spark 7
;
; Level 0: $40 = 01000000 -> Spark 1 only (1 spark)
; Level 1: $18 = 00011000 -> Sparks 4,5 (2 sparks)
; Level 2: $A2 = 10100010 -> Sparks 0,2,6 (3 sparks)
; Level 3: $5A = 01011010 -> Sparks 1,3,5,6 (4 sparks)
; ...
; Level 7+: $FF = all 8 sparks
; --------------------------------------------------------------------------

Xcd82:	DB	'@'					; cd82  ; $40 = level 0 mask
	DB	18H,0A2H,5AH				; cd83  ; Levels 1-3: $18, $A2, $5A

	CP	D		; cd86  ba		; $BA = level 4 mask (disassembled as instruction -- actually data)
	CP	L		; cd87  bd		; $BD = level 5 mask
	DB	0FDH,0FFH	; cd88  fd ff		; $FD = level 6, $FF = level 7

	ORG	0CD92H
	; (Levels 8-15 are all $FF = all 8 sparks)


; ==========================================================================
; DATA TABLE: CHASER INITIAL POSITIONS ($CD92)
; ==========================================================================
; 2 chasers x 3 bytes (X, Y, direction), plus one padding byte.
;
; Chaser 1: X=$40(64), Y=$12(18), dir=$00(0=Right)
;   Starts at the center of the top border, moving rightward.
;   The chaser follows walls clockwise by default.
;
; Chaser 2: X=$40(64), Y=$5D(93), dir=$04(4=Left)
;   Starts at the center of the bottom border, moving leftward.
;   The chaser follows walls counter-clockwise relative to chaser 1.
;
; The trailing $00 is padding.
; --------------------------------------------------------------------------

CHASER_POSITIONS:
	DB	40H,12H,0,40H,5DH,4,0			; cd92  ; Chaser 1: (64,18,Right), Chaser 2: (64,93,Left), pad

	ORG	0CD9BH


; ==========================================================================
; DATA TABLE: CHASER ACTIVATION MASKS ($CD9B)
; ==========================================================================
; 16 bytes, one per level (0-15; higher levels clamp to 15).
; Bit 7 = chaser 1 active, bit 6 = chaser 2 active.
; Consumed via RLC C at $CD2F (same technique as spark masks).
;
; Levels 0-5:  $80 = 10000000 -> Chaser 1 only (1 chaser)
; Levels 6-15: $C0 = 11000000 -> Both chasers active (2 chasers)
;
; Note: The disassembler rendered these as Z80 instructions because
; $80 = ADD A,B and $C0 = RET NZ. They are pure data bytes.
; --------------------------------------------------------------------------

CHASER_ACTIVATION:
	ADD	A,B		; cd9b  80		; $80 = level 0: chaser 1 only
	ADD	A,B		; cd9c  80		; $80 = level 1: chaser 1 only
	ADD	A,B		; cd9d  80		; $80 = level 2: chaser 1 only
	ADD	A,B		; cd9e  80		; $80 = level 3: chaser 1 only
	ADD	A,B		; cd9f  80		; $80 = level 4: chaser 1 only
	ADD	A,B		; cda0  80		; $80 = level 5: chaser 1 only
	RET	NZ		; cda1  c0		; $C0 = level 6: both chasers
	RET	NZ		; cda2  c0		; $C0 = level 7: both chasers
	RET	NZ		; cda3  c0		; $C0 = level 8: both chasers
	RET	NZ		; cda4  c0		; $C0 = level 9: both chasers
	RET	NZ		; cda5  c0		; $C0 = level 10: both chasers
	RET	NZ		; cda6  c0		; $C0 = level 11: both chasers
	RET	NZ		; cda7  c0		; $C0 = level 12: both chasers
	RET	NZ		; cda8  c0		; $C0 = level 13: both chasers
	RET	NZ		; cda9  c0		; $C0 = level 14: both chasers
	RET	NZ		; cdaa  c0		; $C0 = level 15: both chasers


; ==========================================================================
; DATA TABLE: LEVEL COLOR TABLE ($CDAB)
; ==========================================================================
; 16 ZX Spectrum attribute bytes, one per level (cycled via level & 0x0F).
; Format: bit 6 = BRIGHT (always set), bits 5-3 = PAPER color, bits 2-0 = INK (always 0 = black).
;
; Raw hex: 70 68 58 60 68 78 68 70 60 58 78 68 70 50 58 68
;
; Decoded PAPER colors:
;   Level  0: $70 -> PAPER 6 = bright yellow     (PAPER = (0x70 >> 3) & 7 = 14 & 7 = 6)
;   Level  1: $68 -> PAPER 5 = bright cyan        (PAPER = (0x68 >> 3) & 7 = 13 & 7 = 5)
;   Level  2: $58 -> PAPER 3 = bright magenta     (wait, $58 >> 3 = 11 & 7 = 3)
;   Level  3: $60 -> PAPER 4 = bright green
;   Level  4: $68 -> PAPER 5 = bright cyan
;   Level  5: $78 -> PAPER 7 = bright white
;   Level  6: $68 -> PAPER 5 = bright cyan
;   Level  7: $70 -> PAPER 6 = bright yellow
;   Level  8: $60 -> PAPER 4 = bright green
;   Level  9: $58 -> PAPER 3 = bright magenta
;   Level 10: $78 -> PAPER 7 = bright white
;   Level 11: $68 -> PAPER 5 = bright cyan
;   Level 12: $70 -> PAPER 6 = bright yellow
;   Level 13: $50 -> PAPER 2 = bright red
;   Level 14: $58 -> PAPER 3 = bright magenta
;   Level 15: $68 -> PAPER 5 = bright cyan
;
; Note: Disassembler rendered these as ASCII strings because they happen
; to be printable characters ('p', 'h', 'X', '`', etc.).
; --------------------------------------------------------------------------

Xcdab:	DB	'phX`hx'				; cdab  ; Levels 0-5:  $70,$68,$58,$60,$68,$78
Xcdb1:	DB	'h'					; cdb1  ; Level 6:     $68
Xcdb2:	DB	'p`'					; cdb2  ; Levels 7-8:  $70,$60
Xcdb4:	DB	'Xx'					; cdb4  ; Levels 9-10: $58,$78
Xcdb6:	DB	'hpPXhp'				; cdb6  ; Levels 11-16: $68,$70,$50,$58,$68,$70
					;			; (Last 2 bytes overlap with XCDBC area -- only 16 are used by LEVEL_INIT)


; ==========================================================================
; XCDBC: COUNT NON-EMPTY CELLS (full bitmap scan)
; ==========================================================================
; Scans the entire game field bitmap ($4000 area) row by row using the
; row pointer lookup table at $FC40. Each row contains 32 bytes, and
; each byte holds 4 cells packed as 2-bit values.
;
; Algorithm:
;   For each of 80 ($50) display rows (via $FC40 table, stepping by 4):
;     For each of 32 bytes in the row:
;       Test each of 4 cell positions (using a rotating $C0 mask)
;       If the masked bits are non-zero: increment cell count (DE)
;
; The mask starts at $C0 (bits 7-6 = cell 0) and rotates right by 2
; each iteration: $C0 -> $30 -> $0C -> $03 -> $C0 (carry set = next byte).
;
; Entry: none
; Exit:  HL = total count of non-empty cells
; Clobbers: A, B, C, DE, IX
;
; Related: CALC_PERCENTAGE at $C780 calls this, then subtracts
;          BORDER_CELL_COUNT (396) and divides by 90 to get percentage.
; --------------------------------------------------------------------------

XCDBC:	LD	IX,XFC40	; cdbc  dd 21 40 fc	; IX = row pointer table base (offset $40 into $FC00 table)
					;			; Each entry is 4 bytes: 2-byte screen addr, 2-byte (attr? or stride)
					;			; Only the first 2 bytes (lo/hi of row address) are used here
	LD	B,50H		; cdc0  06 50		; B = 80 rows to scan ($50 = 80 decimal)
					;			; The game field spans 80 character rows (160 pixel rows / 2)
	LD	DE,X0000	; cdc2  11 00 00	; DE = 0 (cell counter, starts at zero)

XCDC5:	PUSH	BC		; cdc5  c5		; Save outer loop counter (row count)
	LD	L,(IX+0)	; cdc6  dd 6e 00	; L = low byte of this row's bitmap address
XCDC9:	LD	H,(IX+1)	; cdc9  dd 66 01	; H = high byte -- HL now points to start of row in bitmap

	LD	B,20H		; cdcc  06 20		; B = 32 (bytes per row to scan)
	LD	C,0C0H		; cdce  0e c0		; C = $C0 = initial cell mask (bits 7-6 = leftmost cell)

	; --- Inner loop: check each 2-bit cell position ---
XCDD0:	LD	A,(HL)		; cdd0  7e		; A = current bitmap byte
	AND	C		; cdd1  a1		; Mask out one cell's 2 bits
XCDD2:	JR	Z,XCDD5		; cdd2  28 01		; If zero: cell is empty, skip counting
XCDD4:	INC	DE		; cdd4  13		; Non-empty cell found: increment counter

XCDD5:	RRC	C		; cdd5  cb 09		; Rotate mask right by 1 bit
	RRC	C		; cdd7  cb 09		; Rotate mask right by 1 more bit (total: shifted right 2 positions)
					;			; $C0 -> $30 -> $0C -> $03 -> $C0 (wraps, carry gets set)
	JR	NC,XCDD0	; cdd9  30 f5		; If no carry: still within the same byte, check next cell
					;			; When carry is set: we've checked all 4 cells in this byte

	INC	L		; cddb  2c		; Advance to next byte in this row (L++ since rows don't cross page boundaries)
	DJNZ	XCDD0		; cddc  10 f2		; Decrement B (byte count); if bytes remain, continue scanning

	; --- Advance to next row ---
	LD	BC,X0004	; cdde  01 04 00	; BC = 4 (stride in the row pointer table)
	ADD	IX,BC		; cde1  dd 09		; IX += 4 (advance to next row's pointer entry)
	POP	BC		; cde3  c1		; Restore outer loop counter
	DJNZ	XCDC5		; cde4  10 df		; Decrement B (row count); if rows remain, process next row

	EX	DE,HL		; cde6  eb		; HL = DE (move cell count into HL for return value)
	RET			; cde7  c9		; Return with HL = count of all non-empty cells


; ==========================================================================
; XCDE8: COUNT CLAIMED CELLS ONLY (filtered scan)
; ==========================================================================
; Similar to XCDBC above, but with an additional filter step.
; After checking that a cell is non-zero, it XORs the masked bits with
; $55 (the CLAIMED cell pattern). If the result is zero, the cell matches
; the claimed pattern exactly, and it is NOT counted.
;
; Wait -- let's trace the logic more carefully:
;   1. A = (HL) AND C     -- extract cell bits
;   2. If zero: skip (cell is empty)
;   3. XOR $55            -- flip with claimed pattern
;   4. AND C              -- re-mask to just this cell's bits
;   5. If non-zero: skip  (cell is NOT claimed -- it's border or trail)
;   6. INC DE             -- count it
;
; So this actually counts cells that ARE claimed (pattern = $55/$00 in top row).
; The XOR $55 makes claimed cells become zero, and the JR NZ skips if they
; DON'T match -- meaning the INC DE only executes when they DO match.
;
; Actually re-reading: step 5 says JR NZ,XCE06 which SKIPS the INC.
; So: after XOR and re-mask, if result is NZ -> NOT claimed -> skip.
; If result is zero -> IS claimed -> fall through to INC DE.
;
; Entry: none
; Exit:  HL = count of claimed cells (cell value = 1)
; Clobbers: A, B, C, DE, IX
; --------------------------------------------------------------------------

XCDE8:	LD	IX,XFC40	; cde8  dd 21 40 fc	; IX = row pointer table (same base as XCDBC)
XCDEC:	LD	B,50H		; cdec  06 50		; B = 80 rows to scan
	LD	DE,X0000	; cdee  11 00 00	; DE = 0 (claimed cell counter)

XCDF1:	PUSH	BC		; cdf1  c5		; Save row counter
	LD	L,(IX+0)	; cdf2  dd 6e 00	; L = low byte of row's bitmap address
	LD	H,(IX+1)	; cdf5  dd 66 01	; H = high byte -- HL = bitmap row address
	LD	B,20H		; cdf8  06 20		; B = 32 bytes per row
	LD	C,0C0H		; cdfa  0e c0		; C = $C0 (initial cell mask, bits 7-6)

	; --- Inner loop: test each 2-bit cell ---
XCDFC:	LD	A,(HL)		; cdfc  7e		; A = current bitmap byte
	AND	C		; cdfd  a1		; Mask to one cell's 2 bits
	JR	Z,XCE06		; cdfe  28 06		; If zero: cell is empty, skip to next cell

	; --- Cell is non-empty: check if it matches the "claimed" pattern ---
	XOR	55H		; ce00  ee 55		; XOR with $55 (the top-row pattern for claimed cells)
					;			; If the cell was $55 (claimed), the relevant bits become 0
	AND	C		; ce02  a1		; Re-mask to this cell's bit positions
	JR	NZ,XCE06	; ce03  20 01		; If non-zero: cell is NOT claimed (it's border $FF or trail $AA)
					;			; Skip counting

	; --- Cell IS claimed: increment counter ---
	INC	DE		; ce05  13		; Count this claimed cell

XCE06:	RRC	C		; ce06  cb 09		; Rotate mask right 1 bit
	RRC	C		; ce08  cb 09		; Rotate mask right 1 more (total 2 bits shifted)
XCE0A:	JR	NC,XCDFC	; ce0a  30 f0		; If no carry: more cells in this byte, continue
					;			; Carry set = all 4 cells in byte processed

	INC	L		; ce0c  2c		; Next byte in row
	DJNZ	XCDFC		; ce0d  10 ed		; Decrement byte counter; loop if bytes remain

	; --- Next row ---
	LD	BC,X0004	; ce0f  01 04 00	; BC = 4 (row pointer table stride)
	ADD	IX,BC		; ce12  dd 09		; Advance IX to next row entry
	POP	BC		; ce14  c1		; Restore row counter
	DJNZ	XCDF1		; ce15  10 da		; Loop for remaining rows

	EX	DE,HL		; ce17  eb		; HL = claimed cell count
	RET			; ce18  c9		; Return


; ==========================================================================
; XCE19: CLEAR SCREEN BITMAP AND SHADOW GRID
; ==========================================================================
; Zeroes the entire game field in both the screen bitmap ($4000-$57FF)
; and the shadow grid ($6000-$77FF). Called at the start of each level
; from LEVEL_INIT ($CC67) before the border is drawn.
;
; Uses the row pointer table at $FC40 to iterate 160 ($A0) rows.
; For each row:
;   1. Zero 32 bytes at the bitmap address (row in $4000 region)
;   2. Zero 32 bytes at the shadow address (same row but with bit 5
;      of H set, mapping $4xxx -> $6xxx)
;
; The row pointer table entries are spaced 2 bytes apart here (IX advances
; by 2 per row, not 4), because this routine processes individual pixel
; rows rather than cell rows.
;
; Entry: none
; Exit:  Bitmap and shadow grid cleared
; Clobbers: A, B, HL, IX
; --------------------------------------------------------------------------

XCE19:	LD	IX,XFC40	; ce19  dd 21 40 fc	; IX = row pointer table (starting at offset $40)
	LD	B,0A0H		; ce1d  06 a0		; B = 160 rows ($A0 = 160 decimal)
					;			; 80 cell rows x 2 pixel rows each = 160 pixel rows

XCE1F:	PUSH	BC		; ce1f  c5		; Save row counter

	; --- Clear one row of the screen bitmap ($4000 area) ---
	LD	L,(IX+0)	; ce20  dd 6e 00	; L = low byte of this row's screen address
	LD	H,(IX+1)	; ce23  dd 66 01	; H = high byte -- HL = row address in bitmap
	LD	B,20H		; ce26  06 20		; B = 32 (bytes per pixel row)

XCE28:	LD	(HL),0		; ce28  36 00		; Clear this byte to zero
	INC	L		; ce2a  2c		; Next byte in row (L++ is safe, rows don't cross page boundaries)
	DJNZ	XCE28		; ce2b  10 fb		; Loop until all 32 bytes of this row are cleared

	; --- Clear the corresponding row in the shadow grid ($6000 area) ---
	; The shadow grid mirrors the bitmap layout but at $6000 instead of $4000.
	; Setting bit 5 of H maps $40xx-$57xx to $60xx-$77xx.
	LD	L,(IX+0)	; ce2d  dd 6e 00	; Reload L (low byte of row address)
	LD	H,(IX+1)	; ce30  dd 66 01	; Reload H (high byte of row address)
	SET	5,H		; ce33  cb ec		; Set bit 5 of H: $4x -> $6x (bitmap -> shadow)
	LD	B,20H		; ce35  06 20		; B = 32 bytes per row

XCE37:	LD	(HL),0		; ce37  36 00		; Clear this byte to zero
	INC	L		; ce39  2c		; Next byte in row
	DJNZ	XCE37		; ce3a  10 fb		; Loop until all 32 bytes cleared

	; --- Advance to next row in the pointer table ---
	INC	IX		; ce3c  dd 23		; IX += 1 (advancing through row pointer table)
	INC	IX		; ce3e  dd 23		; IX += 1 (total +2 per row: each entry is 2 bytes)
	POP	BC		; ce40  c1		; Restore row counter
	DJNZ	XCE1F		; ce41  10 dc		; Decrement B; loop for remaining rows
	RET			; ce43  c9		; Return -- bitmap and shadow fully cleared


; ==========================================================================
; XCE44: COPY BITMAP TO SHADOW GRID
; ==========================================================================
; Copies the entire game field from the screen bitmap ($4000) to the
; shadow grid ($6000). This is called after flood-fill operations to
; synchronize the shadow with newly-claimed areas. The shadow is what
; sparks and chasers use for navigation -- they need to see claimed cells
; as solid walls.
;
; Iterates 160 ($A0) pixel rows using the row pointer table at $FC40.
; For each row, copies 32 bytes from bitmap address to shadow address
; using Z80's LDIR block copy instruction.
;
; Entry: none
; Exit:  Shadow grid is an exact copy of the bitmap
; Clobbers: A, B, C, DE, HL, IX
; --------------------------------------------------------------------------

XCE44:	LD	IX,XFC40	; ce44  dd 21 40 fc	; IX = row pointer table base
	LD	B,0A0H		; ce48  06 a0		; B = 160 rows to copy

XCE4A:	LD	L,(IX+0)	; ce4a  dd 6e 00	; L = low byte of row's bitmap address
	LD	H,(IX+1)	; ce4d  dd 66 01	; H = high byte -- HL = source (bitmap row)

XCE50:	LD	E,L		; ce50  5d		; E = L (copy low byte for destination)
	LD	D,H		; ce51  54		; D = H (copy high byte for destination)
	SET	5,D		; ce52  cb ea		; Set bit 5 of D: $4x -> $6x (bitmap -> shadow)
					;			; DE now points to the corresponding shadow row

	PUSH	BC		; ce54  c5		; Save row counter
	LD	BC,X0020	; ce55  01 20 00	; BC = 32 (number of bytes to copy per row)
	LDIR			; ce58  ed b0		; Block copy: copy 32 bytes from HL (bitmap) to DE (shadow)
					;			; HL and DE both advance by 32; BC decremented to 0
	POP	BC		; ce5a  c1		; Restore row counter

	; --- Advance to next row ---
	INC	IX		; ce5b  dd 23		; IX += 1
	INC	IX		; ce5d  dd 23		; IX += 1 (total +2 per row entry)
	DJNZ	XCE4A		; ce5f  10 e9		; Decrement B; loop for remaining rows
	RET			; ce61  c9		; Return -- shadow grid now matches bitmap
;
