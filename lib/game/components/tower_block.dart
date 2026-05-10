import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';

/// A single dynamic tower block. Spawned by the [Hook] and inserted into the
/// physics world as soon as the player taps to drop it.
class TowerBlock extends BodyComponent {
  TowerBlock({
    required this.skinIndex,
    required this.spawnPosition,
    required this.spawnVelocity,
    required this.spawnAngularVelocity,
  }) : super(priority: 5);

  /// 1..6 — matches `block_asset_0X.webp`.
  final int skinIndex;
  final Vector2 spawnPosition;
  final Vector2 spawnVelocity;
  final double spawnAngularVelocity;

  late final ui.Image _image;

  /// Set to true after the block has come to rest and been counted into the
  /// tower. Used by the world to find the current top.
  bool placed = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _image = await Flame.images.load(AppAssets.block(skinIndex));
  }

  @override
  Body createBody() {
    final hw = GameConstants.blockWidth / 2;
    final hh = GameConstants.blockHeight / 2;
    final shape = PolygonShape()..setAsBoxXY(hw, hh);
    final body = world.createBody(BodyDef(
      type: BodyType.dynamic,
      position: spawnPosition.clone(),
      linearVelocity: spawnVelocity.clone(),
      angularVelocity: spawnAngularVelocity,
      bullet: true,
      userData: 'tower_block',
    ));
    body.createFixture(FixtureDef(
      shape,
      density: 1.4,
      friction: 0.92,
      restitution: 0.02,
    ));
    return body;
  }

  @override
  void render(Canvas canvas) {
    final aspect = _image.width / _image.height;
    var w = GameConstants.blockWidth;
    var h = w / aspect;
    if (h < GameConstants.blockHeight) {
      h = GameConstants.blockHeight;
      w = h * aspect;
    }
    final dst = Rect.fromCenter(
      center: Offset.zero,
      width: w,
      height: h,
    );
    final src = Rect.fromLTWH(
      0,
      0,
      _image.width.toDouble(),
      _image.height.toDouble(),
    );
    canvas.drawImageRect(_image, src, dst, Paint()..isAntiAlias = false);
  }

  /// Returns the world-space top Y of the block (smallest Y of its corners).
  double get topY {
    final t = body.transform;
    final hw = GameConstants.blockWidth / 2;
    final hh = GameConstants.blockHeight / 2;
    final corners = <Vector2>[
      Vector2(-hw, -hh),
      Vector2(hw, -hh),
      Vector2(hw, hh),
      Vector2(-hw, hh),
    ];
    var minY = double.infinity;
    for (final c in corners) {
      final w = t.p + Vector2(
        c.x * t.q.cos - c.y * t.q.sin,
        c.x * t.q.sin + c.y * t.q.cos,
      );
      if (w.y < minY) minY = w.y;
    }
    return minY;
  }
}
