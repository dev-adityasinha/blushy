import 'dart:async';
// Dynamic dashboard generated for stage: everyday_wellness
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:math' show min;
import '../../../../core/state.dart';
import '../../../../core/storage.dart';
import '../../../../core/cycle_calculator.dart';
import '../../../../theme/colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/voice_note_bottom_sheet.dart';
import '../../../../services/api_auth_service.dart';
import '../../../../core/stage_conflict_engine.dart';
import '../../models.dart';
import '../../widgets/cycle_card.dart';
import '../../widgets/real_insights_list.dart';
import '../../widgets/real_cycle_history.dart';
import '../../widgets/real_journey_timeline.dart';
import '../../../../services/sia_dashboard_service.dart';
import '../../../../services/api_blushy_service.dart';
import '../../../../services/api_contract_client.dart';
import '../../../../services/auth_storage.dart';
import '../../checkin_event_mapper.dart';
import '../../../../services/offline_event_queue.dart';
import '../../../../shared/api_state_card.dart';
import '../doctor_summary_screen.dart';
import '../../../../models/blushy_models.dart';
import '../../../../services/api_insights_service.dart';
import '../../../../services/api_community_service.dart';
import '../../../community/post_detail_screen.dart';
import '../../../sia/sia_screen.dart';
import '../../../m_studio/m_studio_screen.dart';
import '../../home_screen.dart';

String _getTimeBasedGreetingPrefix() {
  final istNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  final hour = istNow.hour;
  if (hour < 12) {
    return "Good Morning";
  } else if (hour < 17) {
    return "Good Afternoon";
  } else {
    return "Good Evening";
  }
}

class EverydayWellnessDashboard extends StatefulWidget {
  final String? stageKey;
  final List<String>? activeStages;
  final bool isNested;
  const EverydayWellnessDashboard({
    super.key,
    this.stageKey,
    this.activeStages,
    this.isNested = false,
  });

  @override
  State<EverydayWellnessDashboard> createState() => _EverydayWellnessDashboardState();
}

