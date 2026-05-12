import 'package:flutter/services.dart';

/// Loading splash only — separate portrait/landscape video assets may rotate.
///
/// Menu, shop, settings, in-app WebViews, and [GameScreen] use
/// [setOrientationsLockedPortrait] so the game never offers horizontal layout
/// on iOS or Android.
Future<void> setOrientationsForLoadingScreens() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

Future<void> setOrientationsLockedPortrait() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}
