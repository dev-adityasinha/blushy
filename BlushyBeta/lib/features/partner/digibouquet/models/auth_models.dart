enum UserRole {
  woman('woman', 'Woman', 'Woman login'),
  man('man', 'Man', 'Man login');

  const UserRole(this.value, this.label, this.subtitle);

  final String value;
  final String label;
  final String subtitle;

  static UserRole fromValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'girl') {
      return UserRole.woman;
    }
    if (normalized == 'partner') {
      return UserRole.man;
    }

    return UserRole.values.firstWhere(
      (role) => role.value == normalized,
      orElse: () => UserRole.woman,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.message,
    required this.token,
    required this.userId,
    required this.tokenType,
    required this.expiresIn,
    required this.role,
    this.email,
    this.cycleStartDate,
  });

  final String message;
  final String token;
  final String userId;
  final String tokenType;
  final int expiresIn;
  final UserRole role;
  final String? email;
  final DateTime? cycleStartDate;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      message: json['message'] as String? ?? 'Verified',
      token: json['token'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      role: UserRole.fromValue(json['role'] as String?),
      email: json['email'] as String?,
      cycleStartDate: DateTime.tryParse(json['cycleStartDate'] as String? ?? '')?.toUtc(),
    );
  }
}

class UserProfileController {
  UserProfileController._();
  static final UserProfileController instance = UserProfileController._();

  String get displayName => 'You';
}
