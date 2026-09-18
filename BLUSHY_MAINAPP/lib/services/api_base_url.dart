import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, debugPrint;

/// Where the app looks for the backend.
///
/// Getting this wrong does not look like a configuration problem in the UI: an
/// unreachable host throws on connect, and every server-backed card reports
/// itself as offline. So the debug defaults below matter.
String resolveApiBaseUrl() {
  // Explicit override always wins:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.9.31:3000
  // This is the only thing that works on a physical phone, which has to reach
  // the dev machine by its address on the network.
  const envUrl = String.fromEnvironment('API_BASE_URL');
  if (envUrl.isNotEmpty) {
    return envUrl;
  }

  final resolved = _resolve();
  if (kDebugMode && resolved != _lastLoggedBaseUrl) {
    // Logged once, not per request: this is called on every call site, and at
    // one line per HTTP request it buried the errors it was meant to help
    // diagnose. Only a change in the resolved host is worth a line.
    _lastLoggedBaseUrl = resolved;
    debugPrint('[api] base url: $resolved');
  }
  return resolved;
}

/// Last value printed, so an unchanged host stays quiet.
String? _lastLoggedBaseUrl;

String _resolve() {
  // Web: the page's own origin tells us whether this is local dev or live.
  if (kIsWeb) {
    final host = Uri.base.host;
    if (host == 'localhost' || host == '127.0.0.1') {
      return 'http://localhost:3000';
    }
    if (host.contains('pinggy') || host.contains('trycloudflare')) {
      return 'https://scott-reid-newspapers-sleeps.trycloudflare.com';
    }
    return _liveBaseUrl;
  }

  if (kDebugMode) {
    // 127.0.0.1 on Android is the *phone's* own loopback, not the dev machine.
    // It works here only because `adb reverse tcp:3000 tcp:3000` forwards that
    // port back over USB -- run it once per device connection:
    //
    //   adb reverse tcp:3000 tcp:3000
    //
    // That path is preferred over the machine's LAN address because many
    // networks (including "RU Wifi" here) isolate clients from each other, so
    // the phone cannot open a socket to the laptop even on the same subnet.
    // It also works for the emulator, which otherwise needs the 10.0.2.2 alias.
    //
    // Without the tunnel, pass the machine's address explicitly:
    //   --dart-define=API_BASE_URL=http://10.0.9.31:3000
    return 'http://127.0.0.1:3000';
  }

  return _liveBaseUrl;
}

/// The deployed backend, for release builds and the hosted web build.
///
/// A Docker web service on Render (`blushy-api-new`), built from
/// `BLUSHY_MAINAPP/backend/Dockerfile` on the `dev-adityasinha/blushy` repo.
/// It replaced `blushy-api-l51h`, which lived in a different Render account
/// and was suspended on 2026-09-17 -- it now answers 503. Both pointed at the
/// same Atlas cluster, so while both ran, whichever one a client reached held
/// the scheduler lease and wrote the data.
///
/// CORS_ORIGIN on this service is the hosted web origin
/// (`https://blushy-web-upload-eight.vercel.app`), verified by preflight:
/// the service returns that origin and refuses others. `isAllowedOrigin` in
/// backend/src/app.js always permits localhost, so local dev needs no entry.
/// A web build shipped against a host whose CORS_ORIGIN omits its own origin
/// loads the page and then fails every request, which in the browser looks
/// like an app that simply does nothing -- so check the preflight before
/// deploying web against a new backend.
///
/// Android is unaffected either way: native HTTP is not subject to CORS, and
/// `app.js` admits a request with no Origin header at all.
///
/// Before that it was api.blushy.life, a VPS nothing in this repository
/// deploys to.
///
/// Render's free plan stops the instance when it is idle, and the first
/// request after that pays the cold start: measured at 27s, and the client
/// timeout has to be able to absorb it. `ApiWarmup.ping()` fires during
/// startup so that wait is spent behind the splash rather than under the first
/// card the user looks at.
const String _liveBaseUrl = 'https://blushy-api-new.onrender.com';
