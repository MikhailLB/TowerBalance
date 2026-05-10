import 'package:flutter/material.dart';

import '../app/app_assets.dart';
import '../app/app_theme.dart';

/// A pressable button rendered on top of the painted `button_asset.webp`.
///
/// Uses an `AnimatedScale` so the button visibly "presses" on tap, giving the
/// game some tactile feedback even without sound.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 220,
    this.height = 70,
    this.fontSize = 24,
  });

  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final double fontSize;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: Opacity(
          opacity: disabled ? 0.55 : 1.0,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  AppAssets.button,
                  fit: BoxFit.fill,
                  width: widget.width,
                  height: widget.height,
                ),
                Padding(
                  // The painted bevel sits ~6 px below the centre, nudge text up.
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    widget.label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.button(
                      size: widget.fontSize,
                      color: AppColors.text,
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
