import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';

import 'package:blushy_life_app/models/blushy_models.dart';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/shared/api_state_card.dart';

/// Client-side tests for the response contract and the card states
/// (spec section 27 and section 4).

void main() {
  group('ApiResult states', () {
    test('distinguishes empty from insufficient data', () {
      const empty = ApiResult<List<Insight>>(data: [], state: ApiState.empty);
      const insufficient = ApiResult<List<Insight>>(data: [], state: ApiState.insufficientData);

      expect(empty.isInsufficientData, isFalse);
      expect(insufficient.isInsufficientData, isTrue);
      expect(insufficient.isReady, isFalse);
    });

    test('restricted is not an error', () {
      const restricted = ApiResult<String>(state: ApiState.restricted, errorCode: 'PERMISSION_RESTRICTED');
      expect(restricted.isRestricted, isTrue);
      expect(restricted.isError, isFalse);
    });

    test('flags AI-sourced values so the UI can label them', () {
      const fromAi = ApiResult<String>(data: 'x', state: ApiState.ready, source: 'ai');
      const fromRule = ApiResult<String>(data: 'x', state: ApiState.ready, source: 'rule');
      expect(fromAi.isAiGenerated, isTrue);
      expect(fromRule.isAiGenerated, isFalse);
    });
  });

  group('Model parsing', () {
    test('CycleState keeps the calculation version and never infers pregnancy', () {
      final cycle = CycleState.fromJson({
        'lifeStage': 'cycle_tracking',
        'cycleTrackingAvailable': true,
        'hasData': true,
        'trackingState': 'sufficient_data',
        'currentCycle': {'currentCycleDay': 14, 'phase': 'Luteal Phase', 'isOverdue': false},
        'prediction': {
          'nextPeriodStartDate': '2026-06-01',
          'predictionRange': {'earliestDate': '2026-05-30', 'latestDate': '2026-06-03'},
          'daysUntilNextPeriod': 14,
          'disclaimer': 'Predictions are estimates.',
        },
        'dataSufficiency': {'confidenceLevel': 'higher_confidence', 'displayLabel': 'Higher confidence'},
        'calculationVersion': 'v2.0-canonical-ssot',
        'pregnancyInferred': false,
      });

      expect(cycle.currentCycleDay, 14);
      expect(cycle.hasPrediction, isTrue);
      expect(cycle.predictionEarliest, '2026-05-30');
      expect(cycle.calculationVersion, 'v2.0-canonical-ssot');
      expect(cycle.disclaimer, isNotNull);
    });

    test('CycleState surfaces an overdue cycle instead of hiding it', () {
      // The dashboard used to compute `daysSinceStart % cycleLength + 1`, which
      // turned a 34-day-late period into "Cycle Day 6". The server sends the
      // real day plus an explicit overdue state, and the model keeps both.
      final cycle = CycleState.fromJson({
        'lifeStage': 'cycle_tracking',
        'cycleTrackingAvailable': true,
        'hasData': true,
        'currentCycle': {
          'currentCycleDay': 62,
          'phase': 'Late / Overdue Cycle (+34 days)',
          'isOverdue': true,
          'daysOverdue': 34,
        },
        'prediction': {
          'nextPeriodStartDate': null,
          'estimatedOvulationDate': null,
          'fertileWindowStart': null,
          'fertileWindowEnd': null,
        },
        'dataSufficiency': {'confidenceLevel': 'higher_confidence'},
        'lateNotice': 'Your period is later than your logged pattern suggests.',
        'pregnancyInferred': false,
      });

      expect(cycle.currentCycleDay, 62);
      expect(cycle.isOverdue, isTrue);
      expect(cycle.daysOverdue, 34);
      // No forward prediction is offered while overdue.
      expect(cycle.hasPrediction, isFalse);
      expect(cycle.estimatedOvulationDate, isNull);
      expect(cycle.lateNotice, isNotNull);
    });

    test('CycleState withholds predictions when history is thin', () {
      final cycle = CycleState.fromJson({
        'cycleTrackingAvailable': true,
        'hasData': true,
        'trackingState': 'learning_initial',
        'currentCycle': {'currentCycleDay': 4, 'phase': 'Menstrual Phase'},
        'prediction': {'nextPeriodStartDate': null, 'estimatedOvulationDate': null},
        'dataSufficiency': {
          'confidenceLevel': 'low',
          'message': 'Estimated ovulation based on 28-day baseline.',
        },
      });

      expect(cycle.currentCycleDay, 4);
      expect(cycle.hasPrediction, isFalse);
      expect(cycle.confidenceLevel, 'low');
      expect(cycle.sufficiencyMessage, isNotNull);
    });

    test('CycleState handles the restricted menopause shape', () {
      final cycle = CycleState.fromJson({
        'lifeStage': 'menopause',
        'cycleTrackingAvailable': false,
        'reason': 'menopause_uses_wellness_history',
        'message': 'Your history is shown as wellness history.',
      });

      expect(cycle.cycleTrackingAvailable, isFalse);
      expect(cycle.restrictedReason, 'menopause_uses_wellness_history');
      expect(cycle.currentCycleDay, isNull);
    });

    test('Insight carries its evidence and version', () {
      final insight = Insight.fromJson({
        'id': 'i1',
        'type': 'sleep_mood',
        'title': 'Sleep and mood',
        'description': 'Based on your recent logs...',
        'sourceEventIds': ['e1', 'e2'],
        'confidence': 0.72,
        'strength': 'strong',
        'engineVersion': 'patterns-v1.0.0',
        'source': 'rule',
      });

      expect(insight.sourceEventIds, hasLength(2));
      expect(insight.confidence, 0.72);
      expect(insight.engineVersion, 'patterns-v1.0.0');
      expect(insight.isObservationOnly, isTrue);
    });

    test('HealthEvent marks AI-derived logs as not user confirmed', () {
      final event = HealthEvent.fromJson({
        'eventId': 'e1',
        'eventType': 'mood_logged',
        'timestamp': '2026-05-10T09:00:00.000Z',
        'source': 'ai_derived',
        'userConfirmed': false,
        'payload': {'mood': 'low'},
      });

      expect(event.isAiDerived, isTrue);
      expect(event.userConfirmed, isFalse);
    });

    test('HomeScreenModel orders modules and exposes them by id', () {
      final home = HomeScreenModel.fromJson({
        'lifeStage': 'cycle_tracking',
        'capabilities': {'cycleLanguage': true},
        'onboardingRequired': false,
        'safetyActive': false,
        'modules': [
          {'moduleId': 'patterns', 'order': 5, 'state': 'insufficient_data'},
          {'moduleId': 'greeting', 'order': 0, 'state': 'ready', 'data': {'preferredName': 'Ada'}},
          {'moduleId': 'hero_tracker', 'order': 3, 'state': 'empty'},
        ],
      });

      expect(home.modules.map((m) => m.moduleId).toList(), ['greeting', 'hero_tracker', 'patterns']);
      expect(home.module('patterns')!.isInsufficientData, isTrue);
      expect(home.module('greeting')!.asMap['preferredName'], 'Ada');
      expect(home.module('missing'), isNull);
    });

    test('PartnerSharingState reports what is currently shared', () {
      final sharing = PartnerSharingState.fromJson({
        'connectionId': 'c1',
        'connectionState': 'accepted',
        'permissions': [
          {'key': 'energy', 'label': 'Energy', 'enabled': true, 'alwaysOn': false},
          {'key': 'mood', 'label': 'Mood', 'enabled': false, 'alwaysOn': false},
          {'key': 'care_requests', 'label': 'Care requests', 'enabled': true, 'alwaysOn': true},
        ],
      });

      expect(sharing.isActive, isTrue);
      expect(sharing.enabled.map((p) => p.key), containsAll(['energy', 'care_requests']));
      expect(sharing.enabled.map((p) => p.key), isNot(contains('mood')));
    });

    test('Timeline distinguishes menopause wellness history', () {
      final timeline = Timeline.fromJson({
        'entries': [
          {'eventId': 'e1', 'eventType': 'hot_flash_logged', 'date': '2026-05-10T09:00:00.000Z', 'displayText': 'Hot flash 6/10'},
        ],
        'historyType': 'wellness_and_symptoms',
        'pagination': {'total': 1, 'hasMore': false},
      });

      expect(timeline.usesCycleHistory, isFalse);
      expect(timeline.entries.single.displayText, 'Hot flash 6/10');
    });

    test('SafetyFlow reads the emergency escalation shape', () {
      final flow = SafetyFlow.fromJson({
        'level': 'emergency',
        'suppressWellnessContent': true,
        'steps': [
          {
            'ruleId': 'rf_pg_heavy_bleeding',
            'title': 'Bleeding during pregnancy',
            'instruction': 'Contact your maternity unit now.',
            'level': 'emergency',
            'source': 'NICE NG121',
            'reviewer': 'Blushy Clinical Review Board',
          },
        ],
        'emergencyResources': {
          'region': 'IN',
          'emergencyNumber': '112',
          'resources': [
            {'id': 'in_emergency', 'name': 'National Emergency Number', 'contact': '112', 'type': 'emergency'},
          ],
        },
      });

      expect(flow.isEmergency, isTrue);
      expect(flow.suppressWellnessContent, isTrue);
      expect(flow.steps.single.instruction, isNotEmpty);
      expect(flow.steps.single.source, isNotNull);
      expect(flow.emergencyNumber, '112');
      expect(flow.resources, hasLength(1));
    });

    test('ScreeningResult is never a diagnosis', () {
      final result = ScreeningResult.fromJson({
        'screeningId': 's1',
        'instrumentId': 'EPDS',
        'instrumentName': 'Edinburgh Postnatal Depression Scale',
        'instrumentVersion': '1987.1',
        'totalScore': 15,
        'maxScore': 30,
        'outcome': 'concerning',
        'requiresProfessionalSupport': true,
      });

      expect(result.isDiagnosis, isFalse);
      expect(result.requiresProfessionalSupport, isTrue);
      expect(result.instrumentVersion, '1987.1');
    });

    test('LibraryItem exposes clinical provenance', () {
      final item = LibraryItem.fromJson({
        'contentId': 'mc_test',
        'title': 'Title',
        'body': 'Body',
        'source': 'NICE NG23',
        'version': '1.0.0',
        'progress': {'progressPercent': 40, 'completed': false, 'bookmarked': true},
      });

      expect(item.hasClinicalProvenance, isTrue);
      expect(item.progressPercent, 40);
      expect(item.bookmarked, isTrue);
    });
  });

  group('ApiStateCard', () {
    Future<void> pumpWith(WidgetTester tester, ApiResult<String> result) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ApiStateCard<String>(
              result: result,
              emptyMessage: 'Nothing logged yet.',
              insufficientDataMessage: 'Keep logging to see this.',
              restrictedMessage: 'This has not been shared with you.',
              builder: (context, data) => Text(data),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the value when ready', (tester) async {
      await pumpWith(tester, const ApiResult(data: 'Cycle day 14', state: ApiState.ready));
      expect(find.text('Cycle day 14'), findsOneWidget);
    });

    testWidgets('empty and insufficient data read differently', (tester) async {
      await pumpWith(tester, const ApiResult(state: ApiState.empty));
      expect(find.text('Nothing logged yet.'), findsOneWidget);

      await pumpWith(tester, const ApiResult(state: ApiState.insufficientData));
      expect(find.text('Keep logging to see this.'), findsOneWidget);
      expect(find.text('Nothing logged yet.'), findsNothing);
    });

    testWidgets('restricted says the data exists but is not shared', (tester) async {
      await pumpWith(tester, const ApiResult(state: ApiState.restricted));
      expect(find.text('This has not been shared with you.'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('an error offers a retry without hiding the card', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ApiStateCard<String>(
              result: const ApiResult(state: ApiState.error, errorMessage: 'Could not load.'),
              onRetry: () async => retried = true,
              builder: (context, data) => Text(data),
            ),
          ),
        ),
      );

      expect(find.text('Could not load.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('offline shows the last known value with a banner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ApiStateCard<String>(
              result: const ApiResult(state: ApiState.offline),
              cachedData: 'Cycle day 12',
              builder: (context, data) => Text(data),
            ),
          ),
        ),
      );

      expect(find.text('Cycle day 12'), findsOneWidget);
      // The banner says the server could not be reached rather than blaming
      // the user's connection: the usual cause is a backend the app cannot
      // route to, which is not the same thing as being offline.
      expect(find.textContaining('Not connected'), findsOneWidget);
    });

    testWidgets('loading shows a skeleton, not an empty state', (tester) async {
      await pumpWith(tester, const ApiResult.loading());
      expect(find.text('Nothing logged yet.'), findsNothing);
      expect(find.byType(FractionallySizedBox), findsWidgets);
    });
  });

  group('SourceLabel', () {
    testWidgets('names where a value came from', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SourceLabel(source: 'rule'))),
      );
      expect(find.text('Calculated from your logs'), findsOneWidget);
    });

    testWidgets('renders nothing for an unknown source', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SourceLabel(source: 'mystery'))),
      );
      expect(find.byType(Text), findsNothing);
    });
  });
}
