import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../config/gray_assets.dart';
import '../config/runtime_brand.dart';
import '../services/network_radar.dart';
import '../services/pulse_dispatch.dart';
import '../services/runtime_cache.dart';
import 'browser_shell.dart';

/// Custom permission prompt shown before opening the WebView. Plays a branded
/// background video (portrait + landscape) and renders Accept / Skip buttons
/// ~1 cm from the bottom of the screen via CustomPainter.
///
/// Video lifecycle (ported from TowerBalance LoadingScreen — prevents stutter):
///   1. Both portrait AND landscape controllers are initialised in initState.
///   2. Both are played immediately so the codec can bind to a texture early.
///   3. Each time the orientation changes the visible controller gets an extra
///      play() kick via addPostFrameCallback — catches codecs that only start
///      delivering frames after a Surface is attached.
///   4. A listener on each controller restarts it only when the platform
///      actually reports completion (instead of polling).
class NotifyOfferScreen extends StatefulWidget {
  final RuntimeCache cache;
  final PulseDispatch pulse;
  final NetworkRadar radar;
  final String destination;

  const NotifyOfferScreen({
    super.key,
    required this.cache,
    required this.pulse,
    required this.radar,
    required this.destination,
  });

  @override
  State<NotifyOfferScreen> createState() => _NotifyOfferScreenState();
}

