import 'dart:convert';
import 'dart:io';

import 'package:blushy_life_app/core/onboarding_answers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The health settings page edits three checkbox groups through one save.
///
/// Only conditions was ever sent. Goals and symptoms changed local state,
/// showed the "saved" tick, and were wiped by the next sync, which rebuilds the
/// context from what the server holds — and those two are exactly what the home
/// page gates its cards on, so ticking a symptom appeared to work, changed the
/// cards, and then quietly undid both.
void main() {
  test('the profile sync carries every group the settings page edits', () {
    final source = File('lib/core/state.dart').readAsStringSync();

    // The payload built in updatePersonalContext.
    final start = source.indexOf('final Map<String, dynamic> payload = {');
    expect(start, greaterThan(-1), reason: 'the payload was renamed');
    final payload = source.substring(start, source.indexOf('};', start));

    for (final field in const [
      'medical_conditions',
      'symptoms',
      'goals',
      'medications',
    ]) {
      expect(payload.contains("'$field':"), isTrue,
          reason: '$field is edited in health settings and must be sent');
    }
  });

  group('what the server stores can be read back', () {
    // `saveMyOnboarding` stores a non-string answer as JSON.stringify(value),
    // so a list of symptoms comes back as a string. If the reader could not
    // parse that, the round trip would still lose them.
    test('a stringified list survives', () {
      final answers = <String, dynamic>{
        'symptoms': jsonEncode(['Cramps & Pelvic Pain', 'Fatigue & Low Energy']),
        'goals': jsonEncode(['Improve sleep quality & rest']),
      };

      expect(OnboardingAnswers.symptoms(answers),
          containsAll(['Cramps & Pelvic Pain', 'Fatigue & Low Energy']));
      expect(OnboardingAnswers.goals(answers),
          contains('Improve sleep quality & rest'));
    });

    test('a real list survives too', () {
      final answers = <String, dynamic>{
        'symptoms': ['Acne & Skin Breakouts'],
        'goals': ['Boost energy & reduce fatigue'],
      };

      expect(OnboardingAnswers.symptoms(answers), contains('Acne & Skin Breakouts'));
      expect(OnboardingAnswers.goals(answers), contains('Boost energy & reduce fatigue'));
    });

    test('unticking everything reads back as empty, not as stale', () {
      final answers = <String, dynamic>{'symptoms': jsonEncode(<String>[]), 'goals': '[]'};

      expect(OnboardingAnswers.symptoms(answers), isEmpty);
      expect(OnboardingAnswers.goals(answers), isEmpty);
    });
  });

  test('a ticked symptom can switch a home page card on', () {
    // The point of saving them. The dashboard gates on these words, so a
    // symptom that survives the round trip has to match a card keyword.
    final dashboard = File(
      'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart',
    ).readAsStringSync();

    final answers = <String, dynamic>{
      'symptoms': jsonEncode(['Cramps & Pelvic Pain']),
    };
    final restored = OnboardingAnswers.symptoms(answers).first.toLowerCase();

    expect(dashboard.contains("'cramps'"), isTrue,
        reason: 'the dashboard must gate something on cramps');
    expect(restored.contains('cramps'), isTrue,
        reason: 'and the restored answer must contain that word');
  });

  test('the memory preference is sent and read back', () {
    final source = File('lib/core/state.dart').readAsStringSync();

    final start = source.indexOf('final Map<String, dynamic> payload = {');
    final payload = source.substring(start, source.indexOf('};', start));
    expect(payload.contains("'sia_memory_enabled':"), isTrue,
        reason: 'a privacy control has to reach where the data is processed');

    // And the synced value must actually be used, not set into a local that
    // the rebuilt context then ignores.
    expect(source.contains('preferences: preferences,'), isTrue,
        reason: 'reading the field back would discard the synced choice');
  });
}
