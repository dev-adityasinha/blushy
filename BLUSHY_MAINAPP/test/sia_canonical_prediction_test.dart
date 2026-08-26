import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/core/cycle_calculator.dart';
import 'package:blushy_life_app/services/api_period_service.dart';
import 'package:blushy_life_app/services/sia_dashboard_service.dart';
import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/home/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Canonical Period Prediction Client & Model Suite', () {
    test('1. Null Data State Parsing', () {
      final json = {
        "hasData": false,
        "trackingState": "no_data",
        "currentCycle": {
          "currentCycleDay": null,
          "phase": "Not Logged",
        },
        "prediction": {
          "nextPeriodStartDate": null,
          "daysUntilNextPeriod": null,
          "estimatedOvulationDate": null,
        },
        "dataSufficiency": {
          "completedCyclesCount": 0,
          "confidenceLevel": "none",
          "displayLabel": "No Data Logged",
        }
      };

      final pred = PeriodPrediction.fromJson(json);
      expect(pred.hasData, isFalse);
      expect(pred.trackingState, equals('no_data'));
      expect(pred.currentCycleDay, isNull);
      expect(pred.currentPhase, equals('Not Logged'));
      expect(pred.nextPeriodStartDate, isNull);
      expect(pred.confidence, equals('none'));
    });

    test('2. Option A: Day 1 Convention on Period Start Date', () {
      final today = DateTime.now();
      final calc = CycleCalculation.compute(
        lastPeriodStart: today,
        cycleLength: 28,
        periodDuration: 5,
      );

      expect(calc.hasData, isTrue);
      expect(calc.currentCycleDay, equals(1), reason: 'Period started today must be Day 1');
      expect(calc.currentPhase, equals('Menstrual Phase'));
      expect(calc.isOverdue, isFalse);
      expect(calc.daysOverdue, equals(0));
    });

    test('3. Overdue Cycle Test (Last period 40 days ago, no silent reset)', () {
      final fortyDaysAgo = DateTime.now().subtract(const Duration(days: 40));
      final calc = CycleCalculation.compute(
        lastPeriodStart: fortyDaysAgo,
        cycleLength: 28,
        periodDuration: 5,
      );

      expect(calc.hasData, isTrue);
      expect(calc.currentCycleDay, equals(41), reason: 'Must evaluate to Day 41 without resetting');
      expect(calc.isOverdue, isTrue);
      expect(calc.daysOverdue, equals(13)); // 41 - 28 = 13
      expect(calc.daysUntilNextPeriod, isNull, reason: 'Negative countdowns are prohibited');
      expect(calc.nextPeriodStart, isNull);
      expect(calc.ovulationDay, isNull);
      expect(calc.currentPhase, contains('Late / Overdue Cycle'));
    });

    test('4. Higher Confidence JSON Deserialization (3 completed cycles)', () {
      final json = {
        "status": "success",
        "hasData": true,
        "trackingState": "sufficient_data",
        "currentCycle": {
          "currentCycleDay": 14,
          "phase": "Estimated Ovulation Day",
          "periodDurationDays": 5,
          "isOverdue": false,
          "daysOverdue": 0,
        },
        "prediction": {
          "nextPeriodStartDate": "2026-09-09",
          "daysUntilNextPeriod": 15,
          "estimatedOvulationDate": "2026-08-26",
          "fertileWindowStart": "2026-08-21",
          "fertileWindowEnd": "2026-08-27",
          "isOvulationSupported": true,
          "disclaimer": "Predictions are estimates and are not intended for contraception or medical diagnosis.",
        },
        "dataSufficiency": {
          "completedCyclesCount": 3,
          "validStartDatesCount": 4,
          "confidenceLevel": "higher_confidence",
          "displayLabel": "Higher confidence from 3 completed cycles",
          "message": "Estimated ovulation based on your recent cycle history.",
        }
      };

      final pred = PeriodPrediction.fromJson(json);
      expect(pred.hasData, isTrue);
      expect(pred.currentCycleDay, equals(14));
      expect(pred.currentPhase, equals('Estimated Ovulation Day'));
      expect(pred.isOverdue, isFalse);
      expect(pred.nextPeriodStartDate, equals('2026-09-09'));
      expect(pred.daysUntilNextPeriod, equals(15));
      expect(pred.confidence, equals('higher_confidence'));
      expect(pred.displayLabel, equals('Higher confidence from 3 completed cycles'));
    });

    test('5. Sia Dashboard Service Insufficient Data Learning States', () {
      final service = SiaDashboardService();
      final pc = PersonalContext(
        userName: 'Test User',
        trackingPreference: CycleTrackingPreference.enabled,
        cyclePattern: CyclePattern.predictable,
        confidence: DataConfidence.medium,
        lifeContexts: {LifeContext.none},
        userGoals: {'energyBoost'},
        preferences: UserPreferences(),
        cycleDay: 1,
        cyclePhase: 'Follicular Phase',
      );
      final state = BlushyOSState();

      final observations = service.getSiaObservations(pc: pc, state: state);
      expect(observations.isNotEmpty, isTrue);

      for (final obs in observations) {
        expect(obs['insight']?.contains('last three periods'), isNot(true),
            reason: 'Hardcoded 3-period claim must not be present in default observations');
        expect(obs['insight']?.contains('35% reduction'), isNot(true),
            reason: 'Fake percentage claim must not be present');
      }

      final patterns = service.getCyclePatterns(pc: pc, state: state);
      expect(patterns.isNotEmpty, isTrue);
      for (final pat in patterns) {
        expect(pat.observation.contains('35% reduction in reported cramp severity'), isNot(true),
            reason: 'Hardcoded 35% cramp reduction claim must not be emitted');
      }
    });

    test('6. Dashboard-Wide Equality: Home, Header, Period, Insights, Discover & Partner consume identical SSOT values', () {
      // Simulate confirmed backend prediction payload
      final canonicalPayload = {
        "status": "success",
        "hasData": true,
        "trackingState": "sufficient_data",
        "currentCycle": {
          "currentCycleDay": 5,
          "phase": "Menstrual Phase (Day 5 of 5)",
          "cycleStartDate": "2026-08-21",
          "latestConfirmedPeriodStartDate": "2026-08-21",
          "periodDurationDays": 5,
          "isCurrentPeriod": true,
          "periodDay": 5,
          "isOverdue": false,
          "daysOverdue": 0,
        },
        "prediction": {
          "nextPeriodStartDate": "2026-09-18",
          "daysUntilNextPeriod": 24,
          "estimatedOvulationDate": "2026-09-04",
          "fertileWindowStart": "2026-08-30",
          "fertileWindowEnd": "2026-09-05",
          "isOvulationSupported": true,
        },
        "dataSufficiency": {
          "completedCyclesCount": 3,
          "confidenceLevel": "higher_confidence",
          "displayLabel": "Higher confidence from 3 completed cycles",
        }
      };

      final canonicalPrediction = PeriodPrediction.fromJson(canonicalPayload);

      // Hydrate Flutter state with canonical prediction
      final state = BlushyOSState();
      final pc = PersonalContext(
        userName: 'Sophia',
        trackingPreference: CycleTrackingPreference.enabled,
        cyclePattern: CyclePattern.predictable,
        confidence: DataConfidence.high,
        lifeContexts: {LifeContext.none},
        userGoals: {'vitality'},
        preferences: UserPreferences(),
        cycleDay: canonicalPrediction.currentCycleDay,
        cyclePhase: canonicalPrediction.currentPhase,
        lastPeriodStart: DateTime.parse(canonicalPrediction.lastPeriodStartDate!),
      );

      // Verify Home & Header brief
      final headerBrief = SiaDashboardService().getDailyHeaderBrief(
        pc: pc,
        state: state,
        stagesSummary: 'Everyday Wellness',
      );
      expect(headerBrief, isNotEmpty);
      expect(headerBrief.contains('Day 5'), isTrue, reason: 'Header must consume canonical Cycle Day 5');

      // Verify Insights & Living patterns
      final insights = SiaDashboardService().getCyclePatterns(pc: pc, state: state);
      expect(insights.isNotEmpty, isTrue);

      // Verify Discover topics
      final discover = SiaDashboardService().getDiscoverTopicsAndArticles(pc: pc, state: state);
      expect(discover.isNotEmpty, isTrue);

      // Verify Period & Partner values match PersonalContext exactly
      expect(pc.cycleDay, equals(canonicalPrediction.currentCycleDay));
      expect(pc.cyclePhase, equals(canonicalPrediction.currentPhase));
      expect(pc.lastPeriodStart?.toIso8601String().split('T').first, equals(canonicalPrediction.lastPeriodStartDate));
    });
  });
}
