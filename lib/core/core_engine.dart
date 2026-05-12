import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config/brand_core.dart';
import 'screens/app_gateway.dart';
import 'services/signal_sender.dart';
import 'services/conn_radar.dart';
import 'services/push_agent.dart';
import 'services/route_client.dart';
import 'services/data_vault.dart';
import 'services/safe_net.dart';

/// One-stop wiring for the core boot flow.
///
/// Usage (in your host app's `main`):
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final core = await CoreEngine.prepare();
///   runApp(MaterialApp(
///     home: core.buildHome(
///       fallbackHomeBuilder: (_) => const MyOriginalHomeScreen(),
///     ),
///   ));
/// }
/// ```
///
/// All the wiring (Firebase init, AppCheck, AppsFlyer warmup container,
/// `DataVault`, push dispatcher, gateway client) is constructed once and
/// re-used. [buildHome] returns either the core [AppGateway] when the brand
/// has been provisioned ([BrandCore.gateEnabled] = true) or the host's
/// fallback home directly when the brand is empty — so dropping this module
/// into a project with no AppsFlyer / Firebase keys is a safe no-op.
class CoreEngine {
  final DataVault cache;
  final ConnRadar radar;
  final SignalSender install;
  final RouteClient gate;
  final PushAgent pulse;
  final bool firebaseReady;

  CoreEngine._({
    required this.cache,
    required this.radar,
    required this.install,
    required this.gate,
    required this.pulse,
    required this.firebaseReady,
  });

  /// Initialises Firebase + AppCheck, warms up the HTTP client and opens the
  /// persistence layer. Safe to call multiple times — Firebase guards against
  /// `[core/duplicate-app]` internally on most versions.
  static Future<CoreEngine> prepare() async {
    final firebaseReady = await _bootFirebase();

    await safeNet.warmup();

    final cache = DataVault();
    try {
      await cache.bootstrap();
    } catch (err) {
      if (kDebugMode) debugPrint('[CoreEngine] DataVault failed: $err');
    }

    final radar = ConnRadar();
    final install = SignalSender();
    final gate = RouteClient(cache);
    final pulse = PushAgent(cache);

    return CoreEngine._(
      cache: cache,
      radar: radar,
      install: install,
      gate: gate,
      pulse: pulse,
      firebaseReady: firebaseReady,
    );
  }

  /// Returns the widget the host app should mount as its `home`.
  ///
  ///   • If the brand has been provisioned, this is the core [AppGateway].
  ///   • If the brand is empty (no AppsFlyer dev key AND no gateway URL),
  ///     this short-circuits straight to [fallbackHomeBuilder] — no boot
  ///     pipeline, no splash, no gateway requests.
  ///
  /// Pass [splashBuilder] to replace the default splash. See
  /// [SplashFactory] / [AppGateway] for the contract.
  Widget buildHome({
    required WidgetBuilder fallbackHomeBuilder,
    SplashFactory? splashBuilder,
  }) {
    if (!BrandCore.gateEnabled) {
      return Builder(builder: fallbackHomeBuilder);
    }
    return AppGateway(
      cache: cache,
      radar: radar,
      install: install,
      gate: gate,
      pulse: pulse,
      fallbackHomeBuilder: fallbackHomeBuilder,
      splashBuilder: splashBuilder,
    );
  }

  static Future<bool> _bootFirebase() async {
    try {
      await Firebase.initializeApp();
    } catch (err) {
      if (kDebugMode) debugPrint('[CoreEngine] Firebase skipped: $err');
      return false;
    }
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
      );
    } catch (err) {
      if (kDebugMode) debugPrint('[CoreEngine] AppCheck skipped: $err');
    }
    return true;
  }
}
