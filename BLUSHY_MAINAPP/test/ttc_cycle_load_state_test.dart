import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "Sometimes it works, sometimes it doesn't" was one screen guessing.
///
/// Trying to Conceive was the only cycle dashboard still calling
/// `getPredictions()` -- the variant that returns data alone -- with its
/// errors swallowed by a bare `.catchError((_) {})`. So a slow or refused
/// request left the card asserting "No period logged yet" about an account
/// that had one, while the same account a minute later, on a warm backend,
/// showed the day.
///
/// Render's free instance pays a cold start of up to ~27s, and the local
/// fallback (`last_period_entry.json`) is skipped whenever there is no
/// session -- so the two ways of finding the cycle could both come up empty
/// without anything being wrong with the cycle.
///
/// First Period and Hormonal Health have used `getPredictionsResult()` and
/// tracked the state all along. This brings the third into line.
void main() {
  late final String ttc;

  setUpAll(() {
    ttc = File('lib/features/home/presentation/stages/trying_to_conceive_dashboard.dart')
        .readAsStringSync();
  });

  test('it asks for the result, not just the data', () {
    expect(ttc, contains('getPredictionsResult()'));
    expect(
      ttc.contains('ApiPeriodService().getPredictions().then'),
      isFalse,
      reason: 'the data-only call cannot report why it came back empty',
    );
  });

  test('a dropped request is recorded, not swallowed', () {
    expect(ttc, contains('ApiState _cycleState'));
    expect(ttc, contains('_cycleState = result.state'));
    expect(ttc, contains('_cycleState = ApiState.offline'));

    // The bare catch is what made a failure indistinguishable from an empty
    // account.
    expect(ttc.contains('.catchError((_) {});'), isFalse);
  });

  test('and the screen says which kind of nothing it is', () {
    final start = ttc.indexOf('StageStateNotice(');
    expect(start, greaterThan(-1), reason: 'no notice above the tracker');

    final notice = ttc.substring(start, start + 500);
    expect(notice, contains('state: _cycleState'));
    expect(notice, contains('hasData: _hasLoggedPeriod'));
    expect(notice, contains('onRetry: _rehydrateTtcState'),
        reason: 'a failed load has to be retryable');
  });

  test('it still sits above the tracker card', () {
    // Below the card it would be explaining a claim the card already made.
    final notice = ttc.indexOf('StageStateNotice(');
    final card = ttc.indexOf('_buildPeriodTrackerCard(context),', notice);
    expect(card, greaterThan(notice));
  });

  test('all three cycle dashboards now load the same way', () {
    for (final path in [
      'lib/features/home/presentation/stages/trying_to_conceive_dashboard.dart',
      'lib/features/home/presentation/stages/first_period_started_dashboard.dart',
      'lib/features/home/presentation/stages/hormonal_health_dashboard.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('getPredictionsResult()'), reason: path);
      expect(source, contains('_cycleState'), reason: path);
    }
  });
}
