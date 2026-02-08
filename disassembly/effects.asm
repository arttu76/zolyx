; ==========================================================================
; VISUAL EFFECTS & PRNG ($D3C4-$D500)
; ==========================================================================
;
; This module contains four distinct routines used for visual feedback and
; randomness in Zolyx:
;
; SET_BRIGHT_FIELD ($D3C4):
;   Sets bit 6 (BRIGHT) on all field attributes (rows 4-23).
;   Creates a bright flash effect. Used during fill events.
;   Called from CHECK_PAUSE to restore brightness after un-pausing,
;   but only if the game is not in a "dimmed overlay" state.
;
; RESET_BRIGHT_FIELD ($D3D3):
;   Clears bit 6 (BRIGHT) on all field attributes.
;   Used to dim the field during level complete and game over overlays.
;   Creates a visual contrast so the popup text is more readable.
;   Called from: LEVEL_COMPLETE ($C55D), GAME_OVER ($C674),
;               OUT_OF_TIME ($C6C9), CHECK_PAUSE ($C61B).
;
; PRNG ($D3E4):
;   Pseudo-random number generator. Returns 8-bit value in A.
;   Uses a linear feedback approach on a 16-bit seed combined with
;   the Z80 refresh register (R) for additional entropy.
;   Called during spark initialization (random offsets and directions),
;   chaser placement (trail_cursor_init.asm), menu effects, and
;   sound effect timing (utilities.asm $BB2D).
;
; INK_CYCLE ($D3F3):
;   INK color cycling animation on a rectangular attribute area.
;   Cycles the INK color (bits 0-2) through all 8 ZX colors.
;   16 iterations x 2 HALT frames = 32 frames = 640ms at 50fps.
;   PAPER, BRIGHT, and FLASH bits are preserved.
;   (Appears to be unused / dead code — no CALL references found.)
;
; RAINBOW_CYCLE ($D415):
;   Rainbow PAPER cycling animation on a rectangular attribute area.
;   Input: BC=row/col, DE=height/width (same as FILL_ATTR_RECT).
;   Cycles the PAPER color (bits 3-5) through all 8 ZX colors twice:
;     16 iterations x 2 HALT frames = 32 frames = 640ms.
;   Color sequence: cyan->green->yellow->white->black->blue->red->magenta->...
;   INK, BRIGHT, and FLASH bits are preserved.
;   Called from: LEVEL_COMPLETE ($C577), GAME_OVER ($C68E),
;               OUT_OF_TIME ($C6E3).
;
; ZX Spectrum Attribute Byte Format (for reference):
;   Bit 7: FLASH   (1=flashing)
;   Bit 6: BRIGHT  (1=bright colors)
;   Bits 5-3: PAPER color (0-7)
;   Bits 2-0: INK color (0-7)
;
; ZX Spectrum Attribute Memory Layout:
;   $5800-$5AFF = 768 bytes (32 columns x 24 rows)
;   Row 0 starts at $5800, each row is 32 bytes
;   Field rows 4-23 span $5880-$5AFF (640 = $280 bytes)
;


; ==========================================================================
; SET_BRIGHT_FIELD ($D3C4)
; ==========================================================================
; Sets the BRIGHT attribute (bit 6) on every cell in the game field area
; (rows 4 through 23, all 32 columns). This creates a brighter, more vivid
; appearance for the playing field. Called to restore field brightness after
; un-pausing, provided the game was in "bright" mode before the pause.
;
; The field area starts at attribute row 4 ($5880) and spans 640 bytes
; ($0280), covering 20 rows x 32 columns = 640 attribute cells.
;
; On entry: (no parameters)
; On exit:  HL = $5B00 (one past end of attribute area)
;           BC = $0000
;           A  = 0
;           All field attributes have bit 6 set
; ==========================================================================
SET_BRIGHT_FIELD:	LD	HL,X5880	; d3c4  21 80 58	!.X  ; HL = start of field attributes (row 4, col 0)
	LD	BC,X0280	; d3c7  01 80 02	...  ; BC = 640 bytes to process (20 rows x 32 cols)
