; ==========================================================================
; PLAYER MOVEMENT & DRAWING ($C7B5-$CA42)
; ==========================================================================
;
; This is the core player movement routine for Zolyx, a Qix-like game.
; It handles two fundamentally different movement modes:
;
; ---- NOT-DRAWING MODE (border walking) ----
;   The player walks along the border of the game field (cells with value 3).
;   Movement is restricted to adjacent border cells only. If the player
;   presses fire while facing an empty cell (value 0), drawing mode begins.
;
; ---- DRAWING MODE (trail cutting) ----
;   The player moves through empty space, leaving a trail behind (value 2).
;   Each trail position is recorded in a buffer at $9000. When the trail
;   reaches a border cell, the trail is converted to border, and a flood
;   fill claims the smaller enclosed area.
;
; ---- Axis Priority System ----
;   When multiple directional keys are pressed simultaneously, the game must
;   decide which axis to try first. Player flags bit 0 at (IX+0) tracks this:
;     bit 0 = 1  =>  last move was HORIZONTAL  =>  try vertical first
;     bit 0 = 0  =>  last move was VERTICAL    =>  try horizontal first
;   This creates smooth corner navigation in border mode: the player
;   "anticipates" turns by preferring the perpendicular axis, so holding a
;   direction before reaching a corner causes an immediate turn.
;   In drawing mode, the priority is reversed (prefer same axis) to prevent
;   accidental diagonal trail cuts.
;
; ---- Speed Control ----
;   During drawing, holding fire activates "fast mode" (bit 4 of player
;   flags). Counterintuitively, this means HALF speed: movement is skipped
;   on odd frames (RRA checks carry = bit 0 of frame counter). Releasing
;   fire clears fast mode for full-speed movement every frame.
;   This gives the player precise control when cutting through empty space.
;
; ---- Trail Cursor ----
;   After 72 frames ($48) of drawing, a trail cursor activates at the start
;   of the trail buffer and begins chasing the player (2 entries/frame).
;   If the cursor catches the player, it triggers a collision/death.
;
; ---- Fill Direction ($C921) ----
;   When the trail reaches a border and fill is triggered:
;   Case A (trail has turns): Sum all direction changes along the trail.
;     Positive sum (net clockwise) => fill to the right of the trail.
;     Negative sum (net counter-clockwise) => fill to the left.
;   Case B (straight horizontal trail): Compare Y to midpoint 55 ($37).
;     Y < 55 => fill upward. Y >= 55 => fill downward.
;   Case C (straight vertical trail): Compare X to midpoint 63 ($3F).
;     X < 63 => fill leftward. X >= 63 => fill rightward.
;   Fill seeds are placed one cell perpendicular to each trail point on
;   the chosen side, then flood fill ($CF01) claims the enclosed area.
;
; ---- Key Data Structures ----
;   IX = $B0E1 (PLAYER_FLAGS)      Player flags byte
;   (IX+0) bit 0: axis flag         1=last horizontal, 0=last vertical
;   (IX+0) bit 4: fast mode         Fire held during drawing (half speed)
;   (IX+0) bit 5: draw axis         0=entered drawing horizontally, 1=vertically
;   (IX+0) bit 6: fill complete     Trail reached border, trigger fill
;   (IX+0) bit 7: drawing           Currently drawing a trail
;   (IX+1) = $B0E2                  Current movement direction (0-7)
;   $B003/$B004 = Player X/Y        Loaded as DE (E=X, D=Y)
;   $B0E4/$B0E5 = DRAW_START        Position where drawing began
;   $B0E6/$B0E7 = TRAIL_WRITE_PTR   Write pointer into trail buffer at $9000
;   $B0E8 = TRAIL_FRAME_CTR         Frame counter (cursor activates at 72)
;   $B0C7 = FRAME_CTR               Global frame counter (for odd/even check)
;   $B0E3 = FILL_CELL_VAL           Cell value used during fill (1=claimed or 2=trail)
;   $B0D1 = DIR_TABLE                Direction deltas: 8 dirs x 2 bytes (dx, dy)
;                                     0=Right(+1,0) 2=Down(0,+1) 4=Left(-1,0) 6=Up(0,-1)
;                                     1=DR(+1,+1) 3=DL(-1,+1) 5=UL(-1,-1) 7=UR(+1,-1)
;
; ---- Called Subroutines ----
;   READ_KEYBOARD ($BA68)            Reads keyboard, returns input bits in C
;   TRY_HORIZONTAL ($CA43)           Try horizontal input -> new E, direction in B, Z flag if no move
;   TRY_VERTICAL ($CA6F)             Try vertical input -> new D, direction in B, Z flag if no move
;   XCEDB ($CEDB)                    Convert coords (D,E) to screen addr, then read cell value
;                                     Returns: A = cell value (0-3), HL = screen address
;   READ_CELL_BMP ($CEDE)            Read cell value from bitmap at HL
;                                     Returns: A = cell value (0=empty, 1=claimed, 2=trail, 3=border)
;   XCEB4 ($CEB4)                    Write cell value A at screen address HL (bitmap only)
;   COORDS_TO_ADDR ($CE8A)           Convert game coords (E=X, D=Y) to screen address HL
;   XCA9B ($CA9B)                    Activate trail cursor at first trail buffer entry
;   XCE44 ($CE44)                    Copy bitmap to shadow grid (sync after fill)
;   CALC_PERCENTAGE ($C780)          Recalculate filled/claimed percentages
;
; ---- Cross-references ----
;   Called from: main_loop.asm (once per frame during gameplay)
;   Calls into: movement_collision.asm (TRY_HORIZONTAL, TRY_VERTICAL, XCA9B)
;               cell_io.asm (XCEDB, READ_CELL_BMP, XCEB4, COORDS_TO_ADDR, XCE44)
;               flood_fill.asm (via FILL_DIRECTION seeding)
;               death_scoring.asm (CALC_PERCENTAGE)
;
; ==========================================================================


;
; ==========================================================================
; PLAYER_MOVEMENT — Main entry point
; ==========================================================================
;
; Called once per frame from the main game loop.
; Reads keyboard input, determines the player's movement mode (border
; walking vs. drawing), applies axis priority, and dispatches to the
; appropriate movement handler.
;
; On entry:
;   No specific register requirements (all loaded internally)
; On exit:
;   Player position at $B003/$B004 may be updated
;   Player flags at $B0E1 may be modified
;   Trail buffer at $9000 may have new entries
;   Fill may be triggered if trail reached border
; Corrupts:
;   AF, BC, DE, HL, IX
; ==========================================================================

