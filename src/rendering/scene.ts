/**
 * Scene rendering -- compose the full game frame from grid, entities, HUD, and overlays.
 *
 * This is the largest rendering module. It orchestrates all visual output:
 *   1. Clear screen buffers
 *   2. Render the appropriate scene (start screen, gameplay, game over, pause)
 *   3. Blit to canvas
 *
 * Original Z80 rendering is scattered across many routines:
 *   $C3E5-$C3FA   Erase entities at old positions
 *   $C3FD-$C43A   Draw sparks
 *   $C43D-$C44A   Draw trail cell at player position
 *   $C49E-$C4B3   Draw entities (player, cursor, chasers)
 *   $D27A-$D291   Update score display
 *   $D2C1          Update timer bar
 *   $D3D3          Dim field (clear BRIGHT from rows 4-23)
 *   $D415          Rainbow color cycling animation
 *   $BF70          Bordered rectangle overlay
 */

import { state } from '../state';
import {
  SCREEN_W, SCREEN_H, ATTR_COLS, ATTR_ROWS,
  FIELD_MIN_X, FIELD_MAX_X, FIELD_MIN_Y, FIELD_MAX_Y,
  CELL_EMPTY, CELL_PATTERNS,
  LEVEL_COLORS_ATTR,
} from '../constants';
import { screenBitmap, screenAttrs } from '../screen';
import { fillRect, blitSCR, setPixel } from './primitives';
import { setAttr, makeAttr, setAttrRun, setAttrRow } from './attributes';
import { printAt, printHudAt, printCentered } from './text';
import { drawMaskedSprite, drawSpark } from './sprites';
import { blitToCanvas } from './blit';
import {
  SPRITE_PLAYER_DATA,
  SPRITE_CHASER_DATA,
  SPRITE_CURSOR_DATA,
} from '../data/sprites';
import { getDisplayScore, getLevelColorIndex } from '../scoring';

/** Draw the game grid cells into the screen bitmap. */
function drawGrid(): void {
  for (let gy = FIELD_MIN_Y; gy <= FIELD_MAX_Y; gy++) {
    for (let gx = FIELD_MIN_X; gx <= FIELD_MAX_X; gx++) {
      const cell = state.grid[gy][gx];
      if (cell === CELL_EMPTY) continue;

      const px = gx * 2;
      const py = gy * 2;
      const pat = CELL_PATTERNS[cell];

      // Top row: extract 2 pixel values from the pattern byte
      setPixel(px,     py,     (pat[0] >> (7 - (px & 7))) & 1);
      setPixel(px + 1, py,     (pat[0] >> (7 - ((px + 1) & 7))) & 1);
      // Bottom row
      setPixel(px,     py + 1, (pat[1] >> (7 - (px & 7))) & 1);
      setPixel(px + 1, py + 1, (pat[1] >> (7 - ((px + 1) & 7))) & 1);
    }
  }
}

/**
 * Draw all entities into the screen bitmap.
 * Rendering order from the original frame loop at $C3DC:
 *   1. Sparks -- single 2x2 cells drawn with border pattern ($CEAE)
 *   2. Entities -- 8x8 masked sprites drawn on top ($D078)
 * Entities use AND-mask + OR-data rendering. No attribute changes during gameplay.
 */
function drawEntities(): void {
  // Sparks -- single 2x2 pixel cells (border pattern, via $CEAE).
  for (const spark of state.sparks) {
    if (!spark.active) continue;
    drawSpark(spark.x, spark.y);
  }

  // Trail cursor -- 8x8 checkerboard-filled circle ($F200)
  if (state.trailCursor.active) {
    drawMaskedSprite(state.trailCursor.x, state.trailCursor.y, SPRITE_CURSOR_DATA);
  }

  // Chasers -- 8x8 pac-man eye pattern ($F100)
  for (const ch of state.chasers) {
    if (!ch.active) continue;
    drawMaskedSprite(ch.x, ch.y, SPRITE_CHASER_DATA);
  }

  // Player -- 8x8 hollow circle ($F000), drawn last for visual priority
  if (state.deathAnimTimer <= 0) {
    drawMaskedSprite(state.player.x, state.player.y, SPRITE_PLAYER_DATA);
  }
}