XD3CA:	SET	6,(HL)		; d3ca  cb f6		Kv   ; Set bit 6 (BRIGHT) in the attribute byte at (HL)
	INC	HL		; d3cc  23		#    ; Advance to the next attribute cell
	DEC	BC		; d3cd  0b		.    ; Decrement the byte counter
	LD	A,B		; d3ce  78		x    ; Load high byte of counter into A
	OR	C		; d3cf  b1		1    ; OR with low byte: A=0 only when BC=0
	JR	NZ,XD3CA	; d3d0  20 f8		 x   ; If BC != 0, loop back to process next cell
	RET			; d3d2  c9		I    ; All 640 cells now have BRIGHT set; return
;

; ==========================================================================
; RESET_BRIGHT_FIELD ($D3D3)
; ==========================================================================
; Clears the BRIGHT attribute (bit 6) on every cell in the game field area
; (rows 4 through 23, all 32 columns). This dims the playing field to
; provide visual contrast when a popup overlay (game over, level complete,
; out of time, or pause) is displayed on top.
;
; Structurally identical to SET_BRIGHT_FIELD above, except it uses RES
; (reset bit) instead of SET (set bit).
;
; On entry: (no parameters)
; On exit:  HL = $5B00 (one past end of attribute area)
;           BC = $0000
;           A  = 0
;           All field attributes have bit 6 cleared
; ==========================================================================
RESET_BRIGHT_FIELD:	LD	HL,X5880	; d3d3  21 80 58	!.X  ; HL = start of field attributes (row 4, col 0)
	LD	BC,X0280	; d3d6  01 80 02	...  ; BC = 640 bytes to process (20 rows x 32 cols)
XD3D9:	RES	6,(HL)		; d3d9  cb b6		K6   ; Clear bit 6 (BRIGHT) in the attribute byte at (HL)
	INC	HL		; d3db  23		#    ; Advance to the next attribute cell
	DEC	BC		; d3dc  0b		.    ; Decrement the byte counter
	LD	A,B		; d3dd  78		x    ; Load high byte of counter into A
	OR	C		; d3de  b1		1    ; OR with low byte: A=0 only when BC=0
	JR	NZ,XD3D9	; d3df  20 f8		 x   ; If BC != 0, loop back to process next cell
	RET			; d3e1  c9		I    ; All 640 cells now have BRIGHT cleared; return
;

; --------------------------------------------------------------------------
; PRNG Seed (2 bytes at $D3E2)
; --------------------------------------------------------------------------
; 16-bit seed value for the PRNG. Stored inline in the code segment
; (self-modifying data). Initial value is $0208 (little-endian: low=$08,
; high=$02). The seed is incremented each call, wrapping within a 8KB
; window ($0000-$1FFF) due to the RES 5,H masking.
; --------------------------------------------------------------------------
XD3E2:	DB	8,2					; d3e2 ..  ; PRNG seed: low byte = $08, high byte = $02
;

; ==========================================================================
; PRNG ($D3E4) — Pseudo-Random Number Generator
; ==========================================================================
; Generates an 8-bit pseudo-random number returned in register A.
;
; Algorithm:
;   1. Load the 16-bit seed from $D3E2 into HL
;   2. Increment HL (advance through memory space)
;   3. Mask H to keep HL within $0000-$1FFF (clear bit 5 of H)
;      This constrains the seed to a 8192-address window
;   4. Store the updated seed back to $D3E2
;   5. Read the Z80 refresh register R into A (provides hardware entropy;
;      R increments with each instruction fetch, giving timing-dependent
;      randomness)
;   6. XOR A with the byte at address (HL) — this reads from whatever
;      data happens to live in the $0000-$1FFF range (ROM on a real
;      Spectrum), mixing ROM content with the R register for the final
;      random value.
;
; The combination of R (timing-dependent) and ROM data (deterministic but
; varying with the seed pointer) produces adequately random values for
; game purposes: spark direction choices, chaser initial placement offsets,
; and sound effect timing jitter.
;
; Note: The seed at $D3E2 is inline data, making this self-modifying in
; the sense that the PRNG state lives within the code segment. The LD/store
; pair at $D3E5/$D3EB reads and writes the two bytes at $D3E2.
;
; On entry: (no parameters)
; On exit:  A = pseudo-random 8-bit value
;           HL preserved (saved/restored via stack)
;           Flags: affected by XOR
; ==========================================================================
PRNG:	PUSH	HL		; d3e4  e5		e    ; Save HL (caller may be using it)
	LD	HL,(XD3E2)	; d3e5  2a e2 d3	*bS  ; Load 16-bit seed into HL from $D3E2
	INC	HL		; d3e8  23		#    ; Increment the seed by 1
	RES	5,H		; d3e9  cb ac		K,   ; Clear bit 5 of H, keeping HL in range $0000-$1FFF
	LD	(XD3E2),HL	; d3eb  22 e2 d3	"bS  ; Store the updated seed back to $D3E2
	LD	A,R		; d3ee  ed 5f		m_   ; Read the Z80 refresh register into A (hardware entropy)
	XOR	(HL)		; d3f0  ae		.    ; XOR A with byte at address HL (ROM content), mixing entropy
	POP	HL		; d3f1  e1		a    ; Restore HL to its original value
	RET			; d3f2  c9		I    ; Return with random value in A
