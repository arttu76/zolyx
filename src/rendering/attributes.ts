/**
 * Attribute operations -- ZX Spectrum attribute cell manipulation.
 *
 * The ZX Spectrum display uses a 32x24 grid of 8x8 pixel character cells.
 * Each cell has a single attribute byte controlling ink/paper colors and brightness:
 *   bit 7 = FLASH, bit 6 = BRIGHT, bits 5-3 = PAPER (0-7), bits 2-0 = INK (0-7)
 *
 * Original Z80: attribute memory at $5800-$5AFF (768 bytes).
 */

import { screenAttrs } from '../screen';
import { ATTR_COLS, ATTR_ROWS } from '../constants';

/** Set an attribute cell at character grid position (col, row). */
export function setAttr(col: number, row: number, attr: number): void {
  if (col >= 0 && col < ATTR_COLS && row >= 0 && row < ATTR_ROWS)
    screenAttrs[row * ATTR_COLS + col] = attr;
}

/** Build a ZX attribute byte: bright flag, paper color index, ink color index. */
export function makeAttr(bright: boolean, paper: number, ink: number): number {
  return ((bright ? 1 : 0) << 6) | ((paper & 7) << 3) | (ink & 7);
}

/** Set attributes for a horizontal run of character cells. */
export function setAttrRun(row: number, col: number, len: number, attr: number): void {
  for (let i = 0; i < len; i++) setAttr(col + i, row, attr);
}

/** Set attributes for an entire character row. */
export function setAttrRow(row: number, attr: number): void {
  setAttrRun(row, 0, ATTR_COLS, attr);
}
