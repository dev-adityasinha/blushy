import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One radius scale across the app.
///
/// This used to say "everything between 14 and 32 is wrong, use 12". That was
/// the right rule for the app it was written against, where radii had spread
/// from 14 to 32 and nothing matched anything else. The app has since been
/// rebuilt to a design that is made of rounded cards, so a flat 12 is no
/// longer what it looks like -- and a rule describing the old look would just
/// be switched off.
///
/// What survives is the reason the rule existed: radii must come from a short
/// shared list, so a new one cannot be picked per widget. The list is the
/// scale below, and anything off it fails.
///
/// Deliberately not covered: `BorderRadius.vertical` / `.only` (sheet tops and
/// artwork), `BoxShape.circle`, and `StadiumBorder`.
const Set<int> radiusScale = {
  // Hairlines and marks: dots, bars, rails, progress ticks.
  1, 2, 3, 4,
  // Small chips and inline tags.
  6, 8, 10,
  // Controls: buttons, fields, dialogs. The old single value, still the
  // most-used one by a wide margin.
  12,
  // Tiles and inline pills.
  16,
  // Cards. BlushySurface's default, and what most of the app now sits on.
  20,
  // The largest surfaces: the cycle hero, the nav bar, the chat input.
  24,
  // Search: a full pill at the height it is used at.
  28,
  // The radio marker, which is a circle written as a big radius.
  100,
};

void main() {
  test('every radius comes from the scale', () {
    final offenders = <String>[];
    // Uniform corners only. `BorderRadius.vertical` / `.only` are sheet tops
    // and artwork, which are shaped by what they sit against rather than by
    // the control scale, and were exempt under the old rule too.
    final pattern = RegExp(
        r'BorderRadius\.circular\((\d+)\)'
        r'|BorderRadius\.all\(Radius\.circular\((\d+)\)\)');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final value = int.parse((match.group(1) ?? match.group(2))!);
        if (radiusScale.contains(value)) continue;
        offenders.add('${entity.path}: circular($value)');
      }
    }

    expect(offenders, isEmpty,
        reason: 'pick the nearest value from radiusScale rather than a new one');
  });

  test('the scale stays short', () {
    // The point of a scale is that it is small enough to hold in your head.
    // Adding to it is allowed; adding to it freely is how the spread this
    // guard was written for came back.
    expect(radiusScale.length, lessThanOrEqualTo(14));
  });
}
