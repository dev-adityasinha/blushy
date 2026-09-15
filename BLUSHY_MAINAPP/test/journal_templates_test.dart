import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/features/journal/journal_templates.dart';

/// A template has to change what the page opens with.
///
/// Templates were names and nothing else: choosing "Gratitude" created an
/// entry titled "Gratitude" carrying the same blank "Tap to start writing your
/// reflection..." as every other one. The stage config already varied the list
/// by life stage, so the app knew which template suited her and then did
/// nothing with the answer.
void main() {
  group('prompts', () {
    test('a template gives the page something to ask', () {
      final prompts = JournalTemplates.promptsFor('Gratitude');
      expect(prompts, isNotEmpty);
      expect(prompts, isNot(JournalTemplates.fallback));
    });

    test('name variants resolve to the same set', () {
      // The stage lists carry "Gratitude", "Gratitude Log" and "Gratitude
      // Journal". Matching exact names would drop two of the three to blank.
      final a = JournalTemplates.promptsFor('Gratitude');
      final b = JournalTemplates.promptsFor('Gratitude Log');
      final c = JournalTemplates.promptsFor('Gratitude Journal');
      expect(b, a);
      expect(c, a);
    });

    test('an unknown template still opens with a usable prompt', () {
      expect(JournalTemplates.promptsFor('Something Invented'),
          JournalTemplates.fallback);
      expect(JournalTemplates.promptsFor(null), JournalTemplates.fallback);
      expect(JournalTemplates.fallback, isNotEmpty);
    });

    test('every template name in the stage config resolves', () {
      // A name nobody wrote prompts for falls back silently, which is how this
      // feature ended up doing nothing in the first place.
      final config = File('lib/core/stage_config.dart').readAsStringSync();
      final block = RegExp(r'journalTemplates:\s*\[([^\]]*)\]', dotAll: true);
      final names = <String>{};
      for (final m in block.allMatches(config)) {
        for (final n in RegExp(r"'([^']+)'").allMatches(m[1]!)) {
          names.add(n[1]!);
        }
      }

      expect(names, isNotEmpty, reason: 'no template names found to check');

      final unresolved = names
          .where((n) => JournalTemplates.promptsFor(n) == JournalTemplates.fallback)
          .toList()
        ..sort();

      expect(unresolved, isEmpty,
          reason: 'these open blank despite being offered: ${unresolved.join(", ")}');
    });

    test('the pregnancy prompts do not assume how it is going', () {
      // A prompt about a due date or a growing bump lands badly on someone
      // whose pregnancy has ended.
      final prompts = JournalTemplates.promptsFor('Pregnancy Journal').join(' ').toLowerCase();
      for (final assumption in ['due date', 'bump', 'baby is', 'weeks along', 'kick']) {
        expect(prompts.contains(assumption), isFalse,
            reason: 'assumes a course this pregnancy may not be taking: $assumption');
      }
    });
  });

  test('the entry builder places one item per prompt', () {
    final source =
        File('lib/features/journal/journal_screen.dart').readAsStringSync();
    expect(source.contains('JournalTemplates.promptsFor'), isTrue);
    expect(RegExp(r'for \(var i = 0; i < prompts\.length; i\+\+\)').hasMatch(source), isTrue,
        reason: 'each prompt needs its own item, or they render as one blob');
  });
}
