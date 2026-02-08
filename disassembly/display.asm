; ==========================================================================
; SCORE DISPLAY, TIMER BAR & TEXT RENDERING ($D27A-$D3C3)
; ==========================================================================
;
; This module handles all HUD (heads-up display) rendering for Zolyx.
; The HUD occupies screen rows 0-3, above the game field (which starts
; at pixel row 16, i.e. character row 2 for the field border).
;
; HUD LAYOUT (rows 0-3, above the game field):
;   Row 0-1: "Score XXXXX   Level XX   Lives X" (double-height HUD font)
;   Row 2-3: "Time" + timer bar + "XXX%"
;
; The HUD uses a custom double-height font stored at $FA00. Each character
; is 8 pixels wide and 8 bytes tall in the font, but rendered as 8x16 on
; screen by writing each font byte to two consecutive pixel rows. The font
; has a limited character set (32 entries): digits 0-9, space, %, and just
; enough letters to spell "Score", "Level", "Lives", "Time".
;
; RENDERING COORDINATE SYSTEM:
;   SCORE_DISPLAY_POS ($D312) is a 3-byte working variable:
;     Byte 0 (IX+0): Column offset within the screen row (0-31)
;     Byte 1 (IX+1): Screen character row (0-23)
;     Byte 2 (IX+2): Flags — bit 7 set = inverse video (CPL the font data)
;   Each display routine sets the column and row before rendering.
;   After each character is rendered, the column auto-advances by 1.
;
; The row pointer table at $FC00 maps pixel rows to ZX Spectrum screen
; addresses (which are non-linear due to the Spectrum's peculiar memory
; layout: 3 thirds of 8 character rows, each interleaved by pixel line).
; Each entry is 2 bytes: low byte = offset within row, high byte = page.
; The table has 2 bytes per pixel row, so row N is at $FC00 + N*2.
;
; KEY MEMORY ADDRESSES (see game_variables.asm):
;   $B0BF  TIMER_BAR_POS — Current displayed bar width (animated toward GAME_TIMER)
;   $B0C0  GAME_TIMER    — Actual timer value (0-176, counts down)
;   $B0C1  LEVEL_NUM     — Current level (0-based; displayed as +1)
;   $B0C2  LIVES         — Lives remaining
;   $B0C3  BASE_SCORE    — 16-bit base score (little-endian)
;   $B0C5  RAW_PERCENT   — Raw claimed percentage (cells claimed / 90)
;   $B0C6  FILL_PERCENT  — Filled percentage (all non-empty - 396 border cells) / 90
;
; CROSS-REFERENCES:
;   PROCESS_ATTR_COLOR ($BC07) — Converts a color value for current screen mode
;   FILL_ATTR_RECT ($BAF6)     — Fills a rectangular area of attribute memory
;   HUD_FONT ($FA00)           — 32-char x 8-byte double-height font data
;   ROW_PTR_TABLE ($FC00)      — Pre-computed screen line address lookup
;   Main loop calls UPDATE_TIMER_BAR in a tight loop at level-complete ($C57D)
;   Trail/init code calls UPDATE_LIVES_DISPLAY at $CC57
;
; ==========================================================================


