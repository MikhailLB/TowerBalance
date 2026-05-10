import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';

/// Sky background that tiles vertically as the tower grows. Lives inside the
/// world (not the viewport) so we can let the camera pan across it.
///
/// The painted asset is just a single short slice of sky, so we draw it
/// repeatedly across a range that comfortably covers any reachable tower
/// height.
class SkyBackground extends PositionComponent {
  SkyBackground({Images? imagesCache})
      : _imagesCache = imagesCache,
        super(priority: -100);

  final Images? _imagesCache;
  late final ui.Image _image;

  /// Logical world rows we'll cover in either direction.
  static const _heightUp = 400.0;
  static const _heightDown = 50.0;
  static const _tileWidth = GameConstants.worldWidth;

  @override
  Future<void> onLoad() async {
    final cache = _imagesCache ?? Flame.images;
    _image = await cache.load(AppAssets.sky);
    size = Vector2(_tileWidth, _heightUp + _heightDown);
    position = Vector2(-_tileWidth / 2, -_heightUp);
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
    final imageAspect = _image.width / _image.height;
    final tileHeight = _tileWidth / imageAspect;
    var y = 0.0;
    while (y < size.y) {
      final dst = Rect.fromLTWH(0, y, size.x, tileHeight);
      canvas.drawImageRect(_image, src, dst, paint);
      y += tileHeight;
    }
  }
}
