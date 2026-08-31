import 'package:flutter/foundation.dart';
import '../core/storage.dart';
import '../core/state.dart';
import '../features/home/models.dart';
import 'auth_storage.dart';
import 'api_auth_service.dart';
import 'api_insights_service.dart';
import 'api_community_service.dart';

class SiaDashboardObservation {
  final String insight;
  final String explanation;
  final String? category;

  SiaDashboardObservation({
    required this.insight,
    required this.explanation,
    this.category,
  });

  Map<String, String> toMap() => {
    'insight': insight,
    'explanation': explanation,
  };
}

class SiaMonthlyReflectionData {
  final List<String> milestones;
  final List<MilestoneItem> milestoneItems;
  final String reflection;
  final String dataState;
  final String reportingMonth;
  final int checkinCount;

  SiaMonthlyReflectionData({
    required this.milestones,
    this.milestoneItems = const [],
    required this.reflection,
    this.dataState = 'no_data',
    this.reportingMonth = '',
    this.checkinCount = 0,
  });
}

class SiaDashboardService {
  static final SiaDashboardService _instance = SiaDashboardService._internal();
  factory SiaDashboardService() => _instance;
  SiaDashboardService._internal();

  final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  bool hasUnsyncedChanges = false;
  bool isDiscoverDirty = false;

  // Cached dynamic datasets scoped by authenticated user ID
  String? _cachedUserId;
  List<SiaDashboardObservation>? _cachedObservations;
  List<CycleInsight>? _cachedPatterns;
  Map<String, List<Map<String, String>>>? _cachedDiscoverArticles;
  SiaMonthlyReflectionData? _cachedMonthlyReflection;
  MonthlyInsightsData? _cachedMonthlyInsightsData;
  String? _cachedDailyHeaderBrief;

  void _validateUserCache() {
    final currentUid = AuthStorage.getUserId();
    if (_cachedUserId != currentUid) {
      clearUserCache();
      _cachedUserId = currentUid;
    }
  }

  void clearUserCache() {
    ApiCommunityService().clearCache();
    _cachedObservations = null;
    _cachedPatterns = null;
    _cachedDiscoverArticles = null;
    _cachedMonthlyReflection = null;
    _cachedMonthlyInsightsData = null;
    _cachedDailyHeaderBrief = null;
    hasUnsyncedChanges = false;
    isDiscoverDirty = false;
    refreshNotifier.value++;
  }

  void markDashboardDirty() {
    ApiCommunityService().clearCache();
    hasUnsyncedChanges = true;
    isDiscoverDirty = true;
    _cachedObservations = null;
    _cachedPatterns = null;
    _cachedDiscoverArticles = null;
    _cachedMonthlyReflection = null;
    _cachedDailyHeaderBrief = null;
    refreshNotifier.value++;
  }

  void triggerRefresh() {
    refreshNotifier.value++;
  }

  void notifyChatUpdated({bool topicsChanged = false}) {
    _validateUserCache();
    hasUnsyncedChanges = true;
    if (topicsChanged) {
      isDiscoverDirty = true;
    }
    refreshNotifier.value++;
  }

  Future<void> queueOfflineExtraction(Map<String, dynamic> extraction) async {
    final queue = Map<String, dynamic>.from(BlushyStorage.read('sia_offline_queue.json'));
    final list = List<dynamic>.from(queue['queue'] ?? []);
    list.add(extraction);
    queue['queue'] = list;
    BlushyStorage.write('sia_offline_queue.json', queue);
    markDashboardDirty();
  }

  Future<void> syncAllDashboardsFromBackend({BlushyOSState? state}) async {
    _validateUserCache();
    final currentUid = AuthStorage.getUserId();
    if (currentUid == null || currentUid.isEmpty) {
      clearUserCache();
      return;
    }

    try {
      if (isDiscoverDirty) {
        BlushyStorage.write('blushy_daily_discover_cache', {});
      }

      final authService = ApiAuthService();
      final userData = await authService.fetchUserData();
      final freshProfile = userData['profile'] as Map<String, dynamic>?;

      final activeUid = AuthStorage.getUserId();
      if (activeUid != currentUid) {
        return;
      }

      if (freshProfile != null && freshProfile.isNotEmpty) {
        BlushyStorage.write('user_profile.json', freshProfile);
      }

      // Fetch fresh monthly insights from backend
      try {
        final freshInsights = await ApiInsightsService().getMonthlyInsights();
        if (freshInsights != null && AuthStorage.getUserId() == currentUid) {
          _cachedMonthlyInsightsData = freshInsights;
        }
      } catch (_) {}

      _cachedObservations = null;
      _cachedPatterns = null;
      _cachedDiscoverArticles = null;
      _cachedMonthlyReflection = null;
      _cachedDailyHeaderBrief = null;
      hasUnsyncedChanges = false;
      isDiscoverDirty = false;

      refreshNotifier.value++;
    } catch (_) {}
  }

