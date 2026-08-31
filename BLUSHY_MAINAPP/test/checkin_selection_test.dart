import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A check-in selection must survive changing tabs.
///
/// Switching tabs makes the shell call `syncAllDashboardsFromBackend`, which
/// fires `refreshNotifier`, which calls `_onSiaRefresh`, which reloads the
/// dashboard. **Three** separate paths write the check-in fields on that
/// reload, and each one replaced the tap she had just made:
///
///   * the remote hydration, from `daily_*` answers that carry no date, so the
///     value restored could be from a previous day;
///   * the device restore, from `daily_checkin.json` — the one that bites when
///     running against no backend, since it is then the only writer;
///   * `_loadTodayCheckins`, whose request can have left before her tap
///     arrived and so carries the previous value.
///
/// Asserted against the source: the paths live in a 13,000-line stateful
/// widget behind a backend, a sync service and device storage.
void main() {
  final source = File(
    'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart',
  ).readAsStringSync();

  test('every path that restores a check-in field checks for a fresh edit', () {
    // Remote hydration. The rule itself now lives in `checkin_merge.dart`,
    // where it is exercised against the values from a real device trace; what
    // matters here is that this path routes through it and passes on whether
    // she has just edited the metric.
    expect(
        RegExp(r'void hydrate\(String key[\s\S]{0,400}?'
                r'shouldApplyRemoteCheckin\([\s\S]{0,300}?'
                r'editedThisSession: _userEditedMetrics\.contains\(key\)')
            .hasMatch(source),
        isTrue,
        reason: 'the backend sync must not overwrite a selection she just made');

    // Device restore.
    expect(
        RegExp(r'void restore\(String key[\s\S]{0,200}?'
                r"_userEditedMetrics\.contains\('daily_\$key'\)")
            .hasMatch(source),
        isTrue,
        reason: 'the stored copy must not overwrite a selection she just made');

    // Today's events.
    expect(
        RegExp(r"selections\.removeWhere\([\s\S]{0,120}?"
                r"_userEditedMetrics\.contains\('daily_\$metric'\)")
            .hasMatch(source),
        isTrue,
        reason: 'an in-flight event list must not overwrite a newer tap');
  });

  test('a tap records the edit before anything can restore over it', () {
    expect(source.contains('_userEditedMetrics.add(logKey);'), isTrue,
        reason: 'the tracker key marks the metric as edited');
    expect(source.contains("_userEditedMetrics.add('daily_\$checkinKey');"), isTrue,
        reason: 'so does the check-in key the restore paths are keyed on');

    for (final key in const ['daily_mood', 'daily_energy', 'daily_stress']) {
      expect(source.contains("_userEditedMetrics.add('$key');"), isTrue,
          reason: '$key is written by its own call site and must mark too');
    }
  });

  test('the daily selectors write to the device, not only to the server', () {
    // Without this the stored file kept an older value and put it straight
    // back: the selector persisted to the backend alone.
    expect(
        RegExp(r"checkin\[checkinKey\] = opt;[\s\S]{0,160}?"
                r"BlushyStorage\.write\('daily_checkin\.json', checkin\)")
            .hasMatch(source),
        isTrue,
        reason: 'a tap must update the file the restore path reads');

    // All five daily metrics carry a key, or the ones without it revert.
    for (final key in const ['pain', 'sleep', 'stress', 'water', 'exercise']) {
      expect(source.contains("checkinKey: '$key'"), isTrue,
          reason: '$key must pass a checkinKey or it will be overwritten');
    }
  });
}
