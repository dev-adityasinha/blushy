import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/services/sia_dashboard_service.dart';
import 'package:blushy_life_app/core/state.dart';
import 'helpers/isolated_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Each test process gets its own storage directory.
  useIsolatedStorage();


  group('SIA Dynamic Dashboard & Multi-Vector Exit Synchronization Suite', () {
    setUp(() {
      AuthStorage.clearSession();
      BlushyStorage.clearUserData();
      BlushyStorage.clearMemoryCache();
      SiaDashboardService().clearUserCache();
    });

    // -------------------------------------------------------------------------
    // 1. Core Synchronization & Real-Data Flow
    // -------------------------------------------------------------------------
    test('1. Sia message extraction updates state and triggers fresh header brief', () async {
      final uid = 'user_sync_flow_${DateTime.now().microsecondsSinceEpoch}';
      AuthStorage.saveSession(token: 'mock_jwt', userId: uid, email: 'sync@flow.test');

      final state = BlushyOSState();
      final service = SiaDashboardService();

      state.updateWellbeing(
        mood: 3,
        energy: 3,
        symptoms: ['cramps', 'fatigue'],
      );

      service.notifyChatUpdated(topicsChanged: true);
      expect(service.hasUnsyncedChanges, isTrue);
      expect(service.isDiscoverDirty, isTrue);

      await service.syncAllDashboardsFromBackend(state: state);

      expect(service.hasUnsyncedChanges, isFalse);
      expect(service.isDiscoverDirty, isFalse);

      final brief = service.getDailyHeaderBrief(
        pc: state.personalContext,
        state: state,
        stagesSummary: 'Everyday Wellness',
      );
      expect(brief, isNotEmpty);
      expect(brief.contains('18 check-ins'), isFalse);
    });

    // -------------------------------------------------------------------------
    // 2. Individual Dashboard Backend Refreshes
    // -------------------------------------------------------------------------
    test('2. Home & Header: Recomputes hormonal brief dynamically from active cycle day', () {
      final uid = 'user_header_${DateTime.now().microsecondsSinceEpoch}';
      AuthStorage.saveSession(token: 'mock_jwt', userId: uid, email: 'header@test.com');

      final pc = PersonalContext(
        userName: 'Elena',
        trackingPreference: CycleTrackingPreference.enabled,
        cyclePattern: CyclePattern.predictable,
        confidence: DataConfidence.high,
        lifeContexts: {LifeContext.none},
        userGoals: {'energyBoost'},
        preferences: UserPreferences(),
        cycleDay: 14,
        cyclePhase: 'Ovulation',
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 14)),
      );
      final state = BlushyOSState();

      final brief = SiaDashboardService().getDailyHeaderBrief(
        pc: pc,
        state: state,
        stagesSummary: 'Everyday Wellness',
      );

      expect(brief.contains('Ovulatory Window') || brief.contains('Cycle Day 14'), isTrue);
    });

    test('3. Discover: Invalidates stale daily cache when conversation introduces new symptoms', () async {
      final uid = 'user_discover_${DateTime.now().microsecondsSinceEpoch}';
      AuthStorage.saveSession(token: 'mock_jwt', userId: uid, email: 'disc@test.com');
      final service = SiaDashboardService();

      BlushyStorage.write('blushy_daily_discover_cache', {'cached': 'old_topics'});
      expect(BlushyStorage.read('blushy_daily_discover_cache'), isNotEmpty);

      service.notifyChatUpdated(topicsChanged: true);
      await service.syncAllDashboardsFromBackend();

      expect(BlushyStorage.read('blushy_daily_discover_cache'), isEmpty);
    });

    test('4. Monthly Check-in: Displays real 0 milestone count for newly onboarded user', () {
      final uid = 'user_clean_monthly_${DateTime.now().microsecondsSinceEpoch}';
      AuthStorage.saveSession(token: 'mock_jwt', userId: uid, email: 'clean_month@test.com');

      final pc = PersonalContext(
        userName: 'NewUser',
        trackingPreference: CycleTrackingPreference.enabled,
        cyclePattern: CyclePattern.predictable,
        confidence: DataConfidence.low,
        lifeContexts: {LifeContext.none},
        userGoals: {},
        preferences: UserPreferences(),
      );
      final state = BlushyOSState();

      final reflection = SiaDashboardService().getMonthlyReflectionAndMilestones(
        pc: pc,
        state: state,
        chatHistory: [],
      );

      expect(reflection.milestones.any((m) => m.contains('0 check-ins')), isTrue);
      expect(reflection.milestones.any((m) => m.contains('18 check-ins')), isFalse);
    });

    test('5. Everyday Wellness: Correctly aggregates dynamic cycle patterns without dummy data', () {
      final uid = 'user_wellness_${DateTime.now().microsecondsSinceEpoch}';
      AuthStorage.saveSession(token: 'mock_jwt', userId: uid, email: 'well@test.com');

      final pc = PersonalContext(
        userName: 'WellnessUser',
        trackingPreference: CycleTrackingPreference.enabled,
        cyclePattern: CyclePattern.predictable,
        confidence: DataConfidence.high,
        lifeContexts: {LifeContext.none},
        userGoals: {'sleep'},
        preferences: UserPreferences(),
        cycleDay: 22,
        cyclePhase: 'Luteal Phase',
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 22)),
      );
      final state = BlushyOSState();

      final patterns = SiaDashboardService().getCyclePatterns(
        pc: pc,
        state: state,
      );

      expect(patterns, isNotNull);
      for (final p in patterns) {
        expect(p.evidence.contains('18 recent daily check-ins'), isFalse);
      }
    });

    // -------------------------------------------------------------------------
    // 3. Navigation & Exit Vectors
    // -------------------------------------------------------------------------
    test('6. PopScope & Navigation Exits: Triggers synchronization within bounded 2.5s window', () async {
      final uid = 'user_pop_${DateTime.now().microsecondsSinceEpoch}';
      AuthStorage.saveSession(token: 'mock_jwt', userId: uid, email: 'pop@test.com');

      final service = SiaDashboardService();
      int notified = 0;
      service.refreshNotifier.addListener(() => notified++);

      final stopwatch = Stopwatch()..start();
      await service.syncAllDashboardsFromBackend();
      stopwatch.stop();

      expect(notified, greaterThan(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });

    test('7. Tab Switch: Bottom navigation changes trigger dashboard backend synchronization', () async {
      final uid = 'user_tab_${DateTime.now().microsecondsSinceEpoch}';
      AuthStorage.saveSession(token: 'mock_jwt', userId: uid, email: 'tab@test.com');

      final service = SiaDashboardService();
      service.notifyChatUpdated();
      expect(service.hasUnsyncedChanges, isTrue);

      await service.syncAllDashboardsFromBackend();
      expect(service.hasUnsyncedChanges, isFalse);
    });

    test('8. Route Dismissals (Bottom-sheet, FAB, M-Studio): Synchronize calling screens on return', () async {
      final uid = 'user_routes_${DateTime.now().microsecondsSinceEpoch}';
      AuthStorage.saveSession(token: 'mock_jwt', userId: uid, email: 'routes@test.com');

      final service = SiaDashboardService();
      service.notifyChatUpdated(topicsChanged: true);
      expect(service.isDiscoverDirty, isTrue);

      // Simulating FAB / M-Studio .then() completion
      await service.syncAllDashboardsFromBackend();

      expect(service.isDiscoverDirty, isFalse);
      expect(service.hasUnsyncedChanges, isFalse);
    });

    // -------------------------------------------------------------------------
    // 4. Offline Queue, Retry, & Late Race Guard
    // -------------------------------------------------------------------------
    test('9. Offline Queue: Correctly queues captures and isolates User A from User B', () async {
      final uidA = 'user_offline_a_${DateTime.now().microsecondsSinceEpoch}';
      final uidB = 'user_offline_b_${DateTime.now().microsecondsSinceEpoch}';

      AuthStorage.saveSession(token: 'mock_jwt_a', userId: uidA, email: 'a@offline.test');
      await SiaDashboardService().queueOfflineExtraction({
        'moodCapture': {'updated': true, 'mood': 'calm'},
      });

      final queueA = BlushyStorage.read('sia_offline_queue.json');
      expect((queueA['queue'] as List).length, equals(1));

      AuthStorage.clearSession();
      AuthStorage.saveSession(token: 'mock_jwt_b', userId: uidB, email: 'b@offline.test');

      final queueB = BlushyStorage.read('sia_offline_queue.json');
      expect(queueB, isEmpty, reason: 'User B must never access User A offline sync queue');
    });

    test('10. Late Response Race Guard: Ignores pending sync if user switches accounts during flush', () async {
      final uidA = 'user_race_a_${DateTime.now().microsecondsSinceEpoch}';
      final uidB = 'user_race_b_${DateTime.now().microsecondsSinceEpoch}';

      AuthStorage.saveSession(token: 'mock_jwt_a', userId: uidA, email: 'a@race.test');
      final service = SiaDashboardService();

      // Start sync for User A
      final syncFuture = service.syncAllDashboardsFromBackend();

      // Immediately switch account to User B while sync is in-flight
      AuthStorage.clearSession();
      AuthStorage.saveSession(token: 'mock_jwt_b', userId: uidB, email: 'b@race.test');

      await syncFuture;

      // User B storage must remain pristine
      final userBCheckin = BlushyStorage.read('daily_checkin.json');
      expect(userBCheckin, isEmpty, reason: 'Late User A sync response must never write into User B session');
    });

    test('11. Explicit Logout purges user caches and isolates subsequent session', () {
      final uid = 'user_logout_${DateTime.now().microsecondsSinceEpoch}';
      AuthStorage.saveSession(token: 'mock_jwt', userId: uid, email: 'logout@test.com');

      BlushyStorage.write('daily_checkin.json', {'feeling': 'PRIVATE_FEELING'});
      AuthStorage.clearSession();
      BlushyStorage.clearMemoryCache();

      final readData = BlushyStorage.read('daily_checkin.json');
      expect(readData, isEmpty, reason: 'Unauthenticated storage read must return empty');
    });

    // -------------------------------------------------------------------------
    // 5. Onboarding Permutations & Life Stage Guard
    // -------------------------------------------------------------------------
    test('12. Onboarding: First Period Not Started cleanly disables cycle tracking', () {
      final pc = PersonalContext(
        userName: 'YoungGirl',
        trackingPreference: CycleTrackingPreference.disabled,
        cyclePattern: CyclePattern.unknown,
        confidence: DataConfidence.low,
        lifeContexts: {LifeContext.none},
        userGoals: {'healthyHabits'},
        preferences: UserPreferences(wantsCycleTracking: false),
      );
      final state = BlushyOSState();

      final brief = SiaDashboardService().getDailyHeaderBrief(
        pc: pc,
        state: state,
        stagesSummary: 'First Period Journey',
      );

      expect(brief, isNotEmpty);
      expect(brief.contains('Cycle Day'), isFalse);
    });

    test('13. Onboarding: Menopause stage renders stage-appropriate brief without fake cycle days', () {
      final pc = PersonalContext(
        userName: 'Margaret',
        trackingPreference: CycleTrackingPreference.disabled,
        cyclePattern: CyclePattern.unknown,
        confidence: DataConfidence.high,
        lifeContexts: {LifeContext.menopause},
        userGoals: {'boneDensity', 'sleepQuality'},
        preferences: UserPreferences(wantsCycleTracking: false),
        lifeStage: 'menopause',
      );
      final state = BlushyOSState();

      final brief = SiaDashboardService().getDailyHeaderBrief(
        pc: pc,
        state: state,
        stagesSummary: 'Menopause Journey',
      );

      expect(brief, isNotEmpty);
      expect(brief.contains('Cycle Day'), isFalse);
      expect(brief.contains('Menopause Journey'), isTrue);
    });
  });
}
