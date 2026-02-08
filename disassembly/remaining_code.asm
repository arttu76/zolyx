; ==========================================================================
; "FREEBIE" — CELLULAR 2D AUTOMATON ($D501-$EFFF)
; ==========================================================================
;
; A complete standalone "Cellular 2D Automaton" program bundled as a
; bonus feature in the Zolyx game, accessible via the "Freebie" menu
; option. Implements a variation of Conway's Game of Life with an
; editable rule table, color mapping, and speed control.
;
; The automaton operates on a 32x23 grid of cells stored in a 34x25
; grid buffer (with 1-cell borders). Each cell has a value 0-3 (4 states).
; On each generation, each cell's new value is determined by summing the
; values of its 4 neighbors (up/down/left/right) and using that sum as
; an index into a 13-entry RULE table ($E1D5). The rule table maps
; neighbor sums (0-12) to new cell values (0-3).
;
; The grid is displayed using ZX Spectrum attribute memory, where each
; cell's value maps to a COLOR MAP ($E1E8, 4 entries) that selects the
; attribute color. Rendering writes directly to $5820 (attribute row 1).
;
; --------------------------------------------------------------------------
; ROUTINE INDEX
; --------------------------------------------------------------------------
;   $D502  (Partial) Attribute write for color map editor
;   $D527  FREEBIE_MENU_HANDLER  Dispatch to sub-handler via jump table
;   $D541  Jump table: 4 entries ($D549, $D660, $D6C8, $D601)
;   $D55A  SPEED_SELECT          Display 4 speed options + Accept/Cancel
;   $D601  RULE_EDITOR           Edit the 13-entry rule table
;   $D660  COLOR_MAP_EDITOR      Edit the 4-entry color map
;   $D6C8  PATTERN_EDITOR        Main edit display with rule/restore/clear/exit
;   $D756  SHOW_COLOR_MAP_INLINE Display current color map swatch
;   $D780  GENERATE_NEXT         Compute next automaton generation
;   $D7BB  RENDER_GRID           Render automaton grid to screen attributes
;
; --------------------------------------------------------------------------
; DATA SECTIONS
; --------------------------------------------------------------------------
;   $D7DF-$DB30  Grid backup buffer (852 bytes = 34 * 25 + 2)
;   $DB31-$DB53  Current rule table + color map (active state)
;   $DB54-$DE82  Cell grid buffer (34 * 25 = 850 bytes, with borders)
;   $DE83-$E01E  Generation scratch buffer (852 bytes)
;   $E1D5-$E1E1  RULE TABLE: 13 entries, maps neighbor sum → cell value
;   $E1E6         Current speed selection (0-3)
;   $E1E7         Current editor mode
;   $E1E8-$E1EB  COLOR MAP: 4 entries, cell value → attribute color index
;   $E1EC         Generation counter (16-bit)
;   $E1EE-$E233  Color name strings (Black, Blue, Red, etc.)
;   $E236-$E263  Main menu string ("Run / Rule / Col.Map / Edit / Exit")
;   $E264-$E319  Rule editor display string
;   $E31B-$E366  Color map editor display string
;   $E367-$E3F6  Pattern editor display string
;   $E3F7-$E3FF  Generation counter display prefix
;   $E400-$E415  Generation display string
;   $E416-$E499  Segment tables for rule/color/pattern editors
;   $E49A-$E4AD  Speed selection segment table
;   $E4B5-$E72B  "Cellular 2D Automaton" title + info text + copyright
;   $EDC8-$EFFF  Unused zero-filled RAM (568 bytes)
; --------------------------------------------------------------------------
; COPYRIGHT: "Program Copyright Pete Cooke 1987. Coded for Firebird
;            Software Dec 87"
; --------------------------------------------------------------------------
;

; --- Partial routine (entry is on previous page at $D4D7) ---
; Writes a cell value to the grid buffer and updates the corresponding
; screen attribute byte with the mapped color.
	ADD	HL,DE		; d502  19		HL = row * 34
	ADD	HL,HL		; d503  29		(intermediate calculation)
	LD	DE,XDB54	; d504  11 54 db	DE = grid buffer base
	ADD	HL,DE		; d507  19		HL = cell address in grid buffer
	LD	B,0		; d508  06 00		BC = column offset
	ADD	HL,BC		; d50a  09		HL = exact cell position
	LD	A,(XE1E7)	; d50b  3a e7 e1	A = current editor value (cell state)
	LD	(HL),A		; d50e  77		Store cell value in grid buffer
; --- Update corresponding attribute on screen ---
	POP	HL		; d50f  e1		HL = row index
	ADD	HL,HL		; d510  29		HL = row * 2... (screen row computation)
	LD	DE,X5820	; d511  11 20 58	DE = attribute memory row 1 ($5800+32)
	ADD	HL,DE		; d514  19		HL = attribute address for this row
	ADD	HL,BC		; d515  09		HL = attribute address for this cell
	EX	DE,HL		; d516  eb		DE = target attribute address
	LD	A,(XE1E7)	; d517  3a e7 e1	A = cell value (0-3)
	LD	C,A		; d51a  4f		\  BC = cell value
	LD	B,0		; d51b  06 00		/
	LD	HL,XE1E8	; d51d  21 e8 e1	HL = color map table base
	ADD	HL,BC		; d520  09		HL = color map entry for this value
	LD	A,(HL)		; d521  7e		A = mapped color index (0-6)
	OR	38H		; d522  f6 38		Set PAPER bits (white paper) + color as ink
	LD	(DE),A		; d524  12		Write attribute to screen
	JR	XD4D7		; d525  18 b0		Jump back to editor loop (on prev page)
;
; ==========================================================================
; FREEBIE_MENU_HANDLER ($D527)
; ==========================================================================
; Called from the main Freebie display loop. Cleans up menu, reads the
; selected option, and dispatches to the appropriate sub-handler via a
; jump table. Options 0-3 are handled; option 4+ (Exit) returns.
; Pushes the main loop address ($D4CE) so sub-handlers return to it.
; ==========================================================================
XD527:	CALL	XBF61		; d527  cd 61 bf	Clean up menu highlights + play sound
	LD	A,(XBDF6)	; d52a  3a f6 bd	A = selected menu segment
	CP	4		; d52d  fe 04		Option 4 (Exit) or beyond?
	RET	NC		; d52f  d0		If Exit, return to caller
	ADD	A,A		; d530  87		A = selection * 2 (word offset)
	LD	E,A		; d531  5f		\  DE = offset into jump table
	LD	D,0		; d532  16 00		/
	LD	HL,XD541	; d534  21 41 d5	HL = jump table base
	ADD	HL,DE		; d537  19		HL = address of handler pointer
	LD	E,(HL)		; d538  5e		\  DE = handler address
	INC	HL		; d539  23		|
	LD	D,(HL)		; d53a  56		/
	EX	DE,HL		; d53b  eb		HL = handler address
	LD	DE,XD4CE	; d53c  11 ce d4	DE = return address (main Freebie loop)
	PUSH	DE		; d53f  d5		Push return address onto stack
	JP	(HL)		; d540  e9		Jump to selected handler
;
; --- Jump table: 4 sub-handler addresses ---
XD541:	DW	XD549		; d541  Option 0: Speed selection ($D549)
	DW	XD660		; d543  Option 1: Color map editor ($D660)
	DW	XD6C8		; d545  Option 2: Pattern editor ($D6C8)
	DW	XD601		; d547  Option 3: Rule editor ($D601)
;
; --- Speed selection init (mixed code/data) ---
; Draws bordered rect and renders speed selection menu string.
	DB	00H,00H,11H,08H,0CH	; d54a  Params: row=0,col=0,h=$11,w=$08... wait
	DB	3EH,30H			; d54f  LD A,$30 (attribute for bordered rect)
	DB	0CDH,70H,0BFH		; d551  CALL DRAW_BORDERED_RECT
	LD	HL,XE3B3	; d554  21 b3 e3	HL = speed selection string data
	CALL	STRING_RENDERER		; d557  cd 26 bc	Render speed menu text
; ==========================================================================
; SPEED_SELECT ($D55A)
; ==========================================================================
; Displays the 4 speed options (Fast/Med/Slow/S.Step), highlights the
; currently selected speed, and waits for user input. Options 0-3 set
; the speed; option 4+ (Go!/Cancel) exits to run or cancel.
;
; Speed values: 0=Fast, 1=Med, 2=Slow, 3=Single-Step
; Uses timer bar cursor system for menu navigation.
; ==========================================================================
XD55A:	LD	IX,XBCA9	; d55a  dd 21 a9 bc	IX = cursor position struct
	LD	B,4		; d55e  06 04		B = 4 speed options to display
; --- Loop: highlight each speed option ---
XD560:	LD	A,4		; d560  3e 04		\  A = option index (0-3)
	SUB	B		; d562  90		/  (4-B gives 0,1,2,3)
	LD	C,A		; d563  4f		C = option index (save for comparison)
	ADD	A,3		; d564  c6 03		A = screen row (option index + 3)
	LD	(IX+1),A	; d566  dd 77 01	Set cursor Y position
	LD	(IX+0),30H	; d569  dd 36 00 30	Set cursor X position = $30
	LD	A,(XE1E6)	; d56d  3a e6 e1	A = currently selected speed
	CP	C		; d570  b9		Is this option the active speed?
	LD	A,9EH		; d571  3e 9e		A = $9E (unselected marker char)
	JR	NZ,XD576	; d573  20 01		Skip if not active speed
	INC	A		; d575  3c		A = $9F (selected marker: filled square)
XD576:	CALL	XBCB5		; d576  cd b5 bc	Draw marker character at cursor position
	DJNZ	XD560		; d579  10 e5		Loop for all 4 options
; --- Set up segment table and wait for selection ---
	LD	HL,XE49A	; d57b  21 9a e4	HL = speed selection segment table
	CALL	XBF18		; d57e  cd 18 bf	Initialize timer bar cursor system
XD581:	CALL	XBF3A		; d581  cd 3a bf	Poll for selection (timer bar input)
	JR	NC,XD581	; d584  30 fb		Loop until selection confirmed
	CALL	XBF61		; d586  cd 61 bf	Clean up highlights + play sound
	LD	A,(XBDF6)	; d589  3a f6 bd	A = selected segment index
	CP	4		; d58c  fe 04		Option 4+ (Go! or Cancel)?
	JR	NC,XD596	; d58e  30 06		Yes — jump to Go/Cancel handler
