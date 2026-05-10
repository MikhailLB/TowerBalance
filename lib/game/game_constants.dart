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
  /// hook + swinging block fill the upper two thirds.
  static Vector2 get initialCameraTarget => Vector2(0, 1.0);

  /// Y of the top of the ground rectangle. Anything below this is "out of
  /// bounds" and counts as a fail.
  static const groundTopY = 7.5;

  /// First "platform" the player stacks on — the painted starter shop. The
  /// physics body (and the rendered sprite) match these dimensions.
  static const startBuildingTopY = 5.1;
  static const startBuildingWidth = 2.6;
  static const startBuildingHeight = 2.4;

  /// Block dimensions. The sprite is rendered at exactly these dimensions so
  /// stacked blocks line up edge-to-edge with no overhang/overlap. Aspect
  /// (~1.15) is intentionally close to the natural aspect of the source PNGs
  /// (0.85-1.18) to minimise visible squashing.
  static const blockWidth = 3.0;
  static const blockHeight = 2.6;

  /// Pendulum geometry — chain pivots above the tower and swings the block in
  /// a real arc (not a flat slide).
  static const hookChainLength = 5.0;

  /// Resting (centred) gap between the bottom of the swinging block and the
  /// current top of the tower.
  static const hookBlockOffsetAboveTop = 1.0;

  /// Maximum swing angle of the pendulum in radians (~25 degrees). Translates
  /// to a horizontal amplitude of `chainLength * sin(maxAngle)` ≈ 2.0 m.
  static const hookMaxAngle = 0.42;

  /// Initial half-period of the swing (seconds for a one-way swing). Higher
  /// = slower / smoother.
  static const hookInitialHalfPeriod = 1.9;

  /// Floor of the speed-up ramp. The hook never gets faster than this.
  static const hookMinHalfPeriod = 0.7;

  /// How much the period shrinks per successfully placed block.
  static const hookSpeedUpPerBlock = 0.05;

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
  static const minOverlapToCount = 1.0;

  /// Camera follows the tower top. The top stays this many meters below the
  /// camera centre — leaves room for the hook above.
  static const cameraOffsetBelowCenter = 2.5;

  /// Time spent smoothly panning the camera to a new target.
  static const cameraLerp = 4.0;

  static const baseRewardPerBlock = 1;
}
