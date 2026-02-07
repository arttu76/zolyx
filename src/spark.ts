/**
 * Spark movement and death logic.
 *
 * Original Z80 routines:
 *   $D18A–$D279  moveSpark — diagonal movement with bounce off borders
 *   $D267        killSpark — deactivate spark, award 50 points
 *
 * Sparks move diagonally (directions 1, 3, 5, 7 only) and interact with cells:
 *   - Empty: move freely
 *   - Border: bounce (CW 90, CCW 90, 180, or stay)
 *   - Claimed: spark dies (+50 points)
 *   - Trail: spark moves through (trail collision detected separately)
 */

import { state } from './state';
import {
  CELL_EMPTY, CELL_CLAIMED, CELL_TRAIL, CELL_BORDER,
  DIR_DX, DIR_DY, SPARK_KILL_POINTS,
} from './constants';
import { getCell } from './grid';
import type { Spark, DiagonalDirection } from './types';

/**
 * Move a single spark. Matches the spark movement routine at $D18A–$D279.
 *
 * Sparks move diagonally (directions 1, 3, 5, 7 only) and interact with cells:
 *   1. Check current position -- if not empty, spark dies (+50 points)
 *      From $D19B–$D1A4: read cell at current pos, if non-zero -> $D267 (die)
 *   2. Compute target position using direction table
 *   3. If target is empty -> move there
 *   4. If target is border (3) -> bounce:
 *      a) Try CW 90 rotation (dir + 2). From $D1D9–$D207.
 *      b) Try CCW 90 rotation (dir - 2). From $D208–$D236.
 *      c) Try 180 reversal (dir + 4). From $D237–$D266.
 *      d) If all blocked -> stay put (no movement this frame)
 *   5. If target is claimed (1) or trail (2) -> spark dies, +50 points
 *      From $D1CF–$D1D1: CP $03 / JP NZ,$D267
 */
export function moveSpark(spark: Spark): void {
  if (!spark.active) return;

  // Step 1: Check if current cell is still empty
  // The cell might have been claimed since the spark was placed here.
  // If it's now TRAIL, checkTrailCollisions (which ran before this) already set
  // the collision flag -- the player dies. We still kill the spark for cleanup.
  // If it's CLAIMED, the area was filled -- spark dies, +50 points.
  const currentCell = getCell(spark.x, spark.y);
  if (currentCell === CELL_CLAIMED) {
    killSpark(spark);
    return;
  }
  if (currentCell === CELL_TRAIL) {
    // Trail collision already detected by checkTrailCollisions -> player dies.
    // Kill the spark as cleanup (level will reset anyway).
    state.collision = true;
    killSpark(spark);
    return;
  }

  // Step 2: Compute target position
  const targetX = spark.x + DIR_DX[spark.dir];
  const targetY = spark.y + DIR_DY[spark.dir];
  const targetCell = getCell(targetX, targetY);

  // Step 3: Move if empty or trail.
  // In the original, sparks check the SHADOW grid ($6000) for movement, where
  // trail cells still read as empty (trail only exists in the bitmap at $4000).
  // So sparks move freely into trail cells. The trail collision check next frame
  // ($C467) detects the spark on trail and sets the collision flag.
  if (targetCell === CELL_EMPTY || targetCell === CELL_TRAIL) {
    spark.x = targetX;
    spark.y = targetY;
    return;
  }

  // Step 4: If border, try bouncing.
  // Only real borders (shadow grid = $FF) cause bouncing in the original.
  if (targetCell === CELL_BORDER) {
    // Try CW 90 (dir + 2)
    const dir1 = ((spark.dir + 2) & 7) as DiagonalDirection;
    const t1x = spark.x + DIR_DX[dir1];
    const t1y = spark.y + DIR_DY[dir1];
    if (getCell(t1x, t1y) === CELL_EMPTY) {
      spark.dir = dir1;
      spark.x = t1x;
      spark.y = t1y;
      return;
    }

    // Try CCW 90 (dir - 2)
    const dir2 = ((spark.dir + 6) & 7) as DiagonalDirection; // +6 = -2 mod 8
    const t2x = spark.x + DIR_DX[dir2];
    const t2y = spark.y + DIR_DY[dir2];
    if (getCell(t2x, t2y) === CELL_EMPTY) {
      spark.dir = dir2;
      spark.x = t2x;
      spark.y = t2y;
      return;
    }

    // Try 180 (dir + 4)
    const dir3 = ((spark.dir + 4) & 7) as DiagonalDirection;
    const t3x = spark.x + DIR_DX[dir3];
    const t3y = spark.y + DIR_DY[dir3];
    if (getCell(t3x, t3y) === CELL_EMPTY) {
      spark.dir = dir3;
      spark.x = t3x;
      spark.y = t3y;
      return;
    }

    // All directions blocked -- stay put
    return;
  }

  // Step 5: Hit claimed area -> spark dies (+50 points).
  // Trail is handled in step 3 (move through). Only claimed cells kill the spark.
  killSpark(spark);
}

/**
 * Kill a spark: deactivate it and award points.
 * From $D267: LD (IX+0),$00 / LD DE,$0032 / ADD HL,DE.
 */
export function killSpark(spark: Spark): void {
  spark.active = false;
  spark.x = 0;
  spark.y = 0;
  state.score += SPARK_KILL_POINTS;
}
