import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/services/api_partner_service.dart';

/// The Memory Book is built from completed shared activities ordered by when
/// they were finished. The server has always returned `completedAt`; the model
/// dropped it, so there was nothing to order or date the entries by.
void main() {
  group('SharedActivity', () {
    test('parses completedAt so the Memory Book can date an entry', () {
      final activity = SharedActivity.fromJson({
        'key': 'evening_walk',
        'title': 'Evening walk',
        'description': 'A short walk together.',
        'status': 'completed',
        'completedByUserId': 'user_a',
        'completedAt': '2026-08-28T18:30:00.000Z',
        'completionCount': 3,
      });

      expect(activity.isCompleted, isTrue);
      expect(activity.completedAt, isNotNull);
      expect(activity.completedAt!.toUtc().year, 2026);
      expect(activity.completedAt!.toUtc().month, 8);
      expect(activity.completedAt!.toUtc().day, 28);
      expect(activity.completionCount, 3);
    });

    test('a missing completedAt is null rather than a fabricated date', () {
      final activity = SharedActivity.fromJson({
        'key': 'cook_together',
        'title': 'Cook together',
        'description': 'Make something new.',
        'status': 'not_started',
      });

      expect(activity.completedAt, isNull);
      expect(activity.isCompleted, isFalse);
    });

    test('an unparseable completedAt is null, not an exception', () {
      final activity = SharedActivity.fromJson({
        'key': 'x',
        'title': 'X',
        'description': '',
        'status': 'completed',
        'completedAt': 'not-a-date',
      });

      expect(activity.completedAt, isNull);
    });
  });
}