; --- Speed 0-3 selected: store and redisplay ---
	LD	(XE1E6),A	; d590  32 e6 e1	Store new speed selection
	JP	XD55A		; d593  c3 5a d5	Redisplay with new selection highlighted
;
; --- Go! or Cancel selected ---
XD596:	CALL	RESTORE_RECT		; d596  cd 3e c0	Restore screen under speed popup
	LD	A,(XBDF6)	; d599  3a f6 bd	A = selected segment
	CP	5		; d59c  fe 05		Was "Cancel" selected? (segment 5)
	RET	Z		; d59e  c8		Yes — return without running
; --- "Go!" selected (segment 4): start automaton run ---
	LD	HL,XDB31	; d59f  21 31 db	\  Backup current state (rule table +
	LD	DE,XD7DF	; d5a2  11 df d7	|  color map + grid) to backup buffer
	LD	BC,X0352	; d5a5  01 52 03	|  BC = 850 bytes (34*25)
	LDIR			; d5a8  ed b0		/
	LD	C,0		; d5aa  0e 00		C = 0 (no extra attribute bits)
	CALL	XD7BB		; d5ac  cd bb d7	Render initial grid to screen
	LD	HL,X0000	; d5af  21 00 00	\  Reset generation counter to 0
	LD	(XE1EC),HL	; d5b2  22 ec e1	/
	LD	HL,XE3F7	; d5b5  21 f7 e3	HL = generation counter display prefix
	CALL	STRING_RENDERER		; d5b8  cd 26 bc	Render "Gen:" label on screen
; --- Main automaton loop: generate + render + delay ---
XD5BB:	CALL	XD780		; d5bb  cd 80 d7	Compute next generation
	LD	C,0		; d5be  0e 00		C = 0 (no extra attribute bits)
	CALL	XD7BB		; d5c0  cd bb d7	Render grid to screen attributes
	LD	HL,XE400	; d5c3  21 00 e4	HL = generation display string
	CALL	STRING_RENDERER		; d5c6  cd 26 bc	Render current generation number
	LD	HL,(XE1EC)	; d5c9  2a ec e1	\  Increment generation counter
	INC	HL		; d5cc  23		|
	LD	(XE1EC),HL	; d5cd  22 ec e1	/
	CALL	XBBD8		; d5d0  cd d8 bb	Display generation number on screen
	LD	A,(XE1E6)	; d5d3  3a e6 e1	A = current speed setting
	CP	3		; d5d6  fe 03		Single-step mode? (speed 3)
	JR	NZ,XD5E8	; d5d8  20 0e		No — use timed delay
; --- Single-step mode: wait for Fire button press ---
XD5DA:	CALL	XBA9D		; d5da  cd 9d ba	Check for Break key
	JR	NC,XD5F5	; d5dd  30 16		Break pressed — stop running
	CALL	READ_KEYBOARD		; d5df  cd 68 ba	Read keyboard/joystick input
	BIT	0,C		; d5e2  cb 41		Fire button pressed?
	JR	Z,XD5DA		; d5e4  28 f4		No — keep waiting
	JR	XD5BB		; d5e6  18 d3		Yes — run next generation
;
; --- Timed delay mode (speed 0-2): delay = speed*8 + 2 frames ---
XD5E8:	ADD	A,A		; d5e8  87		\  A = speed * 8
	ADD	A,A		; d5e9  87		|  (0→0, 1→8, 2→16)
	ADD	A,A		; d5ea  87		/
	ADD	A,2		; d5eb  c6 02		A = delay frames (2, 10, or 18)
	CALL	FRAME_DELAY		; d5ed  cd 48 bb	Wait A frames
	CALL	XBA9D		; d5f0  cd 9d ba	Check for Break key
	JR	C,XD5BB		; d5f3  38 c6		No break — continue running
; --- Break pressed or run ended: restore main menu ---
XD5F5:	LD	C,38H		; d5f5  0e 38		C = $38 (white paper, black ink attribute)
	CALL	XD7BB		; d5f7  cd bb d7	Re-render grid with neutral colors
	LD	HL,XE236	; d5fa  21 36 e2	HL = main menu string
	CALL	STRING_RENDERER		; d5fd  cd 26 bc	Redraw main Freebie menu
	RET			; d600  c9		Return to Freebie main loop
;
; ==========================================================================
; RULE_EDITOR ($D601)
; ==========================================================================
; Displays and edits the 13-entry rule table. Each entry maps a neighbor
; sum (0-12) to a new cell value (0-3). The user can increment/decrement
; each entry using left/right on the timer bar cursor. Selection segment
; pairs: even=decrement, odd=increment for each rule entry.
; Exit option is segment $1A (26).
; ==========================================================================
	LD	BC,X0005	; d601  01 05 00	BC: row=0, col=5
	LD	DE,X1208	; d604  11 08 12	DE: height=$12 (18), width=$08 (8)
	LD	A,30H		; d607  3e 30		A = $30 (yellow paper attribute)
	CALL	DRAW_BORDERED_RECT		; d609  cd 70 bf	Draw bordered popup
	LD	HL,XE264	; d60c  21 64 e2	HL = rule editor display string
	CALL	STRING_RENDERER		; d60f  cd 26 bc	Render rule editor frame text
; --- Redraw loop: display all 13 rule values ---
XD612:	LD	HL,XE1D5	; d612  21 d5 e1	HL = rule table base (13 entries)
	LD	B,0DH		; d615  06 0d		B = 13 entries to display
	LD	IX,XBCA9	; d617  dd 21 a9 bc	IX = cursor position struct
XD61B:	LD	A,0FH		; d61b  3e 0f		\  A = screen row for this entry
	SUB	B		; d61d  90		/  (15-B gives rows 2..14)
	LD	(IX+1),A	; d61e  dd 77 01	Set cursor Y position
	LD	(IX+0),50H	; d621  dd 36 00 50	Set cursor X position = $50
	LD	A,(HL)		; d625  7e		A = rule value (0-3)
	ADD	A,80H		; d626  c6 80		A = char $80-$83 (block graphic for value)
	CALL	XBCB5		; d628  cd b5 bc	Draw value character at cursor
	INC	HL		; d62b  23		Advance to next rule entry
	DJNZ	XD61B		; d62c  10 ed		Loop for all 13 entries
; --- Set up segment table and wait for selection ---
	LD	HL,XE416	; d62e  21 16 e4	HL = rule editor segment table
	CALL	XBF18		; d631  cd 18 bf	Initialize timer bar cursor system
XD634:	CALL	XBF3A		; d634  cd 3a bf	Poll for selection
	JR	NC,XD634	; d637  30 fb		Loop until confirmed
	CALL	XBF61		; d639  cd 61 bf	Clean up + sound
	LD	A,(XBDF6)	; d63c  3a f6 bd	A = selected segment
	CP	1AH		; d63f  fe 1a		Exit option? (segment 26)
	JR	Z,XD65C		; d641  28 19		Yes — close editor
; --- Adjust selected rule entry ---
; Segment encoding: even=decrement (-1), odd=increment (+1) for entry E/2
	LD	E,A		; d643  5f		E = segment index
	RRCA			; d644  0f		Carry = bit 0 (odd=increment)
	CCF			; d645  3f		Invert carry (odd→NC, even→C)
	SBC	A,A		; d646  9f		A = $00 (odd/inc) or $FF (even/dec)
	ADD	A,A		; d647  87		A = $00 or $FE
	INC	A		; d648  3c		A = +1 (increment) or -1 (decrement)
	SRL	E		; d649  cb 3b		E = segment / 2 = rule entry index
	LD	D,0		; d64b  16 00		DE = rule entry index
	LD	HL,XE1D5	; d64d  21 d5 e1	HL = rule table base
	ADD	HL,DE		; d650  19		HL = address of target rule entry
	ADD	A,(HL)		; d651  86		A = new value (current + delta)
	JP	M,XD612		; d652  fa 12 d6	If negative (underflow) — ignore, redraw
	CP	4		; d655  fe 04		Value >= 4 (overflow)?
	JR	NC,XD612	; d657  30 b9		Yes — ignore, redraw
	LD	(HL),A		; d659  77		Store valid new value (0-3)
	JR	XD612		; d65a  18 b6		Redraw with updated value
;
XD65C:	CALL	RESTORE_RECT		; d65c  cd 3e c0	Restore screen under popup
	RET			; d65f  c9		Return to Freebie main loop
;
; ==========================================================================
; COLOR_MAP_EDITOR ($D660)
; ==========================================================================
; Displays and edits the 4-entry color map. Each entry maps a cell value
; (0-3) to a ZX Spectrum color index (0-6: Black..White). Color names are
; displayed from the color name string table at $E1EE.
; Segment pairs: even=prev color, odd=next color for each entry.
; Exit option is segment 8+.
; ==========================================================================
	LD	BC,X0009	; d660  01 09 00	BC: row=0, col=9
	LD	DE,X090D	; d663  11 0d 09	DE: height=$09 (9), width=$0D (13)
	LD	A,30H		; d666  3e 30		A = $30 (yellow paper attribute)
	CALL	DRAW_BORDERED_RECT		; d668  cd 70 bf	Draw bordered popup
	LD	HL,XE31B	; d66b  21 1b e3	HL = color map editor display string
	CALL	STRING_RENDERER		; d66e  cd 26 bc	Render editor frame text
; --- Redraw loop: display all 4 color names ---
XD671:	LD	HL,XE1E8	; d671  21 e8 e1	HL = color map table (4 entries)
	LD	B,4		; d674  06 04		B = 4 entries to display
	LD	IX,XBCA9	; d676  dd 21 a9 bc	IX = cursor position struct
XD67A:	PUSH	BC		; d67a  c5		Save loop counter
	LD	A,6		; d67b  3e 06		\  A = screen row (6-B → rows 2..5)
	SUB	B		; d67d  90		/
	LD	(IX+1),A	; d67e  dd 77 01	Set cursor Y position
	LD	(IX+0),68H	; d681  dd 36 00 68	Set cursor X position = $68
	LD	A,(HL)		; d685  7e		A = color index for this cell value
	INC	HL		; d686  23		Advance to next color map entry
	PUSH	HL		; d687  e5		Save color map pointer
	LD	HL,XE1EE	; d688  21 ee e1	HL = color name string table base
	CALL	XBB3B		; d68b  cd 3b bb	Find Ath string in table → HL
	CALL	STRING_RENDERER		; d68e  cd 26 bc	Render color name at cursor
	POP	HL		; d691  e1		Restore color map pointer
	POP	BC		; d692  c1		Restore loop counter
	DJNZ	XD67A		; d693  10 e5		Loop for all 4 entries
