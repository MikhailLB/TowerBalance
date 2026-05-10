import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';
import '../tower_game.dart';

/// Sky background painted from [AppAssets.sky].
///
/// The artwork is a 1080x2400 portrait that already covers a full screen of
/// sky. We pin it to the camera every frame so it always fills the viewport,
/// regardless of how high the tower has grown. No tiling — the painted gradient
/// stays seamless because there's only ever one copy on screen at a time.
class SkyBackground extends PositionComponent
    with HasGameReference<TowerGame> {
  SkyBackground() : super(priority: -100);

  late final ui.Image _image;
  // We render a quad slightly larger than the world rect so any rounding
  // never reveals a transparent edge.
  static const _padding = 1.0;

  @override
  Future<void> onLoad() async {
    _image = await Flame.images.load(AppAssets.sky);
    size = Vector2(
      GameConstants.worldWidth + _padding * 2,
      GameConstants.worldHeight + _padding * 2,
    );
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = game.camera.viewfinder.position.clone();
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
