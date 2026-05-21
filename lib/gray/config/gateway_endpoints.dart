import '../utils/byte_unmask.dart';

/// Gateway endpoint and browser-fingerprint helpers for the gray flow.
///
/// Real values are XOR-masked at rest (see [unmask] / `byte_unmask.dart`) so
/// they don't appear in plaintext inside the binary. When a value isn't
/// provisioned the corresponding mask is left empty, [gateEndpoint] /
/// [gcdEndpoint] return an empty string and [RemoteGateClient] short-circuits
/// to the offline arcade fallback path.

// Server gate URL used for the launch dispatch POST. Plaintext is:
// "https://towerbalancebuildhold.com/config.php".
const List<int> _gateUrlMask = <int>[
  203, 173, 173, 29, 165, 43, 68, 7, 193, 37, 165, 81,
  126, 88, 236, 90, 235, 150, 153, 81, 223, 140, 63, 249,
  119, 123, 174, 115, 190, 83, 84, 153, 45, 227, 251, 205,
  60, 144, 201, 110, 46, 34, 134, 0,
];

// AppsFlyer GCD endpoint used as a backup when the SDK callback is missed.
// Format will be: "<host>?app_id=...&device_id=...".
const List<int> _gcdHostMask = <int>[];

String gateEndpoint() => unmask(_gateUrlMask);

String gcdEndpoint(String appId, String deviceId) {
  final host = unmask(_gcdHostMask);
  if (host.isEmpty) return '';
  final sep = host.contains('?') ? '&' : '?';
  return '$host${sep}app_id=$appId&device_id=$deviceId';
}

/// Chrome major version reported in the WebView/HTTP user agent. Keep this
/// close to the actual current release so the UA doesn't stand out as stale.
/// Chrome 136 was the stable channel as of May 2026.
String webChromeVersion() => '136.0.7103.93';

/// Safari WebKit build number for the iOS user agent variant.
String webSafariVersion() => '605.1.15';

const String brandPrivacyUrl =
    'https://towerbalancebuildhold.com/privacy-policy.html';
const String brandSupportUrl =
    'https://towerbalancebuildhold.com/support.html';
const String brandSiteUrl = 'https://towerbalancebuildhold.com';
