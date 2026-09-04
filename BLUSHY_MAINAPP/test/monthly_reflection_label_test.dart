import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The monthly card has to name its month, and has to be there.
///
/// It reports the last *completed* calendar month — the server refuses the
/// current one, because a month still running has nothing final to say. So on
/// 31 August it shows July, which is correct and reads as a bug unless the
/// card says "July" somewhere a reader will see it.
void main() {
  final dashboard = File(
    'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart',
  ).readAsStringSync();

  test('the month is named, from the reporting month', () {
    // The name sits on its own line under the heading now, rather than
    // appended to it -- "MONTHLY REFLECTION & JOURNEY — JULY 2026" ran off a
    // phone's width -- but the card about July must still say July.
    expect(
      dashboard.contains('monthLabel: _monthLabel(journeyData.reportingMonth)'),
      isTrue,
      reason: 'a card about July must say July',
    );
  });

  test('a missing or malformed month leaves the label out', () {
    // Better no month line than "NULL 2026".
    final start = dashboard.indexOf('static String? _monthLabel');
    expect(start, greaterThan(-1));
    final body = dashboard.substring(start, dashboard.indexOf('\n  }', start));

    expect(body.contains('if (parts.length != 2) return null;'), isTrue);
    expect(
      RegExp(r'month == null \|\| month < 1 \|\| month > 12').hasMatch(body),
      isTrue,
      reason: 'an out-of-range month would index past the end of the names',
    );
  });

  test('the card renders in every state, including the month before joining',
      () {
    // It used to return SizedBox.shrink() for `not_yet_joined`, so the card
    // appeared from the local fallback and vanished when the server answered:
    // the page changed shape on a network response.
    final start = dashboard.indexOf('Widget _buildLivingJourney() {');
    expect(start, greaterThan(-1));
    // '\n  }' rather than '\n  }\n': the file is CRLF, and a pattern with
    // a trailing LF never matches a line that ends in CR LF.
    final body = dashboard.substring(start, dashboard.indexOf('\n  }', start));
    expect(body.contains('SizedBox.shrink()'), isFalse,
        reason: 'the page must not change shape on a network response');
    expect(body.contains("'not_yet_joined'"), isTrue,
        reason: 'that state is still recognised -- and said, not hidden');
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
