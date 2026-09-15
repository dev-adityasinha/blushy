import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tapping the tracker explains where she is; it does not reopen the calendar.
///
/// Every dashboard passed `onTapLog: () => _openLogPeriodDialog(context)`, so
/// tapping the drawing of her cycle asked her to log a period she had already
/// logged. The one thing the picture is about -- the phase she is in -- was
/// the one thing a tap could not tell her.
///
/// The exception is an account with nothing logged. There is no phase to
/// explain then, and offering to log is the only useful thing a tap can do, so
/// that is what it still does.
void main() {
  const dashboards = {
    'first_period_started': 'lib/features/home/presentation/stages/first_period_started_dashboard.dart',
    'hormonal_health': 'lib/features/home/presentation/stages/hormonal_health_dashboard.dart',
    'living_with_my_cycle': 'lib/features/home/presentation/stages/living_with_my_cycle_dashboard.dart',
  };

  test('the tracker no longer opens the date picker outright', () {
    dashboards.forEach((name, path) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('onTapLog: () => _openLogPeriodDialog(context)'),
        isFalse,
        reason: '$name still opens the calendar on tap',
      );
    });
  });

  test('it asks Docsy about the phase she is actually in', () {
    dashboards.forEach((name, path) {
      final source = File(path).readAsStringSync();
      final start = source.indexOf('onTap: () => _hasLoggedPeriod');
      expect(start, greaterThan(-1), reason: name);

      final wiring = source.substring(start, start + 320);
      expect(wiring, contains('_openDocsyWithPrompt'), reason: name);
      // The question names her phase rather than asking in the abstract.
      expect(wiring, contains(r'$_currentPhaseName'), reason: name);
      // And with nothing logged, logging is still what a tap offers.
      expect(wiring, contains('_openLogPeriodDialog(context)'), reason: name);
    });
  });

  test('the parameter no longer claims to be a log action', () {
    final widget = File('lib/features/home/widgets/cycle_tracker_image.dart')
        .readAsStringSync();

    // Comments stripped first: the file explains what the old name was, and
    // saying so there is the point rather than a relapse.
    final code = widget
        .split(String.fromCharCode(10))
        .where((line) => !line.trimLeft().startsWith('//'))
        .join(String.fromCharCode(10));

    expect(code.contains('onTapLog'), isFalse);
    expect(code, contains('final VoidCallback? onTap;'));
  });

  test('the shared card keeps its old behaviour unless told otherwise', () {
    // Perimenopause and trying-to-conceive go through this card and have no
    // phase explainer, so a tap there must still open the picker rather than
    // doing nothing.
    final card = File('lib/features/home/widgets/blushy_period_tracker_card.dart')
        .readAsStringSync();
    expect(card, contains('onTap: onTapTracker ?? onTapLogPeriod'));
  });
}
