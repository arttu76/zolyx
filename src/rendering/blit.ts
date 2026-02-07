/**
 * Canvas blitting -- convert ZX Spectrum screen buffers to HTML5 Canvas pixels.
 *
 * Reads screenBitmap (1 byte per pixel: 0=paper, 1=ink) and screenAttrs
 * (768 attribute bytes), maps each pixel to its RGB color using the ZX Spectrum
 * palette, and writes to the canvas ImageData.
 *
 * ZX Spectrum attribute format:
 *   bit 7 = FLASH, bit 6 = BRIGHT, bits 5-3 = PAPER (0-7), bits 2-0 = INK (0-7)
 *
 * Color palettes:
 *   BRIGHT=0: dimmer colors (208 intensity)
 *   BRIGHT=1: full colors (255 intensity)
 */

import { screenBitmap, screenAttrs, getCtx, getImageData } from '../screen';
import { SCREEN_W, SCREEN_H, ATTR_COLS } from '../constants';

/**
 * ZX Spectrum BRIGHT color palette [R, G, B].
 * Index 0-7: black, blue, red, magenta, green, cyan, yellow, white.
 */
const ZX_BRIGHT: readonly (readonly [number, number, number])[] = [
  [0,0,0], [0,0,255], [255,0,0], [255,0,255],
  [0,255,0], [0,255,255], [255,255,0], [255,255,255]
];

/** ZX Spectrum normal (non-bright) color palette. */
const ZX_NORMAL: readonly (readonly [number, number, number])[] = [
  [0,0,0], [0,0,208], [208,0,0], [208,0,208],
  [0,208,0], [0,208,208], [208,208,0], [208,208,208]
];

/**
 * Convert the screen bitmap + attributes to canvas ImageData and display.
 * This is the final step: each pixel's color is determined by its attribute
 * cell's INK/PAPER colors and whether the bitmap bit is set.
 */
export function blitToCanvas(): void {
  const imageData = getImageData();
  const ctx = getCtx();
  const data = imageData.data;
  for (let y = 0; y < SCREEN_H; y++) {
    const attrRow = y >> 3;
    const bitmapRowOff = y * SCREEN_W;
    const attrRowOff = attrRow * ATTR_COLS;
    for (let x = 0; x < SCREEN_W; x++) {
      const attr = screenAttrs[attrRowOff + (x >> 3)];
      const bright = (attr >> 6) & 1;
      const paper = (attr >> 3) & 7;
      const ink = attr & 7;
      const palette = bright ? ZX_BRIGHT : ZX_NORMAL;
      const color = screenBitmap[bitmapRowOff + x] ? palette[ink] : palette[paper];
      const idx = (bitmapRowOff + x) << 2;
      data[idx]     = color[0];
      data[idx + 1] = color[1];
      data[idx + 2] = color[2];
      data[idx + 3] = 255;
    }
  }
  ctx.putImageData(imageData, 0, 0);
}
