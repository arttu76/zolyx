; ==========================================================================
; CELL READ/WRITE & BORDER DRAWING ($CE62-$CF00)
; ==========================================================================
;
; These routines handle reading and writing the 2-bit packed game cells.
; Each cell is 2x2 pixels in a 128x128 grid.
;
; DRAW_BORDER_RECT ($CE62):
;   Draws the game field border rectangle at the start of each level.
;
; COORDS_TO_ADDR ($CE8A):
;   Converts game coordinates to bitmap screen address.
;   Input: E=game X, D=game Y
;   Output: HL=bitmap address of top pixel row
;   Algorithm: pixelY = Y*2, pixelX = X*2, compute ZX screen address.
;
; WRITE_CELL_BOTH ($CE9F):
;   Writes cell to BOTH bitmap ($4000) and shadow grid ($6000).
;   Used for: border, claimed, empty.
;
; WRITE_CELL_BMP ($CEAE):
;   Writes cell to bitmap ONLY, not shadow.
;   Used for: trail cells and spark rendering.
;   This is how trail is "invisible" to sparks/chasers reading shadow.
;
; READ_CELL_BMP ($CEDE):
;   Reads cell value from bitmap. Returns visual state (includes trail).
;
; READ_CELL_SHADOW ($CEF3):
;   Reads cell value from shadow grid. Trail appears as empty.
;   Used by spark movement and chaser wall-following.
;
; Cell encoding (2-bit values):
;   0 = empty   (pattern $00/$00)
;   1 = claimed  (pattern $55/$00 - checkerboard)
;   2 = trail   (pattern $AA/$55 - dense checker)
;   3 = border  (pattern $FF/$FF - solid)
;
; Mask table at $FB00: $C0, $30, $0C, $03 (cell position within byte)
;

;

; ==========================================================================
; DRAW_BORDER_RECT ($CE62)
; ==========================================================================
;
; Draws the rectangular border around the game playing field.
; Called from trail_cursor_init ($CC8E) at the start of each level.
;
; The border is a closed rectangle of "border" cells (value 3) drawn
; clockwise: top edge (left to right), right edge (top to bottom),
; bottom edge (right to left), left edge (bottom to top).
;
; The rectangle spans:
;   X: 2 to 125 (inclusive) -- 124 cells wide
;   Y: 18 ($12) to 93 ($5D) (inclusive) -- 76 cells tall
;
; These are game coordinates. The interior (fillable area) is one cell
; inward from each edge: X=[3,124], Y=[19,92].
;
; All border cells are written to BOTH the screen bitmap and the shadow
; grid via WRITE_CELL_BOTH, so chasers and sparks can see the border.
;
; Entry: (none -- coordinates are hardcoded)
; Exit:  DE = (2, $12) -- back to starting corner
; Modifies: AF, BC, DE, HL
;
; --- Draw border rect ---
DRAW_BORDER_RECT:	LD	DE,X1202	; ce62  11 02 12	; DE = starting corner: E=2 (X), D=$12=18 (Y)
;
; --- Top edge: draw from X=2 to X=$7C (124), Y=18 fixed ---
XCE65:	CALL	WRITE_CELL_BOTH		; ce65  cd 9f ce	; Write border cell (value 3) to both bitmap and shadow
	INC	E		; ce68  1c		; Move one cell to the right (X++)
	LD	A,E		; ce69  7b		; Load current X into A for comparison
	CP	7DH		; ce6a  fe 7d		; Have we reached X=125 ($7D)? (last column of border)
	JR	NZ,XCE65	; ce6c  20 f7		; If not, keep drawing top edge rightward
;
; --- Right edge: draw from Y=18 to Y=$5C (92), X=125 fixed ---
; (E=125 from the top-edge loop exit, D still=$12 initially, then increments)
XCE6E:	CALL	WRITE_CELL_BOTH		; ce6e  cd 9f ce	; Write border cell at current position on right edge
	INC	D		; ce71  14		; Move one cell downward (Y++)
	LD	A,D		; ce72  7a		; Load current Y into A for comparison
	CP	5DH		; ce73  fe 5d		; Have we reached Y=93 ($5D)? (bottom-right corner)
	JR	NZ,XCE6E	; ce75  20 f7		; If not, keep drawing right edge downward