; --- Set up segment table and wait for selection ---
	LD	HL,XE468	; d695  21 68 e4	HL = color map editor segment table
	CALL	XBF18		; d698  cd 18 bf	Initialize timer bar cursor
XD69B:	CALL	XBF3A		; d69b  cd 3a bf	Poll for selection
	JR	NC,XD69B	; d69e  30 fb		Loop until confirmed
	CALL	XBF61		; d6a0  cd 61 bf	Clean up + sound
	LD	A,(XBDF6)	; d6a3  3a f6 bd	A = selected segment
	CP	8		; d6a6  fe 08		Exit option? (segment 8+)
	JR	NC,XD6BF	; d6a8  30 15		Yes — close editor
; --- Adjust selected color map entry ---
; Segment encoding: even=prev color, odd=next color for entry A/2
	SRL	A		; d6aa  cb 3f		A/2 = color map entry index, carry=direction
	LD	E,A		; d6ac  5f		E = entry index
	CCF			; d6ad  3f		Invert carry (odd→decrement, even→increment)
	SBC	A,A		; d6ae  9f		A = $00 or $FF
	ADD	A,A		; d6af  87		A = $00 or $FE
	INC	A		; d6b0  3c		A = +1 or -1 (delta)
	LD	D,0		; d6b1  16 00		DE = entry index
	LD	HL,XE1E8	; d6b3  21 e8 e1	HL = color map table base
	ADD	HL,DE		; d6b6  19		HL = address of target entry
	ADD	A,(HL)		; d6b7  86		A = new color (current + delta)
	CP	7		; d6b8  fe 07		Color >= 7 (out of range)?
	JR	NC,XD671	; d6ba  30 b5		Yes — ignore (also catches negative via wrap)
	LD	(HL),A		; d6bc  77		Store valid new color (0-6)
	JR	XD671		; d6bd  18 b2		Redraw with updated color
;
XD6BF:	CALL	RESTORE_RECT		; d6bf  cd 3e c0	Restore screen under popup
	LD	C,38H		; d6c2  0e 38		C = $38 (white paper attribute base)
	CALL	XD7BB		; d6c4  cd bb d7	Re-render grid with new colors
	RET			; d6c7  c9		Return to Freebie main loop
;
; ==========================================================================
; PATTERN_EDITOR ($D6C8)
; ==========================================================================
; Main edit screen for the cellular automaton. Allows the user to select
; a "colour number" (cell value 0-3) for painting, then presents options:
;   Options 0-3: Select colour number for grid painting
;   Option 4: "Clear" — fill grid with current colour, re-render
;   Option 5: "Restore" — restore grid from backup buffer
;   Option 6+: "Exit" — return to main menu
; After selecting a colour, the grid editor ($D4CE loop, on prev page)
; lets the user paint cells with that colour value.
; ==========================================================================
	LD	BC,X0011	; d6c8  01 11 00	BC: row=0, col=$11 (17)
	LD	DE,X0A09	; d6cb  11 09 0a	DE: height=$0A (10), width=$09 (9)
	LD	A,30H		; d6ce  3e 30		A = $30 (yellow paper attribute)
	CALL	DRAW_BORDERED_RECT		; d6d0  cd 70 bf	Draw bordered popup
	LD	HL,XE367	; d6d3  21 67 e3	HL = pattern editor display string
	CALL	STRING_RENDERER		; d6d6  cd 26 bc	Render editor frame text
; --- Redraw loop: display 4 colour number options with markers ---
XD6D9:	LD	B,4		; d6d9  06 04		B = 4 options
	LD	IX,XBCA9	; d6db  dd 21 a9 bc	IX = cursor position struct
XD6DF:	LD	A,4		; d6df  3e 04		\  A = option index (0-3)
	SUB	B		; d6e1  90		/
	LD	C,A		; d6e2  4f		C = option index (save for comparison)
	LD	A,9CH		; d6e3  3e 9c		A = base X position ($9C)
	BIT	0,C		; d6e5  cb 41		Odd option?
	JR	Z,XD6EB		; d6e7  28 02		No — use left column
	ADD	A,20H		; d6e9  c6 20		Yes — offset to right column (+$20)
XD6EB:	LD	(IX+0),A	; d6eb  dd 77 00	Set cursor X position
	LD	A,C		; d6ee  79		A = option index
	SRL	A		; d6ef  cb 3f		A = option / 2 (row offset: 0 or 1)
	ADD	A,3		; d6f1  c6 03		A = screen row (3 or 4)
	LD	(IX+1),A	; d6f3  dd 77 01	Set cursor Y position
	LD	A,(XE1E7)	; d6f6  3a e7 e1	A = currently selected colour number
	CP	C		; d6f9  b9		Is this option the active colour?
	LD	A,9EH		; d6fa  3e 9e		A = $9E (unselected marker)
	JR	NZ,XD6FF	; d6fc  20 01		Skip if not active colour
	INC	A		; d6fe  3c		A = $9F (selected marker: filled square)
XD6FF:	CALL	XBCB5		; d6ff  cd b5 bc	Draw marker at cursor
	DJNZ	XD6DF		; d702  10 db		Loop for all 4 options
	CALL	XD756		; d704  cd 56 d7	Show color map swatch inline
	LD	HL,XE484	; d707  21 84 e4	HL = pattern editor segment table
XD70A:	CALL	XBF18		; d70a  cd 18 bf	Initialize timer bar cursor
XD70D:	CALL	XBF3A		; d70d  cd 3a bf	Poll for selection
	JR	NC,XD70D	; d710  30 fb		Loop until confirmed
	CALL	XBF61		; d712  cd 61 bf	Clean up + sound
	LD	A,(XBDF6)	; d715  3a f6 bd	A = selected segment
	CP	4		; d718  fe 04		Option 4+ (Clear/Restore/Exit)?
	JR	NC,XD721	; d71a  30 05		Yes — handle special options
; --- Colour 0-3 selected: store and redisplay ---
	LD	(XE1E7),A	; d71c  32 e7 e1	Store new colour number
	JR	XD6D9		; d71f  18 b8		Redisplay with new selection
;
; --- Handle special options: Clear / Restore / Exit ---
XD721:	CALL	RESTORE_RECT		; d721  cd 3e c0	Restore screen under popup
	LD	A,(XBDF6)	; d724  3a f6 bd	A = selected segment
	CP	4		; d727  fe 04		Option 4: "Clear"?
	JR	NZ,XD740	; d729  20 15		No — check Restore/Exit
; --- Clear: fill entire grid with selected colour ---
	LD	HL,XDB31	; d72b  21 31 db	HL = active state buffer start
	LD	A,(XE1E7)	; d72e  3a e7 e1	A = selected colour number (0-3)
	LD	(HL),A		; d731  77		Write colour to first byte
	LD	DE,XDB32	; d732  11 32 db	DE = second byte of buffer
	LD	BC,X0351	; d735  01 51 03	BC = 849 bytes (fill rest via LDIR)
	LDIR			; d738  ed b0		Fill entire buffer with colour value
	LD	C,38H		; d73a  0e 38		C = $38 (white paper base attribute)
	CALL	XD7BB		; d73c  cd bb d7	Re-render grid to screen
	RET			; d73f  c9		Return to Freebie main loop
;
XD740:	CP	5		; d740  fe 05		Option 5: "Restore"?
	JR	NZ,XD755	; d742  20 11		No — must be Exit
; --- Restore: copy backup buffer back to active state ---
	LD	HL,XD7DF	; d744  21 df d7	HL = backup buffer
	LD	DE,XDB31	; d747  11 31 db	DE = active state buffer
	LD	BC,X0352	; d74a  01 52 03	BC = 850 bytes
	LDIR			; d74d  ed b0		Restore from backup
	LD	C,38H		; d74f  0e 38		C = $38 (white paper base attribute)
	CALL	XD7BB		; d751  cd bb d7	Re-render grid to screen
	RET			; d754  c9		Return to Freebie main loop
;
; --- Exit: just return ---
XD755:	RET			; d755  c9		Return to Freebie main loop
;
; ==========================================================================
; SHOW_COLOR_MAP_INLINE ($D756)
; ==========================================================================
; Displays a color swatch block next to the pattern editor, showing the
; actual color of the currently selected cell value. Temporarily overrides
; the cursor's attribute byte (IX+2) to use the mapped color with BRIGHT
; bit set, draws a block character ($7E = "~" / solid block), then restores
; the original attribute.
; ==========================================================================
XD756:	LD	IX,XBCA9	; d756  dd 21 a9 bc	IX = cursor position struct
	LD	(IX+0),0F8H	; d75a  dd 36 00 f8	Set cursor X = $F8 (far right)
	LD	(IX+1),0	; d75e  dd 36 01 00	Set cursor Y = 0 (top)
	LD	A,(XE1E7)	; d762  3a e7 e1	A = currently selected colour number
	LD	E,A		; d765  5f		\  DE = colour index
	LD	D,0		; d766  16 00		/
	LD	HL,XE1E8	; d768  21 e8 e1	HL = color map table
	ADD	HL,DE		; d76b  19		HL = color map entry for this colour
	LD	A,(IX+2)	; d76c  dd 7e 02	A = original attribute (save it)
	PUSH	AF		; d76f  f5		Save original attribute on stack
	LD	A,(HL)		; d770  7e		A = mapped color (0-6)
	SET	7,A		; d771  cb ff		Set BRIGHT bit (bit 7)
	LD	(IX+2),A	; d773  dd 77 02	Override cursor attribute with color
	LD	A,7EH		; d776  3e 7e		A = $7E (solid block character "~")
	CALL	XBCB5		; d778  cd b5 bc	Draw colored block at cursor
	POP	AF		; d77b  f1		Restore original attribute
	LD	(IX+2),A	; d77c  dd 77 02	Put back cursor's original attribute
	RET			; d77f  c9		Return
