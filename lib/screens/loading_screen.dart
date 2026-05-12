import 'dart:async';

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../app/app_assets.dart';
import 'main_menu_screen.dart';

/// Branded loading splash. Plays a looping promo video (portrait/landscape)
/// and animates a 4-state engraved progress bar while heavy assets warm up.
///
/// Doubles as the splash for the gray boot flow: when [routeFuture],
/// [contentReady], and/or [keepAsUnderlay] are passed (by `EntryGate`), the
/// screen holds itself visible until both the bar animation has completed
/// and the gray pipeline has resolved a destination.
///
///   • [routeFuture]     — completes with the widget builder for the next
///                         screen (or `null` to fall back to [MainMenuScreen]).
///   • [contentReady]    — completes when the resolved widget has actually
///                         painted its first frame (BrowserShell signals this
///                         on `onPageFinished`). When omitted the splash
///                         treats content as ready immediately.
///   • [keepAsUnderlay]  — when it resolves to `true`, the resolved widget is
///                         mounted UNDER the splash; the splash then fades
///                         out without a route swap (preserves WebView state).
///                         Otherwise navigation uses `pushReplacement`.
class LoadingScreen extends StatefulWidget {
  final Future<WidgetBuilder>? routeFuture;
  final Future<void>? contentReady;
  final Future<bool>? keepAsUnderlay;

  const LoadingScreen({
    super.key,
    this.routeFuture,
    this.contentReady,
    this.keepAsUnderlay,
  });

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

  // Gray-flow gating state.
  WidgetBuilder? _resolvedBuilder;
  bool _routeReady = false;
  bool _contentReady = false;
  bool? _keepDecision;
  bool _useUnderlay = false;
  bool _splashVisible = true;

  static const _minDuration = Duration(milliseconds: 6000);
  static const _barDelay = Duration(milliseconds: 120);
  static const _barDuration = Duration(milliseconds: 4500);

  // Hard deadline for [contentReady]; if the underlay never reports painted
  // (silent WebView crash etc.) we still hand over instead of stalling on
  // a full progress bar forever.
  static const _contentReadyDeadline = Duration(seconds: 12);

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

    // Wire gray-flow signals (no-op when running in plain host mode).
    final routeFuture = widget.routeFuture;
    if (routeFuture == null) {
      _routeReady = true;
    } else {
      routeFuture.then((builder) {
        if (!mounted) return;
        setState(() {
          _resolvedBuilder = builder;
          _routeReady = true;
        });
      }).catchError((err, st) {
        debugPrint('[LoadingScreen] route resolver failed: $err\n$st');
        if (!mounted) return;
        setState(() => _routeReady = true);
      });
    }

