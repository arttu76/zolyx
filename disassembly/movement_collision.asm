; ==========================================================================
; MOVEMENT HELPERS & COLLISION DETECTION ($CA43-$CB02)
; ==========================================================================
;
; This module contains four logically distinct pieces:
;
;   1. TRY_HORIZONTAL ($CA43) -- attempt to move the player left or right
;   2. TRY_VERTICAL   ($CA6F) -- attempt to move the player up or down
;   3. TRAIL CURSOR ACTIVATION ($CA9B) -- initialize the trail cursor
;   4. CHECK_COLLISIONS ($CAA9) -- proximity test against chasers & trail cursor
;
; --------------------------------------------------------------------------
; INPUT BIT ENCODING (register C, from READ_KEYBOARD at $BA68):
;
;   Bit 0 = Fire button
;   Bit 1 = Down
;   Bit 2 = Up
;   Bit 3 = Right
;   Bit 4 = Left
;
; --------------------------------------------------------------------------
; DIRECTION TABLE at $B0D1 (DIR_TABLE), 8 entries of 2 bytes each (dx, dy):
;
;   Index 0 = Right  (+1,  0)       Index 4 = Left  (-1,  0)
;   Index 1 = Down-Right (+1, +1)   Index 5 = Up-Left (-1, -1)
;   Index 2 = Down   ( 0, +1)       Index 6 = Up    ( 0, -1)
;   Index 3 = Down-Left (-1, +1)    Index 7 = Up-Right (+1, -1)
;
; --------------------------------------------------------------------------
; PLAYER DATA STRUCTURES (referenced via IX = $B0E1, PLAYER_FLAGS):
;
;   (IX+0) = Player flags byte:
;              bit 0: axis flag (1=horizontal last, 0=vertical last)
;              bit 4: fast/slow mode (fire held = half speed)
;              bit 5: draw direction flag (used in fill logic)
;              bit 6: fill-complete flag (trail reached border)
;              bit 7: currently drawing a trail
;   (IX+1) = Player direction index (0/2/4/6 = right/down/left/up)
;
;   PLAYER_XY ($B003-$B004): E=X position, D=Y position
;     (loaded as 16-bit: LD DE,(PLAYER_XY) gives E=low byte=X, D=high byte=Y)
;
; --------------------------------------------------------------------------
; FIELD COORDINATE BOUNDS:
;
;   X range: [2, 125]  ($02 to $7D)   -- full field including border
;   Y range: [18, 93]  ($12 to $5D)   -- full field including border
;
; ==========================================================================


; ==========================================================================
; TRY_HORIZONTAL ($CA43)
; ==========================================================================
;
; Attempts to compute a new horizontal position from joystick input.
;
; ENTRY:
;   C  = input bits from keyboard (bit 3=right, bit 4=left)
;   E  = current player X position
;   D  = current player Y position
;   IX = pointer to PLAYER_FLAGS ($B0E1)
;
; EXIT:
;   If no horizontal movement (both or neither left/right pressed):
;     Z flag SET (zero), registers unchanged
;     Returns immediately via RET Z
;
;   If horizontal movement computed:
;     E  = new X position (clamped to [2, 125])
;     B  = direction index (0=right, 4=left), stored into (IX+1)
;     (IX+0) bit 0 SET to mark last movement axis as horizontal
;     Z flag CLEAR (non-zero) if position actually changed
;     Z flag SET if new position equals old position (clamped at boundary)
;
; ALGORITHM:
;   1. Extract bits 3 and 4 from input (right and left)
;   2. If both pressed or neither pressed, return with Z set (no movement)
;   3. Start with A = current X
;   4. If left pressed: decrement A, set direction = 4 (left)
;   5. If right pressed: increment A, set direction = 0 (right)
;   6. Clamp A to range [2, 125] (field boundaries)
;   7. Store direction in (IX+1), set horizontal axis flag in (IX+0)
;   8. Compare new X with old X to set/clear Z flag, update E
;
; ==========================================================================

