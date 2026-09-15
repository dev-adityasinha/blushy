import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/models/blushy_models.dart';

/// The partner-safe read model (spec sections 19 to 21).
///
/// The partner app renders whatever survived the server-side permission
/// filter. These pin that an empty result is a designed state rather than an
/// error, and that nothing unpermitted arrives to be rendered by mistake.

Map<String, dynamic> _home({
  bool relationshipActive = true,
  List<Map<String, dynamic>> sections = const [],
  List<Map<String, dynamic>> requests = const [],
  Map<String, dynamic> permitted = const {},
  List<String> grants = const [],
}) {
  return {
    'greeting': {'prompt': 'How can I show up today?', 'partnerPreferredName': 'Ada'},
    'lifeStageContext': 'cycle_tracking',
    'permittedContext': permitted,
    'allowedGrants': grants,
    'supportRequests': requests,
    'sharedSections': sections,
    'nothingShared': sections.every((s) => (s['items'] as List).isEmpty),
    'relationshipActive': relationshipActive,
  };
}

void main() {
  group('nothing shared', () {
    test('is a populated, usable model rather than an error', () {
      final home = PartnerHomeModel.fromJson(_home());

      expect(home.relationshipActive, isTrue);
      expect(home.nothingShared, isTrue);
      expect(home.sharedSections, isEmpty);
      // Partner Home still works with nothing shared (spec section 25).
      expect(home.prompt, 'How can I show up today?');
      expect(home.partnerPreferredName, 'Ada');
    });

    test('carries no permitted context when nothing is granted', () {
      final home = PartnerHomeModel.fromJson(_home());
      expect(home.allowedGrants, isEmpty);
      expect(home.permittedContext['mood'], isNull);
      expect(home.permittedContext['symptoms'], isNull);
      expect(home.permittedContext['journalEntries'], isNull);
    });
  });

  group('granted context', () {
    test('exposes only what the server sent', () {
      final home = PartnerHomeModel.fromJson(_home(
        permitted: {
          'partnerPreferredName': 'Ada',
          'lifeStage': 'cycle_tracking',
          'energyLevel': {'value': 2, 'scale': '1_5'},
        },
        grants: ['log.energy'],
      ));

      expect(home.allowedGrants, contains('log.energy'));
      expect(home.permittedContext['energyLevel']['value'], 2);
      // Anything not granted simply is not present to render.
      expect(home.permittedContext['mood'], isNull);
      expect(home.permittedContext['cyclePhase'], isNull);
    });

    test('reads populated shared sections', () {
      final home = PartnerHomeModel.fromJson(_home(sections: [
        {
          'key': 'cycle_context',
          'enabled': true,
          'items': [
            {'phase': 'Luteal Phase', 'cycleDay': 21}
          ],
        },
        {'key': 'appointments', 'enabled': false, 'items': []},
      ]));

      expect(home.sharedSections, hasLength(2));

      final cycle = home.sharedSections.firstWhere((s) => s.key == 'cycle_context');
      expect(cycle.enabled, isTrue);
      expect(cycle.items.single['phase'], 'Luteal Phase');

      final appointments = home.sharedSections.firstWhere((s) => s.key == 'appointments');
      expect(appointments.enabled, isFalse);
      expect(appointments.items, isEmpty);
    });
  });

  group('ended relationship', () {
    test('reports inactive so the partner is told access has gone', () {
      final home = PartnerHomeModel.fromJson(_home(relationshipActive: false));
      expect(home.relationshipActive, isFalse);
    });
  });

  group('care requests', () {
    test('carry the request and nothing about her health', () {
      final home = PartnerHomeModel.fromJson(_home(requests: [
        {
          'requestId': 'r1',
          'type': 'rest',
          'label': 'I need rest',
          'message': 'Some quiet time would really help right now.',
          'state': 'pending',
          'createdAt': '2026-08-29T09:00:00.000Z',
        },
      ]));

      final request = home.supportRequests.single;
      expect(request.type, 'rest');
      expect(request.label, 'I need rest');
      expect(request.isPending, isTrue);
      expect(request.isActionable, isTrue);

      // The partner projection has no requester id and no health fields.
      final serialized = request.toString();
      expect(serialized.contains('symptom'), isFalse);
      expect(serialized.contains('cycle'), isFalse);
    });

    test('a completed request is no longer actionable', () {
      final request = SupportRequest.fromJson({
        'requestId': 'r2',
        'type': 'comfort',
        'message': 'A hug would help.',
        'state': 'completed',
      });

      expect(request.isPending, isFalse);
      expect(request.isActionable, isFalse);
    });

    test('an acknowledged request is still actionable, so it can be completed', () {
      final request = SupportRequest.fromJson({
        'requestId': 'r3',
        'type': 'company',
        'message': 'I would like some company.',
        'state': 'acknowledged',
      });

      expect(request.isPending, isFalse);
      expect(request.isActionable, isTrue);
    });
  });
}
