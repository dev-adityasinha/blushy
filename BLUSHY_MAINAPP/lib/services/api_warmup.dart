import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_base_url.dart';

/// Wakes the API before a screen needs it.
///
/// The service spins down when idle, so the first request after a quiet spell
/// waits on a cold start rather than on the work it asked for. Measured
/// against the live host: a first call hung past 90 seconds and the next
/// answered in 18.3s, while a warm one returns in about a second. Whichever
/// screen made that first call reported a request timeout — on the home page,
/// Docsy insights and cycle patterns.
///
/// Firing it at startup means the wait is spent on the launch screen, where
/// nothing is blocked on it, instead of under a card the user is looking at.
class ApiWarmup {
  const ApiWarmup._();

  static bool _started = false;

  /// Fire-and-forget. Never awaited, never surfaced: this is an optimisation,
  /// and a failure here must not change what any screen does.
  static void ping() {
    if (_started) return;
    _started = true;

    http
        .get(Uri.parse(resolveApiBaseUrl()))
        .timeout(const Duration(seconds: 60))
        .then((_) {}, onError: (Object e) {
      if (kDebugMode) {
        debugPrint('BlushyWarmup: $e');
      }
    });
  }
}
