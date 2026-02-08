; ==========================================================================
; MAIN GAME LOOP & LEVEL COMPLETE ($C371-$C616)
; ==========================================================================
;
; This is the heart of the Zolyx game engine. It contains the game entry
; point, the per-frame main loop, and the level-complete sequence. Zolyx
; is a Qix-like territory-claiming game: the player walks along a border,
; draws trails through empty space, and triggers flood-fill to claim
; territory. The game runs at a locked 50fps (PAL ZX Spectrum HALT sync).
;
; -----------------------------------------------------------------------
; GAME ENTRY ($C371):
;   Called from the menu system after the player presses start.
;   Initializes the first level then falls through to the main loop.
;   $C374: CALL $CC5A (LEVEL_INIT) then fall through to main loop.
;   $C377: Restart level after death (entities reset, grid preserved).
;
; MAIN LOOP ($C3DC):
;   Executes once per frame, synchronized to 50Hz via HALT.
;   Order of operations each frame:
;     1. Increment frame counter ($B0C7)
;     2. HALT (wait for vertical blank interrupt)
;     3. Erase all entities at old positions (restore saved backgrounds)
;     4. Erase sparks by writing empty cells at their old positions
;     5. If player is drawing, redraw the trail cell under the player
;     6. Process player movement and input ($C7B5)
;     7. Save new background pixels under each entity position
;     8. Check spark positions for trail collision (spark on trail cell)
;     9. Draw sparks at their new positions (cell pattern 3=border look)
;    10. Draw entities: player, trail cursor, chaser 1, chaser 2
;    11. Play sounds based on state flags (bit 6=cursor, bit 7=bounce)
;    12. Check player-enemy collisions ($CAA9)
;    13. Move chaser 1 ($CB03), chaser 2 ($CB03) — wall-following AI
;    14. Move all 8 sparks ($D18A x 8) — diagonal bouncing
;    15. Move trail cursor ($CBFE) — chases player along trail buffer
;    16. Decrement timer (sub-counter at $B0E9, main at $B0C0)
;    17. Update score display ($D27A)
;    18. Update timer bar animation ($D2C1)
;    19. Check pause key ($C617)
;    20. Check state flags ($B0C8):
;        bit 1 set -> timer expired -> death/game over
;        bit 0 set -> collision -> lose life
;        bit 2 set -> level complete (>=75%) -> celebrate -> next level
;        none set -> loop back to $C3DC
;
; LEVEL COMPLETE ($C55D):
;   Triggered when filled percentage >= 75%. Sequence:
;     1. Dim field (clear BRIGHT bit on all field attributes)
;     2. Draw popup rectangle at rows 11-15, cols 8-23 (bright cyan)
;     3. Print "Screen Completed" text in popup
;     4. Rainbow color cycling: 16 steps x 2 frames = 32 frames = 640ms
;        Cycles PAPER bits (3-5) through all 8 ZX colors twice
;     5. Finalize percentage into score: score += (raw% + fill%) * 4
;     6. Sync timer bar display to match actual timer value
;     7. Timer-to-score countdown: each remaining timer tick = +1 point
;        Animated: timer bar shrinks, score increments, 40ms per tick
;        Max duration: 176 ticks x 40ms = ~7 seconds
;     8. Post-countdown pause: 50 frames = 1.0 second
;     9. Restore screen (undo popup, redraw underlying graphics)
;    10. Increment level number ($B0C1), jump to LEVEL_INIT ($CC5A)
;
; STRINGS embedded after code:
;   $C5BB: "Screen Completed" (with position/color control bytes)
;   $C5D1: "All Screens Completed" (unused/dead code — never reached)
;   $C5EC: "Game Paused" / "Continue" / "Abort" (pause menu strings)
;
; -----------------------------------------------------------------------
; MEMORY MAP REFERENCES:
;   $B003-$B004  Player X,Y position (E=X, D=Y when loaded as 16-bit)
;   $B028        Chaser 1 data structure (37 bytes)
;   $B04D        Chaser 2 data structure (37 bytes)
;   $B072        Trail cursor state (X,Y,pointer)
;   $B097-$B0BC  Spark array: 8 sparks x 5 bytes each
;   $B099+       Spark old positions (for erase): every 5th byte pair
;   $B0BF        Timer bar display position
;   $B0C0        Game timer (countdown from 176 = $B0)
;   $B0C1        Level number (0-based)
;   $B0C2        Lives remaining
;   $B0C3-$B0C4  Base score (16-bit little-endian)
;   $B0C5        Raw claimed percentage
;   $B0C6        Filled percentage
;   $B0C7        Frame counter (wraps at 256)
;   $B0C8        Game state flags
;   $B0E1        Player flags (drawing, axis, speed, fill-complete)
;   $B0E6-$B0E7  Trail buffer write pointer (into $9000 region)
;   $B0E8        Trail frame counter (cursor activates at 72)
;   $B0E9        Timer sub-counter (counts down from 14)
;   $B0EA        Timer speed reload value (14 = $0E)
;   $9000-$93FF  Trail buffer (3 bytes/entry: X, Y, direction)
; -----------------------------------------------------------------------


; ==========================================================================
; GAME ENTRY POINT ($C371)
; ==========================================================================
; Called from the menu system. This is a slightly unusual entry sequence:
; the DW at $C371 is actually the tail end of the menu's CALL instruction
; with an embedded byte. The real game initialization starts at $C374.
;
GAME_ENTRY:
	DW	X40CD		; c371   cd 40      M@
;
	DB	0CCH					; c373 L
;


; ==========================================================================
; LEVEL START ($C374)
; ==========================================================================
; Entry point when starting a brand new level (after level complete or
; game start). Calls LEVEL_INIT which clears the screen, draws the border,
; sets up colors, spawns sparks/chasers, and calculates initial percentage.
;
; Routine: LEVEL_INIT ($CC5A) — see trail_cursor_init.asm
;   Sets timer to 176, clears state flags, loads level color, draws
;   border, initializes all entities, calculates initial percentage (0%).
;
LEVEL_START:	CALL	LEVEL_INIT		; c374  cd 5a cc	MZL


