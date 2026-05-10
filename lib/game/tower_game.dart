import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import 'game_constants.dart';
import 'game_status.dart';
import 'tower_world.dart';

/// Top-level Forge2D game. Owns the camera, forwards taps to the world, and
/// keeps the camera smoothly following the top of the tower.
class TowerGame extends Forge2DGame<TowerWorld> with TapCallbacks {
  TowerGame({
    required int Function() skinPicker,
    required this.startWithSlowHook,
  }) : super(
          gravity: Vector2(0, GameConstants.gravity),
          world: TowerWorld(skinPicker: skinPicker),
          camera: CameraComponent.withFixedResolution(
            width: GameConstants.worldWidth,
            height: GameConstants.worldHeight,
          ),
        );

  final bool startWithSlowHook;

  @override
  Color backgroundColor() => const Color(0xFF87CEEB);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.position = GameConstants.initialCameraTarget;
    world.startRound(slowHookEnabled: startWithSlowHook);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (world.status.value == TowerGameStatus.paused ||
        world.status.value == TowerGameStatus.gameOver) {
      return;
    }
    world.dropBlock();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _followTower(dt);
  }

  void _followTower(double dt) {
    final desiredCenterY =
        world.currentTopY - GameConstants.cameraOffsetBelowCenter;
    final current = camera.viewfinder.position.y;
    // Camera only goes up (never drops back down even if blocks fall).
    final target = math.min(current, desiredCenterY);
    final newY = current + (target - current) * (1 - math.exp(-dt * GameConstants.cameraLerp));
    camera.viewfinder.position = Vector2(0, newY);
  }

  void setPaused(bool value) {
    world.setPaused(value);
    paused = value;
  }

  void requestSecondChance() {
    world.secondChanceAvailable = true;
  }
}
