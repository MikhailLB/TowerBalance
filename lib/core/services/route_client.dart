import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/brand_core.dart';
import '../models/route_reply.dart';
import 'data_vault.dart';
import 'safe_net.dart';

/// Sends the install/launch payload to the remote gateway and persists the
/// destination URL for future runs. When the gateway URL is unset (no key
/// shipped yet) the client returns [RouteReply.declined] so callers fall
/// back to the local arcade flow without crashing.
class RouteClient {
  final DataVault _cache;

  RouteClient(this._cache);

  Future<RouteReply> dispatch(Map<String, dynamic> body) async {
    final endpoint = BrandCore.configUrl;
    if (endpoint.isEmpty) {
      if (kDebugMode) {
        debugPrint('[RGC] gateway endpoint missing — declined');
      }
      return RouteReply.declined('endpoint_missing');
    }

    try {
      final uri = Uri.parse(endpoint);
      final response = await safeNet
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 18));

      if (kDebugMode) {
        debugPrint('[RGC] status=${response.statusCode}');
        final preview = response.body.length > 600
            ? '${response.body.substring(0, 600)}…'
            : response.body;
        debugPrint('[RGC] body=$preview');
      }

      if (response.statusCode != 200) {
        return RouteReply.declined('http_${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return RouteReply.declined('bad_json');
      }

      final reply = RouteReply.fromMap(decoded);
      if (reply.granted && reply.destination != null) {
        await _cache.writeCachedTarget(reply.destination!);
        final ttl = reply.expiresAtEpoch;
        if (ttl != null) {
          await _cache.writeCachedTtl(ttl);
        }
      }
      return reply;
    } catch (err, st) {
      if (kDebugMode) {
        debugPrint('[RGC] dispatch error: $err');
        debugPrint('$st');
      }
      return RouteReply.declined(err.toString());
    }
  }
}
