import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/features/home/services/discover_service.dart';

void main() {
  group('DiscoverService & DiscoverPayload Unit Tests', () {
    test('DiscoverPayload parses AI JSON response correctly', () {
      final json = {
        "success": true,
        "featuredTopic": "Nutrition",
        "topics": ["Nutrition", "Exercise", "Women's Health"],
        "topicArticles": {
          "Nutrition": [
            {
              "title": "Curbing Luteal Cravings",
              "desc": "Magnesium-rich foods to natural calm sugar spikes.",
              "content": "Dark chocolate and spinach balance blood sugar."
            }
          ]
        },
        "isPersonalized": true,
        "dayIndex": 20679,
        "lastUpdated": "2026-08-14T08:00:00.000Z"
      };

      final payload = DiscoverPayload.fromJson(json);

      expect(payload.featuredTopic, equals("Nutrition"));
      expect(payload.topics.length, equals(3));
      expect(payload.isPersonalized, isTrue);
      expect(payload.dayIndex, equals(20679));
      expect(payload.topicArticles["Nutrition"]?.length, equals(1));
      expect(payload.topicArticles["Nutrition"]?.first.title, equals("Curbing Luteal Cravings"));
    });

    test('DiscoverService returns valid fallback payload offline', () async {
      final payload = await DiscoverService.fetchDailyDiscoverPayload();
      expect(payload.topics, isNotEmpty);
      expect(payload.featuredTopic, isNotEmpty);
      expect(payload.topicArticles.keys, contains(payload.featuredTopic));
    });
  });
}
