import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_assets.dart';
import '../app/app_orientation.dart';
import '../app/app_theme.dart';
import '../main.dart';
import '../services/audio_service.dart';
import '../widgets/pixel_button.dart';
import 'game_screen.dart';
import 'info_web_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

/// Main menu shown after the loading splash. Allows rotation; only
/// [GameScreen] locks to portrait.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    setAppOrientationsForNonGame();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    progress.addListener(_onProgressChanged);
    AudioService.instance.playBgm(Bgm.menu);
  }

  void _onProgressChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    progress.removeListener(_onProgressChanged);
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    AudioService.instance.playSfx(Sfx.buttonClick);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const GameScreen()),
    );
    // Returning from gameplay — switch back to menu music.
    if (mounted) AudioService.instance.playBgm(Bgm.menu);
  }

  Future<void> _openShop() async {
    AudioService.instance.playSfx(Sfx.buttonClick);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
    );
  }

  Future<void> _openSettings() async {
    AudioService.instance.playSfx(Sfx.buttonClick);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _openPrivacy() async {
    AudioService.instance.playSfx(Sfx.buttonClick);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const InfoWebScreen(
          title: 'Privacy Policy',
          url: 'https://towerbalance.com/privacy-policy.html',
        ),
      ),
    );
  }

  Future<void> _openSupport() async {
    AudioService.instance.playSfx(Sfx.buttonClick);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const InfoWebScreen(
          title: 'Support',
          url: 'https://towerbalance.com/support.html',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.startBg, fit: BoxFit.cover),
          Align(
            alignment: const Alignment(0, 0.55),
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (_, child) {
                final t = _floatController.value;
                return Transform.translate(
                  offset: Offset(0, -8 + 8 * (1 - t)),
                  child: child,
                );
              },
              child: Image.asset(
                AppAssets.startBuilding,
                width: size.width * 0.9,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TopBar(
                    coins: progress.coins,
                    highScore: progress.highScore,
                    onSettings: _openSettings,
                  ),
                  const Spacer(),
                  Image.asset(
                    AppAssets.logoName,
                    width: size.width * 0.8,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(flex: 4),
                  Column(
                    children: [
                      PixelButton(
                        label: 'Play',
                        onPressed: _startGame,
                        width: 240,
                        height: 78,
                        fontSize: 30,
                      ),
                      const SizedBox(height: 18),
                      PixelButton(
                        label: 'Shop',
                        onPressed: _openShop,
                        width: 200,
                        height: 64,
                        fontSize: 24,
                        color: PixelButtonColor.secondary,
                      ),
                      const SizedBox(height: 14),
                      // Privacy + Support: small links required for store
                      // compliance. Each opens an in-app WebView.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TextLinkButton(
                            label: 'Privacy Policy',
                            onTap: _openPrivacy,
                          ),
                          const SizedBox(width: 18),
                          _TextLinkButton(
                            label: 'Support',
                            onTap: _openSupport,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextLinkButton extends StatelessWidget {
  const _TextLinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: AppTextStyles.body(size: 14, color: Colors.white).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.coins,
    required this.highScore,
    required this.onSettings,
  });

  final int coins;
  final int highScore;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Pill(
          icon: Icons.emoji_events_rounded,
          iconColor: AppColors.accent,
          label: 'Best $highScore',
        ),
        Row(
          children: [
            _Pill(
              icon: Icons.monetization_on_rounded,
              iconColor: AppColors.accent,
              label: '$coins',
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.panel,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSettings,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.settings_rounded,
                      color: AppColors.text, size: 24),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.button(size: 18)),
        ],
      ),
    );
  }
}
