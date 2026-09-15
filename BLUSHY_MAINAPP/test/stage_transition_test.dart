import 'dart:convert';

import 'package:blushy_life_app/features/home/stage_transition.dart';
import 'package:blushy_life_app/services/api_blushy_service.dart';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/isolated_storage.dart';

/// A stage change the server refuses reaches the app with its reasons.
///
/// The server answers a refused transition with `state: "error"`, an
/// `errorCode` and, in `data`, which stage she is in, whether a
/// confirmation would do and what context is missing. The client parsed
/// that `data` as the requested payload and dropped the rest, so every
/// refusal looked the same to the screen.
void main() {
  useIsolatedStorage();

  setUp(() {
    AuthStorage.saveSession(token: 't', userId: 'u', email: 'a@b.c', role: 'woman', onboardingCompleted: true);
  });
  tearDown(() => ApiContractClient.clientOverride = null);

  http.Response refusal(int status, String code, Map<String, dynamic> data) => http.Response(
        jsonEncode({
          'data': data,
          'state': 'error',
          'lastUpdated': '2026-09-05T00:00:00.000Z',
          'source': 'rule',
          'version': 'life-stage-v1',
          'permissions': null,
          'errorCode': code,
        }),
        status,
        headers: {'content-type': 'application/json'},
      );

  group('refused transitions keep their reasons', () {
    test('confirmation required is readable', () async {
      ApiContractClient.clientOverride = MockClient((req) async => refusal(409, 'CONFIRMATION_REQUIRED', {
            'fromStage': 'ttc',
            'toStage': 'pregnancy',
            'requiresConfirmation': true,
            'missingContext': null,
            'reason': 'pregnancy_confirmed',
          }));
      final r = await LifeStageApi.transition(toStage: 'pregnancy');
      expect(r.isReady, isFalse);
      expect(r.errorCode, 'CONFIRMATION_REQUIRED');
      expect(r.meta?['requiresConfirmation'], isTrue);
      expect(r.meta?['fromStage'], 'ttc');
    });

    test('missing context names what is missing', () async {
      ApiContractClient.clientOverride = MockClient((req) async => refusal(422, 'MISSING_BRANCH_CONTEXT', {
            'fromStage': 'pregnancy',
            'toStage': 'postpartum',
            'requiresConfirmation': false,
            'missingContext': ['baby_birth_date'],
          }));
      final r = await LifeStageApi.transition(toStage: 'postpartum', confirmed: true);
      expect(r.errorCode, 'MISSING_BRANCH_CONTEXT');
      expect(r.meta?['missingContext'], ['baby_birth_date']);
    });

    test('not allowed is not a parse failure', () async {
      ApiContractClient.clientOverride = MockClient((req) async => refusal(409, 'TRANSITION_NOT_ALLOWED', {
            'fromStage': 'pregnancy',
            'toStage': 'perimenopause',
            'requiresConfirmation': false,
          }));
      final r = await LifeStageApi.transition(toStage: 'perimenopause');
      expect(r.errorCode, 'TRANSITION_NOT_ALLOWED');
      expect(r.errorCode, isNot('PARSE_FAILED'));
    });

    test('a successful change still parses the stage', () async {
      ApiContractClient.clientOverride = MockClient((req) async => http.Response(
            jsonEncode({
              'data': {
                'stage': {'lifeStage': 'pregnancy', 'branchContext': {'due_date': '2027-03-01'}},
                'transition': {'from': 'ttc', 'to': 'pregnancy'},
              },
              'state': 'ready',
              'version': 'life-stage-v1',
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final r = await LifeStageApi.transition(toStage: 'pregnancy', confirmed: true, context: {'due_date': '2027-03-01'});
      expect(r.isReady, isTrue);
      expect(r.data?.lifeStage, 'pregnancy');
    });

    test('the context she gave is sent with the change', () async {
      Map<String, dynamic>? sent;
      ApiContractClient.clientOverride = MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return refusal(409, 'TRANSITION_NOT_ALLOWED', {});
      });
      await LifeStageApi.transition(toStage: 'postpartum', confirmed: true, context: {'baby_birth_date': '2026-09-01'});
      expect(sent?['context'], {'baby_birth_date': '2026-09-01'});
      expect(sent?['confirmed'], isTrue);
    });
  });

  group('context from the questionnaire', () {
    test('pregnancy sends the due date', () {
      expect(branchContextFromAnswers('pregnancy', {'due_date': '2027-03-01', 'pregnancy_first': 'Yes'}),
          {'due_date': '2027-03-01'});
    });

    test('postpartum sends the birth date', () {
      expect(branchContextFromAnswers('postpartum', {'baby_birth_date': '2026-09-01', 'postpartum_feeding': 'Pumping'}),
          {'baby_birth_date': '2026-09-01'});
    });

    test('other stages send nothing, and no answers is no context', () {
      expect(branchContextFromAnswers('tryingToConceive', {'ttc_duration': 'Under 6 months'}), isEmpty);
      expect(branchContextFromAnswers('pregnancy', null), isEmpty);
    });

    test('saved answers are found under stage_answers or the stage key', () {
      expect(savedStageAnswers({'stage_answers': {'pregnancy': {'due_date': 'x'}}}, 'pregnancy'), {'due_date': 'x'});
      expect(savedStageAnswers({'pregnancy': {'due_date': 'y'}}, 'pregnancy'), {'due_date': 'y'});
      expect(savedStageAnswers({}, 'pregnancy'), isNull);
    });
  });

  group('what she is told', () {
    test('a path that does not exist names both stages', () {
      final m = transitionRefusalMessage('TRANSITION_NOT_ALLOWED', {'fromStage': 'pregnancy'}, 'Perimenopause');
      expect(m, contains('Pregnancy'));
      expect(m, contains('Perimenopause'));
    });

    test('missing context says which date', () {
      expect(transitionRefusalMessage('MISSING_BRANCH_CONTEXT', {'missingContext': ['baby_birth_date']}, 'Postpartum'),
          contains('birth date'));
      expect(transitionRefusalMessage('MISSING_BRANCH_CONTEXT', {'missingContext': ['due_date']}, 'Pregnancy'),
          contains('due date'));
    });

    test('anything else keeps the plain message', () {
      expect(transitionRefusalMessage('SOMETHING_ELSE', null, 'Pregnancy'), 'That change could not be saved.');
    });
  });
}
