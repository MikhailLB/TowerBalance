import '../utils/byte_unmask.dart';

/// Gateway endpoint and browser-fingerprint helpers for the gray flow.
///
/// Real values are stored as obfuscated byte arrays — use
/// `dart run tool/encode_keys.dart` to generate them. Until the brand owner
/// ships them, the arrays stay empty and [gateEndpoint] / [gcdEndpoint]
/// return empty strings, which makes the gray boot short-circuit to the
/// host's fallback home (see [RuntimeBrand.gateEnabled]).

/// Server gate URL used for the launch dispatch POST.
/// TODO: encode the gateway URL and paste the byte array here when provided.
const List<int> _gateUrlMask = <int>[];

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

/// TODO: replace with the real TowerBalance privacy policy URL.
const String brandPrivacyUrl = 'https://example.com/privacy';

/// TODO: replace with the real TowerBalance support URL.
const String brandSupportUrl = 'https://example.com/support';
