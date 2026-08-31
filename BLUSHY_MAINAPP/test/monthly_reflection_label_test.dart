import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The monthly card has to name its month.
///
/// It reports the last *completed* calendar month — the server refuses the
/// current one, because a month still running has nothing final to say. So on
/// 31 August it shows July, which is correct and reads as a bug: the heading
/// said only "MONTHLY REFLECTION & JOURNEY", and the only clue was the word
/// "July" buried in the body text.
void main() {
  final dashboard = File(
    'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart',
  ).readAsStringSync();

  test('the heading is built from the reporting month', () {
    expect(dashboard.contains('_monthlyHeading(journeyData.reportingMonth)'), isTrue,
        reason: 'a card about July must say July');
  });

  test('a missing or malformed month degrades to the plain heading', () {
    // Better a heading without a month than "MONTHLY REFLECTION — NULL".
    final start = dashboard.indexOf('static String _monthlyHeading');
    expect(start, greaterThan(-1));
    final body = dashboard.substring(start, dashboard.indexOf('\n  }', start));

    expect(body.contains('if (parts.length != 2) return heading;'), isTrue);
    expect(RegExp(r'month == null \|\| month < 1 \|\| month > 12').hasMatch(body), isTrue,
        reason: 'an out-of-range month would index past the end of the names');
  });

  test('the server still refuses the current month', () async {
    // If that ever changes, this card should show the running month and the
    // "completed month" framing above becomes wrong.
    final service = File(
      'backend/src/services/monthlyInsightsService.js',
    ).readAsStringSync();

    expect(service.contains('getPreviousCompletedMonthBoundaries'), isTrue);
    expect(service.contains('Cannot request current or future month'), isTrue,
        reason: 'the completed-month rule is what makes July correct on 31 August');
  });
}
