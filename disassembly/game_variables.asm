; ==========================================================================
; GAME VARIABLES & DATA TABLES ($B000-$B0FF)
; ==========================================================================
;
; All mutable game state is concentrated in this 256-byte region.
; IX register typically points to $B0E1 (PLAYER_FLAGS) during gameplay.
;
; Player data:
;   $B003-$B004  Player X,Y position (loaded as 16-bit via LD DE,($B003))
;   $B0E1        Player flags byte:
;                  bit 0: axis flag (1=horizontal last move, 0=vertical)
;                  bit 4: fast mode (fire held during drawing = half speed)
;                  bit 5: draw direction (used in fill direction logic)
;                  bit 6: fill complete (trail reached border, trigger fill)
;                  bit 7: drawing (currently drawing a trail)
;   $B0E2        Player direction (0=right, 2=down, 4=left, 6=up)
;   $B0E4-$B0E5  Drawing start position (X, Y saved when drawing begins)
;
; Chaser data (37 bytes each):
;   $B028        Chaser 1: +0=X, +1=Y, +3=direction, +4=wall-side, +5..+36=sprite bg
;   $B04D        Chaser 2: same structure
;
; Trail cursor:
;   $B072        X position (0=inactive), $B073=Y, $B075=buffer pointer
;
; Spark array (8 x 5 bytes):
;   $B097        Spark 0: +0=X (0=inactive), +1=Y, +2=oldX, +3=oldY, +4=direction
;   $B09C-$B0BA  Sparks 1-7 (5 bytes each)
;
; Core game state:
;   $B0BF        Timer bar display position (for animated bar)
;   $B0C0        Game timer (countdown from 176, decrements every 14 frames)
;   $B0C1        Level number (0-based, uses level & 0x0F for table lookups)
;   $B0C2        Lives remaining (starts at 3)
;   $B0C3-$B0C4  Base score (16-bit little-endian)
;   $B0C5        Raw claimed percentage = claimed_cells / 90
;   $B0C6        Filled percentage = (all_non_empty - 396) / 90
;   $B0C7        Frame counter (incremented each game loop, wraps at 256)
;   $B0C8        Game state flags:
;                  bit 0: collision detected (set by $CAA9, $CC1F)
;                  bit 1: timer expired (set when timer reaches 0)
;                  bit 2: level complete (set when percentage >= 75%)
;                  bit 6: trail cursor moving (sound trigger)
;                  bit 7: spark bounce (sound trigger)
;
; Data tables:
;   $B0C9 (8 bytes)  Cell patterns: 2 bytes per cell value (top/bottom row)
;                     Empty=$00/$00, Claimed=$55/$00, Trail=$AA/$55, Border=$FF/$FF
;   $B0D1 (16 bytes) Direction deltas: 8 dirs x 2 bytes (dx, dy, signed)
;                     0=Right(+1,0) 1=DR(+1,+1) 2=Down(0,+1) 3=DL(-1,+1)
;                     4=Left(-1,0) 5=UL(-1,-1) 6=Up(0,-1) 7=UR(+1,-1)
;
; Trail tracking:
;   $B0E6-$B0E7  Trail buffer write pointer (into $9000 area)
;   $B0E8        Trail frame counter (trail cursor activates at 72)
;   $B0E9        Timer speed sub-counter (current countdown value)
;   $B0EA        Timer speed reload value ($0E = 14 frames per timer tick)
;   $B0EC        Game field color attribute byte (changes per level)
;

XB000:	JP	XB0F5		; b000  c3 f5 b0	Cu0
;

; --- Player position (L=X, H=Y) ---
PLAYER_XY:	INC	BC		; b003  03		.
	ADD	HL,SP		; b004  39		9
;
	ORG	0B028H
;

; --- Chaser 1 data structure (37 bytes) ---
CHASER1_DATA:	NOP			; b028  00		.
;
	ORG	0B02AH
;
	DB	1					; b02a .
;
	ORG	0B04DH
;

; --- Chaser 2 data structure (37 bytes) ---
CHASER2_DATA:	NOP			; b04d  00		.
;
	ORG	0B04FH
;
	DB	1					; b04f .
;
	ORG	0B072H
;

; --- Trail cursor state ---
TRAIL_CURSOR:	NOP			; b072  00		.
;
	ORG	0B074H