;
; --- Bottom edge: draw from X=125 back to X=2, Y=93 fixed ---
; (D=$5D=93, E decrements from 125)
XCE77:	CALL	WRITE_CELL_BOTH		; ce77  cd 9f ce	; Write border cell at current position on bottom edge
	DEC	E		; ce7a  1d		; Move one cell to the left (X--)
	LD	A,E		; ce7b  7b		; Load current X into A for comparison
	CP	2		; ce7c  fe 02		; Have we reached X=2? (bottom-left corner)
	JR	NZ,XCE77	; ce7e  20 f7		; If not, keep drawing bottom edge leftward
;
; --- Left edge: draw from Y=93 back to Y=$12 (18), X=2 fixed ---
; (E=2, D decrements from $5D=93)
XCE80:	CALL	WRITE_CELL_BOTH		; ce80  cd 9f ce	; Write border cell at current position on left edge
	DEC	D		; ce83  15		; Move one cell upward (Y--)
	LD	A,D		; ce84  7a		; Load current Y into A for comparison
	CP	12H		; ce85  fe 12		; Have we reached Y=$12=18? (back to top-left corner)
	JR	NZ,XCE80	; ce87  20 f7		; If not, keep drawing left edge upward
	RET			; ce89  c9		; Border rectangle is complete; return
;

