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
    BlushyStorage.write(_storageKey, {
      'token': token,
      'refreshToken': refreshToken ?? '',
      'userId': userId ?? '',
      'email': email ?? '',
      'role': role ?? 'woman',
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

  static String? getUserId() {
    final data = BlushyStorage.read(_storageKey);
    return data['userId'] as String?;
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
    return data['role'] as String?;
  }

  static void saveRole(String role) {
    final data = BlushyStorage.read(_storageKey);
    data['role'] = role;
    BlushyStorage.write(_storageKey, data);
  }

  static void clearSession() {
    BlushyStorage.write(_storageKey, {});
  }
}
