// ============================================================================
// SCREEN — ZX Spectrum display simulation buffers and canvas setup
// ============================================================================

import { SCREEN_W, SCREEN_H, ATTR_COLS, ATTR_ROWS } from './constants';

/** Screen bitmap: 1 byte per pixel (0=paper, 1=ink). 256x192 = 49152 bytes. */
export const screenBitmap = new Uint8Array(SCREEN_W * SCREEN_H);

/** Attribute memory: one byte per 8x8 character cell. 32x24 = 768 bytes. */
export const screenAttrs = new Uint8Array(ATTR_COLS * ATTR_ROWS);

// --- Canvas internals (initialized by initScreen) ---
let canvas: HTMLCanvasElement | null = null;
let ctx: CanvasRenderingContext2D | null = null;
let imageData: ImageData | null = null;

/**
 * Initialize the canvas, 2D context, and ImageData from the DOM.
 * Must be called after the DOM is ready (the <canvas id="game"> element must exist).
 */
export function initScreen(): void {
  canvas = document.getElementById("game") as HTMLCanvasElement;
  canvas.width = SCREEN_W;
  canvas.height = SCREEN_H;
  ctx = canvas.getContext("2d")!;
  imageData = ctx.createImageData(SCREEN_W, SCREEN_H);
}

/** Get the 2D rendering context. Throws if initScreen() has not been called. */
export function getCtx(): CanvasRenderingContext2D {
  if (!ctx) throw new Error("Screen not initialized — call initScreen() first");
  return ctx;
}

/** Get the ImageData buffer. Throws if initScreen() has not been called. */
export function getImageData(): ImageData {
  if (!imageData) throw new Error("Screen not initialized — call initScreen() first");
  return imageData;
}
