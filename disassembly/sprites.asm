; ==========================================================================
; SPRITE DRAWING ROUTINES ($D078-$D189)
; ==========================================================================
;
; This module implements all sprite rendering for the Zolyx game entities:
; player, chasers, and the trail cursor. It uses the classic ZX Spectrum
; AND-mask + OR-data compositing technique for transparency, along with
; background save/restore to cleanly erase sprites each frame.
;
; --------------------------------------------------------------------------
; RENDERING TECHNIQUE: AND-Mask + OR-Data Compositing
; --------------------------------------------------------------------------
;
; Each sprite is 8x8 pixels but occupies TWO screen bytes per row because
; the sprite can straddle a byte boundary (sub-byte X alignment). Each row
; is therefore 4 bytes: mask_left, data_left, mask_right, data_right.
;
; For each screen byte under the sprite:
;   new_byte = (old_byte AND mask_byte) OR data_byte
;
; Mask byte semantics:
;   - Bit = 1: transparent (preserve background pixel)
;   - Bit = 0: opaque (sprite covers this pixel)
; Data byte semantics:
;   - Bit = 1: draw INK pixel
;   - Bit = 0: draw PAPER pixel (only matters where mask = 0)
;
; Examples:
;   Transparent pixel: mask=1, data=0 -> (bg AND 1) OR 0 = bg (preserved)
;   Opaque INK pixel:  mask=0, data=1 -> (bg AND 0) OR 1 = 1 (INK)
;   Opaque PAPER pixel: mask=0, data=0 -> (bg AND 0) OR 0 = 0 (PAPER)
;
; --------------------------------------------------------------------------
; SPRITE DATA LAYOUT ($F000-$F2FF)
; --------------------------------------------------------------------------
;
; Each entity has 256 bytes = 8 alignment variants x 32 bytes per variant.
; A variant is 8 rows x 4 bytes (mask_left, data_left, mask_right, data_right).
;
;   $F000-$F0FF: Player sprite   (hollow circle outline)
;   $F100-$F1FF: Chaser sprite   (pac-man / eye shape)
;   $F200-$F2FF: Trail cursor    (checkerboard-filled circle)
;
; The 8 variants handle sub-pixel X alignment (0-7 pixel offsets within
; a byte). The correct variant is selected based on (X*2-3) & 7, which
; gives the pixel offset of the sprite's left edge within its screen byte.
;
; Variant selection: the low 5 bits of the sprite X pixel position encode
; the byte column (bits 7-3) and the pixel offset (bits 2-0). The offset
; selects which of the 8 pre-shifted variants to use. Each variant is
; 32 bytes, so the variant index * 32 gives the offset into the entity's
; sprite block.
;
; --------------------------------------------------------------------------
; ENTITY DATA STRUCTURE (pointed to by HL on entry)
; --------------------------------------------------------------------------
;
; All three routines receive HL pointing to an entity data structure:
;
;   Offset +0: X position (game coordinates, 0 = inactive)
;   Offset +1: Y position (game coordinates)
;   Offset +2: (varies: sprite type index for player, old pos for chasers)
;   Offset +3: (varies: direction for chasers)
;   Offset +4: (varies: wall-side for chasers)
;   Offset +5..+36: Background save buffer (32 bytes)
;                    Format: 8 entries of (addr_lo, addr_hi, byte1, byte2)
;                    Each entry saves one pixel row: the screen address
;                    and the two screen bytes under the sprite at that row.
;
; Entities in memory:
;   $B003: PLAYER_XY   (player position + bg buffer)
;   $B028: CHASER1_DATA (37-byte chaser structure)
;   $B04D: CHASER2_DATA (37-byte chaser structure)
;   $B072: TRAIL_CURSOR (trail cursor position + bg buffer)
;
; --------------------------------------------------------------------------
; ZX SPECTRUM SCREEN ADDRESS COMPUTATION
; --------------------------------------------------------------------------
;
; The ZX Spectrum screen bitmap ($4000-$57FF) has a non-linear layout:
;   - 3 "thirds" of 64 pixel rows each (8 character rows x 8 pixel lines)
;   - Within each third, pixel lines are interleaved by character row
;   - Address bits: 010T TSSS LLLC CCCC
;     TT    = third (0-2)
;     SSS   = pixel line within character (0-7)
;     LLL   = character row within third (0-7)
;     CCCCC = byte column (0-31)
;
; To avoid recomputing this complex layout, a pre-computed row pointer
; table exists at $FC00. Each entry is 2 bytes (little-endian screen
; address for column 0 of that pixel row). The table is indexed by
; pixel Y * 2 (since each entry is 2 bytes).
;
; To get the screen address for (pixelX, pixelY):
;   1. Look up base address from $FC00 + pixelY * 2
;   2. Add (pixelX / 8) as the byte column offset
;
; --------------------------------------------------------------------------
; CALL GRAPH (from main_loop.asm)
; --------------------------------------------------------------------------
;
; Each frame, the main loop at $C3DC:
;   1. Calls RESTORE_SPRITE_BG for each entity (erase old sprites)
;   2. Processes movement and game logic
;   3. Calls SAVE_SPRITE_BG for each entity (save new backgrounds)
;   4. Calls DRAW_MASKED_SPRITE for each entity (draw sprites)
;
; Order matters: backgrounds must be saved BEFORE drawing, and restored
; BEFORE the next frame's save. This ensures the save buffer always
; contains clean (sprite-free) background data.
;
; --------------------------------------------------------------------------
;
; ROUTINES IN THIS MODULE:
;
; DRAW_MASKED_SPRITE ($D078):
;   Draws an 8x8 pixel sprite using AND-mask + OR-data compositing.
;   Each sprite row is 4 bytes: mask1, data1, mask2, data2
;   (2 bytes wide to handle sub-pixel alignment).
;   For each pixel row:
;     screen_byte = (screen_byte AND mask) OR data
;   This allows transparent pixels (mask=FF, data=00) and opaque
;   pixels (mask=00, data=sprite_bits).
;
; SAVE_SPRITE_BG ($D0AC):
;   Saves the 32 bytes of screen bitmap under a sprite's position.
;   For each of 8 pixel rows, saves: screen address (2 bytes) +
;   screen contents (2 bytes) = 4 bytes per row, 32 bytes total.
;   Stored in the entity's data structure at offset +5.
;
; RESTORE_SPRITE_BG ($D0E5):
;   Restores saved background, effectively erasing the sprite.
;   Reads back the saved screen addresses and bytes from the entity's
;   bg buffer and writes them back to the screen.
;   Called at the start of each frame before entities are redrawn.
;
; 16-BIT DIVISION ($D14F):
;   Unsigned 16-bit divide: BC / DE -> quotient in BC, remainder in HL.
;   Used by CALC_PERCENTAGE in death_scoring.asm to compute
;   claimed_cells / 90 and filled_cells / 90.
;
; 16-BIT MULTIPLICATION ($D177):
;   Unsigned 16-bit multiply: B:C * DE -> result in HL.
;   Unreferenced in the final game; possibly a library routine left
;   over from development.
;
; Each entity (player, chasers, trail cursor) has 8 pre-shifted
; alignment variants of its sprite at $F000/$F100/$F200.
; The variant is selected based on the entity's sub-pixel X position.
;

