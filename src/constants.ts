// ============================================================================
// CONSTANTS — Matching original Z80 game values exactly
// ============================================================================

// --- Field coordinates ---

/** Minimum X coordinate of the border frame (left wall). From $CE62: LD DE,$1202 -> E=2. */
export const FIELD_MIN_X = 2;
/** Maximum X coordinate of the border frame (right wall). From border draw loop exit at CP $7D. */
export const FIELD_MAX_X = 125;
/** Minimum Y coordinate of the border frame (top wall). From $CE62: D=$12=18. */
export const FIELD_MIN_Y = 18;
/** Maximum Y coordinate of the border frame (bottom wall). From right border loop exit at CP $5D. */
export const FIELD_MAX_Y = 93;

/** First interior X (border+1). Clamped in $CA59: CP $02. */
export const INTERIOR_MIN_X = 3;
/** Last interior X (border-1). */
export const INTERIOR_MAX_X = 124;
/** First interior Y. Clamped in $CA85: CP $12. */
export const INTERIOR_MIN_Y = 19;
/** Last interior Y. */
export const INTERIOR_MAX_Y = 92;

// --- Cell values ---

/** Cell value: empty/unclaimed space. Pattern: $00,$00. */
export const CELL_EMPTY = 0;
/** Cell value: claimed/filled area. Pattern: $55,$00. Counts toward win percentage. */
export const CELL_CLAIMED = 1;
/** Cell value: player's active drawing trail. Pattern: $AA,$55. */
export const CELL_TRAIL = 2;
/** Cell value: border wall (original frame + converted trail segments). Pattern: $FF,$FF. */
export const CELL_BORDER = 3;

// --- Direction tables ---

/**
 * Direction delta-X table. From $B0D1 in original:
 * $B0D1: 01 00 01 01 00 01 FF 01 FF 00 FF FF 00 FF 01 FF
 * (pairs of dx,dy for directions 0-7)
 */
export const DIR_DX = [1, 1, 0, -1, -1, -1, 0, 1] as const;
/**
 * Direction delta-Y table. From $B0D1 (second byte of each pair).
 * Note: Y increases downward (screen coordinates).
 */
export const DIR_DY = [0, 1, 1, 1, 0, -1, -1, -1] as const;

// --- Game parameters ---

/**
 * Number of original border cells around the field perimeter.
 * Top: 124 + Bottom: 124 + Left: 74 + Right: 74 = 396.
 * Used in percentage calculation: percentage = (non_empty - 396) / 90.
 * From $C792: LD DE,$018C (= 396).
 */
export const BORDER_CELL_COUNT = 396;

/**
 * Divisor for percentage calculation. From $C785/$C79A: LD DE,$005A (= 90).
 * Interior area = 9028 cells. 9028 / 90 ~ 100.3, so dividing by 90 gives ~percentage.
 */
export const PERCENTAGE_DIVISOR = 90;

/** Win threshold: percentage must be >= 75. From $C7A5: CP $4B (= 75). */
export const WIN_PERCENTAGE = 75;

/** Initial lives count. From $CC4D: LD A,$03. */
export const INITIAL_LIVES = 3;

/** Initial timer value per level. From $CC5C: LD A,$B0 (= 176). */
export const INITIAL_TIMER = 176;

/**
 * Timer speed: frames between timer decrements. From $B0EA = $0E (= 14).
 * Timer decrements every 14 frames. Total time = 176 x 14 = 2464 frames ~ 49.3s at 50fps.
 */
export const TIMER_SPEED = 14;

/**
 * Trail frame threshold for activating the trail cursor.
 * From $C8F3/$C91A: CP $48 (= 72).
 * When the player has been drawing for 72 frames, the trail cursor activates
 * and begins chasing along the trail buffer, erasing trail from behind.
 */
export const TRAIL_CURSOR_THRESHOLD = 72;

/**
 * Points awarded when a spark dies (hits claimed/trail area).
 * From $D272: LD DE,$0032 (= 50).
 */
export const SPARK_KILL_POINTS = 50;

/**
 * Collision detection distance threshold.
 * From $CAB7/$CAC2/$CAD2 etc.: CP $02.
 * Collision occurs when |dx| < 2 AND |dy| < 2 between player and enemy.
 */
export const COLLISION_DISTANCE = 2;

// --- Spark configuration ---

/**
 * Spark base position table (8 sparks x {baseX, baseY}).
 * From raw bytes at $CD72-$CD81 in the SNA:
 *   $CD72: 1D 21 3D 21 5D 21 1D 35 5D 35 1D 49 3D 49 5D 49
 * Random offset (0-7 for X, 0-14 for Y) is added during level init.
 */
export const SPARK_BASE_POSITIONS: ReadonlyArray<{ x: number; y: number }> = [
  { x: 0x1D, y: 0x21 }, // Spark 0: (29, 33) — top-left area
  { x: 0x3D, y: 0x21 }, // Spark 1: (61, 33) — top-center
  { x: 0x5D, y: 0x21 }, // Spark 2: (93, 33) — top-right
  { x: 0x1D, y: 0x35 }, // Spark 3: (29, 53) — middle-left
  { x: 0x5D, y: 0x35 }, // Spark 4: (93, 53) — middle-right
  { x: 0x1D, y: 0x49 }, // Spark 5: (29, 73) — bottom-left
  { x: 0x3D, y: 0x49 }, // Spark 6: (61, 73) — bottom-center
  { x: 0x5D, y: 0x49 }, // Spark 7: (93, 73) — bottom-right
];

