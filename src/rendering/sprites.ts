/**
 * Sprite rendering -- draw masked 8x8 sprites and spark cells.
 *
 * Original Z80 routines:
 *   $D078  AND-mask + OR-data sprite renderer
 *   $CEAE  Spark cell renderer (draws 2x2 border-pattern block)
 *
 * Sprite format (from $F000-$F2FF):
 *   8 mask bytes + 8 data bytes per sprite.
 *   mask bit 0 = sprite covers this pixel (clear background first).
 *   data bit 1 = draw INK pixel.
 */

import { SPRITE_MASK } from '../data/sprites';
import { setPixel } from './primitives';

/**
 * Draw an 8x8 masked sprite at game coordinates (gx, gy).
 * Uses AND-mask + OR-data rendering from original $D078:
 *   pixel = (mask_bit === 0) ? data_bit : existing_pixel
 * Sprite is centered on the 2x2 game cell: top-left at pixel (gx*2-3, gy*2-3).
 */
export function drawMaskedSprite(gx: number, gy: number, data: readonly number[]): void {
  const px = gx * 2 - 3;
  const py = gy * 2 - 3;
  for (let r = 0; r < 8; r++) {
    const m = SPRITE_MASK[r];
    const d = data[r];
    for (let b = 0; b < 8; b++) {
      const bit = 7 - b;
      if (!((m >> bit) & 1)) {
        // Mask bit 0 = sprite area: write data bit
        setPixel(px + b, py + r, (d >> bit) & 1);
      }
    }
  }
}

/**
 * Draw a spark as a single 2x2 pixel cell (all pixels set).
 * Matches the original $CEAE which draws sparks as cell value 3 (border pattern
 * $FF/$FF = solid 2x2 block). Sparks only exist on empty cells.
 */
export function drawSpark(gx: number, gy: number): void {
  const px = gx * 2;
  const py = gy * 2;
  setPixel(px, py, 1);
  setPixel(px + 1, py, 1);
  setPixel(px, py + 1, 1);
  setPixel(px + 1, py + 1, 1);
}
