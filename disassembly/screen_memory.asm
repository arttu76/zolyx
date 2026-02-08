; ==========================================================================
; SCREEN MEMORY & ZX SPECTRUM SYSTEM AREA
; ==========================================================================
;
; This file contains the raw screen memory captured from the Zolyx .SNA
; snapshot file. At snapshot time, this data represents the loading screen
; (title artwork). The game code clears and redraws the screen during
; level initialization, so this data is only visible briefly at load time.
;
; ==========================================================================
; ZX SPECTRUM SCREEN MEMORY LAYOUT OVERVIEW
; ==========================================================================
;
; The ZX Spectrum's screen occupies 6912 bytes of contiguous memory:
;
;   $4000-$57FF  Bitmap area   (6144 bytes = 256x192 pixels, 1 bit/pixel)
;   $5800-$5AFF  Attribute area (768 bytes = 32x24 colour cells)
;
; The screen is 256 pixels wide (32 bytes) and 192 pixels tall.
; Each byte encodes 8 horizontal pixels (MSB = leftmost pixel).
;
; --------------------------------------------------------------------------
; BITMAP ADDRESSING (NON-LINEAR)
; --------------------------------------------------------------------------
;
; The bitmap is NOT laid out in simple top-to-bottom raster order.
; Instead, the 192 pixel rows are divided into 3 "thirds" of 64 rows each.
; Within each third, the addressing interleaves pixel rows from different
; character rows, making the layout non-linear.
;
; A screen address is decoded from its 16-bit value as follows:
;
;   Bit: 15 14 13 | 12 11 | 10  9  8 | 7  6  5 | 4  3  2  1  0
;        ---------|-------|-----------|---------|----------------
;         0  1  0 | T1 T0 | P2 P1 P0 | R2 R1 R0|  C4 C3 C2 C1 C0
;
;   Bits 15-13: Always 010 (selects the screen at $4000)
;   Bits 12-11: Third number (0-2), selects which 64-pixel-tall band
;   Bits 10-8:  Pixel row within the character cell (0-7)
;   Bits 7-5:   Character row within the third (0-7)
;   Bits 4-0:   Column byte (0-31, selects which 8-pixel-wide byte)
;
; This means consecutive memory addresses do NOT correspond to consecutive
; screen lines. For example:
;
;   $4000 = Third 0, char row 0, pixel line 0, column 0  (screen line 0)
;   $4020 = Third 0, char row 0, pixel line 0, column 0  ... wait --
;
; Actually, incrementing by 32 ($20) moves to the NEXT column-0 byte,
; which is pixel line 1 of character row 0 (not the next character row).
; The layout within each third (2048 bytes) is:
;
;   Offset $000-$01F: char row 0, pixel line 0 (32 bytes)
;   Offset $020-$03F: char row 1, pixel line 0
;   Offset $040-$05F: char row 2, pixel line 0
;   ...
;   Offset $0E0-$0FF: char row 7, pixel line 0
;   Offset $100-$11F: char row 0, pixel line 1  <-- jumps back!
;   Offset $120-$13F: char row 1, pixel line 1
;   ...
;   Offset $1E0-$1FF: char row 7, pixel line 1
;   Offset $200-$21F: char row 0, pixel line 2
;   ...
;   Offset $7E0-$7FF: char row 7, pixel line 7
;
; The three thirds occupy:
;   Third 0: $4000-$47FF  (screen lines   0-63,  character rows  0-7)
;   Third 1: $4800-$4FFF  (screen lines  64-127, character rows  8-15)
;   Third 2: $5000-$57FF  (screen lines 128-191, character rows 16-23)
;
; --------------------------------------------------------------------------
; ATTRIBUTE FORMAT
; --------------------------------------------------------------------------
;
; The 768-byte attribute area at $5800-$5AFF provides colour for each
; 8x8 pixel character cell. The screen has 32 columns x 24 rows = 768 cells.
;
; Each attribute byte is structured as:
;
;   Bit 7:    FLASH  (0=off, 1=alternates INK/PAPER every 16 frames)
;   Bit 6:    BRIGHT (0=normal, 1=bright/high-intensity colours)
;   Bits 5-3: PAPER colour (background)
;   Bits 2-0: INK colour   (foreground)
;
; Colour values (0-7):
;   0=Black  1=Blue  2=Red  3=Magenta  4=Green  5=Cyan  6=Yellow  7=White
;
; The attribute at address $5800 + (row * 32) + column applies to the
; 8x8 pixel block at screen position (column*8, row*8).
;
; --------------------------------------------------------------------------
; MEMORY MAP
; --------------------------------------------------------------------------
;
;   $4000-$47FF  Bitmap Third 0  (2048 bytes, char rows 0-7,  lines 0-63)
;   $4800-$4FFF  Bitmap Third 1  (2048 bytes, char rows 8-15, lines 64-127)
;   $5000-$57FF  Bitmap Third 2  (2048 bytes, char rows 16-23, lines 128-191)
;   $5800-$5AFF  Colour attributes (768 bytes, 32x24 character cells)
;   $5B00-$5BFF  ZX Spectrum system variables
;   $5C00-$5FFF  ZX Spectrum system area (channels, BASIC program, etc.)
;
; --------------------------------------------------------------------------
; ZOLYX-SPECIFIC MEMORY REGIONS
; --------------------------------------------------------------------------
;
;   $6000-$77FF  SHADOW GRID - a second copy of the bitmap layout
;                Used by the game engine for entity navigation.
;                Key insight: the player's trail is NOT written to the shadow
;                grid. Sparks and chasers read the shadow grid to decide their
;                movement, so they see trail cells as empty space. This is how
;                entities can "chase" the player along unfilled territory.
;
;   $9000-$93FF  Trail buffer (3 bytes per point: X, Y, direction)
;                Records the player's drawing trail for later fill operations.
;
;   $9400-$97FF  Flood fill stack (2-byte coordinate pairs)
;                Temporary workspace for the scanline flood fill algorithm.
;
; --------------------------------------------------------------------------
; NOTE ON DISASSEMBLY FORMAT
; --------------------------------------------------------------------------
;
; The data below was extracted from the .SNA snapshot. Because this memory
; region is pure screen data (not executable code), the disassembler has
; somewhat arbitrarily interpreted some byte sequences as Z80 instructions
; (NOP, RST 38H, LD BC,xxxx, etc.). These are NOT real instructions --
; they are bitmap pixel data that happens to match opcode encodings.
; The DB/DW directives are raw data bytes. The ORG gaps between data
; blocks indicate zero-filled regions (blank areas of the loading screen).
;
; Most non-zero bytes are sparse because the loading screen artwork only
; occupies portions of the display. Zero bytes (blank/black pixels) are
; omitted by the disassembler, represented by ORG jumps to the next
; non-zero data location.

;
;  DZ80 V3.4.1 Z80 Disassembly of zolyx.bin
;  2026/02/08 00:55
;

; ==========================================================================
; BITMAP THIRD 0: $4000-$47FF
; ==========================================================================
;
; Screen lines 0-63 (the top 1/3 of the display).
; Character rows 0-7 (8 rows of 8x8 pixel cells).
;
; Address structure within this third:
;   $40xx-$41xx: pixel lines 0-1 of char rows 0-7
;   $42xx-$43xx: pixel lines 2-3 of char rows 0-7
;   $44xx-$45xx: pixel lines 4-5 of char rows 0-7
;   $46xx-$47xx: pixel lines 6-7 of char rows 0-7
;
; More precisely, for address $4YZC (hex):
;   Y (bits 10-8) = pixel line within char cell (0-7)
;   Z (bits 7-5)  = character row within third (0-7)
;   C (bits 4-0)  = column byte (0-31)
;
; The sparse data below represents the non-zero pixels of the loading
; screen's top third. Gaps between ORG directives are zero-filled
; (black/empty pixels).

	ORG	4000H
;
X4000:	NOP			; 4000  00		.
X4001:	NOP			; 4001  00		.
;
	ORG	402DH
;
	DB	60H					; 402d `
;
	ORG	4031H
;
	DB	2					; 4031 .
	DW	XC0FF		; 4032   ff c0      .@
;
;
	ORG	4037H
;
	DB	1FH					; 4037 .
;
	ORG	403AH
;
	DB	80H					; 403a .
;
	ORG	403FH
;
	DB	3FH,0FH,0F8H				; 403f ?.x
;
	ORG	4045H
;
	DB	3					; 4045 .
;
	ORG	4048H
;
	DW	XA0FE		; 4048   fe a0      ~ 
;
	DB	0,0FH					; 404a ..
	DW	X3AF0		; 404c   f0 3a      p:
;
	DB	0					; 404e .
;
	ORG	4053H
;
	RST	38H		; 4053  ff		.
;
	DB	0E0H,0,7				; 4054 `..
	DW	XA0FE		; 4057   fe a0      ~ 
	DB	3					; 4059 .
	DW	X80FF		; 405a   ff 80      ..
;
	DB	0,3FH					; 405c .?
	DW	X00EA		; 405e   ea 00      j.
;
;
	ORG	4062H
;
	DB	0FH					; 4062 .
	DW	XFBFF		; 4063   ff fb      .{
	DB	0FFH					; 4065 .
	DW	XFEAF		; 4066   af fe      /~
;
	DB	0A0H,3,0FDH				; 4068  .}
	DW	X7FD0		; 406b   d0 7f      P.
;
	DB	3EH,80H					; 406d >.
;
	ORG	4073H
;
	DB	3					; 4073 .
	DW	X80FF		; 4074   ff 80      ..
	DW	XEAFF		; 4076   ff ea      .j
;
;
	ORG	407AH
;
	DB	7					; 407a .
	DW	XFFFE		; 407b   fe ff      ~.
	DW	X00EA		; 407d   ea 00      j.
;
;
	ORG	4083H
;
	DB	7					; 4083 .
	DW	XA0FE		; 4084   fe a0      ~ 
;
	DB	1FH,0FAH,1,0FFH				; 4086 .z..
;
	ORG	408CH
;
	DB	1FH					; 408c .
	DW	X80BE		; 408d   be 80      >.
;
;
	ORG	4094H
;
	DB	1					; 4094 .
	DW	XFEFF		; 4095   ff fe      .~
;
;
	ORG	409AH
;
	DB	0FH					; 409a .
	DW	XF8FF		; 409b   ff f8      .x
;
;
	ORG	40A2H
