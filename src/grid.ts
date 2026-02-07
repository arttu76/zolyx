/**
 * Grid management — initialize, read, and write game field cells.
 *
 * Original Z80 routines:
 *   $CE62–$CE89  Border drawing (initGrid)
 *   $CEDB/$CEDE  Cell reading (getCell)
 *   $CEB4        Cell writing (setCell) — writes to both bitmap $4000 and shadow $6000
 */

import { state } from './state';
import {
  FIELD_MIN_X, FIELD_MAX_X,
  FIELD_MIN_Y, FIELD_MAX_Y,
  CELL_EMPTY, CELL_BORDER,
} from './constants';

/**
 * Initialize the grid: create the border rectangle and fill interior with empty.
 * Matches the border drawing routine at $CE62–$CE89 in the original,
 * which draws border value (3) around X in [2,125], Y in [18,93].
 */
export function initGrid(): void {
  const grid: number[][] = [];
  for (let y = 0; y < 128; y++) {
    grid[y] = [];
    for (let x = 0; x < 128; x++) {
      grid[y][x] = CELL_EMPTY;
    }
  }
  // Draw top border: X from FIELD_MIN_X to FIELD_MAX_X, Y = FIELD_MIN_Y
  for (let x = FIELD_MIN_X; x <= FIELD_MAX_X; x++) grid[FIELD_MIN_Y][x] = CELL_BORDER;
  // Draw bottom border
  for (let x = FIELD_MIN_X; x <= FIELD_MAX_X; x++) grid[FIELD_MAX_Y][x] = CELL_BORDER;
  // Draw left border: Y from FIELD_MIN_Y to FIELD_MAX_Y, X = FIELD_MIN_X
  for (let y = FIELD_MIN_Y; y <= FIELD_MAX_Y; y++) grid[y][FIELD_MIN_X] = CELL_BORDER;
  // Draw right border
  for (let y = FIELD_MIN_Y; y <= FIELD_MAX_Y; y++) grid[y][FIELD_MAX_X] = CELL_BORDER;

  state.grid = grid;
}

/**
 * Read a cell value from the grid, with bounds checking.
 * Returns CELL_BORDER for out-of-bounds reads (safe default).
 * Equivalent to the original's $CEDB/$CEDE cell-reading functions.
 */
export function getCell(x: number, y: number): number {
  if (x < 0 || x >= 128 || y < 0 || y >= 128) return CELL_BORDER;
  return state.grid[y][x];
}

/**
 * Write a cell value to the grid.
 * Equivalent to the original's $CEB4 cell-writing function
 * (which writes to both bitmap at $4000 and shadow at $6000).
 */
export function setCell(x: number, y: number, value: number): void {
  if (x >= 0 && x < 128 && y >= 0 && y < 128) {
    state.grid[y][x] = value;
  }
}
