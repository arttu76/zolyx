// ============================================================================
// TYPES — TypeScript interfaces and type definitions for Zolyx
// ============================================================================

/**
 * Cell values (2 bits per cell in original packed format):
 *   0 = empty    (pattern $00,$00 — black)
 *   1 = claimed  (pattern $55,$00 — checkerboard, counts toward percentage)
 *   2 = trail    (pattern $AA,$55 — denser checkerboard, player's active trail)
 *   3 = border   (pattern $FF,$FF — solid, the walls/frame)
 *
 * NOT a const enum — esbuild doesn't support them well with isolatedModules.
 */
export const CellEmpty = 0 as const;
export const CellClaimed = 1 as const;
export const CellTrail = 2 as const;
export const CellBorder = 3 as const;
export type CellValue = 0 | 1 | 2 | 3;

/**
 * Direction encoding (8 directions, indices 0-7):
 *   0: Right     (+1,  0)     4: Left      (-1,  0)
 *   1: Down-Right(+1, +1)     5: Up-Left   (-1, -1)
 *   2: Down      ( 0, +1)     6: Up        ( 0, -1)
 *   3: Down-Left (-1, +1)     7: Up-Right  (+1, -1)
 */
export type Direction = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7;

/** Cardinal directions only (Right, Down, Left, Up). */
export type CardinalDirection = 0 | 2 | 4 | 6;

/** Diagonal directions only (Down-Right, Down-Left, Up-Left, Up-Right). */
export type DiagonalDirection = 1 | 3 | 5 | 7;

/**
 * Player state — matches original variables at $B003-$B004 and $B0E1.
 */
export interface Player {
  x: number;               // $B003: X position (E register in LD DE,($B003))
  y: number;               // $B004: Y position (D register)
  dir: CardinalDirection;   // $B0E2 (IX+1): current movement direction (0,2,4,6)
  axisH: boolean;           // $B0E1 bit 0: true=last move was horizontal
  drawing: boolean;         // $B0E1 bit 7: true=currently drawing a trail
  fastMode: boolean;        // $B0E1 bit 4: true=fire held during drawing (half speed)
  fillComplete: boolean;    // $B0E1 bit 6: trail reached border, trigger fill
}

/**
 * Chaser entities. Original data at $B028 (chaser 1) and $B04D (chaser 2).
 */
export interface Chaser {
  x: number;
  y: number;
  dir: CardinalDirection;
  active: boolean;
  wallSide: 0 | 1;
}

/**
 * Spark entities (up to 8). Original data at $B097, 5 bytes per spark.
 * Sparks move diagonally (directions 1, 3, 5, 7 only), bouncing off borders
 * and dying when hitting claimed/trail cells (+50 points).
 */
export interface Spark {
  x: number;
  y: number;
  dir: DiagonalDirection;
  active: boolean;
}

/**
 * Trail cursor: chases the player along the trail buffer.
 * Activates when trailFrameCounter reaches 72.
 * From $B072-$B076 in the original.
 */
export interface TrailCursor {
  x: number;               // $B072: cursor X position
  y: number;               // $B073: cursor Y position
  active: boolean;         // non-zero X means active (original: $B072 != 0)
  bufferIndex: number;     // index into trailBuffer (original: 16-bit pointer at $B075)
}

/**
 * Trail buffer entry: records each cell the player draws through.
 * Original is at $9000 with 3 bytes per entry (X, Y, direction).
 */
export interface TrailEntry {
  x: number;
  y: number;
  dir: Direction;
}

/** Input state — mapped from keyboard port bits in the original. */
export interface InputKeys {
  up: boolean;
  down: boolean;
  left: boolean;
  right: boolean;
  fire: boolean;
}

/**
 * Move target returned by movement functions.
 */
export interface MoveTarget {
  x: number;
  y: number;
  dir: CardinalDirection;
}

/**
 * The game grid: 2D array indexed as grid[y][x].
 * Values are CELL_EMPTY (0), CELL_CLAIMED (1), CELL_TRAIL (2), CELL_BORDER (3).
 * Dimensions cover the full coordinate space used by the original game.
 */
export type Grid = number[][];
