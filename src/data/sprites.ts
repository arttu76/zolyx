// ============================================================================
// SPRITE DATA — Extracted from $F000-$F2FF in the original SNA
// ============================================================================

/**
 * Entity sprite data from $F000-$F2FF (alignment 0).
 * Format: 8 mask bytes + 8 data bytes per sprite.
 * mask bit 0 = sprite covers this pixel (clear background first).
 * data bit 1 = draw INK pixel.
 */

/** Shared sprite mask (all sprites use the same mask). */
export const SPRITE_MASK = [0xff, 0xc3, 0x81, 0x81, 0x81, 0x81, 0xc3, 0xff];

/** Player sprite pixel data. */
export const SPRITE_PLAYER_DATA = [0x00, 0x3c, 0x42, 0x42, 0x42, 0x42, 0x3c, 0x00];

/** Chaser sprite pixel data. */
export const SPRITE_CHASER_DATA = [0x00, 0x3c, 0x72, 0x7a, 0x7e, 0x7e, 0x3c, 0x00];

/** Trail cursor sprite pixel data. */
export const SPRITE_CURSOR_DATA = [0x00, 0x3c, 0x6a, 0x56, 0x6a, 0x56, 0x3c, 0x00];
