/**
 * Main entry point -- initializes the ZX Spectrum screen simulation,
 * decodes the loading screen, sets up input, and starts the game loop.
 *
 * Targets 50fps to match the original ZX Spectrum's PAL refresh rate
 * (the game uses HALT at $C3E4 to sync to the 50Hz interrupt).
 */

import { initScreen } from './screen';
import { LOADING_SCR_B64 } from './data/loading-screen';
import { state } from './state';
import { setupInput } from './input';
import { gameFrame } from './game-loop';
import { render } from './rendering/scene';
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

// 2. Decode loading screen from base64
{
  const bin = atob(LOADING_SCR_B64);
  state.loadingScrData = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) state.loadingScrData[i] = bin.charCodeAt(i);
}

// 3. Set up keyboard input handlers
setupInput();

// 4. Start the game loop
requestAnimationFrame((ts: number) => {
  lastFrameTime = ts;
  mainLoop(ts);
});
