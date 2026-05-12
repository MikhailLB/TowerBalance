import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../config/gray_assets.dart';
import '../services/network_radar.dart';

/// Shown whenever the gray flow detects the device went offline.
///
/// Background: portrait + landscape videos from [GrayAssets] (same no-lag
/// dual-controller pattern as [NotifyOfferScreen]). Falls back to a gradient
/// when no videos are configured.
///
/// The Retry button is drawn entirely in Flutter (CustomPainter) — no image
/// assets needed. It sits ~1 cm from the physical screen bottom.
class NetworkPauseScreen extends StatefulWidget {
  final WidgetBuilder retryBuilder;
  final NetworkRadar radar;

  const NetworkPauseScreen({
    super.key,
    required this.retryBuilder,
    required this.radar,
  });

  @override
  State<NetworkPauseScreen> createState() => _NetworkPauseScreenState();
}

class _NetworkPauseScreenState extends State<NetworkPauseScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _portraitCtl;
  VideoPlayerController? _landscapeCtl;
  VoidCallback? _portraitListener;
  VoidCallback? _landscapeListener;

  bool _videosReady = false;
  bool _busy = false;
  bool _hint = false;
  Timer? _hintTimer;

  late final AnimationController _press;

  // Fixed distance from the physical screen bottom (~1 cm on standard density).
  static const double _buttonBottom = 40.0;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _initBothVideos();
  }

  Future<void> _initBothVideos() async {
    final portraitPath = GrayAssets.networkPauseBackgroundPortrait;
    final landscapePath = GrayAssets.networkPauseBackgroundLandscape;

    if (portraitPath == null && landscapePath == null) {
      // No video paths configured — image / gradient fallback handles it.
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
      });
    } catch (e) {
      debugPrint('[NetworkPause] video init failed: $e');
    }
  }

  void _restartIfFinished(VideoPlayerController? c) {
    if (c == null) return;
    final v = c.value;
    if (!v.isInitialized || v.isPlaying) return;
    if (v.position < v.duration) return;
    c.seekTo(Duration.zero);
    c.play();
  }

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
    _hintTimer?.cancel();
    _press.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    await _press.forward();
    await _press.reverse();
    if (!mounted) return;
    setState(() => _busy = true);

    final online = await widget.radar.isReachable();
    if (!mounted) return;

    if (!online) {
      _hintTimer?.cancel();
      setState(() {
        _busy = false;
        _hint = true;
      });
      _hintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _hint = false);
      });
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.retryBuilder),
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

          if (ctl != null && ctl.value.isInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _kickIfNotPlaying(ctl);
            });
          }

          final videoReady =
              _videosReady && ctl != null && ctl.value.isInitialized;

          final imagePath = isPortrait
              ? GrayAssets.networkPauseImagePortrait
              : GrayAssets.networkPauseImageLandscape;
          final hasImage = imagePath != null && imagePath.isNotEmpty;

          return LayoutBuilder(
            builder: (context, c) {
              final buttonWidth = isPortrait
                  ? (c.maxWidth * 0.55).clamp(200.0, 360.0)
                  : (c.maxWidth * 0.28).clamp(220.0, 420.0);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Background: video → image → gradient fallback
                  if (videoReady)
                    _FullCoverVideo(controller: ctl)
                  else if (hasImage)
                    Image.asset(imagePath, fit: BoxFit.cover)
                  else
                    _DefaultPauseBackground(isPortrait: isPortrait),

                  // Retry button ~1 cm from screen bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _buttonBottom,
                    child: Center(
                      child: _RetryButton(
                        width: buttonWidth,
                        busy: _busy,
                        press: _press,
                        onTap: _retry,
                      ),
                    ),
                  ),

                  // "Still no internet" hint
                  SafeArea(
                    child: Align(
                      alignment: isPortrait
                          ? Alignment.bottomCenter
                          : Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: isPortrait ? 80 : 12,
                        ),
                        child: AnimatedOpacity(
                          opacity: _hint ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              child: Text(
                                'Still no internet — please try again.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
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
// Fallback background (when no video assets are configured)
// ---------------------------------------------------------------------------

class _DefaultPauseBackground extends StatelessWidget {
  final bool isPortrait;
  const _DefaultPauseBackground({required this.isPortrait});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF111929), Color(0xFF050912)],
            ),
          ),
        ),
        Align(
          alignment: Alignment(0, isPortrait ? -0.30 : -0.40),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 64, color: Color(0xFFE0E5EE)),
              SizedBox(height: 14),
              Text(
                'No internet connection',
                style: TextStyle(
                  color: Color(0xFFE0E5EE),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Reconnect and tap Retry.',
                style: TextStyle(color: Color(0x99E0E5EE), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Retry button — CustomPainter drawn, no image asset required
// ---------------------------------------------------------------------------

class _RetryButton extends StatelessWidget {
  final double width;
  final bool busy;
  final AnimationController press;
  final VoidCallback onTap;

  const _RetryButton({
    required this.width,
    required this.busy,
    required this.press,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: AnimatedBuilder(
        animation: press,
        builder: (_, child) {
          final scale = 1.0 - 0.05 * press.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: 3.8,
            child: CustomPaint(
              painter: _RetryButtonPainter(pressed: press.value),
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2A150A),
                          ),
                        ),
                      )
                    : const _RetryLabel(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryLabel extends StatelessWidget {
  const _RetryLabel();

  @override
  Widget build(BuildContext context) {
    const fontSize = 18.0;
    const outlineWidth = 2.2;
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          'RETRY',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = outlineWidth
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF6E1F00),
          ),
        ),
        const Text(
          'RETRY',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: [
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

class _RetryButtonPainter extends CustomPainter {
  final double pressed;
  const _RetryButtonPainter({required this.pressed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cr = h * 0.45;

    final outerRect = Rect.fromLTWH(0, 0, w, h);
    final outerRRect = RRect.fromRectAndRadius(
      outerRect.deflate(2),
      Radius.circular(cr),
    );
    final innerRRect = RRect.fromRectAndRadius(
      outerRect.deflate(h * 0.13),
      Radius.circular(cr * 0.85),
    );

    // Outer glow
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..color = const Color(0xFFFFB74D).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 14),
    );

    // Drop shadow
    canvas.drawRRect(
      outerRRect.shift(Offset(0, h * 0.10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Outer rim
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE7A0), Color(0xFF7A2A06)],
        ).createShader(outerRect),
    );

    // Inner panel
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD24A), Color(0xFFE0681A)],
        ).createShader(outerRect),
    );

    // Top highlight
    canvas.save();
    canvas.clipRRect(innerRRect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.55),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFF6CC).withValues(alpha: 0.55),
            const Color(0xFFFFF6CC).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.55)),
    );
    canvas.restore();

    // Inner stroke
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, h * 0.025)
        ..color = const Color(0xFF7A2A06).withValues(alpha: 0.85),
    );

    // Outer rim hairline
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, h * 0.018)
        ..color = const Color(0xFFFFE7A0).withValues(alpha: 0.75),
    );

    // Press feedback
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
  bool shouldRepaint(covariant _RetryButtonPainter old) =>
      old.pressed != pressed;
}
