import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

/// In-memory mirror of [StorageService] that notifies the UI on changes.
class GameProgress extends ChangeNotifier {
  GameProgress(this._storage)
      : _coins = _storage.coins,
        _highScore = _storage.highScore,
        _slowHookBoosts = _storage.slowHookBoosts,
        _secondChanceBoosts = _storage.secondChanceBoosts,
        _ownedSkins = List<int>.from(_storage.ownedSkins),
        _selectedSkin = _storage.selectedSkin,
        _soundEnabled = _storage.soundEnabled,
        _musicEnabled = _storage.musicEnabled,
        _vibrationEnabled = _storage.vibrationEnabled,
        _musicVolume = _storage.musicVolume,
        _sfxVolume = _storage.sfxVolume;

  final StorageService _storage;

  int _coins;
  int _highScore;
  int _slowHookBoosts;
  int _secondChanceBoosts;
  List<int> _ownedSkins;
  int _selectedSkin;
  bool _soundEnabled;
  bool _musicEnabled;
  bool _vibrationEnabled;
  double _musicVolume;
  double _sfxVolume;

  int get coins => _coins;
  int get highScore => _highScore;
  int get slowHookBoosts => _slowHookBoosts;
  int get secondChanceBoosts => _secondChanceBoosts;
  List<int> get ownedSkins => List.unmodifiable(_ownedSkins);
  int get selectedSkin => _selectedSkin;
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    _coins += amount;
    await _storage.setCoins(_coins);
    notifyListeners();
  }

  Future<bool> spendCoins(int amount) async {
    if (amount <= 0 || _coins < amount) return false;
    _coins -= amount;
    await _storage.setCoins(_coins);
    notifyListeners();
    return true;
  }

  Future<void> reportScore(int score) async {
    if (score > _highScore) {
      _highScore = score;
      await _storage.setHighScore(_highScore);
    }
    await addCoins(score);
  }

  Future<void> setSelectedSkin(int skin) async {
    _selectedSkin = skin;
    await _storage.setSelectedSkin(skin);
    notifyListeners();
  }

  Future<void> unlockSkin(int skin) async {
    if (_ownedSkins.contains(skin)) return;
    _ownedSkins = [..._ownedSkins, skin]..sort();
    await _storage.addOwnedSkin(skin);
    notifyListeners();
  }

  Future<void> grantSlowHook(int amount) async {
    _slowHookBoosts += amount;
    await _storage.setSlowHookBoosts(_slowHookBoosts);
    notifyListeners();
  }

  Future<bool> consumeSlowHook() async {
    if (_slowHookBoosts <= 0) return false;
    _slowHookBoosts -= 1;
    await _storage.setSlowHookBoosts(_slowHookBoosts);
    notifyListeners();
    return true;
  }

  Future<void> grantSecondChance(int amount) async {
    _secondChanceBoosts += amount;
    await _storage.setSecondChanceBoosts(_secondChanceBoosts);
    notifyListeners();
  }

  Future<bool> consumeSecondChance() async {
    if (_secondChanceBoosts <= 0) return false;
    _secondChanceBoosts -= 1;
    await _storage.setSecondChanceBoosts(_secondChanceBoosts);
    notifyListeners();
    return true;
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    await _storage.setSoundEnabled(value);
    notifyListeners();
  }

  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    await _storage.setMusicEnabled(value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    await _storage.setVibrationEnabled(value);
    notifyListeners();
  }

  Future<void> setMusicVolume(double value) async {
    _musicVolume = value.clamp(0.0, 1.0);
    await _storage.setMusicVolume(_musicVolume);
    notifyListeners();
  }

  Future<void> setSfxVolume(double value) async {
    _sfxVolume = value.clamp(0.0, 1.0);
    await _storage.setSfxVolume(_sfxVolume);
    notifyListeners();
  }
}
