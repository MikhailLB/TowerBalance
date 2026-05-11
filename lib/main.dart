import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_theme.dart';
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

  final storage = await StorageService.create();
  progress = GameProgress(storage);

  // Debug grant: top up to at least 10 000 coins on every launch so the shop
  // can be exercised. Idempotent — only adds the delta needed to reach the
  // floor, never goes above it on subsequent launches.
  const debugCoinFloor = 10000;
  if (progress.coins < debugCoinFloor) {
    await progress.addCoins(debugCoinFloor - progress.coins);
  }

  await AudioService.init(progress);

  runApp(const TowerBalanceApp());
}

class TowerBalanceApp extends StatelessWidget {
  const TowerBalanceApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const LoadingScreen(),
    );
  }
}
