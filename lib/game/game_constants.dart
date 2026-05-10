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

  /// Centre of the camera at game start; matches a 9x16 viewport with the
  /// origin in the centre.
  static Vector2 get initialCameraTarget => Vector2(0, 0);

  /// Y of the top of the ground rectangle. Anything below this is "out of
  /// bounds" and counts as a fail.
  static const groundTopY = 7.5;

  /// Stack starts on top of the painted starter building.
  static const startBuildingTopY = 1.5;
  static const startBuildingWidth = 4.5;
  static const startBuildingHeight = 6.0;

  static const blockWidth = 2.6;
  static const blockHeight = 0.95;

  /// Vertical distance between the bottom of the swinging hook block and the
  /// current top of the tower.
  static const hookBlockOffsetAboveTop = 6.0;

  /// Horizontal sway: hook X = sin(t) * amplitude.
  static const hookAmplitude = 2.6;

  /// Initial half-period of the sine wave (seconds for a one-way swing).
  static const hookInitialHalfPeriod = 1.05;

  /// Floor of the speed-up ramp. The hook never gets faster than this.
  static const hookMinHalfPeriod = 0.32;

  /// How much the period shrinks per successfully placed block.
  static const hookSpeedUpPerBlock = 0.04;

  /// Acceleration of gravity used by the Forge2D world.
  static const gravity = 28.0;

  /// Active block is "settled" when its linear speed has stayed below this
  /// threshold for [settleHoldSeconds].
  static const settleSpeedThreshold = 0.25;
  static const settleHoldSeconds = 0.45;

  /// Hard timeout: even if the block is still wobbling we declare the round
  /// over after this many seconds (prevents infinite stalls).
  static const settleTimeoutSeconds = 4.0;

  /// Minimum X-overlap (in meters) between the new block and the previous
  /// tower top required to keep playing. Less overlap == failed placement.
  static const minOverlapToCount = 0.55;

  /// Camera follows the tower top. The top stays this many meters below the
  /// camera centre — leaves room for the hook above.
  static const cameraOffsetBelowCenter = 3.5;

  /// Time spent smoothly panning the camera to a new target.
  static const cameraLerp = 4.0;

  static const baseRewardPerBlock = 1;
}
