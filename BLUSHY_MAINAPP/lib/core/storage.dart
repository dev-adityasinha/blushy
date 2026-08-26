import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'web_storage_stub.dart' if (dart.library.html) 'web_storage_html.dart';
import '../services/auth_storage.dart';

class BlushyStorage {
  static final Map<String, dynamic> _memoryCache = {};

  static const Set<String> _globalKeys = {
    'blushy_auth_session.json',
    'coach_first_launch.json',
    'generic_discover_cache.json',
  };

  static bool _isGlobalKey(String key) {
    for (final gk in _globalKeys) {
      if (key == gk || key.startsWith(gk.replaceAll('.json', ''))) {
        return true;
      }
    }
    return false;
  }

  /// Atomically resolves the user-scoped storage key per operation.
  /// If the key is private and there is no active authenticated user, returns null to block write/read leaks.
  static String? _resolveKey(String key) {
    if (_isGlobalKey(key)) {
      if (kIsWeb) {
        try {
          final port = Uri.base.port;
          if (port != 0) {
            return '${key.replaceAll('.json', '')}_$port.json';
          }
        } catch (_) {}
      }
      return key.endsWith('.json') ? key : '$key.json';
    }

    // Dynamic resolution per operation based on active verified user ID
    final String? userId = AuthStorage.getUserId();
    if (userId != null && userId.trim().isNotEmpty) {
      final sanitizedUid = userId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final cleanKey = key.replaceAll('.json', '');
      return 'usr_${sanitizedUid}_$cleanKey.json';
    }

    // Missing authenticated userId for private health/profile data
    return null;
  }

  static void write(String key, Map<String, dynamic> data) {
    final resolvedKey = _resolveKey(key);
    // Block/skip writing private health/profile data when there is no authenticated user
    if (resolvedKey == null) {
      debugPrint('[BlushyStorage] Skipped private write for key "$key": No authenticated user session.');
      return;
    }

    _memoryCache[resolvedKey] = data;
    final jsonStr = jsonEncode(data);

    if (kIsWeb) {
      saveWebStorage(resolvedKey, jsonStr);
    } else {
      try {
        final file = File(resolvedKey);
        file.writeAsStringSync(jsonStr);
      } catch (e) {
        debugPrint('[BlushyStorage] Error writing file "$resolvedKey": $e');
      }
    }
  }

  static Map<String, dynamic> read(String key) {
    final resolvedKey = _resolveKey(key);
    // Return empty for private health/profile data when there is no authenticated user
    if (resolvedKey == null) {
      return {};
    }

    if (_memoryCache.containsKey(resolvedKey)) {
      return _memoryCache[resolvedKey] ?? {};
    }

    if (kIsWeb) {
      final webDataStr = readWebStorage(resolvedKey);
      if (webDataStr != null && webDataStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(webDataStr);
          if (decoded is Map<String, dynamic>) {
            _memoryCache[resolvedKey] = decoded;
            return decoded;
          }
        } catch (_) {}
      }
    } else {
      try {
        final file = File(resolvedKey);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _memoryCache[resolvedKey] = decoded;
            return decoded;
          }
        }
      } catch (_) {}
    }

    return {};
  }

  static void delete(String key) {
    final resolvedKey = _resolveKey(key);
    if (resolvedKey != null) {
      _memoryCache.remove(resolvedKey);
    }
    _memoryCache.remove(key);

    if (kIsWeb) {
      if (resolvedKey != null) removeWebStorage(resolvedKey);
      removeWebStorage(key);
    } else {
      if (resolvedKey != null) {
        try {
          final file = File(resolvedKey);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
      try {
        final file = File(key);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
  }

  static void clearUserData() {
    final userKeys = [
      'blushy_auth_session.json',
      'user_profile.json',
      'user_onboarding_answers.json',
      'user_onboarding_wizard_state.json',
      'coach_first_launch.json',
      'partner_decoder_enabled',
      'blushy_prefs.json',
    ];
    for (final key in userKeys) {
      delete(key);
    }
  }

  /// Purges in-memory cache to guarantee zero cross-account state leakage
  static void clearMemoryCache() {
    _memoryCache.clear();
  }

  /// Deletes all user-scoped storage items for a specific user ID
  static void clearUserScopedStorage(String userId) {
    if (userId.trim().isEmpty) return;
    final sanitizedUid = userId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final prefix = 'usr_${sanitizedUid}_';

    _memoryCache.removeWhere((k, v) => k.startsWith(prefix));

    if (!kIsWeb) {
      try {
        final dir = Directory.current;
        final files = dir.listSync();
        for (final f in files) {
          if (f is File && f.uri.pathSegments.last.startsWith(prefix)) {
            f.deleteSync();
          }
        }
      } catch (_) {}
    }
  }
}

