import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';

/// The crane hook + the block currently being teased above the tower.
///
/// The hook is purely visual until the player taps to drop. When dropped,
/// the world reads `currentX` and `currentVelocityX` to spawn an actual
/// dynamic [TowerBlock] at the same place.
class Hook extends PositionComponent {
  Hook({required this.skinIndexProvider})
      : super(priority: 6);

  /// Returns the skin index (1..6) for the *next* block to attach.
  final int Function() skinIndexProvider;

  late ui.Image _hookImage;
  late ui.Image _blockImage;
  int _currentSkin = 1;

  /// Current top-of-tower Y (used to position the hook above it).
  double topY = GameConstants.startBuildingTopY;

  /// Current half period (seconds) — controls swing speed.
  double halfPeriod = GameConstants.hookInitialHalfPeriod;

  /// Phase accumulator. Reset when a new block is attached.
  double _phase = 0;

  /// True while the block is attached. False after a drop, until the world
  /// calls [attachNewBlock].
  bool _hasBlock = true;

  /// Current X position of the swinging block (world coordinates).
  double get currentX =>
      math.sin(_phase) * GameConstants.hookAmplitude;

  /// Derivative of position (m/s) — used as the spawn velocity of the block.
  double get currentVelocityX =>
      math.cos(_phase) *
      GameConstants.hookAmplitude *
      (math.pi / halfPeriod);

  /// Y position of the hanging block (top of tower minus a fixed offset).
  double get blockY => topY - GameConstants.hookBlockOffsetAboveTop;

  /// Y position of the hook image (a bit above the block).
  double get hookY => blockY - GameConstants.blockHeight - 0.4;

  bool get hasBlock => _hasBlock;

  @override
  Future<void> onLoad() async {
    _hookImage = await Flame.images.load(AppAssets.hook);
    _currentSkin = skinIndexProvider();
    _blockImage = await Flame.images.load(AppAssets.block(_currentSkin));
  }

  /// Detach the block from the hook (drop). The world will create a real
  /// physics block and call [attachNewBlock] when ready.
  void releaseBlock() {
    _hasBlock = false;
  }

  Future<void> attachNewBlock() async {
    _currentSkin = skinIndexProvider();
    _blockImage = await Flame.images.load(AppAssets.block(_currentSkin));
    _hasBlock = true;
    // Don't reset phase — preserve "where the swing is" for less surprise.
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Advance phase. Half period = pi radians of phase, so dphi/dt = pi / Tp.
    _phase += dt * (math.pi / halfPeriod);
    // Keep phase bounded for floating-point health.
    if (_phase > math.pi * 2) _phase -= math.pi * 2;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..isAntiAlias = false;
    final blockX = currentX;
    final yBlock = blockY;
    final yHook = hookY;

    // Hook image (pulley + chain spool). Anchored so the chain bottom lands
    // exactly on the block top.
    final hookAspect = _hookImage.width / _hookImage.height;
    const hookHeight = 1.4;
    final hookWidth = hookHeight * hookAspect;
    final hookSrc = Rect.fromLTWH(
      0,
      0,
      _hookImage.width.toDouble(),
      _hookImage.height.toDouble(),
    );
    final hookCenterY = yHook - hookHeight / 2;
    final hookDst = Rect.fromCenter(
      center: Offset(blockX, hookCenterY),
      width: hookWidth,
      height: hookHeight,
    );

    // Chain (a thin dark rectangle from the top of viewport down to hook).
    final chainPaint = Paint()..color = const Color(0xFF222222);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(blockX, hookCenterY - 8),
        width: 0.08,
        height: 16,
      ),
      chainPaint,
    );

    canvas.drawImageRect(_hookImage, hookSrc, hookDst, paint);

    if (_hasBlock) {
      final blockAspect = _blockImage.width / _blockImage.height;
      var w = GameConstants.blockWidth;
      var h = w / blockAspect;
      if (h < GameConstants.blockHeight) {
        h = GameConstants.blockHeight;
        w = h * blockAspect;
      }
      final blockDst = Rect.fromCenter(
        center: Offset(blockX, yBlock + GameConstants.blockHeight / 2),
        width: w,
        height: h,
      );
      final blockSrc = Rect.fromLTWH(
        0,
        0,
        _blockImage.width.toDouble(),
        _blockImage.height.toDouble(),
      );
      canvas.drawImageRect(_blockImage, blockSrc, blockDst, paint);
    }
  }
}