; --- Player movement ---
PLAYER_MOVEMENT:
	LD	IX,PLAYER_FLAGS	; c7b5  dd 21 e1 b0	Load IX with address of player flags byte ($B0E1)
				;                       IX+0 = flags, IX+1 = direction ($B0E2)
	CALL	READ_KEYBOARD	; c7b9  cd 68 ba	Read keyboard/joystick input -> C register holds input bits
				;                       C bit 0 = fire, bit 1 = down, bit 2 = up,
				;                       bit 3 = right, bit 4 = left
	LD	DE,(PLAYER_XY)	; c7bc  ed 5b 03 b0	Load current player position: E = X ($B003), D = Y ($B004)
	BIT	7,(IX+0)	; c7c0  dd cb 00 7e	Test bit 7 of player flags: are we currently drawing?
	JP	NZ,XC889	; c7c4  c2 89 c8	If bit 7 is set (drawing mode), jump to DRAWING MODE handler

; --------------------------------------------------------------------------
; NOT-DRAWING MODE (border walking)
; --------------------------------------------------------------------------
; The player is walking along the border. We try to move in the preferred
; axis first (perpendicular to last movement for smooth corner navigation).
; If that fails, try the other axis.
;
; Axis priority: bit 0 of (IX+0)
;   0 = last move was vertical   => try horizontal first ($C7CD)
;   1 = last move was horizontal => try vertical first ($C82B)
; --------------------------------------------------------------------------

	BIT	0,(IX+0)	; c7c7  dd cb 00 46	Test axis flag: was last move horizontal?
	JR	NZ,XC82B	; c7cb  20 5e		If yes (bit 0 = 1), jump ahead to try vertical first

; ==========================================================================
; PATH A: Last move was vertical (axis=0) => try HORIZONTAL first
; ==========================================================================
; Try horizontal movement. If that doesn't yield a valid border cell,
; fall through to try vertical.
; ==========================================================================

	CALL	TRY_HORIZONTAL	; c7cd  cd 43 ca	Try horizontal input: reads bits 3,4 of C register
				;                       On return: Z flag set = no horizontal input
				;                       E = new X (if moved), B = direction (0=right, 4=left)
				;                       Also sets bit 0 of (IX+0) = 1 (horizontal axis)
	JR	Z,XC7FA	; c7d0  28 28		If no horizontal input (Z set), skip to try vertical

; --------------------------------------------------------------------------
; Horizontal input detected (not-drawing, axis=0). Check what's at the
; target cell to decide if the player can move there.
; --------------------------------------------------------------------------

	CALL	XCEDB		; c7d2  cd db ce	Convert coords in D,E to screen addr and read cell value
				;                       Returns: A = cell value at target (0-3), HL = screen addr
	CP	3		; c7d5  fe 03		Is the target cell a border cell (value 3)?
	JP	Z,XC8FA	; c7d7  ca fa c8	If yes, move is valid -> jump to COMMIT_MOVE to update position

; --------------------------------------------------------------------------
; Target is NOT border. Check if we can START drawing here.
; To start drawing: target must be empty (0) AND fire must be pressed.
; --------------------------------------------------------------------------

	OR	A		; c7da  b7		Test if A is zero (target cell is empty)
	JR	NZ,XC7F6	; c7db  20 19		If target is NOT empty (trail=2, claimed=1), can't move -> retry vertical
	BIT	0,C		; c7dd  cb 41		Test fire button (bit 0 of input register C)
	JR	Z,XC7F6	; c7df  28 15		If fire NOT pressed, can't start drawing -> retry vertical

; --------------------------------------------------------------------------
; START DRAWING: Target is empty AND fire is pressed.
; Save the current position as the drawing start point, set drawing flags,
; and proceed to COMMIT_MOVE which will record the first trail point.
; The player entered drawing mode moving HORIZONTALLY, so bit 5 is cleared.
; --------------------------------------------------------------------------

	LD	HL,(PLAYER_XY)	; c7e1  2a 03 b0	Load current player position into HL (before moving)
	LD	(DRAW_START),HL	; c7e4  22 e4 b0	Save as drawing start position at $B0E4/$B0E5
				;                       (Used later if we need to know where drawing began)
	SET	7,(IX+0)	; c7e7  dd cb 00 fe	Set bit 7: player is now in DRAWING mode
	RES	5,(IX+0)	; c7eb  dd cb 00 ae	Clear bit 5: drawing started HORIZONTALLY
				;                       (bit 5 = 0 means horizontal entry; used in fill direction)
	SET	4,(IX+0)	; c7ef  dd cb 00 e6	Set bit 4: fast mode ON (fire is held, so half-speed)
	JP	XC8FA		; c7f3  c3 fa c8	Jump to COMMIT_MOVE to finalize the position update

; --------------------------------------------------------------------------
; Horizontal move failed in not-drawing mode (target was non-border and
; either not empty or fire not pressed). Restore original position and
; fall through to try vertical movement instead.
; --------------------------------------------------------------------------

;
XC7F6:	LD	DE,(PLAYER_XY)	; c7f6  ed 5b 03 b0	Reload original player position (TRY_HORIZONTAL modified E)

; ==========================================================================
; PATH A continued: Try VERTICAL as the second axis
; ==========================================================================
; Same logic as horizontal above, but for the vertical axis.
; ==========================================================================

XC7FA:	CALL	TRY_VERTICAL	; c7fa  cd 6f ca	Try vertical input: reads bits 1,2 of C register
				;                       On return: Z flag set = no vertical input
				;                       D = new Y (if moved), B = direction (2=down, 6=up)
				;                       Also clears bit 0 of (IX+0) (vertical axis)
	JP	Z,XC8E9	; c7fd  ca e9 c8	If no vertical input either, jump to NO_MOVE handler

; --------------------------------------------------------------------------
; Vertical input detected (not-drawing, axis=0, horizontal failed or skipped).
; Check target cell.
; --------------------------------------------------------------------------

	CALL	XCEDB		; c800  cd db ce	Convert coords to screen addr, read cell value -> A
	CP	3		; c803  fe 03		Is target a border cell?
	JP	Z,XC8FA	; c805  ca fa c8	If border, valid move -> jump to COMMIT_MOVE

; --------------------------------------------------------------------------
; Target is not border. Can we start drawing vertically?
; --------------------------------------------------------------------------

	OR	A		; c808  b7		Is target empty (A=0)?
	JR	NZ,XC824	; c809  20 19		If not empty, can't move -> jump to final no-move
	BIT	0,C		; c80b  cb 41		Is fire button pressed?
	JR	Z,XC824	; c80d  28 15		If no fire, can't start drawing -> jump to final no-move

