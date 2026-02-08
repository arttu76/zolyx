; ==========================================================================
; SCANLINE FLOOD FILL ALGORITHM ($CF01-$D077)
; ==========================================================================
;
; Triggered when the player's trail reaches a border cell, after all trail
; cells have been converted to border. The caller (FILL_DIRECTION at $C921
; in player_movement.asm) determines which side of the trail to fill, then
; calls this routine once per trail seed point.
;
; --------------------------------------------------------------------------
; ALGORITHM: SCANLINE FLOOD FILL WITH EXPLICIT STACK
; --------------------------------------------------------------------------
;
; This implements a classic scanline flood fill. From each seed point:
;
;   1. Check the seed cell. If not empty, return immediately.
;   2. From the seed, scan RIGHTWARD filling every empty cell in the row.
;      While scanning right, monitor the row above (via IX) and row below
;      (via IY). When an empty region transitions into a filled region (or
;      vice versa), push a new seed coordinate onto the fill stack. This
;      ensures that adjacent rows' empty regions will be processed later.
;   3. Return to the original seed position and scan LEFTWARD, performing
;      the same fill-and-check-neighbors logic.
;   4. After both scans, pop the next seed from the fill stack and repeat
;      from step 1. Continue until the stack is empty.
;
; The rightward and leftward scans are nearly identical code, differing
; only in the direction of X increment/decrement and byte pointer
; adjustment.
;
; --------------------------------------------------------------------------
; MEMORY MAP
; --------------------------------------------------------------------------
;
;   $4000-$57FF  ZX Spectrum screen bitmap (256x192 pixels, 6144 bytes)
;                The fill reads AND writes this memory directly.
;                Each game cell = 2x2 pixels = 2 bits within a byte.
;
;   $6000-$77FF  Shadow grid. Same layout as bitmap, but trail cells are
;                NOT written here. After the fill completes, the caller
;                syncs bitmap->shadow via CALL $CE44 (full LDIR copy).
;                The flood fill itself only touches the bitmap.
;
;   $9400-$97FF  Flood fill stack. Stores (X, Y) coordinate pairs as
;                2-byte entries. Grows upward. Stack pointer is kept in
;                the self-modifying variable at $CEFF.
;
;   $B0C9        CELL_PATTERNS table (8 bytes: 4 cells x 2 pattern bytes)
;                Pattern byte 0 = top pixel row, byte 1 = bottom pixel row.
;                Cell 0 (empty): $00, $00
;                Cell 1 (claimed): $55, $00   (checkerboard)
;                Cell 2 (trail): $AA, $55
;                Cell 3 (border): $FF, $FF    (solid)
;
;   $FB00-$FB03  Cell bitmask table: $C0, $30, $0C, $03
;                Maps cell position (0-3) within a byte to its 2-bit mask.
;                Position 0 ($C0) = bits 7-6 (leftmost cell in byte)
;                Position 3 ($03) = bits 1-0 (rightmost cell in byte)
;
;   $FC40+       Row address lookup table (160 entries, 2 bytes each)
;                Maps (pixelY * 4) to a ZX Spectrum screen address.
;                Used by COORDS_TO_ADDR to convert game Y -> screen addr.
;
; --------------------------------------------------------------------------
; SELF-MODIFYING CODE VARIABLES (in cell_io.asm address space)
; --------------------------------------------------------------------------
;
;   $CEFC (1 byte)  Pattern byte 0 for the fill cell (top pixel row).
;                    Written during init, read during the scan loops.
;
;   $CEFD (1 byte)  Pattern byte 1 for the fill cell (bottom pixel row).
;                    Written during init, read during the scan loops.
;
;   $CEFE (1 byte)  Fill stack entry count. Decremented to pop; when it
;                    goes negative (DEC -> $FF, sign flag set), the stack
;                    is empty and the fill terminates.
;
;   $CEFF (2 bytes) Fill stack pointer. Points to the next free slot in
;                    the fill stack at $9400+. Advanced by 2 bytes per push.
;
; --------------------------------------------------------------------------
; REGISTER CONVENTIONS
; --------------------------------------------------------------------------
;
; FLOOD_FILL ($CF01) entry:
;   A  = Cell value to fill with (1 = CLAIMED, or 2 = TRAIL depending
;         on fill mode). Multiplied by 2 to index the pattern table.
;   D  = Seed Y coordinate (game coordinates, range 18-93)
;   E  = Seed X coordinate (game coordinates, range 2-125)
;
; FLOOD_FILL ($CF01) exit:
;   All registers clobbered. Fill stack variables updated.
;   Returns when the stack is empty (all connected empty cells filled).
;
; FILL_ONE_SCANLINE ($CF34) entry:
;   D  = Y coordinate of current seed
;   E  = X coordinate of current seed
;   Fill stack variables at $CEFC-$CEFF are initialized.
;
; FILL_ONE_SCANLINE ($CF34) exit:
;   Returns via RET when the rightward scan is complete. The main loop
;   then pops seeds and re-enters, or returns when the leftward scan
;   from a popped seed completes and the stack is empty.
;
; SCAN LOOP ($CF81 rightward / $D01D leftward) steady-state registers:
;   HL = Screen bitmap address for current cell (current row Y)
;   IX = Screen bitmap address for same column, row Y-1 (above)
;   IY = Screen bitmap address for same column, row Y+1 (below)
;   B  = 2-bit cell mask for current cell position within the byte
;        ($C0, $30, $0C, or $03). Rotated left by 2 each step.
;   C  = Segment tracking flags:
;        Bit 0: "above-row segment active" -- set when the row above
;               has a non-empty cell at this X position. When this bit
;               transitions from set to clear (non-empty -> empty), a
;               new seed is pushed for the row above.
;        Bit 1: "below-row segment active" -- same logic for row below.
;   D  = Current Y coordinate
;   E  = Current X coordinate (incremented or decremented each step)
;
; PUSH_SEED ($D067) entry:
;   D  = Y coordinate to push (caller temporarily adjusts D by +/-1)
;   E  = X coordinate to push
;   HL = Preserved (saved/restored via PUSH/POP)
;
; --------------------------------------------------------------------------
; ZX SPECTRUM SCREEN ADDRESS ENCODING
; --------------------------------------------------------------------------
;
; The ZX Spectrum bitmap is NOT linearly organized. Each character cell
; (8x8 pixels) has its 8 rows interleaved across the screen thirds.
; The COORDS_TO_ADDR routine (at $CE8A) handles this conversion:
;
;   pixelY = gameY * 2  (each game cell = 2 pixels tall)
;   byteCol = gameX / 4  (each byte holds 4 game cells, 2 bits each)
;   screenAddr = LOOKUP_TABLE[pixelY * 2] + byteCol
;
; The lookup table at $FC40 pre-computes the ZX Spectrum screen address
; for each pixel row, eliminating the need for complex bit manipulation.
;
; Within each screen byte, the 4 game cells are packed MSB-first:
;   Bits 7-6 = cell at position 0 (leftmost), mask $C0
;   Bits 5-4 = cell at position 1, mask $30
;   Bits 3-2 = cell at position 2, mask $0C
;   Bits 1-0 = cell at position 3 (rightmost), mask $03
;
; Moving to the next pixel row WITHIN a character cell is simply INC H
; (add $0100 to the address). This is used to write both pixel rows of
; each 2-pixel-tall game cell: row 0 at (HL), row 1 at (HL + $0100).
;
; --------------------------------------------------------------------------
; HOW THE MASK ROTATION WORKS
; --------------------------------------------------------------------------
;
; The scan loops use RLC B twice to advance the cell mask. RLC rotates
; the byte left circularly (bit 7 -> carry and bit 0). Two rotations
; shift the 2-bit mask pattern left by 2 positions:
;
;   $C0 (11000000) -> RLC x2 -> $03 (00000011), carry SET
;   $03 (00000011) -> RLC x2 -> $0C (00001100), carry clear
;   $0C (00001100) -> RLC x2 -> $30 (00110000), carry clear
;   $30 (00110000) -> RLC x2 -> $C0 (11000000), carry clear
;
; Carry is set ONLY when the mask wraps from $C0 -> $03, which signals
; a byte boundary crossing. When carry is set, the byte pointers
; (HL, IX, IY) must be adjusted: INC for rightward scan, DEC for
; leftward scan. When carry is clear, we stay in the same byte.
;
; The visit order for cells within a byte is therefore:
;   Starting from any position, RLC x2 moves to the position whose bits
;   are 2 positions higher (with wraparound). The byte boundary trigger
;   ensures correct sequential scanning despite the circular rotation.
;

