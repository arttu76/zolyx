/**
 * Main game loop — per-frame update, death handling, level completion.
 *
 * Original Z80 routines:
 *   $C64F–$C671  handleDeath — lose life, restart level or game over
 *   $C55D–$C5B6  handleLevelComplete — bonus score, advance level
 *   $C3DC–$C55A  gameFrame — one frame of the main game loop
 *
 * Main loop order (from $C3DC):
 *   INC frame counter -> HALT -> erase entities -> draw sparks ->
 *   draw trail -> move player -> check fill -> check trail collisions ->
 *   draw entities -> check collisions -> move chasers -> move sparks ->
 *   move trail cursor -> decrement timer -> update score -> check flags
 */

import { state } from './state';
import {
  FIELD_MIN_X, FIELD_MIN_Y,
  CELL_EMPTY, CELL_TRAIL,
  TIMER_SPEED,
} from './constants';
import { getCell, setCell } from './grid';
import { movePlayer } from './player';
import { performFill } from './fill';
import { checkTrailCollisions, checkCollisions } from './collision';
import { moveChaser } from './chaser';
import { moveSpark } from './spark';
import { moveTrailCursor } from './trail-cursor';
import { updatePercentage } from './scoring';
import { initLevel, initChasers, initSparks } from './init';

/**
 * Handle player death: lose a life and restart the level.
 * From $C64F–$C671:
 *   1. Animate death (flash/sound effects)
 *   2. Move chasers while death animation plays
 *   3. Decrement lives ($B0C2)
 *   4. If lives > 0 -> restart level at $C377 (re-init entities but keep score/level)
 *   5. If lives == 0 -> game over sequence at $C674
 */
export function handleDeath(): void {
  // Clear any active trail from the grid
  for (const pt of state.trailBuffer) {
    if (getCell(pt.x, pt.y) === CELL_TRAIL) {
      setCell(pt.x, pt.y, CELL_EMPTY);
    }
  }
  state.trailBuffer = [];
  state.trailFrameCounter = 0;
  state.trailCursor = { x: 0, y: 0, active: false, bufferIndex: 0 };
  state.player.drawing = false;
  state.player.fillComplete = false;

  state.lives--;
  if (state.lives <= 0) {
    state.gameOver = true;
    state.gameOverFrame = 0;
    return;
  }

  // Restart level entities (keep grid state, score, level)
  // From $C377: reset trail, player position, re-draw entities
  state.player.x = FIELD_MIN_X;
  state.player.y = FIELD_MIN_Y;
  state.player.dir = 0;
  state.player.axisH = false;

  // Re-initialize chasers and sparks for the current level
  initChasers();
  initSparks();
  state.collision = false;
  state.timerExpired = false;
  state.deathAnimTimer = 30; // Brief pause after death
}

/**
 * Start the level completion sequence. From $C55D–$C5B6:
 *   1. Dim field (clear BRIGHT on all field attributes)
 *   2. Draw "Screen Completed" popup with rainbow cycling (32 frames)
 *   3. Finalize percentage into score: score += (raw% + fill%) * 4
 *   4. Timer-to-score countdown: each tick = +1 point, 2 frames per tick
 *   5. Post-countdown pause (50 frames = 1 second)
 *   6. Restore, increment level, jump to level init
 */
export function handleLevelComplete(): void {
  // Finalize percentage bonus immediately (step 5 in Z80: $C57A CALL $C6F6)
  state.score += (state.rawPercentage + state.percentage) * 4;
  state.rawPercentage = 0;
  state.percentage = 0;

  // Start the animated sequence
  state.lcAnim.active = true;
  state.lcAnim.phase = 0;  // rainbow cycling
  state.lcAnim.frame = 0;
  state.lcAnim.timerCountdown = state.timer;
  state.lcAnim.subFrame = 0;
}

/**
 * Advance the level complete animation by one frame.
 * Called from gameFrame() while lcAnim.active is true.
 *
 * Phase 0: Rainbow cycling (32 frames)
 * Phase 1: Timer-to-score countdown (2 frames per tick)
 * Phase 2: Post-countdown pause (50 frames)
 * Phase 3: Done — advance to next level
 */
export function tickLevelComplete(): void {
  const lc = state.lcAnim;
  lc.frame++;

  switch (lc.phase) {
    case 0: // Rainbow cycling: 16 color steps x 2 frames = 32 frames
      if (lc.frame >= 32) {
        lc.phase = 1;
        lc.frame = 0;
        lc.subFrame = 0;
      }
      break;

    case 1: // Timer-to-score countdown
      if (lc.timerCountdown <= 0) {
        lc.phase = 2;
        lc.frame = 0;
        break;
      }
      lc.subFrame++;
      if (lc.subFrame >= 2) { // 2 frames per tick (40ms at 50fps)
        lc.subFrame = 0;
        lc.timerCountdown--;
        state.timer--;
        state.score++; // +1 point per timer tick
      }
      break;

    case 2: // Post-countdown pause: 50 frames = 1 second
      if (lc.frame >= 50) {
        lc.phase = 3;
      }
      break;

    case 3: // Done — advance to next level
      lc.active = false;
      state.levelComplete = false;
      state.level++;
      initLevel();
      break;
  }
}