; ==========================================================================
; RESTART LEVEL ($C377)
; ==========================================================================
; Entry point after player death (lives > 0). The game grid is preserved
; (claimed territory stays), but entities are reset to starting positions
; and the trail buffer is cleared. This is also the fall-through from
; LEVEL_START above.
;
; On entry: Grid state preserved, entities need re-initialization.
; On exit:  Falls through to MAIN_LOOP after setup and initial pause.
;
; Steps:
;   1. Reset trail buffer write pointer to start ($9000)
;   2. Clear state flags (no collision, no timer expired, no level complete)
;   3. Redraw HUD lives counter
;   4. Save sprite backgrounds for all 4 main entities
;   5. Draw all 4 entities at their positions
;   6. Draw all 8 sparks as border-colored cells
;   7. Play INK cycling animation on the timer bar area
;   8. Pause 50 frames (1 second) to let the player get ready
;
RESTART_LEVEL:	LD	HL,X9000	; c377  21 00 90	!..     ; HL = start of trail buffer at $9000
	LD	(HL),0		; c37a  36 00		6.      ; Write 0 to first byte (marks buffer as empty)
	LD	(TRAIL_WRITE_PTR),HL	; c37c  22 e6 b0	"f0     ; Reset trail write pointer to $9000
	LD	A,0		; c37f  3e 00		>.      ; A = 0 (clear all flags)
	LD	(STATE_FLAGS),A	; c381  32 c8 b0	2H0     ; Clear state flags: no collision/timeout/complete
	CALL	UPDATE_LIVES_DISPLAY		; c384  cd b0 d2	M0R     ; Redraw the lives counter in the HUD

