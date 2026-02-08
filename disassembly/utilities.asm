; ==========================================================================
; INPUT, ATTRIBUTES & SCREEN UTILITIES ($BA68-$C03D)
; ==========================================================================
;
; This file contains low-level utility routines used throughout the game.
; It is the largest utility module, covering keyboard input, attribute
; manipulation, string rendering, number display, sound effects, timer bar
; management, menu cursor handling, and bordered rectangle overlays.
;
; --------------------------------------------------------------------------
; KEYBOARD INPUT
; --------------------------------------------------------------------------
;
; READ_KEYBOARD ($BA68):
;   Reads up to 5 configurable keyboard mappings from a lookup table.
;   Each mapping specifies a ZX Spectrum keyboard half-row port address
;   and a bit position within that row. The routine reads 5 inputs and
;   encodes them as a 5-bit value returned in register C:
;     bit 0 = Fire (Space bar)
;     bit 1 = Down
;     bit 2 = Up
;     bit 3 = Right
;     bit 4 = Left
;   The keyboard mapping table at $BACE stores 5 entries, each encoding
;   the port address and bit offset. The port lookup table at $BABC
;   holds 8 ZX Spectrum keyboard port addresses ($FEFE-$7FFE).
;   Called from: PLAYER_MOVEMENT ($C7B5), main loop, menu cursor handler.
;
; CHECK_FIRE_KEYS ($BA9D):
;   Quick check for fire key (Space or Caps Shift). Does NOT use the
;   configurable mapping. Reads port $7FFE (Space) and $FEFE (Caps Shift)
;   directly. Returns: Carry set = Space pressed; Carry clear, then
;   returns with bit 0 from Caps Shift row.
;   Called from: menu system (wait for key).
;
; WAIT_FIRE_RELEASE ($BAA9):
;   Polls keyboard in a loop until fire (bit 0 of C) is NOT pressed.
;   Used to debounce after detecting a fire press.
;
; WAIT_FIRE_PRESS ($BAB1):
;   Calls WAIT_FIRE_RELEASE first, then polls until fire IS pressed.
;   Used for "press fire to continue" prompts.
;
; --------------------------------------------------------------------------
; KEYBOARD PORT TABLE ($BABC)
; --------------------------------------------------------------------------
;   8 entries, each a 16-bit port address for IN A,(C):
;     $BABC: $FEFE (row: Caps-V)    $BABE: $FDFE (row: A-G)
;     $BAC0: $FBFE (row: Q-T)       $BAC2: $F7FE (row: 1-5)
;     $BAC4: $EFFE (row: 0-6)       $BAC6: $DFFE (row: P-Y)
;     $BAC8: $BFFE (row: Enter-H)   $BACA: $7FFE (row: Space-B)
;
; --------------------------------------------------------------------------
; KEY MAPPING TABLE ($BACC-$BAE6)
; --------------------------------------------------------------------------
;   5 entries at $BACE, each byte encodes:
;     bits 4-1: index into port table (x2 for word offset)
;     bits 2-0: bit position within the port's 5-bit result
;   Default: $29=Fire(Space), $28=Down(Sym Shift?), $11=Up, $1A=Right, $38=Left
;   A second copy at $BAE2 stores the same defaults for reset.
;
; --------------------------------------------------------------------------
; ATTRIBUTE ROUTINES
; --------------------------------------------------------------------------
;
; COMPUTE_ATTR_ADDR ($BAE7):
;   Converts character row/column to a ZX Spectrum attribute address.
;   Input:  B = row (0-23), C = column (0-31)
;   Output: HL = $5800 + B*32 + C
;   Method: A = B*8; HL = A * 256 where H=$16; HL <<= 2 gives row*32 base;
;           then add C. Preserves B.
;   Called from: FILL_ATTR_RECT, DRAW_BORDERED_RECT, and many others.
;
; FILL_ATTR_RECT ($BAF6):
;   Fills a rectangular region of the attribute area with a single byte.
;   Input:  B = start row, C = start column, D = height (rows),
;           E = width (columns), A = attribute byte value
;   Uses COMPUTE_ATTR_ADDR to find the start address, then iterates
;   D rows x E columns writing A to each cell. Advances 32 bytes per row.
;   Called from: LEVEL_INIT (field color), SET_BRIGHT/RESET_BRIGHT area fills,
;   DRAW_BORDERED_RECT (overlay color fill).
;
; --------------------------------------------------------------------------
; SOUND EFFECTS
; --------------------------------------------------------------------------
;
; PLAY_SOUND ($BB11-$BB3A):
;   Generates sound effects via the ZX Spectrum beeper (port $FE, bit 4).
;   Entry point $BB11 sets default duration/pitch parameters.
;   The inner loop at $BB28 toggles the speaker bit and uses PRNG-derived
;   random delays for noise-like effects (explosion/death sounds).
;   Gated by bit 0 of $B0ED (sound enable flag).
;   Called from: death handler, spark kill, various game events.
;
; SKIP_STRINGS ($BB3B):
;   Skips A null-terminated strings in memory starting at HL.
;   Advances HL past A complete strings (each terminated by $00).
;   Used by menu system to index into string arrays.
;
; FRAME_DELAY ($BB48):
;   Waits for A video frames by executing A HALT instructions.
;   Each HALT waits for the next interrupt (1/50th second on PAL).
;   Input:  A = number of frames to wait
;   Called from: level complete animation, death sequence, menu transitions.
;
; --------------------------------------------------------------------------
; INTERRUPT SERVICE ROUTINE SUPPORT ($BB4F-$BB68)
; --------------------------------------------------------------------------
;
; $BB4F: ISR_FLAGS byte — bit 7 = "waiting for ISR" flag
; $BB50: ISR_COUNTER — incremented each interrupt, used for timing
; $BB51: ISR handler — saves all registers, clears bit 7 of ISR_FLAGS,
;        increments ISR_COUNTER, restores registers, returns.
;        Called from the Z80 interrupt vector during HALT.
;
; --------------------------------------------------------------------------
; TIMER BAR ($BB69-$BE40)
; --------------------------------------------------------------------------
;
; BB69: INIT_TIMER_BAR — initializes the timer bar display. Sets the
;       "waiting" flag, waits for ISR, reads timer bar state, computes
;       screen position, and draws the initial bar segments.
;
; $BBD8: NUM_TO_DIGITS — converts a 16-bit number in HL to 5 decimal
;        digits, rendering each via RENDER_CHAR. Used for score display.
;        Divides successively by 10000, 1000, 100, 10, remainder.
;
; $BBFB: DIV_HL_DE — divides HL by DE, returns quotient+$80 in A,
;        remainder in HL. The +$80 offset maps digits to the HUD font
;        character set (where '0' = $80).
;
; --------------------------------------------------------------------------
; COLOR PROCESSING
; --------------------------------------------------------------------------
;
; PROCESS_ATTR_COLOR ($BC07):
;   Adapts attribute colors for monochrome TV mode. If bit 7 of $B0EE
;   is set (color TV), returns A unchanged. Otherwise remaps the INK
;   color: if INK >= 2, sets INK to 7 (white); if INK < 2, sets INK
;   to 0 (black). PAPER is set to the inverse. Preserves BRIGHT/FLASH.
;   Called from: STRING_RENDERER ($BC4B), DRAW_BORDERED_RECT ($BF70).
;
; --------------------------------------------------------------------------
; STRING RENDERING
; --------------------------------------------------------------------------
;
; STRING_RENDERER ($BC26):
;   Renders control-code strings to the screen. Reads bytes from (HL)
;   and dispatches based on value:
;     $00        = end of string, return
;     $08        = backspace (X -= 8 pixels)
;     $09        = tab (X += 8 pixels)
;     $0A        = line feed (Y += 1 char row)
;     $0B        = reverse line feed (Y -= 1 char row)
;     $1C xx yy  = repeat character yy xx times
;     $1D        = pad to next 8-pixel boundary with spaces
;     $1E xx     = set attribute color to xx (via PROCESS_ATTR_COLOR)
;     $1F xx yy  = set cursor position: X=xx (pixel), Y=yy (char row)
;     $20-$FF    = printable ASCII, rendered via RENDER_CHAR
;   Cursor state stored at IX ($BCA9): IX+0=X pixel, IX+1=Y row, IX+2=attr
;   Called from: menu system, game over, level complete, HUD setup.
;
; RENDER_CHAR ($BCB5):
;   Renders a single character to the screen bitmap and attribute area.
;   Uses the game font at $C0D5 (character widths) and pixel data table.
;   Handles proportional-width rendering: each character has a width of
;   1-8 pixels. After rendering, advances the cursor X position.
;   The rendering uses mask-and-OR compositing to preserve surrounding pixels.
;
; --------------------------------------------------------------------------
; SCREEN CHARACTER DRAWING ($BD65-$BD9B)
; --------------------------------------------------------------------------
;
; XOR_DRAW_CHAR ($BD65):
;   Draws a character cell using XOR mode at a given screen position.
;   Input: D=Y char row, E=X column offset, A=width, C=width
;   Uses ROW_PTR_TABLE ($FC00) to convert Y to screen address.
;   XORs pixel data with existing screen content (used for cursor blink).
;
; --------------------------------------------------------------------------
; TIMER BAR MANAGEMENT ($BD9C-$BF17)
; --------------------------------------------------------------------------
;
; PROCESS_TIMER_SEGMENTS ($BD9C):
;   Iterates through the timer bar segment table (pointed to by $BDF4).
;   Each segment is 3 bytes: X position, Y row, width.
;   Bit 7 of byte 0: 0=draw segment, 1=erase segment.
;   Compares each segment against the current cursor position (B,C) and
;   toggles segments on/off as the timer bar shrinks.
;
; TIMER_BAR_STATE ($BDEE-$BDF6):
;   $BDEE-$BDEF: Current timer bar X,Y position (16-bit)
;   $BDF0: Timer bar direction/state
;   $BDF2: Previous input state (for repeat detection)
;   $BDF3: Repeat counter (accelerates after held frames)
;   $BDF4-$BDF5: Pointer to timer segment table
;   $BDF6: Selected segment index
;
; DRAW_TIMER_ROW ($BDF7):
;   Draws/updates one row of the timer bar on screen. Reads position
;   from $BDEE, computes screen address via ROW_PTR_TABLE, copies
;   pixel rows from the timer bar pattern data at $BBB7.
;
; RESTORE_TIMER_ROW ($BE41):
;   Reverses DRAW_TIMER_ROW — restores screen content behind timer bar.
;   Used when timer bar shrinks (each tick removes one segment).
;
; --------------------------------------------------------------------------
; MENU CURSOR HANDLING ($BEBA-$BF60)
; --------------------------------------------------------------------------
;
; MENU_CURSOR_MOVE ($BEBA):
;   Reads keyboard input and moves a menu cursor/selection box.
;   Movement speed accelerates: 1px for first 12 frames of holding,
;   2px for frames 12-16, 3px for 16-20, 4px beyond 20 frames.
;   Clamps position to valid range (X: 0-$FC, Y: 0-$BE).
;   Stores new position at $BDF0.
;
; MENU_INIT ($BF18):
;   Initializes menu state: stores segment table pointer, computes
;   cursor position, draws initial segments, waits for fire release.
;
; MENU_FIRE_HANDLER ($BF3A):
;   Checks for fire button press. If fire pressed with repeat counter
;   indicating a clean press (not held), searches the segment table
;   for the segment under the cursor and returns its index.
;
; MENU_CLEANUP ($BF61):
;   Resets menu display: redraws timer bar in normal state, restores
;   segments to default visibility, plays cleanup sound.
;
; --------------------------------------------------------------------------
; BORDERED RECTANGLE OVERLAYS ($BF70-$C03D)
; --------------------------------------------------------------------------
;
; DRAW_BORDERED_RECT ($BF70):
;   Draws a popup rectangle with a 1-pixel black border and solid fill.
;   Saves the original bitmap and attribute data to a buffer (pointed
;   to by $C0BD) so it can be restored later. The rectangle is drawn
;   row by row: first row all $FF (solid black line), middle rows have
;   $80 left edge + $00 interior + $01 right edge, last row all $FF.
;   Attributes are filled with the specified color byte.
;   Input:  A = attribute color, B = start column (pixel/8),
;           C = start row (char row), D = height, E = width
;   State:  $C0B7 = overlay count, $C0B8 = color, $C0B9-$C0BA = row/col,
;           $C0BB-$C0BC = height/width, $C0BD-$C0BE = save buffer pointer
;   Called from: LEVEL_COMPLETE ($C55D), GAME_OVER ($C674),
;               OUT_OF_TIME ($C6C9), CHECK_PAUSE ($C61B).
;
; RESTORE_RECT ($C03E — not in this file, defined elsewhere):
;   Reverses DRAW_BORDERED_RECT by restoring saved bitmap/attr data.
;   Called after dismissing popups.
;

