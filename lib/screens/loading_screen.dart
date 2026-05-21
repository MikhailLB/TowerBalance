import 'dart:async';
import 'dart:math' show min;

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../app/app_assets.dart';
import '../app/app_orientation.dart';
import 'main_menu_screen.dart';

/// Initial splash that plays a looping promo video and shows a 4-state
/// progress bar while heavy assets warm up.
///
/// Video lifecycle (kept deliberately minimal — earlier "keep-alive" timers
/// that called play()/seekTo() every 250 ms were the actual cause of the
/// stutter):
///   1. Build the controller from the asset.
///   2. await initialize().
///   3. setLooping(true), setVolume(0).
///   4. Call play() IMMEDIATELY (sync, in init flow). Some Android codecs
///      need play() before the texture is bound; calling it now means the
///      first frame is already on its way by the time the widget mounts.
///   5. Each time the user rotates the device (or on first build), we also
///      kick play() inside the OrientationBuilder via a post-frame callback —
///      catches the case where the codec held off until the surface was bound.
///   6. A single listener restarts the video only when the platform reports
///      it has actually finished, instead of polling.
class LoadingScreen extends StatefulWidget {
  /// Optional gray-flow integration:
  ///
  /// When [routeFuture] is non-null, the splash navigates to the resolved
  /// [WidgetBuilder] instead of [MainMenuScreen] when the bar animation
  /// finishes (and after [contentReady] resolves, if provided).
  ///
  /// When [keepAsUnderlay] resolves to `true` the resolved widget is mounted
  /// as a sibling beneath the splash (so it can paint while the bar finishes)
  /// and the splash simply fades out instead of pushing a new route. This is
  /// what the gray BrowserShell flow uses to keep the WKWebView state alive
  /// across the splash → ready handover. For routes that don't care
  /// (MainMenu, NetworkPause), [keepAsUnderlay] can be null/false and the
  /// classic [Navigator.pushReplacement] path is used.
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

  static const _minDuration = Duration(milliseconds: 6000);
  // Bar appears almost as soon as the splash background does — earlier feedback
  // was that the long delay made it feel like the splash had stalled.
  static const _barDelay = Duration(milliseconds: 120);
  static const _barDuration = Duration(milliseconds: 4500);

  // Hard ceiling we wait for [widget.contentReady]. If the underlay never
  // signals (e.g. WebView crashed silently) the splash still hands over so
  // the user is never stuck on the loading bar forever.
  static const _contentReadyDeadline = Duration(seconds: 6);

  WidgetBuilder? _resolvedBuilder;
  bool _routeResolved = false;
  bool _contentReady = false;
  bool? _keepDecision;
  bool _splashVisible = true;
  bool _underlayFade = false;

  @override
  void initState() {
    super.initState();
    setOrientationsForLoadingScreens();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _progressController = AnimationController(
      vsync: this,
      duration: _barDuration,
    );

    _wireRouteFuture();
    _wireContentReady();
    _wireKeepDecision();

    _initialise();
  }

  void _wireRouteFuture() {
    final future = widget.routeFuture;
    if (future == null) {
      _routeResolved = true;
      return;
    }
    future.then((builder) {
      if (!mounted) return;
      setState(() {
        _resolvedBuilder = builder;
        _routeResolved = true;
      });
    }).catchError((err, st) {
      debugPrint('LoadingScreen: route future failed: $err\n$st');
      if (!mounted) return;
      setState(() => _routeResolved = true);
    });
  }

  void _wireContentReady() {
    final ready = widget.contentReady;
    if (ready == null) {
      _contentReady = true;
      return;
    }
    ready.timeout(_contentReadyDeadline, onTimeout: () {
      debugPrint('LoadingScreen: contentReady timeout — handing over');
    }).then((_) {
      if (!mounted) return;
      setState(() => _contentReady = true);
    }).catchError((err) {
      debugPrint('LoadingScreen: contentReady error: $err');
      if (!mounted) return;
      setState(() => _contentReady = true);
    });
  }

  void _wireKeepDecision() {
    final keep = widget.keepAsUnderlay;
    if (keep == null) {
      _keepDecision = false;
      return;
    }
    keep.then((v) {
      if (!mounted) return;
      setState(() => _keepDecision = v);
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _keepDecision = false);
    });
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