class _NotifyOfferScreenState extends State<NotifyOfferScreen>
    with TickerProviderStateMixin {
  // Pre-initialised controllers — both created upfront so an orientation
  // switch is instant (no re-init stutter).
  VideoPlayerController? _portraitCtl;
  VideoPlayerController? _landscapeCtl;
  VoidCallback? _portraitListener;
  VoidCallback? _landscapeListener;

  bool _videosReady = false;
  bool _videoFailed = false;
  bool _busy = false;

  late final AnimationController _shimmer;
  late final AnimationController _pulse;

  // Fixed distance from the physical screen bottom so the buttons sit
  // roughly 1 cm from the edge in both portrait and landscape.
  static const double _buttonBottom = 40.0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _initBothVideos();
  }

  /// Initialises portrait + landscape controllers in parallel and starts
  /// playback immediately, matching TowerBalance's LoadingScreen approach.
  Future<void> _initBothVideos() async {
    final portraitPath = GrayAssets.notifyOfferVideoPortrait;
    final landscapePath = GrayAssets.notifyOfferVideoLandscape;

    if (portraitPath == null && landscapePath == null) {
      if (mounted) setState(() => _videoFailed = true);
      return;
    }

    try {
      VideoPlayerController? portrait;
      VideoPlayerController? landscape;

      final futures = <Future<void>>[];

      if (portraitPath != null) {
        portrait = VideoPlayerController.asset(portraitPath);
        futures.add(portrait.initialize());
      }
      if (landscapePath != null) {
        landscape = VideoPlayerController.asset(landscapePath);
        futures.add(landscape.initialize());
      }

      await Future.wait(futures);

      if (!mounted) {
        await portrait?.dispose();
        await landscape?.dispose();
        return;
      }

      for (final ctl in [portrait, landscape]) {
        if (ctl == null) continue;
        ctl.setLooping(true);
        ctl.setVolume(0);
        try {
          await ctl.play();
        } catch (_) {}
      }

      _portraitListener = () => _restartIfFinished(portrait);
      _landscapeListener = () => _restartIfFinished(landscape);
      portrait?.addListener(_portraitListener!);
      landscape?.addListener(_landscapeListener!);

      setState(() {
        _portraitCtl = portrait;
        _landscapeCtl = landscape;
        _videosReady = true;
        _videoFailed = false;
      });
    } catch (e) {
      debugPrint('[NotifyOffer] video init failed: $e');
      if (mounted) setState(() => _videoFailed = true);
    }
  }

  /// Restarts a controller only when it actually reports reaching its end.
  /// Cheap, idempotent, and avoids the polling-based approach that caused
  /// stutter in earlier implementations.
  void _restartIfFinished(VideoPlayerController? c) {
    if (c == null) return;
    final v = c.value;
    if (!v.isInitialized || v.isPlaying) return;
    if (v.position < v.duration) return;
    c.seekTo(Duration.zero);
    c.play();
  }

  /// Kicks playback after the video texture has been bound to the widget tree.
  /// Some Android codecs silently ignore play() calls made before the Surface
  /// is attached; the kick ensures the first frame arrives promptly.
  void _kickIfNotPlaying(VideoPlayerController? c) {
    if (c == null || !c.value.isInitialized || c.value.isPlaying) return;
    c.play();
  }

  @override
  void dispose() {
    if (_portraitListener != null) {
      _portraitCtl?.removeListener(_portraitListener!);
    }
    if (_landscapeListener != null) {
      _landscapeCtl?.removeListener(_landscapeListener!);
    }
    _portraitCtl?.dispose();
    _landscapeCtl?.dispose();
    _shimmer.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.pulse.askConsent();
      _openShell();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _registerCooldown();
    _openShell();
  }

  Future<void> _registerCooldown() async {
    final until = (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
        RuntimeBrand.notifyCooldownSeconds;
    await widget.cache.writePushCooldownUntil(until);
  }

  void _openShell() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BrowserShell(
          destination: widget.destination,
          cache: widget.cache,
          pulse: widget.pulse,
          radar: widget.radar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050912),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          final ctl = isPortrait ? _portraitCtl : _landscapeCtl;

          // Kick play after the texture for this orientation has been bound.
          if (ctl != null && ctl.value.isInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _kickIfNotPlaying(ctl);
            });
          }

          final videoReady =
              _videosReady && ctl != null && ctl.value.isInitialized;
          final bg = GrayAssets.notifyOfferBackground;

          return LayoutBuilder(
            builder: (context, c) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Background: video → fallback image → gradient
                  if (videoReady)
                    _FullCoverVideo(controller: ctl)
                  else if (_videoFailed && bg != null && bg.isNotEmpty)
                    Image.asset(bg, fit: BoxFit.cover)
                  else
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF132036), Color(0xFF050912)],
                        ),
                      ),
                    ),
                  // Accept / Skip buttons at ~1 cm from the screen bottom.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _buttonBottom,
                    child: isPortrait
                        ? _portraitButtons(c)
                        : _landscapeButtons(c),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _portraitButtons(BoxConstraints c) {
    final buttonWidth = c.maxWidth * 0.78;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BonusButton(
          width: buttonWidth,
          label: 'ACCEPT',
          busy: _busy,
          enabled: !_busy,
          shimmer: _shimmer,
          pulse: _pulse,
          variant: _ButtonVariant.gold,
          onTap: _accept,
        ),
        SizedBox(height: c.maxHeight * 0.022),
        _BonusButton(
          width: buttonWidth,
          label: 'SKIP',
          busy: false,
          enabled: !_busy,
          shimmer: _shimmer,
          pulse: _pulse,
          variant: _ButtonVariant.slate,
          onTap: _skip,
        ),
      ],
    );
  }

  Widget _landscapeButtons(BoxConstraints c) {
    final buttonWidth = (c.maxWidth * 0.28).clamp(220.0, 380.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BonusButton(
          width: buttonWidth,
          label: 'ACCEPT',
          busy: _busy,
          enabled: !_busy,
          shimmer: _shimmer,
          pulse: _pulse,
          variant: _ButtonVariant.gold,
          onTap: _accept,
          aspectRatio: 5.6,
        ),
        SizedBox(height: c.maxHeight * 0.025),
        _BonusButton(
          width: buttonWidth,
          label: 'SKIP',
          busy: false,
          enabled: !_busy,
          shimmer: _shimmer,
          pulse: _pulse,
          variant: _ButtonVariant.slate,
          onTap: _skip,
          aspectRatio: 5.6,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Video widget
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Button widgets (CustomPainter-drawn, no image assets needed)
// ---------------------------------------------------------------------------

enum _ButtonVariant { gold, slate }

class _ButtonPalette {
  final Color innerStart;
  final Color innerEnd;
  final Color rimDark;
  final Color rimLight;
  final Color highlight;
  final Color glow;
  final Color textColor;
  final Color textStroke;

  const _ButtonPalette({
    required this.innerStart,
    required this.innerEnd,
    required this.rimDark,
    required this.rimLight,
    required this.highlight,
    required this.glow,
    required this.textColor,
    required this.textStroke,
  });

  factory _ButtonPalette.of(_ButtonVariant v) {
    switch (v) {
      case _ButtonVariant.gold:
        return const _ButtonPalette(
          innerStart: Color(0xFFFFD24A),
          innerEnd: Color(0xFFE0681A),
          rimDark: Color(0xFF7A2A06),
          rimLight: Color(0xFFFFE7A0),
          highlight: Color(0xFFFFF6CC),
          glow: Color(0xFFFFB74D),
          textColor: Color(0xFFFFFFFF),
          textStroke: Color(0xFF6E1F00),
        );
      case _ButtonVariant.slate:
        return const _ButtonPalette(
          innerStart: Color(0xFF3C4860),
          innerEnd: Color(0xFF1F2738),
          rimDark: Color(0xFF0B0F1A),
          rimLight: Color(0xFFD5A24A),
          highlight: Color(0xFFB8C4DA),
          glow: Color(0xFF6B7B98),
          textColor: Color(0xFFFFEAB8),
          textStroke: Color(0xFF1A1208),
        );
    }
  }
}

class _BonusButton extends StatefulWidget {
  final double width;
  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  final _ButtonVariant variant;
  final AnimationController shimmer;
  final AnimationController pulse;
  final double aspectRatio;

  const _BonusButton({
    required this.width,
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onTap,
    required this.variant,
    required this.shimmer,
    required this.pulse,
    this.aspectRatio = 4.4,
  });

  @override
  State<_BonusButton> createState() => _BonusButtonState();
}

class _BonusButtonState extends State<_BonusButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  bool get _interactive => widget.enabled && !widget.busy;

  Future<void> _onTap() async {
    if (!_interactive) return;
    await _press.forward();
    await _press.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ButtonPalette.of(widget.variant);
    final plateHeight = widget.width / widget.aspectRatio;
    final fontSize = (plateHeight * 0.46).clamp(14.0, 30.0);
    final isHero = widget.variant == _ButtonVariant.gold;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_press, widget.shimmer, widget.pulse]),
        builder: (_, unused) {
          final scale = 1.0 - 0.04 * _press.value;
          final pulseT = isHero ? widget.pulse.value : 0.0;
          return Opacity(
            opacity: _interactive ? 1.0 : 0.55,
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: widget.width,
                child: AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  child: CustomPaint(
                    painter: _BonusButtonPainter(
                      palette: palette,
                      shimmer: widget.shimmer.value,
                      pulse: pulseT,
                      pressed: _press.value,
                      hero: isHero,
                    ),
                    child: Center(
                      child: widget.busy
                          ? SizedBox(
                              width: fontSize + 6,
                              height: fontSize + 6,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  palette.textColor,
                                ),
                              ),
                            )
                          : _StrokedLabel(
                              label: widget.label,
                              fontSize: fontSize,
                              color: palette.textColor,
                              stroke: palette.textStroke,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StrokedLabel extends StatelessWidget {
  final String label;
  final double fontSize;
  final Color color;
  final Color stroke;

  const _StrokedLabel({
    required this.label,
    required this.fontSize,
    required this.color,
    required this.stroke,
  });

  @override
  Widget build(BuildContext context) {
    final outlineWidth = math.max(2.0, fontSize * 0.12);
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = outlineWidth
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: const [
              Shadow(
                color: Color(0x66000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BonusButtonPainter extends CustomPainter {
  final _ButtonPalette palette;
  final double shimmer;
  final double pulse;
  final double pressed;
  final bool hero;

  _BonusButtonPainter({
    required this.palette,
    required this.shimmer,
    required this.pulse,
    required this.pressed,
    required this.hero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cornerRadius = h * 0.45;

    final outerRect = Rect.fromLTWH(0, 0, w, h);
    final outerRRect = RRect.fromRectAndRadius(
      outerRect.deflate(2),
      Radius.circular(cornerRadius),
    );
    final innerRRect = RRect.fromRectAndRadius(
      outerRect.deflate(h * 0.13),
      Radius.circular(cornerRadius * 0.85),
    );

    if (hero) {
      final glowAlpha = 0.30 + 0.25 * pulse;
      final glowPaint = Paint()
        ..color = palette.glow.withValues(alpha: glowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 16 + 6 * pulse);
      canvas.drawRRect(outerRRect, glowPaint);
    }

    canvas.drawRRect(
      outerRRect.shift(Offset(0, h * 0.10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawRRect(
      outerRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.rimLight, palette.rimDark],
        ).createShader(outerRect),
    );

    canvas.drawRRect(
      innerRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.innerStart, palette.innerEnd],
        ).createShader(outerRect),
    );

    canvas.save();
    canvas.clipRRect(innerRRect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.55),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.highlight.withValues(alpha: 0.55),
            palette.highlight.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.55)),
    );

    final shimmerPos = (shimmer * 1.6) - 0.3;
    final cx = w * shimmerPos;
    canvas.drawRect(
      Rect.fromLTWH(-w, -h, w * 3, h * 3),
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1, -1),
          end: const Alignment(1, 1),
          colors: [
            Colors.transparent,
            palette.highlight.withValues(alpha: hero ? 0.40 : 0.18),
            Colors.transparent,
          ],
          stops: const [0.46, 0.5, 0.54],
        ).createShader(
          Rect.fromCenter(
            center: Offset(cx, h * 0.5),
            width: w * 1.4,
            height: h,
          ),
        ),
    );
    canvas.restore();

    canvas.drawRRect(
      innerRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, h * 0.025)
        ..color = palette.rimDark.withValues(alpha: 0.85),
    );

    canvas.drawRRect(
      outerRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, h * 0.018)
        ..color = palette.rimLight.withValues(alpha: 0.75),
    );

    if (pressed > 0) {
      canvas.save();
      canvas.clipRRect(innerRRect);
      canvas.drawColor(
        Colors.black.withValues(alpha: 0.12 * pressed),
        BlendMode.srcOver,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BonusButtonPainter old) =>
      old.shimmer != shimmer ||
      old.pulse != pulse ||
      old.pressed != pressed ||
      old.hero != hero ||
      old.palette != palette;
}
