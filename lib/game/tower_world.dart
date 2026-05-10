import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';

import 'components/cloud.dart';
import 'components/ground.dart';
import 'components/hook.dart';
import 'components/sky_background.dart';
import 'components/start_building.dart';
import 'components/tower_block.dart';
import 'game_constants.dart';
import 'game_status.dart';
import 'tower_game.dart';

/// Holds every world-space component (background, blocks, hook, ground) and
/// owns the gameplay state machine that drives the round.
class TowerWorld extends Forge2DWorld with HasGameReference<TowerGame> {
  TowerWorld({required this.skinPicker})
      : hook = Hook(skinIndexProvider: skinPicker);

  /// Returns 1..6 — invoked every time we need a new block skin.
  final int Function() skinPicker;

  // Constructed up-front (not `late`) so that the game loop, which can run a
  // few frames before [onLoad] finishes, never crashes with a
  // LateInitializationError when [update] reads the hook.
  final Hook hook;
  final List<TowerBlock> _placedBlocks = [];
  TowerBlock? _activeBlock;

  /// Updated every frame in [update] — used by [TowerGame] to lerp the camera.
  double currentTopY = GameConstants.startBuildingTopY;

  /// Time the active block has spent below the settle speed threshold.
  double _settleTimer = 0;
  double _fallTimer = 0;

  /// Notifies the score widget without rebuilding the whole game.
  final ValueNotifier<int> score = ValueNotifier(0);

  /// Notifies overlays.
  final ValueNotifier<TowerGameStatus> status =
      ValueNotifier(TowerGameStatus.ready);

  bool _secondChanceUsedThisRun = false;
  bool secondChanceAvailable = false;