    // Gray-flow extension: wait until both the resolved builder AND any
    // contentReady future are settled before handing over. Capped by the
    // deadline above so a flaky web payload still releases the splash.
    while (mounted && (!_routeResolved || !_contentReady)) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 300));
    _handoff();
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
      debugPrint(
        'LoadingScreen: landscape dur=${landscape.value.duration} '
        'size=${landscape.value.size}',
      );

      portrait.setLooping(true);
      landscape.setLooping(true);
      portrait.setVolume(0);
      landscape.setVolume(0);

      // Kick playback right away. If the codec needs the texture bound first
      // it will silently no-op; the OrientationBuilder kick below covers that.
      try {
        await portrait.play();
        debugPrint(
            'LoadingScreen: portrait play() OK isPlaying=${portrait.value.isPlaying}');
      } catch (e) {
        debugPrint('LoadingScreen: portrait play() failed: $e');
      }
      try {
        await landscape.play();
        debugPrint(
            'LoadingScreen: landscape play() OK isPlaying=${landscape.value.isPlaying}');
      } catch (e) {
        debugPrint('LoadingScreen: landscape play() failed: $e');
      }

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

  /// Idempotent kick-start used when the surface (texture) is bound to the
  /// widget tree. Some Android codecs only actually start delivering frames
  /// once a Surface is attached, and play() called before that is a no-op.
  void _kickIfNotPlaying(VideoPlayerController? c, String label) {
    if (c == null) return;
    if (!c.value.isInitialized) return;
    if (c.value.isPlaying) return;
    debugPrint('LoadingScreen: kick $label (post-bind play)');
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
    // Preload Google Fonts referenced by AppTextStyles. Without this the very
    // first frame of MainMenuScreen renders with the system fallback font and
    // visibly snaps to Bangers/Fredoka a few hundred ms later.
    try {
      // Touching each style triggers a runtime fetch; pendingFonts() awaits
      // every fetch currently in flight.
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

  /// Either fades the splash out (underlay mode — the resolved widget is
  /// already mounted beneath) or pushes the resolved widget as a new top
  /// level route. Falls back to [MainMenuScreen] when no builder was
  /// supplied (classic standalone flow).
  Future<void> _handoff() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    final builder = _resolvedBuilder ?? (_) => const MainMenuScreen();
    final keep = _keepDecision == true && _resolvedBuilder != null;

    if (keep) {
      // Underlay mode: just fade out — the builder is already mounted
      // beneath the splash in [build].
      setState(() => _underlayFade = true);
      return;
    }

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
    // Underlay mode: the resolved builder is mounted beneath the splash so it
    // can paint while the loading bar finishes (used by the gray BrowserShell
    // flow to keep the WKWebView alive across the handover).
    final renderUnderlay =
        _keepDecision == true && _resolvedBuilder != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (renderUnderlay)
            Positioned.fill(child: Builder(builder: _resolvedBuilder!)),
          if (_splashVisible)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _underlayFade ? 0.0 : 1.0,
                onEnd: () {
                  if (!mounted) return;
                  if (_underlayFade && _splashVisible) {
                    setState(() => _splashVisible = false);
                  }
                },
                child: AbsorbPointer(
                  absorbing: !_underlayFade,
                  child: _buildSplash(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSplash(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          final controller =
              isPortrait ? _portraitVideo : _landscapeVideo;
          // After the layout for this orientation has been laid out (and the
          // video Texture has been bound), kick play() in case the codec was
          // waiting for a surface.
          if (controller != null && controller.value.isInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _kickIfNotPlaying(
                controller,
                isPortrait ? 'portrait' : 'landscape',
              );
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
                  // On tablets (iPad) the bar width was too large — the image
                  // scaled up proportionally in height, pushing its top edge
                  // into the "LOADING" text baked into the video. We clamp
                  // the bottom so the bar stays near the screen edge on all
                  // devices. The safe-area bottom is included so nothing hides
                  // under the Home Indicator on notched / dynamic-island iPads.
                  bottom: MediaQuery.of(context).padding.bottom,
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
    // Cap width on tablets (iPads): a 70% width on a 768px+ screen produces
    // a very tall bar image that overlaps the "LOADING" text in the video.
    // 340 px is wide enough to look good on phones and small enough to stay
    // below the "LOADING" label on any iPad.
    final rawWidth = isPortrait ? size.width * 0.7 : size.height * 0.4;
    final width = min(rawWidth, 340.0);
    return Image.asset(
      AppAssets.loadingBar(state),
      width: width,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }
}
