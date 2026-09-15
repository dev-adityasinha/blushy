import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'api_blushy_service.dart';

/// Supplies the device's push token.
///
/// This is the seam where a messaging SDK plugs in. It is deliberately not
/// `firebase_messaging` yet: that plugin needs `android/app/google-services.json`
/// from a real Firebase project, and adding it without that file breaks the
/// Android build for everyone. Once the project exists, implement this with
/// `FirebaseMessaging.instance.getToken()` and `onTokenRefresh`.
abstract class PushTokenSource {
  /// The current token, or null when push is unavailable or not yet granted.
  Future<String?> getToken();

  /// Fires whenever the provider rotates the token. A rotated token must be
  /// registered or the device silently stops receiving anything.
  Stream<String> get onTokenRefresh;
}

/// The state before a provider is configured: no token, so nothing registers.
/// Every call below becomes a no-op rather than a failure, so sign-in and
/// sign-out work exactly as they do today.
class UnconfiguredPushTokenSource implements PushTokenSource {
  const UnconfiguredPushTokenSource();

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();
}

/// Keeps the server's idea of this device in step with the actual token.
///
/// The server holds one row per (user, token) and never returns the token
/// again, so re-registering is cheap and idempotent.
class PushRegistrationService {
  PushRegistrationService({PushTokenSource? tokenSource})
      : _tokenSource = tokenSource ?? const UnconfiguredPushTokenSource();

  final PushTokenSource _tokenSource;

  String? _registeredToken;
  bool _listening = false;

  /// Whether a token was actually registered. False simply means push is not
  /// configured on this build; it is not an error.
  bool get isRegistered => _registeredToken != null;

  /// The value the backend expects in `platform`.
  @visibleForTesting
  static String resolvePlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {
      // Platform is unavailable on some targets; fall through.
    }
    return 'web';
  }

  /// Call after sign-in. Safe to call repeatedly.
  Future<void> registerCurrentDevice({String? appVersion}) async {
    final token = await _tokenSource.getToken();
    if (token == null || token.isEmpty) return;

    await _register(token, appVersion: appVersion);

    if (!_listening) {
      _listening = true;
      _tokenSource.onTokenRefresh.listen((refreshed) {
        // The old token stops working the moment it rotates, so drop it before
        // claiming the new one.
        unawaited(_replace(refreshed, appVersion: appVersion));
      });
    }
  }

  Future<void> _replace(String token, {String? appVersion}) async {
    final previous = _registeredToken;
    if (previous != null && previous != token) {
      await NotificationsApi.unregisterDevice(previous);
    }
    await _register(token, appVersion: appVersion);
  }

  Future<void> _register(String token, {String? appVersion}) async {
    final result = await NotificationsApi.registerDevice(
      token: token,
      platform: resolvePlatform(),
      appVersion: appVersion,
    );
    if (!result.isError) {
      _registeredToken = token;
    } else {
      debugPrint('BlushyPush: device registration failed: ${result.errorCode}');
    }
  }

  /// Call before sign-out, so the next person to use this device does not
  /// receive the previous account's notifications.
  Future<void> unregisterCurrentDevice() async {
    final token = _registeredToken ?? await _tokenSource.getToken();
    _registeredToken = null;
    if (token == null || token.isEmpty) return;
    await NotificationsApi.unregisterDevice(token);
  }
}
