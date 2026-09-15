import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A period that did not save must not be shown as saved.
///
/// Reported as: after logging, the tracker still says "No period logged yet"
/// and the drawing stays grey.
///
/// `logPeriodEntry` returns null when the write was refused -- an expired
/// session, a rejected date -- and the trying-to-conceive dashboard threw that
/// result away inside a bare `catch (_) {}`. So the card flipped to "Day N"
/// optimistically, nothing reached the server, the local write was skipped too
/// when there was no session, and the next load went back to "No period logged
/// yet". From the outside that reads as logging simply not working.
///
/// The card also offered "Insights for your phase", heart icon and all, to
/// somebody it had just told "No period logged yet" -- one card giving two
/// answers about the same fact.
void main() {
  late final String ttc;
  late final String card;

  setUpAll(() {
    ttc = File('lib/features/home/presentation/stages/trying_to_conceive_dashboard.dart')
        .readAsStringSync();
    card = File('lib/features/home/widgets/blushy_period_tracker_card.dart')
        .readAsStringSync();
  });

  test('the result of the save is actually read', () {
    final start = ttc.indexOf('PeriodEntry? saved;');
    expect(start, greaterThan(-1), reason: 'the result is thrown away again');

    final handler = ttc.substring(start, start + 1400);
    expect(handler, contains('if (saved == null)'));
  });

  test('a refused save puts the card back', () {
    // Leaving the optimistic "Day N" on screen is what made a failure look
    // like a success until the next reload.
    final start = ttc.indexOf('final previousDate = _lastPeriodStartDate;');
    expect(start, greaterThan(-1));

    final handler = ttc.substring(start, start + 2600);
    for (final restored in [
      '_lastPeriodStartDate = previousDate',
      '_hasLoggedPeriod = previousHasLogged',
      '_currentCycleDay = previousDay',
    ]) {
      expect(handler, contains(restored), reason: restored);
    }
  });

  test('and says so, rather than failing quietly', () {
    expect(ttc, contains('That period could not be saved'));
    // The old handler swallowed everything.
    final start = ttc.indexOf('PeriodEntry? saved;');
    final handler = ttc.substring(start, start + 1400);
    expect(handler.contains('} catch (_) {}'), isFalse,
        reason: 'a bare catch here is what hid the failure');
  });

  test('the insights row follows whether a period is logged', () {
    final start = card.indexOf('// Insights Row');
    expect(start, greaterThan(-1));

    final row = card.substring(start, start + 1400);
    expect(row, contains('hasLoggedPeriod ? onTapInsights : onTapLogPeriod'));
    expect(row, contains('Log your period to unlock phase insights'));
    expect(row, contains('Icons.lock_outline_rounded'));
  });
}
