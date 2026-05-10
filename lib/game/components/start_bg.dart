import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';
import '../tower_game.dart';

/// Painted strip of distant city silhouettes that sits between the sky and the
/// starter shop.
///
/// `start_bg_asset.webp` is a 1080x416 wide horizontal panel (aspect ~2.6)
/// containing rooftops, lamp posts and a faint cityscape. We render it three
/// times the world width so the edges stay off-screen even when the camera
/// pans, with its bottom resting just below the ground line.
class StartBg extends PositionComponent with HasGameReference<TowerGame> {
  StartBg() : super(priority: -50);

  late final ui.Image _image;

  @override
  Future<void> onLoad() async {
    _image = await Flame.images.load(AppAssets.startBg);
    final aspect = _image.width / _image.height;
    final width = GameConstants.worldWidth * 3.0;
    final height = width / aspect;
    size = Vector2(width, height);
    anchor = Anchor.bottomCenter;
    // Bottom of the artwork sits just below the ground line so the painted
    // pavement / dirt edge meets the real ground without a visible seam.
    position = Vector2(0, GameConstants.groundTopY + 0.4);
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