/**
 * Spark activation bitmasks per level. From bytes at $CD82-$CD91.
 * Each bit enables one spark (bit 7 = spark 0, bit 6 = spark 1, etc.
 * — bits are rotated left via RLC C in the init loop at $CCE1).
 *
 * Level 0: $40 = 01000000 -> spark 1 (1 spark)
 * Level 1: $18 = 00011000 -> sparks 4,5 (2 sparks, but rotated...)
 * ...through to Level 7+: $FF = all 8 sparks
 *
 * Note: In the original code, RLC rotates left so bit 7 goes to carry first.
 * The iteration processes sparks 0-7 with successive RLC operations.
 */
export const SPARK_MASKS: readonly number[] = [
  0x40, 0x18, 0xA2, 0x5A, 0xBA, 0xBD, 0xFD, 0xFF,
  0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
];

// --- Chaser configuration ---

/**
 * Chaser activation bitmasks per level. From bytes at $CD9B-$CDAA.
 * Bit 7 = chaser 1, bit 6 = chaser 2.
 * Levels 0-5: $80 = one chaser only.
 * Levels 6+:  $C0 = both chasers active.
 */
export const CHASER_MASKS: readonly number[] = [
  0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
  0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0
];

/**
 * Level color table — ZX Spectrum attribute bytes from $CDAB-$CDBA.
 * Format: bit 6 = BRIGHT, bits 5-3 = PAPER color, bits 2-0 = INK color.
 * All entries have BRIGHT set and INK = 0 (black).
 *
 * ZX Spectrum bright colors: 0=black, 1=blue, 2=red, 3=magenta,
 *                             4=green, 5=cyan, 6=yellow, 7=white
 */
export const LEVEL_COLORS_ATTR: readonly number[] = [
  0x70, 0x68, 0x58, 0x60, 0x68, 0x78, 0x68, 0x70,
  0x60, 0x58, 0x78, 0x68, 0x70, 0x50, 0x58, 0x68
];

/**
 * Map ZX Spectrum bright PAPER color index to CSS hex color.
 */
export const ZX_BRIGHT_COLORS: readonly string[] = [
  "#000000", // 0: black
  "#0000FF", // 1: blue
  "#FF0000", // 2: red
  "#FF00FF", // 3: magenta
  "#00FF00", // 4: green
  "#00FFFF", // 5: cyan
  "#FFFF00", // 6: yellow
  "#FFFFFF", // 7: white
];

/**
 * Chaser initial positions. From bytes at $CD92-$CD97:
 *   Chaser 1: X=$40(64), Y=$12(18), dir=$00(0=Right)
 *   Chaser 2: X=$40(64), Y=$5D(93), dir=$04(4=Left)
 */
export const CHASER_INIT: ReadonlyArray<{ x: number; y: number; dir: number }> = [
  { x: 64, y: 18, dir: 0 },  // Chaser 1: top border, heading right
  { x: 64, y: 93, dir: 4 },  // Chaser 2: bottom border, heading left
];

// --- Screen dimensions ---

/** ZX Spectrum native screen resolution. */
export const SCREEN_W = 256;
export const SCREEN_H = 192;
/** Attribute grid: 32 columns x 24 rows of 8x8 pixel character cells. */
export const ATTR_COLS = 32;
export const ATTR_ROWS = 24;

// --- Color palettes ---

/**
 * ZX Spectrum BRIGHT color palette [R, G, B].
 * Index 0-7: black, blue, red, magenta, green, cyan, yellow, white.
 */
export const ZX_BRIGHT: readonly (readonly number[])[] = [
  [0, 0, 0], [0, 0, 255], [255, 0, 0], [255, 0, 255],
  [0, 255, 0], [0, 255, 255], [255, 255, 0], [255, 255, 255]
];
/** ZX Spectrum normal (non-bright) color palette. */
export const ZX_NORMAL: readonly (readonly number[])[] = [
  [0, 0, 0], [0, 0, 208], [208, 0, 0], [208, 0, 208],
  [0, 208, 0], [0, 208, 208], [208, 208, 0], [208, 208, 208]
];

// --- Cell patterns ---

/**
 * Cell bitmap patterns: [cellValue] = [row0_byte, row1_byte].
 * Each game cell is 2x2 Spectrum pixels; these bytes define the ink pattern
 * for each row. The pixel value is extracted by bit position (MSB-first).
 * Exact values from the pattern table at $B0C9 in the original.
 */
export const CELL_PATTERNS: readonly (readonly number[])[] = [
  [0x00, 0x00], // CELL_EMPTY:   all paper
  [0x55, 0x00], // CELL_CLAIMED: checkerboard top, blank bottom
  [0xAA, 0x55], // CELL_TRAIL:   inverse checker top, checker bottom
  [0xFF, 0xFF], // CELL_BORDER:  solid ink
];

// --- Timing ---

/** Target frame rate matching ZX Spectrum's 50Hz display refresh. */
export const TARGET_FPS = 50;
/** Frame duration in milliseconds. */
export const FRAME_TIME = 1000 / TARGET_FPS;
