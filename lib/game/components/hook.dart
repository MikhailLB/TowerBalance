import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';

/// The crane hook + the block currently being teased above the tower.
///
/// The whole assembly (block + V-shaped chains + hook sprite + crane line)
/// behaves as a single rigid pendulum hanging from a virtual pivot above the
/// tower. The pivot is fixed in world space (a chain-length above the
/// resting block) and the entire assembly rotates around it, so the block
/// traces a true left-right arc — slow at the extremes, fast through the
/// centre — and visibly rises a touch at the edges, just like a real swing.
///
/// Visuals match the screenshot reference: a single crane wire goes from off
/// screen down to the hook, then two parallel chains diverge from the hook to
/// the top corners of the block (forming a V).
class Hook extends PositionComponent {
  Hook({required this.skinIndexProvider}) : super(priority: 10);

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

  // --- Pendulum math ---------------------------------------------------------

  /// Current pendulum angle (radians, 0 = straight down).
  double get _angle =>
      math.sin(_phase) * GameConstants.hookMaxAngle;

  /// Y of the pivot (fixed in world space).
  double get _pivotY =>
      topY -
      GameConstants.hookBlockOffsetAboveTop -
      GameConstants.blockHeight -
      GameConstants.hookChainLength;

  double get _blockCenterX =>
      math.sin(_angle) * GameConstants.hookChainLength;

  double get _blockCenterY =>
      _pivotY + math.cos(_angle) * GameConstants.hookChainLength;

  /// Spawn position X (world).
  double get currentX => _blockCenterX;

  /// Spawn position Y (world centre of block).
  double get currentY => _blockCenterY;

  /// Tangential X velocity at the current angle.
  double get currentVelocityX {
    final phaseDot = math.pi / halfPeriod;
    final angleDot = math.cos(_phase) * GameConstants.hookMaxAngle * phaseDot;
    return math.cos(_angle) * GameConstants.hookChainLength * angleDot;
  }

  /// Y position of the hanging block's top edge.
  double get blockY => _blockCenterY - GameConstants.blockHeight / 2;

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

    final angle = _angle;
    final dirX = math.sin(angle);
    final dirY = math.cos(angle);

    // Pivot — virtual point above tower; renders as the off-screen end of the
    // crane wire.
    final pivotX = 0.0;
    final pivotY = _pivotY;

    final blockCx = _blockCenterX;
    final blockCy = _blockCenterY;

    // The visible hook sprite sits on the chain just above the block.
    const hookHeight = 1.0;
    final hookAspect = _hookImage.width / _hookImage.height;
    final hookWidth = hookHeight * hookAspect;
    final hookOffset = GameConstants.blockHeight / 2 + hookHeight / 2 + 0.2;
    final hookCx = blockCx - dirX * hookOffset;
    final hookCy = blockCy - dirY * hookOffset;

    final chainPaint = Paint()
      ..color = const Color(0xFF1F1F1F)
      ..strokeWidth = 0.10
      ..strokeCap = StrokeCap.round;

    // 1) Crane wire — a single thicker line from the pivot (and beyond, off
    //    the top of the screen) down to the hook.
    final aboveX = pivotX - dirX * 18;
    final aboveY = pivotY - dirY * 18;
    canvas.drawLine(
      Offset(aboveX, aboveY),
      Offset(hookCx, hookCy),
      Paint()
        ..color = const Color(0xFF1F1F1F)
        ..strokeWidth = 0.13
        ..strokeCap = StrokeCap.round,
    );

    // 2) Two diverging chains from the hook to the top corners of the block.
    if (_hasBlock) {
      final hw = GameConstants.blockWidth * 0.42;
      final hh = GameConstants.blockHeight / 2;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final tlX = blockCx + (-hw) * cosA - (-hh) * sinA;
      final tlY = blockCy + (-hw) * sinA + (-hh) * cosA;
      final trX = blockCx + (hw) * cosA - (-hh) * sinA;
      final trY = blockCy + (hw) * sinA + (-hh) * cosA;
      canvas.drawLine(
          Offset(hookCx, hookCy), Offset(tlX, tlY), chainPaint);
      canvas.drawLine(
          Offset(hookCx, hookCy), Offset(trX, trY), chainPaint);
    }

    // 3) Hook sprite (rotated to follow the swing).
    canvas.save();
    canvas.translate(hookCx, hookCy);
    canvas.rotate(angle);
    canvas.drawImageRect(
      _hookImage,
      Rect.fromLTWH(
        0,
        0,
        _hookImage.width.toDouble(),
        _hookImage.height.toDouble(),
      ),
      Rect.fromCenter(
        center: Offset.zero,
        width: hookWidth,
        height: hookHeight,
      ),
      paint,
    );
    canvas.restore();

    // 4) Block.
    if (_hasBlock) {
      canvas.save();
      canvas.translate(blockCx, blockCy);
      canvas.rotate(angle);
      canvas.drawImageRect(
        _blockImage,
        Rect.fromLTWH(
          0,
          0,
          _blockImage.width.toDouble(),
          _blockImage.height.toDouble(),
        ),
        Rect.fromCenter(
          center: Offset.zero,
          width: GameConstants.blockWidth,
          height: GameConstants.blockHeight,
        ),
        paint,
      );
      canvas.restore();
    }
  }
}
