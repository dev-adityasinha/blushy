import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/core/metric_gating.dart';

/// The home page is gated on what she answered. These are the rules deciding
/// that, pulled out of the widget so they can be exercised.
void main() {
  group('what she picked switches the card on', () {
    test('a symptom she chose opens the card keyed to it', () {
      expect(metricMatches(['cramps', 'fatigue'], ['pain', 'cramps']), isTrue);
      expect(metricMatches(['stitches'], ['stitches', 'perineal']), isTrue);
      expect(metricMatches(['bleeding (lochia)'], ['lochia']), isTrue);
    });

    test('a branch answer counts, not just the symptom list', () {
      // These were asked, stored, and never read: the gating looked at
      // `symptoms` and `goals` only.
      // Keyword lists copied verbatim from the dashboard gates they guard, so
      // this asserts against the real thing rather than a plausible-looking
      // list. An earlier draft of this test invented `['ovulation test','opk']`
      // and failed, because the real gate carries 'strip' too.
      expect(
          metricMatches(['basal body temperature'],
              ['bbt', 'temperature', 'basal', 'thermometer']),
          isTrue);
      expect(
          metricMatches(['ovulation strips'],
              ['lh', 'ovulation test', 'opk', 'strip', 'fertility']),
          isTrue);
      expect(
          metricMatches(['breastfeeding'],
              ['feeding', 'breastfeeding', 'pumping', 'bottle', 'baby']),
          isTrue,
          reason: 'the keyword sits inside the word she picked');
    });

    test('a shorter choice still matches a longer keyword', () {
      expect(metricMatches(['acne'], ['hormonal acne']), isTrue);
      expect(metricMatches(['pain'], ['back pain']), isTrue);
    });
  });

  group('what she did not pick stays off', () {
    test('a short value does not bleed into an unrelated keyword', () {
      // The bug this rule exists for. Her energy level is stored in the same
      // map, and plain substring matching put the period-flow card on a
      // postpartum home page because "flow" contains "low".
      expect(metricMatches(['low'], ['flow', 'period', 'bleeding']), isFalse);
      expect(metricMatches(['no'], ['conception', 'hormone']), isFalse);
    });

    test('an unrelated symptom does not open the card', () {
      expect(metricMatches(['headache'], ['lochia', 'incision']), isFalse);
    });

    test('nothing chosen matches nothing', () {
      expect(metricMatches([], ['cramps']), isFalse);
      expect(metricMatches(['', '  '], ['cramps']), isFalse);
    });
  });

  group('only answers to questions are eligible', () {
    test('profile fields and check-in state are excluded', () {
      // The stored map is not just the questionnaire: it carries her name, her
      // weight and today's sliders alongside the answers.
      for (final k in const [
        'preferred_name', 'date_of_birth', 'weight', 'life_stage',
        'daily_mood', 'daily_energy', 'baby_birth_date', 'created_at',
      ]) {
        expect(isNonQuestionAnswerKey(k), isTrue, reason: '$k must not gate cards');
      }
    });

    test('the branch questions are eligible', () {
      for (final k in const [
        'ttc_tracking_method', 'postpartum_feeding', 'contraception_choice',
        'hormonal_treatment', 'ttc_treatment',
      ]) {
        expect(isNonQuestionAnswerKey(k), isFalse, reason: '$k is an answer');
      }
    });

    test("her name cannot switch a card on", () {
      // "Forrest" contains "rest". Excluding the key is what stops this, since
      // the match itself would allow it.
      expect(metricMatches(['forrest'], ['rest', 'sleep']), isTrue,
          reason: 'the matcher alone would let this through');
      expect(isNonQuestionAnswerKey('preferred_name'), isTrue,
          reason: 'so the key must never reach the matcher');
    });
  });
}
