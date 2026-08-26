import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_base_url.dart';
import 'auth_storage.dart';

class ApiCommunityService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: resolveApiBaseUrl(),
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 25),
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

  /// Fetches community feed posts: `GET /posts/feed`
  Future<List<Map<String, dynamic>>> getFeedPosts() async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return [];

    try {
      final response = await _dio.get(
        '/posts/feed',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic> && response.data['posts'] is List) {
        final List postsList = response.data['posts'];
        return postsList.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      if (response.data is List) {
        return (response.data as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('BlushyCommunity: Error fetching feed posts: $e');
      return [];
    }
  }

  /// Creates a new community post: `POST /posts`
  Future<bool> createPost(String content) async {
    try {
      await _dio.post(
        '/posts',
        data: {'content': content},
        options: _authOptions(),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyCommunity: Error creating post: $e');
      return false;
    }
  }

  /// Lists all public communities: `GET /community`
  Future<List<Map<String, dynamic>>> getCommunities() async {
    try {
      final response = await _dio.get(
        '/community',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['communities'] is List) {
        final List list = response.data['communities'];
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('BlushyCommunity: Error listing communities: $e');
      return [];
    }
  }

  /// Follows / Joins a community: `POST /community/:communityId/follow`
  Future<bool> followCommunity(String communityId) async {
    try {
      await _dio.post(
        '/community/$communityId/follow',
        options: _authOptions(),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyCommunity: Error following community: $e');
      return false;
    }
  }

  /// Unfollows / Leaves a community: `POST /community/:communityId/unfollow`
  Future<bool> unfollowCommunity(String communityId) async {
    try {
      await _dio.post(
        '/community/$communityId/unfollow',
        options: _authOptions(),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyCommunity: Error unfollowing community: $e');
      return false;
    }
  }

  /// Sends a message into a community group: `POST /community/:communityId/messages`
  Future<bool> sendCommunityMessage(String communityId, String content) async {
    try {
      await _dio.post(
        '/community/$communityId/messages',
        data: {'content': content},
        options: _authOptions(),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyCommunity: Error sending community message: $e');
      return false;
    }
  }
}
