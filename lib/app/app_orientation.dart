import 'package:flutter/services.dart';

/// Loading splash, menu, shop, settings, and in-app WebViews may use both
/// portrait and landscape (separate assets / layouts per orientation).
///
/// [GameScreen] locks to portrait only — the Flame/Forge2D world is authored
/// for a tall phone aspect ratio.
Future<void> setAppOrientationsForNonGame() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

Future<void> setAppOrientationsForGameplay() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}
