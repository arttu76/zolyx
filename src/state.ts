// ============================================================================
// GAME STATE — All mutable game state in a single exported object
// ============================================================================

import type { Player, Chaser, Spark, TrailCursor, TrailEntry, InputKeys, Grid } from './types';
import { FIELD_MIN_X, FIELD_MIN_Y, INITIAL_LIVES, INITIAL_TIMER, TIMER_SPEED } from './constants';

/**
 * Central mutable game state object.
 * The binding is const (never reassigned), but all properties are mutable.
 * Field comments reference original Z80 memory addresses.
 */
export const state = {
  /**
   * The game grid: 2D array indexed as grid[y][x].
   * Values are CELL_EMPTY (0), CELL_CLAIMED (1), CELL_TRAIL (2), CELL_BORDER (3).
   * Dimensions cover the full coordinate space used by the original game.
   */
  grid: [] as Grid,

  /** Player state — matches original variables at $B003-$B004 and $B0E1. */
  player: {
    x: FIELD_MIN_X,        // $B003: X position (E register in LD DE,($B003))
    y: FIELD_MIN_Y,        // $B004: Y position (D register)
    dir: 0,                // $B0E2 (IX+1): current movement direction (0,2,4,6)
    axisH: false,          // $B0E1 bit 0: true=last move was horizontal
    drawing: false,        // $B0E1 bit 7: true=currently drawing a trail
    fastMode: false,       // $B0E1 bit 4: true=fire held during drawing (half speed)
    fillComplete: false,   // $B0E1 bit 6: trail reached border, trigger fill
  } as Player,

  /**
   * Trail buffer: records each cell the player draws through.
   * Original is at $9000 with 3 bytes per entry (X, Y, direction).
   * The trail buffer write pointer is at $B0E6-$B0E7.
   */
  trailBuffer: [] as TrailEntry[],

  /**
   * Trail frame counter (not the same as trail length!).
   * Incremented every frame while drawing, even if the player doesn't move.
   * From $B0E8. When it reaches 72 ($48), the trail cursor activates.
   */
  trailFrameCounter: 0,

  /** Chaser entities. Original data at $B028 (chaser 1) and $B04D (chaser 2). */
  chasers: [] as Chaser[],

  /**
   * Spark entities (up to 8). Original data at $B097, 5 bytes per spark.
   * Sparks move diagonally (directions 1, 3, 5, 7 only), bouncing off borders
   * and dying when hitting claimed/trail cells (+50 points).
   */
  sparks: [] as Spark[],

  /**
   * Trail cursor: chases the player along the trail buffer.
   * Activates when trailFrameCounter reaches 72.
   * From $B072-$B076 in the original.
   */
  trailCursor: {
    x: 0,              // $B072: cursor X position
    y: 0,              // $B073: cursor Y position
    active: false,     // non-zero X means active (original: $B072 != 0)
    bufferIndex: 0,    // index into trailBuffer (original: 16-bit pointer at $B075)
  } as TrailCursor,

  // --- Global game state ---
  score: 0,                        // $B0C3-$B0C4: 16-bit score
  lives: INITIAL_LIVES,            // $B0C2: lives remaining
  level: 0,                        // $B0C1: current level (0-based)
  timer: INITIAL_TIMER,            // $B0C0: game timer countdown
  timerSub: TIMER_SPEED,           // $B0E9: timer sub-counter
  frameCounter: 0,                 // $B0C7: frame counter (incremented each game loop)
  percentage: 0,                   // $B0C6: current filled percentage
  rawPercentage: 0,                // $B0C5: raw claimed-only percentage
  fieldColor: "#FFFF00",           // Current level's field color (derived from $CDAB table)
  gameOver: false,
  gameOverOutOfTime: false,        // true = "Out of Time" variant, false = normal game over
  gameOverFrame: 0,                // Animation frame counter for rainbow cycling
  levelComplete: false,

  // Level complete animation state (matches Z80 $C55D-$C5B5 sequence)
  lcAnim: {
    active: false,                 // true while level complete sequence is playing
    phase: 0 as number,           // 0=rainbow, 1=timer countdown, 2=pause, 3=done
    frame: 0,                     // frame counter within current phase
    timerCountdown: 0,            // remaining timer ticks to count down
    subFrame: 0,                  // sub-frame counter (2 frames per tick in countdown)
  },
  collision: false,
  timerExpired: false,
  paused: false,
  deathAnimTimer: 0,               // Countdown for death/level-complete animation

  // --- Input state ---
  keys: {
    up: false,
    down: false,
    left: false,
    right: false,
    fire: false,
  } as InputKeys,
};
