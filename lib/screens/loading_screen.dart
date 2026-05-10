import 'dart:async';

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../app/app_assets.dart';
import 'main_menu_screen.dart';

/// Initial splash screen that plays a looping promo video and animates a
/// 4-state progress bar while the heavy assets are warming up in the cache.
///
/// The screen is the only place in the app that supports both portrait and
/// landscape — once we hand off to the menu we lock to portrait again.
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

  late final AnimationController _progressController;
  Timer? _navigationTimer;

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
      duration: const Duration(milliseconds: 4500),
    );

    _initialise();
  }

  Future<void> _initialise() async {
    // Kick off the video init and the asset warm-up in parallel so the bar
    // tracks real work rather than a fake timer.
    final portrait = VideoPlayerController.asset(AppAssets.loadingVideoPortrait);
    final landscape =
        VideoPlayerController.asset(AppAssets.loadingVideoLandscape);
    _portraitVideo = portrait;
    _landscapeVideo = landscape;

    final videoFuture = Future.wait([
      portrait.initialize(),
      landscape.initialize(),
    ]).then((_) {
      portrait
        ..setLooping(true)
        ..setVolume(0)
        ..play();
      landscape
        ..setLooping(true)
        ..setVolume(0)
        ..play();
      if (mounted) setState(() => _videosReady = true);
    });

    final assetsFuture = _preloadGameAssets();

    _progressController.forward();
    await Future.wait([videoFuture, assetsFuture]);
    // Make sure the bar visibly reaches state 4 even if work finished early.
    if (_progressController.value < 1.0) {
      await _progressController.forward();
    } else {
      // Already finished animating; just wait a beat so users see state 4.
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    _goToMenu();
  }

  Future<void> _preloadGameAssets() async {
    // Use Flame's shared image cache (no `assets/` prefix) so anything we
    // request later via Flame.images is already decoded.
    Flame.images.prefix = '';
    final paths = <String>[
      AppAssets.sky,
      AppAssets.ground,
      AppAssets.cloud,
      AppAssets.hook,
      AppAssets.button,
      AppAssets.startBg,
      AppAssets.startBuilding,
      AppAssets.logo,
      AppAssets.logoName,
      ...AppAssets.allBlocks,
      for (var i = 1; i <= 4; i++) AppAssets.loadingBar(i),
    ];
    await Future.wait(paths.map((p) => Flame.images.load(p)));
  }

  void _goToMenu() {
    if (!mounted) return;
    _navigationTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondary) => const MainMenuScreen(),
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
    _navigationTimer?.cancel();
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
              if (_videosReady && controller != null)
                _FullCoverVideo(controller: controller)
              else
                Container(color: Colors.black),
              // Subtle bottom gradient so the bar stays readable on bright frames.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
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
