; ==========================================================================
; MENU SYSTEM & STARTUP CODE ($B100-$BA67)
; ==========================================================================
;
; The SNA snapshot's return address is $B134 (MENU_LOOP), the main menu
; animation loop. The menu system handles:
;   - Title screen display and animation
;   - Main menu with 5 options (New Game, Scores, Keys, Setup, Freebie)
;   - Setup submenu (Sound, Colour, Inverse Screen, Custom game, Chasers, Timer)
;   - Keys submenu (Alter Keys, 3 joystick presets)
;   - High score display and name entry
;   - Key redefinition by scanning individual keypresses
;
; --------------------------------------------------------------------------
; ROUTINE INDEX
; --------------------------------------------------------------------------
;   $B100  STARTUP_INIT      ISR setup (IM2), initial display, wait for input
;   $B134  MENU_LOOP         Title screen animation loop (color cycling)
;   $B1B0  TITLE_ANIMATE     Draw animated shapes on title screen (XOR sprites)
;   $B26E  READ_MENU_INPUT   Read keyboard/joystick for menu control
;   $B2A3  SHOW_MAIN_MENU    Draw main menu popup, handle selection via jump table
;   $B378  CLEAR_AND_DRAW_HUD  Clear screen, draw HUD borders and labels
;   $B4FC  CHECK_HIGH_SCORE  Check if current score qualifies for high score table
;   $B5C6  NAME_ENTRY_LOOP   On-screen keyboard for entering high score name
;   $B686  REDRAW_NAME       Redisplay entered name string
;   $B68D  DRAW_NAME_CURSOR  Show cursor at current name position
;   $B79A  DISPLAY_SETUP_OPTIONS  Show setup Yes/No toggles
;   $B7CE  DISPLAY_TIMER_SPEED    Show timer speed (Fast/Med/Slow)
;   $B7E9  SETUP_MENU_LOOP   Handle setup menu selections
;   $B943  KEYS_MENU_LOOP    Handle keys menu selections
;   $B9FD  CLEAR_KEY_DISPLAY Clear key binding display lines
;   $BA14  SHOW_KEY_BINDINGS Display current 5 key bindings
;   $BA35  SCAN_SINGLE_KEY   Wait for and identify a single keypress
;
; --------------------------------------------------------------------------
; DATA SECTIONS
; --------------------------------------------------------------------------
;   $B192  "Press N, Space or Fire." string
;   $B1AF  Animation frame counter
;   $B214  Animation shape data (6 shapes x 9 bytes)
;   $B24D  Random position table (16 entries x 2 bytes: X, Y)
;   $B294  Control mapping presets (Kempston, Sinclair, Protek: 5 bytes each)
;   $B2D5  Main menu handler jump table (5 entries x 2 bytes)
;   $B2F4  Main menu display strings ("Options:", "New Game", etc.)
;   $B337  Main menu segment table (16 bytes)
;   $B347  HUD string data for score/status display
;   $B3E1  Name entry cursor string
;   $B3E6  Name entry buffer (14 bytes max)
;   $B3F4  Name entry length counter
;   $B3F5  "A New High Score" display string
;   $B437  "High Scores" display string
;   $B698  "Setup Menu" display string
;   $B75E  Setup menu segment table
;   $B862  "Keys Menu" display string
;   $B914  Blank string (10 spaces) for clearing key display
;   $B91F  Keys menu segment table
; --------------------------------------------------------------------------
;

; ==========================================================================
; STARTUP_INIT ($B100)
; ==========================================================================
; Initialization code (entry is at $B0FC, first 4 bytes on previous page).
; Detects joystick hardware, sets up IM2 interrupt service routine, clears
; border, displays "Press N, Space or Fire" prompt, and waits for input.
; ==========================================================================
	CP	0FFH		; b101  fe ff		Joystick port returns $FF?
	JR	Z,XB10C		; b103  28 07		If yes, no Kempston joystick
	DEC	HL		; b105  2b		Decrement probe counter
	LD	A,H		; b106  7c		\  Check if counter reached 0
	OR	L		; b107  b5		/
	JR	NZ,XB0FC	; b108  20 f2		Loop back to retry probe (on prev page)
	LD	E,0FFH		; b10a  1e ff		No joystick detected: E=$FF
XB10C:	LD	A,E		; b10c  7b		A = joystick detection result
	LD	(XB26D),A	; b10d  32 6d b2	Store joystick presence flag
; --- Set up IM2 interrupt handler ---
	DI			; b110  f3		Disable interrupts
	LD	A,0C3H		; b111  3e c3		A = $C3 (JP opcode)
	LD	(XFDFD),A	; b113  32 fd fd	Write JP instruction at $FDFD
	LD	HL,XBB51	; b116  21 51 bb	HL = ISR handler address
	LD	(XFDFE),HL	; b119  22 fe fd	Store ISR target after JP opcode
	LD	A,0FEH		; b11c  3e fe		A = $FE (interrupt vector table page)
	LD	I,A		; b11e  ed 47		I register = $FE (vector table at $FE00)
	IM	2		; b120  ed 5e		Switch to interrupt mode 2
	EI			; b122  fb		Re-enable interrupts
; --- Display initial prompt and wait for input ---
	XOR	A		; b123  af		A = 0
	OUT	(0FEH),A	; b124  d3 fe		Set border to black (ULA port)
	LD	HL,XB192	; b126  21 92 b1	HL = "Press N, Space or Fire." string
	CALL	STRING_RENDERER		; b129  cd 26 bc	Display prompt
XB12C:	CALL	XB26E		; b12c  cd 6e b2	Read menu input
	LD	A,E		; b12f  7b		A = input result
	OR	A		; b130  b7		Any button pressed?
	JR	NZ,XB12C	; b131  20 f9		Wait until all buttons released
XB133:	HALT			; b133  76		Wait for next frame (VSYNC)
;

; ==========================================================================
; MENU_LOOP ($B134) — SNA return address
; ==========================================================================
; Main title screen animation loop. Cycles attribute colors on the title
; area every frame, draws animated shapes, and polls for input. The color
; cycles through INK 1-7 with BRIGHT on a 56-frame period.
;
; Input result bits: 0=N key, 1=Space, 2=Joystick fire
; ==========================================================================
MENU_LOOP:
	CALL	XB1B0		; b134  cd b0 b1	Animate title screen shapes
	LD	HL,XB1AF	; b137  21 af b1	HL = animation frame counter
	INC	(HL)		; b13a  34		Increment frame counter
	LD	A,(HL)		; b13b  7e		A = frame counter
	CP	38H		; b13c  fe 38		Reached 56 (7 colors * 8 frames)?
	JR	C,XB142		; b13e  38 02		If not, keep current value
	LD	A,0		; b140  3e 00		Reset to 0 (wrap around)
XB142:	LD	(HL),A		; b142  77		Store updated counter
	SRL	A		; b143  cb 3f		\
	SRL	A		; b145  cb 3f		 | A = counter / 8 (0-6, color index)
	SRL	A		; b147  cb 3f		/
	INC	A		; b149  3c		A = 1-7 (INK color, skip black)
	OR	40H		; b14a  f6 40		Set BRIGHT bit → attribute byte
	LD	BC,X1700	; b14c  01 00 17	BC: row=0, col=$17=23 (right side)
	LD	DE,X0120	; b14f  11 20 01	DE: height=1, width=$20=32
	CALL	FILL_ATTR_RECT		; b152  cd f6 ba	Fill title area with cycling color
	CALL	XB26E		; b155  cd 6e b2	Read menu input
	LD	A,E		; b158  7b		A = input result
	CP	1		; b159  fe 01		N key pressed?
	JP	Z,XB16A		; b15b  ca 6a b1	→ handle selection
	CP	2		; b15e  fe 02		Space pressed?
	JP	Z,XB16A		; b160  ca 6a b1	→ handle selection
	CP	4		; b163  fe 04		Joystick fire pressed?
	JP	Z,XB16A		; b165  ca 6a b1	→ handle selection
	JR	XB133		; b168  18 c9		Loop: HALT then animate again
;
; --- Handle menu selection: load control mapping based on input method ---
; Bit 0 = N key (keyboard), Bit 1 = Space (Sinclair joystick), Bit 2 = fire (Kempston)
XB16A:	LD	HL,XB294	; b16a  21 94 b2	HL = Kempston joystick key mapping
	BIT	0,E		; b16d  cb 43		Was N (keyboard) pressed?
	JR	NZ,XB17B	; b16f  20 0a		If yes, skip to load (uses keyboard mapping at $B294)
	LD	HL,XB299	; b171  21 99 b2	HL = Sinclair joystick key mapping
	BIT	1,E		; b174  cb 4b		Was Space pressed?
	JR	NZ,XB17B	; b176  20 03		If yes, use Sinclair mapping
	LD	HL,XB29E	; b178  21 9e b2	HL = Protek joystick key mapping
; --- Copy 5-byte control mapping to both active and default key tables ---
XB17B:	LD	B,5		; b17b  06 05		B = 5 keys to copy (L,R,U,D,Fire)
	LD	DE,XBACE	; b17d  11 ce ba	DE = active key mapping table
	LD	IX,XBAE2	; b180  dd 21 e2 ba	IX = default key mapping table (for Break reset)
XB184:	LD	A,(HL)		; b184  7e		Read key code from preset
	LD	(DE),A		; b185  12		Store in active mapping
	LD	(IX+0),A	; b186  dd 77 00	Store in default mapping
	INC	HL		; b189  23		Next source byte
	INC	DE		; b18a  13		Next active table entry
	INC	IX		; b18b  dd 23		Next default table entry
	DJNZ	XB184		; b18d  10 f5		Loop for all 5 keys
	JP	XB2A3		; b18f  c3 a3 b2	Jump to main menu display
;
; --- String data: initial prompt ---
XB192:	DB	1EH,47H		; b192		Control: set attribute to $47 (white INK on black, BRIGHT)
	DB	1FH,3AH,17H		; b194		Control: set cursor position X=$3A, Y=$17
	DB	'Press N, Space or Fire.'		; b197
	DB	0					; b1ae	String terminator