    final keep = widget.keepAsUnderlay;
    if (keep == null) {
      _keepDecision = false;
    } else {
      keep.then((v) {
        if (!mounted) return;
        setState(() => _keepDecision = v);
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _keepDecision = false);
      });
    }

    final ready = widget.contentReady;
    if (ready == null) {
      _contentReady = true;
    } else {
      ready.timeout(_contentReadyDeadline, onTimeout: () {
        debugPrint('[LoadingScreen] contentReady timeout — handing over');
      }).then((_) {
        if (!mounted) return;
        setState(() => _contentReady = true);
      }).catchError((err) {
        debugPrint('[LoadingScreen] contentReady error: $err');
        if (!mounted) return;
        setState(() => _contentReady = true);
      });
    }

    _initialise();
  }

  Future<void> _initialise() async {
    final start = DateTime.now();
    Flame.images.prefix = '';

    await _initVideos();
    if (!mounted) return;
    setState(() => _videosReady = true);

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

    // Gray-flow: hold the splash until the pipeline + first-paint have settled.
    await _waitForGrayHandover();
    if (!mounted) return;

    _goNext();
  }

  /// Polls the gray-flow state flags until both the route is known AND
  /// (for web flows) the underlay has reported first paint. Cheap busy-loop
  /// because the flags are flipped from `then()` callbacks and a single
  /// `Future.delayed` per iteration is enough to yield to the event loop.
  Future<void> _waitForGrayHandover() async {
    while (mounted && !(_routeReady && _contentReady)) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _initVideos() async {
    try {
      final portrait =
          VideoPlayerController.asset(AppAssets.loadingVideoPortrait);
      final landscape =
          VideoPlayerController.asset(AppAssets.loadingVideoLandscape);

      await Future.wait([portrait.initialize(), landscape.initialize()]);

      portrait.setLooping(true);
      landscape.setLooping(true);
      portrait.setVolume(0);
      landscape.setVolume(0);

      try {
        await portrait.play();
      } catch (_) {}
      try {
        await landscape.play();
      } catch (_) {}

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

  void _restartIfFinished(VideoPlayerController c) {
    final value = c.value;
    if (!value.isInitialized) return;
    if (value.isPlaying) return;
    if (value.position < value.duration) return;
    c.seekTo(Duration.zero);
    c.play();
  }

  void _kickIfNotPlaying(VideoPlayerController? c) {
    if (c == null) return;
    if (!c.value.isInitialized) return;
    if (c.value.isPlaying) return;
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
    try {
      GoogleFonts.bangers();
      GoogleFonts.fredoka();
      await GoogleFonts.pendingFonts(<TextStyle>[
        GoogleFonts.bangers(),
        GoogleFonts.fredoka(),
      ]);
    } catch (e) {
      debugPrint('LoadingScreen: Google Fonts preload failed: $e');
    }
  }

  Future<void> _goNext() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    bool keep = false;
    final keepFuture = widget.keepAsUnderlay;
    if (keepFuture != null) {
      try {
        keep = await keepFuture.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => false,
        );
      } catch (_) {
        keep = false;
      }
    }
    if (!mounted) return;

    if (keep && _resolvedBuilder != null) {
      // Underlay mode: the resolved widget is mounted under the splash; just
      // fade the splash out and dispose its heavy bits.
      setState(() => _useUnderlay = true);
      return;
    }

    final builder = _resolvedBuilder ?? (_) => const MainMenuScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondary) =>
            Builder(builder: builder),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _disposeSplashAssets() async {
    final portrait = _portraitVideo;
    final landscape = _landscapeVideo;
    _portraitVideo = null;
    _landscapeVideo = null;
    try {
      _progressController.stop();
    } catch (_) {}
    try {
      await portrait?.pause();
    } catch (_) {}
    try {
      await landscape?.pause();
    } catch (_) {}
    try {
      await portrait?.dispose();
    } catch (_) {}
    try {
      await landscape?.dispose();
    } catch (_) {}
    if (mounted) setState(() {});
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

  Widget _buildSplash(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;
        final controller = isPortrait ? _portraitVideo : _landscapeVideo;
        if (controller != null && controller.value.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _kickIfNotPlaying(controller);
          });
        }
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
                bottom: isPortrait ? 4 : 2,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Single, stable widget tree so the underlay (e.g. BrowserShell hosting a
    // WebView) keeps the same Element across the splash → handover transition
    // and never gets remounted (which would tear down the WebView and lose
    // its loading state). The underlay only mounts when the gray flow asked
    // for it (`keepAsUnderlay == true`); otherwise navigation is via
    // [Navigator.pushReplacement] inside [_goNext].
    final renderUnderlay = _keepDecision == true && _resolvedBuilder != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (renderUnderlay)
            Positioned.fill(child: Builder(builder: _resolvedBuilder!)),
          if (_splashVisible)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: !_useUnderlay,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _useUnderlay ? 0.0 : 1.0,
                  onEnd: () async {
                    if (!mounted || !_splashVisible) return;
                    if (_useUnderlay) {
                      setState(() => _splashVisible = false);
                      await _disposeSplashAssets();
                    }
                  },
                  child: _buildSplash(context),
                ),
              ),
            ),
        ],
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
    final width = isPortrait ? size.width * 0.7 : size.height * 0.4;
    return Image.asset(
      AppAssets.loadingBar(state),
      width: width,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }
}