; --------------------------------------------------------------------------
; START DRAWING VERTICALLY: Target is empty, fire pressed, entering from
; vertical direction. Set drawing flags with bit 5 = 1 (vertical entry).
; --------------------------------------------------------------------------

	SET	7,(IX+0)	; c80f  dd cb 00 fe	Set bit 7: enter DRAWING mode
	SET	5,(IX+0)	; c813  dd cb 00 ee	Set bit 5: drawing started VERTICALLY
				;                       (bit 5 = 1 for vertical; used in fill direction logic)
	SET	4,(IX+0)	; c817  dd cb 00 e6	Set bit 4: fast mode ON (fire held)
	LD	HL,(PLAYER_XY)	; c81b  2a 03 b0	Load current position (before moving)
	LD	(DRAW_START),HL	; c81e  22 e4 b0	Save as drawing start point
	JP	XC8FA		; c821  c3 fa c8	Jump to COMMIT_MOVE

; --------------------------------------------------------------------------
; Both axes failed for not-drawing mode (path A). No movement possible.
; --------------------------------------------------------------------------

;
XC824:	LD	DE,(PLAYER_XY)	; c824  ed 5b 03 b0	Reload original position (vertical try modified D)
	JP	XC8E9		; c828  c3 e9 c8	Jump to NO_MOVE handler


; ==========================================================================
; PATH B: Last move was horizontal (axis=1) => try VERTICAL first
; ==========================================================================
; This is the mirror of Path A. When the player's last move was horizontal,
; we try vertical FIRST (perpendicular preference for smooth corner turns),
; then fall back to horizontal.
; ==========================================================================

XC82B:	CALL	TRY_VERTICAL	; c82b  cd 6f ca	Try vertical input first (perpendicular to last move)
	JR	Z,XC858	; c82e  28 28		If no vertical input, skip to try horizontal

; --------------------------------------------------------------------------
; Vertical input detected (not-drawing, axis=1). Check target cell.
; --------------------------------------------------------------------------

	CALL	XCEDB		; c830  cd db ce	Convert coords to screen addr, read cell -> A
	CP	3		; c833  fe 03		Is target a border cell?
	JP	Z,XC8FA	; c835  ca fa c8	If border, valid move -> COMMIT_MOVE

; --------------------------------------------------------------------------
; Not border. Can we start drawing vertically?
; --------------------------------------------------------------------------

	OR	A		; c838  b7		Is target empty?
	JR	NZ,XC854	; c839  20 19		Not empty -> can't move, try horizontal
	BIT	0,C		; c83b  cb 41		Fire pressed?
	JR	Z,XC854	; c83d  28 15		No fire -> can't start drawing, try horizontal

; --------------------------------------------------------------------------
; START DRAWING VERTICALLY (from axis=1 path).
; --------------------------------------------------------------------------

	LD	HL,(PLAYER_XY)	; c83f  2a 03 b0	Save current position before moving
	LD	(DRAW_START),HL	; c842  22 e4 b0	Store as drawing start
	SET	7,(IX+0)	; c845  dd cb 00 fe	Enter DRAWING mode (bit 7)
	RES	5,(IX+0)	; c849  dd cb 00 ae	Clear bit 5: drawing started HORIZONTALLY
				;                       NOTE: Even though we moved vertically here,
				;                       bit 5=0 indicates the entry axis for fill logic
	SET	4,(IX+0)	; c84d  dd cb 00 e6	Fast mode ON (fire held)
	JP	XC8FA		; c851  c3 fa c8	Jump to COMMIT_MOVE

; --------------------------------------------------------------------------
; Vertical move failed. Restore position and try horizontal.
; --------------------------------------------------------------------------

;
XC854:	LD	DE,(PLAYER_XY)	; c854  ed 5b 03 b0	Reload original position

; ==========================================================================
; PATH B continued: Try HORIZONTAL as second axis
; ==========================================================================

XC858:	CALL	TRY_HORIZONTAL	; c858  cd 43 ca	Try horizontal input
	JP	Z,XC8E9	; c85b  ca e9 c8	No horizontal input -> NO_MOVE

; --------------------------------------------------------------------------
; Horizontal input detected (not-drawing, axis=1, vertical failed/skipped).
; --------------------------------------------------------------------------

	CALL	XCEDB		; c85e  cd db ce	Read target cell value -> A
	CP	3		; c861  fe 03		Border cell?
	JP	Z,XC8FA	; c863  ca fa c8	Yes -> COMMIT_MOVE

; --------------------------------------------------------------------------
; Not border. Can we start drawing horizontally?
; --------------------------------------------------------------------------

	OR	A		; c866  b7		Empty?
	JR	NZ,XC882	; c867  20 19		Not empty -> no move
	BIT	0,C		; c869  cb 41		Fire pressed?
	JR	Z,XC882	; c86b  28 15		No fire -> no move

; --------------------------------------------------------------------------
; START DRAWING HORIZONTALLY (from axis=1 path).
; --------------------------------------------------------------------------

	SET	7,(IX+0)	; c86d  dd cb 00 fe	Enter DRAWING mode
	SET	5,(IX+0)	; c871  dd cb 00 ee	Set bit 5: drawing started VERTICALLY
				;                       (bit 5 tracks axis for fill direction)
	SET	4,(IX+0)	; c875  dd cb 00 e6	Fast mode ON
	LD	HL,(PLAYER_XY)	; c879  2a 03 b0	Save current position
	LD	(DRAW_START),HL	; c87c  22 e4 b0	Store as drawing start
	JP	XC8FA		; c87f  c3 fa c8	Jump to COMMIT_MOVE

; --------------------------------------------------------------------------
; Both axes failed. No movement possible.
; --------------------------------------------------------------------------

;
XC882:	LD	DE,(PLAYER_XY)	; c882  ed 5b 03 b0	Reload original position
	JP	XC8E9		; c886  c3 e9 c8	Jump to NO_MOVE


; ==========================================================================
; DRAWING MODE HANDLER ($C889)
; ==========================================================================
;
; Reached when bit 7 of player flags is set (player is drawing a trail).
; This section handles:
;   1. Speed control: fire held = half speed (skip odd frames)
;   2. Movement through empty cells, leaving trail
;   3. Detection of trail reaching border (triggers fill)
;
; On entry:
;   C = keyboard input bits (bit 0 = fire)
;   DE = current player X,Y
;   IX = $B0E1 (player flags)
; ==========================================================================