;

; ==========================================================================
; READ_KEYBOARD ($BA68)
; ==========================================================================
; Reads 5 configurable key inputs and encodes them into register C as a
; 5-bit field: bit4=Left, bit3=Right, bit2=Up, bit1=Down, bit0=Fire.
;
; The mapping table at $BACE has 5 bytes. Each byte encodes:
;   bits 4-1 → index into PORT_TABLE ($BABC), giving the keyboard port
;   bits 2-0 → bit position within that port's 5 data bits
;
; For each of the 5 entries, the routine reads the ZX Spectrum keyboard
; port via IN A,(C), isolates the relevant bit, and shifts it into C.
;
; On entry: (no parameters)
; On exit:  C = 5-bit input state (bit 0=fire, 1=down, 2=up, 3=right, 4=left)
;           B = 0
; Corrupts: AF, DE, HL
; ==========================================================================
READ_KEYBOARD:	LD	HL,XBACE	; ba68  21 ce ba	HL = pointer to key mapping table (5 entries)
	LD	BC,X0500	; ba6b  01 00 05	B = 5 (loop counter), C = 0 (result accumulator)
XBA6E:	LD	A,(HL)		; ba6e  7e		A = current mapping byte from table
	RRA			; ba6f  1f		Shift right once: bits 4-1 → bits 3-0
	RRA			; ba70  1f		Shift right again: now bits 4-1 are in bits 2-0 (x2 offset)
	AND	1EH		; ba71  e6 1e		Mask to get port table index (even offset, 0-14)
	LD	E,A		; ba73  5f		DE = port table offset (D will be set to 0)
	LD	D,0		; ba74  16 00		Clear D for 16-bit index
	LD	A,(HL)		; ba76  7e		Reload mapping byte (need bit position from bits 2-0)
	INC	HL		; ba77  23		Advance to next mapping entry
	PUSH	HL		; ba78  e5		Save mapping table pointer
	LD	HL,XBABC	; ba79  21 bc ba	HL = PORT_TABLE base address
	ADD	HL,DE		; ba7c  19		HL = address of port entry for this key
	LD	D,A		; ba7d  57		D = original mapping byte (save for bit position extraction)
	PUSH	BC		; ba7e  c5		Save loop counter (B) and result accumulator (C)
	LD	C,(HL)		; ba7f  4e		C = low byte of port address (always $FE for ZX keyboard)
	INC	HL		; ba80  23		Advance to high byte
	LD	B,(HL)		; ba81  46		B = high byte of port address (row select: $FE-$7F)
	IN	A,(C)		; ba82  ed 78		Read keyboard port — A = 5-bit key state (0=pressed)
	INC	B		; ba84  04		Test if B was $FF (Kempston joystick port $FF)
	DEC	B		; ba85  05		Sets Z flag if B was $FF (INC then DEC is a Z-flag test)
	JR	Z,XBA89		; ba86  28 01		If Kempston port ($FF): bits are active-HIGH, skip CPL
	CPL			; ba88  2f		For keyboard ports: invert (0=pressed → 1=pressed)
XBA89:	LD	E,A		; ba89  5f		E = inverted port data (1=pressed)
	POP	BC		; ba8a  c1		Restore loop counter and result
	POP	HL		; ba8b  e1		Restore mapping table pointer
	LD	A,D		; ba8c  7a		A = original mapping byte
	AND	7		; ba8d  e6 07		Isolate bit position (0-7) within the port byte
	JR	Z,XBA96		; ba8f  28 05		If bit position = 0, skip shifting
XBA91:	RR	E		; ba91  cb 1b		Shift E right to move target bit toward bit 0
	DEC	A		; ba93  3d		Decrement shift counter
	JR	NZ,XBA91	; ba94  20 fb		Loop until target bit is in bit 0 position
XBA96:	RR	E		; ba96  cb 1b		Shift target bit out of E into carry flag
	RL	C		; ba98  cb 11		Rotate carry (key state) into C from the right
	DJNZ	XBA6E		; ba9a  10 d2		Decrement B (entry counter), loop for next key
	RET			; ba9c  c9		Return: C = 5-bit input state
;
; ==========================================================================
; CHECK_FIRE_KEYS ($BA9D)
; ==========================================================================
; Quick-check for fire keys without full keyboard scan. Reads Space ($7FFE)
; and Caps Shift ($FEFE) directly. Does not use configurable key mapping.
; On exit: Carry = Space pressed (returns early). Otherwise A bit 0 = Caps.
; ==========================================================================
XBA9D:	LD	A,7FH		; ba9d  3e 7f		A = $7F: select keyboard row Space-B (port $7FFE)
	IN	A,(0FEH)	; ba9f  db fe		Read keyboard row — bit 0 = Space key (0=pressed)
	RRA			; baa1  1f		Rotate Space bit into carry (inverted: carry=0 means pressed)
	RET	C		; baa2  d8		If carry set (Space NOT pressed in raw read)... wait, ZX keys are active-low
				;                       Actually: bit0=0 when pressed, RRA puts it in carry, carry=0=pressed
				;                       RET C returns if Space is NOT pressed (carry=1 = key up)
	LD	A,0FEH		; baa3  3e fe		A = $FE: select keyboard row Caps Shift-V (port $FEFE)
	IN	A,(0FEH)	; baa5  db fe		Read keyboard row — bit 0 = Caps Shift (0=pressed)
	RRA			; baa7  1f		Rotate Caps Shift bit into carry
	RET			; baa8  c9		Return: carry indicates Caps Shift state
;
; ==========================================================================
; WAIT_FIRE_RELEASE ($BAA9)
; ==========================================================================
; Blocks until the fire button (bit 0 of C) is released.
; Used for debouncing after a fire press is detected.
; ==========================================================================
XBAA9:	CALL	READ_KEYBOARD		; baa9  cd 68 ba	Read keyboard → C = input bits
	BIT	0,C		; baac  cb 41		Test fire bit (bit 0)
	JR	NZ,XBAA9	; baae  20 f9		If fire still pressed (bit 0 = 1), keep waiting
	RET			; bab0  c9		Fire released, return
;
; ==========================================================================
; WAIT_FIRE_PRESS ($BAB1)
; ==========================================================================
; First waits for fire to be released (debounce), then waits for a new press.
; Used for "press fire to continue" prompts in menus and game over.
; ==========================================================================
XBAB1:	CALL	XBAA9		; bab1  cd a9 ba	First wait for fire to be released (debounce)
XBAB4:	CALL	READ_KEYBOARD		; bab4  cd 68 ba	Read keyboard → C = input bits
	BIT	0,C		; bab7  cb 41		Test fire bit (bit 0)
	JR	Z,XBAB4		; bab9  28 f9		If fire NOT pressed (bit 0 = 0), keep waiting
	RET			; babb  c9		Fire pressed, return
;
; ==========================================================================
; KEYBOARD PORT TABLE ($BABC) — 8 ZX Spectrum keyboard half-row ports
; ==========================================================================
; Each entry is a 16-bit port address used with IN A,(C).
; Low byte is always $FE (keyboard ULA). High byte selects the row.
; ZX Spectrum keyboard is arranged as 8 half-rows of 5 keys each.
; ==========================================================================
XBABC:	DW	XF7FE		; babc   fe f7      Port $F7FE: keys 1-5 (row 3)
	DW	XFBFE		; babe   fe fb      Port $FBFE: keys Q-T (row 2)
	DW	XFDFE		; bac0   fe fd      Port $FDFE: keys A-G (row 1)
	DW	XFEFE		; bac2   fe fe      Port $FEFE: keys Caps-V (row 0)
	DW	XEFFE		; bac4   fe ef      Port $EFFE: keys 0-6 (row 4)
	DW	XDFFE		; bac6   fe df      Port $DFFE: keys P-Y (row 5)
	DW	XBFFE		; bac8   fe bf      Port $BFFE: keys Enter-H (row 6)
	DW	X7FFE		; baca   fe 7f      Port $7FFE: keys Space-B (row 7)
;
; ==========================================================================
; KEY MAPPING DATA ($BACC-$BAE6)
; ==========================================================================
; $BACC-$BACD: 2-byte prefix (control/format data)
; $BACE-$BAD2: Active key mapping (5 bytes, one per input direction/fire)
;   Each byte encodes: bits 4-1 = port table index, bits 2-0 = bit position
;   Default: Fire=Space($29), Down($28), Up($11), Right($1A), Left($38)
; $BAD3-$BAE1: Menu system string/control data
; $BAE2-$BAE6: Default key mapping backup (same 5 bytes, used for reset)
; ==========================================================================
	DB	1FH,0					; bacc  Control prefix bytes (used by string renderer)
XBACE:	DB	29H					; bace  Fire: port 7FFE bit 0 = Space key
XBACF:	DB	28H,11H,1AH				; bacf  Down($28), Up($11), Right($1A)
	DB	'8'					; bad2  Left: $38
Xbad3:	DB	'A@CBD'					; bad3  Menu string data (ASCII characters)
	DB	4					; bad8  Control byte
	DB	'"#$ $#!'				; bad9  Menu string data
	DB	22H,20H					; bae0  Control bytes
XBAE2:	DB	29H,28H,11H,1AH,38H			; bae2  Default key mapping backup: Fire,Down,Up,Right,Left
;

; ==========================================================================
; COMPUTE_ATTR_ADDR ($BAE7)
; ==========================================================================
; Converts a character row and column to a ZX Spectrum attribute address.
; The attribute area is at $5800-$5AFF, with 32 bytes per row (24 rows).
;
; Math: address = $5800 + row*32 + col
; Implementation: L = row*8; H = $16; HL <<= 2 gives $5800 + row*32;
;                 then add column C.
;
; On entry: B = row (0-23), C = column (0-31)
; On exit:  HL = attribute address ($5800 + B*32 + C)
;           B preserved (saved and restored)
; Corrupts: AF
; ==========================================================================
COMPUTE_ATTR_ADDR:	LD	A,B		; bae7  78		A = row number
	ADD	A,A		; bae8  87		A = row * 2
	ADD	A,A		; bae9  87		A = row * 4
	ADD	A,A		; baea  87		A = row * 8
	LD	L,A		; baeb  6f		L = row * 8
	LD	H,16H		; baec  26 16		H = $16 → HL = $1600 + row*8
	ADD	HL,HL		; baee  29		HL = $2C00 + row*16
	ADD	HL,HL		; baef  29		HL = $5800 + row*32 — this is the attribute row base!
	LD	A,B		; baf0  78		Save original row value
	LD	B,0		; baf1  06 00		B = 0 so BC = column only
	ADD	HL,BC		; baf3  09		HL = $5800 + row*32 + col — final attribute address
	LD	B,A		; baf4  47		Restore B to original row value
	RET			; baf5  c9		Return with HL = attribute address
;

; ==========================================================================
; FILL_ATTR_RECT ($BAF6)
; ==========================================================================
; Fills a rectangular region of the ZX Spectrum attribute area with a
; single attribute byte. Used to set field colors, popup backgrounds, etc.
;
; On entry: B = start row, C = start column, D = height (rows),
;           E = width (columns), A = attribute byte to fill
; On exit:  D = 0, HL past end of last row
; Corrupts: AF, BC, HL
; ==========================================================================
FILL_ATTR_RECT:	EX	AF,AF'		; baf6  08		Save attribute byte in A' (shadow register)
	CALL	COMPUTE_ATTR_ADDR		; baf7  cd e7 ba	HL = attribute address for (B, C)
	EX	AF,AF'		; bafa  08		Restore attribute byte from A'
	LD	C,A		; bafb  4f		C = attribute byte (save for inner loop)
XBAFC:	PUSH	HL		; bafc  e5		Save row start address (restored after each row)
	LD	B,E		; bafd  43		B = width (column counter for this row)
	LD	A,C		; bafe  79		A = attribute byte to write
XBAFF:	LD	(HL),A		; baff  77		Write attribute byte to current cell
	INC	L		; bb00  2c		Advance to next column (INC L is safe within a 256-byte aligned row)
	DJNZ	XBAFF		; bb01  10 fc		Loop for all columns in this row
	POP	HL		; bb03  e1		Restore row start address
	LD	A,20H		; bb04  3e 20		A = 32 (bytes per attribute row)
	ADD	A,L		; bb06  85		Add 32 to L to move to next row
	LD	L,A		; bb07  6f		Update L
	LD	A,H		; bb08  7c		Handle carry into H (if L wrapped past 255)
	ADC	A,0		; bb09  ce 00		Add carry to H
	LD	H,A		; bb0b  67		HL now points to the same column in the next row
	DEC	D		; bb0c  15		Decrement row counter
	JP	NZ,XBAFC	; bb0d  c2 fc ba	Loop for all rows
	RET			; bb10  c9		Return
