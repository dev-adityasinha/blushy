import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/features/home/checkin_event_mapper.dart';

/// The daily check-in selectors offer buckets, not exact values. These tests
/// pin the mapping onto the backend event scales, and pin the two behaviours
/// that matter most: the original label survives, and a symptom in the mood
/// selector is not recorded as a mood.

void main() {
  group('mood selector routing', () {
    test('actual moods become mood_logged with a backend-valid mood', () {
      expect(CheckinEventMapper.map('mood', 'Happy'),
          const CheckinEvent(eventType: 'mood_logged', payload: {'mood': 'good'}));
      expect(CheckinEventMapper.map('mood', 'Okay'),
          const CheckinEvent(eventType: 'mood_logged', payload: {'mood': 'okay'}));
      expect(CheckinEventMapper.map('mood', 'Irritable'),
          const CheckinEvent(eventType: 'mood_logged', payload: {'mood': 'irritable'}));
    });

    test('symptoms in the mood selector become symptom_logged, not a mood', () {
      final cramps = CheckinEventMapper.map('mood', 'Cramps');
      expect(cramps!.eventType, 'symptom_logged');
      expect(cramps.payload['symptom'], 'cramps');

      final tired = CheckinEventMapper.map('mood', 'Tired');
      expect(tired!.eventType, 'symptom_logged');
      expect(tired.payload['symptom'], 'tiredness');
    });

    test('every mood option the dashboard offers is mapped', () {
      for (final label in ['Happy', 'Okay', 'Cramps', 'Tired', 'Irritable']) {
        expect(CheckinEventMapper.map('mood', label), isNotNull, reason: '$label is unmapped');
      }
    });
  });

  group('bucketed metrics', () {
    test('energy maps onto the 1-5 scale and keeps the label', () {
      final high = CheckinEventMapper.map('energy', 'High')!;
      expect(high.eventType, 'energy_logged');
      expect(high.payload['level'], 5);
      expect(high.payload['reportedAs'], 'High');

      expect(CheckinEventMapper.map('energy', 'Medium')!.payload['level'], 3);
      expect(CheckinEventMapper.map('energy', 'Low')!.payload['level'], 1);
    });

    test('sleep buckets keep the range the user picked alongside the number', () {
      final mid = CheckinEventMapper.map('sleep', '6-8h')!;
      expect(mid.eventType, 'sleep_logged');
      expect(mid.payload['durationHours'], 7);
      // The bucket is preserved so "7 hours" is never shown back as exact.
      expect(mid.payload['reportedAs'], '6-8h');

      expect(CheckinEventMapper.map('sleep', '<6h')!.payload['durationHours'], 5);
      expect(CheckinEventMapper.map('sleep', '>8h')!.payload['durationHours'], 9);
    });

    test('pain maps onto the 0-10 severity scale', () {
      expect(CheckinEventMapper.map('pain', 'None')!.payload['severity'], 0);
      expect(CheckinEventMapper.map('pain', 'Mild')!.payload['severity'], 3);
      expect(CheckinEventMapper.map('pain', 'Severe')!.payload['severity'], 8);
      expect(CheckinEventMapper.map('pain', 'Severe')!.eventType, 'pain_logged');
    });

    test('stress and water map onto their scales', () {
      expect(CheckinEventMapper.map('stress', 'High')!.payload['level'], 5);
      expect(CheckinEventMapper.map('stress', 'Moderate')!.payload['level'], 3);

      final water = CheckinEventMapper.map('water', '2L')!;
      expect(water.eventType, 'hydration_logged');
      expect(water.payload['glasses'], 8);
      expect(water.payload['reportedAs'], '2L');
    });

    test('flow is its own event, not folded into the period start', () {
      final flow = CheckinEventMapper.map('flow', 'Heavy')!;
      expect(flow.eventType, 'flow_logged');
      expect(flow.payload['flow'], 'heavy');
    });

    test('exercise becomes an activity with a duration', () {
      final active = CheckinEventMapper.map('exercise', 'Active')!;
      expect(active.eventType, 'activity_logged');
      expect(active.payload['activity'], 'exercise');
      expect(active.payload['durationMinutes'], 45);
      expect(CheckinEventMapper.map('exercise', 'None')!.payload['durationMinutes'], 0);
    });

    test('every selector option the dashboard offers is mapped', () {
      const options = {
        'energy': ['High', 'Medium', 'Low'],
        'flow': ['Light', 'Medium', 'Heavy'],
        'pain': ['None', 'Mild', 'Severe'],
        'sleep': ['<6h', '6-8h', '>8h'],
        'stress': ['Low', 'Moderate', 'High'],
        'water': ['1L', '2L', '3L'],
        'exercise': ['Active', 'Light', 'None'],
      };

      options.forEach((metric, values) {
        for (final value in values) {
          expect(CheckinEventMapper.map(metric, value), isNotNull,
              reason: '$metric "$value" is unmapped');
        }
      });
    });
  });

  group('unmapped input', () {
    test('an unknown value is dropped rather than guessed at', () {
      expect(CheckinEventMapper.map('energy', 'Somewhat'), isNull);
      expect(CheckinEventMapper.map('mood', 'Ecstatic'), isNull);
      expect(CheckinEventMapper.map('not_a_metric', 'High'), isNull);
      expect(CheckinEventMapper.map('energy', '   '), isNull);
    });
  });

  group('reverse mapping', () {
    test('every selector option survives a round trip unchanged', () {
      // This is what makes a check-in made on one device show as selected on
      // another: the stored event maps back to the exact label the card renders.
      const options = {
        'mood': ['Happy', 'Okay', 'Cramps', 'Tired', 'Irritable'],
        'energy': ['High', 'Medium', 'Low'],
        'flow': ['Light', 'Medium', 'Heavy'],
        'pain': ['None', 'Mild', 'Severe'],
        'sleep': ['<6h', '6-8h', '>8h'],
        'stress': ['Low', 'Moderate', 'High'],
        'water': ['1L', '2L', '3L'],
        'exercise': ['Active', 'Light', 'None'],
      };

      options.forEach((metric, values) {
        for (final value in values) {
          final event = CheckinEventMapper.map(metric, value);
          expect(event, isNotNull, reason: '$metric "$value" did not map');

          final back = CheckinEventMapper.reverse(event!.eventType, event.payload);
          expect(back, isNotNull, reason: '$metric "$value" did not reverse');
          expect(back!.key, metric, reason: '$metric "$value" reversed to the wrong metric');
          expect(back.value, value, reason: '$metric "$value" reversed to "${back.value}"');
        }
      });
    });

    test('a symptom logged from the mood selector reverses back to the mood card', () {
      final event = CheckinEventMapper.map('mood', 'Cramps')!;
      expect(event.eventType, 'symptom_logged');

      final back = CheckinEventMapper.reverse(event.eventType, event.payload)!;
      expect(back.key, 'mood');
      expect(back.value, 'Cramps');
    });

    test('events written before reportedAs existed still reverse by value', () {
      // Older rows have only the derived number.
      expect(CheckinEventMapper.reverse('energy_logged', {'level': 5})!.value, 'High');
      expect(CheckinEventMapper.reverse('sleep_logged', {'durationHours': 7})!.value, '6-8h');
      expect(CheckinEventMapper.reverse('pain_logged', {'severity': 8})!.value, 'Severe');
      expect(CheckinEventMapper.reverse('hydration_logged', {'glasses': 8})!.value, '2L');
    });

    test('a value between buckets is left unmapped rather than snapped', () {
      // An exact sleep entry of 6.5h is not any of the three buckets, so no
      // chip is shown as selected instead of the nearest one being guessed.
      expect(CheckinEventMapper.reverse('sleep_logged', {'durationHours': 6.5}), isNull);
      expect(CheckinEventMapper.reverse('energy_logged', {'level': 4}), isNull);
    });

    test('reportedAs wins over the derived number', () {
      final back = CheckinEventMapper.reverse(
        'sleep_logged',
        {'durationHours': 7, 'reportedAs': '6-8h'},
      );
      expect(back!.value, '6-8h');
    });

    test('unrelated events are ignored', () {
      expect(CheckinEventMapper.reverse('period_logged', {'startDate': '2026-08-29'}), isNull);
      expect(CheckinEventMapper.reverse('journal_created', {'text': 'x'}), isNull);
      expect(CheckinEventMapper.reverse('mood_logged', {'mood': 'awful'}), isNull);
      expect(CheckinEventMapper.reverse('symptom_logged', {'symptom': 'headache'}), isNull);
    });
  });

  group('idempotency key', () {
    test('is stable for the same metric on the same day', () {
      final a = CheckinEventMapper.idempotencyKey(
          userId: 'u1', metric: 'mood', day: DateTime(2026, 8, 29));
      final b = CheckinEventMapper.idempotencyKey(
          userId: 'u1', metric: 'mood', day: DateTime(2026, 8, 29, 23, 59));
      expect(a, b);
      expect(a, 'checkin:u1:mood:2026-08-29');
    });

    test('differs by metric, day and user', () {
      final base = CheckinEventMapper.idempotencyKey(
          userId: 'u1', metric: 'mood', day: DateTime(2026, 8, 29));
      expect(
          base,
          isNot(CheckinEventMapper.idempotencyKey(
              userId: 'u1', metric: 'energy', day: DateTime(2026, 8, 29))));
      expect(
          base,
          isNot(CheckinEventMapper.idempotencyKey(
              userId: 'u1', metric: 'mood', day: DateTime(2026, 8, 30))));
      expect(
          base,
          isNot(CheckinEventMapper.idempotencyKey(
              userId: 'u2', metric: 'mood', day: DateTime(2026, 8, 29))));
    });
  });
}