XC889:	BIT	0,C		; c889  cb 41		Test fire button (bit 0 of input C)
	JR	NZ,XC891	; c88b  20 04		If fire IS pressed, skip (keep fast mode as-is)
	RES	4,(IX+0)	; c88d  dd cb 00 a6	Fire NOT pressed: clear bit 4 (fast mode OFF)
				;                       Player now moves at full speed (every frame)

; --------------------------------------------------------------------------
; Speed control: If fast mode is active (fire held), skip movement on
; odd frames. This effectively halves the drawing speed for precision.
; --------------------------------------------------------------------------

XC891:	BIT	4,(IX+0)	; c891  dd cb 00 66	Is fast mode active (bit 4)?
	JR	Z,XC89D	; c895  28 06		If not, proceed with movement at full speed

	LD	A,(FRAME_CTR)	; c897  3a c7 b0	Load global frame counter ($B0C7)
	RRA			; c89a  1f		Rotate right: bit 0 goes into carry flag
				;                       Carry set = odd frame number
	JR	C,XC8E9	; c89b  38 4c		If odd frame (carry set), skip movement entirely
				;                       -> jump to NO_MOVE (but still increment trail counter)

; ==========================================================================
; DRAWING MODE: Try movement in both axes
; ==========================================================================
; In drawing mode, we try HORIZONTAL first (unlike border mode which
; uses axis priority). If horizontal fails, try vertical.
;
; For each direction:
;   - If target is EMPTY (0): move there, mark as trail -> COMMIT_MOVE
;   - If target is BORDER (3): drawing is complete, trigger fill
;     BUT we also check the SHADOW GRID (SET 5,H flips to $6xxx shadow).
;     Both the bitmap AND shadow must show border for a valid fill.
;     This prevents false fill triggers from visual artifacts.
;   - If target is TRAIL (2) or CLAIMED (1): can't move (no crossing trail)
; ==========================================================================

XC89D:	CALL	TRY_HORIZONTAL	; c89d  cd 43 ca	Try horizontal movement
	JR	Z,XC8C3	; c8a0  28 21		No horizontal input -> try vertical

; --------------------------------------------------------------------------
; Horizontal input in drawing mode. Read target cell.
; --------------------------------------------------------------------------

	CALL	XCEDB		; c8a2  cd db ce	Read target cell at new position -> A = cell value
	OR	A		; c8a5  b7		Is target EMPTY (A=0)?
	JR	Z,XC8FA	; c8a6  28 52		If empty, move there -> COMMIT_MOVE (will mark as trail)

; --------------------------------------------------------------------------
; Target is NOT empty. Could be border (end drawing) or trail/claimed (blocked).
; --------------------------------------------------------------------------

	CP	3		; c8a8  fe 03		Is target a border cell (value 3)?
	JR	NZ,XC8BF	; c8aa  20 13		If NOT border (must be trail=2 or claimed=1), can't move

; --------------------------------------------------------------------------
; Target appears to be border in the bitmap. Verify in the shadow grid too.
; The shadow grid is at $6000-$77FF, exactly $2000 above the bitmap at
; $4000-$57FF. SET 5,H adds $20 to H, which adds $2000 to the address.
; In the shadow grid, trail cells appear as EMPTY (this is how sparks/
; chasers "see through" the trail). We need BOTH grids to confirm border.
; --------------------------------------------------------------------------

	SET	5,H		; c8ac  cb ec		Flip screen addr HL from bitmap ($4xxx) to shadow ($6xxx)
				;                       H bit 5: 0->1, effectively HL += $2000
	CALL	READ_CELL_BMP	; c8ae  cd de ce	Read cell value from shadow grid at same position
				;                       Returns A = cell value from shadow
	CP	3		; c8b1  fe 03		Is shadow cell also border?
	JR	NZ,XC8BF	; c8b3  20 0a		If NOT border in shadow -> can't complete drawing here

; --------------------------------------------------------------------------
; DRAWING COMPLETE: Trail reached a confirmed border cell.
; Clear drawing flag (bit 7) and set fill-complete flag (bit 6).
; The fill will be processed in FILL_DIRECTION below.
; --------------------------------------------------------------------------

	RES	7,(IX+0)	; c8b5  dd cb 00 be	Clear bit 7: no longer in drawing mode
	SET	6,(IX+0)	; c8b9  dd cb 00 f6	Set bit 6: fill is pending (trigger flood fill)
	JR	XC8FA		; c8bd  18 3b		Jump to COMMIT_MOVE (updates position to the border cell)

; --------------------------------------------------------------------------
; Horizontal drawing move failed. Restore position and try vertical.
; --------------------------------------------------------------------------

;
XC8BF:	LD	DE,(PLAYER_XY)	; c8bf  ed 5b 03 b0	Reload original position (E was modified by TRY_HORIZONTAL)

; ==========================================================================
; DRAWING MODE: Try VERTICAL as second axis
; ==========================================================================
; Same logic as horizontal drawing above, mirrored for vertical.
; ==========================================================================

XC8C3:	CALL	TRY_VERTICAL	; c8c3  cd 6f ca	Try vertical movement
	JR	Z,XC8E9	; c8c6  28 21		No vertical input -> NO_MOVE

	CALL	XCEDB		; c8c8  cd db ce	Read target cell -> A
	OR	A		; c8cb  b7		Is target EMPTY?
	JR	Z,XC8FA	; c8cc  28 2c		If empty, valid drawing move -> COMMIT_MOVE

	CP	3		; c8ce  fe 03		Is target BORDER?
	JR	NZ,XC8E5	; c8d0  20 13		Not border -> blocked (trail or claimed)

; --------------------------------------------------------------------------
; Target is border in bitmap. Verify in shadow grid.
; --------------------------------------------------------------------------

	SET	5,H		; c8d2  cb ec		Switch HL to shadow grid address (HL += $2000)
	CALL	READ_CELL_BMP	; c8d4  cd de ce	Read cell from shadow grid
	CP	3		; c8d7  fe 03		Shadow also shows border?
	JR	NZ,XC8E5	; c8d9  20 0a		If not, can't complete drawing

; --------------------------------------------------------------------------
; DRAWING COMPLETE (vertical direction).
; --------------------------------------------------------------------------

	RES	7,(IX+0)	; c8db  dd cb 00 be	Clear drawing flag (bit 7)
	SET	6,(IX+0)	; c8df  dd cb 00 f6	Set fill-complete flag (bit 6)
	JR	XC8FA		; c8e3  18 15		Jump to COMMIT_MOVE

; --------------------------------------------------------------------------
; Vertical drawing move also failed.
; --------------------------------------------------------------------------

;
XC8E5:	LD	DE,(PLAYER_XY)	; c8e5  ed 5b 03 b0	Reload original position


