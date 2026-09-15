import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A message sent today must not move to "Yesterday" when the app reopens.
///
/// The server stores timestamps in UTC, so `DateTime.tryParse` returns a UTC
/// DateTime and reading `.year`/`.month`/`.day` off it gives the *UTC*
/// calendar date. At 01:00 in Asia/Kolkata that is still the previous date in
/// UTC, so a message sent minutes earlier was filed under yesterday.
///
/// It only showed after a reload, which is what made it look like a glitch: a
/// message added during the session carries a local timestamp and grouped
/// correctly, and only the reloaded history carries the server's UTC one.
/// Switching the app off and on is exactly what swaps one for the other.
void main() {
  test('a UTC timestamp read raw gives the wrong calendar day', () {
    // 19:30 UTC is already tomorrow anywhere past UTC+04:30.
    final utcEvening = DateTime.utc(2026, 9, 14, 19, 30);
    final local = utcEvening.toLocal();

    final rawDay = DateTime(utcEvening.year, utcEvening.month, utcEvening.day);
    final localDay = DateTime(local.year, local.month, local.day);

    if (local.day != utcEvening.day) {
      // The machine running this is east of UTC, so the bug is reproducible
      // here and `localDay` is the one matching the clock on her wall.
      expect(localDay, isNot(rawDay));
      expect(localDay.day, local.day);
    } else {
      // West of UTC, or on UTC itself, both agree -- which is why this was
      // invisible to anyone testing there.
      expect(localDay, rawDay);
    }
  });

  test('the screen converts before it groups or prints a time', () {
    final source = File('lib/features/sia/sia_screen.dart').readAsStringSync();

    // Two reads of a message timestamp: the day separator, and the clock on
    // the bubble. A raw parse in either one is the bug.
    final reads = RegExp(r"DateTime\.tryParse\(msg\['at'\] \?\? ''\)(\?\.toLocal\(\))?")
        .allMatches(source)
        .toList();

    expect(reads.length, 2, reason: 'both reads have to be covered');
    for (final read in reads) {
      expect(read.group(1), isNotNull, reason: 'raw UTC parse: ${read.group(0)}');
    }
  });

  test('the day label still compares against a local today', () {
    // `toLocal()` on the message only helps if the other side of the
    // subtraction is local too.
    final source = File('lib/features/sia/sia_screen.dart').readAsStringSync();
    final label = source.substring(
      source.indexOf('String _dayLabel(DateTime day) {'),
      source.indexOf('Widget _buildDaySeparator'),
    );

    expect(label, contains('DateTime.now()'));
    expect(label.contains('DateTime.now().toUtc()'), isFalse);
  });
}
