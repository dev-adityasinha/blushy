import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/features/home/services/cycle_insight_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CycleInsightService Tests', () {
    setUp(() {
      BlushyStorage.clearUserData();
      AuthStorage.saveSession(token: 'test_token', userId: 'test_user_cycle');
    });

    test('generates PCOS & hormonal balance insights when user onboarding profile has PCOS condition', () {
      final mockProfile = {
        'profile': {
          'preferredName': 'Sophia',
          'lifeStage': 'hormonalHealth',
          'goals': ['Cycle Syncing', 'Manage Stress'],
          'symptoms': ['Cramps', 'Insomnia'],
          'conditions': ['PCOS'],
        }
      };
      BlushyStorage.write('user_profile.json', mockProfile);

      final insights = CycleInsightService.getPersonalizedInsights();

      expect(insights.isNotEmpty, isTrue);
      expect(insights.any((i) => i.title.contains('Hormonal & Endocrine Balance')), isTrue);
      expect(insights.any((i) => i.title.contains('Pelvic Relief & Cramp Management')), isTrue);
      expect(insights.any((i) => i.title.contains('Sleep Quality & Rest Recovery')), isTrue);
      expect(insights.any((i) => i.title.contains('Four-Phase Cycle Syncing')), isTrue);
    });

    test('generates TTC fertility insights when life stage is tryingToConceive', () {
      final mockProfile = {
        'profile': {
          'preferredName': 'Aria',
          'lifeStage': 'tryingToConceive',
          'goals': ['Fertility Tracking'],
          'symptoms': ['Bloating'],
          'conditions': [],
        }
      };
      BlushyStorage.write('user_profile.json', mockProfile);

      final insights = CycleInsightService.getPersonalizedInsights();

      expect(insights.any((i) => i.title.contains('Fertility Window Tracking')), isTrue);
      expect(insights.any((i) => i.title.contains('Hydration & Fluid Retention')), isTrue);
    });

    test('generates real-time conversation cards immediately after user talks to Sia AI', () {
      final mockChat = {
        'messages': [
          {'sender': 'sia', 'text': 'Hello Maya! How are you feeling today?'},
          {'sender': 'user', 'text': 'I have a terrible headache and feel completely exhausted today.'},
        ],
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      BlushyStorage.write('recent_sia_chats.json', mockChat);

      final insights = CycleInsightService.getPersonalizedInsights();

      expect(insights.isNotEmpty, isTrue);
      expect(insights.first.title, contains('Headaches'));
      expect(insights.first.timestamp, equals('Just now'));
      expect(insights.any((i) => i.title.contains('Fatigue Recovery')), isTrue);
    });
  });
}
