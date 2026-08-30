import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/features/home/doctor_summary_composer.dart';

/// These pin the point where the user's removals are honoured. If the composer
/// is wrong, something the user explicitly took out of their summary reaches a
/// clinician, a message thread or the clipboard.

List<Map<String, dynamic>> _sections() => [
      {
        'key': 'symptoms',
        'title': 'Symptoms logged in this period',
        'provenance': 'user_reported',
        'items': [
          {'text': 'Pelvic pain: logged 5 times, average severity 6/10'},
          {'text': 'Fatigue: logged 3 times'},
          {'text': 'Bloating: logged 2 times'},
        ],
      },
      {
        'key': 'app_observations',
        'title': 'Patterns the app noticed',
        'provenance': 'app_generated',
        'items': [
          {'text': 'Based on your recent logs, shorter sleep precedes lower mood.'},
        ],
      },
    ];

DoctorSummaryComposer _composer({
  Set<String> removed = const {},
  List<String> questions = const [],
  String? disclaimer,
}) {
  return DoctorSummaryComposer(
    sections: _sections(),
    removed: removed,
    questions: questions,
    fromLabel: '1 Jun 2026',
    toLabel: '29 Aug 2026',
    disclaimer: disclaimer,
  );
}

void main() {
  group('removals', () {
    test('nothing removed keeps everything', () {
      final composer = _composer();
      expect(composer.keptSections.length, 2);
      expect(composer.keptEntryCount, 4);
      expect(composer.isEmpty, isFalse);
    });

    test('a removed entry is absent from the sections and the text', () {
      final composer = _composer(removed: {DoctorSummaryComposer.entryKey('symptoms', 1)});

      final symptoms = composer.keptSections.firstWhere((s) => s['key'] == 'symptoms');
      final texts = (symptoms['items'] as List).map((i) => i['text']).toList();

      expect(texts, hasLength(2));
      expect(texts.any((t) => t.toString().contains('Fatigue')), isFalse);
      expect(composer.toPlainText().contains('Fatigue'), isFalse);
      // The others survive.
      expect(composer.toPlainText().contains('Pelvic pain'), isTrue);
      expect(composer.toPlainText().contains('Bloating'), isTrue);
    });

    test('removing every entry in a section drops the section, not just its rows', () {
      final composer = _composer(removed: {
        DoctorSummaryComposer.entryKey('app_observations', 0),
      });

      expect(composer.keptSections.map((s) => s['key']), ['symptoms']);
      expect(composer.toPlainText().contains('Patterns the app noticed'), isFalse);
    });

    test('removing everything reports empty rather than exporting a bare header', () {
      final composer = _composer(removed: {
        DoctorSummaryComposer.entryKey('symptoms', 0),
        DoctorSummaryComposer.entryKey('symptoms', 1),
        DoctorSummaryComposer.entryKey('symptoms', 2),
        DoctorSummaryComposer.entryKey('app_observations', 0),
      });

      expect(composer.isEmpty, isTrue);
      expect(composer.keptSections, isEmpty);
      expect(composer.keptEntryCount, 0);
    });

    test('removal keys are scoped per section, so index 0 of one is not index 0 of another', () {
      final composer = _composer(removed: {DoctorSummaryComposer.entryKey('symptoms', 0)});
      final text = composer.toPlainText();

      expect(text.contains('Pelvic pain'), isFalse);
      // The other section's index 0 is untouched.
      expect(text.contains('shorter sleep precedes lower mood'), isTrue);
    });

    test('the composer does not mutate the sections it was given', () {
      final original = _sections();
      final composer = DoctorSummaryComposer(
        sections: original,
        removed: {DoctorSummaryComposer.entryKey('symptoms', 0)},
        fromLabel: 'a',
        toLabel: 'b',
      );
      composer.keptSections;

      expect((original[0]['items'] as List).length, 3, reason: 'source data must be untouched');
    });
  });

  group('exported text', () {
    test('labels which lines are reported and which are app-generated', () {
      final text = _composer().toPlainText();
      expect(text.contains('What you logged'), isTrue);
      expect(text.contains('What the app noticed'), isTrue);
    });

    test('always carries the disclaimer, because context is lost once shared', () {
      expect(_composer().toPlainText().contains('not a diagnosis'), isTrue);

      final custom = _composer(disclaimer: 'Server-supplied wording, not a diagnosis.');
      expect(custom.toPlainText().contains('Server-supplied wording'), isTrue);
    });

    test('includes the date range and the questions', () {
      final text = _composer(questions: ['Could this be endometriosis?']).toPlainText();
      expect(text.contains('1 Jun 2026 to 29 Aug 2026'), isTrue);
      expect(text.contains('Questions to ask'), isTrue);
      expect(text.contains('Could this be endometriosis?'), isTrue);
    });

    test('omits the questions heading when there are none', () {
      expect(_composer().toPlainText().contains('Questions to ask'), isFalse);
    });

    test('handles plain string items as well as mapped ones', () {
      final composer = DoctorSummaryComposer(
        sections: [
          {'key': 'k', 'title': 'T', 'provenance': 'user_reported', 'items': ['a bare string entry']},
        ],
        fromLabel: 'a',
        toLabel: 'b',
      );
      expect(composer.toPlainText().contains('a bare string entry'), isTrue);
    });
  });

  group('provenance labels', () {
    test('map to plain wording', () {
      expect(DoctorSummaryComposer.provenanceLabel('user_reported'), 'What you logged');
      expect(DoctorSummaryComposer.provenanceLabel('app_generated'), 'What the app noticed');
      expect(DoctorSummaryComposer.provenanceLabel(null), 'From your records');
      expect(DoctorSummaryComposer.provenanceLabel('something_else'), 'From your records');
    });
  });
}