;

; ==========================================================================
; DRAW_MASKED_SPRITE ($D078)
; ==========================================================================
;
; Draws an 8x8 pixel sprite onto the ZX Spectrum screen bitmap using
; AND-mask + OR-data compositing for transparency.
;
; ENTRY:
;   HL = pointer to entity data structure
;        (HL)+0 = X position (game coordinates; 0 = inactive/skip)
;        (HL)+1 = Y position (game coordinates)
;        (HL)+2 = sprite type index (selects $F0xx/$F1xx/$F2xx page)
;
; EXIT:
;   All registers modified. Returns immediately if entity X = 0.
;
; ALGORITHM:
;   1. Read entity X, Y, and sprite type from the data structure
;   2. Convert X to pixel coordinates: pixelX = X*2 - 3 (center 8px
;      sprite on the 2px game cell)
;   3. Compute sprite variant offset from pixelX:
;      variant = (pixelX rotated right 3) AND $E0
;      This extracts bits 2-0 into bits 7-5, giving variant * 32
;   4. Compute screen base address from Y using the row pointer table
;      at $FC00
;   5. Build DE = sprite data pointer: D = sprite page ($F0+type), E = variant
;   6. For each of 8 pixel rows:
;      a. Load screen address from row pointer table, add byte column
;      b. Read mask byte from sprite -> AND with screen byte
;      c. Read data byte from sprite -> OR into result
;      d. Write composited byte back to screen
;      e. Repeat for the second (right) screen byte
;      f. Advance to next row pointer table entry
;
; The row pointer table entries are stored as (screen_addr_lo, addr_hi)
; pairs starting at $FC00, indexed by pixel Y.
;
; CROSS-REFERENCES:
;   Called from main_loop.asm at $C3A2 (player), $C3A8 (cursor),
;   $C3AE (chaser 1), $C3B4 (chaser 2).
;   Sprite data at $F000 (player), $F100 (chaser), $F200 (cursor).
;   Row pointer table at $FC00 (pre-computed in sprite_data.asm).
;
; --- Draw masked sprite ---
DRAW_MASKED_SPRITE:	LD	A,(HL)		; d078  7e		~	; A = entity X position (offset +0)
	OR	A		; d079  b7		7	; Test if X is zero (entity inactive)
	RET	Z		; d07a  c8		H	; If X=0, entity is inactive -- skip drawing
	INC	HL		; d07b  23		#	; HL -> offset +1 (skip X, now pointing at Y)
	INC	HL		; d07c  23		#	; HL -> offset +2 (sprite type index byte)
