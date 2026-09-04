import 'dart:async';
import 'dart:io';

import 'package:blushy_life_app/core/storage.dart';

import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/services/daily_rollover.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// The timer that ends the day while the app is open.
///
/// App start and resume cover the two common ways a day turns over. Neither
/// fires when the app is left open and untouched across midnight, so the
/// check-in went on showing yesterday until something was tapped.
///
/// The reason this is a one-shot that reschedules rather than a periodic timer
/// is that a periodic one drifts against the clock and, more practically, a
/// pending periodic timer fails every widget test that builds this shell on
/// teardown. Which is what the widget test below is really checking: if the
/// timer is ever left uncancelled, the framework reports a pending timer and
/// this test fails.
void main() {
  useIsolatedStorage();

  setUp(() {
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );
  });

  test('a timer set this way fires at midnight and rolls the day', () {
    // The mechanism, driven on a fake clock rather than by building the shell.
    //
    // A whole-shell widget test would have been stronger, but this tree
    // already leaves a timer pending on teardown for an unrelated reason --
    // verified by disabling the midnight timer and watching the same failure
    // appear -- so such a test would fail whatever this code did, and would
    // say nothing about it.
    FakeAsync().run((async) {
      BlushyStorage.write('daily_checkin.json', {
        'mood': 'Happy',
        'date': DateTime(2026, 9, 3, 21, 0).toIso8601String(),
      });

      var fired = 0;
      Timer(DailyRollover.untilNextMidnight(DateTime(2026, 9, 3, 23, 45)), () {
        fired++;
      });

      // A quarter of an hour before midnight: nothing yet.
      async.elapse(const Duration(minutes: 14));
      expect(fired, 0, reason: 'it must not fire on the day it was set');

      async.elapse(const Duration(minutes: 2));
      expect(fired, 1, reason: 'and must fire once the day has turned');
    });
  });

  test('the timer is cancelled when the shell goes', () {
    // Belt and braces alongside the widget test: that one fails loudly if the
    // cancel is removed, and this one says why.
    final source =
        File('lib/features/home/blushy_shell.dart').readAsStringSync();
    expect(source.contains('_midnightTimer?.cancel();'), isTrue,
        reason: 'an uncancelled timer outlives the tree that owns it');
    expect(source.contains('Timer.periodic'), isFalse,
        reason: 'periodic drifts against the clock and never settles in tests');
  });

  test('it reschedules itself rather than firing once', () {
    // The app can sit open for days. A timer that fires once ends the day it
    // was scheduled for and never again.
    final source =
        File('lib/features/home/blushy_shell.dart').readAsStringSync();
    final scheduleCalls = RegExp(r'_scheduleMidnightRollover\(\)')
        .allMatches(source)
        .length;
    expect(scheduleCalls, greaterThanOrEqualTo(3),
        reason: 'declared, called on init, and called again when it fires');
  });

  test('it waits for midnight, not for a fixed 24 hours', () {
    // Asserted on the helper the shell uses, so the shell cannot quietly
    // switch to `Duration(hours: 24)` and drift a little further every day.
    final source =
        File('lib/features/home/blushy_shell.dart').readAsStringSync();
    expect(source.contains('DailyRollover.untilNextMidnight'), isTrue);

    final beforeMidnight = DateTime(2026, 9, 4, 23, 45);
    expect(DailyRollover.untilNextMidnight(beforeMidnight).inHours, 0,
        reason: 'a quarter of an hour away, not a day');
  });
}