; ==========================================================================
; NO_MOVE HANDLER ($C8E9)
; ==========================================================================
;
; Reached when the player could not move in any direction this frame.
; If the player is currently drawing, we still increment the trail frame
; counter (the clock ticks even when standing still). If the counter
; reaches 72 ($48), the trail cursor is activated.
;
; On entry:
;   IX = $B0E1 (player flags)
; On exit:
;   Trail frame counter may be incremented
;   Trail cursor may be activated
; ==========================================================================

XC8E9:	BIT	7,(IX+0)	; c8e9  dd cb 00 7e	Are we in drawing mode?
	RET	Z		; c8ed  c8		If NOT drawing, nothing to do -> return

; --------------------------------------------------------------------------
; In drawing mode but didn't move. Still increment the trail frame counter.
; The trail cursor timer ticks regardless of movement.
; --------------------------------------------------------------------------

	LD	HL,TRAIL_FRAME_CTR	; c8ee  21 e8 b0	Point HL to trail frame counter ($B0E8)
	INC	(HL)		; c8f1  34		Increment counter (one more frame spent drawing)
	LD	A,(HL)		; c8f2  7e		Load new counter value into A
	CP	48H		; c8f3  fe 48		Has counter reached 72 ($48)?
				;                       Magic constant: 72 frames = ~1.44 seconds at 50fps
	RET	NZ		; c8f5  c0		If not yet 72, return (cursor not activated yet)

; --------------------------------------------------------------------------
; Trail frame counter reached 72: activate the trail cursor.
; The cursor starts at the beginning of the trail buffer and will chase
; the player from behind, advancing 2 entries per frame.
; See XCA9B in movement_collision.asm for cursor initialization.
; --------------------------------------------------------------------------

	CALL	XCA9B		; c8f6  cd 9b ca	Activate trail cursor: set cursor position to first
				;                       trail buffer entry ($9000), store pointer at $B075
	RET			; c8f9  c9		Return to main loop


; ==========================================================================
; COMMIT_MOVE ($C8FA)
; ==========================================================================
;
; The player has successfully determined a valid move. This routine:
;   1. Stores the new position to $B003/$B004
;   2. If drawing: records the new position in the trail buffer at $9000
;      (3 bytes per entry: X, Y, direction), increments write pointer
;   3. Increments trail frame counter and checks for cursor activation
;   4. Falls through to FILL_DIRECTION if fill-complete flag is set
;
; On entry:
;   DE = new player position (E=X, D=Y)
;   IX = $B0E1 (player flags)
;   (IX+1) = current direction (set by TRY_HORIZONTAL/TRY_VERTICAL)
; Trail buffer entry format (3 bytes + terminator):
;   Byte 0: X coordinate
;   Byte 1: Y coordinate
;   Byte 2: direction (0-7)
;   Byte 3: $00 terminator (marks end of buffer)
; ==========================================================================

;
XC8FA:	LD	(PLAYER_XY),DE	; c8fa  ed 53 03 b0	Store new player position to $B003 (X) and $B004 (Y)

	BIT	7,(IX+0)	; c8fe  dd cb 00 7e	Are we in drawing mode?
	JR	Z,FILL_DIRECTION ; c902  28 1d		If NOT drawing, skip trail recording
				;                       -> jump to FILL_DIRECTION (which checks bit 6)

; --------------------------------------------------------------------------
; Record new trail point in the trail buffer at $9000.
; Each entry is 3 bytes: X, Y, direction, followed by a $00 terminator
; at the next position to mark the end of the buffer.
; --------------------------------------------------------------------------

	LD	HL,(TRAIL_WRITE_PTR) ; c904  2a e6 b0	Load current write pointer into trail buffer
				;                       Initially points to $9000 (start of buffer)
	LD	(HL),E		; c907  73		Store X coordinate at current buffer position
	INC	HL		; c908  23		Advance write pointer
	LD	(HL),D		; c909  72		Store Y coordinate
	INC	HL		; c90a  23		Advance write pointer
	LD	A,(IX+1)	; c90b  dd 7e 01	Load current direction from (IX+1) = $B0E2
	LD	(HL),A		; c90e  77		Store direction in trail buffer
	INC	HL		; c90f  23		Advance write pointer past the direction byte
	LD	(HL),0		; c910  36 00		Write $00 terminator at next position
				;                       This marks the end of the trail buffer
	LD	(TRAIL_WRITE_PTR),HL ; c912  22 e6 b0	Save updated write pointer (points to the terminator)

; --------------------------------------------------------------------------
; Increment trail frame counter and check for cursor activation.
; Same logic as in the NO_MOVE handler above.
; --------------------------------------------------------------------------

	LD	HL,TRAIL_FRAME_CTR ; c915  21 e8 b0	Point to trail frame counter
	INC	(HL)		; c918  34		Increment (another frame of drawing)
	LD	A,(HL)		; c919  7e		Load counter value
	CP	48H		; c91a  fe 48		Reached 72? (cursor activation threshold)
	JR	NZ,FILL_DIRECTION ; c91c  20 03		Not yet -> proceed to fill direction check
	CALL	XCA9B		; c91e  cd 9b ca	Counter = 72: activate trail cursor


; ==========================================================================
; FILL_DIRECTION ($C921)
; ==========================================================================
;
; This routine is reached after every successful move. It checks whether
; the fill-complete flag (bit 6) is set, indicating the trail has reached
; a border and the enclosed area needs to be flood-filled.
;
; If fill is pending:
;   1. Determine the fill cell value (claimed=1 or trail=2 based on mode)
;   2. Convert all trail buffer entries from trail to BORDER (value 3)
;      in both the bitmap and shadow grid
;   3. Determine fill direction (which side of the trail to fill)
;   4. Seed flood fill from each trail point, offset perpendicular
;   5. Sync bitmap to shadow grid, recalculate percentage
;   6. Reset trail buffer and cursor
;
; Fill direction algorithm:
;   Case A (trail has turns): Sum direction changes along trail.
;     Positive sum -> fill offset +2 (right of trail direction)
;     Negative sum -> fill offset -2 (left of trail direction)
;   Case B (straight horizontal): Y < 55 -> fill up; Y >= 55 -> fill down
;   Case C (straight vertical): X < 63 -> fill left; X >= 63 -> fill right
;
; On entry:
;   IX = $B0E1 (player flags)
; On exit:
;   If fill was triggered: trail converted to border, area filled,
;   percentage recalculated, trail buffer reset
; ==========================================================================

; --- Fill direction ---
FILL_DIRECTION:
	BIT	6,(IX+0)	; c921  dd cb 00 76	Is fill-complete flag set (bit 6)?
	RET	Z		; c925  c8		If not, no fill needed -> return normally

