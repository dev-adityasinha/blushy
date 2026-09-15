import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/core/onboarding_answers.dart';

/// Onboarding answers must be read whichever flow recorded them.
///
/// Measured against the live database: 21 women have a `goals` list, while 32
/// have `selected_goals` plus a set of `goal_*` booleans. The home page read
/// only the first shape, so the larger group's goals were collected, stored,
/// and then ignored — which is what "onboarding questions aren't used to
/// optimise home pages" looks like from the outside.
void main() {
  group('goals', () {
    test('reads a plain list', () {
      expect(
        OnboardingAnswers.goals({'goals': ['track_period', 'manage_weight']}),
        {'track_period', 'manage_weight'},
      );
    });

    test('reads the yes/no shape the other flow actually writes', () {
      // The real shape, taken from the live database: these are the strings
      // "yes" and "no", not booleans. Checking for `true` matched none of the
      // 53 stored "yes" values.
      final answers = <String, dynamic>{
        'goal_track_period': 'yes',
        'goal_get_pregnant': 'yes',
        'goal_manage_weight': 'no',
        'goal_already_pregnant': 'no',
      };

      expect(OnboardingAnswers.goals(answers), {'track_period', 'get_pregnant'});
    });

    test('reads selected_goals as the comma-separated string it is stored as', () {
      // Stored as one line, not a list. Treated as a single answer it becomes
      // one nonsense goal containing every choice.
      final answers = <String, dynamic>{
        'selected_goals': 'get_pregnant,track_period,charge_well_being',
      };

      expect(
        OnboardingAnswers.goals(answers),
        {'get_pregnant', 'track_period', 'charge_well_being'},
      );
    });

    test('booleans are still honoured where a flow wrote real ones', () {
      expect(
        OnboardingAnswers.goals({'goal_track_period': true, 'goal_manage_weight': false}),
        {'track_period'},
      );
    });

    test('a row carrying both shapes keeps every choice', () {
      // Dropping either half loses a goal the user actually picked, so both
      // are read rather than taking the first that matches.
      final answers = <String, dynamic>{
        'goals': ['manage_weight'],
        'goal_track_period': true,
      };

      expect(OnboardingAnswers.goals(answers), {'manage_weight', 'track_period'});
    });

    test('reads a JSON-encoded list, which some rows store', () {
      expect(
        OnboardingAnswers.goals({'goals': '["track_period","nutrition"]'}),
        {'track_period', 'nutrition'},
      );
    });

    test('a bare string is one answer, not malformed JSON', () {
      expect(OnboardingAnswers.goals({'goals': 'track_period'}), {'track_period'});
    });

    test('a negative answer is not a goal, in either spelling', () {
      expect(OnboardingAnswers.goals({'goal_manage_weight': false}), isEmpty);
      expect(OnboardingAnswers.goals({'goal_manage_weight': 'no'}), isEmpty);
    });

    test('missing and null answers are empty, not an error', () {
      expect(OnboardingAnswers.goals(null), isEmpty);
      expect(OnboardingAnswers.goals(<String, dynamic>{}), isEmpty);
      expect(OnboardingAnswers.goals({'goals': null}), isEmpty);
    });
  });

  group('symptoms and conditions', () {
    test('symptoms are read across the onboarding and check-in spellings', () {
      expect(
        OnboardingAnswers.symptoms({'period_pms_symptoms': ['cramps', 'fatigue']}),
        {'cramps', 'fatigue'},
      );
      expect(
        OnboardingAnswers.symptoms({'checkin_symptoms': ['bloating']}),
        {'bloating'},
      );
    });

    test('conditions accept every stored spelling', () {
      expect(OnboardingAnswers.conditions({'medical_conditions': ['pcos']}), {'pcos'});
      expect(OnboardingAnswers.conditions({'diagnosed_conditions': ['endometriosis']}),
          {'endometriosis'});
    });
  });
}