;
	ORG	0CF01H
;

; ==========================================================================
; FLOOD_FILL ($CF01) -- Main entry point
; ==========================================================================
;
; Called from the fill seeding loop in FILL_DIRECTION ($C921) once per
; trail seed point. Each call processes the initial seed and then drains
; the fill stack, filling all reachable empty cells in the connected
; region.
;
; On first entry, the fill stack at $9400 is empty. The initial seed
; is processed via CALL $CF34 (FILL_ONE_SCANLINE), which may push
; additional seeds onto the stack. The main loop then pops and processes
; seeds until the stack is exhausted.
;
; On entry:
;   A = cell value to fill with (1=CLAIMED or 2=TRAIL)
;   D = seed Y coordinate
;   E = seed X coordinate
;
; The first 7 instructions are encoded as DB bytes because the original
; disassembler lost instruction-stream sync (likely due to the data
; variables at $CEFC-$CEFF being in the middle of the code stream).
; The actual Z80 instructions are annotated in the right-hand comments.
; ==========================================================================

; --- Flood fill ---
FLOOD_FILL:
; --------------------------------------------------------------------------
; INITIALIZATION: Set up the fill pattern and stack
; --------------------------------------------------------------------------
; Compute the pattern bytes for the fill cell value and store them in
; the self-modifying code locations at $CEFC and $CEFD. These locations
; are read by LD A,($CEFC) and LD A,($CEFD) during the scan loops to
; write the fill pattern into the screen bitmap.
;
; Also initialize the fill stack pointer ($CEFF) to $9400 (stack base)
; and the stack counter ($CEFE) to 0 (empty).
; --------------------------------------------------------------------------
	DB	87H,4FH,6,0,21H,0C9H,0B0H,9		; cf01 .O..!I0.
	; CF01: ADD A,A           ; A = cellValue * 2 (pattern table has 2 bytes per cell)
	; CF02: LD  C,A           ; C = cellValue * 2
	; CF03: LD  B,0           ; B = 0, so BC = cellValue * 2
	; CF05: LD  HL,$B0C9      ; HL = address of CELL_PATTERNS table
	; CF08: ADD HL,BC         ; HL now points to the 2-byte pattern for this cell value

	DB	7EH,32H					; cf09 ~2
	DW	XCEFC		; cf0b   fc ce      |N
	; CF09: LD  A,(HL)        ; A = pattern byte 0 (top pixel row of cell)
	; CF0A: LD  ($CEFC),A     ; [SELF-MOD] Store pattern byte 0 at $CEFC
	;                         ; This value is loaded later by LD A,($CEFC) at $CF85/$D020
;
	DB	23H,7EH,32H,0FDH			; cf0d #~2}
	DW	X21CE		; cf11   ce 21      N!
	; CF0D: INC HL            ; Advance to pattern byte 1
	; CF0E: LD  A,(HL)        ; A = pattern byte 1 (bottom pixel row of cell)
	; CF0F: LD  ($CEFD),A     ; [SELF-MOD] Store pattern byte 1 at $CEFD
	;                         ; This value is loaded later by LD A,($CEFD) at $CF8C/$D027
	; CF12: LD  HL,$9400      ; HL = base address of the flood fill stack
;
	DB	0,94H,22H,0FFH				; cf13 ..".
	DW	X3ECE		; cf17   ce 3e      N>
	; (continuation of LD HL,$9400 from CF12 — the $9400 value spans the DB/DW boundary)
	; CF15: LD  ($CEFF),HL    ; [SELF-MOD] Initialize fill stack pointer to $9400
	;                         ; This pointer is read/written by the PUSH_SEED routine ($D067)
	;                         ; and by the main loop's stack pop at $CF28.
	; CF18: LD  A,0           ; A = 0
;

; --------------------------------------------------------------------------
; MAIN LOOP: Process seeds from the fill stack
; --------------------------------------------------------------------------
; This loop processes one seed at a time. It first calls FILL_ONE_SCANLINE
; ($CF34) which does the rightward scan from the seed, then decrements
; the stack counter. If the counter went negative, the stack is empty and
; we return. Otherwise, pop (X,Y) from the stack and do the leftward scan
; (which falls through from the rightward scan setup at $CF34, eventually
; reaching the leftward scan code at $CFD1-$D077).
;
; Wait -- actually the flow is: CALL $CF34 processes both the rightward
; scan (from the seed) and then the leftward scan (from seed-1). The
; leftward scan returns via RET NZ or RET M at $D01F/$D059. After that
; return, we check if there are more seeds on the stack.
;
; Note: The very first CALL $CF34 (at $CF1D) processes the original seed
; passed in registers D,E. Subsequent iterations pop seeds from the stack.
; --------------------------------------------------------------------------
	DB	0,32H					; cf19 .2
	DW	XCEFE		; cf1b   fe ce      ~N
	; CF19: (continuation of LD A,0 from CF18)
	; CF1A: LD  ($CEFE),A     ; [SELF-MOD] Initialize stack counter to 0 (no entries yet)

	DW	X34CD		; cf1d   cd 34      M4
	; CF1D: CALL $CF34        ; Process the initial seed point (FILL_ONE_SCANLINE)
	;                         ; This fills rightward, then leftward from (D,E).
	;                         ; May push new seeds onto the fill stack for rows above/below.

	DW	X3ACF		; cf1f   cf 3a      O:
	DW	XCEFE		; cf21   fe ce      ~N
	; CF20: LD  A,($CEFE)     ; Load the fill stack counter
	;                         ; Each push increments this, each pop (here) decrements it.
;
	DB	3DH,0F8H,32H				; cf23 =x2
	DW	XCEFE		; cf26   fe ce      ~N
	; CF23: DEC A              ; Decrement the stack counter (pop one entry)
	; CF24: RET M              ; If counter went negative (no more entries), fill is DONE.
	;                          ; The sign flag is set when A decrements from 0 to $FF.
	;                          ; This is the main termination condition for the flood fill.
	; CF25: LD  ($CEFE),A      ; Store the decremented counter back
;

; --------------------------------------------------------------------------
; POP SEED: Retrieve the next (X, Y) seed from the fill stack
; --------------------------------------------------------------------------
; The fill stack grows upward from $9400. The stack pointer ($CEFF) always
; points to the next FREE slot. To pop, we decrement the pointer by 2,
; then read Y (at pointer+1) and X (at pointer+0).
;
; After popping, we jump back to CALL $CF34 to process this new seed.
; --------------------------------------------------------------------------
	DB	2AH,0FFH				; cf28 *.
	DW	X2BCE		; cf2a   ce 2b      N+
	; CF28: LD  HL,($CEFF)    ; Load the current fill stack pointer
	; CF2B: DEC HL             ; Move pointer back to the Y byte of the top entry
;
	DB	56H,2BH,5EH,22H,0FFH			; cf2c V+^".
	DW	X18CE		; cf31   ce 18      N.
	; CF2C: LD  D,(HL)         ; D = Y coordinate from the popped stack entry
	; CF2D: DEC HL             ; Move pointer back to the X byte
	; CF2E: LD  E,(HL)         ; E = X coordinate from the popped stack entry
	; CF2F: LD  ($CEFF),HL     ; Store updated stack pointer (now 2 bytes lower)
	; CF32: JR  $CF1D          ; Jump back to CALL $CF34 (process this seed)
	;                          ; This creates the main fill loop:
	;                          ;   process seed -> pop next -> process -> ... -> stack empty -> RET


