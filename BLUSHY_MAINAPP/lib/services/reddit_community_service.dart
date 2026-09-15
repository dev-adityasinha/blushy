import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_base_url.dart';
import 'auth_storage.dart';
import '../models/community_models.dart';

/// Raised when the server refuses a request because too many have arrived.
///
/// Every failure used to collapse into `null`, so being rate limited and the
/// post genuinely failing produced the same "Failed to publish post" message.
/// One of those is worth retrying in a minute and the other is not, and the
/// user could not tell which they had.
class CommunityRateLimited implements Exception {
  const CommunityRateLimited([this.retryAfterSeconds]);

  final int? retryAfterSeconds;

  @override
  String toString() => 'CommunityRateLimited';
}

class RedditCommunityService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: resolveApiBaseUrl(),
    connectTimeout: const Duration(seconds: 15),
    // Despite the name this goes to our own backend, so it pays the same
    // Render cold start (~27s) as the rest; see api_community_service.dart.
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  Options _authOptions() {
    final token = AuthStorage.getToken();
    if (token != null && token.isNotEmpty) {
      return Options(headers: {'Authorization': 'Bearer $token'});
    }
    return Options();
  }

  // --- Post APIs ---

  /// Fetches feed posts based on type: latest, trending, following, home
  /// The feed, optionally narrowed by a search term.
  ///
  /// [search] is applied on the server across every public post, not only the
  /// page the app is holding. Filtering client-side could never find anything
  /// past the first page, while people search hit the server and did.
  Future<List<CommunityPost>> getFeed(String type, {String search = ''}) async {
    try {
      final response = await _dio.get(
        '/posts/feed',
        queryParameters: {
          'type': type,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['posts'] is List) {
        final List list = response.data['posts'];
        return list.map((item) => CommunityPost.fromJson(Map<String, dynamic>.from(item))).toList();
      }
      return [];
    } catch (e) {
      debugPrint('RedditCommunityService: getFeed error: $e');
      return [];
    }
  }

  /// Creates a text post
  Future<CommunityPost?> createPost(String title, String text, List<String> tags) async {
    try {
      final response = await _dio.post(
        '/posts',
        data: {
          'title': title,
          'text': text,
          'tags': tags,
          'privacy': 'public',
        },
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['post'] != null) {
        return CommunityPost.fromJson(Map<String, dynamic>.from(response.data['post']));
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final retryAfter = int.tryParse(
          e.response?.headers.value('retry-after') ?? '',
        );
        throw CommunityRateLimited(retryAfter);
      }
      debugPrint('RedditCommunityService: createPost error: $e');
      return null;
    } catch (e) {
      debugPrint('RedditCommunityService: createPost error: $e');
      return null;
    }
  }

  /// Edits an existing post
  Future<CommunityPost?> editPost(String postId, String title, String text, List<String> tags) async {
    try {
      final response = await _dio.put(
        '/posts/$postId',
        data: {
          'title': title,
          'text': text,
          'tags': tags,
        },
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['post'] != null) {
        return CommunityPost.fromJson(Map<String, dynamic>.from(response.data['post']));
      }
      return null;
    } catch (e) {
      debugPrint('RedditCommunityService: editPost error: $e');
      return null;
    }
  }

  /// Deletes a post
  Future<bool> deletePost(String postId) async {
    try {
      final response = await _dio.delete(
        '/posts/$postId',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('RedditCommunityService: deletePost error: $e');
      return false;
    }
  }

  /// Votes on a post: value is 1 (upvote), -1 (downvote), 0 (clear)
  Future<CommunityPost?> votePost(String postId, int voteValue) async {
    try {
      final response = await _dio.post(
        '/posts/$postId/vote',
        data: {'vote': voteValue},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['post'] != null) {
        return CommunityPost.fromJson(Map<String, dynamic>.from(response.data['post']));
      }
      return null;
    } catch (e) {
      debugPrint('RedditCommunityService: votePost error: $e');
      return null;
    }
  }

  /// Reports a post
  Future<bool> reportPost(String postId, String reason) async {
    try {
      final response = await _dio.post(
        '/posts/$postId/report',
        data: {'reason': reason},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('RedditCommunityService: reportPost error: $e');
      return false;
    }
  }

  // --- Comments APIs ---

  /// Fetches comments for a post, returns hierarchical comments tree
  Future<List<CommunityComment>> getComments(String postId, String sort) async {
    try {
      final response = await _dio.get(
        '/posts/$postId/comments',
        queryParameters: {'sort': sort},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['comments'] is List) {
        final List list = response.data['comments'];
        final List<CommunityComment> flatList = list.map((item) => CommunityComment.fromJson(Map<String, dynamic>.from(item))).toList();
        return _buildCommentTree(flatList);
      }
      return [];
    } catch (e) {
      debugPrint('RedditCommunityService: getComments error: $e');
      return [];
    }
  }

  /// Creates a comment or a nested reply
  Future<CommunityComment?> createComment(String postId, String text, {String? parentId}) async {
    try {
      final response = await _dio.post(
        '/posts/$postId/comments',
        data: {
          'text': text,
          'parentId': parentId,
        },
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['comment'] != null) {
        return CommunityComment.fromJson(Map<String, dynamic>.from(response.data['comment']));
      }
      return null;
    } catch (e) {
      debugPrint('RedditCommunityService: createComment error: $e');
      return null;
    }
  }

  /// Edits a comment
  Future<CommunityComment?> editComment(String commentId, String text) async {
    try {
      final response = await _dio.put(
        '/posts/comments/$commentId',
        data: {'text': text},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['comment'] != null) {
        return CommunityComment.fromJson(Map<String, dynamic>.from(response.data['comment']));
      }
      return null;
    } catch (e) {
      debugPrint('RedditCommunityService: editComment error: $e');
      return null;
    }
  }

  /// Deletes a comment
  Future<bool> deleteComment(String commentId) async {
    try {
      final response = await _dio.delete(
        '/posts/comments/$commentId',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('RedditCommunityService: deleteComment error: $e');
      return false;
    }
  }

  /// Votes on a comment
  Future<CommunityComment?> voteComment(String commentId, int voteValue) async {
    try {
      final response = await _dio.post(
        '/posts/comments/$commentId/vote',
        data: {'vote': voteValue},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['comment'] != null) {
        return CommunityComment.fromJson(Map<String, dynamic>.from(response.data['comment']));
      }
      return null;
    } catch (e) {
      debugPrint('RedditCommunityService: voteComment error: $e');
      return null;
    }
  }

  // --- Follow APIs ---

  /// Follows a user
  Future<bool> followUser(String userId) async {
    try {
      final response = await _dio.post(
        '/posts/users/$userId/follow',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('RedditCommunityService: followUser error: $e');
      return false;
    }
  }

  /// Unfollows a user
  Future<bool> unfollowUser(String userId) async {
    try {
      final response = await _dio.post(
        '/posts/users/$userId/unfollow',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('RedditCommunityService: unfollowUser error: $e');
      return false;
    }
  }

  // --- Profile APIs ---

  /// Fetches a user's profile statistics and data
  Future<UserProfileData?> getUserProfile(String userId) async {
    try {
      final response = await _dio.get(
        '/posts/users/$userId/profile',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['profile'] != null) {
        return UserProfileData.fromJson(Map<String, dynamic>.from(response.data['profile']));
      }
      return null;
    } catch (e) {
      debugPrint('RedditCommunityService: getUserProfile error: $e');
      return null;
    }
  }

  /// Updates current user profile bio
  Future<UserProfileData?> updateUserProfile(String bio) async {
    try {
      final response = await _dio.put(
        '/posts/users/profile',
        data: {'bio': bio},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['profile'] != null) {
        return UserProfileData.fromJson(Map<String, dynamic>.from(response.data['profile']));
      }
      return null;
    } catch (e) {
      debugPrint('RedditCommunityService: updateUserProfile error: $e');
      return null;
    }
  }

  /// Searches users by username or email
  Future<List<UserProfileData>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        '/friends/search',
        queryParameters: {'q': query},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['users'] is List) {
        final List list = response.data['users'];
        return list.map((item) => UserProfileData.fromJson(Map<String, dynamic>.from(item))).toList();
      }
      return [];
    } catch (e) {
      debugPrint('RedditCommunityService: searchUsers error: $e');
      return [];
    }
  }

  // --- Helper to build hierarchical comment tree ---
  List<CommunityComment> _buildCommentTree(List<CommunityComment> flatList) {
    final Map<String, CommunityComment> commentMap = {
      for (var c in flatList) c.commentId: c
    };
    final List<CommunityComment> rootComments = [];

    for (var c in flatList) {
      // Re-initialize replies as a list to avoid const list errors
      c.replies = [];
    }

    for (var c in flatList) {
      if (c.parentId == null || !commentMap.containsKey(c.parentId)) {
        rootComments.add(c);
      } else {
        final parent = commentMap[c.parentId]!;
        parent.replies.add(c);
      }
    }
    return rootComments;
  }
}
