import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';
import '../tower_game.dart';

/// Painted backdrop scene that sits behind the start building.
///
/// Renders [AppAssets.startBg] as a wide static image anchored at the ground,
/// extending upward by its natural aspect. Sits between the tiled
/// [SkyBackground] (priority -100) and the start building (priority 0), so the
/// distant city / horizon line shows through the empty sky next to the tower.
class StartBg extends PositionComponent with HasGameReference<TowerGame> {
  StartBg() : super(priority: -60);

  late final ui.Image _image;

  @override
  Future<void> onLoad() async {
    _image = await Flame.images.load(AppAssets.startBg);
    final aspect = _image.width / _image.height;
    // Stretch the backdrop wider than the viewport so its edges always sit
    // off-screen even on tall portrait phones.
    final width = GameConstants.worldWidth * 2.0;
    final height = width / aspect;
    size = Vector2(width, height);
    anchor = Anchor.bottomCenter;
    // Bottom of the artwork sits a hair below the ground line so the dirt
    // strip from GroundDecal can finish it off.
    position = Vector2(0, GameConstants.groundTopY + 0.3);
  }

  @override
  void render(Canvas canvas) {
    final src = Rect.fromLTWH(
      0,
      0,
      _image.width.toDouble(),
      _image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawImageRect(
      _image,
      src,
      dst,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.medium,
    );
  }
}
