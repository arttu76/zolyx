/**
 * Game and level initialization routines.
 *
 * Original Z80 routines:
 *   $D3E4        rand — LFSR PRNG seeded from R register
 *   $CC40        initGame — reset level, score, lives
 *   $CC5A–$CD5B  initLevel — timer, grid, color, entities, percentage
 *   $CCAE–$CD0B  initSparks — 8 sparks with random positions and diagonal dirs
 *   $CD19–$CD5B  initChasers — 2 chasers from position table, level mask
 */

import { state } from './state';
import {
  FIELD_MIN_X, FIELD_MIN_Y,
  INITIAL_LIVES, INITIAL_TIMER, TIMER_SPEED,
  SPARK_BASE_POSITIONS, SPARK_MASKS,
  CHASER_MASKS, CHASER_INIT,
  LEVEL_COLORS_ATTR, ZX_BRIGHT_COLORS,
} from './constants';
import { initGrid } from './grid';
import { updatePercentage } from './scoring';
import type { Spark, Chaser, DiagonalDirection, CardinalDirection } from './types';

/**
 * Simple PRNG matching the general behavior of the original's $D3E4 routine.
 * The original uses a linear feedback shift register seeded from the R register.
 */
export function rand(): number {
  return Math.floor(Math.random() * 256);
}

/**
 * Extract the PAPER color index from a ZX Spectrum attribute byte.
 * Bits 5-3 contain the paper color (0-7).
 */
export function getLevelColor(lvl: number): string {
  const attr = LEVEL_COLORS_ATTR[lvl & 0x0F];
  const paperIndex = (attr >> 3) & 7;
  return ZX_BRIGHT_COLORS[paperIndex];
}

/**
 * Initialize a new game from scratch.
 * Matches the init routine at $CC40:
 *   $CC40: LD A,$00 / LD ($B0C1),A -> level = 0
 *   $CC45: LD HL,$0000 / LD ($B0C3),HL -> score = 0
 *   $CC4B: LD A,$03 / LD ($B0C2),A -> lives = 3
 */
export function initGame(): void {
  state.level = 0;
  state.score = 0;
  state.lives = INITIAL_LIVES;
  state.gameOver = false;
  state.gameOverOutOfTime = false;
  state.gameOverFrame = 0;
  initLevel();
}

/**
 * Initialize the current level.
 * Matches the level setup routine at $CC5A–$CD5B:
 *   1. Set timer to 176 ($B0)
 *   2. Clear game state flags
 *   3. Clear screen/grid
 *   4. Set field color from level color table
 *   5. Draw border rectangle
 *   6. Set player to start position (2, 18)
 *   7. Initialize chasers based on level mask
 *   8. Initialize sparks based on level mask
 *   9. Calculate initial percentage
 */
export function initLevel(): void {
  // $CC5A: LD A,$B0 / LD ($B0C0),A -- timer = 176
  state.timer = INITIAL_TIMER;
  state.timerSub = TIMER_SPEED;
  state.frameCounter = 0;
  state.trailFrameCounter = 0;
  state.levelComplete = false;
  state.collision = false;
  state.timerExpired = false;
  state.deathAnimTimer = 0;

  // $CC6A–$CC82: Get level color from $CDAB table
  state.fieldColor = getLevelColor(state.level);

  // $CE19: Clear screen (all cells to empty)
  initGrid();

  // $CCA0: LD HL,$1202 / LD ($B003),HL -- player start at (2, 18)
  // Note: H=$12=18=Y, L=$02=2=X in the original's LD ($B003),HL format
  state.player.x = FIELD_MIN_X;
  state.player.y = FIELD_MIN_Y;
  state.player.dir = 0;
  state.player.axisH = false;
  state.player.drawing = false;
  state.player.fastMode = false;
  state.player.fillComplete = false;
  state.player.drawStartX = 0;
  state.player.drawStartY = 0;

  // Clear trail buffer and cursor
  state.trailBuffer = [];
  state.trailCursor = { x: 0, y: 0, active: false, bufferIndex: 0 };

  // $CCAE–$CCC6: Initialize 8 sparks -- clear data, set random diagonal direction
  initSparks();

  // $CD19–$CD5B: Initialize chasers based on level mask
  initChasers();

  // Calculate initial percentage
  updatePercentage();
}

/**
 * Initialize sparks for the current level.
 * Matches $CCAE–$CD0B:
 *   1. For each of 8 sparks, clear 4 data bytes, set random diagonal direction
 *   2. Get spark mask for current level from $CD82 table
 *   3. For each active spark (bit set in mask):
 *      - Set X = base_X + random(0-7)
 *      - Set Y = base_Y + random(0-14)  [random(0-7) * 2 via RLCA at $CD00]
 *
 * Direction values are always diagonal: 1 (down-right), 3 (down-left),
 * 5 (up-left), or 7 (up-right). Generated as: random(0-3) * 2 + 1.
 * From $CCBE: AND $03 / ADD A,A / ADD A,$01.
 */
export function initSparks(): void {
  const sparks: Spark[] = [];
  const lvl = Math.min(state.level, 15);
  const mask = SPARK_MASKS[lvl];

  for (let i = 0; i < 8; i++) {
    // Random diagonal direction: (rand & 3) * 2 + 1 gives 1, 3, 5, or 7
    const dir = (((rand() & 3) * 2) + 1) as DiagonalDirection;

    // Check if this spark is active for the current level.
    // Original uses RLC C (rotate left through carry) to test each bit.
    // Bit 7 is tested first -> spark 0, then bit 6 -> spark 1, etc.
    const bitMask = 0x80 >> i;
    const active = (mask & bitMask) !== 0;

    if (active) {
      // Position = base + random offset
      // X offset: random(0-7). From $CCF1: AND $07.
      // Y offset: random(0-7) then RLCA (*2) -> 0-14. From $CCFF/$CD00.
      const base = SPARK_BASE_POSITIONS[i];
      const x = base.x + (rand() & 7);
      const y = base.y + ((rand() & 7) * 2);
      sparks.push({ x, y, dir, active: true });
    } else {
      sparks.push({ x: 0, y: 0, dir, active: false });
    }
  }

  state.sparks = sparks;
}

/**
 * Initialize chasers for the current level.
 * Matches $CD19–$CD5B:
 *   1. Get chaser mask from $CD9B table
 *   2. For each of 2 chasers: if bit set in mask, load initial position
 *      from $CD92 table; otherwise disable (X=0)
 *
 * Chaser 1: starts at (64, 18) heading right (dir=0) -- top border
 * Chaser 2: starts at (64, 93) heading left (dir=4) -- bottom border
 */
export function initChasers(): void {
  const lvl = Math.min(state.level, 15);
  const mask = CHASER_MASKS[lvl];
  const chasers: Chaser[] = [];

  for (let i = 0; i < 2; i++) {
    // Bit 7 = chaser 0, bit 6 = chaser 1 (via RLC C at $CD2F)
    const bitMask = 0x80 >> i;
    const active = (mask & bitMask) !== 0;

    if (active) {
      const init = CHASER_INIT[i];
      chasers.push({ x: init.x, y: init.y, dir: init.dir as CardinalDirection, active: true, wallSide: 0 });
    } else {
      chasers.push({ x: 0, y: 0, dir: 0, active: false, wallSide: 0 });
    }
  }

  state.chasers = chasers;
}
