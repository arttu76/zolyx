/**
 * Touch input handling for mobile devices.
 *
 * Sets the same state.keys booleans as keyboard input — no game logic changes needed.
 * Uses Touch.identifier tracking for proper multi-touch (e.g. fire + direction simultaneously).
 */

import { state } from './state';
import { initGame } from './init';

type DirKey = 'up' | 'down' | 'left' | 'right';

/** Maps active touch identifiers to the button/direction they're controlling. */
const activeTouches = new Map<number, string>();

/** Re-scale canvas after touch controls become visible. */
function rescale(): void {
  const fn = (window as any).scaleCanvas;
  if (fn) fn();
}

function bindDpad(btn: HTMLElement, dir: DirKey): void {
  btn.addEventListener('touchstart', (e: TouchEvent) => {
    e.preventDefault();
    for (let i = 0; i < e.changedTouches.length; i++) {
      activeTouches.set(e.changedTouches[i].identifier, dir);
    }
    state.keys[dir] = true;
    btn.classList.add('active');
  }, { passive: false });

  const release = (e: TouchEvent) => {
    e.preventDefault();
    for (let i = 0; i < e.changedTouches.length; i++) {
      activeTouches.delete(e.changedTouches[i].identifier);
    }
    // Only release if no other touch is holding this direction
    let stillHeld = false;
    for (const v of activeTouches.values()) {
      if (v === dir) { stillHeld = true; break; }
    }
    if (!stillHeld) {
      state.keys[dir] = false;
      btn.classList.remove('active');
    }
  };
  btn.addEventListener('touchend', release, { passive: false });
  btn.addEventListener('touchcancel', release, { passive: false });
}

function bindFire(btn: HTMLElement): void {
  btn.addEventListener('touchstart', (e: TouchEvent) => {
    e.preventDefault();
    for (let i = 0; i < e.changedTouches.length; i++) {
      activeTouches.set(e.changedTouches[i].identifier, 'fire');
    }
    state.keys.fire = true;
    btn.classList.add('active');
  }, { passive: false });

  const release = (e: TouchEvent) => {
    e.preventDefault();
    for (let i = 0; i < e.changedTouches.length; i++) {
      activeTouches.delete(e.changedTouches[i].identifier);
    }
    let stillHeld = false;
    for (const v of activeTouches.values()) {
      if (v === 'fire') { stillHeld = true; break; }
    }
    if (!stillHeld) {
      state.keys.fire = false;
      btn.classList.remove('active');
    }
  };
  btn.addEventListener('touchend', release, { passive: false });
  btn.addEventListener('touchcancel', release, { passive: false });
}

export function setupTouch(): void {
  // Detect touch on first interaction and show controls
  let revealed = false;
  const revealOnTouch = () => {
    if (revealed) return;
    revealed = true;
    document.body.classList.add('has-touch');
    // Re-scale after controls become visible
    requestAnimationFrame(rescale);
  };
  window.addEventListener('touchstart', revealOnTouch, { once: true });

  // D-pad buttons
  const dpadBtns = document.querySelectorAll<HTMLElement>('.dpad-btn[data-dir]');
  dpadBtns.forEach(btn => {
    const dir = btn.dataset.dir as DirKey;
    bindDpad(btn, dir);
  });

  // Fire button
  const fireBtn = document.getElementById('btn-fire');
  if (fireBtn) bindFire(fireBtn);

  // Pause button — toggle like P key
  const pauseBtn = document.getElementById('btn-pause');
  if (pauseBtn) {
    pauseBtn.addEventListener('touchstart', (e: TouchEvent) => {
      e.preventDefault();
      state.paused = !state.paused;
    }, { passive: false });
  }

  // Restart button — same as Enter key during game over
  const restartBtn = document.getElementById('btn-restart');
  if (restartBtn) {
    restartBtn.addEventListener('touchstart', (e: TouchEvent) => {
      e.preventDefault();
      if (state.gameOver) initGame();
    }, { passive: false });
  }
}