  /// Slow-hook boost active flag and remaining seconds.
  double _slowHookSecondsRemaining = 0;
  static const _slowHookFactor = 1.8; // multiplies the half period

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(SkyBackground());
    await add(GroundDecal());
    await add(Ground());
    await add(StartBuilding());
    await add(hook);
    await add(CloudLayer());
  }

  /// Begin a new round (called from [TowerGame] after onLoad).
  void startRound({bool slowHookEnabled = false}) {
    _placedBlocks.clear();
    _activeBlock = null;
    _settleTimer = 0;
    _fallTimer = 0;
    score.value = 0;
    currentTopY = GameConstants.startBuildingTopY;
    hook.topY = currentTopY;
    hook.halfPeriod = GameConstants.hookInitialHalfPeriod;
    _secondChanceUsedThisRun = false;
    if (slowHookEnabled) {
      _slowHookSecondsRemaining = 6.0;
    }
    status.value = TowerGameStatus.swinging;
  }

  /// Player tapped — drop the swinging block. No-op unless we're swinging.
  void dropBlock() {
    if (status.value != TowerGameStatus.swinging || !hook.hasBlock) return;
    final spawnPos = Vector2(
      hook.currentX,
      hook.blockY + GameConstants.blockHeight / 2,
    );
    final velocity = Vector2(hook.currentVelocityX, 0);
    final block = TowerBlock(
      skinIndex: skinPicker(),
      spawnPosition: spawnPos,
      spawnVelocity: velocity,
      spawnAngularVelocity: 0,
    );
    _activeBlock = block;
    add(block);
    hook.releaseBlock();
    _settleTimer = 0;
    _fallTimer = 0;
    status.value = TowerGameStatus.falling;
  }

  /// Pause / resume the world. Setting `paused` on the game also stops Box2D
  /// from stepping, so this just flips the status enum for the overlay.
  void setPaused(bool value) {
    if (value) {
      if (status.value == TowerGameStatus.swinging ||
          status.value == TowerGameStatus.falling) {
        status.value = TowerGameStatus.paused;
      }
    } else {
      if (status.value == TowerGameStatus.paused) {
        // Resume in whichever sub-state the block is in.
        status.value = _activeBlock != null
            ? TowerGameStatus.falling
            : TowerGameStatus.swinging;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // `ready` covers the small window between the world being mounted and
    // [TowerGame.onLoad] calling [startRound] — touching the hook before its
    // own onLoad has finished is fine for plain field assignments, but we
    // still skip work to avoid surprises.
    if (status.value == TowerGameStatus.ready ||
        status.value == TowerGameStatus.paused ||
        status.value == TowerGameStatus.gameOver) {
      return;
    }

    if (_slowHookSecondsRemaining > 0) {
      _slowHookSecondsRemaining = math.max(0, _slowHookSecondsRemaining - dt);
      hook.halfPeriod = _baseHalfPeriod() * _slowHookFactor;
    } else {
      hook.halfPeriod = _baseHalfPeriod();
    }

    // Track current top from the highest placed block (smallest Y).
    var top = GameConstants.startBuildingTopY;
    for (final b in _placedBlocks) {
      final t = b.topY;
      if (t < top) top = t;
    }
    if (_activeBlock != null && _activeBlock!.placed) {
      final t = _activeBlock!.topY;
      if (t < top) top = t;
    }
    currentTopY = top;
    hook.topY = currentTopY;

    if (status.value == TowerGameStatus.falling && _activeBlock != null) {
      _evaluateFalling(dt);
    }
  }

  double _baseHalfPeriod() {
    final placed = _placedBlocks.length;
    final v = GameConstants.hookInitialHalfPeriod -
        placed * GameConstants.hookSpeedUpPerBlock;
    return math.max(GameConstants.hookMinHalfPeriod, v);
  }

  void _evaluateFalling(double dt) {
    final block = _activeBlock!;
    if (!block.isMounted) return;
    final body = block.body;
    final v = body.linearVelocity;
    final speed = v.length;

    _fallTimer += dt;

    if (speed < GameConstants.settleSpeedThreshold) {
      _settleTimer += dt;
    } else {
      _settleTimer = 0;
    }

    final settled = _settleTimer >= GameConstants.settleHoldSeconds;
    final timedOut = _fallTimer >= GameConstants.settleTimeoutSeconds;
    final fellThrough = body.position.y > GameConstants.groundTopY - 0.4;

    if (fellThrough) {
      _handleFail();
      return;
    }
    if (settled || timedOut) {
      _handleLanding();
    }
  }

  void _handleLanding() {
    final block = _activeBlock!;
    final blockTop = block.topY;
    final blockX = block.body.position.x;

    // Find the highest support beneath us (start building counts as a wide
    // platform, otherwise we measure overlap with the topmost block).
    final supportTop = _findSupportTopAt(blockX, exclude: block);
    final supportingBlock = _findTopBlock(exclude: block);

    final landedAboveSomething = blockTop < supportTop + 0.05;
    final overlap = supportingBlock == null
        ? GameConstants.blockWidth // start building is huge
        : _horizontalOverlap(block, supportingBlock);
    final tilt = block.body.angle.abs();

    final tooMuchTilt = tilt > 0.7; // ~40 degrees
    final tooLittleOverlap = overlap < GameConstants.minOverlapToCount;

    if (!landedAboveSomething || tooMuchTilt || tooLittleOverlap) {
      _handleFail();
      return;
    }

    block.placed = true;
    _placedBlocks.add(block);
    score.value = _placedBlocks.length * GameConstants.baseRewardPerBlock;
    _activeBlock = null;
    _settleTimer = 0;
    _fallTimer = 0;

    // Attach a fresh block to the hook for the next swing.
    hook.attachNewBlock();
    status.value = TowerGameStatus.swinging;
  }

  void _handleFail() {
    if (secondChanceAvailable && !_secondChanceUsedThisRun) {
      _secondChanceUsedThisRun = true;
      secondChanceAvailable = false;
      // Remove the failing block and resume swinging with a new one.
      final block = _activeBlock;
      _activeBlock = null;
      if (block != null && block.isMounted) {
        block.removeFromParent();
      }
      hook.attachNewBlock();
      status.value = TowerGameStatus.swinging;
      _settleTimer = 0;
      _fallTimer = 0;
      return;
    }
    status.value = TowerGameStatus.gameOver;
  }

  TowerBlock? _findTopBlock({TowerBlock? exclude}) {
    TowerBlock? top;
    var minY = double.infinity;
    for (final b in _placedBlocks) {
      if (identical(b, exclude)) continue;
      final y = b.topY;
      if (y < minY) {
        minY = y;
        top = b;
      }
    }
    return top;
  }

  /// Returns the highest "y" (smallest value) under [x] from existing geometry.
  double _findSupportTopAt(double x, {TowerBlock? exclude}) {
    final hw = GameConstants.startBuildingWidth / 2;
    var best = double.infinity;
    if (x.abs() <= hw) {
      best = GameConstants.startBuildingTopY;
    }
    for (final b in _placedBlocks) {
      if (identical(b, exclude)) continue;
      final dx = (b.body.position.x - x).abs();
      if (dx < GameConstants.blockWidth / 2 + 0.1) {
        final y = b.topY;
        if (y < best) best = y;
      }
    }
    return best;
  }

  double _horizontalOverlap(TowerBlock a, TowerBlock b) {
    final aLeft = a.body.position.x - GameConstants.blockWidth / 2;
    final aRight = a.body.position.x + GameConstants.blockWidth / 2;
    final bLeft = b.body.position.x - GameConstants.blockWidth / 2;
    final bRight = b.body.position.x + GameConstants.blockWidth / 2;
    final overlap =
        math.min(aRight, bRight) - math.max(aLeft, bLeft);
    return overlap.clamp(0, GameConstants.blockWidth).toDouble();
  }
}
