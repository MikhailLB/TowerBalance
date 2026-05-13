import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../state/game_progress.dart';

/// One-shot SFX channels available throughout the game.
enum Sfx {
  /// Played when the player taps any UI button.
  buttonClick,

  /// Played when a block hits the tower or fails the placement.
  blockFall,
}

/// Background music tracks the game knows how to play.
enum Bgm { menu, gameplay }

/// Single global audio system. Owns:
///   * one looping [AudioPlayer] for background music
///   * one short-lived [AudioPlayer] per SFX play (so concurrent taps don't
///     cancel each other)
///   * mute / volume preferences read from [GameProgress]
///
/// Initialise once in `main()` after [GameProgress] exists, then call from
/// anywhere via [AudioService.instance]. Listens to the progress object so
/// volume/mute changes apply immediately without restarting tracks.
class AudioService with WidgetsBindingObserver {
  AudioService._(this._progress);

  static AudioService? _instance;
  static AudioService get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('AudioService.init() must be called first');
    }
    return i;
  }

  static const _kMenuBgm = 'music/mainmenumusic.mp3';
  static const _kGameplayBgm = 'music/gameplaymusic.mp3';
  static const _kBlockFall = 'music/block_fall_sound.mp3';
  static const _kButtonClick = 'music/button-click-error.mp3';

  final GameProgress _progress;
  final AudioPlayer _bgm = AudioPlayer(playerId: 'tower_balance_bgm');
  Bgm? _currentBgm;

  /// True while the OS reports the app is in the foreground. Tracked by
  /// [didChangeAppLifecycleState] so we can suppress BGM resume requests that
  /// would otherwise restart playback while the user is in another app.
  bool _appInForeground = true;

  /// Initialise the global audio system. Pre-loads the SFX clips so they
  /// fire with no perceptible latency. Safe to call multiple times.
  static Future<void> init(GameProgress progress) async {
    if (_instance != null) return;
    final svc = AudioService._(progress);
    _instance = svc;

    // Configure the global audio context so SFX playback does NOT request
    // audio focus on Android. Without this, every new short-lived SFX player
    // grabs focus and pauses the looping BGM player ("music stops on every
    // tap / block fall"). `gainTransientMayDuck` would lower the music while
    // SFX plays, which still causes the dip — `none` lets them mix freely.
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.none,
          ),
          // iOS rejects `mixWithOthers` unless the category is one of
          // playback / playAndRecord / multiRoute. Earlier we used `ambient`
          // (which itself implies mixing) and audioplayers' assertion fired.
          // `playback` is the correct category for a music-driven game and
          // explicitly allows mixWithOthers so SFX players spawned later
          // don't pause the looping BGM.
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (e) {
      debugPrint('AudioService: setAudioContext failed: $e');
    }

    await svc._bgm.setReleaseMode(ReleaseMode.loop);
    await svc._bgm.setVolume(progress.musicVolume);
    // The BGM player was constructed before setAudioContext above ran — push
    // the same focus-free context onto it so the looping music keeps playing
    // while SFX players come and go.
    try {
      await svc._bgm.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (e) {
      debugPrint('AudioService: bgm setAudioContext failed: $e');
    }
    progress.addListener(svc._onProgressChanged);
    WidgetsBinding.instance.addObserver(svc);
  }

  void _onProgressChanged() {
    // Apply music volume / mute changes live.
    if (_progress.musicEnabled && _appInForeground) {
      _bgm.setVolume(_progress.musicVolume);
      if (_currentBgm != null && _bgm.state != PlayerState.playing) {
        _bgm.resume();
      }
    } else {
      _bgm.pause();
    }
  }

  /// Pauses BGM when the app is backgrounded / hidden / inactive and resumes
  /// it when the player returns. Without this the looping music keeps playing
  /// in the system mixer even after the user has switched away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _appInForeground) return;
    _appInForeground = foreground;
    if (!foreground) {
      _bgm.pause();
    } else if (_progress.musicEnabled && _currentBgm != null) {
      _bgm.resume();
    }
  }

  String _bgmPath(Bgm bgm) =>
      bgm == Bgm.menu ? _kMenuBgm : _kGameplayBgm;

  String _sfxPath(Sfx sfx) =>
      sfx == Sfx.buttonClick ? _kButtonClick : _kBlockFall;

  /// Start (or switch to) the given background track. Idempotent — calling
  /// with the same [bgm] while it's already playing is a no-op.
  Future<void> playBgm(Bgm bgm) async {
    if (_currentBgm == bgm && _bgm.state == PlayerState.playing) return;
    _currentBgm = bgm;
    if (!_progress.musicEnabled || !_appInForeground) return;
    try {
      await _bgm.stop();
      await _bgm.setVolume(_progress.musicVolume);
      await _bgm.play(AssetSource(_bgmPath(bgm)));
    } catch (e) {
      debugPrint('AudioService: bgm play failed: $e');
    }
  }

  /// Stop the background music entirely (used when leaving the app).
  Future<void> stopBgm() async {
    _currentBgm = null;
    try {
      await _bgm.stop();
    } catch (_) {}
  }

  /// Fire-and-forget SFX. Spawns its own short-lived [AudioPlayer] each call
  /// so simultaneous SFX don't truncate each other.
  Future<void> playSfx(Sfx sfx) async {
    if (!_progress.soundEnabled) return;
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(_progress.sfxVolume);
      await player.play(AssetSource(_sfxPath(sfx)));
      // Auto-dispose once the clip is done.
      player.onPlayerComplete.first.then((_) => player.dispose());
    } catch (e) {
      debugPrint('AudioService: sfx play failed: $e');
      player.dispose();
    }
  }

  /// Trigger a short device vibration if the player has it enabled.
  /// Uses [HapticFeedback] from `flutter/services` so we don't need an extra
  /// permission or plugin.
  Future<void> vibrate({bool heavy = false}) async {
    if (!_progress.vibrationEnabled) return;
    if (heavy) {
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.mediumImpact();
    }
  }
}
