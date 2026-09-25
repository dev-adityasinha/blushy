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

  test('the cycle read is delegated to the view model', () {
    // The fetch/error/day logic moved out of the widget into CycleViewModel,
    // which is unit-tested in cycle_view_model_test.dart. The dashboard is now
    // its View: it holds the view model and mirrors its result.
    expect(ttc, contains('CycleViewModel _cycleVM'));
    expect(ttc, contains('_cycleVM.load()'));
    expect(ttc.contains('getPredictionsResult()'), isFalse,
        reason: 'the data fetch belongs to the view model now, not the widget');
  });

  test('a dropped request is still recorded, not swallowed', () {
    // The result is mirrored into _cycleState from the view model on change.
    expect(ttc, contains('ApiState _cycleState'));
    expect(ttc, contains('_cycleState = _cycleVM.state'));
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

  test('the tracker leads the page, with the load notice below it', () {
    // The period tracker is pinned to the top (right after the greeting) by
    // request, so the cycle is the first thing she sees. The notice explaining
    // "still general guidance until you log" now sits just below the tracker.
    final card = ttc.indexOf('_buildPeriodTrackerCard(context),');
    final notice = ttc.indexOf('StageStateNotice(');
    expect(card, greaterThan(-1));
    expect(notice, greaterThan(-1));
    expect(card, lessThan(notice),
        reason: 'the tracker is kept at the top, above the loading notice');
  });

  test('every cycle dashboard reports load state, one way or another', () {
    // TTC reports it through the view model; the others still hold the inline
    // getPredictionsResult call (they convert next). Either way, none of them
    // may go back to the state-blind getPredictions().
    for (final path in [
      'lib/features/home/presentation/stages/trying_to_conceive_dashboard.dart',
      'lib/features/home/presentation/stages/first_period_started_dashboard.dart',
      'lib/features/home/presentation/stages/hormonal_health_dashboard.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final reportsState = source.contains('getPredictionsResult()') ||
          source.contains('CycleViewModel');
      expect(reportsState, isTrue, reason: path);
      expect(source, contains('_cycleState'), reason: path);
    }
  });
}