  List<String> _extractChatContext(List<Map<String, String>> chatHistory) {
    final List<String> topics = [];
    for (final msg in chatHistory) {
      final text = (msg['content'] ?? msg['text'] ?? '').toLowerCase();
      if (text.contains('cramp') || text.contains('pain')) topics.add('cramps');
      if (text.contains('tired') || text.contains('fatigue') || text.contains('sleep') || text.contains('exhausted')) topics.add('sleep');
      if (text.contains('anxious') || text.contains('stress') || text.contains('mood') || text.contains('sad')) topics.add('mood');
      if (text.contains('bloat') || text.contains('digestion')) topics.add('bloating');
      if (text.contains('headache') || text.contains('migraine')) topics.add('headache');
    }
    return topics;
  }

  List<Map<String, String>> getSiaObservations({
    required PersonalContext pc,
    required BlushyOSState state,
    List<Map<String, String>> chatHistory = const [],
  }) {
    _validateUserCache();
    if (_cachedObservations != null) {
      return _cachedObservations!.map((o) => o.toMap()).toList();
    }

    final int cycleDay = pc.cycleDay ?? 0;
    final String phase = pc.cyclePhase ?? 'Not Logged';
    final topics = _extractChatContext(chatHistory);
    final feeling = (BlushyStorage.read('daily_checkin.json')['feeling'] ?? (BlushyStorage.read('logged_feeling.json')['feeling']))?.toString();

    final List<SiaDashboardObservation> list = [];

    if (topics.contains('cramps')) {
      list.add(SiaDashboardObservation(
        insight: "Mild cramping noted during your conversations.",
        explanation: "Gentle heat therapy, magnesium-rich foods, and restorative pacing can help comfort uterine muscles.",
        category: "Symptoms",
      ));
    }

    if (topics.contains('sleep') || (feeling != null && feeling.toLowerCase().contains('tired'))) {
      list.add(SiaDashboardObservation(
        insight: "Energy dips observed in recent logs.",
        explanation: "Progesterone fluctuations can heighten fatigue. Aim for consistent sleep hygiene and steady hydration.",
        category: "Energy",
      ));
    }

    if (topics.contains('mood') || (feeling != null && feeling.toLowerCase().contains('anxious'))) {
      list.add(SiaDashboardObservation(
        insight: "Emotional sensitivity noted in your recent reflections.",
        explanation: "Hormonal transitions often heighten emotional depth. Mindful breathing and supportive pacing can provide balance.",
        category: "Mood",
      ));
    }

    if (phase.toLowerCase().contains('menstru')) {
      list.add(SiaDashboardObservation(
        insight: "Menstrual Phase active (Cycle Day $cycleDay).",
        explanation: "Your body is shedding the uterine lining. Prioritize restorative rest, warm fluids, and iron-rich nutrition.",
        category: "Cycle",
      ));
    } else if (phase.toLowerCase().contains('follicular')) {
      list.add(SiaDashboardObservation(
        insight: "Follicular Phase active (Cycle Day $cycleDay).",
        explanation: "Rising estrogen supports sharper cognitive focus and physical endurance. Great time for creative planning.",
        category: "Cycle",
      ));
    } else if (phase.toLowerCase().contains('ovulat')) {
      list.add(SiaDashboardObservation(
        insight: "Ovulatory Phase window (Cycle Day $cycleDay).",
        explanation: "Peak estrogen and LH surge enhance social communication, confidence, and natural vitality.",
        category: "Cycle",
      ));
    } else if (phase.toLowerCase().contains('luteal')) {
      list.add(SiaDashboardObservation(
        insight: "Luteal Phase active (Cycle Day $cycleDay).",
        explanation: "Progesterone dominance guides you inward. Complex carbohydrates, magnesium, and calm evenings support equilibrium.",
        category: "Cycle",
      ));
    }

    if (list.isEmpty) {
      list.add(SiaDashboardObservation(
        insight: "Dr. Docsy is continuously learning your wellness rhythm.",
        explanation: "Daily check-ins, symptom logs, and chats help build your authentic personalized health pattern.",
        category: "General",
      ));
    }

    _cachedObservations = list;
    return list.map((o) => o.toMap()).toList();
  }

