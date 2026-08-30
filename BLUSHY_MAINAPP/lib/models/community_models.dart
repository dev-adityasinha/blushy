class CommunityPost {
  final String postId;
  final String authorId;
  final String authorName;
  final String title;
  final String text;
  final List<String> tags;
  final String postType;
  final int score;
  final int commentCount;
  final int userVote; // 1, -1, 0
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Attached by the server to any post touching a health topic, so a reader
  /// is never left to infer that a community post carries clinical authority
  /// (spec section 12).
  final String? moderationNotice;

  /// Community content is never clinically reviewed. Stated explicitly rather
  /// than left implicit.
  final bool isClinicallyReviewed;

  final List<String> sensitiveTopics;

  CommunityPost({
    required this.postId,
    this.authorId = '',
    required this.authorName,
    required this.title,
    required this.text,
    required this.tags,
    this.postType = 'discussion',
    this.moderationNotice,
    this.isClinicallyReviewed = false,
    this.sensitiveTopics = const [],
    required this.score,
    this.commentCount = 0,
    required this.userVote,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      postId: json['postId'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? 'Anonymous',
      title: json['title'] ?? '',
      text: json['text'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      postType: json['postType'] ?? json['post_type'] ?? 'discussion',
      score: json['score'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      userVote: json['userVote'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      moderationNotice: json['moderationNotice'] as String?,
      isClinicallyReviewed: json['isClinicallyReviewed'] == true,
      sensitiveTopics: List<String>.from(json['sensitiveTopics'] ?? const []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'title': title,
      'text': text,
      'tags': tags,
      'postType': postType,
      'score': score,
      'commentCount': commentCount,
      'userVote': userVote,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class DashboardPersonalizedCommunityPayload {
  final bool isPersonalized;
  final String? fallbackLabel;
  final DateTime generatedAt;
  final String personalizationVersion;
  final List<CommunityPost> questions;
  final List<CommunityPost> stories;
  final List<CommunityPost> tips;
  final List<CommunityPost> trending;

  DashboardPersonalizedCommunityPayload({
    required this.isPersonalized,
    this.fallbackLabel,
    required this.generatedAt,
    required this.personalizationVersion,
    required this.questions,
    required this.stories,
    required this.tips,
    required this.trending,
  });

  factory DashboardPersonalizedCommunityPayload.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json);

    return DashboardPersonalizedCommunityPayload(
      isPersonalized: data['isPersonalized'] == true,
      fallbackLabel: data['fallbackLabel'] as String?,
      generatedAt: data['generatedAt'] != null
          ? DateTime.tryParse(data['generatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      personalizationVersion: data['personalizationVersion']?.toString() ?? 'v1',
      questions: (data['questions'] as List? ?? [])
          .map((i) => CommunityPost.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
      stories: (data['stories'] as List? ?? [])
          .map((i) => CommunityPost.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
      tips: (data['tips'] as List? ?? [])
          .map((i) => CommunityPost.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
      trending: (data['trending'] as List? ?? [])
          .map((i) => CommunityPost.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }

  factory DashboardPersonalizedCommunityPayload.emptyFallback({String fallbackLabel = 'Popular in the community'}) {
    return DashboardPersonalizedCommunityPayload(
      isPersonalized: false,
      fallbackLabel: fallbackLabel,
      generatedAt: DateTime.now(),
      personalizationVersion: 'v1',
      questions: const [],
      stories: const [],
      tips: const [],
      trending: const [],
    );
  }
}

class CommunityComment {
  final String commentId;
  final String postId;
  final String? parentId;
  final String authorId;
  final String authorName;
  final String text;
  final int score;
  final int userVote; // 1, -1, 0
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Attached by the server when a comment touches a health topic, for the
  /// same reason posts carry one (spec section 12).
  final String? moderationNotice;
  final bool isClinicallyReviewed;

  List<CommunityComment> replies;

  CommunityComment({
    required this.commentId,
    required this.postId,
    this.parentId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.score,
    required this.userVote,
    required this.createdAt,
    required this.updatedAt,
    this.replies = const [],
      this.moderationNotice,
    this.isClinicallyReviewed = false,
});

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      commentId: json['commentId'] ?? '',
      postId: json['postId'] ?? '',
      parentId: json['parentId'],
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? 'Anonymous',
      text: json['text'] ?? '',
      score: json['score'] ?? 0,
      userVote: json['userVote'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      moderationNotice: json['moderationNotice'] as String?,
      isClinicallyReviewed: json['isClinicallyReviewed'] == true,
      replies: [],
    );
  }
}

class UserProfileData {
  final String userId;
  final String displayName;
  final String bio;
  final int karma;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final String email;

  UserProfileData({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.karma,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
    this.email = '',
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      userId: json['userId'] ?? '',
      displayName: json['displayName'] ?? 'Anonymous',
      bio: json['bio'] ?? '',
      karma: json['karma'] ?? 0,
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      isFollowing: json['isFollowing'] ?? false,
      email: json['email'] ?? '',
    );
  }
}
