/// The invite code the app was launched with.
///
/// A shareable invite arrives as a fragment on the app's own URL --
/// `https://<host>/#code=<64 hex chars>` -- and the fragment is the only part
/// of the link that never reaches a server, which is why the code travels
/// there rather than in the query string.
///
/// Reading it where it is claimed does not work. `MaterialApp` runs its
/// navigator with `reportsRouteUpdateToEngine: true`, so every
/// `pushReplacementNamed` on web rewrites the browser URL through the default
/// hash strategy: a recipient who lands on `/#code=...`, picks an experience
/// and finishes onboarding passes through `/#/onboarding/women` and `/#/home`,
/// and by the time the partner screen mounts the code has been overwritten
/// twice. So it is read once in `main()`, before anything can navigate, and
/// held here.
///
/// On anything other than web `Uri.base` is the working directory and carries
/// no fragment, so capture is a no-op there.
class PendingInviteCode {
  PendingInviteCode._();

  /// Server tokens are 32 random bytes rendered as hex.
  static const int _minCodeLength = 32;

  static String? _code;
  static bool _captured = false;

  /// The code the app was opened with, or null. Reading does not consume it --
  /// a claim that never reached the server has to be able to try again.
  static String? get code => _code;

  static bool get hasCode => _code != null;

  /// Drops the code once the server has given an answer about it, so a screen
  /// that rebuilds does not claim the same invite twice.
  static void clear() {
    _code = null;
  }

  /// Reads the launch URL. Call once, from `main()`, before `runApp`.
  static void captureFromLaunchUrl() {
    if (_captured) return;
    _captured = true;
    _code = parse(Uri.base);
  }

  /// Pulls a usable code out of a launch URL, or returns null.
  ///
  /// Exposed so the parsing can be tested without a browser.
  static String? parse(Uri uri) {
    try {
      final fragment = uri.fragment;
      if (fragment.isEmpty || !fragment.contains('code=')) {
        return null;
      }

      // The hash strategy leaves route paths here too (`/home`), and those
      // contain no `code=`, so they fall out above rather than being parsed.
      final params = Uri.splitQueryString(fragment);
      final code = params['code']?.trim();
      if (code == null || code.length < _minCodeLength) {
        return null;
      }
      return code;
    } catch (_) {
      return null;
    }
  }

  /// Test seam. Not called by the app.
  static void debugReset() {
    _code = null;
    _captured = false;
  }
}
