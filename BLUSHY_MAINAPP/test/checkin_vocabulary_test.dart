import 'dart:io';

import 'package:blushy_life_app/features/home/checkin_event_mapper.dart';
import 'package:blushy_life_app/features/home/checkin_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

/// A word a selector can offer must be a word the mapper can record.
///
/// This is the guard the registry exists for. Declaring the vocabularies in
/// one file does not stop them drifting from [CheckinEventMapper]; this does.
///
/// Before it, a list could gain a word the mapper had never heard of and the
/// answer went nowhere: `map` returned null, `_recordCheckinEvent` returned
/// without recording, and no error was raised anywhere. Found that way, over
/// four separate rounds: the everyday wellness sleep ranges, two of its three
/// movement options, its half-litre hydration step, the perimenopause 1.5L
/// step and its "None" flow, and the pregnancy and postpartum movement
/// wording. Each was logged by a person, stored, shown back on the dashboard,
/// and never reached the pattern engine, the care plan, the doctor summary,
/// the partner view or Docsy.
void main() {
  group('the registry and the mapper agree', () {
    test('every word maps, unless it is declared unrecorded', () {
      final unmapped = <String>[];

      CheckinVocabulary.byMetric.forEach((metric, variants) {
        for (final label in {for (final v in variants) ...v}) {
          if (CheckinVocabulary.isUnrecorded(metric, label)) continue;
          if (CheckinEventMapper.map(metric, label) == null) {
            unmapped.add('$metric "$label"');
          }
        }
      });

      expect(unmapped, isEmpty,
          reason: 'these would be dropped without a word: ${unmapped.join(", ")}');
    });

    test('a word declared unrecorded really records nothing', () {
      // The other direction, and the one that keeps the opt-out honest. A
      // declaration that stopped being true would otherwise sit there reading
      // like a decision while the value was quietly being stored after all.
      final recorded = <String>[];

      CheckinVocabulary.unrecorded.forEach((metric, labels) {
        for (final label in labels) {
          if (CheckinEventMapper.map(metric, label) != null) {
            recorded.add('$metric "$label"');
          }
        }
      });

      expect(recorded, isEmpty,
          reason: 'declared unrecorded but recorded anyway: ${recorded.join(", ")}');
    });

    test('an unrecorded word belongs to a real vocabulary', () {
      // Guards against the opt-out drifting: a metric renamed or a word
      // reworded would leave this declaration exempting something that no
      // longer exists, and the next word to go missing would look declared.
      CheckinVocabulary.unrecorded.forEach((metric, labels) {
        expect(CheckinVocabulary.byMetric.containsKey(metric), isTrue,
            reason: '$metric is declared unrecorded but is not a metric');
        for (final label in labels) {
          expect(CheckinVocabulary.labelsFor(metric), contains(label),
              reason: '$metric "$label" is exempted but no card offers it');
        }
      });
    });

    test('a word keeps its own casing when read back', () {
      // The label she picked is what the card must show again, so "8h+" does
      // not come back as "8h", "2.5L" does not come back as "2.5l", and
      // "Eggwhite" does not come back as "egg_white".
      //
      // Every metric in the registry, rather than a list written out here --
      // a hardcoded list is what let the vocabularies drift in the first
      // place, and this file exists because of that.
      for (final metric in CheckinVocabulary.byMetric.keys) {
        for (final label in CheckinVocabulary.labelsFor(metric)) {
          // Nothing to read back for a word that was never written down.
          if (CheckinVocabulary.isUnrecorded(metric, label)) continue;
          final event = CheckinEventMapper.map(metric, label)!;
          final back = CheckinEventMapper.reverse(event.eventType, event.payload);
          expect(back?.value, label,
              reason: '$metric "$label" came back as "${back?.value}"');
        }
      }
    });
  });

  group('the dashboards use the registry', () {
    /// Read from source, because the failure this catches is someone writing a
    /// fresh literal list instead of reaching for the registry -- which is
    /// exactly how the vocabularies drifted apart in the first place.
    test('no stage declares its own list for a mapped metric', () {
      final source = File(
        'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart',
      ).readAsStringSync();

      // Only the metrics the mapper records. The stage-specific trackers
      // (cervical mucus, hot flashes, feeding and the rest) have no event type
      // at all, so their lists are not covered here and are left inline.
      final mapped = CheckinVocabulary.byMetric.keys.join('|');
      final literals = RegExp(
        'final List<String> ($mapped)Options = \\[',
      ).allMatches(source).map((m) => m.group(1)).toList();

      expect(literals, isEmpty,
          reason: 'these declare their own words instead of using '
              'CheckinVocabulary: ${literals.join(", ")}');
    });
  });
}
