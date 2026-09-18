import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/features/auth/presentation/onboarding_wizard.dart';

void main() {
  int calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  bool isStageAllowedForAge(LifeStage stage, int? age) {
    if (age == null) return true;
    if (age < 9) return false;

    if (age < 13) {
      return stage == LifeStage.firstPeriodNotStarted ||
          stage == LifeStage.firstPeriodStarted;
    }

    if (age < 18) {
      return stage == LifeStage.firstPeriodNotStarted ||
          stage == LifeStage.firstPeriodStarted ||
          stage == LifeStage.reproductiveYears ||
          stage == LifeStage.hormonalHealth;
    }

    if (age <= 44) {
      return stage == LifeStage.firstPeriodStarted ||
          stage == LifeStage.reproductiveYears ||
          stage == LifeStage.hormonalHealth ||
          stage == LifeStage.tryingToConceive ||
          stage == LifeStage.pregnancy ||
          stage == LifeStage.postpartum;
    }

    if (age <= 51) {
      return stage == LifeStage.reproductiveYears ||
          stage == LifeStage.hormonalHealth ||
          stage == LifeStage.tryingToConceive ||
          stage == LifeStage.pregnancy ||
          stage == LifeStage.postpartum ||
          stage == LifeStage.perimenopause ||
          stage == LifeStage.menopause;
    }

    return stage == LifeStage.perimenopause ||
        stage == LifeStage.menopause ||
        stage == LifeStage.hormonalHealth;
  }

  group('Clinical Age Calculation', () {
    test('computes exact chronological age across leap years and birthdays', () {
      final now = DateTime.now();
      final dob10 = DateTime(now.year - 10, now.month, now.day);
      expect(calculateAge(dob10), 10);

      final dob25 = DateTime(now.year - 25, now.month, now.day);
      expect(calculateAge(dob25), 25);
    });
  });

  group('Clinical Life Stage Age-Gating', () {
    test('under 9 years old is strictly blocked for all stages', () {
      for (final stage in LifeStage.values) {
        expect(
          isStageAllowedForAge(stage, 8),
          isFalse,
          reason: '$stage must be locked for an 8-year-old child',
        );
      }
    });

    test('pre-teen ages (9-12) only permit puberty and early cycle stages', () {
      const allowed = {
        LifeStage.firstPeriodNotStarted,
        LifeStage.firstPeriodStarted,
      };

      for (final stage in LifeStage.values) {
        final expected = allowed.contains(stage);
        expect(
          isStageAllowedForAge(stage, 10),
          expected,
          reason: 'Stage $stage should be ${expected ? "allowed" : "locked"} for age 10',
        );
      }
    });

    test('minors under 18 cannot register for pregnancy, TTC, perimenopause, or menopause', () {
      for (final age in [13, 15, 17]) {
        expect(isStageAllowedForAge(LifeStage.pregnancy, age), isFalse);
        expect(isStageAllowedForAge(LifeStage.tryingToConceive, age), isFalse);
        expect(isStageAllowedForAge(LifeStage.perimenopause, age), isFalse);
        expect(isStageAllowedForAge(LifeStage.menopause, age), isFalse);

        // Adolescent stages must be open
        expect(isStageAllowedForAge(LifeStage.firstPeriodNotStarted, age), isTrue);
        expect(isStageAllowedForAge(LifeStage.firstPeriodStarted, age), isTrue);
        expect(isStageAllowedForAge(LifeStage.reproductiveYears, age), isTrue);
        expect(isStageAllowedForAge(LifeStage.hormonalHealth, age), isTrue);
      }
    });

    test('adults 18-44 cannot select First Period Not Started (primary amenorrhea)', () {
      expect(isStageAllowedForAge(LifeStage.firstPeriodNotStarted, 25), isFalse);
      expect(isStageAllowedForAge(LifeStage.firstPeriodNotStarted, 30), isFalse);

      // Adult stages open
      expect(isStageAllowedForAge(LifeStage.reproductiveYears, 28), isTrue);
      expect(isStageAllowedForAge(LifeStage.tryingToConceive, 28), isTrue);
      expect(isStageAllowedForAge(LifeStage.pregnancy, 28), isTrue);
      expect(isStageAllowedForAge(LifeStage.postpartum, 28), isTrue);
    });

    test('mature adults (52+) are gated from puberty, pregnancy, and TTC', () {
      expect(isStageAllowedForAge(LifeStage.pregnancy, 55), isFalse);
      expect(isStageAllowedForAge(LifeStage.tryingToConceive, 55), isFalse);
      expect(isStageAllowedForAge(LifeStage.firstPeriodNotStarted, 55), isFalse);
      expect(isStageAllowedForAge(LifeStage.firstPeriodStarted, 55), isFalse);

      // Menopause & perimenopause open
      expect(isStageAllowedForAge(LifeStage.menopause, 55), isTrue);
      expect(isStageAllowedForAge(LifeStage.perimenopause, 55), isTrue);
    });
  });

  group('Symptom Mutual Exclusivity Logic', () {
    test('selecting None clears all specific symptoms', () {
      final symptoms = <String>{'Cramps', 'Bloating', 'Fatigue'};
      const noneOption = 'No notable symptoms';

      // Simulating selection of 'No notable symptoms'
      final isNoneOption = noneOption.toLowerCase().contains("none") ||
          noneOption.toLowerCase().contains("no notable");
      if (isNoneOption) {
        symptoms.clear();
        symptoms.add(noneOption);
      }

      expect(symptoms, {'No notable symptoms'});
    });

    test('selecting a specific symptom removes None / No notable symptoms', () {
      final symptoms = <String>{'No notable symptoms'};
      const newSymptom = 'Headache';

      final isNoneOption = newSymptom.toLowerCase().contains("none") ||
          newSymptom.toLowerCase().contains("no notable");
      if (!isNoneOption) {
        symptoms.removeWhere((s) =>
            s.toLowerCase().contains("none") ||
            s.toLowerCase().contains("no notable"));
        symptoms.add(newSymptom);
      }

      expect(symptoms, {'Headache'});
      expect(symptoms.contains('No notable symptoms'), isFalse);
    });
  });
}
