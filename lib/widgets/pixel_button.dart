import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// Color theme for [PixelButton]. Primary is the warm yellow/orange used for
/// the main action (Play); secondary is the cooler sky-blue used for
/// supporting actions (Shop, Continue).
enum PixelButtonColor { primary, secondary }

/// Custom-painted cartoon button with a thick dark border, body gradient and
/// inner highlight to give it a juicy, candy-like feel that matches the rest
/// of the painted UI without relying on a bitmap asset.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 220,
    this.height = 70,
    this.fontSize = 24,
    this.color = PixelButtonColor.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final double fontSize;
  final PixelButtonColor color;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final palette = widget.color == PixelButtonColor.primary
        ? const _ButtonPalette(
            top: Color(0xFFFFD93D),
            bottom: Color(0xFFFF8A00),
            topPressed: Color(0xFFE9A800),
            bottomPressed: Color(0xFFB36000),
            border: Color(0xFF5A2D08),
            highlight: Color(0xCCFFFFFF),
          )
        : const _ButtonPalette(
            top: Color(0xFF7DDCEE),
            bottom: Color(0xFF2C9BC0),
            topPressed: Color(0xFF55B9CF),
            bottomPressed: Color(0xFF1A7A9B),
            border: Color(0xFF0E4654),
            highlight: Color(0xCCFFFFFF),
          );

    final radius = widget.height * 0.34;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Opacity(
          opacity: disabled ? 0.55 : 1.0,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _pressed
                    ? [palette.topPressed, palette.bottomPressed]
                    : [palette.top, palette.bottom],
              ),
              border: Border.all(color: palette.border, width: 3),
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _pressed ? 0.3 : 0.45),
                  blurRadius: _pressed ? 4 : 12,
                  offset: Offset(0, _pressed ? 2 : 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Top inner highlight gives the button a glossy, 3D look.
                Positioned(
                  top: 4,
                  left: 8,
                  right: 8,
                  height: widget.height * 0.42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(radius - 4),
                        bottom: Radius.circular(radius * 0.15),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          palette.highlight,
                          palette.highlight.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Subtle bottom shadow inside the button for added depth.
                Positioned(
                  bottom: 4,
                  left: 6,
                  right: 6,
                  height: widget.height * 0.18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(radius * 0.1),
                        bottom: Radius.circular(radius - 6),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.22),
                          Colors.black.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: _pressed ? 0 : 2),
                  child: Text(
                    widget.label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.button(
                      size: widget.fontSize,
                      color: Colors.white,
                    ).copyWith(
                      shadows: [
                        Shadow(color: palette.border, offset: const Offset(2, 2)),
                        Shadow(color: palette.border, offset: const Offset(-2, 2)),
                        Shadow(color: palette.border, offset: const Offset(2, -2)),
                        Shadow(color: palette.border, offset: const Offset(-2, -2)),
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonPalette {
  const _ButtonPalette({
    required this.top,
    required this.bottom,
    required this.topPressed,
    required this.bottomPressed,
    required this.border,
    required this.highlight,
  });

  final Color top;
  final Color bottom;
  final Color topPressed;
  final Color bottomPressed;
  final Color border;
  final Color highlight;
}
