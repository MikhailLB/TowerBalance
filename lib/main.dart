import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_theme.dart';
import 'gray/config/gray_assets.dart';
import 'gray/gray_boot.dart';
import 'screens/loading_screen.dart';
import 'services/audio_service.dart';
import 'services/storage_service.dart';
import 'state/game_progress.dart';

/// Global handle to player progress. Initialised in [main] before runApp so
/// every screen can read/observe it without prop drilling.
late final GameProgress progress;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ---------------------------------------------------------------------------
  // Gray flow asset paths — configure BEFORE GrayBoot.prepare().
  //
  // TODO: verify the exact filenames once the video files are placed in the
  // asset folders. Naming convention used: 9x16_* = portrait, 16x9_* = landscape.
  //
  // When GrayBoot.gateEnabled == false (all keys empty), these paths are never
  // read, so mis-spelling them is harmless until the gray flow is activated.
  // ---------------------------------------------------------------------------
  GrayAssets.configure(
    notifyOfferVideoPortrait:
        'assets/additional_assets/notifications/9x16_notification_screen.mp4',
    notifyOfferVideoLandscape:
        'assets/additional_assets/notifications/16x9_notification_screen.mp4',
    networkPauseBackgroundPortrait:
        'assets/additional_assets/no_wifi/9x16_no_wifi_screen.mp4',
    networkPauseBackgroundLandscape:
        'assets/additional_assets/no_wifi/16x9_no_wifi_screen.mp4',
  );

  // ---------------------------------------------------------------------------
  // Gray flow boot — initialises Firebase (when google-services.json is
  // present), AppsFlyer SDK container, SharedPreferences cache, and the
  // network/push dispatcher. Safe no-op when all keys are empty.
  // ---------------------------------------------------------------------------
  final gray = await GrayBoot.prepare();

  // ---------------------------------------------------------------------------
  // White (game) boot — unchanged from before.
  // ---------------------------------------------------------------------------
  final storage = await StorageService.create();
  progress = GameProgress(storage);

  // Debug grant: top up to at least 10 000 coins on every launch so the shop
  // can be exercised.
  const debugCoinFloor = 10000;
  if (progress.coins < debugCoinFloor) {
    await progress.addCoins(debugCoinFloor - progress.coins);
  }

  await AudioService.init(progress);

  runApp(TowerBalanceApp(gray: gray));
}

class TowerBalanceApp extends StatelessWidget {
  final GrayBoot? gray;

  const TowerBalanceApp({super.key, this.gray});

  @override
  Widget build(BuildContext context) {
    // When the gray flow is provisioned (keys filled) EntryGate decides the
    // route and shows DefaultGraySplash while the pipeline runs. The
    // fallbackHomeBuilder routes organic users into the normal white flow.
    // When no keys are present, gray is skipped entirely and LoadingScreen
    // mounts directly — zero overhead, zero risk.
    final home = gray != null
        ? gray!.buildHome(
            fallbackHomeBuilder: (_) => const LoadingScreen(),
          )
        : const LoadingScreen();

    return MaterialApp(
      title: 'TowerBalance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.sky,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ),
      ),
      home: home,
    );
  }
}