;
; ==========================================================================
; GENERATE_NEXT ($D780)
; ==========================================================================
; Computes the next generation of the cellular automaton. For each of the
; 32x23 interior cells, sums the 4 orthogonal neighbors from the scratch
; buffer (previous generation), looks up the new value in the rule table,
; and writes it to the active grid buffer.
;
; Grid layout: 34 bytes/row (32 interior + 1 border on each side),
;              25 rows (23 interior + 1 border top + 1 border bottom).
; Neighbor offsets from IX: up=-34 ($DE), left=-1 ($FF), right=+1, down=+34 ($22).
; ==========================================================================
XD780:	LD	HL,XDB31	; d780  21 31 db	\  Copy entire active state to scratch
	LD	DE,XDE83	; d783  11 83 de	|  buffer so we read from previous gen
	LD	BC,X0352	; d786  01 52 03	|  while writing new values
	LDIR			; d789  ed b0		/
	LD	HL,XDB54	; d78b  21 54 db	HL = first interior cell in active grid
	LD	IX,XDEA6	; d78e  dd 21 a6 de	IX = first interior cell in scratch buffer
	LD	C,17H		; d792  0e 17		C = 23 rows to process
; --- Outer loop: process each row ---
XD794:	LD	B,20H		; d794  06 20		B = 32 columns per row
; --- Inner loop: process each cell ---
XD796:	LD	A,(IX+0DEH)	; d796  dd 7e de	A = neighbor above (offset -34 = $DE)
	ADD	A,(IX+0FFH)	; d799  dd 86 ff	A += neighbor left  (offset -1 = $FF)
	ADD	A,(IX+1)	; d79c  dd 86 01	A += neighbor right (offset +1)
	ADD	A,(IX+22H)	; d79f  dd 86 22	A += neighbor below (offset +34 = $22)
; --- A = neighbor sum (0-12). Look up in rule table ---
	LD	DE,XE1D5	; d7a2  11 d5 e1	DE = rule table base
	ADD	A,E		; d7a5  83		\  DE = rule table base + neighbor sum
	LD	E,A		; d7a6  5f		|  (16-bit add: E += A, carry into D)
	ADC	A,D		; d7a7  8a		|
	SUB	E		; d7a8  93		|
	LD	D,A		; d7a9  57		/
	LD	A,(DE)		; d7aa  1a		A = rule[neighbor_sum] = new cell value
	LD	(HL),A		; d7ab  77		Store new value in active grid
	INC	HL		; d7ac  23		Advance active grid pointer
	INC	IX		; d7ad  dd 23		Advance scratch buffer pointer
	DJNZ	XD796		; d7af  10 e5		Loop for all 32 columns
; --- Skip border cells at end/start of rows ---
	INC	HL		; d7b1  23		\  Skip 2 border cells in active grid
	INC	HL		; d7b2  23		/  (right border of this row + left of next)
	INC	IX		; d7b3  dd 23		\  Skip 2 border cells in scratch buffer
	INC	IX		; d7b5  dd 23		/
	DEC	C		; d7b7  0d		Decrement row counter
	JR	NZ,XD794	; d7b8  20 da		Loop for all 23 rows
	RET			; d7ba  c9		Return
;
; ==========================================================================
; RENDER_GRID ($D7BB)
; ==========================================================================
; Renders the 32x23 cellular automaton grid to ZX Spectrum attribute
; memory. Each cell value (0-3) is looked up in the color map to get
; an attribute color, then OR'd with C (extra attribute bits, e.g. $38
; for white paper). Writes to $5820 (attribute row 1, skipping top row).
;
; Entry: C = extra attribute bits to OR with color (0 or $38)
; Uses alternate register set: DE' = color map base ($E1E8)
; ==========================================================================
XD7BB:	LD	HL,XDB54	; d7bb  21 54 db	HL = first interior cell in grid buffer
	LD	DE,X5820	; d7be  11 20 58	DE = attribute memory row 1 ($5800+32)
	LD	B,17H		; d7c1  06 17		B = 23 rows
	EXX			; d7c3  d9		Switch to alternate registers
	LD	DE,XE1E8	; d7c4  11 e8 e1	DE' = color map table base
	EXX			; d7c7  d9		Switch back to main registers
; --- Outer loop: each row ---
XD7C8:	PUSH	BC		; d7c8  c5		Save row counter
	LD	B,20H		; d7c9  06 20		B = 32 columns
; --- Inner loop: each cell in row ---
XD7CB:	LD	A,(HL)		; d7cb  7e		A = cell value (0-3)
	EXX			; d7cc  d9		Switch to alternate registers
	LD	L,A		; d7cd  6f		\  HL' = color_map_base + cell_value
	LD	H,0		; d7ce  26 00		|
	ADD	HL,DE		; d7d0  19		/
	LD	A,(HL)		; d7d1  7e		A = mapped color from color map
	EXX			; d7d2  d9		Switch back to main registers
	OR	C		; d7d3  b1		A = color OR extra_bits
	LD	(DE),A		; d7d4  12		Write attribute byte to screen
	INC	HL		; d7d5  23		Advance grid pointer
	INC	DE		; d7d6  13		Advance attribute pointer
	DJNZ	XD7CB		; d7d7  10 f2		Loop for all 32 columns
; --- Skip border cells between rows ---
	INC	HL		; d7d9  23		\  Skip 2 border cells in grid
	INC	HL		; d7da  23		/  (right of this row + left of next)
	POP	BC		; d7db  c1		Restore row counter
	DJNZ	XD7C8		; d7dc  10 ea		Loop for all 23 rows
	RET			; d7de  c9		Return
;
; ==========================================================================
; DATA: GRID BACKUP BUFFER ($D7DF-$DB30, 850 bytes)
; ==========================================================================
; Stores a backup copy of the active state (rule table + color map + grid)
; saved before running the automaton. Used by "Restore" in the pattern
; editor to undo a run. Format matches the active state at $DB31.
; ==========================================================================
XD7DF:	NOP			; d7df  00		(first byte of backup buffer)
;
	ORG	0DB31H
;
; ==========================================================================
; DATA: ACTIVE STATE BUFFER ($DB31-$DE82)
; ==========================================================================
; Active rule table + color map + cell grid. Layout:
;   $DB31-$DB53: Rule table (13 bytes) + padding + color map (4 bytes)
;   $DB54-$DE82: Cell grid buffer (34 * 25 = 850 bytes, with borders)
; Grid is 34 bytes wide (32 interior + 1 border each side) x 25 rows
; (23 interior + 1 border top + 1 border bottom).
; ==========================================================================
XDB31:	NOP			; db31  00		(first byte of active state)
XDB32:	NOP			; db32  00		(second byte, used as LDIR destination)
;
	ORG	0DB54H
;
; --- Cell grid: 34x25 buffer, cell values 0-3, borders are 0 ---
XDB54:	NOP			; db54  00		(first byte of cell grid)
;
	ORG	0DE83H
;
; ==========================================================================
; DATA: GENERATION SCRATCH BUFFER ($DE83-$E01E, 852 bytes)
; ==========================================================================
; Temporary copy of the grid used during generation computation.
; GENERATE_NEXT copies the active state here, then reads neighbors from
; this buffer while writing new values to the active grid at $DB54.
; ==========================================================================
XDE83:	NOP			; de83  00		(first byte of scratch buffer)
;
	ORG	0E01FH
;
XE01F:	NOP			; e01f  00		(padding)
;
	ORG	0E1D5H
;
; ==========================================================================
; DATA: RULE TABLE ($E1D5-$E1E1, 13 entries)
; ==========================================================================
; Maps neighbor sum (0-12) to new cell value (0-3).
; Rule[sum] = new_value. Modified by the rule editor.
; Default values: 0,1,0,2,2,0,?,?,2,1,2,1,3
; ==========================================================================
XE1D5:	DB	0		; e1d5  Rule[0]: sum=0 → value 0
;
	DB	1,0,2,2,0	; e1d6  Rule[1..5]: sums 1-5
;
	ORG	0E1DDH
;
	DB	2,1,2,1,3	; e1dd  Rule[8..12]: sums 8-12
;
	ORG	0E1E6H
;
; ==========================================================================
; DATA: AUTOMATON VARIABLES ($E1E6-$E1ED)
; ==========================================================================
XE1E6:	DB	0		; e1e6  Current speed (0=Fast,1=Med,2=Slow,3=S.Step)
;
XE1E7:	DB	1		; e1e7  Current editor colour number (0-3)
; --- Color map: cell value → ZX Spectrum color index ---
XE1E8:	DB	0,1,2		; e1e8  Colors for values 0,1,2 (Black,Blue,Red)
XE1EB:	DB	3		; e1eb  Color for value 3 (Magenta)
;
XE1EC:	DW	0		; e1ec  Generation counter (16-bit, little-endian)
;
	ORG	0E1EEH
;
; ==========================================================================
; DATA: COLOR NAME STRINGS ($E1EE-$E235)
; ==========================================================================
; Null-terminated strings for the 7 ZX Spectrum colors (indices 0-6).
; Padded with $1D (horizontal rule) and $7E (space/fill chars) to
; equal width for clean display in the color map editor.
; Used by XBB3B to find the Nth string in the table.
; ==========================================================================
XE1EE:	DB	'Black',1DH,7EH,7EH,7EH,0		; e1ee  Color 0: Black
	DB	'Blue',1DH,7EH,7EH,7EH,0		; e1f8  Color 1: Blue
	DB	'Red',1DH,7EH,7EH,7EH,7EH		; e201  Color 2: Red
;
	DB	0					; e209  (null terminator)
	DB	'Magenta'				; e20a  Color 3: Magenta
	DB	0,'Green',1DH,7EH			; e211  Color 4: Green
	DB	7EH,0,'Cyan',1DH,7EH			; e219  Color 5: Cyan
	DB	7EH,7EH,0				; e221  (null + padding)
	DB	'Yellow'				; e224  Color 6: Yellow
	DB	1DH,7EH,0,'White'			; e22a  Color 7: White (unused — max is 6)
	DB	1DH,7EH,7EH,0				; e232  (null terminator)
; ==========================================================================
; DATA: MAIN MENU STRING ($E236-$E263)
; ==========================================================================
; String for the main Freebie menu: "Run / Rule / Col.Map / Edit / Exit"
; Control codes: $1F=set position, $1E=set attribute, $1D=horiz rule
; ==========================================================================
XE236:	DB	1FH,0,0		; e236  Set cursor to (0,0)
	DB	1EH,'0'		; e239  Set attribute $30 (yellow paper)
	DB	'~Run'		; e23b  "Run" (~ = space)
	DB	1DH		; e23f  Horizontal rule
	DB	'~~Rule'	; e240  "Rule"
	DB	1DH		; e246  Horizontal rule
	DB	'~~Col.Map'	; e247  "Col.Map"
	DB	1DH		; e250  Horizontal rule
	DB	'~~Edit'	; e251  "Edit"
	DB	1DH		; e257  Horizontal rule
	DB	'~~~Exit'	; e258  "Exit"
	DB	1DH,7EH,7EH,7EH,0	; e25f  Trailing fill + null terminator
