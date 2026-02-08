; ==========================================================================
; ZOLYX — Complete Z80 Disassembly Index
; ZX Spectrum game by Pete Cooke (Firebird Software, 1987)
; Disassembled from zolyx.sna (48K snapshot)
; ==========================================================================
;
; Disassembly tool: dz80 V3.4.1 with trace analysis
; Annotations: reverse-engineered by AI (Claude)
;
; Files:
;   screen_memory.asm                   Screen Memory & System Variables
;   game_variables.asm                  Game Variables & Data Tables
;   menu_system.asm                     Menu System & Startup Code
;   utilities.asm                       Input, Attributes & Screen Utilities
;   main_loop.asm                       Main Game Loop & Level Complete
;   death_scoring.asm                   Death Handler, Game Over & Scoring
;   player_movement.asm                 Player Movement & Drawing
;   movement_collision.asm              Movement Helpers & Collision Detection
;   chaser.asm                          Chaser Wall-Following Movement
;   trail_cursor_init.asm               Trail Cursor & Game Initialization
;   cell_io.asm                         Cell Read/Write & Border Drawing
;   flood_fill.asm                      Scanline Flood Fill Algorithm
;   sprites.asm                         Sprite Drawing Routines
;   spark.asm                           Spark Diagonal Movement
;   display.asm                         Score Display, Timer Bar & Text Rendering
;   effects.asm                         Visual Effects & PRNG
;   remaining_code.asm                  Cellular Automaton (Freebie Feature)
;   sprite_data.asm                     Sprite & Font Data
;
; Memory Map:
;   $4000-$57FF  Screen bitmap (256x192, non-linear ZX layout)
;   $5800-$5AFF  Screen attributes (32x24, 8x8 pixel cells)
;   $6000-$77FF  Shadow grid (bitmap copy; trail=empty for entity navigation)
;   $9000-$93FF  Trail buffer (3 bytes/point: X, Y, direction)
;   $9400-$97FF  Flood fill stack (coordinate pairs)
;   $B000-$B0FF  Game variables & data tables (all mutable state)
;   $B100-$BA67  Menu system & startup code
;   $BA68-$D4FF  Main game code (~6.5 KB)
;   $F000-$F2FF  Entity sprite data (player, chaser, cursor)
;   $F700-$F9FF  Game font (96 chars, printable ASCII)
;   $FA00-$FAFF  HUD font (32 chars, limited set)
;   $FB00-$FB03  Cell bit-mask table
;   $FC00-$FDFF  Grid row pointer lookup table
;

