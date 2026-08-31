import 'package:blushy_life_app/core/checkin_merge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Built from a real device trace, not from reading the code.
///
/// Tapping a check-in option and switching tabs changed the selections. The
/// trace showed why: the device copy and today's events agreed with what she
/// had picked, and the `daily_*` answers on the server — a partial mirror that
/// only some selectors write and nothing clears — disagreed, and were applied
/// over the top on every sync.
void main() {
  group('the exact values from the device trace', () {
    // device  : mood Happy | energy High | sleep 6-8h | water 3L | flow Heavy
    // remote  : mood Cramps| energy Medium| sleep <6h | water 1L | flow Light
    const observed = {
      'mood': ['Happy', 'Cramps'],
      'energy': ['High', 'Medium'],
      'sleep': ['6-8h', '<6h'],
      'water': ['3L', '1L'],
      'flow': ['Heavy', 'Light'],
    };

    test('the stale mirror never replaces what the device holds', () {
      observed.forEach((metric, pair) {
        final onDevice = pair[0];
        final onServer = pair[1];

        expect(
          shouldApplyRemoteCheckin(
            remoteValue: onServer,
            deviceValue: onDevice,
            // What the trace had: the device dated, the mirror undated.
            deviceAt: DateTime(2026, 8, 31, 19, 42),
            remoteAt: null,
          ),
          isFalse,
          reason: '$metric would change from $onDevice to $onServer — '
              'this is the reported bug',
        );
      });
    });
  });

  test('it still fills in a metric the device knows nothing about', () {
    // A fresh install, or an answer given on another device: without this the
    // mirror would be useless rather than merely quiet.
    expect(
      shouldApplyRemoteCheckin(remoteValue: 'Medium', deviceValue: null),
      isTrue,
    );
    expect(
      shouldApplyRemoteCheckin(remoteValue: 'Medium', deviceValue: '  '),
      isTrue,
    );
  });

  test('a demonstrably newer server answer does replace the device copy', () {
    expect(
      shouldApplyRemoteCheckin(
        remoteValue: 'Low',
        deviceValue: 'High',
        deviceAt: DateTime(2026, 8, 31, 9, 0),
        remoteAt: DateTime(2026, 8, 31, 11, 0),
      ),
      isTrue,
      reason: 'logged later on another device',
    );

    expect(
      shouldApplyRemoteCheckin(
        remoteValue: 'Low',
        deviceValue: 'High',
        deviceAt: DateTime(2026, 8, 31, 11, 0),
        remoteAt: DateTime(2026, 8, 31, 9, 0),
      ),
      isFalse,
      reason: 'older than what the device already has',
    );
  });

  test('a tap made this session outranks anything the server says', () {
    expect(
      shouldApplyRemoteCheckin(
        remoteValue: 'Severe',
        deviceValue: 'Mild',
        remoteAt: DateTime(2030),
        editedThisSession: true,
      ),
      isFalse,
      reason: 'the sync carrying this can have left before her tap arrived',
    );
  });

  test('an empty server value is not an answer', () {
    expect(shouldApplyRemoteCheckin(remoteValue: null, deviceValue: 'High'),
        isFalse);
    expect(shouldApplyRemoteCheckin(remoteValue: '', deviceValue: null), isFalse);
    expect(shouldApplyRemoteCheckin(remoteValue: '   ', deviceValue: null),
        isFalse);
  });
}