; ==========================================================================
; FILL_ONE_SCANLINE ($CF34) -- Process one seed: rightward then leftward
; ==========================================================================
;
; On entry:
;   D = seed Y coordinate
;   E = seed X coordinate
;   Self-modifying variables at $CEFC-$CEFF are initialized.
;
; This subroutine:
;   1. Checks if the seed cell is empty. If not, returns immediately.
;   2. Performs the rightward scan from the seed (inline, $CF39-$CFCC).
;   3. Restores the seed coordinates, steps one cell LEFT, and falls
;      through to the leftward scan ($CFD1-$D077).
;
; The rightward scan fills cells from the seed to the right, pushing
; new seeds for empty regions found in the rows above and below. The
; leftward scan does the same but moves left from (seed_X - 1).
; ==========================================================================

	DW	XCDE9		; cf33   e9 cd      iM
	DB	0DBH					; cf35 [
	DW	XB7CE		; cf36   ce b7      N7
	; CF34: CALL $CEDB         ; Convert (D=Y, E=X) to screen address HL and read cell.
	;                          ; $CEDB = COORDS_TO_ADDR ($CE8A) + READ_CELL_BMP ($CEDE).
	;                          ; On return: A = 2-bit cell value (0=empty, 1=claimed,
	;                          ;            2=trail, 3=border). HL = screen bitmap address.
	; CF37: OR  A              ; Set flags: Z if cell is empty (A=0), NZ if occupied


; ==========================================================================
; RIGHTWARD SCAN ($CF38-$CFCC)
; ==========================================================================
;
; If the seed cell is not empty, return immediately (nothing to fill).
; Otherwise, set up screen addresses for three rows (Y+1, Y-1, Y) and
; scan rightward from the seed, filling empty cells and pushing seeds
; for adjacent empty regions in the rows above and below.
;
; The three screen addresses are computed using the same algorithm as
; COORDS_TO_ADDR ($CE8A): multiply the pixel-Y by 4 to index the row
; address lookup table at $FC40, then add the byte column offset. The
; code computes this three times (for Y+1, Y-1, and Y) with boundary
; clamping for Y+1 and Y-1.
; ==========================================================================

	DB	0C0H,0D5H,7BH,1FH,1FH,0E6H,3FH,4FH	; cf38 @U{..f?O
	; CF38: RET NZ             ; If seed cell is NOT empty (A != 0), nothing to fill. Return.
	;                          ; This is the fast-exit path for seeds that land on already-
	;                          ; filled or border cells. Critical for performance since many
	;                          ; seeds pushed from adjacent rows may already be filled.
	;
	; CF39: PUSH DE            ; Save the original seed coordinates (D=Y, E=X) on the CPU
	;                          ; stack. We need them later after the rightward scan to set up
	;                          ; the leftward scan (pop at $CFCE).
	;
	; -- Compute byte column offset from X coordinate --
	;
	; CF3A: LD  A,E            ; A = seed X coordinate (game coords, range 2-125)
	; CF3B: RRA                ; Shift right through carry (divide by 2, bit 0 -> carry)
	; CF3C: RRA                ; Shift right again (divide by 4 total, bit 1 -> carry)
	;                          ; After two RRA: A = X / 4 (the byte column), but with
	;                          ; carry bits rotated into the top. AND $3F cleans this up.
	; CF3D: AND $3F            ; Mask to lower 6 bits, giving the byte column offset (0-31).
	;                          ; Each screen byte holds 4 game cells (2 bits each), so
	;                          ; X / 4 = byte offset within the screen row.
	; CF3F: LD  C,A            ; C = byte column offset (preserved across address lookups)

; --------------------------------------------------------------------------
; Compute screen address for ROW Y+1 (one row BELOW the seed)
; --------------------------------------------------------------------------
; The address lookup table at $FC40 has 2-byte entries indexed by
; (pixelY * 2). Since each game cell = 2 pixel rows, game Y -> pixel row
; = Y * 2. The table index = Y * 2 * 2 = Y * 4.
;
; The calculation is:
;   tableIndex = (Y+1) * 4    (Y+1 clamped to field bounds)
;   tableAddr  = $FC00 + tableIndex  (effectively, via the ADC $FC trick)
;   rowBaseAddr = table[tableIndex]  (2-byte little-endian screen address)
;   screenAddr = rowBaseAddr + byteColumnOffset
;
; Boundary clamping: If Y+1 >= 96 ($60), clamp to Y (don't go past the
; field bottom at Y=93; pixel row 95 is the last valid row). The CP/CCF/
; SBC sequence does: if Y+1 >= 96, subtract 1 -> use Y instead of Y+1.
; --------------------------------------------------------------------------

	DB	7AH,3CH,0FEH,60H,3FH,0DEH,0,87H		; cf40 z<~`?^..
	; CF40: LD  A,D            ; A = seed Y coordinate
	; CF41: INC A              ; A = Y + 1 (one row below the seed)
	; CF42: CP  $60            ; Compare A with 96 (decimal). The field bottom pixel row
	;                          ; is at Y=93, pixel row 186, which is within bounds. Row 96
	;                          ; in game coords (pixel 192) is beyond the screen.
	;                          ; If A < 96: carry flag SET.
	;                          ; If A >= 96: carry flag CLEAR.
	; CF44: CCF                ; Complement Carry Flag.
	;                          ; If Y+1 < 96: carry now CLEAR -> SBC subtracts 0 -> keep Y+1
	;                          ; If Y+1 >= 96: carry now SET -> SBC subtracts 1 -> clamp to Y
	; CF45: SBC A,0            ; A = A - 0 - carry. Clamps Y+1 to at most 95.
	;                          ; This prevents reading past the field boundary.
	;
	; -- Convert clamped (Y+1) to screen address using lookup table --
	;
	; CF47: ADD A,A            ; A = (Y+1_clamped) * 2   (first step of *4)

	DB	87H,6FH,0CEH,0FCH,95H,67H,79H,86H	; cf48 .oN|.gy.
	; CF48: ADD A,A            ; A = (Y+1_clamped) * 4   (table index: 4 bytes per row entry)
	; CF49: LD  L,A            ; L = table index (low byte)
	; CF4A: ADC A,$FC          ; A = tableIndex + $FC + carry. This computes the high byte
	;                          ; of the lookup table address. The table is at $FC00-$FD2F.
	;                          ; If tableIndex overflows 8 bits, carry propagates into high.
	;                          ; The math: tableAddr = $FC00 + tableIndex. High byte = $FC
	;                          ; plus any carry from the low byte addition.
	; CF4C: SUB L              ; A = highByte - lowByte, isolating the high byte component.
	;                          ; This is a clever trick: since H = (L + $FC + carry) - L,
	;                          ; we get H = $FC + carry (from the ADC). This computes the
	;                          ; correct high byte of the table pointer.
	; CF4D: LD  H,A            ; H = high byte of table pointer. Now HL points into $FC00+.
	; CF4E: LD  A,C            ; A = byte column offset (computed at CF3F)
	; CF4F: ADD A,(HL)         ; Add the low byte of the screen row address from the table.
	;                          ; The table entry's low byte is the starting byte offset
	;                          ; of that pixel row within the screen memory.

	DB	23H,66H,6FH,0E5H,7AH,0D6H,1,0CEH	; cf50 #foezV.N
	; CF50: INC HL             ; Advance to high byte of the table entry
	; CF51: LD  H,(HL)         ; H = high byte of the screen row address from the table.
	;                          ; For the bitmap, this is $40-$57 (screen at $4000-$57FF).
	; CF52: LD  L,A            ; L = low byte (row start + column offset). Now HL is the
	;                          ; complete screen bitmap address for cell (X, Y+1).
	; CF53: PUSH HL            ; Save the Y+1 address on the CPU stack (popped into IY later).

; --------------------------------------------------------------------------
; Compute screen address for ROW Y-1 (one row ABOVE the seed)
; --------------------------------------------------------------------------
; Same algorithm as above, but for Y-1 instead of Y+1.
; Boundary clamping: If Y-1 underflows (Y was 0, so Y-1 = $FF), the
; SUB 1 sets carry, and ADC A,0 adds 1 back, clamping to 0.
; In practice Y is always >= 18 (field top), so this clamp never triggers.
; --------------------------------------------------------------------------

	; CF54: LD  A,D            ; A = seed Y coordinate
	; CF55: SUB 1              ; A = Y - 1 (one row above the seed)
	;                          ; If Y was 0 (impossible in game, but safe): carry SET.
	; CF57: ADC A,0            ; A = (Y-1) + 0 + carry. If Y-1 underflowed, this adds 1
	;                          ; back, clamping to 0. Otherwise A stays as Y-1.

	DB	0,87H,87H,6FH,0CEH,0FCH,95H,67H		; cf58 ...oN|.g
	; CF58: (continuation of ADC A,0 from CF57)
	; CF59: ADD A,A            ; A = (Y-1_clamped) * 2
	; CF5A: ADD A,A            ; A = (Y-1_clamped) * 4   (lookup table index)
	; CF5B: LD  L,A            ; L = table index
	; CF5C: ADC A,$FC          ; Compute high byte of table address ($FC + carry)
	; CF5E: SUB L              ; Isolate high byte
	; CF5F: LD  H,A            ; H = high byte of table pointer

	DB	79H,86H,23H,66H,6FH,0E5H,7AH,87H	; cf60 y.#foez.
	; CF60: LD  A,C            ; A = byte column offset
	; CF61: ADD A,(HL)         ; Add row base address (low byte) from lookup table
	; CF62: INC HL             ; Advance to high byte of table entry
	; CF63: LD  H,(HL)         ; H = high byte of screen row address
	; CF64: LD  L,A            ; L = complete low byte. HL = screen address for (X, Y-1).
	; CF65: PUSH HL            ; Save the Y-1 address (popped into IX later)

; --------------------------------------------------------------------------
; Compute screen address for ROW Y (the seed's own row, CURRENT row)
; --------------------------------------------------------------------------
; No boundary clamping needed for the seed's own row.
; --------------------------------------------------------------------------

	; CF66: LD  A,D            ; A = seed Y coordinate (unchanged)
	; CF67: ADD A,A            ; A = Y * 2

	DB	87H,6FH,0CEH,0FCH,95H,67H,79H,86H	; cf68 .oN|.gy.
	; CF68: ADD A,A            ; A = Y * 4 (lookup table index)
	; CF69: LD  L,A            ; L = table index
	; CF6A: ADC A,$FC          ; Compute high byte of table address
	; CF6C: SUB L              ; Isolate high byte
	; CF6D: LD  H,A            ; H = high byte of table pointer
	; CF6E: LD  A,C            ; A = byte column offset
	; CF6F: ADD A,(HL)         ; Add row base address (low byte) from lookup table

	DB	23H,66H,6FH,0DDH,0E1H,0FDH,0E1H,7BH	; cf70 #fo]a}a{
	; CF70: INC HL             ; Advance to high byte of table entry
	; CF71: LD  H,(HL)         ; H = high byte of screen row address
	; CF72: LD  L,A            ; HL = screen bitmap address for (X, Y) — current row.
	;                          ; This is the primary working pointer for the scan loop.
	;
	; -- Pop the two saved row addresses into index registers --
	;
	; CF73: POP IX             ; IX = screen address for row Y-1 (above seed row).
	;                          ; Was pushed at CF65. IX tracks the same column but one
	;                          ; row above, for checking whether to push above-row seeds.
	; CF75: POP IY             ; IY = screen address for row Y+1 (below seed row).
	;                          ; Was pushed at CF53. IY tracks one row below.

; --------------------------------------------------------------------------
; Set up the cell bitmask and segment flags for the scan
; --------------------------------------------------------------------------
; The cell bitmask B selects which 2 bits within a screen byte correspond
; to the current X position. The mask table at $FB00 maps cell position
; (X AND 3) to the appropriate 2-bit mask.
;
; The segment flags in C track whether the rows above and below are
; currently in a "non-empty segment." When the scan encounters a
; transition from non-empty to empty in an adjacent row, it pushes a
; seed for that row. Initializing C=3 (both bits set) means we treat
; both rows as "in a non-empty segment" initially, so the very first
; empty cell found above/below will trigger a seed push.
; --------------------------------------------------------------------------

	; CF77: LD  A,E            ; A = seed X coordinate

	DB	0E6H,3,4FH,6,0FBH,0AH,47H,0EH		; cf78 f.O.{.G.
	; CF78: AND 3              ; A = X mod 4 (cell position within byte: 0, 1, 2, or 3)
	; CF7A: LD  C,A            ; C = cell position (temporary use for table lookup)
	; CF7B: LD  B,$FB          ; B = $FB. Now BC = $FB00 + position = address in mask table.
	;                          ; The mask table at $FB00: $C0(pos 0), $30(pos 1),
	;                          ; $0C(pos 2), $03(pos 3).
	; CF7D: LD  A,(BC)         ; A = the 2-bit bitmask for this cell position
	; CF7E: LD  B,A            ; B = cell bitmask (stays in B throughout the scan loop)
	; CF7F: LD  C,3            ; C = $03 = initial segment flags (bit 0 + bit 1 both set)
	;                          ; Bit 0 = "row above is in a non-empty segment"
	;                          ; Bit 1 = "row below is in a non-empty segment"
	;                          ; Starting with both set means: we assume the adjacent rows
	;                          ; start in a non-empty state. When the scan encounters an
	;                          ; empty cell above/below, the transition is detected and a
	;                          ; seed is pushed.

; ==========================================================================
; RIGHTWARD SCAN LOOP ($CF81-$CFCC)
; ==========================================================================
;
; This loop fills cells moving rightward from the seed position. For each
; cell at the current X position:
;
;   1. TEST: If the cell (at HL) is non-empty, jump to END_RIGHT_SCAN
;      at $CFCE (the rightward scan has hit a boundary).
;   2. FILL: Write the fill pattern to both pixel rows of the cell in
;      the bitmap.
;   3. CHECK ABOVE: Read the cell in the row above (at IX). Detect
;      transitions between empty and non-empty. On non-empty->empty
;      transition (bit 0 of C drops from set to clear), push a seed
;      for that position in the row above.
;   4. CHECK BELOW: Same logic for the row below (at IY).
;   5. ADVANCE: Increment E (X coordinate). If X overflows (sign flag
;      set), end the scan. Rotate B left by 2 (advance cell position).
;      If carry set (crossed byte boundary), increment HL/IX/IY to
;      next byte. Jump back to step 1.
; ==========================================================================

	DB	3,78H,0A6H,20H,49H,3AH,0FCH,0CEH	; cf80 .x& I:|N
	; CF80: (this byte is the $03 operand of LD C,3 at CF7F — part of the 2-byte instruction)
	;
	; -- SCAN_RIGHT_LOOP (top of loop at $CF81) --
	;
	; CF81: LD  A,B            ; A = current cell bitmask (the 2-bit mask for this X position)
	; CF82: AND (HL)           ; Test the screen byte at the current row against the mask.
	;                          ; If ANY bits are set in the masked position, the cell is
	;                          ; non-empty (border, claimed, or trail). Result: NZ if occupied.
	; CF83: JR  NZ,$CFCE       ; [RIGHTWARD BOUNDARY] If cell is not empty, the rightward
	;                          ; scan has reached a wall, border, or already-claimed area.
	;                          ; Jump to END_RIGHT_SCAN ($CFCE) to start the leftward scan.
	;
	; -- FILL CURRENT CELL: Write fill pattern to bitmap --
	;
	; CF85: LD  A,($CEFC)      ; [SELF-MOD READ] A = pattern byte 0 (top pixel row of fill cell)
	;                          ; For CLAIMED (value 1): A = $55 (01010101 = checkerboard)

	DB	0A0H,0B6H,77H,24H,3AH,0FDH,0CEH,0A0H	; cf88  6w$:}N
	; CF88: AND B              ; Mask the pattern to only the 2 bits for this cell position.
	;                          ; E.g., if B=$C0 and A=$55: result = $40 (bit 6 set).
	; CF89: OR  (HL)           ; Merge the new cell bits with the existing screen byte.
	;                          ; Preserves other cells in the same byte that are already set.
	; CF8A: LD  (HL),A         ; Write the merged byte back to the screen bitmap.
	;                          ; [MEMORY WRITE: $4000-$57FF bitmap, top pixel row of cell]
	; CF8B: INC H              ; H += 1. In ZX Spectrum screen layout, this moves to the
	;                          ; next pixel row within the same character cell. Since each
	;                          ; game cell is 2 pixels tall, this is the bottom pixel row.
	;                          ; Address goes from e.g. $4020 to $4120.
	; CF8C: LD  A,($CEFD)      ; [SELF-MOD READ] A = pattern byte 1 (bottom pixel row)
	;                          ; For CLAIMED (value 1): A = $00 (all zeros = blank row)
	; CF8F: AND B              ; Mask to this cell's 2-bit position

	DB	0B6H,77H,25H,0DDH,7EH,0,0A0H,20H	; cf90 6w%]~.
	; CF90: OR  (HL)           ; Merge with existing byte at the bottom pixel row
	; CF91: LD  (HL),A         ; Write back to bitmap.
	;                          ; [MEMORY WRITE: bottom pixel row of the cell]
	;                          ; NOTE: This writes to BITMAP ONLY, not the shadow grid.
	;                          ; The shadow grid ($6000+) is synced later by the caller
	;                          ; via CALL $CE44 (full bitmap->shadow copy).
	; CF92: DEC H              ; H -= 1. Restore HL to the top pixel row address.
	;                          ; We need HL pointing to the top row for the cell-empty
	;                          ; test at the top of the loop.

; --------------------------------------------------------------------------
; CHECK ROW ABOVE (IX): Detect empty-region transitions
; --------------------------------------------------------------------------
; Read the cell at the same X position in the row above (via IX, which
; tracks row Y-1). Use the same bitmask B to test the same cell column.
;
; The segment flag (bit 0 of C) tracks whether we're currently inside a
; "non-empty region" in the row above:
;
;   - If the above cell is NON-EMPTY: Set bit 0 of C (we're in a segment).
;   - If the above cell is EMPTY AND bit 0 was SET: This is a transition
;     from non-empty to empty. Push a seed for (X, Y-1) to fill this new
;     empty region later. Clear bit 0 (we're now in an empty area).
;   - If the above cell is EMPTY AND bit 0 was CLEAR: We're still in the
;     same empty region that was already seeded. Skip (no duplicate push).
; --------------------------------------------------------------------------

	; CF93: LD  A,(IX+0)       ; Read the screen byte at the row-above address (IX)
	; CF96: AND B              ; Test the cell at the current X position
	;                          ; NZ = cell above is occupied, Z = cell above is empty

	DB	0DH,0CBH,41H,28H,0BH,0CBH,81H,15H	; cf98 .KA(.K..
	; CF97: JR  NZ,$CFA6       ; If above cell is NON-EMPTY, jump to set the segment flag.
	;                          ; [GAME LOGIC: The row above has a wall/border/claimed cell
	;                          ; at this position. We mark that we're "inside" a non-empty
	;                          ; segment. If the next cell to the right is empty, the
	;                          ; transition will be detected and a seed pushed.]
	;
	; -- Above cell IS empty --
	;
	; CF99: BIT 0,C            ; Test bit 0: were we in a non-empty segment above?
	; CF9B: JR  Z,$CFA8        ; If bit 0 is CLEAR, we were already in an empty area.
	;                          ; No transition occurred -> skip to below-row check.
	;                          ; [GAME LOGIC: We've been tracking this empty region since
	;                          ; a previous cell. One seed is enough per contiguous region.]
	;
	; -- Transition detected: above went from non-empty to empty --
	;
	; CF9D: RES 0,C            ; Clear bit 0 of C: we're now in an empty region above.
	; CF9F: DEC D              ; D = Y - 1 (temporarily adjust to the row above)

	DB	0CDH,67H,0D0H,14H,18H,2,0CBH,0C1H	; cfa0 MgP...KA
	; CFA0: CALL $D067         ; PUSH_SEED: Push (E, D) = (currentX, Y-1) onto the fill
	;                          ; stack. This seed will be processed later, causing the fill
	;                          ; to spread into the empty region in the row above.
	; CFA3: INC D              ; D = Y (restore to the current seed row)
	; CFA4: JR  $CFA8          ; Skip the SET instruction (we just cleared the flag)
	;
	; -- Mark non-empty segment above --
	;
	; CFA6: SET 0,C            ; Set bit 0 of C: we're now inside a non-empty segment above.
	;                          ; [GAME LOGIC: The row above is occupied here. If a later
	;                          ; cell in the scan finds the above row empty, that transition
	;                          ; will trigger a seed push for that new empty region.]

; --------------------------------------------------------------------------
; CHECK ROW BELOW (IY): Same logic, using bit 1 of C
; --------------------------------------------------------------------------
; Identical algorithm to the row-above check, but using IY (row Y+1)
; and bit 1 of C as the segment tracking flag.
; --------------------------------------------------------------------------

	DB	0FDH,7EH,0,0A0H,20H,0DH,0CBH,49H	; cfa8 }~.  .KI
	; CFA8: LD  A,(IY+0)       ; Read the screen byte at the row-below address (IY)
	; CFAB: AND B              ; Test the cell at the current X position
	;                          ; NZ = cell below is occupied, Z = cell below is empty
	; CFAC: JR  NZ,$CFBB       ; If below cell is NON-EMPTY, jump to set segment flag.

	DB	28H,0BH,0CBH,89H,14H,0CDH,67H,0D0H	; cfb0 (.K..MgP
	; CFAE: BIT 1,C            ; Test bit 1: were we in a non-empty segment below?
	; CFB0: JR  Z,$CFBD        ; If bit 1 CLEAR, already in empty area -> skip.
	;
	; -- Transition: below went from non-empty to empty --
	;
	; CFB2: RES 1,C            ; Clear bit 1: now in empty region below.
	; CFB4: INC D              ; D = Y + 1 (temporarily adjust to the row below)
	; CFB5: CALL $D067         ; PUSH_SEED: Push (E, D) = (currentX, Y+1) onto fill stack.
	;                          ; The fill will later spread into this empty region below.

	DB	15H,18H,2,0CBH,0C9H,1CH,0FAH,0CEH	; cfb8 ...KI.zN
	; CFB8: DEC D              ; D = Y (restore to current seed row)
	; CFB9: JR  $CFBD          ; Skip the SET instruction
	;
	; -- Mark non-empty segment below --
	;
	; CFBB: SET 1,C            ; Set bit 1 of C: inside non-empty segment below.

; --------------------------------------------------------------------------
; ADVANCE RIGHTWARD: Increment X, rotate mask, check byte boundary
; --------------------------------------------------------------------------

	; CFBD: INC E              ; E = X + 1 (advance one cell to the right)
	; CFBE: JP  M,$CFCE        ; If E has the sign flag set (X crossed from 127 to 128),
	;                          ; the scan has reached the right edge. Jump to END_RIGHT_SCAN.
	;                          ; [BOUNDARY: X=127 ($7F) is beyond field max of 125. The
	;                          ; sign bit ($80) acts as a cheap out-of-bounds detector.]

	DB	0CFH,0CBH,8,0CBH,8,30H,0BAH,23H		; cfc0 OK.K.0:#
	; CFC0: (this byte $CF is the high byte of $CFCE in the JP M instruction above)
	;
	; CFC1: RLC B              ; Rotate the cell bitmask LEFT by 1 bit.
	; CFC3: RLC B              ; Rotate LEFT again (total: 2 bit positions left).
	;                          ; This advances the mask to the next cell position going
	;                          ; rightward. Carry is SET if the mask wrapped from $C0
	;                          ; back to $03 (byte boundary crossing). See the mask
	;                          ; rotation explanation in the file header.
	; CFC5: JR  NC,$CF81       ; If carry is CLEAR: still within the same byte. Jump back
	;                          ; to the top of the rightward scan loop. No pointer adjustment
	;                          ; needed since all four cells share the same screen byte.
	;
	; -- Byte boundary crossed: advance all three row pointers --
	;
	; CFC7: INC HL             ; HL += 1: move to the next byte in the current row.
	;                          ; In ZX Spectrum screen layout, adjacent bytes within a row
	;                          ; are at consecutive addresses.

	DB	0DDH,23H,0FDH,23H,18H,0B3H,0D1H,1DH	; cfc8 ]#}#.3Q.
	; CFC8: INC IX             ; IX += 1: move to the next byte in the row above.
	; CFCA: INC IY             ; IY += 1: move to the next byte in the row below.
	; CFCC: JR  $CF81          ; Jump back to the top of the rightward scan loop.


; ==========================================================================
; END_RIGHT_SCAN ($CFCE): Transition from rightward to leftward scan
; ==========================================================================
;
; The rightward scan has ended (hit a non-empty cell or reached X > 127).
; Now restore the original seed coordinates, step one cell to the LEFT,
; and begin the leftward scan. The leftward scan checks if the cell at
; (seed_X - 1) is empty, then scans left using the same fill-and-check
; logic as the rightward scan.
; ==========================================================================

	; CFCE: POP DE             ; Restore the original seed coordinates (saved at CF39).
	;                          ; D = original seed Y, E = original seed X.
	; CFCF: DEC E              ; E = seed_X - 1 (one cell to the left of the seed)

; --------------------------------------------------------------------------
; LEFTWARD SCAN SETUP ($CFD0-$D01B)
; --------------------------------------------------------------------------
; Check if the cell at (E, D) = (seed_X - 1, seed_Y) is empty. If so,
; compute the screen addresses for three rows (Y+1, Y-1, Y) at this new
; X position and enter the leftward scan loop. If the cell is not empty,
; return (the seed was at the leftmost empty cell in the row).
; --------------------------------------------------------------------------

	DB	0F8H,0CDH,0DBH,0CEH,0B7H,0C0H,7BH,1FH	; cfd0 xM[N7@{.
	; CFD0: RET M              ; If E went negative (X < 0), the seed was at X=0.
	;                          ; No leftward scan possible -> return.
	;                          ; [BOUNDARY: DEC E from 0 gives $FF = -1, sign flag set.]
	; CFD1: CALL $CEDB         ; Read the cell at (D=Y, E=X-1). This calls COORDS_TO_ADDR
	;                          ; to convert to a screen address and READ_CELL_BMP to get
	;                          ; the 2-bit cell value. Returns A = cell value, HL = address.
	; CFD4: OR  A              ; Set Z flag if cell is empty (A=0)
	; CFD5: RET NZ             ; If cell at (seed_X-1, seed_Y) is NOT empty, return.
	;                          ; Nothing to fill leftward. The rightward scan already
	;                          ; handled everything to the right, and the cell to the left
	;                          ; is already a wall/border/claimed cell.

; --------------------------------------------------------------------------
; The cell at (seed_X - 1) IS empty. Set up for leftward scanning.
; Compute byte column offset and screen addresses for three rows.
; This is the same computation as $CF3A-$CF80 but for the new X position.
; --------------------------------------------------------------------------

	; CFD6: LD  A,E            ; A = new X coordinate (seed_X - 1)
	; CFD7: RRA                ; Shift right (divide by 2 step 1)

	DB	1FH,0E6H,3FH,4FH,7AH,3CH,0FEH,60H	; cfd8 .f?Oz<~`
	; CFD8: RRA                ; Shift right again. A = X / 4 (byte column, with junk in top bits)
	; CFD9: AND $3F            ; Mask to 6 bits: clean byte column offset (0-31)
	; CFDB: LD  C,A            ; C = byte column offset
	;
	; -- Compute screen address for row Y+1 (below) --
	;
	; CFDC: LD  A,D            ; A = Y coordinate
	; CFDD: INC A              ; A = Y + 1
	; CFDE: CP  $60            ; Compare with 96: clamp Y+1 to field bounds

	DB	3FH					; cfe0 ?
	; CFE0: CCF                ; Complement carry for the clamping logic
;

; --------------------------------------------------------------------------
; From here ($CFE1), the original disassembler successfully decoded the
; instructions. The following code is the address computation for the
; three rows (Y+1, Y-1, Y) and the mask/flag setup, identical in logic
; to the rightward scan setup at $CF40-$CF80.
; --------------------------------------------------------------------------

	SBC	A,0		; cfe1  de 00		^.
	; CFE1: SBC A,0            ; A = (Y+1) - 0 - carry. Clamps Y+1 to at most 95.
	;                          ; Same boundary protection as in the rightward setup at CF45.

	ADD	A,A		; cfe3  87		.
	; CFE3: ADD A,A            ; A = clamped(Y+1) * 2 (first multiply for table index)

	ADD	A,A		; cfe4  87		.
	; CFE4: ADD A,A            ; A = clamped(Y+1) * 4 (table index into $FC40 lookup table)

	LD	L,A		; cfe5  6f		o
	; CFE5: LD  L,A            ; L = table index (low byte of pointer into lookup table)

	ADC	A,0FCH		; cfe6  ce fc		N|
	; CFE6: ADC A,$FC          ; Compute high byte: A = tableIndex + $FC + carry
	;                          ; The lookup table base is at $FC00. Adding $FC to the low
	;                          ; index plus any carry from the *4 multiplication gives the
	;                          ; correct high byte of the table address.

	SUB	L		; cfe8  95		.
	; CFE8: SUB L              ; A = highByte (isolate: subtract L back out)
	;                          ; Result: A = $FC + carry_from_ADC, which is the high byte
	;                          ; of the pointer into the row address lookup table.

	LD	H,A		; cfe9  67		g
	; CFE9: LD  H,A            ; H = high byte of table pointer. HL now points into $FC00+.

	LD	A,C		; cfea  79		y
	; CFEA: LD  A,C            ; A = byte column offset (computed at CFDB)

	ADD	A,(HL)		; cfeb  86		.
	; CFEB: ADD A,(HL)         ; A = byteCol + table[index].low = screen address low byte
	;                          ; The table entry's low byte is the row's starting byte offset.

	INC	HL		; cfec  23		#
	; CFEC: INC HL             ; Advance to the high byte of the table entry

	LD	H,(HL)		; cfed  66		f
	; CFED: LD  H,(HL)         ; H = table[index].high = screen address high byte ($40-$57)

	LD	L,A		; cfee  6f		o
	; CFEE: LD  L,A            ; L = screen address low byte. HL = screen addr for (X, Y+1).

	PUSH	HL		; cfef  e5		e
	; CFEF: PUSH HL            ; Save Y+1 row address on CPU stack (will be popped into IY)

; --------------------------------------------------------------------------
; Compute screen address for row Y-1 (above)
; --------------------------------------------------------------------------

	LD	A,D		; cff0  7a		z
	; CFF0: LD  A,D            ; A = Y coordinate

	SUB	1		; cff1  d6 01		V.
	; CFF1: SUB 1              ; A = Y - 1 (one row above). If Y was 0: carry SET.

	ADC	A,0		; cff3  ce 00		N.
	; CFF3: ADC A,0            ; A = (Y-1) + carry. Clamps Y-1 to 0 if underflow occurred.
	;                          ; In practice, Y >= 18 (field top), so clamp never triggers.

	ADD	A,A		; cff5  87		.
	; CFF5: ADD A,A            ; A = clamped(Y-1) * 2

	ADD	A,A		; cff6  87		.
	; CFF6: ADD A,A            ; A = clamped(Y-1) * 4 (lookup table index)

	LD	L,A		; cff7  6f		o
	; CFF7: LD  L,A            ; L = table index

	ADC	A,0FCH		; cff8  ce fc		N|
	; CFF8: ADC A,$FC          ; Compute high byte of table pointer

	SUB	L		; cffa  95		.
	; CFFA: SUB L              ; Isolate high byte

	LD	H,A		; cffb  67		g
	; CFFB: LD  H,A            ; H = high byte. HL points into the lookup table.

	LD	A,C		; cffc  79		y
	; CFFC: LD  A,C            ; A = byte column offset

	ADD	A,(HL)		; cffd  86		.
	; CFFD: ADD A,(HL)         ; Add row base address low byte from lookup table

	INC	HL		; cffe  23		#
	; CFFE: INC HL             ; Advance to high byte of table entry

	LD	H,(HL)		; cfff  66		f
	; CFFF: LD  H,(HL)         ; H = high byte of screen row address

	LD	L,A		; d000  6f		o
	; D000: LD  L,A            ; HL = screen address for (X, Y-1)

	PUSH	HL		; d001  e5		e
	; D001: PUSH HL            ; Save Y-1 row address on CPU stack (will be popped into IX)

; --------------------------------------------------------------------------
; Compute screen address for row Y (current row)
; --------------------------------------------------------------------------

	LD	A,D		; d002  7a		z
	; D002: LD  A,D            ; A = Y coordinate (no adjustment needed for current row)

	ADD	A,A		; d003  87		.
	; D003: ADD A,A            ; A = Y * 2

	ADD	A,A		; d004  87		.
	; D004: ADD A,A            ; A = Y * 4 (lookup table index)

	LD	L,A		; d005  6f		o
	; D005: LD  L,A            ; L = table index

	ADC	A,0FCH		; d006  ce fc		N|
	; D006: ADC A,$FC          ; Compute high byte of table pointer

	SUB	L		; d008  95		.
	; D008: SUB L              ; Isolate high byte

	LD	H,A		; d009  67		g
	; D009: LD  H,A            ; H = high byte. HL points into lookup table.

	LD	A,C		; d00a  79		y
	; D00A: LD  A,C            ; A = byte column offset

	ADD	A,(HL)		; d00b  86		.
	; D00B: ADD A,(HL)         ; Add row base address low byte

	INC	HL		; d00c  23		#
	; D00C: INC HL             ; Advance to high byte

	LD	H,(HL)		; d00d  66		f
	; D00D: LD  H,(HL)         ; H = high byte of screen row address

	LD	L,A		; d00e  6f		o
	; D00E: LD  L,A            ; HL = screen bitmap address for (X, Y) — current row.
	;                          ; This is the primary pointer for the leftward scan loop.

; --------------------------------------------------------------------------
; Pop the saved row addresses into index registers
; --------------------------------------------------------------------------

	POP	IX		; d00f  dd e1		]a
	; D00F: POP IX             ; IX = address for row Y-1 (saved at D001).
	;                          ; Used to check the row above during the leftward scan.

	POP	IY		; d011  fd e1		}a
	; D011: POP IY             ; IY = address for row Y+1 (saved at CFEF).
	;                          ; Used to check the row below during the leftward scan.

