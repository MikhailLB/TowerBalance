import 'dart:async';

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../app/app_assets.dart';
import 'main_menu_screen.dart';

/// Initial splash that plays a looping promo video and shows a 4-state
/// progress bar while heavy assets warm up.
///
/// Video lifecycle (kept deliberately minimal — earlier "keep-alive" timers
/// that issued play()/seekTo() every 250 ms were the actual cause of the
/// video stuttering and freezing):
///   1. Build the controller from the asset.
///   2. await initialize().
///   3. setLooping(true) and setVolume(0).
///   4. After the widget is in the tree (post-frame callback), call play()
///      ONCE. Trust the codec from there.
///   5. As a defensive backup, attach a single listener that detects the
///      "playback finished" event the platform emits when looping isn't
///      honoured and re-issues seekTo(0) + play(). This fires at most twice
///      per loop, not on a polling timer.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _portraitVideo;
  VideoPlayerController? _landscapeVideo;
  bool _videosReady = false;
  bool _showBar = false;
  bool _hasNavigated = false;

  VoidCallback? _portraitListener;
  VoidCallback? _landscapeListener;

  late final AnimationController _progressController;

  static const _minDuration = Duration(milliseconds: 6000);
  static const _barDelay = Duration(milliseconds: 400);
  static const _barDuration = Duration(milliseconds: 4500);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _progressController = AnimationController(
      vsync: this,
      duration: _barDuration,
    );

    _initialise();
  }

  Future<void> _initialise() async {
    final start = DateTime.now();
    Flame.images.prefix = '';

    await _initVideos();
    if (!mounted) return;
    setState(() => _videosReady = true);

    // Start playback only once the texture is bound to a widget in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _portraitVideo?.play();
      _landscapeVideo?.play();
    });

    await Future<void>.delayed(_barDelay);
    if (!mounted) return;
    setState(() => _showBar = true);

    final barFuture = _progressController.forward();
    final assetsFuture = _preloadGameAssets();

    await Future.wait([barFuture, assetsFuture]);

    final elapsed = DateTime.now().difference(start);
    if (elapsed < _minDuration) {
      await Future<void>.delayed(_minDuration - elapsed);
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    _goToMenu();
  }

  Future<void> _initVideos() async {
    try {
      final portrait =
          VideoPlayerController.asset(AppAssets.loadingVideoPortrait);
      final landscape =
          VideoPlayerController.asset(AppAssets.loadingVideoLandscape);

      await Future.wait([portrait.initialize(), landscape.initialize()]);

      debugPrint(
        'LoadingScreen: portrait dur=${portrait.value.duration} '
        'size=${portrait.value.size}',
      );

      portrait.setLooping(true);
      landscape.setLooping(true);
      portrait.setVolume(0);
      landscape.setVolume(0);

      // Defensive loop fallback — fires only when the platform reports the
      // video has actually completed and was not auto-restarted by setLooping.
      _portraitListener = () => _restartIfFinished(portrait);
      _landscapeListener = () => _restartIfFinished(landscape);
      portrait.addListener(_portraitListener!);
      landscape.addListener(_landscapeListener!);

      _portraitVideo = portrait;
      _landscapeVideo = landscape;
    } catch (e, st) {
      debugPrint('LoadingScreen: video init failed: $e\n$st');
    }
  }

  /// Called by the controller's listener — restarts playback if and only if
  /// the video reports it just finished. Cheap and idempotent.
  void _restartIfFinished(VideoPlayerController c) {
    final value = c.value;
    if (!value.isInitialized) return;
    if (value.isPlaying) return;
    if (value.position < value.duration) return;
    c.seekTo(Duration.zero);
    c.play();
  }

  Future<void> _preloadGameAssets() async {
    Flame.images.prefix = '';
    final paths = <String>[
      AppAssets.sky,
      AppAssets.ground,
      AppAssets.cloud,
      AppAssets.hook,
      AppAssets.startBg,
      AppAssets.startBuilding,
      AppAssets.logo,
      AppAssets.logoName,
      ...AppAssets.allBlocks,
      for (var i = 1; i <= 4; i++) AppAssets.loadingBar(i),
    ];
    for (final p in paths) {
      try {
        await Flame.images.load(p);
      } catch (e) {
        debugPrint('LoadingScreen: failed to preload $p: $e');
      }
    }
  }

  void _goToMenu() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondary) =>
            const MainMenuScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    if (_portraitListener != null) {
      _portraitVideo?.removeListener(_portraitListener!);
    }
    if (_landscapeListener != null) {
      _landscapeVideo?.removeListener(_landscapeListener!);
    }
    _portraitVideo?.dispose();
    _landscapeVideo?.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          final controller =
              isPortrait ? _portraitVideo : _landscapeVideo;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (_videosReady &&
                  controller != null &&
                  controller.value.isInitialized)
                _FullCoverVideo(controller: controller)
              else
                Container(color: Colors.black),
              if (_showBar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).padding.bottom +
                      (isPortrait ? 56 : 14),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) {
                        final progress = _progressController.value;
                        final state = (progress * 4)
                            .clamp(0.0, 4.0)
                            .floor()
                            .clamp(1, 4);
                        return _LoadingBar(
                          state: state,
                          isPortrait: isPortrait,
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FullCoverVideo extends StatelessWidget {
  const _FullCoverVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.state, required this.isPortrait});

  final int state;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Smaller bar in landscape so it can't possibly cover hero artwork.
    final width = isPortrait ? size.width * 0.7 : size.height * 0.4;
    return Image.asset(
      AppAssets.loadingBar(state),
      width: width,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }
}
