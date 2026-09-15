import 'package:web/web.dart' as web;

/// Browser-side storage. Selected by the conditional import in `storage.dart`;
/// the stub is used everywhere else.
///
/// Every call is guarded: a browser can refuse storage outright (private
/// browsing, blocked site data), and that must degrade rather than throw.

void saveWebStorage(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {}
}

String? readWebStorage(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void removeWebStorage(String key) {
  try {
    web.window.localStorage.removeItem(key);
    web.window.sessionStorage.removeItem(key);
  } catch (_) {}
}