; ==========================================================================
; DATA: RULE EDITOR DISPLAY STRING ($E264-$E31A)
; ==========================================================================
; String data for the rule editor popup. Contains cursor positioning,
; attribute changes, and rule entry labels (sum values 0-12) with
; placeholder chars ($80-$8C) for the editable values. Each row shows:
;   sum_value  [<]  value_char  [>]
; The "]" ($5D) and "`" ($60) chars are left/right arrow markers.
; "B" ($42) at specific positions is the row label letter.
; ==========================================================================
XE264:	DB	1FH,28H,0		; e264  Set position (40,0)
	DB	1EH,0B0H		; e267  Set attribute $B0 (bright yellow paper)
	DB	7EH			; e269  Space fill
	DB	'Rule'			; e26a  Title "Rule"
	DB	1DH			; e26e  Horizontal rule
	DB	1CH,4,7EH		; e26f  Color code + space
	DB	1EH,30H			; e272  Set attribute $30 (yellow paper)
; --- Row entries for sums 0-12: position, block char, arrows ---
	DB	1FH,34H,2,80H		; e274  Row 2: sum=0, value char $80
	DB	1FH,42H,2,5DH		; e278  Arrow "]" at (66,2)
	DB	1FH,5CH,2		; e27c  Position (92,2)
	DB	60H			; e27f  Arrow "`"
	DB	1FH,34H,3,81H		; e280  Row 3: sum=1, value char $81
	DB	1FH,42H,3,5DH		; e284  Arrow "]" at (66,3)
	DB	1FH,5CH,3		; e288  Position (92,3)
	DB	60H			; e28b  Arrow "`"
	DB	1FH,34H,4,82H		; e28c  Row 4: sum=2, value char $82
	DB	1FH,42H,4,5DH		; e290  Arrow "]"
	DB	1FH,5CH,4		; e294  Position
	DB	60H			; e297  Arrow "`"
	DB	1FH,34H,5,83H		; e298  Row 5: sum=3
	DB	1FH,42H,5,5DH		; e29c  Arrow "]"
	DB	1FH,5CH,5		; e2a0  Position
	DB	60H			; e2a3  Arrow "`"
	DB	1FH,34H,6,84H		; e2a4  Row 6: sum=4
	DB	1FH,42H,6,5DH		; e2a8
	DB	1FH,5CH,6,60H		; e2ac
	DB	1FH,34H,7,85H		; e2b0  Row 7: sum=5
	DB	1FH,42H,7,5DH		; e2b4
	DB	1FH,5CH,7,60H		; e2b8
	DB	1FH,34H,8,86H		; e2bc  Row 8: sum=6
	DB	1FH,42H,8,5DH		; e2c0
	DB	1FH,5CH,8,60H		; e2c4
	DB	1FH,34H,9,87H		; e2c8  Row 9: sum=7
	DB	1FH,42H,9,5DH		; e2cc  Arrow "]"
	DB	1FH,5CH,9,60H		; e2d0  Arrow "`"
	DB	1FH,34H,0AH,88H	; e2d4  Row 10: sum=8
	DB	1FH,42H,0AH,5DH	; e2d8
	DB	1FH,5CH,0AH,60H	; e2dc
	DB	1FH,34H,0BH,89H	; e2e0  Row 11: sum=9
	DB	1FH,42H,0BH,5DH	; e2e4
	DB	1FH,5CH,0BH,60H	; e2e8
	DB	1FH,2AH,0CH,81H	; e2ec  Row 12: sum=10 (displayed as "10")
	DB	80H			; e2f0  Second digit char
	DB	1FH,42H,0CH,5DH	; e2f1
	DB	1FH,5CH,0CH,60H	; e2f5
	DB	1FH,2AH,0DH,81H	; e2f9  Row 13: sum=11
	DB	81H			; e2fd
	DB	1FH,42H,0DH,5DH	; e2fe
	DB	1FH,5CH,0DH,60H	; e302
	DB	1FH,2AH,0EH,81H	; e306  Row 14: sum=12
	DB	82H			; e30a
	DB	1FH,42H,0EH,5DH	; e30b
	DB	1FH,5CH,0EH,60H	; e30f
	DB	1FH,2AH,10H		; e313  Position for "Exit" label
	DB	'Exit'			; e316  "Exit" option
	DB	0			; e31a  Null terminator
; ==========================================================================
; DATA: COLOR MAP EDITOR DISPLAY STRING ($E31B-$E366)
; ==========================================================================
; String for the color map editor popup frame. Shows 4 entries
; (cell values 0-3) with left/right arrows and color name placeholders.
; ==========================================================================
XE31B:	DB	1EH,0B0H		; e31b  Set attribute $B0 (bright yellow paper)
	DB	1FH,48H,0		; e31d  Set position (72,0)
	DB	'~~Col.Map'		; e320  Title
	DB	1DH,1CH,5,7EH		; e329  Horiz rule + color code + space
	DB	1EH,30H			; e32d  Set attribute $30 (yellow paper)
; --- 4 color entries with arrows ---
	DB	1FH,4CH,2,80H		; e32f  Row 2: value 0, char $80
	DB	1FH,5CH,2,5DH		; e333  Arrow "]" (decrement)
	DB	1FH,0A4H,2,60H		; e337  Arrow "`" (increment)
	DB	1FH,4CH,3,81H		; e33b  Row 3: value 1, char $81
	DB	1FH,5CH,3,5DH		; e33f
	DB	1FH,0A4H,3,60H		; e343
	DB	1FH,4CH,4,82H		; e347  Row 4: value 2, char $82
	DB	1FH,5CH,4,5DH		; e34b
	DB	1FH,0A4H,4,60H		; e34f
	DB	1FH,4CH,5,83H		; e353  Row 5: value 3, char $83
	DB	1FH,5CH,5,5DH		; e357
	DB	1FH,0A4H,5,60H		; e35b
	DB	1FH,4CH,7		; e35f  Position for Exit
	DB	'Exit',0		; e362  "Exit" + null terminator
; ==========================================================================
; DATA: PATTERN EDITOR DISPLAY STRING ($E367-$E3B2)
; ==========================================================================
; String for the pattern editor popup. Shows colour selection (0-3),
; Clear, Restore, and Exit options.
; ==========================================================================
XE367:	DB	1EH,0B0H		; e367  Set attribute $B0 (bright yellow paper)
	DB	1FH,88H,0		; e369  Set position (136,0)
	DB	'~~Edit'		; e36c  Title
	DB	1DH,1CH,4,7EH		; e372  Horiz rule + color code + space
	DB	1EH,30H			; e376  Set attribute $30 (yellow paper)
	DB	1FH,8CH,2		; e378  Position for "Colour No"
	DB	'Colour No'		; e37b
; --- 4 colour selection options in 2x2 grid ---
	DB	1FH,8CH,3		; e384  Position row 3
	DB	80H,7EH,9EH,7EH	; e387  Value 0: block + space + marker + space
	DB	81H,7EH,9EH,7EH	; e38b  Value 1: block + space + marker + space
	DB	1FH,8CH,4		; e38f  Position row 4
	DB	82H,7EH,9EH,7EH	; e392  Value 2
	DB	83H,7EH,9EH		; e396  Value 3
; --- Action options ---
	DB	1FH,8CH,6		; e399  Position row 6
	DB	'Clear'			; e39c  "Clear" option
	DB	1FH,8CH,7		; e3a1  Position row 7
	DB	'Restore'		; e3a4  "Restore" option
	DB	1FH,8CH,8		; e3ab  Position row 8
	DB	'Exit',0		; e3ae  "Exit" + null terminator
; ==========================================================================
; DATA: SPEED SELECTION STRING ($E3B3-$E3F6)
; ==========================================================================
; String for the speed selection popup. Shows Run title, speed options
; (Fast/Med/Slow/S.Step), Go! and Cancel buttons.
; ==========================================================================
XE3B3:	DB	1EH,0B0H		; e3b3  Set attribute $B0 (bright yellow paper)
	DB	1FH,0,0			; e3b5  Set position (0,0)
	DB	'~Run'			; e3b8  Title "Run" (~ = space)
	DB	1DH,1CH,4,7EH		; e3bc  Horiz rule + color + space
	DB	1EH,30H			; e3c0  Set attribute $30 (yellow paper)
	DB	1FH,4,2			; e3c2  Position (4,2)
	DB	'Speed'			; e3c5  "Speed" label
	DB	1FH,4,3			; e3ca  Position (4,3)
	DB	'Fast'			; e3cd  Speed 0
	DB	1FH,4,4			; e3d1  Position (4,4)
	DB	'Med'			; e3d4  Speed 1
	DB	1FH,4,5			; e3d7  Position (4,5)
	DB	'Slow'			; e3da  Speed 2
	DB	1FH,4,6			; e3de  Position (4,6)
	DB	'S.Step'		; e3e1  Speed 3 (single step)
	DB	1FH,4,8			; e3e7  Position (4,8)
	DB	'Go!'			; e3ea  Accept button
	DB	1FH,4,0AH		; e3ed  Position (4,10)
	DB	'Cancel'		; e3f0  Cancel button
	DB	0			; e3f6  Null terminator
; ==========================================================================
; DATA: GENERATION COUNTER STRINGS ($E3F7-$E405)
; ==========================================================================
; Two strings used during automaton run:
;   $E3F7: Prefix label drawn once ("Gen:" or similar header)
;   $E400: Generation number display (redrawn each frame)
; ==========================================================================
XE3F7:	DB	1EH,05H		; e3f7  Set attribute $05
	DB	1FH,0,0		; e3f9  Set position (0,0)
	DB	1CH,20H,7EH		; e3fc  Color code + space + fill
	DB	0			; e3ff  Null terminator
XE400:	DB	1EH,05H		; e400  Set attribute $05
	DB	1FH,0D8H,0		; e402  Set position (216,0)
	DB	0			; e405  Null terminator (number rendered separately)
;
	ORG	0E406H
;
XE406:	DB	0		; e406  (padding)
;
	ORG	0E408H