; ==========================================================================
; UPDATE_SCORE_DISPLAY ($D27A)
; ==========================================================================
; Computes the display score and renders it as 5 decimal digits in the HUD.
;
; The display score formula is:
;   display_score = BASE_SCORE + (FILL_PERCENT + RAW_PERCENT) * 4
;
; This means the score shown to the player includes both the base score
; (accumulated from spark kills at +50 each, and timer bonus at level end)
; and a real-time bonus proportional to how much of the field is filled.
; The *4 multiplier makes percentage progress visibly rewarding.
;
; Entry: No register requirements (reads from game variables)
; Exit:  All registers modified. Score rendered at column 6, row 0.
; ==========================================================================
UPDATE_SCORE_DISPLAY:	LD	HL,X0006	; d27a  21 06 00	!..	; HL = $0006: column 6, row 0 (score digits position)
	LD	(SCORE_DISPLAY_POS),HL	; d27d  22 12 d3	".S	; Store rendering position — col=6, row=0
	LD	A,(FILL_PERCENT)	; d280  3a c6 b0	:F0	; A = filled percentage (0-100, stored at $B0C6)
	LD	HL,RAW_PERCENT	; d283  21 c5 b0	!E0	; HL points to raw claimed percentage ($B0C5)
	ADD	A,(HL)		; d286  86		.	; A = FILL_PERCENT + RAW_PERCENT (combined percentage)
	LD	L,A		; d287  6f		o	; L = combined percentage value
	LD	H,0		; d288  26 00		&.	; HL = combined percentage as 16-bit (H=0, L=sum)
	ADD	HL,HL		; d28a  29		)	; HL = combined * 2
	ADD	HL,HL		; d28b  29		)	; HL = combined * 4 (the percentage bonus multiplier)
	LD	DE,(BASE_SCORE)	; d28c  ed 5b c3 b0	m[C0	; DE = 16-bit base score from $B0C3-$B0C4
	ADD	HL,DE		; d290  19		.	; HL = BASE_SCORE + (FILL_PERCENT + RAW_PERCENT) * 4
;
; NOTE: The following two DW directives are actually executable code that the
; disassembler failed to decode. The raw bytes are: CD 15 D3 C9, which is:
;   CALL DISPLAY_5DIGIT   ($D315)  — render HL as 5 decimal digits
;   RET                            — return to caller
; The disassembler split these across a DW boundary incorrectly.
;
	DW	X15CD		; d291   cd 15      M.	; Actually: CALL $D315 (DISPLAY_5DIGIT)
	DW	XC9D3		; d293   d3 c9      SI	; Actually: ...D3 is high byte of $D315; C9 = RET
;


; ==========================================================================
; UPDATE_LEVEL_DISPLAY ($D295)
; ==========================================================================
; Renders the current level number as a 2-digit decimal in the HUD.
; The internal level number (LEVEL_NUM at $B0C1) is 0-based, so we add 1
; before displaying to show the player "Level 1" on the first level.
;
; Entry: No register requirements
; Exit:  All registers modified. Level rendered at column 20 ($14), row 0.
; ==========================================================================
UPDATE_LEVEL_DISPLAY:	LD	HL,X0014	; d295  21 14 00	!..	; HL = $0014: column 20, row 0 (level display position)
	LD	(SCORE_DISPLAY_POS),HL	; d298  22 12 d3	".S	; Store rendering position — col=20, row=0
	LD	A,(LEVEL_NUM)	; d29b  3a c1 b0	:A0	; A = current level number (0-based, from $B0C1)
	INC	A		; d29e  3c		<	; A = level + 1 (convert to 1-based for display)
	CALL	DISPLAY_2DIGIT		; d29f  cd 41 d3	MAS	; Render A as 2 decimal digits at current HUD position
	RET			; d2a2  c9		I	; Return to caller
;


; ==========================================================================
; UPDATE_PERCENT_DISPLAY ($D2A3)
; ==========================================================================
; Renders the filled percentage as a 3-digit decimal in the HUD.
; This shows the player how much of the field they have claimed.
; The "%" suffix character is part of the static HUD label, not rendered here.
;
; Entry: No register requirements
; Exit:  All registers modified. Percentage rendered at column 28 ($1C), row 2.
; ==========================================================================
UPDATE_PERCENT_DISPLAY:	LD	HL,X021C	; d2a3  21 1c 02	!..	; HL = $021C: column 28, row 2 (percentage position)
	LD	(SCORE_DISPLAY_POS),HL	; d2a6  22 12 d3	".S	; Store rendering position — col=28 ($1C), row=2
	LD	A,(FILL_PERCENT)	; d2a9  3a c6 b0	:F0	; A = filled percentage (0-100, from $B0C6)
	CALL	DISPLAY_3DIGIT		; d2ac  cd 4e d3	MNS	; Render A as 3 decimal digits at current HUD position
	RET			; d2af  c9		I	; Return to caller
;


; ==========================================================================
; UPDATE_LIVES_DISPLAY ($D2B0)
; ==========================================================================
; Renders the remaining lives count as a single digit in the HUD.
; Only one digit is needed since lives start at 3 and max is single-digit.
; This is the only display routine that calls HUD_CHAR_RENDER directly
; rather than going through a multi-digit conversion routine.
;
; Entry: No register requirements
; Exit:  All registers modified. Lives rendered at column 31 ($1F), row 0.
; Called from: trail_cursor_init.asm ($CC57), main_loop.asm ($C384)
; ==========================================================================
UPDATE_LIVES_DISPLAY:	LD	HL,X001F	; d2b0  21 1f 00	!..	; HL = $001F: column 31, row 0 (lives position, rightmost)
	LD	(SCORE_DISPLAY_POS),HL	; d2b3  22 12 d3	".S	; Store rendering position — col=31, row=0
	LD	A,(LIVES)	; d2b6  3a c2 b0	:B0	; A = lives remaining (from $B0C2)
	LD	IX,SCORE_DISPLAY_POS	; d2b9  dd 21 12 d3	]!.S	; IX points to rendering position structure
	CALL	HUD_CHAR_RENDER		; d2bd  cd 86 d3	M.S	; Render single digit A at (col=31, row=0)
	RET			; d2c0  c9		I	; Return to caller
;


