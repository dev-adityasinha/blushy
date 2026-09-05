import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_base_url.dart';

/// Wakes the API before a screen needs it, and says when it is awake.
///
/// The service spins down when idle, so the first request after a quiet spell
/// waits on a cold start rather than on the work it asked for. Measured
/// against the live host: a first call hung past 90 seconds and the next
/// answered in 18.3s, while a warm one returns in about a second. Whichever
/// screen made that first call reported a request timeout -- on the home
/// page, Docsy insights and cycle patterns, and at sign-in.
///
/// Firing it at startup means the wait is spent on the launch screen, where
/// nothing is blocked on it, instead of under a card the user is looking at.
/// [ready] lets a request that ran into the cold start anyway wait for the
/// wake-up to finish before trying once more, instead of failing.
class ApiWarmup {
  const ApiWarmup._();

  /// A client to send with instead of the package's top-level functions;
  /// tests hand in a MockClient. Null in the app.
  static http.Client? clientOverride;

  static Completer<bool>? _completer;
  static bool _awake = false;

  /// True once the API has answered anything since launch.
  static bool get awake => _awake;

  /// Completes when the wake-up ping has answered (true) or given up (false).
  /// Completes at once when no ping was started.
  static Future<bool> get ready => _completer?.future ?? Future.value(_awake);

  /// Fire-and-forget. Never awaited by the caller, never surfaced: this is an
  /// optimisation, and a failure here must not change what any screen does.
  static void ping() {
    if (_completer != null) return;
    final completer = _completer = Completer<bool>();
    _attempt(2).then((ok) {
      _awake = ok;
      if (!completer.isCompleted) completer.complete(ok);
    });
  }

  /// A request that reached the API can report it awake, so a later retry
  /// does not wait on a ping that has already been overtaken.
  static void noteAwake() {
    _awake = true;
    final c = _completer;
    if (c != null && !c.isCompleted) c.complete(true);
  }

  static Future<bool> _attempt(int tries) async {
    final client = clientOverride ?? http.Client();
    for (var i = 0; i < tries; i++) {
      try {
        // Long enough for the cold start itself; a second try covers a host
        // that took longer than that to come up.
        final response = await client
            .get(Uri.parse('${resolveApiBaseUrl()}/health'))
            .timeout(const Duration(seconds: 75));
        if (response.statusCode < 500) return true;
      } catch (e) {
        if (kDebugMode) debugPrint('BlushyWarmup: $e');
      }
    }
    return false;
  }

  /// Tests only: forgets the ping so the next [ping] starts afresh.
  @visibleForTesting
  static void reset() {
    _completer = null;
    _awake = false;
  }
}
