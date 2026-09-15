import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The onboarding date is a seed. It fills in; it does not overrule.
///
/// `period_last_start_date`, `last_period`, `cycle_start_date` and friends are
/// written once at signup and never updated — logging a period writes a
/// different set of keys. So whenever one of them is applied *over* a date the
/// user has since logged, her entry is silently replaced by a stale one.
///
/// Traced on a device: after logging 26 Aug, the dashboard refresh that follows
/// a tab change put 31 Aug back and then pushed it to the server, so the value
/// alternated 26 -> 31 -> 26 -> 31 and the cycle reset to Day 1.
///
/// The same mistake has been fixed in four places, so this guards the shape
/// rather than any one of them.
void main() {
  String read(String p) => File(p).readAsStringSync();

  test('the dashboard applies the seed only when nothing is known', () {
    final source = read(
      'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart',
    );

    expect(
        source.contains("if (remoteAnswers.containsKey('period_last_start_date')) {"),
        isFalse,
        reason: 'applying it unconditionally overwrites a logged period');

    expect(
        RegExp(r"pStart == null &&\s*remoteAnswers\.containsKey\('period_last_start_date'\)")
            .hasMatch(source),
        isTrue,
        reason: 'the seed must be a fallback');
  });

  test('the sync applies the answers only when nothing is known', () {
    final source = read('lib/core/state.dart');

    expect(
        RegExp(r'if \(lastPeriodStart == null\) \{\s*final rawPeriod =')
            .hasMatch(source),
        isTrue,
        reason: 'the onboarding answers must not overrule the profile date');

    // A logged entry is authoritative, not "only if it happens to be later".
    expect(source.contains('latest.isAfter(lastPeriodStart)'), isFalse,
        reason: 'a stale seed dated ahead of a real entry would win again');
  });

  test('the period picker records what the save actually returned', () {
    final source = read('lib/features/sia/sia_screen.dart');

    expect(source.contains('saved = entry != null;'), isTrue,
        reason: 'a refused write must not be reported as recorded');
    expect(
        RegExp(r'logPeriodEntry\([^;]*\);\s*saved = true;').hasMatch(source),
        isFalse,
        reason: 'saved must depend on the result, not follow the call');
  });
}