; ==========================================================================
; UPDATE_TIMER_BAR ($D2C1)
; ==========================================================================
; Animates the timer bar toward the current GAME_TIMER value.
;
; The timer bar is a visual representation of remaining time, displayed as
; a filled horizontal bar spanning columns 5-26, rows 2-3 of the HUD area.
; The bar is 13 pixels tall (pixel rows 17-29) and its width in pixels
; equals the TIMER_BAR_POS value (0-176). The bar animates: each call moves
; TIMER_BAR_POS one step closer to GAME_TIMER, toggling one column of pixels
; via XOR. This creates a smooth grow/shrink animation.
;
; The bar color changes based on remaining time:
;   - Green (attr $44 = bright green ink on green paper) when bar >= 40 pixels
;   - Red   (attr $42 = bright red ink on red paper)   when bar < 40 pixels
; This gives the player an urgent visual warning when time is running low.
;
; The XOR drawing technique means:
;   - When the bar grows (TIMER_BAR_POS < GAME_TIMER), INC bar pos first,
;     then XOR the NEW column → pixels appear (0 XOR font = font)
;   - When the bar shrinks (TIMER_BAR_POS > GAME_TIMER), read OLD pos,
;     then DEC bar pos → XOR the old column → pixels disappear (font XOR font = 0)
;
; The pixel column to toggle is computed from TIMER_BAR_POS + 40:
;   - The +40 offset ($28) shifts the bar to start at pixel X=40 (column 5)
;   - The column byte = (TIMER_BAR_POS + 40) >> 3 (divide by 8 for char column)
;   - The bit position within that byte comes from a bitmask table at $FB08+
;     indexed by (TIMER_BAR_POS + 40) & 7, giving the single-pixel bit to XOR
;
; The row pointer table at $FC22 is $FC00 + 17*2, corresponding to pixel
; row 17 (the first pixel row of the timer bar area). Each entry is 2 bytes
; (low addr, high addr) for the ZX Spectrum's non-linear screen layout.
; 13 entries cover pixel rows 17-29 (the full height of the timer bar).
;
; Entry: No register requirements
; Exit:  Carry flag: set (1) if bar is still animating (pos != timer)
;                    clear (0) if bar has reached target (pos == timer)
;        All registers modified.
; Called from: main_loop.asm level-complete animation ($C57D, tight loop)
; ==========================================================================
UPDATE_TIMER_BAR:	LD	HL,TIMER_BAR_POS	; d2c1  21 bf b0	!?0	; HL points to current bar display width ($B0BF)
	LD	A,(GAME_TIMER)	; d2c4  3a c0 b0	:@0	; A = actual game timer value (0-176, from $B0C0)
	CP	(HL)		; d2c7  be		>	; Compare GAME_TIMER with TIMER_BAR_POS
	RET	Z		; d2c8  c8		H	; If equal, bar is fully updated — return with carry=0 (Z implies NC after CP)
	JR	C,XD2CF		; d2c9  38 04		8.	; If GAME_TIMER < BAR_POS, bar needs to shrink → jump to shrink path
;
; --- Bar needs to grow (GAME_TIMER > TIMER_BAR_POS) ---
	INC	(HL)		; d2cb  34		4	; Increment TIMER_BAR_POS by 1 (bar grows one pixel)
	LD	A,(HL)		; d2cc  7e		~	; A = new (incremented) bar position — this is the column to draw
	JR	XD2D1		; d2cd  18 02		..	; Skip to the common drawing code
;
; --- Bar needs to shrink (GAME_TIMER < TIMER_BAR_POS) ---
XD2CF:	LD	A,(HL)		; d2cf  7e		~	; A = current bar position (the column to erase via XOR)
	DEC	(HL)		; d2d0  35		5	; Decrement TIMER_BAR_POS by 1 (bar shrinks one pixel)
