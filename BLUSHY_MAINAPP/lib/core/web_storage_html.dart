// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void saveWebStorage(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

String? readWebStorage(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void removeWebStorage(String key) {
  try {
    html.window.localStorage.remove(key);
    html.window.sessionStorage.remove(key);
  } catch (_) {}
}


