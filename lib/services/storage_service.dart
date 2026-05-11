import 'package:shared_preferences/shared_preferences.dart';

/// Persistent storage for player progress: coins, high score, owned skins,
/// equipped skin, consumable boosts, and audio/haptic preferences.
class StorageService {
  StorageService._(this._prefs);

  static const _kHighScore = 'high_score';
  static const _kCoins = 'coins';
  static const _kOwnedSkins = 'owned_skins';
  static const _kSelectedSkin = 'selected_skin';
  static const _kBoostSlowHook = 'boost_slow_hook';
  static const _kBoostSecondChance = 'boost_second_chance';
  static const _kSoundEnabled = 'sound_enabled';
  static const _kMusicEnabled = 'music_enabled';
  static const _kVibrationEnabled = 'vibration_enabled';
  static const _kMusicVolume = 'music_volume';
  static const _kSfxVolume = 'sfx_volume';

  final SharedPreferences _prefs;

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final service = StorageService._(prefs);
    await service._seedDefaults();
    return service;
  }

  Future<void> _seedDefaults() async {
    if (!_prefs.containsKey(_kOwnedSkins)) {
      await _prefs.setStringList(_kOwnedSkins, ['1']);
    }
    if (!_prefs.containsKey(_kSelectedSkin)) {
      await _prefs.setInt(_kSelectedSkin, 0);
    }
    if (!_prefs.containsKey(_kSoundEnabled)) {
      await _prefs.setBool(_kSoundEnabled, true);
    }
    if (!_prefs.containsKey(_kMusicEnabled)) {
      await _prefs.setBool(_kMusicEnabled, true);
    }
    if (!_prefs.containsKey(_kVibrationEnabled)) {
      await _prefs.setBool(_kVibrationEnabled, true);
    }
    if (!_prefs.containsKey(_kMusicVolume)) {
      await _prefs.setDouble(_kMusicVolume, 0.6);
    }
    if (!_prefs.containsKey(_kSfxVolume)) {
      await _prefs.setDouble(_kSfxVolume, 0.8);
    }
  }

  int get highScore => _prefs.getInt(_kHighScore) ?? 0;
  int get coins => _prefs.getInt(_kCoins) ?? 0;
  int get slowHookBoosts => _prefs.getInt(_kBoostSlowHook) ?? 0;
  int get secondChanceBoosts => _prefs.getInt(_kBoostSecondChance) ?? 0;
  bool get soundEnabled => _prefs.getBool(_kSoundEnabled) ?? true;
  bool get musicEnabled => _prefs.getBool(_kMusicEnabled) ?? true;
  bool get vibrationEnabled => _prefs.getBool(_kVibrationEnabled) ?? true;
  double get musicVolume => _prefs.getDouble(_kMusicVolume) ?? 0.6;
  double get sfxVolume => _prefs.getDouble(_kSfxVolume) ?? 0.8;

  /// Skins the player owns (block_asset_n). Always contains at least skin 1.
  List<int> get ownedSkins =>
      (_prefs.getStringList(_kOwnedSkins) ?? const ['1'])
          .map(int.parse)
          .toList()
        ..sort();

  /// 0 means "use a random skin from `ownedSkins` for every block".
  int get selectedSkin => _prefs.getInt(_kSelectedSkin) ?? 0;

  Future<void> setHighScore(int value) => _prefs.setInt(_kHighScore, value);
  Future<void> setCoins(int value) => _prefs.setInt(_kCoins, value);
  Future<void> setSlowHookBoosts(int value) =>
      _prefs.setInt(_kBoostSlowHook, value);
  Future<void> setSecondChanceBoosts(int value) =>
      _prefs.setInt(_kBoostSecondChance, value);
  Future<void> setSoundEnabled(bool value) =>
      _prefs.setBool(_kSoundEnabled, value);
  Future<void> setMusicEnabled(bool value) =>
      _prefs.setBool(_kMusicEnabled, value);
  Future<void> setVibrationEnabled(bool value) =>
      _prefs.setBool(_kVibrationEnabled, value);
  Future<void> setMusicVolume(double value) =>
      _prefs.setDouble(_kMusicVolume, value);
  Future<void> setSfxVolume(double value) =>
      _prefs.setDouble(_kSfxVolume, value);
  Future<void> setSelectedSkin(int skin) =>
      _prefs.setInt(_kSelectedSkin, skin);

  Future<void> addOwnedSkin(int skin) async {
    final list = ownedSkins;
    if (!list.contains(skin)) {
      list.add(skin);
      await _prefs.setStringList(
        _kOwnedSkins,
        list.map((e) => e.toString()).toList(),
      );
    }
  }
}
