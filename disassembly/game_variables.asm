; ==========================================================================
; GAME VARIABLES & DATA TABLES ($B000-$B0FF)
; ==========================================================================
;
; This 256-byte region contains ALL mutable game state for Zolyx.
; It is the single source of truth for every game variable, entity
; position, configuration table, and runtime flag. The entire region
; is laid out as a flat structure with fixed offsets, allowing fast
; indexed access via IX or direct LD (addr),A instructions.
;
; IX register typically points to $B0E1 (PLAYER_FLAGS) during gameplay,
; set at $C3DC: LD IX,$B0E1. Offsets from IX reach player state,
; direction byte (IX+1=$B0E2), fill cell value (IX+2=$B0E3), etc.
;
; -----------------------------------------------------------------------
; MEMORY MAP OVERVIEW
; -----------------------------------------------------------------------
;
; $B000-$B002  Boot jump (JP $B0F5 -> port init, not used during game)
; $B003-$B004  Player X,Y position (16-bit pair, E=X, D=Y)
; $B005-$B027  (gap/unused during gameplay)
; $B028-$B04C  Chaser 1 data structure (37 bytes)
; $B04D-$B071  Chaser 2 data structure (37 bytes)
; $B072-$B076  Trail cursor state (5 bytes)
; $B077-$B096  (gap/unused)
; $B097-$B0BE  Spark array (8 x 5 bytes = 40 bytes)
; $B0BF        Timer bar display position
; $B0C0        Game timer (countdown)
; $B0C1        Level number
; $B0C2        Lives remaining
; $B0C3-$B0C4  Base score (16-bit)
; $B0C5        Raw claimed percentage
; $B0C6        Filled percentage
; $B0C7        Frame counter
; $B0C8        Game state flags
; $B0C9-$B0D0  Cell pattern table (4 x 2 bytes)
; $B0D1-$B0E0  Direction delta table (8 x 2 bytes)
; $B0E1        Player flags byte
; $B0E2        Player direction
; $B0E3        Fill cell value
; $B0E4-$B0E5  Drawing start position
; $B0E6-$B0E7  Trail buffer write pointer
; $B0E8        Trail frame counter
; $B0E9        Timer sub-counter (current)
; $B0EA        Timer speed reload value
; $B0EB        (unused/padding)
; $B0EC        Field color attribute
; $B0ED-$B0F4  (misc/startup data)
; $B0F5-$B0FF  Boot code (port init, not used during game)
;
; -----------------------------------------------------------------------
; PLAYER DATA
; -----------------------------------------------------------------------
;
;   $B003 (E) = Player X coordinate
;     Valid range: 2-125 (FIELD_MIN_X to FIELD_MAX_X)
;     Clamped by TRY_HORIZONTAL at $CA59: CP $02 / $CA5F: CP $7E
;     When not drawing: must be on a border cell (value 3)
;     Initial value: 2 (top-left corner of border)
;     Set during level init at $CCA0: LD (PLAYER_XY),HL with HL=$1202
;
;   $B004 (D) = Player Y coordinate
;     Valid range: 18-93 (FIELD_MIN_Y to FIELD_MAX_Y)
;     Clamped by TRY_VERTICAL at $CA85: CP $12 / $CA8B: CP $5E
;     Initial value: 18 (top border row)
;     Set alongside X as 16-bit pair: D=Y=$12=18, E=X=$02=2
;
;   Together loaded/stored as 16-bit pair:
;     LD DE,($B003)  -- E=X, D=Y (used throughout movement/collision)
;     LD ($B003),DE  -- store after successful move ($C8FA)
;
;   Cross-references (read):
;     $C7BC: LD DE,(PLAYER_XY) -- movement entry
;     $C443: LD DE,(PLAYER_XY) -- trail redraw during drawing
;     $CAAC: LD DE,(PLAYER_XY) -- collision detection
;     $C7E1/$C81B/$C83F/$C879: LD HL,(PLAYER_XY) -- save draw start pos
;     $C387/$C39F/$C3F7/$C44F: LD HL,PLAYER_XY -- sprite BG save/restore
;
;   Cross-references (write):
;     $C8FA: LD (PLAYER_XY),DE -- store new position after move
;     $CCA0: LD (PLAYER_XY),HL -- level init (set to $1202)
;
;   $B0E1 = Player flags byte (IX+0 when IX=$B0E1)
;     Bit 0: Axis flag
;       1 = last move was horizontal (SET by TRY_HORIZONTAL at $CA68)
;       0 = last move was vertical (RES by TRY_VERTICAL at $CA94)
;       Controls movement priority: when bit 0=1, main movement tries
;       vertical first to enable smooth corner anticipation on borders.
;       Tested at $C7C7: BIT 0,(IX+0)
;
;     Bit 4: Fast mode (fire held during drawing)
;       SET at $C7EF/$C817/$C84D/$C875 when entering draw mode with fire
;       RES at $C88D when fire is released during drawing
;       When set, movement skipped on odd frames (half speed)
;       Tested at $C891: BIT 4,(IX+0) / $C897: RRA / JR C
;
;     Bit 5: Draw direction flag
;       SET when entering drawing mode via vertical input ($C813/$C871)
;       RES when entering drawing mode via horizontal input ($C7EB/$C849)
;       Used by fill direction logic to determine fill side
;       Tested at $C92C: BIT 4,(IX+0) -- determines fill cell value
;
;     Bit 6: Fill complete flag
;       SET at $C8B9/$C8DF when trail reaches border (end of drawing)
;       RES at $C926 when fill processing begins
;       Triggers flood fill in FILL_DIRECTION at $C921
;       Tested at $C921: BIT 6,(IX+0) / RET Z
;
;     Bit 7: Drawing flag (currently drawing a trail)
;       SET at $C7E7/$C80F/$C845/$C86D when entering draw mode
;       RES at $C8B5/$C8DB when trail reaches border
;       Controls which movement mode is active
;       Tested at $C7C0/$C43D/$C8E9/$C8FE: BIT 7,(IX+0)
;
;     Initial value: 0 (no flags set)
;     Reset at $CCA5: LD ($B0E1),A with A=0
;
;   $B0E2 = Player direction (IX+1)
;     Values: 0=right, 2=down, 4=left, 6=up (cardinal only)
;     Set by TRY_HORIZONTAL: B=0 (right) or B=4 (left) at $CA57/$CA50
;     Set by TRY_VERTICAL: B=2 (down) or B=6 (up) at $CA83/$CA7C
;     Stored via (IX+1) at $CA65/$CA91
;     Read at $C90B: LD A,(IX+1) for trail buffer recording
;     Read at $C95A: LD A,(IX+1) for fill direction calculation
;
;   $B0E3 = Fill cell value
;     Set at $C934 after determining fill type:
;       A=2 (trail) if not fast mode, A=1 (claimed) if fast mode
;     Read at $C9C6/$C9F6/$CA20 during flood fill seed setup
;     Range: 1 (CELL_CLAIMED) or 2 (CELL_TRAIL)
;
;   $B0E4-$B0E5 = Drawing start position (X, Y)
;     Saved when player enters drawing mode (fire + empty cell)
;     $B0E4 = start X, $B0E5 = start Y
;     Written at $C7E4/$C81E/$C842/$C87C: LD (DRAW_START),HL
;     Read at $C774: LD HL,(DRAW_START) -- restore player pos on death
;     Used to reset player position if death occurs mid-trail
;
; -----------------------------------------------------------------------
; CHASER DATA STRUCTURES (37 bytes each)
; -----------------------------------------------------------------------
;
; Each chaser has a 37-byte structure starting at its base address.
; Chasers follow walls using a left-hand/right-hand rule algorithm.
;
; Structure layout (offsets from base):
;   +0  X position (1 byte)
;     Valid range: 2-125 (always on border cells)
;     0 = chaser inactive (not spawned for this level)
;   +1  Y position (1 byte)
;     Valid range: 18-93
;   +2  (unused/padding, 1 byte)
;   +3  Direction (1 byte)
;     Values: 0=R, 1=DR, 2=D, 3=DL, 4=L, 5=UL, 6=U, 7=UR
;     For chasers, typically cardinal (0,2,4,6) but diagonals used
;     as intermediate look-ahead values in wall-following
;   +4  Wall-side flag (1 byte)
;     0 = wall is on LEFT (prefer turning right)
;     1 = wall is on RIGHT (prefer turning left)
;     Updated dynamically by wall-following logic at $CB75-$CB8F
;   +5..+36  Sprite background save area (32 bytes)
;     When the chaser sprite is drawn, the original background pixels
;     are saved here so they can be restored before the next frame.
;     Used by SAVE_SPRITE_BG ($D0AC) and RESTORE_SPRITE_BG ($D0E5)
;
; Chaser 1: base=$B028, initialized from $CD92: X=$40(64), Y=$12(18), dir=0
;   Starts at top border, heading right
;   IX=$B028 when moving chaser 1 at $C4DD
;
; Chaser 2: base=$B04D, initialized from $CD95: X=$40(64), Y=$5D(93), dir=4
;   Starts at bottom border, heading left
;   IX=$B04D when moving chaser 2 at $C4E4
;
; Cross-references:
;   $CD29: LD HL,CHASER1_DATA -- chaser init loop entry
;   $CD2C: LD DE,CHASER_POSITIONS -- load init positions
;   $CAA9: LD HL,(CHASER1_DATA) -- collision check (reads X,Y pair)
;   $CAC8: LD HL,(CHASER2_DATA) -- collision check
;   $C393/$C3AB/$C45B/$C461: sprite background save/restore
;   $C3E5/$C3EB: entity erase at old positions
;   $C661/$C668: move chasers during death animation
;
; Activation: controlled by CHASER_ACTIVATION table at $CD9B
;   Levels 0-5: $80 = only chaser 1 active (bit 7 set)
;   Levels 6+:  $C0 = both chasers active (bits 7,6 set)
;

