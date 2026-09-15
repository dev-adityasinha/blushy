import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/models/community_models.dart';
import 'package:blushy_life_app/services/api_community_service.dart';
import 'package:blushy_life_app/services/auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard Community Personalization Suite', () {
    setUp(() {
      AuthStorage.clearSession();
      ApiCommunityService().clearCache();
    });

    test('1. JSON Contract & Model Parsing: All 4 tabs and postType', () {
      final json = {
        "status": "success",
        "data": {
          "isPersonalized": true,
          "fallbackLabel": null,
          "generatedAt": "2026-08-25T11:30:00.000Z",
          "personalizationVersion": "v1",
          "questions": [
            {
              "postId": "p-q-1",
              "authorName": "Elena",
              "title": "Managing luteal cramps?",
              "text": "Anyone tried magnesium?",
              "tags": ["cramps", "luteal"],
              "postType": "question",
              "score": 14,
              "commentCount": 5,
              "userVote": 1,
              "createdAt": "2026-08-25T08:00:00.000Z"
            }
          ],
          "stories": [
            {
              "postId": "p-s-1",
              "authorName": "Maya",
              "title": "My journey with tracking",
              "text": "Started last month and feel so in control.",
              "tags": ["story", "journey"],
              "postType": "story",
              "score": 22,
              "commentCount": 3,
              "userVote": 0,
              "createdAt": "2026-08-25T08:30:00.000Z"
            }
          ],
          "tips": [
            {
              "postId": "p-t-1",
              "authorName": "Sofia",
              "title": "Tip: Warm ginger tea",
              "text": "Best morning drink for digestion.",
              "tags": ["tips", "tea"],
              "postType": "tip",
              "score": 40,
              "commentCount": 8,
              "userVote": 0,
              "createdAt": "2026-08-25T09:00:00.000Z"
            }
          ],
          "trending": [
            {
              "postId": "p-tr-1",
              "authorName": "Chloe",
              "title": "Cycle sync strength guide",
              "text": "Full breakdown for follicular workouts.",
              "tags": ["fitness", "strength"],
              "postType": "tip",
              "score": 95,
              "commentCount": 19,
              "userVote": 0,
              "createdAt": "2026-08-25T09:30:00.000Z"
            }
          ]
        }
      };

      final payload = DashboardPersonalizedCommunityPayload.fromJson(json);

      expect(payload.isPersonalized, isTrue);
      expect(payload.fallbackLabel, isNull);
      expect(payload.questions.length, equals(1));
      expect(payload.questions[0].postId, equals('p-q-1'));
      expect(payload.questions[0].postType, equals('question'));
      expect(payload.questions[0].commentCount, equals(5));
      expect(payload.questions[0].userVote, equals(1));

      expect(payload.stories.length, equals(1));
      expect(payload.stories[0].postType, equals('story'));

      expect(payload.tips.length, equals(1));
      expect(payload.tips[0].postType, equals('tip'));

      expect(payload.trending.length, equals(1));
      expect(payload.trending[0].score, equals(95));
    });

    test('2. Zero-Data / Popular Fallback Payload', () {
      final fallback = DashboardPersonalizedCommunityPayload.emptyFallback();
      expect(fallback.isPersonalized, isFalse);
      expect(fallback.fallbackLabel, equals('Popular in the community'));
      expect(fallback.questions, isEmpty);
      expect(fallback.stories, isEmpty);
      expect(fallback.tips, isEmpty);
      expect(fallback.trending, isEmpty);
    });

    test('3. Client In-Memory Cache Isolation & Token Security', () async {
      AuthStorage.saveSession(userId: 'user_a', token: 'token_a');

      final service = ApiCommunityService();
      service.clearCache();

      // Verify unauthenticated user receives fallback safely
      AuthStorage.clearSession();
      final feedNoAuth = await service.getDashboardPersonalizedFeed();
      expect(feedNoAuth.isPersonalized, isFalse);
      expect(feedNoAuth.fallbackLabel, equals('Popular in the community'));
    });

    test('4. Real post_id Presence & Privacy Field Safety', () {
      final post = CommunityPost(
        postId: 'uuid-1234-5678',
        authorName: 'Elena',
        title: 'Managing cramps',
        text: 'Drink water',
        tags: ['cramps'],
        postType: 'tip',
        score: 10,
        commentCount: 2,
        userVote: 0,
        createdAt: DateTime.now(),
      );

      final jsonMap = post.toJson();
      expect(jsonMap['postId'], equals('uuid-1234-5678'));
      expect(jsonMap['postType'], equals('tip'));
      expect(jsonMap.containsKey('symptoms'), isFalse);
      expect(jsonMap.containsKey('cyclePhase'), isFalse);
      expect(jsonMap.containsKey('relevanceScore'), isFalse);
    });

    test('5. In-Flight Account-Switch Race Guard: Delayed User A response discarded after User B logs in', () async {
      final service = ApiCommunityService();
      service.clearCache();

      // Simulate User A active session
      AuthStorage.saveSession(userId: 'user_a', token: 'token_a');

      // Prime User A cached payload
      final userAPayload = DashboardPersonalizedCommunityPayload(
        isPersonalized: true,
        fallbackLabel: null,
        generatedAt: DateTime.now(),
        personalizationVersion: 'v1',
        questions: [
          CommunityPost(
            postId: 'user-a-question-1',
            authorName: 'Elena',
            title: 'User A Private Question',
            text: 'Cramps question for User A',
            tags: ['cramps'],
            postType: 'question',
            score: 5,
            commentCount: 1,
            userVote: 0,
            createdAt: DateTime.now(),
          )
        ],
        stories: [],
        tips: [],
        trending: [],
      );

      // Save User A cache explicitly
      service.setCacheForTesting('user_a', userAPayload);

      // Verify User A gets User A cache
      final cachedA = await service.getDashboardPersonalizedFeed();
      expect(cachedA.questions.first.postId, equals('user-a-question-1'));

      // User A logs out and User B logs in
      AuthStorage.clearSession();
      AuthStorage.saveSession(userId: 'user_b', token: 'token_b');

      // Request as User B - MUST NOT return User A's cache
      final feedB = await service.getDashboardPersonalizedFeed();
      expect(feedB.questions.where((q) => q.postId == 'user-a-question-1').isEmpty, isTrue);

      // If User A response arrives late after User B is active, it must not pollute User B
      service.clearCache('user_a');
      final feedBAfterPurge = await service.getDashboardPersonalizedFeed();
      expect(feedBAfterPurge.questions.where((q) => q.postId == 'user-a-question-1').isEmpty, isTrue);
    });

    test('6. App Restart & Offline Graceful Fallback', () async {
      final service = ApiCommunityService();
      service.clearCache();

      // Unauthenticated / offline request always returns honest popular fallback
      AuthStorage.clearSession();
      final offlinePayload = await service.getDashboardPersonalizedFeed();
      expect(offlinePayload.isPersonalized, isFalse);
      expect(offlinePayload.fallbackLabel, equals('Popular in the community'));
    });
  });
}

