import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A check-in answer must survive the reload that changing tabs causes.
///
/// Switching tabs makes the shell call `syncAllDashboardsFromBackend`, which
/// fires `refreshNotifier`, which calls `_onSiaRefresh`, which reloads the
/// dashboard. **Three** separate paths write the check-in fields on that
/// reload, and each one replaced the answer just given:
///
///   * the remote hydration, from `daily_*` answers that carry no date, so the
///     value restored could be from a previous day;
///   * the device restore, from `daily_checkin.json` — the one that bites when
///     running against no backend, since it is then the only writer;
///   * `_loadTodayCheckins`, whose request can have left before her tap
///     arrived and so carries the previous value.
///
/// The answers used to come from selectors inline in seven per-stage check-in
/// builders. They come from the symptoms sheet now, so the writers are the
/// three persist functions rather than the selector helper — the race is
/// unchanged, only the call sites moved.
///
/// Asserted against the source: the paths live in a 10,000-line stateful
/// widget behind a backend, a sync service and device storage.
void main() {
  final source = File(
    'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart',
  ).readAsStringSync();

  test('every path that restores a check-in field checks for a fresh edit', () {
    // Remote hydration. The rule itself lives in `checkin_merge.dart`, where
    // it is exercised against values from a real device trace; what matters
    // here is that this path routes through it and passes on whether she has
    // just edited the metric.
    // Asserted on the guard call rather than on how close the two lines are:
    // a proximity window silently stops testing anything the moment the
    // function grows.
    expect(source.contains('shouldApplyRemoteCheckin('), isTrue,
        reason: 'remote hydration must route through the merge rule');
    expect(
        source.contains('editedThisSession: _userEditedMetrics.contains(key)'),
        isTrue,
        reason: 'and must tell it whether she has just answered');

    // The in-flight event list.
    expect(
        RegExp(r"selections\.removeWhere\([\s\S]{0,120}?"
                r"_userEditedMetrics\.contains\('daily_\$metric'\)")
            .hasMatch(source),
        isTrue,
        reason: 'an in-flight event list must not overwrite a newer answer');

    // And the symptoms, which are a list rather than a single value.
    expect(source.contains("_userEditedMetrics.contains('daily_symptom')"),
        isTrue,
        reason: 'the restored symptom set must not overwrite a newer one');
  });

  test('every writer marks the metric as edited', () {
    // Each of the three is a way an answer reaches storage, and any that does
    // not mark is one the next reload silently reverts.
    for (final entry in const {
      '_persistCheckinAnswer': "_userEditedMetrics.add('daily_\$key');",
      '_persistCheckinSymptoms': "_userEditedMetrics.add('daily_symptom');",
      '_persistNumericMetric': "_userEditedMetrics.add('daily_\${metric.key}');",
    }.entries) {
      expect(source.contains(entry.key), isTrue,
          reason: '${entry.key} is the writer this asserts about');
      expect(source.contains(entry.value), isTrue,
          reason: '${entry.key} must mark the metric as edited');
    }
  });

  test('every writer reaches the device, not only the server', () {
    // Without this the stored file keeps an older value and puts it straight
    // back: the selector used to persist to the backend alone.
    final writes = RegExp(r"BlushyStorage\.write\('daily_checkin\.json', checkin\)")
        .allMatches(source)
        .length;
    expect(writes, greaterThanOrEqualTo(3),
        reason: 'each of the three writers must update the file the restore '
            'path reads');

    for (final fn in const [
      '_persistCheckinAnswer',
      '_persistCheckinSymptoms',
      '_persistNumericMetric',
    ]) {
      // The declaration, not the first mention: the call sites come earlier
      // in the file and their windows do not contain the write.
      final start = source.indexOf('void $fn(');
      expect(start, greaterThan(-1));
      // Within the body, not somewhere else in the file.
      // The whole function rather than a fixed window: the sheet's writer
      // grew past 2600 characters, with the write still in it.
      final body = source.substring(start, source.indexOf('\n  }', start));
      expect(body.contains("BlushyStorage.write('daily_checkin.json'"), isTrue,
          reason: '$fn must write to the device');
    }
  });
}