; --------------------------------------------------------------------------
; Fill is pending! Clear the flag and begin the fill process.
; --------------------------------------------------------------------------

	RES	6,(IX+0)	; c926  dd cb 00 b6	Clear fill-complete flag (bit 6) — one-shot trigger

; --------------------------------------------------------------------------
; Determine the fill cell value. When the player was in "fast mode" (fire
; held, bit 4), use value 1 (CLAIMED/checkerboard). Otherwise use value 2
; (TRAIL pattern). This affects the visual appearance of the filled area.
; NOTE: In practice, the filled area always ends up as CLAIMED (1) after
; the flood fill; this value is what gets written during the fill seeding.
; --------------------------------------------------------------------------

	LD	A,2		; c92a  3e 02		Default fill value = 2 (trail pattern)
	BIT	4,(IX+0)	; c92c  dd cb 00 66	Was fast mode active (fire held during drawing)?
	JR	Z,XC934	; c930  28 02		If NOT fast mode, keep value 2
	LD	A,1		; c932  3e 01		Fast mode was active: fill value = 1 (claimed pattern)
XC934:	LD	(FILL_CELL_VAL),A ; c934  32 e3 b0	Store fill value at $B0E3 (used by flood fill later)

; ==========================================================================
; STEP 1: Convert all trail buffer entries to BORDER (value 3).
; ==========================================================================
; Iterate through the trail buffer at $9000. Each entry is 3 bytes
; (X, Y, direction). The buffer is terminated by a $00 byte at the X
; position. For each entry, write border (3) to both the bitmap ($4xxx)
; and the shadow grid ($6xxx).
; ==========================================================================

	LD	HL,X9000	; c937  21 00 90	Point HL to start of trail buffer

; --------------------------------------------------------------------------
; Loop: convert each trail point to border
; --------------------------------------------------------------------------

XC93A:	LD	A,(HL)		; c93a  7e		Load X coordinate from trail buffer
	OR	A		; c93b  b7		Is it zero? (end-of-buffer terminator)
	JR	Z,XC956	; c93c  28 18		If zero, done converting trail -> jump to direction calc

	LD	E,A		; c93e  5f		E = X coordinate of this trail point
	INC	HL		; c93f  23		Advance to Y byte
	LD	D,(HL)		; c940  56		D = Y coordinate
	INC	HL		; c941  23		Advance past Y
	INC	HL		; c942  23		Advance past direction byte (skip it)
	PUSH	HL		; c943  e5		Save trail buffer pointer on stack

; --------------------------------------------------------------------------
; Write border (3) to this trail position in the BITMAP ($4xxx).
; COORDS_TO_ADDR converts game coords (E=X, D=Y) to screen address HL.
; XCEB4 writes cell value A at address HL using the cell pattern table.
; --------------------------------------------------------------------------

	CALL	COORDS_TO_ADDR	; c944  cd 8a ce	Convert E,D to screen bitmap address -> HL
	LD	A,3		; c947  3e 03		A = 3 (border cell value)
	CALL	XCEB4		; c949  cd b4 ce	Write border pattern to bitmap at HL
				;                       (Writes 2 pixel rows using pattern from $B0C9+6/$B0C9+7)

; --------------------------------------------------------------------------
; Write border (3) to the SHADOW GRID ($6xxx) at the same position.
; SET 5,H adds $2000 to the address, switching from bitmap to shadow.
; --------------------------------------------------------------------------

	SET	5,H		; c94c  cb ec		Flip HL from bitmap ($4xxx) to shadow ($6xxx)
	LD	A,3		; c94e  3e 03		A = 3 (border)
	CALL	XCEB4		; c950  cd b4 ce	Write border to shadow grid
	POP	HL		; c953  e1		Restore trail buffer pointer
	JR	XC93A		; c954  18 e4		Loop to next trail entry


; ==========================================================================
; STEP 2: Determine fill direction
; ==========================================================================
; Now all trail cells have been converted to border. We need to decide
; which side of the trail to flood fill.
;
; First, check if the trail is straight or has turns by comparing the
; first trail direction with the player's current direction.
;
; $9002 contains the direction byte of the FIRST trail entry.
; (IX+1) = $B0E2 = player's current/final direction.
; If they differ, the trail has turns -> use turn-sum algorithm.
; If they match, need to check all intermediate entries too.
; ==========================================================================

XC956:	LD	A,(X9002)	; c956  3a 02 90	Load direction of FIRST trail entry from buffer+2
	LD	C,A		; c959  4f		C = first trail direction (for comparison)
	LD	A,(IX+1)	; c95a  dd 7e 01	Load player's current direction from (IX+1)=$B0E2
	SUB	C		; c95d  91		A = current_dir - first_dir
	JP	Z,XC9CF	; c95e  ca cf c9	If equal (A=0), trail MIGHT be straight -> jump to
				;                       straight-trail handler (needs further checking)

; ==========================================================================
; CASE A: Trail has turns (first dir != last dir)
; ==========================================================================
;
; NOTE: The code from $C961 to $C9CE was not fully disassembled by the
; disassembler tool — it appears as DB (data byte) sequences because the
; disassembler lost sync with the instruction stream. However, based on
; the TypeScript reimplementation and cross-referencing with the game
; logic, this section implements the following algorithm:
;
;   1. Initialize turn sum accumulator (B=0)
;   2. Walk through trail buffer, comparing consecutive direction values
;   3. For each pair, compute diff = next_dir - prev_dir
;   4. Normalize the diff: if +6 then treat as -2 (crossing 0/7 boundary)
;                          if -6 then treat as +2
;   5. Accumulate into turn sum
;   6. After all entries, check sign of sum:
;      Positive (net right/clockwise turns) => fill offset = +2
;      Negative (net left/counter-clockwise) => fill offset = -2
;   7. For each trail point, compute seed = point + DIR_TABLE[dir +/- 2]
;      This places the fill seed one cell perpendicular to the trail,
;      on the side determined by the turn sum.
;   8. Call flood fill from each seed that lands on an empty cell.
;
; The direction values 0-7 map to: 0=R, 1=DR, 2=D, 3=DL, 4=L, 5=UL, 6=U, 7=UR
; Adding 2 rotates 90 degrees clockwise (right), subtracting 2 rotates left.
; The normalizations for +/-6 handle wraparound (e.g., dir 0->6 = -6 -> +2).
;
; Key constants used in the DB sequences:
;   $06 = CP 6 (check for +6 direction difference)
;   $FA = -6 as signed byte (check for -6 direction difference)
;   $18 = JR offset (various relative jumps)
;   $B0D1 = DIR_TABLE address (direction delta lookup)
;   $B0E3 = FILL_CELL_VAL address
;
; The sequence ends with a JR back to XC9A6 which loops through all
; trail entries, seeding flood fill for each one.
; ==========================================================================

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