; --- Animation state ---
XB1AF:	DB	35H			; b1af		Animation frame counter (0-55, cycling)
;
; ==========================================================================
; TITLE_ANIMATE ($B1B0)
; ==========================================================================
; Animates shapes on the title screen. Uses a countdown timer that controls
; shape progression (6 animation phases). When all phases complete, picks
; a random new position from a 16-entry table and restarts.
;
; The shape data at $B214 contains 6 shapes x 9 bytes each. Each shape is
; XOR-drawn onto the screen at the position stored at $B24B-$B24C, using
; the ROW_PTR_TABLE for screen address lookup.
; ==========================================================================
XB1B0:	LD	HL,XB24A	; b1b0  21 4a b2	HL = animation timer
	DEC	(HL)		; b1b3  35		Decrement timer
	LD	A,(HL)		; b1b4  7e		A = current timer value
	AND	7		; b1b5  e6 07		Only act every 8 frames
	RET	NZ		; b1b7  c0		Return if not on 8-frame boundary
	LD	A,(HL)		; b1b8  7e		A = timer value again
	SRL	A		; b1b9  cb 3f		\
	SRL	A		; b1bb  cb 3f		 | A = timer / 8 = animation phase (0-5, then 6+)
	SRL	A		; b1bd  cb 3f		/
	CP	6		; b1bf  fe 06		Phase < 6?
	JR	C,XB1DD		; b1c1  38 1a		If yes, draw shape for this phase
	CP	1FH		; b1c3  fe 1f		Phase = 31 (timer fully expired)?
	RET	NZ		; b1c5  c0		If not, idle (gap between animations)
; --- Animation cycle complete: pick random new position ---
	LD	(HL),38H	; b1c6  36 38		Reset timer to 56 (7 phases * 8 frames)
	CALL	PRNG		; b1c8  cd e4 d3	Get pseudo-random number
	AND	0FH		; b1cb  e6 0f		Mask to 0-15 (16 positions)
	ADD	A,A		; b1cd  87		Double for 2-byte table entries
	LD	E,A		; b1ce  5f		\  DE = table offset
	LD	D,0		; b1cf  16 00		/
	LD	HL,XB24D	; b1d1  21 4d b2	HL = random position table base
	ADD	HL,DE		; b1d4  19		HL = selected position entry
	LD	DE,XB24B	; b1d5  11 4b b2	DE = current animation X,Y storage
	LDI			; b1d8  ed a0		Copy X byte
	LDI			; b1da  ed a0		Copy Y byte
	RET			; b1dc  c9		Return
;
; --- Draw shape for current animation phase ---
XB1DD:	LD	C,A		; b1dd  4f		C = phase number
	ADD	A,A		; b1de  87		A = phase * 2
	ADD	A,C		; b1df  81		A = phase * 3
	LD	C,A		; b1e0  4f		C = phase * 3
	ADD	A,A		; b1e1  87		A = phase * 6
	ADD	A,C		; b1e2  81		A = phase * 9 (9 bytes per shape)
	LD	E,A		; b1e3  5f		\  DE = offset into shape data
	LD	D,0		; b1e4  16 00		/
	LD	HL,XB214	; b1e6  21 14 b2	HL = shape data table base
	ADD	HL,DE		; b1e9  19		HL = pointer to this phase's shape data
; --- Look up screen address from Y position ---
	LD	A,(XB24C)	; b1ea  3a 4c b2	A = current Y pixel position
	ADD	A,A		; b1ed  87		A = Y * 2 (word index into ROW_PTR_TABLE)
	LD	E,A		; b1ee  5f		\  DE = Y * 2 (with carry into D)
	LD	A,0		; b1ef  3e 00		|
	ADC	A,0		; b1f1  ce 00		|
	LD	D,A		; b1f3  57		/
	LD	IX,ROW_PTR_TABLE	; b1f4  dd 21 00 fc	IX = row pointer table ($FC00)
	ADD	IX,DE		; b1f8  dd 19		IX = screen addr entry for row Y
	EX	DE,HL		; b1fa  eb		DE = shape data, HL = free
; --- XOR-draw 9 rows of 1-byte-wide shape ---
	LD	A,(XB24B)	; b1fb  3a 4b b2	A = current X byte position
	LD	C,A		; b1fe  4f		C = X offset within screen row
	LD	B,9		; b1ff  06 09		B = 9 pixel rows to draw
XB201:	LD	A,C		; b201  79		A = X byte offset
	ADD	A,(IX+0)	; b202  dd 86 00	Add screen row low byte
	LD	L,A		; b205  6f		L = screen addr low
	LD	H,(IX+1)	; b206  dd 66 01	H = screen addr high
	LD	A,(DE)		; b209  1a		A = shape data byte
	XOR	(HL)		; b20a  ae		XOR with existing screen content
	LD	(HL),A		; b20b  77		Write back (toggle pixels)
	INC	DE		; b20c  13		Next shape data byte
	INC	IX		; b20d  dd 23		\  Advance to next row in ROW_PTR_TABLE
	INC	IX		; b20f  dd 23		/  (2 bytes per entry)
	DJNZ	XB201		; b211  10 ee		Loop for 9 rows
	RET			; b213  c9		Return
;
; --- Animation shape data: 6 shapes x 9 bytes each ---
; Each shape is a 1-byte-wide x 9-row-tall XOR pattern for title screen animation.
; The shapes form an expanding/contracting diamond or cross pattern.
XB214:	DB	00H					; b214  Shape 0 (single dot)
;
	ORG	0B218H
;
	DB	04H					; b218  Shape 1 (small cross)
;
	ORG	0B220H
;
	DB	0EH,0AH,0EH				; b220  Shape 2 (ring)
;
	ORG	0B226H
;
	DB	04H,04H,15H,00H,11H,00H,15H,04H		; b226  Shape 3 (larger diamond)
	DB	04H,04H,04H,15H,00H,11H,00H		; b22e  Shape 4 (expanded diamond)
;
	DB	15H,04H,04H				; b235  Shape 5 (final expanded)
	DB	00H,00H,00H				; b238   (blank rows)
	DB	0EH,0AH					; b23b   (ring fragment)
	DB	0EH,00H					; b23d   (fading out)
;
	ORG	0B245H
;
	DB	04H					; b245  (ending dot)
;
	ORG	0B24AH
;
; --- Animation state variables ---
XB24A:	DB	0AH			; b24a  Animation countdown timer
XB24B:	DB	1BH			; b24b  Current X byte position
XB24C:	DB	34H			; b24c  Current Y pixel row
; --- Random position table: 16 entries of (X_byte, Y_pixel) ---
XB24D:	DB	00H,1CH		; b24d  Position 0:  X=0,  Y=28
	DB	01H,1CH		; b24f  Position 1:  X=1,  Y=28
	DB	05H,2BH		; b251  Position 2:  X=5,  Y=43
	DB	04H,34H		; b253  Position 3:  X=4,  Y=52
	DB	06H,4CH		; b255  Position 4:  X=6,  Y=76
	DB	0CH,4CH		; b257  Position 5:  X=12, Y=76
	DB	0FH,1CH		; b259  Position 6:  X=15, Y=28
	DB	12H,1CH		; b25b  Position 7:  X=18, Y=28
	DB	15H,0CH		; b25d  Position 8:  X=21, Y=12
	DB	19H,14H		; b25f  Position 9:  X=25, Y=20
	DB	1CH,04H		; b261  Position 10: X=28, Y=4
	DB	1EH,1CH		; b263  Position 11: X=30, Y=28
	DB	1FH,2CH		; b265  Position 12: X=31, Y=44
	DB	1BH,34H		; b267  Position 13: X=27, Y=52
	DB	16H,3CH		; b269  Position 14: X=22, Y=60
	DB	11H,3CH		; b26b  Position 15: X=17, Y=60
; --- Joystick detection flag ---
XB26D:	DB	0FFH			; b26d  $FF=no Kempston, $00=Kempston present
;
; ==========================================================================
; READ_MENU_INPUT ($B26E)
; ==========================================================================
; Reads keyboard and optional Kempston joystick for menu control.
; Returns: E = input bits (bit 0=N key, bit 1=Space, bit 2=Joystick fire)
; ==========================================================================
XB26E:	LD	E,0		; b26e  1e 00		E = 0 (no input)
	LD	HL,XB26D	; b270  21 6d b2	HL = joystick detection flag
	BIT	0,(HL)		; b273  cb 46		Kempston present? (flag bit 0 = 0 if present)
	JR	Z,XB281		; b275  28 0a		Skip joystick read if not present
; --- Read Kempston joystick port ---
	LD	BC,X001F	; b277  01 1f 00	BC = Kempston joystick port ($001F)
	IN	A,(C)		; b27a  ed 78		Read joystick state
	RRA			; b27c  1f		\  Shift fire button (bit 4) down
	RRA			; b27d  1f		/  to bit 2
	AND	4		; b27e  e6 04		Isolate fire bit only
	LD	E,A		; b280  5f		E = bit 2 set if fire pressed
; --- Read keyboard half-row $7FFE (B,N,M,Symbol,Space) ---
XB281:	LD	BC,X7FFE	; b281  01 fe 7f	BC = keyboard port for B-Space row
	IN	A,(C)		; b284  ed 78		Read keyboard row
	CPL			; b286  2f		Invert: now 1=pressed, 0=not pressed
	BIT	0,A		; b287  cb 47		Space pressed? (bit 0)
	JR	Z,XB28D		; b289  28 02		Skip if not
	SET	1,E		; b28b  cb cb		Set bit 1 in result: Space
XB28D:	BIT	3,A		; b28d  cb 5f		N pressed? (bit 3)
	JR	Z,XB293		; b28f  28 02		Skip if not
	SET	0,E		; b291  cb c3		Set bit 0 in result: N key
XB293:	RET			; b293  c9		Return (E = input bits)
;
; --- Control mapping presets: 5 bytes each (Left, Right, Up, Down, Fire) ---
; Values are keyboard scan codes used by READ_KEYBOARD routine.
XB294:	DB	29H,28H,11H,1AH,3BH	; b294  Kempston defaults:  Q,W,O,P,Space
XB299:	DB	29H,28H,11H,1AH	; b299  Sinclair joystick:  Q,W,O,P,
	DB	38H			; b29d    key code $38 (8 = fire)
