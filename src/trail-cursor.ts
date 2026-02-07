/**
 * Trail cursor movement — chases the player along the trail buffer.
 *
 * Original Z80 routine:
 *   $CBFE–$CC31  moveTrailCursor
 *
 * The trail cursor activates when trailFrameCounter reaches 72 ($48).
 * It advances 2 entries per frame along the trail buffer.
 * If it catches the player (runs out of buffer), collision is triggered.
 */

import { state } from './state';

/**
 * Move the trail cursor. Matches $CBFE–$CC31.
 *
 * The trail cursor chases the player along the trail buffer:
 *   1. If not active, return immediately. From $CC02: RET Z.
 *   2. Advance buffer index by 2 entries per frame (the original skips
 *      6 bytes = 2 entries of 3 bytes each). From $CC0E–$CC10: INC HL x3 twice.
 *   3. If the buffer runs out (next entry is zero/end), the cursor has caught
 *      the player -> set collision flag. From $CC1C: SET 0,($B0C8).
 *   4. Otherwise, update cursor position to the new buffer entry.
 *      From $CC22–$CC2E: LD (IX+0),A / LD (IX+1),A / update pointer.
 *
 * The cursor erasing trail cells behind it is handled by the draw routine
 * (the cursor's old position is restored to border or empty).
 */
export function moveTrailCursor(): void {
  if (!state.trailCursor.active) return;

  // Advance by 2 entries in the trail buffer
  // (original reads 2 entries ahead: +3 and +6 bytes)
  const newIndex = state.trailCursor.bufferIndex + 2;

  if (newIndex >= state.trailBuffer.length) {
    // Cursor has caught up to the player -> collision!
    state.collision = true;
    return;
  }

  // The trail cursor advances along the trail WITHOUT erasing it.
  // It simply chases toward the player; if it catches up -> collision.

  // Update cursor position
  state.trailCursor.bufferIndex = newIndex;
  const entry = state.trailBuffer[newIndex];
  state.trailCursor.x = entry.x;
  state.trailCursor.y = entry.y;
}
