/**
 * Player movement — direction priority, drawing mode, and trail management.
 *
 * Original Z80 routines:
 *   $CA43–$CA6E  tryHorizontal
 *   $CA6F–$CA9A  tryVertical
 *   $C7D2–$C8FA  attemptMove (border walking + drawing mode)
 *   $C7B5–$C8F9  movePlayer (main movement with axis-based priority)
 *   $C8F3/$C91A  checkTrailCursorActivation (CP $48 = 72 threshold)
 */

import { state } from './state';
import {
  FIELD_MIN_X, FIELD_MAX_X,
  FIELD_MIN_Y, FIELD_MAX_Y,
  CELL_EMPTY, CELL_BORDER, CELL_TRAIL,
  TRAIL_CURSOR_THRESHOLD,
} from './constants';
import { getCell, setCell } from './grid';
import { getInputBits } from './input';
import type { MoveTarget, CardinalDirection } from './types';

/**
 * Try horizontal movement. Matches $CA43–$CA6E.
 *
 * Reads bits 3 (right) and 4 (left) from input. If both or neither pressed,
 * returns null (no movement). Otherwise:
 *   - Computes new X = current X +/- 1
 *   - Clamps to [FIELD_MIN_X, FIELD_MAX_X] (from $CA59/$CA5F: CP $02, CP $7E)
 *   - Sets direction (0=right, 4=left) and axis flag to horizontal (SET 0)
 *   - Returns {newX, newY, dir} or null if no input
 */
export function tryHorizontal(input: number, px: number, py: number): MoveTarget | null {
  const h = input & 0x18; // bits 3,4
  if (h === 0 || h === 0x18) return null; // No input or both pressed -> ignore

  let newX = px;
  let dir: CardinalDirection = 0;

  if (input & 0x10) { // Left pressed (bit 4)
    newX = px - 1;
    dir = 4; // Left direction
  }
  if (input & 0x08) { // Right pressed (bit 3)
    newX = px + 1;
    dir = 0; // Right direction
  }

  // Clamp X to field bounds. From $CA59: CP $02 / $CA5F: CP $7E.
  if (newX < FIELD_MIN_X) newX = FIELD_MIN_X;
  if (newX > FIELD_MAX_X) newX = FIELD_MAX_X;

  // If position didn't actually change, report no movement
  if (newX === px) return null;

  return { x: newX, y: py, dir };
}

/**
 * Try vertical movement. Matches $CA6F–$CA9A.
 *
 * Reads bits 1 (down) and 2 (up) from input. Same pattern as horizontal.
 *   - Computes new Y = current Y +/- 1
 *   - Clamps to [FIELD_MIN_Y, FIELD_MAX_Y] (from $CA85/$CA8B: CP $12, CP $5E)
 *   - Sets direction (2=down, 6=up) and axis flag to vertical (RES 0)
 */
export function tryVertical(input: number, px: number, py: number): MoveTarget | null {
  const v = input & 0x06; // bits 1,2
  if (v === 0 || v === 0x06) return null;

  let newY = py;
  let dir: CardinalDirection = 0;

  if (input & 0x04) { // Up pressed (bit 2)
    newY = py - 1;
    dir = 6; // Up direction
  }
  if (input & 0x02) { // Down pressed (bit 1)
    newY = py + 1;
    dir = 2; // Down direction
  }

  if (newY < FIELD_MIN_Y) newY = FIELD_MIN_Y;
  if (newY > FIELD_MAX_Y) newY = FIELD_MAX_Y;

  if (newY === py) return null;

  return { x: px, y: newY, dir };
}

interface AttemptMoveResult {
  moved: boolean;
  startDraw: boolean;
  endDraw: boolean;
}

/**
 * Attempt to move the player to a target cell.
 * Returns {moved, startDraw, endDraw}.
 *
 * When NOT drawing: player can only move onto border cells (value 3).
 * When drawing: player moves through empty cells (value 0) leaving trail.
 *   If the target is border (3), drawing ends and fill is triggered.
 */
