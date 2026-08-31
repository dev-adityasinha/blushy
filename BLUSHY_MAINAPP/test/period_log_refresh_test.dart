import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/services/sia_dashboard_service.dart';

import 'helpers/isolated_storage.dart';

/// Logging a period must refresh what the home page shows.
///
/// The dashboard keeps its own copy of the cycle, fetched from the server, and
/// `updatePersonalContext` does not invalidate it. The only thing that reloads
/// it is `refreshNotifier`.
///
/// Home did bump that notifier — but only when Dr. Docsy was pushed as a route
/// from the home floating button and then popped. Dr. Docsy is also a bottom
/// navigation tab, and moving between tabs pops nothing, so a period logged
/// that way left the chart showing the previous cycle until something else
/// happened to reload it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedStorage();

  test('markDashboardDirty tells listening dashboards to reload', () {
    final service = SiaDashboardService();
    var notified = 0;
    void listener() => notified++;

    service.refreshNotifier.addListener(listener);
    addTearDown(() => service.refreshNotifier.removeListener(listener));

    service.markDashboardDirty();

    expect(notified, greaterThan(0),
        reason: 'the dashboard reloads its cycle from this notifier and nothing else');
  });

  test('the Dr. Docsy period log marks the dashboard dirty', () {
    // Source-level: reaching this button in a widget test means building the
    // whole assistant screen with a signed-in user and a live backend. The
    // call is what matters, and its absence is exactly the reported bug.
    final source = File('lib/features/sia/sia_screen.dart').readAsStringSync();
    final logIndex = source.indexOf('logPeriodEntry');
    expect(logIndex, greaterThan(-1), reason: 'the period log path moved');

    // Within the same handler, not merely somewhere in the file.
    final handler = source.substring(logIndex, logIndex + 1400);
    expect(
      handler.contains('markDashboardDirty'),
      isTrue,
      reason: 'logging a period must invalidate the dashboard, or the chart '
          'keeps showing the previous cycle',
    );
  });

  test('a failed period log does not claim the date was recorded', () {
    // The write was wrapped in `catch (_) {}` and the success message shown
    // regardless, so a failure was indistinguishable from a save.
    final source = File('lib/features/sia/sia_screen.dart').readAsStringSync();
    final logIndex = source.indexOf('logPeriodEntry');
    final handler = source.substring(logIndex, logIndex + 1400);

    expect(handler.contains('couldNotSaveMessage'), isTrue,
        reason: 'a failed write must say so rather than confirming');
  });
}