; ==========================================================================
; COORDS_TO_ADDR ($CE8A)
; ==========================================================================
;
; Converts game-grid coordinates into a ZX Spectrum screen bitmap address.
;
; The ZX Spectrum screen bitmap ($4000-$57FF, 6144 bytes) has a notoriously
; non-linear memory layout. It is divided into 3 "thirds" (0-63, 64-127,
; 128-191 pixel rows), and within each third, rows are interleaved:
;   lines 0,8,16,24,32,40,48,56, then 1,9,17,25,33,41,49,57, etc.
;
; To avoid computing this complex mapping on every cell access, the game
; uses a pre-computed ROW POINTER TABLE at $FC00. This table contains
; 2-byte screen addresses (lo, hi) for each pixel row used by the game
; grid. Since each game cell is 2 pixels tall, game Y coordinate maps
; to pixel row Y*2, and the table is indexed as Y*4 (2 bytes per entry,
; 2 pixel rows per cell = 4 bytes per game row).
;
; For the X coordinate, each screen byte holds 8 pixels = 4 game cells
; (each cell is 2 pixels wide). So the byte offset within a row is X/4
; (equivalently, X >> 2). The remaining X & 3 tells which 2-bit cell
; position within the byte.
;
; Entry:
;   E = game X coordinate (range 2..125)
;   D = game Y coordinate (range 18..93)
;   A = cell value to write (if called before WRITE; preserved in AF')
;
; Exit:
;   HL = screen bitmap address of the TOP pixel row of the cell
;        (i.e., the address of the byte in the $4000-$57FF region
;        that contains this cell's top 2 pixels)
;   A  = cell value (restored from AF'; available for caller)
;   AF'= game X coordinate stored in A' (used later by WRITE/READ
;        to determine which 2-bit position within the byte)
;
; The BOTTOM pixel row address is obtained by the caller via INC H,
; which works because the ZX Spectrum screen layout places consecutive
; pixel lines within a character cell at H+1 offsets.
;
; Modifies: AF, AF', HL
;
; --- Coords to addr ---
COORDS_TO_ADDR:	EX	AF,AF'		; ce8a  08		; Save A (cell value) into the alternate A register
	LD	A,D		; ce8b  7a		; A = game Y coordinate (D register)
	ADD	A,A		; ce8c  87		; A = Y * 2 (first doubling; carry set if Y >= 128)
	ADD	A,A		; ce8d  87		; A = Y * 4 (second doubling; carry set if Y*2 >= 128, i.e., Y >= 64)
;
; Now A = (Y * 4) mod 256, and Carry = overflow bit from multiplication.
; We want HL = $FC00 + Y*4 to index into the row pointer table.
; L gets the low byte (Y*4 mod 256), H gets $FC or $FD depending on carry.
;
	LD	L,A		; ce8e  6f		; L = low byte of Y*4 (table offset within page)
	ADC	A,0FCH		; ce8f  ce fc		; A = (Y*4 mod 256) + $FC + carry_from_Y*4
	SUB	L		; ce91  95		; A = $FC + carry (subtract out the Y*4 low byte)
;                                               ;   If Y < 64: no carry, H = $FC. Table page = $FC.
;                                               ;   If Y >= 64: carry set, H = $FD. Table page = $FD.
	LD	H,A		; ce92  67		; H = $FC or $FD. Now HL = $FC00 + Y*4 (pointer into row table)
;
; HL now points to the 2-byte screen address entry for this game row's
; top pixel line. Each entry is: [low_byte, high_byte] of the screen
; address for the leftmost byte (X=0) of that pixel row.
;
; Next, compute the byte offset within the row from game X coordinate.
; Each byte holds 8 pixels = 4 cells (2 pixels per cell), so offset = X / 4.
;
	LD	A,E		; ce93  7b		; A = game X coordinate (E register)
	RRA			; ce94  1f		; A = (carry << 7) | (X >> 1) -- rotate right through carry
	RRA			; ce95  1f		; A = (carry << 7) | (prev >> 1) -- rotate right again
	AND	3FH		; ce96  e6 3f		; Mask off top 2 bits, giving A = X >> 2 = byte offset in row
;                                               ;   (AND $3F clears bits 7-6 which may contain junk from carry/rotation)
;                                               ;   Valid range: X=2..125 => offset 0..31
;
	ADD	A,(HL)		; ce98  86		; Add byte offset to the row's base low-byte address
;                                               ;   A = table_lo[Y] + (X >> 2)
	INC	HL		; ce99  23		; Point to the high byte of the table entry
	LD	H,(HL)		; ce9a  66		; H = table_hi[Y] (screen address high byte, e.g., $40-$57)
	LD	L,A		; ce9b  6f		; L = computed low byte. Now HL = screen address of the byte
;                                               ;   containing this cell's top pixel row
;
	LD	A,E		; ce9c  7b		; A = game X coordinate again (needed by caller to find
;                                               ;   the 2-bit position within the byte via X & 3)
	EX	AF,AF'		; ce9d  08		; Swap back: A restored to cell value, A' now holds game X
;                                               ;   The caller will use A' (via masking with X & 3) to locate
;                                               ;   the correct 2-bit cell within the byte at (HL)
	RET			; ce9e  c9		; Return. HL=screen address, A=cell value, A'=game X
;

; ==========================================================================
; WRITE_CELL_BOTH ($CE9F)
; ==========================================================================
;
; Writes a cell value to BOTH the main screen bitmap ($4000 region) AND
; the shadow grid ($6000 region). The shadow grid is a mirror of the
; screen bitmap used by enemy AI (sparks and chasers) for navigation.
;
; This routine is used for permanent cell types that should be visible
; to both the player and the enemy AI: border cells (value 3), claimed
; cells (value 1), and empty cells (value 0).
;
; The shadow grid starts at $6000, which is exactly $2000 above the
; screen bitmap at $4000. Since bit 5 of the high byte differentiates
; them ($40xx has bit5=0, $60xx has bit5=1), SET 5,H flips between them.
;
; Entry:
;   E = game X coordinate
;   D = game Y coordinate
;   (cell value is hardcoded as 3 = border; this routine is only called
;    from DRAW_BORDER_RECT which always writes border cells)
;
; Exit:
;   DE preserved (coordinates unchanged for loop continuation)
;   HL, AF, BC modified
;
; Called from:
;   DRAW_BORDER_RECT ($CE62) -- draws border cells around the field
;   flood_fill.asm -- fills claimed regions on both bitmap and shadow
;
; --- Write cell both ---
WRITE_CELL_BOTH:	PUSH	DE		; ce9f  d5		; Save game coordinates (needed by caller's loop)
	LD	A,3		; cea0  3e 03		; A = 3 (border cell value -- solid $FF/$FF pattern)
	CALL	XCEB1		; cea2  cd b1 ce	; Write cell value 3 to the MAIN BITMAP at (E,D)
;                                               ;   XCEB1 calls COORDS_TO_ADDR then falls into the write logic
;                                               ;   After return, HL still points to the bitmap address
	SET	5,H		; cea5  cb ec		; Flip H bit5: $4xxx -> $6xxx (switch to shadow grid address)
;                                               ;   e.g., $4820 becomes $6820
	LD	A,3		; cea7  3e 03		; A = 3 again (cell value for shadow grid write)
	CALL	XCEB4		; cea9  cd b4 ce	; Write cell value 3 to the SHADOW GRID at same position
;                                               ;   XCEB4 skips COORDS_TO_ADDR (address already in HL)
	POP	DE		; ceac  d1		; Restore game coordinates for the caller
	RET			; cead  c9		; Return to caller (DRAW_BORDER_RECT loop)
;

; ==========================================================================
; WRITE_CELL_BMP ($CEAE)
; ==========================================================================
;
; Writes a cell value to the main screen bitmap ONLY, not to the shadow
; grid. This is crucial for trail cells (value 2): because trail is only
; written to the bitmap, sparks and chasers reading the shadow grid will
; see "empty" where trail actually exists. This is the fundamental
; mechanism that makes trail invisible to enemy AI.
;
; Also used by the main loop ($C3C7-$C43A) for rendering spark movement
; and temporary visual effects that shouldn't affect the shadow grid.
;
; The first two instructions (INC E; DEC E) are a clever idiom to test
; if E == 0 without destroying A. If E is zero, the Z flag is set and
; the routine returns immediately via RET Z. This guards against writing
; to X=0 which would be outside the game field.
;
; Entry:
;   A = cell value to write (0=empty, 1=claimed, 2=trail, 3=border)
;   E = game X coordinate
;   D = game Y coordinate
;
; Exit:
;   HL = screen bitmap address (top pixel row, after DEC H at end)
;   A, AF', BC, DE modified
;
; Called from:
;   main_loop.asm ($C3C7-$C43A) -- spark/trail rendering
;   player_movement.asm -- writing trail cells as player moves
;
; --- Write cell bitmap ---
WRITE_CELL_BMP:	INC	E		; ceae  1c		; Increment E to test if it was 0
	DEC	E		; ceaf  1d		; Decrement E back (restores original value, sets Z if E==0)
	RET	Z		; ceb0  c8		; If E was 0, return immediately (guard: X=0 is invalid)
;
; --- Shared entry point: convert coords then write ---
; XCEB1 is also called by WRITE_CELL_BOTH to perform coord conversion + write.
;
XCEB1:	CALL	COORDS_TO_ADDR		; ceb1  cd 8a ce	; Convert (E,D) game coords to HL=screen address
;                                               ;   After this: HL=bitmap addr, A=cell value, A'=game X
;
; ==========================================================================
; XCEB4: Core cell-write engine (shared by WRITE_CELL_BOTH and WRITE_CELL_BMP)
; ==========================================================================
;
; Writes a 2-bit cell pattern into the screen bitmap at address HL.
; Each cell occupies a 2x2 pixel area:
;   - Top 2 pixels:  in the byte at (HL), bits determined by X & 3
;   - Bottom 2 pixels: in the byte at (HL + $100), same bit position
;     (INC H moves down one pixel line in ZX Spectrum screen layout)
;
; The cell pattern is looked up from CELL_PATTERNS ($B0C9), which stores
; 2 bytes per cell value (top row pattern, bottom row pattern).
; These patterns are full-byte values that get masked to the correct
; 2-bit position using the CELL MASK TABLE at $FB00.
;
; Cell patterns at $B0C9 (2 bytes each, for 4 cell values):
;   Value 0 (empty):   $00, $00  -- both rows blank
;   Value 1 (claimed): $55, $00  -- top=01010101 (checkerboard), bottom=00000000
;   Value 2 (trail):   $AA, $55  -- top=10101010, bottom=01010101 (dense checker)
;   Value 3 (border):  $FF, $FF  -- both rows solid (all pixels set)
;
; Mask table at $FB00 (indexed by X & 3):
;   [0] = $C0 = 11000000b  -- leftmost cell in byte (bits 7-6)
;   [1] = $30 = 00110000b  -- second cell (bits 5-4)
;   [2] = $0C = 00001100b  -- third cell (bits 3-2)
;   [3] = $03 = 00000011b  -- rightmost cell (bits 1-0)
;
; Algorithm for each pixel row:
;   1. Read the mask for this cell's position: mask = $FB00[X & 3]
;   2. Clear the old cell bits: screen_byte &= ~mask
;   3. Read the new pattern byte from CELL_PATTERNS
;   4. Mask the pattern to just this cell's bits: pattern &= mask
;   5. OR the masked pattern into the screen byte: screen_byte |= pattern
;
; Entry:
;   A  = cell value (0-3)
;   HL = screen bitmap address (top pixel row of the cell)
;   A' = game X coordinate (from COORDS_TO_ADDR, in the alternate A register)
;
; Exit:
;   HL = screen address (top row -- H decremented back at end)
;   BC, DE modified
;
XCEB4:	ADD	A,A		; ceb4  87		; A = cell_value * 2 (each pattern is 2 bytes: top + bottom row)
	LD	BC,CELL_PATTERNS	; ceb5  01 c9 b0	; BC = $B0C9 (base address of cell pattern table)
	ADD	A,C		; ceb8  81		; Add offset to low byte: C = $C9 + cell_value*2
	LD	C,A		; ceb9  4f		; C = low byte of pattern address
	ADC	A,B		; ceba  88		; A = C + B + carry (handle page crossing)
	SUB	C		; cebb  91		; A = B + carry (isolate high byte adjustment)
	LD	B,A		; cebc  47		; B = high byte of pattern address
;                                               ;   Now BC = $B0C9 + cell_value*2 = pointer to this cell's pattern
;
; Determine which 2-bit position within the byte this cell occupies.
; The position depends on (game_X & 3), used to index the mask table at $FB00.
;
	LD	A,E		; cebd  7b		; A = game X coordinate (still in E from COORDS_TO_ADDR)
;                                               ;   NOTE: After COORDS_TO_ADDR, E still holds game X because
;                                               ;   COORDS_TO_ADDR only reads E, doesn't modify it
	AND	3		; cebe  e6 03		; A = X & 3 (cell position within byte: 0-3)
	LD	E,A		; cec0  5f		; E = mask table index (0-3)
	LD	D,0FBH		; cec1  16 fb		; D = $FB (high byte of mask table base address)
;                                               ;   Now DE = $FB00 + (X & 3) = address of the 2-bit mask
;
; --- Write top pixel row ---
; Clear the old cell's 2 bits, then OR in the new pattern's 2 bits.
;
	LD	A,(DE)		; cec3  1a		; A = mask byte from $FB00 (e.g., $C0 for position 0)
	CPL			; cec4  2f		; A = ~mask (inverted: e.g., $3F). This clears the cell's bits.
	AND	(HL)		; cec5  a6		; A = screen_byte & ~mask (clear old cell bits, keep others)
	LD	(HL),A		; cec6  77		; Write back to screen: old cell bits are now zeroed
	LD	A,(BC)		; cec7  0a		; A = top-row pattern byte from CELL_PATTERNS (e.g., $FF for border)
	EX	DE,HL		; cec8  eb		; Swap DE<->HL. Now HL=$FB0x (mask addr), DE=screen addr
	AND	(HL)		; cec9  a6		; A = pattern & mask (isolate only this cell's 2 bits from pattern)
	EX	DE,HL		; ceca  eb		; Swap back. HL=screen addr, DE=$FB0x (mask addr)
	OR	(HL)		; cecb  b6		; A = (cleared screen byte) | (masked pattern) -- merge new bits in
	LD	(HL),A		; cecc  77		; Write final byte back to screen bitmap (top row done)
;
; --- Write bottom pixel row ---
; Move down one pixel line (INC H) and repeat the same mask-and-OR process.
; On the ZX Spectrum, consecutive pixel lines within the same character cell
; are stored $100 bytes apart (incrementing H by 1), so INC H moves to the
; next pixel line directly below.
;
	INC	BC		; cecd  03		; BC now points to the BOTTOM row pattern byte (2nd byte in pair)
	INC	H		; cece  24		; Move HL down one pixel line (H++ = next pixel row in ZX layout)
	LD	A,(DE)		; cecf  1a		; A = mask byte again (same mask, same horizontal position)
	CPL			; ced0  2f		; A = ~mask (inverted mask to clear old bits)
	AND	(HL)		; ced1  a6		; A = screen_byte & ~mask (clear old cell bits on bottom row)
	LD	(HL),A		; ced2  77		; Write cleared byte back to screen
	LD	A,(BC)		; ced3  0a		; A = bottom-row pattern byte from CELL_PATTERNS
	EX	DE,HL		; ced4  eb		; Swap DE<->HL. HL=$FB0x (mask addr), DE=screen addr
	AND	(HL)		; ced5  a6		; A = pattern & mask (isolate this cell's 2 bits for bottom row)
	EX	DE,HL		; ced6  eb		; Swap back. HL=screen addr, DE=$FB0x
	OR	(HL)		; ced7  b6		; A = (cleared screen byte) | (masked pattern)
	LD	(HL),A		; ced8  77		; Write final byte to screen bitmap (bottom row done)
;
; Restore HL to point to the top pixel row (undo the INC H from above).
; Callers like WRITE_CELL_BOTH rely on HL still pointing to the top row
; so they can SET 5,H to switch to the shadow grid address.
;
	DEC	H		; ced9  25		; Move HL back up to top pixel row (undo INC H)
	RET			; ceda  c9		; Return. Cell has been written to screen.
;

; ==========================================================================
; XCEDB: Alternate entry point (COORDS_TO_ADDR + READ_CELL_BMP)
; ==========================================================================
;
; Convenience entry point that converts coordinates and then reads the cell.
; Callers who already have HL set can jump directly to READ_CELL_BMP ($CEDE).
;
; Entry:
;   E = game X coordinate
;   D = game Y coordinate
;
; Exit:
;   A = cell value (0-3)
;   HL = screen address of the cell
;
XCEDB:	CALL	COORDS_TO_ADDR		; cedb  cd 8a ce	; Convert (E,D) coords to HL=screen bitmap address

; ==========================================================================
; READ_CELL_BMP ($CEDE)
; ==========================================================================
;
; Reads the cell value (0-3) from the main screen bitmap at address HL.
;
; The cell value is encoded in 2 bits within a byte. This routine extracts
; those 2 bits by:
;   1. Loading the full screen byte
;   2. Shifting it right by (3 - (X & 3)) * 2 bit positions to move the
;      target cell's bits into the lowest 2 bit positions
;   3. Masking with AND 3 to isolate the 2-bit value
;
; Why (3 - (X & 3))? The cells are packed left-to-right in a byte:
;   Cell position 0 (X & 3 = 0): bits 7-6 (need 3 shifts of 2 = 6 right)
;   Cell position 1 (X & 3 = 1): bits 5-4 (need 2 shifts of 2 = 4 right)
;   Cell position 2 (X & 3 = 2): bits 3-2 (need 1 shift  of 2 = 2 right)
;   Cell position 3 (X & 3 = 3): bits 1-0 (need 0 shifts     = already there)
;
; So shift_count = 3 - (X & 3). The routine computes this as NEG(X & 3) + 3.
; If the result is 0, it skips the shift loop entirely.
;
; Entry:
;   HL = screen bitmap address (from COORDS_TO_ADDR or caller)
;   E  = game X coordinate (or A' contains it; E is used here)
;
; Exit:
;   A = cell value (0=empty, 1=claimed, 2=trail, 3=border)
;   B = shifted screen byte (partially consumed)
;   HL preserved
;
; Called from:
;   chaser.asm ($CB22, $CB45, $CB6A) -- wall-following direction checks
;   player_movement.asm ($C8AE, $C8D4) -- checking what's ahead of player
;   spark.asm ($D19B-$D259) -- checking cells in all 4 spark directions
;   main_loop.asm -- various cell checks
;
; --- Read cell bitmap ---
READ_CELL_BMP:	LD	B,(HL)		; cede  46		; B = screen byte at HL (contains four 2-bit cells packed)
	LD	A,E		; cedf  7b		; A = game X coordinate
	AND	3		; cee0  e6 03		; A = X & 3 (which of the 4 cell positions in this byte)
	NEG			; cee2  ed 44		; A = -(X & 3) = two's complement (256 - (X & 3))
;                                               ;   This works because: 0->0, 1->$FF, 2->$FE, 3->$FD
	ADD	A,3		; cee4  c6 03		; A = 3 - (X & 3) = number of 2-bit shifts needed
;                                               ;   Position 0: 3 shifts (bits 7-6 -> bits 1-0)
;                                               ;   Position 1: 2 shifts (bits 5-4 -> bits 1-0)
;                                               ;   Position 2: 1 shift  (bits 3-2 -> bits 1-0)
;                                               ;   Position 3: 0 shifts (bits 1-0, already in place)
	JR	Z,XCEEF		; cee6  28 07		; If shift_count == 0 (position 3), skip shifting entirely
;
; --- Shift loop: move target cell's bits into bit positions 1-0 ---
; Each iteration shifts B right by 2 bits (SRL B twice).
;
XCEE8:	SRL	B		; cee8  cb 38		; Logical shift B right by 1 (bit 0 lost, 0 enters bit 7)
	SRL	B		; ceea  cb 38		; Shift right again (total: 2 bits per iteration)
;                                               ;   Two SRL B = shift one cell position right
	DEC	A		; ceec  3d		; Decrement shift counter
	JR	NZ,XCEE8	; ceed  20 f9		; Loop until all shifts done
;
XCEEF:	LD	A,B		; ceef  78		; A = shifted byte (target cell now in bits 1-0)
	AND	3		; cef0  e6 03		; Mask to isolate the 2-bit cell value (0-3)
	RET			; cef2  c9		; Return with A = cell value
;

; ==========================================================================
; READ_CELL_SHADOW ($CEF3)
; ==========================================================================
;
; Reads a cell value from the SHADOW GRID ($6000-$77FF) instead of the
; main screen bitmap ($4000-$57FF).
;
; The shadow grid is a parallel copy of the screen bitmap, but trail cells
; (value 2) are NEVER written to it (WRITE_CELL_BMP only writes to $4000).
; This means sparks and chasers reading via this routine see trail as
; empty space, which is the core mechanic allowing them to chase the player
; through their own trail.
;
; Implementation: This routine is identical to the XCEDB sequence
; (CALL COORDS_TO_ADDR + READ_CELL_BMP) except it inserts SET 5,H
; between the two calls. SET 5,H converts the bitmap address ($4xxx)
; to the shadow grid address ($6xxx) before reading.
;
; NOTE: The disassembler could not decode this as instructions because
; the label references confused it. The raw bytes are:
;   $CEF3: CD 8A CE    = CALL COORDS_TO_ADDR ($CE8A)
;   $CEF6: CB EC       = SET 5,H
;   $CEF8: CD DE CE    = CALL READ_CELL_BMP ($CEDE)
;   $CEFB: C9          = RET
;
; Entry:
;   E = game X coordinate
;   D = game Y coordinate
;
; Exit:
;   A = cell value from shadow grid (0=empty, 1=claimed, 3=border)
;       NOTE: Value 2 (trail) will never be returned because trail
;       is not written to the shadow grid.
;
; Called from:
;   spark.asm -- all spark movement direction checks
;   chaser.asm -- wall-following AI reads shadow to decide direction
;
; --- Read cell shadow ---
; (Raw bytes -- disassembler rendered as data due to label parsing issues)
READ_CELL_SHADOW:
	DB	0CDH,8AH				; cef3 ; CD 8A = first 2 bytes of CALL $CE8A (COORDS_TO_ADDR)
	DW	XCBCE		; cef5   ce cb  ; CE CB = $CE8A address high byte + CB prefix for SET instruction
;                                       ; Together with $CEF3-$CEF4: CALL $CE8A, then CB prefix byte
	DW	XCDEC		; cef7   ec cd  ; EC CD = SET 5,H opcode ($CB $EC) split across words + CD prefix
;                                       ; Decoded: $CEF6-$CEF7 = CB EC = SET 5,H
;                                       ;          $CEF8 = CD = start of CALL instruction
	DB	0DEH					; cef9 ; DE = second byte of CALL $CEDE address
	DW	XC9CE		; cefa   ce c9  ; CE C9 = $CEDE address high byte + C9 = RET
;                                       ; Together: $CEF8-$CEFA = CALL $CEDE (READ_CELL_BMP)
;                                       ;           $CEFB = C9 = RET
;

; ==========================================================================
; Padding / unused bytes ($CEFC-$CEFF)
; ==========================================================================
;
; These bytes appear to be unused padding or uninitialized data between
; the end of READ_CELL_SHADOW ($CEFB) and the next routine at $CF01.
; They are all zero (NOP opcode) in the snapshot.
;
XCEFC:	DB	0					; cefc ; Unused byte (zero)
;
XCEFD:	NOP			; cefd  00		; Unused padding
XCEFE:	NOP			; cefe  00		; Unused padding
XCEFF:	NOP			; ceff  00		; Unused padding
;
	ORG	0CF01H
;
