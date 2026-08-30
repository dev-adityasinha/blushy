import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

String resolveApiBaseUrl() {
  // Allow environment override if passed via --dart-define=API_BASE_URL=...
  const envUrl = String.fromEnvironment('API_BASE_URL');
  if (envUrl.isNotEmpty) {
    return envUrl;
  }

  // Web browser target: dynamically detect local dev vs live production domain
  if (kIsWeb) {
    final host = Uri.base.host;
    if (host == 'localhost' || host == '127.0.0.1') {
      return 'http://localhost:3000';
    }
    return 'https://api.blushy.life';
  }

  // Debug mode for mobile / native apps
  if (kDebugMode) {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {}
    return 'http://localhost:3000';
    return 'http://127.0.0.1:3000';
  }

  // Production fallback for mobile / native apps
  return 'https://api.blushy.life';
}
