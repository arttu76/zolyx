/**
 * Rendering primitives -- pixel-level operations on the ZX Spectrum screen buffers.
 *
 * All functions operate on screenBitmap (1 byte per pixel, 0=paper, 1=ink)
 * and screenAttrs (one byte per 8x8 character cell).
 *
 * Original Z80 equivalents:
 *   setPixel/xorPixel  — inline pixel writes to $4000 bitmap
 */

import { screenBitmap } from '../screen';
import { SCREEN_W, SCREEN_H } from '../constants';

/** Set a pixel in the screen bitmap. */
export function setPixel(x: number, y: number, v: number): void {
  if (x >= 0 && x < SCREEN_W && y >= 0 && y < SCREEN_H)
    screenBitmap[y * SCREEN_W + x] = v;
}

/** XOR a pixel in the screen bitmap. */
export function xorPixel(x: number, y: number): void {
  if (x >= 0 && x < SCREEN_W && y >= 0 && y < SCREEN_H)
    screenBitmap[y * SCREEN_W + x] ^= 1;
}

/** XOR a rectangle of pixels in the bitmap. */
export function xorRect(x: number, y: number, w: number, h: number): void {
  for (let py = y; py < y + h; py++)
    for (let px = x; px < x + w; px++)
      xorPixel(px, py);
}

/** Fill a rectangle of pixels in the bitmap. */
export function fillRect(x: number, y: number, w: number, h: number, v: number): void {
  for (let py = y; py < y + h; py++)
    for (let px = x; px < x + w; px++)
      setPixel(px, py, v);
}

