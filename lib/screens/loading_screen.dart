import 'dart:async';

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../app/app_assets.dart';
import 'main_menu_screen.dart';

/// Initial splash that plays a looping promo video and shows a 4-state
/// progress bar while heavy assets warm up. The bar only starts moving once
/// the video is actually playing so the two stay visually in sync.
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
  bool _hasNavigated = false;

  late final AnimationController _progressController;

  /// Minimum time the splash stays on-screen (so the loading video has a
  /// chance to actually be enjoyed even on a fast phone).
  static const _minDuration = Duration(milliseconds: 5000);

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
      duration: _minDuration,
    );

    _initialise();
  }

  Future<void> _initialise() async {
    final start = DateTime.now();
    Flame.images.prefix = '';

    // 1) Initialise the videos and start them playing BEFORE we show the
    //    progress bar, so the bar does not race ahead of the video.
    await _initVideos();
    if (!mounted) return;
    setState(() => _videosReady = true);

    // Give the engine one frame to actually display the first video frame
    // before kicking off the bar animation.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // 2) Start the bar animation in parallel with asset preloading.
    final barFuture = _progressController.forward();
    final assetsFuture = _preloadGameAssets();

    await Future.wait([assetsFuture]);
    await barFuture;

    // 3) Ensure the splash is visible for at least [_minDuration].
    final elapsed = DateTime.now().difference(start);
    if (elapsed < _minDuration) {
      await Future<void>.delayed(_minDuration - elapsed);
    }

    // 4) Linger briefly on full bar so the user clearly sees state 4.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    _goToMenu();
  }

  Future<void> _initVideos() async {
    try {
      final portrait =
          VideoPlayerController.asset(AppAssets.loadingVideoPortrait);
      final landscape =
          VideoPlayerController.asset(AppAssets.loadingVideoLandscape);
      _portraitVideo = portrait;
      _landscapeVideo = landscape;

      await Future.wait([portrait.initialize(), landscape.initialize()]);

      // Configure looping/volume sequentially before playback so the first
      // frame shown is already part of a real, looping playback.
      await portrait.setLooping(true);
      await portrait.setVolume(0);
      await landscape.setLooping(true);
      await landscape.setVolume(0);

      await portrait.play();
      await landscape.play();
    } catch (e, st) {
      debugPrint('LoadingScreen: video init failed: $e\n$st');
    }
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
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              // Show the bar only once the video is actually playing so it
              // never visually finishes before the splash even starts.
              if (_videosReady)
                Align(
                  alignment: const Alignment(0, 0.85),
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      final progress = _progressController.value;
                      // Snap into 4 discrete bar states (1..4) like the artwork.
                      final state = (progress * 4).clamp(0, 4).floor();
                      final visibleState = state.clamp(1, 4);
                      return _LoadingBar(state: visibleState);
                    },
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
  const _LoadingBar({required this.state});

  final int state;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.shortestSide * 0.7;
    return Image.asset(
      AppAssets.loadingBar(state),
      width: width,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }
}