; --- Try horizontal ---
TRY_HORIZONTAL:	LD	A,C		; ca43  79		Load input bits into A
	AND	18H		; ca44  e6 18		Isolate bits 3 (right) and 4 (left): mask $18 = 00011000
	RET	Z		; ca46  c8		If neither left nor right is pressed, return (Z=1, no movement)
	CP	18H		; ca47  fe 18		Check if BOTH left and right are pressed simultaneously
	RET	Z		; ca49  c8		If both pressed, return (Z=1, conflicting input = no movement)
	LD	A,E		; ca4a  7b		Load current player X position into A
	BIT	4,C		; ca4b  cb 61		Test bit 4 of input: is LEFT pressed?
	JR	Z,XCA52		; ca4d  28 03		If left NOT pressed, skip the decrement (jump to right check)
	DEC	A		; ca4f  3d		Left is pressed: decrement X by 1 (move left)
	LD	B,4		; ca50  06 04		Set direction index to 4 (= Left in direction table)
XCA52:	BIT	3,C		; ca52  cb 59		Test bit 3 of input: is RIGHT pressed?
	JR	Z,XCA59		; ca54  28 03		If right NOT pressed, skip the increment (proceed to clamping)
	INC	A		; ca56  3c		Right is pressed: increment X by 1 (move right)
	LD	B,0		; ca57  06 00		Set direction index to 0 (= Right in direction table)
XCA59:	CP	2		; ca59  fe 02		Compare new X against left boundary (X=2)
	JR	NC,XCA5F	; ca5b  30 02		If X >= 2, it's within bounds -- skip clamping
	LD	A,2		; ca5d  3e 02		Clamp X to minimum: X = 2 (left edge of field)
XCA5F:	CP	7EH		; ca5f  fe 7e		Compare new X against right boundary + 1 (126 = $7E)
	JR	C,XCA65		; ca61  38 02		If X < 126 (i.e., X <= 125), it's within bounds -- skip clamping
	LD	A,7DH		; ca63  3e 7d		Clamp X to maximum: X = 125 ($7D, right edge of field)
XCA65:	LD	(IX+1),B	; ca65  dd 70 01	Store the computed direction index into player direction slot
	SET	0,(IX+0)	; ca68  dd cb 00 c6	Set bit 0 of player flags: mark last movement as HORIZONTAL
	CP	E		; ca6c  bb		Compare new X (in A) with old X (in E) -- sets Z if unchanged
	LD	E,A		; ca6d  5f		Store new X position back into E register
	RET			; ca6e  c9		Return; Z flag indicates whether position actually changed
;


; ==========================================================================
; TRY_VERTICAL ($CA6F)
; ==========================================================================
;
; Attempts to compute a new vertical position from joystick input.
; Mirror image of TRY_HORIZONTAL but for the Y axis.
;
; ENTRY:
;   C  = input bits from keyboard (bit 1=down, bit 2=up)
;   D  = current player Y position
;   E  = current player X position
;   IX = pointer to PLAYER_FLAGS ($B0E1)
;
; EXIT:
;   If no vertical movement (both or neither up/down pressed):
;     Z flag SET (zero), registers unchanged
;     Returns immediately via RET Z
;
;   If vertical movement computed:
;     D  = new Y position (clamped to [18, 93])
;     B  = direction index (2=down, 6=up), stored into (IX+1)
;     (IX+0) bit 0 CLEARED to mark last movement axis as vertical
;     Z flag CLEAR (non-zero) if position actually changed
;     Z flag SET if new position equals old position (clamped at boundary)
;
; ALGORITHM:
;   1. Extract bits 1 and 2 from input (down and up)
;   2. If both pressed or neither pressed, return with Z set (no movement)
;   3. Start with A = current Y
;   4. If up pressed: decrement A, set direction = 6 (up)
;   5. If down pressed: increment A, set direction = 2 (down)
;   6. Clamp A to range [18, 93] (field boundaries)
;   7. Store direction in (IX+1), clear horizontal axis flag in (IX+0)
;   8. Compare new Y with old Y to set/clear Z flag, update D
;
; ==========================================================================

; --- Try vertical ---
TRY_VERTICAL:	LD	A,C		; ca6f  79		Load input bits into A
	AND	6		; ca70  e6 06		Isolate bits 1 (down) and 2 (up): mask $06 = 00000110
	RET	Z		; ca72  c8		If neither up nor down is pressed, return (Z=1, no movement)
	CP	6		; ca73  fe 06		Check if BOTH up and down are pressed simultaneously
	RET	Z		; ca75  c8		If both pressed, return (Z=1, conflicting input = no movement)
	LD	A,D		; ca76  7a		Load current player Y position into A
	BIT	2,C		; ca77  cb 51		Test bit 2 of input: is UP pressed?
	JR	Z,XCA7E		; ca79  28 03		If up NOT pressed, skip the decrement (jump to down check)
	DEC	A		; ca7b  3d		Up is pressed: decrement Y by 1 (move up, Y decreases)
	LD	B,6		; ca7c  06 06		Set direction index to 6 (= Up in direction table)