/**
 * One frame of the main game loop. Matches $C3DC–$C55A in the original.
 *
 * Original main loop order:
 *   $C3DC: LD IX,$B0E1 -- point IX to player flags
 *   $C3E0: INC ($B0C7) -- increment frame counter
 *   $C3E4: HALT -- wait for vertical blank (we use requestAnimationFrame)
 *   $C3E5–$C3FA: Erase all entities at old positions (D0E5 calls)
 *   $C3FD–$C43A: Draw sparks (CEAE calls with A=0 to erase, then A=3 to draw)
 *   $C43D–$C44A: If drawing, draw trail cell at player position
 *   $C44C: CALL $C7B5 -- process player movement
 *   $C44F–$C464: Store entity background for drawing (D0AC calls)
 *   $C467–$C491: Check spark positions for trail collision
 *   $C492–$C49C: Draw sparks at new positions
 *   $C49E–$C4B3: Draw entities (player, cursor, chasers -- D078 calls)
 *   $C4B6–$C4D0: Play sounds based on game state flags
 *   $C4D3: CALL $CAA9 -- check player-enemy collisions
 *   $C4DD: CALL $CB03 -- move chaser 1
 *   $C4E4: CALL $CB03 -- move chaser 2
 *   $C4EB–$C520: CALL $D18A x8 -- move all 8 sparks
 *   $C523: CALL $CBFE -- move trail cursor
 *   $C52A–$C53D: Decrement timer (with sub-counter at $B0E9)
 *   $C53F: CALL $D27A -- update score display
 *   $C542: CALL $D2C1 -- update timer bar
 *   $C545: CALL $C617 -- check for pause key
 *   $C548–$C55A: Check game state flags:
 *     bit 1 -> timer expired -> game over/out of time
 *     bit 0 -> collision -> lose life
 *     bit 2 -> level complete -> next level
 *     none -> loop back to $C3DC
 */
export function gameFrame(): void {
  if (state.paused) return;
  if (state.gameOver) { state.gameOverFrame++; return; }

  // Level complete animation runs its own frame logic
  if (state.lcAnim.active) {
    tickLevelComplete();
    return;
  }

  if (state.deathAnimTimer > 0) {
    state.deathAnimTimer--;
    return;
  }

  // Increment frame counter. From $C3E0: INC ($B0C7).
  state.frameCounter++;

  // --- PLAYER MOVEMENT ---
  // From $C44C: CALL $C7B5
  movePlayer();

  // --- CHECK FILL ---
  // If the player just completed a trail (reached border while drawing),
  // perform the flood fill. From $C921: BIT 6,(IX+0) / CALL NZ [fill logic].
  if (state.player.fillComplete) {
    state.player.fillComplete = false;
    performFill();
  }

  // --- CHECK TRAIL COLLISIONS ---
  // From $C467–$C48E: check if sparks/chasers are on trail cells
  if (state.player.drawing && checkTrailCollisions()) {
    state.collision = true;
  }

  // --- MOVE CHASERS ---
  // From $C4DD/$C4E4: CALL $CB03 for each chaser
  for (const ch of state.chasers) {
    moveChaser(ch);
  }

  // --- MOVE SPARKS ---
  // From $C4EB–$C520: CALL $D18A for each of 8 sparks
  for (const spark of state.sparks) {
    moveSpark(spark);
  }

  // --- MOVE TRAIL CURSOR ---
  // From $C523: CALL $CBFE
  moveTrailCursor();

  // --- CHECK PLAYER-ENEMY COLLISION ---
  // From $C4D3: CALL $CAA9
  if (checkCollisions()) {
    state.collision = true;
  }

  // --- DECREMENT TIMER ---
  // From $C52A–$C53D:
  //   DEC ($B0E9) -- decrement sub-counter
  //   If zero: reload from ($B0EA), then DEC ($B0C0) -- decrement timer
  //   If timer reaches 0: SET 1,($B0C8) -- timer expired flag
  state.timerSub--;
  if (state.timerSub <= 0) {
    state.timerSub = TIMER_SPEED;
    state.timer--;
    if (state.timer <= 0) {
      state.timer = 0;
      state.timerExpired = true;
    }
  }

  // --- UPDATE PERCENTAGE ---
  // The original recalculates percentage after fills; we also do it each
  // frame for the display (minimal overhead with our simple grid)
  // From $C53F: CALL $D27A (updates score display which depends on percentage)
  updatePercentage();

  // --- CALCULATE DISPLAY SCORE ---
  // From $D27A–$D291: score = base_score + (rawPercentage + percentage) * 4

  // --- CHECK GAME STATE FLAGS ---
  // From $C548–$C55A:
  if (state.timerExpired) {
    // $C550: JP NZ,$C6C9 -- "Out of Time" -> game over sequence
    state.gameOverOutOfTime = true;
    handleDeath();
    state.timerExpired = false;
    return;
  }

  if (state.collision) {
    // $C555: JP NZ,$C64F -- collision -> lose life
    state.gameOverOutOfTime = false;
    handleDeath();
    state.collision = false;
    return;
  }

  if (state.levelComplete) {
    // $C558: JP NZ -> level complete handler at $C55D
    handleLevelComplete();
    return;
  }
}
