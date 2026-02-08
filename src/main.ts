/**
 * Main entry point -- initializes the ZX Spectrum screen simulation,
 * sets up input, and starts the game loop.
 *
 * Targets 50fps to match the original ZX Spectrum's PAL refresh rate
 * (the game uses HALT at $C3E4 to sync to the 50Hz interrupt).
 */

import { initScreen } from './screen';
import { setupInput } from './input';
import { gameFrame } from './game-loop';
import { render } from './rendering/scene';
import { initGame } from './init';
import { TARGET_FPS } from './constants';

const FRAME_TIME: number = 1000 / TARGET_FPS;
let lastFrameTime: number = 0;
let accumulator: number = 0;

function mainLoop(timestamp: number): void {
  const delta = timestamp - lastFrameTime;
  lastFrameTime = timestamp;
  accumulator += delta;

  // Process game frames at fixed 50fps rate
  while (accumulator >= FRAME_TIME) {
    gameFrame();
    accumulator -= FRAME_TIME;
  }

  render();
  requestAnimationFrame(mainLoop);
}

// --- Initialization ---

// 1. Initialize the ZX Spectrum screen buffers and canvas
initScreen();

// 2. Set up keyboard input handlers
setupInput();

// 3. Start the game immediately (no title screen)
initGame();

// 4. Start the game loop
requestAnimationFrame((ts: number) => {
  lastFrameTime = ts;
  mainLoop(ts);
});