; -----------------------------------------------------------------------
; TRAIL CURSOR STATE (5 bytes at $B072-$B076)
; -----------------------------------------------------------------------
;
; The trail cursor chases the player along the trail buffer from behind.
; It activates when TRAIL_FRAME_CTR reaches 72 ($48), then advances
; 2 entries per frame (6 bytes in the $9000 trail buffer).
; If the cursor exhausts the buffer (catches the player), a collision
; is triggered: SET 0,(HL) on STATE_FLAGS at $CC1F.
;
; Layout:
;   $B072  X position (0 = cursor inactive/not yet activated)
;   $B073  Y position
;   $B074  (direction or sub-data, initialized to 2)
;   $B075-$B076  Trail buffer read pointer (16-bit, into $9000 area)
;     Advances by 3 bytes (one trail entry) for each step
;     Compared against TRAIL_WRITE_PTR to detect catching up
;
; Cross-references:
;   $CA9B: trail cursor activation (set from first trail buffer entry)
;   $CBFE: MOVE_TRAIL_CURSOR -- advance cursor along trail
;   $CC03: SET 6,(HL) on STATE_FLAGS -- sound trigger when cursor moves
;   $CC1F: SET 0,(HL) on STATE_FLAGS -- collision if cursor exhausted
;   $CAE3: LD HL,(TRAIL_CURSOR) -- collision check (player vs cursor)
;   $C3F1/$C455: sprite background save/restore
;   $CCAB: LD (TRAIL_CURSOR),HL with HL=$0000 -- reset at level init
;   $CA3F: LD (TRAIL_CURSOR),A with A=0 -- reset after fill complete
;