;

; ==========================================================================
; INK_CYCLE ($D3F3) — INK Color Cycling Animation
; ==========================================================================
; Cycles the INK color (bits 0-2) of a rectangular attribute area through
; all 8 ZX Spectrum colors. Runs for 16 iterations (cycling through the
; 8 colors twice), with 2 HALT frames per step (32 frames total = 640ms).
;
; This routine is structurally identical to RAINBOW_CYCLE below, but
; operates on the INK bits (0-2) instead of the PAPER bits (3-5).
; No call sites were found in the disassembly — this may be dead code,
; a debugging leftover, or used via an indirect call not yet identified.
;
; Algorithm:
;   1. Call COMPUTE_ATTR_ADDR to convert (row,col) in BC to an attribute
;      memory address in HL.
;   2. Read the current attribute byte at that address into L (used as
;      the "working attribute" value).
;   3. Set H = 16 (iteration counter: 16 color steps).
;   4. Loop body:
;      a. Isolate the non-INK bits: A = L AND $F8 (preserves FLASH,
;         BRIGHT, PAPER — clears INK bits 0-2). Save on stack.
;      b. Compute next INK color: A = (L + 1) AND 7 (advance INK by 1,
;         wrapping 7->0). Store in L.
;      c. Merge: A = saved_non_INK_bits OR new_INK. Store back in L.
;      d. Save BC, DE, HL on stack (FILL_ATTR_RECT modifies them).
;      e. Wait 2 frames (two HALT instructions) for visible animation.
;      f. Call FILL_ATTR_RECT with A'=L (attribute), BC=row/col,
;         DE=height/width to paint the rectangle with the new color.
;      g. Restore HL, DE, BC from stack.
;      h. Decrement H (iteration counter). Loop if not zero.
;
; On entry: BC = row (B) / col (C) of rectangle top-left corner
;           DE = height (D) / width (E) of rectangle
;           A' = attribute byte to use (passed via EX AF,AF' in
;                FILL_ATTR_RECT; here the working value is in L
;                and gets passed through the CALL mechanism)
; On exit:  All registers modified
;
; Cross-references:
;   Calls COMPUTE_ATTR_ADDR ($BAE7) — see utilities.asm
;   Calls FILL_ATTR_RECT ($BAF6) — see utilities.asm
; ==========================================================================
XD3F3:	CALL	COMPUTE_ATTR_ADDR		; d3f3  cd e7 ba	Mg:  ; Convert (row,col) in BC to attr address in HL
	LD	L,(HL)		; d3f6  6e		n    ; Read current attribute byte at that address into L
	LD	H,10H		; d3f7  26 10		&.   ; H = 16 = iteration counter (cycle 8 colors x 2)
XD3F9:	LD	A,L		; d3f9  7d		}    ; A = current working attribute byte
	AND	0F8H		; d3fa  e6 f8		fx   ; Mask out INK bits (0-2), keep FLASH+BRIGHT+PAPER (bits 3-7)
	PUSH	AF		; d3fc  f5		u    ; Save the non-INK portion on the stack
	LD	A,L		; d3fd  7d		}    ; A = current working attribute byte again
	ADD	A,1		; d3fe  c6 01		F.   ; Increment by 1 (advances INK color by 1)
	AND	7		; d400  e6 07		f.   ; Mask to 3 bits: new INK color = (old + 1) MOD 8
	LD	L,A		; d402  6f		o    ; Store new INK color in L temporarily
	POP	AF		; d403  f1		q    ; Restore non-INK bits (FLASH+BRIGHT+PAPER) into A
	OR	L		; d404  b5		5    ; Merge: A = non-INK bits OR new INK color
	LD	L,A		; d405  6f		o    ; L = complete new attribute byte for this frame
	PUSH	BC		; d406  c5		E    ; Save row/col (FILL_ATTR_RECT destroys BC)
	PUSH	DE		; d407  d5		U    ; Save height/width (FILL_ATTR_RECT destroys DE)
	PUSH	HL		; d408  e5		e    ; Save working attribute (L) and counter (H)
	HALT			; d409  76		v    ; Wait for vertical retrace (frame 1 of 2)
