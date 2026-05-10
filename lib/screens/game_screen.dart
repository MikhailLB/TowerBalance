import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../game/game_status.dart';
import '../game/tower_game.dart';
import '../main.dart';
import '../widgets/pixel_button.dart';

/// Hosts the [TowerGame] inside a [GameWidget] and adds Flutter-side overlays
/// for the HUD, pause menu and game over screen.
///
/// The heavy [GameWidget] is intentionally mounted *after* the navigation
/// transition is complete so the route push animation stays smooth and the
/// app cannot appear "frozen" while Flame is initialising.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  TowerGame? _game;
  late final math.Random _rand = math.Random();
  bool _scoreSubmitted = false;

  @override
  void initState() {
    super.initState();
    // Defer the Flame world creation until after the route transition has
    // finished painting. Otherwise we try to spin up Forge2D + load textures
    // mid-animation which can stall the UI thread for hundreds of ms.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() {
        _spawnGame(useSlowHook: false);
      });
    });
  }

  void _spawnGame({required bool useSlowHook}) {
    _scoreSubmitted = false;
    _game = TowerGame(
      skinPicker: _pickSkin,
      startWithSlowHook: useSlowHook,
    );
  }

  int _pickSkin() {
    final selected = progress.selectedSkin;
    final owned = progress.ownedSkins;
    if (selected != 0 && owned.contains(selected)) return selected;
    if (owned.isEmpty) return 1;
    return owned[_rand.nextInt(owned.length)];
  }

  Future<void> _onPause() async {
    _game?.setPaused(true);
  }

  void _onResume() {
    _game?.setPaused(false);
  }

  Future<void> _onUseSlowHook() async {
    final granted = await progress.consumeSlowHook();
    if (!granted) return;
    setState(() {
      _spawnGame(useSlowHook: true);
    });
  }

  Future<void> _onUseSecondChance() async {
    final granted = await progress.consumeSecondChance();
    if (!granted) return;
    _game?.requestSecondChance();
    _game?.setPaused(false);
  }

  Future<void> _onRestart() async {
    setState(() {
      _spawnGame(useSlowHook: false);
    });
  }

  Future<void> _onExit() async {
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _submitFinalScore(int score) async {
    if (_scoreSubmitted) return;
    _scoreSubmitted = true;
    await progress.reportScore(score);
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (game == null) {
          await _onExit();
          return;
        }
        final status = game.world.status.value;
        if (status == TowerGameStatus.swinging ||
            status == TowerGameStatus.falling) {
          game.setPaused(true);
        } else if (status == TowerGameStatus.paused ||
            status == TowerGameStatus.gameOver) {
          await _onExit();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.sky,
        body: game == null ? const _GameLoading() : _GameView(
          game: game,
          onPause: _onPause,
          onResume: _onResume,
          onRestart: _onRestart,
          onExit: _onExit,
          onUseSlowHook:
              progress.slowHookBoosts > 0 ? _onUseSlowHook : null,
          onUseSecondChance: _onUseSecondChance,
          submitFinalScore: _submitFinalScore,
        ),
      ),
    );
  }
}

class _GameLoading extends StatelessWidget {
  const _GameLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sky,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 4,
          ),
          const SizedBox(height: 18),
          Text('Building...', style: AppTextStyles.button(size: 22)),
        ],
      ),
    );
  }
}

class _GameView extends StatelessWidget {
  const _GameView({
    required this.game,
    required this.onPause,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
    required this.onUseSlowHook,
    required this.onUseSecondChance,
    required this.submitFinalScore,
  });

  final TowerGame game;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final VoidCallback? onUseSlowHook;
  final Future<void> Function() onUseSecondChance;
  final Future<void> Function(int score) submitFinalScore;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: GameWidget(
            key: ValueKey(game),
            game: game,
            backgroundBuilder: (_) => Container(color: AppColors.sky),
            loadingBuilder: (_) => const _GameLoading(),
            errorBuilder: (_, error) => Container(
              color: AppColors.sky,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load game:\n$error',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(size: 18),
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: game.world.score,
          builder: (context, score, _) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Hud(
                score: score,
                onPause: onPause,
                slowHooks: progress.slowHookBoosts,
                onUseSlowHook: onUseSlowHook,
              ),
            ),
          ),
        ),
        ValueListenableBuilder<TowerGameStatus>(
          valueListenable: game.world.status,
          builder: (context, status, _) {
            if (status == TowerGameStatus.paused) {
              return _PauseOverlay(onResume: onResume, onExit: onExit);
            }
            if (status == TowerGameStatus.gameOver) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await submitFinalScore(game.world.score.value);
              });
              return _GameOverOverlay(
                score: game.world.score.value,
                highScore: math.max(
                  progress.highScore,
                  game.world.score.value,
                ),
                secondChances: progress.secondChanceBoosts,
                onRestart: onRestart,
                onExit: onExit,
                onUseSecondChance:
                    progress.secondChanceBoosts > 0 &&
                            game.world.score.value > 0
                        ? () => onUseSecondChance()
                        : null,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.score,
    required this.onPause,
    required this.slowHooks,
    required this.onUseSlowHook,
  });

  final int score;
  final VoidCallback onPause;
  final int slowHooks;
  final VoidCallback? onUseSlowHook;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RoundButton(
          icon: Icons.pause_rounded,
          onPressed: onPause,
        ),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black26),
          ),
          child: Text(
            'Score $score',
            style: AppTextStyles.score(size: 22),
          ),
        ),
        const Spacer(),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _RoundButton(
              icon: Icons.speed_rounded,
              onPressed: onUseSlowHook,
              tint: onUseSlowHook == null
                  ? AppColors.panel
                  : AppColors.accent.withValues(alpha: 0.85),
            ),
            if (slowHooks > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    'x$slowHooks',
                    style: AppTextStyles.body(size: 11, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, this.onPressed, this.tint});

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint ?? AppColors.panel,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.text, size: 28),
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onExit});

  final VoidCallback onResume;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return _ModalScrim(
      child: _PanelCard(
        title: 'Paused',
        children: [
          PixelButton(label: 'Continue', onPressed: onResume),
          const SizedBox(height: 12),
          PixelButton(
            label: 'Main Menu',
            onPressed: onExit,
            color: PixelButtonColor.secondary,
          ),
        ],
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.score,
    required this.highScore,
    required this.secondChances,
    required this.onRestart,
    required this.onExit,
    required this.onUseSecondChance,
  });

  final int score;
  final int highScore;
  final int secondChances;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final VoidCallback? onUseSecondChance;

  @override
  Widget build(BuildContext context) {
    return _ModalScrim(
      child: _PanelCard(
        title: 'Game Over',
        children: [
          Text('Score $score', style: AppTextStyles.score(size: 26)),
          Text('Best $highScore',
              style: AppTextStyles.body(size: 16, color: AppColors.accent)),
          const SizedBox(height: 16),
          if (onUseSecondChance != null) ...[
            PixelButton(
              label: 'Second chance (x$secondChances)',
              onPressed: onUseSecondChance,
              fontSize: 18,
            ),
            const SizedBox(height: 12),
          ],
          PixelButton(label: 'Restart', onPressed: onRestart),
          const SizedBox(height: 12),
          PixelButton(
            label: 'Main Menu',
            onPressed: onExit,
            color: PixelButtonColor.secondary,
          ),
        ],
      ),
    );
  }
}

class _ModalScrim extends StatelessWidget {
  const _ModalScrim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: const [
          BoxShadow(blurRadius: 30, color: Colors.black54),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTextStyles.title(size: 36)),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}
