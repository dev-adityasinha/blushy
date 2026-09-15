class UserProfile {
  final String name;
  final String avatarEmoji;
  final DateTime createdAt;

  UserProfile({
    required this.name,
    required this.avatarEmoji,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'avatarEmoji': avatarEmoji,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String,
        avatarEmoji: json['avatarEmoji'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
