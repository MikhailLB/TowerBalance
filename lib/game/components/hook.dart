import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';

/// The crane hook + the block currently being teased above the tower.
///
/// Movement: pure horizontal slide. The hook moves left/right on a sine wave
/// (`x = sin(phase) * amplitude`) at a fixed Y. Nothing rotates — the hook
/// sprite, the block, and the chains all stay upright. This matches the
/// reference design (the hook ladders straight back and forth above the
/// tower, no pendulum arc).
///
/// Visual structure (top to bottom):
///   1. The `hook_asset.webp` sprite — drawn upright, its built-in upward
///      ropes vanishing off the top of the screen.
///   2. Two diagonal chain lines forming an inverted V (Λ) from the bottom of
///      the hook sprite down to the top-left and top-right corners of the
///      block.
///   3. The block sprite, hanging directly below the hook, upright.
///
/// Block image cache: all six skin sprites are loaded once in [onLoad] so
/// [attachNewBlock] is synchronous — the next block appears on the same frame
/// as the round transitions from `falling` back to `swinging`.
class Hook extends PositionComponent {
  Hook({required this.skinIndexProvider}) : super(priority: 10);

  /// Returns the skin index (1..6) for the *next* block to attach.
  final int Function() skinIndexProvider;

  late ui.Image _hookImage;
  final Map<int, ui.Image> _blockImages = {};
  late ui.Image _blockImage;
  int _currentSkin = 1;

  /// Current top-of-tower Y (used to position the hook above it).
  double topY = GameConstants.startBuildingTopY;

  /// Current half period (seconds) — controls slide speed.
  double halfPeriod = GameConstants.hookInitialHalfPeriod;

  /// Phase accumulator. Reset when a new block is attached.
  double _phase = 0;

  /// True while the block is attached. False after a drop, until the world
  /// calls [attachNewBlock].
  bool _hasBlock = true;

  // --- Slide math (no rotation, no arc) -------------------------------------

  /// World-space X of the hook centre / block centre.
  double get currentX =>
      math.sin(_phase) * GameConstants.hookAmplitude;

  /// World-space Y of the block centre. Fixed — moves only when the tower
  /// grows taller (which lifts [topY]).
  double get currentY =>
      topY -
      GameConstants.hookBlockOffsetAboveTop -
      GameConstants.blockHeight / 2;

  /// Horizontal speed of the slide at the current phase (m/s).
  double get currentVelocityX =>
      math.cos(_phase) *
      GameConstants.hookAmplitude *
      (math.pi / halfPeriod);

  /// Top edge of the hanging block.
  double get blockY => currentY - GameConstants.blockHeight / 2;

  bool get hasBlock => _hasBlock;

  @override
  Future<void> onLoad() async {
    _hookImage = await Flame.images.load(AppAssets.hook);
    for (var i = 1; i <= 6; i++) {
      _blockImages[i] = await Flame.images.load(AppAssets.block(i));
    }
    _currentSkin = skinIndexProvider();
    _blockImage = _blockImages[_currentSkin]!;
  }

  /// Detach the block from the hook (drop). The world will create a real
  /// physics block and call [attachNewBlock] when ready.
  void releaseBlock() {
    _hasBlock = false;
  }

  /// Synchronously snap the next block onto the hook.
  void attachNewBlock() {
    _currentSkin = skinIndexProvider();
    _blockImage = _blockImages[_currentSkin] ?? _blockImage;
    _hasBlock = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt * (math.pi / halfPeriod);
    if (_phase > math.pi * 2) _phase -= math.pi * 2;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium;

    final cx = currentX;
    final blockCy = currentY;
    final blockTopY = blockCy - GameConstants.blockHeight / 2;

    // Hook sprite geometry — upright, sitting above the block with the chain
    // gap reserved between its bottom and the block top.
    const hookSpriteHeight = GameConstants.hookSpriteHeight;
    final hookAspect = _hookImage.width / _hookImage.height; // 0.24
    final hookSpriteWidth = hookSpriteHeight * hookAspect;
    final hookBottomY = blockTopY - GameConstants.hookChainHeight;
    final hookCenterY = hookBottomY - hookSpriteHeight / 2;

    // 1) Hook sprite (upright, no rotation). Drawn first so the chains in
    //    step 2 visually run UNDER the painted hook curl.
    canvas.drawImageRect(
      _hookImage,
      Rect.fromLTWH(
        0,
        0,
        _hookImage.width.toDouble(),
        _hookImage.height.toDouble(),
      ),
      Rect.fromCenter(
        center: Offset(cx, hookCenterY),
        width: hookSpriteWidth,
        height: hookSpriteHeight,
      ),
      paint,
    );

    if (_hasBlock) {
      // 2) Inverted-V chains from hook bottom down to the block's top corners.
      final inset = GameConstants.blockWidth * 0.08;
      final attachLeftX = cx - GameConstants.blockWidth / 2 + inset;
      final attachRightX = cx + GameConstants.blockWidth / 2 - inset;
      final chainPaint = Paint()
        ..color = const Color(0xFF1F1F1F)
        ..strokeWidth = 0.10
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cx, hookBottomY),
        Offset(attachLeftX, blockTopY),
        chainPaint,
      );
      canvas.drawLine(
        Offset(cx, hookBottomY),
        Offset(attachRightX, blockTopY),
        chainPaint,
      );

      // 3) Block sprite (upright, no rotation), at exact body dimensions.
      canvas.drawImageRect(
        _blockImage,
        Rect.fromLTWH(
          0,
          0,
          _blockImage.width.toDouble(),
          _blockImage.height.toDouble(),
        ),
        Rect.fromCenter(
          center: Offset(cx, blockCy),
          width: GameConstants.blockWidth,
          height: GameConstants.blockHeight,
        ),
        paint,
      );
    }
  }
}