;
; --- Common: toggle pixel column A (relative bar position) ---
; At this point, A = the bar pixel offset (0-176) to toggle on/off.
; We need to convert this to a screen byte address and bit mask.
;
XD2D1:	ADD	A,28H		; d2d1  c6 28		F(	; A = bar_pos + 40 — convert to absolute pixel X coordinate
				;				; (bar starts at pixel X=40, i.e. character column 5)
	LD	B,A		; d2d3  47		G	; B = absolute pixel X (save for bit extraction below)
;
; --- Compute character column (X / 8) ---
	RRA			; d2d4  1f		.	; A = X >> 1 (rotate right through carry)
	RRA			; d2d5  1f		.	; A = X >> 2
	RRA			; d2d6  1f		.	; A = X >> 3  (effectively pixel_X / 8)
	AND	1FH		; d2d7  e6 1f		f.	; Mask to 5 bits (0-31 column range) — this is the byte column
	LD	C,A		; d2d9  4f		O	; C = character column (byte offset within each screen row)
;
; --- Compute pixel bit mask address ---
; The bitmask for the specific pixel within the byte is stored in a table
; at $FB00+. The index is (pixel_X & 7) + 8, using bits 0-2 of the X coord.
; $FB08 holds single-pixel bitmasks: bit 7 for X&7=0, bit 6 for X&7=1, etc.
; DE will point to the correct bitmask byte.
;
	LD	A,B		; d2da  78		x	; A = absolute pixel X (restore from B)
	AND	7		; d2db  e6 07		f.	; A = X & 7 (bit position within the byte, 0-7)
	ADD	A,8		; d2dd  c6 08		F.	; A = (X & 7) + 8 — offset into bitmask table at $FB00
	LD	E,A		; d2df  5f		_	; E = bitmask table index
	LD	D,0FBH		; d2e0  16 fb		.{	; D = $FB high byte → DE = $FB00 + (X&7) + 8 (bitmask address)
;
; --- Set up row pointer for 13 pixel rows ---
; IX points to the row pointer table entry for pixel row 17 (first row of bar).
; $FC22 = $FC00 + 17*2 = row pointer table base + offset for pixel row 17.
; Each row pointer entry is 2 bytes: (low_byte, high_byte) of screen address.
; We iterate B=13 times for pixel rows 17 through 29.
;
	LD	IX,XFC22	; d2e2  dd 21 22 fc	]!"|	; IX = $FC22: row pointer table entry for pixel row 17
	LD	B,0DH		; d2e6  06 0d		..	; B = 13: number of pixel rows in the timer bar
;
; --- XOR loop: toggle one pixel in each of the 13 rows ---
; For each row:
;   1. Read the low byte of the screen address from (IX+0)
;   2. Add the column offset C to get the exact byte address (low)
;   3. Read the high byte of the screen address from (IX+1)
;   4. Load the pixel bitmask from (DE)
;   5. XOR the bitmask with the screen byte → toggle that single pixel
;   6. Write the result back to the screen
;   7. Advance IX by 2 to the next row's pointer entry
;
XD2E8:	LD	A,(IX+0)	; d2e8  dd 7e 00	]~.	; A = low byte of screen address for this pixel row
	ADD	A,C		; d2eb  81		.	; A = screen_addr_low + column_offset (byte within row)
	LD	L,A		; d2ec  6f		o	; L = computed low byte of target screen address
	LD	H,(IX+1)	; d2ed  dd 66 01	]f.	; H = high byte of screen address for this row
				;				; HL now points to the exact screen byte to modify
	LD	A,(DE)		; d2f0  1a		.	; A = pixel bitmask (single bit set for the target pixel)
	XOR	(HL)		; d2f1  ae		.	; A = screen_byte XOR bitmask — toggles the target pixel
	LD	(HL),A		; d2f2  77		w	; Write the modified byte back to screen memory
	INC	IX		; d2f3  dd 23		]#	; IX += 1 (first half of advancing to next row entry)
	INC	IX		; d2f5  dd 23		]#	; IX += 1 (second half — each row pointer is 2 bytes)
	DJNZ	XD2E8		; d2f7  10 ef		.o	; Decrement B; if not zero, loop for next pixel row
