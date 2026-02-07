/**
 * Chaser AI — wall-following movement algorithm.
 *
 * Original Z80 routine:
 *   $CB03–$CBFD  moveChaser
 *
 * The chaser moves along border cells using a wall-following strategy:
 *   1. Check 3 cells ahead: forward-left (dir-2), forward (dir+0), forward-right (dir+2)
 *   2. Store the cell values at each of these positions
 *   3. Determine turn direction based on wall-following rules
 *
 * The chaser uses a shadow grid where trail cells read as empty,
 * so chasers treat trail as passable terrain for their wall-following probe.
 */

import { state } from './state';
import {
  CELL_EMPTY, CELL_BORDER, CELL_TRAIL,
  DIR_DX, DIR_DY,
} from './constants';
import { getCell } from './grid';
import type { Chaser, CardinalDirection } from './types';

/**
 * Move a single chaser using the wall-following algorithm.
 * Matches the chaser movement routine at $CB03–$CBFD.
 *
 * The chaser has a "wall side" flag (bit 0 of byte 4):
 *   - wallSide=0: wall is on the LEFT -> prefer turning LEFT
 *   - wallSide=1: wall is on the RIGHT -> prefer turning RIGHT
 *
 * Decision logic (from $CB75–$CBDD):
 *   If wallSide=0 (wall on left):
 *     - If forward-right is border -> turn right by 2 (+2)
 *     - Else if forward is border -> go straight (0)
 *     - Else if forward-left is border -> turn left by 2 (-2)
 *     - Else -> turn hard left (-4, U-turn)
 *
 *   If wallSide=1 (wall on right):
 *     - If forward-left is border -> turn left (-2)
 *     - Else if forward is border -> go straight (0)
 *     - Else if forward-right is border -> turn right (+2)
 *     - Else -> turn hard left (-4, U-turn)
 */
export function moveChaser(ch: Chaser): void {
  if (!ch.active) return;

  // Compute the 3 look-ahead directions:
  // Forward-left = dir - 2, Forward = dir, Forward-right = dir + 2
  const dirLeft = (ch.dir + 6) & 7;   // dir - 2
  const dirFwd = ch.dir;
  const dirRight = (ch.dir + 2) & 7;  // dir + 2

  // Read cells from look-ahead positions.
  // Original reads from shadow screen ($6000) where trail = empty.
  // We mimic this: treat CELL_TRAIL as CELL_EMPTY for chaser probing.
  const rawL = getCell(ch.x + DIR_DX[dirLeft], ch.y + DIR_DY[dirLeft]);
  const rawF = getCell(ch.x + DIR_DX[dirFwd], ch.y + DIR_DY[dirFwd]);
  const rawR = getCell(ch.x + DIR_DX[dirRight], ch.y + DIR_DY[dirRight]);
  const cellLeft: number = rawL === CELL_TRAIL ? CELL_EMPTY : rawL;
  const cellFwd: number = rawF === CELL_TRAIL ? CELL_EMPTY : rawF;
  const cellRight: number = rawR === CELL_TRAIL ? CELL_EMPTY : rawR;

  // --- Wall-side flag update (from $CB75–$CB8F) ---
  // wallSide=0: wall is on LEFT, wallSide=1: wall is on RIGHT.
  //
  // Original Z80 logic:
  //   if cellLeft == BORDER -> skip (keep current wallSide)
  //   else:
  //     if cellRight == EMPTY -> wallSide = 0 (open on right -> wall on left)
  //     elif cellRight == BORDER -> keep current
  //     else (cellRight == CLAIMED) -> wallSide = 1 (obstacle on right -> wall on right)
  if (cellLeft !== CELL_BORDER) {
    if (cellRight === CELL_EMPTY) {
      ch.wallSide = 0;
    } else if (cellRight !== CELL_BORDER) {
      ch.wallSide = 1; // claimed or other non-empty non-border
    }
    // cellRight === CELL_BORDER -> keep current
  }
  // cellLeft === CELL_BORDER -> skip flag update entirely

  // --- Direction decision (from $CB90–$CBDC) ---
  // Chaser ONLY walks on BORDER cells (CP $03 in original).
  let turnAmount: number;

  if (ch.wallSide === 0) {
    // Wall is on LEFT -> hug left wall -> prefer turning RIGHT (toward wall)
    // Priority: right > forward > left > U-turn ($CB96–$CBB9)
    if (cellRight === CELL_BORDER) {
      turnAmount = 2;    // Turn right
    } else if (cellFwd === CELL_BORDER) {
      turnAmount = 0;    // Go straight
    } else if (cellLeft === CELL_BORDER) {
      turnAmount = -2;   // Turn left
    } else {
      turnAmount = -4;   // U-turn
    }
  } else {
    // Wall is on RIGHT -> hug right wall -> prefer turning LEFT (toward wall)
    // Priority: left > forward > right > U-turn ($CBBB–$CBDC)
    if (cellLeft === CELL_BORDER) {
      turnAmount = -2;   // Turn left
    } else if (cellFwd === CELL_BORDER) {
      turnAmount = 0;    // Go straight
    } else if (cellRight === CELL_BORDER) {
      turnAmount = 2;    // Turn right
    } else {
      turnAmount = -4;   // U-turn
    }
  }

  // Apply turn: raw direction accumulation (matches $CBDE–$CBE1)
  ch.dir = ((ch.dir + turnAmount + 8) & 7) as CardinalDirection;

  // Move to new position (matches $CBE4–$CBFA)
  ch.x += DIR_DX[ch.dir];
  ch.y += DIR_DY[ch.dir];
}