;                                                        ; Each HALT waits ~20ms (1/50th sec on PAL Spectrum)
	HALT			; d40a  76		v    ; Wait for vertical retrace (frame 2 of 2)
;                                                        ; Total: 40ms per color step = visible but smooth
	CALL	FILL_ATTR_RECT		; d40b  cd f6 ba	Mv:  ; Fill the rectangle with new attribute (A' = attr byte)
	POP	HL		; d40e  e1		a    ; Restore working attribute (L) and counter (H)
	POP	DE		; d40f  d1		Q    ; Restore height/width
	POP	BC		; d410  c1		A    ; Restore row/col
	DEC	H		; d411  25		%    ; Decrement iteration counter (16 -> 0)
	JR	NZ,XD3F9	; d412  20 e5		 e   ; If counter != 0, loop for next color step
	RET			; d414  c9		I    ; All 16 iterations done; return
;

; ==========================================================================
; RAINBOW_CYCLE ($D415) — PAPER Color Cycling Animation
; ==========================================================================
; Cycles the PAPER color (bits 3-5) of a rectangular attribute area through
; all 8 ZX Spectrum colors, creating a rainbow flashing effect. Runs for
; 16 iterations (cycling through the 8 colors twice), with 2 HALT frames
; per step for a total of 32 frames = 640ms of animation at 50fps.
;
; This is the primary visual celebration effect, used for:
;   - LEVEL_COMPLETE ($C577): flashes the "Level Complete" popup
;   - GAME_OVER ($C68E): flashes the "Game Over" popup
;   - OUT_OF_TIME ($C6E3): flashes the "Out of Time" popup
;
; The color sequence depends on the starting PAPER color of the rectangle.
; With a typical starting attribute, the PAPER cycles through:
;   cyan -> green -> yellow -> white -> black -> blue -> red -> magenta
; (and repeats once more for the second cycle).
;
; INK, BRIGHT, and FLASH bits are preserved throughout the animation,
; so text remains readable against the changing background.
;
; Algorithm:
;   1. Call COMPUTE_ATTR_ADDR to convert (row,col) in BC to an attribute
;      memory address in HL.
;   2. Read the current attribute byte at that address into L (this
;      captures the existing colors so we preserve INK/BRIGHT/FLASH).
;   3. Set H = $10 = 16 (iteration counter).
;   4. Loop body:
;      a. Isolate non-PAPER bits: A = L AND $C7 (keep FLASH, BRIGHT,
;         and INK — clear PAPER bits 3-5). Save on stack.
;      b. Compute next PAPER color: A = (L + 8) AND $38.
;         Adding 8 advances bits 3-5 by one color step (8 = 1 << 3).
;         AND $38 masks to just the PAPER bits. Store in L.
;      c. Merge: A = saved_non_PAPER_bits OR new_PAPER. Store in L.
;      d. Save BC, DE, HL (FILL_ATTR_RECT destroys them).
;      e. Wait 2 frames (two HALT instructions).
;      f. Call FILL_ATTR_RECT to repaint the rectangle.
;         Note: FILL_ATTR_RECT expects the attribute byte in A' (the
;         alternate accumulator). The CALL convention here relies on
;         the attribute having been set up via EX AF,AF' inside
;         FILL_ATTR_RECT's entry code.
;      g. Restore HL, DE, BC from stack.
;      h. Decrement H. Loop if not zero.
;
; On entry: BC = row (B) / col (C) of rectangle top-left corner
;           DE = height (D) / width (E) of rectangle in cells
; On exit:  All registers modified
;           The rectangle's PAPER has been cycled and ends on a color
;           that is 16 steps (= 2 full cycles) past the original.
;
; Cross-references:
;   Calls COMPUTE_ATTR_ADDR ($BAE7) — converts (B=row, C=col) to
;         attribute address in HL. See utilities.asm.
;   Calls FILL_ATTR_RECT ($BAF6) — fills D rows x E cols starting at
;         (B=row, C=col) with attribute in A'. See utilities.asm.
;   Called from: LEVEL_COMPLETE in main_loop.asm ($C577)
;               GAME_OVER in death_scoring.asm ($C68E)
;               OUT_OF_TIME in death_scoring.asm ($C6E3)
; ==========================================================================
RAINBOW_CYCLE:	CALL	COMPUTE_ATTR_ADDR		; d415  cd e7 ba	Mg:  ; Convert (B=row, C=col) to attribute address in HL
	LD	L,(HL)		; d418  6e		n    ; Read current attribute byte at top-left corner into L
	LD	H,10H		; d419  26 10		&.   ; H = 16 = iteration counter (2 full color cycles)