;
; --- Set timer bar color attribute based on remaining time ---
; After toggling the pixel column, update the attribute colors for the
; entire timer bar area. Green (safe) when >= 40 ticks remain, red (danger)
; when < 40.
;
; ZX Spectrum attribute byte format: bit7=FLASH, bit6=BRIGHT, bits5-3=PAPER, bits2-0=INK
;   $44 = 01 000 100 = BRIGHT, paper=black(0), ink=green(4) → bright green on black
;   $42 = 01 000 010 = BRIGHT, paper=black(0), ink=red(2)   → bright red on black
;
; PROCESS_ATTR_COLOR ($BC07) may remap the color based on current display mode.
; FILL_ATTR_RECT ($BAF6) fills a rectangle of attribute cells.
;   Entry: A=attr byte, BC=top-left (B=row, C=col), DE=size (D=height, E=width)
;
	LD	A,(TIMER_BAR_POS)	; d2f9  3a bf b0	:?0	; A = current bar display width (0-176)
	CP	28H		; d2fc  fe 28		~(	; Compare with 40 — the danger threshold
	LD	A,44H		; d2fe  3e 44		>D	; A = $44 = bright green attribute (optimistic default)
	JR	NC,XD304	; d300  30 02		0.	; If bar >= 40, keep green → skip to color application
	LD	A,42H		; d302  3e 42		>B	; A = $42 = bright red attribute (danger! time is low)
XD304:	CALL	PROCESS_ATTR_COLOR		; d304  cd 07 bc	M.<	; Process/remap the attribute color value in A
	LD	BC,X0205	; d307  01 05 02	...	; BC = top-left corner: row=2, col=5 (timer bar area)
	LD	DE,X0216	; d30a  11 16 02	...	; DE = dimensions: height=2 rows, width=22 columns
	CALL	FILL_ATTR_RECT		; d30d  cd f6 ba	Mv:	; Fill the 2x22 attribute rectangle with the color
	SCF			; d310  37		7	; Set carry flag = 1 (signal: bar is still animating)
	RET			; d311  c9		I	; Return with carry=1 (caller loops until bar reaches target)
;


; ==========================================================================
; SCORE_DISPLAY_POS ($D312) — Rendering Position Variable
; ==========================================================================
; 3-byte mutable variable used by all HUD rendering routines:
;   Byte 0 ($D312, IX+0): Column (0-31) — auto-incremented after each char
;   Byte 1 ($D313, IX+1): Character row (0-23) — stays fixed during a string
;   Byte 2 ($D314, IX+2): Flags — bit 7: inverse video (1=CPL font data)
;
; This acts as a "cursor" for HUD text output. Display routines write the
; starting position here, then call digit/string renderers which advance
; the column automatically.
; ==========================================================================
SCORE_DISPLAY_POS:	NOP			; d312  00		.	; Byte 0: column position (0-31)
;
	ORG	0D314H
;
	DB	38H					; d314 8	; Byte 2: flags — $38 here is snapshot state; bit 7=0 → normal video


; ==========================================================================
; DISPLAY_5DIGIT ($D315)
; ==========================================================================
; Converts a 16-bit value in HL to 5 decimal digits and renders each digit
; using the HUD double-height font.
;
; Algorithm: Repeated subtraction. For each decimal place (10000, 1000, 100,
; 10, 1), count how many times the divisor fits into HL, render that count
; as a digit, then continue with the remainder.
;
; Entry: HL = 16-bit value to display (0-65535, but practically 0-99999)
;        SCORE_DISPLAY_POS already set to starting column/row
; Exit:  HL = 0 (fully consumed). All registers modified.
;        5 characters rendered at consecutive columns.
; ==========================================================================
DISPLAY_5DIGIT:	LD	IX,SCORE_DISPLAY_POS	; d315  dd 21 12 d3	]!.S	; IX points to the rendering position structure
	LD	DE,X2710	; d319  11 10 27	..'	; DE = 10000 ($2710) — ten-thousands digit divisor
	CALL	XD335		; d31c  cd 35 d3	M5S	; Extract & render ten-thousands digit, HL = remainder
	LD	DE,X03E8	; d31f  11 e8 03	.h.	; DE = 1000 ($03E8) — thousands digit divisor
	CALL	XD335		; d322  cd 35 d3	M5S	; Extract & render thousands digit, HL = remainder
	LD	DE,X0064	; d325  11 64 00	.d.	; DE = 100 ($0064) — hundreds digit divisor
	CALL	XD335		; d328  cd 35 d3	M5S	; Extract & render hundreds digit, HL = remainder
	LD	DE,X000A	; d32b  11 0a 00	...	; DE = 10 ($000A) — tens digit divisor
	CALL	XD335		; d32e  cd 35 d3	M5S	; Extract & render tens digit, HL = remainder (0-9)
	LD	A,L		; d331  7d		}	; A = ones digit (L holds the final remainder, 0-9)
	JP	HUD_CHAR_RENDER		; d332  c3 86 d3	C.S	; Render the ones digit and return (tail call)
