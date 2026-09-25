import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_base_url.dart';
import 'runtime_env_stub.dart' if (dart.library.io) 'runtime_env_io.dart';

/// Wakes the API before a screen needs it, and lets callers wait for it.
///
/// The service spins down when idle, so the first request after a quiet spell
/// waits on a cold start rather than on the work it asked for. Measured against
/// the live host: a first call hung past 90 seconds and the next answered in
/// 18.3s, while a warm one returns in about a second. Whichever screen made
/// that first call reported a request timeout -- on a stage dashboard that
/// surfaced as "This stage could not be loaded".
///
/// [ping] fires at startup so the wait is spent on the launch screen. [ensureWarm]
/// is the awaitable version: a load that awaits it is held on a spinner until
/// the server is up, then runs for real -- the cold start becomes a wait, not an
/// error. Every ApiContractClient request awaits it, so this covers the app.
class ApiWarmup {
  const ApiWarmup._();

  static bool _warm = false;
  static Future<void>? _warming;

  /// Fire-and-forget startup nudge. Never awaited, never surfaced: a failure
  /// here must not change what any screen does.
  static void ping() {
    // Kick off the shared warm-up; ignore the result on this path.
    ensureWarm();
  }

  /// Completes once the API has answered at least once, so a caller that awaits
  /// it never fires its real request into a cold start.
  ///
  /// Shared across callers and cached once warm (so after the first success it
  /// returns immediately). Time-boxed, so a genuinely-down server does not block
  /// forever: callers then proceed and fall back to their own per-request retry.
  static Future<void> ensureWarm() {
    // Never block tests on a real network ping: the runner has no server, so the
    // warm-up would loop until it timed out under every test that hits a service.
    if (_warm || isUnderFlutterTest) return Future<void>.value();
    return _warming ??= _run();
  }

  static Future<void> _run() async {
    final url = Uri.parse('${resolveApiBaseUrl()}/health');
    final deadline = DateTime.now().add(const Duration(seconds: 75));
    while (DateTime.now().isBefore(deadline)) {
      try {
        // A plain GET with no custom headers is a CORS "simple request", so this
        // works from the web build without a preflight.
        final res = await http.get(url).timeout(const Duration(seconds: 30));
        if (res.statusCode >= 200 && res.statusCode < 500) {
          _warm = true;
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('BlushyWarmup: $e');
        }
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    // Gave up waiting for the wake; let callers proceed on their own retry, and
    // allow a later call to try warming again.
    _warming = null;
  }
}
