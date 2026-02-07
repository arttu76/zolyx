/**
 * Text rendering -- draw characters and strings into the ZX Spectrum screen bitmap.
 *
 * Three font systems:
 *   1. ZX_FONT ($F700): Custom game font, 96 characters (ASCII 32-127), 8 bytes each.
 *      Used for general text (menus, overlays, game messages).
 *   2. HUD_FONT ($FA00): Custom HUD font, 32 characters, rendered double-height (8x16).
 *      Used for score/level/timer display. Rendered by $D386 in the original.
 *   3. Double-size: ZX_FONT at 2x scale (16x16 per glyph), used for title text.
 *
 * Original Z80 routines:
 *   $D386  HUD double-height character renderer
 *   Various CALL sequences for text printing
 */

import { ZX_FONT, HUD_FONT, HUD_CHAR_MAP } from '../data/fonts';
import { setPixel } from './primitives';
import { SCREEN_W, ATTR_COLS } from '../constants';

/**
 * Draw a character glyph at pixel position (px, py) into the bitmap.
 * Characters 32-127 are supported via ZX_FONT.
 */
export function drawCharAt(ch: string, px: number, py: number): void {
  const code = ch.charCodeAt(0);
  if (code < 32 || code > 127) return;
  const off = (code - 32) * 8;
  for (let r = 0; r < 8; r++) {
    const byte = ZX_FONT[off + r];
    for (let b = 0; b < 8; b++) {
      if (byte & (0x80 >> b)) setPixel(px + b, py + r, 1);
    }
  }
}

/** Print a string at character grid position (row, col). Uppercased. */
export function printAt(row: number, col: number, str: string): void {
  const s = str.toUpperCase();
  for (let i = 0; i < s.length; i++)
    drawCharAt(s[i], (col + i) * 8, row * 8);
}

/**
 * Draw a HUD font character at double height (8x16 pixels, each row drawn twice).
 * Matches the original's $D386 renderer which writes each font byte to two
 * consecutive pixel lines, producing 16px-tall text spanning 2 character rows.
 */
export function drawHudChar(ch: string, px: number, py: number): void {
  const idx = HUD_CHAR_MAP[ch];
  if (idx === undefined) return;
  const off = idx * 8;
  for (let r = 0; r < 8; r++) {
    const byte = HUD_FONT[off + r];
    for (let b = 0; b < 8; b++) {
      if (byte & (0x80 >> b)) {
        setPixel(px + b, py + r * 2, 1);
        setPixel(px + b, py + r * 2 + 1, 1);
      }
    }
  }
}

/**
 * Print a string using the custom HUD font at double height.
 * Does NOT uppercase -- the HUD font has specific mixed-case characters.
 * Row is in character rows (0-based), col in character columns.
 */
export function printHudAt(row: number, col: number, str: string): void {
  for (let i = 0; i < str.length; i++)
    drawHudChar(str[i], (col + i) * 8, row * 8);
}

/** Print a string at character grid position with centered alignment. */
export function printCentered(row: number, str: string): number {
  const col = Math.floor((ATTR_COLS - str.length) / 2);
  printAt(row, col, str);
  return col;
}

/**
 * Draw a character at double size (2x2 pixels per font pixel) for titles.
 * Draws at pixel position (px, py), occupying 16x16 pixels.
 */
export function drawCharDouble(ch: string, px: number, py: number): void {
  const code = ch.charCodeAt(0);
  if (code < 32 || code > 127) return;
  const off = (code - 32) * 8;
  for (let r = 0; r < 8; r++) {
    const byte = ZX_FONT[off + r];
    for (let b = 0; b < 8; b++) {
      if (byte & (0x80 >> b)) {
        setPixel(px + b * 2, py + r * 2, 1);
        setPixel(px + b * 2 + 1, py + r * 2, 1);
        setPixel(px + b * 2, py + r * 2 + 1, 1);
        setPixel(px + b * 2 + 1, py + r * 2 + 1, 1);
      }
    }
  }
}

/** Print a string at double size, centered on a given pixel Y. */
export function printDouble(py: number, str: string): number {
  const s = str.toUpperCase();
  const totalW = s.length * 16;
  const startX = Math.floor((SCREEN_W - totalW) / 2);
  for (let i = 0; i < s.length; i++)
    drawCharDouble(s[i], startX + i * 16, py);
  return startX;
}