;
; ==========================================================================
; DATA: MAIN MENU SEGMENT TABLE ($E408-$E415)
; ==========================================================================
; Defines 5 selectable regions for the Freebie main menu:
; Run, Rule, Col.Map, Edit, Exit. Each entry is 3 bytes:
;   byte 0: left X position (in attribute columns)
;   byte 1: row Y position
;   byte 2: reserved/width
; Table terminated by $FF.
; ==========================================================================
	DB	5,5,0		; e408  Segment 0: Run
	DB	5,0AH,0	; e40b  Segment 1: Rule
	DB	8,12H,0		; e40e  Segment 2: Col.Map (wider)
	DB	6,18H,0		; e411  Segment 3: Edit
	DB	6,0FFH		; e414  Segment 4: Exit (FF=terminator/last)
; ==========================================================================
; DATA: RULE EDITOR SEGMENT TABLE ($E416-$E467)
; ==========================================================================
; 26 segments (13 pairs) for the 13 rule entries, each with
; decrement (left) and increment (right) options.
; Format: 3 bytes per segment (x, y, width).
; Segments 0-25 = rule pairs, segment 26 ($1A) = Exit.
; Terminated by $FF.
; ==========================================================================
XE416:	DB	8,2,2		; e416  Seg 0: Rule[0] decrement
	DB	0BH,2,2	; e419  Seg 1: Rule[0] increment
	DB	8,3,2		; e41c  Seg 2: Rule[1] decrement
	DB	0BH,3,2	; e41f  Seg 3: Rule[1] increment
	DB	8,4,2		; e422  Seg 4: Rule[2] dec
	DB	0BH,4,2	; e425  Seg 5: Rule[2] inc
	DB	8,5,2		; e428  Seg 6: Rule[3] dec
	DB	0BH,5,2	; e42b  Seg 7: Rule[3] inc
	DB	8,6,2		; e42e  Seg 8: Rule[4] dec
	DB	0BH,6,2	; e431  Seg 9: Rule[4] inc
	DB	8,7,2		; e434  Seg 10: Rule[5] dec
	DB	0BH,7,2	; e437  Seg 11: Rule[5] inc
	DB	8,8,2		; e43a  Seg 12: Rule[6] dec
	DB	8,9,2		; e43d  Seg 13: Rule[6] inc (note: x=8 not $0B)
	DB	0BH,9,2	; e440  Seg 14: Rule[7] dec
	DB	8,0AH,2	; e443  Seg 15: Rule[7] inc
	DB	0BH,0AH,2	; e446  Seg 16: Rule[8] dec
	DB	8,0BH,2	; e449  Seg 17: Rule[8] inc
	DB	0BH,0BH,2	; e44c  Seg 18: Rule[9] dec
	DB	8,0CH,2	; e44f  Seg 19: Rule[9] inc
	DB	0BH,0CH,2	; e452  Seg 20: Rule[10] dec
	DB	8,0DH,2	; e455  Seg 21: Rule[10] inc
	DB	0BH,0DH,2	; e458  Seg 22: Rule[11] dec
	DB	8,0EH,2	; e45b  Seg 23: Rule[11] inc
	DB	0BH,0EH,2	; e45e  Seg 24: Rule[12] dec
	DB	5,10H,8		; e461  Seg 25: (Exit label area)
	DB	0FFH		; e464  Terminator (segment 26 = Exit)
; ==========================================================================
; DATA: COLOR MAP EDITOR SEGMENT TABLE ($E468-$E483)
; ==========================================================================
; 8 segments (4 pairs) for the 4 color map entries, plus Exit.
; Terminated by $FF.
; ==========================================================================
XE468:	DB	0BH,2,2	; e468  Seg 0: Color[0] decrement
	DB	14H,2,2	; e46b  Seg 1: Color[0] increment
	DB	0BH,3,2	; e46e  Seg 2: Color[1] dec
XE46F:	DB	14H,3,2	; e471  Seg 3: Color[1] inc (note: XE46F label)
	DB	0BH,4,2	; e474  Seg 4: Color[2] dec
	DB	14H,4,2	; e477  Seg 5: Color[2] inc
	DB	0BH,5,2	; e47a  Seg 6: Color[3] dec
XE47D:	DB	14H,5,2	; e47d  Seg 7: Color[3] inc (note: XE47D label)
	DB	9,7,0DH	; e480  Seg 8: Exit (wide region)
	DB	0FFH		; e483  Terminator
; ==========================================================================
; DATA: PATTERN EDITOR SEGMENT TABLE ($E484-$E499)
; ==========================================================================
; 4 colour selections + Clear + Restore + Exit options.
; Terminated by $FF.
; ==========================================================================
XE484:	DB	13H,3,2	; e484  Seg 0: Colour 0
	DB	17H,3,2	; e487  Seg 1: Colour 1
	DB	13H,4,2	; e48a  Seg 2: Colour 2
	DB	17H,4,2	; e48d  Seg 3: Colour 3
	DB	11H,6,9	; e490  Seg 4: Clear
	DB	11H,7,9	; e493  Seg 5: Restore
	DB	11H,8,9	; e496  Seg 6: Exit
	DB	0FFH		; e499  Terminator
; ==========================================================================
; DATA: SPEED SELECTION SEGMENT TABLE ($E49A-$E4AC)
; ==========================================================================
; 4 speed options + Go! + Cancel. Terminated by $FF.
; ==========================================================================
XE49A:	DB	0,3,8		; e49a  Seg 0: Fast
	DB	0,4,8		; e49d  Seg 1: Med
	DB	0,5,8		; e4a0  Seg 2: Slow
	DB	0,6,8		; e4a3  Seg 3: S.Step
	DB	0,8,8		; e4a6  Seg 4: Go!
	DB	0,0AH,8	; e4a9  Seg 5: Cancel
	DB	0FFH		; e4ac  Terminator
	DB	7EH		; e4ad  (padding byte "~")
;
	ORG	0E4B4H
;
	DB	7EH		; e4b4  (padding)
; ==========================================================================
; DATA: TITLE SCREEN STRING ($E4B5-$E52F)
; ==========================================================================
; Displays the "Cellular 2D Automaton" title screen with subtitle,
; author credit, and menu options (Information / Start Automaton).
; ==========================================================================
XE4B5:	DB	1EH,70H		; e4b5  Set attribute $70 (white paper)
	DB	1FH,3FH,6	; e4b7  Set position (63,6)
	DB	'Cellular 2D Automaton'		; e4ba  Title
	DB	1FH,5BH,8	; e4cf  Set position (91,8)
	DB	'A rule based'			; e4d2  Subtitle line 1
	DB	1FH,46H,9	; e4de  Set position (70,9)
	DB	'Pattern Generator'		; e4e1  Subtitle line 2
	DB	1FH,40H,0CH	; e4f2  Set position (64,12)
	DB	'By Pete Cooke Dec 87'		; e4f5  Author credit
	DB	1FH,5CH,10H	; e509  Set position (92,16)
	DB	'Information'			; e50c  Menu option 1
	DB	1FH,4CH,12H	; e517  Set position (76,18)
	DB	'Start Automaton'		; e51a  Menu option 2
	DB	0			; e529  Null terminator
; --- Title screen segment table (2 menu options) ---
	DB	4,10H,18H	; e52a  Seg 0: Information
	DB	4,12H,18H	; e52d  Seg 1: Start Automaton
	DB	0FFH		; e530  Terminator
; ==========================================================================
; DATA: INFORMATION SCREEN STRING ($E531-$E6E6)
; ==========================================================================
; Multi-page information text explaining the cellular automaton rules.
; References John Conway's Game of Life and explains how neighbor sums
; and the RULE table determine new cell colours.
; ==========================================================================
	DB	1EH,46H		; e531  Set attribute $46 (green paper + cyan ink?)
	DB	1FH,3FH,2	; e533  Set position (63,2)
	DB	'Cellular 2D Automaton'		; e536  Title repeat
	DB	1FH,5CH,5	; e54b  Set position (92,5)
	DB	'Information'			; e54e  Section header
	DB	1EH,6		; e559  Set attribute $06
	DB	1FH,8,8		; e55b  Set position (8,8)
	DB	'This program is a variation on John'	; e55e
	DB	1FH,0,9	; e581  Set position (0,9)
	DB	'Conway',27H,'s Life. The screen is divided into' ; e584
	DB	1FH,0,0AH	; e5ad  Set position (0,10)
	DB	'a grid of CELLS and each cell can have'  ; e5b0
	DB	1FH,0,0BH	; e5d6  Set position (0,11)
	DB	'one of 4 colours. To calculate the colour' ; e5d9
	DB	1FH,0,0CH	; e602  Set position (0,12)
	DB	'value of a cell in the next generation the' ; e605
	DB	1FH,0,0DH	; e62f  Set position (0,13)
	DB	'computer adds the value of the cells'	; e632
	DB	1FH,0,0EH	; e656  Set position (0,14)
	DB	'left, right, above and below it.'	; e659
	DB	1FH,0,0FH	; e679  Set position (0,15)
	DB	'The corresponding entry in a table,'	; e67c
	DB	1FH,0,10H	; e69f  Set position (0,16)
	DB	'known as the RULE table, then gives'	; e6a2
	DB	1FH,0,11H	; e6c5  Set position (0,17)
	DB	'the new colour.'			; e6c8
	DB	1EH,46H		; e6d7  Set attribute $46
	DB	1FH,60H,16H	; e6d9  Set position (96,22)
	DB	'Press Fire'			; e6dc  Prompt
	DB	0			; e6e6  Null terminator
; ==========================================================================
; DATA: COPYRIGHT STRING ($E6E7-$E72B)
; ==========================================================================
; "Program Copyright Pete Cooke 1987.Coded for Firebird Software Dec 87"
; Null-terminated. Not displayed in-game (embedded metadata).
; ==========================================================================
	DB	'Program Copyright Pete Cooke 1987'	; e6e7
	DB	'.Coded for Firebird Software Dec 87'	; e707
	DB	0					; e72b  Null terminator
;
; ==========================================================================
; DATA: SPARSE REFERENCED ADDRESSES ($E87F-$ECCB)
; ==========================================================================
; Various addresses referenced by the disassembler but containing only
; zero bytes in the snapshot. May be runtime scratch variables or
; addresses referenced from code on other pages.
; ==========================================================================
	ORG	0E87FH
;
XE87F:	DB	0		; e87f  (referenced variable)
;
	ORG	0E8B7H
;
XE8B7:	DB	0		; e8b7  (referenced variable)
;
	ORG	0EA7FH
