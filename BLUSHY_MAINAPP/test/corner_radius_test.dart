import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One small corner radius across the app.
///
/// The codebase had spread from 14 to 32, so buttons and chips read as pills
/// and nothing matched anything else. Everything in that band is 12 now.
///
/// Deliberately not covered: radii already 12 or under, sheet tops and artwork
/// written as `BorderRadius.vertical` / `.only`, `BoxShape.circle`, and the one
/// `circular(100)` that draws a radio marker.
void main() {
  test('nothing is rounded back into a pill', () {
    final offenders = <String>[];
    final pattern = RegExp(r'BorderRadius\.circular\((\d+)\)');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final value = int.parse(match.group(1)!);
        if (value >= 14 && value <= 32) {
          offenders.add('${entity.path}: circular($value)');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'use 12 (BlushyTheme.radius) so controls stay rectangular');
  });
}
