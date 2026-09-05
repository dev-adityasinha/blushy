import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_base_url.dart';
import 'auth_storage.dart';
import '../models/community_models.dart';
import 'cold_start_retry.dart';

class ApiCommunityService {
  static final ApiCommunityService _instance = ApiCommunityService._internal();
  factory ApiCommunityService() => _instance;
  ApiCommunityService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: resolveApiBaseUrl(),
    connectTimeout: const Duration(seconds: 15),
    // Long enough to absorb a cold start. The backend is on Render's free
    // plan, which stops the instance once it goes idle; the request that wakes
    // it waits for the boot, measured at 27s. Connecting is not what waits --
    // Render's edge accepts immediately and holds the request while the
    // instance comes up -- so this is the timeout that has to give, not
    // connectTimeout above.
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ))
    ..interceptors.add(ColdStartRetryInterceptor());

  // In-memory user-scoped cache: Map<userId, DashboardPersonalizedCommunityPayload>
  final Map<String, DashboardPersonalizedCommunityPayload> _userScopedCache = {};

  void clearCache([String? userId]) {
    if (userId != null) {
      _userScopedCache.remove(userId);
    } else {
      _userScopedCache.clear();
    }
  }

  @visibleForTesting
  void setCacheForTesting(String userId, DashboardPersonalizedCommunityPayload payload) {
    _userScopedCache[userId] = payload;
  }

  Options _authOptions() {
    final token = AuthStorage.getToken();
    if (token != null && token.isNotEmpty) {
      return Options(headers: {'Authorization': 'Bearer $token'});
    }
    return Options();
  }

  /// Fetches canonical personalized community feed for the dashboard: `GET /api/posts/dashboard-personalized`
  Future<DashboardPersonalizedCommunityPayload> getDashboardPersonalizedFeed({bool forceRefresh = false}) async {
    final currentUid = AuthStorage.getUserId();
    if (currentUid == null || currentUid.isEmpty) {
      return DashboardPersonalizedCommunityPayload.emptyFallback();
    }

    if (!forceRefresh && _userScopedCache.containsKey(currentUid)) {
      return _userScopedCache[currentUid]!;
    }

    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      return DashboardPersonalizedCommunityPayload.emptyFallback();
    }

    try {
      final response = await _dio.get(
        '/api/posts/dashboard-personalized',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // Race condition protection: discard if active user switched in-flight
      final activeUidAfterRequest = AuthStorage.getUserId();
      if (activeUidAfterRequest != currentUid) {
        return DashboardPersonalizedCommunityPayload.emptyFallback();
      }

      if (response.data is Map<String, dynamic>) {
        final payload = DashboardPersonalizedCommunityPayload.fromJson(response.data as Map<String, dynamic>);
        _userScopedCache[currentUid] = payload;
        return payload;
      }
      return DashboardPersonalizedCommunityPayload.emptyFallback();
    } catch (e) {
      debugPrint('BlushyCommunity: Error fetching dashboard personalized feed: $e');
      if (_userScopedCache.containsKey(currentUid)) {
        return _userScopedCache[currentUid]!;
      }
      return DashboardPersonalizedCommunityPayload.emptyFallback();
    }
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
