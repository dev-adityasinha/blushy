import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/services/daily_rollover.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// The check-in has to end at midnight.
///
/// `daily_checkin.json` carried a date and nothing read it, so yesterday's
/// answers kept showing as today's: the follow-up cards were generated from
/// yesterday's symptoms, and "Not logged" never came back.
void main() {
  // So the rollover's flush runs for real rather than being swallowed by the
  // catch that exists for a failed network, which would leave that path
  // untested.
  TestWidgetsFlutterBinding.ensureInitialized();

  useIsolatedStorage();

  setUp(() {
    AuthStorage.saveSession(
      token: 't',
      userId: 'u',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );
  });

  group('when the day has turned', () {
    // Fixed clocks throughout. A test that asks the system what day it is
    // passes all afternoon and fails at midnight.
    final morning = DateTime(2026, 9, 4, 7, 30);

    test('yesterday evening is a new day', () {
      final lastNight = DateTime(2026, 9, 3, 23, 55).toIso8601String();
      expect(DailyRollover.isNewDay(lastNight, morning), isTrue);
    });

    test('earlier the same day is not', () {
      final earlier = DateTime(2026, 9, 4, 0, 5).toIso8601String();
      expect(DailyRollover.isNewDay(earlier, morning), isFalse);
    });

    test('the comparison is local, not UTC', () {
      // 22:00 local on the 4th is the 4th, whatever it is in UTC. Comparing in
      // UTC rolls the day over mid-evening for anyone east of Greenwich, which
      // is most of this app's users.
      final sameEvening = DateTime(2026, 9, 4, 22, 0);
      expect(DailyRollover.isNewDay(sameEvening.toIso8601String(),
          DateTime(2026, 9, 4, 23, 30)), isFalse);
    });

    test('a missing or unreadable date is stale', () {
      // The file predates the stamp, so it cannot be today's.
      expect(DailyRollover.isNewDay(null, morning), isTrue);
      expect(DailyRollover.isNewDay('', morning), isTrue);
      expect(DailyRollover.isNewDay('not a date', morning), isTrue);
    });
  });

  group('when the timer should fire', () {
    test('it waits for the next local midnight, plus a moment', () {
      final evening = DateTime(2026, 9, 4, 23, 30);
      final gap = DailyRollover.untilNextMidnight(evening);
      // Thirty minutes to midnight, plus the buffer.
      expect(gap.inMinutes, 30);
      expect(gap.inSeconds, 30 * 60 + 5);
    });

    test('the buffer means the timer never fires on yesterday', () {
      // Firing a moment early would see yesterday's date, do nothing, and not
      // run again until the following midnight.
      final justBefore = DateTime(2026, 9, 4, 23, 59, 59);
      final fireAt = justBefore.add(DailyRollover.untilNextMidnight(justBefore));
      expect(fireAt.day, 5);
    });

    test('it crosses a month end', () {
      final gap = DailyRollover.untilNextMidnight(DateTime(2026, 9, 30, 23, 0));
      final fireAt = DateTime(2026, 9, 30, 23, 0).add(gap);
      expect(fireAt.month, 10);
      expect(fireAt.day, 1);
    });

    test('it crosses a year end', () {
      final gap = DailyRollover.untilNextMidnight(DateTime(2026, 12, 31, 22, 0));
      final fireAt = DateTime(2026, 12, 31, 22, 0).add(gap);
      expect(fireAt.year, 2027);
      expect(fireAt.month, 1);
      expect(fireAt.day, 1);
    });

    test('it is never zero or negative', () {
      // A timer scheduled for the past fires immediately and in a loop.
      for (final at in [
        DateTime(2026, 9, 4, 0, 0, 0),
        DateTime(2026, 9, 4, 23, 59, 59, 999),
      ]) {
        expect(DailyRollover.untilNextMidnight(at) > Duration.zero, isTrue);
      }
    });
  });

  group('rolling over', () {
    final today = DateTime(2026, 9, 4, 7, 30);

    test('yesterday\'s answers do not show as today\'s', () async {
      BlushyStorage.write('daily_checkin.json', {
        'mood': 'Happy',
        'pain': 'Severe',
        'symptom': ['Cramps', 'Fatigue'],
        'date': DateTime(2026, 9, 3, 21, 0).toIso8601String(),
      });

      final rolled = await DailyRollover.runIfNeeded(now: today);
      expect(rolled, isTrue);

      final after = BlushyStorage.read('daily_checkin.json');
      expect(after['mood'], isNull);
      expect(after['pain'], isNull);
      expect(after['symptom'], isNull,
          reason: 'the follow-up cards are generated from this');
    });

    test('the cycle carries over, because a cycle does not end at midnight',
        () async {
      BlushyStorage.write('daily_checkin.json', {
        'mood': 'Happy',
        'lastPeriodStart': '2026-08-29',
        'cycleLength': 28,
        'date': DateTime(2026, 9, 3, 21, 0).toIso8601String(),
      });

      await DailyRollover.runIfNeeded(now: today);

      final after = BlushyStorage.read('daily_checkin.json');
      expect(after['lastPeriodStart'], '2026-08-29',
          reason: 'blanking this empties the cycle card every morning');
      expect(after['cycleLength'], 28);
      expect(after['mood'], isNull);
    });

    test('the same day is left alone', () async {
      final stored = {
        'mood': 'Happy',
        'date': DateTime(2026, 9, 4, 6, 0).toIso8601String(),
      };
      BlushyStorage.write('daily_checkin.json', stored);

      final rolled = await DailyRollover.runIfNeeded(now: today);
      expect(rolled, isFalse);
      expect(BlushyStorage.read('daily_checkin.json')['mood'], 'Happy');
    });

    test('an empty file is not a day to roll over', () async {
      BlushyStorage.write('daily_checkin.json', {});
      expect(await DailyRollover.runIfNeeded(now: today), isFalse);
    });

    test('a file with no date at all is rolled over once', () async {
      // Written before the stamp existed. It cannot be shown as today's, and
      // after the rollover it has a clean slate rather than rolling forever.
      BlushyStorage.write('daily_checkin.json', {'mood': 'Happy'});

      expect(await DailyRollover.runIfNeeded(now: today), isTrue);
      expect(BlushyStorage.read('daily_checkin.json')['mood'], isNull);
      // Now empty, so there is nothing left to roll.
      expect(await DailyRollover.runIfNeeded(now: today), isFalse);
    });
  });
}