; --------------------------------------------------------------------------
; Set up cell bitmask and segment tracking flags
; --------------------------------------------------------------------------

	LD	A,E		; d013  7b		{
	; D013: LD  A,E            ; A = X coordinate (seed_X - 1, for leftward scan)

	AND	3		; d014  e6 03		f.
	; D014: AND 3              ; A = X mod 4 (cell position within byte: 0-3)

	LD	C,A		; d016  4f		O
	; D016: LD  C,A            ; C = cell position (temporary, for mask table lookup)

	LD	B,0FBH		; d017  06 fb		.{
	; D017: LD  B,$FB          ; B = $FB high byte. BC = $FB00 + cellPosition.
	;                          ; The mask table at $FB00: [$C0, $30, $0C, $03]

	LD	A,(BC)		; d019  0a		.
	; D019: LD  A,(BC)         ; A = 2-bit bitmask for this cell position
	;                          ; E.g., position 0 -> $C0 (bits 7-6), position 3 -> $03 (bits 1-0)

	LD	B,A		; d01a  47		G
	; D01A: LD  B,A            ; B = cell bitmask (used throughout the leftward scan loop)

	LD	C,3		; d01b  0e 03		..
	; D01B: LD  C,3            ; C = $03 = initial segment flags
	;                          ; Bit 0 set = "row above in non-empty segment"
	;                          ; Bit 1 set = "row below in non-empty segment"


; ==========================================================================
; LEFTWARD SCAN LOOP ($D01D-$D065)
; ==========================================================================
;
; Identical in logic to the rightward scan loop ($CF81-$CFCC), but moves
; LEFT (DEC E, DEC HL/IX/IY instead of INC). The loop fills empty cells
; and pushes seeds for adjacent empty regions in rows above and below.
;
; Entry:
;   HL = screen bitmap address for current cell (row Y)
;   IX = screen bitmap address for current cell (row Y-1, above)
;   IY = screen bitmap address for current cell (row Y+1, below)
;   B  = 2-bit cell bitmask for current position within the byte
;   C  = segment tracking flags (both bits set initially)
;   D  = Y coordinate
;   E  = X coordinate (starting at seed_X - 1, decrementing leftward)
;
; Exit:
;   Returns via RET NZ (hit non-empty cell) or RET M (X went negative).
;   The return goes back to the main FLOOD_FILL loop at $CF20, which
;   pops the next seed or terminates the fill.
; ==========================================================================

XD01D:	LD	A,B		; d01d  78		x
	; D01D: LD  A,B            ; A = current cell bitmask

	AND	(HL)		; d01e  a6		&
	; D01E: AND (HL)           ; Test screen byte against mask: are the cell's bits set?
	;                          ; Z = cell is empty (all masked bits are 0)
	;                          ; NZ = cell is occupied (at least one masked bit is 1)

	RET	NZ		; d01f  c0		@
	; D01F: RET NZ             ; [LEFTWARD BOUNDARY] If cell is not empty, the leftward
	;                          ; scan has hit a wall. Return to the main fill loop at $CF20.
	;                          ; This is analogous to JR NZ,$CFCE in the rightward scan,
	;                          ; but uses RET because the leftward scan was entered via
	;                          ; the CALL $CF34 at $CF1D. The RET pops back to $CF20.

; --------------------------------------------------------------------------
; FILL CURRENT CELL: Write the fill pattern to the bitmap
; --------------------------------------------------------------------------

	LD	A,(XCEFC)	; d020  3a fc ce	:|N
	; D020: LD  A,($CEFC)      ; [SELF-MOD READ] A = pattern byte 0 (top pixel row)
	;                          ; For CLAIMED cells: A = $55 (checkerboard: 01010101)
	;                          ; For BORDER cells: A = $FF (solid: 11111111)
	;                          ; This was stored during FLOOD_FILL init at $CF0A.

	AND	B		; d023  a0
	; D023: AND B              ; Mask pattern to only this cell's 2-bit position.
	;                          ; E.g., B=$C0, A=$55 -> A=$40 (only bits 7-6 from pattern)

	OR	(HL)		; d024  b6		6
	; D024: OR  (HL)           ; Merge new cell bits with existing screen byte.
	;                          ; Other cells in this byte (at different positions) are
	;                          ; preserved because their bits were zeroed by the AND B.

	LD	(HL),A		; d025  77		w
	; D025: LD  (HL),A         ; [MEMORY WRITE] Write to bitmap, top pixel row of cell.
	;                          ; Address range: $4000-$57FF (ZX Spectrum screen bitmap).

	INC	H		; d026  24		$
	; D026: INC H              ; Move to the next pixel row within the character cell.
	;                          ; In ZX Spectrum layout, adding $0100 to the address moves
	;                          ; down one pixel row (within the same 8-pixel-tall char cell).
	;                          ; This gives us the bottom pixel row of the 2-pixel-tall game cell.

	LD	A,(XCEFD)	; d027  3a fd ce	:}N
	; D027: LD  A,($CEFD)      ; [SELF-MOD READ] A = pattern byte 1 (bottom pixel row)
	;                          ; For CLAIMED cells: A = $00 (blank bottom row)

	AND	B		; d02a  a0
	; D02A: AND B              ; Mask to this cell's 2-bit position

	OR	(HL)		; d02b  b6		6
	; D02B: OR  (HL)           ; Merge with existing byte at the bottom pixel row

	LD	(HL),A		; d02c  77		w
	; D02C: LD  (HL),A         ; [MEMORY WRITE] Write to bitmap, bottom pixel row of cell.

	DEC	H		; d02d  25		%
	; D02D: DEC H              ; Restore HL to the top pixel row address.
	;                          ; All cell reads (AND (HL) at D01E) use the top pixel row.

; --------------------------------------------------------------------------
; CHECK ROW ABOVE (IX): Detect empty/non-empty transitions
; --------------------------------------------------------------------------
; Same logic as the rightward scan's above-check at $CF93-$CFA6.
; Bit 0 of C tracks the "in non-empty segment above" state.
; --------------------------------------------------------------------------

	LD	A,(IX+0)	; d02e  dd 7e 00	]~.
	; D02E: LD  A,(IX+0)       ; Read screen byte from the row above (Y-1) at this column.
	;                          ; IX tracks the same byte column as HL but in the row above.

	AND	B		; d031  a0
	; D031: AND B              ; Test whether the cell above is occupied (non-zero).
	;                          ; Uses the same 2-bit mask B as the current cell.

	JR	NZ,XD041	; d032  20 0d		 .
	; D032: JR  NZ,$D041       ; If above cell is NON-EMPTY: jump to SET 0,C (mark that
	;                          ; we're inside a non-empty segment in the row above).
	;                          ; [GAME LOGIC: Wall or claimed cell above. When the scan
	;                          ; later finds an empty cell above, the transition triggers
	;                          ; a seed push.]

	BIT	0,C		; d034  cb 41		KA
	; D034: BIT 0,C            ; Was bit 0 set? (Were we in a non-empty segment above?)

	JR	Z,XD043		; d036  28 0b		(.
	; D036: JR  Z,$D043        ; If bit 0 was already CLEAR (we were in an empty area),
	;                          ; skip to the below-row check. No new seed needed -- we
	;                          ; already pushed a seed for this contiguous empty region.

	RES	0,C		; d038  cb 81		K.
	; D038: RES 0,C            ; Clear bit 0: transitioning from non-empty to empty above.
	;                          ; This marks that we're now in an empty region in the row above.

	DEC	D		; d03a  15		.
	; D03A: DEC D              ; D = Y - 1 (temporarily point to the row above for seed push).

	CALL	XD067		; d03b  cd 67 d0	MgP
	; D03B: CALL $D067         ; PUSH_SEED: Push (E=currentX, D=Y-1) onto the fill stack.
	;                          ; When this seed is later popped and processed, the fill will
	;                          ; expand into the empty region in the row above the current scan.

	INC	D		; d03e  14		.
	; D03E: INC D              ; D = Y (restore current row Y coordinate).

	JR	XD043		; d03f  18 02		..
	; D03F: JR  $D043          ; Skip the SET instruction, go to below-row check.
;
XD041:	SET	0,C		; d041  cb c1		KA
	; D041: SET 0,C            ; Mark that the row above is in a non-empty segment at this X.
	;                          ; The next time an empty cell is found above, the transition
	;                          ; from set->clear will trigger a seed push.

; --------------------------------------------------------------------------
; CHECK ROW BELOW (IY): Same logic, using bit 1 of C
; --------------------------------------------------------------------------

XD043:	LD	A,(IY+0)	; d043  fd 7e 00	}~.
	; D043: LD  A,(IY+0)       ; Read screen byte from the row below (Y+1) at this column.
	;                          ; IY tracks the same byte column as HL but in the row below.

	AND	B		; d046  a0
	; D046: AND B              ; Test whether the cell below is occupied.

	JR	NZ,XD056	; d047  20 0d		 .
	; D047: JR  NZ,$D056       ; If below cell is NON-EMPTY: jump to SET 1,C.

	BIT	1,C		; d049  cb 49		KI
	; D049: BIT 1,C            ; Was bit 1 set? (Were we in a non-empty segment below?)

	JR	Z,XD058		; d04b  28 0b		(.
	; D04B: JR  Z,$D058        ; If already in empty area below, skip. No duplicate seed.

	RES	1,C		; d04d  cb 89		K.
	; D04D: RES 1,C            ; Clear bit 1: entering empty region below.

	INC	D		; d04f  14		.
	; D04F: INC D              ; D = Y + 1 (temporarily point to row below).

	CALL	XD067		; d050  cd 67 d0	MgP
	; D050: CALL $D067         ; PUSH_SEED: Push (E=currentX, D=Y+1) onto the fill stack.
	;                          ; The fill will later expand into this empty region below.

	DEC	D		; d053  15		.
	; D053: DEC D              ; D = Y (restore current row).

	JR	XD058		; d054  18 02		..
	; D054: JR  $D058          ; Skip SET, go to advance.
;
XD056:	SET	1,C		; d056  cb c9		KI
	; D056: SET 1,C            ; Mark that row below is in a non-empty segment.

; --------------------------------------------------------------------------
; ADVANCE LEFTWARD: Decrement X, rotate mask, check byte boundary
; --------------------------------------------------------------------------

XD058:	DEC	E		; d058  1d		.
	; D058: DEC E              ; E = X - 1 (advance one cell to the LEFT).

	RET	M		; d059  f8		x
	; D059: RET M              ; [LEFTWARD BOUNDARY] If E went negative (DEC from 0 gives
	;                          ; $FF, which is -1 with sign flag set), the scan has reached
	;                          ; the left edge. Return to the main fill loop at $CF20.
	;                          ; In practice, the border at X=2 is non-empty, so the scan
	;                          ; always hits RET NZ at D01F before reaching X=0.

	RLC	B		; d05a  cb 00		K.
	; D05A: RLC B              ; Rotate cell bitmask LEFT by 1 bit.

	RLC	B		; d05c  cb 00		K.
	; D05C: RLC B              ; Rotate LEFT again (total: 2 positions left).
	;                          ; Moving LEFT means going to a HIGHER bit position within
	;                          ; the byte. RLC x2 achieves this with the wraparound carry
	;                          ; signaling a byte boundary crossing.
	;                          ;
	;                          ; Carry is SET when the mask wraps from $C0 (position 0,
	;                          ; leftmost in byte) to $03 (position 3, rightmost in the
	;                          ; PREVIOUS byte). The carry signals that we need to move
	;                          ; to the preceding screen byte.

	JR	NC,XD01D	; d05e  30 bd		0=
	; D05E: JR  NC,$D01D       ; If carry is CLEAR: still within the same screen byte.
	;                          ; Jump back to the top of the leftward scan loop.

; --------------------------------------------------------------------------
; Byte boundary crossed (leftward): move to the previous screen byte
; --------------------------------------------------------------------------

	DEC	HL		; d060  2b		+
	; D060: DEC HL             ; HL -= 1: move to the PREVIOUS byte in the current row.

	DEC	IX		; d061  dd 2b		]+
	; D061: DEC IX             ; IX -= 1: move to the previous byte in the row above.

	DEC	IY		; d063  fd 2b		}+
	; D063: DEC IY             ; IY -= 1: move to the previous byte in the row below.

	JR	XD01D		; d065  18 b6		.6
	; D065: JR  $D01D          ; Jump back to the top of the leftward scan loop.
	;                          ; The mask B now points to position 3 ($03) in this new byte,
	;                          ; which is the rightmost cell — correct for leftward movement
	;                          ; entering a new byte from the right side.


