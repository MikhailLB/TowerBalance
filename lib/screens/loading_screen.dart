import 'dart:async';

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../app/app_assets.dart';
import 'main_menu_screen.dart';

/// Branded loading splash. Plays the orientation-matched intro video and
/// animates the 4-state engraved progress bar; once both the bar animation
/// and the optional [routeFuture] have completed, navigates to the resolved
/// page.
///
/// Doubles as the splash for the gray boot flow. When [routeFuture],
/// [contentReady], and/or [keepAsUnderlay] are passed (by `EntryGate`), the
/// screen holds itself visible until both the bar animation has completed
/// AND the gray pipeline has resolved a destination AND any underlay has
/// reported first paint.
///
/// Video lifecycle mirrors the working TowerFalls implementation:
///   • a single controller is lazy-loaded on the FIRST [didChangeDependencies]
///     pass and on every subsequent orientation change.
///   • the previous controller is disposed only AFTER the new one is fully
///     bound to a Surface (prevents the "black flash" on rotation).
///   • the progress bar appears as soon as the screen is ready (video bound
///     or load failed) — no extra delay.
class LoadingScreen extends StatefulWidget {
  final Future<WidgetBuilder>? routeFuture;
  final Future<void>? contentReady;
  // Resolves to true when the resolved widget is something we MUST keep
  // mounted (so it doesn't lose state on handover — i.e. WebView). When
  // false / null we fall back to Navigator.pushReplacement.
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
  // Hard ceiling we wait for [contentReady]. If the underlay never signals
  // (e.g. silent WebView crash) the splash still hands over so the user is
  // not stuck on a 100% progress bar forever.
  static const Duration _contentReadyDeadline = Duration(seconds: 12);

  // Bar duration. After it completes we ALSO require the optional gray gates
  // to have settled before navigating.
  static const Duration _barDuration = Duration(milliseconds: 4500);

  // Minimum on-screen time for the splash. Stops the bar from "flickering"
  // off the screen on very fast cold-starts (and gives the route + content
  // gates a chance to resolve when they're nearly-instant).
  static const Duration _minSplashDuration = Duration(milliseconds: 6000);

  VideoPlayerController? _video;
  Orientation? _videoOrientation;
  bool _videoLoading = false;
  bool _videoFailed = false;

  late final AnimationController _progress;
  bool _progressStarted = false;
  bool _assetsPreloadStarted = false;
  DateTime? _splashStart;

  bool _navigated = false;

  WidgetBuilder? _resolvedBuilder;
  bool _routeReady = false;
  bool _contentReady = false;
  bool? _keepDecision;
  bool _useUnderlay = false;
  bool _splashVisible = true;

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

    _progress = AnimationController(
      vsync: this,
      duration: _barDuration,
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _maybeGoNext();
      });

    _wireGraySignals();
  }

  void _wireGraySignals() {
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
        _maybeGoNext();
      }).catchError((err, st) {
        debugPrint('[LoadingScreen] route resolver failed: $err\n$st');
        if (!mounted) return;
        setState(() => _routeReady = true);
        _maybeGoNext();
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
        _maybeGoNext();
      }).catchError((err) {
        debugPrint('[LoadingScreen] contentReady error: $err');
        if (!mounted) return;
        setState(() => _contentReady = true);
        _maybeGoNext();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.of(context).orientation;
    if (!_videoLoading && _videoOrientation != orientation) {
      _loadVideo(orientation);
    }
  }

  Future<void> _loadVideo(Orientation orientation) async {
    _videoLoading = true;
    final path = orientation == Orientation.landscape
        ? AppAssets.loadingVideoLandscape
        : AppAssets.loadingVideoPortrait;

    final previous = _video;
    final controller = VideoPlayerController.asset(path);
    try {
      await controller.initialize().timeout(const Duration(seconds: 6));
      await controller.setLooping(true);
      await controller.setVolume(0.0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _video = controller;
        _videoOrientation = orientation;
        _videoFailed = false;
      });
      // Dispose the previous orientation's controller AFTER swapping so
      // there's never a frame where both are nil.
      await previous?.dispose();
      _startProgressIfNeeded();
      _startPreloadIfNeeded();
    } catch (e, st) {
      debugPrint('Loading video failed ($path): $e\n$st');
      await controller.dispose();
      if (mounted) {
        setState(() {
          _videoOrientation = orientation;
          _videoFailed = true;
        });
      }
      _startProgressIfNeeded();
      _startPreloadIfNeeded();
    } finally {
      _videoLoading = false;
    }
  }

  void _startProgressIfNeeded() {
    if (_progressStarted) return;
    _progressStarted = true;
    _splashStart = DateTime.now();
    _progress.forward();
  }

  void _startPreloadIfNeeded() {
    if (_assetsPreloadStarted) return;
    _assetsPreloadStarted = true;
    unawaited(_preloadGameAssets());
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

  void _maybeGoNext() {
    if (_navigated) return;
    if (_progress.status != AnimationStatus.completed) return;
    if (!_routeReady) return;
    if (!_contentReady) return;
    // Enforce minimum on-screen time before handing over.
    final start = _splashStart;
    if (start != null) {
      final remaining = _minSplashDuration - DateTime.now().difference(start);
      if (remaining > Duration.zero) {
        Future.delayed(remaining, _maybeGoNext);
        return;
      }
    }
    _goNext();
  }

  Future<void> _goNext() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    bool keep = false;
    final keepFuture = widget.keepAsUnderlay;
    if (keepFuture != null) {
      try {
        keep = await keepFuture
            .timeout(const Duration(milliseconds: 500), onTimeout: () => false);
      } catch (_) {
        keep = false;
      }
    }
    if (!mounted) return;

    if (keep && _resolvedBuilder != null) {
      // Underlay mode: the resolved widget mounts under the splash; we just
      // fade the splash out and dispose its heavy bits.
      setState(() => _useUnderlay = true);
      return;
    }

    final builder = _resolvedBuilder ?? (_) => const MainMenuScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondary) =>
            Builder(builder: builder),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _disposeSplashAssets() async {
    final video = _video;
    _video = null;
    try {
      _progress.stop();
    } catch (_) {}
    try {
      await video?.pause();
    } catch (_) {}
    try {
      await video?.dispose();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.dispose();
    _progress.dispose();
    super.dispose();
  }

  Widget _buildSplash(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isPortrait = orientation == Orientation.portrait;
    final video = _video;
    final videoReady = video != null && video.value.isInitialized;
    final screenReady = videoReady || _videoFailed;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (videoReady)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: video.value.size.width,
              height: video.value.size.height,
              child: VideoPlayer(video),
            ),
          )
        else
          const ColoredBox(color: Colors.black),
        // The bar appears as soon as the screen is "ready" (either the video
        // is bound or load definitively failed) — no extra delay.
        // Use Positioned for pixel-perfect bottom placement in both
        // orientations; landscape bar sits closer to the physical edge.
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: screenReady ? 1 : 0,
          child: Positioned(
            left: 0,
            right: 0,
            bottom: isPortrait ? 6 : 2,
            child: Center(
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  final state = (_progress.value * 4)
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Single stable widget tree so the underlay (e.g. BrowserShell hosting a
    // WebView) keeps the same Element across the splash → handover transition
    // and never gets remounted.
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