; --------------------------------------------------------------------------
; FILL SEEDING LOOP (for turn-based fill direction)
; --------------------------------------------------------------------------
; For each trail entry, offset perpendicular to the trail direction by
; the computed fill offset, and seed a flood fill at that position.
; Each trail entry: bytes at (HL) = X, (HL+1) = Y, (HL+2) = direction.
; The fill offset has been computed into C as either +2 or -2.
; --------------------------------------------------------------------------

XC9A6:	LD	A,(HL)		; c9a6  7e		Load X coord from current trail entry
	OR	A		; c9a7  b7		Is it zero? (end of trail buffer)
	JR	Z,XCA29	; c9a8  28 7f		If zero, all entries processed -> jump to CLEANUP

; --------------------------------------------------------------------------
; More trail entries to process. The following DB sequence represents
; the inline code that:
;   1. Loads X, Y, direction from the trail entry
;   2. Computes the perpendicular seed offset using DIR_TABLE at $B0D1:
;      seed_dir = (trail_dir + fill_offset) AND 7
;      seed_x = trail_x + DIR_TABLE[seed_dir*2]      (dx)
;      seed_y = trail_y + DIR_TABLE[seed_dir*2 + 1]  (dy)
;   3. Reads the cell at the seed position
;   4. If empty (0), calls flood fill ($CF01) with the fill cell value
;   5. Advances to next trail entry and loops
;
; References visible in the byte stream:
;   $B0D1 = DIR_TABLE (at bytes c9b7-c9b8)
;   $B0E3 = FILL_CELL_VAL (at bytes c9c6-c9c7)
;   $CF01 = FLOOD_FILL entry point (referenced via CALL)
; --------------------------------------------------------------------------

	DB	'_#V#~#'				; c9aa  ; LD E,A / INC HL / LD D,(HL) / INC HL / LD A,(HL) / INC HL
	DB	0C5H					; c9b0 E  ; PUSH BC (save loop state)
	DW	X81E5		; c9b1   e5 81      ; PUSH HL / ADD A,C (add fill offset to direction)
;
	DB	87H,0E6H,0FH,21H			; c9b3 .f.!  ; ADD A,A / AND $0F / LD HL,...
	DW	DIR_TABLE		; c9b7   d1 b0  ; ...DIR_TABLE ($B0D1) — direction deltas table