/**
 * Render the HUD (score, level, percentage, lives, timer bar) into the bitmap.
 *
 * Original layout from Z80 text data at $B347-$B375:
 *   Row 0: "score 00000   Level 00   Lives 0"  (32 chars, full row)
 *   Row 1: empty separator
 *   Row 2-3: "Time" at col 0, timer bar cols 5-26 (13px tall, Y=17-29),
 *            percentage "000%" at cols 28-31
 *
 * Attributes from $B378-$B3D0:
 *   Rows 0-1: $45 = BRIGHT, PAPER=black, INK=cyan
 *   Row 2-3, cols 0-4:   $45 = BRIGHT cyan (label "Time")
 *   Row 2-3, cols 5-26:  $44 = BRIGHT green (timer bar) or $42 = BRIGHT red (low timer)
 *   Row 2-3, cols 27:    $45 = BRIGHT cyan (spacer)
 *   Row 2-3, cols 28-31: $47 = BRIGHT white (percentage display)
 */
function renderHUD(): void {
  // --- Row 0-1: "Score 00000   Level 00   Lives 0" (double-height custom font) ---
  const scoreVal = getDisplayScore().toString().padStart(5, "0");
  const levelVal = (state.level + 1).toString().padStart(2, "0");
  const livesVal = state.lives.toString();
  // Build the full 32-char row matching original text data at $B347
  const row0 = "Score " + scoreVal + "   Level " + levelVal + "   Lives " + livesVal;
  printHudAt(0, 0, row0);

  // Rows 0-1: BRIGHT cyan on black ($45)
  const cyanAttr = makeAttr(true, 0, 5); // $45
  setAttrRow(0, cyanAttr);
  setAttrRow(1, cyanAttr);

  // --- Rows 2-3: Timer bar area (double-height custom font) ---
  // "Time" label at row 2, col 0
  printHudAt(2, 0, "Time");

  // Timer bar: 13 pixels tall (Y=17 to Y=29), spanning pixel cols 40-215
  // In original $D2C1: pixel_column = timer_display + 40
  // timer goes 176->0, directly maps to pixel width of the bar
  const barX = 40;
  const barY = 17;
  const barH = 13;
  const barW = state.timer;
  if (barW > 0) {
    fillRect(barX, barY, barW, barH, 1);
  }

  // Percentage display at row 2, col 28: "XXX%" (double-height custom font)
  const pctStr = state.percentage.toString().padStart(3, "0") + "%";
  printHudAt(2, 28, pctStr);

  // --- Attributes for rows 2-3 ---
  // Timer bar color: green ($44) when timer >= 40, red ($42) when low
  // From $D2FC: CP $28 (= 40 decimal)
  const timerBarAttr = state.timer >= 40 ? makeAttr(true, 0, 4) : makeAttr(true, 0, 2);

  for (let r = 2; r <= 3; r++) {
    // Cols 0-4: cyan (Time label)
    setAttrRun(r, 0, 5, cyanAttr);
    // Cols 5-26: timer bar color (green or red)
    setAttrRun(r, 5, 22, timerBarAttr);
    // Col 27: cyan spacer
    setAttr(27, r, cyanAttr);
    // Cols 28-31: white (percentage)
    setAttrRun(r, 28, 4, makeAttr(true, 0, 7)); // $47 = BRIGHT white
  }
}

