/**
 * Collision detection between the player and enemies.
 *
 * Original Z80 routines:
 *   $CAA9–$CAFF  checkCollisions — proximity check (|dx| < 2 AND |dy| < 2)
 *   $C467–$C48E  checkTrailCollisions — spark/chaser on trail cell detection
 */

import { state } from './state';
import { COLLISION_DISTANCE, CELL_TRAIL } from './constants';
import { getCell } from './grid';

/**
 * Check for collisions between the player and all enemies.
 * Matches the collision detection routine at $CAA9–$CAFF.
 *
 * The original checks Manhattan-like proximity:
 *   |player.Y - enemy.Y| < 2 AND |player.X - enemy.X| < 2
 * This means entities must be within 1 cell in both X and Y simultaneously.
 * (CP $02 at $CAB7/$CAC2/$CAD2/$CADD/$CAED/$CAF8)
 *
 * Checks against: chaser 1 ($B028), chaser 2 ($B04D), trail cursor ($B072).
 * Returns true if any collision is detected (carry flag set in original).
 */
export function checkCollisions(): boolean {
  const px = state.player.x;
  const py = state.player.y;

  // Check each chaser
  for (const ch of state.chasers) {
    if (!ch.active) continue;
    if (Math.abs(py - ch.y) < COLLISION_DISTANCE &&
        Math.abs(px - ch.x) < COLLISION_DISTANCE) {
      return true;
    }
  }

  // Check trail cursor
  if (state.trailCursor.active) {
    if (Math.abs(py - state.trailCursor.y) < COLLISION_DISTANCE &&
        Math.abs(px - state.trailCursor.x) < COLLISION_DISTANCE) {
      return true;
    }
  }

  return false;
}

/**
 * Check if any enemy spark/chaser touches the player's active trail.
 * From the main loop at $C467–$C48E:
 *   For each spark, read the cell at its position. If it's on a border cell
 *   that overlaps with trail (checking shadow copy), set collision flag.
 *
 * In our implementation: if any chaser or spark is on a TRAIL cell, collision.
 */
export function checkTrailCollisions(): boolean {
  // Check sparks on trail
  for (const spark of state.sparks) {
    if (!spark.active) continue;
    if (getCell(spark.x, spark.y) === CELL_TRAIL) {
      return true;
    }
  }
  // Check chasers on trail
  for (const ch of state.chasers) {
    if (!ch.active) continue;
    if (getCell(ch.x, ch.y) === CELL_TRAIL) {
      return true;
    }
  }
  return false;
}
