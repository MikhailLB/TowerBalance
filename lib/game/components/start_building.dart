import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';

/// First "platform" the player stacks on — the painted starter shop.
///
/// Renders [AppAssets.startBuilding] (the small green "BALANCE" shop) at
/// exactly the body dimensions, so the visible footprint and the collision
/// shape are identical. Sits on the ground line.
class StartBuilding extends BodyComponent {
  StartBuilding() : super(priority: 0);

  late final ui.Image _image;

  @override
  bool get renderBody => false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _image = await Flame.images.load(AppAssets.startBuilding);
  }

  @override
  Body createBody() {
    final width = GameConstants.startBuildingWidth;
    final height = GameConstants.startBuildingHeight;
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
    // BodyComponent renders in body-local space. Sprite occupies the exact
    // body footprint so visuals == collider.
    final dst = Rect.fromCenter(
      center: Offset.zero,
      width: GameConstants.startBuildingWidth,
      height: GameConstants.startBuildingHeight,
    );
    final src = Rect.fromLTWH(
      0,
      0,
      _image.width.toDouble(),
      _image.height.toDouble(),
    );
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