;
; ==========================================================================
; PLAY_SOUND ($BB11)
; ==========================================================================
; Generates beeper sound effects. Entry point $BB11 sets default params
; (D=10 iterations, E=5 base pitch). Other entry points at $BB16/$BB1E
; provide alternate parameters for different sound effects.
;
; The sound loop toggles the speaker bit (bit 4 of port $FE) and uses
; PRNG for random delay, creating noise-like effects for explosions/deaths.
; Gated by bit 0 of $B0ED — if sound is disabled, returns immediately.
;
; On entry (via $BB20): D = duration (iterations), E = base pitch offset
;          A loaded from $B0EB = initial speaker/border state
; Corrupts: AF, BC, DE
; ==========================================================================
XBB11:	LD	DE,X0A05	; bb11  11 05 0a	D = 10 (duration), E = 5 (base pitch)
	JR	XBB20		; bb14  18 0a		Jump to sound generation
;
; --- Alternate sound parameter entry points ---
	DB	11H,8,60H,18H,5,11H,7FH,40H		; bb16  LD DE,$6008; JR +5; LD DE,$407F
	DB	18H,0					; bb1e  JR +0 (fall through)
;
XBB20:	LD	A,(XB0ED)	; bb20  3a ed b0	A = sound/config flags byte
	RRA			; bb23  1f		Rotate bit 0 (sound enable) into carry
	RET	NC		; bb24  d0		If sound disabled (bit 0 = 0), return silently
	LD	A,(XB0EB)	; bb25  3a eb b0	A = current border color / speaker state
XBB28:	OUT	(0FEH),A	; bb28  d3 fe		Output to ULA port: sets border color AND speaker
	XOR	10H		; bb2a  ee 10		Toggle bit 4 (speaker) — creates the sound wave
	EX	AF,AF'		; bb2c  08		Save speaker state in A'
	CALL	PRNG		; bb2d  cd e4 d3	Get random number for variable delay → A = 0-255
	AND	7FH		; bb30  e6 7f		Mask to 0-127 range
	ADD	A,E		; bb32  83		Add base pitch offset → A = random delay value
	LD	B,A		; bb33  47		B = delay counter
XBB34:	DJNZ	XBB34		; bb34  10 fe		Busy-wait loop: delay B cycles (controls pitch)
	EX	AF,AF'		; bb36  08		Restore speaker state from A'
	DEC	D		; bb37  15		Decrement duration counter
	JR	NZ,XBB28	; bb38  20 ee		Loop until duration exhausted
	RET			; bb3a  c9		Return — sound complete
;
; ==========================================================================
; SKIP_STRINGS ($BB3B)
; ==========================================================================
; Skips A null-terminated strings starting at HL. Advances HL past all
; of them. Used by menu system to index into arrays of strings.
;
; On entry: A = number of strings to skip, HL = start of string data
; On exit:  HL = pointer to the byte after the A-th null terminator
;           A = 0
; Corrupts: AF
; ==========================================================================
XBB3B:	OR	A		; bb3b  b7		Test A — is count zero?
	RET	Z		; bb3c  c8		If zero strings to skip, return immediately
	PUSH	BC		; bb3d  c5		Save BC
	LD	B,A		; bb3e  47		B = number of strings to skip
XBB3F:	LD	A,(HL)		; bb3f  7e		A = current byte from string
	INC	HL		; bb40  23		Advance past this byte
	OR	A		; bb41  b7		Test if byte is $00 (null terminator)
	JR	NZ,XBB3F	; bb42  20 fb		If not null, keep scanning this string
	DJNZ	XBB3F		; bb44  10 f9		Null found: decrement string counter, continue if more
	POP	BC		; bb46  c1		Restore BC
	RET			; bb47  c9		Return — HL points past the last null terminator
;

; ==========================================================================
; FRAME_DELAY ($BB48)
; ==========================================================================
; Waits for A video frames by executing HALT instructions. Each HALT
; suspends the CPU until the next maskable interrupt, which fires once
; per frame (50 Hz on PAL ZX Spectrum). So FRAME_DELAY(2) = 40ms.
;
; On entry: A = number of frames to wait (1-255)
; On exit:  A unchanged (but B clobbered inside)
; Corrupts: B (restored via PUSH/POP BC)
; ==========================================================================
FRAME_DELAY:	PUSH	BC		; bb48  c5		Save BC
	LD	B,A		; bb49  47		B = frame count
XBB4A:	HALT			; bb4a  76		Wait for next interrupt (1/50th second)
;
	DJNZ	XBB4A		; bb4b  10 fd		Decrement B, loop if frames remain
	POP	BC		; bb4d  c1		Restore BC
	RET			; bb4e  c9		Return after waiting A frames
;
; ==========================================================================
; INTERRUPT SERVICE ROUTINE SUPPORT ($BB4F-$BB68)
; ==========================================================================
; $BB4F (ISR_FLAGS): bit 7 = "waiting for ISR" flag. Set by code that
;   needs to synchronize with the frame interrupt. The ISR clears it.
; $BB50 (ISR_COUNTER): incremented each interrupt. Used for frame timing.
;
; $BB51 (ISR_HANDLER): The actual interrupt service routine. Called by Z80
;   hardware on each VBLANK interrupt (50Hz). Saves all registers, clears
;   the "waiting" flag, increments the frame counter, then restores.
; ==========================================================================
XBB4F:	DB	1					; bb4f  ISR_FLAGS: bit 7 = waiting flag (currently $01 = not waiting)
XBB50:	DB	0F8H					; bb50  ISR_COUNTER: frame counter (current value $F8)
;
; --- Interrupt Service Routine ---
XBB51:	PUSH	AF		; bb51  f5		Save all registers (ISR must not corrupt anything)
	PUSH	BC		; bb52  c5
	PUSH	DE		; bb53  d5
	PUSH	HL		; bb54  e5
	PUSH	IX		; bb55  dd e5
	DI			; bb57  f3		Disable interrupts during ISR (prevent re-entry)
	LD	HL,XBB4F	; bb58  21 4f bb	HL = address of ISR_FLAGS
	RES	7,(HL)		; bb5b  cb be		Clear bit 7: signal "ISR has fired" to waiting code
	LD	HL,XBB50	; bb5d  21 50 bb	HL = address of ISR_COUNTER
	INC	(HL)		; bb60  34		Increment frame counter (wraps 0-255)
	POP	IX		; bb61  dd e1		Restore all registers
	POP	HL		; bb63  e1
	POP	DE		; bb64  d1
	POP	BC		; bb65  c1
	POP	AF		; bb66  f1
	EI			; bb67  fb		Re-enable interrupts
	RET			; bb68  c9		Return from ISR
;
; ==========================================================================
; INIT_TIMER_BAR ($BB69)
; ==========================================================================
; Initializes the timer bar display. Synchronizes with the ISR, reads
; the timer position, converts pixel coordinates to character cell
; coordinates (dividing by 8), and draws the initial bar.
;
; On exit: Timer bar drawn on screen, state variables initialized
; Corrupts: AF, BC, DE, HL, IX
; ==========================================================================
XBB69:	LD	HL,XBB4F	; bb69  21 4f bb	HL = ISR_FLAGS address
	SET	7,(HL)		; bb6c  cb fe		Set bit 7: "waiting for ISR"
XBB6E:	BIT	7,(HL)		; bb6e  cb 7e		Test bit 7: has ISR fired yet?
	JR	NZ,XBB6E	; bb70  20 fc		Spin-wait until ISR clears the flag
	LD	C,80H		; bb72  0e 80		C = $80 (flag: draw mode for timer row)
	CALL	XBDF7		; bb74  cd f7 bd	Draw current timer bar row to screen
	LD	BC,(XBDF0)	; bb77  ed 4b f0 bd	BC = timer bar pixel position (B=Y, C=X)
	LD	(XBDEE),BC	; bb7b  ed 43 ee bd	Copy to working position variable
	SRL	B		; bb7f  cb 38		B >>= 1 (divide Y by 2)
	SRL	B		; bb81  cb 38		B >>= 1 (divide Y by 4)
	SRL	B		; bb83  cb 38		B >>= 1 (divide Y by 8) → B = char row
	SRL	C		; bb85  cb 39		C >>= 1 (divide X by 2)
	SRL	C		; bb87  cb 39		C >>= 1 (divide X by 4)
	SRL	C		; bb89  cb 39		C >>= 1 (divide X by 8) → C = char column
	CALL	XBD9C		; bb8b  cd 9c bd	Process timer segments at current position
	LD	C,0		; bb8e  0e 00		C = 0 (flag: erase mode for timer row)
	CALL	XBDF7		; bb90  cd f7 bd	Erase old timer bar row from screen
	CALL	XBE41		; bb93  cd 41 be	Restore screen content behind erased bar
	RET			; bb96  c9		Return
;
; ==========================================================================
; TIMER BAR PIXEL PATTERNS ($BB97-$BBB7)
; ==========================================================================
; Bitmap data for drawing the timer bar segments on screen. These are
; pixel row patterns used by DRAW_TIMER_ROW ($BDF7) and RESTORE_TIMER_ROW
; ($BE41). The timer bar is 3 bytes wide and up to 8 pixel rows tall.
; ==========================================================================
	ORG	0BB99H
;
	DB	3FH,0,1FH,0,0FH,80H,6			; bb99  Timer bar pixel patterns (right-edge shapes)
	DW	X0060		; bba0   60 00
;
	DB	18H,0,6,0				; bba2  Timer bar patterns continued
;
	ORG	0BBA8H
;
	DB	7FH,80H,7FH				; bba8  Timer bar segment patterns
	DW	X7FC0		; bbab   c0 7f
;
	DB	0E0H,1FH				; bbad  Left-edge pattern
	DW	X07F0		; bbaf   f0 07
;
	DB	0F9H,81H				; bbb1  Full-bar pattern
	DW	XE0FF		; bbb3   ff e0
	DW	XF9FF		; bbb5   ff f9
;
;
XBBB7:	NOP			; bbb7  00		Timer bar bitmap buffer start (3 bytes per row x 8 rows)
;
; ==========================================================================
; NUMBER DISPLAY SETUP ($BBCF-$BBD7)
; ==========================================================================
; Partial code/data — appears to be an alternate entry point for number
; rendering, setting IX to CURSOR_STATE ($BCA9) with different parameters.
; ==========================================================================
	ORG	0BBCFH
;
	DB	0DDH,21H,0A9H				; bbcf  LD IX,$BCA9 (encoded as raw bytes)
	DW	X6FBC		; bbd2   bc 6f
;
	DB	26H,0,18H,10H				; bbd4  LD H,0; JR +16 (skip to $BBD8)
;
; ==========================================================================
; NUM_TO_DIGITS ($BBD8)
; ==========================================================================
; Converts a 16-bit number in HL to 5 decimal digits and renders each
; digit to the screen using RENDER_CHAR. Used for score/percentage display.
;
; The number is divided successively by 10000, 1000, 100, 10 to extract
; each digit. The quotient (+$80) gives the HUD font character code
; for that digit ('0' in HUD font = $80). The remainder from the last
; division is the ones digit.
;
; On entry: HL = 16-bit number to display
;           Cursor position must be set beforehand
; On exit:  5 digits rendered to screen at cursor position
; Corrupts: AF, BC, DE, HL, IX
; ==========================================================================
XBBD8:	LD	IX,XBCA9	; bbd8  dd 21 a9 bc	IX = CURSOR_STATE structure (X, Y, attr)
	LD	DE,X2710	; bbdc  11 10 27	DE = 10000 (ten-thousands divisor)
	CALL	XBBFB		; bbdf  cd fb bb	Divide HL by 10000, render digit, HL = remainder
	LD	DE,X03E8	; bbe2  11 e8 03	DE = 1000 (thousands divisor)
	CALL	XBBFB		; bbe5  cd fb bb	Divide HL by 1000, render digit, HL = remainder
	LD	DE,X0064	; bbe8  11 64 00	DE = 100 (hundreds divisor)
	CALL	XBBFB		; bbeb  cd fb bb	Divide HL by 100, render digit, HL = remainder
	LD	DE,X000A	; bbee  11 0a 00	DE = 10 (tens divisor)
	CALL	XBBFB		; bbf1  cd fb bb	Divide HL by 10, render digit, HL = remainder (ones)
	LD	A,L		; bbf4  7d		A = ones digit (0-9)
	ADD	A,80H		; bbf5  c6 80		Add $80 to convert to HUD font char code ('0'=$80)
	CALL	XBCB5		; bbf7  cd b5 bc	Render the ones digit
	RET			; bbfa  c9		Return — all 5 digits rendered
