/**
 * Input handling — keyboard event listeners and input bit conversion.
 *
 * Original Z80 routine:
 *   $BA68  Keyboard reading routine — produces 5-bit input bitmask
 *
 * Input bitmask format:
 *   bit 0 = Fire (Space)
 *   bit 1 = Down
 *   bit 2 = Up
 *   bit 3 = Right
 *   bit 4 = Left
 */

import { state } from './state';
import { initGame } from './init';

/**
 * Convert current key state to the original game's input bitmask format.
 * From the keyboard reading routine at $BA68:
 *   bit 0 = Fire (Space)
 *   bit 1 = Down
 *   bit 2 = Up
 *   bit 3 = Right
 *   bit 4 = Left
 */
export function getInputBits(): number {
  let c = 0;
  if (state.keys.fire)  c |= 0x01;
  if (state.keys.down)  c |= 0x02;
  if (state.keys.up)    c |= 0x04;
  if (state.keys.right) c |= 0x08;
  if (state.keys.left)  c |= 0x10;
  return c;
}

/**
 * Set up keydown/keyup event listeners on `document`.
 * Updates `state.keys` for arrow keys and space (fire).
 *
 * The keydown handler also handles:
 *   - Enter: restart game (after game over)
 *   - P: toggle pause
 */
export function setupInput(): void {
  document.addEventListener("keydown", (e: KeyboardEvent) => {
    switch (e.key) {
      case "ArrowUp":    state.keys.up = true; e.preventDefault(); break;
      case "ArrowDown":  state.keys.down = true; e.preventDefault(); break;
      case "ArrowLeft":  state.keys.left = true; e.preventDefault(); break;
      case "ArrowRight": state.keys.right = true; e.preventDefault(); break;
      case " ":          state.keys.fire = true; e.preventDefault(); break;
      case "p": case "P": state.paused = !state.paused; break;
      case "Enter":
        if (state.gameOver) { initGame(); }
        break;
    }
  });

  document.addEventListener("keyup", (e: KeyboardEvent) => {
    switch (e.key) {
      case "ArrowUp":    state.keys.up = false; break;
      case "ArrowDown":  state.keys.down = false; break;
      case "ArrowLeft":  state.keys.left = false; break;
      case "ArrowRight": state.keys.right = false; break;
      case " ":          state.keys.fire = false; break;
    }
  });
}
