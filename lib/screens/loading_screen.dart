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
/// Sequence:
/// 1. Black screen while video controllers initialise (typically <1s).
/// 2. Video appears and begins looping immediately.
/// 3. The 4-state loading bar fades in after a short pause (400ms) so the
///    user can clearly see the video start before the bar appears.
/// 4. Bar fills over ~4.5 s while the Flame image cache is preheated.
/// 5. After a minimum total splash time of 6s, fade into the main menu.
///
/// Video looping: `setLooping(true)` on some Android codecs briefly pauses at
/// the end before seeking, creating a black flash. We workaround this by
/// listening to the position and manually seeking to 0 when the video is within
/// 200 ms of its end.
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

    // Short pause so user sees the video moving before the bar appears.
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
      _portraitVideo = portrait;
      _landscapeVideo = landscape;

      await Future.wait([portrait.initialize(), landscape.initialize()]);

      // Seamless-loop workaround: manually seek to 0 when within 200 ms of end
      // instead of relying on the codec's built-in loop (which can flash black).
      portrait.addListener(() => _seamlessLoop(portrait));
      landscape.addListener(() => _seamlessLoop(landscape));

      portrait.setVolume(0);
      landscape.setVolume(0);

      await portrait.play();
      await landscape.play();
    } catch (e, st) {
      debugPrint('LoadingScreen: video init failed: $e\n$st');
    }
  }

  /// Seek the controller back to the start if it is within 200 ms of the end.
  void _seamlessLoop(VideoPlayerController c) {
    if (!c.value.isInitialized) return;
    final duration = c.value.duration;
    if (duration == Duration.zero) return;
    final remaining = duration - c.value.position;
    if (remaining.inMilliseconds <= 200 && remaining.inMilliseconds >= 0) {
      c.seekTo(Duration.zero);
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
    _portraitVideo?.removeListener(() => _seamlessLoop(_portraitVideo!));
    _portraitVideo?.dispose();
    _landscapeVideo?.removeListener(() => _seamlessLoop(_landscapeVideo!));
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
              // Subtle vignette at the bottom to make bar more readable.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black45],
                  ),
                ),
              ),
              if (_showBar)
                Align(
                  alignment: const Alignment(0, 0.85),
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      final progress = _progressController.value;
                      final state =
                          (progress * 4).clamp(0.0, 4.0).floor().clamp(1, 4);
                      return _LoadingBar(state: state);
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