;
	DB	85H,6FH,8CH,95H,67H,7BH,86H,5FH		; c9b9 .o..g{._ ; HL = &DIR_TABLE[seed_dir]; seed_x = E + dx
	DB	23H,7AH,86H,57H,3AH			; c9c1 #z.W:   ; seed_y = D + dy; LD A,(...)
	DW	FILL_CELL_VAL		; c9c6   e3 b0  ; Load fill value from $B0E3
	DW	X01CD		; c9c8   cd 01      ; CALL FLOOD_FILL ($CF01)
	DW	XE1CF		; c9ca   cf e1      ; (part of call address) / POP HL
;
	DB	0C1H					; c9cc A  ; POP BC (restore loop state)
;
	JR	XC9A6		; c9cd  18 d7		Loop back to process next trail entry


; ==========================================================================
; CASE B/C: Trail appears straight (first direction == last direction)
; ==========================================================================
;
; We get here when the first and last trail directions match. But the
; trail might still have turns in the middle, so we need to scan all
; intermediate entries. The DB sequences below implement:
;
; CASE B ($C9CF): Straight HORIZONTAL trail (direction 0=right or 4=left)
;   Test bit 1 of first direction (bit 1 is set for directions 2,3,6,7
;   which all have a vertical component). If bit 1 is clear, the trail
;   is horizontal.
;   - Load Y from first trail entry ($9001)
;   - Compare Y to 55 ($37): the vertical midpoint of the field
;     Field Y range is [18, 93], midpoint = (18+93)/2 ~ 55
;   - Y < 55: fill UPWARD (seed_y = trail_y - 1)
;   - Y >= 55: fill DOWNWARD (seed_y = trail_y + 1)
;   - C = fill offset as signed Y delta
;
; CASE C ($C9FF-$CA28): Straight VERTICAL trail (direction 2=down or 6=up)
;   - Load X from first trail entry ($9000)
;   - Compare X to 63 ($3F): the horizontal midpoint of the field
;     Field X range is [2, 125], midpoint = (2+125)/2 ~ 63
;   - X < 63: fill LEFTWARD (seed_x = trail_x - 1)
;   - X >= 63: fill RIGHTWARD (seed_x = trail_x + 1)
;   - C = fill offset as signed X delta
;
; After determining the fill offset, the code seeds flood fill from each
; trail point, similar to Case A but with a simple +/-1 offset instead
; of using the direction table.
;
; Key constants in the DB sequences:
;   $37 = 55 decimal (Y midpoint for horizontal trail decision)
;   $3F = 63 decimal (X midpoint for vertical trail decision)
;   $B0E3 = FILL_CELL_VAL
;   $CF01 = FLOOD_FILL
; ==========================================================================

;
XC9CF:	DB	79H					; c9cf y   ; LD A,C (load first trail direction)
	DW	X02E6		; c9d0   e6 02      ; AND 2 — test bit 1 (vertical component?)
;
	DB	20H					; c9d2     ; JR NZ,... (if vertical, skip to Case C)

; --------------------------------------------------------------------------
; CASE B: Horizontal straight trail — fill above or below based on Y
; --------------------------------------------------------------------------

XC9D3:	DB	2BH,3AH,1,90H				; c9d3 +:.. ; DEC HL / LD A,($9001) — load Y of first trail entry
	DW	X37FE		; c9d7   fe 37      ; CP 55 ($37) — compare Y to field midpoint
;
	DB	9FH,87H,3CH,4FH				; c9d9 ..<O ; SBC A,A / ADD A,A / INC A / LD C,A
				;                       ; If Y<55: carry set -> SBC A,A=$FF -> *2=$FE -> +1=$FF = -1
				;                       ; If Y>=55: no carry -> SBC A,A=$00 -> *2=$00 -> +1=$01 = +1
				;                       ; C = -1 (fill up) or +1 (fill down)

; --------------------------------------------------------------------------
; Seed flood fill for horizontal straight trail.
; For each trail entry with matching direction, seed at (X, Y+C) where
; C is -1 or +1 (up or down).
; --------------------------------------------------------------------------

;
	LD	A,(X9002)	; c9dd  3a 02 90	Reload first trail direction
	LD	B,A		; c9e0  47		B = reference direction (for matching)
	LD	HL,X9000	; c9e1  21 00 90	HL = start of trail buffer
	LD	A,(HL)		; c9e4  7e		Load first X byte
;
	DB	'7'+80h					; c9e5 7  ; (B7 = OR A — test if zero / buffer end marker)
	DB	'(A_'					; c9e6     ; JR Z / ... / LD E,A
Xc9e9:	DB	'#~'					; c9e9     ; INC HL / LD A,(HL) — load Y
	DB	81H					; c9eb .   ; ADD A,C — add fill offset to Y
	DW	X2357		; c9ec   57 23      ; LD D,A / INC HL — D = seed Y
;
	DB	7EH,23H					; c9ee ~#  ; LD A,(HL) / INC HL — load direction
	DW	X20B8		; c9f0   b8 20      ; CP B / JR NZ,... — skip if direction != reference
	DW	XC5F1		; c9f2   f1 c5      ; (jump target for non-matching direction)
;
	DB	0E5H,3AH				; c9f4 e:  ; PUSH HL / LD A,(...)
	DW	FILL_CELL_VAL		; c9f6   e3 b0  ; ...FILL_CELL_VAL ($B0E3)
	DW	X01CD		; c9f8   cd 01      ; CALL FLOOD_FILL ($CF01)
	DW	XE1CF		; c9fa   cf e1      ; (part of address) / POP HL
;
	DB	0C1H,18H,0E5H,3AH,0,90H			; c9fc A.e:.. ; POP BC / JR back / LD A,($9000)
	DW	X3FFE		; ca02   fe 3f      ; CP 63 ($3F) — X midpoint for vertical trail

; --------------------------------------------------------------------------
; CASE C: Vertical straight trail — fill left or right based on X
; --------------------------------------------------------------------------
; The X midpoint is 63 ($3F). X < 63 => fill left (-1), X >= 63 => fill right (+1).
; Same SBC A,A trick: carry flag from CP sets A to $FF or $00, then
; *2+1 gives -1 or +1.
; --------------------------------------------------------------------------

;
	DB	9FH,87H,3CH,4FH,3AH,2,90H,47H		; ca04 ..<O:..G
				; SBC A,A / ADD A,A / INC A / LD C,A — C = xOffset (-1 or +1)
				; LD A,($9002) / LD B,A — B = reference direction
	DB	21H,0,90H,7EH,0B7H,28H,16H,81H		; ca0c !..~7(..
				; LD HL,$9000 / LD A,(HL) / OR A / JR Z,... / ADD A,C
				; — start loop, add X offset to trail X
	DB	'_#V#~#'				; ca14     ; LD E,A / INC HL / LD D,(HL) / INC HL / LD A,(HL) / INC HL
				;                       ; — load trail entry (X+offset, Y, direction)
	DW	X20B8		; ca1a   b8 20      ; CP B / JR NZ,... — skip if dir != reference
	DW	XC5F2		; ca1c   f2 c5      ; (jump target for non-matching)
;
	DB	0E5H,3AH				; ca1e e:  ; PUSH HL / LD A,(...)
	DW	FILL_CELL_VAL		; ca20   e3 b0  ; ...FILL_CELL_VAL ($B0E3)
	DW	X01CD		; ca22   cd 01      ; CALL FLOOD_FILL ($CF01)
	DW	XE1CF		; ca24   cf e1      ; POP HL
;
	DB	0C1H,18H,0E6H				; ca26 A.f ; POP BC / JR back to loop


; ==========================================================================
; CLEANUP: Reset trail state after fill ($CA29)
; ==========================================================================
;
; After all fill seeds have been processed and the flood fill has claimed
; the enclosed area, we need to:
;   1. Reset the trail buffer write pointer to the start ($9000)
;   2. Clear the first two bytes of the trail buffer (end marker)
;   3. Sync the bitmap to the shadow grid (XCE44)
;   4. Recalculate the filled/claimed percentages
;   5. Reset the trail frame counter and trail cursor to inactive
;
; This prepares the state for the next drawing attempt.
; ==========================================================================

;
XCA29:	LD	HL,X9000	; ca29  21 00 90	HL = start of trail buffer ($9000)
	LD	(TRAIL_WRITE_PTR),HL ; ca2c  22 e6 b0	Reset trail write pointer to start of buffer
	LD	(HL),0		; ca2f  36 00		Clear first byte (X = 0 = end marker)
	INC	HL		; ca31  23		Move to second byte
	LD	(HL),0		; ca32  36 00		Clear second byte (Y = 0)

; --------------------------------------------------------------------------
; Sync bitmap to shadow grid. After the fill, the bitmap has new claimed
; cells that the shadow grid doesn't know about yet. XCE44 copies the
; entire bitmap ($4000-$57FF) to the shadow grid ($6000-$77FF) so that
; chasers and sparks can see the newly claimed terrain.
; --------------------------------------------------------------------------

	CALL	XCE44		; ca34  cd 44 ce	Copy bitmap -> shadow grid (full sync)
				;                       See trail_cursor_init.asm for XCE44 implementation

; --------------------------------------------------------------------------
; Recalculate the fill percentage. This counts all non-empty cells in the
; grid and computes: filled% = (non_empty - 396) / 90
; where 396 = number of border cells, 90 = divisor for 100% = 9028 interior cells.
; The result is stored at $B0C5 (raw %) and $B0C6 (filled %).
; The main loop checks if filled% >= 75 for level completion.
; --------------------------------------------------------------------------

	CALL	CALC_PERCENTAGE	; ca37  cd 80 c7	Recalculate and store percentages
				;                       See death_scoring.asm for CALC_PERCENTAGE

; --------------------------------------------------------------------------
; Reset trail tracking state. Clear both the frame counter and the trail
; cursor position. Setting cursor X to 0 deactivates it.
; --------------------------------------------------------------------------

	LD	A,0		; ca3a  3e 00		A = 0 (using LD A,0 instead of XOR A to preserve flags)
				;                       NOTE: Could be XOR A for 1 byte less, but original uses LD
	LD	(TRAIL_FRAME_CTR),A ; ca3c  32 e8 b0	Reset trail frame counter to 0
				;                       Next drawing session starts fresh timer
XCA3F:	LD	(TRAIL_CURSOR),A ; ca3f  32 72 b0	Set trail cursor X to 0 (deactivates cursor)
				;                       Cursor will not be drawn or advanced until reactivated
	RET			; ca42  c9		Return to main game loop
;
