import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_theme.dart';
import 'gray/config/gray_assets.dart';
import 'gray/gray_boot.dart';
import 'screens/loading_screen.dart';
import 'screens/main_menu_screen.dart';
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
  // Naming convention: 9x16_* = portrait, 16x9_* = landscape.
  // ---------------------------------------------------------------------------
  GrayAssets.configure(
    // Notification offer screen — videos.
    notifyOfferVideoPortrait:
        'assets/additional_assets/notifications/9x16_notification.mp4',
    notifyOfferVideoLandscape:
        'assets/additional_assets/notifications/16x9_notification.mp4',
    // No-wifi screen — static images (webp).
    networkPauseImagePortrait:
        'assets/additional_assets/no_wifi/9x16_no_wifi_screen.webp',
    networkPauseImageLandscape:
        'assets/additional_assets/no_wifi/16x9_no_wifi_screen.webp',
  );

  // ---------------------------------------------------------------------------
  // Gray flow boot — Firebase, AppsFlyer SDK warmup, SharedPreferences,
  // network/push dispatcher. Safe no-op when keys are empty.
  // ---------------------------------------------------------------------------
  final gray = await GrayBoot.prepare();

  // ---------------------------------------------------------------------------
  // White (game) boot.
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
    // Two paths:
    //   • gateEnabled == true  → EntryGate drives the gray pipeline. The host
    //     LoadingScreen serves as the splash (video + 4-state bar) and stays
    //     visible until the pipeline resolves a destination. When the gray
    //     flow concludes "arcade" (no web destination), the splash hands over
    //     to MainMenuScreen — assets have already been preloaded by the
    //     splash itself, so no second loading screen is needed.
    //   • gateEnabled == false → gray.buildHome short-circuits to the
    //     fallback, which mounts a plain LoadingScreen → MainMenuScreen.
    final home = gray != null
        ? gray!.buildHome(
            splashBuilder: (routeFuture, contentReady, keepAsUnderlay) =>
                LoadingScreen(
              routeFuture: routeFuture,
              contentReady: contentReady,
              keepAsUnderlay: keepAsUnderlay,
            ),
            fallbackHomeBuilder: (_) => const MainMenuScreen(),
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