XD41B:	LD	A,L		; d41b  7d		}    ; A = current working attribute byte
	AND	0C7H		; d41c  e6 c7		fG   ; Mask out PAPER bits (3-5); keep FLASH(7), BRIGHT(6), INK(0-2)
	PUSH	AF		; d41e  f5		u    ; Save the non-PAPER portion on the stack
	LD	A,L		; d41f  7d		}    ; A = current working attribute byte again
	ADD	A,8		; d420  c6 08		F.   ; Add 8: this increments bits 3-5 by 1 (next PAPER color)
	AND	38H		; d422  e6 38		f8   ; Isolate just the PAPER bits (mask $38 = 00111000b)
	LD	L,A		; d424  6f		o    ; Store new PAPER color in L temporarily
	POP	AF		; d425  f1		q    ; Restore non-PAPER bits (FLASH+BRIGHT+INK) into A
	OR	L		; d426  b5		5    ; Merge: A = non-PAPER bits OR new PAPER color
	LD	L,A		; d427  6f		o    ; L = complete new attribute byte for this frame
	PUSH	BC		; d428  c5		E    ; Save row/col (FILL_ATTR_RECT destroys BC)
	PUSH	DE		; d429  d5		U    ; Save height/width (FILL_ATTR_RECT destroys DE)
	PUSH	HL		; d42a  e5		e    ; Save working attribute (L) and counter (H)
	HALT			; d42b  76		v    ; Wait for vertical retrace (frame 1 of 2)
;                                                        ; HALT suspends CPU until next maskable interrupt (~20ms)
	HALT			; d42c  76		v    ; Wait for vertical retrace (frame 2 of 2)
;                                                        ; Two HALTs = 40ms pause per color = smooth visible cycling
	CALL	FILL_ATTR_RECT		; d42d  cd f6 ba	Mv:  ; Paint the entire rectangle with the new attribute byte
	POP	HL		; d430  e1		a    ; Restore working attribute (L) and iteration counter (H)
	POP	DE		; d431  d1		Q    ; Restore height/width for next iteration
	POP	BC		; d432  c1		A    ; Restore row/col for next iteration
	DEC	H		; d433  25		%    ; Decrement iteration counter (16, 15, ..., 1, 0)
	JR	NZ,XD41B	; d434  20 e5		 e   ; If counter != 0, loop to cycle to next color
	RET			; d436  c9		I    ; All 16 color steps done (2 full cycles); return
;

; --------------------------------------------------------------------------
; Unreferenced data / dead code ($D437-$D500)
; --------------------------------------------------------------------------
; The following bytes appear to be either:
;   - Leftover/dead code from development or an earlier version
;   - Data tables referenced by code not included in this segment
;   - Possibly unreachable code paths
;
; Some recognizable instruction patterns can be seen (LD HL, LD (HL),
; LDIR fragments indicated by ED B0, CALL instructions) but without
; clear entry points. These bytes are preserved verbatim from the
; original snapshot.
; --------------------------------------------------------------------------
	DB	21H,0,40H,36H,0,11H,1,40H		; d437 !.@6...@
	DB	1,0FFH,17H				; d43f ...
	DW	XB0ED		; d442   ed b0      m0
;
	DB	1,0,0,11H,20H,18H,3EH,30H		; d444 .... .>0
	DW	XF6CD		; d44c   cd f6      Mv
	DW	X21BA		; d44e   ba 21      :!