;
XEA7F:	DB	0		; ea7f  (referenced variable)
;
	ORG	0EABFH
;
XEABF:	DB	0		; eabf  (referenced variable)
;
	ORG	0EAFFH
;
XEAFF:	DB	0		; eaff  (referenced variable)
;
	ORG	0EB7FH
;
XEB7F:	DB	0		; eb7f  (referenced variable)
;
	ORG	0ECCBH
;
XECCB:	DB	0		; eccb  (referenced variable)
;
; ==========================================================================
; DATA: UNUSED ZERO-FILLED RAM ($EDC8-$EFFF)
; ==========================================================================
; 568 bytes of zero-filled memory. Likely unused padding or runtime
; scratch space. Contains four labeled addresses (XEDFE, XEDFF, XEFBF,
; XEFFE) that may be referenced from elsewhere.
; Only labeled addresses are shown; all other bytes are $00.
; ==========================================================================
	ORG	0EDC8H
;
	NOP			; edc8  00		(start of zero-filled block)
	NOP			; edc9  00		.
	NOP			; edca  00		.
	NOP			; edcb  00		.
	NOP			; edcc  00		.
	NOP			; edcd  00		.
	NOP			; edce  00		.
	NOP			; edcf  00		.
	NOP			; edd0  00		.
	NOP			; edd1  00		.
	NOP			; edd2  00		.
	NOP			; edd3  00		.
	NOP			; edd4  00		.
	NOP			; edd5  00		.
	NOP			; edd6  00		.
	NOP			; edd7  00		.
	NOP			; edd8  00		.
	NOP			; edd9  00		.
	NOP			; edda  00		.
	NOP			; eddb  00		.
	NOP			; eddc  00		.
	NOP			; eddd  00		.
	NOP			; edde  00		.
	NOP			; eddf  00		.
	NOP			; ede0  00		.
	NOP			; ede1  00		.
	NOP			; ede2  00		.
	NOP			; ede3  00		.
	NOP			; ede4  00		.
	NOP			; ede5  00		.
	NOP			; ede6  00		.
	NOP			; ede7  00		.
	NOP			; ede8  00		.
	NOP			; ede9  00		.
	NOP			; edea  00		.
	NOP			; edeb  00		.
	NOP			; edec  00		.
	NOP			; eded  00		.
	NOP			; edee  00		.
	NOP			; edef  00		.
	NOP			; edf0  00		.
	NOP			; edf1  00		.
	NOP			; edf2  00		.
	NOP			; edf3  00		.
	NOP			; edf4  00		.
	NOP			; edf5  00		.
	NOP			; edf6  00		.
	NOP			; edf7  00		.
	NOP			; edf8  00		.
	NOP			; edf9  00		.
	NOP			; edfa  00		.
	NOP			; edfb  00		.
	NOP			; edfc  00		.
	NOP			; edfd  00		.