XCA7E:	BIT	1,C		; ca7e  cb 49		Test bit 1 of input: is DOWN pressed?
	JR	Z,XCA85		; ca80  28 03		If down NOT pressed, skip the increment (proceed to clamping)
	INC	A		; ca82  3c		Down is pressed: increment Y by 1 (move down, Y increases)
	LD	B,2		; ca83  06 02		Set direction index to 2 (= Down in direction table)
XCA85:	CP	12H		; ca85  fe 12		Compare new Y against top boundary (Y=18, $12)
	JR	NC,XCA8B	; ca87  30 02		If Y >= 18, it's within bounds -- skip clamping
	LD	A,12H		; ca89  3e 12		Clamp Y to minimum: Y = 18 (top edge of field)
XCA8B:	CP	5EH		; ca8b  fe 5e		Compare new Y against bottom boundary + 1 (94 = $5E)
	JR	C,XCA91		; ca8d  38 02		If Y < 94 (i.e., Y <= 93), it's within bounds -- skip clamping
	LD	A,5DH		; ca8f  3e 5d		Clamp Y to maximum: Y = 93 ($5D, bottom edge of field)
XCA91:	LD	(IX+1),B	; ca91  dd 70 01	Store the computed direction index into player direction slot
	RES	0,(IX+0)	; ca94  dd cb 00 86	Clear bit 0 of player flags: mark last movement as VERTICAL
	CP	D		; ca98  ba		Compare new Y (in A) with old Y (in D) -- sets Z if unchanged
	LD	D,A		; ca99  57		Store new Y position back into D register
	RET			; ca9a  c9		Return; Z flag indicates whether position actually changed
;


; ==========================================================================
; TRAIL CURSOR ACTIVATION ($CA9B)
; ==========================================================================
;
; Called when the trail frame counter reaches 72 ($48), meaning the player
; has been drawing a trail for 72 frames. This initializes the trail cursor
; which will chase the player along the trail from behind, erasing it.
; If the cursor catches the player (buffer exhausted), the player dies.
;
; The trail buffer at $9000 stores 3 bytes per trail point:
;   byte 0: X coordinate
;   byte 1: Y coordinate
;   byte 2: direction
;   byte 3: terminator (0)
;
; The first entry in the buffer ($9000) contains a 16-bit pointer to the
; actual first trail coordinate pair. This routine reads that pointer and
; sets the trail cursor's initial position.
;
; ENTRY:
;   No specific register requirements.
;
; EXIT:
;   HL = first trail point coordinates (stored to TRAIL_CURSOR at $B072)
;   ($B075) = pointer into trail buffer (for advancing the cursor later)
;   E, D modified (loaded from trail buffer)
;
; CROSS-REFERENCES:
;   Called from PLAYER_MOVEMENT at $C8F6 and $C91E when trail frame
;   counter reaches 72.
;   Trail cursor is subsequently advanced by MOVE_TRAIL_CURSOR at $CBFE
;   (in trail_cursor_init.asm), called from main loop at $C527.
;
; ==========================================================================

XCA9B:	LD	HL,X9000	; ca9b  21 00 90	Load HL with address of trail buffer start ($9000)
	LD	(XB075),HL	; ca9e  22 75 b0	Store trail buffer pointer at $B075 (cursor read position)
	LD	E,(HL)		; caa1  5e		Load low byte (X coord) of first trail entry into E
	INC	HL		; caa2  23		Advance pointer to next byte in trail buffer
	LD	D,(HL)		; caa3  56		Load high byte (Y coord) of first trail entry into D
	EX	DE,HL		; caa4  eb		Swap DE and HL: now HL = (X, Y) coordinates of first trail point
	LD	(TRAIL_CURSOR),HL	; caa5  22 72 b0	Store trail cursor position at $B072 (L=X, H=Y)
	RET			; caa8  c9		Return -- trail cursor is now active at the trail's starting point
;


