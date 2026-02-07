/**
 * Percentage and score calculation routines.
 *
 * Original Z80 routines:
 *   $CDBC       countAllNonEmpty — scans 80 rows x 32 bytes x 4 cells
 *   $CDE8       countClaimed — checks (byte & mask) XOR $55 == 0
 *   $C780       updatePercentage — calculates raw% and filled%, checks win condition
 *   $D27A–$D291 getDisplayScore — score = base_score + (rawPercentage + percentage) * 4
 */

import { state } from './state';
import {
  FIELD_MIN_X, FIELD_MAX_X,
  FIELD_MIN_Y, FIELD_MAX_Y,
  CELL_EMPTY, CELL_CLAIMED,
  BORDER_CELL_COUNT, PERCENTAGE_DIVISOR,
  WIN_PERCENTAGE, LEVEL_COLORS_ATTR,
} from './constants';

/**
 * Count all non-empty cells in the game field area.
 * Matches the counter at $CDBC which scans 80 rows x 32 bytes x 4 cells.
 * The original scans the screen memory bitmap; we scan our grid array.
 */
export function countAllNonEmpty(): number {
  let count = 0;
  for (let y = FIELD_MIN_Y; y <= FIELD_MAX_Y; y++) {
    for (let x = FIELD_MIN_X; x <= FIELD_MAX_X; x++) {
      if (state.grid[y][x] !== CELL_EMPTY) count++;
    }
  }
  return count;
}

/**
 * Count only claimed cells (value 1) in the game field.
 * Matches $CDE8 which checks: (byte & mask) != 0 AND (byte & mask) XOR $55 == 0.
 * This specifically identifies cells with the claimed pattern ($55).
 */
export function countClaimed(): number {
  let count = 0;
  for (let y = FIELD_MIN_Y; y <= FIELD_MAX_Y; y++) {
    for (let x = FIELD_MIN_X; x <= FIELD_MAX_X; x++) {
      if (state.grid[y][x] === CELL_CLAIMED) count++;
    }
  }
  return count;
}

/**
 * Recalculate the filled percentage and check win condition.
 * Matches the routine at $C780:
 *   1. Count claimed cells -> raw percentage = count / 90
 *   2. Count all non-empty -> filled percentage = (count - 396) / 90
 *   3. If filled percentage >= 75 -> set level complete flag
 *
 * The score display uses: base_score + (raw% + filled%) * 4.
 * From $D280–$D291 in the original.
 */
export function updatePercentage(): void {
  const claimed = countClaimed();
  state.rawPercentage = Math.floor(claimed / PERCENTAGE_DIVISOR);

  const allNonEmpty = countAllNonEmpty();
  state.percentage = Math.floor((allNonEmpty - BORDER_CELL_COUNT) / PERCENTAGE_DIVISOR);

  if (state.percentage >= WIN_PERCENTAGE) {
    state.levelComplete = true;
  }
}

/**
 * Calculate the display score.
 * From $D27A–$D291: score = base_score + (rawPercentage + filledPercentage) * 4
 */
export function getDisplayScore(): number {
  return state.score + (state.rawPercentage + state.percentage) * 4;
}

/**
 * Get the INK color index for the current level.
 * Extracts the PAPER bits from the original attribute table and uses them as INK
 * (since we render with PAPER=black, INK=level_color for correct visual output).
 */
export function getLevelColorIndex(): number {
  return (LEVEL_COLORS_ATTR[state.level & 0x0F] >> 3) & 7;
}