; --- Save background pixels under each entity's current position ---
; SAVE_SPRITE_BG reads the 2x16 bytes of screen bitmap under the entity
; and stores them in the entity's data structure (offset +5..+36).
; This is needed so we can erase the sprite cleanly next frame.
; See sprites.asm: SAVE_SPRITE_BG ($D0AC)
;
; Each entity data structure starts with: +0=X, +1=Y, +2=spriteType,
; +3..+4=varies, +5..+36=background save buffer (32 bytes)
;
	LD	HL,PLAYER_XY	; c387  21 03 b0	!.0     ; HL -> player data at $B003
	CALL	SAVE_SPRITE_BG		; c38a  cd ac d0	M,P     ; Save 32 bytes of screen under player
	LD	HL,TRAIL_CURSOR	; c38d  21 72 b0	!r0     ; HL -> trail cursor data at $B072
	CALL	SAVE_SPRITE_BG		; c390  cd ac d0	M,P     ; Save 32 bytes of screen under cursor
	LD	HL,CHASER1_DATA	; c393  21 28 b0	!(0     ; HL -> chaser 1 data at $B028
	CALL	SAVE_SPRITE_BG		; c396  cd ac d0	M,P     ; Save 32 bytes of screen under chaser 1
	LD	HL,CHASER2_DATA	; c399  21 4d b0	!M0     ; HL -> chaser 2 data at $B04D
	CALL	SAVE_SPRITE_BG		; c39c  cd ac d0	M,P     ; Save 32 bytes of screen under chaser 2

; --- Draw all 4 main entities as masked sprites ---
; DRAW_MASKED_SPRITE ($D078) uses AND-mask/OR-data compositing to render
; an 8x8 pixel sprite at the entity's (X,Y) position. Pre-shifted variants
; at $F000/$F100/$F200 handle sub-pixel X alignment.
;
	LD	HL,PLAYER_XY	; c39f  21 03 b0	!.0     ; HL -> player entity data
	CALL	DRAW_MASKED_SPRITE		; c3a2  cd 78 d0	MxP     ; Draw player sprite
	LD	HL,TRAIL_CURSOR	; c3a5  21 72 b0	!r0     ; HL -> trail cursor entity data
	CALL	DRAW_MASKED_SPRITE		; c3a8  cd 78 d0	MxP     ; Draw trail cursor sprite (if active)
	LD	HL,CHASER1_DATA	; c3ab  21 28 b0	!(0     ; HL -> chaser 1 entity data
	CALL	DRAW_MASKED_SPRITE		; c3ae  cd 78 d0	MxP     ; Draw chaser 1 sprite (if active)
	LD	HL,CHASER2_DATA	; c3b1  21 4d b0	!M0     ; HL -> chaser 2 entity data
	CALL	DRAW_MASKED_SPRITE		; c3b4  cd 78 d0	MxP     ; Draw chaser 2 sprite (if active)

; --- Draw all 8 sparks as border-pattern cells ---
; Sparks are not drawn as masked sprites; instead, each spark is rendered
; as a 2x2 pixel cell with pattern value 3 (border/solid). The loop
; iterates over the 8 spark data structures at $B099, $B09E, ..., $B0BC
; (5 bytes apart), drawing each active spark.
;
; HL -> $B099 (spark 0 old X,Y — used for erase position)
; B = 8 (loop counter: 8 sparks)
;
	LD	HL,XB099	; c3b7  21 99 b0	!.0     ; HL -> spark 0 position data
	LD	B,8		; c3ba  06 08		..      ; B = 8 sparks to process
;
; The following 7 bytes at $C3BC are the disassembler's attempt to decode
; inline data. This is actually the body of the spark drawing loop.
; It reads (HL) as the spark's X,Y position (loaded into DE), calls
; WRITE_CELL_BMP with A=3 (border pattern) to draw the spark, then
; advances HL by 5 bytes to the next spark's data and loops.
;
Xc3bc:	DB	'^#V####'				; c3bc
;
; --- Inner loop body: draw one spark ---
; On each iteration:
;   DE = (HL) = spark X,Y position (E=X, D=Y)
;   A = 3 (border cell pattern — solid block)
;   WRITE_CELL_BMP ($CEAE) writes the cell to bitmap only (not shadow)
;   This means sparks are visible but don't affect entity pathfinding.
;
XC3C3:	PUSH	BC		; c3c3  c5		E       ; Save loop counter
	PUSH	HL		; c3c4  e5		e       ; Save spark array pointer
	LD	A,3		; c3c5  3e 03		>.      ; A = 3 = border cell pattern (solid)
	CALL	WRITE_CELL_BMP		; c3c7  cd ae ce	M.N     ; Draw spark as solid 2x2 block on bitmap
	POP	HL		; c3ca  e1		a       ; Restore spark array pointer
	POP	BC		; c3cb  c1		A       ; Restore loop counter
	DJNZ	XC3BC		; c3cc  10 ee		.n      ; Decrement B; if B!=0, loop to next spark

; --- Play INK cycling animation on the timer area ---
; XD3F3 cycles the INK color (bits 0-2) of a rectangular attribute area.
; BC = row 0, col 24 ($0018) — position of the timer bar
; DE = 2 rows, 8 cols ($0208) — dimensions of the timer bar area
; This creates a brief color flash effect when the level starts or restarts.
;
	LD	BC,X0018	; c3ce  01 18 00	...     ; BC = attr row 0, col 24 (timer bar area)
	LD	DE,X0208	; c3d1  11 08 02	...     ; DE = 2 rows high, 8 cols wide
	CALL	XD3F3		; c3d4  cd f3 d3	MsS     ; Play INK cycling animation (16 steps x 2 HALTs)

; --- Initial pause: 50 frames (1 second at 50fps) ---
; Gives the player a moment to see the level layout before gameplay begins.
; FRAME_DELAY ($BB48) executes A HALT instructions in a loop.
;
	LD	A,32H		; c3d7  3e 32		>2      ; A = 50 decimal = 50 frames = 1.0 second
	CALL	FRAME_DELAY		; c3d9  cd 48 bb	MH;     ; Wait for 50 vertical blank interrupts


; ==========================================================================
; MAIN GAME LOOP ($C3DC)
; ==========================================================================
; This is the core per-frame game loop. Every iteration:
;   - Increments the frame counter
;   - Syncs to the 50Hz display via HALT
;   - Erases all entities, processes input and movement
;   - Redraws all entities at their new positions
;   - Runs AI (chasers, sparks, trail cursor)
;   - Manages the game timer and checks for end conditions
;
; IX is set to PLAYER_FLAGS ($B0E1) and remains there throughout the loop.
; This allows efficient access to player state via IX+offset addressing.
;
MAIN_LOOP:	LD	IX,PLAYER_FLAGS	; c3dc  dd 21 e1 b0	]!a0    ; IX -> $B0E1 (player flags byte)
	LD	HL,FRAME_CTR	; c3e0  21 c7 b0	!G0     ; HL -> frame counter at $B0C7
	INC	(HL)		; c3e3  34		4       ; Increment frame counter (wraps 255->0)
	HALT			; c3e4  76		v       ; Wait for vertical blank interrupt (50Hz sync)


; ==========================================================================
; PHASE 1: ERASE ALL ENTITIES (restore saved backgrounds)
; ==========================================================================
; Before any movement or drawing, we must erase every entity from their
; previous-frame positions. This is done by restoring the background pixels
; that were saved in each entity's data structure during the previous frame.
;
; RESTORE_SPRITE_BG ($D0E5) copies the 32 saved bytes back to the screen
; bitmap, effectively "unpainting" the sprite. Entities are erased in
; reverse draw order (last drawn = first erased) to handle overlaps.
;
; Erase order: chaser 2 -> chaser 1 -> trail cursor -> player
;
	LD	HL,CHASER2_DATA	; c3e5  21 4d b0	!M0     ; HL -> chaser 2 data at $B04D
	CALL	RESTORE_SPRITE_BG		; c3e8  cd e5 d0	MeP     ; Erase chaser 2 sprite (restore background)
	LD	HL,CHASER1_DATA	; c3eb  21 28 b0	!(0     ; HL -> chaser 1 data at $B028
	CALL	RESTORE_SPRITE_BG		; c3ee  cd e5 d0	MeP     ; Erase chaser 1 sprite (restore background)
	LD	HL,TRAIL_CURSOR	; c3f1  21 72 b0	!r0     ; HL -> trail cursor data at $B072
	CALL	RESTORE_SPRITE_BG		; c3f4  cd e5 d0	MeP     ; Erase trail cursor sprite (if active)
	LD	HL,PLAYER_XY	; c3f7  21 03 b0	!.0     ; HL -> player data at $B003
	CALL	RESTORE_SPRITE_BG		; c3fa  cd e5 d0	MeP     ; Erase player sprite (restore background)


; ==========================================================================
; PHASE 2: ERASE ALL 8 SPARKS (overwrite with empty cells)
; ==========================================================================
; Sparks are drawn as grid cells (not masked sprites), so they're erased
; by writing empty (value 0) cells at their old positions. The old position
; of each spark is stored at offsets +2,+3 in the spark's 5-byte structure.
;
; The spark data layout (5 bytes per spark):
;   +0: current X (0 = inactive)
;   +1: current Y
;   +2: old X (previous frame)
;   +3: old Y (previous frame)
;   +4: direction (1=DR, 3=DL, 5=UL, 7=UR — diagonals only)
;
; Spark old positions are at $B099, $B09E, $B0A3, $B0A8, $B0AD, $B0B2,
; $B0B7, $B0BC (every 5 bytes starting from $B097+2).
;
; WRITE_CELL_BMP ($CEAE) writes to the main bitmap only, NOT the shadow
; grid at $6000. XOR A = 0 = empty cell pattern.
;
	LD	DE,(XB099)	; c3fd  ed 5b 99 b0	m[.0    ; DE = spark 0 old position (E=X, D=Y)
	XOR	A		; c401  af		/       ; A = 0 = empty cell pattern
	CALL	WRITE_CELL_BMP		; c402  cd ae ce	M.N     ; Erase spark 0 (write empty cell to bitmap)
	LD	DE,(XB09E)	; c405  ed 5b 9e b0	m[.0    ; DE = spark 1 old position
	XOR	A		; c409  af		/       ; A = 0 = empty
	CALL	WRITE_CELL_BMP		; c40a  cd ae ce	M.N     ; Erase spark 1
	LD	DE,(XB0A3)	; c40d  ed 5b a3 b0	m[#0    ; DE = spark 2 old position
	XOR	A		; c411  af		/       ; A = 0 = empty
	CALL	WRITE_CELL_BMP		; c412  cd ae ce	M.N     ; Erase spark 2
	LD	DE,(XB0A8)	; c415  ed 5b a8 b0	m[(0    ; DE = spark 3 old position
	XOR	A		; c419  af		/       ; A = 0 = empty
	CALL	WRITE_CELL_BMP		; c41a  cd ae ce	M.N     ; Erase spark 3
	LD	DE,(XB0AD)	; c41d  ed 5b ad b0	m[-0    ; DE = spark 4 old position
	XOR	A		; c421  af		/       ; A = 0 = empty
	CALL	WRITE_CELL_BMP		; c422  cd ae ce	M.N     ; Erase spark 4
	LD	DE,(XB0B2)	; c425  ed 5b b2 b0	m[20    ; DE = spark 5 old position
	XOR	A		; c429  af		/       ; A = 0 = empty
	CALL	WRITE_CELL_BMP		; c42a  cd ae ce	M.N     ; Erase spark 5
	LD	DE,(XB0B7)	; c42d  ed 5b b7 b0	m[70    ; DE = spark 6 old position
	XOR	A		; c431  af		/       ; A = 0 = empty
	CALL	WRITE_CELL_BMP		; c432  cd ae ce	M.N     ; Erase spark 6
	LD	DE,(XB0BC)	; c435  ed 5b bc b0	m[<0    ; DE = spark 7 old position
	XOR	A		; c439  af		/       ; A = 0 = empty
	CALL	WRITE_CELL_BMP		; c43a  cd ae ce	M.N     ; Erase spark 7


; ==========================================================================
; PHASE 3: REDRAW TRAIL CELL UNDER PLAYER (if drawing)
; ==========================================================================
; When the player is in drawing mode, erasing the player sprite may have
; damaged the trail cell underneath. We need to redraw it. The trail cell
; pattern is value 3 (border-like solid) written to bitmap only.
;
; Player flags bit 7 ($B0E1 bit 7): 1 = currently drawing a trail.
; XCEB1 writes the cell to bitmap at the given coordinates with pattern A.
; This differs from WRITE_CELL_BMP because it skips the X=0 check.
;
	BIT	7,(IX+0)	; c43d  dd cb 00 7e	]K.~    ; Test bit 7 of player flags: is player drawing?
	JR	Z,XC44C		; c441  28 09		(.      ; If not drawing, skip trail cell redraw
	LD	DE,(PLAYER_XY)	; c443  ed 5b 03 b0	m[.0    ; DE = current player position (E=X, D=Y)
	LD	A,3		; c447  3e 03		>.      ; A = 3 = trail cell drawn as border pattern
	CALL	XCEB1		; c449  cd b1 ce	M1N     ; Redraw trail cell at player's position (bitmap only)


; ==========================================================================
; PHASE 4: PLAYER MOVEMENT AND INPUT
; ==========================================================================
; PLAYER_MOVEMENT ($C7B5) — see player_movement.asm
; Reads keyboard input, determines movement based on current mode:
;   - Border mode: player walks along border cells
;   - Drawing mode: player cuts through empty space, leaving trail
; May set fill-complete flag (bit 6) if trail reaches a border.
; May set collision flag (bit 0) if trail cursor catches up.
; Updates PLAYER_XY ($B003-$B004) with new position.
;
; On entry: IX = $B0E1 (player flags)
; On exit: Player position updated, flags may be modified
;
XC44C:	CALL	PLAYER_MOVEMENT		; c44c  cd b5 c7	M5G     ; Process input, move player, handle drawing


; ==========================================================================
; PHASE 5: SAVE SPRITE BACKGROUNDS (for next frame's erase)
; ==========================================================================
; Before drawing any entities at their new positions, we save the screen
; pixels underneath. This saved data will be used next frame in Phase 1
; to cleanly erase the sprites.
;
	LD	HL,PLAYER_XY	; c44f  21 03 b0	!.0     ; HL -> player data
	CALL	SAVE_SPRITE_BG		; c452  cd ac d0	M,P     ; Save 32 bytes of screen under new player position
	LD	HL,TRAIL_CURSOR	; c455  21 72 b0	!r0     ; HL -> trail cursor data
	CALL	SAVE_SPRITE_BG		; c458  cd ac d0	M,P     ; Save background under trail cursor
	LD	HL,CHASER1_DATA	; c45b  21 28 b0	!(0     ; HL -> chaser 1 data
	CALL	SAVE_SPRITE_BG		; c45e  cd ac d0	M,P     ; Save background under chaser 1
	LD	HL,CHASER2_DATA	; c461  21 4d b0	!M0     ; HL -> chaser 2 data
	CALL	SAVE_SPRITE_BG		; c464  cd ac d0	M,P     ; Save background under chaser 2


; ==========================================================================
; PHASE 6: CHECK SPARK-TRAIL COLLISIONS & DRAW SPARKS
; ==========================================================================
; This is an inline-data block that the disassembler could not fully decode.
; The actual Z80 code performs the following for each of the 8 sparks:
;
; For each spark (HL iterates through spark array at $B097, 5 bytes apart):
;   1. Load spark position into DE
;   2. Call $CEDB (COORDS_TO_ADDR + READ_CELL_BMP) to read the cell
;      value at the spark's current position from the main bitmap
;   3. Compare cell value to 3 (border): CP 3
;      - If cell = trail (value 2) or claimed (value 1):
;        The spark has hit the player's trail. In the shadow grid ($6000)
;        trail reads as empty, so sparks walk through trail freely. But
;        the BITMAP has the trail. When we read from bitmap here, we can
;        detect the overlap.
;      - If trail detected: SET bit 6 of STATE_FLAGS ($B0C8) to signal
;        collision to the sound system
;   4. If the spark is not on a trail cell, check if it's on claimed:
;      SET bit 0 of STATE_FLAGS for collision if needed
;   5. Draw the spark: WRITE_CELL_BMP with A=3 (border pattern)
;      This paints the spark as a solid 2x2 block on the bitmap only.
;
; After all 8 sparks are processed, the code continues to draw entity
; sprites below.
;
; HL -> $B097 (SPARK_ARRAY: spark 0 data start)
; B = 8 (loop counter)
;
	LD	HL,SPARK_ARRAY	; c467  21 97 b0	!.0     ; HL -> spark array base at $B097
	LD	B,8		; c46a  06 08		..      ; B = 8 sparks to process
;
; --- Inline data block: spark trail-collision check + draw loop ---
; The disassembler could not decode this region as clean instructions
; because the jump targets and inline constants confused the trace.
; The raw bytes encode:
;
; Loop body for each spark:
;   Load DE from (HL) — spark's current X,Y
;   Check if E (X) is 0 — if so, spark is inactive, skip it
;   Call XCEDB to read bitmap cell at (E,D)
;   If cell value is 2 (trail): set collision flag, spark kills player
;   Else: draw spark cell with pattern 3
;   Advance HL by 5 bytes to next spark
;   DJNZ back to loop start
;
	DB	'^#V####'				; c46c
	DB	1CH,1DH,28H,18H,0C5H,0E5H		; c473 ..(.Ee
	DW	XDBCD		; c479   cd db      M[
	DB	0CEH					; c47b N
	DW	X03FE		; c47c   fe 03      ~.
;
; --- Trail collision detection within spark loop ---
; If cell at spark position != border (3), check if it's trail (2).
; If trail: mark bit 6 in state flags (sound trigger) and set bit 0
; (collision detected — player dies).
;
	DB	20H,0DH					; c47e  .
	DW	XECCB		; c480   cb ec      Kl
	DW	XDECD		; c482   cd de      M^
	DW	XB7CE		; c484   ce b7      N7
;
; --- If spark is on trail cell, set collision flag ---
; JR NZ skips ahead; otherwise falls through to SET bit 0 of STATE_FLAGS.
;
	DB	20H,5,21H				; c486  .!
	DW	STATE_FLAGS		; c489   c8 b0      H0
	DW	XC6CB		; c48b   cb c6      KF
;
; --- Continue spark loop: restore registers, advance to next spark ---
	DB	0E1H,0C1H				; c48d aA
	DW	X10D5		; c48f   d5 10      U.
;
; --- Draw spark at new position and handle the remaining sparks ---
; After the loop, execution falls through here. Each spark gets drawn
; with cell pattern 3 (solid border block) and the old position is stored.
;
	DB	0DAH,6,8,0D9H				; c491 Z..Y
	DW	X3ED1		; c495   d1 3e      Q>
;
	DB	3,0CDH,0AEH				; c497 .M.
	DW	XD9CE		; c49a   ce d9      NY
;
; --- Loop terminator for spark processing (DJNZ back) ---
	DB	10H,0F6H,21H,3,0B0H			; c49c .v!.0


; ==========================================================================
; PHASE 7: DRAW ENTITY SPRITES AT NEW POSITIONS
; ==========================================================================
; Now that backgrounds are saved and sparks are drawn, render the 4 main
; entities (player, trail cursor, chaser 1, chaser 2) as masked sprites.
;
; DRAW_MASKED_SPRITE ($D078) uses AND-mask + OR-data compositing:
;   screen_byte = (screen_byte AND mask) OR sprite_data
; This allows transparent pixels in the sprite.
;
; Draw order: player -> trail cursor -> chaser 1 -> chaser 2
;
	DW	X78CD		; c4a1   cd 78      Mx      ; CALL DRAW_MASKED_SPRITE
	DW	X21D0		; c4a3   d0 21      P!      ; ... (HL -> next entity)
;
	DB	72H,0B0H				; c4a5 r0      ; = $B072 (TRAIL_CURSOR)
	DW	X78CD		; c4a7   cd 78      Mx      ; CALL DRAW_MASKED_SPRITE for trail cursor
	DW	X21D0		; c4a9   d0 21      P!
;
	DB	28H,0B0H				; c4ab (0      ; = $B028 (CHASER1_DATA)
	DW	X78CD		; c4ad   cd 78      Mx      ; CALL DRAW_MASKED_SPRITE for chaser 1
	DW	X21D0		; c4af   d0 21      P!
;
	DB	4DH,0B0H				; c4b1 M0      ; = $B04D (CHASER2_DATA)
	DW	X78CD		; c4b3   cd 78      Mx      ; CALL DRAW_MASKED_SPRITE for chaser 2
	DW	X21D0		; c4b5   d0 21      P!


; ==========================================================================
; PHASE 8: SOUND EFFECTS BASED ON STATE FLAGS
; ==========================================================================
; Check state flags bit 6 (trail cursor moving) and bit 7 (spark bounce)
; to trigger appropriate sound effects via port $FE output.
;
; STATE_FLAGS ($B0C8):
;   bit 6: Set when trail cursor advances (ticking sound)
;   bit 7: Set when a spark bounces off a wall (click sound)
;
; After checking, the relevant bits are cleared (RES) and a sound routine
; is called with DE specifying the sound parameters.
;
; The disassembler rendered this as inline data because the instruction
; boundaries are entangled with the previous block.
;
	DW	STATE_FLAGS		; c4b7   c8 b0      H0      ; LD HL, STATE_FLAGS ($B0C8)
	DW	X76CB		; c4b9   cb 76      Kv      ; BIT 6,(HL) — test trail cursor sound flag
;
; --- If bit 6 set: play trail cursor ticking sound ---
	DB	28H,0AH					; c4bb (.      ; JR Z, +10 — skip if not set
	DW	XB6CB		; c4bd   cb b6      K6      ; RES 6,(HL) — clear the cursor sound flag
;
	DB	11H,1,4					; c4bf ...     ; LD DE,$0401 — sound params: cursor tick
	DW	X20CD		; c4c2   cd 20      M       ; CALL $BB20 — play sound via port $FE
;
	DB	0BBH,18H,0CH				; c4c4 ;..     ; ... JR +12 — skip past the bounce sound
	DW	X7ECB		; c4c7   cb 7e      K~      ; BIT 7,(HL) — test spark bounce sound flag
;
; --- If bit 7 set: play spark bounce click sound ---
	DB	28H,8					; c4c9 (.      ; JR Z, +8 — skip if not set
	DW	XBECB		; c4cb   cb be      K>      ; RES 7,(HL) — clear the bounce sound flag
;
	DB	11H,0AH,2				; c4cd ...     ; LD DE,$020A — sound params: bounce click
	DW	X20CD		; c4d0   cd 20      M       ; CALL $BB20 — play sound via port $FE
	DB	0BBH					; c4d2 ;       ; (tail byte of the CALL address)


; ==========================================================================
; PHASE 9: CHECK PLAYER-ENEMY COLLISIONS
; ==========================================================================
; CHECK_COLLISIONS ($CAA9) — see movement_collision.asm
; Compares player position against all active enemies:
;   - Chaser 1 at $B028
;   - Chaser 2 at $B04D
;   - Trail cursor at $B072
; Collision threshold: |playerX - enemyX| < 2 AND |playerY - enemyY| < 2
;
; Returns: Carry flag set if collision detected.
; If collision: sets bit 0 of STATE_FLAGS ($B0C8).
;
; After collision check, the code falls through to AI movement if no
; immediate death is triggered. The actual death is handled at the bottom
; of the main loop when state flags are checked.
;
	DW	XA9CD		; c4d3   cd a9      M)      ; CALL CHECK_COLLISIONS ($CAA9)
	DW	X30CA		; c4d5   ca 30      J0      ; JP Z, $C530 — (encoded jump, collision result)
;
; --- If collision detected: set bit 6 of STATE_FLAGS (sound trigger) ---
; This schedules the collision to be processed at the end of the frame.
;
	DB	5,21H					; c4d7 .!      ;
	DW	STATE_FLAGS		; c4d9   c8 b0      H0      ; LD HL, STATE_FLAGS
	DW	XC6CB		; c4db   cb c6      KF      ; SET 0,(HL) — mark collision detected


; ==========================================================================
; PHASE 10: MOVE CHASERS (wall-following AI)
; ==========================================================================
; MOVE_CHASER ($CB03) — see chaser.asm
; Each chaser follows walls using a left-hand/right-hand wall-following
; algorithm. They read from the shadow grid ($6000) where trail cells
; appear as empty, so chasers cannot "see" the player's trail.
;
; Chaser data structure (37 bytes, pointed to by IX):
;   +0: X position
;   +1: Y position
;   +3: Direction (0=right, 2=down, 4=left, 6=up)
;   +4: Wall-following side flag
;   +5..+36: Sprite background save buffer
;
; Each chaser is moved one cell per frame along border/claimed edges.
;
	DB	0DDH,21H,28H,0B0H			; c4dd ]!(0    ; LD IX,$B028 — IX -> chaser 1 data
	DW	X03CD		; c4e1   cd 03      M.      ; CALL MOVE_CHASER ($CB03)
	DW	XDDCB		; c4e3   cb dd      K]      ; (decoded as part of the IX prefix sequence)
;
	DB	21H,4DH,0B0H				; c4e5 !M0     ; LD IX,$B04D — IX -> chaser 2 data
	DW	X03CD		; c4e8   cd 03      M.      ; CALL MOVE_CHASER ($CB03)
	DW	XDDCB		; c4ea   cb dd      K]      ; (decoded as part of the IX prefix sequence)


; ==========================================================================
; PHASE 11: MOVE ALL 8 SPARKS (diagonal bouncing)
; ==========================================================================
; MOVE_SPARK ($D18A) — see spark.asm
; Each spark moves diagonally (directions 1,3,5,7) and bounces off borders.
; Sparks read from the shadow grid where trail = empty, so they pass
; through the player's trail without collision (from their perspective).
; If a spark lands on a claimed cell, it is killed (+50 points).
;
; Spark data (5 bytes, pointed to by IX):
;   +0: X (0 = inactive/dead)
;   +1: Y
;   +2: old X (saved before move for erase)
;   +3: old Y
;   +4: direction (1=DR, 3=DL, 5=UL, 7=UR)
;
; The 8 sparks start at $B097 and are spaced 5 bytes apart.
; The first 4 are encoded as inline data; the last 4 are clean instructions.
;
	DB	21H,97H,0B0H,0CDH,8AH			; c4ec !.0M.   ; LD IX,$B097; CALL MOVE_SPARK (spark 0)
	DW	XDDD1		; c4f1   d1 dd      Q]
;
	DB	21H,9CH,0B0H,0CDH,8AH			; c4f3 !.0M.   ; LD IX,$B09C; CALL MOVE_SPARK (spark 1)
	DW	XDDD1		; c4f8   d1 dd      Q]
;
	DB	21H,0A1H,0B0H,0CDH,8AH			; c4fa !!0M.   ; LD IX,$B0A1; CALL MOVE_SPARK (spark 2)
	DW	XDDD1		; c4ff   d1 dd      Q]
;
	DB	21H,0A6H,0B0H,0CDH			; c501 !&0M    ; LD IX,$B0A6; CALL MOVE_SPARK (spark 3)
;
; --- Sparks 4-7: cleanly decoded instructions ---
;
	ADC	A,D		; c505  8a		.       ; (tail byte of CALL $D18A for spark 3)
	POP	DE		; c506  d1		Q       ; Restore DE after spark 3 move
	LD	IX,XB0AB	; c507  dd 21 ab b0	]!+0    ; IX -> spark 4 data at $B0AB
	CALL	MOVE_SPARK		; c50b  cd 8a d1	M.Q     ; Move spark 4 diagonally, handle bounces
	LD	IX,XB0B0	; c50e  dd 21 b0 b0	]!00    ; IX -> spark 5 data at $B0B0
	CALL	MOVE_SPARK		; c512  cd 8a d1	M.Q     ; Move spark 5 diagonally, handle bounces
	LD	IX,XB0B5	; c515  dd 21 b5 b0	]!50    ; IX -> spark 6 data at $B0B5
	CALL	MOVE_SPARK		; c519  cd 8a d1	M.Q     ; Move spark 6 diagonally, handle bounces
	LD	IX,XB0BA	; c51c  dd 21 ba b0	]!:0    ; IX -> spark 7 data at $B0BA
	CALL	MOVE_SPARK		; c520  cd 8a d1	M.Q     ; Move spark 7 diagonally, handle bounces


; ==========================================================================
; PHASE 12: MOVE TRAIL CURSOR
; ==========================================================================
; MOVE_TRAIL_CURSOR ($CBFE) — see trail_cursor_init.asm
; The trail cursor chases the player along the trail buffer ($9000).
; It advances 2 entries per frame (6 bytes), converting trail cells back
; to empty as it goes. If the cursor catches the player (buffer exhausted),
; it sets bit 0 of STATE_FLAGS (collision = death).
;
; The cursor only activates after 72 frames of drawing (trail frame counter
; at $B0E8 reaches $48). This gives the player a head start.
;
; IX -> $B072 (TRAIL_CURSOR data: X, Y, sprite type, buffer pointer)
;
	LD	IX,TRAIL_CURSOR	; c523  dd 21 72 b0	]!r0    ; IX -> trail cursor data at $B072
	CALL	MOVE_TRAIL_CURSOR		; c527  cd fe cb	M~K     ; Advance cursor along trail buffer


; ==========================================================================
; PHASE 13: GAME TIMER MANAGEMENT
; ==========================================================================
; The game timer uses a two-level countdown:
;   - $B0E9 (TIMER_SUB_CTR): sub-counter, counts down from 14
;   - $B0C0 (GAME_TIMER): main timer, counts down from 176
;
; Each frame, the sub-counter decrements. When it reaches 0:
;   - Reload sub-counter from $B0EA (timer speed = 14 frames)
;   - Decrement the main game timer
;   - If main timer reaches 0: set bit 1 of STATE_FLAGS (time expired)
;
; Effective timer: 176 ticks x 14 frames/tick = 2464 frames = ~49.3 seconds
;
	LD	HL,TIMER_SUB_CTR	; c52a  21 e9 b0	!i0     ; HL -> timer sub-counter at $B0E9
	DEC	(HL)		; c52d  35		5       ; Decrement sub-counter
	JR	NZ,XC53F	; c52e  20 0f		 .      ; If sub-counter != 0, skip timer tick
; --- Sub-counter reached 0: one timer tick ---
	LD	A,(TIMER_SPEED)	; c530  3a ea b0	:j0     ; A = timer speed reload value (14 = $0E)
	LD	(HL),A		; c533  77		w       ; Reload sub-counter to 14
	LD	HL,GAME_TIMER	; c534  21 c0 b0	!@0     ; HL -> main game timer at $B0C0
	DEC	(HL)		; c537  35		5       ; Decrement main timer (176, 175, ..., 1, 0)
	JR	NZ,XC53F	; c538  20 05		 .      ; If timer != 0, continue playing
; --- Timer reached 0: game over due to timeout ---
	LD	HL,STATE_FLAGS	; c53a  21 c8 b0	!H0     ; HL -> state flags at $B0C8
	SET	1,(HL)		; c53d  cb ce		KN      ; Set bit 1: timer expired flag


; ==========================================================================
; PHASE 14: UPDATE HUD DISPLAYS
; ==========================================================================
; UPDATE_SCORE_DISPLAY ($D27A) — see display.asm
;   Computes display_score = base_score + (rawPercent + fillPercent) * 4
;   Renders as 5 decimal digits using the double-height HUD font at $FA00.
;
; UPDATE_TIMER_BAR ($D2C1) — see display.asm
;   Animated XOR pixel bar showing remaining time. The bar display position
;   ($B0BF) animates toward the actual timer value, shrinking one pixel
;   per frame. Returns carry=1 if still animating (bar != timer).
;
XC53F:	CALL	UPDATE_SCORE_DISPLAY		; c53f  cd 7a d2	MzR     ; Redraw the 5-digit score in the HUD
	CALL	UPDATE_TIMER_BAR		; c542  cd c1 d2	MAR     ; Animate the timer bar toward current value


; ==========================================================================
; PHASE 15: CHECK PAUSE KEY
; ==========================================================================
; CHECK_PAUSE ($C617) — see death_scoring.asm
; Checks if the P key is pressed. If so:
;   1. Dims field (clears BRIGHT bit on all field attributes)
;   2. Draws "Game Paused" popup with "Continue" / "Abort" options
;   3. Waits for player selection
;   4. If "Continue": restore screen and resume
;   5. If "Abort": return carry flag to exit to menu
;
; Returns: Carry clear = continue playing; Carry set = abort game
; The JP NC below jumps to the menu return handler if aborted.
;
	CALL	CHECK_PAUSE		; c545  cd 17 c6	M.F     ; Check P key, show pause menu if pressed
	JP	NC,XC6F2	; c548  d2 f2 c6	RrF     ; If player chose "Abort", jump to menu return


; ==========================================================================
; PHASE 16: CHECK GAME STATE FLAGS — DETERMINE FRAME OUTCOME
; ==========================================================================
; STATE_FLAGS ($B0C8) is the central dispatch register:
;   bit 1: Timer expired -> death/game over (highest priority)
;   bit 0: Collision detected -> lose a life
;   bit 2: Level complete (fill% >= 75%) -> celebration sequence
;   all 0: Nothing happened -> loop back for next frame
;
; Priority order matters: timer expiry overrides collision, collision
; overrides level complete. This prevents a simultaneous collision+complete
; from giving the player credit for the level.
;
	LD	HL,STATE_FLAGS	; c54b  21 c8 b0	!H0     ; HL -> state flags at $B0C8
	BIT	1,(HL)		; c54e  cb 4e		KN      ; Test bit 1: has the timer expired?
	JP	NZ,OUT_OF_TIME	; c550  c2 c9 c6	BIF     ; If timer expired, jump to "Out of Time" handler
	BIT	0,(HL)		; c553  cb 46		KF      ; Test bit 0: was a collision detected?
	JP	NZ,DEATH_HANDLER	; c555  c2 4f c6	BOF     ; If collision, jump to death animation/life loss
	BIT	2,(HL)		; c558  cb 56		KV      ; Test bit 2: is the level complete (>=75% filled)?
	JP	Z,MAIN_LOOP		; c55a  ca dc c3	J\C     ; If no flags set, loop back to next frame
	; --- Fall through to LEVEL_COMPLETE when bit 2 is set ---


; ==========================================================================
; LEVEL COMPLETE SEQUENCE ($C55D)
; ==========================================================================
; Triggered when the filled percentage reaches or exceeds 75%.
; This is a multi-step celebration:
;   1. Dim the field by clearing BRIGHT on all field attributes
;   2. Draw a popup box and display "Screen Completed"
;   3. Rainbow color cycling animation (640ms)
;   4. Convert remaining percentage to bonus score
;   5. Countdown timer to bonus points (animated)
;   6. Brief pause, then advance to next level
;
LEVEL_COMPLETE:

; --- Step 1: Dim the game field ---
; RESET_BRIGHT_FIELD ($D3D3) clears bit 6 (BRIGHT) on all attribute
; cells in rows 4-23 (the game field area at $5880-$5AFF).
;
	CALL	RESET_BRIGHT_FIELD		; c55d  cd d3 d3	MSS     ; Clear BRIGHT bit on all field attributes

; --- Step 2: Draw popup rectangle ---
; DRAW_BORDERED_RECT ($BF70) draws a filled rectangle with a 1-cell
; border in the attribute area.
;   B = row 8, C = col 11    -> top-left corner of popup
;   D = height 16, E = width 5 -> 5 rows by 16 columns
;   A = $68 = attribute byte: BRIGHT=1, PAPER=cyan(5), INK=black(0)
;
	LD	BC,X0B08	; c560  01 08 0b	...     ; B=8 (row), C=11 (col) — popup top-left
	LD	DE,X0510	; c563  11 10 05	...     ; D=16 (width), E=5 (height)
	LD	A,68H		; c566  3e 68		>h      ; A=$68: BRIGHT + cyan PAPER + black INK
	CALL	DRAW_BORDERED_RECT		; c568  cd 70 bf	Mp?     ; Draw the popup rectangle

; --- Step 3: Print "Screen Completed" text ---
; STRING_RENDERER ($BC26) renders a string with embedded position/color
; control bytes. The string at $C5BB contains cursor positioning codes
; followed by the ASCII text "Screen Completed".
;
	LD	HL,XC5BB	; c56b  21 bb c5	!;E     ; HL -> "Screen Completed" string data
	CALL	STRING_RENDERER		; c56e  cd 26 bc	M&<     ; Render text into the popup

; --- Step 4: Rainbow color cycling animation ---
; RAINBOW_CYCLE ($D415) cycles the PAPER color (bits 3-5) through all
; 8 ZX Spectrum colors: cyan->green->yellow->white->black->blue->red->magenta
; 16 iterations x 2 HALT frames per step = 32 frames = 640ms total.
; The same rectangle coordinates as the popup are used.
;
	LD	BC,X0B08	; c571  01 08 0b	...     ; B=8, C=11 — same popup area
	LD	DE,X0510	; c574  11 10 05	...     ; D=16, E=5 — same dimensions
	CALL	RAINBOW_CYCLE		; c577  cd 15 d4	M.T     ; Play rainbow PAPER cycling animation

; --- Step 5: Finalize percentage into bonus score ---
; SCORE_FINALIZE ($C6F6) — see death_scoring.asm
; Adds (rawPercentage + filledPercentage) * 4 to the base score.
; Then clears both percentage accumulators to 0.
; This rewards the player for claiming more territory.
;
	CALL	SCORE_FINALIZE		; c57a  cd f6 c6	MvF     ; score += (raw% + fill%) * 4

; --- Step 6: Sync timer bar display to actual value ---
; UPDATE_TIMER_BAR ($D2C1) animates the timer bar one pixel per call.
; The bar display position ($B0BF) may be ahead of or behind the actual
; timer value ($B0C0). This loop calls it repeatedly until they match.
; Returns carry=1 if still animating, carry=0 when synced.
;
XC57D:	CALL	UPDATE_TIMER_BAR		; c57d  cd c1 d2	MAR     ; Animate timer bar one step
	JR	C,XC57D		; c580  38 fb		8{      ; If bar != timer, keep animating

; --- Step 7: Timer-to-score countdown ---
; Each remaining timer tick is converted to +1 bonus point.
; The animation: timer bar shrinks (tick by tick), score increments,
; with a 2-frame delay per tick for visual effect.
;
; If timer is already 0 (very rare — would mean time ran out exactly
; as the player completed the level), skip the countdown.
;
	LD	A,(GAME_TIMER)	; c582  3a c0 b0	:@0     ; A = remaining timer value (0-176)
	OR	A		; c585  b7		7       ; Test if timer is zero
	JR	Z,XC5A9		; c586  28 21		(!      ; If timer=0, skip countdown (no bonus)
	LD	B,A		; c588  47		G       ; B = number of ticks to count down

; --- Countdown loop: one iteration per remaining timer tick ---
; Each iteration:
;   1. Decrement the game timer
;   2. Update (shrink) the timer bar visually
;   3. Increment the base score by 1
;   4. Redraw the score display
;   5. Wait 2 frames (40ms) for visible animation
;
XC589:	PUSH	BC		; c589  c5		E       ; Save remaining tick count
	LD	HL,GAME_TIMER	; c58a  21 c0 b0	!@0     ; HL -> game timer at $B0C0
	DEC	(HL)		; c58d  35		5       ; Decrement timer by 1 tick
	CALL	UPDATE_TIMER_BAR		; c58e  cd c1 d2	MAR     ; Shrink the timer bar by one step

; --- Increment score by 1 point per timer tick ---
; SCORE_DISPLAY_POS ($D312) is a 2-byte variable that tells the HUD
; renderer where to draw. $0006 = column 6 of row 0 (score position).
; DISPLAY_5DIGIT ($D315) converts the 16-bit value in HL to 5 decimal
; digits and renders them with the double-height HUD font.
;
	LD	HL,X0006	; c591  21 06 00	!..     ; HL = $0006 = score display column position
	LD	(SCORE_DISPLAY_POS),HL	; c594  22 12 d3	".S     ; Set display position to score area
	LD	HL,(BASE_SCORE)	; c597  2a c3 b0	*C0     ; HL = current base score (16-bit)
	INC	HL		; c59a  23		#       ; Increment score by 1 (timer bonus point)
	LD	(BASE_SCORE),HL	; c59b  22 c3 b0	"C0     ; Store new score back
	CALL	DISPLAY_5DIGIT		; c59e  cd 15 d3	M.S     ; Render the updated 5-digit score

; --- 2-frame delay between each countdown step ---
; FRAME_DELAY ($BB48) waits A frames. 2 frames = 40ms at 50fps.
; This makes the countdown visible and creates a satisfying ticker effect.
;
	LD	A,2		; c5a1  3e 02		>.      ; A = 2 frames = 40ms delay
	CALL	FRAME_DELAY		; c5a3  cd 48 bb	MH;     ; Wait 2 vertical blank interrupts
	POP	BC		; c5a6  c1		A       ; Restore remaining tick count
	DJNZ	XC589		; c5a7  10 e0		.`      ; Decrement B; if ticks remain, loop back

; --- Step 8: Post-countdown pause ---
; 50 frames = 1 second at 50fps. Lets the player admire their score
; before the screen is restored and the next level begins.
;
XC5A9:	LD	A,32H		; c5a9  3e 32		>2      ; A = 50 frames = 1.0 second pause
	CALL	FRAME_DELAY		; c5ab  cd 48 bb	MH;     ; Wait 50 frames

; --- Step 9: Restore screen (undo popup) ---
; RESTORE_RECT ($C03E) undoes the popup by restoring the attribute and
; bitmap data that was saved when DRAW_BORDERED_RECT was called.
; This brings back the game field graphics underneath the popup.
;
	CALL	RESTORE_RECT		; c5ae  cd 3e c0	M>@     ; Restore screen area under the popup

; --- Step 10: Advance to next level ---
; Increment the level number and jump back to LEVEL_START to initialize
; the next level. Level number wraps via AND $0F in LEVEL_INIT, so the
; game effectively has 16 unique level configurations that cycle.
;
	LD	HL,LEVEL_NUM	; c5b1  21 c1 b0	!A0     ; HL -> level number at $B0C1
	INC	(HL)		; c5b4  34		4       ; Increment level (0->1, 1->2, ...)
	JP	LEVEL_START		; c5b5  c3 74 c3	CtC     ; Jump to LEVEL_START to begin next level


; ==========================================================================
; EMBEDDED DATA: ADDRESSES AND STRING DATA
; ==========================================================================
; These bytes after the level complete code contain:
;   - Jump target addresses used by the menu/restart system
;   - Embedded strings with control codes for the text renderer
;
; Format of control codes in strings:
;   $1E = set attribute byte (next byte is the attribute)
;   $1F = set cursor position (next byte encodes row*16+col or similar)
;   $0D = newline / carriage return
;   $00 = end of string
;
;
	DW	XF2C3		; c5b8   c3 f2      Cr      ; Address: JP $C3F2 (used by menu dispatch)
;
	DW	X1EC6		; c5ba   c6 1e      F.      ; Address reference

; --- "Screen Completed" string (with embedded control codes) ---
; $1E,$68 = set attribute: BRIGHT + cyan PAPER
; $1F,$4B = set cursor position: row 9, col 11
; $0D     = carriage return / move to next line
; Then ASCII "Screen Completed"
; $00     = string terminator
;
	DB	68H,1FH,4BH,0DH				; c5bc h.K.    ; Attr=$68, pos=$4B, CR
	DB	'Screen Completed'			; c5c0                  ; 16 bytes of ASCII text
	DB	0,1EH,68H,1FH,82H,0DH			; c5d0 ..h...  ; Terminator, then...

; --- "All Screens Completed" string (UNUSED / dead code) ---
; This string is never reached in normal gameplay. It may have been
; intended for a victory screen when all 16 levels are beaten, but
; the level counter just wraps around instead of triggering this.
;
	DB	'All Screens Completed'			; c5d6                  ; 21 bytes of ASCII text
XC5EB:	DB	0					; c5eb .       ; String terminator

; --- Pause menu strings ---
; Used by CHECK_PAUSE ($C617) when the P key is pressed.
; Contains "Game Paused", "Continue", and "Abort" with positioning codes.
;
; $1E,$68 = attribute: BRIGHT + cyan PAPER
; $1F,$5A = cursor position for "Game Paused"
; $1F,$4C = cursor position for "Continue"
; $1F,$8C = cursor position for "Abort"
; $0F     = switch to secondary font / highlight text
;
XC5EC:	DB	1EH,68H,1FH,5AH,0DH			; c5ec .h.Z.   ; Attr + position for title
Xc5f1:	DB	'G'					; c5f1         ; 'G' — start of "Game Paused"
Xc5f2:	DB	'ame'					; c5f2         ; 'ame'
Xc5f5:	DB	' Paused'				; c5f5         ; ' Paused'
	DB	1FH,4CH,0FH				; c5fc .L.     ; Position + highlight for "Continue"
	DB	'Continue'				; c5ff         ; 8 bytes: menu option 1
	DB	1FH,8CH,0FH,41H,62H,6FH,72H,74H		; c607 ...Abort ; Position + "Abort"
	DB	0					; c60f .       ; String terminator


; ==========================================================================
; TRAILING BYTES ($C610-$C616)
; ==========================================================================
; These bytes appear to be data used by the pause menu's option selection
; system. They encode the menu option positions and selection parameters
; for the "Continue" / "Abort" choice in the pause overlay.
;
; $C610: Menu option descriptor table
;   $09 = ADD HL,BC (possibly coincidental encoding of data)
;   $0F = option highlight attribute or cursor position
;   $08 = EX AF,AF' (data byte)
;   $11,$0F,$06 = LD DE,$060F — menu highlight parameters
;   $FF = RST 38H (data byte / padding)
;
XC610:	ADD	HL,BC		; c610  09		.       ; Menu data byte
	RRCA			; c611  0f		.       ; Menu data byte
	EX	AF,AF'		; c612  08		.       ; Menu data byte
	LD	DE,X060F	; c613  11 0f 06	...     ; Menu option selection parameters
	RST	38H		; c616  ff		.       ; Data padding / end marker
