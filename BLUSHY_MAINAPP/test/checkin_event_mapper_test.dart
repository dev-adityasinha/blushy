import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/features/home/checkin_event_mapper.dart';
import 'package:blushy_life_app/features/home/checkin_vocabulary.dart';

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

    test('the mood selector no longer carries symptoms', () {
      // 'Cramps' and 'Tired' used to be mood options that mapped to
      // `symptom_logged`. Choosing one recorded no mood at all, and because a
      // check-in answer is one value per metric it also erased a mood already
      // picked that day -- so "happy but cramping" was unsayable.
      expect(CheckinEventMapper.map('mood', 'Cramps'), isNull);
      expect(CheckinEventMapper.map('mood', 'Tired'), isNull);
    });

    test('every mood option the dashboard offers is a mood', () {
      for (final label in CheckinVocabulary.mood) {
        final event = CheckinEventMapper.map('mood', label);
        expect(event, isNotNull, reason: '$label is unmapped');
        expect(event!.eventType, 'mood_logged',
            reason: '$label is offered as a mood, so it must record as one');
      }
    });

    test('symptom chips record as symptoms, keeping the wording tapped', () {
      final cramps = CheckinEventMapper.map('symptom', 'Cramps')!;
      expect(cramps.eventType, 'symptom_logged');
      expect(cramps.payload['symptom'], 'cramps');
      expect(cramps.payload['reportedAs'], 'Cramps');

      final bloating = CheckinEventMapper.map('symptom', 'Bloating')!;
      expect(bloating.eventType, 'symptom_logged');
      expect(bloating.payload['symptom'], 'bloating');
    });

    test('"Everything is fine" is not recorded as a symptom', () {
      // Recording it would put a symptom she does not have into the timeline,
      // the doctor summary and Docsy's context.
      expect(CheckinEventMapper.map('symptom', 'Everything is fine'), isNull);
      expect(
          CheckinVocabulary.isUnrecorded('symptom', 'Everything is fine'), isTrue);
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
      // Hand-maintained, and that is how the gap happened: this listed the
      // cycle dashboards' labels only, so the everyday wellness selector's
      // own vocabulary went unmapped and was silently dropped while this test
      // stayed green -- all three sleep ranges, two of three movement options,
      // and the half-litre hydration step. Anything a selector can render goes
      // here, whichever dashboard renders it.
      const options = {
        'energy': ['High', 'Medium', 'Low'],
        'flow': ['Light', 'Medium', 'Heavy'],
        'pain': ['None', 'Mild', 'Severe'],
        'sleep': ['<6h', '6-8h', '>8h', '6-7h', '7-8h', '8h+'],
        'stress': ['Low', 'Moderate', 'High'],
        'water': ['1L', '2L', '3L', '2.5L'],
        'exercise': ['Active', 'Light', 'None', 'Workout', 'Walk'],
      };

      options.forEach((metric, values) {
        for (final value in values) {
          expect(CheckinEventMapper.map(metric, value), isNotNull,
              reason: '$metric "$value" is unmapped');
        }
      });
    });
  });

  group('fertility selectors', () {
    test('cervical mucus becomes the observation the server accepts', () {
      final e = CheckinEventMapper.map('cervical_mucus', 'Eggwhite')!;
      expect(e.eventType, 'cervical_mucus_logged');
      // The card says one word, the server calls it egg_white.
      expect(e.payload['observation'], 'egg_white');
      expect(e.payload['reportedAs'], 'Eggwhite');

      expect(CheckinEventMapper.map('cervical_mucus', 'Dry')!.payload['observation'], 'dry');
    });

    test('an LH result becomes the result the server accepts', () {
      final e = CheckinEventMapper.map('lh_test', 'Peak')!;
      expect(e.eventType, 'lh_test_logged');
      expect(e.payload['result'], 'peak');
      expect(e.payload['reportedAs'], 'Peak');
    });

    test('both reverse to the word on the card', () {
      for (final label in ['Dry', 'Sticky', 'Creamy', 'Eggwhite']) {
        final e = CheckinEventMapper.map('cervical_mucus', label)!;
        final back = CheckinEventMapper.reverse(e.eventType, e.payload)!;
        expect(back.key, 'cervical_mucus');
        expect(back.value, label);
      }
      for (final label in ['Low', 'High', 'Peak']) {
        final e = CheckinEventMapper.map('lh_test', label)!;
        expect(CheckinEventMapper.reverse(e.eventType, e.payload)!.value, label);
      }
    });

    test('an older row without reportedAs still reverses', () {
      expect(CheckinEventMapper.reverse(
          'cervical_mucus_logged', {'observation': 'egg_white'})!.value, 'Eggwhite');
      expect(CheckinEventMapper.reverse(
          'lh_test_logged', {'result': 'peak'})!.value, 'Peak');
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
        'mood': ['Happy', 'Okay', 'Calm', 'Low', 'Irritable'],
        'symptom': ['Cramps', 'Headache', 'Backache', 'Dry eyes', 'Bloating'],
        'energy': ['High', 'Medium', 'Low'],
        'flow': ['Light', 'Medium', 'Heavy'],
        'pain': ['None', 'Mild', 'Severe'],
        'sleep': ['<6h', '6-8h', '>8h', '6-7h', '7-8h', '8h+'],
        'stress': ['Low', 'Moderate', 'High'],
        'water': ['1L', '2L', '3L', '2.5L'],
        'exercise': ['Active', 'Light', 'None', 'Workout', 'Walk'],
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

    test('a symptom reverses back to the symptoms sheet, not the mood card', () {
      final event = CheckinEventMapper.map('symptom', 'Cramps')!;
      final back = CheckinEventMapper.reverse(event.eventType, event.payload)!;
      expect(back.key, 'symptom');
      expect(back.value, 'Cramps');
    });

    test('each symptom reverses on its own, so a day can hold several', () {
      // The restore path accumulates on this metric instead of overwriting;
      // last-wins would leave exactly one chip selected out of however many
      // she tapped.
      final picked = ['Cramps', 'Headache', 'Fatigue'];
      final restored = <String>{};
      for (final label in picked) {
        final event = CheckinEventMapper.map('symptom', label)!;
        final back = CheckinEventMapper.reverse(event.eventType, event.payload)!;
        expect(back.key, 'symptom');
        restored.add(back.value);
      }
      expect(restored, picked.toSet());
    });

    test('events written before reportedAs existed still reverse by value', () {
      // Older rows have only the derived number.
      expect(CheckinEventMapper.reverse('energy_logged', {'level': 5})!.value, 'High');
      expect(CheckinEventMapper.reverse('sleep_logged', {'durationHours': 7})!.value, '6-8h');
      expect(CheckinEventMapper.reverse('pain_logged', {'severity': 8})!.value, 'Severe');
      expect(CheckinEventMapper.reverse('hydration_logged', {'glasses': 8})!.value, '2L');
    });

    test('a value between buckets is left unmapped rather than snapped', () {
      // 6.2h is not any bucket, so no chip is shown as selected instead of the
      // nearest one being guessed.
      //
      // This used 6.5h until the everyday wellness labels were added, which
      // made 6.5 the value behind "6-7h" -- a real bucket, and no longer an
      // example of the thing being tested.
      expect(CheckinEventMapper.reverse('sleep_logged', {'durationHours': 6.2}), isNull);
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
      // A symptom no chip offers. 'headache' is a chip now, so it is no
      // longer the example of one this card does not show.
      expect(CheckinEventMapper.reverse('symptom_logged', {'symptom': 'dizziness'}), isNull);
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
