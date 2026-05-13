import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_theme.dart';
import 'gray/config/runtime_brand.dart';
import 'gray/screens/entry_gate.dart';
import 'gray/services/install_signal_client.dart';
import 'gray/services/network_radar.dart';
import 'gray/services/pulse_dispatch.dart';
import 'gray/services/remote_gate_client.dart';
import 'gray/services/runtime_cache.dart';
import 'gray/services/secure_http.dart';
import 'screens/loading_screen.dart';
import 'services/audio_service.dart';
import 'services/storage_service.dart';
import 'state/game_progress.dart';

/// Global handle to player progress. Initialised in [main] before runApp so
/// every screen can read/observe it without prop drilling.
late final GameProgress progress;

Future<void> _bootFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (err) {
    if (kDebugMode) debugPrint('[BOOT] Firebase skipped: $err');
    return;
  }
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (err) {
    if (kDebugMode) debugPrint('[BOOT] AppCheck skipped: $err');
  }
}

Future<void> main() async {
  final swMain = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // White (game) initialisation — game progress, audio service.
  final storage = await StorageService.create();
  progress = GameProgress(storage);
  const debugCoinFloor = 10000;
  if (progress.coins < debugCoinFloor) {
    await progress.addCoins(debugCoinFloor - progress.coins);
  }
  await AudioService.init(progress);

  // Gray (gate) initialisation — run heavy independent steps in parallel.
  // Firebase init dominates (~700–1500ms), but secureHttp.warmup
  // (DeviceInfo lookup) and RuntimeCache.bootstrap (SharedPreferences open)
  // don't depend on Firebase, so we kick them off concurrently to shave
  // ~250-400ms off boot.
  final firebaseFuture = _bootFirebase();
  final httpFuture = secureHttp.warmup();
  final cache = RuntimeCache();
  final cacheFuture = cache.bootstrap().catchError((err) {
    debugPrint('[TB.GRAY] RuntimeCache failed: $err');
  });

  await firebaseFuture;
  debugPrint('[TB.GRAY] firebase ready in ${swMain.elapsedMilliseconds}ms');
  await Future.wait([httpFuture, cacheFuture]);
  debugPrint('[TB.GRAY] http+cache ready in ${swMain.elapsedMilliseconds}ms');

  final radar = NetworkRadar();
  final install = InstallSignalClient();
  final gate = RemoteGateClient(cache);
  final pulse = PulseDispatch(cache);

  // PRE-FIRE pulse.bootstrap so its expensive network work (APNs token poll,
  // FCM token fetch, getInitialMessage round-trip) overlaps with the first
  // frame, splash video init, and EntryGate.initState. The future is cached
  // inside PulseDispatch so EntryGate's `await pulse.bootstrap()` returns
  // the same in-flight handle instead of starting a second copy.
  unawaited(pulse.bootstrap().catchError((err) {
    debugPrint('[TB.GRAY] pulse pre-fire failed: $err');
  }));

  debugPrint('[TB.GRAY] runtime brand:'
      ' gateEnabled=${RuntimeBrand.gateEnabled}'
      ' configUrl="${RuntimeBrand.configUrl}"'
      ' devKeyLen=${RuntimeBrand.installDevKey.length}'
      ' fbProj=${RuntimeBrand.firebaseProjectNumber}'
      ' iosAppId=${RuntimeBrand.iosAppId}'
      ' bundle=${RuntimeBrand.packageName}'
      ' bootMs=${swMain.elapsedMilliseconds}');

  runApp(TowerBalanceApp(
    cache: cache,
    radar: radar,
    install: install,
    gate: gate,
    pulse: pulse,
  ));
}

class TowerBalanceApp extends StatelessWidget {
  final RuntimeCache cache;
  final NetworkRadar radar;
  final InstallSignalClient install;
  final RemoteGateClient gate;
  final PulseDispatch pulse;

  const TowerBalanceApp({
    super.key,
    required this.cache,
    required this.radar,
    required this.install,
    required this.gate,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    // When the brand owner hasn't provisioned any gate value yet
    // [RuntimeBrand.gateEnabled] is false and we boot straight into the
    // existing TowerBalance game flow (LoadingScreen → MainMenu). With the
    // grey-ios provisioning in place this branch is the active one.
    final Widget home = RuntimeBrand.gateEnabled
        ? EntryGate(
            cache: cache,
            radar: radar,
            install: install,
            gate: gate,
            pulse: pulse,
          )
        : const LoadingScreen();

    return MaterialApp(
      title: RuntimeBrand.displayTitle,
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