Xb29e:	DB	41H,40H,43H,42H,44H	; b29e  Protek joystick: key codes
;
; ==========================================================================
; SHOW_MAIN_MENU ($B2A3)
; ==========================================================================
; Clears the screen, draws HUD, then shows the main menu popup with 5
; options. Polls for selection via timer bar cursor, then dispatches to
; the selected handler via a jump table.
; ==========================================================================
XB2A3:	CALL	XB378		; b2a3  cd 78 b3	Clear screen and draw HUD
XB2A6:	LD	BC,X050A	; b2a6  01 0a 05	B=row 5, C=col 10
	LD	DE,X0D0C	; b2a9  11 0c 0d	D=height 13, E=width 12
	LD	A,68H		; b2ac  3e 68		A = color $68 (bright, cyan paper, black ink)
	CALL	DRAW_BORDERED_RECT		; b2ae  cd 70 bf	Draw menu popup box
	LD	HL,XB2F4	; b2b1  21 f4 b2	HL = menu text string data
	CALL	STRING_RENDERER		; b2b4  cd 26 bc	Render "Options:", "New Game", etc.
; --- Menu selection loop ---
XB2B7:	LD	HL,XB337	; b2b7  21 37 b3	HL = menu segment table
	CALL	XBF18		; b2ba  cd 18 bf	Initialize menu cursor with segments
XB2BD:	CALL	XBF3A		; b2bd  cd 3a bf	Poll keyboard + move cursor
	JR	NC,XB2BD	; b2c0  30 fb		Loop until fire pressed (carry set)
	CALL	XBF61		; b2c2  cd 61 bf	Clean up menu highlights + play sound
; --- Dispatch to selected handler via jump table ---
	LD	A,(XBDF6)	; b2c5  3a f6 bd	A = selected segment index
	ADD	A,A		; b2c8  87		A = index * 2 (word offset)
	LD	E,A		; b2c9  5f		\  DE = offset into jump table
	LD	D,0		; b2ca  16 00		/
	LD	HL,XB2D5	; b2cc  21 d5 b2	HL = handler jump table base
	ADD	HL,DE		; b2cf  19		HL = address of handler pointer
	LD	E,(HL)		; b2d0  5e		\  DE = handler address
	INC	HL		; b2d1  23		|
	LD	D,(HL)		; b2d2  56		/
	EX	DE,HL		; b2d3  eb		HL = handler address
	JP	(HL)		; b2d4  e9		Jump to selected handler
;
; --- Main menu handler jump table ---
; 5 entries x 2 bytes: addresses for New Game, Scores, Keys, Setup, Freebie
XB2D5:	DW	XB2DF		; b2d5  Handler 0: New Game ($B2DF)
	DW	XB42F		; b2d7  Handler 1: Scores  ($B42F)  [approximate - mixed code/data]
	DW	XB989		; b2d9  Handler 2: Keys    ($B989)  [approximate]
	DW	XB7E8		; b2db  Handler 3: Setup   ($B7E8)  [approximate]
	DW	XB2CD		; b2dd  Handler 4: Freebie ($B2CD)  [approximate]
;
; NOTE: The bytes from $B2DF to $B2F3 contain the "New Game" handler and
; related code, but the disassembler has partially decoded them as mixed
; code and data. The handler at $B2DF calls RESTORE_RECT ($C03E) then
; jumps to the game initialization at $C371.
;
	DB	3EH,0C0H		; b2df  (LD A,$C0)
	DB	0CDH,71H,0C3H		; b2e1  (CALL $C371) — not cleanly decoded
	DB	0C3H			; b2e4
	DB	0A6H			; b2e5
	DB	0B2H			; b2e6
	DB	0CDH			; b2e7
;
	DB	3EH,0C0H		; b2e9
	DB	0CDH,37H		; b2eb
	DB	0D4H,0CDH		; b2ed
	DB	78H			; b2ef
	DB	0B3H,0C3H		; b2f0
;
	DB	0A6H			; b2f2
;
	DB	0B2H			; b2f3
; --- Main menu display string data ---
; Uses STRING_RENDERER control codes: $1E=set attr, $1F=set cursor, $1D=horiz line
XB2F4:	DB	1EH,0E8H	; b2f4  Set attribute: bright, yellow paper
	DB	1FH,50H		; b2f6  Set cursor position
;
	DB	05H			; b2f8  (control code)
	DB	'~~Options:'		; b2f9  Title with decorative ~~ prefix
	DB	1DH			; b303  Draw horizontal rule
	DB	7EH,7EH,7EH		; b304  Tilde decoration
	DB	1EH,68H			; b307  Set attribute: bright, cyan paper
	DB	1FH,60H			; b309  Set cursor position
	DB	08H			; b30b  (control code)
	DB	'New Game'		; b30c  Option 0
	DB	1FH,60H,0AH		; b314  Set cursor for next line
	DB	'Scores'		; b317  Option 1
	DB	1FH,60H,0CH		; b31d  Set cursor for next line
	DB	'Keys'			; b320  Option 2
	DB	1FH,60H,0EH		; b324  Set cursor for next line
	DB	'Setup'			; b327  Option 3
	DB	1FH,60H,10H		; b32c  Set cursor for next line
	DB	'Freebie'		; b32f  Option 4
	DB	0			; b336  String terminator
; --- Main menu segment table ---
; Format: pairs of (X_start, X_end) for each selectable option row, $FF=end
XB337:	DB	0AH,08H,0CH,0AH	; b337  Segment 0: New Game row
	DB	0AH,0CH,0AH,0CH	; b33b  Segment 1: Scores row
	DB	0CH,0AH,0EH,0CH	; b33f  Segment 2: Keys row
	DB	0AH,10H,0CH,0FFH	; b343  Segments 3-4: Setup, Freebie; $FF=end
;
; --- HUD string data: score labels and status display ---
XB347:	DB	00H			; b347  (padding/data)
;
	ORG	0B349H
;
	DB	0CH,0DH,0EH,0FH,10H,0AH,00H		; b349  HUD label string data
;
	ORG	0B354H
;
	DB	0AH,0AH,0AH,11H,10H,12H,10H,13H		; b354 ........
	DB	0AH,0,0,0AH,0AH,0AH,11H,14H		; b35c ........
	DB	12H,10H,15H,0AH,0			; b364 .....
	DW	X00FF		; b369   ff 00      ..
;
	DB	2,16H,14H,17H,10H			; b36b .....
	DW	X1CFF		; b370   ff 1c      ..
;
	DB	2					; b372 .
;
	ORG	0B376H
;
	DB	0BH,0FFH				; b376 ..
;
; ==========================================================================
; CLEAR_AND_DRAW_HUD ($B378)
; ==========================================================================
; Clears the entire screen bitmap, draws HUD labels using the double-height
; font, resets timer state, and fills attribute areas with game colors.
; ==========================================================================
XB378:	LD	HL,X4000	; b378  21 00 40	HL = screen bitmap start ($4000)
	LD	(HL),0		; b37b  36 00		Clear first byte
	LD	DE,X4001	; b37d  11 01 40	DE = $4001
	LD	BC,X182F	; b380  01 2f 18	BC = 6191 bytes (full bitmap $4000-$57FF)
	LDIR			; b383  ed b0		Fill entire screen bitmap with 0
; --- Draw HUD text labels ---
	LD	HL,XB347	; b385  21 47 b3	HL = HUD string data (score area)
	CALL	HUD_STRING_RENDER		; b388  cd 6e d3	Render score labels
	LD	HL,XB36A	; b38b  21 6a b3	HL = HUD string data (lives/level)
	CALL	HUD_STRING_RENDER		; b38e  cd 6e d3	Render game info labels
	LD	HL,XB371	; b391  21 71 b3	HL = HUD string data (timer area)
	CALL	HUD_STRING_RENDER		; b394  cd 6e d3	Render timer labels
; --- Reset timer state ---
	XOR	A		; b397  af		A = 0
	LD	(TIMER_BAR_POS),A	; b398  32 bf b0	Reset timer bar position
	LD	(GAME_TIMER),A	; b39b  32 c0 b0	Reset game timer
; --- Fill attribute areas with game colors ---
XB39E:	LD	BC,X0000	; b39e  01 00 00	B=row 0, C=col 0
	LD	DE,X0420	; b3a1  11 20 04	D=height 4, E=width 32
	LD	A,45H		; b3a4  3e 45		A = $45 (cyan INK on black, BRIGHT)
	CALL	PROCESS_ATTR_COLOR		; b3a6  cd 07 bc	Process color for inverse mode
	CALL	FILL_ATTR_RECT		; b3a9  cd f6 ba	Fill top HUD area (rows 0-3)
	LD	BC,X021C	; b3ac  01 1c 02	B=row 28, C=col 2
	LD	DE,X0204	; b3af  11 04 02	D=height 2, E=width 4
	LD	A,47H		; b3b2  3e 47		A = $47 (white INK on black, BRIGHT)
	CALL	PROCESS_ATTR_COLOR		; b3b4  cd 07 bc	Process color
	CALL	FILL_ATTR_RECT		; b3b7  cd f6 ba	Fill lives/level display area
	LD	BC,X0400	; b3ba  01 00 04	B=row 0, C=col 4
	LD	DE,X1420	; b3bd  11 20 14	D=height 20, E=width 32
	LD	A,(FIELD_COLOR)	; b3c0  3a ec b0	A = current field color
	CALL	PROCESS_ATTR_COLOR		; b3c3  cd 07 bc	Process color
	CALL	FILL_ATTR_RECT		; b3c6  cd f6 ba	Fill main game field area
; --- Timer bar color: green if timer low, red if high ---
	LD	A,(TIMER_BAR_POS)	; b3c9  3a bf b0	A = timer bar position
	CP	28H		; b3cc  fe 28		Position >= 40?
	LD	A,44H		; b3ce  3e 44		A = $44 (green INK, default)
	JR	NC,XB3D4	; b3d0  30 02		If high, use green
	LD	A,42H		; b3d2  3e 42		A = $42 (red INK) — timer running low
XB3D4:	CALL	PROCESS_ATTR_COLOR		; b3d4  cd 07 bc	Process color
	LD	BC,X0205	; b3d7  01 05 02	B=row 5, C=col 2
	LD	DE,X0216	; b3da  11 16 02	D=height 2, E=width 22
	CALL	FILL_ATTR_RECT		; b3dd  cd f6 ba	Fill timer bar area
	RET			; b3e0  c9		Return