;
; ==========================================================================
; DIV_HL_DE ($BBFB)
; ==========================================================================
; Divides HL by DE using repeated subtraction. Returns quotient as a
; HUD font character code ($80 + digit) and renders it immediately.
; HL is left holding the remainder.
;
; On entry: HL = dividend, DE = divisor
; On exit:  HL = remainder, digit rendered to screen
; Corrupts: AF
; ==========================================================================
XBBFB:	LD	A,7FH		; bbfb  3e 7f		A = $7F (one less than '0' in HUD font; INC will make $80)
XBBFD:	INC	A		; bbfd  3c		Increment quotient counter (starts at $80 = '0')
	SBC	HL,DE		; bbfe  ed 52		HL = HL - DE (subtract one divisor unit)
	JR	NC,XBBFD	; bc00  30 fb		If no borrow (HL >= 0), keep subtracting
	ADD	HL,DE		; bc02  19		Went one too far — add DE back to get true remainder
	CALL	XBCB5		; bc03  cd b5 bc	Render digit A to screen (A = $80+quotient = HUD char)
	RET			; bc06  c9		Return: HL = remainder
;

; ==========================================================================
; PROCESS_ATTR_COLOR ($BC07)
; ==========================================================================
; Adapts an attribute byte for monochrome TV mode. If bit 7 of $B0EE
; (color TV flag) is set, returns the attribute unchanged. Otherwise,
; remaps colors to high-contrast black/white:
;   INK >= 2 → INK = 7 (white), PAPER = 0 (black)
;   INK < 2  → INK = 0 (black), PAPER = 7 (white)
; BRIGHT and FLASH bits (7-6) are preserved from the original.
;
; On entry: A = attribute byte
; On exit:  A = processed attribute (unchanged if color TV mode)
; Corrupts: HL (saved/restored)
; ==========================================================================
PROCESS_ATTR_COLOR:	PUSH	HL		; bc07  e5		Save HL
	LD	HL,XB0EE	; bc08  21 ee b0	HL = address of display mode flags
	BIT	7,(HL)		; bc0b  cb 7e		Test bit 7: is color TV mode enabled?
	JR	NZ,XBC24	; bc0d  20 15		If color TV (bit 7 set), skip remapping — return A as-is
	LD	L,A		; bc0f  6f		L = original attribute byte (save for later)
	AND	0C0H		; bc10  e6 c0		Isolate FLASH + BRIGHT bits (bits 7-6)
	LD	H,A		; bc12  67		H = FLASH|BRIGHT bits preserved
	LD	A,L		; bc13  7d		A = original attribute byte
	AND	7		; bc14  e6 07		Isolate INK color (bits 2-0)
	CP	2		; bc16  fe 02		Compare INK to 2
	CCF			; bc18  3f		Complement carry: carry set if INK < 2
	SBC	A,A		; bc19  9f		A = $FF if INK >= 2, A = $00 if INK < 2
	LD	L,A		; bc1a  6f		L = $FF (white ink) or $00 (black ink)
	AND	7		; bc1b  e6 07		A = 7 (white) or 0 (black) — new INK value
	OR	H		; bc1d  b4		Combine with FLASH|BRIGHT bits
	LD	H,A		; bc1e  67		H = FLASH|BRIGHT|new_INK
	LD	A,L		; bc1f  7d		A = $FF or $00
	CPL			; bc20  2f		Invert: $00 → $FF, $FF → $00
	AND	38H		; bc21  e6 38		Mask to PAPER bits (bits 5-3): 7<<3=$38 or 0
	OR	H		; bc23  b4		Combine: FLASH|BRIGHT|PAPER|INK — final attribute
XBC24:	POP	HL		; bc24  e1		Restore HL
	RET			; bc25  c9		Return: A = processed attribute
;

; ==========================================================================
; STRING_RENDERER ($BC26)
; ==========================================================================
; Renders control-code strings to the screen bitmap and attribute area.
; Reads bytes sequentially from (HL) and dispatches based on value.
; Cursor state is stored at IX ($BCA9): IX+0=X pixel, IX+1=Y row, IX+2=attr.
;
; Control codes:
;   $00        → end of string (return)
;   $08        → backspace: X -= 8 pixels
;   $09        → tab: X += 8 pixels
;   $0A        → line feed: Y += 1
;   $0B        → reverse LF: Y -= 1
;   $1C nn cc  → repeat: render char cc nn times
;   $1D        → pad to 8-pixel boundary with space ($7E)
;   $1E xx     → set attribute to xx (via PROCESS_ATTR_COLOR)
;   $1F xx yy  → set position: X=xx pixels, Y=yy char row (masked to 0-127)
;   $20-$FF    → printable character, rendered via RENDER_CHAR ($BCB5)
;
; On entry: HL = pointer to control string
; On exit:  HL = past the $00 terminator
; Corrupts: AF, BC, DE, IX
; ==========================================================================
STRING_RENDERER:	LD	IX,XBCA9	; bc26  dd 21 a9 bc	IX = CURSOR_STATE: [X pixel, Y row, attribute]
XBC2A:	LD	A,(HL)		; bc2a  7e		A = next byte from string
	INC	HL		; bc2b  23		Advance string pointer
	OR	A		; bc2c  b7		Test for $00 (null terminator)
	RET	Z		; bc2d  c8		If $00: end of string, return
	CP	20H		; bc2e  fe 20		Is it a printable character (>= $20)?
	JR	C,XBC37		; bc30  38 05		If < $20: it's a control code, jump to dispatcher
	CALL	XBCB5		; bc32  cd b5 bc	Printable char: render it via RENDER_CHAR
	JR	XBC2A		; bc35  18 f3		Loop for next byte
;
; --- Control code dispatcher ---
; At this point A < $20 (control code). Branch based on value.
XBC37:	CP	1EH		; bc37  fe 1e		Is it $1E (set attribute)?
	JR	Z,XBC4B		; bc39  28 10		Yes → handle set attribute
	JR	C,XBC55		; bc3b  38 18		< $1E → check for other control codes
; --- $1F: Set cursor position ---
; Format: $1F, X_pixel, Y_charrow
	LD	A,(HL)		; bc3d  7e		A = X position in pixels
	LD	(IX+0),A	; bc3e  dd 77 00	Store X pixel position in cursor state
	INC	HL		; bc41  23		Advance to Y byte
	LD	A,(HL)		; bc42  7e		A = Y char row
	AND	7FH		; bc43  e6 7f		Mask to 0-127 range (bit 7 cleared)
	LD	(IX+1),A	; bc45  dd 77 01	Store Y char row in cursor state
	INC	HL		; bc48  23		Advance past Y byte
	JR	XBC2A		; bc49  18 df		Continue processing string
;
; --- $1E: Set attribute color ---
; Format: $1E, attribute_byte
XBC4B:	LD	A,(HL)		; bc4b  7e		A = raw attribute byte
	CALL	PROCESS_ATTR_COLOR		; bc4c  cd 07 bc	Process for mono TV mode if needed
	LD	(IX+2),A	; bc4f  dd 77 02	Store processed attribute in cursor state
	INC	HL		; bc52  23		Advance past attribute byte
	JR	XBC2A		; bc53  18 d5		Continue processing string
;
; --- Dispatch remaining control codes (< $1E) ---
XBC55:	CP	1CH		; bc55  fe 1c		Is it $1C (repeat character)?
	JR	Z,XBC71		; bc57  28 18		Yes → handle repeat
	JR	C,XBC7F		; bc59  38 24		< $1C → check for $08/$09/$0A/$0B
; --- $1D: Pad to 8-pixel boundary ---
; Renders space ($7E) characters until X is aligned to 8 pixels
	LD	A,(IX+0)	; bc5b  dd 7e 00	A = current X pixel position
	AND	7		; bc5e  e6 07		Check if already on 8-pixel boundary
	JR	Z,XBC2A		; bc60  28 c8		If aligned (low 3 bits = 0), nothing to do
	LD	A,7EH		; bc62  3e 7e		A = $7E (space character in game font)
	CALL	XBCB5		; bc64  cd b5 bc	Render space character (advances cursor)
	LD	A,(IX+0)	; bc67  dd 7e 00	A = updated X position
	AND	0F8H		; bc6a  e6 f8		Round down to 8-pixel boundary
	LD	(IX+0),A	; bc6c  dd 77 00	Store aligned position
	JR	XBC2A		; bc6f  18 b9		Continue processing string
;
; --- $1C: Repeat character ---
; Format: $1C, count, character
XBC71:	LD	B,(HL)		; bc71  46		B = repeat count
	INC	HL		; bc72  23		Advance to character byte
	LD	C,(HL)		; bc73  4e		C = character to repeat
	INC	HL		; bc74  23		Advance past character byte
	PUSH	HL		; bc75  e5		Save string pointer (loop uses HL internally)
XBC76:	LD	A,C		; bc76  79		A = character to render
	CALL	XBCB5		; bc77  cd b5 bc	Render character
	DJNZ	XBC76		; bc7a  10 fa		Loop B times
	POP	HL		; bc7c  e1		Restore string pointer
	JR	XBC2A		; bc7d  18 ab		Continue processing string
;
; --- $08: Backspace (cursor left 8 pixels) ---
XBC7F:	CP	8		; bc7f  fe 08		Is it $08?
	JR	NZ,XBC8D	; bc81  20 0a		No → check next
	LD	A,(IX+0)	; bc83  dd 7e 00	A = current X position
	SUB	8		; bc86  d6 08		Move left 8 pixels
	LD	(IX+0),A	; bc88  dd 77 00	Store new X position
	JR	XBC2A		; bc8b  18 9d		Continue processing string
;
; --- $09: Tab (cursor right 8 pixels) ---
XBC8D:	CP	9		; bc8d  fe 09		Is it $09?
	JR	NZ,XBC9B	; bc8f  20 0a		No → check next
	LD	A,(IX+0)	; bc91  dd 7e 00	A = current X position
	ADD	A,8		; bc94  c6 08		Move right 8 pixels
	LD	(IX+0),A	; bc96  dd 77 00	Store new X position
	JR	XBC2A		; bc99  18 8f		Continue processing string
;
; --- $0A: Line feed (cursor down 1 char row) ---
XBC9B:	CP	0AH		; bc9b  fe 0a		Is it $0A?
	JR	NZ,XBCA4	; bc9d  20 05		No → must be $0B (reverse LF)
	INC	(IX+1)		; bc9f  dd 34 01	Increment Y char row
	JR	XBC2A		; bca2  18 86		Continue processing string
;
; --- $0B: Reverse line feed (cursor up 1 char row) ---
XBCA4:	DEC	(IX+1)		; bca4  dd 35 01	Decrement Y char row
	JR	XBC2A		; bca7  18 81		Continue processing string
;
; ==========================================================================
; CURSOR_STATE ($BCA9)
; ==========================================================================
; 3-byte structure used by STRING_RENDERER and RENDER_CHAR:
;   $BCA9 (IX+0): cursor X position in pixels (0-255)
;   $BCAA (IX+1): cursor Y position in char rows (0-23)
;   $BCAB (IX+2): current attribute byte for text rendering
;
; Followed by a character width mask table ($BCAC-$BCB4):
;   Index 0: $00 (width 0 — unused)
;   Index 1: $80 (width 1 — leftmost pixel only)
;   Index 2: $C0 (width 2)
;   Index 3: $E0 (width 3)
;   Index 4: $F0 (width 4)
;   Index 5: $F8 (width 5)
;   Index 6: $FC (width 6)
;   Index 7: $FE (width 7)
;   Index 8: $FF (width 8 — full byte)
; These masks are used to clip character pixel data to the correct width.
; ==========================================================================
XBCA9:	PUSH	BC		; bca9  c5		Cursor state byte 0: X pixel position (value=$C5 at snapshot)
XBCAA:	RLA			; bcaa  17		Cursor state byte 1: Y char row (value=$17 = row 23)
	LD	B,A		; bcab  47		Cursor state byte 2: attribute (value=$47)