; ==========================================================================
; PUSH_SEED ($D067) -- Push a coordinate onto the flood fill stack
; ==========================================================================
;
; Called from the scan loops when a transition from non-empty to empty is
; detected in an adjacent row. Pushes the current (X, Y) coordinate pair
; onto the fill stack at $9400+, where it will be popped later by the
; main fill loop at $CF28.
;
; On entry:
;   E = X coordinate to push (the current scan position)
;   D = Y coordinate to push (adjusted by the caller to Y-1 or Y+1)
;   HL = must be preserved (it holds the current row scan address)
;
; On exit:
;   Stack pointer ($CEFF) advanced by 2
;   Stack counter ($CEFE) incremented by 1
;   HL preserved (saved/restored via PUSH/POP)
;   D, E unchanged
;
; Stack entry format (2 bytes):
;   Byte 0: X coordinate (E)
;   Byte 1: Y coordinate (D)
;
; The stack grows upward from $9400. The $9400-$97FF range provides 1024
; bytes = 512 entries, which is more than enough for any game field
; (the field interior is only 122 x 74 = 9028 cells).
; ==========================================================================

XD067:	PUSH	HL		; d067  e5		e
	; D067: PUSH HL            ; Save the current scan-row screen address on the CPU stack.
	;                          ; We need to use HL temporarily for the fill stack pointer.

	LD	HL,(XCEFF)	; d068  2a ff ce	*.N
	; D068: LD  HL,($CEFF)     ; [SELF-MOD READ] Load the fill stack pointer.
	;                          ; Points to the next free slot in the stack at $9400+.

	LD	(HL),E		; d06b  73		s
	; D06B: LD  (HL),E         ; Store X coordinate at the current stack slot.

	INC	HL		; d06c  23		#
	; D06C: INC HL             ; Advance to the next byte in the stack.

	LD	(HL),D		; d06d  72		r
	; D06D: LD  (HL),D         ; Store Y coordinate.

	INC	HL		; d06e  23		#
	; D06E: INC HL             ; Advance past the Y byte. HL now points to the next free slot.

	LD	(XCEFF),HL	; d06f  22 ff ce	".N
	; D06F: LD  ($CEFF),HL     ; [SELF-MOD WRITE] Update the fill stack pointer.
	;                          ; Next push will write to this new location.

	LD	HL,XCEFE	; d072  21 fe ce	!~N
	; D072: LD  HL,$CEFE       ; HL = address of the fill stack counter.

	INC	(HL)		; d075  34		4
	; D075: INC (HL)           ; Increment the stack counter.
	;                          ; The main loop at $CF23 decrements this to pop entries.
	;                          ; When DEC at $CF23 takes the counter below 0, the stack
	;                          ; is empty and RET M terminates the fill.

	POP	HL		; d076  e1		a
	; D076: POP HL             ; Restore the scan-row screen address.
	;                          ; The scan loop continues from exactly where it was.

	RET			; d077  c9		I
	; D077: RET                ; Return to the scan loop (caller at $CFA0/$CFB5/$D03B/$D050).
;
