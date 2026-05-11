import 'package:flutter/material.dart';

import '../app/app_assets.dart';
import '../app/app_theme.dart';
import '../main.dart';
import '../services/audio_service.dart';
import '../widgets/pixel_button.dart';

/// Spend earned coins on cosmetic block skins or consumable boosts.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const _skinPrice = 80;
  static const _slowHookPrice = 35;
  static const _secondChancePrice = 60;

  @override
  void initState() {
    super.initState();
    progress.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    progress.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _buySkin(int skin) async {
    AudioService.instance.playSfx(Sfx.buttonClick);
    if (progress.ownedSkins.contains(skin)) {
      // Tapping an owned skin equips just that one (single-skin mode). Tap
      // "Random" below to switch back to rotation.
      await progress.setSelectedSkin(skin);
      return;
    }
    final ok = await progress.spendCoins(_skinPrice);
    if (!ok) {
      _showSnack('Not enough coins');
      return;
    }
    await progress.unlockSkin(skin);
    // After buying a new skin, default to rotation mode so every owned skin
    // (the new one included) takes part in the next game. The player can
    // always tap a specific skin afterwards to lock onto it.
    await progress.setSelectedSkin(0);
  }

  Future<void> _buySlowHook() async {
    AudioService.instance.playSfx(Sfx.buttonClick);
    final ok = await progress.spendCoins(_slowHookPrice);
    if (!ok) {
      _showSnack('Not enough coins');
      return;
    }
    await progress.grantSlowHook(1);
  }

  Future<void> _buySecondChance() async {
    AudioService.instance.playSfx(Sfx.buttonClick);
    final ok = await progress.spendCoins(_secondChancePrice);
    if (!ok) {
      _showSnack('Not enough coins');
      return;
    }
    await progress.grantSecondChance(1);
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        backgroundColor: AppColors.panel,
        content: Text(text, style: AppTextStyles.body()),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.startBg, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _BackButton(onTap: () {
                        AudioService.instance.playSfx(Sfx.buttonClick);
                        Navigator.of(context).pop();
                      }),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Shop',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.title(size: 36),
                        ),
                      ),
                      _CoinPill(coins: progress.coins),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        _SectionHeader(title: 'Block skins'),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: size.width * 0.35,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 6,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, index) {
                              final skin = index + 1;
                              final owned =
                                  progress.ownedSkins.contains(skin);
                              final selected = progress.selectedSkin == skin;
                              return _SkinCard(
                                skin: skin,
                                owned: owned,
                                selected: selected,
                                price: _skinPrice,
                                onTap: () => _buySkin(skin),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ToggleChoice(
                                label: 'Random',
                                selected: progress.selectedSkin == 0,
                                onTap: () {
                                  AudioService.instance.playSfx(Sfx.buttonClick);
                                  progress.setSelectedSkin(0);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _SectionHeader(title: 'Boosts'),
                        const SizedBox(height: 8),
                        _BoostCard(
                          icon: Icons.speed_rounded,
                          title: 'Slow Hook',
                          subtitle:
                              'Slows the swinging hook for the first 6 seconds.',
                          price: _slowHookPrice,
                          owned: progress.slowHookBoosts,
                          onBuy: _buySlowHook,
                        ),
                        const SizedBox(height: 10),
                        _BoostCard(
                          icon: Icons.favorite_rounded,
                          title: 'Second Chance',
                          subtitle:
                              'Survive a single bad placement and keep playing.',
                          price: _secondChancePrice,
                          owned: progress.secondChanceBoosts,
                          onBuy: _buySecondChance,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.arrow_back_rounded,
              color: AppColors.text, size: 26),
        ),
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins});

  final int coins;

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
          const Icon(Icons.monetization_on_rounded,
              color: AppColors.accent, size: 22),
          const SizedBox(width: 6),
          Text('$coins', style: AppTextStyles.button(size: 18)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: AppTextStyles.button(size: 22)),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.owned,
    required this.selected,
    required this.price,
    required this.onTap,
  });

  final int skin;
  final bool owned;
  final bool selected;
  final int price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.accent
        : (owned ? Colors.white60 : Colors.black54);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 3),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: Image.asset(
                AppAssets.block(skin),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 4),
            if (owned)
              Text(
                selected ? 'Equipped' : 'Owned',
                style: AppTextStyles.body(size: 12, color: AppColors.accent),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      color: AppColors.accent, size: 14),
                  const SizedBox(width: 2),
                  Text('$price',
                      style: AppTextStyles.body(size: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChoice extends StatelessWidget {
  const _ToggleChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shuffle_rounded,
                color: AppColors.text, size: 18),
            const SizedBox(width: 8),
            Text(
              'Random skin',
              style: AppTextStyles.body(
                size: 14,
                color:
                    selected ? AppColors.textDark : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoostCard extends StatelessWidget {
  const _BoostCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.owned,
    required this.onBuy,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int price;
  final int owned;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accent, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: AppTextStyles.button(size: 18)),
                    const SizedBox(width: 8),
                    if (owned > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'x$owned',
                          style: AppTextStyles.body(
                              size: 12, color: AppColors.textDark),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.body(size: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PixelButton(
            label: '$price',
            onPressed: onBuy,
            width: 96,
            height: 48,
            fontSize: 18,
          ),
        ],
      ),
    );
  }
}
