import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game_constants.dart';
import '../tower_game.dart';

/// Flat gradient sky that always fills the camera viewport.
///
/// We deliberately avoid tiling `bg_sky_asset.webp` because that asset has a
/// painted cloud composition that creates obvious seams when tiled vertically
/// across many "screens" of tower height. A clean two-stop gradient gives the
/// reference look (saturated mid-blue at the top, paler near the horizon) and
/// stays seamless no matter how high the player builds.
class SkyBackground extends PositionComponent
    with HasGameReference<TowerGame> {
  SkyBackground() : super(priority: -100);

  static const _topColor = Color(0xFF6FB6E0);
  static const _bottomColor = Color(0xFFBEE3F4);

  @override
  void render(Canvas canvas) {
    final cam = game.camera.viewfinder.position;
    // Cover an area generous enough to hide any rounding flicker at the
    // viewport edges.
    final left = cam.x - GameConstants.worldWidth;
    final right = cam.x + GameConstants.worldWidth;
    final top = cam.y - GameConstants.worldHeight;
    final bottom = cam.y + GameConstants.worldHeight;
    final rect = Rect.fromLTRB(left, top, right, bottom);
    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_topColor, _bottomColor],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }
}