  List<CycleInsight> getCyclePatterns({
    required PersonalContext pc,
    required BlushyOSState state,
    List<Map<String, String>> chatHistory = const [],
  }) {
    _validateUserCache();
    if (_cachedPatterns != null) {
      return _cachedPatterns!;
    }

    final topics = _extractChatContext(chatHistory);
    final List<CycleInsight> patterns = [];

    if (topics.contains('cramps')) {
      patterns.add(CycleInsight(
        title: "Cramp Correlation",
        observation: "Cramping reported during early cycle phases. Restorative heat therapy showed positive association with comfort.",
        evidence: "Consider magnesium glycinate and warm herbal teas.",
        confidenceLevel: "Medium",
        timestamp: DateTime.now().toIso8601String(),
      ));
    }

    if (topics.contains('sleep')) {
      patterns.add(CycleInsight(
        title: "Sleep Trend",
        observation: "Increased sleep latency reported during luteal transition.",
        evidence: "Wind down 30 minutes earlier with screen-free reading.",
        confidenceLevel: "Medium",
        timestamp: DateTime.now().toIso8601String(),
      ));
    }

    if (patterns.isEmpty) {
      patterns.add(CycleInsight(
        title: "Cycle Baseline",
        observation: "Cycle data is currently aggregating. Keep logging your daily feelings to uncover authentic trends.",
        evidence: "Complete your quick daily check-in each morning.",
        confidenceLevel: "Medium",
        timestamp: DateTime.now().toIso8601String(),
      ));
    }

    _cachedPatterns = patterns;
    return patterns;
  }

  Map<String, List<Map<String, String>>> getDiscoverTopicsAndArticles({
    required PersonalContext pc,
    required BlushyOSState state,
    List<Map<String, String>> chatHistory = const [],
  }) {
    _validateUserCache();
    if (_cachedDiscoverArticles != null) {
      return _cachedDiscoverArticles!;
    }

    final topics = _extractChatContext(chatHistory);
    final String phase = pc.cyclePhase ?? 'General';

    final Map<String, List<Map<String, String>>> map = {
      'Topics': [
        {'title': 'Cycle Phase Nutrition', 'tag': phase},
        if (topics.contains('cramps')) {'title': 'Natural Cramp Relief', 'tag': 'Symptoms'},
        if (topics.contains('sleep')) {'title': 'Sleep & Hormones', 'tag': 'Rest'},
        {'title': 'Emotional Pacing', 'tag': 'Mindfulness'},
      ],
      'Articles': [
        {
          'title': 'Hormonal Alignment Guide',
          'readTime': '4 min read',
          'description': 'How nutrition and restorative movement harmonize with your active cycle phase.',
        },
        if (topics.contains('cramps'))
          {
            'title': 'Gentle Cramp Management',
            'readTime': '3 min read',
            'description': 'Clinical perspectives on heat therapy, hydration, and pelvic relaxation.',
          },
      ]
    };

    _cachedDiscoverArticles = map;
    return map;
  }

  /// 4. MONTHLY REFLECTION & JOURNEY (Connected to authentic backend M-1 aggregation)
  SiaMonthlyReflectionData getMonthlyReflectionAndMilestones({
    required PersonalContext pc,
    required BlushyOSState state,
    List<Map<String, String>> chatHistory = const [],
    MonthlyInsightsData? backendData,
  }) {
    _validateUserCache();
    if (backendData != null) {
      final List<String> stringMilestones = backendData.milestones
          .map((m) => "${m.title}: ${m.description}")
          .toList();

      final data = SiaMonthlyReflectionData(
        milestones: stringMilestones,
        milestoneItems: backendData.milestones,
        reflection: backendData.reflection.summaryText,
        dataState: backendData.dataState,
        reportingMonth: backendData.reportingMonth,
        checkinCount: backendData.metrics.checkinCount,
      );
      _cachedMonthlyReflection = data;
      return data;
    }

    if (_cachedMonthlyReflection != null) {
      return _cachedMonthlyReflection!;
    }

    if (_cachedMonthlyInsightsData != null) {
      return getMonthlyReflectionAndMilestones(
        pc: pc,
        state: state,
        chatHistory: chatHistory,
        backendData: _cachedMonthlyInsightsData,
      );
    }

    // Truthful zero/learning fallback when offline or awaiting initial sync
    final int checkinCount = _getRecentCheckinCount();
    final List<MilestoneItem> items = [
      MilestoneItem(
        id: 'milestone_checkin_consistency',
        title: 'Consistent Daily Check-ins',
        description: checkinCount > 0 ? 'Recorded $checkinCount check-in${checkinCount == 1 ? '' : 's'}.' : 'No check-ins recorded for previous month.',
        sourceField: 'user_daily_logs_woman',
        completionRule: 'checkinCount >= 15',
        isCompleted: checkinCount >= 15,
        showGreenTick: checkinCount >= 15,
        statusLabel: checkinCount >= 15 ? 'Completed' : '$checkinCount / 15 days logged',
      ),
      MilestoneItem(
        id: 'milestone_symptom_tracking',
        title: 'Proactive Symptom Logging',
        description: 'Track symptoms during daily check-ins.',
        sourceField: 'user_daily_logs_woman.symptoms',
        completionRule: 'symptomLogCount >= 1',
        isCompleted: false,
        showGreenTick: false,
        statusLabel: 'Not logged',
      ),
      MilestoneItem(
        id: 'milestone_cycle_logging',
        title: 'Cycle Start Tracking',
        description: 'Log confirmed period start dates.',
        sourceField: 'user_period_logs_woman.period_start_date',
        completionRule: 'periodDaysInMonth >= 1',
        isCompleted: pc.lastPeriodStart != null,
        showGreenTick: pc.lastPeriodStart != null,
        statusLabel: pc.lastPeriodStart != null ? 'Completed' : 'No cycle logged',
      ),
      MilestoneItem(
        id: 'milestone_sia_engagement',
        title: 'Dr. Docsy Wellness Conversations',
        description: 'Engage with Dr. Docsy for personalized wellness guidance.',
        sourceField: 'ai_chat_history_woman',
        completionRule: 'siaConversationsCount >= 3',
        isCompleted: false,
        showGreenTick: false,
        statusLabel: '0 / 3 sessions',
      ),
    ];

    final List<String> milestones = [
      pc.lastPeriodStart != null ? "Your cycle established a steady rhythm." : "No cycle logged.",
      "You completed $checkinCount check-ins.",
      "Dr. Docsy wellness conversations logged.",
      "Tracked wellness feelings and symptoms.",
    ];
    final String reflection = checkinCount >= 15
        ? "\"You completed $checkinCount daily check-ins last month. Your steady logging provides clear visibility into your wellness rhythm.\""
        : "\"Daily check-ins and cycle logs from completed months will appear here in your verified monthly reflection.\"";

    final data = SiaMonthlyReflectionData(
      milestones: milestones,
      milestoneItems: items,
      reflection: reflection,
      dataState: checkinCount == 0 ? 'no_data' : 'learning_state',
      checkinCount: checkinCount,
    );
    _cachedMonthlyReflection = data;
    return data;
  }

