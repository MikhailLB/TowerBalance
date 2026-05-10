import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../game_constants.dart';

/// The crane hook + the block currently being teased above the tower.
///
/// The whole assembly (chain + hook sprite + block) behaves as a single rigid
/// pendulum hanging from a virtual pivot above the tower. The pivot is fixed
/// in world space (a chain-length above the resting block) and the entire
/// assembly rotates around it, so the block traces a true left-right arc —
/// slow at the extremes, fast through the centre — and visibly rises a touch
/// at the edges.
///
/// Visual structure:
///   1. A single dark chain line going from far above the pivot down to the
///      hook sprite.
///   2. A small `hook_asset.webp` sprite (the actual yellow-black hook + a
///      few links of chain) sitting just above the block, with its hook end
///      pointing down towards the block.
///   3. The block sprite rendered at exact body dimensions, attached just
///      below the hook.
///
/// Rotation: when the pendulum is at angle `a`, the chain direction is
/// `(sin(a), cos(a))`. We render every sprite with `canvas.rotate(-a)` so the
/// sprite's local +Y axis maps to the chain direction in world space. With
/// canvas's standard rotation matrix, local (0, +1) → (-sin(theta), cos(theta));
/// we want this to equal (sin(a), cos(a)), so theta = -a.
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

  /// Synchronously snap the next block onto the hook. Safe to call from
  /// [TowerWorld.update] — no awaits, no allocations besides a map lookup.
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

    final angle = _angle;
    final dirX = math.sin(angle);
    final dirY = math.cos(angle);

    // Hook sprite: small (just the hook itself, not the whole chain). It sits
    // immediately above the block, with its curl pointing toward the block.
    const hookSpriteHeight = 1.6;
    final hookAspect = _hookImage.width / _hookImage.height; // 0.24
    final hookSpriteWidth = hookSpriteHeight * hookAspect;

    // Distance along the chain from block centre back to the hook sprite
    // centre. Half a block + half a hook + a small gap.
    final hookOffset =
        GameConstants.blockHeight / 2 + hookSpriteHeight / 2 - 0.15;
    final hookCx = _blockCenterX - dirX * hookOffset;
    final hookCy = _blockCenterY - dirY * hookOffset;

    // Single chain line: starts at the top of the hook sprite and runs up the
    // chain direction, well past the pivot off the top of the screen.
    final chainBottomX = hookCx - dirX * (hookSpriteHeight / 2 - 0.05);
    final chainBottomY = hookCy - dirY * (hookSpriteHeight / 2 - 0.05);
    final chainTopX = chainBottomX - dirX * 30;
    final chainTopY = chainBottomY - dirY * 30;
    final chainPaint = Paint()
      ..color = const Color(0xFF1F1F1F)
      ..strokeWidth = 0.10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(chainTopX, chainTopY),
      Offset(chainBottomX, chainBottomY),
      chainPaint,
    );

    // Hook sprite. Rotate by -angle so the sprite's local +Y (its hook curl
    // end) points along the chain direction towards the block.
    canvas.save();
    canvas.translate(hookCx, hookCy);
    canvas.rotate(-angle);
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
        width: hookSpriteWidth,
        height: hookSpriteHeight,
      ),
      paint,
    );
    canvas.restore();

    // Block at the bottom, rendered exactly at body dimensions, tilted with
    // the same -angle so the whole assembly looks like one rigid pendulum.
    if (_hasBlock) {
      canvas.save();
      canvas.translate(_blockCenterX, _blockCenterY);
      canvas.rotate(-angle);
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
