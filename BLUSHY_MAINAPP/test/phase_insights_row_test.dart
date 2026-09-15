import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every cycle dashboard offers a way into what its phase means.
///
/// Reported from two screenshots side by side: one screen had "Insights for
/// your phase" under the ring and the other did not. They turned out to be
/// different stages rather than the same screen behaving differently --
/// Hormonal Health builds its own cycle card and had never carried the row,
/// while Living with my cycle and First period have had one since they were
/// written.
///
/// So the stage whose whole premise is that hormones behave unusually was the
/// one that could not ask about them.
void main() {
  const dashboards = {
    'hormonal_health': 'lib/features/home/presentation/stages/hormonal_health_dashboard.dart',
    'first_period_started': 'lib/features/home/presentation/stages/first_period_started_dashboard.dart',
    'living_with_my_cycle': 'lib/features/home/presentation/stages/living_with_my_cycle_dashboard.dart',
  };

  test('each one offers the row', () {
    dashboards.forEach((name, path) {
      final source = File(path).readAsStringSync();
      // First period reaches the same words through the localised key.
      final hasRow = source.contains('Insights for your phase') ||
          source.contains('fpsInsightsForYourPhase');
      expect(hasRow, isTrue, reason: '$name has no phase insights row');
    });
  });

  test('and it asks about the phase she is actually in', () {
    dashboards.forEach((name, path) {
      final source = File(path).readAsStringSync();
      final marker = source.indexOf('// Insights Row');
      expect(marker, greaterThan(-1), reason: name);

      final row = source.substring(marker, marker + 900);
      expect(row, contains('_openDocsyWithPrompt'), reason: name);
      expect(row, contains(r'$_currentPhaseName'), reason: name);
    });
  });

  test('with nothing logged it says what would unlock it', () {
    // A row that opens a phase explanation for someone with no phase would
    // have nothing to explain, so it offers logging instead -- and says so
    // rather than looking broken.
    for (final name in ['hormonal_health', 'living_with_my_cycle']) {
      final source = File(dashboards[name]!).readAsStringSync();
      expect(source, contains('Log your period to unlock phase insights'),
          reason: name);
      expect(source, contains('_openLogPeriodDialog(context)'), reason: name);
    }
  });
}
