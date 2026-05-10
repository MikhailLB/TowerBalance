import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';

/// A drifting cloud sprite. Wraps around horizontally and stays in a band
/// relative to the camera centre so the sky always looks alive.
class Cloud extends SpriteComponent with HasGameReference {
  Cloud({
    required this.speed,
    required this.relativeY,
    required this.scaleFactor,
    required this.startX,
    required this.cloudAlpha,
  });

  /// Meters per second.
  final double speed;

  /// Y offset relative to the camera centre (negative == above centre).
  final double relativeY;

  /// Visual scale of the cloud sprite in meters of width.
  final double scaleFactor;

  final double startX;

  /// 0..1 — modulates the white tint applied to the sprite.
  final double cloudAlpha;

  static Future<Sprite> _loadSprite() async =>
      Sprite(await Flame.images.load(AppAssets.cloud));

  @override
  Future<void> onLoad() async {
    sprite = await _loadSprite();
    final aspect = sprite!.srcSize.x / sprite!.srcSize.y;
    size = Vector2(scaleFactor, scaleFactor / aspect);
    anchor = Anchor.center;
    position = Vector2(startX, relativeY);
    paint = Paint()
      ..colorFilter = ColorFilter.mode(
        const Color(0xFFFFFFFF).withValues(alpha: cloudAlpha),
        BlendMode.modulate,
      );
    priority = -50;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += speed * dt;
    final cameraCenter = game.camera.viewfinder.position;
    // Wrap horizontally a little outside the visible area for a smooth loop.
    final maxX = cameraCenter.x + GameConstants.worldWidth / 2 + size.x;
    final minX = cameraCenter.x - GameConstants.worldWidth / 2 - size.x;
    if (position.x > maxX) {
      position.x = minX;
      position.y = cameraCenter.y + relativeY;
    } else if (position.x < minX) {
      position.x = maxX;
      position.y = cameraCenter.y + relativeY;
    }
  }
}

/// Spawns and respawns clouds tied to the camera centre.
class CloudLayer extends Component with HasGameReference {
  CloudLayer({this.seed = 0});

  final int seed;
  late final math.Random _rand = math.Random(seed);

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < 6; i++) {
      add(_spawnCloud());
    }
  }

  Cloud _spawnCloud() {
    final width = GameConstants.worldWidth;
    final speed = (_rand.nextDouble() * 0.5 + 0.25) *
        (_rand.nextBool() ? 1 : -1);
    final relativeY = -_rand.nextDouble() * 7 - 1; // above the tower
    final scale = 2.5 + _rand.nextDouble() * 2.5;
    final startX = (_rand.nextDouble() - 0.5) * width;
    final cloudOpacity = 0.7 + _rand.nextDouble() * 0.3;
    return Cloud(
      speed: speed,
      relativeY: relativeY,
      scaleFactor: scale,
      startX: startX,
      cloudAlpha: cloudOpacity,
    );
  }
}