XBCAC:	NOP			; bcac  00		Width mask[0]: $00 — zero width
	ADD	A,B		; bcad  80		Width mask[1]: $80 — 1 pixel wide
	RET	NZ		; bcae  c0		Width mask[2]: $C0 — 2 pixels wide
	RET	PO		; bcaf  e0		Width mask[3]: $E0 — 3 pixels wide
	RET	P		; bcb0  f0		Width mask[4]: $F0 — 4 pixels wide
	RET	M		; bcb1  f8		Width mask[5]: $F8 — 5 pixels wide
	CALL	M,XFFFE		; bcb2  fc fe ff	Width masks [6]=$FC, [7]=$FE, [8]=$FF
; ==========================================================================
; RENDER_CHAR ($BCB5)
; ==========================================================================
; Renders a single character to the screen at the current cursor position.
; Uses the game font: character widths from $C0D5 (one byte per char),
; pixel data from the font bitmap. Characters are proportional-width
; (1-8 pixels). Uses mask-and-OR compositing to avoid overwriting
; adjacent characters.
;
; After rendering, advances the cursor X position by the character width.
; If X overflows past 255, wraps to next line (Y incremented if < 23).
;
; On entry: A = character code, IX = cursor state pointer
; On exit:  Cursor position advanced
; Corrupts: AF, BC, DE, HL
; ==========================================================================
XBCB5:	PUSH	BC		; bcb5  c5		Save BC
	PUSH	DE		; bcb6  d5		Save DE
	PUSH	HL		; bcb7  e5		Save HL (string pointer)
	LD	E,A		; bcb8  5f		E = character code
	LD	D,0		; bcb9  16 00		DE = character code (16-bit index)
	LD	HL,XC0D5	; bcbb  21 d5 c0	HL = character width table base
	ADD	HL,DE		; bcbe  19		HL = address of this char's width byte
	LD	A,(HL)		; bcbf  7e		A = character width (1-8 pixels)
	LD	B,A		; bcc0  47		B = width (saved for cursor advance)
	LD	HL,XBCAC	; bcc1  21 ac bc	HL = width mask table base
	ADD	A,L		; bcc4  85		Index into mask table
	LD	L,A		; bcc5  6f		HL = address of width mask
	ADC	A,H		; bcc6  8c		Handle carry for high byte
	SUB	L		; bcc7  95		Compute H correctly
	LD	H,A		; bcc8  67		HL = &mask_table[width]
	LD	A,(HL)		; bcc9  7e		A = width mask (e.g. $F0 for 4-pixel-wide char)
	CPL			; bcca  2f		Invert mask: clear bits = char area, set bits = preserve
	LD	C,A		; bccb  4f		C = inverted mask (used for AND-compositing)
	LD	L,(IX+1)	; bccc  dd 6e 01	L = cursor Y char row
	LD	H,0		; bccf  26 00		HL = Y row (16-bit)
	ADD	HL,HL		; bcd1  29		HL = Y * 2
	ADD	HL,HL		; bcd2  29		HL = Y * 4
	ADD	HL,HL		; bcd3  29		HL = Y * 8
	ADD	HL,HL		; bcd4  29		HL = Y * 16 (offset into row pointer table)
	LD	A,0FCH		; bcd5  3e fc		A = $FC (high byte of ROW_PTR_TABLE at $FC00)
;
; --- The following section is densely packed code that the disassembler ---
; --- could not fully resolve. It continues the RENDER_CHAR logic:      ---
; ---   1. Compute screen address from row pointer table + X offset     ---
; ---   2. For each of 8 pixel rows in the character cell:              ---
; ---      a. Read font pixel data for this row                         ---
; ---      b. Shift right by (X & 7) to align to sub-byte position     ---
; ---      c. AND existing screen byte with inverted mask               ---
; ---      d. OR in the shifted character pixels                        ---
; ---      e. Write back to screen                                      ---
; ---      f. If char spans two bytes, do the same for the next byte    ---
; ---      g. INC H to advance to next pixel row (ZX screen layout)     ---
; ---   3. Write attribute byte to attribute area                       ---
; ---   4. Advance cursor X by character width                          ---
; ==========================================================================
	DB	84H					; bcd7  ADD A,H — adds row ptr table high byte
	DB	'g~#fo'					; bcd8  LD H,A; LD A,(HL); INC HL; LD L,(HL); LD (HL),A
	DB	0DDH,7EH,0,1FH,1FH,1FH,0E6H,1FH		; bcdd  LD A,(IX+0); RRA; RRA; RRA; AND $1F — X/8 column
	DB	85H,6FH					; bce5  ADD A,L; LD L,A — add column offset to screen addr
	DW	X29EB		; bce7   eb 29      EX DE,HL; ADD HL,HL — DE=screen addr, HL=font offset
;
	DB	29H,29H,3EH,0F6H,84H,67H		; bce9  ADD HL,HL x2; LD A,$F6; ADD A,H; LD H,A — font addr
	DW	XC5EB		; bcef   eb c5      EX DE,HL; PUSH BC — HL=screen, stack=width+mask
;
; --- Main render loop: 8 pixel rows per character cell ---
	DB	6,8,1AH,0DDH,0CBH,2,7EH,28H		; bcf1  LD B,8; LD A,(DE); BIT 7,(IX+2); JR Z — 8 rows, check attr flag
	DB	2					; bcf9  skip distance
	DW	X2FB1		; bcfa   b1 2f      OR C; CPL — combine mask bits
;
	DB	13H,0C5H				; bcfc  INC DE; PUSH BC — advance font ptr, save row counter
	DW	X5FD5		; bcfe   d5 5f      PUSH DE; LD E,A — save font ptr, E=font pixel data
;
	DB	16H,0,6,0FFH,0DDH,7EH,0,0E6H		; bd00  LD D,0; LD B,$FF; LD A,(IX+0); AND...
	DB	7,28H,0CH				; bd08  ...7; JR Z,+12 — get sub-byte shift (X & 7)
	DW	X3BCB		; bd0b   cb 3b      SRL E — shift char pixel data right
	DW	X1ACB		; bd0d   cb 1a      RR D — overflow into second byte
	DB	37H					; bd0f  SCF — set carry for mask shift
	DW	X19CB		; bd10   cb 19      RR C — shift inverted mask right
	DW	X18CB		; bd12   cb 18      RR B — overflow into second mask byte
;
	DB	3DH,20H,0F4H,79H,0A6H,0B3H,77H,23H	; bd14  DEC A; JR NZ,-12; LD A,C; AND (HL); OR E; LD (HL),A; INC HL
	DB	78H,0A6H				; bd1c  LD A,B; AND (HL) — composite second byte
	DW	X77B2		; bd1e   b2 77      OR D; LD (HL),A — write second byte
;
	DB	2BH,24H					; bd20  DEC HL; INC H — back to first byte col, next pixel row
	DW	XC1D1		; bd22   d1 c1      POP DE; POP BC — restore font ptr and row counter
	DB	10H					; bd24  DJNZ — loop for 8 pixel rows
	DW	XC1CD		; bd25   cd c1      (jump offset); POP BC — end of render loop
;
; --- Write attribute and advance cursor ---
	DB	0DDH,7EH,1,87H,87H,87H,6FH,26H		; bd27  LD A,(IX+1); ADD x3; LD L,A; LD H — compute attr addr
	DB	16H,29H,29H,0DDH,7EH,0,1FH,1FH		; bd2f  Y*32 continued; LD A,(IX+0); RRA; RRA
	DB	1FH,0E6H,1FH,85H,6FH,0DDH,5EH,2		; bd37  RRA; AND $1F; ADD L; LD L,A; LD E,(IX+2) — attr byte
	DW	XBBCB		; bd3f   cb bb      RES 7,E — clear flash bit from attr? or mask operation
;
	DB	73H,0DDH,7EH,0,0E6H,7,80H		; bd41  LD (HL),E; LD A,(IX+0); AND 7; ADD A,B — advance cursor
	DW	X09FE		; bd48   fe 09      CP 9 — check if width >= 9 (overflow)
;
	DB	38H,2,23H,73H,0DDH,7EH,0		; bd4a  JR C,+2; INC HL; LD (HL),E; LD A,(IX+0) — write attr to 2nd cell if wide