/** Render the start/title screen with loading screen background. */
function renderStartScreen(): void {
  if (state.loadingScrData) {
    // Blit the original loading screen as background
    blitSCR(state.loadingScrData);
  } else {
    for (let r = 0; r < ATTR_ROWS; r++) setAttrRow(r, makeAttr(true, 0, 0));
  }

  // Overlay text on rows 17-22 with black background
  const overlayStart = 17;
  const overlayEnd = 23;
  for (let r = overlayStart; r < overlayEnd; r++) {
    setAttrRow(r, makeAttr(true, 0, 0));
    fillRect(0, r * 8, SCREEN_W, 8, 0);
  }

  // "PRESS ENTER TO START"
  const startStr = "PRESS ENTER TO START";
  const startAttr = makeAttr(true, 0, 7); // bright white
  const c3 = printCentered(18, startStr);
  setAttrRun(18, c3, startStr.length, startAttr);

  // Controls
  const ctrl1 = "ARROWS=MOVE  SPACE=FIRE";
  const ctrl2 = "P=PAUSE";
  const ctrlAttr = makeAttr(false, 0, 5); // non-bright cyan
  const c4 = printCentered(20, ctrl1);
  setAttrRun(20, c4, ctrl1.length, ctrlAttr);
  const c5 = printCentered(22, ctrl2);
  setAttrRun(22, c5, ctrl2.length, ctrlAttr);
}

/**
 * Main render function. Builds the Spectrum screen bitmap and attributes
 * each frame, then blits to the canvas.
 */