;
	DB	1,0FFH,0A8H,0,0FH			; 40a2 ..(..
	DW	X00FE		; 40a7   fe 00      ~.
;
;
	ORG	40ABH
;
	DW	X1FFE		; 40ab   fe 1f      ~.
	DW	X80BE		; 40ad   be 80      >.
;
	DB	0					; 40af .
;
	ORG	40B3H
;
	DB	1,0FFH,0A8H				; 40b3 ..(
;
	ORG	40BCH
;
	RST	38H		; 40bc  ff		.
;
	DB	0E0H,0					; 40bd `.
;
	ORG	40C2H
;
	DW	XEA7F		; 40c2   7f ea      .j
;
	DB	0,0					; 40c4 ..
;
	LD	BC,XA0FF	; 40c6  01 ff a0	.. 
;
	ORG	40CCH
;
	DB	7EH					; 40cc ~
X40CD:	DB	7FH,0A0H				; 40cd . 
	DW	XFA7F		; 40cf   7f fa      .z
;
	DB	0A0H,2					; 40d1  .
	DW	XEABF		; 40d3   bf ea      ?j
;
;
	ORG	40DCH
;
	DB	7					; 40dc .
	DW	X80FE		; 40dd   fe 80      ~.
;
;
	ORG	40E1H
;
	DB	3,0FFH,0A0H				; 40e1 .. 
;
	ORG	40ECH
;
	DW	X7FCA		; 40ec   ca 7f      J.
;
	DB	0AAH					; 40ee *
;
	ORG	40F2H
;
	DB	0FH,0A8H,1FH				; 40f2 .(.
	DW	X0080		; 40f5   80 00      ..
;
;
	ORG	40FBH
;
	DB	0EH,0,1FH				; 40fb ...
X40FE:	DB	0F8H,0					; 40fe x.
;
	ORG	4129H
;
	RST	38H		; 4129  ff		.
;
	DW	X00F0		; 412a   f0 00      p.
;
	DB	0					; 412c .
;
	LD	(HL),B		; 412d  70		p
;
	ORG	4132H
;
	DB	3FH					; 4132 ?
	DW	X00F0		; 4133   f0 00      p.
;
;
	ORG	4137H
;
	DB	3FH					; 4137 ?
	DW	XFFF1		; 4138   f1 ff      q.
;
	DB	0E0H,0					; 413a `.
;
	ORG	413FH
;
	DW	X01F0		; 413f   f0 01      p.
;
	DB	0FFH					; 4141 .
;
	ORG	4145H
;
	DB	1FH					; 4145 .
;
	ORG	4148H
;
	DB	0F0H					; 4148 p
;
	ORG	414BH
;
	DB	3,0FDH,38H				; 414b .}8
;
	ORG	4153H
;
	RST	38H		; 4153  ff		.
;
	DW	X00C0		; 4154   c0 00      @.
	DB	7					; 4156 .
	DW	X00FE		; 4157   fe 00      ~.
	DB	1					; 4159 .
	DW	X80FF		; 415a   ff 80      ..
;
	DB	0,7FH					; 415c ..
	DW	X00C0		; 415e   c0 00      @.
;
;
	ORG	4164H
;
	DB	7,0FFH,7				; 4164 ...
	DW	X00FE		; 4167   fe 00      ~.
	DB	0FH					; 4169 .
	DW	X00FE		; 416a   fe 00      ~.
;
	DB	3FH,3CH,0				; 416c ?<.
;
	ORG	4173H
;
	DB	1,0FFH,81H				; 4173 ...
	DW	X80FF		; 4176   ff 80      ..
;
;
	ORG	417AH
;
	DB	7					; 417a .
;
	ORG	417DH
;
	DB	80H					; 417d .
;
	ORG	4183H
;
	DB	0FH,0FCH,0,1FH,0F8H,1,0FFH		; 4183 .|..x..
;
	ORG	418CH
;
	DB	1FH					; 418c .
	DW	X00BE		; 418d   be 00      >.
;
;
	ORG	4194H
;
	DB	3					; 4194 .
	DW	X00FF		; 4195   ff 00      ..
;
;
	ORG	419AH
;
	DB	3FH					; 419a ?
	DW	XF8FF		; 419b   ff f8      .x
;
;
	ORG	41A2H
;
	DB	3					; 41a2 .
	DW	X00FF		; 41a3   ff 00      ..
;
	DB	0,0FH,0FCH,0				; 41a5 ..|.
	DW	XFF7F		; 41a9   7f ff      ..
;
	DB	0FCH,1FH				; 41ab |.
	DW	X00BF		; 41ad   bf 00      ?.
;
;
	ORG	41B3H
;
	DB	3					; 41b3 .
	DW	X00FF		; 41b4   ff 00      ..
;
;
	ORG	41BCH
;
	RST	38H		; 41bc  ff		.
;
	DB	0E0H,0					; 41bd `.
;
	ORG	41C2H
;
	DB	7FH,0E0H,0				; 41c2 .`.
;
	ORG	41C7H
;
	RST	38H		; 41c7  ff		.
;
	DW	X00C0		; 41c8   c0 00      @.
;
	ORG	41CCH
;
	DW	X7FFE		; 41cc   fe 7f      ~.
	DB	83H					; 41ce .
	DW	XC0FF		; 41cf   ff c0      .@
;
;
	ORG	41D3H
;
	DW	XF07F		; 41d3   7f f0      .p
;
	DB	0					; 41d5 .
;
	ORG	41DCH
;
	DB	3					; 41dc .
	DW	X00FF		; 41dd   ff 00      ..
;
;
	ORG	41E1H
;
	DB	7					; 41e1 .
	DW	X00FE		; 41e2   fe 00      ~.
;
;
	ORG	41E8H
;
	DB	3FH					; 41e8 ?
;
	ORG	41ECH
;
	NOP			; 41ec  00		.
;
	DB	78H,0					; 41ed x.
;
	ORG	41F2H
;
	DB	1FH,80H,0FH				; 41f2 ...
	DW	X00C0		; 41f5   c0 00      @.
;
;
	ORG	41FBH
;
	DB	0EH,0,0FH,0FCH,0			; 41fb ...|.
;
	ORG	4228H
;
	DB	0FH					; 4228 .
;
	ORG	422DH
;
	RET	M		; 422d  f8		x
;
	ORG	4232H
;
	DB	1FH,0F8H,0				; 4232 .x.
;
	ORG	4237H
;
	DW	XEA7F		; 4237   7f ea      .j
	DW	XF0BF		; 4239   bf f0      ?p
;
	DB	0					; 423b .
;
	ORG	423EH
;
	DB	7					; 423e .
	DW	X00E2		; 423f   e2 00      b.
	DW	XE0FF		; 4241   ff e0      .`
;
;
	ORG	4245H
;
	DB	7FH					; 4245 .
;
	ORG	4248H
;
	DW	X80EA		; 4248   ea 80      j.
;
	DB	0,1,0F8H,3AH,0				; 424a ..x:.
;
	ORG	4253H
;
	DW	XE87F		; 4253   7f e8      .h
;
	DB	0,0FH					; 4255 ..
	DW	X80FE		; 4257   fe 80      ~.
	DB	0					; 4259 .
	DW	XE0FF		; 425a   ff e0      .`
;
	DB	1,0FFH,0A8H,0				; 425c ..(.
;
	ORG	4263H
;
	DB	0AAH					; 4263 *
	DW	XFEAF		; 4264   af fe      /~
	DW	XFEAF		; 4266   af fe      /~
;
	DB	80H,1FH					; 4268 ..
	DW	XD0FE		; 426a   fe d0      ~P
;
	DB	3FH,3EH					; 426c ?>
	DW	X0080		; 426e   80 00      ..
;
;
	ORG	4274H
;
	RST	38H		; 4274  ff		.
;
	DW	XFFE3		; 4275   e3 ff      c.
;
	DB	0A8H,0,0				; 4277 (..
;
	INC	BC		; 427a  03		.
;
	ORG	427DH
;
	DB	0A8H					; 427d (
;
	ORG	4283H
;
	DB	1FH,0FAH,80H,1FH,0FAH,1,0FFH		; 4283 .z..z..
;
	ORG	428CH
;
	DB	1FH					; 428c .
	DW	X80BE		; 428d   be 80      >.
;
;
	ORG	4294H
;
	DB	7					; 4294 .
	DW	XAAFE		; 4295   fe aa      ~*
	DW	X0080		; 4297   80 00      ..
;
	DB	1,0FFH					; 4299 ..
	DW	XFEFF		; 429b   ff fe      .~
;
;
	ORG	42A2H
;
	DB	3,0FFH,0A0H,0,0FH			; 42a2 .. ..
	DW	X80FE		; 42a7   fe 80      ~.
	DW	XFF7F		; 42a9   7f ff      ..
;
	DB	0FCH,1FH				; 42ab |.
	DW	X80BF		; 42ad   bf 80      ?.
;
;
	ORG	42B3H
;
	DB	3,0FFH,0A0H				; 42b3 .. 
;
	ORG	42BCH
;
	DW	XE87F		; 42bc   7f e8      .h
;
	DB	0					; 42be .
;
	ORG	42C2H
;
	RST	38H		; 42c2  ff		.
;
	DW	X00E8		; 42c3   e8 00      h.
;
	ORG	42C7H
;
	DB	7FH,0E0H,0,0,1				; 42c7 .`...
	DW	X7FFE		; 42cc   fe 7f      ~.
	DW	XFEAF		; 42ce   af fe      /~
;
	DB	0AAH,0,0				; 42d0 *..
	DW	XF8FF		; 42d3   ff f8      .x
;
	DB	0					; 42d5 .
;
	ORG	42DCH
;
	DB	1					; 42dc .
	DW	X80FF		; 42dd   ff 80      ..
;
;
	ORG	42E1H
;
	DB	7					; 42e1 .
	DW	XA0FE		; 42e2   fe a0      ~ 
;
;
	ORG	42E8H
;
	DB	0FH					; 42e8 .
;
	ORG	42EBH
;
	DW	XA8FE		; 42eb   fe a8      ~(
;
	DB	6AH,0A0H,0				; 42ed j .
;
	ORG	42F2H
;
	DB	1FH,0A0H,0FH,0E0H,0			; 42f2 . .`.
;
	ORG	42FDH
;
	DB	7					; 42fd .
	DW	X00FE		; 42fe   fe 00      ~.
;
;
	ORG	4328H
;
	DB	3FH					; 4328 ?
;
	ORG	432BH
;
	DW	X00F0		; 432b   f0 00      p.
;
	DB	0F0H					; 432d p
;
	ORG	4332H
;
	DB	1FH,0F8H,0				; 4332 .x.
;
	ORG	4337H
;
	DB	7FH,0E0H,1FH				; 4337 .`.
	DW	X00F0		; 433a   f0 00      p.
;
;
	ORG	433EH
;
	DB	3FH					; 433e ?
	DW	X00C0		; 433f   c0 00      @.
;
	DB	1FH,0FCH,0,3				; 4341 .|..
;
	ORG	4348H
;
	DW	X00C0		; 4348   c0 00      @.
;
	DB	4,0,0FDH,38H,0				; 434a ..}8.
;
	ORG	4353H
;
	DB	3FH					; 4353 ?
	DW	X00F0		; 4354   f0 00      p.
;
	DB	0FH,0FCH				; 4356 .|
;
	ORG	435AH
;
	DB	7FH,0E0H,3				; 435a .`.
	DW	X00FF		; 435d   ff 00      ..
;
;
	ORG	4364H
;
	DB	3FH,0F8H,0FH,0FCH,0,3FH			; 4364 ?x.|.?
	DW	X18FE		; 436a   fe 18      ~.
	DB	3FH					; 436c ?
	DW	X00BC		; 436d   bc 00      <.
;
;
	ORG	4374H
;
	DB	3FH					; 4374 ?
	DW	XFEFF		; 4375   ff fe      .~
;
;
	ORG	437AH
;
	DB	1					; 437a .
	DW	XFEFF		; 437b   ff fe      .~
;
;
	ORG	4383H
;
	DB	3FH					; 4383 ?
	DW	X00F0		; 4384   f0 00      p.
;
	DB	1FH,0F8H,1,0FFH				; 4386 .x..
;
	ORG	438CH
;
	DB	1FH					; 438c .
	DW	X00BE		; 438d   be 00      >.
;
;
	ORG	4394H
;
	DB	0FH,0FCH,0,0				; 4394 .|..
;
	LD	BC,XFFFF	; 4398  01 ff ff	...
;
	DB	0FH					; 439b .
	DW	X00FE		; 439c   fe 00      ~.
;
;
	ORG	43A2H
;
	DB	7					; 43a2 .
	DW	X00FE		; 43a3   fe 00      ~.
;
	DB	0,7					; 43a5 ..
	DW	X00FE		; 43a7   fe 00      ~.
	DB	3FH					; 43a9 ?
	DW	X78FF		; 43aa   ff 78      .x
	DB	1FH					; 43ac .
	DW	X00BF		; 43ad   bf 00      ?.
;
	DB	0					; 43af .
;
	LD	BC,XC0FF	; 43b0  01 ff c0	..@
;
	DW	XFE07		; 43b3   07 fe      .~
;
	ORG	43BCH
;
	DB	3FH					; 43bc ?
	DW	X00F0		; 43bd   f0 00      p.
;
;
	ORG	43C2H
;
	RST	38H		; 43c2  ff		.
;
	DW	X00C0		; 43c3   c0 00      @.
;
	ORG	43C7H
;
	DB	3FH					; 43c7 ?
	DW	X00F0		; 43c8   f0 00      p.
;
	DB	0,3					; 43ca ..
	DW	X7FFC		; 43cc   fc 7f      |.
	DW	XF8FF		; 43ce   ff f8      .x
;
;
	ORG	43D2H
;
	DB	1					; 43d2 .
	DW	XF8FC		; 43d3   fc f8      |x
;
;
	ORG	43DDH
;
	RST	38H		; 43dd  ff		.
;
	DW	X0080		; 43de   80 00      ..
;
	DB	0,7					; 43e0 ..
	DW	X00FE		; 43e2   fe 00      ~.
;
;
	ORG	43EBH
;
	RET	NZ		; 43eb  c0		@
;
	ORG	43F2H
;
	DB	1FH,80H,0FH				; 43f2 ...
	DW	X00C0		; 43f5   c0 00      @.
;
;
	ORG	43FDH
;
	DB	3					; 43fd .
	DW	X00FF		; 43fe   ff 00      ..
;
;
	ORG	4418H
;
	DB	1FH					; 4418 .
	DW	X00C0		; 4419   c0 00      @.
;
;
	ORG	442BH
;
	DW	X00FE		; 442b   fe 00      ~.
;
	DB	7AH					; 442d z
;
	ORG	4432H
;
	DB	0FH					; 4432 .
	DW	X00FE		; 4433   fe 00      ~.
;
;
	ORG	4437H
;
	RST	38H		; 4437  ff		.
;
	DW	X1FE8		; 4438   e8 1f      h.
;
	DB	0FAH,0					; 443a z.
;
	ORG	443EH
;
	RST	38H		; 443e  ff		.
;
	DB	0A8H,0,0FH,0FFH				; 443f (...
;
	ORG	4448H
;
	DB	0A8H,0,2,40H,0FCH,3AH,0			; 4448 (..@|:.
;
	ORG	4453H
;
	DB	1FH,0F8H,0,1FH,0FAH			; 4453 .x..z
	DW	X0080		; 4458   80 00      ..
	DB	3FH					; 445a ?
	DW	X07E8		; 445b   e8 07      h.
	DW	XA0FE		; 445d   fe a0      ~ 
;
	DB	0					; 445f .
;
	ORG	4464H
;
	DW	XEA7F		; 4464   7f ea      .j
	DB	8FH					; 4466 .
	DW	X80FE		; 4467   fe 80      ~.
	DW	XFE7F		; 4469   7f fe      .~
;
	DB	0DCH,3FH				; 446b \?
	DW	X80BE		; 446d   be 80      >.
;
;
	ORG	4474H
;
	DB	0FH					; 4474 .
	DW	XFEFF		; 4475   ff fe      .~
;
	DB	0A0H,0					; 4477  .
;
	ORG	447BH
;
	RST	38H		; 447b  ff		.
;
	DW	XA0FE		; 447c   fe a0      ~ 
;
	ORG	4483H
;
	DB	3FH,0FAH,0,1FH,0FAH,1,0FFH,0FFH		; 4483 ?z..z...
	DB	0E1H,1FH				; 448b a.
	DW	X80BE		; 448d   be 80      >.
;
	DB	0					; 448f .
;
	ORG	4494H
;
	DB	1FH,0FAH,80H				; 4494 .z.
;
	ORG	4499H
;
	DB	3FH					; 4499 ?
	DW	XAFFA		; 449a   fa af      z/
	DW	X80FE		; 449c   fe 80      ~.
;
;
	ORG	44A2H
;
	DB	0FH					; 44a2 .
	DW	XA0FE		; 44a3   fe a0      ~ 
;
	DB	0,7					; 44a5 ..
	DW	X80FE		; 44a7   fe 80      ~.
	DB	1FH					; 44a9 .
	DW	X30FE		; 44aa   fe 30      ~0
;
	DB	3FH,3FH,0A0H,0,1FH			; 44ac ?? ..
;
	ORG	44B3H
;
	DW	XFEE7		; 44b3   e7 fe      g~
;
	DB	0A0H					; 44b5  
;
	ORG	44BCH
;
	DB	1FH,0F8H,0				; 44bc .x.
;
	ORG	44C1H
;
	DB	1,0FFH,0A8H				; 44c1 ..(
;
	ORG	44C7H
;
	DB	1FH,0FCH,0,0,7				; 44c7 .|...
	DW	X7FFC		; 44cc   fc 7f      |.
	DW	XEAFF		; 44ce   ff ea      .j
	DW	X0080		; 44d0   80 00      ..
	DB	3					; 44d2 .
	DW	XFEFA		; 44d3   fa fe      z~
;
	DB	0					; 44d5 .
;
	ORG	44DDH
;
	RST	38H		; 44dd  ff		.
;
	DB	0E0H,0,0,0FH				; 44de `...
	DW	X80FE		; 44e2   fe 80      ~.
;
;
	ORG	44E9H
;
	DB	0AAH,0AAH,0AAH,80H,8,0			; 44e9 ***...
;
	ORG	44F2H
;
	DB	1FH,0A0H,0FH				; 44f2 . .
	DW	X00E8		; 44f5   e8 00      h.
;
;
	ORG	44FEH
;
	RST	38H		; 44fe  ff		.
;
	DW	X0080		; 44ff   80 00      ..
;
	ORG	450DH
;
	DB	20H					; 450d  
;
	ORG	4510H
;
X4510:	NOP			; 4510  00		.
;
	ORG	4520H
;
	DB	0F0H					; 4520 p
;
	ORG	4526H
;
	DB	3					; 4526 .
;
	ORG	4529H
;
	DB	0E0H,3					; 4529 `.
	DW	X90FF		; 452b   ff 90      ..
;
	DB	70H					; 452d p
;
	ORG	4532H
;
	DB	7					; 4532 .
	DW	X00FE		; 4533   fe 00      ~.
;
	DB	0					; 4535 .
;
	LD	BC,X80FF	; 4536  01 ff 80	...
;
	DB	0FH,0FCH				; 4539 .|
;
	ORG	453DH
;
	DB	3					; 453d .
	DW	X00FE		; 453e   fe 00      ~.
;
	DB	0					; 4540 .
;
	LD	BC,XFFFF	; 4541  01 ff ff	...
;
	ORG	4546H
;
	DW	XFFFD		; 4546   fd ff      }.
;
	DB	80H					; 4548 .
;
	ORG	454BH
;
	DB	20H,7FH,3CH				; 454b  .<
;
	ORG	4553H
;
	DB	0FH,0FCH,0,3FH,0F0H			; 4553 .|.?p
;
	ORG	455AH
;
	DB	3FH					; 455a ?
	DW	X1FF0		; 455b   f0 1f      p.
;
	DB	0FCH,0					; 455d |.
;
	ORG	4563H
;
	DB	1					; 4563 .
	DW	XC0FF		; 4564   ff c0      .@
;
	DB	0FH,0FCH,0				; 4566 .|.
	DW	XFE7F		; 4569   7f fe      .~
;
	DB	1CH,1FH,0BEH				; 456b ..>
;
	ORG	4574H
;
	DB	3					; 4574 .
	DW	XF8FF		; 4575   ff f8      .x
;
;
	ORG	457AH
;
	DB	1					; 457a .
	DW	XF8FF		; 457b   ff f8      .x
;
;
	ORG	4583H
;
	DB	7FH,0E0H,0,1FH,0F8H,1,0FFH		; 4583 .`..x..
	DW	XEDFF		; 458a   ff ed      .m
;
	DB	1FH,0BEH				; 458c .>
;
	ORG	4594H
;
	DB	3FH					; 4594 ?
	DW	X00F0		; 4595   f0 00      p.
;
;
	ORG	4599H
;
	DB	7,0E0H,3				; 4599 .`.
	DW	X00FF		; 459c   ff 00      ..
;
;
	ORG	45A2H
;
	DB	1FH,0F8H,0,0				; 45a2 .x..
;
	INC	BC		; 45a6  03		.
	RST	38H		; 45a7  ff		.
	NOP			; 45a8  00		.
;
	DB	0FH					; 45a9 .
	DW	X40FE		; 45aa   fe 40      ~@
;
	DB	3FH,3FH,0,0				; 45ac ??..
	DW	XF3FF		; 45b0   ff f3      .s
	DB	0FFH					; 45b2 .
	DW	XF8FF		; 45b3   ff f8      .x
;
;
	ORG	45BCH
;
	DB	1FH,0F8H,0				; 45bc .x.
;
	ORG	45C1H
;
	DB	1					; 45c1 .
	DW	X80FF		; 45c2   ff 80      ..
;
;
	ORG	45C7H
;
	DB	0FH					; 45c7 .
	DW	X00FF		; 45c8   ff 00      ..
;
	DB	0,1FH,0F8H,0FFH				; 45ca ..x.
	DW	X00FF		; 45ce   ff 00      ..
;
;
	ORG	45D2H
;
	DB	7,0E0H,3EH				; 45d2 .`>
;
	ORG	45DDH
;
	DB	7FH					; 45dd .
	DW	X00C0		; 45de   c0 00      @.
;
	DB	0,0FH,0FCH,0				; 45e0 ..|.
;
	ORG	45F2H
;
	DB	1FH,80H,0FH				; 45f2 ...
	DW	X00C0		; 45f5   c0 00      @.
;
;
	ORG	45FEH
;
	DB	3FH					; 45fe ?
	DW	X00C0		; 45ff   c0 00      @.
;
;
	ORG	460DH
;
	DB	20H					; 460d  
;
	ORG	4611H
;
	DB	1FH,0FCH,0				; 4611 .|.
;
	ORG	4617H
;
	DB	3FH,0FFH,0A8H				; 4617 ?.(
;
	ORG	4620H
;
	DB	7FH					; 4620 .
	DW	X0080		; 4621   80 00      ..
;
;
	ORG	4626H
;
	DB	1FH					; 4626 .
;
	ORG	4629H
;
	DB	0AAH,0AAH				; 4629 **
	DW	XC0FF		; 462b   ff c0      .@
;
	DB	7AH					; 462d z
;
	ORG	4632H
;
	DB	3					; 4632 .
	DW	X80FF		; 4633   ff 80      ..
;
	DB	0,1,0FFH,0A8H,7,0FEH			; 4635 ...(.~
;
	ORG	463DH
;
	DB	0FH					; 463d .
	DW	XA0FA		; 463e   fa a0      z 
;
;
	ORG	4645H
;
	DW	XFBBF		; 4645   bf fb      ?{
;
	DB	0FFH,0A0H,0,1,0A0H,7EH,3EH		; 4647 . .. ~>
;
	ORG	4653H
;
	DB	7					; 4653 .
	DW	X00FE		; 4654   fe 00      ~.
;
	DB	3FH,0FAH				; 4656 ?z
;
	ORG	465AH
;
	DB	1FH,0F8H,3FH,0FAH,80H			; 465a .x?z.
;
	ORG	4663H
;
	DB	3,0FFH,0A8H,1FH,0FAH,80H		; 4663 ..(.z.
	DW	XFEFF		; 4669   ff fe      .~
;
	DB	0DEH,1FH				; 466b ^.
	DW	X80BE		; 466d   be 80      >.
;
	DB	0					; 466f .
;
	ORG	4675H
;
	RST	38H		; 4675  ff		.
;
	DB	0FAH,80H				; 4676 z.
;
	ORG	467AH
;
	DB	3					; 467a .
	DW	XEAFF		; 467b   ff ea      .j
	DW	X0080		; 467d   80 00      ..
;
;
	ORG	4683H
;
	RST	38H		; 4683  ff		.
;
	DW	X00EA		; 4684   ea 00      j.
;
	DB	1FH,0FAH,1,0FFH				; 4686 .z..
	DW	XF1FF		; 468a   ff f1      .q
	DB	1FH					; 468c .
	DW	X80BE		; 468d   be 80      >.
;
	DB	0					; 468f .
;
	ORG	4694H
;
	DW	XEA7F		; 4694   7f ea      .j
;
	DB	0					; 4696 .
;
	ORG	4699H
;
	DB	2,0AAH,3				; 4699 .*.
	DW	X80FF		; 469c   ff 80      ..
;
;
	ORG	46A2H
;
	DB	1FH,0FAH				; 46a2 .z
	DW	X0080		; 46a4   80 00      ..
	DB	3					; 46a6 .
	DW	X80FF		; 46a7   ff 80      ..
	DB	3					; 46a9 .
	DW	X00FD		; 46aa   fd 00      }.
;
	DB	3FH,3FH,0A0H,3,0FFH,0AAH		; 46ac ?? ..*
	DW	XFFBF		; 46b2   bf ff      ?.
	DB	0FAH					; 46b4 z
	DW	X0080		; 46b5   80 00      ..
;
;
	ORG	46BCH
;
	DB	0FH					; 46bc .
	DW	X00FE		; 46bd   fe 00      ~.
;
;
	ORG	46C1H
;
	DB	3,0FFH,0A0H				; 46c1 .. 
;
	ORG	46C7H
;
	DB	7					; 46c7 .
	DW	X80FF		; 46c8   ff 80      ..
;
	DB	0,3FH,0F4H				; 46ca .?t
	DW	XFAFF		; 46cd   ff fa      .z
;
	DB	0A8H					; 46cf (
;
	ORG	46D2H
;
	DB	7					; 46d2 .
	DW	X1EEA		; 46d3   ea 1e      j.
	DW	X0080		; 46d5   80 00      ..
;
;
	ORG	46DDH
;
	DB	3FH					; 46dd ?
	DW	X00E8		; 46de   e8 00      h.
;
	DB	0,1FH,0FAH,80H				; 46e0 ..z.
;
	ORG	46F2H
;
	DB	1FH,0A0H,0FH				; 46f2 . .
	DW	X00E8		; 46f5   e8 00      h.
;
;
	ORG	46FEH
;
	DB	0FH					; 46fe .
	DW	X00F0		; 46ff   f0 00      p.
;
;
	ORG	470DH
;
	DB	60H					; 470d `
;
	ORG	4711H
;
	DB	7					; 4711 .
	DW	X00FF		; 4712   ff 00      ..
;
;
	ORG	4717H
;
	DB	7					; 4717 .
	DW	XF8FF		; 4718   ff f8      .x
;
;
	ORG	4720H
;
	DB	1FH					; 4720 .
	DW	X00C0		; 4721   c0 00      @.
;
;
	ORG	4726H
;
	DB	7FH					; 4726 .
;
	ORG	4729H
;
	NOP			; 4729  00		.
	NOP			; 472a  00		.
;
	DW	XF47F		; 472b   7f f4      .t
;
	DB	38H					; 472d 8
;
	ORG	4732H
;
	DB	1					; 4732 .
	DW	X80FF		; 4733   ff 80      ..
;
	DB	0,3					; 4735 ..
	DW	X00FF		; 4737   ff 00      ..
;
	DB	3,0FFH					; 4739 ..
;
	ORG	473DH
;
	DB	1FH					; 473d .
	DW	X00F0		; 473e   f0 00      p.
;
;
	ORG	4742H
;
	DB	3FH					; 4742 ?
	DW	XFEFF		; 4743   ff fe      .~
	DB	0FFH					; 4745 .
	DW	XFFE3		; 4746   e3 ff      c.
;
	DB	0,0,0F8H,10H,7FH,3CH,0			; 4748 ..x..<.
;
	ORG	4753H
;
	DB	7					; 4753 .
	DW	X00FE		; 4754   fe 00      ~.
;
	DB	7FH,0E0H				; 4756 .`
;
	ORG	475AH
;
	DB	0FH,0F8H				; 475a .x
	DW	XF07F		; 475c   7f f0      .p
;
	DB	0					; 475e .
;
	ORG	4763H
;
	DB	7					; 4763 .
	DW	X00FE		; 4764   fe 00      ~.
;
	DB	1FH,0F8H,0,0FFH				; 4766 .x..
	DW	X3EFF		; 476a   ff 3e      .>
;
	DB	1FH,0BEH				; 476c .>
;
	ORG	4775H
;
	RST	38H		; 4775  ff		.
;
	DB	0F8H,0					; 4776 x.
;
	ORG	477AH
;
	DB	7					; 477a .
	DW	XF0FF		; 477b   ff f0      .p
;
;
	ORG	4783H
;
	RST	38H		; 4783  ff		.
;
	DW	X00C0		; 4784   c0 00      @.
;
	DB	0FH,0FCH,0,0FFH				; 4786 .|..
	DW	XF0FF		; 478a   ff f0      .p
;
	DB	1FH,0BEH				; 478c .>
;
	ORG	4794H
;
	RST	38H		; 4794  ff		.
;
	DW	X00C0		; 4795   c0 00      @.
;
	ORG	479BH
;
	DB	1					; 479b .
	DW	X80FF		; 479c   ff 80      ..
;
;
	ORG	47A2H
;
	DB	3FH					; 47a2 ?
	DW	X00F0		; 47a3   f0 00      p.
;
	DB	0					; 47a5 .
;
	LD	BC,X80FF	; 47a6  01 ff 80	...
;
	DW	XFE00		; 47a9   00 fe      .~
;
	DW	X7E00		; 47ab   00 7e      .~
;
	DB	3FH,80H,1FH				; 47ad ?..
	DW	X00FE		; 47b0   fe 00      ~.
	DB	3					; 47b2 .
	DW	XC0FF		; 47b3   ff c0      .@
;
;
	ORG	47BCH
;
	DB	7					; 47bc .
	DW	X00FE		; 47bd   fe 00      ~.
;
;
	ORG	47C1H
;
	DB	3					; 47c1 .
	DW	X00FF		; 47c2   ff 00      ..
;
;
	ORG	47C7H
;
	DB	3					; 47c7 .
	DW	XE0FF		; 47c8   ff e0      .`
	DB	1					; 47ca .
	DW	XE0FF		; 47cb   ff e0      .`
	DW	XE0FF		; 47cd   ff e0      .`
;
	DB	0					; 47cf .
;
	ORG	47D2H
;
	DB	0FH					; 47d2 .
	DW	X1FC0		; 47d3   c0 1f      @.
;
;
	ORG	47DBH
;
	DB	0EH,0,3FH				; 47db ..?
	DW	X00F0		; 47de   f0 00      p.
;
	DB	0,1FH,0F8H,0				; 47e0 ..x.
;
	ORG	47F2H
;
	DB	1FH,80H,0FH				; 47f2 ...
	DW	X0080		; 47f5   80 00      ..
;
;
	ORG	47FEH
;
	DB	3,0FCH,0,1FH,0FAH			; 47fe .|..z
	; NOTE: The 5 bytes at $47FE extend to $4802, crossing into Third 1's
	; address space. The first 2 bytes ($47FE-$47FF) are in Third 0;
	; bytes at $4800-$4802 are technically in Third 1 address range.

; ==========================================================================
; BITMAP THIRD 1: $4800-$4FFF
; ==========================================================================
;
; Screen lines 64-127 (the middle 1/3 of the display).
; Character rows 8-15 (8 rows of 8x8 pixel cells).
;
; Same interleaved addressing as Third 0 but with base $4800:
;   $48xx-$49xx: pixel lines 0-1 of char rows 8-15
;   $4Axx-$4Bxx: pixel lines 2-3 of char rows 8-15
;   $4Cxx-$4Dxx: pixel lines 4-5 of char rows 8-15
;   $4Exx-$4Fxx: pixel lines 6-7 of char rows 8-15
;
; The data here continues the loading screen artwork (middle band).

	ORG	4812H
;
	DB	1FH,0E0H,1FH,0A8H,0			; 4812 .`.(.
;
	ORG	481FH
;
	RST	38H		; 481f  ff		.
	NOP			; 4820  00		.
	RST	38H		; 4821  ff		.
;
	DW	X03E8		; 4822   e8 03      h.
;
	DB	0FFH,0AAH				; 4824 .*
;
	ORG	4828H
;
	DB	15H					; 4828 .
;
	ORG	4840H
;
	DB	3					; 4840 .
	DW	XBFFE		; 4841   fe bf      ~?
;
	DB	0FAH,80H				; 4843 z.
;
	ORG	4848H
;
	DB	17H,80H,40H,3CH,0			; 4848 ..@<.
;
	ORG	4856H
;
	DB	1BH,58H,0				; 4856 .X.
;
	ORG	4860H
;
	DB	7					; 4860 .
	DW	XFAFF		; 4861   ff fa      .z
	DW	X0080		; 4863   80 00      ..
;
;
	ORG	4868H
;
	DB	1FH					; 4868 .
	DW	XEFBF		; 4869   bf ef      ?o
;
	DB	0CFH,0					; 486b O.
;
	ORG	4875H
;
	DB	3					; 4875 .
	DW	X5FFE		; 4876   fe 5f      ~_
;
	DB	0A1H,0					; 4878 !.
;
	ORG	4880H
;
	DB	0FH,0FAH,80H				; 4880 .z.
;
	ORG	4888H
;
	DB	1					; 4888 .
	DW	X01F0		; 4889   f0 01      p.
	DW	X00F0		; 488b   f0 00      p.
;
;
	ORG	4896H
;
	DW	XEB7F		; 4896   7f eb      .k
;
	DB	4,8,20H					; 4898 .. 
;
	ORG	48A0H
;
	DB	1EH,0A0H,0				; 48a0 . .
;
	ORG	48ABH
;
	DB	3,0E0H,0				; 48ab .`.
;
	ORG	48B8H
;
	DB	3,1,8					; 48b8 ...
;
	ORG	48C5H
;
	DB	18H					; 48c5 .
;
	ORG	48E5H
;
	DB	77H					; 48e5 w
	DW	X3FF0		; 48e6   f0 3f      p?
;
	DB	0,4,2,0					; 48e8 ....
;
	ORG	48EFH
;
	DB	80H					; 48ef .
	DW	X0080		; 48f0   80 00      ..
;
;
	ORG	4901H
;
	DB	3FH					; 4901 ?
	DW	X00F0		; 4902   f0 00      p.
;
;
	ORG	4906H
;
	DB	7FH,0E0H,0				; 4906 .`.
;
	ORG	4912H
;
	DB	0FH,0E0H,3FH				; 4912 .`?
;
	ORG	4921H
;
	RST	38H		; 4921  ff		.
;
	DB	80H,7					; 4922 ..
	DW	X00FE		; 4924   fe 00      ~.
;
;
	ORG	4928H
;
	DB	0AH,0A0H,0				; 4928 . .
;
	ORG	4940H
;
	DB	3					; 4940 .
	DW	X7FFC		; 4941   fc 7f      |.
;
	DB	0E0H,0					; 4943 `.
;
	ORG	4948H
;
	DB	2FH,1EH,0FH,9EH,0			; 4948 /....
;
	ORG	4956H
;
	DB	3CH,0C2H,0				; 4956 <B.
;
	ORG	4960H
;
	DB	7					; 4960 .
	DW	XE0FF		; 4961   ff e0      .`
;
;
	ORG	4968H
;
	DW	XFF5F		; 4968   5f ff      _.
	DW	XBFEF		; 496a   ef bf      o?
;
	DB	0					; 496c .
;
	ORG	4975H
;
	DB	3,9FH,1FH,0E1H,0			; 4975 ...a.
;
	ORG	4980H
;
	DB	0FH,0E0H,0				; 4980 .`.
;
	ORG	4989H
;
	DW	X53F9		; 4989   f9 53      yS
;
	DB	0E0H					; 498b `
;
	ORG	4996H
;
	DB	37H					; 4996 7
	DW	X0454		; 4997   54 04      T.
;
	DB	8,20H					; 4999 . 
;
	ORG	49A0H
;
	DB	1CH					; 49a0 .
;
	ORG	49ACH
;
	DB	0C0H					; 49ac @
;
	ORG	49B8H
;
	DB	0CH,2,8					; 49b8 ...
;
	ORG	49C7H
;
	DB	0E0H					; 49c7 `
;
	ORG	49E4H
;
	DB	1,7,0F7H,7FH,80H,4,1,2			; 49e4 ..w.....
	DB	2,8,0,40H,40H,0				; 49ec ...@@.
;
	ORG	4A01H
;
	DB	3FH,0FAH,0,0				; 4a01 ?z..
;
	RRA			; 4a05  1f		.
	RST	38H		; 4a06  ff		.
;
	DB	0F8H					; 4a07 x
;
	ORG	4A12H
;
	DB	0FH					; 4a12 .
	DW	XFEFF		; 4a13   ff fe      .~
;
	DB	0A0H,0					; 4a15  .
;
	ORG	4A1FH
;
	DB	0AH,0,0FFH,0A8H,1FH			; 4a1f ...(.
	DW	XA0FE		; 4a24   fe a0      ~ 
;
;
	ORG	4A28H
;
	DB	11H,3,0F8H				; 4a28 ..x
;
	ORG	4A37H
;
	DB	42H					; 4a37 B
;
	ORG	4A40H
;
	DB	3					; 4a40 .
	DW	XFFFE		; 4a41   fe ff      ~.
	DW	X00EA		; 4a43   ea 00      j.
;
;
	ORG	4A48H
;
	DB	0FH,73H					; 4a48 .s
	DW	XFEB9		; 4a4a   b9 fe      9~
;
	DB	0					; 4a4c .
;
	ORG	4A56H
;
	DB	7FH,0DBH,0				; 4a56 .[.
;
	ORG	4A60H
;
	DB	0FH					; 4a60 .
	DW	XEAFF		; 4a61   ff ea      .j
;
;
	ORG	4A68H
;
	DW	XFF5F		; 4a68   5f ff      _.
	DB	0F7H					; 4a6a w
	DW	X00BF		; 4a6b   bf 00      ?.
;
;
	ORG	4A75H
;
	DB	3,67H					; 4a75 .g
	DW	XA1FF		; 4a77   ff a1      .!
;
	DB	0					; 4a79 .
;
	ORG	4A80H
;
	DB	1FH					; 4a80 .
	DW	X00EA		; 4a81   ea 00      j.
;
;
	ORG	4A88H
;
	DB	3,7EH,0FH				; 4a88 .~.
	DW	X00C0		; 4a8b   c0 00      @.
;
;
	ORG	4A96H
;
	DB	1AH					; 4a96 .
	DW	X08E8		; 4a97   e8 08      h.
;
	DB	8,20H					; 4a99 . 
;
	ORG	4AA0H
;
	DB	1AH					; 4aa0 .
	DW	X0080		; 4aa1   80 00      ..
;
;
	ORG	4AB9H
;
	DB	0CH,10H,0				; 4ab9 ...
;
	ORG	4AC5H
;
	DB	38H					; 4ac5 8
;
	ORG	4AE4H
;
	DB	3,67H					; 4ae4 .g
	DW	X7EF8		; 4ae6   f8 7e      x~
	DW	X02C0		; 4ae8   c0 02      @.
;
	DB	0,81H,1,4,10H,20H,40H			; 4aea ..... @
;
	ORG	4B01H
;
	DB	7FH,0E0H,0,1				; 4b01 .`..
	DW	XF0FF		; 4b05   ff f0      .p
;
	DB	7EH					; 4b07 ~
;
	ORG	4B12H
;
	DB	7					; 4b12 .
	DW	XFEFF		; 4b13   ff fe      .~
;
;
	ORG	4B20H
;
	DB	1					; 4b20 .
	DW	X00FF		; 4b21   ff 00      ..
	DW	XF07F		; 4b23   7f f0      .p
;
;
	ORG	4B28H
;
	DB	8,8FH,0FEH				; 4b28 ..~
;
	ORG	4B40H
;
	DB	3,0F8H					; 4b40 .x
	DW	X80FF		; 4b42   ff 80      ..
;
	DB	0					; 4b44 .
;
	ORG	4B48H
;
	DB	0EH,0E1H				; 4b48 .a
	DW	XFEB0		; 4b4a   b0 fe      0~
;
	DB	0					; 4b4c .
;
	ORG	4B56H
;
	RST	38H		; 4b56  ff		.
;
	DW	X80C7		; 4b57   c7 80      G.
;
	ORG	4B60H
;
	DB	0FH					; 4b60 .
	DW	X80FF		; 4b61   ff 80      ..
;
;
	ORG	4B68H
;
	DW	XF9CF		; 4b68   cf f9      Oy
	DW	XFEF3		; 4b6a   f3 fe      s~
;
	DB	0					; 4b6c .
;
	ORG	4B75H
;
	DB	3,1BH,0FFH,61H,0			; 4b75 ...a.
;
	ORG	4B80H
;
	DB	1FH					; 4b80 .
	DW	X00C0		; 4b81   c0 00      @.
;
;
	ORG	4B88H
;
	DB	3,9FH					; 4b88 ..
	DW	X10FE		; 4b8a   fe 10      ~.
;
	DB	0					; 4b8c .
;
	ORG	4B96H
;
	DB	5					; 4b96 .
	DW	X1050		; 4b97   50 10      P.
;
	DB	10H,20H					; 4b99 . 
;
	ORG	4BA0H
;
	DB	18H					; 4ba0 .
;
	ORG	4BB9H
;
	DB	30H,10H,0				; 4bb9 0..
;
	ORG	4BC6H
;
	DB	1					; 4bc6 .
	DW	X00C0		; 4bc7   c0 00      @.
;
;
	ORG	4BE4H
;
	DB	3,9FH					; 4be4 ..
	DW	X7FFA		; 4be6   fa 7f      z.
;
	DB	50H,2,0,80H,81H,2,8,10H			; 4be8 P.......
	DB	0					; 4bf0 .
;
	ORG	4C01H
;
	DW	XEA7F		; 4c01   7f ea      .j
;
	DB	0,7,0FFH,0AAH				; 4c03 ...*
	DW	X80AF		; 4c07   af 80      /.
;
	DB	0					; 4c09 .
;
	ORG	4C12H
;
	DB	3					; 4c12 .
	DW	XFEFF		; 4c13   ff fe      .~
	DW	X0080		; 4c15   80 00      ..
;
;
	ORG	4C20H
;
	DB	1,0FFH,0A0H				; 4c20 .. 
	DW	XEAFF		; 4c23   ff ea      .j
	DW	X0080		; 4c25   80 00      ..
;
	DB	0,14H,3FH				; 4c27 ..?
	DW	X80FF		; 4c2a   ff 80      ..
;
	DB	0					; 4c2c .
;
	ORG	4C36H
;
	DB	1,86H,0					; 4c36 ...
;
	ORG	4C40H
;
	DB	3,0FBH					; 4c40 .{
	DW	XA8FF		; 4c42   ff a8      .(
;
	DB	0					; 4c44 .
;
	ORG	4C48H
;
	DB	1EH					; 4c48 .
	DW	XB4C5		; 4c49   c5 b4      E4
;
	DB	7FH,0					; 4c4b ..
;
	ORG	4C55H
;
	DB	1,8FH					; 4c55 ..
	DW	XC0FF		; 4c57   ff c0      .@
;
	DB	0					; 4c59 .
;
	ORG	4C60H
;
	DB	0FH					; 4c60 .
	DW	XA8FF		; 4c61   ff a8      .(
;
;
	ORG	4C68H
;
	DB	6FH					; 4c68 o
	DW	X4FFE		; 4c69   fe 4f      ~O
	DW	X00FE		; 4c6b   fe 00      ~.
;
;
	ORG	4C75H
;
	DB	3,3					; 4c75 ..
	DW	XA1FE		; 4c77   fe a1      ~!
;
	DB	8					; 4c79 .
;
	ORG	4C80H
;
	DB	1FH,0A8H,0				; 4c80 .(.
;
	ORG	4C88H
;
	DB	3,7,0F8H,78H,0				; 4c88 ..xx.
;
	ORG	4C98H
;
	DB	20H,10H,40H				; 4c98  .@
;
	ORG	4CA0H
;
	DB	12H					; 4ca0 .
;
	ORG	4CA5H
;
	DB	2					; 4ca5 .
;
	ORG	4CBAH
;
	DB	62H					; 4cba b
;
	ORG	4CC5H
;
	DB	78H,0F8H,0				; 4cc5 xx.
;
	ORG	4CE4H
;
	DB	7					; 4ce4 .
	DW	XF8FF		; 4ce5   ff f8      .x
;
	DB	0FDH,0A0H,2,0,40H,80H,82H,4		; 4ce7 } ..@...
	DB	8,0					; 4cef ..
;
	ORG	4D01H
;
	DB	7FH,0E0H,0,1FH,0FCH,0,1			; 4d01 .`..|..
	DW	X00C0		; 4d08   c0 00      @.
;
;
	ORG	4D13H
;
	RST	38H		; 4d13  ff		.
;
	DW	X00F0		; 4d14   f0 00      p.
;
	ORG	4D20H
;
	DB	1,0FFH,3				; 4d20 ...
	DW	X80FF		; 4d23   ff 80      ..
;
;
	ORG	4D28H
;
	DB	22H					; 4d28 "
;
	ORG	4D2BH
;
	DB	0E0H					; 4d2b `
;
	ORG	4D40H
;
	DB	3,0FBH,0FEH				; 4d40 .{~
;
	ORG	4D48H
;
	DB	1EH					; 4d48 .
	DW	XB8E3		; 4d49   e3 b8      c8
	DW	X00FF		; 4d4b   ff 00      ..
;
;
	ORG	4D55H
;
	DB	1					; 4d55 .
	DW	XFFB7		; 4d56   b7 ff      7.
	DW	X00C0		; 4d58   c0 00      @.
;
;
	ORG	4D60H
;
	DB	0FH					; 4d60 .
	DW	X00FE		; 4d61   fe 00      ~.
;
;
	ORG	4D68H
;
	DW	XBFAF		; 4d68   af bf      /?
	DW	XBEBF		; 4d6a   bf be      ?>
;
	ORG	4D75H
;
	DB	1,83H					; 4d75 ..
	DW	X42FF		; 4d77   ff 42      .B
;
	DB	8					; 4d79 .
;
	ORG	4D80H
;
	DB	1FH					; 4d80 .
;
	ORG	4D8BH
;
	DB	3CH,4,0					; 4d8b <..
;
	ORG	4D98H
;
	DW	X20C0		; 4d98   c0 20      @ 
;
	DB	40H					; 4d9a @
;
	ORG	4DA0H
;
	DB	10H					; 4da0 .
;
	ORG	4DA7H
;
	DB	10H					; 4da7 .
;
	ORG	4DB9H
;
	DB	1,82H,0					; 4db9 ...
;
	ORG	4DC5H
;
	DB	3,0FBH,0B0H				; 4dc5 .{0
;
	ORG	4DE4H
;
	DB	0FH					; 4de4 .
;
	ORG	4DE8H
;
	DB	0D8H,1,0,40H,40H,81H,2,8		; 4de8 X..@@...
;
	ORG	4E01H
;
	RST	38H		; 4e01  ff		.
;
	DW	X00E8		; 4e02   e8 00      h.
	DB	3FH					; 4e04 ?
	DW	XA0FA		; 4e05   fa a0      z 
	DB	0					; 4e07 .
	DW	X0060		; 4e08   60 00      `.
;
;
	ORG	4E13H
;
	DB	2AH,0AAH,80H				; 4e13 **.
;
	ORG	4E20H
;
	DB	1					; 4e20 .
	DW	XAFFE		; 4e21   fe af      ~/
	DW	XA8FE		; 4e23   fe a8      ~(
;
;
	ORG	4E28H
;
	DB	15H					; 4e28 .
;
	ORG	4E2BH
;
	DB	0F0H					; 4e2b p
;
	ORG	4E36H
;
	DB	3,18H,0					; 4e36 ...
;
	ORG	4E40H
;
	DB	7					; 4e40 .
	DW	XFEFF		; 4e41   ff fe      .~
;
	DB	0A0H,0					; 4e43  .
;
	ORG	4E48H
;
	DB	1EH					; 4e48 .
	DW	X9DF7		; 4e49   f7 9d      w.
	DW	X00FF		; 4e4b   ff 00      ..
;
;
	ORG	4E55H
;
	DB	3,96H,3FH				; 4e55 ..?
	DW	X00E2		; 4e58   e2 00      b.
;
;
	ORG	4E60H
;
	DB	0FH					; 4e60 .
	DW	XA0FE		; 4e61   fe a0      ~ 
;
;
	ORG	4E68H
;
	DB	67H					; 4e68 g
	DW	XFECF		; 4e69   cf fe      O~
;
	DB	7CH,0					; 4e6b |.
;
	ORG	4E75H
;
	DB	1					; 4e75 .
	DW	XFAE7		; 4e76   e7 fa      gz
;
	DB	0C2H,8					; 4e78 B.
;
	ORG	4E80H
;
	DB	1FH,0A0H,0				; 4e80 . .
;
	ORG	4E8BH
;
	DB	0EH,8,0					; 4e8b ...
;
	ORG	4E97H
;
	DB	3,0,40H					; 4e97 ..@
	DW	X0080		; 4e9a   80 00      ..
;
;
	ORG	4EA0H
;
	DB	2					; 4ea0 .
;
	ORG	4EA5H
;
	DB	0CH					; 4ea5 .
;
	ORG	4EBAH
;
	DB	0CH					; 4eba .
;
	ORG	4EC5H
;
	DB	0FBH					; 4ec5 {
	DW	X3CF0		; 4ec6   f0 3c      p<
;
	DB	0,10H					; 4ec8 ..
;
	ORG	4ECFH
;
	DB	6					; 4ecf .
;
	ORG	4EE4H
;
	DB	1FH					; 4ee4 .
;
	ORG	4EE8H
;
	DB	0A0H,1,0,40H,40H,81H,1,4		; 4ee8  ..@@...
;
	ORG	4F01H
;
	RST	38H		; 4f01  ff		.
;
	DW	X00C0		; 4f02   c0 00      @.
	DW	XE0FF		; 4f04   ff e0      .`
;
	ORG	4F08H
;
	DB	8					; 4f08 .
;
	ORG	4F20H
;
	DB	1					; 4f20 .
	DW	X1FFE		; 4f21   fe 1f      ~.
;
	DB	0F8H,0					; 4f23 x.
;
	ORG	4F28H
;
	DB	23H					; 4f28 #
	DW	XF0E1		; 4f29   e1 f0      ap
;
	DB	0F8H,0					; 4f2b x.
;
	ORG	4F37H
;
	DB	40H					; 4f37 @
;
	ORG	4F40H
;
	DB	7					; 4f40 .
	DW	XF8FF		; 4f41   ff f8      .x
;
;
	ORG	4F48H
;
	DB	1FH					; 4f48 .
	DW	XDF7F		; 4f49   7f df      ._
	DW	X00FF		; 4f4b   ff 00      ..
;
;
	ORG	4F55H
;
	DB	3					; 4f55 .
	DW	XDFC6		; 4f56   c6 df      F_
;
	DB	0E1H,0					; 4f58 a.
;
	ORG	4F60H
;
	DB	0FH,0F8H,0				; 4f60 .x.
;
	ORG	4F68H
;
	DB	3					; 4f68 .
	DW	XF8E3		; 4f69   e3 f8      cx
;
	DB	0F8H,0					; 4f6b x.
;
	ORG	4F76H
;
	RST	38H		; 4f76  ff		.
;
	DW	X02FD		; 4f77   fd 02      }.
;
	DB	8,0					; 4f79 ..
;
	ORG	4F80H
;
	DB	1EH					; 4f80 .
;
	ORG	4F8BH
;
	DB	7,30H,0					; 4f8b .0.
;
	ORG	4F99H
;
	DB	80H,88H,0				; 4f99 ...
;
	ORG	4FA7H
;
	DB	70H					; 4fa7 p
;
	ORG	4FC5H
;
	DB	3					; 4fc5 .
	DW	XBEF7		; 4fc6   f7 be      w>
;
	DB	0,8,4,0					; 4fc8 ....
;
	ORG	4FCFH
;
	DB	1					; 4fcf .
;
	ORG	4FE4H
;
	DB	1FH					; 4fe4 .
;
	ORG	4FE8H
;
	DW	X01D4		; 4fe8   d4 01      T.
;
	DB	0,20H,40H,41H,1,4,0			; 4fea . @A...

; ==========================================================================
; BITMAP THIRD 2: $5000-$57FF
; ==========================================================================
;
; Screen lines 128-191 (the bottom 1/3 of the display).
; Character rows 16-23 (8 rows of 8x8 pixel cells).
;
; Same interleaved addressing as Thirds 0 and 1 but with base $5000:
;   $50xx-$51xx: pixel lines 0-1 of char rows 16-23
;   $52xx-$53xx: pixel lines 2-3 of char rows 16-23
;   $54xx-$55xx: pixel lines 4-5 of char rows 16-23
;   $56xx-$57xx: pixel lines 6-7 of char rows 16-23
;
; The loading screen's bottom third typically contains credit text
; and the lower portions of the title artwork. The data here becomes
; increasingly sparse toward the bottom of the screen.

	ORG	5001H
;
X5001:	NOP			; 5001  00		.
;
	ORG	5004H
;
	DB	3FH,1FH					; 5004 ?.
;
	RST	38H		; 5006  ff		.
	RST	38H		; 5007  ff		.
	XOR	B		; 5008  a8		(
	NOP			; 5009  00		.
	ADD	A,B		; 500a  80		.
	JR	NZ,X502D	; 500b  20 20		  
	LD	B,B		; 500d  40		@
	ADD	A,B		; 500e  80		.
	ADD	A,B		; 500f  80		.
	NOP			; 5010  00		.
;
	ORG	5024H
;
	DB	7FH					; 5024 .
;
	ORG	5028H
;
	DB	0D9H,1,0,40H,41H			; 5028 Y..@A
;
X502D:	NOP			; 502d  00		.
;
	ORG	5038H
;
	DB	16H,0DFH,0F4H,0AAH,97H,0FDH,0B4H	; 5038 ._t*.}4
;
	ORG	5044H
;
	DB	1FH					; 5044 .
;
	ORG	5047H
;
	DB	0AAH,4,8,2,0				; 5047 *....
;
	ORG	5058H
;
	DB	0FH					; 5058 .
;
	ORG	505BH
;
	DB	0C9H					; 505b I
;
	ORG	505EH
;
	DB	0F8H					; 505e x
;
	ORG	5065H
;
	DB	10H,82H,10H				; 5065 ...
;
	ORG	5079H
;
	DB	20H					; 5079  
;
	ORG	507CH
;
	DB	4,0,6					; 507c ...
;
	ORG	50E7H
;
	DB	1FH					; 50e7 .
;
	ORG	50ECH
;
	DB	31H,80H,1EH				; 50ec 1..
;
	ORG	50F5H
;
X50F5:	DB	1FH					; 50f5 .
	DW	X00B0		; 50f6   b0 00      0.
;
;
	ORG	5104H
;
	DB	3CH,0FH,0F8H,0FFH			; 5104 <.x.
	DW	X00D5		; 5108   d5 00      U.
;
	DB	80H,20H,20H,40H,80H			; 510a .  @.
	DW	X0080		; 510f   80 00      ..
;
;
	ORG	5124H
;
	DB	7FH					; 5124 .
;
	ORG	5128H
;
	DB	0F4H,1,0,40H,81H			; 5128 t..@.
;
	ORG	5138H
;
	DB	2FH					; 5138 /
	DW	XF5FF		; 5139   ff f5      .u
;
	DB	6BH,57H					; 513b kW
	DW	XFAFF		; 513d   ff fa      .z
;
;
	ORG	5144H
;
	DB	0FH					; 5144 .
	DW	XFEFF		; 5145   ff fe      .~
	DW	X50D5		; 5147   d5 50      UP
;
;
	ORG	5158H
;
	DB	15H					; 5158 .
;
	ORG	515BH
;
	DB	7FH					; 515b .
;
	ORG	515EH
;
	DB	54H					; 515e T
;
	ORG	5165H
;
	DB	2,29H,40H				; 5165 .)@
;
	ORG	5178H
;
	DB	4,0,80H,80H,80H,10H,2,0			; 5178 ........
;
	ORG	51B8H
;
	DW	X00C0		; 51b8   c0 00      @.
	DW	X80C0		; 51ba   c0 80      @.
;
	DB	6					; 51bc .
X51BD:	DB	0,80H					; 51bd ..
;
	ORG	51E7H
;
	DB	19H					; 51e7 .
	DW	X0080		; 51e8   80 00      ..
;
;
	ORG	51ECH
;
	DB	39H,80H,33H				; 51ec 9.3
;
	ORG	51F5H
;
	DB	18H					; 51f5 .
;
	ORG	5204H
;
	DB	3EH					; 5204 >
	DW	XE0EF		; 5205   ef e0      o`
;
	DB	7FH,68H,0,80H,20H,20H,40H,80H		; 5207 .h..  @.
	DW	X0080		; 520f   80 00      ..
;
;
	ORG	5224H
;
	DB	7FH,80H					; 5224 ..
	DW	XFF7F		; 5226   7f ff      ..
;
	DB	0AAH,1,0,40H,81H			; 5228 *..@.
;
	ORG	5238H
;
	DB	6FH					; 5238 o
	DW	XFDFF		; 5239   ff fd      .}
	DW	XDFBE		; 523b   be df      >_
	DW	XFBFF		; 523d   ff fb      .{
;
;
	ORG	5244H
;
	DB	7,0DDH					; 5244 .]
	DW	X3AEB		; 5246   eb 3a      k:
;
	DB	0					; 5248 .
;
	ORG	5258H
;
	DB	2AH					; 5258 *
;
	ORG	525BH
;
	DB	3EH					; 525b >
;
	ORG	525EH
;
	DB	2AH					; 525e *
;
	ORG	5266H
;
	DB	84H					; 5266 .
;
	ORG	5278H
;
	DB	3FH					; 5278 ?
	DW	XF7B7		; 5279   b7 f7      7w
	DW	XF6F7		; 527b   f7 f6      wv
	DW	XFEFE		; 527d   fe fe      ~~
;
	DB	0					; 527f .
;
	ORG	52B8H
;
	DB	0A0H,0,0A0H				; 52b8  . 
	DW	X08C0		; 52bb   c0 08      @.
;
	DB	0,80H					; 52bd ..
;
	ORG	52E7H
;
	DB	19H,9EH,3CH,78H				; 52e7 ..<x
	DW	X3DF0		; 52eb   f0 3d      p=
;
X52ED:	DB	80H,30H,7CH,78H				; 52ed .0|x
	DW	XE0F1		; 52f1   f1 e0      q`
;
	DB	3CH,78H,18H,33H				; 52f3 <x.3
	DW	X80C7		; 52f7   c7 80      G.
;
	DB	0					; 52f9 .
;
	ORG	5304H
;
	DB	7EH,87H					; 5304 ~.
	DW	X3FE7		; 5306   e7 3f      g?
;
	DB	0B4H,0,80H,20H,20H,40H			; 5308 4..  @
	DW	X0080		; 530e   80 00      ..
;
;
	ORG	5319H
;
	DB	10H					; 5319 .
;
	ORG	531DH
;
	DB	4					; 531d .
;
	ORG	5324H
;
	DB	7FH,7FH					; 5324 ..
	DW	XFBBF		; 5326   bf fb      ?{
;
	DB	54H,2,0,80H,82H				; 5328 T....
;
	ORG	5338H
;
	DB	3FH					; 5338 ?
	DW	XFDFF		; 5339   ff fd      .}
;
	DB	0FFH,0DFH				; 533b ._
	DW	XFEFF		; 533d   ff fe      .~
;
;
	ORG	5344H
;
	DB	3,6FH					; 5344 .o
	DW	X51BD		; 5346   bd 51      =Q
;
	DB	20H					; 5348  
;
	ORG	5358H
;
	DB	2AH					; 5358 *
;
	ORG	535BH
;
	DB	3EH					; 535b >
;
	ORG	535EH
;
	DB	2AH					; 535e *
;
	ORG	5379H
;
	DB	20H,10H,4,24H,2,82H,0			; 5379  ..$...
;
	ORG	53B8H
;
	DW	X40CA		; 53b8   ca 40      J@
;
	DB	0A4H,84H,8,44H,0A4H			; 53ba $..D$
;
	ORG	53E7H
;
	DB	1FH,33H,66H				; 53e7 .3f
	DW	X80C1		; 53ea   c1 80      A.
;
	DB	37H,80H,1EH,66H,0DH,9BH,30H,66H		; 53ec 7..f..0f
	DW	X1FCC		; 53f4   cc 1f      L.
;
	DB	36H,6CH					; 53f6 6l
	DW	X00C0		; 53f8   c0 00      @.
;
;
	ORG	5404H
;
	LD	A,A		; 5404  7f		.
	RRA			; 5405  1f		.
	CALL	P,XCA3F		; 5406  f4 3f ca	t?J
	ADD	A,B		; 5409  80		.
	ADD	A,B		; 540a  80		.
	JR	NZ,X542D	; 540b  20 20		  
	LD	B,B		; 540d  40		@
	ADD	A,B		; 540e  80		.
	NOP			; 540f  00		.
;
	ORG	5419H
;
	DB	0B4H					; 5419 4
;
	ORG	541DH
;
	DB	16H					; 541d .
	DW	X0080		; 541e   80 00      ..
;
;
	ORG	5424H
;
	DB	3EH					; 5424 >
	DW	XDFC3		; 5425   c3 df      C_
	DW	XA2FF		; 5427   ff a2      ."
;
	DB	2,0,81H,0				; 5429 ....
;
X542D:	NOP			; 542d  00		.
;
	ORG	5438H
;
	DB	3FH					; 5438 ?
	DW	XFCFF		; 5439   ff fc      .|
;
	DB	0FFH,9FH				; 543b ..
	DW	XFCFF		; 543d   ff fc      .|
;
;
	ORG	5444H
;
	DB	2,0FAH					; 5444 .z
	DW	XA8EE		; 5446   ee a8      n(
;
	DB	0					; 5448 .
;
	ORG	5458H
;
	DB	2AH					; 5458 *
;
	ORG	545BH
;
	DB	1CH					; 545b .
;
	ORG	545EH
;
	DB	2AH					; 545e *
;
	ORG	5478H
;
	DB	3FH,0A7H				; 5478 ?'
	DW	XF7E7		; 547a   e7 f7      gw
;
	DB	0F4H,0FCH,92H				; 547c t|.
;
	ORG	54B8H
;
	DB	0AAH,0					; 54b8 *.
	DW	X8ECE		; 54ba   ce 8e      N.
;
	DB	8,0AAH,0CEH				; 54bc .*N
;
	ORG	54E7H
;
	DB	18H,30H,7EH,78H				; 54e7 .0~x
	DW	X33F0		; 54eb   f0 33      p3
;
	DB	80H,3,66H,7DH,83H			; 54ed ..f}.
	DW	X66F0		; 54f2   f0 66      pf
	DW	X18C0		; 54f4   c0 18      @.
;
	DB	36H,0FH					; 54f6 6.
	DW	X00C0		; 54f8   c0 00      @.
;
;
	ORG	5504H
;
	DW	XFF7F		; 5504   7f ff      ..
;
	DB	0F8H,0FDH				; 5506 x}
	DW	X00E4		; 5508   e4 00      d.
;
	DB	80H,20H,20H,81H				; 550a .  .
;
	ORG	5518H
;
	DB	1,0A5H,40H,8,1,52H,0C0H			; 5518 .%@..R@
;
	ORG	5524H
;
	DB	3FH,0,0FH				; 5524 ?..
	DW	X50F5		; 5527   f5 50      uP
;
	DB	2,0					; 5529 ..
	DW	X0080		; 552b   80 00      ..
;
;
	ORG	5538H
;
	DB	1FH					; 5538 .
	DW	XFEFF		; 5539   ff fe      .~
	DB	0FFH					; 553b .
	DW	XFFBF		; 553c   bf ff      ?.
;
	DB	0FCH					; 553e |
;
	ORG	5545H
;
	DB	17H,55H,40H				; 5545 .U@
;
	ORG	555BH
;
	DB	1CH					; 555b .
;
	ORG	5578H
;
	DB	20H,24H,84H,4,14H,90H,82H		; 5578  $.....
;
	ORG	55B8H
;
	DB	0A6H,40H,88H,88H,8,0AAH,0A8H		; 55b8 &@...*(
;
	ORG	55E7H
;
	DB	18H,30H					; 55e7 .0
	DW	X0C60		; 55e9   60 0c      `.
;
	DB	18H,31H,98H,33H,7CH			; 55eb .1.3|
	DW	X9BCD		; 55f0   cd 9b      M.
;
	DB	0,66H					; 55f2 .f
	DW	X18C0		; 55f4   c0 18      @.
;
	DB	36H,0CH,18H,0				; 55f6 6...
;
	ORG	5604H
;
	DB	7FH					; 5604 .
;
	ORG	5608H
;
	DB	0A9H,0,80H,20H,40H,81H,0		; 5608 ).. @..
;
	ORG	5618H
;
	DB	5					; 5618 .
	DW	X68B5		; 5619   b5 68      5h
;
	DB	2AH,0BH,56H,0D0H			; 561b *.VP
;
	ORG	5624H
;
	DB	3FH,0,0FH				; 5624 ?..
	DW	XA4FE		; 5627   fe a4      ~$
;
	DB	4,1					; 5629 ..
;
	ORG	563BH
;
	DB	3EH					; 563b >
;
	ORG	5645H
;
	DB	88H,0AAH,95H				; 5645 .*.
;
	ORG	565BH
;
	DB	8					; 565b .
;
	ORG	5678H
;
	DB	20H,24H,44H,14H,14H,88H,86H,0		; 5678  $D.....
;
	ORG	56B8H
;
	DB	0C2H,0,84H,64H,6,44H,0A4H		; 56b8 B..d.D$
;
	ORG	56E7H
;
	DB	18H,30H,3CH,0F9H			; 56e7 .0<y
	DW	X31F0		; 56eb   f0 31      p1
;
	DB	98H,1EH,60H,7CH				; 56ed ..`|
	DW	XE0F1		; 56f1   f1 e0      q`
	DB	3CH					; 56f3 <
	DW	X18C0		; 56f4   c0 18      @.
;
	DB	36H,7,98H,0				; 56f6 6...
;
	ORG	5704H
;
	DB	7FH					; 5704 .
;
	ORG	5708H
;
	DB	74H,80H,80H,20H,40H,81H			; 5708 t.. @.
;
	ORG	5718H
;
	DB	15H					; 5718 .
	DB	'?R]%~T'				; 5719
	DB	0					; 571f .
;
	ORG	5723H
;
	NOP			; 5723  00		.
;
	DB	1FH					; 5724 .
	DW	X1FC0		; 5725   c0 1f      @.
	DW	X50E9		; 5727   e9 50      iP
;
	DB	4,1					; 5729 ..
;
	ORG	573BH
;
	DB	1CH					; 573b .
;
	ORG	5745H
;
	DB	26H,50H,40H				; 5745 &P@
;
	ORG	575BH
;
	DB	8					; 575b .
;
	ORG	5778H
;
	DB	10H,94H,33H				; 5778 ..3
	DW	XE2F7		; 577b   f7 e2      wb
;
	DB	86H,7AH					; 577d .z
;
	ORG	57B8H
;
	DB	0CH					; 57b8 .
;
	ORG	57EDH
;
	DB	30H,0,60H				; 57ed 0.`

; ==========================================================================
; SCREEN ATTRIBUTES: $5800-$5AFF
; ==========================================================================
;
; 768 bytes defining the colour for each 8x8 character cell on screen.
; Layout: 24 rows of 32 bytes each (row 0 at $5800, row 1 at $5820, ...).
;
; Each byte encodes:
;   Bit 7:    FLASH  (0=off, 1=alternating INK/PAPER)
;   Bit 6:    BRIGHT (0=normal, 1=bright colours)
;   Bits 5-3: PAPER colour (0-7)
;   Bits 2-0: INK colour   (0-7)
;
; The disassembler has output these bytes as ASCII character strings because
; the attribute values happen to fall in the printable ASCII range:
;
;   'G' = $47 = 0_1_000_111 = BRIGHT, PAPER black (0), INK white (7)
;   'F' = $46 = 0_1_000_110 = BRIGHT, PAPER black (0), INK yellow (6)
;   'E' = $45 = 0_1_000_101 = BRIGHT, PAPER black (0), INK cyan (5)
;   'D' = $44 = 0_1_000_100 = BRIGHT, PAPER black (0), INK green (4)
;   'B' = $42 = 0_1_000_010 = BRIGHT, PAPER black (0), INK red (2)
;
; All cells have FLASH=off, BRIGHT=on, PAPER=black.
; The INK colour varies to create the loading screen's colour regions:
;   - White (7/'G'): dominant colour, used for most of the screen
;   - Cyan  (5/'E'): used in the upper-left area (title/artwork)
;   - Yellow(6/'F'): central region (Firebird logo area?)
;   - Green (4/'D'): lower-center area
;   - Red   (2/'B'): lower-right block (3 rows of 7 columns)
;
; --------------------------------------------------------------------------
; Attribute rows 0-7 (character rows 0-7, screen lines 0-63):

	ORG	5800H
;
	DB	'GGGGGGGGGGGGGEGGGEEGGGEEEEEGGGGG'	; 5800 row 0
X5820:	DB	'EEGGGGEEEEEEEEGGGGEEGGEEEEEGGEEE'	; 5820 row 1
	DB	'EEEEEEEEEEFEEEGGGGGEEGEEGEEEEEEG'	; 5840 row 2
	DB	'GGEEEEEEEFFFEEGGGGGEEEEEGGEEEEGG'	; 5860 row 3
X5880:	DB	'GGGEEGEEFFFFEEGGGGGGEEEEGEEEEGGG'	; 5880 row 4
	DB	'GGEEGGEEEFFFEEEEEEEEEGGGGGEGEEGG'	; 58a0 row 5
	DB	'GEEEGGEEEEGEEEEEEEEEEEGGGGGGEEEG'	; 58c0 row 6
	DB	'GEEEGGGGEEEEEEEGGGEEEEGGGGGGGEEE'	; 58e0 row 7
; --------------------------------------------------------------------------
; Attribute rows 8-15 (character rows 8-15, screen lines 64-127):
	DB	'GEEGEEEEGGGGGGGGGGEEEEGGGGGGGGGE'	; 5900 row 8
	DB	'EEEEEEGGFFFFGGGGGGGGGGGFGGGGGGGG'	; 5920 row 9  (yellow region appears)
	DB	'EEEEGGGGFFFFGGGGGGGGGFFFFGGGGGGG'	; 5940 row 10
	DB	'EEEGGGGGFFFFGGGGGGGGGFFFFGGGGGGG'	; 5960 row 11
	DB	'EEEGGGGGFFFFFGGGGGGGGGFGGGGGGGGG'	; 5980 row 12
	DB	'EEGGGFFFGGGFFGGGGGGGGGGGGGGGGGGG'	; 59a0 row 13
	DB	'GGGGGFFFGDDGGGDDDGGGGGGGGGGGGGGG'	; 59c0 row 14 (green region appears)
	DB	'GGGGFFFFFDDDDDDDDGGGGGGGGGGGGGGG'	; 59e0 row 15
; --------------------------------------------------------------------------
; Attribute rows 16-23 (character rows 16-23, screen lines 128-191):
	DB	'GGGGFFFFGGDDDDDDGGGGGGGGBBBBBBBG'	; 5a00 row 16 (red region appears)
	DB	'GGGGFFFFGDDDDGGGGGGGGGGGBBBBBBBG'	; 5a20 row 17
	DB	'GGGGFFFGGDDGGGGGGGGGGGGGBBBBBBBG'	; 5a40 row 18
	DB	'GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG'	; 5a60 row 19
	DB	'GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG'	; 5a80 row 20
	DB	'GGGGGGGGGGGGGGGGGGGGGGGG'		; 5aa0 row 21 (24 bytes, cols 0-23)
	; Row 21 continues at $5ab8 (cols 24-31) with raw numeric values:
	DB	5,5,5,5,5,5,5,47H			; 5ab8 row 21 cols 24-31
	; $05 = 0_0_000_101 = no BRIGHT, PAPER black, INK cyan
	; $47 = 'G' = BRIGHT, PAPER black, INK white
	; Row 22:
	DB	7,7,7,7,7,7,7,7				; 5ac0 row 22 cols 0-7
	DB	7,7,7,7,7,7,7,7				; 5ac8 row 22 cols 8-15
	DB	7,7,7,7,7,7,7,7				; 5ad0 row 22 cols 16-23
	DB	7,7,7,7,7,7,7,7				; 5ad8 row 22 cols 24-31
	; $07 = 0_0_000_111 = no BRIGHT, PAPER black, INK white
	; Row 23:
	DB	'GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG'	; 5ae0 row 23
	DB	0					; 5b00 .

; ==========================================================================
; ZX SPECTRUM SYSTEM VARIABLES: $5B00-$5BFF
; ==========================================================================
;
; This 256-byte region is used by the ZX Spectrum ROM for system variables.
; The snapshot captures whatever state these variables were in at the time
; of the .SNA dump. Most of this area is zero in the snapshot.
; Only a few bytes have non-zero values.

	ORG	5BFEH
;
X5BFE:	NOP			; 5bfe  00		.

; ==========================================================================
; ZX SPECTRUM SYSTEM AREA: $5C00-$5FFF
; ==========================================================================
;
; This region contains the ZX Spectrum's channel information, BASIC program
; area, calculator stack, and other system data structures managed by the ROM.
; The data below is the snapshot's captured state of these system structures.
;
; Key locations in the standard Spectrum memory map:
;   $5C00-$5C09: Channel information (I/O channels K, S, P)
;   $5C10-$5CB5: System variables (KSTATE, FLAGS, ERR_SP, etc.)
;   $5CB6+:      BASIC program area / channel data
;   $5D00+:      BASIC program text or workspace
;
; In the Zolyx snapshot, this area contains remnants of the BASIC loader
; program that was used to load the game from tape, plus system state.

	ORG	5C03H
;
	NOP			; 5c03  00		.
	RST	38H		; 5c04  ff		.
	NOP			; 5c05  00		.
;
	DB	14H,0DH,0DH,14H,3,0			; 5c06 ......
;
	ORG	5C0EH
;
	DB	10H,0,1,0,6,0,0BH,0			; 5c0e ........
	DB	1,0,1,0,6,0,10H				; 5c16 .......
;
	ORG	5C37H
;
	DB	3CH,40H,0,0FFH				; 5c37 <@..
	DW	X00CD		; 5c3b   cd 00      M.
	DW	X7FFC		; 5c3d   fc 7f      |.
;
	DB	0					; 5c3f .
;
	ORG	5C44H
;
	RST	38H		; 5c44  ff		.
;
	DB	1EH,0,1,7				; 5c45 ....
;
	ORG	5C4BH
;
	DB	59H,5DH,0,0				; 5c4b Y]..
	DW	X5CB6		; 5c4f   b6 5c      6\
	DW	X5CBB		; 5c51   bb 5c      ;\
	DW	X5CCB		; 5c53   cb 5c      K\
;
	DB	1DH,5DH,'J'+80h				; 5c55 .]J
	DB	'\Z]]]'					; 5c58
	DB	1CH,5DH,92H				; 5c5d .].
	DB	']_]_]_]-'				; 5c60
	DB	92H					; 5c68 .
	DW	X005C		; 5c69   5c 00      \.
;
	DB	2					; 5c6b .
;
	ORG	5C74H
;
	DW	X1AB6		; 5c74   b6 1a      6.
;
	DB	0,0,22H,10H,0,58H,0FFH			; 5c76 .."..X.
;
	ORG	5C7FH
;
	DB	21H,0					; 5c7f !.
	DW	X215B		; 5c81   5b 21      [!
;
	DB	17H,40H,40H,0E0H,50H,21H,16H,21H	; 5c83 .@@`P!.!
	DB	17H,3					; 5c8b ..
;
	ORG	5CB2H
;
	RST	38H		; 5cb2  ff		.
;
	DW	XFF7F		; 5cb3   7f ff      ..
;
	ORG	5CB6H
;
X5CB6:	DB	0F4H,9,0A8H,10H,4BH			; 5cb6 t.(.K
X5CBB:	DB	0F4H,9					; 5cbb t.
	DW	X15C4		; 5cbd   c4 15      D.
;
	DB	53H,81H,0FH				; 5cbf S..
	DW	X15C4		; 5cc2   c4 15      D.
;
	DB	52H,0F4H,9				; 5cc4 Rt.
	DW	X15C4		; 5cc7   c4 15      D.
	DB	50H					; 5cc9 P
	DW	X0080		; 5cca   80 00      ..
;
	DB	0AH,28H,0,0DAH,30H,0EH,0		; 5ccc .(.Z0..
;
	ORG	5CD7H
;
	DB	3AH,0D9H,30H,0EH,0			; 5cd7 :Y0..
;
	ORG	5CE0H
;
	DB	3AH					; 5ce0 :
	DW	X30E7		; 5ce1   e7 30      g0
;
	DB	0EH,0					; 5ce3 ..
;
	ORG	5CE9H
;
	DB	3AH,0FDH,33H,32H,37H,36H,37H,0EH	; 5ce9 :}32767.
	DB	0,0,0FFH,7FH,0,0DH,0,14H		; 5cf1 ........
	DB	10H,0					; 5cf9 ..
	DW	X22EF		; 5cfb   ef 22      o"
;
	DB	22H,'/'+80h				; 5cfd "/
	DB	'65024'					; 5cff
	DB	0EH,0					; 5d04 ..
;
	ORG	5D08H
;
	DW	X00FE		; 5d08   fe 00      ~.
;
	DB	0DH,0,1EH,0EH,0,0F9H,'@'+80h		; 5d0a .....y@
	DB	'65024'					; 5d11
	DB	0EH,0					; 5d16 ..
;
	ORG	5D1AH
;
	DW	X00FE		; 5d1a   fe 00      ~.
;
	DB	0DH,0,28H,16H,0,0F4H,32H,33H		; 5d1c ..(..t23
	DB	34H,31H,38H,0EH,0,0,7AH,5BH		; 5d24 418...z[
	DB	0,2CH,38H,34H,0EH			; 5d2c .,84.
;
	ORG	5D33H
;
	DB	54H					; 5d33 T
;
	ORG	5D36H
;
	DB	0DH,0,32H,11H,0,0F8H			; 5d36 ..2..x
	DB	'"Zolyx'				; 5d3c
	DB	22H					; 5d42 "
	DW	X30CA		; 5d43   ca 30      J0
;
	DB	0EH					; 5d45 .
;
	ORG	5D4BH
;
	DB	0DH,0,3CH,9,0,0EFH			; 5d4b ..<..o
	DB	'"mast0'				; 5d51
	DB	22H,0DH,80H				; 5d57 "..
	DW	X22EF		; 5d5a   ef 22      o"
;
	DB	22H,0DH					; 5d5c ".
	DW	X0080		; 5d5e   80 00      ..
;
;
	ORG	5D62H
;
	DW	X00FE		; 5d62   fe 00      ~.
;
	DB	'      '				; 5d64
	DB	0					; 5d6a .
;
	ORG	5D6DH
;
	CP	0		; 5d6d  fe 00		~.
;
	ORG	5D70H
;
	DB	3					; 5d70 .
	DB	'loader    '				; 5d71 -- BASIC filename for tape loading
	DB	0,2,0					; 5d7b ...
	DW	X8EFE		; 5d7e   fe 8e      ~.
;
	DB	80H					; 5d80 .
;
	ORG	5D84H
;
	DB	0FEH					; 5d84 ~

; ==========================================================================
; END OF SYSTEM AREA / UPPER MEMORY: $5FF8+
; ==========================================================================
;
; Data at $5FF8-$5FFF is the tail end of the system/workspace area.
; At $6000+ begins the SHADOW GRID region which Zolyx uses as a second
; copy of the game field bitmap. The loader bootstrap code appears to
; occupy some of this space in the snapshot.

	ORG	5FF8H
;
	DB	4BH					; 5ff8 K
	DW	X32FF		; 5ff9   ff 32      .2
;
	DB	0FFH,93H,0				; 5ffb ...
X5FFE:	DB	0A4H					; 5ffe $

; ==========================================================================
; SHADOW GRID / LOADER BOOTSTRAP: $5FFF-$604F
; ==========================================================================
;
; $6000-$77FF is the shadow grid in Zolyx -- a mirror of the $4000-$57FF
; bitmap layout but where the player's trail is NOT recorded. Chasers and
; sparks read this shadow grid to navigate, causing them to treat trail
; cells as empty space.
;
; In the snapshot, the beginning of this region contains the tape loader
; bootstrap code (LDDR to copy code, JP to game entry point). This code
; ran during the loading process and is no longer relevant at runtime.
; The game reinitializes this entire $6000-$77FF region on level start.

	CP	21H		; 5fff  fe 21		~!
	RST	38H		; 6001  ff		.
	DB	0FDH,11H	; 6002  fd 11		}.
;
	RST	38H		; 6004  ff		.
	RST	38H		; 6005  ff		.
	LD	BC,X5001	; 6006  01 01 50	..P
	LDDR			; 6009  ed b8		m8
	JP	XB000		; 600b  c3 00 b0	C.0  -- jumps to game code at $B000
;
	DW	X37AF		; 600e   af 37      /7
;
	DB	14H,8,15H				; 6010 ...
	DW	X3EF3		; 6013   f3 3e      s>
	DB	8					; 6015 .
	DW	XFED3		; 6016   d3 fe      S~
;
	DB	21H,6AH,0FFH,0E5H,0DBH			; 6018 !j.e[
	DW	X1FFE		; 601d   fe 1f      ~.
;
	DB	0E6H,20H				; 601f f 
	DW	X00F6		; 6021   f6 00      v.
	DB	4FH					; 6023 O
	DW	XC0BF		; 6024   bf c0      ?@
	DW	X4CCD		; 6026   cd 4c      ML
	DW	X30FF		; 6028   ff 30      .0
	DW	X21FA		; 602a   fa 21      z!
;
	DB	15H,4,10H				; 602c ...
	DW	X2BFE		; 602f   fe 2b      ~+
	DB	7CH					; 6031 |
	DW	X20B5		; 6032   b5 20      5 
	DW	XCDF9		; 6034   f9 cd      yM
	DB	48H					; 6036 H
	DW	X30FF		; 6037   ff 30      .0
	DW	X06EB		; 6039   eb 06      k.
	DB	9CH					; 603b .
	DW	X48CD		; 603c   cd 48      MH
	DW	X30FF		; 603e   ff 30      .0
	DW	X3EE4		; 6040   e4 3e      d>
	DB	0C6H					; 6042 F
	DW	X30B8		; 6043   b8 30      80
;
	DB	0E0H,24H,20H				; 6045 `$ 
	DW	X06F1		; 6048   f1 06      q.
	DW	XCDC9		; 604a   c9 cd      IM
	DB	4CH					; 604c L
	DW	X30FF		; 604d   ff 30      .0
	DW	X00D5		; 604f   d5 00      U.

; ==========================================================================
; HIGH MEMORY REFERENCES: $7FDE+
; ==========================================================================
;
; These addresses are outside the screen memory and shadow grid regions.
; They appear in this file because the disassembler included them as part
; of the contiguous data dump from the .SNA snapshot.
;
; $7FDE-$7FFF: Tail end of the shadow grid + any residual data.
;              In the standard Spectrum memory map this is general-purpose
;              RAM. Zolyx uses various high-memory regions for game data.
;
; $8000+:      Referenced label targets (X8014, X8080, X80FF, X810C, etc.)
;              These are address constants used as branch targets or data
;              pointers by the game code elsewhere in the disassembly.
;
; $9000+:      Trail buffer and flood fill stack workspace.
;
; $AE00+:      Game data tables / initialization code referenced by the
;              main game routines. The code at $AF33+ is the title screen /
;              attract mode loop (HALT for frame sync, attribute cycling,
;              input polling, PRNG, etc.).

	ORG	7FDEH
;
	DB	0F3H					; 7fde s
;
	DEC	C		; 7fdf  0d		.
;
	DB	'7'+80h					; 7fe0 7
	DB	'-_]Z]'					; 7fe1
	DB	0,0FEH					; 7fe6 .~
;
	DEC	HL		; 7fe8  2b		+
	DEC	L		; 7fe9  2d		-
	LD	H,L		; 7fea  65		e
	INC	SP		; 7feb  33		3
	RET	Z		; 7fec  c8		H
	LD	C,D		; 7fed  4a		J
	DB	0EDH,10H	; 7fee  ed 10 0d	m..
;
	NOP			; 7ff1  00		.
	ADD	HL,BC		; 7ff2  09		.
	NOP			; 7ff3  00		.
	ADD	A,L		; 7ff4  85		.
	INC	E		; 7ff5  1c		.
	DJNZ	X8014		; 7ff6  10 1c		..
	LD	D,D		; 7ff8  52		R
	DEC	DE		; 7ff9  1b		.
X7FFA:	HALT			; 7ffa  76		v
;
	DEC	DE		; 7ffb  1b		.
X7FFC:	INC	BC		; 7ffc  03		.
	INC	DE		; 7ffd  13		.
X7FFE:	NOP			; 7ffe  00		.
	LD	A,0		; 7fff  3e 00		>.
;
	ORG	8014H
;
X8014:	NOP			; 8014  00		.
	; Label referenced as branch target from $7FF6 (DJNZ)
;
	ORG	8080H
;
X8080:	NOP			; 8080  00		.
	; Referenced label (data pointer or branch target)
;
	ORG	80FFH
;
X80FF:	NOP			; 80ff  00		.
	; Referenced label
;
	ORG	810CH
;
X810C:	NOP			; 810c  00		.
X810D:	NOP			; 810d  00		.
X810E:	NOP			; 810e  00		.
	; Three consecutive referenced labels at $810C-$810E

; --------------------------------------------------------------------------
; Trail buffer and flood fill stack workspace labels:
;   $9000 = start of trail buffer (3 bytes per entry: X, Y, direction)
;   $9002 = offset into trail buffer (used for indexed access)

	ORG	9000H
;
X9000:	NOP			; 9000  00		.
;
	ORG	9002H
;
X9002:	NOP			; 9002  00		.

; --------------------------------------------------------------------------

	ORG	0A0FFH
;
XA0FF:	NOP			; a0ff  00		.

; ==========================================================================
; GAME DATA / TITLE SCREEN CODE: $AE00+
; ==========================================================================
;
; This section contains game data tables (sprite patterns, colour cycling
; data) and the title screen / attract mode code. Key routines:
;
;   $AECB-$AEE3: Sprite pattern data (alternating bit patterns for
;                 entities -- $55/$AA checkerboard, $FF solid, etc.)
;
;   $AEE7-$AF2F: Initialization / tape loader remnants
;
;   $AF33 (XAF33): Title screen main loop
;     - HALT for frame synchronization (50 fps on PAL Spectrum)
;     - Calls XB1B0 (attribute colour cycling animation)
;     - Increments colour cycle counter at XB1AF
;     - Wraps counter at 56 ($38) back to 0
;     - Computes attribute byte from counter (SRL x3, INC, OR $40)
;     - Fills attribute rectangle via FILL_ATTR_RECT ($BAF6)
;     - Polls keyboard via XB26E for input
;     - Checks for keys 1, 2, or 4 (player count selection)
;     - Loops back to HALT if no valid input
;
;   $AFDD-$AFFF: Key processing, PRNG-based level selection,
;                player configuration setup

	ORG	0AE00H
;
	DW	XF5C3		; ae00   c3 f5      Cu
	DW	X03B0		; ae02   b0 03      0.
;
	DB	39H					; ae04 9
;
	ORG	0AE2AH
;
	DB	1					; ae2a .
;
	ORG	0AE4FH
;
	DB	1					; ae4f .
;
	ORG	0AE74H
;
	DB	2					; ae74 .
;
	ORG	0AECBH
;
	; Sprite/entity pixel patterns:
	; $55 = 01010101 (alternating pixels), $AA = 10101010 (inverse)
	; $FF = solid, $00 = empty -- used for animated entity rendering
	DB	55H,0,0AAH,55H,0FFH			; aecb U.*U.
	DW	X01FF		; aed0   ff 01      ..
;
;
	NOP			; aed2  00		.
;
	DB	1,1,0,1					; aed3 ....
	DW	X01FF		; aed7   ff 01      ..
	DW	X00FF		; aed9   ff 00      ..
	DB	0FFH					; aedb .
	DW	X00FF		; aedc   ff 00      ..
;
;
	RST	38H		; aede  ff		.
;
	DB	1					; aedf .
	DW	X00FF		; aee0   ff 00      ..
;
	DB	0					; aee2 .
;
	LD	(BC),A		; aee3  02		.
;
	ORG	0AEE7H
;
	DB	90H					; aee7 .
;
	ORG	0AEEAH
;
	DB	0EH,0,70H				; aeea ..p
;
	ORG	0AEEFH
;
	NOP			; aeef  00		.
	NOP			; aef0  00		.
	RST	38H		; aef1  ff		.
	LD	BC,X01FF	; aef2  01 ff 01	...
;
	DB	31H,0,0B0H,21H				; aef5 1.0!
	DW	X07D0		; aef9   d0 07      P.
;
	DB	5FH,1,1FH,0				; aefb _...
	DW	X78ED		; aeff   ed 78      mx
	DW	XFFFE		; af01   fe ff      ~.
;
	DB	28H,7,2BH,7CH				; af03 (.+|
	DW	X20B5		; af07   b5 20      5 
	DW	X1EF2		; af09   f2 1e      r.
;
	DB	0FFH,7BH,32H,6DH			; af0b .{2m
	DW	XF3B2		; af0f   b2 f3      2s
	DB	3EH					; af11 >
	DW	X32C3		; af12   c3 32      C2
	DW	XFDFD		; af14   fd fd      }}
;
	DB	21H,51H					; af16 !Q
	DW	X22BB		; af18   bb 22      ;"
	DW	XFDFE		; af1a   fe fd      ~}
	DB	3EH					; af1c >
	DW	XEDFE		; af1d   fe ed      ~m
	DB	47H					; af1f G
	DW	X5EED		; af20   ed 5e      m^
	DB	0FBH					; af22 {
	DW	XD3AF		; af23   af d3      /S
	DW	X21FE		; af25   fe 21      ~!
	DB	92H					; af27 .
	DW	XCDB1		; af28   b1 cd      1M
	DB	26H					; af2a &
	DW	XCDBC		; af2b   bc cd      <M
	DB	6EH					; af2d n
	DW	X7BB2		; af2e   b2 7b      2{
	DW	X20B7		; af30   b7 20      7 
;
	DB	0F9H					; af32 y
;
; --- Title screen main loop ---
; Waits for a frame (HALT), cycles rainbow colours on the title,
; then polls keyboard for player count selection (1, 2, or 4).
; Loops until valid input is received.
XAF33:	HALT			; af33  76  -- wait for vertical blank (frame sync)
;
	CALL	XB1B0		; af34  cd b0 b1  -- update title screen animation
	LD	HL,XB1AF	; af37  21 af b1  -- HL -> colour cycle counter
	INC	(HL)		; af3a  34        -- increment counter each frame
	LD	A,(HL)		; af3b  7e        -- A = current counter value
	CP	38H		; af3c  fe 38     -- counter >= 56?
	JR	C,XAF42		; af3e  38 02     -- no: skip reset
	LD	A,0		; af40  3e 00     -- yes: reset counter to 0
XAF42:	LD	(HL),A		; af42  77        -- store (possibly reset) counter
	SRL	A		; af43  cb 3f     -- A = counter >> 1
	SRL	A		; af45  cb 3f     -- A = counter >> 2
	SRL	A		; af47  cb 3f     -- A = counter >> 3 (0-6 range)
	INC	A		; af49  3c        -- A = 1-7 (INK colour)
	OR	40H		; af4a  f6 40     -- set BRIGHT bit -> attribute byte
	LD	BC,X1700	; af4c  01 00 17  -- B=0 (row), C=$17=23 (height)
	LD	DE,X0120	; af4f  11 20 01  -- D=$20=32 (width), E=1 (col)
	CALL	FILL_ATTR_RECT		; af52  cd f6 ba  -- fill title area with colour
	CALL	XB26E		; af55  cd 6e b2  -- poll keyboard, result in E
	LD	A,E		; af58  7b        -- A = key pressed
	CP	1		; af59  fe 01     -- key '1'? (1 player)
	JP	Z,XB16A		; af5b  ca 6a b1  -- yes: start game
	CP	2		; af5e  fe 02     -- key '2'? (2 players)
	JP	Z,XB16A		; af60  ca 6a b1  -- yes: start game
	CP	4		; af63  fe 04     -- key '4'? (4 players)
	JP	Z,XB16A		; af65  ca 6a b1  -- yes: start game
	JR	XAF33		; af68  18 c9     -- loop: wait for valid input
;
	DB	21H,94H					; af6a !.
	DW	XCBB2		; af6c   b2 cb      2K
;
	DB	43H,20H,0AH,21H,99H			; af6e C .!.
	DW	XCBB2		; af73   b2 cb      2K
;
	DB	4BH,20H,3,21H,9EH			; af75 K .!.
	DW	X06B2		; af7a   b2 06      2.
;
	DB	5,11H					; af7c ..
	DW	XBACE		; af7e   ce ba      N:
;
;
	LD	IX,XBAE2	; af80  dd 21 e2 ba	]!b:
XAF84:	LD	A,(HL)		; af84  7e		~
	LD	(DE),A		; af85  12		.
	LD	(IX+0),A	; af86  dd 77 00	]w.
	INC	HL		; af89  23		#
	INC	DE		; af8a  13		.
	INC	IX		; af8b  dd 23		]#
	DJNZ	XAF84		; af8d  10 f5		.u
	JP	XB2A3		; af8f  c3 a3 b2	C#2
;
	; Text string data for the title screen prompt:
	DB	1EH,47H,1FH,3AH,17H			; af92 .G.:. -- cursor positioning codes
	DB	'Press N, Space or Fire.'		; af97   -- the actual prompt text
	DB	0,47H,21H,4AH				; afae .G!J
	DW	X35B2		; afb2   b2 35      25
;
	DB	7EH,0E6H,7				; afb4 ~f.
	DW	X7EC0		; afb7   c0 7e      @~
	DW	X3FCB		; afb9   cb 3f      K?
	DW	X3FCB		; afbb   cb 3f      K?
	DW	X3FCB		; afbd   cb 3f      K?
;
;
	CP	6		; afbf  fe 06		~.
	JR	C,XAFDD		; afc1  38 1a		8.
	CP	1FH		; afc3  fe 1f		~.
	RET	NZ		; afc5  c0		@
	LD	(HL),38H	; afc6  36 38		68
	; When colour counter wraps ($1F), use PRNG to pick a random level colour
	CALL	PRNG		; afc8  cd e4 d3  -- get pseudo-random number
	AND	0FH		; afcb  e6 0f     -- mask to 0-15
	ADD	A,A		; afcd  87        -- *2 (word index into table)
	LD	E,A		; afce  5f        -- DE = table offset
	LD	D,0		; afcf  16 00
	LD	HL,XB24D	; afd1  21 4d b2  -- HL -> colour table
	ADD	HL,DE		; afd4  19        -- HL -> selected entry
	LD	DE,XB24B	; afd5  11 4b b2  -- DE -> active colour pair
	LDI			; afd8  ed a0     -- copy 2 bytes (colour pair)
	LDI			; afda  ed a0
	RET			; afdc  c9
;
XAFDD:	LD	C,A		; afdd  4f		O
	ADD	A,A		; afde  87		.
	ADD	A,C		; afdf  81		.
	LD	C,A		; afe0  4f		O
	ADD	A,A		; afe1  87		.
	ADD	A,C		; afe2  81		.
	LD	E,A		; afe3  5f		_
	XOR	C		; afe4  a9		)
	CP	H		; afe5  bc		<
	RET	PE		; afe6  e8		h
	LD	D,E		; afe7  53		S
	XOR	C		; afe8  a9		)
	CP	H		; afe9  bc		<
	OR	53H		; afea  f6 53		vS
	LD	C,E		; afec  4b		K
	LD	SP,HL		; afed  f9		y
	RRA			; afee  1f		.
	LD	B,78H		; afef  06 78		.x
	RST	30H		; aff1  f7		w
	RRA			; aff2  1f		.
	LD	BC,XFC7A	; aff3  01 7a fc	.z|
	LD	L,L		; aff6  6d		m
	OR	D		; aff7  b2		2
	NOP			; aff8  00		.
	NOP			; aff9  00		.
XAFFA:	CP	7FH		; affa  fe 7f		~.
	SUB	E		; affc  93		.
	NOP			; affd  00		.
XAFFE:	INC	(HL)		; affe  34		4
	OR	C		; afff  b1		1
