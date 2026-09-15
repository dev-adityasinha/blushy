import 'package:blushy_life_app/features/home/checkin_event_mapper.dart';
import 'package:blushy_life_app/features/home/checkin_followups.dart';
import 'package:blushy_life_app/features/home/checkin_vocabulary.dart';
import 'package:blushy_life_app/features/home/symptom_categories.dart';
import 'package:flutter_test/flutter_test.dart';

/// The check-in questions generated from today's symptoms.
void main() {
  group('generation', () {
    test('nothing logged asks nothing extra', () {
      expect(CheckinFollowUps.forSymptoms(const []), isEmpty);
      expect(CheckinFollowUps.forSymptoms(const ['']), isEmpty);
    });

    test('a symptom earns questions it does not already answer', () {
      final cards = CheckinFollowUps.forSymptoms(['Fatigue']);
      expect(cards, isNotEmpty);
      // Asking "are you tired?" after she logged fatigue learns nothing.
      for (final card in cards) {
        expect(card.question.toLowerCase(), isNot(contains('tired')));
        expect(card.becauseOf, contains('fatigue'));
      }
    });

    test('the cards change when the symptoms change', () {
      final monday = CheckinFollowUps.forSymptoms(['Fatigue']);
      final tuesday = CheckinFollowUps.forSymptoms(['Cramps']);

      expect(monday, isNot(equals(tuesday)));
      expect(monday.map((c) => c.metric), contains('sleep'));
      expect(tuesday.map((c) => c.metric), contains('exercise'));
    });

    test('case does not matter', () {
      expect(CheckinFollowUps.forSymptoms(['CRAMPS']),
          CheckinFollowUps.forSymptoms(['cramps']));
    });

    test('several symptoms pointing at one metric ask once, naming all', () {
      // Cramps, backache and abdominal pain all raise movement. This used to
      // produce a single card crediting only the first, so logging three pain
      // symptoms asked one question and looked like it had ignored two.
      final cards =
          CheckinFollowUps.forSymptoms(['Cramps', 'Backache', 'Abdominal pain']);

      final movement = cards.where((c) => c.metric == 'exercise');
      expect(movement.length, 1, reason: 'two cards would overwrite each other');
      expect(movement.first.becauseOf,
          containsAll(['cramps', 'backache', 'abdominal pain']));
      expect(movement.first.becauseOfLabel,
          'cramps, backache and abdominal pain');
    });

    test('a full day earns more than three questions', () {
      // The cap was three, which could not cover a day with six symptoms in
      // it -- and the pattern engine needs paired observations across several
      // metrics before it can report anything at all.
      final cards = CheckinFollowUps.forSymptoms(
          ['Headache', 'Cramps', 'Fatigue', 'Bloating', 'Acne', 'Insomnia']);

      expect(cards.length, greaterThanOrEqualTo(5));
      expect(cards.length, lessThanOrEqualTo(CheckinFollowUps.maxCards));
      // Each on its own metric, so none of them overwrites another.
      expect(cards.map((c) => c.metric).toSet().length, cards.length);
    });

    test('the most-implicated question comes first', () {
      // A metric five symptoms raise is worth more than one a single symptom
      // raises. Before this the first rule in file order simply won.
      final cards = CheckinFollowUps.forSymptoms(
          ['Headache', 'Cramps', 'Fatigue', 'Bloating', 'Acne', 'Insomnia']);

      for (var i = 1; i < cards.length; i++) {
        expect(cards[i - 1].becauseOf.length,
            greaterThanOrEqualTo(cards[i].becauseOf.length),
            reason: 'cards must be ordered by how much they are implicated');
      }
    });

    test('never more than the cap, however much is logged', () {
      final cards = CheckinFollowUps.forSymptoms(
          CheckinVocabulary.symptoms + CheckinVocabulary.digestion);
      expect(cards.length, lessThanOrEqualTo(CheckinFollowUps.maxCards));
    });

    test('the opt-out earns no follow-ups', () {
      expect(CheckinFollowUps.forSymptoms(['Everything is fine']), isEmpty);
    });

    test('the clinical words earn no lifestyle question', () {
      // There is no lifestyle question that belongs after a blood clot, and
      // inventing one would suggest it is hers to fix.
      for (final clinical in ['Blood clots', 'Unusual', 'Clumpy white', 'Grey']) {
        expect(CheckinFollowUps.forSymptoms([clinical]), isEmpty,
            reason: '$clinical must not raise a lifestyle question');
      }
    });

    test('the same symptoms give the same cards in the same order', () {
      // Stable within a day: the ranking must not shuffle on rebuild.
      final a = CheckinFollowUps.forSymptoms(['Headache', 'Cramps', 'Acne']);
      final b = CheckinFollowUps.forSymptoms(['Acne', 'Cramps', 'Headache']);
      expect(a.map((c) => c.id).toList(), b.map((c) => c.id).toList());
    });

    test('a symptom repeated does not count twice', () {
      final cards = CheckinFollowUps.forSymptoms(['Cramps', 'cramps', 'CRAMPS']);
      for (final card in cards) {
        expect(card.becauseOf, ['cramps']);
      }
    });
  });

  group('every answer has somewhere to go', () {
    test('each metric a follow-up writes is one the mapper knows', () {
      for (final metric in CheckinFollowUps.metrics) {
        expect(CheckinVocabulary.byMetric.containsKey(metric), isTrue,
            reason: '$metric is not in the registry');
      }
    });

    test('every yes and no is a word its metric actually offers', () {
      // A value the selector cannot render reverses back to nothing, so the
      // answer would not show as recorded.
      final byMetric = <String, Set<String>>{};
      for (final symptom in CheckinFollowUps.symptomsWithQuestions) {
        for (final card in CheckinFollowUps.forSymptoms([symptom])) {
          byMetric.putIfAbsent(card.metric, () => <String>{})
            ..add(card.yesValue)
            ..add(card.noValue);
        }
      }

      expect(byMetric, isNotEmpty);
      byMetric.forEach((metric, values) {
        final offered = CheckinVocabulary.labelsFor(metric);
        for (final value in values) {
          expect(offered, contains(value),
              reason: '$metric does not offer "$value"');
          expect(CheckinEventMapper.map(metric, value), isNotNull,
              reason: '$metric "$value" does not map to an event');
        }
      });
    });

    test('every symptom with a question is one the sheet can log', () {
      // A rule for a word no category offers is a question that can never be
      // asked, and would go unnoticed.
      final loggable = {
        for (final c in SymptomCategories.all)
          for (final o in c.options) o.toLowerCase(),
      };
      for (final symptom in CheckinFollowUps.symptomsWithQuestions) {
        expect(loggable, contains(symptom),
            reason: '$symptom raises a question but cannot be logged');
      }
    });

    test('pain is deliberately not asked as a yes or no', () {
      // The only honest mapping for "yes" is Severe, which stores an 8 --
      // above the threshold on rf_pg_severe_abdominal_pain. A checkbox must
      // not raise a reviewed clinical escalation.
      expect(CheckinFollowUps.metrics, isNot(contains('pain')));
    });
  });
}
