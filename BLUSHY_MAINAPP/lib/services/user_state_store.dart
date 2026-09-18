import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/storage.dart';
import 'api_base_url.dart';
import 'auth_storage.dart';

/// Screen documents that belong to the account, not to one installation.
///
/// Thirteen of these were written with `BlushyStorage` and nowhere else: the
/// period kit, the school bag, what she is noticing, her life mode, her
/// treatments and support circle, her health records, her reflections. They
/// were invisible on the web, absent for a clinician, and gone with a
/// reinstall -- and `stage4_treatments` is medication history.
///
/// The server is the record; the device keeps a mirror so the screens can go
/// on reading synchronously during a build, and so a phone with no signal
/// still shows what it had. [hydrate] pulls the account's copy in at startup
/// and overwrites the mirror, so a second device does not keep showing its
/// own stale version.
class UserStateStore {
  UserStateStore._();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: resolveApiBaseUrl(),
    connectTimeout: const Duration(seconds: 15),
    // Absorbs a Render cold start, as the other services do.
    receiveTimeout: const Duration(seconds: 60),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  ));

  static Options _auth() {
    final token = AuthStorage.getToken();
    return Options(headers: {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });
  }

  /// Local file backing the mirror for [key].
  static String _mirrorKey(String key) => '$key.json';

  /// The account's documents, read once after sign-in.
  ///
  /// Failure is not fatal and not silent: the mirror stays as it was, which is
  /// the right answer offline, and the screens carry on.
  static Future<bool> hydrate() async {
    if ((AuthStorage.getToken() ?? '').isEmpty) return false;
    try {
      final response = await _dio.get('/api/v1/user-state', options: _auth());
      final data = response.data;
      if (data is! Map || data['state'] is! Map) return false;

      final state = Map<String, dynamic>.from(data['state'] as Map);
      state.forEach((key, value) {
        if (value is Map) {
          BlushyStorage.write(_mirrorKey(key), Map<String, dynamic>.from(value));
        }
      });
      debugPrint('[user-state] hydrated ${state.length} document(s)');
      return true;
    } catch (e) {
      debugPrint('[user-state] hydrate failed: $e');
      return false;
    }
  }

  /// The mirror, read synchronously so a `build` can use it unchanged.
  static Map<String, dynamic> read(String key) {
    try {
      return BlushyStorage.read(_mirrorKey(key));
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Writes the mirror now and the account in the background.
  ///
  /// The mirror first on purpose: the screen has already shown the change, and
  /// a slow or refused request must not undo it on screen. A failed PUT leaves
  /// the device ahead of the server until the next successful write of the
  /// same key, which is the same bargain the check-in sheet makes.
  static void write(String key, Map<String, dynamic> value) {
    try {
      BlushyStorage.write(_mirrorKey(key), value);
    } catch (_) {}
    unawaited(_push(key, value));
  }

  static Future<void> _push(String key, Map<String, dynamic> value) async {
    if ((AuthStorage.getToken() ?? '').isEmpty) return;
    try {
      await _dio.put('/api/v1/user-state/$key', data: {'value': value}, options: _auth());
    } catch (e) {
      debugPrint('[user-state] could not save "$key": $e');
    }
  }

  /// Fire-and-forget without importing dart:async at every call site.
  static void unawaited(Future<void> future) {
    future.catchError((Object e) {
      debugPrint('[user-state] background write failed: $e');
    });
  }
}