; -----------------------------------------------------------------------
; SPARK ARRAY (8 x 5 bytes at $B097-$B0BE)
; -----------------------------------------------------------------------
;
; Up to 8 sparks, each a 5-byte structure. Sparks move diagonally and
; bounce off borders. They die when hitting claimed areas (+50 points)
; and pass through trail cells (but trail collision is checked separately).
;
; Structure layout (offsets from each spark's base):
;   +0  X position (0 = spark inactive/dead)
;   +1  Y position
;   +2  Previous X (saved before move, for sprite erase)
;   +3  Previous Y (saved before move, for sprite erase)
;   +4  Direction (diagonal only: 1=DR, 3=DL, 5=UL, 7=UR)
;     Random diagonal at spawn: (rand() & 3) * 2 + 1
;     Modified on bounce: +2 (CW90), -2 (CCW90), or +4 (180)
;
; Spark base addresses:
;   Spark 0: $B097  (IX=$B097 at $C4EC)
;   Spark 1: $B09C  (IX=$B09C at $C4F3)
;   Spark 2: $B0A1  (IX=$B0A1 at $C4FA)
;   Spark 3: $B0A6  (IX=$B0A6 at $C501)
;   Spark 4: $B0AB  (IX=$B0AB at $C507)
;   Spark 5: $B0B0  (IX=$B0B0 at $C50E)
;   Spark 6: $B0B5  (IX=$B0B5 at $C515)
;   Spark 7: $B0BA  (IX=$B0BA at $C51C)
;
; Each spark also has an "old position" pair at base+2, base+3.
; The main loop erases sparks at their old positions before drawing
; at new positions. Old X,Y read at:
;   $C3FD: LD DE,($B099)  -- spark 0 old X,Y (base+2)
;   $C405: LD DE,($B09E)  -- spark 1 old X,Y
;   ...through $C435: LD DE,($B0BC) -- spark 7 old X,Y
;
; The old position is used for the XOR erase: CALL WRITE_CELL_BMP
; with A=0 to clear the spark's previous pixel position.
;
; Cross-references:
;   $CCBE-$CD0B: spark initialization loop (position + random offset)
;   $D18A: MOVE_SPARK -- diagonal movement with bounce
;   $D267: KILL_SPARK -- deactivate (IX+0=0) + award 50 pts
;   $C467: trail collision check (iterate all 8 sparks)
;   $C3B7/$C728: iterate spark old positions for erase/redraw
;
; Activation: controlled by SPARK_ACTIVATION table at $CD82
;   Level 0: $40 = 1 spark      Level 3: $5A = 4 sparks
;   Level 1: $18 = 2 sparks     Level 7+: $FF = all 8 sparks
;
; Base positions from $CD72 table (random offset 0-7 added to X,
; random offset 0-14 added to Y during init):
;   Spark 0: (29,33)  Spark 4: (93,53)
;   Spark 1: (61,33)  Spark 5: (29,73)
;   Spark 2: (93,33)  Spark 6: (61,73)
;   Spark 3: (29,53)  Spark 7: (93,73)
;

; -----------------------------------------------------------------------
; CORE GAME STATE ($B0BF-$B0C8)
; -----------------------------------------------------------------------
;
;   $B0BF = Timer bar display position
;     Tracks the VISUAL position of the timer bar, which animates
;     toward the actual timer value. UPDATE_TIMER_BAR ($D2C1) compares
;     this against GAME_TIMER and increments/decrements by 1 per frame.
;     Returns carry=1 if bar is still animating (not yet matching timer).
;     Range: 0-176 (mirrors timer range)
;
;   $B0C0 = Game timer (countdown from 176)
;     Decremented every TIMER_SPEED (14) frames at $C537: DEC (HL)
;     Total duration: 176 * 14 = 2464 frames = ~49.3 seconds at 50fps
;     When reaches 0: SET 1 on STATE_FLAGS at $C53D -> timer expired
;     Set to $B0=176 at level init ($CC5C: LD A,$B0 / LD (GAME_TIMER),A)
;     Read at $C582/$D2C4 for level complete countdown and bar display
;     Written at $C58D during level complete timer-to-score countdown
;
;   $B0C1 = Level number (0-based)
;     Used with AND $0F at $CC6D for 16-level wraparound on table lookups
;     Levels 0-15 have distinct configurations; levels 16+ reuse level 15
;     Incremented at $C5B4: INC (HL) after level complete
;     Read at $CCC8/$CD0D for spark/chaser activation
;     Read at $CC6A for color table lookup
;     Read at $D29B for display (shown as level+1 on HUD)
;
;   $B0C2 = Lives remaining
;     Initial value: 3 (set at $CC4B: LD A,$03 / LD ($B0C2),A)
;     Decremented at $C670: DEC (HL) on player death
;     When reaches 0: game over sequence at $C674
;     Read at $D2B6: LD A,(LIVES) for HUD display
;
;   $B0C3-$B0C4 = Base score (16-bit little-endian)
;     $B0C3 = low byte, $B0C4 = high byte
;     Incremented by 50 on spark kill: $D272 LD DE,$0032 / ADD HL,DE
;     Incremented by 1 per timer tick during level complete: $C59B INC HL
;     Added to percentage bonus at level complete: $C706 ADD HL,HL x2
;     Display score = base_score + (raw% + fill%) * 4 ($D280-$D290)
;     Reset to 0 at new game init ($CC47: LD HL,$0000 / LD ($B0C3),HL)
;
;   $B0C5 = Raw claimed percentage
;     Calculated at $C780: count claimed cells / 90
;     Only counts cells with value CELL_CLAIMED (1), not border (3)
;     Used in score formula: score += (raw% + fill%) * 4
;     Cleared to 0 at score finalize ($C700)
;     Range: 0-100 (theoretical; typically 0-~25 before fill converts)
;
;   $B0C6 = Filled percentage
;     Calculated at $C78F: (total_non_empty_cells - 396) / 90
;     396 = border cell count (top 124 + bottom 124 + left 74 + right 74)
;     When >= 75 (CP $4B at $C7A5): level complete triggered
;     Displayed on HUD by UPDATE_PERCENT_DISPLAY at $D2A9
;     Cleared to 0 at score finalize ($C6FA)
;     Range: 0-100
;
;   $B0C7 = Frame counter
;     Incremented every frame at $C3E3: INC (HL)
;     Wraps at 256 (single byte). Used for:
;       - Speed control during drawing: odd frame check at $C897/$C89A
;       - Timing/animation purposes throughout
;     Read at $C897: LD A,(FRAME_CTR)
;
;   $B0C8 = Game state flags (bitfield)
;     Checked at end of each main loop iteration ($C54B-$C55A)
;     Multiple subsystems set bits; main loop reads and dispatches:
;
;     Bit 0: Collision detected
;       SET by CHECK_COLLISIONS return (carry flag -> dispatcher)
;       SET by trail cursor exhaustion at $CC1F: SET 0,(HL)
;       Triggers DEATH_HANDLER at $C555: JP NZ,$C64F
;       Cleared at $C381: LD ($B0C8),A with A=0 (level restart)
;
;     Bit 1: Timer expired
;       SET at $C53D when GAME_TIMER reaches 0
;       Triggers OUT_OF_TIME at $C550: JP NZ,$C6C9
;       Cleared alongside other flags at level restart
;
;     Bit 2: Level complete
;       SET at $C7AC when filled percentage >= 75%
;       Triggers LEVEL_COMPLETE at $C558: BIT 2,(HL)
;       Cleared implicitly when level advances
;
;     Bit 6: Trail cursor moving (sound trigger)
;       SET at $CC06: SET 6,(HL) when trail cursor advances
;       Tested at $C4B9: BIT 6,(HL) for sound generation
;       RES at $C4BD after sound is played
;       Used only for the clicking/ticking sound effect
;
;     Bit 7: Spark bounce (sound trigger)
;       SET at $D1D7: SET 7,(HL) when a spark bounces off border
;       Tested at $C4C7: BIT 7,(HL) for sound generation
;       RES at $C4CB after sound is played
;       Used only for the bounce/ping sound effect
;
;     Initial value: 0 (cleared at $CC61 and $C381)
;

; -----------------------------------------------------------------------
; CELL PATTERN TABLE (8 bytes at $B0C9-$B0D0)
; -----------------------------------------------------------------------
;
; Defines the 2x2 pixel appearance of each cell type in the game field.
; Each cell value (0-3) has 2 bytes: top row pattern and bottom row pattern.
; These bytes are written into the ZX Spectrum bitmap at the cell's
; 2-pixel-wide column position using bit masking.
;
; The pattern bytes use bit pairs for 2-pixel-wide cells:
;   Each byte covers 4 cells horizontally (8 pixels / 2 pixels per cell)
;   Bit pairs: 76=leftmost cell, 54=next, 32=next, 10=rightmost
;   $00 = both pixels off (paper color)
;   $55 = alternating: 01 01 01 01 (checkerboard column A)
;   $AA = alternating: 10 10 10 10 (checkerboard column B)
;   $FF = both pixels on (ink color)
;
; Table entries (2 bytes each):
;   Value 0 (CELL_EMPTY):   $00, $00 -- blank (paper)
;   Value 1 (CELL_CLAIMED): $55, $00 -- dotted top row, blank bottom
;   Value 2 (CELL_TRAIL):   $AA, $55 -- inverse dot top, dot bottom
;   Value 3 (CELL_BORDER):  $FF, $FF -- solid (ink)
;
; Cross-references:
;   Read by WRITE_CELL_BMP ($CEAE) and READ_CELL_BMP ($CEDE):
;     Uses A*2 as index into this table to get the pattern pair.
;     The cell-write routine masks these bits into the screen bitmap.
;   The table is constant (never modified during gameplay).
;

; -----------------------------------------------------------------------
; DIRECTION DELTA TABLE (16 bytes at $B0D1-$B0E0)
; -----------------------------------------------------------------------
;
; Maps direction index (0-7) to signed (dx, dy) movement deltas.
; Each entry is 2 bytes: first byte = dx, second byte = dy.
; Direction index * 2 gives the byte offset into this table.
;
; Directions follow clockwise order starting from right:
;   Dir 0 (Right):      dx=+1 ($01), dy= 0 ($00)
;   Dir 1 (Down-Right): dx=+1 ($01), dy=+1 ($01)
;   Dir 2 (Down):       dx= 0 ($00), dy=+1 ($01)
;   Dir 3 (Down-Left):  dx=-1 ($FF), dy=+1 ($01)
;   Dir 4 (Left):       dx=-1 ($FF), dy= 0 ($00)
;   Dir 5 (Up-Left):    dx=-1 ($FF), dy=-1 ($FF)
;   Dir 6 (Up):         dx= 0 ($00), dy=-1 ($FF)
;   Dir 7 (Up-Right):   dx=+1 ($01), dy=-1 ($FF)
;
; Player uses only cardinal directions (0, 2, 4, 6).
; Sparks use only diagonal directions (1, 3, 5, 7).
; Chasers use all 8 for their look-ahead probing, but move cardinally.
;
; Cross-references:
;   $D1AE/$D1E7/$D216/$D245: LD HL,DIR_TABLE in MOVE_SPARK
;     Spark reads dx,dy to compute target position
;   $C9B7: LD HL,DIR_TABLE in FILL_DIRECTION
;     Fill logic reads deltas to compute perpendicular seed positions
;   $CB4A/$CB5B (inferred): chaser look-ahead position calculation
;     Chaser probes 3 directions: dir-2, dir, dir+2
;

; -----------------------------------------------------------------------
; TRAIL TRACKING & TIMER CONFIGURATION ($B0E6-$B0EC)
; -----------------------------------------------------------------------
;
;   $B0E6-$B0E7 = Trail buffer write pointer (16-bit, little-endian)
;     Points into the trail buffer at $9000. Each trail entry is 3 bytes
;     (X, Y, direction), plus a zero terminator byte.
;     Initialized to $9000 at level start ($C37C) and after fill ($CA2C)
;     Advanced by 3 after each trail cell is recorded ($C908-$C912)
;     Read at $C904: LD HL,(TRAIL_WRITE_PTR) for recording new points
;     Written at $C912: LD (TRAIL_WRITE_PTR),HL after advancing
;     Maximum buffer space: $9000-$93FF = 1024 bytes = ~341 entries
;
;   $B0E8 = Trail frame counter
;     Incremented every frame while player is in drawing mode,
;     even if the player does not actually move.
;     Incremented at $C8F1/$C918: INC (HL)
;     Checked at $C8F3/$C91A: CP $48 (72 decimal)
;     When it reaches 72: trail cursor activates via CALL $CA9B
;     This gives the player ~1.44 seconds (72 frames at 50fps) before
;     the cursor begins chasing the trail from behind.
;     Reset to 0 at $CA3C (after fill) and $CC64 (level init)
;
;   $B0E9 = Timer sub-counter (current countdown value)
;     Counts down from TIMER_SPEED to 0, then resets and decrements
;     the main game timer. Decremented at $C52D: DEC (HL)
;     When reaches 0: reload from $B0EA and DEC GAME_TIMER ($C537)
;     This creates the timer tick rate: one timer decrement per N frames
;
;   $B0EA = Timer speed reload value
;     Constant $0E (14 decimal) -- frames between timer decrements
;     Loaded at $C530: LD A,(TIMER_SPEED) to reload sub-counter
;     Total level time: 176 ticks * 14 frames/tick = 2464 frames
;     At 50fps: 2464/50 = 49.28 seconds per level
;
;   $B0EC = Game field color attribute byte
;     ZX Spectrum attribute format: bit 7=flash, bit 6=bright,
;     bits 5-3=paper color, bits 2-0=ink color
;     All level colors have BRIGHT=1 and INK=0 (black)
;     Loaded from LEVEL_COLORS table at $CDAB, indexed by level & 0x0F
;     Set at $CC82: LD (FIELD_COLOR),A
;     Used to fill the field attribute area: FILL_ATTR_RECT at $CC8B
;
;     Level color progression (from $CDAB table):
;       Level  0: $70 = bright yellow paper
;       Level  1: $68 = bright cyan paper
;       Level  2: $58 = bright magenta paper
;       Level  3: $60 = bright green paper
;       Level  4: $68 = bright cyan paper
;       Level  5: $78 = bright white paper
;       Level  6: $68 = bright cyan paper
;       Level  7: $70 = bright yellow paper
;       Level  8: $60 = bright green paper
;       Level  9: $58 = bright magenta paper
;       Level 10: $78 = bright white paper
;       Level 11: $68 = bright cyan paper
;       Level 12: $70 = bright yellow paper
;       Level 13: $50 = bright red paper
;       Level 14: $58 = bright magenta paper
;       Level 15: $68 = bright cyan paper
;
; -----------------------------------------------------------------------
; MISCELLANEOUS / UNKNOWN ($B0ED-$B0F4)
; -----------------------------------------------------------------------
;
;   $B0ED-$B0EE  Appear to be $FF,$FF -- possibly unused sentinel values
;   $B0EF        Tested at $CC7C: BIT 7,(HL) -- game mode flag?
;                If bit 7 set, CALL $CD5C (color transform routine)
;                May control color inversion for alternate game modes
;   $B0F0        $00 -- unknown, possibly padding
;   $B0F1        Tested at $CD21: BIT 7,(HL) -- chaser enable override?
;                If bit 7 clear at $CD23, chaser activation mask forced to 0
;                May be a difficulty/cheat flag
;   $B0F2-$B0F4  Boot code continuation data (LD BC,$01FF)
;


; ==========================================================================
; BEGIN DISASSEMBLY
; ==========================================================================

; --------------------------------------------------------------------------
; $B000-$B002: BOOT JUMP
; --------------------------------------------------------------------------
; Entry point when the game binary is first loaded.
; Jumps to $B0F5 which initializes the stack pointer and reads the
; keyboard port. This code is only executed once at startup; during
; normal gameplay, execution is in the main loop at $C3DC.
; --------------------------------------------------------------------------
XB000:	JP	XB0F5		; b000  c3 f5 b0	Jump to boot/init code at $B0F5
;


; --------------------------------------------------------------------------
; $B003-$B004: PLAYER POSITION (16-bit pair: E=X, D=Y)
; --------------------------------------------------------------------------
; Loaded together as LD DE,($B003) where E=X at $B003, D=Y at $B004.
; The disassembler interprets the raw bytes as instructions, but they
; are actually data bytes representing the current player coordinates.
;
; Initial state from SNA dump: X=$03 (3), Y=$39 (57)
; These are overwritten to X=2, Y=18 at every level/restart init.
;
; The "INC BC" at $B003 is really data byte $03 = X coordinate.
; The "ADD HL,SP" at $B004 is really data byte $39 = Y coordinate.
; --------------------------------------------------------------------------
PLAYER_XY:	INC	BC		; b003  03		[DATA: Player X = $03]
	ADD	HL,SP		; b004  39		[DATA: Player Y = $39]
;
	ORG	0B028H
;

; --------------------------------------------------------------------------
; $B028-$B04C: CHASER 1 DATA STRUCTURE (37 bytes)
; --------------------------------------------------------------------------
; Wall-following enemy that patrols border cells.
; Initialized from CHASER_POSITIONS table at $CD92:
;   X=$40(64), Y=$12(18), dir=$00(right)
; Starts at top border, midpoint, heading right.
;
; Byte layout:
;   $B028+0 ($B028) = X position (0=inactive)
;   $B028+1 ($B029) = Y position
;   $B028+2 ($B02A) = direction (data byte shown below: $01)
;   $B028+3 ($B02B) = (sub-field, used in movement)
;   $B028+4 ($B02C) = wall-side flag (0=left, 1=right)
;   $B028+5..$B028+36 = sprite background save buffer (32 bytes)
;
; IX=$B028 when processing chaser 1 movement at $C4DD/$C661
; Collision check reads as 16-bit pair at $CAA9: LD HL,($B028)
; --------------------------------------------------------------------------
CHASER1_DATA:	NOP			; b028  00		[DATA: Chaser 1 X = 0 (inactive in snapshot)]
;
	ORG	0B02AH
;
	DB	1					; b02a [DATA: Chaser 1 direction = 1 (down-right)]
;
	ORG	0B04DH
;

; --------------------------------------------------------------------------
; $B04D-$B071: CHASER 2 DATA STRUCTURE (37 bytes)
; --------------------------------------------------------------------------
; Second wall-following enemy. Same structure as chaser 1.
; Initialized from CHASER_POSITIONS at $CD95:
;   X=$40(64), Y=$5D(93), dir=$04(left)
; Starts at bottom border, midpoint, heading left.
;
; Only active on levels 6+ (CHASER_ACTIVATION[$CD9B] bit 6).
;
; IX=$B04D when processing chaser 2 movement at $C4E4/$C664
; Collision check reads at $CAC8: LD HL,($B04D)
; --------------------------------------------------------------------------
CHASER2_DATA:	NOP			; b04d  00		[DATA: Chaser 2 X = 0 (inactive in snapshot)]
;
	ORG	0B04FH
;
	DB	1					; b04f [DATA: Chaser 2 direction = 1]
;
	ORG	0B072H
;

; --------------------------------------------------------------------------
; $B072-$B076: TRAIL CURSOR STATE
; --------------------------------------------------------------------------
; The trail cursor appears after the player has been drawing for 72 frames.
; It chases along the trail buffer from the starting point, erasing trail
; cells as it goes. If it catches the player (buffer exhausted), a collision
; is triggered and the player dies.
;
; $B072 = cursor X (0 = inactive; activated by $CA9B/$CAA5)
; $B073 = cursor Y
; $B074 = sub-state byte (initialized to 2; purpose: cursor sprite type?)
; $B075-$B076 = trail buffer read pointer (16-bit, into $9000 area)
;
; IX=$B072 when processing cursor movement at $C523: LD IX,$B072
; Collision check at $CAE3: LD HL,($B072)
; Reset to 0 at $CCAB (level init) and $CA3F (after fill)
; --------------------------------------------------------------------------
TRAIL_CURSOR:	NOP			; b072  00		[DATA: Cursor X = 0 (inactive)]
;
	ORG	0B074H
;
	DB	2					; b074 [DATA: Cursor sub-state = 2]
;
XB075:	NOP			; b075  00		[DATA: Trail buffer read pointer low = $00]
;
	ORG	0B097H
;

; --------------------------------------------------------------------------
; $B097-$B0BE: SPARK DATA ARRAY (8 sparks x 5 bytes = 40 bytes)
; --------------------------------------------------------------------------
; Each spark is 5 bytes: X, Y, oldX, oldY, direction.
; X=0 means inactive. Sparks move diagonally (dirs 1,3,5,7 only).
;
; Spark 0: $B097-$B09B  (oldXY at $B099-$B09A)
; Spark 1: $B09C-$B0A0  (oldXY at $B09E-$B09F)
; Spark 2: $B0A1-$B0A5  (oldXY at $B0A3-$B0A4)
; Spark 3: $B0A6-$B0AA  (oldXY at $B0A8-$B0A9)
; Spark 4: $B0AB-$B0AF  (oldXY at $B0AD-$B0AE)
; Spark 5: $B0B0-$B0B4  (oldXY at $B0B2-$B0B3)
; Spark 6: $B0B5-$B0B9  (oldXY at $B0B7-$B0B8)
; Spark 7: $B0BA-$B0BE  (oldXY at $B0BC-$B0BD)
;
; The main loop erases sparks at old positions (XOR method) before
; moving, then redraws at new positions. The old position pairs are
; loaded individually: LD DE,($B099), LD DE,($B09E), etc.
;
; Movement routine: MOVE_SPARK at $D18A (called 8 times per frame)
; Kill routine: KILL_SPARK at $D267 (sets X=0, awards 50 points)
; Init: $CCBE loop with random diagonal direction and position offset
; --------------------------------------------------------------------------
SPARK_ARRAY:	NOP			; b097  00		[DATA: Spark 0 X = 0 (inactive)]
;
	ORG	0B099H
;
; --- Spark 0: previous position (for erase) ---
; Read at $C3FD: LD DE,($B099) to get old X,Y for XOR erase
XB099:	NOP			; b099  00		[DATA: Spark 0 old X = 0]
;
	ORG	0B09EH
;
; --- Spark 1: previous position ---
; Read at $C405: LD DE,($B09E)
XB09E:	NOP			; b09e  00		[DATA: Spark 1 old X = 0]
;
	ORG	0B0A3H
;
; --- Spark 2: previous position ---
; Read at $C40D: LD DE,($B0A3)
XB0A3:	NOP			; b0a3  00		[DATA: Spark 2 old X = 0]
;
	ORG	0B0A8H
;
; --- Spark 3: previous position ---
; Read at $C415: LD DE,($B0A8)
XB0A8:	NOP			; b0a8  00		[DATA: Spark 3 old X = 0]
;
	ORG	0B0ADH
;
; --- Spark 4: previous position ---
; Read at $C41D: LD DE,($B0AD)
XB0AD:	NOP			; b0ad  00		[DATA: Spark 4 old X = 0]
;
	ORG	0B0B2H
;
; --- Spark 5: previous position ---
; Read at $C425: LD DE,($B0B2)
XB0B2:	NOP			; b0b2  00		[DATA: Spark 5 old X = 0]
;
	ORG	0B0B7H
;
; --- Spark 6: previous position ---
; Read at $C42D: LD DE,($B0B7)
XB0B7:	NOP			; b0b7  00		[DATA: Spark 6 old X = 0]
;
	ORG	0B0BCH
;
; --- Spark 7: previous position ---
; Read at $C435: LD DE,($B0BC)
XB0BC:	NOP			; b0bc  00		[DATA: Spark 7 old X = 0]
;
	ORG	0B0BFH
;

; --------------------------------------------------------------------------
; $B0BF: TIMER BAR DISPLAY POSITION
; --------------------------------------------------------------------------
; The visual position of the animated timer bar. The actual game timer
; is at $B0C0, but the bar animates toward it by incrementing/decrementing
; by 1 pixel per frame in UPDATE_TIMER_BAR ($D2C1).
;
; Read at $D2C7: CP (HL) -- compare against GAME_TIMER
; Modified at $D2CB: INC (HL) or $D2D0: DEC (HL)
; Bar is drawn as a 13-pixel-tall XOR column at X=(value+40)
; Range: 0-176 (matching timer range)
; --------------------------------------------------------------------------
TIMER_BAR_POS:	NOP			; b0bf  00		[DATA: Timer bar position = 0]

; --------------------------------------------------------------------------
; $B0C0: GAME TIMER (countdown from 176)
; --------------------------------------------------------------------------
; Main game timer. Counts down from 176 ($B0) to 0.
; Decremented every 14 frames (when TIMER_SUB_CTR hits 0).
; When reaches 0: SET 1 on STATE_FLAGS -> OUT_OF_TIME
;
; Set at $CC5C: LD A,$B0 / LD (GAME_TIMER),A (level init)
; Decremented at $C537: DEC (HL)
; Read at $C582: LD A,(GAME_TIMER) -- level complete countdown start
; Read at $D2C4: LD A,(GAME_TIMER) -- timer bar display sync
; Decremented at $C58D during level complete timer-to-score countdown
; --------------------------------------------------------------------------
GAME_TIMER:	NOP			; b0c0  00		[DATA: Timer = 0 (in snapshot)]

; --------------------------------------------------------------------------
; $B0C1: LEVEL NUMBER (0-based)
; --------------------------------------------------------------------------
; Current level, starting at 0. Displayed as level+1 on HUD.
; Used with AND $0F at $CC6D for 16-level config table wraparound.
; Levels beyond 15 reuse level 15's configuration (max spark/chaser).
;
; Set to 0 at new game: $CC41 area
; Incremented at $C5B4: INC (HL) after level complete
; Read at $CC6A/$CCC8/$CD0D: level table lookups
; Read at $D29B: LD A,(LEVEL_NUM) for HUD display
; --------------------------------------------------------------------------
LEVEL_NUM:	NOP			; b0c1  00		[DATA: Level = 0]

; --------------------------------------------------------------------------
; $B0C2: LIVES REMAINING
; --------------------------------------------------------------------------
; Starts at 3. No extra lives are awarded during gameplay.
; Decremented on death; game over when reaching 0.
;
; Set at $CC4B: LD A,$03 / LD ($B0C2),A (new game init)
; Decremented at $C670: DEC (HL) (death handler)
; Read at $D2B6: LD A,(LIVES) for HUD display
; Tested at $C671: JP NZ,RESTART_LEVEL (lives > 0 -> continue)
; --------------------------------------------------------------------------
LIVES:	NOP			; b0c2  00		[DATA: Lives = 0 (in snapshot)]

; --------------------------------------------------------------------------
; $B0C3-$B0C4: BASE SCORE (16-bit little-endian)
; --------------------------------------------------------------------------
; The accumulated base score, separate from the percentage bonus.
; Display formula: displayed_score = base_score + (raw% + fill%) * 4
;
; $B0C3 = low byte, $B0C4 = high byte
;
; Reset at $CC49: LD ($B0C3),HL with HL=$0000 (new game)
; Read at $D28C: LD DE,(BASE_SCORE) for score display calculation
; Read at $D26F: LD HL,(BASE_SCORE) for spark kill score add
; Written at $D276: LD (BASE_SCORE),HL after spark kill (+50)
; Written at $C59B: LD (BASE_SCORE),HL after timer tick (+1 per tick)
; Written at $C70D: LD (BASE_SCORE),HL after percentage finalization
; Read at $C707: LD DE,(BASE_SCORE) for level complete bonus add
; --------------------------------------------------------------------------
BASE_SCORE:	NOP			; b0c3  00		[DATA: Score low byte = 0]
;
	ORG	0B0C5H
;

; --------------------------------------------------------------------------
; $B0C5: RAW CLAIMED PERCENTAGE
; --------------------------------------------------------------------------
; Percentage of interior cells with value CELL_CLAIMED (1) only.
; Does not count border cells (3) or trail cells (2).
; Calculated as: count_of_claimed_cells / 90 at $C785-$C78E
;
; Written at $C78E: LD (HL),C (result of division)
; Read at $D283: LD HL,RAW_PERCENT for score display
; Read at $C6FC/$C6FF: ADD A,(HL) for score finalize
; Cleared at $C700: LD (HL),0 after score finalize
; --------------------------------------------------------------------------
RAW_PERCENT:	NOP			; b0c5  00		[DATA: Raw % = 0]

; --------------------------------------------------------------------------
; $B0C6: FILLED PERCENTAGE
; --------------------------------------------------------------------------
; Total fill percentage: (all_non_empty_cells - 396) / 90
; 396 accounts for the original border frame cells.
; This is the main progress indicator shown on the HUD.
; When >= 75: level complete is triggered (SET 2 on STATE_FLAGS)
;
; Written at $C7A3: LD (HL),C (result of division)
; Read at $C7A4: CP $4B for win condition check
; Read at $D280: LD A,(FILL_PERCENT) for score display
; Read at $D2A9: LD A,(FILL_PERCENT) for HUD percent display
; Read at $C6F9: LD A,(HL) for score finalize
; Cleared at $C6FA: LD (HL),0 after score finalize
; --------------------------------------------------------------------------
FILL_PERCENT:	NOP			; b0c6  00		[DATA: Fill % = 0]

; --------------------------------------------------------------------------
; $B0C7: FRAME COUNTER
; --------------------------------------------------------------------------
; Incremented every game loop frame. Wraps at 256 (8-bit).
; Used for timing and speed control.
;
; Incremented at $C3E3: INC (HL) (start of each main loop frame)
; Read at $C897: LD A,(FRAME_CTR) -- odd/even frame check for
;   half-speed drawing when fire button is held
; --------------------------------------------------------------------------
FRAME_CTR:	NOP			; b0c7  00		[DATA: Frame counter = 0]

; --------------------------------------------------------------------------
; $B0C8: GAME STATE FLAGS (bitfield)
; --------------------------------------------------------------------------
; Central flag register checked at the end of each frame.
; Multiple game subsystems SET individual bits; the main loop
; tests them in priority order: timer(1) > collision(0) > complete(2)
;
; Bit 0: Collision detected
;   SET at $CC1F (trail cursor catches player)
;   SET via carry flag from CHECK_COLLISIONS ($CAA9)
;   Checked at $C553: BIT 0,(HL) -> JP NZ,DEATH_HANDLER
;
; Bit 1: Timer expired
;   SET at $C53D: SET 1,(HL) when game timer reaches 0
;   Checked at $C54E: BIT 1,(HL) -> JP NZ,OUT_OF_TIME
;
; Bit 2: Level complete (>=75% filled)
;   SET at $C7AC: SET 2,(HL) when fill% >= 75
;   Checked at $C558: BIT 2,(HL) -> JP Z,MAIN_LOOP (loop if not set)
;
; Bit 6: Trail cursor sound trigger
;   SET at $CC06: SET 6,(HL) each time cursor advances
;   Checked/cleared at $C4B9/$C4BD for sound generation
;
; Bit 7: Spark bounce sound trigger
;   SET at $D1D7: SET 7,(HL) on spark border bounce
;   Checked/cleared at $C4C7/$C4CB for sound generation
;
; Cleared wholesale at $CC61/$C381: LD (STATE_FLAGS),A with A=0
; --------------------------------------------------------------------------
STATE_FLAGS:	NOP			; b0c8  00		[DATA: Flags = 0]

; --------------------------------------------------------------------------
; $B0C9-$B0D0: CELL PATTERN TABLE (4 entries x 2 bytes = 8 bytes)
; --------------------------------------------------------------------------
; Bitmap patterns for the 4 cell types. Each cell occupies a 2x2 pixel
; area on the ZX Spectrum screen. Two bytes define the top and bottom
; pixel rows of the cell.
;
; Index 0 (CELL_EMPTY):   $00, $00  -- both rows blank
; Index 1 (CELL_CLAIMED): $55, $00  -- dotted top, blank bottom
; Index 2 (CELL_TRAIL):   $AA, $55  -- checkerboard pattern
; Index 3 (CELL_BORDER):  $FF, $FF  -- solid block
;
; Read by cell I/O routines at $CEAE (write) and $CEDE (read).
; The routine computes table address as: CELL_PATTERNS + (cell_value * 2)
; --------------------------------------------------------------------------
CELL_PATTERNS:	NOP			; b0c9  00		[DATA: Empty top  = $00 (blank)]
;
	ORG	0B0CBH
;
; Index 1 (CELL_CLAIMED): top=$55 (01010101 = checkerboard), bottom=$00
; Index 2 (CELL_TRAIL): top=$AA (10101010 = inverse checker), bottom=$55
; Index 3 (CELL_BORDER): top=$FF (11111111 = solid), bottom=$FF
; The DW X01FF at $B0D0 encodes the last byte of border ($FF) and
; the first byte of the direction table ($01).
	DB	55H,0,0AAH,55H,0FFH			; b0cb [DATA: Claimed/Trail/Border patterns]
	DW	X01FF		; b0d0   ff 01      [DATA: Border bottom=$FF, Dir0 dx=$01]
;

; --------------------------------------------------------------------------
; $B0D1-$B0E0: DIRECTION DELTA TABLE (8 directions x 2 bytes = 16 bytes)
; --------------------------------------------------------------------------
; Maps direction index to (dx, dy) signed byte pairs.
; Accessed as: table_base + direction * 2
;
; The raw 16 bytes are:
;   $B0D1: 01 00  (dir 0: Right,      dx=+1, dy= 0)
;   $B0D3: 01 01  (dir 1: Down-Right, dx=+1, dy=+1)
;   $B0D5: 00 01  (dir 2: Down,       dx= 0, dy=+1)
;   $B0D7: FF 01  (dir 3: Down-Left,  dx=-1, dy=+1)
;   $B0D9: FF 00  (dir 4: Left,       dx=-1, dy= 0)
;   $B0DB: FF FF  (dir 5: Up-Left,    dx=-1, dy=-1)
;   $B0DD: 00 FF  (dir 6: Up,         dx= 0, dy=-1)
;   $B0DF: 01 FF  (dir 7: Up-Right,   dx=+1, dy=-1)
;
; NOTE: The disassembler interprets these data bytes as instructions
; (NOP, INC, RST, etc.) because they happen to be valid opcodes.
; They are NEVER executed -- only read as data via indexed loads.
;
; Player cardinal directions:  0(R), 2(D), 4(L), 6(U)
; Spark diagonal directions:   1(DR), 3(DL), 5(UL), 7(UR)
; Chaser look-ahead uses all 8 for probing neighboring cells.
;
; Referenced by label DIR_TABLE at:
;   $D1AE/$D1E7/$D216/$D245: LD HL,DIR_TABLE  (spark movement)
;   $C9B7: LD HL,DIR_TABLE  (fill direction seed calculation)
; --------------------------------------------------------------------------
;
; Dir 0 (Right): dx=+1 ($01), dy=0 ($00)
; Note: The dx=$01 byte is shared with the last byte of the cell pattern
; table above (encoded in the DW X01FF at $B0D0).
	NOP			; b0d2  00		[DATA: Dir 0 dy = $00 (Right: dy=0)]
;
; Dir 1 (Down-Right): dx=+1 ($01), dy=+1 ($01)
	DB	1,1,0,1					; b0d3 [DATA: Dir 1 dx=+1,dy=+1 / Dir 2 dx=0,dy=+1]
; Dir 3 (Down-Left): dx=-1 ($FF), dy=+1 ($01)
	DW	X01FF		; b0d7   ff 01      [DATA: Dir 3 dx=$FF(-1), dy=$01(+1)]
; Dir 4 (Left): dx=-1 ($FF), dy=0 ($00)
	DW	X00FF		; b0d9   ff 00      [DATA: Dir 4 dx=$FF(-1), dy=$00(0)]
; Dir 5 (Up-Left): dx=-1 ($FF), dy=-1 ($FF)
	DB	0FFH					; b0db [DATA: Dir 5 dx=$FF(-1)]
	DW	X00FF		; b0dc   ff 00      [DATA: Dir 5 dy=$FF(-1), Dir 6 dx=$00(0)]
;
; Dir 6 (Up): dx=0 ($00), dy=-1 ($FF)
; Note: Dir 6 dx=$00 is the second byte of the DW above.
	RST	38H		; b0de  ff		[DATA: Dir 6 dy = $FF (-1)]
;
; Dir 7 (Up-Right): dx=+1 ($01), dy=-1 ($FF)
	DB	1					; b0df [DATA: Dir 7 dx = $01 (+1)]
	DW	X00FF		; b0e0   ff 00      [DATA: Dir 7 dy=$FF(-1), then padding $00]
;

; --------------------------------------------------------------------------
; $B0E1: PLAYER FLAGS BYTE (IX+0 when IX=$B0E1)
; --------------------------------------------------------------------------
; This is the primary player state register, accessed via IX+0.
; IX is set to $B0E1 at the start of each frame: LD IX,$B0E1 ($C3DC)
;
; Bit 0: Axis (1=horizontal, 0=vertical) -- last move direction axis
; Bit 4: Fast mode (fire held during drawing) -- half-speed movement
; Bit 5: Draw direction (used in fill cell value determination)
; Bit 6: Fill complete (trail reached border, trigger flood fill)
; Bit 7: Drawing (currently creating a trail through empty space)
;
; Initial value: 0 (cleared at $CCA5 during level init)
; Note: $B0E1 is NOT shown in the disassembly listing since it falls
; between DIR_TABLE's last byte ($B0E0) and PLAYER_DIR ($B0E2).
; The label PLAYER_FLAGS is used at $CCA5 and $C3DC.
; --------------------------------------------------------------------------

; --------------------------------------------------------------------------
; $B0E2: PLAYER DIRECTION (IX+1)
; --------------------------------------------------------------------------
; Current player movement direction. Cardinal only: 0, 2, 4, or 6.
; Set by TRY_HORIZONTAL ($CA65) and TRY_VERTICAL ($CA91).
; Read at $C90B: LD A,(IX+1) when recording trail buffer entries.
; Read at $C95A: LD A,(IX+1) for fill direction diff calculation.
; --------------------------------------------------------------------------
PLAYER_DIR:
	DB	0					; b0e2 [DATA: Direction = 0 (right)]
;

; --------------------------------------------------------------------------
; $B0E3: FILL CELL VALUE (IX+2)
; --------------------------------------------------------------------------
; Determines what cell value is used when seeding the flood fill.
; Set at $C934 based on player flags:
;   If BIT 4 (fast mode) is set: A=1 (CELL_CLAIMED)
;   If BIT 4 is clear: A=2 (CELL_TRAIL)
; Read at $C9C6/$C9F6/$CA20 as the fill value for CALL $CF01.
; --------------------------------------------------------------------------
FILL_CELL_VAL:	LD	(BC),A		; b0e3  02		[DATA: Fill value = $02 (CELL_TRAIL)]

; --------------------------------------------------------------------------
; $B0E4-$B0E5: DRAWING START POSITION
; --------------------------------------------------------------------------
; Saved when the player enters drawing mode (presses fire on empty cell).
; $B0E4 = start X, $B0E5 = start Y.
; Written at $C7E4/$C81E/$C842/$C87C: LD (DRAW_START),HL
; Read at $C774: LD HL,(DRAW_START) to restore player position on death
; while drawing (reverts to where the draw began).
; --------------------------------------------------------------------------
DRAW_START:	NOP			; b0e4  00		[DATA: Draw start X = 0]
;
	ORG	0B0E6H
;

; --------------------------------------------------------------------------
; $B0E6-$B0E7: TRAIL BUFFER WRITE POINTER (16-bit)
; --------------------------------------------------------------------------
; Points to the next free position in the trail buffer at $9000.
; Each trail entry is 3 bytes: X, Y, direction, followed by a $00 sentinel.
; The pointer advances by 3 after each new trail cell.
;
; Initialized to $9000 at:
;   $C37C: LD (TRAIL_WRITE_PTR),HL -- restart level
;   $CA2C: LD (TRAIL_WRITE_PTR),HL -- after fill complete
; Advanced at $C912: LD (TRAIL_WRITE_PTR),HL after recording new point
; Read at $C904: LD HL,(TRAIL_WRITE_PTR) to get current write position
;
; Low byte at $B0E6, high byte at $B0E7 (=$90 = $9000 base)
; --------------------------------------------------------------------------
TRAIL_WRITE_PTR:	NOP			; b0e6  00		[DATA: Trail ptr low = $00]
;
	DB	90H					; b0e7 [DATA: Trail ptr high = $90 -> pointer = $9000]
;

; --------------------------------------------------------------------------
; $B0E8: TRAIL FRAME COUNTER
; --------------------------------------------------------------------------
; Counts frames elapsed since the player started drawing.
; Incremented every frame during drawing mode, even if player doesn't move.
; When it reaches 72 ($48): trail cursor activates and begins chasing.
;
; Incremented at $C8F1/$C918: INC (HL)
; Compared at $C8F3/$C91A: CP $48
; Reset at $CA3C/$CC64: LD (TRAIL_FRAME_CTR),A with A=0
;
; Range: 0-255 (wraps, but cursor activates at 72 so wrapping is moot)
; At 50fps: 72 frames = 1.44 seconds of drawing before cursor appears
; --------------------------------------------------------------------------
TRAIL_FRAME_CTR:	NOP			; b0e8  00		[DATA: Trail frames = 0]

; --------------------------------------------------------------------------
; $B0E9: TIMER SUB-COUNTER (current countdown)
; --------------------------------------------------------------------------
; Counts down from TIMER_SPEED (14) to 0, then reloads and decrements
; the main GAME_TIMER. This creates the timer tick rate.
;
; Decremented at $C52D: DEC (HL) -- every frame in main loop
; When reaches 0: reload from $B0EA, then DEC GAME_TIMER at $C537
; --------------------------------------------------------------------------
TIMER_SUB_CTR:	NOP			; b0e9  00		[DATA: Sub-counter = 0 (in snapshot)]
;

; --------------------------------------------------------------------------
; $B0EA: TIMER SPEED RELOAD VALUE
; --------------------------------------------------------------------------
; Constant value $0E (14 decimal). Loaded into TIMER_SUB_CTR when it
; reaches 0, establishing the rate: one timer tick every 14 frames.
;
; Total level time: 176 ticks * 14 frames = 2464 frames / 50fps = 49.28s
; Read at $C530: LD A,(TIMER_SPEED) to reload sub-counter
; This value is never modified during gameplay.
; --------------------------------------------------------------------------
TIMER_SPEED:	DB	0EH					; b0ea [DATA: Speed = $0E (14 frames/tick)]

; --------------------------------------------------------------------------
; $B0EB: (UNKNOWN/UNUSED)
; --------------------------------------------------------------------------
; Appears to be unused padding. Always 0 in the snapshot.
; --------------------------------------------------------------------------
XB0EB:	DB	0					; b0eb [DATA: $00 (unused)]

; --------------------------------------------------------------------------
; $B0EC: FIELD COLOR ATTRIBUTE
; --------------------------------------------------------------------------
; ZX Spectrum attribute byte for the game field area.
; Format: FBPPPIII (F=flash, B=bright, PPP=paper, III=ink)
; All levels: Bright=1, Ink=0 (black). Paper color varies by level.
;
; Set at $CC82: LD (FIELD_COLOR),A from level color table
; Used to set the attribute area for the playing field
;
; $70 = 01110000 = Bright + Paper 6 (yellow) + Ink 0 (black)
; This is the initial/default value (level 0 = yellow field).
; --------------------------------------------------------------------------
FIELD_COLOR:	DB	70H					; b0ec [DATA: Attr = $70 (bright yellow)]

; --------------------------------------------------------------------------
; $B0ED-$B0F4: MISCELLANEOUS / BOOT DATA
; --------------------------------------------------------------------------
; These bytes contain a mix of runtime flags and boot initialization data.
; Some are tested during level init but their exact purpose is uncertain.
;
; $B0ED = $FF  (unknown sentinel or flag)
; $B0EE = $FF  (unknown sentinel or flag)
; $B0EF = $00  Tested at $CC7C: BIT 7,(HL)
;              If bit 7 set, calls $CD5C (color attribute transform)
;              Possibly a game mode or visual effects flag
; $B0F0 = $00  Unknown, possibly unused padding
; $B0F1 = $FF  Tested at $CD21: BIT 7,(HL)
;              If bit 7 clear, chaser activation mask forced to $00
;              Acts as a chaser enable/disable override
;              $FF (bit 7 set) = chasers use normal activation rules
;              $00 (bit 7 clear) = all chasers disabled regardless of level
; $B0F2-$B0F4 = LD BC,$01FF (part of boot code, not used in gameplay)
; --------------------------------------------------------------------------
;
XB0ED:	RST	38H		; b0ed  ff		[DATA: $FF (unknown flag)]
XB0EE:	RST	38H		; b0ee  ff		[DATA: $FF (unknown flag)]
XB0EF:	NOP			; b0ef  00		[DATA: $00 (color mode flag)]
XB0F0:	NOP			; b0f0  00		[DATA: $00 (unused)]
XB0F1:	RST	38H		; b0f1  ff		[DATA: $FF (chaser enable override)]
XB0F2:	LD	BC,X01FF	; b0f2  01 ff 01	[BOOT: LD BC,$01FF -- part of init]

; --------------------------------------------------------------------------
; $B0F5-$B0FF: BOOT INITIALIZATION CODE
; --------------------------------------------------------------------------
; Executed once at game startup (jumped to from $B000: JP $B0F5).
; Sets up the stack pointer and reads the keyboard port.
; After this runs, control transfers to the menu system.
; This code is NOT part of the game loop -- it only runs on cold start.
;
; $B0F5: LD SP,$B000  -- stack grows downward from $B000
;                        (stack area is below game variables)
; $B0F8: LD HL,$07D0  -- parameter for subsequent code
; $B0FB: LD E,A       -- save accumulator
; $B0FC: LD BC,$001F  -- keyboard port address
; $B0FF: IN A,(C)     -- read keyboard port $xx1F
;                        (standard ZX Spectrum keyboard matrix read)
; --------------------------------------------------------------------------
XB0F5:	LD	SP,XB000	; b0f5  31 00 b0	[BOOT: Set stack pointer to $B000]
	LD	HL,X07D0	; b0f8  21 d0 07	[BOOT: LD HL,$07D0]
	LD	E,A		; b0fb  5f		[BOOT: Save A to E]
XB0FC:	LD	BC,X001F	; b0fc  01 1f 00	[BOOT: Keyboard port address $001F]
	IN	A,(C)		; b0ff  ed 78		[BOOT: Read keyboard port]