; --- Compute sprite variant offset from X position ---
; The sprite X in game coords maps to pixel X = X*2. The sprite is 8 pixels
; wide, centered on the 2-pixel cell, so the left edge is at X*2-3.
; The low 3 bits of the pixel X determine which of the 8 pre-shifted
; sprite variants to use (each variant is 32 bytes = $20).
	ADD	A,A		; d07d  87		.	; A = X * 2 (convert game coords to pixel coords)
	SUB	3		; d07e  d6 03		V.	; A = X*2 - 3 (sprite left edge pixel X)
	RRCA			; d080  0f		.	; Rotate right 3 times to move bits 4-2
	RRCA			; d081  0f		.	;   into bits 7-5 position, effectively
	RRCA			; d082  0f		.	;   computing (pixelX & 7) << 5 = variant * 32
	AND	0E0H		; d083  e6 e0		f`	; Mask to keep only bits 7-5 (variant index * 32)
	LD	E,A		; d085  5f		_	; E = sprite variant offset (0, $20, $40, ... $E0)
; --- Read sprite type and compute sprite data page ---
; The sprite type byte at entity offset +2 selects which 256-byte sprite
; page to use: 0 = $F000 (player), 1 = $F100 (chaser), 2 = $F200 (cursor).
	LD	A,(HL)		; d086  7e		~	; A = sprite type index (0, 1, or 2)
	INC	HL		; d087  23		#	; HL -> offset +3
	INC	HL		; d088  23		#	; HL -> offset +4
	INC	HL		; d089  23		#	; HL -> offset +5 (start of row pointer data)
	ADD	A,0F0H		; d08a  c6 f0		Fp	; A = $F0 + type = sprite page high byte
	LD	D,A		; d08c  57		W	; D = sprite page ($F0, $F1, or $F2)
; --- DE now points to the selected sprite variant data ---
; DE = (sprite_page << 8) | variant_offset
; For example: player variant 3 = $F060 (page $F0, offset $60)
	LD	B,8		; d08d  06 08		..	; B = 8 rows to draw (sprite is 8 pixels tall)
; ==========================================================================
; INNER LOOP: Process one pixel row of the sprite
; ==========================================================================
; At this point, HL points into the entity's bg save buffer (offset +5).
; SAVE_SPRITE_BG has previously stored 4 bytes per pixel row here:
;   (addr_lo, addr_hi, saved_byte1, saved_byte2)
;
; DRAW_MASKED_SPRITE reuses the pre-computed screen addresses from the
; save buffer. For each row it:
;   1. Reads the 16-bit screen address from (HL), (HL+1)
;   2. Skips the 2 saved background bytes (HL += 4 total per row)
;   3. Applies AND mask + OR data to the 2 screen bytes at that address
;   4. Advances DE by 4 (consuming mask1, data1, mask2, data2 from sprite)
;
; This coupling between SAVE and DRAW means SAVE must always be called
; before DRAW for the same entity, so the addresses are populated.
;
XD08F:	LD	A,(HL)		; d08f  7e		~	; A = screen address low byte for this row
	INC	HL		; d090  23		#	; HL -> screen address high byte
	PUSH	HL		; d091  e5		e	; Save HL (we will use HL as screen pointer)
	LD	H,(HL)		; d092  66		f	; H = screen address high byte
	LD	L,A		; d093  6f		o	; L = screen address low byte -> HL = screen addr
; --- Composite left screen byte (byte 1 of 2) ---
; DE points to the sprite data: mask_left, data_left, mask_right, data_right
	LD	A,(DE)		; d094  1a		.	; A = mask_left byte from sprite data
	INC	DE		; d095  13		.	; DE -> data_left byte
	AND	(HL)		; d096  a6		&	; A = screen_byte AND mask (preserve bg where mask=1)
	EX	DE,HL		; d097  eb		k	; Swap: HL=sprite ptr, DE=screen ptr
	OR	(HL)		; d098  b6		6	; A = (screen AND mask) OR data_left (overlay sprite)
	EX	DE,HL		; d099  eb		k	; Swap back: HL=screen ptr, DE=sprite ptr
	LD	(HL),A		; d09a  77		w	; Write composited byte back to screen
; --- Composite right screen byte (byte 2 of 2) ---
	INC	HL		; d09b  23		#	; HL -> next screen byte (right half)
	INC	DE		; d09c  13		.	; DE -> mask_right byte
	LD	A,(DE)		; d09d  1a		.	; A = mask_right byte from sprite data
	INC	DE		; d09e  13		.	; DE -> data_right byte
	AND	(HL)		; d09f  a6		&	; A = screen_byte AND mask_right
	EX	DE,HL		; d0a0  eb		k	; Swap: HL=sprite ptr, DE=screen ptr
	OR	(HL)		; d0a1  b6		6	; A = (screen AND mask) OR data_right
	EX	DE,HL		; d0a2  eb		k	; Swap back: HL=screen ptr, DE=sprite ptr
	LD	(HL),A		; d0a3  77		w	; Write composited byte back to screen
; --- Advance to next row ---
	INC	DE		; d0a4  13		.	; DE -> next row's mask_left (skip past data_right)
	POP	HL		; d0a5  e1		a	; Restore HL to the screen addr high byte position
	INC	HL		; d0a6  23		#	; HL -> saved byte 1 (skip high addr byte)
	INC	HL		; d0a7  23		#	; HL -> saved byte 2
	INC	HL		; d0a8  23		#	; HL -> next row's screen addr low byte
	DJNZ	XD08F		; d0a9  10 e4		.d	; Decrement B; loop if rows remain (8 -> 0)
	RET			; d0ab  c9		I	; All 8 rows drawn -- return
;

; ==========================================================================
; SAVE_SPRITE_BG ($D0AC)
; ==========================================================================
;
; Saves the screen bitmap contents under a sprite's position into the
; entity's background buffer (offset +5). This allows clean sprite erasure
; later via RESTORE_SPRITE_BG.
;
; ENTRY:
;   HL = pointer to entity data structure
;        (HL)+0 = X position (game coordinates; 0 = inactive/skip)
;        (HL)+1 = Y position (game coordinates)
;
; EXIT:
;   Entity bg buffer at offset +5 filled with 32 bytes:
;     8 rows x 4 bytes per row (addr_lo, addr_hi, screen_byte1, screen_byte2)
;   All registers modified. Returns immediately if entity X = 0.
;
; ALGORITHM:
;   1. Read entity X and Y from the data structure
;   2. Convert to pixel coordinates: pixelX = X*2-3, pixelY = Y*2-3
;   3. Compute byte column = pixelX >> 3 (which 8-pixel-wide byte column)
;   4. Look up the row pointer table at $FC00 for the starting pixel row
;   5. For each of 8 pixel rows:
;      a. Read 16-bit screen address from row pointer table, add byte column
;      b. Store screen address into bg buffer (2 bytes)
;      c. Read 2 screen bytes at that address, store in bg buffer (2 bytes)
;      d. Advance to next row pointer table entry
;
; NOTE: The disassembler failed to trace through this routine because it
; shares the same coordinate-to-screen-address arithmetic as DRAW_MASKED_SPRITE
; and COORDS_TO_ADDR ($CE8A), but was not reached during static trace analysis.
; The bytes from $D0AF-$D0E4 below are presented as DB directives in the
; original disassembly output, but they ARE executable code. The decoded
; instructions are documented in the comments.
;
; CROSS-REFERENCES:
;   Called from main_loop.asm at $C38A (player), $C390 (cursor),
;   $C396 (chaser 1), $C39C (chaser 2), and again at $C452-$C464
;   after movement processing.
;   Output buffer is consumed by DRAW_MASKED_SPRITE ($D078) for screen
;   addresses, and by RESTORE_SPRITE_BG ($D0E5) for restoring pixels.
;
; --- Save sprite bg ---
SAVE_SPRITE_BG:	LD	A,(HL)		; d0ac  7e		~	; A = entity X position (offset +0)
	OR	A		; d0ad  b7		7	; Test if X is zero (entity inactive)
	RET	Z		; d0ae  c8		H	; If X=0, entity is inactive -- skip save
;
; --- The disassembler output below is raw byte data, but decodes as: ---
;
; $D0AF: LD  E,A          ; 5F    ; E = X position (save for later)
; $D0B0: INC HL           ; 23    ; HL -> offset +1 (Y position)
; $D0B1: LD  D,(HL)       ; 56    ; D = Y position
; $D0B2: INC HL           ; 23    ; HL -> offset +2
; $D0B3: INC HL           ; 23    ; HL -> offset +3
; $D0B4: INC HL           ; 23    ; HL -> offset +4
; $D0B5: INC HL           ; 23    ; HL -> offset +5 (bg save buffer start)
; $D0B6: LD  A,E          ; 7B    ; A = X position (retrieve from E)
;
; --- Convert X to pixel byte column ---
; pixelX = X * 2 - 3 (center 8px sprite on 2px game cell)
; byteColumn = pixelX >> 3 (divide by 8 to get screen byte column, 0-31)
;
; $D0B7: ADD A,A          ; 87    ; A = X * 2 (game coords to pixel coords)
; $D0B8: SUB 3            ; D6 03 ; A = X*2 - 3 (sprite left edge pixel X)
; $D0BA: RRA              ; 1F    ; } Rotate right 3 times through carry
; $D0BB: RRA              ; 1F    ; } to divide by 8. Using RRA instead
; $D0BC: RRA              ; 1F    ; } of SRL; carry from SUB is shifted in.
; $D0BD: AND $1F          ; E6 1F ; Mask to 5 bits = byte column (0-31)
; $D0BF: LD  C,A          ; 4F    ; C = byte column offset for screen addr
;
; --- Convert Y to row pointer table index ---
; pixelY = Y * 2 - 3 (center 8px sprite on 2px game cell)
; tableIndex = pixelY * 2 (2 bytes per table entry)
;
; $D0C0: LD  A,D          ; 7A    ; A = Y position (from entity data)
; $D0C1: ADD A,A          ; 87    ; A = Y * 2 (game coords to pixel coords)
; $D0C2: SUB 3            ; D6 03 ; A = Y*2 - 3 (sprite top edge pixel Y)
; $D0C4: ADD A,A          ; 87    ; A = pixelY * 2 (index into row ptr table)
;                                 ;   (each table entry is 2 bytes)
;
; --- Compute row pointer table address (table at $FC00) ---
; Uses the same arithmetic as COORDS_TO_ADDR ($CE8A):
;   E = low byte of index
;   D = $FC + carry (high byte, placing us in the $FC00 page)
;
; $D0C5: LD  E,A          ; 5F    ; E = table index low byte
; $D0C6: ADC A,$FC        ; CE FC ; A = (pixelY*2) + $FC + carry flag
; $D0C8: SUB E            ; 93    ; A = high byte only (subtract low byte)
; $D0C9: LD  D,A          ; 57    ; D = table high byte
;                                 ; DE = address in row pointer table ($FC00+)
;
; --- Swap so HL = table pointer, DE = bg buffer pointer ---
;
; $D0CA: EX  DE,HL        ; EB    ; HL = row ptr table addr, DE = bg buffer ptr
; $D0CB: LD  B,8          ; 06 08 ; B = 8 rows (loop counter)
;
; =======================================================================
; Inner loop: save one pixel row's background (4 bytes per iteration)
; =======================================================================
; For each row:
;   - Read screen address from row pointer table at (HL), add byte column
;   - Save the screen address to the bg buffer
;   - Read 2 screen bytes and save them to the bg buffer
;   - Advance HL to next row pointer table entry
;
; $D0CD: LD  A,C          ; 79    ; A = byte column offset
; $D0CE: ADD A,(HL)       ; 86    ; A = table_lo + column = screen addr low byte
; $D0CF: INC HL           ; 23    ; HL -> table entry high byte
; $D0D0: PUSH HL          ; E5    ; Save table pointer (will need for next row)
; $D0D1: LD  H,(HL)       ; 66    ; H = screen addr high byte from table
; $D0D2: LD  L,A          ; 6F    ; L = screen addr low byte -> HL = screen addr
;
; --- Swap and save the screen address into the bg buffer ---
;
; $D0D3: EX  DE,HL        ; EB    ; HL = bg buffer ptr, DE = screen address
; $D0D4: LD  (HL),E       ; 73    ; Save screen addr low byte to bg buffer
; $D0D5: INC HL           ; 23    ; Advance bg buffer pointer
; $D0D6: LD  (HL),D       ; 72    ; Save screen addr high byte to bg buffer
; $D0D7: INC HL           ; 23    ; Advance bg buffer pointer
;
; --- Read and save the two screen bytes at that address ---
;
; $D0D8: LD  A,(DE)       ; 1A    ; A = first screen byte (left half)
; $D0D9: LD  (HL),A       ; 77    ; Save to bg buffer
; $D0DA: INC HL           ; 23    ; Advance bg buffer pointer
; $D0DB: INC DE           ; 13    ; DE -> next screen byte (right half)
; $D0DC: LD  A,(DE)       ; 1A    ; A = second screen byte (right half)
; $D0DD: LD  (HL),A       ; 77    ; Save to bg buffer
; $D0DE: INC HL           ; 23    ; Advance bg buffer pointer
;
; --- Swap back and advance to next row in the table ---
;
; $D0DF: EX  DE,HL        ; EB    ; HL = (not needed), DE = bg buffer ptr
; $D0E0: POP HL           ; E1    ; Restore row pointer table position
; $D0E1: INC HL           ; 23    ; HL -> next table entry (skip high byte)
; $D0E2: DJNZ $D0CD       ; 10 E9 ; Decrement B; loop for next row (8 -> 0)
; $D0E4: RET              ; C9    ; All 8 rows saved -- return
;
; --- Raw bytes as output by the disassembler (code not traced) ---
	DB	'_#V####{'				; d0af
	DB	87H					; d0b7 .
	DW	X03D6		; d0b8   d6 03      V.
;
	DB	1FH,1FH,1FH,0E6H,1FH,4FH,7AH,87H	; d0ba ...f.Oz.
	DW	X03D6		; d0c2   d6 03      V.
;
	DB	87H,5FH,0CEH,0FCH,93H,57H		; d0c4 ._N|.W
	DW	X06EB		; d0ca   eb 06      k.
;
	DB	8,79H,86H,23H,0E5H,66H,6FH		; d0cc .y.#efo
	DW	X73EB		; d0d3   eb 73      ks
;
	DB	23H,72H,23H,1AH,77H,23H,13H,1AH		; d0d5 #r#.w#..
	DB	77H,23H					; d0dd w#
	DW	XE1EB		; d0df   eb e1      ka
;
	DB	23H,10H					; d0e1 #.
	DW	XC9E9		; d0e3   e9 c9      iI
;
;

; ==========================================================================
; RESTORE_SPRITE_BG ($D0E5)
; ==========================================================================
;
; Restores the screen bitmap contents that were saved by SAVE_SPRITE_BG,
; effectively erasing the sprite by putting back the original background.
;
; ENTRY:
;   HL = pointer to entity data structure
;        (HL)+0 = X position (0 = inactive/skip)
;        (HL)+5..+36 = saved background buffer (32 bytes from SAVE_SPRITE_BG)
;
; EXIT:
;   Screen bytes at the saved addresses restored to pre-sprite state.
;   All registers modified. Returns immediately if entity X = 0.
;
; ALGORITHM:
;   1. Check if entity is active (X != 0)
;   2. Skip to offset +5 (bg save buffer start)
;   3. For each of 8 rows:
;      a. Read 16-bit screen address from buffer (2 bytes)
;      b. Copy 2 saved screen bytes from buffer back to that address
;
; The bg buffer format (written by SAVE_SPRITE_BG) is:
;   8 x (addr_lo, addr_hi, screen_byte_1, screen_byte_2) = 32 bytes
;
; Uses the Z80 LDI instruction (block copy: LD (DE),(HL); INC DE; INC HL;
; DEC BC) to efficiently copy 2 bytes per row. BC is set with B=8 (loop
; counter) and C=$FF (LDI decrements BC, but we only use B for DJNZ).
;
; CROSS-REFERENCES:
;   Called from main_loop.asm at $C3E8 (chaser 2), $C3EE (chaser 1),
;   $C3F4 (cursor), $C3FA (player) -- note reverse order from drawing.
;   Also called from death_scoring.asm at $C713-$C725 during death
;   sequence to erase all sprites before the death animation.
;
; --- Restore sprite bg ---
RESTORE_SPRITE_BG:	LD	A,(HL)		; d0e5  7e		~	; A = entity X position (offset +0)
	OR	A		; d0e6  b7		7	; Test if X is zero (entity inactive)
	RET	Z		; d0e7  c8		H	; If X=0, entity is inactive -- skip restore
	LD	DE,X0005	; d0e8  11 05 00	...	; DE = 5 (offset to bg save buffer)
	ADD	HL,DE		; d0eb  19		.	; HL = HL + 5 -> points to bg buffer start
	LD	BC,X08FF	; d0ec  01 ff 08	...	; B = 8 (row counter), C = $FF (LDI padding)
; ==========================================================================
; Inner loop: restore one pixel row (read 4 bytes from buffer)
; ==========================================================================
; Each iteration reads a saved entry: (addr_lo, addr_hi, byte1, byte2)
; and writes byte1 and byte2 back to the screen at the saved address.
;
XD0EF:	LD	E,(HL)		; d0ef  5e		^	; E = saved screen address low byte
	INC	HL		; d0f0  23		#	; HL -> saved screen address high byte
	LD	D,(HL)		; d0f1  56		V	; D = saved screen address high byte
	INC	HL		; d0f2  23		#	; HL -> saved screen byte 1 (left)
; --- Copy 2 bytes from bg buffer to screen ---
; LDI: copy (HL) to (DE), increment both, decrement BC.
; This writes the saved background bytes back to the screen.
	LDI			; d0f3  ed a0		m 	; Copy byte 1: (DE) <- (HL); DE++; HL++; BC--
	LDI			; d0f5  ed a0		m 	; Copy byte 2: (DE) <- (HL); DE++; HL++; BC--
	DJNZ	XD0EF		; d0f7  10 f6		.v	; Decrement B; loop for next row (8 -> 0)
	RET			; d0f9  c9		I	; All 8 rows restored -- return
;

; ==========================================================================
; UNREFERENCED CODE REGION ($D0FA-$D14E)
; ==========================================================================
;
; This block contains what appears to be additional sprite manipulation
; routines that are not called anywhere in the game's traced code paths.
; They may be:
;   - Shadow grid ($6000) versions of save/restore (for the duplicate
;     screen buffer used by chasers and sparks)
;   - Development/debug routines left in the binary
;   - Alternative implementations that were superseded
;
; The disassembler could not trace into this region and output the bytes
; as raw data with only partial instruction decoding. The routines follow
; the same patterns as SAVE/RESTORE_SPRITE_BG above (same check-active
; prologue, same LDI-based copy loops, same row pointer table math).
;
; $D0FA-$D0FC: "Check active" prologue (LD A,(HL); OR A; RET Z)
; $D0FD-$D14E: What appears to be save-bg and restore-bg variants,
;              possibly operating on the shadow grid at $6000 instead of
;              the main screen at $4000. The routines contain the same
;              row-pointer-table lookup, screen address computation, and
;              LDI-based byte copy patterns.
;
; At $D13E the disassembler partially decoded some instructions:
;   OR C; LD (DE),A; INC HL -- consistent with screen byte manipulation.
; At $D141: LD BC,$03FF; and the loop at $D144 is a 3-row restore loop
;   (B=3 rows with LDI x2 per row), possibly for a smaller sprite or
;   partial screen area.
;
	DB	7EH					; d0fa ~
	DW	XC8B7		; d0fb   b7 c8      7H
;
	DB	1					; d0fd .
XD0FE:	DB	0,0CH,87H				; d0fe ...
	DW	X03D6		; d101   d6 03      V.
	DW	X3FCB		; d103   cb 3f      K?
	DW	X03E6		; d105   e6 03      f.
;
	DB	28H,0BH					; d107 (.
	DW	X38CB		; d109   cb 38      K8
	DW	X19CB		; d10b   cb 19      K.
	DW	X38CB		; d10d   cb 38      K8
	DW	X19CB		; d10f   cb 19      K.
;
	DB	3DH,20H					; d111 =
	DW	XC5F5		; d113   f5 c5      uE
;
	DB	11H,5,0,19H,1,0FFH,3,5EH		; d115 .......^
	DB	23H,56H,23H				; d11d #V#
	DW	XA0ED		; d120   ed a0      m
	DW	XA0ED		; d122   ed a0      m
;
	DB	10H,0F6H,0C1H,5EH,23H,56H,23H,7EH	; d124 .vA^#V#~
	DB	0B0H,12H,23H,13H,7EH			; d12c 0.#.~
	DW	X12B1		; d131   b1 12      1.
;
	DB	'#^#V#~'				; d133
	DB	0B0H,12H,23H,13H,7EH			; d139 0.#.~
;
	OR	C		; d13e  b1		1	; (partially decoded) OR C into accumulator
	LD	(DE),A		; d13f  12		.	; Write accumulator to (DE) screen address
	INC	HL		; d140  23		#	; Advance buffer pointer
	LD	BC,X03FF	; d141  01 ff 03	...	; B=3 (row counter), C=$FF (LDI padding)
; --- Small restore loop: 3 rows x 2 bytes ---
; Same structure as RESTORE_SPRITE_BG but only 3 rows (possibly for a
; partial sprite area or a different context).
XD144:	LD	E,(HL)		; d144  5e		^	; E = saved screen address low byte
	INC	HL		; d145  23		#	; HL -> saved screen address high byte
	LD	D,(HL)		; d146  56		V	; D = saved screen address high byte
	INC	HL		; d147  23		#	; HL -> saved screen byte 1
	LDI			; d148  ed a0		m 	; Copy byte 1: (DE) <- (HL); DE++; HL++; BC--
	LDI			; d14a  ed a0		m 	; Copy byte 2: (DE) <- (HL); DE++; HL++; BC--
	DJNZ	XD144		; d14c  10 f6		.v	; Decrement B; loop for next row (3 -> 0)
	RET			; d14e  c9		I	; Return after 3-row restore
;

; ==========================================================================
; 16-BIT UNSIGNED DIVISION ($D14F)
; ==========================================================================
;
; Performs unsigned 16-bit integer division: BC / DE.
;
; ENTRY:
;   B:C = 16-bit dividend (B = high byte, C = low byte)
;   DE  = 16-bit divisor
;
; EXIT:
;   B:A = quotient high byte (B) and low bits (A)
;     -- actually the quotient is returned in A:C (see below)
;   B:C = 16-bit quotient (result of BC / DE)
;     -- quotient bits are shifted into A:C during the loop, then
;        B is loaded from A at the end
;   HL  = 16-bit remainder (BC mod DE)
;
; ALGORITHM:
;   Standard binary long division (restoring division) with 16 iterations.
;   For each bit of the dividend (MSB first):
;     1. Shift the next dividend bit into the remainder (HL)
;     2. Try subtracting the divisor (DE) from the remainder
;     3. If subtraction succeeds (no borrow): quotient bit = 1
;     4. If subtraction fails (borrow): restore remainder, quotient bit = 0
;
;   The quotient bits are shifted into A:C from the right, building up the
;   16-bit quotient one bit at a time. After 16 iterations, A:C contains
;   the full quotient and HL contains the remainder.
;
; RESTORING DIVISION DETAIL:
;   - XD155 path: trial subtraction succeeded -> CCF flips carry to NC,
;     which means "quotient bit = 1" will be shifted in on next RL C/RLA
;   - XD164 path: trial subtraction failed -> add divisor back to HL
;     (restoring the remainder), then shift in "quotient bit = 0"
;
; CROSS-REFERENCES:
;   Called from CALC_PERCENTAGE in death_scoring.asm at $C788 and $C79D:
;     LD DE,$005A (90 decimal)
;     CALL XD14F
;   Computes claimed_cells / 90 -> raw percentage
;   and (filled_cells - 396) / 90 -> fill percentage
;   (The game field interior is 122 x 74 = 9028 cells, and 9028/90 ~= 100%)
;
XD14F:	LD	A,B		; d14f  78		x	; A = dividend high byte (B)
	LD	B,10H		; d150  06 10		..	; B = 16 (iteration counter, one per bit)
	LD	HL,X0000	; d152  21 00 00	!..	; HL = 0 (initialize remainder to zero)
; ==========================================================================
; Division loop: trial subtraction path (remainder was >= divisor)
; ==========================================================================
; This entry point is used when the previous subtraction succeeded,
; meaning the remainder is still valid after SBC HL,DE.
;
XD155:	RL	C		; d155  cb 11		K.	; Shift C left; carry -> bit 0 (quotient bit in)
	RLA			; d157  17		.	; Shift A left through carry (A:C = dividend shift)
	ADC	HL,HL		; d158  ed 6a		mj	; HL = HL*2 + carry (shift dividend bit into remainder)
	SBC	HL,DE		; d15a  ed 52		mR	; Trial subtract: HL = HL - DE (try removing divisor)
XD15C:	CCF			; d15c  3f		?	; Complement carry flag: C=0 after SBC means it fit,
	; 					        ;   so CCF makes C=1 -> this quotient bit = 1.
	; 					        ;   C=1 after SBC means borrow (didn't fit),
	; 					        ;   so CCF makes C=0 -> quotient bit = 0.
	JR	NC,XD170	; d15d  30 11		0.	; If carry clear (subtraction failed after CCF):
	; 					        ;   jump to XD170 to enter the "restore" path
	; 					        ;   which will add the divisor back
XD15F:	DJNZ	XD155		; d15f  10 f4		.t	; Decrement B; loop back to XD155 if bits remain
	JP	XD172		; d161  c3 72 d1	CrQ	; All 16 bits done -- jump to finalization
;
; ==========================================================================
; Division loop: restore path (remainder was < divisor)
; ==========================================================================
; This entry point is used when the previous subtraction failed (borrow).
; We need to ADD the divisor back to restore the remainder, then try
; the next dividend bit.
;
XD164:	RL	C		; d164  cb 11		K.	; Shift C left; carry -> bit 0 (quotient bit in)
	RLA			; d166  17		.	; Shift A left through carry (A:C = dividend shift)
	ADC	HL,HL		; d167  ed 6a		mj	; HL = HL*2 + carry (shift next dividend bit into remainder)
	OR	A		; d169  b7		7	; Clear carry flag (so ADC = ADD)
	ADC	HL,DE		; d16a  ed 5a		mZ	; HL = HL + DE (restore: add divisor back to remainder)
	; 					        ;   Note: no SBC instruction on Z80 for 16-bit;
	; 					        ;   instead we add and check if result >= divisor
	JR	C,XD15F		; d16c  38 f1		8q	; If carry set: remainder overflowed -> subtraction
	; 					        ;   would succeed -> go to "success" path at XD15F
	JR	Z,XD15C		; d16e  28 ec		(l	; If zero: remainder exactly equals divisor ->
	; 					        ;   subtraction succeeds -> jump to CCF at XD15C
XD170:	DJNZ	XD164		; d170  10 f2		.r	; Decrement B; loop back to XD164 if bits remain
; --- Finalization: extract quotient result ---
XD172:	RL	C		; d172  cb 11		K.	; Shift final quotient bit into C
	RLA			; d174  17		.	; Shift final quotient bit into A
	LD	B,A		; d175  47		G	; B = quotient high byte (A)
	; 					        ; B:C = 16-bit quotient, HL = remainder
	RET			; d176  c9		I	; Return with quotient in B:C, remainder in HL
;

; ==========================================================================
; 16-BIT UNSIGNED MULTIPLICATION ($D177) -- UNREFERENCED
; ==========================================================================
;
; Performs unsigned 16-bit multiplication: B:C * DE -> result in HL.
; Uses the standard shift-and-add algorithm.
;
; ENTRY:
;   B:C = 16-bit multiplicand (B = high byte, C = low byte)
;   DE  = 16-bit multiplier
;
; EXIT:
;   HL = 16-bit product (low 16 bits of B:C * DE)
;   Flags modified.
;
; ALGORITHM:
;   For each of 16 bits of the multiplicand (MSB first):
;     1. Shift B:C left; MSB goes into carry
;     2. If carry set: add DE to HL (partial product)
;     3. Shift HL left (double the running total)
;   After 15 iterations, handle the final overflow case.
;
; NOTE: This routine is NOT called anywhere in the game's traced code paths.
; It may be a general-purpose math library routine included by the assembler
; or development toolchain. The division routine above ($D14F) IS used for
; percentage calculations, but this multiply is unreferenced.
;
; The bytes below were not decoded as instructions by the disassembler:
;
; $D177: LD  A,B          ; 78    ; A = multiplicand high byte
; $D178: LD  B,15         ; 06 0F ; B = 15 (loop counter, 15 iterations)
; $D17A: LD  HL,$0000     ; 21 00 00 ; HL = 0 (initialize product accumulator)
; $D17D: SLA C            ; CB 21 ; Shift C left, MSB -> carry
; $D17F: RLA              ; 17    ; Rotate A left through carry (A:C shift)
; $D180: JR  NC,$D183     ; 30 01 ; If carry clear, skip the ADD
; $D182: ADD HL,DE        ; 19    ; HL += DE (add multiplier to partial product)
; $D183: ADD HL,HL        ; 29    ; HL *= 2 (shift product left)
; $D184: DJNZ $D17D       ; 10 F7 ; Loop for 15 iterations
; $D186: OR  A            ; B7    ; Test A (clear carry, check sign)
; $D187: RET P            ; F0    ; If positive (bit 15 of multiplicand was 0): done
; $D188: ADD HL,DE        ; 19    ; If negative (final bit was 1): add DE one more time
; $D189: RET              ; C9    ; Return with product in HL
;
	DB	78H,6,0FH,21H,0,0			; d177 x..!..
	DW	X21CB		; d17d   cb 21      K!
;
	DB	17H,30H,1,19H,29H,10H,0F7H		; d17f .0..).w
	DW	XF0B7		; d186   b7 f0      7p
;
	DB	19H,0C9H				; d188 .I
;