;
; --- Name entry cursor display string ---
XB3E1:	DB	1FH,10H,0EH	; b3e1  Set cursor X=$10, Y=$0E
	DB	3EH		; b3e4  (control code)
	DB	7EH		; b3e5  '~' character (cursor indicator)
;
; --- Name entry buffer: up to 13 chars + null terminator ---
XB3E6:	DB	00H		; b3e6  Name buffer (zeroed = empty)
;
	ORG	0B3F4H
;
; --- Name entry length counter ---
XB3F4:	DB	00H		; b3f4  Current name length (0-13)
;
; --- "A New High Score" popup string ---
XB3F5:	DB	1EH,0E8H	; b3f5  Set attribute: bright, yellow paper
	DB	1FH		; b3f7  Set cursor position
	DB	08H,0AH,1CH,04H	; b3f8  Cursor coords + control
	DB	'~A New High Score'	; b3fc  Title with ~ decoration
	DB	1DH,1CH,04H,7EH	; b40d  Horizontal rule + tilde
	DB	1EH,68H			; b411  Set attribute: bright cyan paper
	DB	1FH,70H			; b413  Set cursor position
	DB	14H			; b415  (control code)
	DB	98H,99H,9AH,9BH,9CH,9DH	; b416  Score digit placeholders
	DB	1FH,10H,0CH		; b41c  Set cursor position
	DB	'Please Enter Your Name'	; b41f  Prompt text
	DB	00H			; b435  String terminator
; --- "High Scores" display string ---
	DB	1EH,0E8H		; b436  Set attribute: bright, yellow paper
	DB	1FH			; b438  Set cursor position
	DB	08H,07H,1CH,06H	; b439  Cursor coords
	DB	'~High Scores'		; b43d  Title
	DB	1DH,1CH,06H,7EH	; b449  Horizontal rule + tilde
	DB	1EH,68H			; b44d  Set attribute: bright cyan paper
	DB	1FH,1CH			; b44f  Set cursor position
	DB	15H			; b451  (control code)
	DB	'Return to Main Menu'	; b452  Return option text
	DB	00H			; b465  String terminator
; --- Game type label strings ---
	DB	1FH,28H,08H		; b466  Set cursor position
	DB	'(Standard Game)'	; b469  Standard game label
	DB	00H			; b478  String terminator
	DB	1FH,28H,08H		; b479  Set cursor position
	DB	'(Customized Game)'	; b47c  Customized game label
	DB	00H			; b48d  String terminator
; --- Score table configuration ---
	DB	01H,15H,15H		; b48e  Table display parameters
	DW	X01FF		; b491  End marker
;
; --- High score display and entry handler code ---
; This section contains mixed code/data that handles displaying score tables,
; checking if the player's score qualifies, and entering names. The disassembler
; could not cleanly separate code from inline data here.
	DB	01H,07H,11H,15H,10H,3EH,68H		; b493  Setup for bordered rect
	DB	0CDH,70H,0BFH				; b49a  CALL DRAW_BORDERED_RECT
	DB	21H,0BFH				; b49d  LD HL,...
	DB	36H					; b49f  (data)
	DB	0B4H,0CDH				; b4a0
	DB	26H					; b4a2
	DB	0BCH,3AH				; b4a3
	DB	0F0H,0B0H				; b4a5
;
	DB	21H,66H					; b4a7
	DB	0B4H,0CBH				; b4a9
;
	DB	7FH,28H,03H,21H,79H			; b4ab
	DB	0B4H,0CDH				; b4b0
;
	DB	26H,0BCH,06H,0AH,21H,8DH,0C1H,3AH	; b4b2
	DB	0F0H,0B0H,0CBH,7FH,28H,04H,11H,0AAH	; b4ba
	DB	00H,19H,3EH,14H			; b4c2
; --- Score table display loop (mixed code/data) ---
; Loops through score entries, renders each with STRING_RENDERER, handles
; the menu segment selection, then returns to main menu.
XB4C5:	DB	90H,0DDH,77H,01H,0DDH,36H,00H,10H	; b4c5  SUB B; LD (IX+1),A; LD (IX+0),$10
	DB	0E5H,0CDH,26H,0BCH,0E1H,11H,0FH,00H	; b4cd  PUSH HL; CALL STRING_RENDERER; POP HL; LD DE,$000F
	DB	19H,0DDH,36H,00H,80H,0C5H,5EH,23H	; b4d5  ADD HL,DE; LD (IX+0),$80; PUSH BC; LD E,(HL); INC HL
	DB	56H,23H,0E5H,0EBH,0CDH,0D8H,0BBH,0E1H	; b4dd  LD D,(HL); INC HL; PUSH HL; EX DE,HL; CALL NUM_TO_DIGITS; POP HL
	DB	0C1H,10H,0DBH,21H,8EH,0B4H,0CDH,18H	; b4e5  POP BC; DJNZ loop; LD HL,$B48E; CALL MENU_INIT
	DB	0BFH,0CDH,3AH,0BFH,30H,0FBH,0CDH,61H	; b4ed  CALL MENU_FIRE_HANDLER; JR NC,-5; CALL MENU_CLEANUP
	DB	0BFH,0CDH,3EH,0C0H,0C3H,0B7H,0B2H	; b4f5  CALL RESTORE_RECT; JP SHOW_MAIN_MENU
;
; ==========================================================================
; CHECK_HIGH_SCORE ($B4FC)
; ==========================================================================
; Checks if the current score (BASE_SCORE) qualifies for the high score
; table. Iterates through 10 entries, each 17 bytes apart. If game is
; customized (bit 7 of $B0F0), uses the second score table (+$AA offset).
;
; Each entry: 15 bytes name + 2 bytes score (at offset $0F-$10)
; Returns: B = position (0-9) where score fits, or B=0 if doesn't qualify
; ==========================================================================
XB4FC:	LD	IX,XC18D	; b4fc  dd 21 8d c1	IX = high score table base
	LD	B,0AH		; b500  06 0a		B = 10 entries to check
	LD	A,(XB0F0)	; b502  3a f0 b0	A = game mode flags
	BIT	7,A		; b505  cb 7f		Customized game?
	JR	Z,XB50E		; b507  28 05		If standard, skip offset
	LD	DE,X00AA	; b509  11 aa 00	DE = $AA (170 = 10 entries * 17 bytes)
	ADD	IX,DE		; b50c  dd 19		IX = second table (customized scores)
XB50E:	LD	L,(IX+0FH)	; b50e  dd 6e 0f	L = score low byte (offset 15)
	LD	H,(IX+10H)	; b511  dd 66 10	H = score high byte (offset 16)
	LD	DE,(BASE_SCORE)	; b514  ed 5b c3 b0	DE = current player score
	OR	A		; b518  b7		Clear carry
;
	DB	0EDH,52H	; b519			SBC HL,DE — compare table score vs player score
;
	DB	38H,08H		; b51b			JR C,+8 — if table < player, score qualifies
	DB	11H,11H,00H	; b51d			LD DE,$0011 (17 bytes per entry)