; ==========================================================================
; CHECK_COLLISIONS ($CAA9)
; ==========================================================================
;
; Tests the player's position against three potential threats:
;   1. Chaser 1 (wall-following enemy)
;   2. Chaser 2 (wall-following enemy)
;   3. Trail cursor (the erasing cursor that chases the player's trail)
;
; COLLISION ALGORITHM:
;   For each enemy, the routine computes the absolute distance on both
;   axes between the player and the enemy:
;     |player.Y - enemy.Y| and |player.X - enemy.X|
;   If BOTH distances are less than 2 pixels, it's a collision.
;   This creates a 3x3 pixel collision box centered on each entity
;   (distance 0 or 1 on each axis).
;
;   The Y coordinate is stored in the HIGH byte (H) and X in the LOW
;   byte (L) of each entity's data word, matching the (X,Y) = (E,D)
;   layout where LD HL,(...) gives H=Y, L=X.
;
; ENTRY:
;   No specific register requirements. Reads player and enemy positions
;   from their fixed memory locations.
;
; EXIT:
;   Carry flag SET = collision detected (player touching an enemy)
;   Carry flag CLEAR = no collision
;   D = player Y position
;   E = player X position
;
; CROSS-REFERENCES:
;   Chaser 1 data: $B028 (CHASER1_DATA) -- H=Y byte ($B029), L=X byte ($B028)
;   Chaser 2 data: $B04D (CHASER2_DATA) -- H=Y byte ($B04E), L=X byte ($B04D)
;   Trail cursor:  $B072 (TRAIL_CURSOR) -- H=Y byte ($B073), L=X byte ($B072)
;   Player pos:    $B003 (PLAYER_XY)    -- D=Y byte ($B004), E=X byte ($B003)
;
;   Called from main game loop. If carry is returned set, the caller
;   sets bit 0 of $B0C8 (STATE_FLAGS) to signal a collision/death.
;   Death handling is in death_scoring.asm.
;
; ==========================================================================


; -------------------------------------------------------
; PHASE 1: Check collision with Chaser 1
; -------------------------------------------------------
; Load chaser 1's position (H=Y, L=X) and player position (D=Y, E=X).
; Compute |chaser1.Y - player.Y|; if >= 2, skip to chaser 2.
; Then compute |chaser1.X - player.X|; if >= 2, skip to chaser 2.
; If both < 2: collision detected, return with carry set.
; -------------------------------------------------------

; --- Check collisions ---
CHECK_COLLISIONS:	LD	HL,(CHASER1_DATA)	; caa9  2a 28 b0	Load chaser 1 position: L=X ($B028), H=Y ($B029)
	LD	DE,(PLAYER_XY)	; caac  ed 5b 03 b0	Load player position: E=X ($B003), D=Y ($B004)
	LD	A,H		; cab0  7c		A = chaser 1 Y coordinate
	SUB	D		; cab1  92		A = chaser1.Y - player.Y (signed result)
	JP	P,XCAB7		; cab2  f2 b7 ca	If result is positive (chaser below or same), skip negation
	NEG			; cab5  ed 44		Result was negative (chaser above): negate to get absolute value
XCAB7:	CP	2		; cab7  fe 02		Is |deltaY| >= 2?
	JR	NC,XCAC8	; cab9  30 0d		If distance >= 2 on Y axis, no collision with chaser 1 -- try chaser 2
	LD	A,L		; cabb  7d		A = chaser 1 X coordinate
	SUB	E		; cabc  93		A = chaser1.X - player.X (signed result)
	JP	P,XCAC2		; cabd  f2 c2 ca	If result is positive (chaser to right or same), skip negation
	NEG			; cac0  ed 44		Result was negative (chaser to left): negate to get absolute value
XCAC2:	CP	2		; cac2  fe 02		Is |deltaX| >= 2?
	JR	NC,XCAC8	; cac4  30 02		If distance >= 2 on X axis, no collision -- try chaser 2
	SCF			; cac6  37		COLLISION! Set carry flag to signal player has been hit
	RET			; cac7  c9		Return with carry SET -- chaser 1 killed the player
;


; -------------------------------------------------------
; PHASE 2: Check collision with Chaser 2
; -------------------------------------------------------
; Same algorithm as phase 1, but using chaser 2's position.
; DE (player position) is still valid from the load above.
; -------------------------------------------------------

XCAC8:	LD	HL,(CHASER2_DATA)	; cac8  2a 4d b0	Load chaser 2 position: L=X ($B04D), H=Y ($B04E)
	LD	A,H		; cacb  7c		A = chaser 2 Y coordinate
	SUB	D		; cacc  92		A = chaser2.Y - player.Y (signed result)
	JP	P,XCAD2		; cacd  f2 d2 ca	If result is positive or zero, skip negation
	NEG			; cad0  ed 44		Negate to get absolute value of Y distance
XCAD2:	CP	2		; cad2  fe 02		Is |deltaY| >= 2?
	JR	NC,XCAE3	; cad4  30 0d		If distance >= 2 on Y axis, no collision with chaser 2 -- try trail cursor
	LD	A,L		; cad6  7d		A = chaser 2 X coordinate
	SUB	E		; cad7  93		A = chaser2.X - player.X (signed result)
	JP	P,XCADD		; cad8  f2 dd ca	If result is positive or zero, skip negation
	NEG			; cadb  ed 44		Negate to get absolute value of X distance
XCADD:	CP	2		; cadd  fe 02		Is |deltaX| >= 2?
	JR	NC,XCAE3	; cadf  30 02		If distance >= 2 on X axis, no collision -- try trail cursor
	SCF			; cae1  37		COLLISION! Set carry flag to signal player has been hit
	RET			; cae2  c9		Return with carry SET -- chaser 2 killed the player
;


; -------------------------------------------------------
; PHASE 3: Check collision with Trail Cursor
; -------------------------------------------------------
; The trail cursor is the erasing head that chases the player's trail
; from behind. It activates after 72 frames of drawing. If its X
; coordinate is 0, the cursor is inactive (no collision possible).
; However, since X=0 is far from the field (field starts at X=2),
; the distance check will naturally fail, so no explicit active check
; is needed here.
;
; Same absolute-distance algorithm as phases 1 and 2.
; -------------------------------------------------------

XCAE3:	LD	HL,(TRAIL_CURSOR)	; cae3  2a 72 b0	Load trail cursor position: L=X ($B072), H=Y ($B073)
	LD	A,H		; cae6  7c		A = trail cursor Y coordinate
	SUB	D		; cae7  92		A = cursor.Y - player.Y (signed result)
	JP	P,XCAED		; cae8  f2 ed ca	If result is positive or zero, skip negation
	NEG			; caeb  ed 44		Negate to get absolute value of Y distance
XCAED:	CP	2		; caed  fe 02		Is |deltaY| >= 2?
	JR	NC,XCAFE	; caef  30 0d		If distance >= 2 on Y axis, no collision with cursor -- no collision at all
	LD	A,L		; caf1  7d		A = trail cursor X coordinate
	SUB	E		; caf2  93		A = cursor.X - player.X (signed result)
	JP	P,XCAF8		; caf3  f2 f8 ca	If result is positive or zero, skip negation
	NEG			; caf6  ed 44		Negate to get absolute value of X distance
XCAF8:	CP	2		; caf8  fe 02		Is |deltaX| >= 2?
	JR	NC,XCAFE	; cafa  30 02		If distance >= 2 on X axis, no collision -- fall through to "no collision"
	SCF			; cafc  37		COLLISION! Set carry flag -- trail cursor caught the player
	RET			; cafd  c9		Return with carry SET -- trail cursor killed the player
;


; -------------------------------------------------------
; NO COLLISION EXIT
; -------------------------------------------------------
; All three checks passed without detecting a collision.
; Clear the carry flag to indicate the player is safe.
; -------------------------------------------------------

XCAFE:	OR	A		; cafe  b7		OR A with itself: clears carry flag (and sets Z if A=0, but irrelevant)
	RET			; caff  c9		Return with carry CLEAR -- no collision detected
;


; -------------------------------------------------------
; PADDING / UNUSED BYTES ($CB00-$CB02)
; -------------------------------------------------------
; Three NOP bytes at the end of this block. These may be:
;   - Alignment padding to reach a specific address boundary
;   - Leftover space from a previous version of the code
;   - Reserved space that was never used
; -------------------------------------------------------

XCB00:	NOP			; cb00  00		Unused byte (no operation)
XCB01:	NOP			; cb01  00		Unused byte (no operation)
XCB02:	NOP			; cb02  00		Unused byte (no operation)
