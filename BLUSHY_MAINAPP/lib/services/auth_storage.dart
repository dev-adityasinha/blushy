import '../core/storage.dart';

class AuthStorage {
  static const String _storageKey = 'blushy_auth_session.json';

  static void saveSession({
    required String token,
    String? refreshToken,
    String? userId,
    String? email,
    String? role,
    bool onboardingCompleted = false,
  }) {
    // Purge memory cache before saving new user identity
    BlushyStorage.clearMemoryCache();

    final normalizedRole = (role == 'partner' || role == 'man') ? 'partner' : 'woman';
    BlushyStorage.write(_storageKey, {
      'token': token,
      'refreshToken': refreshToken ?? '',
      'userId': userId ?? '',
      'email': email ?? '',
      'role': normalizedRole,
      'onboardingCompleted': onboardingCompleted,
    });
  }

  static String? getToken() {
    final data = BlushyStorage.read(_storageKey);
    final token = data['token'] as String?;
    if (token != null && token.isNotEmpty) {
      return token;
    }
    return null;
  }

  /// The refresh token saved at sign-in. It was written and never read, so an
  /// expired session had no way back other than signing in again.
  static String? getRefreshToken() {
    final data = BlushyStorage.read(_storageKey);
    final value = data['refreshToken'];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static String? getUserId() {
    final data = BlushyStorage.read(_storageKey);
    final uid = data['userId'] as String?;
    if (uid != null && uid.trim().isNotEmpty) {
      return uid.trim();
    }
    return null;
  }

  static bool isOnboardingCompleted() {
    final data = BlushyStorage.read(_storageKey);
    return data['onboardingCompleted'] == true;
  }

  static Map<String, dynamic> getSession() {
    return BlushyStorage.read(_storageKey);
  }

  static String? getRole() {
    final data = BlushyStorage.read(_storageKey);
    final rawRole = data['role'] as String?;
    if (rawRole == 'partner' || rawRole == 'man') {
      return 'partner';
    }
    if (rawRole == 'woman' || rawRole == 'girl') {
      return 'woman';
    }
    return rawRole;
  }

  static void saveRole(String role) {
    final normalizedRole = (role == 'partner' || role == 'man') ? 'partner' : 'woman';
    final data = BlushyStorage.read(_storageKey);
    data['role'] = normalizedRole;
    BlushyStorage.write(_storageKey, data);
  }

  static void clearSession() {
    BlushyStorage.clearMemoryCache();
    BlushyStorage.write(_storageKey, {});
  }
}