;
	DB	31H,0DBH,36H,0,11H,32H,0DBH,1		; d450 1[6..2[.
	DB	51H,3					; d458 Q.
	DW	XB0ED		; d45a   ed b0      m0
;
	DB	1,4,4,11H,18H,10H,3EH,70H		; d45c ......>p
	DW	X70CD		; d464   cd 70      Mp
	DW	X21BF		; d466   bf 21      ?!
	DW	XE4B5		; d468   b5 e4      5d
	DW	X26CD		; d46a   cd 26      M&
	DW	X21BC		; d46c   bc 21      <!
;
	DB	2AH,0E5H				; d46e *e
	DW	X18CD		; d470   cd 18      M.
	DW	XCDBF		; d472   bf cd      ?M
	DB	3AH					; d474 :
	DW	X30BF		; d475   bf 30      ?0
	DB	0FBH					; d477 {
	DW	X61CD		; d478   cd 61      Ma
	DW	XCDBF		; d47a   bf cd      ?M
	DB	3EH					; d47c >
	DW	X3AC0		; d47d   c0 3a      @:
	DB	0F6H					; d47f v
	DW	XB7BD		; d480   bd b7      =7
;
	DB	20H,14H,1,0,0,11H,20H,18H		; d482  ..... .
	DB	3EH,46H					; d48a >F
	DW	XF6CD		; d48c   cd f6      Mv
	DW	X21BA		; d48e   ba 21      :!
;
	DB	31H,0E5H				; d490 1e
	DW	X26CD		; d492   cd 26      M&
	DW	XCDBC		; d494   bc cd      <M
	DW	XBAB1		; d496   b1 ba      1:
;
	DB	1,0,0,11H,20H,18H,3EH,30H		; d498 .... .>0
	DW	XF6CD		; d4a0   cd f6      Mv
;
	DB	0BAH,0DDH,21H,10H			; d4a2 :]!.
	DW	X06FC		; d4a6   fc 06      |.
	DB	17H					; d4a8 .
	DW	X11C5		; d4a9   c5 11      E.
;
	DB	0ADH,0E4H,6,8				; d4ab -d..
	DW	X1AC5		; d4af   c5 1a      E.
;
	DB	13H,0DDH,6EH,0,0DDH,23H,0DDH,66H	; d4b1 .]n.]#]f
	DB	0,0DDH,23H,6,20H,77H,2CH,10H		; d4b9 .]#. w,.
	DW	XC1FC		; d4c1   fc c1      |A
	DB	10H					; d4c3 .
	DW	XC1EA		; d4c4   ea c1      jA
;
	DB	10H,0E1H,21H,36H			; d4c6 .a!6
	DW	XCDE2		; d4ca   e2 cd      bM
;
	DB	26H					; d4cc &
;
	CP	H		; d4cd  bc		<
XD4CE:	CALL	XD756		; d4ce  cd 56 d7	MVW
	LD	HL,XE406	; d4d1  21 06 e4	!.d
	CALL	XBF18		; d4d4  cd 18 bf	M.?
XD4D7:	CALL	XBF3A		; d4d7  cd 3a bf	M:?
	JR	C,XD527		; d4da  38 4b		8K
	LD	A,(XBDF2)	; d4dc  3a f2 bd	:r=
	RRA			; d4df  1f		.
	JR	NC,XD4D7	; d4e0  30 f5		0u
	LD	BC,(XBDEE)	; d4e2  ed 4b ee bd	mKn=
	SRL	B		; d4e6  cb 38		K8
	SRL	B		; d4e8  cb 38		K8
	SRL	B		; d4ea  cb 38		K8
	INC	B		; d4ec  04		.
	DEC	B		; d4ed  05		.
	JR	Z,XD4D7		; d4ee  28 e7		(g
	DEC	B		; d4f0  05		.
	SRL	C		; d4f1  cb 39		K9
	SRL	C		; d4f3  cb 39		K9
	SRL	C		; d4f5  cb 39		K9
	LD	L,B		; d4f7  68		h
	LD	H,0		; d4f8  26 00		&.
	ADD	HL,HL		; d4fa  29		)
	ADD	HL,HL		; d4fb  29		)
	ADD	HL,HL		; d4fc  29		)
	ADD	HL,HL		; d4fd  29		)
	PUSH	HL		; d4fe  e5		e
	LD	E,B		; d4ff  58		X
	LD	D,0		; d500  16 00		..
