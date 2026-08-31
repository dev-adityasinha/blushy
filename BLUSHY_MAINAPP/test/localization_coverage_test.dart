import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rules for the translation files while the app is being made translatable.
///
/// Strings are being pulled out of the widgets into `app_en.arb` in bulk, so
/// the six other locales are deliberately behind. A key missing from a locale
/// inherits the English implementation from the generated base class, so the
/// app keeps working and the key simply reads as untranslated — which is the
/// normal hand-off point for a translator.
///
/// What must not happen: a locale quietly carrying an English string as though
/// it were translated, or the locales drifting apart from each other so that
/// one language is further along than the rest for no recorded reason.
void main() {
  Map<String, dynamic> read(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  final template = read('lib/l10n/app_en.arb');
  final templateKeys = template.keys.where((k) => !k.startsWith('@')).toSet();

  final localeFiles = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb') && !f.path.endsWith('app_en.arb'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there is a template and locales to check', () {
    expect(templateKeys, isNotEmpty);
    expect(localeFiles, isNotEmpty);
  });

  for (final file in localeFiles) {
    final name = file.path.split(RegExp(r'[\\/]')).last;
    final data = read(file.path);
    final keys = data.keys.where((k) => !k.startsWith('@')).toSet();

    test('$name defines nothing the template does not', () {
      // A key here with no counterpart in English is dead weight: nothing can
      // ever read it, and it hides the fact that the English string was renamed.
      final orphans = keys.difference(templateKeys).toList()..sort();
      expect(orphans, isEmpty,
          reason: '$name has keys the template dropped: ${orphans.take(8).join(", ")}');
    });

    test('$name is translated where it claims to be', () {
      // Copying the English string into a locale file looks like progress and
      // reads as English to the user. Falling back by omission is honest; a
      // duplicate is not.
      final fake = keys
          .where((k) => data[k] is String && template[k] is String)
          .where((k) => (data[k] as String) == (template[k] as String))
          // A brand name is legitimately the same in every language.
          .where((k) => !(data[k] as String).contains('Dr. Docsy'))
          .toList()
        ..sort();

      expect(fake.length, lessThan(5),
          reason: '$name repeats the English string for: ${fake.take(8).join(", ")}. '
              'Leave the key out instead — it will fall back and stay visible as untranslated.');
    });
  }

  test('the locales stay in step with each other', () {
    // One language racing ahead of the others is usually an accident of which
    // screen someone happened to work on, and it makes the backlog impossible
    // to reason about.
    final counts = <String, int>{};
    for (final file in localeFiles) {
      final name = file.path.split(RegExp(r'[\\/]')).last;
      counts[name] = read(file.path).keys.where((k) => !k.startsWith('@')).length;
    }

    final values = counts.values.toSet();
    expect(values.length, 1,
        reason: 'locales define different numbers of keys: $counts');
  });
}