XEDFE:	NOP			; edfe  00		.
XEDFF:	NOP			; edff  00		.
	NOP			; ee00  00		.
	NOP			; ee01  00		.
	NOP			; ee02  00		.
	NOP			; ee03  00		.
	NOP			; ee04  00		.
	NOP			; ee05  00		.
	NOP			; ee06  00		.
	NOP			; ee07  00		.
	NOP			; ee08  00		.
	NOP			; ee09  00		.
	NOP			; ee0a  00		.
	NOP			; ee0b  00		.
	NOP			; ee0c  00		.
	NOP			; ee0d  00		.
	NOP			; ee0e  00		.
	NOP			; ee0f  00		.
	NOP			; ee10  00		.
	NOP			; ee11  00		.
	NOP			; ee12  00		.
	NOP			; ee13  00		.
	NOP			; ee14  00		.
	NOP			; ee15  00		.
	NOP			; ee16  00		.
	NOP			; ee17  00		.
	NOP			; ee18  00		.
	NOP			; ee19  00		.
	NOP			; ee1a  00		.
	NOP			; ee1b  00		.
	NOP			; ee1c  00		.
	NOP			; ee1d  00		.
	NOP			; ee1e  00		.
	NOP			; ee1f  00		.
	NOP			; ee20  00		.
	NOP			; ee21  00		.
	NOP			; ee22  00		.
	NOP			; ee23  00		.
	NOP			; ee24  00		.
	NOP			; ee25  00		.
	NOP			; ee26  00		.
	NOP			; ee27  00		.
	NOP			; ee28  00		.
	NOP			; ee29  00		.
	NOP			; ee2a  00		.
	NOP			; ee2b  00		.
	NOP			; ee2c  00		.
	NOP			; ee2d  00		.
	NOP			; ee2e  00		.
	NOP			; ee2f  00		.
	NOP			; ee30  00		.
	NOP			; ee31  00		.
	NOP			; ee32  00		.
	NOP			; ee33  00		.
	NOP			; ee34  00		.
	NOP			; ee35  00		.
	NOP			; ee36  00		.
	NOP			; ee37  00		.
	NOP			; ee38  00		.
	NOP			; ee39  00		.
	NOP			; ee3a  00		.
	NOP			; ee3b  00		.
	NOP			; ee3c  00		.
	NOP			; ee3d  00		.
	NOP			; ee3e  00		.
	NOP			; ee3f  00		.
	NOP			; ee40  00		.
	NOP			; ee41  00		.
	NOP			; ee42  00		.
	NOP			; ee43  00		.
	NOP			; ee44  00		.
	NOP			; ee45  00		.
	NOP			; ee46  00		.
	NOP			; ee47  00		.
	NOP			; ee48  00		.
	NOP			; ee49  00		.
	NOP			; ee4a  00		.
	NOP			; ee4b  00		.
	NOP			; ee4c  00		.
	NOP			; ee4d  00		.
	NOP			; ee4e  00		.
	NOP			; ee4f  00		.
	NOP			; ee50  00		.
	NOP			; ee51  00		.
	NOP			; ee52  00		.
	NOP			; ee53  00		.
	NOP			; ee54  00		.
	NOP			; ee55  00		.
	NOP			; ee56  00		.
	NOP			; ee57  00		.
	NOP			; ee58  00		.
	NOP			; ee59  00		.
	NOP			; ee5a  00		.
	NOP			; ee5b  00		.
	NOP			; ee5c  00		.
	NOP			; ee5d  00		.
	NOP			; ee5e  00		.
	NOP			; ee5f  00		.
	NOP			; ee60  00		.
	NOP			; ee61  00		.
	NOP			; ee62  00		.
	NOP			; ee63  00		.
	NOP			; ee64  00		.
	NOP			; ee65  00		.
	NOP			; ee66  00		.
	NOP			; ee67  00		.
	NOP			; ee68  00		.
	NOP			; ee69  00		.
	NOP			; ee6a  00		.
	NOP			; ee6b  00		.
	NOP			; ee6c  00		.
	NOP			; ee6d  00		.
	NOP			; ee6e  00		.
	NOP			; ee6f  00		.
	NOP			; ee70  00		.
	NOP			; ee71  00		.
	NOP			; ee72  00		.
	NOP			; ee73  00		.
	NOP			; ee74  00		.
	NOP			; ee75  00		.
	NOP			; ee76  00		.
	NOP			; ee77  00		.
	NOP			; ee78  00		.
	NOP			; ee79  00		.
	NOP			; ee7a  00		.
	NOP			; ee7b  00		.
	NOP			; ee7c  00		.
	NOP			; ee7d  00		.
	NOP			; ee7e  00		.
	NOP			; ee7f  00		.
	NOP			; ee80  00		.
	NOP			; ee81  00		.
	NOP			; ee82  00		.
	NOP			; ee83  00		.
	NOP			; ee84  00		.
	NOP			; ee85  00		.
	NOP			; ee86  00		.
	NOP			; ee87  00		.
	NOP			; ee88  00		.
	NOP			; ee89  00		.
	NOP			; ee8a  00		.
	NOP			; ee8b  00		.
	NOP			; ee8c  00		.
	NOP			; ee8d  00		.
	NOP			; ee8e  00		.
	NOP			; ee8f  00		.
	NOP			; ee90  00		.
	NOP			; ee91  00		.
	NOP			; ee92  00		.
	NOP			; ee93  00		.
	NOP			; ee94  00		.
	NOP			; ee95  00		.
	NOP			; ee96  00		.
	NOP			; ee97  00		.
	NOP			; ee98  00		.
	NOP			; ee99  00		.
	NOP			; ee9a  00		.
	NOP			; ee9b  00		.
	NOP			; ee9c  00		.
	NOP			; ee9d  00		.
	NOP			; ee9e  00		.
	NOP			; ee9f  00		.
	NOP			; eea0  00		.
	NOP			; eea1  00		.
	NOP			; eea2  00		.
	NOP			; eea3  00		.
	NOP			; eea4  00		.
	NOP			; eea5  00		.
	NOP			; eea6  00		.
	NOP			; eea7  00		.
	NOP			; eea8  00		.
	NOP			; eea9  00		.
	NOP			; eeaa  00		.
	NOP			; eeab  00		.
	NOP			; eeac  00		.
	NOP			; eead  00		.
	NOP			; eeae  00		.
	NOP			; eeaf  00		.
	NOP			; eeb0  00		.
	NOP			; eeb1  00		.
	NOP			; eeb2  00		.
	NOP			; eeb3  00		.
	NOP			; eeb4  00		.
	NOP			; eeb5  00		.
	NOP			; eeb6  00		.
	NOP			; eeb7  00		.
	NOP			; eeb8  00		.
	NOP			; eeb9  00		.
	NOP			; eeba  00		.
	NOP			; eebb  00		.
	NOP			; eebc  00		.
	NOP			; eebd  00		.
	NOP			; eebe  00		.
	NOP			; eebf  00		.
	NOP			; eec0  00		.
	NOP			; eec1  00		.
	NOP			; eec2  00		.
	NOP			; eec3  00		.
	NOP			; eec4  00		.
	NOP			; eec5  00		.
	NOP			; eec6  00		.
	NOP			; eec7  00		.
	NOP			; eec8  00		.
	NOP			; eec9  00		.
	NOP			; eeca  00		.
	NOP			; eecb  00		.
	NOP			; eecc  00		.
	NOP			; eecd  00		.
	NOP			; eece  00		.
	NOP			; eecf  00		.
	NOP			; eed0  00		.
	NOP			; eed1  00		.
	NOP			; eed2  00		.
	NOP			; eed3  00		.
	NOP			; eed4  00		.
	NOP			; eed5  00		.
	NOP			; eed6  00		.
	NOP			; eed7  00		.
	NOP			; eed8  00		.
	NOP			; eed9  00		.
	NOP			; eeda  00		.
	NOP			; eedb  00		.
	NOP			; eedc  00		.
	NOP			; eedd  00		.
	NOP			; eede  00		.
	NOP			; eedf  00		.
	NOP			; eee0  00		.
	NOP			; eee1  00		.
	NOP			; eee2  00		.
	NOP			; eee3  00		.
	NOP			; eee4  00		.
	NOP			; eee5  00		.
	NOP			; eee6  00		.
	NOP			; eee7  00		.
	NOP			; eee8  00		.
	NOP			; eee9  00		.
	NOP			; eeea  00		.
	NOP			; eeeb  00		.
	NOP			; eeec  00		.
	NOP			; eeed  00		.
	NOP			; eeee  00		.
	NOP			; eeef  00		.
	NOP			; eef0  00		.
	NOP			; eef1  00		.
	NOP			; eef2  00		.
	NOP			; eef3  00		.
	NOP			; eef4  00		.
	NOP			; eef5  00		.
	NOP			; eef6  00		.
	NOP			; eef7  00		.
	NOP			; eef8  00		.
	NOP			; eef9  00		.
	NOP			; eefa  00		.
	NOP			; eefb  00		.
	NOP			; eefc  00		.
	NOP			; eefd  00		.
	NOP			; eefe  00		.
	NOP			; eeff  00		.
	NOP			; ef00  00		.
	NOP			; ef01  00		.
	NOP			; ef02  00		.
	NOP			; ef03  00		.
	NOP			; ef04  00		.
	NOP			; ef05  00		.
	NOP			; ef06  00		.
	NOP			; ef07  00		.
	NOP			; ef08  00		.
	NOP			; ef09  00		.
	NOP			; ef0a  00		.
	NOP			; ef0b  00		.
	NOP			; ef0c  00		.
	NOP			; ef0d  00		.
	NOP			; ef0e  00		.
	NOP			; ef0f  00		.
	NOP			; ef10  00		.
	NOP			; ef11  00		.
	NOP			; ef12  00		.
	NOP			; ef13  00		.
	NOP			; ef14  00		.
	NOP			; ef15  00		.
	NOP			; ef16  00		.
	NOP			; ef17  00		.
	NOP			; ef18  00		.
	NOP			; ef19  00		.
	NOP			; ef1a  00		.
	NOP			; ef1b  00		.
	NOP			; ef1c  00		.
	NOP			; ef1d  00		.
	NOP			; ef1e  00		.
	NOP			; ef1f  00		.
	NOP			; ef20  00		.
	NOP			; ef21  00		.
	NOP			; ef22  00		.
	NOP			; ef23  00		.
	NOP			; ef24  00		.
	NOP			; ef25  00		.
	NOP			; ef26  00		.
	NOP			; ef27  00		.
	NOP			; ef28  00		.
	NOP			; ef29  00		.
	NOP			; ef2a  00		.
	NOP			; ef2b  00		.
	NOP			; ef2c  00		.
	NOP			; ef2d  00		.
	NOP			; ef2e  00		.
	NOP			; ef2f  00		.
	NOP			; ef30  00		.
	NOP			; ef31  00		.
	NOP			; ef32  00		.
	NOP			; ef33  00		.
	NOP			; ef34  00		.
	NOP			; ef35  00		.
	NOP			; ef36  00		.
	NOP			; ef37  00		.
	NOP			; ef38  00		.
	NOP			; ef39  00		.
	NOP			; ef3a  00		.
	NOP			; ef3b  00		.
	NOP			; ef3c  00		.
	NOP			; ef3d  00		.
	NOP			; ef3e  00		.
	NOP			; ef3f  00		.
	NOP			; ef40  00		.
	NOP			; ef41  00		.
	NOP			; ef42  00		.
	NOP			; ef43  00		.
	NOP			; ef44  00		.
	NOP			; ef45  00		.
	NOP			; ef46  00		.
	NOP			; ef47  00		.
	NOP			; ef48  00		.
	NOP			; ef49  00		.
	NOP			; ef4a  00		.
	NOP			; ef4b  00		.
	NOP			; ef4c  00		.
	NOP			; ef4d  00		.
	NOP			; ef4e  00		.
	NOP			; ef4f  00		.
	NOP			; ef50  00		.
	NOP			; ef51  00		.
	NOP			; ef52  00		.
	NOP			; ef53  00		.
	NOP			; ef54  00		.
	NOP			; ef55  00		.
	NOP			; ef56  00		.
	NOP			; ef57  00		.
	NOP			; ef58  00		.
	NOP			; ef59  00		.
	NOP			; ef5a  00		.
	NOP			; ef5b  00		.
	NOP			; ef5c  00		.
	NOP			; ef5d  00		.
	NOP			; ef5e  00		.
	NOP			; ef5f  00		.
	NOP			; ef60  00		.
	NOP			; ef61  00		.
	NOP			; ef62  00		.
	NOP			; ef63  00		.
	NOP			; ef64  00		.
	NOP			; ef65  00		.
	NOP			; ef66  00		.
	NOP			; ef67  00		.
	NOP			; ef68  00		.
	NOP			; ef69  00		.
	NOP			; ef6a  00		.
	NOP			; ef6b  00		.
	NOP			; ef6c  00		.
	NOP			; ef6d  00		.
	NOP			; ef6e  00		.
	NOP			; ef6f  00		.
	NOP			; ef70  00		.
	NOP			; ef71  00		.
	NOP			; ef72  00		.
	NOP			; ef73  00		.
	NOP			; ef74  00		.
	NOP			; ef75  00		.
	NOP			; ef76  00		.
	NOP			; ef77  00		.
	NOP			; ef78  00		.
	NOP			; ef79  00		.
	NOP			; ef7a  00		.
	NOP			; ef7b  00		.
	NOP			; ef7c  00		.
	NOP			; ef7d  00		.
	NOP			; ef7e  00		.
	NOP			; ef7f  00		.
	NOP			; ef80  00		.
	NOP			; ef81  00		.
	NOP			; ef82  00		.
	NOP			; ef83  00		.
	NOP			; ef84  00		.
	NOP			; ef85  00		.
	NOP			; ef86  00		.
	NOP			; ef87  00		.
	NOP			; ef88  00		.
	NOP			; ef89  00		.
	NOP			; ef8a  00		.
	NOP			; ef8b  00		.
	NOP			; ef8c  00		.
	NOP			; ef8d  00		.
	NOP			; ef8e  00		.
	NOP			; ef8f  00		.
	NOP			; ef90  00		.
	NOP			; ef91  00		.
	NOP			; ef92  00		.
	NOP			; ef93  00		.
	NOP			; ef94  00		.
	NOP			; ef95  00		.
	NOP			; ef96  00		.
	NOP			; ef97  00		.
	NOP			; ef98  00		.
	NOP			; ef99  00		.
	NOP			; ef9a  00		.
	NOP			; ef9b  00		.
	NOP			; ef9c  00		.
	NOP			; ef9d  00		.
	NOP			; ef9e  00		.
	NOP			; ef9f  00		.
	NOP			; efa0  00		.
	NOP			; efa1  00		.
	NOP			; efa2  00		.
	NOP			; efa3  00		.
	NOP			; efa4  00		.
	NOP			; efa5  00		.
	NOP			; efa6  00		.
	NOP			; efa7  00		.
	NOP			; efa8  00		.
	NOP			; efa9  00		.
	NOP			; efaa  00		.
	NOP			; efab  00		.
	NOP			; efac  00		.
	NOP			; efad  00		.
	NOP			; efae  00		.
	NOP			; efaf  00		.
	NOP			; efb0  00		.
	NOP			; efb1  00		.
	NOP			; efb2  00		.
	NOP			; efb3  00		.
	NOP			; efb4  00		.
	NOP			; efb5  00		.
	NOP			; efb6  00		.
	NOP			; efb7  00		.
	NOP			; efb8  00		.
	NOP			; efb9  00		.
	NOP			; efba  00		.
	NOP			; efbb  00		.
	NOP			; efbc  00		.
	NOP			; efbd  00		.
	NOP			; efbe  00		.
XEFBF:	NOP			; efbf  00		.
	NOP			; efc0  00		.
	NOP			; efc1  00		.
	NOP			; efc2  00		.
	NOP			; efc3  00		.
	NOP			; efc4  00		.
	NOP			; efc5  00		.
	NOP			; efc6  00		.
	NOP			; efc7  00		.
	NOP			; efc8  00		.
	NOP			; efc9  00		.
	NOP			; efca  00		.
	NOP			; efcb  00		.
	NOP			; efcc  00		.
	NOP			; efcd  00		.
	NOP			; efce  00		.
	NOP			; efcf  00		.
	NOP			; efd0  00		.
	NOP			; efd1  00		.
	NOP			; efd2  00		.
	NOP			; efd3  00		.
	NOP			; efd4  00		.
	NOP			; efd5  00		.
	NOP			; efd6  00		.
	NOP			; efd7  00		.
	NOP			; efd8  00		.
	NOP			; efd9  00		.
	NOP			; efda  00		.
	NOP			; efdb  00		.
	NOP			; efdc  00		.
	NOP			; efdd  00		.
	NOP			; efde  00		.
	NOP			; efdf  00		.
	NOP			; efe0  00		.
	NOP			; efe1  00		.
	NOP			; efe2  00		.
	NOP			; efe3  00		.
	NOP			; efe4  00		.
	NOP			; efe5  00		.
	NOP			; efe6  00		.
	NOP			; efe7  00		.
	NOP			; efe8  00		.
	NOP			; efe9  00		.
	NOP			; efea  00		.
	NOP			; efeb  00		.
	NOP			; efec  00		.
	NOP			; efed  00		.
	NOP			; efee  00		.
	NOP			; efef  00		.
	NOP			; eff0  00		.
	NOP			; eff1  00		.
	NOP			; eff2  00		.
	NOP			; eff3  00		.
	NOP			; eff4  00		.
	NOP			; eff5  00		.
	NOP			; eff6  00		.
	NOP			; eff7  00		.
	NOP			; eff8  00		.
	NOP			; eff9  00		.
	NOP			; effa  00		.
	NOP			; effb  00		.
	NOP			; effc  00		.
	NOP			; effd  00		.
XEFFE:	NOP			; effe  00		.
	NOP			; efff  00		.