;
	ADD	IX,DE		; b520  dd 19		Advance to next table entry
	DJNZ	XB50E		; b522  10 ea		Loop through all 10 entries
	RET			; b524  c9		Return (B=0: didn't qualify)
;
; --- High score save and name entry handler (mixed code/data $B525-$B5C0) ---
; This block handles:
;   - Shifting existing score entries down to make room for new high score
;   - Copying the entered name from buffer ($B3E6) to the score table
;   - Storing the player's score (BASE_SCORE) into the table entry
;   - Drawing the "New High Score" popup and initiating name entry
;   - Name entry rendering with on-screen keyboard grid
;
; The disassembler could not cleanly decode this section because code and
; inline data are interleaved. Key operations identified:
;   $B568: LD HL,$C18D — load high score table base
;   $B577: Copy 15 bytes from name buffer to score table entry (LDIR)
;   $B585: Store BASE_SCORE in table entry
;
	DB	0C5H,05H				; b525
	DB	28H,1EH,78H,87H,87H,87H,87H,80H	; b527
	DB	4FH,06H,00H,21H,36H,0C2H,3AH		; b52f
	DB	0F0H,0B0H				; b536
	DB	0CBH,7FH				; b538
	DB	28H,04H,11H,0AAH,00H,19H		; b53a
	DB	0EBH,21H				; b540
	DB	0EFH,0FFH				; b542
	DB	19H					; b544
	DB	0EDH,0B8H				; b545
	DB	01H,01H,0AH,11H,15H,0CH,3EH,68H	; b547
	DB	0CDH,70H				; b54f
	DB	0BFH,21H				; b551
	DB	0F5H,0B3H				; b553
	DB	0CDH,26H				; b555
	DB	0BCH,0CDH				; b557
	DB	8CH					; b559
	DB	0B5H,0C1H				; b55a
	DB	3EH,0AH,90H,47H,87H,87H,87H,87H	; b55c
	DB	80H,5FH,16H,00H			; b564
;
; --- Copy entered name to high score table ---
	LD	HL,XC18D	; b568  21 8d c1	HL = score table base
	ADD	HL,DE		; b56b  19		HL = target entry
	LD	A,(XB0F0)	; b56c  3a f0 b0	A = game mode flags
	BIT	7,A		; b56f  cb 7f		Customized game?
	JR	Z,XB577		; b571  28 04		If standard, skip offset
	LD	DE,X00AA	; b573  11 aa 00	DE = $AA (second table offset)
	ADD	HL,DE		; b576  19		Adjust to customized table
XB577:	EX	DE,HL		; b577  eb		DE = target entry in table
	LD	HL,XB3E6	; b578  21 e6 b3	HL = name entry buffer
	LD	BC,X000F	; b57b  01 0f 00	BC = 15 bytes (name field length)
	LDIR			; b57e  ed b0		Copy name to score table
	EX	DE,HL		; b580  eb		HL = next byte after name in table
	LD	DE,(BASE_SCORE)	; b581  ed 5b c3 b0	DE = player's score
	LD	(HL),E		; b585  73		Store score low byte
;
; --- Continuation of score save + name entry rendering (mixed) ---
	DB	23H,72H					; b586  INC HL; LD (HL),D — store score high
	DB	0CDH,3EH				; b588  CALL RESTORE_RECT ($C03E)
	DB	0C0H					; b58a
	DB	0C9H,0DDH				; b58b
	DB	21H,0A9H				; b58d
	DB	0BCH,0EH				; b58f
	DB	41H,21H,14H,10H,06H,0AH,22H,0A9H	; b591
	DB	0BCH,79H				; b599
	DB	0FEH,5BH				; b59b
	DB	30H,10H,0CDH				; b59d
	DB	0B5H,0BCH				; b5a0
	DB	7DH					; b5a2
	DB	0C6H,10H				; b5a3
	DB	6FH,0CH,10H				; b5a5
	DB	0EEH,24H				; b5a8
	DB	24H,2EH,14H,18H,0E6H,0AFH,32H,0F4H	; b5aa
	DB	0B3H,21H,0E6H,0B3H,36H,00H		; b5b2
	DB	0CDH,86H				; b5b8
	DB	0B6H,0CDH				; b5ba
	DB	8DH,0B6H,0EH,00H,0CDH			; b5bc
;
; --- End of mixed code/data block ---
	DB	0F7H		; b5c1  (RST 30H — actually part of name entry cleanup)
	DB	0BDH		; b5c2  (data)
	CALL	XBE41		; b5c3  cd 41 be	Restore timer bar row
; ==========================================================================
; NAME_ENTRY_LOOP ($B5C6)
; ==========================================================================
; On-screen keyboard for high score name entry. Displays a 3x10 character
; grid (A-Z plus special keys). Player navigates with game keys, fire to
; select. Uses the timer bar as a visual keyboard grid indicator.
;
; Grid layout: 3 rows x 10 columns, characters A-Z, then Delete ($1B)
; and Enter ($1C). Grid coordinates mapped from timer bar cursor position.
; ==========================================================================
XB5C6:	CALL	XBEBA		; b5c6  cd ba be	Read keyboard + move menu cursor
	LD	HL,XBB4F	; b5c9  21 4f bb	HL = ISR flag byte
	SET	7,(HL)		; b5cc  cb fe		Request ISR processing
XB5CE:	BIT	7,(HL)		; b5ce  cb 7e		ISR done yet?
	JR	NZ,XB5CE	; b5d0  20 fc		Wait for ISR to clear flag
	LD	C,80H		; b5d2  0e 80		C = $80 (draw mode)
	CALL	XBDF7		; b5d4  cd f7 bd	Draw timer bar (shows keyboard grid)
	LD	HL,(XBDF0)	; b5d7  2a f0 bd	HL = cursor X,Y position
	LD	(XBDEE),HL	; b5da  22 ee bd	Save as previous position
	LD	C,0		; b5dd  0e 00		C = 0 (erase mode)
	CALL	XBDF7		; b5df  cd f7 bd	Erase timer bar (will be redrawn next)
	CALL	XBE41		; b5e2  cd 41 be	Restore timer bar pixels from backup
; --- Check if fire was pressed ---
	LD	A,(XBDF2)	; b5e5  3a f2 bd	A = input state
	RRC	A		; b5e8  cb 0f		Rotate fire bit into carry
	JR	NC,XB5C6	; b5ea  30 da		If no fire, loop back
; --- Convert cursor position to grid row/column ---
	LD	BC,(XBDEE)	; b5ec  ed 4b ee bd	B=cursor X, C=cursor Y
	LD	A,B		; b5f0  78		A = cursor X position
	SUB	7CH		; b5f1  d6 7c		Subtract grid left edge offset
	JR	C,XB5C6		; b5f3  38 d1		If left of grid, ignore
	SRL	A		; b5f5  cb 3f		\
	SRL	A		; b5f7  cb 3f		 | A = (X - $7C) / 16 = grid row (0-2)
	SRL	A		; b5f9  cb 3f		 |
	SRL	A		; b5fb  cb 3f		/
	CP	3		; b5fd  fe 03		Row >= 3?
	JR	NC,XB5C6	; b5ff  30 c5		If out of range, ignore
	LD	B,A		; b601  47		B = grid row (0-2)
	LD	A,C		; b602  79		A = cursor Y position
	SUB	10H		; b603  d6 10		Subtract grid top offset
	JR	C,XB5C6		; b605  38 bf		If above grid, ignore
	SRL	A		; b607  cb 3f		\
	SRL	A		; b609  cb 3f		 | A = (Y - $10) / 16 = grid column (0-9)
	SRL	A		; b60b  cb 3f		 |
	SRL	A		; b60d  cb 3f		/
	CP	0AH		; b60f  fe 0a		Column >= 10?
	JR	NC,XB5C6	; b611  30 b3		If out of range, ignore
; --- Convert row/column to character index ---
	LD	C,A		; b613  4f		C = column (0-9)
	LD	A,B		; b614  78		A = row (0-2)
	ADD	A,A		; b615  87		\
	ADD	A,A		; b616  87		 | A = row * 10
	ADD	A,B		; b617  80		 | (row*4 + row = row*5)
	ADD	A,A		; b618  87		 | (row*5 * 2 = row*10)
	ADD	A,C		; b619  81		/  A = row*10 + column = char index (0-29)
	CP	1DH		; b61a  fe 1d		Index >= 29?
	JR	NC,XB5C6	; b61c  30 a8		If beyond valid range, ignore
; --- Dispatch based on character index ---
	CP	1CH		; b61e  fe 1c		Index 28 = Enter?
	JR	Z,XB67A		; b620  28 58		→ handle Enter (accept name)
	CP	1BH		; b622  fe 1b		Index 27 = Delete?
	JR	Z,XB654		; b624  28 2e		→ handle Delete (backspace)
	CP	1AH		; b626  fe 1a		Index 26 = Space? (after Z)
	JR	NZ,XB62C	; b628  20 02		If not space, it's A-Z
	LD	A,0DFH		; b62a  3e df		Remap: $DF + $41 = $20 = ASCII space
; --- Add character to name ---
XB62C:	ADD	A,41H		; b62c  c6 41		A = index + $41 = ASCII character (A=$41, B=$42...)
	LD	C,A		; b62e  4f		C = character to add
	LD	A,(XB3F4)	; b62f  3a f4 b3	A = current name length
	CP	0DH		; b632  fe 0d		Already 13 chars (max)?
	JR	NC,XB5C6	; b634  30 90		If full, ignore keypress
	LD	E,A		; b636  5f		\  DE = name length (offset)
	LD	D,0		; b637  16 00		/
	INC	A		; b639  3c		Increment length
	LD	(XB3F4),A	; b63a  32 f4 b3	Store new length
	LD	HL,XB3E6	; b63d  21 e6 b3	HL = name buffer
	ADD	HL,DE		; b640  19		HL = position for new char
	LD	(HL),C		; b641  71		Store character
	INC	HL		; b642  23		Next position
	LD	(HL),0		; b643  36 00		Null-terminate string
	CALL	XB686		; b645  cd 86 b6	Redraw name display
	CALL	XB68D		; b648  cd 8d b6	Draw cursor after name
	CALL	XBB11		; b64b  cd 11 bb	Play keypress sound
	CALL	XBAA9		; b64e  cd a9 ba	Wait for fire release
	JP	XB5C6		; b651  c3 c6 b5	Loop back to keyboard
;
; --- Handle Delete (backspace) ---
XB654:	LD	A,(XB3F4)	; b654  3a f4 b3	A = current name length
	OR	A		; b657  b7		Is name empty?
	JP	Z,XB5C6		; b658  ca c6 b5	If empty, can't delete — loop back
	DEC	A		; b65b  3d		Decrement length
	LD	(XB3F4),A	; b65c  32 f4 b3	Store new length
	LD	E,A		; b65f  5f		\  DE = new length (offset)
	LD	D,0		; b660  16 00		/
	LD	HL,XB3E6	; b662  21 e6 b3	HL = name buffer
	ADD	HL,DE		; b665  19		HL = position of deleted char
	LD	(HL),0		; b666  36 00		Replace with null terminator
	LD	(XB3F4),A	; b668  32 f4 b3	(redundant store of same length)
	CALL	XB686		; b66b  cd 86 b6	Redraw name display
	CALL	XB68D		; b66e  cd 8d b6	Draw cursor at new position
	CALL	XBB11		; b671  cd 11 bb	Play keypress sound
	CALL	XBAA9		; b674  cd a9 ba	Wait for fire release
	JP	XB5C6		; b677  c3 c6 b5	Loop back to keyboard
;
; --- Handle Enter (accept name) ---
XB67A:	CALL	XB686		; b67a  cd 86 b6	Redraw name one final time
	LD	A,7EH		; b67d  3e 7e		A = '~' (tilde = end marker char)
	CALL	XBCB5		; b67f  cd b5 bc	Render end-of-name marker
	CALL	XBB11		; b682  cd 11 bb	Play confirmation sound
	RET			; b685  c9		Return (name entry complete)
;
; --- REDRAW_NAME ($B686): display current name string ---
XB686:	LD	HL,XB3E1	; b686  21 e1 b3	HL = name display string (with cursor prefix)
	CALL	STRING_RENDERER		; b689  cd 26 bc	Render name at cursor position
	RET			; b68c  c9		Return
;
; --- DRAW_NAME_CURSOR ($B68D): show cursor after name ---
XB68D:	LD	A,7FH		; b68d  3e 7f		A = $7F (filled block = cursor)
	CALL	XBCB5		; b68f  cd b5 bc	Render cursor block
	LD	A,7EH		; b692  3e 7e		A = '~' (tilde = boundary marker)
	CALL	XBCB5		; b694  cd b5 bc	Render after cursor
	RET			; b697  c9		Return
;
; --- Setup menu display string data ---
	DB	1EH,0E8H		; b698  Set attribute: bright yellow paper
	DB	1FH			; b69a  Set cursor position
	DB	40H,05H,1CH,06H	; b69b  Cursor coords + control
	DB	'~Setup Menu'		; b69f  Title with ~ decoration
	DB	1DH,1CH,08H,7EH	; b6aa  Horizontal rule + tilde
	DB	1EH,68H			; b6ae  Set attribute: bright cyan paper
	DB	1FH,48H			; b6b0  Set cursor position
	DB	07H			; b6b2  (control code)
	DB	'Sound'			; b6b3  "Sound" label
	DB	1FH,0AAH		; b6b8  Set cursor position
	DB	07H			; b6ba  (control code)
	DB	'Yes'			; b6bb  "Yes" option
	DB	1FH,0D8H		; b6be  Set cursor position
	DB	07H			; b6c0  (control code)
	DB	'No'			; b6c1  "No" option
	DB	1FH,48H,09H		; b6c3  Set cursor position
	DB	'Colou'			; b6c6  "Colour" label (split)
Xb6cb:	DB	'r'			; b6cb  (continued)
	DB	1FH			; b6cc  Set cursor position
;
; (Continuation of setup menu strings — "Colour" Yes/No options and remaining items)
	DB	0AAH,09H		; b6cd  Set cursor for Yes/No
	DB	'Yes'			; b6cf  "Yes" option
	DB	1FH,0D8H		; b6d2  Set cursor position
	DB	09H			; b6d4  (control code)
	DB	'No'			; b6d5  "No" option
	DB	1FH,48H			; b6d7  Set cursor position
;
	DB	0BH			; b6d9  (control code)
	DB	'Inverse Screen'	; b6da  "Inverse Screen" label
	DB	1FH,0AAH,0BH		; b6e8  Cursor + control
	DB	'Yes'			; b6eb  "Yes" option
	DB	1FH,0D8H		; b6ee  Set cursor position
	DB	0BH			; b6f0  (control code)
	DB	'No'			; b6f1  "No" option
	DB	1FH,48H,0DH		; b6f3  Set cursor position
	DB	'Customize game'	; b6f6  "Customize game" label
	DB	1FH,0AAH,0DH		; b704  Cursor + control
	DB	'Yes'			; b707  "Yes" option
	DB	1FH,0D8H		; b70a  Set cursor position
	DB	0DH			; b70c  (control code)
	DB	'No'			; b70d  "No" option
	DB	1FH,48H,0FH		; b70f  Set cursor position
	DB	'Chasers'		; b712  "Chasers" label
	DB	1FH,0AAH,0FH		; b719  Cursor + control
	DB	'Yes'			; b71c  "Yes" option
	DB	1FH			; b71f  Set cursor position
;
	DB	0D8H,0FH		; b720  Cursor position
	DB	'No'			; b722  "No" option
	DB	1FH,48H			; b724  Set cursor position
;
	DB	11H			; b726  (control code)
	DB	'Timer Speed:'		; b727  "Timer Speed" label
	DB	1FH,48H,13H		; b733  Set cursor
	DB	'Fast'			; b736  "Fast" option
	DB	1FH,88H,13H		; b73a  Set cursor
	DB	'Med'			; b73d  "Med" option
	DB	1FH,0C8H,13H		; b740  Set cursor
;
	DB	'Slow'			; b743  "Slow" option
	DB	1FH,48H,15H		; b747  Set cursor position
	DB	'Return to Main Menu'	; b74a  Return option
	DB	00H			; b75d  String terminator
; --- Setup menu segment table ---
; Format: groups of 3 bytes (X_start, Y_row, flags) defining selectable segments
; Each row has two segments (Yes/No), plus timer speed (3 segments) and Return
XB75E:	DB	18H,07H,02H	; b75e  Sound: Yes segment
	DB	1DH,07H,02H	; b761  Sound: No segment
	DB	18H,09H,02H	; b764  Colour: Yes
	DB	1DH,09H,02H	; b767  Colour: No
	DB	18H,0BH,02H	; b76a  Inverse: Yes
	DB	1DH,0BH,02H	; b76d  Inverse: No
	DB	18H,0DH,02H	; b770  Customize: Yes
	DB	1DH,0DH,02H	; b773  Customize: No
	DB	18H,0FH,02H	; b776  Chasers: Yes
	DB	1DH,0FH,02H	; b779  Chasers: No
	DB	0DH,13H,02H	; b77c  Timer: Fast
	DB	15H,13H,02H	; b77f  Timer: Med
	DB	1DH,13H,02H	; b782  Timer: Slow
	DB	08H,15H,17H	; b785  Return to Main Menu
	DB	0FFH		; b788  End marker
	DB	01H		; b789  (padding)
;
; --- Setup menu init code (mixed code/data) ---
; Draws bordered rect, renders setup menu string, then falls through to
; DISPLAY_SETUP_OPTIONS to show current Yes/No states.
	DB	08H,05H,11H,17H,12H	; b78a  Params for bordered rect: row=5, col=$11, h=$17, w=$12
	DB	3EH,68H			; b78f  LD A,$68 (bright cyan paper)
	DB	0CDH,70H,0BFH		; b791  CALL DRAW_BORDERED_RECT
	DB	21H,98H,0B6H		; b794  LD HL,$B698 (setup menu string)
	DB	0CDH,26H,0BCH		; b797  CALL STRING_RENDERER
;
; ==========================================================================
; DISPLAY_SETUP_OPTIONS ($B79A)
; ==========================================================================
; Renders the current state of the 5 setup options (Sound, Colour, Inverse,
; Customize, Chasers) as highlighted Yes/No indicators. Uses RENDER_CHAR
; to draw special indicator characters at computed positions.
;
; Option flags are stored at $B0ED (5 bytes, one per option):
;   0=No (bit 0 clear), $FF=Yes (bit 0 set)
; ==========================================================================
XB79A:	LD	B,5		; b79a  06 05		B = 5 options to display
	LD	HL,XB0ED	; b79c  21 ed b0	HL = option flags array
	LD	IX,XBCA9	; b79f  dd 21 a9 bc	IX = cursor state (for positioning)
XB7A3:	LD	A,B		; b7a3  78		A = loop counter (5→1)
	ADD	A,A		; b7a4  87		A = counter * 2
	NEG			; b7a5  ed 44		A = -(counter * 2)
	ADD	A,11H		; b7a7  c6 11		A = $11 - counter*2 = Y row for this option
	LD	(XBCAA),A	; b7a9  32 aa bc	Set cursor Y position
	LD	(IX+0),0C4H	; b7ac  dd 36 00 c4	Set cursor X to $C4 (Yes column)
	LD	A,9EH		; b7b0  3e 9e		A = $9E (unchecked indicator char)
	BIT	0,(HL)		; b7b2  cb 46		Option enabled? (bit 0)
	JR	Z,XB7B7		; b7b4  28 01		If no, keep unchecked char
	INC	A		; b7b6  3c		A = $9F (checked indicator char)
XB7B7:	PUSH	AF		; b7b7  f5		Save indicator state
	CALL	XBCB5		; b7b8  cd b5 bc	Render Yes indicator character
	LD	(IX+0),0ECH	; b7bb  dd 36 00 ec	Set cursor X to $EC (No column)
	POP	AF		; b7bf  f1		Restore indicator
	NEG			; b7c0  ed 44		Invert: checked↔unchecked
	ADD	A,3DH		; b7c2  c6 3d		A = $3D - indicator = opposite state
	CALL	XBCB5		; b7c4  cd b5 bc	Render No indicator character
	INC	HL		; b7c7  23		Next option flag
	DJNZ	XB7A3		; b7c8  10 d9		Loop for all 5 options
	LD	(IX+1),13H	; b7ca  dd 36 01 13	Set cursor Y to $13 (timer speed row)
; ==========================================================================
; DISPLAY_TIMER_SPEED ($B7CE)
; ==========================================================================
; Shows which of the 3 timer speeds (Fast/Med/Slow) is selected, using
; indicator characters. The speed index is stored at $B0F2 (0-2).
; ==========================================================================
XB7CE:	LD	B,3		; b7ce  06 03		B = 3 speed options
XB7D0:	LD	A,3		; b7d0  3e 03		A = 3
	SUB	B		; b7d2  90		A = 3 - counter = speed index (0,1,2)
	LD	C,A		; b7d3  4f		C = speed index
	RRCA			; b7d4  0f		\  Compute X position: index * 64 + $6C
	RRCA			; b7d5  0f		/  (RRCA rotates right through carry)
	ADD	A,6CH		; b7d6  c6 6c		A = X position for this speed option
	LD	(IX+0),A	; b7d8  dd 77 00	Set cursor X position
	LD	A,(XB0F2)	; b7db  3a f2 b0	A = currently selected speed (0-2)
	CP	C		; b7de  b9		Is this the selected speed?
	LD	A,9EH		; b7df  3e 9e		A = $9E (unchecked indicator)
	JR	NZ,XB7E4	; b7e1  20 01		If not selected, keep unchecked
	INC	A		; b7e3  3c		A = $9F (checked indicator)
XB7E4:	CALL	XBCB5		; b7e4  cd b5 bc	Render speed indicator character
	DJNZ	XB7D0		; b7e7  10 e7		Loop for all 3 speeds
; ==========================================================================
; SETUP_MENU_LOOP ($B7E9)
; ==========================================================================
; Main selection loop for the setup menu. Initializes menu cursor with the
; segment table, polls for selection, then dispatches based on which
; segment was highlighted when fire was pressed.
;
; Segments 0-9: Yes/No toggles for 5 options (pairs)
; Segments 10-12: Timer speed (Fast/Med/Slow)
; Segment 13: Return to Main Menu
; ==========================================================================
XB7E9:	LD	HL,XB75E	; b7e9  21 5e b7	HL = setup menu segment table
	CALL	XBF18		; b7ec  cd 18 bf	Initialize menu cursor
XB7EF:	CALL	XBF3A		; b7ef  cd 3a bf	Poll keyboard + move cursor
	JR	NC,XB7EF	; b7f2  30 fb		Loop until fire pressed
	CALL	XBF61		; b7f4  cd 61 bf	Clean up highlights + play sound
	LD	A,(XBDF6)	; b7f7  3a f6 bd	A = selected segment index
	CP	0AH		; b7fa  fe 0a		Segment >= 10? (timer speed or return)
	JR	NC,XB838	; b7fc  30 3a		→ handle timer/return
	CP	8		; b7fe  fe 08		Segment >= 8? (Chasers Yes/No)
	JR	C,XB809		; b800  38 07		If < 8, toggle directly
; --- Chasers option requires "Customize game" to be enabled ---
	LD	HL,XB0F0	; b802  21 f0 b0	HL = game mode flags
	BIT	0,(HL)		; b805  cb 46		Customize enabled?
	JR	Z,XB7E9		; b807  28 e0		If not, ignore and restart loop
; --- Toggle the selected Yes/No option ---
XB809:	LD	E,A		; b809  5f		E = segment index
	SRL	E		; b80a  cb 3b		E = index / 2 = option number (0-4)
	LD	D,0		; b80c  16 00		\  DE = option number
	LD	HL,XB0ED	; b80e  21 ed b0	HL = option flags base
	ADD	HL,DE		; b811  19		HL = pointer to this option's flag
	RRCA			; b812  0f		Carry = bit 0 of segment (0=Yes, 1=No)
	CCF			; b813  3f		Invert carry: Yes→set, No→clear
	SBC	A,A		; b814  9f		A = $FF if Yes selected, $00 if No
	LD	(HL),A		; b815  77		Store option state
; --- Special handling when Customize option was toggled ---
	LD	A,(XBDF6)	; b816  3a f6 bd	A = segment that was selected
	CP	6		; b819  fe 06		Was it Customize Yes (segment 6)?
	JP	C,XB79A		; b81b  da 9a b7	If earlier option, just redisplay
	CP	8		; b81e  fe 08		Was it Customize No (segment 7)?
	JP	NC,XB79A	; b820  d2 9a b7	If later option, just redisplay
; --- Swap Chasers+Timer settings when toggling Customize ---
; Swaps 2 bytes between $B0F1-F2 and $B0F3-F4 to save/restore custom settings
	LD	HL,XB0F3	; b823  21 f3 b0	HL = saved custom settings
	LD	DE,XB0F1	; b826  11 f1 b0	DE = active settings
	LD	B,2		; b829  06 02		B = 2 bytes to swap
XB82B:	LD	C,(HL)		; b82b  4e		C = saved value
	LD	A,(DE)		; b82c  1a		A = active value
	EX	DE,HL		; b82d  eb		\  Swap: write saved→active, active→saved
	LD	(HL),C		; b82e  71		|
	LD	(DE),A		; b82f  12		/
	EX	DE,HL		; b830  eb		Restore HL/DE order
	INC	HL		; b831  23		Next byte
	INC	DE		; b832  13		Next byte
	DJNZ	XB82B		; b833  10 f6		Loop for 2 bytes
	JP	XB79A		; b835  c3 9a b7	Redisplay all options
;
; --- Handle timer speed or return to main menu ---
XB838:	CP	0DH		; b838  fe 0d		Segment 13? (Return)
	JR	NC,XB84C	; b83a  30 10		If Return, exit setup
; --- Timer speed selected (segments 10-12) ---
	LD	HL,XB0F0	; b83c  21 f0 b0	HL = game mode flags
	BIT	0,(HL)		; b83f  cb 46		Customize enabled?
	JP	Z,XB7E9		; b841  ca e9 b7	If not, ignore timer change
	SUB	0AH		; b844  d6 0a		A = segment - 10 = speed index (0-2)
	LD	(XB0F2),A	; b846  32 f2 b0	Store selected speed index
	JP	XB79A		; b849  c3 9a b7	Redisplay all options
;
; --- Return to Main Menu: clean up and apply settings ---
XB84C:	CALL	RESTORE_RECT		; b84c  cd 3e c0	Remove setup menu popup
	CALL	RESTORE_RECT		; b84f  cd 3e c0	Remove outer popup
	CALL	XB39E		; b852  cd 9e b3	Redraw HUD attribute areas
; --- Convert speed index (0-2) to timer speed value ---
	LD	A,(XB0F2)	; b855  3a f2 b0	A = speed index (0=Fast, 1=Med, 2=Slow)
	ADD	A,A		; b858  87		\
	ADD	A,A		; b859  87		/  A = index * 4
	ADD	A,0AH		; b85a  c6 0a		A = index * 4 + 10 (Fast=10, Med=14, Slow=18)
	LD	(TIMER_SPEED),A	; b85c  32 ea b0	Store computed timer speed
	JP	XB2A6		; b85f  c3 a6 b2	Return to main menu display
;
; --- Keys menu display string data ---
	DB	1EH,0E8H		; b862  Set attribute: bright yellow paper
	DB	1FH			; b864  Set cursor position
	DB	08H,07H,1CH,03H	; b865  Cursor coords + control
	DB	'~Keys Menu'		; b869  Title
	DB	1DH,1CH,09H,7EH	; b873  Horizontal rule
	DB	1EH,68H			; b877  Set attribute: bright cyan paper
	DB	1FH,20H,0FH		; b879  Set cursor position
	DB	'Alter Keys'		; b87c  Option 0
	DB	1FH,20H,10H		; b886  Set cursor position
	DB	'Kempston Joystick'	; b889  Option 1
	DB	1FH,20H,11H		; b89a  Set cursor position
	DB	'Sinclair Joystick'	; b89d  Option 2
	DB	1FH,20H,12H		; b8ae  Set cursor position
	DB	'Protek Joystick'	; b8b1  Option 3
	DB	1FH,20H,13H		; b8c0  Set cursor position
	DB	'Return to Main Menu'	; b8c3  Option 4
; --- Key binding display labels ---
	DB	1FH,28H,09H		; b8d6  Set cursor position
	DB	'Left'			; b8d9  "Left" label
	DB	1FH,28H,0AH		; b8dd  Set cursor position
	DB	'Rig'			; b8e0  "Right" label (split)
Xb8e3:	DB	'ht'			; b8e3  (continued)
	DB	1FH,28H,0BH		; b8e5  Set cursor position
	DB	'Up'			; b8e8  "Up" label
	DB	1FH,28H,0CH		; b8ea  Set cursor position
XB8ED:	DB	'Down'			; b8ed  "Down" label
	DB	1FH,28H,0DH		; b8f1  Set cursor position
	DB	'Fire'			; b8f4  "Fire" label
	DB	1FH,0CH,15H		; b8f8  Set cursor position
	DB	'(Break for default keys)'	; b8fb  Help text
	DB	00H			; b913  String terminator
; --- Blank string for clearing key display ---
Xb914:	DB	'          '		; b914  10 spaces (clears key name field)
	DB	00H			; b91e  String terminator
; --- Keys menu segment table ---
XB91F:	DB	01H,0FH,14H	; b91f  Segment 0: Alter Keys row
	DB	01H,10H,14H	; b922  Segment 1: Kempston row
	DB	01H,11H,14H	; b925  Segment 2: Sinclair row
	DB	01H,12H,14H	; b928  Segment 3: Protek row
	DB	01H,13H,14H	; b92b  Segment 4: Return row
	DB	0FFH		; b92e  End marker
	DB	01H		; b92f  (padding)
;
; --- Keys menu init code (mixed code/data) ---
; Draws bordered rect, renders keys menu string, then displays current bindings.
	DB	01H,07H,11H,14H,10H	; b930  Params: row=7, col=$11, h=$14, w=$10
	DB	3EH,68H			; b935  LD A,$68 (bright cyan paper)
	DB	0CDH,70H,0BFH		; b937  CALL DRAW_BORDERED_RECT
	DB	21H,62H,0B8H		; b93a  LD HL,$B862 (keys menu string)
	DB	0CDH,26H,0BCH		; b93d  CALL STRING_RENDERER
	DB	0CDH,14H,0BAH		; b940  CALL SHOW_KEY_BINDINGS
;
; ==========================================================================
; KEYS_MENU_LOOP ($B943)
; ==========================================================================
; Main selection loop for the keys menu. Handles 5 options:
;   0: Alter Keys — scan keyboard for 5 new key bindings
;   1-3: Load preset joystick mapping (Kempston/Sinclair/Protek)
;   4: Return to main menu
; ==========================================================================
XB943:	LD	HL,XB91F	; b943  21 1f b9	HL = keys menu segment table
	CALL	XBF18		; b946  cd 18 bf	Initialize menu cursor
XB949:	CALL	XBF3A		; b949  cd 3a bf	Poll keyboard + move cursor
	CALL	XB9DC		; b94c  cd dc b9	Check for Break key (load defaults)
	JR	NC,XB949	; b94f  30 f8		Loop until fire pressed
	CALL	XBF61		; b951  cd 61 bf	Clean up highlights + play sound
	LD	A,(XBDF6)	; b954  3a f6 bd	A = selected segment index
	CP	4		; b957  fe 04		Segment 4 = Return?
	JP	Z,XB9D6		; b959  ca d6 b9	→ exit keys menu
	OR	A		; b95c  b7		Segment 0 = Alter Keys?
	JR	NZ,XB9B7	; b95d  20 58		If not, → load joystick preset
; --- Alter Keys: redefine all 5 keys one by one ---
	CALL	XB9FD		; b95f  cd fd b9	Clear current key display
; --- Initialize key table with $FF (invalid) to prevent duplicates ---
	LD	HL,XBACE	; b962  21 ce ba	HL = active key mapping table
	LD	(HL),0FFH	; b965  36 ff		First entry = $FF
	LD	DE,XBACF	; b967  11 cf ba	DE = second entry
	LD	BC,X0004	; b96a  01 04 00	BC = 4 remaining bytes
	LDIR			; b96d  ed b0		Fill all 5 entries with $FF
; --- Scan for each of 5 keys ---
	LD	B,5		; b96f  06 05		B = 5 keys to define
	LD	DE,X0950	; b971  11 50 09	DE = cursor position (X=$50, Y=$09)
	LD	HL,XBACE	; b974  21 ce ba	HL = key mapping table
XB977:	PUSH	BC		; b977  c5		Save key counter
	PUSH	DE		; b978  d5		Save cursor position
	PUSH	HL		; b979  e5		Save key table pointer
	LD	(XBCA9),DE	; b97a  ed 53 a9 bc	Set rendering cursor to current row
; --- Wait for all keys to be released first ---
XB97E:	CALL	XBA35		; b97e  cd 35 ba	Scan keyboard
	LD	A,D		; b981  7a		A = scan result (0=no key, 1=one key, 2=multi)
	OR	A		; b982  b7		Any key pressed?
	JR	NZ,XB97E	; b983  20 f9		Wait until all released
; --- Wait for exactly one key to be pressed ---
XB985:	CALL	XBA35		; b985  cd 35 ba	Scan keyboard
	LD	A,D		; b988  7a		A = scan result
	CP	1		; b989  fe 01		Exactly 1 key pressed?
	JR	NZ,XB985	; b98b  20 f8		Loop until single key detected
; --- Check for duplicate key assignment ---
	LD	A,E		; b98d  7b		A = key code of pressed key
	LD	B,5		; b98e  06 05		B = 5 entries to check
	LD	HL,XBACE	; b990  21 ce ba	HL = key mapping table
XB993:	CP	(HL)		; b993  be		Is this key already assigned?
	JR	Z,XB97E		; b994  28 e8		If duplicate, reject (wait for release)
	INC	HL		; b996  23		Check next entry
	DJNZ	XB993		; b997  10 fa		Loop through all entries
; --- Accept key: store and display ---
	POP	HL		; b999  e1		Restore key table pointer
	LD	(HL),A		; b99a  77		Store accepted key code
	INC	HL		; b99b  23		Advance to next table entry
	PUSH	HL		; b99c  e5		Save updated pointer
	LD	HL,XC2E1	; b99d  21 e1 c2	HL = key name string table
	CALL	XBB3B		; b9a0  cd 3b bb	Skip A strings to find key name
	CALL	STRING_RENDERER		; b9a3  cd 26 bc	Display key name on screen
	POP	HL		; b9a6  e1		Restore key table pointer
	POP	DE		; b9a7  d1		Restore cursor position
	INC	D		; b9a8  14		Advance cursor Y to next row
	POP	BC		; b9a9  c1		Restore key counter
	DJNZ	XB977		; b9aa  10 cb		Loop for remaining keys
; --- All 5 keys defined ---
	LD	A,19H		; b9ac  3e 19		A = 25 frames delay
	CALL	FRAME_DELAY		; b9ae  cd 48 bb	Brief pause
	CALL	XBAA9		; b9b1  cd a9 ba	Wait for fire release
	JP	XB943		; b9b4  c3 43 b9	Return to keys menu
;
; --- Load joystick preset (segments 1-3) ---
XB9B7:	PUSH	AF		; b9b7  f5		Save selection
	CALL	XB9FD		; b9b8  cd fd b9	Clear key display
	POP	AF		; b9bb  f1		Restore A = selection (1-3)
	DEC	A		; b9bc  3d		A = 0-2 (joystick preset index)
	LD	C,A		; b9bd  4f		C = index
	ADD	A,A		; b9be  87		\
	ADD	A,A		; b9bf  87		 | A = index * 5 (5 bytes per preset)
	ADD	A,C		; b9c0  81		/
	LD	E,A		; b9c1  5f		\  DE = offset into preset table
	LD	D,0		; b9c2  16 00		/
	LD	HL,XBAD3	; b9c4  21 d3 ba	HL = joystick preset table (3 presets)
	ADD	HL,DE		; b9c7  19		HL = selected preset data
	LD	DE,XBACE	; b9c8  11 ce ba	DE = active key mapping table
	LD	BC,X0005	; b9cb  01 05 00	BC = 5 bytes to copy
	LDIR			; b9ce  ed b0		Copy preset to active mapping
	CALL	XBA14		; b9d0  cd 14 ba	Display new key bindings
	JP	XB943		; b9d3  c3 43 b9	Return to keys menu
;
; --- Return to main menu from keys submenu ---
XB9D6:	CALL	RESTORE_RECT		; b9d6  cd 3e c0	Remove keys menu popup
	JP	XB2B7		; b9d9  c3 b7 b2	Return to main menu selection loop
;
; ==========================================================================
; CHECK_BREAK_KEY ($B9DC)
; ==========================================================================
; Checks if Break (Caps Shift + Space) was pressed. If so, reloads the
; default key mapping from the backup table ($BAE2 → $BACE), clears and
; redisplays key bindings, then waits for Break release.
; Returns: preserves carry from original fire key check
; ==========================================================================
XB9DC:	PUSH	AF		; b9dc  f5		Save carry (fire button state)
	CALL	XBA9D		; b9dd  cd 9d ba	Check fire keys (includes Break check)
	JR	C,XB9FB		; b9e0  38 19		If Break not pressed, skip
; --- Break pressed: reload default keys ---
	LD	HL,XBAE2	; b9e2  21 e2 ba	HL = default key mapping backup
	LD	DE,XBACE	; b9e5  11 ce ba	DE = active key mapping
	LD	BC,X0005	; b9e8  01 05 00	BC = 5 bytes
	LDIR			; b9eb  ed b0		Restore defaults
	CALL	XB9FD		; b9ed  cd fd b9	Clear key display
	CALL	XBA14		; b9f0  cd 14 ba	Display restored key bindings
XB9F3:	CALL	XBA9D		; b9f3  cd 9d ba	Wait for Break to be released
	JR	NC,XB9F3	; b9f6  30 fb		Loop until released
	CALL	XBAA9		; b9f8  cd a9 ba	Wait for fire release too
XB9FB:	POP	AF		; b9fb  f1		Restore original carry (fire state)
	RET			; b9fc  c9		Return
;
; ==========================================================================
; CLEAR_KEY_DISPLAY ($B9FD)
; ==========================================================================
; Clears the 5 key binding display lines by rendering 10 spaces at each
; position. Used before redefining keys or loading a new preset.
; ==========================================================================
XB9FD:	LD	B,5		; b9fd  06 05		B = 5 lines to clear
	LD	DE,X0950	; b9ff  11 50 09	DE = start position (X=$50, Y=$09)
XBA02:	PUSH	BC		; ba02  c5		Save counter
	PUSH	DE		; ba03  d5		Save position
	LD	(XBCA9),DE	; ba04  ed 53 a9 bc	Set cursor to this row
	LD	HL,XB914	; ba08  21 14 b9	HL = blank string (10 spaces)
	CALL	STRING_RENDERER		; ba0b  cd 26 bc	Render spaces (clears line)
	POP	DE		; ba0e  d1		Restore position
	INC	D		; ba0f  14		Advance Y to next row
	POP	BC		; ba10  c1		Restore counter
	DJNZ	XBA02		; ba11  10 ef		Loop for 5 lines
	RET			; ba13  c9		Return
;
; ==========================================================================
; SHOW_KEY_BINDINGS ($BA14)
; ==========================================================================
; Displays the current 5 key bindings (Left, Right, Up, Down, Fire) by
; looking up key names in the string table at $C2E1. Each key code is
; used as an index to skip through the table via SKIP_STRINGS.
; ==========================================================================
XBA14:	LD	B,5		; ba14  06 05		B = 5 keys to display
	LD	DE,X0950	; ba16  11 50 09	DE = start position (X=$50, Y=$09)
	LD	HL,XBACE	; ba19  21 ce ba	HL = active key mapping table
XBA1C:	PUSH	BC		; ba1c  c5		Save counter
	PUSH	DE		; ba1d  d5		Save position
	LD	(XBCA9),DE	; ba1e  ed 53 a9 bc	Set rendering cursor position
	LD	A,(HL)		; ba22  7e		A = key code for this binding
	INC	HL		; ba23  23		Advance to next key
	PUSH	HL		; ba24  e5		Save key table pointer
	LD	HL,XC2E1	; ba25  21 e1 c2	HL = key name string table
	CALL	XBB3B		; ba28  cd 3b bb	Skip A strings to find key name
	CALL	STRING_RENDERER		; ba2b  cd 26 bc	Render key name string
	POP	HL		; ba2e  e1		Restore key table pointer
	POP	DE		; ba2f  d1		Restore cursor position
	INC	D		; ba30  14		Advance Y to next row
	POP	BC		; ba31  c1		Restore counter
	DJNZ	XBA1C		; ba32  10 e8		Loop for 5 keys
	RET			; ba34  c9		Return
;
; ==========================================================================
; SCAN_SINGLE_KEY ($BA35)
; ==========================================================================
; Scans all 8 keyboard half-rows to detect a single keypress. Returns a
; unique key code in E and the number of simultaneous keys in D.
;
; The keyboard port table at $BABC defines 8 half-rows, each with 5 keys.
; Keys are numbered sequentially: row 0 bits 0-4 = keys 0-4, row 1 = 8-12,
; etc. (3 unused codes between rows for the gap between bit 4 and next row).
;
; Returns: D = 0 (no key), 1 (one key, code in E), 2 (multiple keys)
;          E = key code (valid only when D=1)
; ==========================================================================
XBA35:	LD	HL,XBABC	; ba35  21 bc ba	HL = keyboard port table
	LD	B,8		; ba38  06 08		B = 8 half-rows
	LD	DE,X0000	; ba3a  11 00 00	D=0 (key count flag), E=0
XBA3D:	PUSH	BC		; ba3d  c5		Save row counter
	LD	C,(HL)		; ba3e  4e		C = port low byte
	INC	HL		; ba3f  23		.
	LD	B,(HL)		; ba40  46		B = port high byte
	INC	HL		; ba41  23		Advance to next port entry
	IN	A,(C)		; ba42  ed 78		Read keyboard half-row
	CPL			; ba44  2f		Invert: 1=pressed, 0=not pressed
	LD	C,A		; ba45  4f		C = key state bits
	LD	B,5		; ba46  06 05		B = 5 keys per half-row
XBA48:	SRL	C		; ba48  cb 39		Shift bit 0 into carry
	JR	NC,XBA53	; ba4a  30 07		If key not pressed, skip
	BIT	7,D		; ba4c  cb 7a		Already found a key?
	JR	NZ,XBA64	; ba4e  20 14		If yes, → multiple keys detected
	LD	E,D		; ba50  5a		E = current key code (D holds code counter)
	SET	7,D		; ba51  cb fa		Mark: one key found (bit 7 = found flag)
XBA53:	INC	D		; ba53  14		Increment key code counter
	DJNZ	XBA48		; ba54  10 f2		Loop for 5 bits in this row
	LD	A,D		; ba56  7a		A = code counter
	ADD	A,3		; ba57  c6 03		Skip 3 codes (gap between rows)
	LD	D,A		; ba59  57		D = start code for next row
	POP	BC		; ba5a  c1		Restore row counter
	DJNZ	XBA3D		; ba5b  10 e0		Loop for 8 rows
; --- All rows scanned ---
	BIT	7,D		; ba5d  cb 7a		Was any key found?
	LD	D,0		; ba5f  16 00		D = 0 (no key default)
	RET	Z		; ba61  c8		Return D=0 if no key
	INC	D		; ba62  14		D = 1 (exactly one key)
	RET			; ba63  c9		Return D=1, E=key code
;
; --- Multiple keys detected: early exit ---
XBA64:	POP	BC		; ba64  c1		Clean up stack
	LD	D,2		; ba65  16 02		D = 2 (multiple keys pressed)
	RET			; ba67  c9		Return
;