  /// 5. DASHBOARD DAILY HEADER BRIEF (Dynamic summary below name updated daily)
  String getDailyHeaderBrief({
    required PersonalContext pc,
    required BlushyOSState state,
    required String stagesSummary,
    List<Map<String, String>> chatHistory = const [],
  }) {
    _validateUserCache();
    if (_cachedDailyHeaderBrief != null && _cachedDailyHeaderBrief!.isNotEmpty) {
      return _cachedDailyHeaderBrief!;
    }

    final bool hasCycle = pc.trackingPreference != CycleTrackingPreference.disabled && pc.lastPeriodStart != null;
    final String? phase = pc.cyclePhase;
    final int? cycleDay = pc.cycleDay;
    final topics = _extractChatContext(chatHistory);
    final feeling = (BlushyStorage.read('daily_checkin.json')['feeling'] ?? (BlushyStorage.read('logged_feeling.json')['feeling']))?.toString();

    String brief;

    if (hasCycle && phase != null && phase.toLowerCase().contains('menstru') && cycleDay != null) {
      brief = "You're on Cycle Day $cycleDay in your Menstrual Phase. Today is ideal for restorative pacing, nourishing hydration, and honoring your body's renewal cycle.";
    } else if (hasCycle && phase != null && phase.toLowerCase().contains('ovulat') && cycleDay != null) {
      brief = "You're on Cycle Day $cycleDay in your Ovulatory Window. Estrogen is peaking, bringing heightened clarity, social confidence, and vibrant energy for your day.";
    } else if (hasCycle && phase != null && phase.toLowerCase().contains('luteal') && cycleDay != null) {
      brief = "You're on Cycle Day $cycleDay in your Luteal Phase. Progesterone is guiding you inward; focus on balanced nutrition, restful sleep, and calming routines.";
    } else if (hasCycle && phase != null && phase.toLowerCase().contains('follicular') && cycleDay != null) {
      brief = "You're on Cycle Day $cycleDay in your Follicular Phase. Rising estrogen supports high cognitive focus, fresh creativity, and physical stamina today.";
    } else if (topics.contains('sleep') || (feeling != null && feeling.toLowerCase().contains('tired'))) {
      brief = "Here is your personalized wellness space. Dr. Docsy has tuned today's insights to support deeper rest, gentle movement, and steady energy.";
    } else {
      brief = "Here is your personalized space bringing together insights for $stagesSummary. Every rhythm is connected, and we're here to guide you seamlessly.";
    }

    _cachedDailyHeaderBrief = brief;
    return brief;
  }

  int _getRecentCheckinCount() {
    try {
      final checkin = BlushyStorage.read('daily_checkin.json');
      if (checkin.isNotEmpty) {
        final count = checkin['monthly_count'] ?? checkin['count'];
        if (count is int && count > 0) return count;
      }
    } catch (_) {}
    return 0;
  }
}