;
; --- XD335: Extract and render one decimal digit ---
; Divides HL by DE using repeated subtraction. The quotient (0-9) is the
; digit value, which is passed to HUD_CHAR_RENDER. HL is left holding
; the remainder.
;
; Entry: HL = value to divide, DE = divisor (power of 10)
; Exit:  HL = remainder (HL mod DE). A = digit rendered.
;        One character rendered at current position, column advanced.
;
XD335:	LD	A,0FFH		; d335  3e ff		>.	; A = -1 (pre-decrement; first INC will make it 0)
XD337:	INC	A		; d337  3c		<	; A++ (count how many times DE fits into HL)
	SBC	HL,DE		; d338  ed 52		mR	; HL = HL - DE (subtract divisor; SBC uses carry from previous iteration)
	JR	NC,XD337	; d33a  30 fb		0{	; If no borrow (HL >= 0), keep subtracting → loop
	ADD	HL,DE		; d33c  19		.	; Overshot by one subtraction — add DE back to get remainder
	CALL	HUD_CHAR_RENDER		; d33d  cd 86 d3	M.S	; Render digit A (0-9) at current HUD position
	RET			; d340  c9		I	; Return; HL = remainder for next digit place
;


; ==========================================================================
; DISPLAY_2DIGIT ($D341)
; ==========================================================================
; Converts an 8-bit value in A to 2 decimal digits and renders them.
; Used for level number display (max level typically < 100).
;
; Entry: A = value to display (0-99)
;        SCORE_DISPLAY_POS already set by caller
; Exit:  All registers modified. 2 characters rendered.
; ==========================================================================
DISPLAY_2DIGIT:	LD	IX,SCORE_DISPLAY_POS	; d341  dd 21 12 d3	]!.S	; IX points to the rendering position structure
	LD	E,0AH		; d345  1e 0a		..	; E = 10 — divisor for tens digit
	CALL	XD360		; d347  cd 60 d3	M`S	; Extract tens digit: render quotient, A = remainder (0-9)
	CALL	HUD_CHAR_RENDER		; d34a  cd 86 d3	M.S	; Render the ones digit (remainder in A)
	RET			; d34d  c9		I	; Return to caller
;


; ==========================================================================
; DISPLAY_3DIGIT ($D34E)
; ==========================================================================
; Converts an 8-bit value in A to 3 decimal digits and renders them.
; Used for percentage display (0-100, though values > 100 are possible
; if both raw and fill percentages were somehow combined here — they aren't).
;
; Entry: A = value to display (0-255, practically 0-100 for percentage)
;        SCORE_DISPLAY_POS already set by caller
; Exit:  All registers modified. 3 characters rendered.
; ==========================================================================
DISPLAY_3DIGIT:	LD	IX,SCORE_DISPLAY_POS	; d34e  dd 21 12 d3	]!.S	; IX points to the rendering position structure
	LD	E,64H		; d352  1e 64		.d	; E = 100 ($64) — divisor for hundreds digit
	CALL	XD360		; d354  cd 60 d3	M`S	; Extract hundreds digit: render it, A = remainder (0-99)
	LD	E,0AH		; d357  1e 0a		..	; E = 10 — divisor for tens digit
	CALL	XD360		; d359  cd 60 d3	M`S	; Extract tens digit: render it, A = remainder (0-9)
	CALL	HUD_CHAR_RENDER		; d35c  cd 86 d3	M.S	; Render the ones digit (remainder in A)
	RET			; d35f  c9		I	; Return to caller
;
; --- XD360: 8-bit division by repeated subtraction, render quotient ---
; Divides A by E. Renders the quotient as a HUD character. Returns
; the remainder in A for the next digit extraction.
;
; Entry: A = dividend, E = divisor (10 or 100)
;        IX = SCORE_DISPLAY_POS
; Exit:  A = remainder (A mod E). Quotient digit rendered.
;        C = quotient (also used internally). Column advanced by 1.
;
XD360:	LD	C,0FFH		; d360  0e ff		..	; C = -1 (pre-decrement counter; first INC makes it 0)
XD362:	INC	C		; d362  0c		.	; C++ (count how many times E fits into A)
	SUB	E		; d363  93		.	; A = A - E (subtract divisor)
	JR	NC,XD362	; d364  30 fc		0|	; If no borrow (A >= 0), keep subtracting → loop
	ADD	A,E		; d366  83		.	; Overshot by one — add E back to get correct remainder
	PUSH	AF		; d367  f5		u	; Save remainder (A) and flags on stack
	LD	A,C		; d368  79		y	; A = quotient digit (the count of subtractions)
	CALL	HUD_CHAR_RENDER		; d369  cd 86 d3	M.S	; Render the quotient digit at current HUD position
	POP	AF		; d36c  f1		q	; Restore remainder to A
	RET			; d36d  c9		I	; Return; A = remainder for next digit place
;


; ==========================================================================
; HUD_STRING_RENDER ($D36E)
; ==========================================================================
; Renders a string of characters using the double-height HUD font.
; The string is stored in memory as:
;   Byte 0: column (starting X position, 0-31)
;   Byte 1: character row (0-23)
;   Byte 2+: character codes (HUD font indices), terminated by $FF
;
; The HUD font character set is limited (32 entries at $FA00):
;   0-9:   digit characters '0' through '9'
;   10:    space
;   11:    '%'
;   12-16: 'S','c','o','r','e'    (for "Score")
;   17-19: 'L','v','l'            (for "Level" — reuses 'e' from above)
;   20-21: 'i','s'                (for "Lives" — reuses 'L','v','e')
;   22-23: 'T','m'                (for "Time" — reuses 'i','e')
;
; Entry: HL = pointer to string data (column, row, chars..., $FF)
; Exit:  All registers modified. String rendered at specified position.
; Called from: menu_system.asm and trail_cursor_init.asm for static labels
; ==========================================================================
HUD_STRING_RENDER:	LD	IX,SCORE_DISPLAY_POS	; d36e  dd 21 12 d3	]!.S	; IX points to the rendering position structure
	LD	A,(HL)		; d372  7e		~	; A = first byte of string data (column number)
	LD	(IX+0),A	; d373  dd 77 00	]w.	; Store column in SCORE_DISPLAY_POS byte 0
	INC	HL		; d376  23		#	; Advance HL to next byte in string data
	LD	A,(HL)		; d377  7e		~	; A = second byte of string data (character row)
	LD	(IX+1),A	; d378  dd 77 01	]w.	; Store row in SCORE_DISPLAY_POS byte 1
	INC	HL		; d37b  23		#	; Advance HL to first character code
;
; --- Character rendering loop ---
;
XD37C:	LD	A,(HL)		; d37c  7e		~	; A = next character code from string
	INC	HL		; d37d  23		#	; Advance HL past this character (for next iteration)
	CP	0FFH		; d37e  fe ff		~.	; Is this the $FF terminator?
	RET	Z		; d380  c8		H	; If $FF, string is complete — return
	CALL	HUD_CHAR_RENDER		; d381  cd 86 d3	M.S	; Render this character at current position (auto-advances column)
	JR	XD37C		; d384  18 f6		.v	; Loop back for next character
;


; ==========================================================================
; HUD_CHAR_RENDER ($D386)
; ==========================================================================
; Renders a single character using the double-height HUD font.
;
; Each character in the HUD font ($FA00) is 8 bytes (8 pixel rows of 8 bits).
; This routine renders each font byte TWICE — once at pixel row N, and once
; at pixel row N+1 — creating a double-height (8x16 pixel) character.
;
; The rendering uses the ZX Spectrum's non-linear screen memory layout.
; Rather than computing addresses from scratch, it uses a pre-built row
; pointer table at $FC00. Each character row occupies 16 pixel rows on
; screen (since character height = 8 pixels, doubled = 16). The table
; entries for these 16 pixel rows are at $FC00 + row*32 (since each
; character row = 16 pixel rows, and each entry = 2 bytes: 16*2 = 32).
;
; The row pointer table entries have a structure of:
;   (IX+0): Low byte offset (column 0 address within the row)
;   (IX+1): High byte (page) of the screen address
;   Entries are spaced 4 bytes apart in the lookup (2 bytes per pixel row,
;   but we skip every other entry since we write the same byte to two
;   consecutive rows using INC H, which works because the ZX Spectrum
;   screen layout places consecutive pixel rows 256 bytes apart within
;   each character cell).
;
; The INC H trick: Within a single character cell on the ZX Spectrum,
; consecutive pixel rows differ only in the high byte of the address
; (incrementing by 1, i.e., +256 bytes). So after writing to row N at
; address H:L, writing to row N+1 is simply (H+1):L. This is why the
; loop advances the row pointer by 4 bytes (skipping the entry for the
; odd pixel row, since INC H handles it).
;
; Inverse video: If bit 7 of SCORE_DISPLAY_POS+2 ($D314) is set, the
; font data is complemented (CPL) before writing, producing white-on-black
; instead of black-on-white text.
;
; Entry: A = character code (HUD font index, 0-31)
;        IX = pointer to SCORE_DISPLAY_POS (column, row, flags)
; Exit:  Column (IX+0) incremented by 1 (cursor advances right)
;        All other registers restored (BC, DE, HL saved/restored via stack)
; ==========================================================================
HUD_CHAR_RENDER:	PUSH	BC		; d386  c5		E	; Save BC on stack (preserved for caller)
	PUSH	DE		; d387  d5		U	; Save DE on stack
	PUSH	HL		; d388  e5		e	; Save HL on stack
;
; --- Compute font data address ---
; Font address = $FA00 + character_code * 8
; Each character is 8 bytes in the font.
;
	LD	L,A		; d389  6f		o	; L = character code (0-31)
	LD	H,0		; d38a  26 00		&.	; HL = character code as 16-bit value
	ADD	HL,HL		; d38c  29		)	; HL = code * 2
	ADD	HL,HL		; d38d  29		)	; HL = code * 4
	ADD	HL,HL		; d38e  29		)	; HL = code * 8 (8 bytes per font character)
	LD	DE,HUD_FONT	; d38f  11 00 fa	..z	; DE = $FA00 (base address of HUD font data)
	ADD	HL,DE		; d392  19		.	; HL = $FA00 + code * 8 (address of this char's font data)
	EX	DE,HL		; d393  eb		k	; DE = font data pointer (source); HL is now free
;
; --- Compute row pointer table address for the target character row ---
; Row pointer base address = $FC00 + character_row * 16 * 2
; (16 pixel rows per double-height char, 2 bytes per table entry = *32)
; But since each font byte is written to 2 pixel rows (via INC H),
; we step through the table 4 bytes at a time (every other pixel row entry).
;
; The computation: row * 16 = (row << 4). Then the base address offset
; from $FC00 is row*32 = row*16*2. But the code does: row << 4 to get
; the low byte offset, then adds $FC as the high byte.
; If (IX+1)*16 overflows 8 bits, the carry propagates into H.
;
	LD	A,(IX+1)	; d394  dd 7e 01	]~.	; A = character row (0-23) from SCORE_DISPLAY_POS byte 1
	ADD	A,A		; d397  87		.	; A = row * 2
	ADD	A,A		; d398  87		.	; A = row * 4
	ADD	A,A		; d399  87		.	; A = row * 8
	ADD	A,A		; d39a  87		.	; A = row * 16 (low byte of row*16; may overflow/carry)
	LD	L,A		; d39b  6f		o	; L = (row * 16) & 0xFF — low byte of table offset
	LD	A,0FCH		; d39c  3e fc		>|	; A = $FC (high byte of row pointer table base)
	ADC	A,0		; d39e  ce 00		N.	; A = $FC + carry from row*16 overflow (handles rows >= 16)
	LD	H,A		; d3a0  67		g	; H = high byte of row pointer table address
				;				; HL now points to the row pointer table entry for the first
				;				; pixel row of this character's double-height cell
;
; --- Main rendering loop: 8 font bytes → 16 pixel rows ---
; For each of the 8 bytes in the font character:
;   1. Read screen row base address from row pointer table at (HL)
;   2. Add column offset to get exact screen byte address
;   3. Read one byte of font data from (DE)
;   4. Optionally complement it for inverse video
;   5. Write it to screen at computed address (first pixel row)
;   6. INC H to move to next pixel row (ZX Spectrum layout trick)
;   7. Write same byte again (second pixel row — double-height effect)
;   8. Advance row pointer by 4 bytes (skip 2 pixel rows in table)
;
	LD	B,8		; d3a1  06 08		..	; B = 8: loop counter (8 bytes per font character)
XD3A3:	LD	A,(IX+0)	; d3a3  dd 7e 00	]~.	; A = current column (0-31) from SCORE_DISPLAY_POS byte 0
	ADD	A,(HL)		; d3a6  86		.	; A = column + row_pointer_low_byte (screen address low byte)
	INC	HL		; d3a7  23		#	; Advance HL to high byte of this row pointer entry
	PUSH	HL		; d3a8  e5		e	; Save row pointer position (we'll need it for next iteration)
	LD	H,(HL)		; d3a9  66		f	; H = high byte of screen address (page)
	LD	L,A		; d3aa  6f		o	; L = low byte of screen address (column + offset)
				;				; HL = complete screen address for this pixel row + column
	LD	A,(DE)		; d3ab  1a		.	; A = font byte (8 pixels of character data)
	INC	DE		; d3ac  13		.	; Advance DE to next font byte
	BIT	7,(IX+2)	; d3ad  dd cb 02 7e	]K.~	; Test bit 7 of flags byte ($D314) — inverse video flag
	JR	Z,XD3B4		; d3b1  28 01		(.	; If bit 7 = 0 (normal video), skip the complement
	CPL			; d3b3  2f		/	; Complement A: flip all bits (white↔black for inverse)
XD3B4:	LD	(HL),A		; d3b4  77		w	; Write font byte to screen — first pixel row
	INC	H		; d3b5  24		$	; H++ → move to next pixel row (ZX Spectrum: +256 bytes = next line in cell)
	LD	(HL),A		; d3b6  77		w	; Write same font byte again — second pixel row (double-height)
	POP	HL		; d3b7  e1		a	; Restore row pointer table position
	INC	HL		; d3b8  23		#	; Skip past high byte of current entry
	INC	HL		; d3b9  23		#	; Skip low byte of next pixel row entry (handled by INC H)
	INC	HL		; d3ba  23		#	; Skip high byte of next pixel row entry
				;				; HL now points to the row pointer entry 2 pixel rows ahead
				;				; (we advance by 4 bytes total: 1 from before PUSH + 3 INC here)
	DJNZ	XD3A3		; d3bb  10 e6		.f	; Decrement B; if not zero, loop for next font byte
;
; --- Advance cursor column ---
	INC	(IX+0)		; d3bd  dd 34 00	]4.	; Column++ (advance cursor to next character position)
;
; --- Restore registers and return ---
	POP	HL		; d3c0  e1		a	; Restore HL (caller's value)
	POP	DE		; d3c1  d1		Q	; Restore DE
	POP	BC		; d3c2  c1		A	; Restore BC
	RET			; d3c3  c9		I	; Return to caller
;
