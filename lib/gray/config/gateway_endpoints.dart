import '../utils/byte_unmask.dart';

/// Gateway endpoint and browser-fingerprint helpers for the gray flow.
///
/// Real values are stored as obfuscated byte arrays — use
/// `dart run tool/encode_keys.dart` to generate them. Until the brand owner
/// ships them, the arrays stay empty and [gateEndpoint] / [gcdEndpoint]
/// return empty strings, which makes the gray boot short-circuit to the
/// host's fallback home (see [RuntimeBrand.gateEnabled]).

/// Server gate URL used for the launch dispatch POST.
/// https://towerbalance.com/config.php (encoded).
const List<int> _gateUrlMask = [252, 94, 199, 17, 225, 141, 2, 64, 169, 188, 240, 199, 35, 97, 175, 156, 204, 67, 140, 213, 161, 251, 214, 250, 90, 138, 181, 210, 219, 79, 134, 186, 213, 222, 73];

/// AppsFlyer GCD endpoint used as a fallback when the SDK callback is missed.
/// TODO: encode the GCD host URL and paste here when provided.
const List<int> _gcdHostMask = <int>[];

String gateEndpoint() => unmask(_gateUrlMask);

String gcdEndpoint(String appId, String deviceId) {
  final host = unmask(_gcdHostMask);
  if (host.isEmpty) return '';
  final sep = host.contains('?') ? '&' : '?';
  return '$host${sep}app_id=$appId&device_id=$deviceId';
}

/// Chrome major version reported in the WebView/HTTP user agent.
String webChromeVersion() => '127.0.6533.103';

/// Safari WebKit build number for the iOS user agent variant.
String webSafariVersion() => '605.1.15';

const String brandPrivacyUrl = 'https://towerbalance.com/privacy-policy.html';

const String brandSupportUrl = 'https://towerbalance.com/support.html';
