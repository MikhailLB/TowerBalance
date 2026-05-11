import 'package:flutter/material.dart';

import '../app/app_assets.dart';
import '../app/app_theme.dart';
import '../main.dart';
import '../services/audio_service.dart';
import '../widgets/pixel_button.dart';

/// Sound, music and haptic preferences. Mutates [progress] which the audio
/// service already listens to — every tweak here applies live.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    progress.addListener(_onChanged);
  }

  @override
  void dispose() {
    progress.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.startBg, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.55)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          'Settings',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.title(size: 36),
                        ),
                      ),
                      const SizedBox(width: 56), // balance the back button
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        _SettingTile(
                          title: 'Music',
                          subtitle: 'Background music in menu and gameplay',
                          icon: Icons.music_note_rounded,
                          child: Switch(
                            value: progress.musicEnabled,
                            activeThumbColor: AppColors.accent,
                            onChanged: (v) async {
                              await AudioService.instance
                                  .playSfx(Sfx.buttonClick);
                              await progress.setMusicEnabled(v);
                            },
                          ),
                        ),
                        _VolumeTile(
                          title: 'Music volume',
                          icon: Icons.volume_up_rounded,
                          value: progress.musicVolume,
                          enabled: progress.musicEnabled,
                          onChanged: (v) => progress.setMusicVolume(v),
                        ),
                        const SizedBox(height: 12),
                        _SettingTile(
                          title: 'Sound effects',
                          subtitle: 'Block taps, drops and UI clicks',
                          icon: Icons.graphic_eq_rounded,
                          child: Switch(
                            value: progress.soundEnabled,
                            activeThumbColor: AppColors.accent,
                            onChanged: (v) async {
                              await AudioService.instance
                                  .playSfx(Sfx.buttonClick);
                              await progress.setSoundEnabled(v);
                              // Play a sample click after re-enabling so the
                              // user gets immediate feedback.
                              if (v) {
                                AudioService.instance.playSfx(Sfx.buttonClick);
                              }
                            },
                          ),
                        ),
                        _VolumeTile(
                          title: 'SFX volume',
                          icon: Icons.volume_up_rounded,
                          value: progress.sfxVolume,
                          enabled: progress.soundEnabled,
                          onChanged: (v) => progress.setSfxVolume(v),
                        ),
                        const SizedBox(height: 12),
                        _SettingTile(
                          title: 'Vibration',
                          subtitle: 'Haptic feedback on key actions',
                          icon: Icons.vibration_rounded,
                          child: Switch(
                            value: progress.vibrationEnabled,
                            activeThumbColor: AppColors.accent,
                            onChanged: (v) async {
                              await progress.setVibrationEnabled(v);
                              if (v) {
                                AudioService.instance.vibrate();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  PixelButton(
                    label: 'Done',
                    onPressed: () {
                      AudioService.instance.playSfx(Sfx.buttonClick);
                      Navigator.of(context).pop();
                    },
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

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
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
            child: Icon(icon, color: AppColors.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.button(size: 18)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.body(size: 12)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _VolumeTile extends StatelessWidget {
  const _VolumeTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: enabled ? AppColors.accent : Colors.white30,
            size: 20,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              title,
              style: AppTextStyles.body(
                size: 13,
                color: enabled ? AppColors.text : Colors.white38,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppColors.accent,
                overlayColor: AppColors.accent.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: AppTextStyles.body(
                size: 13,
                color: enabled ? AppColors.text : Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
