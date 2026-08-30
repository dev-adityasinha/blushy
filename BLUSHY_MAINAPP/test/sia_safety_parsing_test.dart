import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/models/blushy_models.dart';

/// The chat endpoint attaches a `safety` block when a deterministic red flag
/// rule fires. These pin the shape the Sia screen relies on to decide whether
/// a reply is a generated chat message or clinically reviewed guidance.

Map<String, dynamic> _escalationResponse() => {
      'message': 'You deserve support right now. Please contact your local emergency number.',
      'model': 'safety-ruleset:redflag-v1.0.0',
      'aiGenerated': false,
      'safety': {
        'triggered': true,
        'level': 'emergency',
        'suppressWellnessContent': true,
        'steps': [
          {
            'ruleId': 'rf_mh_self_harm',
            'title': 'Thoughts of self-harm',
            'instruction': 'You deserve support right now. Please contact your local emergency number.',
            'level': 'emergency',
            'source': 'WHO mhGAP intervention guide',
            'reviewer': 'Blushy Clinical Review Board',
          },
        ],
        'emergencyResources': {
          'region': 'IN',
          'emergencyNumber': '112',
          'resources': [
            {'id': 'in_emergency', 'name': 'National Emergency Number', 'contact': '112', 'type': 'emergency'},
            {'id': 'in_mental_health', 'name': 'Tele-MANAS', 'contact': '14416', 'type': 'mental_health'},
          ],
        },
      },
    };

void main() {
  group('escalation response', () {
    test('is marked as not AI generated', () {
      final data = _escalationResponse();
      expect(data['aiGenerated'], isFalse);
      expect(data['model'].toString().startsWith('safety-ruleset'), isTrue);
    });

    test('parses into a suppressing safety flow', () {
      final flow = SafetyFlow.fromJson(_escalationResponse()['safety']);
      expect(flow.triggered, isTrue);
      expect(flow.isEmergency, isTrue);
      expect(flow.suppressWellnessContent, isTrue);
      expect(flow.steps, hasLength(1));
    });

    test('carries the reviewed instruction, its source and the local resources', () {
      final flow = SafetyFlow.fromJson(_escalationResponse()['safety']);
      final step = flow.steps.single;

      expect(step.title, 'Thoughts of self-harm');
      expect(step.instruction, isNotEmpty);
      // Guidance must state where it came from.
      expect(step.source, 'WHO mhGAP intervention guide');
      expect(step.reviewer, isNotNull);

      expect(flow.emergencyNumber, '112');
      expect(flow.resources, hasLength(2));
      expect(flow.resources.map((r) => r.contact), containsAll(['112', '14416']));
    });

    test('the displayed message is the reviewed instruction, not a paraphrase', () {
      final data = _escalationResponse();
      final flow = SafetyFlow.fromJson(data['safety']);
      expect(data['message'], flow.steps.single.instruction);
    });
  });

  group('non-suppressing flag', () {
    test('is shown alongside the reply rather than replacing it', () {
      final flow = SafetyFlow.fromJson({
        'triggered': true,
        'level': 'contact_provider',
        'suppressWellnessContent': false,
        'steps': [
          {
            'ruleId': 'rf_gyn_prolonged_bleeding',
            'title': 'Prolonged or very heavy bleeding',
            'instruction': 'Bleeding that is unusually heavy should be reviewed by a clinician.',
            'level': 'contact_provider',
            'source': 'NICE NG88 heavy menstrual bleeding',
          },
        ],
        'emergencyResources': {'region': 'GB', 'emergencyNumber': '999', 'resources': []},
      });

      expect(flow.triggered, isTrue);
      expect(flow.isEmergency, isFalse);
      // The chat reply still stands; the banner is additional.
      expect(flow.suppressWellnessContent, isFalse);
    });
  });

  group('ordinary reply', () {
    test('has no safety block at all', () {
      final data = {'message': 'Here are some ideas for steady energy.', 'aiGenerated': true, 'safety': null};
      expect(data['safety'], isNull);
      expect(data['aiGenerated'], isTrue);
    });
  });
}
