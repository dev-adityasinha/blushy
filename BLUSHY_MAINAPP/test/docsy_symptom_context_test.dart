import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Docsy was told about a day she could not see.
///
/// Her side: the symptom sheet writes `daily_checkin.json` and posts to the
/// server, but it never touched `BlushyOSState` -- and `wellbeingState.symptoms`
/// is exactly what the chat screen hands over as `context['symptoms']`. State
/// is hydrated from the backend at startup, so what she logged five seconds
/// before asking about it was the one thing missing from the question.
///
/// His side: `getRelationshipAdvice` gathered mood, sleep and cycle phase and
/// stopped there. Symptoms are a real grant (`log.symptoms`) with their own
/// visible-symptom allowlist, and none of it reached the model -- so the thing
/// a partner most often asks about was the thing Docsy had no sight of.
void main() {
  String read(String p) => File(p).readAsStringSync();

  String stripComments(String source) => source
      .split(String.fromCharCode(10))
      .where((line) => !line.trimLeft().startsWith('//'))
      .join(String.fromCharCode(10));

  group('her side', () {
    test('the sheet updates app state, not only storage', () {
      final sheet = read('lib/features/home/widgets/log_symptoms_section.dart');
      final write = sheet.lastIndexOf("BlushyStorage.write('daily_checkin.json', checkin);");
      expect(write, greaterThan(-1));

      final after = sheet.substring(write, write + 900);
      expect(after, contains('updateWellbeing(symptoms: logged)'),
          reason: 'what she logged never reached wellbeingState');
    });

    test('everything she picked counts, not just the symptom group', () {
      final sheet = stripComments(read('lib/features/home/widgets/log_symptoms_section.dart'));
      expect(sheet, contains('for (final labels in byMetric.values) ...labels'));
    });

    test('and the chat reads today\'s sheet before falling back to state', () {
      final screen = read('lib/features/sia/sia_screen.dart');
      expect(screen, contains("'symptoms': _loggedToday().isNotEmpty"));
      expect(screen, contains('List<String> _loggedToday()'));
      expect(screen, contains("BlushyStorage.read('daily_checkin.json')"));
    });
  });

  group('his side', () {
    late final String controller;

    setUpAll(() {
      controller = stripComments(
        read('backend/src/controllers/aiController.js'),
      );
    });

    test('relationship advice now carries her logged symptoms', () {
      final start = controller.indexOf('export async function getRelationshipAdvice');
      expect(start, greaterThan(-1));
      final body = controller.substring(start, start + 6000);

      expect(body, contains('sharedSymptoms'));
      expect(body, contains('Symptoms they have logged in the last week:'));
    });

    test('read through the permission-filtered context, not queried raw', () {
      // getPartnerSafeContext is where the log.symptoms grant and the
      // visible-symptom allowlist are applied. Querying health events here
      // would have bypassed both.
      expect(controller, contains('partnerSafeService.getPartnerSafeContext(connectionId, viewerUserId)'));
      expect(controller.contains("eventTypes: ['symptom_logged']"), isFalse,
          reason: 'that would read past her switches');
    });

    test('and only when she allows AI insights at all', () {
      final start = controller.indexOf('let sharedSymptoms = [];');
      expect(start, greaterThan(-1));
      expect(controller.substring(start, start + 120), contains('if (aiAllowed)'));
    });

    test('a failure to load them does not lose the answer', () {
      final start = controller.indexOf('let sharedSymptoms = [];');
      final body = controller.substring(start, start + 700);
      expect(body, contains('catch (error)'));
    });
  });
}
