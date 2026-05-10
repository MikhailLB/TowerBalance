import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';
import '../tower_game.dart';

/// Sky background that follows the camera and tiles only the strip currently
/// visible. Drawing the full ~450m of sky every frame on weaker phones causes
/// a noticeable hitch on first launch — this version only paints a handful of
/// tiles around the viewport and moves with the camera.
class SkyBackground extends PositionComponent
    with HasGameReference<TowerGame> {
  SkyBackground({Images? imagesCache})
      : _imagesCache = imagesCache,
        super(priority: -100);

  final Images? _imagesCache;
  late final ui.Image _image;
  late final double _tileHeight;
  static const _tileWidth = GameConstants.worldWidth;

  @override
  Future<void> onLoad() async {
    final cache = _imagesCache ?? Flame.images;
    _image = await cache.load(AppAssets.sky);
    final aspect = _image.width / _image.height;
    _tileHeight = _tileWidth / aspect;
    size = Vector2(_tileWidth, GameConstants.worldHeight + _tileHeight * 2);
    anchor = Anchor.topLeft;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final cam = game.camera.viewfinder.position;
    // Snap top of the painted strip to the tile above the camera so seams
    // line up perfectly even after long pans.
    final topY =
        cam.y - GameConstants.worldHeight - _tileHeight;
    final snappedTop = (topY / _tileHeight).floorToDouble() * _tileHeight;
    position = Vector2(-_tileWidth / 2, snappedTop);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..isAntiAlias = false;
    final src = Rect.fromLTWH(
      0,
      0,
      _image.width.toDouble(),
      _image.height.toDouble(),
    );
    var y = 0.0;
    while (y < size.y) {
      final dst = Rect.fromLTWH(0, y, size.x, _tileHeight);
      canvas.drawImageRect(_image, src, dst, paint);
      y += _tileHeight;
    }
  }
}
