import 'dart:async';

abstract class AuthService {
  Future<bool> signUpWithEmail(String email, String password);
  Future<bool> verifyCode(String email, String code);
  Future<bool> loginWithEmail(String email, String password, {String? role});
  Future<bool> resetPassword(String email);
  Future<void> signOut();
}

class MockAuthService implements AuthService {
  // Simple in-memory mock database of registered emails
  static final Set<String> _registeredEmails = {'existing@blushy.life'};
  
  // Temporary storage for verification codes: email -> code
  static final Map<String, String> _verificationCodes = {};

  @override
  Future<bool> signUpWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (_registeredEmails.contains(email)) {
      throw Exception('Looks like you already have a Blushy account.');
    }
    // Generate a simple verification code: '123456'
    _verificationCodes[email] = '123456';
    return true;
  }

  @override
  Future<bool> verifyCode(String email, String code) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final correctCode = _verificationCodes[email] ?? '123456'; // Default mockup code
    if (code != correctCode) {
      throw Exception('Incorrect code. Please try again.');
    }
    // Register the user upon successful verification
    _registeredEmails.add(email);
    _verificationCodes.remove(email);
    return true;
  }

  @override
  Future<bool> loginWithEmail(String email, String password, {String? role}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!_registeredEmails.contains(email)) {
      throw Exception("The email or password doesn't look right.");
    }
    // Simple password validation for mock: passwords must be >= 8 characters
    if (password.length < 8) {
      throw Exception("The email or password doesn't look right.");
    }
    return true;
  }

  @override
  Future<bool> resetPassword(String email) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_registeredEmails.contains(email)) {
      throw Exception('No account found with this email.');
    }
    return true;
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
