/// Decoded response of the remote launch gateway. Accepts a few alternative
/// field names so the same client can talk to slightly different backends
/// without code changes.
class RouteReply {
  final bool granted;
  final String? destination;
  final String? note;
  final int? expiresAtEpoch;

  const RouteReply._({
    required this.granted,
    this.destination,
    this.note,
    this.expiresAtEpoch,
  });

  factory RouteReply.fromMap(Map<String, dynamic> raw) {
    final granted = (raw['ok'] as bool?) ??
        (raw['granted'] as bool?) ??
        (raw['accepted'] as bool?) ??
        false;

    final destination = raw['url'] as String? ??
        raw['link'] as String? ??
        raw['target'] as String? ??
        raw['destination'] as String?;

    final note = raw['message'] as String? ??
        raw['note'] as String? ??
        raw['reason'] as String?;

    final dynamic ttl = raw['expires'] ?? raw['expires_at'] ?? raw['valid_until'];
    int? expires;
    if (ttl is int) {
      expires = ttl;
    } else if (ttl is num) {
      expires = ttl.toInt();
    } else if (ttl is String) {
      expires = int.tryParse(ttl);
    }

    return RouteReply._(
      granted: granted,
      destination: destination,
      note: note,
      expiresAtEpoch: expires,
    );
  }

  factory RouteReply.declined(String reason) {
    return RouteReply._(granted: false, note: reason);
  }
}