;
	DB	2					; b074 .
;
XB075:	NOP			; b075  00		.
;
	ORG	0B097H
;

; --- Spark data array (8 x 5 bytes) ---
SPARK_ARRAY:	NOP			; b097  00		.
;
	ORG	0B099H
;
XB099:	NOP			; b099  00		.
;
	ORG	0B09EH
;
XB09E:	NOP			; b09e  00		.
;
	ORG	0B0A3H
;
XB0A3:	NOP			; b0a3  00		.
;
	ORG	0B0A8H
;
XB0A8:	NOP			; b0a8  00		.
;
	ORG	0B0ADH
;
XB0AD:	NOP			; b0ad  00		.
;
	ORG	0B0B2H
;
XB0B2:	NOP			; b0b2  00		.
;
	ORG	0B0B7H
;
XB0B7:	NOP			; b0b7  00		.
;
	ORG	0B0BCH
;
XB0BC:	NOP			; b0bc  00		.
;
	ORG	0B0BFH
;

; --- Timer bar display position ---
TIMER_BAR_POS:	NOP			; b0bf  00		.

; --- Main timer countdown (176) ---
GAME_TIMER:	NOP			; b0c0  00		.

; --- Level number (0-based) ---
LEVEL_NUM:	NOP			; b0c1  00		.

; --- Lives remaining ---
LIVES:	NOP			; b0c2  00		.

; --- Base score (16-bit) ---
BASE_SCORE:	NOP			; b0c3  00		.
;
	ORG	0B0C5H
;

; --- Raw claimed % ---
RAW_PERCENT:	NOP			; b0c5  00		.

; --- Filled % ---
FILL_PERCENT:	NOP			; b0c6  00		.

; --- Frame counter ---
FRAME_CTR:	NOP			; b0c7  00		.

; --- Game state flags ---
STATE_FLAGS:	NOP			; b0c8  00		.

; --- Cell patterns ---
CELL_PATTERNS:	NOP			; b0c9  00		.
;
	ORG	0B0CBH
;
	DB	55H,0,0AAH,55H,0FFH			; b0cb U.*U.
	DW	X01FF		; b0d0   ff 01      ..
;
;
	NOP			; b0d2  00		.
;
	DB	1,1,0,1					; b0d3 ....
	DW	X01FF		; b0d7   ff 01      ..
	DW	X00FF		; b0d9   ff 00      ..
	DB	0FFH					; b0db .
	DW	X00FF		; b0dc   ff 00      ..
;
;
	RST	38H		; b0de  ff		.
;
	DB	1					; b0df .
	DW	X00FF		; b0e0   ff 00      ..
;

; --- Player direction ---
PLAYER_DIR:
	DB	0					; b0e2 .
;

; --- Fill cell value ---
FILL_CELL_VAL:	LD	(BC),A		; b0e3  02		.

; --- Drawing start pos ---
DRAW_START:	NOP			; b0e4  00		.
;
	ORG	0B0E6H
;

; --- Trail buffer write ptr ---
TRAIL_WRITE_PTR:	NOP			; b0e6  00		.
;
	DB	90H					; b0e7 .
;

; --- Trail frame counter ---
TRAIL_FRAME_CTR:	NOP			; b0e8  00		.

; --- Timer sub-counter ---
TIMER_SUB_CTR:	NOP			; b0e9  00		.
;

; --- Timer speed reload ---
TIMER_SPEED:	DB	0EH					; b0ea .
XB0EB:	DB	0					; b0eb .

; --- Field color attr ---
FIELD_COLOR:	DB	70H					; b0ec p
;
XB0ED:	RST	38H		; b0ed  ff		.
XB0EE:	RST	38H		; b0ee  ff		.
XB0EF:	NOP			; b0ef  00		.
XB0F0:	NOP			; b0f0  00		.
XB0F1:	RST	38H		; b0f1  ff		.
XB0F2:	LD	BC,X01FF	; b0f2  01 ff 01	...
XB0F5:	LD	SP,XB000	; b0f5  31 00 b0	1.0
	LD	HL,X07D0	; b0f8  21 d0 07	!P.
	LD	E,A		; b0fb  5f		_
XB0FC:	LD	BC,X001F	; b0fc  01 1f 00	...
	IN	A,(C)		; b0ff  ed 78		mx
