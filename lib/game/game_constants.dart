import 'package:flame/components.dart';

/// All gameplay constants live in one place so balancing feels predictable.
///
/// Coordinates are in Forge2D meters. Y grows downwards (standard Box2D), so
/// "up the tower" means decreasing Y.
class GameConstants {
  /// Logical render resolution kept by the camera. The actual pixel size of
  /// the device is scaled to fit this rectangle, preserving aspect ratio.
  static const worldWidth = 9.0;
  static const worldHeight = 16.0;

  /// Centre of the camera at game start. Shifted slightly downward so the
  /// painted city horizon sits near the lower third of the viewport while the
  /// hook fills the upper portion.
  static Vector2 get initialCameraTarget => Vector2(0, 1.0);

  /// Y of the top of the ground rectangle. Anything below this is "out of
  /// bounds" and counts as a fail.
  static const groundTopY = 7.5;

  /// First "platform" the player stacks on — the painted starter shop.
  static const startBuildingTopY = 5.1;
  static const startBuildingWidth = 3.0;
  static const startBuildingHeight = 2.7;

  /// Block dimensions. The sprite is rendered at exactly these dimensions so
  /// stacked blocks line up edge-to-edge with no overhang/overlap. Aspect
  /// (~1.2) is intentionally close to the natural aspect of the source PNGs
  /// (0.85-1.18) to minimise visible squashing.
  static const blockWidth = 3.6;
  static const blockHeight = 3.0;

  // --- Hook (horizontal slide, no pendulum) ---------------------------------

  /// Horizontal amplitude of the hook's left/right slide (in meters from the
  /// world centre). With worldWidth=9 and blockWidth=3.6, an amplitude of 2.5
  /// keeps the block fully on-screen at both extremes.
  static const hookAmplitude = 2.5;

  /// Vertical gap between the bottom of the swinging block and the current
  /// top of the tower.
  static const hookBlockOffsetAboveTop = 1.0;

  /// Vertical length of the inverted-V chains that connect the hook bottom to
  /// the top corners of the block.
  static const hookChainHeight = 1.3;

  /// Visible hook sprite height (its width is computed from the source aspect).
  static const hookSpriteHeight = 2.6;

  /// Initial half-period of the slide (seconds for one-way traversal). Higher
  /// = slower / smoother.
  static const hookInitialHalfPeriod = 1.7;

  /// Floor of the speed-up ramp. The hook never gets faster than this.
  static const hookMinHalfPeriod = 0.55;

  /// How much the period shrinks per successfully placed block.
  static const hookSpeedUpPerBlock = 0.05;

  // --- Physics ---------------------------------------------------------------

  /// Acceleration of gravity used by the Forge2D world.
  static const gravity = 26.0;

  /// Active block is "settled" when its linear speed has stayed below this
  /// threshold for [settleHoldSeconds].
  static const settleSpeedThreshold = 0.25;
  static const settleHoldSeconds = 0.45;

  /// Hard timeout: even if the block is still wobbling we declare the round
  /// over after this many seconds (prevents infinite stalls).
  static const settleTimeoutSeconds = 4.0;

  /// Minimum X-overlap (in meters) between the new block and the previous
  /// tower top required to keep playing. Less overlap == failed placement.
  static const minOverlapToCount = 1.2;

  /// Camera follows the tower top. The top stays this many meters below the
  /// camera centre — leaves room for the hook above.
  static const cameraOffsetBelowCenter = 2.5;

  /// Time spent smoothly panning the camera to a new target.
  static const cameraLerp = 4.0;

  static const baseRewardPerBlock = 1;
}
