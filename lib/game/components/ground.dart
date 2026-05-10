import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';

/// Static Forge2D body acting as the ground floor. A separate
/// [PositionComponent] paints the ground tile so the body itself can be
/// invisible and tightly tuned.
class Ground extends BodyComponent {
  Ground() : super(priority: -10);

  @override
  Body createBody() {
    final shape = PolygonShape()
      ..setAsBox(
        GameConstants.worldWidth * 5,
        2.5,
        Vector2(0, GameConstants.groundTopY + 2.5),
        0,
      );
    final body = world.createBody(BodyDef(
      type: BodyType.static,
      position: Vector2.zero(),
      userData: 'ground',
    ));
    body.createFixture(FixtureDef(
      shape,
      friction: 0.9,
      restitution: 0.0,
    ));
    return body;
  }

  @override
  void render(Canvas canvas) {
    // Body geometry isn't rendered — visuals come from [GroundDecal].
  }
}

class GroundDecal extends PositionComponent {
  GroundDecal() : super(priority: -8);

  late final ui.Image _image;

  @override
  Future<void> onLoad() async {
    _image = await Flame.images.load(AppAssets.ground);
    final aspect = _image.width / _image.height;
    final width = GameConstants.worldWidth * 1.4;
    final height = width / aspect;
    size = Vector2(width, height);
    anchor = Anchor.topCenter;
    position = Vector2(0, GameConstants.groundTopY - 0.05);
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
    final dst = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawImageRect(_image, src, dst, paint);
  }
}
