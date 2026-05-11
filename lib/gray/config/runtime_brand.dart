import 'dart:io';

import '../utils/byte_unmask.dart';
import 'gateway_endpoints.dart';

/// Per-brand constants that control the gray boot flow.
///
/// Values that need to stay private (AppsFlyer dev key, Firebase project
/// number) are stored as obfuscated byte arrays — use
/// `dart run tool/encode_keys.dart` to generate them.
///
/// Until the brand owner ships the real keys, the arrays are empty and
/// [gateEnabled] returns `false`. In that state [GrayBoot.buildHome]
/// short-circuits straight to the host's `fallbackHomeBuilder`, so the app
/// stays fully functional even before the gray flow has been provisioned.

// TODO: when Android AppsFlyer dev key arrives, run `dart run tool/encode_keys.dart`
// with appsflyer_dev_key_android filled in and paste the resulting bytes here.
const List<int> _installKeyAndroid = <int>[];

// TODO: when iOS AppsFlyer dev key arrives, encode and paste here.
// (Leave empty if this project is Android-only.)
const List<int> _installKeyIos = <int>[];

// TODO: when Firebase project number arrives, run the encode tool and paste here.
const List<int> _firebaseProjectAndroid = <int>[];

// TODO: iOS Firebase project number (leave empty for Android-only builds).
const List<int> _firebaseProjectIos = <int>[];

abstract final class RuntimeBrand {
  /// Android applicationId — MUST match `android/app/build.gradle.kts` and
  /// `android/app/src/main/AndroidManifest.xml`.
  static const String packageName = 'com.mikhaillb.tower_balance';

  /// Store-side identifier sent in gateway payloads.
  static const String storeIdentifier = 'com.mikhaillb.tower_balance';

  /// Display name used in any user-facing copy the gray flow renders.
  static const String displayTitle = 'TowerBalance';

  /// App Store numeric ID — used on iOS for AppsFlyer `AppsFlyerOptions.appId`.
  /// TODO: fill in when this app is also published on the App Store.
  static const String iosAppId = '0000000000';

  /// Three days, expressed in seconds. After the user taps "Skip" on the
  /// in-app push opt-in screen we hide it for this long before offering again.
  static const int notifyCooldownSeconds = 60 * 60 * 24 * 3;

  /// Delay before re-querying AppsFlyer GCD when the SDK reports an Organic
  /// install. Some attribution paths become Non-organic only after the
  /// click is matched server-side, so a quick refetch picks them up.
  static const int organicRefetchSeconds = 6;

  static String get installDevKey => Platform.isIOS
      ? unmask(_installKeyIos)
      : unmask(_installKeyAndroid);

  static String get firebaseProjectNumber => Platform.isIOS
      ? unmask(_firebaseProjectIos)
      : unmask(_firebaseProjectAndroid);

  static String get configUrl => gateEndpoint();
  static String get chromeBuild => webChromeVersion();
  static String get safariBuild => webSafariVersion();
  static String get privacyUrl => brandPrivacyUrl;
  static String get supportUrl => brandSupportUrl;

  /// `true` when at least one piece of the gray gate has been provisioned.
  /// [GrayBoot.buildHome] consults this to decide whether to mount the gray
  /// entry gate at all — when `false` (no keys yet) the host app's
  /// `fallbackHomeBuilder` is rendered directly, with zero gray overhead.
  static bool get gateEnabled =>
      configUrl.isNotEmpty || installDevKey.isNotEmpty;
}
