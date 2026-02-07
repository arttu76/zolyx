/**
 * Rendering primitives -- pixel-level operations on the ZX Spectrum screen buffers.
 *
 * All functions operate on screenBitmap (1 byte per pixel, 0=paper, 1=ink)
 * and screenAttrs (one byte per 8x8 character cell).
 *
 * Original Z80 equivalents:
 *   setPixel/xorPixel  — inline pixel writes to $4000 bitmap
 *   blitSCR            — .scr file decoder (interleaved row format)
 */

import { screenBitmap, screenAttrs } from '../screen';
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

/**
 * Decode a ZX Spectrum .scr file (6912 bytes) into screenBitmap and screenAttrs.
 * The bitmap uses the Spectrum's interleaved row ordering within 3 screen thirds.
 */
export function blitSCR(scrData: Uint8Array): void {
  // Bitmap: 6144 bytes. ZX Spectrum interleaved layout.
  for (let y = 0; y < SCREEN_H; y++) {
    const third = y >> 6;                     // which third (0-2)
    const lineInChar = y & 7;                 // pixel row within character cell
    const charRow = (y >> 3) & 7;             // character row within third
    const scrRowOff = third * 2048 + lineInChar * 256 + charRow * 32;
    const bmpRowOff = y * SCREEN_W;
    for (let xByte = 0; xByte < 32; xByte++) {
      const byte = scrData[scrRowOff + xByte];
      const px = xByte * 8;
      for (let b = 0; b < 8; b++) {
        screenBitmap[bmpRowOff + px + b] = (byte >> (7 - b)) & 1;
      }
    }
  }
  // Attributes: 768 bytes at offset 6144
  for (let i = 0; i < 768; i++) {
    screenAttrs[i] = scrData[6144 + i];
  }
}
