class OtpSendResponse {
  const OtpSendResponse({
    required this.message,
    required this.expiresIn,
    this.mode,
    this.accountExists,
    this.attemptsLeft,
    this.maxAttempts,
    this.verificationSkipped = false,
    this.debugOtp,
    this.verificationLink,
    this.deliveryFallbackUsed = false,
  });

  final String message;
  final int expiresIn;
  final String? mode;
  final bool? accountExists;
  final int? attemptsLeft;
  final int? maxAttempts;
  final bool verificationSkipped;
  final String? debugOtp;
  final String? verificationLink;
  final bool deliveryFallbackUsed;

  factory OtpSendResponse.fromJson(Map<String, dynamic> json) {
    return OtpSendResponse(
      message: json['message'] as String? ?? 'Verification code sent',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 60,
      mode: json['mode'] as String?,
      accountExists: json['accountExists'] as bool?,
      attemptsLeft: (json['attemptsLeft'] as num?)?.toInt(),
      maxAttempts: (json['maxAttempts'] as num?)?.toInt(),
      verificationSkipped: json['verificationSkipped'] as bool? ?? false,
      debugOtp: (json['debugOtp'] as String?) ?? (json['debugCode'] as String?),
      verificationLink: json['verificationLink'] as String?,
      deliveryFallbackUsed: json['deliveryFallbackUsed'] as bool? ?? false,
    );
  }
}

class OtpVerifyResponse {
  const OtpVerifyResponse({
    required this.message,
    required this.verificationToken,
    required this.verificationExpiresIn,
    required this.accountExists,
    required this.mode,
    required this.attemptsLeft,
    required this.maxAttempts,
  });

  final String message;
  final String verificationToken;
  final int verificationExpiresIn;
  final bool accountExists;
  final String mode;
  final int attemptsLeft;
  final int maxAttempts;

  factory OtpVerifyResponse.fromJson(Map<String, dynamic> json) {
    return OtpVerifyResponse(
      message: json['message'] as String? ?? 'Verification code verified',
      verificationToken: json['verificationToken'] as String? ?? '',
      verificationExpiresIn: (json['verificationExpiresIn'] as num?)?.toInt() ?? 600,
      accountExists: json['accountExists'] as bool? ?? false,
      mode: json['mode'] as String? ?? 'login',
      attemptsLeft: (json['attemptsLeft'] as num?)?.toInt() ?? 0,
      maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 3,
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
  });

  final String message;
  final String token;
  final String userId;
  final String tokenType;
  final int expiresIn;
  final UserRole role;
  final String? email;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      message: json['message'] as String? ?? 'Verified',
      token: json['token'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      role: UserRole.fromValue(json['role'] as String?),
      email: json['email'] as String?,
    );
  }
}

enum UserRole {
  woman('woman', 'Woman', 'Primary account'),
  man('man', 'Man', 'Support account');

  const UserRole(this.value, this.label, this.subtitle);

  final String value;
  final String label;
  final String subtitle;

  static UserRole fromValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'girl' || normalized == 'woman') {
      return UserRole.woman;
    }
    if (normalized == 'partner' || normalized == 'man') {
      return UserRole.man;
    }

    return UserRole.values.firstWhere(
      (role) => role.value == normalized,
      orElse: () => UserRole.woman,
    );
  }
}

class CountryOption {
  const CountryOption({
    required this.label,
    required this.isoCode,
    required this.dialCode,
  });

  final String label;
  final String isoCode;
  final String dialCode;

  static const List<CountryOption> values = [
    CountryOption(label: 'India', isoCode: 'IN', dialCode: '+91'),
    CountryOption(label: 'United States', isoCode: 'US', dialCode: '+1'),
    CountryOption(label: 'United Kingdom', isoCode: 'GB', dialCode: '+44'),
    CountryOption(label: 'Canada', isoCode: 'CA', dialCode: '+1'),
    CountryOption(label: 'Australia', isoCode: 'AU', dialCode: '+61'),
    CountryOption(label: 'Singapore', isoCode: 'SG', dialCode: '+65'),
    CountryOption(label: 'United Arab Emirates', isoCode: 'AE', dialCode: '+971'),
    CountryOption(label: 'South Africa', isoCode: 'ZA', dialCode: '+27'),
  ];
}