export function render(): void {
  // Clear bitmap and reset attributes to black
  screenBitmap.fill(0);
  screenAttrs.fill(0); // paper=0(black), ink=0(black), no bright

  if (state.startScreen) {
    renderStartScreen();
    blitToCanvas();
    return;
  }

  // --- Set field attributes ---
  // Use the ORIGINAL attribute byte from the level color table directly.
  // Format: BRIGHT=1, PAPER=level_color, INK=black(0).
  // This gives the authentic monochrome look: colored background, black ink patterns.
  // Empty cells (bitmap 0) = PAPER (colored), border/patterns (bitmap 1) = INK (black).
  const fieldAttr = LEVEL_COLORS_ATTR[state.level & 0x0F];
  for (let row = 4; row < ATTR_ROWS; row++)
    setAttrRow(row, fieldAttr);

  // --- Draw grid ---
  drawGrid();

  // --- Draw entities (XOR + attribute clash) ---
  drawEntities();

  // --- HUD ---
  renderHUD();

  // --- Overlays (monochrome using field attribute inverted) ---
  const overlayAttr = makeAttr(true, 0, getLevelColorIndex());

  if (state.gameOver) {
    // --- Step 1: Dim the game field ($D3D3: clear BRIGHT from rows 4-23) ---
    for (let row = 4; row < ATTR_ROWS; row++) {
      for (let col = 0; col < ATTR_COLS; col++) {
        const idx = row * ATTR_COLS + col;
        screenAttrs[idx] &= ~0x40; // clear bit 6 (BRIGHT)
      }
    }

    // --- Step 2: Draw bordered rectangle overlay ($BF70) ---
    // Normal game over: rows 11-15 (h=5), cols 8-23 (w=16)
    // Out of time: rows 11-17 (h=7), cols 8-23 (w=16)
    const rectRow = 11;
    const rectCol = 8;
    const rectW = 16;
    const rectH = state.gameOverOutOfTime ? 7 : 5;
    const px0 = rectCol * 8;
    const py0 = rectRow * 8;
    const pw = rectW * 8;
    const ph = rectH * 8;

    // Clear interior to PAPER
    fillRect(px0, py0, pw, ph, 0);
    // Draw 1px border: top, bottom, left, right lines
    fillRect(px0, py0, pw, 1, 1);              // top
    fillRect(px0, py0 + ph - 1, pw, 1, 1);     // bottom
    fillRect(px0, py0, 1, ph, 1);               // left
    fillRect(px0 + pw - 1, py0, 1, ph, 1);     // right

    // --- Step 3: Rainbow color cycling animation ($D415) ---
    // 8 colors, 2 frames per step, 16 steps (2 complete cycles), 32 frames total.
    // After animation ends, stays at cyan.
    const RAINBOW = [0x70, 0x78, 0x40, 0x48, 0x50, 0x58, 0x60, 0x68];
    let rectAttr: number;
    if (state.gameOverFrame < 32) {
      const colorIdx = Math.floor(state.gameOverFrame / 2) & 7;
      rectAttr = RAINBOW[colorIdx];
    } else {
      rectAttr = 0x68; // final: BRIGHT CYAN paper, BLACK ink
    }

    // Set attributes for the rectangle area
    for (let r = rectRow; r < rectRow + rectH; r++) {
      setAttrRun(r, rectCol, rectW, rectAttr);
    }

    // --- Step 4: Draw text ---
    // Original uses proportional font at $F600. We use ZX ROM font, centered
    // within the rectangle. Text is INK (black) on PAPER (cycling color).
    if (state.gameOverOutOfTime) {
      // "Out of Time" centered at row 13, "Game Over" at row 15
      const t1 = "OUT OF TIME";
      printAt(13, Math.floor(rectCol + (rectW - t1.length) / 2), t1);
      const t2 = "GAME OVER";
      printAt(15, Math.floor(rectCol + (rectW - t2.length) / 2), t2);
    } else {
      // "Game Over" centered in the 5-row rectangle (row 13)
      const t1 = "GAME OVER";
      printAt(13, Math.floor(rectCol + (rectW - t1.length) / 2), t1);
    }
  }

  // --- Level Complete overlay ---
  if (state.lcAnim.active) {
    // Step 1: Dim field ($D3D3: clear BRIGHT from rows 4-23)
    for (let row = 4; row < ATTR_ROWS; row++) {
      for (let col = 0; col < ATTR_COLS; col++) {
        screenAttrs[row * ATTR_COLS + col] &= ~0x40;
      }
    }

    // Step 2: Draw bordered popup rectangle (rows 11-15, cols 7-24)
    // Original uses cols 8-23 but text "SCREEN COMPLETED" is 16 chars = full width.
    // Widen by 2 cols for padding, matching the visual style of other popups.
    const lcRow = 11, lcCol = 7, lcW = 18, lcH = 5;
    const lcPx = lcCol * 8, lcPy = lcRow * 8;
    const lcPw = lcW * 8, lcPh = lcH * 8;
    fillRect(lcPx, lcPy, lcPw, lcPh, 0);
    fillRect(lcPx, lcPy, lcPw, 1, 1);
    fillRect(lcPx, lcPy + lcPh - 1, lcPw, 1, 1);
    fillRect(lcPx, lcPy, 1, lcPh, 1);
    fillRect(lcPx + lcPw - 1, lcPy, 1, lcPh, 1);

    // Step 3: Rainbow color cycling ($D415)
    const RAINBOW = [0x70, 0x78, 0x40, 0x48, 0x50, 0x58, 0x60, 0x68];
    const lc = state.lcAnim;
    let lcAttr: number;
    if (lc.phase === 0 && lc.frame < 32) {
      lcAttr = RAINBOW[Math.floor(lc.frame / 2) & 7];
    } else {
      lcAttr = 0x68; // bright cyan
    }
    for (let r = lcRow; r < lcRow + lcH; r++) {
      setAttrRun(r, lcCol, lcW, lcAttr);
    }

    // Step 4: Print "Screen Completed" centered at row 13
    const lcText = "SCREEN COMPLETED";
    printAt(13, Math.floor(lcCol + (lcW - lcText.length) / 2), lcText);
  }

  if (state.paused && !state.gameOver && !state.lcAnim.active) {
    for (let r = 11; r < 13; r++) { setAttrRow(r, overlayAttr); }
    fillRect(0, 88, SCREEN_W, 16, 0);
    printCentered(11, "PAUSED");
    printCentered(12, "P TO RESUME");
  }

  blitToCanvas();
}
