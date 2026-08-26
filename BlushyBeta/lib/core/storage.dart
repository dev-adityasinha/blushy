import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'web_storage_stub.dart' if (dart.library.html) 'web_storage_html.dart';

class BlushyStorage {
  static final Map<String, dynamic> _memoryCache = {};

  static void write(String key, Map<String, dynamic> data) {
    _memoryCache[key] = data;
    final jsonStr = jsonEncode(data);

    if (kIsWeb) {
      saveWebStorage(key, jsonStr);
    } else {
      try {
        final file = File(key);
        file.writeAsStringSync(jsonStr);
      } catch (_) {}
    }
  }

  static Map<String, dynamic> read(String key) {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key] ?? {};
    }

    if (kIsWeb) {
      final webDataStr = readWebStorage(key);
      if (webDataStr != null && webDataStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(webDataStr);
          if (decoded is Map<String, dynamic>) {
            _memoryCache[key] = decoded;
            return decoded;
          }
        } catch (_) {}
      }
    } else {
      try {
        final file = File(key);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _memoryCache[key] = decoded;
            return decoded;
          }
        }
      } catch (_) {}
    }

    return {};
  }
}
