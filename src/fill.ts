/**
 * Flood fill algorithm — fills enclosed areas after trail completion.
 *
 * Original Z80 routines:
 *   $C921–$CA42  performFill — trail-to-border conversion + fill direction + seed
 *   $CF01–$D077  floodFill — scanline fill with stack at $9400
 *
 * Fill direction logic:
 *   - If trail has turns: sum direction changes, fill perpendicular to trail
 *   - If trail is straight horizontal: fill toward nearer Y edge
 *   - If trail is straight vertical: fill toward nearer X edge
 */

import { state } from './state';
import {
  CELL_EMPTY, CELL_CLAIMED, CELL_BORDER,
  DIR_DX, DIR_DY,
} from './constants';
import { getCell, setCell } from './grid';
import { updatePercentage } from './scoring';

/**
 * Perform the flood fill after the player's trail reaches a border.
 * Matches the complex fill logic at $C921–$CA42:
 *
 * 1. Convert all trail cells in the buffer to border (3).
 *    From $C937–$C954: iterate trail buffer, CALL $CEB4 with A=3.
 *
 * 2. Determine fill direction:
 *    a) If trail has turns: sum direction changes. Positive sum -> fill right
 *       of trail direction (offset +2). Negative -> fill left (offset -2).
 *       From $C961–$C9A2.
 *    b) If trail is straight horizontal: fill toward nearer Y edge.
 *       Y < 55 -> fill up, Y >= 55 -> fill down. From $C9CF–$C9FD.
 *       Midpoint 55 = ($37) from $C9D7: CP $37.
 *    c) If trail is straight vertical: fill toward nearer X edge.
 *       X < 63 -> fill left, X >= 63 -> fill right. From $C9FF–$CA28.
 *       Midpoint 63 = ($3F) from $CA02: CP $3F.
 *
 * 3. For each trail point, compute a fill seed one cell perpendicular to
 *    the trail direction (on the fill side), and flood fill from there.
 *    From $C9A3–$C9CC / $C9DD–$C9FD / $CA0C–$CA28.
 *
 * 4. Reset trail buffer and cursor, recalculate percentage.
 *    From $CA29–$CA42.
 */
export function performFill(): void {
  if (state.trailBuffer.length === 0) return;

  // Step 1: Convert all trail buffer cells to BORDER
  // This creates new wall segments from the player's drawn path
  for (const pt of state.trailBuffer) {
    setCell(pt.x, pt.y, CELL_BORDER);
  }

  // Step 2: Determine fill direction
  // Check if the trail has any turns (direction changes)
  const firstDir = state.trailBuffer[0].dir;
  const lastDir = state.player.dir;
  let hasTurns = (firstDir !== lastDir);

  if (!hasTurns) {
    // Check intermediate points for turns too
    for (let i = 1; i < state.trailBuffer.length; i++) {
      if (state.trailBuffer[i].dir !== firstDir) {
        hasTurns = true;
        break;
      }
    }
  }

  if (hasTurns) {
    // --- TURN-BASED FILL DIRECTION ---
    // Sum all direction changes along the trail.
    // From $C963–$C99B: for each consecutive pair, compute diff,
    // normalize +6 -> -2 and -6 -> +2, accumulate.
    let turnSum = 0;
    let prevDir = state.trailBuffer[0].dir;

    for (let i = 1; i < state.trailBuffer.length; i++) {
      let diff = state.trailBuffer[i].dir - prevDir;
      // Normalize: the original wraps diffs of +/-6 to -/+2
      // (crossing the 0/7 direction boundary)
      if (diff === 6) diff = -2;
      else if (diff === -6) diff = 2;
      turnSum += diff;
      prevDir = state.trailBuffer[i].dir;
    }
    // Also include the difference from last trail dir to player's final dir
    let finalDiff = lastDir - prevDir;
    if (finalDiff === 6) finalDiff = -2;
    else if (finalDiff === -6) finalDiff = 2;
    turnSum += finalDiff;

    // From $C99C–$C9A2: convert sign of sum to fill offset
    // Positive sum (right turns) -> offset = +2 (fill to the right)
    // Negative sum (left turns) -> offset = -2 (fill to the left)
    const fillOffset = turnSum >= 0 ? 2 : -2;

    // Seed flood fill from each trail point, offset perpendicular
    for (const pt of state.trailBuffer) {
      const fillDir = ((pt.dir + fillOffset) & 7);
      const seedX = pt.x + DIR_DX[fillDir];
      const seedY = pt.y + DIR_DY[fillDir];
      if (getCell(seedX, seedY) === CELL_EMPTY) {
        floodFill(seedX, seedY, CELL_CLAIMED);
      }
    }
  } else {
    // --- STRAIGHT TRAIL FILL ---
    const isVertical = (firstDir === 2 || firstDir === 6);

    if (!isVertical) {
      // Horizontal trail: fill above or below toward nearer Y edge
      // From $C9D7: CP $37 (55). Y < 55 -> fill up (-1), Y >= 55 -> fill down (+1).
      const refY = state.trailBuffer[0].y;
      const yOffset = (refY < 55) ? -1 : 1;

      for (const pt of state.trailBuffer) {
        if (pt.dir === firstDir) { // Only fill from points with matching direction
          const seedX = pt.x;
          const seedY = pt.y + yOffset;
          if (getCell(seedX, seedY) === CELL_EMPTY) {
            floodFill(seedX, seedY, CELL_CLAIMED);
          }
        }
      }
    } else {
      // Vertical trail: fill left or right toward nearer X edge
      // From $CA02: CP $3F (63). X < 63 -> fill left (-1), X >= 63 -> fill right (+1).
      const refX = state.trailBuffer[0].x;
      const xOffset = (refX < 63) ? -1 : 1;

      for (const pt of state.trailBuffer) {
        if (pt.dir === firstDir) {
          const seedX = pt.x + xOffset;
          const seedY = pt.y;
          if (getCell(seedX, seedY) === CELL_EMPTY) {
            floodFill(seedX, seedY, CELL_CLAIMED);
          }
        }
      }
    }
  }

  // Step 4: Reset trail state
  // From $CA29–$CA42:
  state.trailBuffer = [];
  state.trailFrameCounter = 0;
  state.trailCursor = { x: 0, y: 0, active: false, bufferIndex: 0 };

  // Recalculate percentage after fill
  updatePercentage();
}

/**
 * Stack-based flood fill. Replaces all connected CELL_EMPTY cells
 * reachable from (startX, startY) with the given fill value.
 *
 * The original at $CF01–$D077 uses a scanline fill with a stack at $9400.
 * Our implementation is functionally equivalent but uses a simpler approach.
 */
export function floodFill(startX: number, startY: number, fillValue: number): void {
  if (getCell(startX, startY) !== CELL_EMPTY) return;

  const stack: [number, number][] = [[startX, startY]];
  setCell(startX, startY, fillValue);

  while (stack.length > 0) {
    const [cx, cy] = stack.pop()!;

    // Check 4 cardinal neighbors (the original scanline fill
    // also only propagates in 4 directions: left, right, up, down)
    const neighbors: [number, number][] = [
      [cx - 1, cy], [cx + 1, cy],
      [cx, cy - 1], [cx, cy + 1]
    ];

    for (const [nx, ny] of neighbors) {
      if (getCell(nx, ny) === CELL_EMPTY) {
        setCell(nx, ny, fillValue);
        stack.push([nx, ny]);
      }
    }
  }
}