;
; --- Update cursor position ---
	ADD	A,B		; bd51  80		Add character width B to cursor X
	LD	(IX+0),A	; bd52  dd 77 00	Store new cursor X
	JR	NC,XBD61	; bd55  30 0a		If no carry (X didn't wrap past 255), done
	LD	A,(IX+1)	; bd57  dd 7e 01	A = current cursor Y row
	CP	17H		; bd5a  fe 17		Compare to 23 (last char row)
	ADC	A,0		; bd5c  ce 00		If Y < 23, increment Y (ADC adds carry from CP)
	LD	(IX+1),A	; bd5e  dd 77 01	Store new cursor Y row (auto line wrap)
XBD61:	POP	HL		; bd61  e1		Restore HL (string pointer)
	POP	DE		; bd62  d1		Restore DE
	POP	BC		; bd63  c1		Restore BC
	RET			; bd64  c9		Return
;
; ==========================================================================
; XOR_DRAW_RECT ($BD65)
; ==========================================================================
; Draws or erases a rectangular highlight on the screen using XOR mode.
; Used by the timer bar and menu system to toggle segment visibility.
; XOR mode means calling twice restores the original screen content.
;
; The first column is XORed with $7F (preserves leftmost pixel as border),
; middle columns are fully inverted (CPL = XOR $FF), and the last column
; is XORed with $FE (preserves rightmost pixel as border).
;
; On entry: D = Y char row, E = column byte offset, A = width (C), C = width
; On exit:  Rectangle XOR-toggled on screen
; Corrupts: AF, BC, DE, HL
; ==========================================================================
XBD65:	PUSH	BC		; bd65  c5		Save BC
	PUSH	DE		; bd66  d5		Save DE
	PUSH	HL		; bd67  e5		Save HL
	LD	C,A		; bd68  4f		C = width in bytes
	LD	L,D		; bd69  6a		L = Y char row
	LD	H,0		; bd6a  26 00		HL = Y (16-bit)
	ADD	HL,HL		; bd6c  29		HL = Y * 2
	ADD	HL,HL		; bd6d  29		HL = Y * 4
	ADD	HL,HL		; bd6e  29		HL = Y * 8
	ADD	HL,HL		; bd6f  29		HL = Y * 16 (row ptr table offset)
	LD	A,0FCH		; bd70  3e fc		A = $FC (ROW_PTR_TABLE high byte)
	ADD	A,H		; bd72  84		A = table page + row offset
	LD	H,A		; bd73  67		HL = address in ROW_PTR_TABLE for this row
	LD	A,E		; bd74  7b		A = column byte offset
	ADD	A,(HL)		; bd75  86		A = low byte of screen address + column
	INC	HL		; bd76  23		Advance to high byte of screen address
	LD	H,(HL)		; bd77  66		H = high byte of screen address
	LD	L,A		; bd78  6f		HL = screen address for (row, col)
	LD	B,8		; bd79  06 08		B = 8 pixel rows per character cell
XBD7B:	PUSH	BC		; bd7b  c5		Save row counter and width
	PUSH	HL		; bd7c  e5		Save screen address for this row
	LD	A,(HL)		; bd7d  7e		A = first screen byte
	XOR	7FH		; bd7e  ee 7f		XOR with $7F: invert all except bit 7 (left border pixel)
	LD	(HL),A		; bd80  77		Write back inverted first byte
	LD	B,C		; bd81  41		B = width counter
	DEC	B		; bd82  05		Decrement for first byte (already done)
	JR	Z,XBD8F		; bd83  28 0a		If width=1, skip to last byte handling
	INC	HL		; bd85  23		Move to second byte
	DEC	B		; bd86  05		Decrement for last byte (handled separately)
	JR	Z,XBD8F		; bd87  28 06		If width=2, skip middle bytes
XBD89:	LD	A,(HL)		; bd89  7e		A = middle screen byte
	CPL			; bd8a  2f		Fully invert all 8 pixels (XOR $FF)
	LD	(HL),A		; bd8b  77		Write back inverted byte
	INC	HL		; bd8c  23		Advance to next byte
	DJNZ	XBD89		; bd8d  10 fa		Loop for remaining middle bytes
XBD8F:	LD	A,(HL)		; bd8f  7e		A = last screen byte
	XOR	0FEH		; bd90  ee fe		XOR with $FE: invert all except bit 0 (right border pixel)
	LD	(HL),A		; bd92  77		Write back inverted last byte
	POP	HL		; bd93  e1		Restore row start address
	INC	H		; bd94  24		INC H = advance to next pixel row (ZX screen trick)
	POP	BC		; bd95  c1		Restore row counter and width
	DJNZ	XBD7B		; bd96  10 e3		Loop for all 8 pixel rows
	POP	HL		; bd98  e1		Restore HL
	POP	DE		; bd99  d1		Restore DE
	POP	BC		; bd9a  c1		Restore BC
	RET			; bd9b  c9		Return
;
; ==========================================================================
; PROCESS_TIMER_SEGMENTS ($BD9C)
; ==========================================================================
; Iterates through a table of timer bar segments (pointed to by $BDF4).
; Each segment entry is 3 bytes:
;   Byte 0: X column (bit 7 = "currently visible" flag)
;   Byte 1: Y char row
;   Byte 2: width in bytes
; Table terminated by $FF.
;
; For each segment, checks if the cursor (B=row, C=col) falls within it.
; If cursor enters a non-highlighted segment: set bit 7 (highlight) and
; XOR-draw it to screen. If cursor leaves a highlighted segment: clear
; bit 7 and XOR-draw again to erase the highlight.
;
; On entry: B = cursor Y (char row), C = cursor X (char column)
;           $BDF4 = pointer to segment table
; Corrupts: AF, DE, IX
; ==========================================================================
XBD9C:	LD	IX,(XBDF4)	; bd9c  dd 2a f4 bd	IX = pointer to segment table
XBDA0:	LD	A,(IX+0)	; bda0  dd 7e 00	A = segment X column (with bit 7 = visible flag)
	CP	0FFH		; bda3  fe ff		Is it $FF (end-of-table marker)?
	RET	Z		; bda5  c8		If end of table, return
	JP	M,XBDC8		; bda6  fa c8 bd	If bit 7 set (segment is highlighted), jump to un-highlight check
; --- Segment is NOT highlighted: check if cursor is inside it ---
	LD	E,A		; bda9  5f		E = segment X column
	LD	A,B		; bdaa  78		A = cursor Y row
	CP	(IX+1)		; bdab  dd be 01	Compare cursor Y with segment Y
	JR	NZ,XBDE7	; bdae  20 37		If different row, skip to next segment
	LD	A,C		; bdb0  79		A = cursor X column
	SUB	E		; bdb1  93		A = cursor_X - segment_X
	JR	C,XBDE7		; bdb2  38 33		If cursor is left of segment, skip
	CP	(IX+2)		; bdb4  dd be 02	Compare offset with segment width
	JR	NC,XBDE7	; bdb7  30 2e		If cursor is past end of segment, skip
; --- Cursor IS inside this segment: highlight it ---
	LD	D,(IX+1)	; bdb9  dd 56 01	D = segment Y row (for XOR_DRAW_RECT)
	LD	A,(IX+2)	; bdbc  dd 7e 02	A = segment width
	SET	7,(IX+0)	; bdbf  dd cb 00 fe	Set bit 7: mark segment as highlighted
	CALL	XBD65		; bdc3  cd 65 bd	XOR-draw the highlight rectangle
	JR	XBDE7		; bdc6  18 1f		Continue to next segment
;
; --- Segment IS highlighted: check if cursor has LEFT it ---
XBDC8:	AND	7FH		; bdc8  e6 7f		Mask off bit 7 to get actual X column
	LD	E,A		; bdca  5f		E = segment X column
	LD	A,B		; bdcb  78		A = cursor Y row
	CP	(IX+1)		; bdcc  dd be 01	Compare cursor Y with segment Y
	JR	NZ,XBDDA	; bdcf  20 09		If different row, cursor has left → un-highlight
	LD	A,C		; bdd1  79		A = cursor X column
	SUB	E		; bdd2  93		A = cursor_X - segment_X
	JR	C,XBDDA		; bdd3  38 05		If cursor is left of segment → un-highlight
	CP	(IX+2)		; bdd5  dd be 02	Compare offset with segment width
	JR	C,XBDE7		; bdd8  38 0d		If cursor still inside segment, skip (keep highlight)
; --- Cursor has LEFT: un-highlight by XOR-drawing again ---
XBDDA:	RES	7,(IX+0)	; bdda  dd cb 00 be	Clear bit 7: mark segment as not highlighted
	LD	D,(IX+1)	; bdde  dd 56 01	D = segment Y row
	LD	A,(IX+2)	; bde1  dd 7e 02	A = segment width
	CALL	XBD65		; bde4  cd 65 bd	XOR-draw to erase the highlight
; --- Advance to next segment entry ---
XBDE7:	LD	DE,X0003	; bde7  11 03 00	DE = 3 (bytes per segment entry)
	ADD	IX,DE		; bdea  dd 19		IX += 3 → point to next segment
	JR	XBDA0		; bdec  18 b2		Loop back to process next segment
;
; ==========================================================================
; TIMER BAR STATE VARIABLES ($BDEE-$BDF6)
; ==========================================================================
XBDEE:	DW	XA0C8		; bdee   c8 a0      Current timer bar position: X=$C8, Y=$A0
;
XBDF0:	DB	0					; bdf0  Timer bar target/direction state
;
	ORG	0BDF2H
;
XBDF2:	NOP			; bdf2  00		Previous keyboard input (for repeat detection)
XBDF3:	NOP			; bdf3  00		Repeat counter (frames held, for acceleration)
XBDF4:	NOP			; bdf4  00		Pointer to timer segment table (low byte)
;
	ORG	0BDF6H
;
; ==========================================================================
; DRAW_TIMER_ROW ($BDF7)
; ==========================================================================
; Draws or saves/restores one row of the timer bar on screen.
; Direction controlled by bit 7 of C: if set ($80), copies FROM timer
; pattern buffer TO screen (draw). If clear ($00), copies FROM screen
; TO buffer (save for later restore).
;
; Reads position from $BDEE (X) and $BDEF (Y). Computes screen address
; via ROW_PTR_TABLE. Copies 3 bytes per pixel row, up to 8 rows.
;
; On entry: C = $80 (draw) or $00 (save/erase)
; On exit:  Timer bar row drawn or saved
; Corrupts: AF, BC, DE, HL, IX
; ==========================================================================
XBDF6:	RST	38H		; bdf6  ff		Selected segment index (data byte, not code)
XBDF7:	LD	HL,XBDEE	; bdf7  21 ee bd	HL = timer bar position state ($BDEE)
	LD	A,(HL)		; bdfa  7e		A = timer X pixel position
	RRA			; bdfb  1f		A >>= 1
	RRA			; bdfc  1f		A >>= 2
	RRA			; bdfd  1f		A >>= 3 (divide by 8 → byte column)
	AND	1FH		; bdfe  e6 1f		Mask to 0-31 column range
	OR	C		; be00  b1		OR with C: bit 7 sets draw/save mode flag
	LD	C,A		; be01  4f		C = column | mode_flag
	INC	HL		; be02  23		HL = $BDEF (Y position)
	LD	A,0C0H		; be03  3e c0		A = 192 (screen height in pixels)
	SUB	(HL)		; be05  96		A = 192 - Y = rows from bottom of screen
	RET	Z		; be06  c8		If Y=192 (off screen), return
	RET	C		; be07  d8		If Y>192 (off screen), return
	CP	8		; be08  fe 08		Is remaining height >= 8?
	JR	C,XBE0E		; be0a  38 02		If < 8, use actual remaining rows
	LD	A,8		; be0c  3e 08		Otherwise cap at 8 pixel rows
XBE0E:	LD	B,A		; be0e  47		B = number of pixel rows to process (1-8)
	LD	L,(HL)		; be0f  6e		L = Y pixel position
	LD	H,0		; be10  26 00		HL = Y (16-bit)
	ADD	HL,HL		; be12  29		HL = Y * 2 (word offset into ROW_PTR_TABLE)
	EX	DE,HL		; be13  eb		DE = row ptr table offset
	LD	IX,ROW_PTR_TABLE	; be14  dd 21 00 fc	IX = ROW_PTR_TABLE base ($FC00)
	ADD	IX,DE		; be18  dd 19		IX = address of screen row pointer for Y
	LD	DE,XBBB7	; be1a  11 b7 bb	DE = timer bar bitmap buffer ($BBB7)
XBE1D:	LD	A,C		; be1d  79		A = column | mode_flag
	AND	1FH		; be1e  e6 1f		Isolate column (mask off mode bit)
	ADD	A,(IX+0)	; be20  dd 86 00	Add column to screen row address low byte
	LD	L,A		; be23  6f		L = screen address low byte
	INC	IX		; be24  dd 23		Advance to high byte of row pointer
	LD	H,(IX+0)	; be26  dd 66 00	H = screen address high byte
	INC	IX		; be29  dd 23		Advance IX to next row pointer
	BIT	7,C		; be2b  cb 79		Test mode flag: bit 7 set = draw mode
	JR	Z,XBE30		; be2d  28 01		If save mode (bit 7 clear), HL=screen, DE=buffer (copy screen→buffer)
	EX	DE,HL		; be2f  eb		If draw mode: swap so HL=buffer, DE=screen (copy buffer→screen)
XBE30:	LDI			; be30  ed a0		Copy byte 1 (source→dest), advance both pointers
	LDI			; be32  ed a0		Copy byte 2
	LDI			; be34  ed a0		Copy byte 3 (timer bar is 3 bytes wide)
	INC	BC		; be36  03		LDI decremented BC by 3, restore it (+1)
	INC	BC		; be37  03		+2
	INC	BC		; be38  03		+3 (BC fully restored)
	BIT	7,C		; be39  cb 79		Test mode flag again
	JR	Z,XBE3E		; be3b  28 01		If save mode, keep current pointer directions
	EX	DE,HL		; be3d  eb		If draw mode, swap back so DE=buffer for next row
XBE3E:	DJNZ	XBE1D		; be3e  10 dd		Loop for all pixel rows
	RET			; be40  c9		Return
;
; ==========================================================================
; RESTORE_TIMER_ROW ($BE41)
; ==========================================================================
; Restores screen content behind the timer bar. Companion to DRAW_TIMER_ROW.
; Reads saved pixel data from XBB97 buffer and writes it back to screen.
; Also uses mask-and-OR compositing (like sprite rendering) to blend the
; timer bar graphics with the screen content.
;
; The first part ($BE41-$BE5C) computes the screen address and row count,
; similar to DRAW_TIMER_ROW. The rest ($BE5D-$BEB9) is a sprite-style
; rendering loop with sub-pixel alignment shifting.
;
; On entry: C = X pixel position (from $BDEE)
; On exit:  Timer bar row restored on screen
; Corrupts: AF, BC, DE, HL, IX
; ==========================================================================
XBE41:	LD	HL,XBDEE	; be41  21 ee bd	HL = timer bar position state
	LD	C,(HL)		; be44  4e		C = X pixel position
	INC	HL		; be45  23		HL = $BDEF (Y position)
	LD	A,0C0H		; be46  3e c0		A = 192 (screen height in pixels)
	SUB	(HL)		; be48  96		A = 192 - Y = remaining rows from bottom
	RET	Z		; be49  c8		If Y=192 (off screen), return
	RET	C		; be4a  d8		If Y>192 (off screen), return
	CP	8		; be4b  fe 08		Is remaining height >= 8?
	JR	C,XBE51		; be4d  38 02		If < 8, use actual remaining rows
	LD	A,8		; be4f  3e 08		Otherwise cap at 8 pixel rows
XBE51:	LD	B,A		; be51  47		B = number of pixel rows to render
	LD	A,(HL)		; be52  7e		A = Y pixel position
	ADD	A,A		; be53  87		A = Y * 2 (word offset into ROW_PTR_TABLE)
	LD	L,A		; be54  6f		L = offset low byte
	ADC	A,0FCH		; be55  ce fc		Add $FC (ROW_PTR_TABLE high byte) + carry
	SUB	L		; be57  95		Compute H correctly: H = $FC + carry from Y*2
	LD	H,A		; be58  67		HL = ROW_PTR_TABLE address for this Y
	LD	IX,XBB97	; be59  dd 21 97 bb	IX = saved timer bar bitmap data buffer
; --- Render loop: one iteration per pixel row ---
XBE5D:	PUSH	BC		; be5d  c5		Save row counter and X position
	LD	A,C		; be5e  79		A = X pixel position
	RRA			; be5f  1f		A >>= 1
	RRA			; be60  1f		A >>= 2
	RRA			; be61  1f		A >>= 3 (divide by 8 → byte column)
	AND	1FH		; be62  e6 1f		Mask to 0-31 column range
;
; --- The following is densely packed sprite compositing code ---
; --- It reads 3 pairs of (mask, data) bytes from IX, shifts them ---
; --- right by (X & 7) for sub-byte alignment, then composites ---
; --- each byte to screen via: screen = (screen AND mask) OR data ---
	DB	86H					; be64  ADD A,(HL) — add column to screen row addr low byte
	DB	'_~#V#'					; be65  LD E,A; LD A,(HL); INC HL; LD D,(HL); INC HL — get screen addr
	DB	0B2H,28H,49H,0E5H			; be6a  OR D; JR Z,+$49; PUSH HL — boundary check + save row ptr
	DW	XE5EB		; be6e   eb e5      EX DE,HL; PUSH HL — HL=screen addr, save it
;
; --- Load 3 mask/data pairs from timer bar pattern buffer ---
	DB	79H,0DDH,46H,0,0DDH,56H,1,26H		; be70  LD A,C; LD B,(IX+0); LD D,(IX+1); LD H,0
	DB	0,0DDH,4EH,10H,0DDH,5EH,11H,2EH		; be78  LD C,(IX+$10); LD E,(IX+$11); LD L,...
;
; --- Sub-byte pixel alignment: shift all mask/data pairs right by (X & 7) ---
	RST	38H		; be80  ff		(data byte $FF, part of instruction sequence)
	AND	7		; be81  e6 07		A = X & 7 (sub-byte pixel offset)
	JR	Z,XBE95		; be83  28 10		If aligned to byte boundary, skip shifting
XBE85:	SRL	B		; be85  cb 38		Shift mask byte 1 right (fill with 1 from left)
	RR	D		; be87  cb 1a		Shift data byte 1 right (overflow continues)
	RR	H		; be89  cb 1c		Shift into third byte position
	SCF			; be8b  37		Set carry (so mask fills with 1s = transparent)
	RR	C		; be8c  cb 19		Shift mask byte 2 right
	RR	E		; be8e  cb 1b		Shift data byte 2 right
	RR	L		; be90  cb 1d		Shift into third position
	DEC	A		; be92  3d		Decrement shift counter
	JR	NZ,XBE85	; be93  20 f0		Loop until all shifts done
; --- Composite to screen: byte = (byte AND mask) OR data ---
XBE95:	EX	(SP),HL		; be95  e3		HL = screen address (from stack), push shifted data
	LD	A,C		; be96  79		A = shifted mask for byte 1
	AND	(HL)		; be97  a6		AND with existing screen byte (preserve non-timer pixels)
	OR	B		; be98  b0		OR in timer bar pixel data
	LD	(HL),A		; be99  77		Write composited byte back to screen
	INC	HL		; be9a  23		Advance to next screen byte
	LD	A,L		; be9b  7d		Check if we've crossed a 32-byte row boundary
	AND	1FH		; be9c  e6 1f		Test low 5 bits (column position)
	JR	Z,XBEB0		; be9e  28 10		If wrapped to column 0, skip remaining bytes
	LD	A,E		; bea0  7b		A = shifted mask for byte 2
	AND	(HL)		; bea1  a6		AND with existing screen byte
	OR	D		; bea2  b2		OR in timer bar pixel data
	LD	(HL),A		; bea3  77		Write composited byte
	INC	HL		; bea4  23		Advance to next screen byte
	LD	A,L		; bea5  7d		Check for row boundary wrap again
	AND	1FH		; bea6  e6 1f		Test low 5 bits
	JR	Z,XBEB0		; bea8  28 06		If wrapped, skip byte 3
	POP	DE		; beaa  d1		Retrieve shifted byte 3 data from stack
	PUSH	DE		; beab  d5		Keep it on stack for cleanup
	LD	A,E		; beac  7b		A = shifted mask for byte 3
	AND	(HL)		; bead  a6		AND with existing screen byte
	OR	D		; beae  b2		OR in timer bar pixel data
	LD	(HL),A		; beaf  77		Write composited byte 3
XBEB0:	POP	DE		; beb0  d1		Clean up stack (discard saved data)
	INC	IX		; beb1  dd 23		Advance IX past mask/data pair 1
	INC	IX		; beb3  dd 23		Advance IX past mask/data pair 2
	POP	HL		; beb5  e1		Restore row pointer table address
	POP	BC		; beb6  c1		Restore row counter and X position
	DJNZ	XBE5D		; beb7  10 a4		Loop for all pixel rows
	RET			; beb9  c9		Return
;
; ==========================================================================
; MENU_CURSOR_MOVE ($BEBA)
; ==========================================================================
; Reads keyboard input and moves a menu selection cursor. Movement speed
; accelerates the longer a direction is held:
;   Frames 0-11:  speed = 1 pixel per frame
;   Frames 12-15: speed = 2 pixels per frame
;   Frames 16-19: speed = 3 pixels per frame
;   Frames 20+:   speed = 4 pixels per frame
;
; Position is clamped to valid range: X in [0, $FC], Y in [0, $BE].
; Result stored at $BDF0 (X) and $BDF1 (Y).
;
; On entry: (reads keyboard internally)
; On exit:  HL = new cursor position (L=X, H=Y), stored at $BDF0
; Corrupts: AF, BC, DE, HL
; ==========================================================================
XBEBA:	CALL	READ_KEYBOARD		; beba  cd 68 ba	Read keyboard → C = input bits
	LD	A,(XBDF3)	; bebd  3a f3 bd	A = previous repeat counter
	INC	A		; bec0  3c		Increment repeat counter
	LD	D,A		; bec1  57		D = new repeat counter (tentative)
	LD	HL,XBDF2	; bec2  21 f2 bd	HL = address of previous input state
	LD	A,C		; bec5  79		A = current input
	CP	(HL)		; bec6  be		Compare with previous input
	JR	Z,XBECB		; bec7  28 02		If same keys held, keep incrementing counter
	LD	D,0		; bec9  16 00		Different keys: reset repeat counter to 0
XBECB:	LD	(HL),A		; becb  77		Store current input as new "previous" state
	LD	A,D		; becc  7a		A = repeat counter
	LD	(XBDF3),A	; becd  32 f3 bd	Store updated repeat counter
; --- Calculate movement speed based on repeat counter ---
	LD	D,1		; bed0  16 01		D = 1 (base speed: 1 pixel/frame)
	CP	0CH		; bed2  fe 0c		Has key been held for 12+ frames?
	JR	C,XBEE1		; bed4  38 0b		If < 12, keep speed=1
	INC	D		; bed6  14		D = 2 (medium speed)
	CP	10H		; bed7  fe 10		Has key been held for 16+ frames?
	JR	C,XBEE1		; bed9  38 06		If < 16, keep speed=2
	INC	D		; bedb  14		D = 3 (fast speed)
	CP	14H		; bedc  fe 14		Has key been held for 20+ frames?
	JR	C,XBEE1		; bede  38 01		If < 20, keep speed=3
	INC	D		; bee0  14		D = 4 (maximum speed)
; --- Apply directional movement ---
XBEE1:	LD	HL,(XBDEE)	; bee1  2a ee bd	HL = current position (L=X, H=Y)
; --- Left (bit 4 of C) ---
	BIT	4,C		; bee4  cb 61		Test Left key
	JR	Z,XBEEE		; bee6  28 06		If not pressed, skip
	LD	A,L		; bee8  7d		A = current X
	SUB	D		; bee9  92		A = X - speed
	JR	NC,XBEED	; beea  30 01		If no underflow, keep value
	XOR	A		; beec  af		Clamp to 0 (X can't go negative)
XBEED:	LD	L,A		; beed  6f		L = new X
; --- Right (bit 3 of C) ---
XBEEE:	BIT	3,C		; beee  cb 59		Test Right key
	JR	Z,XBEFD		; bef0  28 0b		If not pressed, skip
	LD	A,L		; bef2  7d		A = current X
	ADD	A,D		; bef3  82		A = X + speed
	JR	C,XBEFA		; bef4  38 04		If overflow past 255, clamp
	CP	0FCH		; bef6  fe fc		Is X >= $FC (max)?
	JR	C,XBEFC		; bef8  38 02		If < $FC, keep value
XBEFA:	LD	A,0FCH		; befa  3e fc		Clamp to $FC (maximum X)
XBEFC:	LD	L,A		; befc  6f		L = new X
; --- Up (bit 2 of C) ---
XBEFD:	BIT	2,C		; befd  cb 51		Test Up key
	JR	Z,XBF07		; beff  28 06		If not pressed, skip
	LD	A,H		; bf01  7c		A = current Y
	SUB	D		; bf02  92		A = Y - speed
	JR	NC,XBF06	; bf03  30 01		If no underflow, keep value
	XOR	A		; bf05  af		Clamp to 0 (Y can't go negative)
XBF06:	LD	H,A		; bf06  67		H = new Y
; --- Down (bit 1 of C) ---
XBF07:	BIT	1,C		; bf07  cb 49		Test Down key
	JR	Z,XBF14		; bf09  28 09		If not pressed, skip
	LD	A,H		; bf0b  7c		A = current Y
	ADD	A,D		; bf0c  82		A = Y + speed
	CP	0BEH		; bf0d  fe be		Is Y >= $BE (max)?
	JR	C,XBF13		; bf0f  38 02		If < $BE, keep value
	LD	A,0BEH		; bf11  3e be		Clamp to $BE (maximum Y)
XBF13:	LD	H,A		; bf13  67		H = new Y
; --- Store updated position ---
XBF14:	LD	(XBDF0),HL	; bf14  22 f0 bd	Store new position (L=X, H=Y) at $BDF0
	RET			; bf17  c9		Return
;
; ==========================================================================
; MENU_INIT ($BF18)
; ==========================================================================
; Initializes menu state. Stores the segment table pointer, reads current
; position, converts to char coords, processes initial segment highlights,
; waits for fire release, and draws the timer bar.
;
; On entry: HL = pointer to segment table
; Corrupts: AF, BC, DE, HL, IX
; ==========================================================================
XBF18:	LD	(XBDF4),HL	; bf18  22 f4 bd	Store segment table pointer
	LD	BC,(XBDEE)	; bf1b  ed 4b ee bd	BC = current position (B=Y pixel, C=X pixel)
	SRL	B		; bf1f  cb 38		B >>= 1 (Y / 2)
	SRL	B		; bf21  cb 38		B >>= 2 (Y / 4)
	SRL	B		; bf23  cb 38		B >>= 3 (Y / 8 → char row)
	SRL	C		; bf25  cb 39		C >>= 1 (X / 2)
	SRL	C		; bf27  cb 39		C >>= 2 (X / 4)
	SRL	C		; bf29  cb 39		C >>= 3 (X / 8 → char column)
	CALL	XBD9C		; bf2b  cd 9c bd	Process timer segments at cursor position
	CALL	XBAA9		; bf2e  cd a9 ba	Wait for fire button release (debounce)
	LD	C,0		; bf31  0e 00		C = 0 (save mode)
	CALL	XBDF7		; bf33  cd f7 bd	Save screen content behind timer bar
	CALL	XBE41		; bf36  cd 41 be	Restore timer bar area on screen
	RET			; bf39  c9		Return
;
; ==========================================================================
; MENU_FIRE_HANDLER ($BF3A)
; ==========================================================================
; Called each frame in menu mode. Reads keyboard, updates cursor position
; via MENU_CURSOR_MOVE, redraws timer bar. If fire is pressed (clean press,
; not held), searches the segment table for the highlighted segment and
; returns its index via $BDF6 with carry set.
;
; On exit: Carry set = selection made ($BDF6 = segment index)
;          Carry clear = no selection (Z flag set if no input at all)
; Corrupts: AF, BC, DE, HL, IX
; ==========================================================================
XBF3A:	CALL	XBEBA		; bf3a  cd ba be	Read keyboard and move cursor
	LD	A,C		; bf3d  79		A = keyboard input bits
	OR	A		; bf3e  b7		Any key pressed?
	RET	Z		; bf3f  c8		If no input at all, return (Z set, carry clear)
	CALL	XBB69		; bf40  cd 69 bb	Redraw timer bar at new cursor position
	LD	A,(XBDF2)	; bf43  3a f2 bd	A = previous input state
	RRA			; bf46  1f		Rotate fire bit (bit 0) into carry
	RET	NC		; bf47  d0		If fire not pressed, return (carry clear)
; --- Fire pressed: find which segment is highlighted ---
	LD	HL,(XBDF4)	; bf48  2a f4 bd	HL = segment table pointer
	LD	DE,X0003	; bf4b  11 03 00	DE = 3 (bytes per segment entry)
	LD	C,0		; bf4e  0e 00		C = segment index counter
XBF50:	LD	A,(HL)		; bf50  7e		A = segment byte 0 (X + flags)
	CP	0FFH		; bf51  fe ff		End of table?
	RET	Z		; bf53  c8		If end, return (no highlighted segment found)
	JP	M,XBF5B		; bf54  fa 5b bf	If bit 7 set (highlighted), found it!
	ADD	HL,DE		; bf57  19		Skip to next segment entry (+3 bytes)
	INC	C		; bf58  0c		Increment segment index
	JR	XBF50		; bf59  18 f5		Continue searching
;
XBF5B:	LD	A,C		; bf5b  79		A = index of highlighted segment
	LD	(XBDF6),A	; bf5c  32 f6 bd	Store selected segment index
	SCF			; bf5f  37		Set carry flag: selection made
	RET			; bf60  c9		Return with carry set
;
; ==========================================================================
; MENU_CLEANUP ($BF61)
; ==========================================================================
; Resets menu display after a selection: redraws timer bar, resets all
; segment highlights to default, and plays a confirmation sound.
; ==========================================================================
XBF61:	LD	C,80H		; bf61  0e 80		C = $80 (draw mode)
	CALL	XBDF7		; bf63  cd f7 bd	Draw timer bar to screen
	LD	BC,X8080	; bf66  01 80 80	BC = ($80, $80) — trigger all-reset at impossible position
	CALL	XBD9C		; bf69  cd 9c bd	Process segments: all will un-highlight (position out of range)
	CALL	XBB11		; bf6c  cd 11 bb	Play confirmation sound effect
	RET			; bf6f  c9		Return
;

; ==========================================================================
; DRAW_BORDERED_RECT ($BF70)
; ==========================================================================
; Draws a popup rectangle overlay on screen with a 1-pixel-wide border.
; Saves all original screen content (bitmap + attributes) to a buffer so
; the overlay can be removed later by RESTORE_BORDERED_RECT.
;
; The rectangle is drawn as:
;   Top row:    $FF $FF $FF ... $FF   (solid horizontal line)
;   Middle rows: $80 $00 $00 ... $01  (left border, clear interior, right border)
;   Bottom row:  $FF $FF $FF ... $FF  (solid horizontal line)
; Attribute memory is filled with the processed color attribute.
;
; Entry: A = color info (passed to PROCESS_ATTR_COLOR)
;        B = top row (character cell Y, 0-23)
;        C = left column (byte X position, 0-31)
;        D = height (in character cells)
;        E = width (in bytes)
; Uses:  XC0BD = pointer to overlay metadata/save buffer
;        XC0B7 = overlay count (incremented)
; ==========================================================================
DRAW_BORDERED_RECT:	CALL	PROCESS_ATTR_COLOR		; bf70  cd 07 bc	Convert color → ZX attribute byte
	LD	(XC0B8),A	; bf73  32 b8 c0	Store processed attribute color
	LD	(XC0B9),BC	; bf76  ed 43 b9 c0	Store top row (B) and left column (C)
	LD	(XC0BB),DE	; bf7a  ed 53 bb c0	Store height (D) and width (E)
; --- Compute IX = pointer into ROW_PTR_TABLE for top pixel row ---
	LD	A,B		; bf7e  78		A = top row (char cells)
	RLA			; bf7f  17		\
	RLA			; bf80  17		 | A = top_row * 8 (char row → pixel row)
	RLA			; bf81  17		/
	AND	0F8H		; bf82  e6 f8		Mask to clean multiple of 8
	LD	C,A		; bf84  4f		BC = pixel row offset
	LD	B,0		; bf85  06 00		  (B=0, C=pixel_row)
	LD	IX,ROW_PTR_TABLE	; bf87  dd 21 00 fc	IX = base of row pointer table ($FC00)
	ADD	IX,BC		; bf8b  dd 09		IX += pixel_row * 2 (word entries)
	ADD	IX,BC		; bf8d  dd 09		IX now points to screen addr for top pixel row
; --- Compute B = number of middle pixel rows, C = width ---
	LD	A,D		; bf8f  7a		A = height (char cells)
	RLA			; bf90  17		\
	RLA			; bf91  17		 | A = height * 8 (total pixel rows)
	RLA			; bf92  17		/
	AND	0F8H		; bf93  e6 f8		Mask to clean multiple of 8
	SUB	2		; bf95  d6 02		Subtract 2 for top+bottom border rows
	LD	B,A		; bf97  47		B = middle row count (height*8 - 2)
	LD	C,E		; bf98  4b		C = width (bytes)
; --- Load save buffer pointer ---
	LD	HL,(XC0BD)	; bf99  2a bd c0	HL = overlay metadata pointer
	LD	E,(HL)		; bf9c  5e		\  DE = save buffer destination address
	INC	HL		; bf9d  23		 | (first word in metadata = save area ptr)
	LD	D,(HL)		; bf9e  56		/
; --- Compute HL = screen address for top-left pixel ---
	LD	A,(XC0B9)	; bf9f  3a b9 c0	A = left column (byte position)
	ADD	A,(IX+0)	; bfa2  dd 86 00	Add low byte of screen row address
	LD	L,A		; bfa5  6f		L = screen addr low byte
	INC	IX		; bfa6  dd 23		Advance IX to high byte
	LD	H,(IX+0)	; bfa8  dd 66 00	H = screen addr high byte
	INC	IX		; bfab  dd 23		Advance IX to next row entry
; === TOP BORDER ROW: draw solid line ($FF) ===
	PUSH	BC		; bfad  c5		Save middle_count / width
	LD	B,C		; bfae  41		B = width (byte count)
XBFAF:	LD	A,(HL)		; bfaf  7e		Read original screen byte
	LD	(DE),A		; bfb0  12		Save to buffer
	LD	(HL),0FFH	; bfb1  36 ff		Write $FF = solid horizontal line
	INC	HL		; bfb3  23		Next screen byte
	INC	DE		; bfb4  13		Next buffer position
	DJNZ	XBFAF		; bfb5  10 f8		Loop across width
	POP	BC		; bfb7  c1		Restore B=middle_count, C=width
; === MIDDLE ROWS: left border + clear interior + right border ===
XBFB8:	PUSH	BC		; bfb8  c5		Save middle_count / width
	LD	B,C		; bfb9  41		B = width
	DEC	B		; bfba  05		\  B = width - 2 (interior column count,
	DEC	B		; bfbb  05		/  excluding left and right border bytes)
; --- Compute screen address for this row ---
	LD	A,(XC0B9)	; bfbc  3a b9 c0	A = left column
	ADD	A,(IX+0)	; bfbf  dd 86 00	Add low byte of screen row address
	LD	L,A		; bfc2  6f		L = screen addr low
	INC	IX		; bfc3  dd 23		Advance to high byte
	LD	H,(IX+0)	; bfc5  dd 66 00	H = screen addr high
	INC	IX		; bfc8  dd 23		Advance IX to next row
; --- Left border byte ---
	LD	A,(HL)		; bfca  7e		Read original screen byte
	LD	(DE),A		; bfcb  12		Save to buffer
	LD	(HL),80H	; bfcc  36 80		Write $80 = 10000000b (left edge pixel)
	INC	HL		; bfce  23		Next screen byte
	INC	DE		; bfcf  13		Next buffer position
; --- Interior bytes (cleared to 0) ---
XBFD0:	LD	A,(HL)		; bfd0  7e		Read original screen byte
	LD	(DE),A		; bfd1  12		Save to buffer
	LD	(HL),0		; bfd2  36 00		Write $00 = clear interior
	INC	HL		; bfd4  23		Next screen byte
	INC	DE		; bfd5  13		Next buffer position
	DJNZ	XBFD0		; bfd6  10 f8		Loop for interior columns
; --- Right border byte ---
	LD	A,(HL)		; bfd8  7e		Read original screen byte
	LD	(DE),A		; bfd9  12		Save to buffer
	LD	(HL),1		; bfda  36 01		Write $01 = 00000001b (right edge pixel)
	INC	DE		; bfdc  13		Next buffer position
	POP	BC		; bfdd  c1		Restore B=middle_count, C=width
	DJNZ	XBFB8		; bfde  10 d8		Loop for all middle pixel rows
; === BOTTOM BORDER ROW: draw solid line ($FF) ===
	LD	A,(XC0B9)	; bfe0  3a b9 c0	A = left column
	ADD	A,(IX+0)	; bfe3  dd 86 00	Add low byte of screen row address
	LD	L,A		; bfe6  6f		L = screen addr low
	INC	IX		; bfe7  dd 23		Advance to high byte
	LD	H,(IX+0)	; bfe9  dd 66 00	H = screen addr high
	LD	B,C		; bfec  41		B = width (byte count)
XBFED:	LD	A,(HL)		; bfed  7e		Read original screen byte
	LD	(DE),A		; bfee  12		Save to buffer
XBFEF:	LD	(HL),0FFH	; bfef  36 ff		Write $FF = solid horizontal line
	INC	HL		; bff1  23		Next screen byte
	INC	DE		; bff2  13		Next buffer position
	DJNZ	XBFED		; bff3  10 f8		Loop across width
; === ATTRIBUTE FILL: set color for the entire rectangle ===
; Compute HL = attribute address for top-left cell ($5800 + row*32 + col)
	LD	BC,(XC0B9)	; bff5  ed 4b b9 c0	Reload C=left_column, B=top_row
	LD	L,B		; bff9  68		L = top row
	LD	H,0		; bffa  26 00		HL = top row (16-bit)
	ADD	HL,HL		; bffc  29		\
	ADD	HL,HL		; bffd  29		 |
XBFFE:	ADD	HL,HL		; bffe  29		 | HL = top_row * 32
	ADD	HL,HL		; bfff  29		 |
	ADD	HL,HL		; c000  29		/
	LD	B,58H		; c001  06 58		B = $58 (attr memory base high byte)
	ADD	HL,BC		; c003  09		HL = $5800 + top_row*32 + left_column
	LD	BC,(XC0BB)	; c004  ed 4b bb c0	Reload B=height, C=width
; --- Fill attribute rows ---
XC008:	PUSH	BC		; c008  c5		Save height / width
	PUSH	HL		; c009  e5		Save attribute row base address
	LD	B,C		; c00a  41		B = width (columns to fill)
	LD	A,(XC0B8)	; c00b  3a b8 c0	A = processed color attribute
	LD	C,A		; c00e  4f		C = attribute byte (for inner loop)
XC00F:	LD	A,(HL)		; c00f  7e		Read original attribute
	LD	(DE),A		; c010  12		Save to buffer
	LD	(HL),C		; c011  71		Write new attribute color
	INC	HL		; c012  23		Next attribute cell
	INC	DE		; c013  13		Next buffer position
	DJNZ	XC00F		; c014  10 f9		Loop across width
	POP	HL		; c016  e1		Restore attribute row base
	LD	BC,X0020	; c017  01 20 00	BC = 32 (bytes per attribute row)
	ADD	HL,BC		; c01a  09		HL = next attribute row
	POP	BC		; c01b  c1		Restore B=height, C=width
	DJNZ	XC008		; c01c  10 ea		Loop for all character rows
; === UPDATE OVERLAY METADATA STRUCTURE ===
; Format at (XC0BD): [save_ptr(2)] [col(1)] [row(1)] [width(1)] [height(1)] → next entry
	LD	HL,(XC0BD)	; c01e  2a bd c0	HL = current overlay metadata pointer
	INC	HL		; c021  23		Skip past the 2-byte save area pointer
	INC	HL		; c022  23		  (we already read it at start)
	LD	BC,(XC0B9)	; c023  ed 4b b9 c0	C=left_column, B=top_row
	LD	(HL),C		; c027  71		Store left column
	INC	HL		; c028  23		.
	LD	(HL),B		; c029  70		Store top row
	INC	HL		; c02a  23		.
	LD	BC,(XC0BB)	; c02b  ed 4b bb c0	C=width, B=height
	LD	(HL),C		; c02f  71		Store width
	INC	HL		; c030  23		.
	LD	(HL),B		; c031  70		Store height
	INC	HL		; c032  23		.
; --- Advance metadata pointer to next entry ---
	LD	(XC0BD),HL	; c033  22 bd c0	Update metadata pointer to next entry
	LD	(HL),E		; c036  73		Store low byte of current save buffer pos
	INC	HL		; c037  23		  (becomes save_ptr for NEXT overlay)
	LD	(HL),D		; c038  72		Store high byte of save buffer position
; --- Increment overlay counter ---
	LD	HL,XC0B7	; c039  21 b7 c0	HL = overlay count variable
	INC	(HL)		; c03c  34		Increment: one more overlay active
	RET			; c03d  c9		Return
;