export function attemptMove(target: MoveTarget | null, _isFirst: boolean): AttemptMoveResult {
  const result: AttemptMoveResult = { moved: false, startDraw: false, endDraw: false };
  if (!target) return result;

  const cellVal = getCell(target.x, target.y);

  if (!state.player.drawing) {
    // --- NOT DRAWING MODE ---
    // From $C7D2–$C7E7 / $C800–$C821:
    // If target cell is border (3) -> move there (walk along border)
    if (cellVal === CELL_BORDER) {
      state.player.x = target.x;
      state.player.y = target.y;
      state.player.dir = target.dir;
      // Set axis flag: horizontal movement sets bit 0 ($CA68: SET 0)
      state.player.axisH = (target.dir === 0 || target.dir === 4);
      result.moved = true;
      return result;
    }
    // If target cell is empty (0) AND fire is pressed -> start drawing
    // From $C7DD: BIT 0,C (test fire bit)
    if (cellVal === CELL_EMPTY && state.keys.fire) {
      // Set drawing flag. From $C7E7: SET 7,(IX+0).
      state.player.drawing = true;
      // Set fast mode (fire is held). From $C7EF: SET 4,(IX+0).
      state.player.fastMode = true;
      // Set axis flag based on movement direction
      state.player.axisH = (target.dir === 0 || target.dir === 4);
      // Move to the empty cell
      state.player.x = target.x;
      state.player.y = target.y;
      state.player.dir = target.dir;
      // Record first trail point and mark cell as trail
      setCell(target.x, target.y, CELL_TRAIL);
      state.trailBuffer.push({ x: target.x, y: target.y, dir: target.dir });
      state.trailFrameCounter = 1;
      result.moved = true;
      result.startDraw = true;
      return result;
    }
    // Otherwise: can't move in this direction (cell is trail, claimed, or empty without fire)
    return result;
  } else {
    // --- DRAWING MODE ---
    // From $C89D–$C8FA:
    // Target empty (0) -> move there, leave trail
    if (cellVal === CELL_EMPTY) {
      state.player.x = target.x;
      state.player.y = target.y;
      state.player.dir = target.dir;
      state.player.axisH = (target.dir === 0 || target.dir === 4);
      // Record trail and mark cell
      setCell(target.x, target.y, CELL_TRAIL);
      state.trailBuffer.push({ x: target.x, y: target.y, dir: target.dir });
      result.moved = true;
      return result;
    }
    // Target border (3) -> end drawing, trigger fill
    // From $C8B5: RES 7,(IX+0) / SET 6,(IX+0)
    if (cellVal === CELL_BORDER) {
      state.player.x = target.x;
      state.player.y = target.y;
      state.player.dir = target.dir;
      state.player.drawing = false;
      state.player.fillComplete = true;
      result.moved = true;
      result.endDraw = true;
      return result;
    }
    // Target is trail (2) or claimed (1) -> can't move there while drawing
    return result;
  }
}

/**
 * Main player movement routine. Matches $C7B5–$C8F9.
 *
 * The original has a complex priority system for direction:
 *   - When NOT drawing:
 *     - If last move was horizontal (axis=1): try VERTICAL first, then horizontal
 *     - If last move was vertical (axis=0): try HORIZONTAL first, then vertical
 *     This creates the natural border-following behavior where the player
 *     "prefers" to change direction, making corner navigation smooth.
 *   - When drawing:
 *     - Same priority system applies
 *     - Fire button controls speed: fire held = half speed (every other frame),
 *       fire released = full speed (every frame)
 *     - From $C889–$C89B: BIT 0,C / BIT 4,(IX+0) / RRA / JR C
 */
export function movePlayer(): void {
  const input = getInputBits();

  if (state.player.drawing) {
    // --- Speed control during drawing ---
    // $C889: If fire not pressed, clear fast mode
    if (!(input & 0x01)) {
      state.player.fastMode = false;
    }
    // $C891–$C89B: If fast mode active, skip movement on odd frames
    // (fire held = SLOWER, move every other frame for precise control)
    if (state.player.fastMode) {
      if (state.frameCounter & 1) {
        // Still increment trail frame counter even when not moving
        // From $C8EE: INC ($B0E8)
        state.trailFrameCounter++;
        checkTrailCursorActivation();
        return;
      }
    }
  }

  // Try movement in priority order based on axis.
  // From $C7C7: BIT 0,(IX+0) -- if axis=1 (horizontal), JR NZ to try vertical first.
  const hMove = tryHorizontal(input, state.player.x, state.player.y);
  const vMove = tryVertical(input, state.player.x, state.player.y);

  let firstMove: MoveTarget | null;
  let secondMove: MoveTarget | null;

  if (state.player.drawing) {
    // DRAWING MODE: prefer current axis to prevent diagonal trails.
    // Fall through to perpendicular only if current axis is blocked (e.g., hit border).
    if (state.player.axisH) {
      firstMove = hMove;
      secondMove = vMove;
    } else {
      firstMove = vMove;
      secondMove = hMove;
    }
  } else {
    // BORDER MODE: prefer perpendicular for smooth turn anticipation.
    // This lets the player "anticipate" turns: hold up/down before reaching
    // a corner, and the player turns as soon as the perpendicular path opens.
    // No diagonal risk because only one direction leads to a border cell.
    if (state.player.axisH) {
      firstMove = vMove;
      secondMove = hMove;
    } else {
      firstMove = hMove;
      secondMove = vMove;
    }
  }

  let result = attemptMove(firstMove, true);
  if (!result.moved) {
    result = attemptMove(secondMove, false);
  }

  // If drawing, increment trail frame counter regardless of movement
  // From $C8EE/$C915: INC ($B0E8)
  if (state.player.drawing) {
    state.trailFrameCounter++;
    checkTrailCursorActivation();
  }
}

/**
 * Check if the trail cursor should be activated.
 * From $C8F3/$C91A: CP $48 -- if trail frame counter reaches 72, activate cursor.
 * The cursor then chases the player along the trail buffer from behind.
 */
export function checkTrailCursorActivation(): void {
  if (state.trailFrameCounter >= TRAIL_CURSOR_THRESHOLD && !state.trailCursor.active && state.trailBuffer.length > 0) {
    // From $CA9B: Set cursor to first trail buffer entry
    state.trailCursor.active = true;
    state.trailCursor.bufferIndex = 0;
    state.trailCursor.x = state.trailBuffer[0].x;
    state.trailCursor.y = state.trailBuffer[0].y;
  }
}
