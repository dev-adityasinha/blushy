import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/services/api_insights_service.dart';
import 'package:blushy_life_app/services/sia_dashboard_service.dart';
import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/home/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Monthly Insights & Verified Green-Tick Milestone Suite', () {
    test('1. Zero-Data State (M-1): 0 green ticks and honest empty state', () {
      final json = {
        "reportingMonth": "2026-07",
        "startDate": "2026-07-01",
        "endDate": "2026-07-31",
        "userTimezone": "America/New_York",
        "timezoneSource": "user_profile",
        "dataState": "no_data",
        "totalDaysInMonth": 31,
        "metrics": {
          "checkinCount": 0,
          "checkinConsistencyPercentage": 0.0,
          "symptomLogCount": 0,
          "moodLogCount": 0,
          "uniqueSymptomsTracked": [],
          "periodDaysInMonth": 0,
          "completedCyclesInMonth": 0,
          "siaConversationsCount": 0
        },
        "milestones": [
          {
            "id": "milestone_checkin_consistency",
            "title": "Consistent Daily Check-ins",
            "description": "Completed 0 of 31 days in July.",
            "sourceField": "user_daily_logs_woman",
            "completionRule": "checkinCount >= 15",
            "isCompleted": false,
            "showGreenTick": false,
            "statusLabel": "0 / 15 days logged"
          },
          {
            "id": "milestone_symptom_tracking",
            "title": "Proactive Symptom Logging",
            "description": "No symptoms recorded for July.",
            "sourceField": "user_daily_logs_woman.symptoms",
            "completionRule": "symptomLogCount >= 1",
            "isCompleted": false,
            "showGreenTick": false,
            "statusLabel": "Not logged in July"
          },
          {
            "id": "milestone_cycle_logging",
            "title": "Cycle Start Tracking",
            "description": "No period start date logged in July.",
            "sourceField": "user_period_logs_woman.period_start_date",
            "completionRule": "periodDaysInMonth >= 1",
            "isCompleted": false,
            "showGreenTick": false,
            "statusLabel": "No cycle logged in July"
          },
          {
            "id": "milestone_sia_engagement",
            "title": "Sia Wellness Conversations",
            "description": "No wellness conversations logged in July.",
            "sourceField": "ai_chat_history_woman",
            "completionRule": "siaConversationsCount >= 3",
            "isCompleted": false,
            "showGreenTick": false,
            "statusLabel": "0 / 3 sessions"
          }
        ],
        "reflection": {
          "headline": "July Monthly Reflection",
          "summaryText": "No check-ins or cycle events were recorded for July.",
          "isPersonalized": false,
          "sampleSize": 0
        },
        "disclaimer": "Descriptive summary only."
      };

      final data = MonthlyInsightsData.fromJson(json);
      expect(data.dataState, equals('no_data'));
      expect(data.metrics.checkinCount, equals(0));

      for (final m in data.milestones) {
        expect(m.isCompleted, isFalse);
        expect(m.showGreenTick, isFalse, reason: 'Zero data must never show green ticks');
      }

      final pc = PersonalContext(
        userName: 'Elena',
        trackingPreference: CycleTrackingPreference.enabled,
        cyclePattern: CyclePattern.predictable,
        confidence: DataConfidence.low,
        lifeContexts: {LifeContext.none},
        userGoals: {'energyBoost'},
        preferences: UserPreferences(),
      );
      final state = BlushyOSState();

      final journey = SiaDashboardService().getMonthlyReflectionAndMilestones(
        pc: pc,
        state: state,
        backendData: data,
      );

      expect(journey.dataState, equals('no_data'));
      expect(journey.milestoneItems.length, equals(4));
      for (final item in journey.milestoneItems) {
        expect(item.showGreenTick, isFalse);
      }
    });

    test('2. Complete Month (M-1): Legitimate green checkmarks for verified items', () {
      final json = {
        "reportingMonth": "2026-07",
        "startDate": "2026-07-01",
        "endDate": "2026-07-31",
        "userTimezone": "America/New_York",
        "timezoneSource": "user_profile",
        "dataState": "sufficient_data",
        "totalDaysInMonth": 31,
        "metrics": {
          "checkinCount": 20,
          "checkinConsistencyPercentage": 64.5,
          "symptomLogCount": 3,
          "moodLogCount": 20,
          "uniqueSymptomsTracked": ["cramps", "bloating"],
          "periodDaysInMonth": 1,
          "completedCyclesInMonth": 1,
          "siaConversationsCount": 4
        },
        "milestones": [
          {
            "id": "milestone_checkin_consistency",
            "title": "Consistent Daily Check-ins",
            "description": "Completed 20 of 31 days in July.",
            "sourceField": "user_daily_logs_woman",
            "completionRule": "checkinCount >= 15",
            "isCompleted": true,
            "showGreenTick": true,
            "statusLabel": "Completed"
          },
          {
            "id": "milestone_symptom_tracking",
            "title": "Proactive Symptom Logging",
            "description": "Logged cramps and bloating in July.",
            "sourceField": "user_daily_logs_woman.symptoms",
            "completionRule": "symptomLogCount >= 1",
            "isCompleted": true,
            "showGreenTick": true,
            "statusLabel": "Completed (3 logs)"
          },
          {
            "id": "milestone_cycle_logging",
            "title": "Cycle Start Tracking",
            "description": "Confirmed period start date logged in July.",
            "sourceField": "user_period_logs_woman.period_start_date",
            "completionRule": "periodDaysInMonth >= 1",
            "isCompleted": true,
            "showGreenTick": true,
            "statusLabel": "Completed"
          },
          {
            "id": "milestone_sia_engagement",
            "title": "Sia Wellness Conversations",
            "description": "Engaged in 4 Sia wellness sessions in July.",
            "sourceField": "ai_chat_history_woman",
            "completionRule": "siaConversationsCount >= 3",
            "isCompleted": true,
            "showGreenTick": true,
            "statusLabel": "Completed"
          }
        ],
        "reflection": {
          "headline": "July Monthly Reflection",
          "summaryText": "In July, you recorded 20 daily check-ins (64.5% consistency).",
          "isPersonalized": true,
          "sampleSize": 20
        },
        "disclaimer": "Descriptive summary only."
      };

      final data = MonthlyInsightsData.fromJson(json);
      expect(data.dataState, equals('sufficient_data'));
      expect(data.metrics.checkinCount, equals(20));

      for (final m in data.milestones) {
        expect(m.isCompleted, isTrue);
        expect(m.showGreenTick, isTrue);
      }
    });

    test('3. Partial Month (M-1): Verified symptoms checked, check-in count unchecked', () {
      final json = {
        "reportingMonth": "2026-07",
        "startDate": "2026-07-01",
        "endDate": "2026-07-31",
        "userTimezone": "America/New_York",
        "timezoneSource": "user_profile",
        "dataState": "learning_state",
        "totalDaysInMonth": 31,
        "metrics": {
          "checkinCount": 6,
          "checkinConsistencyPercentage": 19.4,
          "symptomLogCount": 2,
          "moodLogCount": 6,
          "uniqueSymptomsTracked": ["cramps"],
          "periodDaysInMonth": 0,
          "completedCyclesInMonth": 0,
          "siaConversationsCount": 1
        },
        "milestones": [
          {
            "id": "milestone_checkin_consistency",
            "title": "Consistent Daily Check-ins",
            "description": "Completed 6 of 31 days in July.",
            "sourceField": "user_daily_logs_woman",
            "completionRule": "checkinCount >= 15",
            "isCompleted": false,
            "showGreenTick": false,
            "statusLabel": "6 / 15 days logged"
          },
          {
            "id": "milestone_symptom_tracking",
            "title": "Proactive Symptom Logging",
            "description": "Logged cramps in July.",
            "sourceField": "user_daily_logs_woman.symptoms",
            "completionRule": "symptomLogCount >= 1",
            "isCompleted": true,
            "showGreenTick": true,
            "statusLabel": "Completed (2 logs)"
          },
        ],
        "reflection": {
          "headline": "July Monthly Reflection",
          "summaryText": "In July, you logged 6 check-ins.",
          "isPersonalized": true,
          "sampleSize": 6
        },
        "disclaimer": "Descriptive summary only."
      };

      final data = MonthlyInsightsData.fromJson(json);
      final checkinM = data.milestones.firstWhere((m) => m.id == 'milestone_checkin_consistency');
      final symptomM = data.milestones.firstWhere((m) => m.id == 'milestone_symptom_tracking');

      expect(checkinM.isCompleted, isFalse, reason: '6 < 15 must remain unchecked');
      expect(checkinM.showGreenTick, isFalse);

      expect(symptomM.isCompleted, isTrue, reason: 'Symptom was recorded');
      expect(symptomM.showGreenTick, isTrue);
    });
  });
}