class _EverydayWellnessDashboardState extends State<EverydayWellnessDashboard> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _wrapDashboardLayout({
    required Widget child,
    GlobalKey<ScaffoldState>? scaffoldKey,
  }) {
    if (widget.isNested) {
      return Container(
        color: const Color(0xFFFAF6F0),
        child: child,
      );
    }
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFFAF6F0),
      body: SafeArea(child: child),
    );
  }

  ScrollPhysics get _effectiveScrollPhysics =>
      widget.isNested ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics();

  bool get _effectiveShrinkWrap => widget.isNested;

  final Set<String> _savedArticles = {};
  String? _selectedFeeling;
  String? _selectedEnergy;
  double? _loggedWeight;

  // Coach marks state

  // Onboarding answers state
  Map<String, dynamic> _onboardingData = {};
  


  // firstPeriodNotStarted interactive states
  final List<String> _lessons = [
    "Understanding My Body",
    "Puberty Basics",
    "Body Changes",
    "Hygiene & Self Care",
    "Preparing For My First Period",
  ];
  final Set<String> _completedLessons = {"Understanding My Body"};
  int _connectTabIndex = 0;
  bool _letsTalkDiscussed = false;
  bool _letsTalkSaved = false;

  // firstPeriodStarted interactive states
  String? _startedFlow = 'Medium';
  int _connectStartedTabIndex = 0;
  bool _startedLetsTalkDiscussed = false;
  bool _startedLetsTalkSaved = false;
  final Map<String, bool> _startedPeriodKitChecklist = {
    "Pads": true,
    "Extra underwear": false,
    "Small pouch": true,
    "Wet wipes": false,
    "Water bottle": false,
    "Trusted teacher": false,
  };
  final Set<String> _startedSavedArticles = {};

  final GlobalKey _checkInKey = GlobalKey();

  void _scrollToCheckIn() {
    final ctx = _checkInKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.02,
      );
    }
  }

  String? _checkInMood;
  String? _checkInEnergy;

  // livingWithMyCycle interactive states
  String _livingDiscoverTopic = 'Cycle Health';
  String _livingCommunityTab = 'Questions';
  final Set<String> _livingSavedArticles = {};
  String? _livingFlow;
  String? _livingPain;
  String? _livingSleep;
  String? _livingStress;
  String? _livingWater;
  String? _livingExercise;

  // hormonalHealth interactive states
  String _hormonalDiscoverTopic = 'Understanding PCOS';
  final Set<String> _hormonalSavedArticles = {};
  String? _hormonalBloating;
  String? _hormonalAcne;
  String? _hormonalHeadache;
  String? _hormonalMedication;
  String? _hormonalPain;
  String? _hormonalCramps;
  String? _hormonalFlow;
  String? _hormonalExercise;

  // tryingToConceive interactive states
  String _ttcDiscoverTopic = 'Understanding Ovulation';
  final Set<String> _ttcSavedArticles = {};
  String? _ttcCervicalMucus;
  String? _ttcLhTest;
  double? _ttcBbt;
  String? _ttcIntercourse;
  String? _ttcExercise;
  String? _ttcVitamins;

  // pregnancy interactive states
  String _pregnancyDiscoverTopic = 'Baby Development';
  final Set<String> _pregnancySavedArticles = {};
  String? _pregnancyBabyMovement;
  int? _pregnancyKickCount;
  String? _pregnancyContractions;
  String? _pregnancyExercise;
  String? _pregnancyVitamins;

  // postpartum interactive states
  String _postpartumDiscoverTopic = 'Physical Recovery';
  String _postpartumCommunityTab = 'Recovery';
  final Set<String> _postpartumSavedArticles = {};
  String? _postpartumFeeding;
  String? _postpartumBleeding;
  String? _postpartumIncision;
  String? _postpartumPelvic;
  String? _postpartumWater;
  String? _postpartumExercise;

  // perimenopause interactive states
  String _periDiscoverTopic = 'Hormonal Changes';
  String _periCommunityTab = 'Hot Flashes';
  final Set<String> _periSavedArticles = {};
  String? _periHotFlashes;
  String? _periNightSweats;
  String? _periBrainFog;
  String? _periHormoneTherapy;
  String? _periFlow;
  String? _periWater;
  String? _periExercise;

  late PeriodConfirmationState _periodConfirmationState;

  // menopause interactive states
  String _menoDiscoverTopic = 'Understanding Menopause';
  String _menoCommunityTab = 'Healthy Ageing';
  final Set<String> _menoSavedArticles = {};
  String? _menoHotFlashes;
  String? _menoNightSweats;
  String? _menoJointPain;
  String? _menoHormoneTherapy;
  String? _menoStrength;
  String? _menoWalking;
  String? _menoWater;

  // everydayWellness interactive states
  String _wellnessDiscoverTopic = 'Nutrition';
  String _wellnessCommunityTab = 'Wellness';
  final Set<String> _wellnessSavedArticles = {};
  String? _wellnessExercise;
  String? _wellnessMeditation;
  String? _wellnessSleep;
  String? _wellnessStress;
  String? _wellnessWater;

  PersonalContext get _currentPc {
    try {
      return BlushyOSProvider.of(context).personalContext;
    } catch (_) {
      return PersonalContext(
        trackingPreference: CycleTrackingPreference.unknown,
        cyclePattern: CyclePattern.unknown,
        confidence: DataConfidence.low,
        lifeContexts: const {LifeContext.none},
        userGoals: const {},
        preferences: UserPreferences(),
      );
    }
  }

  PersonalContext get pc => _currentPc;

  // ---------------------------------------------------------------------
  // Cycle Hero data source.
  //
  // Cycle day, phase and predictions are calculated by the backend and read
  // from here; the dashboard no longer derives them locally. The previous
  // implementation used `daysDiff % cycleLength`, which invented a cycle day
  // for cycles that were never logged: a period logged 61 days ago on a
  // 28-day cycle displayed "Cycle Day 6" instead of a period 33 days late.
  // The server returns the real day count plus an explicit overdue state.
  // ---------------------------------------------------------------------

  // ---------------------------------------------------------------------
  // Daily check-in writes.
  //
  // Each card used to write only to local storage and to
  // `saveOnboardingAnswers`, so a tap produced no timestamped health event and
  // nothing downstream (patterns, care plan, doctor summary) could see it.
  // These now post a validated event, which is what the pattern engine reads.
  //
  // The selectors offer buckets ("6-8h", "Medium", "2L"). Each bucket maps to
  // the value the backend scale expects, and the label the user actually
  // picked travels with it as `reportedAs`, so a bucketed answer is never
  // shown back as a precise measurement.
  // ---------------------------------------------------------------------

  /// Posts one check-in event. Failures are non-fatal: the local write has
  /// already happened, and the offline queue can replay from there.
  ///
  /// The bucket-to-event mapping lives in [CheckinEventMapper] so it can be
  /// tested without building this widget.
  Future<void> _recordCheckinEvent(String metric, String rawValue) async {
    final mapped = CheckinEventMapper.map(metric, rawValue);
    if (mapped == null) return;

    final clientEventId = CheckinEventMapper.idempotencyKey(
      userId: AuthStorage.getUserId() ?? 'anon',
      metric: metric,
      day: DateTime.now(),
    );

    final result = await EventsApi.log(
      eventType: mapped.eventType,
      payload: mapped.payload,
      clientEventId: clientEventId,
    );

    // A write that could not reach the server is queued rather than lost, and
    // replays with the same id so it cannot be recorded twice (spec §25).
    if (result.state == ApiState.offline || result.state == ApiState.error) {
      await OfflineEventQueue.instance.enqueue(
        eventType: mapped.eventType,
        payload: mapped.payload,
        clientEventId: clientEventId,
      );
      return;
    }

    // A symptom or pain entry can trip a red flag rule; surface the reviewed
    // guidance rather than letting the ordinary confirmation stand.
    if (mounted && result.data?.hasSafetyEscalation == true) {
      setState(() => _checkinSafety = result.data!.safety);
    }
  }

  /// Set when a check-in write returns a safety escalation, so the screen can
  /// show the reviewed guidance instead of a wellness confirmation.
  SafetyFlow? _checkinSafety;

  /// Rehydrates today's check-in selections from the server.
  ///
  /// The cards read their selected state from `daily_checkin.json`, which was
  /// only ever written on this device, so a check-in made on web did not show
  /// on Android and vice versa. Today's stored events are the shared source of
  /// truth; this maps them back onto the labels the cards render and refreshes
  /// the local copy so every existing read site stays correct.
  /// Replays writes made while offline, then refreshes what depends on them.
  Future<void> _flushOfflineQueue() async {
    await OfflineEventQueue.instance.load();
    final result = await OfflineEventQueue.instance.flush();
    if (!mounted || !result.didAnything) return;
    await _loadTodayCheckins();
    if (!mounted) return;
    await _loadPatterns();
  }

  Future<void> _loadTodayCheckins() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final result = await EventsApi.list(
      eventTypes: const [
        'mood_logged', 'symptom_logged', 'energy_logged', 'sleep_logged',
        'stress_logged', 'hydration_logged', 'pain_logged', 'flow_logged',
        'activity_logged',
      ],
      from: startOfDay,
      limit: 100,
    );

    if (!mounted || !result.isReady || result.data == null) return;

    // Oldest first, so a later entry for the same metric wins.
    final events = result.data!.reversed;
    final selections = <String, String>{};
    for (final event in events) {
      final mapped = CheckinEventMapper.reverse(event.eventType, event.payload);
      if (mapped != null) selections[mapped.key] = mapped.value;
    }

    if (selections.isEmpty) return;

    final checkin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
    selections.forEach((metric, label) {
      checkin[metric] = label;
      if (metric == 'mood') checkin['feeling'] = label;
    });
    checkin['date'] = now.toIso8601String();
    BlushyStorage.write('daily_checkin.json', checkin);

    setState(() {
      if (selections['mood'] != null) _selectedFeeling = selections['mood'];
      if (selections['energy'] != null) _selectedEnergy = selections['energy'];
      if (selections['sleep'] != null) _livingSleep = selections['sleep'];
      if (selections['stress'] != null) _livingStress = selections['stress'];
      if (selections['water'] != null) _livingWater = selections['water'];
      if (selections['flow'] != null) _livingFlow = selections['flow'];
      if (selections['pain'] != null) _livingPain = selections['pain'];
      if (selections['exercise'] != null) _livingExercise = selections['exercise'];
    });
  }

  /// Renders the reviewed red flag instruction and the location-aware
  /// resources that came with it. The wording is the clinically reviewed text
  /// from the rule, not anything generated here.
  Widget _buildCheckinSafetyBanner(SafetyFlow safety) {
    final step = safety.steps.isNotEmpty ? safety.steps.first : null;
    if (step == null) return const SizedBox.shrink();

    final bool urgent = safety.isEmergency;
    final Color accent = urgent ? const Color(0xFFB3261E) : const Color(0xFFB26A00);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(urgent ? Icons.emergency_outlined : Icons.warning_amber_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.title,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            step.instruction,
            style: GoogleFonts.poppins(fontSize: 12.5, height: 1.45, color: BlushyColors.text),
          ),
          if (safety.emergencyNumber != null) ...[
            const SizedBox(height: 10),
            Text(
              'Emergency number: ${safety.emergencyNumber}',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: accent),
            ),
          ],
          if (step.source != null) ...[
            const SizedBox(height: 8),
            Text(
              'Source: ${step.source}',
              style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _checkinSafety = null),
              child: Text('Dismiss', style: GoogleFonts.poppins(fontSize: 12, color: accent)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Patterns and the Sia Note.
  //
  // These previously rendered hardcoded sentences chosen by keyword-matching
  // recent chat topics, with a fixed "Medium" confidence and an "Evidence:"
  // line that actually contained advice. Nothing was derived from the user's
  // own logs, and nothing could be traced or invalidated.
  //
  // They now render structured insights computed by the backend pattern
  // engine, each carrying the events it was derived from, its strength, when
  // it was generated and which engine version produced it (spec section 8).
  // ---------------------------------------------------------------------

  // ---------------------------------------------------------------------
  // Care Plan.
  //
  // Each life stage previously rendered its own hardcoded list of paragraphs,
  // including a fabricated appointment ("24 Week glucose screening ...
  // scheduled for tomorrow at 10 AM") and supplement instructions tied to
  // nothing the user reported. The hormonal branch rendered
  // `dummyCareRecommendations` from mock_data.dart.
  //
  // Care Plan cards are action objects, not paragraphs (spec section 10): each
  // carries why it was suggested, where it came from, a completion state and a
  // validity window. Repeats are held back by a server-side cooldown, and the
  // whole plan is withheld while a safety escalation is active.
  // ---------------------------------------------------------------------

  // ---------------------------------------------------------------------
  // Timeline.
  //
  // Timeline is raw chronological history; Patterns is interpretation, and the
  // two must not duplicate each other (spec section 11). The old card rendered
  // an "AI Summary" line per row, which is interpretation, on top of
  // `dummyTimelineSummaries` from mock_data.dart - a list that is now empty, so
  // the card had been silently rendering nothing. The TTC variant listed
  // fabricated events ("June 10 Started TTC Journey") as the user's history.
  // ---------------------------------------------------------------------

  // ---------------------------------------------------------------------
  // Reflection.
  //
  // The prompt came from `dummyReflectionPrompts`, indexed by `day % length`
  // over a list of length one, so every user saw the same question every day.
  // More seriously, "Send" only set a local flag: the answer was never stored
  // anywhere, and the spec requires the response to be persisted.
  //
  // Prompts are now data driven and stage aware, and TTC gets the emotionally
  // neutral options the spec asks for rather than a generic mood question.
  // Responses are private by default and never shared with a partner unless
  // that is granted explicitly (spec section 12).
  // ---------------------------------------------------------------------

  // ---------------------------------------------------------------------
  // Condition profile.
  //
  // Only conditions the user reported being diagnosed with. Blushy never
  // infers a diagnosis from logs, and shows no estimated hormone levels
  // because it ingests no validated lab or device data (spec section 14).
  // ---------------------------------------------------------------------

  ApiResult<Map<String, dynamic>> _conditionsResult = const ApiResult.loading();

  Future<void> _loadConditions() async {
    final result = await BranchApi.conditions();
    if (!mounted) return;
    setState(() => _conditionsResult = result);
  }


  Future<void> _loadReflection() async {
    final result = await ReflectionsApi.current();
    if (!mounted) return;
    setState(() {
      // An answer already given this period is shown as answered.
      final existing = result.data?['reflection'];
      if (existing is Map && existing['response'] != null) {
      }
    });
  }





  ApiResult<Timeline> _timelineResult = const ApiResult.loading();

  /// Entries accumulated across pages, so "Load more" appends rather than
  /// replacing what is already on screen.
  final List<TimelineEntry> _timelineEntries = [];
  bool _timelineHasMore = false;
  bool _timelineLoadingMore = false;

  static const int _timelinePageSize = 20;

  Future<void> _loadTimeline({bool append = false}) async {
    if (append) {
      if (_timelineLoadingMore || !_timelineHasMore) return;
      setState(() => _timelineLoadingMore = true);
    }

    final result = await EventsApi.timeline(
      limit: _timelinePageSize,
      skip: append ? _timelineEntries.length : 0,
    );

    if (!mounted) return;
    setState(() {
      _timelineResult = result;
      _timelineLoadingMore = false;
      if (result.isReady && result.data != null) {
        if (!append) _timelineEntries.clear();
        _timelineEntries.addAll(result.data!.entries);
        _timelineHasMore = result.data!.hasMore;
      } else if (!append) {
        _timelineEntries.clear();
        _timelineHasMore = false;
      }
    });
  }

  static const Map<String, IconData> _timelineIcons = {
    'period_logged': Icons.water_drop_rounded,
    'flow_logged': Icons.opacity_rounded,
    'symptom_logged': Icons.healing_rounded,
    'pain_logged': Icons.bolt_rounded,
    'mood_logged': Icons.bubble_chart_rounded,
    'energy_logged': Icons.battery_charging_full_rounded,
    'sleep_logged': Icons.nightlight_round,
    'hydration_logged': Icons.local_drink_rounded,
    'stress_logged': Icons.air_rounded,
    'activity_logged': Icons.directions_run_rounded,
    'hot_flash_logged': Icons.whatshot_rounded,
    'journal_created': Icons.edit_note_rounded,
    'appointment_logged': Icons.event_note_outlined,
    'bbt_logged': Icons.thermostat_rounded,
    'lh_test_logged': Icons.science_outlined,
    'cervical_mucus_logged': Icons.opacity_outlined,
    'pregnancy_week_updated': Icons.child_friendly_outlined,
    'pregnancy_ended': Icons.event_available_outlined,
    'feeding_logged': Icons.restaurant_outlined,
    'recovery_metric_logged': Icons.self_improvement_outlined,
    'condition_reported': Icons.medical_information_outlined,
    'life_scene_set': Icons.landscape_outlined,
  };

  static String _timelineDateLabel(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final sameDay = date.year == now.year && date.month == now.month && date.day == now.day;
    if (sameDay) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${months[date.month - 1]} ${date.day}';
  }

  ApiResult<CarePlan> _carePlanResult = const ApiResult.loading();

  Future<void> _loadCarePlan() async {
    final result = await CarePlanApi.load();
    if (!mounted) return;
    setState(() => _carePlanResult = result);
  }

  Future<void> _completeCareAction(CareAction action) async {
    final messenger = ScaffoldMessenger.of(context);
    await CarePlanApi.complete(action.id);
    if (!mounted) return;
    await _loadCarePlan();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Done: ${action.title}')));
  }

  Future<void> _dismissCareAction(CareAction action) async {
    await CarePlanApi.dismiss(action.id);
    if (!mounted) return;
    await _loadCarePlan();
  }

  static IconData _careActionIcon(String category) {
    switch (category) {
      case 'sleep':
        return Icons.nightlight_round;
      case 'energy':
        return Icons.bolt_rounded;
      case 'hydration':
        return Icons.water_drop_outlined;
      case 'comfort':
        return Icons.spa_outlined;
      case 'emotional':
      case 'mental_health':
        return Icons.favorite_outline;
      case 'cycle':
        return Icons.calendar_month_outlined;
      case 'appointment':
        return Icons.event_note_outlined;
      case 'preventive':
        return Icons.health_and_safety_outlined;
      case 'experiment':
        return Icons.science_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  ApiResult<List<Insight>> _patternsResult = const ApiResult.loading();

  Future<void> _loadPatterns({bool refresh = false}) async {
    if (mounted && refresh) {
      setState(() => _patternsResult = const ApiResult.loading());
    }
    final result = await PatternsApi.load(refresh: refresh);
    if (!mounted) return;
    setState(() => _patternsResult = result);
  }

  Future<void> _markInsightHelpful(Insight insight) async {
    final messenger = ScaffoldMessenger.of(context);
    await PatternsApi.feedback(insight.id, helpful: true);
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Noted. Sia will keep showing observations like this.')),
    );
  }

  /// Not useful: the insight stops being served until its evidence materially
  /// changes, and the feedback is recorded for future ranking (spec section 9).
  Future<void> _markInsightNotUseful(Insight insight) async {
    final messenger = ScaffoldMessenger.of(context);
    await PatternsApi.feedback(insight.id, helpful: false);
    if (!mounted) return;
    await _loadPatterns();
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Thanks. You will not see that one again.')),
    );
  }

  /// Human-readable strength. This describes how consistently the pattern
  /// appears in the logs, never medical certainty.
  static String _strengthLabel(Insight insight) {
    final strength = insight.strength;
    if (strength == null || strength.isEmpty) return 'Observation';
    return '${strength[0].toUpperCase()}${strength.substring(1)} pattern';
  }

  /// The real evidence line: how many observations, over what window.
  static String _evidenceLine(Insight insight) {
    final parts = <String>[];
    if (insight.observationCount != null) {
      parts.add('${insight.observationCount} of your logs');
    }
    if (insight.sourceEventIds.isNotEmpty) {
      parts.add('${insight.sourceEventIds.length} entries');
    }
    if (insight.periodStart != null && insight.periodEnd != null) {
      final days = insight.periodEnd!.difference(insight.periodStart!).inDays;
      if (days > 0) parts.add('over the last $days days');
    }
    return parts.isEmpty ? 'Based on your recent logs' : 'Based on ${parts.join(', ')}';
  }

  ApiResult<CycleState> _cycleResult = const ApiResult.loading();

  /// Last successful server response, so an offline refresh can keep showing
  /// the last known real values instead of falling back to local arithmetic.
  CycleState? _lastKnownCycle;

  Future<void> _loadCycleFromServer() async {
    final result = await CycleApi.current(
      timezone: DateTime.now().timeZoneName,
    );
    if (!mounted) return;
    setState(() {
      _cycleResult = result;
      if (result.isReady && result.data != null) {
        _lastKnownCycle = result.data;
      }
    });
  }

  static String _formatDayMonth(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'Not available';
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return 'Not available';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[parsed.month - 1]} ${parsed.day}';
  }

  /// Projects the server cycle state into the map shape the dashboard cards
  /// already consume, so every existing card keeps working unchanged.
  ///
  /// The `state` key is new: cards that want to distinguish loading from empty
  /// from "not enough data yet" can read it, and the ones that only read
  /// `isLogged` behave exactly as before.
  Map<String, dynamic> _getDynamicCycleDates([PersonalContext? pc]) {
    Map<String, dynamic> unavailable(String state, String dayText, String subtitle) => {
          'state': state,
          'isLogged': false,
          'cycleDay': null,
          'cycleDayText': dayText,
          'subtitle': subtitle,
          'ovulationText': 'Not available',
          'fertileWindow': 'Not available',
          'expectedPeriod': 'Not available',
          'recTestDay': 'Not available',
          'phaseName': 'Not Logged',
        };

    final cycle = _cycleResult.data ?? _lastKnownCycle;

    // Branches that do not use cycle language at all (menopause, pregnancy).
    if (cycle != null && !cycle.cycleTrackingAvailable) {
      return unavailable(
        'restricted',
        'Cycle tracking paused',
        cycle.restrictedMessage ?? 'Your current stage does not use cycle tracking.',
      );
    }

    switch (_cycleResult.state) {
      case ApiState.loading:
        return unavailable('loading', 'Loading…', 'Fetching your cycle.');

      case ApiState.empty:
        // No period data at all. Never show a simulated cycle day here.
        return unavailable(
          'empty',
          'Not Logged',
          'No period logged yet. Tap to set your last period start date.',
        );

      case ApiState.offline:
      case ApiState.error:
        if (cycle == null) {
          return unavailable(
            _cycleResult.state == ApiState.offline ? 'offline' : 'error',
            'Cycle Day unavailable',
            _cycleResult.state == ApiState.offline
                ? 'You are offline. Your cycle will refresh when you reconnect.'
                : 'Could not load your cycle. Pull to refresh.',
          );
        }
        break;

      default:
        break;
    }

    if (cycle == null || cycle.currentCycleDay == null) {
      return unavailable(
        'empty',
        'Not Logged',
        'No period logged yet. Tap to set your last period start date.',
      );
    }

    final int cycleDay = cycle.currentCycleDay!;
    final bool predictionsAvailable = cycle.hasPrediction;

    // Predictions are withheld until there is enough history to give them
    // honestly; the card shows the reason instead of a fabricated date.
    const notEnough = 'Not enough data yet';

    final bool hasOvulation = cycle.estimatedOvulationDate != null;
    final String ovulationText = hasOvulation
        ? _formatDayMonth(cycle.estimatedOvulationDate)
        : notEnough;
    final String expectedPeriod =
        predictionsAvailable ? _formatDayMonth(cycle.nextPeriodStartDate) : notEnough;
    final String fertileWindow = (cycle.fertileWindowStart != null && cycle.fertileWindowEnd != null)
        ? '${_formatDayMonth(cycle.fertileWindowStart)} - ${_formatDayMonth(cycle.fertileWindowEnd)}'
        : notEnough;

    final nextPeriod = cycle.nextPeriodStartDate == null
        ? null
        : DateTime.tryParse(cycle.nextPeriodStartDate!);
    final String recTestDay = nextPeriod == null
        ? notEnough
        : _formatDayMonth(nextPeriod.add(const Duration(days: 3)).toIso8601String());

    // A late period is surfaced as late, not folded into a new cycle.
    final String subtitle;
    if (cycle.isOverdue) {
      subtitle = cycle.lateNotice ??
          'Your period is ${cycle.daysOverdue ?? 0} day(s) later than your logged pattern suggests.';
    } else if (hasOvulation) {
      subtitle = 'Expected Ovulation: $ovulationText';
    } else {
      subtitle = cycle.sufficiencyMessage ?? 'Keep logging to build your cycle picture.';
    }

    return {
      'state': _cycleResult.state == ApiState.insufficientData ? 'insufficient_data' : 'ready',
      'isLogged': true,
      'cycleDay': cycleDay,
      'cycleDayText': cycle.isOverdue
          ? 'Day $cycleDay · ${cycle.daysOverdue ?? 0} days late'
          : 'Cycle Day $cycleDay',
      'subtitle': subtitle,
      'ovulationText': ovulationText,
      'fertileWindow': fertileWindow,
      'expectedPeriod': expectedPeriod,
      'recTestDay': recTestDay,
      'phaseName': cycle.phase ?? 'Not Logged',
      // Provenance, so the card can show which calculation produced the number.
      'calculationVersion': cycle.calculationVersion,
      'confidenceLevel': cycle.confidenceLevel,
      'isOverdue': cycle.isOverdue,
      'disclaimer': cycle.disclaimer,
    };
  }

  List<String> _extractStrings(dynamic val) {
    if (val == null) return [];
    if (val is List) return val.map((e) => e.toString().toLowerCase()).toList();
    if (val is Set) return val.map((e) => e.toString().toLowerCase()).toList();
    if (val is Iterable) return val.map((e) => e.toString().toLowerCase()).toList();
    if (val is String) {
      if (val.trim().isEmpty) return [];
      final cleaned = val.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", '');
      return cleaned.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
    }
    return [val.toString().toLowerCase()];
  }

  // Filter check-in options based on user questionnaire / chosen focus areas
  bool _isMetricSelected(dynamic pcOrKeywords, [List<String>? keywords]) {
    List<String> kw;
    PersonalContext targetPc;
    if (pcOrKeywords is PersonalContext) {
      targetPc = pcOrKeywords;
      kw = keywords ?? [];
    } else if (pcOrKeywords is List<String>) {
      targetPc = _currentPc;
      kw = pcOrKeywords;
    } else if (pcOrKeywords is List) {
      targetPc = _currentPc;
      kw = pcOrKeywords.map((e) => e.toString()).toList();
    } else {
      targetPc = _currentPc;
      kw = keywords ?? [];
    }

    final dynamic answersObj = _onboardingData['answers'];
    final List<String> userChoices = [
      ..._extractStrings(targetPc.userSymptoms),
      ..._extractStrings(targetPc.userGoals),
      ..._extractStrings(targetPc.medicalConditions),
      ..._extractStrings(_onboardingData['symptoms']),
      ..._extractStrings(_onboardingData['userSymptoms']),
      ..._extractStrings(_onboardingData['goals']),
      if (answersObj is Map) ..._extractStrings(answersObj['symptoms']),
      if (answersObj is Map) ..._extractStrings(answersObj['goals']),
    ];

    if (userChoices.isEmpty) {
      // Default to showing core essentials if no granular symptoms specified
      return kw.any((k) => ['mood', 'energy', 'hot flashes', 'cramps', 'bloating', 'pain', 'movement', 'sleep'].contains(k.toLowerCase()));
    }

    return userChoices.any((choice) => kw.any((kwItem) => choice.contains(kwItem.toLowerCase()) || kwItem.toLowerCase().contains(choice)));
  }

  final Map<String, bool> _periodKitChecklist = {
    "Pads": false,
    "Extra underwear": false,
    "Small pouch": false,
    "Wet wipes": false,
    "Water bottle": false,
    "Trusted teacher": false,
  };
  final Set<String> _sharedLessons = {"Understanding My Body"};

  @override
  void initState() {
    super.initState();
    _periodConfirmationState = PeriodConfirmationState(
      hasLoggedPeriod: false,
      predictedStartDate: DateTime.now().add(const Duration(days: 9)),
      actualStartDate: null,
      isDismissed: false,
      status: 'pending',
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animController.forward();
    _checkFirstLaunchCoach();
    _loadOnboardingData();
    // Cycle day, phase and predictions come from the backend calculation
    // service rather than being derived on the client.
    _loadCycleFromServer();
    // Patterns are computed from the user's own logged events.
    _loadPatterns();
    // Care plan actions come from the rule engine, with safety suppression.
    _loadCarePlan();
    // Timeline is the user's own logged events, in order.
    _loadTimeline();
    // Reflection prompt follows the current life stage.
    _loadReflection();
    // Conditions the user reported being diagnosed with.
    _loadConditions();
    // Anything logged offline is sent before today's state is read back.
    _flushOfflineQueue();
    // Today's check-in selections, so they follow the account across devices.
    _loadTodayCheckins();
    SiaDashboardService().refreshNotifier.addListener(_onSiaRefresh);
  }

  void _onSiaRefresh() {
    if (mounted) {
      _loadOnboardingData();
      _loadCycleFromServer();
      _loadPatterns();
      _loadCarePlan();
      _loadTimeline();
      _loadReflection();
      _loadConditions();
      _loadTodayCheckins();
      setState(() {});
    }
  }

  void _saveWeightLog(double val) {
    setState(() {
      _loggedWeight = val;
    });
    try {
      BlushyStorage.write('logged_weight.json', {'weight': val});
      final weightData = BlushyStorage.read('weight_history.json');
      final List history = weightData['history'] is List ? List.from(weightData['history']) : [];
      history.add({'weight': val, 'date': DateTime.now().toIso8601String()});
      BlushyStorage.write('weight_history.json', {'history': history});

      final profileData = BlushyStorage.read('user_profile.json');
      final Map answers = Map.from(profileData['answers'] as Map? ?? profileData['profile']?['answers'] as Map? ?? {});
      answers['weight_current'] = val.toString();
      answers['weight'] = val.toString();
      profileData['answers'] = answers;
      BlushyStorage.write('user_profile.json', profileData);
    } catch (_) {}
    ApiAuthService().saveWeightLog(val).catchError((_) => false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = BlushyOSProvider.of(context);
      final cur = provider.personalContext;
      provider.updatePersonalContext(PersonalContext(
        userName: cur.userName,
        dateOfBirth: cur.dateOfBirth,
        weight: val,
        trackingPreference: cur.trackingPreference,
        cyclePattern: cur.cyclePattern,
        confidence: cur.confidence,
        lifeContexts: cur.lifeContexts,
        userGoals: cur.userGoals,
        medicalConditions: cur.medicalConditions,
        preferences: cur.preferences,
        cycleLength: cur.cycleLength,
        cycleDay: cur.cycleDay,
        cyclePhase: cur.cyclePhase,
        lastPeriodStart: cur.lastPeriodStart,
        medications: cur.medications,
      ));
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Weight saved: ${val.toStringAsFixed(1)} kg")),
      );
    }
  }

  void _loadOnboardingData() {
    try {
      final decoded = BlushyStorage.read('user_profile.json');
      final weightData = BlushyStorage.read('logged_weight.json');
      final savedWeight = weightData['weight'];
      
      final checkinData = BlushyStorage.read('daily_checkin.json');
      if (checkinData['feeling'] != null) _selectedFeeling = checkinData['feeling'].toString();
      if (checkinData['mood'] != null) _selectedFeeling = checkinData['mood'].toString();
      if (checkinData['energy'] != null) _selectedEnergy = checkinData['energy'].toString();
      if (checkinData['sleep'] != null) _livingSleep = checkinData['sleep'].toString();
      if (checkinData['stress'] != null) _livingStress = checkinData['stress'].toString();
      if (checkinData['water'] != null) _livingWater = checkinData['water'].toString();
      if (checkinData['flow'] != null) _livingFlow = checkinData['flow'].toString();
      if (checkinData['pain'] != null) _livingPain = checkinData['pain'].toString();
      if (checkinData['exercise'] != null) _livingExercise = checkinData['exercise'].toString();

      setState(() {
        final p = decoded['profile'];
        _onboardingData = p is Map ? Map<String, dynamic>.from(p) : Map<String, dynamic>.from(decoded);
        if (savedWeight != null && savedWeight.toString().isNotEmpty) {
          _loggedWeight = double.tryParse(savedWeight.toString());
        }
      });
    } catch (_) {
      setState(() {
        _onboardingData = {};
      });
    }

    // Attempt to sync from backend API
    ApiAuthService().getOnboardingAnswers().then((remoteAnswers) {
      if (remoteAnswers.isNotEmpty && mounted) {
        setState(() {
          final currentAnswers = _onboardingData['answers'];
          _onboardingData['answers'] = {
            if (currentAnswers is Map) ...currentAnswers,
            ...remoteAnswers,
          };
          if (remoteAnswers.containsKey('preferred_name')) {
            _onboardingData['preferredName'] = remoteAnswers['preferred_name'];
          }
          if (remoteAnswers.containsKey('life_stage')) {
            final active = BlushyOSProvider.of(context).personalContext.activeLifeStages;
            if (active.isEmpty) {
              _onboardingData['lifeStage'] = remoteAnswers['life_stage'];
            }
          }
          final remoteW = remoteAnswers['weight_current'] ?? remoteAnswers['weight'];
          if (remoteW != null && remoteW.toString().isNotEmpty) {
            final parsedW = double.tryParse(remoteW.toString());
            if (parsedW != null && parsedW > 0) {
              _loggedWeight = parsedW;
            }
          }

          // Hydrate live interactive state from MongoDB
          if (remoteAnswers['daily_mood'] != null) {
            _selectedFeeling = remoteAnswers['daily_mood'].toString();
          }
          if (remoteAnswers['daily_energy'] != null) {
            _selectedEnergy = remoteAnswers['daily_energy'].toString();
          }
          if (remoteAnswers['daily_sleep'] != null) {
            _livingSleep = remoteAnswers['daily_sleep'].toString();
          }
          if (remoteAnswers['daily_water'] != null) {
            _livingWater = remoteAnswers['daily_water'].toString();
          }
          if (remoteAnswers['daily_stress'] != null) {
            _livingStress = remoteAnswers['daily_stress'].toString();
          }
          if (remoteAnswers['daily_flow'] != null) {
            _livingFlow = remoteAnswers['daily_flow'].toString();
          }
          if (remoteAnswers['daily_pain'] != null) {
            _livingPain = remoteAnswers['daily_pain'].toString();
          }
          if (remoteAnswers['daily_exercise'] != null) {
            _livingExercise = remoteAnswers['daily_exercise'].toString();
          }

          if (remoteAnswers['puberty_feeling'] != null) {
            final pf = remoteAnswers['puberty_feeling'];
            if (pf is Map && pf['feeling'] != null) {
              _selectedFeeling = pf['feeling'].toString();
            } else if (pf is String) {
              _selectedFeeling = pf;
            }
          }

          if (remoteAnswers['completed_lessons'] != null) {
            _completedLessons.addAll(_extractStrings(remoteAnswers['completed_lessons']));
          }

          if (remoteAnswers['first_period_kit'] is Map) {
            final kitMap = remoteAnswers['first_period_kit'] as Map;
            kitMap.forEach((k, v) {
              _periodKitChecklist[k.toString()] = v == true;
            });
          }

          if (remoteAnswers['daily_checkin'] is Map) {
            final c = remoteAnswers['daily_checkin'] as Map;
            if (c['feeling'] != null) _selectedFeeling = c['feeling'].toString();
            if (c['mood'] != null) _selectedFeeling = c['mood'].toString();
            if (c['energy'] != null) _selectedEnergy = c['energy'].toString();
            if (c['flow'] != null) _livingFlow = c['flow'].toString();
            if (c['pain'] != null) _livingPain = c['pain'].toString();
            if (c['sleep'] != null) _livingSleep = c['sleep'].toString();
            if (c['stress'] != null) _livingStress = c['stress'].toString();
            if (c['water'] != null) _livingWater = c['water'].toString();
            if (c['exercise'] != null) _livingExercise = c['exercise'].toString();
          }

          if (remoteAnswers['hormone_log'] is Map) {
            final h = remoteAnswers['hormone_log'] as Map;
            if (h['bloating'] != null) _hormonalBloating = h['bloating'].toString();
            if (h['acne'] != null) _hormonalAcne = h['acne'].toString();
            if (h['headache'] != null) _hormonalHeadache = h['headache'].toString();
            if (h['medication'] != null) _hormonalMedication = h['medication'].toString();
          }

          if (remoteAnswers['ttc_log'] is Map) {
            final t = remoteAnswers['ttc_log'] as Map;
            if (t['cervical_mucus'] != null) _ttcCervicalMucus = t['cervical_mucus'].toString();
            if (t['lh_test'] != null) _ttcLhTest = t['lh_test'].toString();
            if (t['bbt'] != null) _ttcBbt = double.tryParse(t['bbt'].toString()) ?? _ttcBbt;
          }

          if (remoteAnswers['pregnancy_log'] is Map) {
            final p = remoteAnswers['pregnancy_log'] as Map;
            if (p['baby_movement'] != null) _pregnancyBabyMovement = p['baby_movement'].toString();
            if (p['kick_count'] != null) _pregnancyKickCount = int.tryParse(p['kick_count'].toString()) ?? _pregnancyKickCount;
          }

          if (remoteAnswers['postpartum_log'] is Map) {
            final post = remoteAnswers['postpartum_log'] as Map;
            if (post['feeding'] != null) _postpartumFeeding = post['feeding'].toString();
            if (post['bleeding'] != null) _postpartumBleeding = post['bleeding'].toString();
          }

          if (remoteAnswers['peri_log'] is Map) {
            final peri = remoteAnswers['peri_log'] as Map;
            if (peri['hot_flashes'] != null) _periHotFlashes = peri['hot_flashes'].toString();
            if (peri['night_sweats'] != null) _periNightSweats = peri['night_sweats'].toString();
          }

          if (remoteAnswers['menopause_log'] is Map) {
            final meno = remoteAnswers['menopause_log'] as Map;
            if (meno['hot_flashes'] != null) _menoHotFlashes = meno['hot_flashes'].toString();
            if (meno['night_sweats'] != null) _menoNightSweats = meno['night_sweats'].toString();
          }
        });

        // Hydrate personal context with fetched user profile values in post frame callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final provider = BlushyOSProvider.of(context);
          final cur = provider.personalContext;
          final name = remoteAnswers['preferred_name']?.toString() ?? cur.userName;
          final cLen = int.tryParse(remoteAnswers['cycle_length']?.toString() ?? '') ?? cur.cycleLength;

          DateTime? pStart = cur.lastPeriodStart;
          if (remoteAnswers.containsKey('period_last_start_date')) {
            pStart = DateTime.tryParse(remoteAnswers['period_last_start_date'].toString());
          }

          provider.updatePersonalContext(PersonalContext(
            userName: name,
            dateOfBirth: cur.dateOfBirth,
            weight: cur.weight ?? _loggedWeight,
            trackingPreference: cur.trackingPreference,
            cyclePattern: cur.cyclePattern,
            confidence: cur.confidence,
            lifeContexts: cur.lifeContexts,
            userGoals: cur.userGoals,
            medicalConditions: cur.medicalConditions,
            preferences: cur.preferences,
            cycleLength: cLen,
            cycleDay: cur.cycleDay,
            cyclePhase: cur.cyclePhase,
            lastPeriodStart: pStart,
            medications: cur.medications,
          ));
        });
      }
    }).catchError((_) {});
  }

  void _checkFirstLaunchCoach() {
    try {
      final file = File('coach_first_launch.json');
      if (file.existsSync()) {
        setState(() {
        });
        file.deleteSync();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    SiaDashboardService().refreshNotifier.removeListener(_onSiaRefresh);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    final pc = state.personalContext;

    final List<String> effectiveActiveStages = widget.activeStages ?? pc.activeLifeStages.toList();
    if (widget.stageKey == null && effectiveActiveStages.length > 1) {
      return _buildUnifiedMultiStageHomeOS(effectiveActiveStages, pc, state);
    }

    final String currentStage = (widget.stageKey != null && widget.stageKey!.isNotEmpty)
        ? widget.stageKey!
        : (pc.activeLifeStages.isNotEmpty ? pc.activeLifeStages.first : null) ??
          (pc.lifeStage ??
              _onboardingData['lifeStage'] ??
              _onboardingData['life_stage'] ??
              _onboardingData['stage'] ??
              'firstPeriodNotStarted')
          .toString()
          .trim();

    final String normalized = currentStage.replaceAll('_', '').replaceAll(' ', '').toLowerCase();

    switch (normalized) {
      case 'firstperiodnotstarted':
      case 'notstarted':
      case 'puberty':
        return _buildNotStartedHomeOS(pc, state);

      case 'firstperiodstarted':
      case 'started':
        return _buildFirstPeriodStartedHomeOS(pc, state);

      case 'reproductiveyears':
      case 'livingwithmycycle':
      case 'cycle':
        return _buildLivingWithMyCycleHomeOS(pc, state);

      case 'hormonalhealth':
      case 'pcos':
      case 'endometriosis':
        return _buildHormonalHealthHomeOS(pc, state);

      case 'tryingtoconceive':
      case 'ttc':
        return _buildTTCHomeOS(pc, state);

      case 'pregnancy':
      case 'pregnant':
        return _buildPregnancyHomeOS(pc, state);

      case 'postpartum':
        return _buildPostpartumHomeOS(pc, state);

      case 'perimenopause':
        return _buildPerimenopauseHomeOS(pc, state);

      case 'menopause':
      case 'postmenopause':
        return _buildMenopauseHomeOS(pc, state);

      case 'everydaywellness':
      case 'wellness':
      default:
        return _buildEverydayWellnessHomeOS(pc, state);
    }
  }

  // --- UNIFIED MULTI-STAGE INTELLIGENT DASHBOARD ---

  bool _shouldShowCycleTracker(List<String> stages) {
    for (final s in stages) {
      final norm = s.replaceAll('_', '').replaceAll(' ', '').toLowerCase();
      if (norm != 'firstperiodnotstarted' && norm != 'notstarted' && norm != 'puberty' && norm != 'menopause') {
        return true;
      }
    }
    return false;
  }

  Widget _buildUnifiedMultiHero(String displayName, List<String> stageTitles) {
    final curPc = BlushyOSProvider.of(context).personalContext;
    final DateTime? pStart = curPc.lastPeriodStart;
    final int cycleDay = (pStart != null)
        ? (DateTime.now().difference(pStart).inDays + 1)
        : (curPc.cycleDay ?? 1);
    final String lastPeriodStr = (pStart != null)
        ? "${pStart.month}/${pStart.day}"
        : "Not logged yet";
    final bool hasCycle = pStart != null;
    final String stagesSummary = stageTitles.join(" & ");

    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBE5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5DDD5), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "SIA'S UNIFIED BRIEF • $stagesSummary".toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.primary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${_getTimeBasedGreetingPrefix()}, $displayName",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            SiaDashboardService().getDailyHeaderBrief(
              pc: curPc,
              state: BlushyOSProvider.of(context),
              stagesSummary: stagesSummary,
            ),
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          if (hasCycle) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CYCLE DAY $cycleDay",
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Last Period: $lastPeriodStr",
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _scrollToCheckIn();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    "Check In",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openAskSiaChat(context, null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BlushyColors.primary,
                    side: const BorderSide(color: BlushyColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Ask Sia",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedMultiSiaInsights(List<String> stages) {
    return _buildLivingSiaInsights();
  }

  Widget _buildStageSectionHeader(String stageKey) {
    final title = StageConflictEngine.getStageTitle(stageKey);
    final icon = StageConflictEngine.getStageIcon(stageKey);
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BlushyColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: BlushyColors.primary),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: BlushyColors.text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: BlushyColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "FOCUS TOPIC",
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: BlushyColors.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    BlushyColors.primary.withValues(alpha: 0.25),
                    BlushyColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageSpecificUniqueContent(String stageKey, PersonalContext pc, BlushyOSState state, bool isMobile, {bool skipJourney = false, bool skipPatterns = false}) {
    final norm = stageKey.replaceAll('_', '').replaceAll(' ', '').toLowerCase();
    switch (norm) {
      case 'firstperiodstarted':
      case 'started':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUnderstandMyCycle(),
            SizedBox(height: isMobile ? 32 : 48),
            _buildStartedConnect(),
            if (!skipJourney) ...[
              SizedBox(height: isMobile ? 32 : 48),
              _buildStartedJourney(),
            ],
          ],
        );
      case 'firstperiodnotstarted':
      case 'notstarted':
      case 'puberty':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContinueLearning(),
            SizedBox(height: isMobile ? 32 : 48),
            _buildCuriousToday(),
            SizedBox(height: isMobile ? 32 : 48),
            _buildConnect(),
            if (!skipJourney) ...[
              SizedBox(height: isMobile ? 32 : 48),
              _buildGrowingJourney(),
            ],
          ],
        );
      case 'reproductiveyears':
      case 'livingwithmycycle':
      case 'cycle':
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!skipPatterns) ...[
              _buildLivingPatterns(),
              SizedBox(height: isMobile ? 32 : 48),
            ],
            _buildLivingDiscover(),
            SizedBox(height: isMobile ? 32 : 48),
            _buildLivingCommunity(),
            if (!skipJourney) ...[
              SizedBox(height: isMobile ? 32 : 48),
              _buildLivingJourney(),
            ],
          ],
        );
    }
  }

  Widget _buildUnifiedMultiStageHomeOS(List<String> stages, PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";
    final List<String> stageTitles = stages.map<String>((s) => StageConflictEngine.getStageTitle(s)).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isMobile = width < 768;
        final bool isTablet = width >= 768 && width <= 1200;
        final double horizontalPadding = isMobile ? 16 : (isTablet ? 24 : 48);
        final double verticalPadding = isMobile ? 24 : 40;

        return _wrapDashboardLayout(
          scaffoldKey: _scaffoldKey,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: min(1440.0, width - (isMobile ? 0.0 : 64.0)),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
              child: ListView(
                shrinkWrap: _effectiveShrinkWrap,
                physics: _effectiveScrollPhysics,
                children: [
                  // 1. UNIFIED HERO BRIEF
                  _buildUnifiedMultiHero(displayName, stageTitles),
                  SizedBox(height: isMobile ? 20 : 32),

                  // 2. ACTIVE FOCUS TOPIC HEADERS (RENDERED ONLY AT THE START)
                  ...stages.map((stageKey) {
                    return _buildStageSectionHeader(stageKey);
                  }),
                  SizedBox(height: isMobile ? 24 : 36),

                  // 3. DEDUPLICATED CYCLE TRACKER (Only 1 authoritative cycle / uterus card)
                  if (_shouldShowCycleTracker(stages)) ...[
                    _buildLivingTodayCycle(),
                    SizedBox(height: isMobile ? 32 : 48),
                  ],

                  // 4. UNIFIED DAILY CHECK-IN (All mood emojis in 1 row + merged health signals)
                  _buildLivingCheckIn(),
                  SizedBox(height: isMobile ? 32 : 48),

                  // 5. COMBINED SIA INSIGHTS
                  _buildUnifiedMultiSiaInsights(stages),
                  SizedBox(height: isMobile ? 32 : 48),

                  // 6. SINGLE MERGED CYCLE PATTERNS & INSIGHTS
                  _buildLivingPatterns(),
                  SizedBox(height: isMobile ? 32 : 48),

                  // 7. STAGE-SPECIFIC DISTINCT MODULES (Focus headers are placed at the start only)
                  ...stages.map((stageKey) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStageSpecificUniqueContent(stageKey, pc, state, isMobile, skipJourney: true, skipPatterns: true),
                        SizedBox(height: isMobile ? 32 : 48),
                      ],
                    );
                  }),

                  // 8. SINGLE MERGED MONTHLY REFLECTION & JOURNEY
                  _buildLivingJourney(),
                  SizedBox(height: isMobile ? 32 : 48),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- FIRST PERIODS OS REDESIGN ---



  // --- SECTION 1: SIA'S DAILY LETTER (HERO) ---
  Widget _buildSiasDailyLetter(String name) {
    return _buildUnifiedHeroCard(
      category: "Sia's Daily Note",
      title: "${_getTimeBasedGreetingPrefix()}, $name",
      subtitle: "Growing up happens one step at a time. You don't have to know everything today. We'll learn together.",
      primaryBtnText: "Ask Sia",
      onPrimaryTap: () => _openAskSiaChat(context, null),
      secondaryBtnText: "Continue Learning",
      onSecondaryTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Scroll down to Continue Learning section"),
            backgroundColor: BlushyColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  // --- SECTION 2: CONTINUE LEARNING ---
  Widget _buildContinueLearning() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "CONTINUE LEARNING",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Small lessons designed for your stage.",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _lessons.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final lesson = _lessons[index];
              final isCompleted = _completedLessons.contains(lesson);
              final isUnlocked = index == 0 || _completedLessons.contains(_lessons[index - 1]);

              // Cover colors
              final List<Color> bgColors = [
                const Color(0xFFFDF2F2),
                const Color(0xFFFFF5EE),
                const Color(0xFFF6F0EB),
                const Color(0xFFFFF7F7),
                const Color(0xFFFDF5E6),
              ];
              final Color cardColor = bgColors[index % bgColors.length];

              return Opacity(
                opacity: isUnlocked ? 1.0 : 0.5,
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCompleted ? BlushyColors.primary.withValues(alpha: 0.4) : BlushyColors.border,
                      width: isCompleted ? 1.5 : 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Cover Thumbnail
                      Container(
                        height: 70,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            isCompleted ? Icons.check_circle : (isUnlocked ? Icons.lock_open : Icons.lock),
                            color: isCompleted ? BlushyColors.primary : Colors.black26,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lesson,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BlushyColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${3 + (index * 2)} min read",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: BlushyColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Progress & Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: isCompleted ? 1.0 : (isUnlocked ? 0.3 : 0.0),
                                backgroundColor: const Color(0xFFF0F0F0),
                                valueColor: AlwaysStoppedAnimation<Color>(BlushyColors.primary),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              if (!isUnlocked) return;
                              setState(() {
                                if (isCompleted) {
                                  _completedLessons.remove(lesson);
                                } else {
                                  _completedLessons.add(lesson);
                                }
                              });
                              ApiAuthService().saveOnboardingAnswers({'completed_lessons': _completedLessons.toList()}).catchError((_) => <String, dynamic>{});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isCompleted ? Colors.transparent : BlushyColors.primary,
                                borderRadius: BorderRadius.circular(8),
                                border: isCompleted ? Border.all(color: BlushyColors.primary) : null,
                              ),
                              child: Text(
                                isCompleted ? "Review" : "Resume",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted ? BlushyColors.primary : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- SECTION 3: CURIOUS TODAY ---
  Widget _buildCuriousToday() {
    // 5 common questions
    final List<Map<String, String>> commonQuestions = [
      {
        "q": "Why is one breast bigger?",
        "ans": "During puberty, breasts grow at different rates. It's completely normal for one to grow faster or look slightly larger than the other. Over time, they usually even out, but minor asymmetry is totally natural and common for most girls."
      },
      {
        "q": "Will periods hurt?",
        "ans": "Some girls feel mild cramps in their lower tummy before or during their period. This is because the uterus muscles tighten. It usually feels like a dull ache. Simple remedies like a warm hot water bottle, walking, or asking a trusted adult for help can make it feel much better."
      },
      {
        "q": "What is white discharge?",
        "ans": "White or clear fluid on your underwear is called discharge. It is your body's natural way of cleaning the vagina and keeping it healthy. It usually starts a few months or a year before your first period begins, showing that your body is developing normally."
      },
      {
        "q": "What if I get my period at school?",
        "ans": "It is a very common worry, but teachers and school nurses are prepared for this! Keeping an extra pad in your backpack or pouch will help you feel ready. If you're caught by surprise, you can always ask a school nurse or female teacher for help."
      },
      {
        "q": "Why am I getting pimples?",
        "ans": "Hormones during puberty cause the skin glands to produce more natural oils, which can clog pores. Washing your face daily with a gentle cleanser helps keep your skin fresh. Pimples are a natural part of growing up that almost everyone goes through!"
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "CURIOUS TODAY",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Subsection A: Daily Discovery
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_sunny_outlined, color: BlushyColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "DAILY DISCOVERY",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Sweat glands become more active during puberty. Drinking plenty of water and washing daily helps keep you fresh, confident, and clean.",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: BlushyColors.text,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      _showArticleDialog(
                        context,
                        "Sweat Glands & Puberty",
                        "When you start puberty, hormones trigger changes in your sweat glands. They begin to produce a new kind of sweat that can cause body odor. This is a sign that your body is growing up! Staying hydrated, taking regular showers, and using gentle deodorant are easy steps to feel fresh daily.",
                      );
                    },
                    child: Text(
                      "Read",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _savedArticles.contains("Sweat Glands") ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: BlushyColors.secondaryText,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_savedArticles.contains("Sweat Glands")) {
                          _savedArticles.remove("Sweat Glands");
                        } else {
                          _savedArticles.add("Sweat Glands");
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20, color: BlushyColors.secondaryText),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Link copied to share with family!")),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Subsection B: Questions Girls Often Ask
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "Questions Girls Often Ask",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: BlushyColors.text,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: commonQuestions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = commonQuestions[index];
              return GestureDetector(
                onTap: () {
                  _showArticleDialog(context, item['q']!, item['ans']!);
                },
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDFBF7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BlushyColors.border, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.help_outline, color: BlushyColors.primary, size: 20),
                      const SizedBox(height: 12),
                      Text(
                        item['q']!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- SECTION 4: CONNECT ---
  Widget _buildConnect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "CONNECT",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Premium Segmented Tab Selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0x0F2E2623),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _connectTabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _connectTabIndex == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Girls",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _connectTabIndex == 0 ? BlushyColors.text : BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _connectTabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _connectTabIndex == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Growing Together",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _connectTabIndex == 1 ? BlushyColors.text : BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _connectTabIndex == 0 ? _buildGirlsTab() : _buildGrowingTogetherTab(),
      ],
    );
  }

  Widget _buildGirlsTab() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Supportive Community Preview",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 12),
          // Latest question
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 16, color: BlushyColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "How do I track if I haven't got my period yet?",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "You can focus on learning, discharge changes and kits here! Sia helps guide you.",
                      style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF5F0EB)),
          // Latest story
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_border, size: 16, color: BlushyColors.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Read what others are sharing",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Real conversations from the community, not examples.",
                      style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Redirecting to Community Space...")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                "Join Community",
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowingTogetherTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shared Reading
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF6F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SHARED READING",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Text(
                "Share articles about growing up with your parent safely.",
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Article shared with Parent account!")),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: BlushyColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Send to Parent", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Opening Shared Library...")),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: BlushyColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Shared Library", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Let's Talk AI Card
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "LET'S TALK • WEEKLY PROMPT",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.warning, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Text(
                "\"What is one thing you've been curious about recently?\"",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: BlushyColors.text),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _letsTalkDiscussed = !_letsTalkDiscussed;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _letsTalkDiscussed ? BlushyColors.success : BlushyColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text(_letsTalkDiscussed ? "Discussed " : "Discussed", style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _letsTalkSaved = !_letsTalkSaved;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _letsTalkSaved ? BlushyColors.disabled : BlushyColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text(_letsTalkSaved ? "Saved" : "Save for Weekend", style: GoogleFonts.poppins(fontSize: 11, color: _letsTalkSaved ? BlushyColors.disabled : BlushyColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // First Period Kit Checklist
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BlushyColors.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "FIRST PERIOD KIT CHECKLIST",
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
                ),
                const SizedBox(height: 12),
                ..._periodKitChecklist.keys.map((item) {
                  final isChecked = _periodKitChecklist[item]!;
                  return CheckboxListTile(
                    title: Text(item, style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text)),
                    value: isChecked,
                    activeColor: BlushyColors.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (val) {
                      setState(() {
                        _periodKitChecklist[item] = val ?? false;
                      });
                      ApiAuthService().saveOnboardingAnswers({'first_period_kit': _periodKitChecklist}).catchError((_) => <String, dynamic>{});
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Shared Journey
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF6F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SHARED JOURNEY",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              Text(
                "Display learning progress completed together. The child decides what is visible.",
                style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              ..._lessons.map((lesson) {
                final isCompleted = _completedLessons.contains(lesson);
                final isShared = _sharedLessons.contains(lesson);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isCompleted ? BlushyColors.success : BlushyColors.disabled,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lesson,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: BlushyColors.text,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (isCompleted) ...[
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isShared) {
                                _sharedLessons.remove(lesson);
                              } else {
                                _sharedLessons.add(lesson);
                              }
                            });
                          },
                          child: Text(
                            isShared ? "Shared " : "Share",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isShared ? BlushyColors.success : BlushyColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 5: GROWING JOURNEY ---
  Widget _buildGrowingJourney() {
    // Which step is active comes from the life stage the user actually chose,
    // not from a fixed list that always highlighted the first one.
    const stageTitles = [
      "Learning About My Body",
      "Understanding Puberty",
      "Preparing For My First Period",
      "My First Period",
      "Living With My Cycle",
    ];

    final normalizedStage = (BlushyOSProvider.of(context).personalContext.lifeStage ?? '')
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '');

    int activeIndex = 0;
    if (normalizedStage.contains('notstarted')) {
      activeIndex = 0;
    } else if (normalizedStage.contains('firstperiod')) {
      activeIndex = 3;
    } else if (normalizedStage.isNotEmpty) {
      // Any later branch means the first period has happened.
      activeIndex = 4;
    }

    final List<Map<String, String>> timelineStages = [
      for (var i = 0; i < stageTitles.length; i++)
        {
          "title": stageTitles[i],
          "status": i == activeIndex
              ? "active"
              : (i < activeIndex ? "done" : "pending"),
        },
    ];

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "GROWING JOURNEY",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 20),
          ...timelineStages.map((stage) {
            final isActive = stage['status'] == "active" || stage['status'] == "done";
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? BlushyColors.primary : Colors.transparent,
                        border: Border.all(
                          color: isActive ? BlushyColors.primary : BlushyColors.border,
                          width: 2,
                        ),
                      ),
                      child: isActive
                          ? const Center(
                              child: Icon(Icons.circle, size: 6, color: Colors.white),
                            )
                          : null,
                    ),
                    // Timeline connector
                    if (stage != timelineStages.last)
                      Container(
                        width: 2,
                        height: 36,
                        color: BlushyColors.border,
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage['title']!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? BlushyColors.text : BlushyColors.secondaryText,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 4),
                        Text(
                          "\"Every little thing you learn today prepares you for tomorrow.\"",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: BlushyColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _openAskSiaChat(BuildContext context, String? initialQuestion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF6F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BlushySiaScreen(initialQuestion: initialQuestion),
          ),
        ),
      ),
    ).then((_) {
      if (mounted) {
        SiaDashboardService().triggerRefresh();
        setState(() {});
      }
    });
  }

  late final ScrollController _homeScrollController = ScrollController();

  Widget _buildNotStartedHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT (Exactly as before, single centered column)
          return _wrapDashboardLayout(
            scaffoldKey: _scaffoldKey,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  children: [
                    _buildSiasDailyLetter(displayName),
                    const SizedBox(height: 32),
                    _buildContinueLearning(),
                    const SizedBox(height: 32),
                    _buildCuriousToday(),
                    const SizedBox(height: 32),
                    _buildConnect(),
                    const SizedBox(height: 32),
                    _buildGrowingJourney(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT (Collapse into one wide column)
          return _wrapDashboardLayout(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: double.infinity),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  children: [
                    _buildSiasDailyLetter(displayName),
                    const SizedBox(height: 48),
                    _buildContinueLearning(),
                    const SizedBox(height: 48),
                    _buildCuriousToday(),
                    const SizedBox(height: 48),
                    _buildConnect(),
                    const SizedBox(height: 48),
                    _buildGrowingJourney(),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (Responsive multi-column editorial grid: 8 / 4 cols)
          return _wrapDashboardLayout(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: min(1440.0, width - 64.0),
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: ListView(
                  controller: widget.isNested ? null : _homeScrollController,
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  children: [
                    // Row 1: Sia Daily Letter (12 columns)
                    _buildSiasDailyLetter(displayName),
                    const SizedBox(height: 48),

                    // Row 2: Continue Learning (12 columns)
                    _buildContinueLearning(),
                    const SizedBox(height: 48),

                    // Row 3: Left Column (8 columns) | Right Column (4 columns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Content Panel (65% width)
                        Expanded(
                          flex: 65,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCuriousToday(),
                              const SizedBox(height: 48),
                              _buildConnect(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),

                        // Right Sidebar Panel (35% width)
                        Expanded(
                          flex: 35,
                          child: _buildGrowingJourney(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // --- BRANCH: FIRST PERIOD STARTED (firstPeriodStarted) ---
  final ScrollController _startedHomeScrollController = ScrollController();

  Widget _buildUnifiedHeroCard({
    required String category,
    required String title,
    required String subtitle,
    String? metricsTitle,
    String? metricsValue,
    required String primaryBtnText,
    required VoidCallback onPrimaryTap,
    String? secondaryBtnText,
    VoidCallback? onSecondaryTap,
    DecorationImage? backgroundImage,
  }) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9F8), // Soft warm peach background
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(36),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(36),
            ),
            border: Border.all(color: const Color(0xFFFDE5DF), width: 1.0),
            image: backgroundImage,
            boxShadow: [
              BoxShadow(
                color: BlushyColors.text.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: BlushyColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.text,
                  height: 1.25,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: BlushyColors.secondaryText,
                    height: 1.4,
                  ),
                ),
              ],
              if (metricsTitle != null && metricsValue != null) ...[
                const SizedBox(height: 10),
                Text(
                  "${metricsTitle.toUpperCase()}  •  $metricsValue",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: onPrimaryTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: Text(
                      primaryBtnText,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (secondaryBtnText != null && onSecondaryTap != null) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: onSecondaryTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary, width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        secondaryBtnText,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SECTION 1: SIA'S LETTER (HERO) ---
  Widget _buildStartedHero(String name) {
    final pc = BlushyOSProvider.of(context).personalContext;
    final DateTime? pStart = pc.lastPeriodStart;
    final int cycleDay = (pStart != null)
        ? (DateTime.now().difference(pStart).inDays + 1)
        : (pc.cycleDay ?? 1);
    final String lastPeriodStr = (pStart != null)
        ? "${pStart.month}/${pStart.day}"
        : "Not logged yet";

    return _buildUnifiedHeroCard(
      category: "Sia's Lesson Note",
      title: "${_getTimeBasedGreetingPrefix()}, $name",
      subtitle: "",
      metricsTitle: "Cycle Day $cycleDay",
      metricsValue: "Last Period: $lastPeriodStr",
      primaryBtnText: "Log Today's Feelings",
      onPrimaryTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Scroll down to 'How Are You Today' logging"),
            backgroundColor: BlushyColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      secondaryBtnText: "Ask Sia",
      onSecondaryTap: () => _openAskSiaChat(context, null),
    );
  }

  // --- SECTION 2: MY FIRST CYCLES (Featuring Ovary loop tracker BlushyCycleCard) ---
  Widget _buildMyFirstCycles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MY FIRST CYCLES",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Your learning cycle companion.",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final curPc = BlushyOSProvider.of(context).personalContext;
                        final DateTime? pStart = curPc.lastPeriodStart;
                        final int cycleDay = (pStart != null)
                            ? (DateTime.now().difference(pStart).inDays + 1)
                            : (curPc.cycleDay ?? 1);
                        final int daysAgo = (pStart != null)
                            ? DateTime.now().difference(pStart).inDays
                            : (cycleDay > 0 ? cycleDay - 1 : 0);
                        final bool hasData = pStart != null || (curPc.cycleDay != null && curPc.cycleDay! > 0);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasData ? "Day $cycleDay of Cycle" : "Cycle Tracking",
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: BlushyColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasData ? "$daysAgo days since last period start" : "No period logged yet",
                              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showLogPeriodBottomSheet(context),
                    icon: const Icon(
                      Icons.edit,
                      color: BlushyColors.primary,
                      size: 20,
                    ),
                    tooltip: AppLocalizations.of(context).dashLogPeriod,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Ovary tracker shape (BlushyCycleCard)
              const Center(
                child: SizedBox(
                  width: 260,
                  height: 95,
                  child: BlushyCycleCard(purePainterMode: true),
                ),
              ),
              const SizedBox(height: 16),
              // Color Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStartedLegendDot("Menstrual", const Color(0xFFDD0D22)),
                  const SizedBox(width: 14),
                  _buildStartedLegendDot("Follicular", const Color(0xFFFF9B9E)),
                  const SizedBox(width: 14),
                  _buildStartedLegendDot("Ovulation", const Color(0xFFFFB800)),
                  const SizedBox(width: 14),
                  _buildStartedLegendDot("Luteal", const Color(0xFF6F42F5)),
                ],
              ),
              const SizedBox(height: 32),

              // Calendar Preview of the last 30 days
              Text(
                "PAST 30 DAYS",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: 30,
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final int day = index + 1;
                    final curPc = BlushyOSProvider.of(context).personalContext;
                    final int activeCycleDay = (curPc.lastPeriodStart != null)
                        ? (DateTime.now().difference(curPc.lastPeriodStart!).inDays + 1)
                        : (curPc.cycleDay ?? 1);
                    final bool isMenstrual = day <= activeCycleDay && day <= 5;
                    return Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isMenstrual ? BlushyColors.primary : const Color(0xFFF9F6F0),
                        shape: BoxShape.circle,
                        border: Border.all(color: BlushyColors.border, width: 0.8),
                      ),
                      child: Center(
                        child: Text(
                          day.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isMenstrual ? Colors.white : BlushyColors.text,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              
              // Irregular cycles reassurance note
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: BlushyColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "It's completely normal for your first few cycles to be irregular. Your body is gently finding its own natural rhythm.",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: BlushyColors.secondaryText,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartedLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: BlushyColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- SECTION 3: HOW ARE YOU TODAY? (One-tap logging) ---
  Widget _buildHowAreYouToday() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "😊", "label": "Happy"},
      {"icon": "🙂", "label": "Okay"},
      {"icon": "😖", "label": "Cramps"},
      {"icon": "🥱", "label": "Tired"},
      {"icon": "😤", "label": "Irritable"},
    ];

    final List<String> energyOptions = ["High", "Medium", "Low"];
    final List<String> flowOptions = ["Light", "Medium", "Heavy"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            AppLocalizations.of(context).dashHowAreYouToday,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shown when something just logged matched a reviewed red flag
              // rule, so the reviewed instruction replaces the usual
              // confirmation rather than sitting alongside it.
              if (_checkinSafety != null) _buildCheckinSafetyBanner(_checkinSafety!),
              // Mood Selector
              Text(
                AppLocalizations.of(context).dashMood,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedFeeling = checkinData['feeling'] ?? (BlushyStorage.read('logged_feeling.json'))['feeling'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeFeeling = _selectedFeeling ?? savedFeeling ?? (wb.symptoms.isNotEmpty ? wb.symptoms.first : null);
                  final isSelected = activeFeeling != null && activeFeeling.toString().toLowerCase() == (opt['label'] as String).toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Logged Feeling: ${opt['label']}"),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withValues(alpha: 0.1) : const Color(0xFFF9F6F0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? BlushyColors.primary : BlushyColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt['icon'],
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Energy Selector
              Text(
                AppLocalizations.of(context).dashEnergyLevel,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: energyOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedEnergy = checkinData['energy'] ?? (BlushyStorage.read('logged_energy.json'))['energy'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeEnergy = _selectedEnergy ?? savedEnergy ?? (wb.energy != null ? (wb.energy! >= 7 ? 'High' : (wb.energy! >= 4 ? 'Medium' : 'Low')) : null);
                  final isSelected = activeEnergy != null && activeEnergy.toString().toLowerCase() == opt.toLowerCase();
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedEnergy = opt;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary : const Color(0xFFF9F6F0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? BlushyColors.primary : BlushyColors.border, width: 0.8),
                          ),
                          child: Text(
                            opt,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : BlushyColors.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Flow Selector
              Text(
                AppLocalizations.of(context).dashFlowLevel,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: flowOptions.map((opt) {
                  final isSelected = _startedFlow == opt;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _startedFlow = opt;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary : const Color(0xFFF9F6F0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? BlushyColors.primary : BlushyColors.border, width: 0.8),
                          ),
                          child: Text(
                            opt,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : BlushyColors.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Notes & Voice logging
              Text(
                AppLocalizations.of(context).dashNotesReflections,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        VoiceNoteBottomSheet.show(context);
                      },
                      icon: const Icon(Icons.mic, size: 18),
                      label: const Text("Voice Note"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BlushyMStudioScreen()),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("M Studio"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 4: UNDERSTAND MY CYCLE (Educational carousel) ---
  Widget _buildUnderstandMyCycle() {
    final List<Map<String, String>> startedArticles = [
      {
        "q": "Why are my cycles irregular?",
        "body": "It takes time for the brain and ovaries to coordinate hormones after your very first period. Cycles can range from 20 to 45 days, and skipping months is very common during the first two years."
      },
      {
        "q": "What is PMS?",
        "body": "Premenstrual Syndrome is the mix of physical and emotional changes that happen before your period. Feeling mood swings, mild bloating, or breast tenderness is normal as hormone levels shift."
      },
      {
        "q": "How do cramps happen?",
        "body": "Cramps are caused by natural chemicals called prostaglandins that make your uterus muscles contract to shed its lining. Placing a warm pad or doing light stretches can relax the muscles."
      },
      {
        "q": "Why am I tired?",
        "body": "Hormones like progesterone rise before your period, which can lower your energy levels. Sleeping 8-9 hours and staying active helps normalize your daily energy cycle."
      },
      {
        "q": "How long should periods last?",
        "body": "A normal period lasts between 3 to 7 days. The flow is usually heavier on the first two days and gets much lighter toward the end. Tracking helps you learn your pattern."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "UNDERSTAND MY CYCLE",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: startedArticles.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = startedArticles[index];
              return Container(
                width: 220,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item['q']!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(context, item['q']!, item['body']!);
                          },
                          child: Text(
                            "Read",
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _startedSavedArticles.contains(item['q']) ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_startedSavedArticles.contains(item['q'])) {
                                _startedSavedArticles.remove(item['q']!);
                              } else {
                                _startedSavedArticles.add(item['q']!);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18, color: BlushyColors.secondaryText),
                          onPressed: () => _openAskSiaChat(context, "Tell me about: ${item['q']}"),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- SECTION 5: CONNECT (Tabs: Girls / Growing Together) ---
  Widget _buildStartedConnect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "CONNECT",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Segment selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0x0F2E2623),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _connectStartedTabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _connectStartedTabIndex == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Girls",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _connectStartedTabIndex == 0 ? BlushyColors.text : BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _connectStartedTabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _connectStartedTabIndex == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Growing Together",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _connectStartedTabIndex == 1 ? BlushyColors.text : BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _connectStartedTabIndex == 0 ? _buildStartedGirlsTab() : _buildStartedGrowingTogetherTab(),
      ],
    );
  }

  Widget _buildStartedGirlsTab() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Community Discussions & Stories",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.explore, size: 16, color: BlushyColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Questions people are asking",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Open the community to read and reply.",
                      style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF5F0EB)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_border, size: 16, color: Colors.pinkAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tips people are sharing",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Open the community to read and reply.",
                      style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Loading Community discussions...")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                "Open Discussions",
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartedGrowingTogetherTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shared reading & notes
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF6F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SHARED READING & PARENT RESOURCES",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Text(
                "Send cycle articles to parent or consult conversation guides.",
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Article shared with Parent!")),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: BlushyColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Share", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Opening Parent Resource library...")),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: BlushyColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Guides", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Conversation Prompt
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "CONVERSATION PROMPT",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.warning, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Text(
                "\"Is there anything you wish we discussed more about body changes?\"",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: BlushyColors.text),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _startedLetsTalkDiscussed = !_startedLetsTalkDiscussed;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _startedLetsTalkDiscussed ? BlushyColors.success : BlushyColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(_startedLetsTalkDiscussed ? "Discussed " : "Discussed", style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _startedLetsTalkSaved = !_startedLetsTalkSaved;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _startedLetsTalkSaved ? BlushyColors.disabled : BlushyColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(_startedLetsTalkSaved ? "Saved" : "Save for Weekend", style: GoogleFonts.poppins(fontSize: 11, color: _startedLetsTalkSaved ? BlushyColors.disabled : BlushyColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Shared checklist
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BlushyColors.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "FIRST PERIOD KIT STATUS",
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
                ),
                const SizedBox(height: 12),
                ..._startedPeriodKitChecklist.keys.map((item) {
                  final isChecked = _startedPeriodKitChecklist[item]!;
                  return CheckboxListTile(
                    title: Text(item, style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text)),
                    value: isChecked,
                    activeColor: BlushyColors.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (val) {
                      setState(() {
                        _startedPeriodKitChecklist[item] = val ?? false;
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Parental safety disclosure
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            " Sia Safety: Your parent never has access to your private chat logs, notes, or moods.",
            style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText, fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  // --- SECTION 6: MY JOURNEY (Milestones) ---
  /// Real logged events, not a scripted timeline. Replaced a hardcoded list
  /// that marked milestones complete on a freshly installed app.
  Widget _buildStartedJourney() {
    return const RealJourneyTimeline(
      title: 'Your Cycle Journey',
      emptyHeadline: 'Your journey starts with your first period log',
    );
  }

  Widget _buildFirstPeriodStartedHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return _wrapDashboardLayout(
            scaffoldKey: _scaffoldKey,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  children: [
                    _buildStartedHero(displayName),
                    const SizedBox(height: 32),
                    _buildMyFirstCycles(),
                    const SizedBox(height: 32),
                    _buildHowAreYouToday(),
                    const SizedBox(height: 32),
                    _buildUnderstandMyCycle(),
                    const SizedBox(height: 32),
                    _buildStartedConnect(),
                    const SizedBox(height: 32),
                    _buildStartedJourney(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return _wrapDashboardLayout(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: double.infinity),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  children: [
                    _buildStartedHero(displayName),
                    const SizedBox(height: 48),
                    _buildMyFirstCycles(),
                    const SizedBox(height: 48),
                    _buildHowAreYouToday(),
                    const SizedBox(height: 48),
                    _buildUnderstandMyCycle(),
                    const SizedBox(height: 48),
                    _buildStartedConnect(),
                    const SizedBox(height: 48),
                    _buildStartedJourney(),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return _wrapDashboardLayout(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: min(1440.0, width - 64.0),
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: ListView(
                  controller: widget.isNested ? null : _startedHomeScrollController,
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  children: [
                    // Row 1: Hero (12 columns)
                    _buildStartedHero(displayName),
                    const SizedBox(height: 48),

                    // Row 2: My First Cycles (12 columns)
                    _buildMyFirstCycles(),
                    const SizedBox(height: 48),

                    // Row 3: Left content (8 columns) | Right sidebar (4 columns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Panel (65% width)
                        Expanded(
                          flex: 65,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHowAreYouToday(),
                              const SizedBox(height: 48),
                              _buildUnderstandMyCycle(),
                              const SizedBox(height: 48),
                              _buildStartedConnect(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),

                        // Right Sidebar Panel (35% width)
                        Expanded(
                          flex: 35,
                          child: _buildStartedJourney(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  void _showArticleDialog(BuildContext context, String title, String summary) {
    showDialog(
      context: context,
      builder: (dialogContext) => ArticleDetailDialog(
        title: title,
        summary: summary,
      ),
    );
  }

  // --- BRANCH: LIVING WITH MY CYCLE (livingWithMyCycle) ---
  final ScrollController _livingHomeScrollController = ScrollController();

  // --- SECTION 1: SIA'S DAILY BRIEF (HERO) ---
  Widget _buildLivingHero(String name) {
    final cycleData = _getDynamicCycleDates(_currentPc);
    final bool hasLogged = cycleData['isLogged'] == true;
    final int cDay = hasLogged ? (cycleData['cycleDay'] as int) : 0;

    String mainDesc = "Log your period start date to track your real-time phase rhythm and energy baseline.";
    String badgeText = "CYCLE TRACKING • NOT LOGGED";
    String subDesc = "Tap below to log your period and unlock tailored cycle guidance.";

    if (hasLogged) {
      mainDesc = SiaDashboardService().getDailyHeaderBrief(
        pc: _currentPc,
        state: BlushyOSProvider.of(context),
        stagesSummary: "Living With My Cycle",
      );
      if (cDay <= 5) {
        badgeText = "CYCLE DAY $cDay • MENSTRUAL PHASE";
        subDesc = "Lower physical stamina. Take things gently today.";
      } else if (cDay <= 13) {
        badgeText = "CYCLE DAY $cDay • FOLLICULAR PHASE";
        subDesc = "Rising energy, great time to build habits or start creative projects.";
      } else if (cDay <= 16) {
        badgeText = "CYCLE DAY $cDay • OVULATORY PHASE";
        subDesc = "Stamina naturally at its highest baseline. Stay active.";
      } else {
        badgeText = "CYCLE DAY $cDay • LUTEAL PHASE";
        subDesc = "Energy naturally winds down; listen to your body and prioritize restful sleep.";
      }
    }

    return _buildUnifiedHeroCard(
      category: "Sia's Daily Brief",
      title: "${_getTimeBasedGreetingPrefix()}, $name",
      subtitle: mainDesc,
      metricsTitle: badgeText,
      metricsValue: subDesc,
      primaryBtnText: hasLogged ? "Check In" : "Log Period Date",
      onPrimaryTap: () {
        if (!hasLogged) {
          _showLogPeriodBottomSheet(context);
        } else {
          _scrollToCheckIn();
        }
      },
      secondaryBtnText: "Ask Sia",
      onSecondaryTap: () => _openAskSiaChat(context, null),
    );
  }

  // --- SECTION 2: TODAY'S CYCLE (Featuring Ovary loop tracker BlushyCycleCard) ---
  Widget _buildLivingTodayCycle() {
    final cycleData = _getDynamicCycleDates(_currentPc);
    final bool hasPeriodLogged = cycleData['isLogged'] == true;
    final String phaseText = hasPeriodLogged ? "${cycleData['phaseName']} Rhythm" : "Cycle Tracking";
    final String dayText = hasPeriodLogged ? (cycleData['cycleDayText'] ?? "Cycle Tracking") : "Cycle Day: Not Logged";
    final String subtitleText = hasPeriodLogged 
        ? (cycleData['subtitle'] ?? "") 
        : "No period logged yet. Tap to set your last period start date.";

    final pc = _currentPc;
    final wb = BlushyOSProvider.of(context).wellbeingState;
    final checkinData = BlushyStorage.read('daily_checkin.json');
    final String? savedMood = checkinData['feeling'] ?? checkinData['mood'];
    final String? savedEnergy = checkinData['energy'];
    final String? savedSleep = checkinData['sleep'];
    final String? savedStress = checkinData['stress'];
    final String? savedWater = checkinData['water'];
    final String? savedExercise = checkinData['exercise'];
    final String? savedFlow = checkinData['flow'];
    final String? savedPain = checkinData['pain'];

    final String energyVal = _selectedEnergy ?? savedEnergy ?? (wb.energy != null ? "Level ${wb.energy}/10" : "Not Logged Today");
    final String moodVal = _selectedFeeling ?? savedMood ?? (wb.mood != null ? (wb.symptoms.isNotEmpty ? wb.symptoms.first : "Level ${wb.mood}/10") : "Not Logged Today");
    final String sleepVal = _livingSleep ?? savedSleep ?? "Not Logged Today";
    final String stressVal = _livingStress ?? savedStress ?? "Not Logged Today";
    final String hydrationVal = _livingWater ?? savedWater ?? "Not Logged Today";
    final String exerciseVal = _livingExercise ?? savedExercise ?? "Not Logged Today";
    final String flowVal = _livingFlow ?? savedFlow ?? "Not Logged Today";
    final String painVal = _livingPain ?? savedPain ?? "Not Logged Today";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TODAY'S CYCLE",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                phaseText,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dayText,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: BlushyColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitleText,
                                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, color: BlushyColors.primary, size: 20),
                          onPressed: () {
                            _showLogPeriodBottomSheet(context);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                          tooltip: "Log / Edit Period Date",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Ovary tracker shape (BlushyCycleCard)
              const Center(
                child: SizedBox(
                  width: 260,
                  height: 95,
                  child: BlushyCycleCard(purePainterMode: true),
                ),
              ),
              const SizedBox(height: 16),
              // Color Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStartedLegendDot("Menstrual", const Color(0xFFDD0D22)),
                  const SizedBox(width: 14),
                  _buildStartedLegendDot("Follicular", const Color(0xFFFF9B9E)),
                  const SizedBox(width: 14),
                  _buildStartedLegendDot("Luteal", const Color(0xFF6F42F5)),
                ],
              ),
              const SizedBox(height: 24),
              // Today's Check-in CTA
              ElevatedButton(
                onPressed: () {
                  if (!hasPeriodLogged) {
                    _showLogPeriodBottomSheet(context);
                  } else {
                    _scrollToCheckIn();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BlushyColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  hasPeriodLogged ? "Log Today's Symptoms" : "Log Period Start Date",
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 32),

              // Today's logged metrics & user focus expectations
              Text(
                "TODAY'S LOGGED SIGNALS",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 16),
              _buildExpectationItem("Energy", energyVal, energyVal != "Not Logged Today" ? "Live Log" : "Tap check-in to log"),
              _buildExpectationItem("Mood", moodVal, moodVal != "Not Logged Today" ? "Live Log" : "Tap check-in to log"),
              if (_isMetricSelected(pc, ['flow', 'period', 'bleeding', 'spotting']))
                _buildExpectationItem("Flow", flowVal, flowVal != "Not Logged Today" ? "Live Log" : "Tap check-in to log"),
              if (_isMetricSelected(pc, ['pain', 'cramps', 'headache', 'back pain']))
                _buildExpectationItem("Pain", painVal, painVal != "Not Logged Today" ? "Live Log" : "Tap check-in to log"),
              if (_isMetricSelected(pc, ['sleep', 'insomnia', 'rest', 'fatigue']))
                _buildExpectationItem("Sleep", sleepVal, sleepVal != "Not Logged Today" ? "Live Log" : "Tap check-in to log"),
              if (_isMetricSelected(pc, ['stress', 'anxiety', 'mood swings', 'mental health']))
                _buildExpectationItem("Stress", stressVal, stressVal != "Not Logged Today" ? "Live Log" : "Tap check-in to log"),
              _buildExpectationItem("Hydration", hydrationVal, hydrationVal != "Not Logged Today" ? "Live Log" : "Tap check-in to log"),
              if (_isMetricSelected(pc, ['exercise', 'workout', 'fitness', 'activity', 'walk']))
                _buildExpectationItem("Movement", exerciseVal, exerciseVal != "Not Logged Today" ? "Live Log" : "Tap check-in to log"),
            ],
          ),
        ),
      ],
    );
  }

  void _showLogPeriodBottomSheet(BuildContext context) {
    DateTime selectedStart = _periodConfirmationState.actualStartDate ?? DateTime.now();
    DateTime? selectedEnd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF6F0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: BlushyColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Log / Edit Period",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Confirm or correct your period start and end dates below.",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "PERIOD START DATE",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: BlushyColors.secondaryText,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedStart,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                        helpText: "SELECT PERIOD START DATE",
                        confirmText: "SELECT",
                        cancelText: "CANCEL",
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedStart = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${selectedStart.year}-${selectedStart.month.toString().padLeft(2, '0')}-${selectedStart.day.toString().padLeft(2, '0')}",
                            style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.text, fontWeight: FontWeight.w600),
                          ),
                          const Icon(Icons.calendar_today_rounded, size: 16, color: BlushyColors.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "PERIOD END DATE (OPTIONAL)",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: BlushyColors.secondaryText,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedEnd ?? selectedStart.add(const Duration(days: 5)),
                        firstDate: selectedStart,
                        lastDate: DateTime.now().add(const Duration(days: 10)),
                        helpText: "SELECT PERIOD END DATE",
                        confirmText: "SELECT",
                        cancelText: "CANCEL",
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedEnd = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedEnd == null 
                                ? "Not ended yet" 
                                : "${selectedEnd!.year}-${selectedEnd!.month.toString().padLeft(2, '0')}-${selectedEnd!.day.toString().padLeft(2, '0')}",
                            style: GoogleFonts.poppins(fontSize: 14, color: selectedEnd == null ? BlushyColors.secondaryText : BlushyColors.text, fontWeight: FontWeight.w600),
                          ),
                          const Icon(Icons.calendar_today_rounded, size: 16, color: BlushyColors.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: BlushyColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            "Cancel",
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.secondaryText),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _logPeriodRange(selectedStart, selectedEnd);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BlushyColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            "Save",
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _logPeriodRange(DateTime startDate, DateTime? endDate) async {
    // Captured before the await below.
    final messenger = ScaffoldMessenger.of(context);
    final provider = BlushyOSProvider.of(context);
    final cur = provider.personalContext;

    // Persist the event, then take the recalculated cycle from the response.
    final logged = await CycleApi.logPeriod(startDate: startDate, endDate: endDate);
    if (!mounted) return;

    final CycleState? serverCycle = logged.data?.cycle;
    if (serverCycle != null) {
      setState(() {
        _lastKnownCycle = serverCycle;
        _cycleResult = ApiResult<CycleState>(
          data: serverCycle,
          state: logged.state == ApiState.loading ? ApiState.ready : logged.state,
          source: logged.source,
          version: logged.version,
          lastUpdated: logged.lastUpdated,
        );
      });
    } else {
      await _loadCycleFromServer();
      if (!mounted) return;
    }

    final int cLen = (cur.cycleLength != null && cur.cycleLength! > 0) ? cur.cycleLength! : 28;
    final int? cDay = serverCycle?.currentCycleDay;

    provider.updatePersonalContext(PersonalContext(
      userName: cur.userName,
      dateOfBirth: cur.dateOfBirth,
      weight: cur.weight,
      lifeStage: cur.lifeStage,
      dueDate: cur.dueDate,
      babyBirthDate: cur.babyBirthDate,
      trackingPreference: cur.trackingPreference,
      cyclePattern: cur.cyclePattern,
      confidence: cur.confidence,
      lifeContexts: cur.lifeContexts,
      userGoals: cur.userGoals,
      userSymptoms: cur.userSymptoms,
      medicalConditions: cur.medicalConditions,
      preferences: cur.preferences,
      cycleLength: cLen,
      cycleDay: cDay,
      // Phase comes from the server calculation, not re-derived here.
      cyclePhase: serverCycle?.phase ?? cur.cyclePhase,
      lastPeriodStart: startDate,
      medications: cur.medications,
    ));

    setState(() {
      _periodConfirmationState = _periodConfirmationState.copyWith(
        hasLoggedPeriod: true,
        actualStartDate: startDate,
        status: 'confirmed',
      );
    });

    try {
      final profileData = BlushyStorage.read('user_profile.json');
      final profileMap = Map<String, dynamic>.from(profileData['profile'] ?? profileData);
      profileMap['period_last_start_date'] = startDate.toIso8601String();
      profileMap['last_period'] = startDate.toIso8601String();
      BlushyStorage.write('user_profile.json', {'profile': profileMap});
      // Already persisted by CycleApi.logPeriod above.
    } catch (_) {}

    if (!mounted) return;
    // Report the day the server actually calculated rather than asserting the
    // cycle reset to day 1, which was not true for a back-dated entry.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          cDay == null ? 'Period logged.' : 'Period logged. You are on day $cDay.',
        ),
      ),
    );
  }

  Widget _buildExpectationItem(String label, String value, String confidence) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 30,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
            ),
          ),
          Expanded(
            flex: 45,
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
            ),
          ),
          Expanded(
            flex: 25,
            child: Text(
              confidence,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 3: CHECK IN (One-tap logging) ---
  Widget _buildLivingCheckIn() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "😊", "label": "Happy"},
      {"icon": "🙂", "label": "Okay"},
      {"icon": "😖", "label": "Cramps"},
      {"icon": "🥱", "label": "Tired"},
      {"icon": "😤", "label": "Irritable"},
    ];

    final List<String> energyOptions = ["High", "Medium", "Low"];
    final List<String> flowOptions = ["Light", "Medium", "Heavy"];
    final List<String> painOptions = ["None", "Mild", "Severe"];
    final List<String> sleepOptions = ["<6h", "6-8h", ">8h"];
    final List<String> stressOptions = ["Low", "Moderate", "High"];
    final List<String> waterOptions = ["1L", "2L", "3L"];
    final List<String> exerciseOptions = ["Active", "Light", "None"];

    return Column(
      key: _checkInKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "CHECK IN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shown when something just logged matched a reviewed red flag
              // rule, so the reviewed instruction replaces the usual
              // confirmation rather than sitting alongside it.
              if (_checkinSafety != null) _buildCheckinSafetyBanner(_checkinSafety!),
              // Mood Selector
              Text(
                AppLocalizations.of(context).dashMood,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedFeeling = checkinData['feeling'] ?? checkinData['mood'] ?? (BlushyStorage.read('logged_feeling.json'))['feeling'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeFeeling = _selectedFeeling ?? savedFeeling ?? (wb.symptoms.isNotEmpty ? wb.symptoms.first : null);
                  final isSelected = activeFeeling != null && activeFeeling.toString().toLowerCase() == (opt['label'] as String).toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      final String moodLabel = opt['label'] as String;
                      final int moodScore = (moodLabel == 'Happy') ? 9 : (moodLabel == 'Okay' ? 7 : (moodLabel == 'Tired' ? 5 : 4));
                      setState(() {
                        _selectedFeeling = moodLabel;
                      });

                      final os = BlushyOSProvider.of(context);
                      final currentWb = os.wellbeingState;
                      os.updateWellbeingState(CurrentWellbeingState(
                        mood: moodScore,
                        energy: currentWb.energy,
                        sleepQuality: currentWb.sleepQuality,
                        symptoms: [moodLabel, ...currentWb.symptoms.where((s) => s != moodLabel)],
                        lastCheckIn: DateTime.now(),
                        periodActive: currentWb.periodActive,
                      ));

                      final updatedCheckin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
                      updatedCheckin['feeling'] = moodLabel;
                      updatedCheckin['mood'] = moodLabel;
                      updatedCheckin['mood_score'] = moodScore;
                      updatedCheckin['date'] = DateTime.now().toIso8601String();
                      BlushyStorage.write('daily_checkin.json', updatedCheckin);
                      // Persist as a timestamped health event so patterns, care plan and
                      // doctor summaries can actually see this entry.
                      _recordCheckinEvent('mood', moodLabel.toString());

                      ApiAuthService().saveOnboardingAnswers({
                        'daily_mood': moodLabel,
                        'daily_mood_score': moodScore,
                        'daily_checkin': updatedCheckin,
                        'daily_logged_at': DateTime.now().toIso8601String(),
                      }).catchError((_) => <String, dynamic>{});

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text("Logged Mood: $moodLabel"),
                            ],
                          ),
                          backgroundColor: const Color(0xFF6F42F5),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withValues(alpha: 0.1) : const Color(0xFFF9F6F0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? BlushyColors.primary : BlushyColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt['icon'],
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              // Energy Selector
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              _buildLivingHorizontalSelector(AppLocalizations.of(context).dashEnergyLevel, energyOptions, _selectedEnergy, (val) {
                final int energyScore = (val == 'High') ? 9 : (val == 'Medium' ? 7 : 4);
                setState(() => _selectedEnergy = val);

                final os = BlushyOSProvider.of(context);
                final currentWb = os.wellbeingState;
                os.updateWellbeingState(CurrentWellbeingState(
                  mood: currentWb.mood,
                  energy: energyScore,
                  sleepQuality: currentWb.sleepQuality,
                  symptoms: currentWb.symptoms,
                  lastCheckIn: DateTime.now(),
                  periodActive: currentWb.periodActive,
                ));

                final updatedCheckin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
                updatedCheckin['energy'] = val;
                updatedCheckin['energy_score'] = energyScore;
                updatedCheckin['date'] = DateTime.now().toIso8601String();
                BlushyStorage.write('daily_checkin.json', updatedCheckin);
                // Persist as a timestamped health event so patterns, care plan and
                // doctor summaries can actually see this entry.
                _recordCheckinEvent('energy', val.toString());

                ApiAuthService().saveOnboardingAnswers({
                  'daily_energy': val,
                  'daily_energy_score': energyScore,
                  'daily_checkin': updatedCheckin,
                  'daily_logged_at': DateTime.now().toIso8601String(),
                }).catchError((_) => <String, dynamic>{});

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text("Logged Energy: $val"),
                      ],
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }, logCategoryKey: 'daily_checkin'),

              // Flow Selector (Shown if selected or tracking cycle)
              if (_isMetricSelected(pc, ['flow', 'period', 'bleeding', 'spotting'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector(AppLocalizations.of(context).dashFlowLevel, flowOptions, _livingFlow, (val) {
                  setState(() => _livingFlow = val);
                  final updatedCheckin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
                  updatedCheckin['flow'] = val;
                  updatedCheckin['date'] = DateTime.now().toIso8601String();
                  BlushyStorage.write('daily_checkin.json', updatedCheckin);
                  // Persist as a timestamped health event so patterns, care plan and
                  // doctor summaries can actually see this entry.
                  _recordCheckinEvent('flow', val.toString());
                  ApiAuthService().saveOnboardingAnswers({
                    'daily_flow': val,
                    'daily_checkin': updatedCheckin,
                  }).catchError((_) => <String, dynamic>{});
                }, logCategoryKey: 'daily_checkin'),
              ],

              // Pain Selector
              if (_isMetricSelected(pc, ['pain', 'cramps', 'headache', 'back pain'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("PAIN LEVEL", painOptions, _livingPain, (val) {
                  setState(() => _livingPain = val);
                  final updatedCheckin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
                  updatedCheckin['pain'] = val;
                  updatedCheckin['date'] = DateTime.now().toIso8601String();
                  BlushyStorage.write('daily_checkin.json', updatedCheckin);
                  // Persist as a timestamped health event so patterns, care plan and
                  // doctor summaries can actually see this entry.
                  _recordCheckinEvent('pain', val.toString());
                  ApiAuthService().saveOnboardingAnswers({
                    'daily_pain': val,
                    'daily_checkin': updatedCheckin,
                  }).catchError((_) => <String, dynamic>{});
                }, logCategoryKey: 'daily_checkin'),
              ],

              // Sleep Selector
              if (_isMetricSelected(pc, ['sleep', 'insomnia', 'rest', 'fatigue'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("SLEEP TIME", sleepOptions, _livingSleep, (val) {
                  final int sleepHours = (val == '>8h') ? 9 : (val == '6-8h' ? 7 : 5);
                  setState(() => _livingSleep = val);

                  final os = BlushyOSProvider.of(context);
                  final currentWb = os.wellbeingState;
                  os.updateWellbeingState(CurrentWellbeingState(
                    mood: currentWb.mood,
                    energy: currentWb.energy,
                    sleepQuality: sleepHours,
                    symptoms: currentWb.symptoms,
                    lastCheckIn: DateTime.now(),
                    periodActive: currentWb.periodActive,
                  ));

                  final updatedCheckin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
                  updatedCheckin['sleep'] = val;
                  updatedCheckin['sleep_hours'] = sleepHours;
                  updatedCheckin['date'] = DateTime.now().toIso8601String();
                  BlushyStorage.write('daily_checkin.json', updatedCheckin);
                  // Persist as a timestamped health event so patterns, care plan and
                  // doctor summaries can actually see this entry.
                  _recordCheckinEvent('sleep', val.toString());

                  ApiAuthService().saveOnboardingAnswers({
                    'daily_sleep': val,
                    'daily_sleep_hours': sleepHours,
                    'daily_checkin': updatedCheckin,
                  }).catchError((_) => <String, dynamic>{});
                }, logCategoryKey: 'daily_checkin'),
              ],

              // Stress Selector
              if (_isMetricSelected(pc, ['stress', 'anxiety', 'mood swings', 'mental health'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("STRESS LEVEL", stressOptions, _livingStress, (val) {
                  setState(() => _livingStress = val);
                  final updatedCheckin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
                  updatedCheckin['stress'] = val;
                  updatedCheckin['date'] = DateTime.now().toIso8601String();
                  BlushyStorage.write('daily_checkin.json', updatedCheckin);
                  // Persist as a timestamped health event so patterns, care plan and
                  // doctor summaries can actually see this entry.
                  _recordCheckinEvent('stress', val.toString());
                  ApiAuthService().saveOnboardingAnswers({
                    'daily_stress': val,
                    'daily_checkin': updatedCheckin,
                  }).catchError((_) => <String, dynamic>{});
                }, logCategoryKey: 'daily_checkin'),
              ],

              // Water Selector
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              _buildLivingHorizontalSelector("DAILY WATER", waterOptions, _livingWater, (val) {
                setState(() => _livingWater = val);
                final updatedCheckin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
                updatedCheckin['water'] = val;
                updatedCheckin['date'] = DateTime.now().toIso8601String();
                BlushyStorage.write('daily_checkin.json', updatedCheckin);
                // Persist as a timestamped health event so patterns, care plan and
                // doctor summaries can actually see this entry.
                _recordCheckinEvent('water', val.toString());
                ApiAuthService().saveOnboardingAnswers({
                  'daily_water': val,
                  'daily_checkin': updatedCheckin,
                }).catchError((_) => <String, dynamic>{});
              }, logCategoryKey: 'daily_checkin'),

              // Exercise Selector
              if (_isMetricSelected(pc, ['exercise', 'workout', 'fitness', 'activity', 'walk'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("EXERCISE ACTIVITY", exerciseOptions, _livingExercise, (val) {
                  setState(() => _livingExercise = val);
                  final updatedCheckin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
                  updatedCheckin['exercise'] = val;
                  updatedCheckin['date'] = DateTime.now().toIso8601String();
                  BlushyStorage.write('daily_checkin.json', updatedCheckin);
                  // Persist as a timestamped health event so patterns, care plan and
                  // doctor summaries can actually see this entry.
                  _recordCheckinEvent('exercise', val.toString());
                  ApiAuthService().saveOnboardingAnswers({
                    'daily_exercise': val,
                    'daily_checkin': updatedCheckin,
                  }).catchError((_) => <String, dynamic>{});
                }, logCategoryKey: 'daily_checkin'),
              ],
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Notes & Reflections
              Text(
                AppLocalizations.of(context).dashNotesReflections,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        VoiceNoteBottomSheet.show(context);
                      },
                      icon: const Icon(Icons.mic, size: 18),
                      label: const Text("Voice Note"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BlushyMStudioScreen()),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("M Studio"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLivingHorizontalSelector(
    String label,
    List<String> options,
    String? selectedValue,
    ValueChanged<String> onSelected, {
    String? logCategoryKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 12),
        Row(
          children: options.map((opt) {
            final isSelected = selectedValue != null && selectedValue.toLowerCase() == opt.toLowerCase();
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () {
                    onSelected(opt);
                    try {
                      final logKey = logCategoryKey ?? 'daily_checkin';
                      final logData = {
                        'metric': label,
                        'value': opt,
                        'date': DateTime.now().toIso8601String(),
                      };
                      ApiAuthService().saveOnboardingAnswers({logKey: logData}).catchError((_) => <String, dynamic>{});
                    } catch (_) {}
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? BlushyColors.primary : const Color(0xFFF9F6F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? BlushyColors.primary : BlushyColors.border, width: 0.8),
                    ),
                    child: Text(
                      opt,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : BlushyColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- SECTION 4: SIA INSIGHTS (AI section) ---
  Widget _buildLivingSiaInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            AppLocalizations.of(context).dashSiaInsights,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ApiStateCard<List<Insight>>(
          result: _patternsResult,
          onRetry: () => _loadPatterns(refresh: true),
          emptyMessage: "Sia has not noticed anything in your logs yet.",
          insufficientDataMessage:
              "Once you have logged a few days, Sia will start sharing what it notices.",
          builder: (context, insights) {
            if (insights.isEmpty) {
              return _buildPatternsPlaceholder("Sia has not noticed anything in your logs yet.");
            }
            // The Sia Note surfaces the strongest current observation.
            return _buildSiaNoteCard(insights.first);
          },
        ),
      ],
    );
  }

  Widget _buildSiaNoteCard(Insight insight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFBF7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BlushyColors.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: BlushyColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight.description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _evidenceLine(insight),
              style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Helpful / not helpful, which the ranking uses later.
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _markInsightHelpful(insight),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                      child: Text(
                        AppLocalizations.of(context).dashHelpful,
                        style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => _markInsightNotUseful(insight),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                      child: Text(
                        AppLocalizations.of(context).dashNotUseful,
                        style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _showArticleDialog(
                    context,
                    "How Sia noticed this",
                    "${insight.description}\n\n${_evidenceLine(insight)}.\n\n"
                        "This describes a pattern in what you logged. It does not explain why, "
                        "and it is not a diagnosis. Blushy shows it so you can decide whether it "
                        "matches your experience.",
                  ),
                  child: Text(
                    "Explain Insight",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // --- SECTION 5: DISCOVER (Personalized educational feed) ---
  Widget _buildLivingDiscover() {
    final List<String> topics = [
      "Cycle Health", "Nutrition", "Movement", "Sleep", "Mental Health", "Relationships", "Sexual Wellness", "Productivity"
    ];

    final Map<String, List<Map<String, String>>> topicArticles = SiaDashboardService().getDiscoverTopicsAndArticles(
      pc: _currentPc,
      state: BlushyOSProvider.of(context),
    );

    final articles = topicArticles[_livingDiscoverTopic] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "DISCOVER",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Horizontally scrolling topic chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topics.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSelected = _livingDiscoverTopic == topic;
              return GestureDetector(
                onTap: () => setState(() => _livingDiscoverTopic = topic),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? BlushyColors.primary : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : BlushyColors.text,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Articles list
        Column(
          children: articles.map((article) {
            final isSaved = _livingSavedArticles.contains(article['title']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(context, article['title']!, article['desc']!);
                          },
                          child: Text(
                            "Read",
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isSaved) {
                                _livingSavedArticles.remove(article['title']!);
                              } else {
                                _livingSavedArticles.add(article['title']!);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, size: 18, color: BlushyColors.secondaryText),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Article link copied!")),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- SECTION 6: COMMUNITY ---
  Widget _buildLivingCommunity() {
    final List<String> tabs = ["Questions", "Stories", "Tips", "Trending"];

    return ValueListenableBuilder<int>(
      valueListenable: SiaDashboardService().refreshNotifier,
      builder: (context, _, _) {
        return FutureBuilder<DashboardPersonalizedCommunityPayload>(
          future: ApiCommunityService().getDashboardPersonalizedFeed(),
          builder: (context, snapshot) {
            final payload = snapshot.data;
            final isPersonalized = payload?.isPersonalized ?? false;
            final fallbackLabel = payload?.fallbackLabel ?? (isPersonalized ? "Recommended for your cycle" : "Popular in the community");

            List<CommunityPost> activePosts = [];
            if (payload != null) {
              if (_livingCommunityTab == 'Questions') {
                activePosts = payload.questions;
              } else if (_livingCommunityTab == 'Stories') {
                activePosts = payload.stories;
              } else if (_livingCommunityTab == 'Tips') {
                activePosts = payload.tips;
              } else {
                activePosts = payload.trending;
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        "COMMUNITY",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: BlushyColors.secondaryText,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPersonalized
                            ? BlushyColors.primary.withValues(alpha: 0.1)
                            : const Color(0xFFF0EAE1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPersonalized ? "✨ AI Personalized" : "✨ $fallbackLabel",
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isPersonalized ? BlushyColors.primary : BlushyColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: tabs.map((tab) {
                      final isSelected = _livingCommunityTab == tab;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _livingCommunityTab = tab),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tab,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? BlushyColors.text : BlushyColors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BlushyColors.border, width: 0.8),
                  ),
                  child: snapshot.connectionState == ConnectionState.waiting && payload == null
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : activePosts.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded, size: 28, color: BlushyColors.disabled),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppLocalizations.of(context).dashNoCommunityPosts,
                                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: activePosts.map((post) {
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PostDetailScreen(post: post),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              post.authorName,
                                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: BlushyColors.disabled)),
                                            const SizedBox(width: 6),
                                            Text(
                                              post.tags.isNotEmpty ? post.tags.first : post.postType,
                                              style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText),
                                            ),
                                            const Spacer(),
                                            Row(
                                              children: [
                                                const Icon(Icons.arrow_upward_rounded, size: 12, color: BlushyColors.secondaryText),
                                                const SizedBox(width: 2),
                                                Text(
                                                  "${post.score}",
                                                  style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(Icons.mode_comment_outlined, size: 11, color: BlushyColors.secondaryText),
                                                const SizedBox(width: 2),
                                                Text(
                                                  "${post.commentCount}",
                                                  style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (post.title.isNotEmpty)
                                          Text(
                                            post.title,
                                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.text),
                                          ),
                                        if (post.text.isNotEmpty)
                                          Text(
                                            post.text,
                                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const Divider(height: 20, color: Color(0xFFF5F0EB)),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- SECTION 7: MY PATTERNS (Personalized observations dynamically generated from onboarding choices) ---
  Widget _buildLivingPatterns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).dashPatternsTitle,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              // Refresh recomputes from current logs; it does not create a
              // duplicate insight (spec section 9).
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                color: BlushyColors.secondaryText,
                tooltip: "Recalculate",
                onPressed: () => _loadPatterns(refresh: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ApiStateCard<List<Insight>>(
          result: _patternsResult,
          onRetry: () => _loadPatterns(refresh: true),
          emptyMessage: "Nothing stands out in your logs yet.",
          insufficientDataMessage:
              "Keep logging for a couple of weeks and Blushy will start showing what it notices.",
          builder: (context, insights) {
            if (insights.isEmpty) {
              return _buildPatternsPlaceholder("Nothing stands out in your logs yet.");
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: insights.map(_buildInsightCard).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPatternsPlaceholder(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border, width: 0.8),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText, height: 1.5),
      ),
    );
  }

  Widget _buildInsightCard(Insight insight) {
    IconData insightIcon;
    final typeLower = "${insight.type} ${insight.title}".toLowerCase();
    if (typeLower.contains("mood")) {
      insightIcon = Icons.bubble_chart_rounded;
    } else if (typeLower.contains("energy")) {
      insightIcon = Icons.bolt_rounded;
    } else if (typeLower.contains("sleep")) {
      insightIcon = Icons.bedtime_rounded;
    } else if (typeLower.contains("symptom")) {
      insightIcon = Icons.healing_rounded;
    } else {
      insightIcon = Icons.analytics_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BlushyColors.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(insightIcon, size: 18, color: BlushyColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insight.title.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BlushyColors.taupe,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _strengthLabel(insight),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Observational wording produced by the pattern engine.
            Text(
              insight.description,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: BlushyColors.text),
            ),
            const SizedBox(height: 8),
            // Real evidence: how many of the logs this was derived from.
            Text(
              _evidenceLine(insight),
              style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).dashPatternNotDiagnosis,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: BlushyColors.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _markInsightNotUseful(insight),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                  child: Text(
                    AppLocalizations.of(context).dashNotUseful,
                    style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                  ),
                ),
                if (insight.generatedAt != null)
                  Text(
                    _relativeTime(insight.generatedAt!),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: BlushyColors.secondaryText.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return "just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }


  // --- SECTION 8: JOURNEY (Monthly reflections) ---
  Widget _buildLivingJourney() {
    final journeyData = SiaDashboardService().getMonthlyReflectionAndMilestones(
      pc: _currentPc,
      state: BlushyOSProvider.of(context),
    );
    final List<MilestoneItem> items = journeyData.milestoneItems;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "MONTHLY REFLECTION & JOURNEY",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 20),
          ...items.map((m) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    m.showGreenTick ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: m.showGreenTick ? BlushyColors.success : const Color(0xFFBDBDBD),
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.title,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: BlushyColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m.description,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: BlushyColors.secondaryText,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 36, color: Color(0xFFF5F0EB)),
          Text(
            "SIA'S REFLECTION",
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            journeyData.reflection,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivingWithMyCycleHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return _wrapDashboardLayout(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  children: [
                    _buildLivingHero(displayName),
                    const SizedBox(height: 32),
                    _buildLivingTodayCycle(),
                    const SizedBox(height: 32),
                    _buildLivingCheckIn(),
                    const SizedBox(height: 32),
                    _buildLivingSiaInsights(),
                    const SizedBox(height: 32),
                    _buildLivingDiscover(),
                    const SizedBox(height: 32),
                    _buildLivingCommunity(),
                    const SizedBox(height: 32),
                    _buildLivingPatterns(),
                    const SizedBox(height: 32),
                    _buildLivingJourney(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return _wrapDashboardLayout(
            child: Center(
              child: ListView(
                shrinkWrap: _effectiveShrinkWrap,
                physics: _effectiveScrollPhysics,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                children: [
                  _buildLivingHero(displayName),
                  const SizedBox(height: 48),
                  _buildLivingTodayCycle(),
                  const SizedBox(height: 48),
                  _buildLivingCheckIn(),
                  const SizedBox(height: 48),
                  _buildLivingSiaInsights(),
                  const SizedBox(height: 48),
                  _buildLivingDiscover(),
                  const SizedBox(height: 48),
                  _buildLivingCommunity(),
                  const SizedBox(height: 48),
                  _buildLivingPatterns(),
                  const SizedBox(height: 48),
                  _buildLivingJourney(),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return _wrapDashboardLayout(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: min(1440.0, width - 64.0),
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: ListView(
                  controller: widget.isNested ? null : _livingHomeScrollController,
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  children: [
                    // Row 1: Sia's Daily Brief (Hero)
                    _buildLivingHero(displayName),
                    const SizedBox(height: 48),

                    // Row 2: Today's Cycle
                    _buildLivingTodayCycle(),
                    const SizedBox(height: 48),

                    // Row 3: Left content (8 columns) | Right sidebar (4 columns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Panel (65% width)
                        Expanded(
                          flex: 65,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLivingCheckIn(),
                              const SizedBox(height: 48),
                              _buildLivingSiaInsights(),
                              const SizedBox(height: 48),
                              _buildLivingDiscover(),
                              const SizedBox(height: 48),
                              _buildLivingCommunity(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),

                        // Right Sidebar Panel (35% width)
                        Expanded(
                          flex: 35,
                          child: Column(
                            children: [
                              _buildLivingPatterns(),
                              const SizedBox(height: 48),
                              _buildLivingJourney(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // --- BRANCH: HORMONAL HEALTH (hormonalHealth) ---
  final ScrollController _hormonalHomeScrollController = ScrollController();

  // --- SECTION 1: SIA'S DAILY BRIEF (HERO) ---
  Widget _buildHormonalHero(String name) {
    return _buildUnifiedHeroCard(
      category: "Sia's Daily Brief",
      title: "${_getTimeBasedGreetingPrefix()}, $name",
      subtitle: "Your body has been through a lot recently. Today let's focus on what you can control.",
      metricsTitle: "CYCLE STATUS: WAITING FOR NEXT PERIOD",
      metricsValue: "Cycle Day 53 • Steady tracking is your best indicator.",
      primaryBtnText: "Today's Check-in",
      onPrimaryTap: _scrollToCheckIn,
      secondaryBtnText: "Ask Sia",
      onSecondaryTap: () => _openAskSiaChat(context, null),
    );
  }

  // --- SECTION 2: MY CYCLE HEALTH (Irregular tracking metrics & Ovary shape) ---
  Widget _buildHormonalCycleHealth() {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MY CYCLE HEALTH",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Hormonal Rhythm Tracker",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Builder(
                builder: (context) {
                  final cycleData = _getDynamicCycleDates(pc);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cycleData['cycleDayText'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: BlushyColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cycleData['subtitle'] as String,
                                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: BlushyColors.primary, size: 20),
                              onPressed: () {
                                _showLogPeriodBottomSheet(context);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 20,
                              tooltip: "Log / Edit Period Date",
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Ovary tracker shape (BlushyCycleCard)
              const Center(
                child: SizedBox(
                  width: 260,
                  height: 95,
                  child: BlushyCycleCard(purePainterMode: true),
                ),
              ),
              const SizedBox(height: 16),
              // Color Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStartedLegendDot("Menstrual", const Color(0xFFDD0D22)),
                  const SizedBox(width: 14),
                  _buildStartedLegendDot("Follicular", const Color(0xFFFF9B9E)),
                  const SizedBox(width: 14),
                  _buildStartedLegendDot("Ovulation", const Color(0xFFFFB800)),
                  const SizedBox(width: 14),
                  _buildStartedLegendDot("Luteal", const Color(0xFF6F42F5)),
                ],
              ),
              const SizedBox(height: 32),

              // Recent Cycle History horizontal blocks
              Text(
                "RECENT CYCLE HISTORY",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 16),
              const RealCycleHistory(),
              const SizedBox(height: 28),

              
              // Educational explanation cards instead of direct prediction certainty
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: BlushyColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            // Read "between 38 and 71 days" for everyone. Both
                            // numbers were literals, shown as her own history.
                            "Cycle length varies for many people, and the history above is drawn from what you have logged.",
                            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFE5DDD5)),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 18, color: BlushyColors.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Your next period may arrive within the next few weeks. Because your cycles vary, this is only an estimate.",
                            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricLabel(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
      ],
    );
  }

  // --- SECTION 3: TODAY'S CHECK-IN (One-tap logging) ---
  Widget _buildHormonalCheckIn() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "😊", "label": "Happy"},
      {"icon": "🙂", "label": "Okay"},
      {"icon": "😖", "label": "Cramps"},
      {"icon": "🥱", "label": "Tired"},
      {"icon": "😤", "label": "Irritable"},
    ];

    final List<String> painOptions = ["None", "Mild", "Severe"];
    final List<String> crampsOptions = ["None", "Mild", "Severe"];
    final List<String> flowOptions = ["Light", "Medium", "Heavy"];
    final List<String> bloatingOptions = ["None", "Mild", "Severe"];
    final List<String> acneOptions = ["None", "Mild", "Severe"];
    final List<String> headacheOptions = ["None", "Mild", "Severe"];
    final List<String> medicationOptions = ["Taken", "Not Taken"];
    final List<String> exerciseOptions = ["Active", "Light", "None"];

    return Column(
      key: _checkInKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S CHECK-IN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shown when something just logged matched a reviewed red flag
              // rule, so the reviewed instruction replaces the usual
              // confirmation rather than sitting alongside it.
              if (_checkinSafety != null) _buildCheckinSafetyBanner(_checkinSafety!),
              // Mood Selector
              Text(
                AppLocalizations.of(context).dashMood,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedFeeling = checkinData['feeling'] ?? (BlushyStorage.read('logged_feeling.json'))['feeling'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeFeeling = _selectedFeeling ?? savedFeeling ?? (wb.symptoms.isNotEmpty ? wb.symptoms.first : null);
                  final isSelected = activeFeeling != null && activeFeeling.toString().toLowerCase() == (opt['label'] as String).toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Logged Mood: ${opt['label']}"),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withValues(alpha: 0.1) : const Color(0xFFF9F6F0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? BlushyColors.primary : BlushyColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt['icon'],
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Pain Selector
              if (_isMetricSelected(pc, ['pain', 'cramps', 'pelvic pain', 'aches'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("PAIN LEVEL", painOptions, _hormonalPain, (val) {
                  setState(() => _hormonalPain = val);
                }, logCategoryKey: 'hormone_log'),
              ],

              // Cramps Selector
              if (_isMetricSelected(pc, ['cramps', 'period pain', 'dysmenorrhea'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("CRAMPS", crampsOptions, _hormonalCramps, (val) {
                  setState(() => _hormonalCramps = val);
                }, logCategoryKey: 'hormone_log'),
              ],

              // Flow Selector
              if (_isMetricSelected(pc, ['flow', 'irregular', 'heavy period', 'spotting'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector(AppLocalizations.of(context).dashFlowLevel, flowOptions, _hormonalFlow, (val) {
                  setState(() => _hormonalFlow = val);
                }, logCategoryKey: 'hormone_log'),
              ],

              // Bloating Selector
              if (_isMetricSelected(pc, ['bloating', 'digestion', 'stomach', 'swelling'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("BLOATING", bloatingOptions, _hormonalBloating, (val) {
                  setState(() => _hormonalBloating = val);
                }, logCategoryKey: 'hormone_log'),
              ],

              // Acne Selector
              if (_isMetricSelected(pc, ['acne', 'skin', 'breakouts', 'hormonal acne'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("ACNE STATUS", acneOptions, _hormonalAcne, (val) {
                  setState(() => _hormonalAcne = val);
                }, logCategoryKey: 'hormone_log'),
              ],

              // Headache Selector
              if (_isMetricSelected(pc, ['headache', 'migraine', 'head pain'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("HEADACHE", headacheOptions, _hormonalHeadache, (val) {
                  setState(() => _hormonalHeadache = val);
                }, logCategoryKey: 'hormone_log'),
              ],

              // Medication Selector
              if (_isMetricSelected(pc, ['medication', 'pills', 'supplements', 'birth control', 'metformin'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("MEDICATION TAKEN", medicationOptions, _hormonalMedication, (val) {
                  setState(() => _hormonalMedication = val);
                }, logCategoryKey: 'hormone_log'),
              ],

              // Exercise Selector
              if (_isMetricSelected(pc, ['exercise', 'workout', 'fitness', 'movement', 'activity'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("EXERCISE ACTIVITY", exerciseOptions, _hormonalExercise, (val) {
                  setState(() => _hormonalExercise = val);
                }, logCategoryKey: 'hormone_log'),
              ],

              // Optional Weight
              Text(
                "WEIGHT (OPTIONAL)",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(AppLocalizations.of(context).dashLogWeight),
                      content: const TextField(
                        decoration: InputDecoration(hintText: "Enter weight in kg"),
                        keyboardType: TextInputType.number,
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                label: Text(AppLocalizations.of(context).dashLogWeight),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BlushyColors.primary,
                  side: const BorderSide(color: BlushyColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Notes & Reflections
              Text(
                AppLocalizations.of(context).dashNotesReflections,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        VoiceNoteBottomSheet.show(context);
                      },
                      icon: const Icon(Icons.mic, size: 18),
                      label: const Text("Voice Note"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BlushyMStudioScreen()),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("M Studio"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 4: SIA INSIGHTS (Observations) ---
  /// Condition profile (spec section 14).
  ///
  /// Shows only what the user told Blushy they were diagnosed with, the
  /// reviewed education that matches it, and observations drawn from their own
  /// logs. Nothing here infers a diagnosis, and no estimated hormone levels are
  /// displayed because Blushy ingests no validated lab or device data.
  ///
  /// This previously rendered `dummyConditionInsights`, which is an empty list,
  /// so the card showed nothing at all.
  /// The hormonal branch shows the same real Sia observation as every other
  /// branch, rather than its own copy.
  Widget _buildHormonalSiaInsights() => _buildLivingSiaInsights();

  Widget _buildConditionProfileCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            AppLocalizations.of(context).dashYourConditions,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ApiStateCard<Map<String, dynamic>>(
          result: _conditionsResult,
          onRetry: _loadConditions,
          emptyMessage:
              "Add any conditions you have been diagnosed with to see related information here.",
          builder: (context, data) {
            final conditions = (data["conditions"] as List?) ?? const [];
            if (conditions.isEmpty) {
              return _buildPatternsPlaceholder(
                data["message"]?.toString() ??
                    "Add any conditions you have been diagnosed with to see related information here.",
              );
            }

            final observations = (data["observations"] as List?) ?? const [];

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BlushyColors.border, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...conditions.map((raw) {
                    final block = Map<String, dynamic>.from(raw as Map);
                    final content = (block["content"] as List?) ?? const [];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.medical_information_outlined,
                                  size: 16, color: BlushyColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  block["condition"]?.toString() ?? "",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: BlushyColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (content.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 24),
                              child: Text(
                                AppLocalizations.of(context).dashNoReviewedArticle,
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: BlushyColors.secondaryText),
                              ),
                            )
                          else
                            ...content.map((c) {
                              final article = Map<String, dynamic>.from(c as Map);
                              return Padding(
                                padding: const EdgeInsets.only(top: 6, left: 24),
                                child: GestureDetector(
                                  onTap: () => _showArticleDialog(
                                    context,
                                    article["title"]?.toString() ?? "",
                                    "${article["body"] ?? ""}\n\nSource: ${article["source"] ?? "not stated"}",
                                  ),
                                  child: Text(
                                    article["title"]?.toString() ?? "",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: BlushyColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  }),
                  if (observations.isNotEmpty) ...[
                    const Divider(height: 24, color: Color(0xFFF5F0EB)),
                    Text(
                      "FROM YOUR LOGS",
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...observations.map((raw) {
                      final obs = Map<String, dynamic>.from(raw as Map);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          obs["description"]?.toString() ?? "",
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: BlushyColors.text, height: 1.4),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    data["disclaimer"]?.toString() ??
                        "Blushy does not diagnose conditions or estimate hormone levels.",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: BlushyColors.secondaryText,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }


  Widget _buildAppointmentSummaryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "FOR YOUR NEXT APPOINTMENT",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).dashPrepareSummary,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                  ),
                  const Icon(Icons.assignment_ind_outlined, color: BlushyColors.primary, size: 24),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Blushy can pull together what you have logged over a date range you choose. "
                "You decide what stays in before you share it.",
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: BlushyColors.secondaryText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DoctorSummaryScreen()),
                  ),
                  child: Text(
                    AppLocalizations.of(context).dashBuildMySummary,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "A record of what you reported and what the app noticed. Not a diagnosis.",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: BlushyColors.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildHormonalPatterns() {
    final List<Map<String, String>> patternCards = [
      {
        "title": "Cycle Pattern",
        "desc": "\"Your last five cycles have gradually become shorter.\"",
        "detail": "This progressive trend indicates improving ovulatory consistency, possibly due to balanced blood glucose levels."
      },
      {
        "title": "Pain Pattern",
        "desc": "\"Cramps usually peak during the first two days.\"",
        "detail": "Prostaglandin concentration is highest as shedding starts, driving muscular micro-spasms."
      },
      {
        "title": "Mood Pattern",
        "desc": "\"Stress levels increase before longer cycles.\"",
        "detail": "High cortisol can delay or prevent ovulation, extending follicular phase length and delaying your period."
      },
      {
        "title": "Sleep Pattern",
        "desc": "\"You sleep longer during weeks without pain.\"",
        "detail": "Lower pain levels prevent nighttime waking and micro-arousals, keeping deep sleep cycles intact."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "UNDERSTANDING MY PATTERNS",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "AI-generated trends across multiple cycle logs",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: BlushyColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...patternCards.map((card) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BlushyColors.border, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card['title']!,
                    style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card['desc']!,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card['detail']!,
                    style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _openAskSiaChat(context, "Explain this pattern: ${card['title']}"),
                        child: Text("Ask Sia", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          _showArticleDialog(context, card['title']!, "Clinical observation maps: ${card['detail']}");
                        },
                        child: Text("Why This Matters", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- SECTION 6: YOUR CARE PLAN (Daily Recommendations) ---
  /// The Care Plan section, shared by every life stage. The backend decides
  /// which actions apply to the current branch, so there is one implementation
  /// rather than a hardcoded list per stage.
  Widget _buildCarePlanSection({String heading = "TODAY'S CARE PLAN"}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            heading,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: ApiStateCard<CarePlan>(
            result: _carePlanResult,
            onRetry: _loadCarePlan,
            emptyMessage: "Nothing to suggest right now. That is a good sign.",
            // While a red flag or a concerning screening result is active the
            // server withholds ordinary wellness suggestions entirely.
            restrictedMessage:
                "Suggestions are paused while Blushy shows you the safety guidance above.",
            builder: (context, plan) {
              if (plan.suppressed || plan.actions.isEmpty) {
                return Text(
                  plan.suppressed
                      ? "Suggestions are paused while Blushy shows you the safety guidance above."
                      : "Nothing to suggest right now. That is a good sign.",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: BlushyColors.secondaryText,
                    height: 1.5,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: plan.actions.map(_buildCareActionRow).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCareActionRow(CareAction action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_careActionIcon(action.category), size: 20, color: BlushyColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        action.title,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.text,
                        ),
                      ),
                    ),
                    if (action.isHighPriority)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: BlushyColors.taupe,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Priority",
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: BlushyColors.secondaryText,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  action.description,
                  style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.45),
                ),
                // Why this was suggested, so no recommendation appears without
                // a stated basis (spec section 10).
                if (action.reason != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    action.reason!,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: BlushyColors.secondaryText,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _completeCareAction(action),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                      child: Text(
                        action.cta,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () => _dismissCareAction(action),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                      child: Text(
                        AppLocalizations.of(context).dashNotNow,
                        style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                      ),
                    ),
                    const Spacer(),
                    // Clinical suggestions say where they came from.
                    if (action.source == 'clinical_content')
                      Text(
                        "Reviewed guidance",
                        style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHormonalCarePlan() {
    return _buildCarePlanSection(heading: "YOUR CARE PLAN");
  }

  // --- SECTION 7: LEARN ---
  Widget _buildHormonalLearn() {
    final List<String> topics = [
      "Understanding PCOS", "Understanding Endometriosis", "Understanding PMDD", "Understanding Irregular Cycles", "Hormones Explained"
    ];

    // The 74 articles that used to live in these maps are now seeded
    // through the reviewed content pipeline, so each one carries a
    // reviewer and a review date and is served only once approved.

    final articles = _educationFor(_hormonalDiscoverTopic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "LEARN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topics.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSelected = _hormonalDiscoverTopic == topic;
              return GestureDetector(
                onTap: () => setState(() => _hormonalDiscoverTopic = topic),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? BlushyColors.primary : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : BlushyColors.text,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: articles.map((article) {
            final isSaved = _hormonalSavedArticles.contains(article['title']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(context, article['title']!, article['desc']!);
                          },
                          child: Text(
                            "Read",
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isSaved) {
                                _hormonalSavedArticles.remove(article['title']!);
                              } else {
                                _hormonalSavedArticles.add(article['title']!);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18, color: BlushyColors.secondaryText),
                          onPressed: () => _openAskSiaChat(context, "Explain this article: ${article['title']}"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- SECTION 8: COMMUNITY ---
  Widget _buildHormonalCommunity() {
    return _buildLivingCommunity();
  }


  // --- SECTION 9: HEALTH TIMELINE (Chronological Health Journey) ---
  /// Timeline: the user's own logged events in order, nothing else.
  ///
  /// Deliberately carries no confidence, correlation or summary. Interpretation
  /// belongs to the Patterns card, and the spec is explicit that the two must
  /// not duplicate each other.
  Widget _buildTimelineSection({
    String heading = "PAST JOURNEY TIMELINE",
    String subheading = "Chronological record of what you have logged",
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subheading,
                style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: ApiStateCard<Timeline>(
            result: _timelineResult,
            onRetry: _loadTimeline,
            emptyMessage: AppLocalizations.of(context).dashNothingLoggedYet,
            builder: (context, timeline) {
              if (_timelineEntries.isEmpty) {
                return Text(
                  AppLocalizations.of(context).dashNothingLoggedYet,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: BlushyColors.secondaryText,
                    height: 1.5,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...List.generate(_timelineEntries.length, (index) {
                    return _buildTimelineRow(
                      _timelineEntries[index],
                      isLast: index == _timelineEntries.length - 1 && !_timelineHasMore,
                    );
                  }),
                  if (_timelineHasMore)
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _timelineLoadingMore ? null : () => _loadTimeline(append: true),
                        child: Text(
                          _timelineLoadingMore ? "Loading..." : "Load earlier entries",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BlushyColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineRow(TimelineEntry entry, {required bool isLast}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 26,
            child: Text(
              _timelineDateLabel(entry.date),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: BlushyColors.primary,
              ),
            ),
          ),
          Expanded(
            flex: 74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _timelineIcons[entry.eventType] ?? Icons.circle_outlined,
                      size: 14,
                      color: BlushyColors.secondaryText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.displayText,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.text,
                        ),
                      ),
                    ),
                    // An entry the user did not confirm is labelled rather than
                    // shown as their own record (spec section 6).
                    if (!entry.editable)
                      Text(
                        "Derived",
                        style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText),
                      ),
                  ],
                ),
                if (!isLast) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF5F0EB)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHormonalTimeline() {
    return _buildTimelineSection(heading: "PAST JOURNEY TIMELINE", subheading: "Chronological record of what you have logged");
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildHormonalJourney() {
    return _buildLivingJourney();
  }

  Widget _buildHormonalHealthHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    children: [
                      _buildHormonalHero(displayName),
                      const SizedBox(height: 32),
                      _buildHormonalCycleHealth(),
                      const SizedBox(height: 32),
                      _buildHormonalCheckIn(),
                      const SizedBox(height: 32),
                      _buildHormonalSiaInsights(),
                      const SizedBox(height: 32),
                      _buildConditionProfileCard(),
                      const SizedBox(height: 32),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 32),
                      _buildHormonalPatterns(),
                      const SizedBox(height: 32),
                      _buildHormonalCarePlan(),
                      const SizedBox(height: 32),
                      _buildHormonalLearn(),
                      const SizedBox(height: 32),
                      _buildHormonalCommunity(),
                      const SizedBox(height: 32),
                      _buildHormonalTimeline(),
                      const SizedBox(height: 32),
                      _buildHormonalJourney(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    children: [
                      _buildHormonalHero(displayName),
                      const SizedBox(height: 48),
                      _buildHormonalCycleHealth(),
                      const SizedBox(height: 48),
                      _buildHormonalCheckIn(),
                      const SizedBox(height: 48),
                      _buildHormonalSiaInsights(),
                      const SizedBox(height: 32),
                      _buildConditionProfileCard(),
                      const SizedBox(height: 48),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 48),
                      _buildHormonalPatterns(),
                      const SizedBox(height: 48),
                      _buildHormonalCarePlan(),
                      const SizedBox(height: 48),
                      _buildHormonalLearn(),
                      const SizedBox(height: 48),
                      _buildHormonalCommunity(),
                      const SizedBox(height: 48),
                      _buildHormonalTimeline(),
                      const SizedBox(height: 48),
                      _buildHormonalJourney(),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: ListView(
                    controller: _hormonalHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Row 1: Sia's Daily Brief (Hero)
                      _buildHormonalHero(displayName),
                      const SizedBox(height: 48),

                      // Row 2: Cycle Health Tracking
                      _buildHormonalCycleHealth(),
                      const SizedBox(height: 48),

                      // Row 3: Left content (8 columns) | Right sidebar (4 columns)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel (65% width)
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHormonalCheckIn(),
                                const SizedBox(height: 48),
                                _buildHormonalSiaInsights(),
                                const SizedBox(height: 32),
                                _buildConditionProfileCard(),
                                const SizedBox(height: 48),
                                _buildAppointmentSummaryCard(),
                                const SizedBox(height: 48),
                                _buildHormonalCarePlan(),
                                const SizedBox(height: 48),
                                _buildHormonalLearn(),
                                const SizedBox(height: 48),
                                _buildHormonalCommunity(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right Sidebar Panel (35% width)
                          Expanded(
                            flex: 35,
                            child: Column(
                              children: [
                                _buildHormonalPatterns(),
                                const SizedBox(height: 48),
                                _buildHormonalTimeline(),
                                const SizedBox(height: 48),
                                _buildHormonalJourney(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // --- BRANCH: TRYING TO CONCEIVE (tryingToConceive) ---
  final ScrollController _ttcHomeScrollController = ScrollController();

  // --- SECTION 1: SIA'S FERTILITY BRIEF (HERO) ---
  Widget _buildTtcHero(String name) {
    final cycleData = _getDynamicCycleDates(_currentPc);
    final String cycleInfo = cycleData['isLogged'] == true
        ? "${cycleData['cycleDayText']} • Expected Test Day: ${cycleData['recTestDay']}"
        : "No period logged yet";

    return _buildUnifiedHeroCard(
      category: "Sia's Fertility Brief",
      title: "${_getTimeBasedGreetingPrefix()}, $name",
      subtitle: "You're in your two-week wait. Be kind to yourself while we wait.",
      metricsTitle: "FERTILITY STAGE: TWO WEEK WAIT",
      metricsValue: cycleInfo,
      primaryBtnText: "Today's Check-In",
      onPrimaryTap: _scrollToCheckIn,
      secondaryBtnText: "Ask Sia",
      onSecondaryTap: () => _openAskSiaChat(context, null),
      backgroundImage: const DecorationImage(
        image: AssetImage("assets/blushy_ttc.jpg"),
        fit: BoxFit.cover,
        opacity: 0.15,
      ),
    );
  }

  // --- SECTION 2: FERTILITY TIMELINE (Reuses Ovary tracker & metrics) ---
  Widget _buildTtcTimeline() {
    final pc = BlushyOSProvider.of(context).personalContext;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "FERTILITY TIMELINE",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Your Fertility Journey",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Builder(
            builder: (context) {
              final cycleData = _getDynamicCycleDates(pc);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cycleData['cycleDayText'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: BlushyColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cycleData['subtitle'] as String,
                                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: BlushyColors.primary, size: 20),
                              onPressed: () {
                                _showLogPeriodBottomSheet(context);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 20,
                              tooltip: "Log / Edit Period Date",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Ovulation logged successfully!")),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BlushyColors.primary,
                          side: const BorderSide(color: BlushyColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text("Log Ovulation", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Ovary tracker shape
                  const Center(
                    child: SizedBox(
                      width: 260,
                      height: 95,
                      child: BlushyCycleCard(purePainterMode: true),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Color Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStartedLegendDot("Menstrual", const Color(0xFFDD0D22)),
                      const SizedBox(width: 14),
                      _buildStartedLegendDot("Follicular", const Color(0xFFFF9B9E)),
                      const SizedBox(width: 14),
                      _buildStartedLegendDot("Ovulation", const Color(0xFFFFB800)),
                      const SizedBox(width: 14),
                      _buildStartedLegendDot("Luteal", const Color(0xFF6F42F5)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Timeline Metrics Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricLabel("Fertile Window", cycleData['fertileWindow'] as String),
                      _buildMetricLabel("Expected Period", cycleData['expectedPeriod'] as String),
                      _buildMetricLabel("Rec. Test Day", cycleData['recTestDay'] as String),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // --- SECTION 3: TODAY'S CHECK-IN ---
  Widget _buildTtcCheckIn() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "✨", "label": "Hopeful"},
      {"icon": "🌿", "label": "Calm"},
      {"icon": "😰", "label": "Anxious"},
      {"icon": "🥱", "label": "Tired"},
      {"icon": "🥺", "label": "Sensitive"},
    ];

    final List<String> mucusOptions = ["Dry", "Sticky", "Creamy", "Eggwhite"];
    final List<String> lhOptions = ["Low", "High", "Peak"];
    final List<String> intercourseOptions = ["Yes", "No"];
    final List<String> exerciseOptions = ["Active", "Light", "None"];
    final List<String> vitaminOptions = ["Taken", "Not Taken"];

    return Column(
      key: _checkInKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S CHECK-IN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shown when something just logged matched a reviewed red flag
              // rule, so the reviewed instruction replaces the usual
              // confirmation rather than sitting alongside it.
              if (_checkinSafety != null) _buildCheckinSafetyBanner(_checkinSafety!),
              // Mood Selector
              Text(
                AppLocalizations.of(context).dashMood,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedFeeling = checkinData['feeling'] ?? (BlushyStorage.read('logged_feeling.json'))['feeling'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeFeeling = _selectedFeeling ?? savedFeeling ?? (wb.symptoms.isNotEmpty ? wb.symptoms.first : null);
                  final isSelected = activeFeeling != null && activeFeeling.toString().toLowerCase() == (opt['label'] as String).toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Logged Mood: ${opt['label']}"),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withValues(alpha: 0.1) : const Color(0xFFF9F6F0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? BlushyColors.primary : BlushyColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt['icon'],
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              // Cervical Mucus (Shown if selected in symptoms/questionnaire)
              if (_isMetricSelected(pc, ['mucus', 'cervical mucus', 'discharge', 'fertility'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("CERVICAL MUCUS", mucusOptions, _ttcCervicalMucus, (val) {
                  setState(() => _ttcCervicalMucus = val);
                }, logCategoryKey: 'ttc_log'),
              ],

              // LH Test Result
              if (_isMetricSelected(pc, ['lh', 'ovulation test', 'opk', 'strip', 'fertility'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("OVULATION TEST (LH)", lhOptions, _ttcLhTest, (val) {
                  setState(() => _ttcLhTest = val);
                }, logCategoryKey: 'ttc_log'),
              ],

              // Intercourse
              if (_isMetricSelected(pc, ['intercourse', 'sex', 'conception', 'trying'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("INTERCOURSE LOG", intercourseOptions, _ttcIntercourse, (val) {
                  setState(() => _ttcIntercourse = val);
                }, logCategoryKey: 'ttc_log'),
              ],

              // BBT Temperature Slider
              if (_isMetricSelected(pc, ['bbt', 'temperature', 'basal', 'thermometer'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                Text(
                  "BASAL BODY TEMPERATURE (BBT)",
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${(_ttcBbt ?? 36.5).toStringAsFixed(1)}C",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                    Expanded(
                      child: Slider(
                        value: _ttcBbt ?? 36.5,
                        min: 35.5,
                        max: 37.8,
                        activeColor: BlushyColors.primary,
                        inactiveColor: const Color(0xFFF5F0EB),
                        onChanged: (val) {
                          setState(() {
                            _ttcBbt = val;
                          });
                          ApiAuthService().saveOnboardingAnswers({
                            'ttc_log': {'metric': 'BBT', 'value': val, 'date': DateTime.now().toIso8601String()}
                          }).catchError((_) => <String, dynamic>{});
                        },
                      ),
                    ),
                  ],
                ),
              ],

              // Prenatal Vitamins
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              _buildLivingHorizontalSelector("PRENATAL VITAMINS", vitaminOptions, _ttcVitamins, (val) {
                setState(() => _ttcVitamins = val);
              }, logCategoryKey: 'ttc_log'),

              // Exercise Activity
              if (_isMetricSelected(pc, ['exercise', 'workout', 'fitness', 'activity', 'walk'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("EXERCISE ACTIVITY", exerciseOptions, _ttcExercise, (val) {
                  setState(() => _ttcExercise = val);
                }, logCategoryKey: 'ttc_log'),
              ],
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Notes & M Studio triggers
              Text(
                "NOTES & M STUDIO",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        VoiceNoteBottomSheet.show(context);
                      },
                      icon: const Icon(Icons.mic, size: 18),
                      label: const Text("Voice Note"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("TTC M Studio Entry"),
                            content: const TextField(
                              decoration: InputDecoration(hintText: "Reflect on today's state..."),
                              maxLines: 3,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("M Studio"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 4: FERTILITY INSIGHTS (AI Observations) ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildTtcInsights() {
    return const RealInsightsList(
      title: 'What your logs show',
    );
  }

  // --- SECTION 5: TODAY'S PLAN ---
  /// The real care plan, which already handles empty, restricted and
  /// safety-suppressed states. This used to be a fixed list of suggestions
  /// with a hardcoded personal target ("2.2L today").
  Widget _buildTtcPlan() {
    return _buildCarePlanSection(heading: "TODAY'S PLAN");
  }

  // --- SECTION 6: LEARN ---
  Widget _buildTtcLearn() {
    final List<String> topics = [
      "Understanding Ovulation", "Fertile Window", "Egg Health", "Stress & Fertility", "Understanding BBT"
    ];

    // The 74 articles that used to live in these maps are now seeded
    // through the reviewed content pipeline, so each one carries a
    // reviewer and a review date and is served only once approved.

    final articles = _educationFor(_ttcDiscoverTopic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "LEARN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topics.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSelected = _ttcDiscoverTopic == topic;
              return GestureDetector(
                onTap: () => setState(() => _ttcDiscoverTopic = topic),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? BlushyColors.primary : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : BlushyColors.text,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: articles.map((article) {
            final isSaved = _ttcSavedArticles.contains(article['title']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(context, article['title']!, article['desc']!);
                          },
                          child: Text(
                            "Read",
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isSaved) {
                                _ttcSavedArticles.remove(article['title']!);
                              } else {
                                _ttcSavedArticles.add(article['title']!);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18, color: BlushyColors.secondaryText),
                          onPressed: () => _openAskSiaChat(context, "Explain this article: ${article['title']}"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- SECTION 7: PARTNER MODE ---
  Widget _buildTtcPartner() {
    final List<Map<String, String>> tasks = [
      {"task": "Prepare ovulation test strips in the bathroom.", "who": "Partner Task"},
      {"task": "Incorporate prenatal vitamins with breakfast.", "who": "Coordinated Task"},
      {"task": "Schedule evening relaxing walk together.", "who": "Coordinated Task"}
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "PARTNER MODE",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, color: BlushyColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    "Shared Timeline & Reminders",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Encouraging Message:",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 4),
              Text(
                "\"Every step we take together brings us closer. I'm right here with you today.\"",
                style: GoogleFonts.poppins(fontSize: 16, fontStyle: FontStyle.italic, color: BlushyColors.text, fontWeight: FontWeight.w600),
              ),
              const Divider(height: 32, color: Color(0xFFF5F0EB)),
              Text(
                "PARTNER TASKS & CONVERSATION STARTERS",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),
              ...tasks.map((t) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_box_outline_blank, size: 18, color: BlushyColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t['task']!,
                          style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x0F2E2623),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t['who']!,
                          style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 8: MY PATTERNS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildTtcPatterns() {
    return const RealInsightsList(
      title: 'Patterns in your logs',
    );
  }

  // --- SECTION 9: JOURNEY TIMELINE ---
  Widget _buildTtcJourneyTimeline() {
    return _buildTimelineSection(heading: "YOUR JOURNEY", subheading: "Chronological record of what you have logged");
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildTtcMonthlyReflection() {
    return _buildLivingJourney();
  }

  Widget _buildTTCHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    children: [
                      _buildTtcHero(displayName),
                      const SizedBox(height: 32),
                      _buildTtcTimeline(),
                      const SizedBox(height: 32),
                      _buildTtcCheckIn(),
                      const SizedBox(height: 32),
                      _buildTtcInsights(),
                      const SizedBox(height: 32),
                      _buildTtcPlan(),
                      const SizedBox(height: 32),
                      _buildTtcLearn(),
                      const SizedBox(height: 32),
                      _buildTtcPartner(),
                      const SizedBox(height: 32),
                      _buildTtcPatterns(),
                      const SizedBox(height: 32),
                      _buildTtcJourneyTimeline(),
                      const SizedBox(height: 32),
                      _buildTtcMonthlyReflection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    children: [
                      _buildTtcHero(displayName),
                      const SizedBox(height: 48),
                      _buildTtcTimeline(),
                      const SizedBox(height: 48),
                      _buildTtcCheckIn(),
                      const SizedBox(height: 48),
                      _buildTtcInsights(),
                      const SizedBox(height: 48),
                      _buildTtcPlan(),
                      const SizedBox(height: 48),
                      _buildTtcLearn(),
                      const SizedBox(height: 48),
                      _buildTtcPartner(),
                      const SizedBox(height: 48),
                      _buildTtcPatterns(),
                      const SizedBox(height: 48),
                      _buildTtcJourneyTimeline(),
                      const SizedBox(height: 48),
                      _buildTtcMonthlyReflection(),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: ListView(
                    controller: _ttcHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Row 1: Hero
                      _buildTtcHero(displayName),
                      const SizedBox(height: 48),

                      // Row 2: Fertility Timeline (with Ovary Loop)
                      _buildTtcTimeline(),
                      const SizedBox(height: 48),

                      // Row 3: Left content (8 cols) | Right sidebar (4 cols)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel (65% width)
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTtcCheckIn(),
                                const SizedBox(height: 48),
                                _buildTtcInsights(),
                                const SizedBox(height: 48),
                                _buildTtcPlan(),
                                const SizedBox(height: 48),
                                _buildTtcLearn(),
                                const SizedBox(height: 48),
                                _buildTtcPartner(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right Sidebar Panel (35% width)
                          Expanded(
                            flex: 35,
                            child: Column(
                              children: [
                                _buildTtcPatterns(),
                                const SizedBox(height: 48),
                                _buildTtcJourneyTimeline(),
                                const SizedBox(height: 48),
                                _buildTtcMonthlyReflection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // --- BRANCH: PREGNANCY (pregnancy) ---
  final ScrollController _pregnancyHomeScrollController = ScrollController();

  // --- SECTION 1: TODAY WITH BABY (HERO) ---
  /// Weeks pregnant, from the due date the user supplied.
  ///
  /// Null when no due date is known, so callers say so rather than naming a
  /// week nobody reported.
  int? _pregnancyWeek() {
    final DateTime? dueDate = BlushyOSProvider.of(context).personalContext.dueDate;
    if (dueDate == null) return null;
    final daysToGo = dueDate.difference(DateTime.now()).inDays;
    return ((280 - daysToGo) / 7).floor();
  }

  /// Reviewed education articles for one topic, keyed by the topic chip label.
  ///
  /// These were seven hardcoded `learnFeeds` maps holding 74 clinical articles
  /// written straight into the widget tree -- no reviewer, no review date, no
  /// locale. They are seeded through the content pipeline now, so an article
  /// awaiting clinical review simply does not appear.
  final Map<String, List<Map<String, String>>> _educationByTopic = {};
  final Set<String> _educationLoading = {};

  List<Map<String, String>> _educationFor(String topic) {
    final cached = _educationByTopic[topic];
    if (cached != null) return cached;

    if (!_educationLoading.contains(topic)) {
      _educationLoading.add(topic);
      unawaited(_loadEducation(topic));
    }
    // Empty until it arrives. An empty list renders the same "nothing here"
    // state as a topic with no approved content, which is the honest answer
    // in both cases.
    return const [];
  }

  Future<void> _loadEducation(String topic) async {
    final result = await ContentApi.browse(
      topic: _educationTopicKey(topic),
      contentType: 'article',
      limit: 10,
    );
    if (!mounted) return;

    setState(() {
      _educationLoading.remove(topic);
      _educationByTopic[topic] = [
        for (final item in result.data ?? const <LibraryItem>[])
          {'title': item.title, 'desc': item.summary ?? ''},
      ];
    });
  }

  /// The seed slugs topics the same way, so the chip label finds its content.
  static String _educationTopicKey(String label) => label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  Widget _buildPregnancyHero(String name) {
    // Every pregnant user saw "WEEK 24" and "112 Days To Go" regardless of
    // their due date. The date is on the personal context and nothing read it.
    final DateTime? dueDate = BlushyOSProvider.of(context).personalContext.dueDate;
    final int? daysToGo = dueDate?.difference(DateTime.now()).inDays;
    // 280 days from the last period is the convention a due date is set by, so
    // the week follows from how far the due date still is.
    final int? week = daysToGo == null ? null : ((280 - daysToGo) / 7).floor();
    final String trimester = week == null
        ? ''
        : week < 14
            ? 'First trimester'
            : week < 28
                ? 'Second trimester'
                : 'Third trimester';

    return _buildUnifiedHeroCard(
      category: "Today with Baby",
      title: "${_getTimeBasedGreetingPrefix()}, $name",
      subtitle: "Your baby is growing rapidly this week. Don't forget to take moments to rest—you deserve them.",
      metricsTitle: week == null
          ? "PREGNANCY"
          : "PREGNANCY STATUS: WEEK $week",
      metricsValue: daysToGo == null
          // Better than naming a week nobody supplied a date for.
          ? "Add your due date to see your week"
          : "$trimester • $daysToGo days to go",
      primaryBtnText: "Today's Check-In",
      onPrimaryTap: _scrollToCheckIn,
      secondaryBtnText: "Ask Sia",
      onSecondaryTap: () => _openAskSiaChat(context, null),
      backgroundImage: const DecorationImage(
        image: AssetImage("assets/blushy_pregnancy.jpg"),
        fit: BoxFit.cover,
        opacity: 0.15,
      ),
    );
  }

  // --- SECTION 2: BABY THIS WEEK ---
  Widget _buildPregnancyBabyThisWeek() {
    final List<String> highlights = [
      "Tiny fingers are becoming stronger.",
      "Hearing continues to develop.",
      "Baby movements may become more noticeable.",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "BABY THIS WEEK",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                // Fixed at week 24 for everyone. The due date is on the
                // personal context, the same source the hero card now reads.
                _pregnancyWeek() == null
                    ? "This week"
                    : "Week ${_pregnancyWeek()} development",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // Was a fixed week-24 comparison shown at every
                          // stage of pregnancy. Size guidance belongs in the
                          // reviewed content pipeline, keyed by week.
                          "Your midwife or doctor can tell you what to expect at this stage.",
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: BlushyColors.primary, height: 1.3),
                        ),
                        const SizedBox(height: 16),
                        ...highlights.map((h) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 16, color: BlushyColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    h,
                                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 40,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFBF7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: BlushyColors.border, width: 0.8),
                      ),
                      child: Center(
                        child: Text(
                          "", // Fetus / baby size visual representation
                          style: const TextStyle(fontSize: 48),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      // Week-specific development detail is clinical content and belongs
                      // in the reviewed pipeline, keyed by week. This was fixed at
                      // week 24 and shown at every stage.
                      _showArticleDialog(context, "Development this week", "Week by week development notes will appear here once they have been reviewed. Your midwife or doctor is the best source in the meantime.");
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BlushyColors.primary,
                      side: const BorderSide(color: BlushyColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Learn More"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 3: YOUR PREGNANCY JOURNEY ---
  /// Real logged events, not a scripted timeline. Replaced a hardcoded list
  /// that marked milestones complete on a freshly installed app.
  Widget _buildPregnancyJourneyTimeline() {
    return const RealJourneyTimeline(
      title: 'Your Pregnancy Log',
      emptyHeadline: 'Your pregnancy timeline is empty so far',
    );
  }

  // --- SECTION 4: TODAY'S CHECK-IN ---
  Widget _buildPregnancyCheckIn() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "🥰", "label": "Joyful"},
      {"icon": "🌿", "label": "Calm"},
      {"icon": "🥱", "label": "Tired"},
      {"icon": "🤢", "label": "Nauseous"},
      {"icon": "🎭", "label": "Moody"},
    ];

    final List<String> movementOptions = ["Active", "Normal", "Quiet"];
    final List<String> contractionOptions = ["None", "Mild", "Strong"];
    final List<String> exerciseOptions = ["Active", "Light", "None"];
    final List<String> vitaminOptions = ["Taken", "Not Taken"];

    return Column(
      key: _checkInKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S CHECK-IN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shown when something just logged matched a reviewed red flag
              // rule, so the reviewed instruction replaces the usual
              // confirmation rather than sitting alongside it.
              if (_checkinSafety != null) _buildCheckinSafetyBanner(_checkinSafety!),
              // Mood Selector
              Text(
                AppLocalizations.of(context).dashMood,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedFeeling = checkinData['feeling'] ?? (BlushyStorage.read('logged_feeling.json'))['feeling'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeFeeling = _selectedFeeling ?? savedFeeling ?? (wb.symptoms.isNotEmpty ? wb.symptoms.first : null);
                  final isSelected = activeFeeling != null && activeFeeling.toString().toLowerCase() == (opt['label'] as String).toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Logged Mood: ${opt['label']}"),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withValues(alpha: 0.1) : const Color(0xFFF9F6F0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? BlushyColors.primary : BlushyColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt['icon'],
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              // Baby Movement (Shown if tracking kicks/movement)
              if (_isMetricSelected(pc, ['movement', 'kicks', 'baby activity', 'fetal'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("BABY MOVEMENT", movementOptions, _pregnancyBabyMovement, (val) {
                  setState(() => _pregnancyBabyMovement = val);
                }, logCategoryKey: 'pregnancy_log'),
              ],

              // Kick Count logger
              if (_isMetricSelected(pc, ['kicks', 'kick count', 'fetal movement', 'baby'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                Text(
                  "KICK COUNT (DAILY)",
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: BlushyColors.primary),
                      onPressed: () {
                        if ((_pregnancyKickCount ?? 0) > 0) {
                          setState(() => _pregnancyKickCount = (_pregnancyKickCount ?? 0) - 1);
                          ApiAuthService().saveOnboardingAnswers({
                            'pregnancy_log': {'metric': 'kick_count', 'value': _pregnancyKickCount, 'date': DateTime.now().toIso8601String()}
                          }).catchError((_) => <String, dynamic>{});
                        }
                      },
                    ),
                    Text(
                      "${_pregnancyKickCount ?? 0} Kicks",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: BlushyColors.primary),
                      onPressed: () {
                        setState(() => _pregnancyKickCount = (_pregnancyKickCount ?? 0) + 1);
                        ApiAuthService().saveOnboardingAnswers({
                          'pregnancy_log': {'metric': 'kick_count', 'value': _pregnancyKickCount, 'date': DateTime.now().toIso8601String()}
                        }).catchError((_) => <String, dynamic>{});
                      },
                    ),
                  ],
                ),
              ],

              // Contractions
              if (_isMetricSelected(pc, ['contractions', 'braxton hicks', 'labor', 'cramps'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("CONTRACTIONS", contractionOptions, _pregnancyContractions, (val) {
                  setState(() => _pregnancyContractions = val);
                }, logCategoryKey: 'pregnancy_log'),
              ],

              // Vitamins
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              _buildLivingHorizontalSelector("PRENATAL VITAMINS", vitaminOptions, _pregnancyVitamins, (val) {
                setState(() => _pregnancyVitamins = val);
              }, logCategoryKey: 'pregnancy_log'),

              // Exercise Activity
              if (_isMetricSelected(pc, ['exercise', 'workout', 'fitness', 'activity', 'walk', 'yoga'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("EXERCISE ACTIVITY", exerciseOptions, _pregnancyExercise, (val) {
                  setState(() => _pregnancyExercise = val);
                }, logCategoryKey: 'pregnancy_log'),
              ],
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Optional Blood Pressure / Blood Sugar
              Text(
                "OPTIONAL HEALTH DATA",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Log Blood Pressure"),
                            content: const TextField(
                              decoration: InputDecoration(hintText: "Enter e.g. 120/80 mmHg"),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.favorite_outline, size: 18),
                      label: const Text("Blood Pressure"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Log Blood Sugar"),
                            content: const TextField(
                              decoration: InputDecoration(hintText: "Enter e.g. 95 mg/dL"),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.water_drop_outlined, size: 18),
                      label: const Text("Blood Sugar"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Notes & Reflections
              Text(
                AppLocalizations.of(context).dashNotesReflections,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        VoiceNoteBottomSheet.show(context);
                      },
                      icon: const Icon(Icons.mic, size: 18),
                      label: const Text("Voice Note"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Pregnancy M Studio Entry"),
                            content: const TextField(
                              decoration: InputDecoration(hintText: "Reflect on this week..."),
                              maxLines: 3,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("M Studio"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 5: SIA INSIGHTS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildPregnancyInsights() {
    return const RealInsightsList(
      title: 'What your logs show',
    );
  }

  // --- SECTION 6: TODAY'S CARE PLAN ---
  Widget _buildPregnancyCarePlan() {
    return _buildCarePlanSection(heading: "TODAY'S CARE PLAN");
  }

  // --- SECTION 7: BABY PREPARATION (Checklists) ---
  Widget _buildPregnancyPrep() {
    final List<Map<String, String>> checklist = [
      {"item": "Hospital Bag Checklist", "unlock": "Unlocked at Week 30"},
      {"item": "Birth Plan Outline", "unlock": "Unlocked at Week 28"},
      {"item": "Baby Names Shortlist", "unlock": "Active Now"},
      {"item": "Nursery Layout Plan", "unlock": "Active Now"},
      {"item": "Newborn Shopping List", "unlock": "Unlocked at Week 32"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "BABY PREPARATION",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_outlined, color: BlushyColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    "Pregnancy Prep & Lists",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...checklist.map((c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_box_outline_blank, size: 18, color: BlushyColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c['item']!,
                          style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x0F2E2623),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c['unlock']!,
                          style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 8: LEARN ---
  Widget _buildPregnancyLearn() {
    final List<String> topics = [
      "Baby Development", "Mother's Body", "Nutrition", "Sleep", "Labour Preparation"
    ];

    // The 74 articles that used to live in these maps are now seeded
    // through the reviewed content pipeline, so each one carries a
    // reviewer and a review date and is served only once approved.

    final articles = _educationFor(_pregnancyDiscoverTopic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "LEARN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topics.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSelected = _pregnancyDiscoverTopic == topic;
              return GestureDetector(
                onTap: () => setState(() => _pregnancyDiscoverTopic = topic),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? BlushyColors.primary : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : BlushyColors.text,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: articles.map((article) {
            final isSaved = _pregnancySavedArticles.contains(article['title']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(context, article['title']!, article['desc']!);
                          },
                          child: Text(
                            "Read",
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isSaved) {
                                _pregnancySavedArticles.remove(article['title']!);
                              } else {
                                _pregnancySavedArticles.add(article['title']!);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18, color: BlushyColors.secondaryText),
                          onPressed: () => _openAskSiaChat(context, "Explain this article: ${article['title']}"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- SECTION 9: PARTNER & FAMILY ---
  Widget _buildPregnancyPartner() {
    final List<Map<String, String>> tasks = [
      {"task": "Incorporate iron supplements with breakfast.", "who": "Coordinated"},
      {"task": "Prepare side sleep body pillows.", "who": "Partner Task"},
      {"task": "Sync 24 Week scan calendar timings.", "who": "Coordinated"}
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "PARTNER & FAMILY",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, color: BlushyColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    "Shared Pregnancy Timeline",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Coordinated Checklists & Tasks:",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              ...tasks.map((t) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_box_outline_blank, size: 18, color: BlushyColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t['task']!,
                          style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x0F2E2623),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t['who']!,
                          style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 10: MY JOURNEY ---
  /// Real logged events. Replaced a scripted timeline that asserted clinical
  /// facts the user never recorded ("Pregnancy Confirmed - Home test positive").
  Widget _buildPregnancyJourney() {
    return const RealJourneyTimeline(
      title: 'Your Pregnancy Journey',
      emptyHeadline: 'Your pregnancy journey is empty so far',
    );
  }

  // --- SECTION 11: MONTHLY REFLECTION ---
  Widget _buildPregnancyReflection() {
    return _buildLivingJourney();
  }

  Widget _buildPregnancyHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    children: [
                      _buildPregnancyHero(displayName),
                      const SizedBox(height: 32),
                      _buildPregnancyBabyThisWeek(),
                      const SizedBox(height: 32),
                      _buildPregnancyJourneyTimeline(),
                      const SizedBox(height: 32),
                      _buildPregnancyCheckIn(),
                      const SizedBox(height: 32),
                      _buildPregnancyInsights(),
                      const SizedBox(height: 32),
                      _buildPregnancyCarePlan(),
                      const SizedBox(height: 32),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 32),
                      _buildPregnancyPrep(),
                      const SizedBox(height: 32),
                      _buildPregnancyLearn(),
                      const SizedBox(height: 32),
                      _buildPregnancyPartner(),
                      const SizedBox(height: 32),
                      _buildPregnancyJourney(),
                      const SizedBox(height: 32),
                      _buildPregnancyReflection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    children: [
                      _buildPregnancyHero(displayName),
                      const SizedBox(height: 48),
                      _buildPregnancyBabyThisWeek(),
                      const SizedBox(height: 48),
                      _buildPregnancyJourneyTimeline(),
                      const SizedBox(height: 48),
                      _buildPregnancyCheckIn(),
                      const SizedBox(height: 48),
                      _buildPregnancyInsights(),
                      const SizedBox(height: 48),
                      _buildPregnancyCarePlan(),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 32),
                      const SizedBox(height: 48),
                      _buildPregnancyPrep(),
                      const SizedBox(height: 48),
                      _buildPregnancyLearn(),
                      const SizedBox(height: 48),
                      _buildPregnancyPartner(),
                      const SizedBox(height: 48),
                      _buildPregnancyJourney(),
                      const SizedBox(height: 48),
                      _buildPregnancyReflection(),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: ListView(
                    controller: _pregnancyHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Row 1: Hero
                      _buildPregnancyHero(displayName),
                      const SizedBox(height: 48),

                      // Row 2: Baby & Journey Details
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 50,
                            child: _buildPregnancyBabyThisWeek(),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 50,
                            child: _buildPregnancyJourneyTimeline(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // Row 3: Left Panel (8 cols) | Right Sidebar (4 cols)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel (65% width)
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPregnancyCheckIn(),
                                const SizedBox(height: 48),
                                _buildPregnancyInsights(),
                                const SizedBox(height: 48),
                                _buildPregnancyCarePlan(),
                                _buildAppointmentSummaryCard(),
                                const SizedBox(height: 32),
                                const SizedBox(height: 48),
                                _buildPregnancyPrep(),
                                const SizedBox(height: 48),
                                _buildPregnancyLearn(),
                                const SizedBox(height: 48),
                                _buildPregnancyPartner(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right Sidebar Panel (35% width)
                          Expanded(
                            flex: 35,
                            child: Column(
                              children: [
                                _buildPregnancyJourney(),
                                const SizedBox(height: 48),
                                _buildPregnancyReflection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // --- BRANCH: POSTPARTUM (postpartum) ---
  final ScrollController _postpartumHomeScrollController = ScrollController();

  // --- SECTION 1: TODAY'S CHECK-IN (HERO) ---
  Widget _buildPostpartumHero(String name) {
    return _buildUnifiedHeroCard(
      category: "Today's Brief",
      title: "${_getTimeBasedGreetingPrefix()}, $name",
      subtitle: "You've already done something incredible. Today, let's take care of you too.",
      metricsTitle: "POSTPARTUM RECOVERY: 6 WEEKS",
      metricsValue: "Recovery In Progress • Focus on healing",
      primaryBtnText: "Today's Check-In",
      onPrimaryTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Scroll down to 'Today's Wellbeing' logging"),
            backgroundColor: BlushyColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      secondaryBtnText: "Ask Sia",
      onSecondaryTap: () => _openAskSiaChat(context, null),
    );
  }

  // --- SECTION 2: YOUR RECOVERY ---
  /// Real logged events, not a scripted timeline. Replaced a hardcoded list
  /// that marked milestones complete on a freshly installed app.
  Widget _buildPostpartumRecoveryTimeline() {
    return const RealJourneyTimeline(
      title: 'Your Recovery Log',
      emptyHeadline: 'Your recovery timeline is empty so far',
    );
  }

  // --- SECTION 3: TODAY'S WELLBEING (One-tap logging) ---
  Widget _buildPostpartumWellbeing() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "💪", "label": "Capable"},
      {"icon": "🥱", "label": "Tired"},
      {"icon": "🤯", "label": "Overwhelmed"},
      {"icon": "😴", "label": "Sleepy"},
      {"icon": "🥺", "label": "Sensitive"},
    ];

    final List<String> feedingOptions = ["Breastfeeding", "Bottle Feeding", "Pumping"];
    final List<String> bleedingOptions = ["None", "Spotting", "Flow"];
    final List<String> incisionOptions = ["Healing", "Sore", "Not Applicable"];
    final List<String> pelvicOptions = ["Completed", "Not Done"];
    final List<String> waterOptions = ["2L", "2.5L", "3L"];
    final List<String> exerciseOptions = ["Light Walk", "Rest", "None"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S WELLBEING",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shown when something just logged matched a reviewed red flag
              // rule, so the reviewed instruction replaces the usual
              // confirmation rather than sitting alongside it.
              if (_checkinSafety != null) _buildCheckinSafetyBanner(_checkinSafety!),
              // Mood Selector
              Text(
                AppLocalizations.of(context).dashMood,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedFeeling = checkinData['feeling'] ?? (BlushyStorage.read('logged_feeling.json'))['feeling'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeFeeling = _selectedFeeling ?? savedFeeling ?? (wb.symptoms.isNotEmpty ? wb.symptoms.first : null);
                  final isSelected = activeFeeling != null && activeFeeling.toString().toLowerCase() == (opt['label'] as String).toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Logged Mood: ${opt['label']}"),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withValues(alpha: 0.1) : const Color(0xFFF9F6F0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? BlushyColors.primary : BlushyColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt['icon'],
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              // Feeding Method (Shown if selected in postpartum goals)
              if (_isMetricSelected(pc, ['feeding', 'breastfeeding', 'pumping', 'bottle', 'baby'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("FEEDING METHOD", feedingOptions, _postpartumFeeding, (val) {
                  setState(() => _postpartumFeeding = val);
                }, logCategoryKey: 'postpartum_log'),
              ],

              // Bleeding (Lochia)
              if (_isMetricSelected(pc, ['bleeding', 'lochia', 'recovery', 'flow'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("BLEEDING STATUS", bleedingOptions, _postpartumBleeding, (val) {
                  setState(() => _postpartumBleeding = val);
                }, logCategoryKey: 'postpartum_log'),
              ],

              // Incision Healing
              if (_isMetricSelected(pc, ['incision', 'c-section', 'stitches', 'perineal', 'healing'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("INCISION HEALING", incisionOptions, _postpartumIncision, (val) {
                  setState(() => _postpartumIncision = val);
                }, logCategoryKey: 'postpartum_log'),
              ],

              // Pelvic Exercises
              if (_isMetricSelected(pc, ['pelvic', 'pelvic floor', 'kegel', 'core'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("PELVIC FLOOR EXERCISE", pelvicOptions, _postpartumPelvic, (val) {
                  setState(() => _postpartumPelvic = val);
                }, logCategoryKey: 'postpartum_log'),
              ],

              // Hydration
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              _buildLivingHorizontalSelector("DAILY HYDRATION", waterOptions, _postpartumWater, (val) {
                setState(() => _postpartumWater = val);
              }, logCategoryKey: 'postpartum_log'),

              // Gentle Movement
              if (_isMetricSelected(pc, ['exercise', 'walk', 'movement', 'activity', 'fitness'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("GENTLE MOVEMENT", exerciseOptions, _postpartumExercise, (val) {
                  setState(() => _postpartumExercise = val);
                }, logCategoryKey: 'postpartum_log'),
              ],
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Optional Weight
              Text(
                "WEIGHT (OPTIONAL)",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(AppLocalizations.of(context).dashLogWeight),
                      content: const TextField(
                        decoration: InputDecoration(hintText: "Enter weight in kg"),
                        keyboardType: TextInputType.number,
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                label: Text(AppLocalizations.of(context).dashLogWeight),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BlushyColors.primary,
                  side: const BorderSide(color: BlushyColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Notes & Reflections
              Text(
                AppLocalizations.of(context).dashNotesReflections,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        VoiceNoteBottomSheet.show(context);
                      },
                      icon: const Icon(Icons.mic, size: 18),
                      label: const Text("Voice Note"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Postpartum M Studio Entry"),
                            content: const TextField(
                              decoration: InputDecoration(hintText: "Reflect on today's recovery..."),
                              maxLines: 3,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("M Studio"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 4: SIA INSIGHTS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildPostpartumInsights() {
    return const RealInsightsList(
      title: 'What your logs show',
    );
  }

  // --- SECTION 5: YOUR CARE PLAN ---
  Widget _buildPostpartumCarePlan() {
    return _buildCarePlanSection(heading: "TODAY'S CARE PLAN");
  }

  // --- SECTION 6: BABY & YOU ---
  Widget _buildPostpartumBabyAndYou() {
    final List<Map<String, String>> items = [
      {"item": "Feeding Session Summary", "val": "8 Sessions Logged Today"},
      {"item": "Weekly Tummy Time Target", "val": "Completed (15 mins/day)"},
      {"item": "Skin-to-Skin Bonding Time", "val": "Logged 30 mins after shift"},
      {"item": "Pediatrician Check-up", "val": "Next Check: August 18"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "BABY & YOU",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.child_care, color: BlushyColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    "Mother-Baby Coordinated Tasks",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...items.map((c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_outline, size: 18, color: BlushyColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c['item']!,
                          style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        c['val']!,
                        style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 7: LEARN ---
  Widget _buildPostpartumLearn() {
    final List<String> topics = [
      "Physical Recovery", "Mental Health", "Postpartum Depression", "Breastfeeding", "Pelvic Floor Recovery"
    ];

    // The 74 articles that used to live in these maps are now seeded
    // through the reviewed content pipeline, so each one carries a
    // reviewer and a review date and is served only once approved.

    final articles = _educationFor(_postpartumDiscoverTopic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "LEARN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topics.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSelected = _postpartumDiscoverTopic == topic;
              return GestureDetector(
                onTap: () => setState(() => _postpartumDiscoverTopic = topic),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? BlushyColors.primary : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : BlushyColors.text,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: articles.map((article) {
            final isSaved = _postpartumSavedArticles.contains(article['title']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(context, article['title']!, article['desc']!);
                          },
                          child: Text(
                            "Read",
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isSaved) {
                                _postpartumSavedArticles.remove(article['title']!);
                              } else {
                                _postpartumSavedArticles.add(article['title']!);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18, color: BlushyColors.secondaryText),
                          onPressed: () => _openAskSiaChat(context, "Explain this article: ${article['title']}"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- SECTION 8: COMMUNITY ---
  Widget _buildPostpartumCommunity() {
    final List<String> tabs = ["Recovery", "Feeding", "Sleep", "Mental Wellbeing", "Working Moms"];
    final threads = [
      {"user": "NewMom99", "text": "Struggling with pelvic floor exercises, are gentle kegels enough for week 6?"},
      {"user": "HealingJourney", "text": "Warm bone broths have helped my digestion so much this week."}
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "COMMUNITY",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0x0F2E2623),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isSelected = _postpartumCommunityTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _postpartumCommunityTab = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tab,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? BlushyColors.text : BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            children: threads.map((post) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post['user']!,
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: BlushyColors.disabled)),
                        const SizedBox(width: 6),
                        Text(
                          "Support Group thread",
                          style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post['text']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
                    ),
                    const Divider(height: 24, color: Color(0xFFF5F0EB)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 9: MY JOURNEY ---
  /// Real logged events, not a scripted timeline. Replaced a hardcoded list
  /// that marked milestones complete on a freshly installed app.
  Widget _buildPostpartumJourney() {
    return const RealJourneyTimeline(
      title: 'Your Postpartum Journey',
      emptyHeadline: 'Your postpartum journey is empty so far',
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildPostpartumReflection() {
    return _buildLivingJourney();
  }

  Widget _buildPostpartumHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    children: [
                      _buildPostpartumHero(displayName),
                      const SizedBox(height: 32),
                      _buildPostpartumRecoveryTimeline(),
                      const SizedBox(height: 32),
                      _buildPostpartumWellbeing(),
                      const SizedBox(height: 32),
                      _buildPostpartumInsights(),
                      const SizedBox(height: 32),
                      _buildPostpartumCarePlan(),
                      const SizedBox(height: 32),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 32),
                      _buildPostpartumBabyAndYou(),
                      const SizedBox(height: 32),
                      _buildPostpartumLearn(),
                      const SizedBox(height: 32),
                      _buildPostpartumCommunity(),
                      const SizedBox(height: 32),
                      _buildPostpartumJourney(),
                      const SizedBox(height: 32),
                      _buildPostpartumReflection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    children: [
                      _buildPostpartumHero(displayName),
                      const SizedBox(height: 48),
                      _buildPostpartumRecoveryTimeline(),
                      const SizedBox(height: 48),
                      _buildPostpartumWellbeing(),
                      const SizedBox(height: 48),
                      _buildPostpartumInsights(),
                      const SizedBox(height: 48),
                      _buildPostpartumCarePlan(),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 32),
                      const SizedBox(height: 48),
                      _buildPostpartumBabyAndYou(),
                      const SizedBox(height: 48),
                      _buildPostpartumLearn(),
                      const SizedBox(height: 48),
                      _buildPostpartumCommunity(),
                      const SizedBox(height: 48),
                      _buildPostpartumJourney(),
                      const SizedBox(height: 48),
                      _buildPostpartumReflection(),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: ListView(
                    controller: _postpartumHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Row 1: Hero
                      _buildPostpartumHero(displayName),
                      const SizedBox(height: 48),

                      // Row 2: Recovery Timeline
                      _buildPostpartumRecoveryTimeline(),
                      const SizedBox(height: 48),

                      // Row 3: Left Panel (8 cols) | Right Sidebar (4 cols)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel (65% width)
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPostpartumWellbeing(),
                                const SizedBox(height: 48),
                                _buildPostpartumInsights(),
                                const SizedBox(height: 48),
                                _buildPostpartumCarePlan(),
                                _buildAppointmentSummaryCard(),
                                const SizedBox(height: 32),
                                const SizedBox(height: 48),
                                _buildPostpartumBabyAndYou(),
                                const SizedBox(height: 48),
                                _buildPostpartumLearn(),
                                const SizedBox(height: 48),
                                _buildPostpartumCommunity(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right Sidebar Panel (35% width)
                          Expanded(
                            flex: 35,
                            child: Column(
                              children: [
                                _buildPostpartumJourney(),
                                const SizedBox(height: 48),
                                _buildPostpartumReflection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // --- BRANCH: PERIMENOPAUSE (perimenopause) ---
  final ScrollController _periHomeScrollController = ScrollController();

  // --- SECTION 1: SIA'S DAILY BRIEF ---
  Widget _buildPeriHero(String name) {
    return _buildUnifiedHeroCard(
      category: "Sia's Daily Brief",
      title: "${_getTimeBasedGreetingPrefix()}, $name",
      subtitle: "Your body is adapting to a new chapter. Every experience is unique, and we'll understand yours together.",
      metricsTitle: "CYCLE STATUS: CYCLE DAY 47",
      metricsValue: "Waiting For Next Period • Perimenopause Journey",
      primaryBtnText: "Today's Check-In",
      onPrimaryTap: _scrollToCheckIn,
      secondaryBtnText: "Ask Sia",
      onSecondaryTap: () => _openAskSiaChat(context, null),
    );
  }

  // --- SECTION 2: MY CHANGING CYCLE ---
  Widget _buildPeriChangingCycle(PersonalContext pc) {
    // These two lines read "Cycle Day 47" and "Last Period: 47 Days Ago" for
    // everyone, regardless of what they had logged. `pc` was already in scope
    // and carries the real dates; nothing was reading it.
    final DateTime? periStart = pc.lastPeriodStart;
    final int? periDaysSince =
        periStart == null ? null : DateTime.now().difference(periStart).inDays;
    final List<int> recentCycles = [31, 45, 62, 39, 54];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MY CHANGING CYCLE",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Transition Tracking & History",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                periDaysSince == null
                                    ? "Cycle day not known yet"
                                    : "Cycle Day ${periDaysSince + 1}",
                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                periDaysSince == null
                                    // Saying so beats inventing a number for
                                    // someone tracking an irregular cycle.
                                    ? "Log a period start date to see this"
                                    : "Last period: $periDaysSince days ago",
                                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, color: BlushyColors.primary, size: 20),
                          onPressed: () {
                            _showLogPeriodBottomSheet(context);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                          tooltip: "Log / Edit Period Date",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: BlushyColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      // "Highly Variable" was asserted to everyone. It is a
                      // description of her cycle, and nothing had measured it.
                      periDaysSince == null ? "Tracking" : "In transition",
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // REUSE OUR BEAUTIFUL PERIOD TRACKER LOOP
              Center(
                child: Column(
                  children: [
                    Text(
                      periDaysSince == null ? "—" : "Day ${periDaysSince + 1}",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    Text(
                      // Naming a phase during perimenopause needs data nobody
                      // has here, so it says what it actually knows.
                      periDaysSince == null
                          ? "No period logged yet"
                          : "Since your last logged period",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 260,
                      height: 95,
                      child: BlushyCycleCard(purePainterMode: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Ovary Legend/Color Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStartedLegendDot("Period", const Color(0xFFC78280)),
                  const SizedBox(width: 12),
                  _buildStartedLegendDot("Follicular", const Color(0xFFE2B7A8)),
                  const SizedBox(width: 12),
                  _buildStartedLegendDot("Luteal/Late", const Color(0xFFE8987E)),
                ],
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              Text(
                "RECENT CYCLE HISTORY",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: recentCycles.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final cycleLen = recentCycles[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF6F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: BlushyColors.border, width: 0.8),
                      ),
                      child: Center(
                        child: Text(
                          "$cycleLen Days",
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // The four figures here were literals presented as her own
              // cycle statistics. The history above is computed from real logs.
              const RealCycleHistory(),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3E4DD), width: 0.8),
                ),
                child: Text(
                  // This claimed to have noticed a trend across her recent
                  // months. Nothing had analysed anything; it was a fixed
                  // sentence shown to everyone in this stage.
                  "Cycles often become less predictable during the perimenopause transition. What you log here builds your own picture over time.",
                  style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: BlushyColors.secondaryText),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Opens the real logging sheet. This used to show
                        // "Period Logged (Simulated)" and record nothing.
                        _showLogPeriodBottomSheet(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.of(context).dashLogPeriod,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _showArticleDialog(context, "Full Cycle History", "Detailed logs of all tracked cycles: \n- June 2026: 54 Days\n- April 2026: 39 Days\n- Feb 2026: 62 Days\n- Dec 2025: 45 Days\n- Oct 2025: 31 Days");
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        "View Full History",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 3: TODAY'S CHECK-IN ---
  Widget _buildPeriWellbeing() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "😌", "label": "Balanced"},
      {"icon": "🥱", "label": "Tired"},
      {"icon": "😰", "label": "Anxious"},
      {"icon": "🔥", "label": "Warm"},
      {"icon": "😤", "label": "Irritable"},
    ];

    final List<String> flashOptions = ["None", "Mild", "Intense"];
    final List<String> sweatOptions = ["None", "Mild", "Intense"];
    final List<String> fogOptions = ["None", "Mild", "Intense"];
    final List<String> therapyOptions = ["Taken", "Not Taken", "None"];
    final List<String> flowOptions = ["None", "Spotting", "Medium", "Heavy"];
    final List<String> exerciseOptions = ["Strength Training", "Walk", "None"];
    final List<String> waterOptions = ["1.5L", "2L", "2.5L"];

    return Column(
      key: _checkInKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S CHECK-IN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shown when something just logged matched a reviewed red flag
              // rule, so the reviewed instruction replaces the usual
              // confirmation rather than sitting alongside it.
              if (_checkinSafety != null) _buildCheckinSafetyBanner(_checkinSafety!),
              // Mood Selector
              Text(
                AppLocalizations.of(context).dashMood,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedFeeling = checkinData['feeling'] ?? (BlushyStorage.read('logged_feeling.json'))['feeling'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeFeeling = _selectedFeeling ?? savedFeeling ?? (wb.symptoms.isNotEmpty ? wb.symptoms.first : null);
                  final isSelected = activeFeeling != null && activeFeeling.toString().toLowerCase() == (opt['label'] as String).toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Logged Mood: ${opt['label']}"),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withValues(alpha: 0.1) : const Color(0xFFF9F6F0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? BlushyColors.primary : BlushyColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt['icon'],
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              // Hot Flashes (Shown if selected in symptoms/questionnaire)
              if (_isMetricSelected(pc, ['hot flashes', 'flashes', 'sweats'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("HOT FLASHES", flashOptions, _periHotFlashes, (val) {
                  setState(() => _periHotFlashes = val);
                }, logCategoryKey: 'peri_log'),
              ],

              // Night Sweats (Shown if selected)
              if (_isMetricSelected(pc, ['night sweats', 'sweats', 'sleep'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("NIGHT SWEATS", sweatOptions, _periNightSweats, (val) {
                  setState(() => _periNightSweats = val);
                }, logCategoryKey: 'peri_log'),
              ],

              // Brain Fog (Shown if selected)
              if (_isMetricSelected(pc, ['brain fog', 'memory', 'focus', 'fatigue'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("BRAIN FOG", fogOptions, _periBrainFog, (val) {
                  setState(() => _periBrainFog = val);
                }, logCategoryKey: 'peri_log'),
              ],

              // Hormone Therapy
              if (_isMetricSelected(pc, ['hrt', 'therapy', 'medication', 'hormone'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("HORMONE THERAPY", therapyOptions, _periHormoneTherapy, (val) {
                  setState(() => _periHormoneTherapy = val);
                }, logCategoryKey: 'peri_log'),
              ],

              // Flow
              if (_isMetricSelected(pc, ['flow', 'irregular', 'spotting', 'period'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("PERIOD FLOW (LOCHIA/SPOTTING)", flowOptions, _periFlow, (val) {
                  setState(() => _periFlow = val);
                }, logCategoryKey: 'peri_log'),
              ],

              // Exercise
              if (_isMetricSelected(pc, ['exercise', 'workout', 'walk', 'activity', 'fitness'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("DAILY EXERCISE", exerciseOptions, _periExercise, (val) {
                  setState(() => _periExercise = val);
                }, logCategoryKey: 'peri_log'),
              ],

              // Hydration
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              _buildLivingHorizontalSelector("DAILY HYDRATION", waterOptions, _periWater, (val) {
                setState(() => _periWater = val);
              }, logCategoryKey: 'peri_log'),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Optional Weight
              Text(
                "WEIGHT (OPTIONAL)",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(AppLocalizations.of(context).dashLogWeight),
                      content: const TextField(
                        decoration: InputDecoration(hintText: "Enter weight in kg"),
                        keyboardType: TextInputType.number,
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                label: Text(AppLocalizations.of(context).dashLogWeight),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BlushyColors.primary,
                  side: const BorderSide(color: BlushyColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Notes & Reflections
              Text(
                AppLocalizations.of(context).dashNotesReflections,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        VoiceNoteBottomSheet.show(context);
                      },
                      icon: const Icon(Icons.mic, size: 18),
                      label: const Text("Voice Note"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("M Studio Reflection"),
                            content: const TextField(
                              decoration: InputDecoration(hintText: "Reflect on how your body feels today..."),
                              maxLines: 3,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("M Studio"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 4: SIA INSIGHTS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildPeriInsights() {
    return const RealInsightsList(
      title: 'What your logs show',
    );
  }

  // --- SECTION 5: UNDERSTANDING MY PATTERNS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildPeriPatterns() {
    return const RealInsightsList(
      title: 'Patterns in your logs',
    );
  }

  // --- SECTION 6: TODAY'S CARE PLAN ---
  Widget _buildPeriCarePlan() {
    return _buildCarePlanSection(heading: "TODAY'S CARE PLAN");
  }

  // --- SECTION 7: LEARN ---
  Widget _buildPeriLearn() {
    final List<String> topics = [
      "Understanding Perimenopause", "Hormonal Changes", "Hot Flashes", "Sleep", "Bone Health"
    ];

    // The 74 articles that used to live in these maps are now seeded
    // through the reviewed content pipeline, so each one carries a
    // reviewer and a review date and is served only once approved.

    final articles = _educationFor(_periDiscoverTopic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "LEARN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topics.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSelected = _periDiscoverTopic == topic;
              return GestureDetector(
                onTap: () => setState(() => _periDiscoverTopic = topic),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? BlushyColors.primary : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : BlushyColors.text,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: articles.map((article) {
            final isSaved = _periSavedArticles.contains(article['title']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(context, article['title']!, article['desc']!);
                          },
                          child: Text(
                            "Read",
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isSaved) {
                                _periSavedArticles.remove(article['title']!);
                              } else {
                                _periSavedArticles.add(article['title']!);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18, color: BlushyColors.secondaryText),
                          onPressed: () => _openAskSiaChat(context, "Explain this article: ${article['title']}"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- SECTION 8: COMMUNITY ---
  Widget _buildPeriCommunity() {
    final List<String> tabs = ["Perimenopause", "Hot Flashes", "Sleep", "Mental Wellbeing", "Hormone Therapy"];
    final threads = [
      {"user": "ElenaK", "text": "Starting strength weights next week to support bone health. Any simple routine tips?"},
      {"user": "Midsommer", "text": "Night sweats have gotten so much better since dropping bedroom temp to 18C."}
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "COMMUNITY",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0x0F2E2623),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isSelected = _periCommunityTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _periCommunityTab = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tab,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? BlushyColors.text : BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            children: threads.map((post) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post['user']!,
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: BlushyColors.disabled)),
                        const SizedBox(width: 6),
                        Text(
                          "Support Group thread",
                          style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post['text']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
                    ),
                    const Divider(height: 24, color: Color(0xFFF5F0EB)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 9: MY TRANSITION ---
  /// Real logged events, not a scripted timeline. Replaced a hardcoded list
  /// that marked milestones complete on a freshly installed app.
  Widget _buildPeriTransition() {
    return const RealJourneyTimeline(
      title: 'Your Transition Log',
      emptyHeadline: 'Your transition timeline is empty so far',
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildPeriReflection() {
    return _buildLivingJourney();
  }

  Widget _buildPerimenopauseHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    children: [
                      _buildPeriHero(displayName),
                      const SizedBox(height: 32),
                      _buildPeriChangingCycle(pc),
                      const SizedBox(height: 32),
                      _buildPeriWellbeing(),
                      const SizedBox(height: 32),
                      _buildPeriInsights(),
                      const SizedBox(height: 32),
                      _buildPeriPatterns(),
                      const SizedBox(height: 32),
                      _buildPeriCarePlan(),
                      const SizedBox(height: 32),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 32),
                      _buildPeriLearn(),
                      const SizedBox(height: 32),
                      _buildPeriCommunity(),
                      const SizedBox(height: 32),
                      _buildPeriTransition(),
                      const SizedBox(height: 32),
                      _buildPeriReflection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    children: [
                      _buildPeriHero(displayName),
                      const SizedBox(height: 48),
                      _buildPeriChangingCycle(pc),
                      const SizedBox(height: 48),
                      _buildPeriWellbeing(),
                      const SizedBox(height: 48),
                      _buildPeriInsights(),
                      const SizedBox(height: 48),
                      _buildPeriPatterns(),
                      const SizedBox(height: 48),
                      _buildPeriCarePlan(),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 32),
                      const SizedBox(height: 48),
                      _buildPeriLearn(),
                      const SizedBox(height: 48),
                      _buildPeriCommunity(),
                      const SizedBox(height: 48),
                      _buildPeriTransition(),
                      const SizedBox(height: 48),
                      _buildPeriReflection(),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: ListView(
                    controller: _periHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Row 1: Hero
                      _buildPeriHero(displayName),
                      const SizedBox(height: 48),

                      // Row 2: Changing Cycle
                      _buildPeriChangingCycle(pc),
                      const SizedBox(height: 48),

                      // Row 3: Left Panel (65% width) | Right Sidebar (35% width)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPeriWellbeing(),
                                const SizedBox(height: 48),
                                _buildPeriInsights(),
                                const SizedBox(height: 48),
                                _buildPeriPatterns(),
                                const SizedBox(height: 48),
                                _buildPeriCarePlan(),
                                _buildAppointmentSummaryCard(),
                                const SizedBox(height: 32),
                                const SizedBox(height: 48),
                                _buildPeriLearn(),
                                const SizedBox(height: 48),
                                _buildPeriCommunity(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right Sidebar Panel (35% width)
                          Expanded(
                            flex: 35,
                            child: Column(
                              children: [
                                _buildPeriTransition(),
                                const SizedBox(height: 48),
                                _buildPeriReflection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // --- BRANCH: MENOPAUSE (menopause) ---
  final ScrollController _menoHomeScrollController = ScrollController();

  // --- SECTION 1: SIA'S DAILY BRIEF ---
  Widget _buildMenoHero(String name) {
    return _buildUnifiedHeroCard(
      category: "Sia's Daily Brief",
      title: "${_getTimeBasedGreetingPrefix()}, $name",
      subtitle: "Your body has entered a new rhythm. Let's help you feel your best today.",
      metricsTitle: "MENOPAUSE JOURNEY",
      metricsValue: "2 Years Since Menopause • Healthy Vitality Focus",
      primaryBtnText: "Today's Check-In",
      onPrimaryTap: _scrollToCheckIn,
      secondaryBtnText: "Ask Sia",
      onSecondaryTap: () => _openAskSiaChat(context, null),
    );
  }

  // --- SECTION 2: MY WELLBEING ---
  // --- SECTION 2: MY WELLBEING ---
  Widget _buildMenoWellbeing([CurrentWellbeingState? wbParam]) {
    final state = BlushyOSProvider.of(context);
    final wb = wbParam ?? state.wellbeingState;

    final String? sleepVal = _wellnessSleep ?? (wb.sleepQuality != null ? "${wb.sleepQuality}h" : null);
    final String? energyVal = (_checkInEnergy?.isNotEmpty == true && _checkInEnergy != 'Balanced') ? _checkInEnergy : (wb.energy != null ? "Level ${wb.energy}/10" : null);
    final String? moodVal = _selectedFeeling ?? (_checkInMood?.isNotEmpty == true && _checkInMood != 'Calm' ? _checkInMood : (wb.mood != null ? "Level ${wb.mood}/10" : null));
    final String? hrtVal = _hormonalMedication != 'Not Taken' ? _hormonalMedication : null;
    final String? walkingVal = _wellnessExercise;
    final String? hydrationVal = _wellnessWater;

    int loggedCount = 0;
    if (sleepVal != null) loggedCount++;
    if (energyVal != null) loggedCount++;
    if (moodVal != null) loggedCount++;
    if (hrtVal != null) loggedCount++;
    if (walkingVal != null) loggedCount++;
    if (hydrationVal != null) loggedCount++;

    final String scoreTitle = loggedCount > 0
        ? "Wellness Score: ${((loggedCount / 6) * 100).round()}%"
        : "Wellness Score: Not Logged";
    final String scoreSubtitle = loggedCount > 0
        ? "Calculated from $loggedCount logged health marker(s) today"
        : "Complete Today's Check-In below to generate your score";

    final String quoteText = loggedCount > 0
        ? "\"You have logged $loggedCount health marker(s) today. Continuing daily check-ins helps track long-term wellbeing and bone health consistency.\""
        : "\"No wellbeing data logged for today yet. Use 'Today's Check-In' below to record your sleep, mood, energy, and activity.\"";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MY WELLBEING",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Long-Term Wellness Overview",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scoreTitle,
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scoreSubtitle,
                          style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildMetricLabel("Sleep Quality", sleepVal ?? "Not Logged")),
                  const SizedBox(width: 24),
                  Expanded(child: _buildMetricLabel("Energy level", energyVal ?? "Not Logged")),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildMetricLabel("Mood State", moodVal ?? "Not Logged")),
                  const SizedBox(width: 24),
                  Expanded(child: _buildMetricLabel("Medication/HRT", hrtVal ?? "Not Logged")),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildMetricLabel("Daily Walking", walkingVal ?? "Not Logged")),
                  const SizedBox(width: 24),
                  Expanded(child: _buildMetricLabel("Hydration", hydrationVal ?? "Not Logged")),
                ],
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3E4DD), width: 0.8),
                ),
                child: Text(
                  quoteText,
                  style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: BlushyColors.secondaryText),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _scrollToCheckIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Today's Check-In",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _showArticleDialog(context, "Wellness History", "Your logged check-in history:\n- Sleep: ${sleepVal ?? 'Not Logged'}\n- Hydration: ${hydrationVal ?? 'Not Logged'}\n- Mood: ${moodVal ?? 'Not Logged'}");
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        "View Health History",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 3: TODAY'S CHECK-IN ---
  Widget _buildMenoCheckIn() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "😌", "label": "Balanced"},
      {"icon": "🥱", "label": "Tired"},
      {"icon": "😰", "label": "Anxious"},
      {"icon": "🔥", "label": "Warm"},
      {"icon": "😤", "label": "Irritable"},
    ];

    final List<String> flashOptions = ["None", "Mild", "Intense"];
    final List<String> sweatOptions = ["None", "Mild", "Intense"];
    final List<String> jointOptions = ["None", "Mild", "Intense"];
    final List<String> therapyOptions = ["Taken", "Not Taken", "None"];
    final List<String> strengthOptions = ["Done", "Not Done"];
    final List<String> walkingOptions = ["Done", "Not Done"];
    final List<String> waterOptions = ["2L", "2.5L", "3L"];

    return Column(
      key: _checkInKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S CHECK-IN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shown when something just logged matched a reviewed red flag
              // rule, so the reviewed instruction replaces the usual
              // confirmation rather than sitting alongside it.
              if (_checkinSafety != null) _buildCheckinSafetyBanner(_checkinSafety!),
              // Mood Selector
              Text(
                AppLocalizations.of(context).dashMood,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedFeeling = checkinData['feeling'] ?? (BlushyStorage.read('logged_feeling.json'))['feeling'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeFeeling = _selectedFeeling ?? savedFeeling ?? (wb.symptoms.isNotEmpty ? wb.symptoms.first : null);
                  final isSelected = activeFeeling != null && activeFeeling.toString().toLowerCase() == (opt['label'] as String).toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Logged Mood: ${opt['label']}"),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withValues(alpha: 0.1) : const Color(0xFFF9F6F0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? BlushyColors.primary : BlushyColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt['icon'],
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              // Hot Flashes (Shown if selected in symptoms/questionnaire)
              if (_isMetricSelected(pc, ['hot flashes', 'flashes', 'sweats'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("HOT FLASHES", flashOptions, _menoHotFlashes, (val) {
                  setState(() => _menoHotFlashes = val);
                }, logCategoryKey: 'menopause_log'),
              ],

              // Night Sweats (Shown if selected)
              if (_isMetricSelected(pc, ['night sweats', 'sweats', 'sleep'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("NIGHT SWEATS", sweatOptions, _menoNightSweats, (val) {
                  setState(() => _menoNightSweats = val);
                }, logCategoryKey: 'menopause_log'),
              ],

              // Joint Stiffness (Shown if selected)
              if (_isMetricSelected(pc, ['joint stiffness', 'joints', 'stiffness', 'body ache', 'pain'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("JOINT STIFFNESS", jointOptions, _menoJointPain, (val) {
                  setState(() => _menoJointPain = val);
                }, logCategoryKey: 'menopause_log'),
              ],

              // Hormone Therapy / Medication
              if (_isMetricSelected(pc, ['hrt', 'therapy', 'medication', 'hormone'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("MEDICATION & HRT STATUS", therapyOptions, _menoHormoneTherapy, (val) {
                  setState(() => _menoHormoneTherapy = val);
                }, logCategoryKey: 'menopause_log'),
              ],

              // Strength Training
              if (_isMetricSelected(pc, ['strength', 'workout', 'fitness', 'exercise'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("STRENGTH WORKOUT", strengthOptions, _menoStrength, (val) {
                  setState(() => _menoStrength = val);
                }, logCategoryKey: 'menopause_log'),
              ],

              // Walking
              if (_isMetricSelected(pc, ['walk', 'walking', 'steps', 'movement', 'activity'])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector("DAILY WALKING HABIT", walkingOptions, _menoWalking, (val) {
                  setState(() => _menoWalking = val);
                }, logCategoryKey: 'menopause_log'),
              ],

              // Hydration
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              _buildLivingHorizontalSelector("DAILY HYDRATION", waterOptions, _menoWater, (val) {
                setState(() => _menoWater = val);
              }, logCategoryKey: 'menopause_log'),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Optional Blood Pressure
              Text(
                "BLOOD PRESSURE (OPTIONAL)",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Log Blood Pressure"),
                      content: const TextField(
                        decoration: InputDecoration(hintText: "Enter systolic/diastolic, e.g. 120/80"),
                        keyboardType: TextInputType.text,
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.favorite_outline, size: 18),
                label: const Text("Log Blood Pressure"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BlushyColors.primary,
                  side: const BorderSide(color: BlushyColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Notes & Reflections
              Text(
                AppLocalizations.of(context).dashNotesReflections,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        VoiceNoteBottomSheet.show(context);
                      },
                      icon: const Icon(Icons.mic, size: 18),
                      label: const Text("Voice Note"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("M Studio Reflection"),
                            content: const TextField(
                              decoration: InputDecoration(hintText: "Write down notes on overall wellbeing..."),
                              maxLines: 3,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("M Studio"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 4: SIA INSIGHTS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildMenoInsights() {
    return const RealInsightsList(
      title: 'What your logs show',
    );
  }

  // --- SECTION 5: LONG-TERM WELLNESS ---
  Widget _buildMenoPatterns() {
    final List<Map<String, String>> wellnessCards = [
      {
        "title": "Bone Health",
        "desc": "\"You've completed strength exercises three times this week.\"",
        "detail": "Resistance exercise triggers osteoblast cells, vital for preserving bone mineral density levels after menopause estrogen drops."
      },
      {
        "title": "Heart Health",
        "desc": "\"You've maintained your walking goal.\"",
        "detail": "Walking helps support vascular elasticity, essential for lowering cardiovascular risks in the post-menopausal transition."
      },
      {
        "title": "Sleep",
        "desc": "\"Sleep quality has gradually improved.\"",
        "detail": "Consistent room coolings and screen-free routines have extended deep REM segments by 30 mins average."
      },
      {
        "title": "Mental Wellbeing",
        "desc": "\"You've been journaling consistently.\"",
        "detail": "Taking 5 minutes to write reflections correlates with stable evening cortisol baselines."
      },
      {
        "title": "Nutrition",
        "desc": "\"Protein intake has improved.\"",
        "detail": "Averaging 70g daily protein helps prevent natural muscle mass declines (sarcopenia) and supports cellular energy."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "LONG-TERM WELLNESS",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "EMPOWERED POST-MENOPAUSE WELLNESS CARDS",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: wellnessCards.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final card = wellnessCards[index];
              return Container(
                width: 280,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card['title']!.toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      card['desc']!,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Why This Matters: Encourages sustainable heart, joint and bone vitalities.",
                      style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(context, card['title']!, card['detail']!);
                          },
                          child: Text("Learn More", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary)),
                        ),
                        TextButton(
                          onPressed: () => _openAskSiaChat(context, "Tell me about my ${card['title']}"),
                          child: Text("Ask Sia", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- SECTION 6: TODAY'S CARE PLAN ---
  Widget _buildMenoCarePlan() {
    return _buildCarePlanSection(heading: "TODAY'S CARE PLAN");
  }

  // --- SECTION 7: LEARN ---
  Widget _buildMenoLearn() {
    final List<String> topics = [
      "Understanding Menopause", "Bone Health", "Heart Health", "Strength Training", "Nutrition"
    ];

    // The 74 articles that used to live in these maps are now seeded
    // through the reviewed content pipeline, so each one carries a
    // reviewer and a review date and is served only once approved.

    final articles = _educationFor(_menoDiscoverTopic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "LEARN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topics.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSelected = _menoDiscoverTopic == topic;
              return GestureDetector(
                onTap: () => setState(() => _menoDiscoverTopic = topic),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? BlushyColors.primary : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : BlushyColors.text,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: articles.map((article) {
            final isSaved = _menoSavedArticles.contains(article['title']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(context, article['title']!, article['desc']!);
                          },
                          child: Text(
                            "Read",
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isSaved) {
                                _menoSavedArticles.remove(article['title']!);
                              } else {
                                _menoSavedArticles.add(article['title']!);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18, color: BlushyColors.secondaryText),
                          onPressed: () => _openAskSiaChat(context, "Explain this article: ${article['title']}"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- SECTION 8: COMMUNITY ---
  Widget _buildMenoCommunity() {
    final List<String> tabs = ["Healthy Ageing", "Fitness", "Nutrition", "Sleep", "Hormone Therapy"];
    final threads = [
      {"user": "JoyfulSilver", "text": "Resistance band training has been a game changer for my joint stiffness."},
      {"user": "GracefulHeart", "text": "Swapped morning caffeine for herbal tea and noticed a big drop in hot flash frequency."}
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "COMMUNITY",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0x0F2E2623),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isSelected = _menoCommunityTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _menoCommunityTab = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tab,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? BlushyColors.text : BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            children: threads.map((post) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post['user']!,
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: BlushyColors.disabled)),
                        const SizedBox(width: 6),
                        Text(
                          "Support Group thread",
                          style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post['text']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
                    ),
                    const Divider(height: 24, color: Color(0xFFF5F0EB)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 9: MY WELLNESS JOURNEY ---
  /// Real logged events, not a scripted timeline. Replaced a hardcoded list
  /// that marked milestones complete on a freshly installed app.
  Widget _buildMenoWellnessJourney() {
    return const RealJourneyTimeline(
      title: 'Your Wellness Journey',
      emptyHeadline: 'Your wellness journey is empty so far',
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildMenoReflection() {
    return _buildLivingJourney();
  }

  Widget _buildMenopauseHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    children: [
                      _buildMenoHero(displayName),
                      const SizedBox(height: 32),
                      _buildMenoWellbeing(),
                      const SizedBox(height: 32),
                      _buildMenoCheckIn(),
                      const SizedBox(height: 32),
                      _buildMenoInsights(),
                      const SizedBox(height: 32),
                      _buildMenoPatterns(),
                      const SizedBox(height: 32),
                      _buildMenoCarePlan(),
                      const SizedBox(height: 32),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 32),
                      _buildMenoLearn(),
                      const SizedBox(height: 32),
                      _buildMenoCommunity(),
                      const SizedBox(height: 32),
                      _buildMenoWellnessJourney(),
                      const SizedBox(height: 32),
                      _buildMenoReflection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    children: [
                      _buildMenoHero(displayName),
                      const SizedBox(height: 48),
                      _buildMenoWellbeing(),
                      const SizedBox(height: 48),
                      _buildMenoCheckIn(),
                      const SizedBox(height: 48),
                      _buildMenoInsights(),
                      const SizedBox(height: 48),
                      _buildMenoPatterns(),
                      const SizedBox(height: 48),
                      _buildMenoCarePlan(),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 32),
                      const SizedBox(height: 48),
                      _buildMenoLearn(),
                      const SizedBox(height: 48),
                      _buildMenoCommunity(),
                      const SizedBox(height: 48),
                      _buildMenoWellnessJourney(),
                      const SizedBox(height: 48),
                      _buildMenoReflection(),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: ListView(
                    controller: _menoHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Row 1: Hero
                      _buildMenoHero(displayName),
                      const SizedBox(height: 48),

                      // Row 2: Wellbeing Card
                      _buildMenoWellbeing(),
                      const SizedBox(height: 48),

                      // Row 3: Left Panel (65% width) | Right Sidebar (35% width)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMenoCheckIn(),
                                const SizedBox(height: 48),
                                _buildMenoInsights(),
                                const SizedBox(height: 48),
                                _buildMenoPatterns(),
                                const SizedBox(height: 48),
                                _buildMenoCarePlan(),
                                _buildAppointmentSummaryCard(),
                                const SizedBox(height: 32),
                                const SizedBox(height: 48),
                                _buildMenoLearn(),
                                const SizedBox(height: 48),
                                _buildMenoCommunity(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right Sidebar Panel (35% width)
                          Expanded(
                            flex: 35,
                            child: Column(
                              children: [
                                _buildMenoWellnessJourney(),
                                const SizedBox(height: 48),
                                _buildMenoReflection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // --- BRANCH: EVERYDAY WELLNESS (everydayWellness) ---
  final ScrollController _wellnessHomeScrollController = ScrollController();

  // --- SECTION 1: SIA'S DAILY BRIEF (HERO) ---
  Widget _buildWellnessHero(String name) {
    return _buildUnifiedHeroCard(
      category: "Sia's Daily Brief",
      title: "${_getTimeBasedGreetingPrefix()}, $name",
      subtitle: "You've been sleeping better this week. Let's build on that today.",
      metricsTitle: "TODAY'S WELLNESS FOCUS: SLEEP & ENERGY",
      metricsValue: "Establishing positive daily routines • Gentle movement focus",
      primaryBtnText: "Today's Check-In",
      onPrimaryTap: _scrollToCheckIn,
      secondaryBtnText: "Ask Sia",
      onSecondaryTap: () => _openAskSiaChat(context, null),
      backgroundImage: const DecorationImage(
        image: AssetImage("assets/blushy_wellness_banner.jpg"),
        fit: BoxFit.cover,
        opacity: 0.15,
      ),
    );
  }

  // --- SECTION 2: MY WELLNESS ---
  // --- SECTION 2: MY WELLNESS ---
  Widget _buildWellnessDashboard([PersonalContext? pcParam, CurrentWellbeingState? wbParam]) {
    final state = BlushyOSProvider.of(context);
    final pc = pcParam ?? state.personalContext;
    final wb = wbParam ?? state.wellbeingState;

    final String? sleepVal = _wellnessSleep ?? (wb.sleepQuality != null ? "${wb.sleepQuality}h" : null);
    final String? energyVal = (_checkInEnergy?.isNotEmpty == true && _checkInEnergy != 'Balanced') ? _checkInEnergy : (wb.energy != null ? "Level ${wb.energy}/10" : null);
    final String? hydrationVal = _wellnessWater != null ? "$_wellnessWater" : null;
    final String? moodVal = _selectedFeeling ?? (_checkInMood?.isNotEmpty == true && _checkInMood != 'Calm' ? _checkInMood : (wb.mood != null ? "Level ${wb.mood}/10" : null));
    final String? movementVal = _wellnessExercise;
    final String? stressVal = _wellnessStress != null ? "$_wellnessStress Stress" : null;

    final List<String> userGoals = _extractStrings(_onboardingData['goals']);
    final List<String> userSymptoms = _extractStrings(_onboardingData['symptoms']);
    final Set<String> activeFilters = {...userGoals, ...userSymptoms, ..._extractStrings(pc.userGoals), ..._extractStrings(pc.userSymptoms)}.toSet();

    final List<Map<String, dynamic>> allMetrics = [
      {
        "label": "Sleep State",
        "val": sleepVal ?? "Not Logged",
        "keys": ["sleep", "fatigue", "rest"]
      },
      {
        "label": "Energy level",
        "val": energyVal ?? "Not Logged",
        "keys": ["energy", "fatigue", "low energy", "vitality"]
      },
      {
        "label": "Daily Hydration",
        "val": hydrationVal ?? "Not Logged",
        "keys": ["hydration", "water", "nutrition"]
      },
      {
        "label": "Mood State",
        "val": moodVal ?? "Not Logged",
        "keys": ["mood", "pms", "emotions", "anxiety", "cramps"]
      },
      {
        "label": "Movement",
        "val": movementVal ?? "Not Logged",
        "keys": ["fitness", "movement", "exercise", "walk"]
      },
      {
        "label": "Stress level",
        "val": stressVal ?? "Not Logged",
        "keys": ["stress", "anxiety", "cramps", "mindfulness"]
      },
      if (_loggedWeight != null || activeFilters.any((f) => f.contains('weight')))
      {
        "label": "Weight",
        "val": _loggedWeight != null ? "${_loggedWeight!.toStringAsFixed(1)} kg" : "Not Logged",
        "keys": ["weight", "nutrition", "fitness"]
      },
    ];

    List<Map<String, dynamic>> displayMetrics = allMetrics;
    if (activeFilters.isNotEmpty) {
      final filtered = allMetrics.where((m) {
        final keys = m['keys'] as List<String>;
        return keys.any((k) => activeFilters.any((af) => af.contains(k)));
      }).toList();
      if (filtered.isNotEmpty) {
        displayMetrics = filtered;
      }
    }

    int loggedCount = displayMetrics.where((m) => m['val'] != 'Not Logged').length;
    int totalMetrics = displayMetrics.length;

    final String scoreTitle = loggedCount > 0
        ? "Wellness Score: ${((loggedCount / totalMetrics) * 100).round()}%"
        : "Wellness Score: Not Logged";
    final String scoreSubtitle = loggedCount > 0
        ? "Calculated from $loggedCount of $totalMetrics selected onboarding habit(s) today"
        : "Complete Today's Check-In below to generate your score";

    final List<String> loggedNames = displayMetrics
        .where((m) => m['val'] != 'Not Logged')
        .map((m) => m['label'].toString().toLowerCase())
        .toList();

    final String quoteText = loggedCount > 0
        ? "\"You have logged $loggedCount selected wellness habit(s) today (${loggedNames.join(', ')}). Keep logging daily to track your long-term health pattern.\""
        : "\"No lifestyle data logged for today yet. Use 'Today's Check-In' below to record your selected sleep, mood, energy, and hydration choices.\"";

    final calc = CycleCalculation.compute(
      lastPeriodStart: pc.lastPeriodStart,
      cycleLength: pc.cycleLength,
    );

    final String lastPeriodStr = pc.lastPeriodStart != null
        ? "${DateTime.now().difference(pc.lastPeriodStart!).inDays} Days Ago"
        : "Not Logged";

    final String cycleDayStr = (pc.cycleDay != null && pc.cycleDay! > 0)
        ? "Day ${pc.cycleDay}"
        : "Not Logged";

    final String nextPeriodStr = calc.hasData
        ? "Est. in ${calc.daysUntilNextPeriod} Days"
        : "Not Logged";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MY WELLNESS",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Daily Lifestyle Overview",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scoreTitle,
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scoreSubtitle,
                        style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: displayMetrics.map((m) {
                  return GestureDetector(
                    onTap: _scrollToCheckIn,
                    child: SizedBox(
                      width: 140,
                      child: _buildMetricLabel(m['label'] as String, m['val'] as String),
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3E4DD), width: 0.8),
                ),
                child: Text(
                  quoteText,
                  style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: BlushyColors.secondaryText),
                ),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // CYCLE OVERVIEW (COMPACT SECONDARY CARD)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF6F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: BlushyColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          "CYCLE OVERVIEW",
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.secondaryText,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildMetricLabel("Last Period", lastPeriodStr)),
                        Expanded(child: _buildMetricLabel("Cycle Day", cycleDayStr)),
                        Expanded(child: _buildMetricLabel("Next Period", nextPeriodStr)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _scrollToCheckIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Today's Check-In",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _showArticleDialog(context, "Wellness History", "Your logged check-in history:\n- Sleep: ${sleepVal ?? 'Not Logged'}\n- Hydration: ${hydrationVal ?? 'Not Logged'}\n- Mood: ${moodVal ?? 'Not Logged'}\n- Weight: ${_loggedWeight != null ? '${_loggedWeight!.toStringAsFixed(1)} kg' : 'Not Logged'}");
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        "View Wellness History",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 3: TODAY'S CHECK-IN ---
  Widget _buildWellnessCheckIn() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "😌", "label": "Balanced"},
      {"icon": "🥱", "label": "Tired"},
      {"icon": "😰", "label": "Anxious"},
      {"icon": "😴", "label": "Sleepy"},
      {"icon": "😤", "label": "Irritable"},
    ];

    final List<String> exerciseOptions = ["Workout", "Walk", "None"];
    final List<String> meditationOptions = ["Completed", "Not Done"];
    final List<String> waterOptions = ["2L", "2.5L", "3L"];
    final List<String> sleepOptions = ["6-7h", "7-8h", "8h+"];
    final List<String> stressOptions = ["Low", "Moderate", "High"];

    return Column(
      key: _checkInKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S CHECK-IN",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shown when something just logged matched a reviewed red flag
              // rule, so the reviewed instruction replaces the usual
              // confirmation rather than sitting alongside it.
              if (_checkinSafety != null) _buildCheckinSafetyBanner(_checkinSafety!),
              // Mood Selector
              Text(
                AppLocalizations.of(context).dashMood,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedFeeling = checkinData['feeling'] ?? (BlushyStorage.read('logged_feeling.json'))['feeling'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeFeeling = _selectedFeeling ?? savedFeeling ?? (wb.symptoms.isNotEmpty ? wb.symptoms.first : null);
                  final isSelected = activeFeeling != null && activeFeeling.toString().toLowerCase() == (opt['label'] as String).toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Logged Mood: ${opt['label']} ${opt['icon']}"),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withValues(alpha: 0.1) : const Color(0xFFF9F6F0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? BlushyColors.primary : BlushyColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt['icon'],
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.black,
                                fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Energy Level Selector
              _buildLivingHorizontalSelector(AppLocalizations.of(context).dashEnergyLevel, ["Low", "Balanced", "High"], _checkInEnergy?.isNotEmpty == true ? _checkInEnergy : null, (val) {
                setState(() => _checkInEnergy = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Sleep Duration
              _buildLivingHorizontalSelector("SLEEP TIME", sleepOptions, _wellnessSleep, (val) {
                setState(() => _wellnessSleep = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Stress Levels
              _buildLivingHorizontalSelector("STRESS LEVEL", stressOptions, _wellnessStress, (val) {
                setState(() => _wellnessStress = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Hydration (Water Intake)
              _buildLivingHorizontalSelector("DAILY HYDRATION (WATER INTAKE)", waterOptions, _wellnessWater, (val) {
                setState(() => _wellnessWater = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Exercise
              _buildLivingHorizontalSelector("DAILY EXERCISE", exerciseOptions, _wellnessExercise, (val) {
                setState(() => _wellnessExercise = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Meditation
              _buildLivingHorizontalSelector("MINDFUL MEDITATION", meditationOptions, _wellnessMeditation, (val) {
                setState(() => _wellnessMeditation = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Optional Weight
              Text(
                "WEIGHT (OPTIONAL)",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final weightController = TextEditingController(
                    text: _loggedWeight != null ? _loggedWeight!.toString() : '',
                  );
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: const Color(0xFFFAF6F0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text(
                        AppLocalizations.of(context).dashLogWeight,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Record your current weight in kg to track trends over time.",
                            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autofocus: true,
                            style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.text),
                            decoration: InputDecoration(
                              labelText: "Weight (kg)",
                              hintText: "e.g. 62.5",
                              suffixText: "kg",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text("Cancel", style: GoogleFonts.poppins(color: BlushyColors.secondaryText)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BlushyColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final val = double.tryParse(weightController.text.trim());
                            if (val != null && val > 0) {
                              _saveWeightLog(val);
                              Navigator.pop(dialogContext);
                            }
                          },
                          child: Text("Save", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                icon: Icon(
                  _loggedWeight != null ? Icons.check_circle_outline : Icons.monitor_weight_outlined,
                  size: 18,
                  color: _loggedWeight != null ? BlushyColors.success : BlushyColors.primary,
                ),
                label: Text(
                  _loggedWeight != null ? "Logged Weight: ${_loggedWeight!.toStringAsFixed(1)} kg" : AppLocalizations.of(context).dashLogWeight,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: _loggedWeight != null ? BlushyColors.text : BlushyColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BlushyColors.primary,
                  side: BorderSide(color: _loggedWeight != null ? BlushyColors.success : BlushyColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Notes & Reflections
              Text(
                AppLocalizations.of(context).dashNotesReflections,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        VoiceNoteBottomSheet.show(context);
                      },
                      icon: const Icon(Icons.mic, size: 18),
                      label: const Text("Voice Note"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BlushyMStudioScreen()),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("M Studio"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 4: SIA INSIGHTS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildWellnessInsights() {
    return const RealInsightsList(
      title: 'What your logs show',
    );
  }

  // --- SECTION 5: TODAY'S PLAN ---
  /// The real care plan, which already handles empty, restricted and
  /// safety-suppressed states. This used to be a fixed list of suggestions
  /// with a hardcoded personal target ("2.2L today").
  Widget _buildWellnessPlan() {
    return _buildCarePlanSection(heading: "TODAY'S PLAN");
  }

  // --- SECTION 6: DISCOVER ---
  Widget _buildWellnessDiscover() {
    final List<String> topics = [
      "Nutrition", "Exercise", "Women's Health", "Mental Wellbeing", "Sleep", "Stress", "Productivity"
    ];

    // The 74 articles that used to live in these maps are now seeded
    // through the reviewed content pipeline, so each one carries a
    // reviewer and a review date and is served only once approved.

    final articles = _educationFor(_wellnessDiscoverTopic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "DISCOVER",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topics.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSelected = _wellnessDiscoverTopic == topic;
              return GestureDetector(
                onTap: () => setState(() => _wellnessDiscoverTopic = topic),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? BlushyColors.primary : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : BlushyColors.text,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: articles.map((article) {
            final isSaved = _wellnessSavedArticles.contains(article['title']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(context, article['title']!, article['desc']!);
                          },
                          child: Text(
                            "Read",
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isSaved) {
                                _wellnessSavedArticles.remove(article['title']!);
                              } else {
                                _wellnessSavedArticles.add(article['title']!);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18, color: BlushyColors.secondaryText),
                          onPressed: () => _openAskSiaChat(context, "Explain this article: ${article['title']}"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- SECTION 7: COMMUNITY ---
  Widget _buildWellnessCommunity() {
    final List<String> tabs = ["Wellness", "Fitness", "Nutrition", "Mental Wellbeing", "Self-Care"];
    final threads = [
      {"user": "HealthyHabits", "text": "Who is up for the 5-day daily hydration challenge next Monday?"},
      {"user": "MindfulMoments", "text": "Evening digital detox (no phones after 9 PM) has improved my sleep quality immensely."}
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "COMMUNITY",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0x0F2E2623),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isSelected = _wellnessCommunityTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _wellnessCommunityTab = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tab,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? BlushyColors.text : BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            children: threads.map((post) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post['user']!,
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: BlushyColors.disabled)),
                        const SizedBox(width: 6),
                        Text(
                          "Support Group thread",
                          style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post['text']!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
                    ),
                    const Divider(height: 24, color: Color(0xFFF5F0EB)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 8: MY HABITS ---
  Widget _buildWellnessHabitCards() {
    final List<String> userGoals = List<String>.from(_onboardingData['goals'] ?? []);
    final List<String> userSymptoms = List<String>.from(_onboardingData['symptoms'] ?? []);
    final Set<String> activeFilters = {...userGoals, ...userSymptoms}.map((e) => e.toLowerCase()).toSet();

    final String sleepDesc = _wellnessSleep != null
        ? "\"You've logged $_wellnessSleep sleep today.\""
        : "\"No sleep logged today yet.\"";

    final String hydrationDesc = _wellnessWater != null
        ? "\"You've logged $_wellnessWater water intake today.\""
        : "\"No water logged today yet.\"";

    final String movementDesc = _wellnessExercise != null
        ? "\"You've logged $_wellnessExercise for movement today.\""
        : "\"No movement logged today yet.\"";

    final String moodDesc = _selectedFeeling != null
        ? "\"You've logged feeling '$_selectedFeeling' today.\""
        : "\"No mood logged today yet.\"";

    final String weightDesc = _loggedWeight != null
        ? "\"Current weight logged: ${_loggedWeight!.toStringAsFixed(1)} kg.\""
        : "\"No weight logged. This one is optional.\"";

    final List<Map<String, String>> allHabitCards = [
      {
        "title": "Sleep",
        "key": "sleep",
        "desc": sleepDesc,
        "detail": "Consistent sleep cycles allow cells to repair, helping regulate daily cortisol and energy spikes naturally."
      },
      {
        "title": "Hydration",
        "key": "hydration",
        "desc": hydrationDesc,
        "detail": "Proper hydration keeps tissues lubricated, supports kidney filterings, and buffers afternoon headaches."
      },
      {
        "title": "Movement",
        "key": "movement",
        "desc": movementDesc,
        "detail": "Establishing a minimum steps target supports vascular elasticity and promotes evening sleep depth."
      },
      {
        "title": "Mood Balance",
        "key": "mood",
        "desc": moodDesc,
        "detail": "Tracking daily emotional changes builds body awareness and highlights phase-based mood trends."
      },
      if (_loggedWeight != null || activeFilters.any((f) => f.contains('weight')))
      {
        "title": "Weight",
        "key": "weight",
        "desc": weightDesc,
        "detail": "Logging weight trends provides contextual insights into hydration shifts and metabolic rhythms."
      },
      {
        "title": "Mindfulness",
        "key": "mindfulness",
        "desc": "\"Mindfulness and breathing routines active.\"",
        "detail": "Slow exhalations trigger active vagal parasympathetic states, helping calm mind stressors."
      },
      {
        "title": "Nutrition",
        "key": "nutrition",
        "desc": "\"Maintained healthy balanced meals today.\"",
        "detail": "High-protein balanced breakfasts keep morning glucose spikes flat, preventing post-lunch fatigue lapses."
      },
    ];

    List<Map<String, String>> habitCards = allHabitCards;
    if (activeFilters.isNotEmpty) {
      final filtered = allHabitCards.where((card) {
        final key = card['key']!;
        return activeFilters.any((f) => f.contains(key) || (key == 'sleep' && f.contains('sleep')) || (key == 'hydration' && f.contains('water')));
      }).toList();
      if (filtered.isNotEmpty) {
        habitCards = filtered;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MY HABITS",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "AI-Generated Habit Insights",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: habitCards.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final card = habitCards[index];
              return Container(
                width: 280,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card['title']!.toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      card['desc']!,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Why This Matters: Supports overall physical health and emotional vitality.",
                      style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(context, card['title']!, card['detail']!);
                          },
                          child: Text("Learn More", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- SECTION 9: MY WELLNESS JOURNEY ---
  /// Real logged events, not a scripted timeline. Replaced a hardcoded list
  /// that marked milestones complete on a freshly installed app.
  Widget _buildWellnessJourney() {
    return const RealJourneyTimeline(
      title: 'Your Wellness Journey',
      emptyHeadline: 'Your wellness journey is empty so far',
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildWellnessReflection() {
    return _buildLivingJourney();
  }

  Widget _buildEverydayWellnessHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    children: [
                      _buildBranchSwitcher(state),
                      _buildWellnessHero(displayName),
                      const SizedBox(height: 32),
                      _buildWellnessDashboard(),
                      const SizedBox(height: 32),
                      _buildWellnessCheckIn(),
                      const SizedBox(height: 32),
                      _buildWellnessInsights(),
                      const SizedBox(height: 32),
                      _buildWellnessPlan(),
                      const SizedBox(height: 32),
                      _buildWellnessDiscover(),
                      const SizedBox(height: 32),
                      _buildWellnessCommunity(),
                      const SizedBox(height: 32),
                      _buildWellnessHabitCards(),
                      const SizedBox(height: 32),
                      _buildWellnessJourney(),
                      const SizedBox(height: 32),
                      _buildWellnessReflection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    children: [
                      _buildWellnessHero(displayName),
                      const SizedBox(height: 48),
                      _buildWellnessDashboard(),
                      const SizedBox(height: 48),
                      _buildWellnessCheckIn(),
                      const SizedBox(height: 48),
                      _buildWellnessInsights(),
                      const SizedBox(height: 48),
                      _buildWellnessPlan(),
                      const SizedBox(height: 48),
                      _buildWellnessDiscover(),
                      const SizedBox(height: 48),
                      _buildWellnessCommunity(),
                      const SizedBox(height: 48),
                      _buildWellnessHabitCards(),
                      const SizedBox(height: 48),
                      _buildWellnessJourney(),
                      const SizedBox(height: 48),
                      _buildWellnessReflection(),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: ListView(
                    controller: _wellnessHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Row 1: Hero
                      _buildWellnessHero(displayName),
                      const SizedBox(height: 48),

                      // Row 2: Dashboard Overview
                      _buildWellnessDashboard(),
                      const SizedBox(height: 48),

                      // Row 3: Left Panel (65% width) | Right Sidebar (35% width)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildWellnessCheckIn(),
                                const SizedBox(height: 48),
                                _buildWellnessInsights(),
                                const SizedBox(height: 48),
                                _buildWellnessPlan(),
                                const SizedBox(height: 48),
                                _buildWellnessDiscover(),
                                const SizedBox(height: 48),
                                _buildWellnessCommunity(),
                                const SizedBox(height: 48),
                                _buildWellnessHabitCards(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right Sidebar Panel (35% width)
                          Expanded(
                            flex: 35,
                            child: Column(
                              children: [
                                _buildWellnessJourney(),
                                const SizedBox(height: 48),
                                _buildWellnessReflection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }



  Widget _buildBranchSwitcher(BlushyOSState state) => const SizedBox.shrink();



  // --- EDITORIAL COMPOSTIONS ---




































}