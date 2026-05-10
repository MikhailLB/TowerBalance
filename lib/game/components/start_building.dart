import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';

/// Painted starter building. Acts as both art and the first physics body that
/// the player stacks blocks on top of.
///
/// We render the asset slightly wider than the physical hitbox so the brick
/// edges visually overhang the collision shape (matches the painting).
class StartBuilding extends BodyComponent {
  StartBuilding() : super(priority: 0);

  late final ui.Image _image;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _image = await Flame.images.load(AppAssets.startBuilding);
  }

  @override
  Body createBody() {
    final width = GameConstants.startBuildingWidth;
    final height = GameConstants.startBuildingHeight;
    // Centre of the body sits half a height below the painted top.
    final centreY = GameConstants.startBuildingTopY + height / 2;
    final shape = PolygonShape()..setAsBoxXY(width / 2, height / 2);
    final body = world.createBody(BodyDef(
      type: BodyType.static,
      position: Vector2(0, centreY),
      userData: 'start_building',
    ));
    body.createFixture(FixtureDef(
      shape,
      friction: 0.95,
      restitution: 0.0,
    ));
    return body;
  }

  @override
  void render(Canvas canvas) {
    // BodyComponent renders in body-local space already.
    final aspect = _image.width / _image.height;
    final paintedWidth = GameConstants.startBuildingWidth * 1.4;
    final paintedHeight = paintedWidth / aspect;
    final dst = Rect.fromCenter(
      center: Offset.zero,
      width: paintedWidth,
      height: paintedHeight,
    );
    final src = Rect.fromLTWH(
      0,
      0,
      _image.width.toDouble(),
      _image.height.toDouble(),
    );
    canvas.drawImageRect(_image, src, dst, Paint()..isAntiAlias = false);
  }
}
