import '../../../../services/api_period_service.dart';
import 'dart:async';
// Dynamic dashboard generated for stage: everyday_wellness
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/checkin_merge.dart';
import '../../../../core/metric_gating.dart';
import '../../../../core/tracker_log.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../widgets/checkin_card_stack.dart';
import '../../widgets/cycle_card.dart';
import '../../widgets/metric_trend_chart.dart';
import '../../widgets/numeric_metric_sheet.dart';
import '../../widgets/symptom_log_sheet.dart';
import '../../widgets/real_insights_list.dart';
import '../../widgets/real_cycle_history.dart';
import '../../widgets/real_journey_timeline.dart';
import '../../../../services/sia_dashboard_service.dart';
import '../../../../services/api_blushy_service.dart';
import '../../../../services/api_contract_client.dart';
import '../../../../services/auth_storage.dart';
import '../../checkin_event_mapper.dart';
import '../../checkin_followups.dart';
import '../../checkin_vocabulary.dart';
import '../../symptom_categories.dart';
import '../../symptom_category_preference.dart';
import '../../../../services/daily_rollover.dart';
import '../../../../services/offline_event_queue.dart';
import '../../../../shared/api_state_card.dart';
import '../doctor_summary_screen.dart';
import '../../../../models/blushy_models.dart';
import '../../../sia/sia_screen.dart';
import '../../../sia/open_docsy.dart';
import '../../home_screen.dart';
import 'living_with_my_cycle_dashboard.dart';
import '../../../../shared/section_heading.dart';
import '../../blushy_shell.dart';
import '../../widgets/home_sections.dart';
import '../../widgets/home_hero.dart';
import '../../widgets/greeting_card.dart' show GreetingCard;
import '../../widgets/home_insight_cards.dart';
import '../../widgets/monthly_journey_card.dart';
import '../../widgets/auto_carousel_cards.dart';
import '../../../../theme/scale.dart';
import '../../home_section_order.dart';
import '../../../../shared/user_display_name.dart';

String _getTimeBasedGreetingPrefix() {
  final istNow = DateTime.now().toUtc().add(
    const Duration(hours: 5, minutes: 30),
  );
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
  State<EverydayWellnessDashboard> createState() =>
      _EverydayWellnessDashboardState();
}

class _EverydayWellnessDashboardState extends State<EverydayWellnessDashboard>
    with SingleTickerProviderStateMixin {

  // State variables for Restored Stage 1, 2 & 3
  final Map<String, bool> _stage1PeriodKitItems = {
    '2-3 soft sanitary pads': true,
    'Fresh pair of backup underwear': true,
    'Small ziplock bag for used items': true,
    'Gentle soothing wet wipes': true,
    'Travel-sized hand sanitizer': true,
    'Favorite comforting chocolate or snack': false,
  };
  String _selectedSelfCareCategory = 'All';
  String _stage1SelectedMood = 'Calm';
  double _stage1EnergyLevel = 5.0;
  String _stage2SelectedTab = 'School';
  String _stage2SelectedKitScenario = 'School Bag';
  final Map<String, Map<String, bool>> _stage2AllKitScenarios = {
    'School Bag': {
      '2-3 daytime sanitary pads': true,
      '1 spare underwear in ziplock': true,
      'Pocket tissue / gentle wet wipes': true,
      'Emergency pain relief patch / roll-on': false,
      'Discreet pouch (stays in backpack)': true,
    },
    'College / Work': {
      '3-4 heavy/medium pads or tampons': true,
      'Spare change of underwear/leggings': true,
      'Soothing cramp balm / herbal tea bags': true,
      'Discreet opaque zipper bag': true,
    },
    'Home Comfort': {
      'Nighttime long pads / period underwear': true,
      'Heating pad / hot water bottle': true,
      'Cozy loose sweatpants': true,
      'Dark-colored bed towel': true,
    },
  };
  String _stage2SelectedMood = 'Calm';
  String _stage2SelectedCramp = 'Mild';
  String _stage2LoggedFlow = 'Medium';
  String _selectedStage3LifestyleTab = 'Work & Focus';

  late final AnimationController _animController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _wrapDashboardLayout({
    required Widget child,
    GlobalKey<ScaffoldState>? scaffoldKey,
  }) {
    if (widget.isNested) {
      return Container(color: BlushyColors.background, child: child);
    }
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: BlushyColors.background,
      body: SafeArea(child: child),
    );
  }

  ScrollPhysics get _effectiveScrollPhysics => widget.isNested
      ? const NeverScrollableScrollPhysics()
      : const BouncingScrollPhysics();

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
  // Starts empty. This was seeded with a lesson title, and because the
  // server load calls addAll rather than replacing, the seed never
  // cleared: every new account was told it had already completed
  // "Understanding My Body".
  final Set<String> _completedLessons = {};
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
  String? _livingFlow;
  String? _livingPain;
  String? _livingSleep;
  String? _livingStress;
  String? _livingWater;
  String? _livingExercise;

  // hormonalHealth interactive states
  String _hormonalDiscoverTopic = 'Understanding PCOS';
  final Set<String> _hormonalSavedArticles = {};

  /// Metrics she has changed in this session.
  ///
  /// Switching tabs triggers a full backend sync, and the sync re-applied the
  /// stored value over whatever she had just picked -- so a selection made a
  /// second earlier was replaced by yesterday's, or by nothing. Her choice
  /// wins until it has been written and read back.
  final Set<String> _userEditedMetrics = {};

  /// One sentence from the analysis run when she finished onboarding.
  String? _onboardingAnalysisSummary;

  // Stage 4 Hormonal Health Interactive States
  String _selectedHormonalCondition = 'pcos'; // 'pcos', 'endo', 'pmdd', 'thyroid', 'irregular'
  int _selectedHormonalTab = 0; // 0: Symptoms & SOS, 1: Glucose Buffer, 2: Supplements, 3: Lab & Doctor
  bool _stage4Initialized = false;
  int _endoPainScale = 4; // 1 to 10
  final Set<String> _stage4LoggedSymptoms = {};
  final Set<String> _glucosePlateItems = {};
  final Set<String> _loggedSupplements = {};
  final List<Map<String, dynamic>> _userLoggedLabResults = [];
  final List<Map<String, dynamic>> _customUserSupplementsList = [];
  bool _heatTimerActive = false;
  int _heatTimerSecondsRemaining = 900; // 15 mins (900 seconds)
  Timer? _heatTimer;
  String? _lastTappedSymptom;
  double _dailyHydrationGoalLiters = 2.5;
  int _dailySleepGoalHours = 8;
  final Set<String> _customSupplements = {};

  // Symptoms the PCOS branch asks about
  String? _hormonalHairThinning;
  String? _hormonalFacialHair;
  String? _hormonalWeightChange;
  String? _hormonalBloating;
  String? _hormonalAcne;
  String? _hormonalHeadache;
  String? _hormonalMedication;

  // tryingToConceive interactive states
  String _ttcDiscoverTopic = 'Understanding Ovulation';
  final Set<String> _ttcSavedArticles = {};
  String? _ttcCervicalMucus;
  String? _ttcLhTest;
  int _selectedTtcActionTab = 0; // 0: 🎯 Fertile Protocol, 1: 🌡️ Biometrics, 2: ⏳ Two-Week Wait, 3: 🤝 Partner Sync, 4: 📊 Doctor Export
  double? _ttcLoggedBBT;
  String? _ttcLoggedOPK; // 'Peak (Surge)', 'High', 'Negative / Low'
  String? _ttcLoggedCervicalFluid; // 'Egg White (Peak)', 'Watery', 'Creamy', 'Sticky', 'Dry'
  bool _ttcLoggedIntercourse = false;
  final Set<String> _ttcCompletedTodayActions = {};
  final List<Map<String, dynamic>> _ttcPartnerTaskList = [
    {
      "id": "1",
      "task": "Stay hydrated throughout the day",
      "who": "Partner Task",
      "completed": false,
    },
    {
      "id": "2",
      "task": "Avoid excessive heat today (hot baths, sauna, laptop on lap)",
      "who": "Partner Task",
      "completed": false,
    },
    {
      "id": "3",
      "task": "Take clinician-prescribed supplements",
      "who": "Coordinated Task",
      "completed": false,
    },
    {
      "id": "4",
      "task": "Get enough sleep (7-8 hours of restorative rest)",
      "who": "Coordinated Task",
      "completed": false,
    },
    {
      "id": "5",
      "task": "Be there during the fertile window",
      "who": "Partner Task",
      "completed": false,
    },
  ];

  // pregnancy interactive states
  String _pregnancyDiscoverTopic = 'Baby Development';
  final Set<String> _pregnancySavedArticles = {};
  String? _pregnancyBabyMovement;

  // postpartum interactive states
  String _postpartumDiscoverTopic = 'Physical Recovery';
  final Set<String> _postpartumSavedArticles = {};
  String? _postpartumFeeding;
  String? _postpartumBleeding;
  String? _postpartumIncision;
  String? _postpartumPelvic;
  String? _postpartumWater;
  String? _postpartumExercise;

  // perimenopause interactive states
  String _periDiscoverTopic = 'Hormonal Changes';
  final Set<String> _periSavedArticles = {};
  String? _periWeightChange;
  String? _periVaginalDryness;
  String? _periHotFlashes;
  String? _periNightSweats;

  late PeriodConfirmationState _periodConfirmationState;

  // menopause interactive states
  String _menoDiscoverTopic = 'Understanding Menopause';
  final Set<String> _menoSavedArticles = {};
  String? _menoVaginalDryness;
  String? _menoBoneJoint;
  String? _menoHeartHealth;
  String? _menoHotFlashes;
  String? _menoNightSweats;

  // everydayWellness interactive states
  String? _wellnessExercise;
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

  /// The icon drawn for each glyph the option lists carry.
  ///
  /// These were emoji, painted with a fallback stack of system emoji fonts --
  /// Apple Color Emoji, Segoe UI Emoji, Noto Color Emoji. None of those exist
  /// under CanvasKit, so on the web every mood in the check-in drew as a tofu
  /// box: five identical empty squares where the faces should be. Icons ship
  /// inside the app, so they render the same on a phone and in a browser.
  ///
  /// Keyed by the glyph rather than rewritten into the option lists, so the
  /// stored label and the value written to `daily_checkin.json` are untouched
  /// and a check-in saved before this still reads back correctly.
  static const Map<String, IconData> _optionGlyphIcons = {
    '\u{1F60A}': Icons.sentiment_very_satisfied_rounded, // happy
    '\u{1F642}': Icons.sentiment_satisfied_rounded, // okay
    '\u{1F60C}': Icons.self_improvement_rounded, // calm
    '\u{1F616}': Icons.sentiment_very_dissatisfied_rounded, // cramps
    '\u{1F971}': Icons.bedtime_rounded, // tired
    '\u{1F624}': Icons.mood_bad_rounded, // irritable
    '\u{1F630}': Icons.sentiment_dissatisfied_rounded, // anxious
    '\u{1F634}': Icons.nights_stay_rounded, // sleepy
    '\u{1F922}': Icons.sick_rounded, // nauseous
    '\u{1F92F}': Icons.psychology_rounded, // overwhelmed
    '\u{1F970}': Icons.favorite_rounded, // loved
    '\u{1F97A}': Icons.sentiment_neutral_rounded, // low
    '\u{2728}': Icons.auto_awesome_rounded,
    '\u{1F33F}': Icons.spa_rounded,
    '\u{1F3AD}': Icons.theater_comedy_rounded,
    '\u{1F4AA}': Icons.fitness_center_rounded,
    '\u{1F525}': Icons.local_fire_department_rounded,
  };

  /// Falls back to a neutral face rather than nothing, so an option added
  /// later still draws something while it waits for an icon of its own.
  static IconData _optionIcon(Object? glyph) =>
      _optionGlyphIcons[glyph?.toString()] ?? Icons.sentiment_neutral_rounded;

  /// Writes one check-in answer where the rest of the app can find it again.
  ///
  /// The wellness selectors only called `setState`, so an answer lived until
  /// the next rebuild and no further. Changing tabs or reopening the app
  /// dropped it, and the overview above then fell back to the figure the
  /// server last held -- which is why a stress level logged as Moderate could
  /// read Low a few minutes later without anyone touching it, and why the
  /// score it was counted into went back to "Not Logged".
  ///
  /// The living selectors already did all four of these steps inline, once per
  /// metric. This is that same sequence in one place.
  void _persistCheckinAnswer(String key, String value) {
    final checkin = Map<String, dynamic>.from(
      BlushyStorage.read('daily_checkin.json'),
    );
    checkin[key] = value;
    // Mood is read back under both names; the restore path tries each.
    if (key == 'mood') checkin['feeling'] = value;
    checkin['date'] = DateTime.now().toIso8601String();
    BlushyStorage.write('daily_checkin.json', checkin);

    // A timestamped health event, so patterns and the doctor summary can see
    // this entry rather than only the dashboard.
    _recordCheckinEvent(key, value);

    // Her choice wins over the next background sync, which would otherwise
    // re-apply the stored server value on top of it.
    _userEditedMetrics.add('daily_$key');

    ApiAuthService()
        .saveOnboardingAnswers({'daily_$key': value, 'daily_checkin': checkin})
        .catchError((_) => <String, dynamic>{});
  }

  /// Recent readings per numeric metric, oldest first, for the trend chart.
  final Map<String, List<MetricReading>> _metricHistory = {};

  /// Today's value for a numeric metric, or null.
  double? _numericValue(String key) {
    final raw = BlushyStorage.read('daily_checkin.json')[key];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  /// Loads the last month of readings so the sheet opens with a trend.
  ///
  /// Best-effort: the sheet is useful without it, so a failure leaves the
  /// chart empty rather than blocking entry.
  Future<void> _loadMetricHistory(NumericMetric metric) async {
    final result = await EventsApi.list(
      eventTypes: [metric.eventType],
      from: DateTime.now().subtract(const Duration(days: 30)),
      limit: 60,
    );
    if (!mounted || !result.isReady || result.data == null) return;

    final readings = <MetricReading>[];
    // The API returns newest first; a trend line reads the other way.
    for (final event in result.data!.reversed) {
      final raw = event.payload[metric.payloadKey];
      if (raw is num) {
        readings.add(
          MetricReading(day: event.timestamp, value: raw.toDouble()),
        );
      }
    }
    if (!mounted) return;
    setState(() => _metricHistory[metric.key] = readings);
  }

  void _persistNumericMetric(NumericMetric metric, double value) {
    final checkin = Map<String, dynamic>.from(
      BlushyStorage.read('daily_checkin.json'),
    );
    checkin[metric.key] = value;
    checkin['date'] = DateTime.now().toIso8601String();
    BlushyStorage.write('daily_checkin.json', checkin);

    _recordNumericEvent(metric, value);
    _userEditedMetrics.add('daily_${metric.key}');

    ApiAuthService()
        .saveOnboardingAnswers({
          'daily_${metric.key}': value,
          'daily_checkin': checkin,
        })
        .catchError((_) => <String, dynamic>{});
  }

  Future<void> _recordNumericEvent(NumericMetric metric, double value) async {
    final clientEventId = CheckinEventMapper.idempotencyKey(
      userId: AuthStorage.getUserId() ?? 'anon',
      metric: metric.key,
      day: DateTime.now(),
    );
    final payload = {metric.payloadKey: value};

    final result = await EventsApi.log(
      eventType: metric.eventType,
      payload: payload,
      clientEventId: clientEventId,
    );

    if (result.state == ApiState.offline || result.state == ApiState.error) {
      await OfflineEventQueue.instance.enqueue(
        eventType: metric.eventType,
        payload: payload,
        clientEventId: clientEventId,
      );
    }
  }

  /// Opens the entry sheet for one numeric metric.
  Future<void> _openNumericMetric(NumericMetric metric) async {
    // Fetched on open rather than on build: the chart is only ever seen here,
    // and every dashboard would otherwise pay for two requests it may not use.
    unawaited(_loadMetricHistory(metric));
    await NumericMetricSheet.show(
      context,
      metric: metric,
      initialValue: _numericValue(metric.key),
      history: _metricHistory[metric.key] ?? const [],
      onSave: (value) => _persistNumericMetric(metric, value),
    );
    if (mounted) setState(() {});
  }

  /// A stage home's sections in the order she asked for at onboarding.
  List<Widget> _orderedHome(List<HomeSection> sections, {required Widget gap}) {
    List<String> picks(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty) return [v];
      return const <String>[];
    }

    Map<String, dynamic> profile;
    try {
      final data = BlushyStorage.read('user_profile.json');
      final p = data['profile'];
      profile = p is Map ? Map<String, dynamic>.from(p) : Map<String, dynamic>.from(data);
    } catch (_) {
      profile = _onboardingData;
    }

    final stage = _resolveStageKey(_currentPc);
    final byStage = profile['stage_answers'];
    final forStage = byStage is Map ? byStage[stage] : null;
    final stagePicks = forStage is Map ? Map<String, dynamic>.from(forStage) : null;

    final answers = profile['answers'];
    final goals = stagePicks != null && (stagePicks['goals'] != null || stagePicks['not_started_learn'] != null)
        ? [
            ...picks(stagePicks['goals']),
            ...picks(stagePicks['not_started_learn']),
            ...picks(stagePicks['desired_help']),
          ]
        : [
            ...picks(profile['goals']),
            if (answers is Map) ...picks(answers['goals']),
            ...picks(profile['not_started_learn']),
          ];
    final symptoms = stagePicks != null && stagePicks['symptoms'] != null
        ? picks(stagePicks['symptoms'])
        : [
            ...picks(profile['symptoms']),
            if (answers is Map) ...picks(answers['symptoms']),
          ];
    return HomeSectionOrder.layout(sections, gap: gap, goals: goals, symptoms: symptoms);
  }

  /// The life stage the dashboard is rendering.
  String _resolveStageKey(PersonalContext pc) {
    if (widget.stageKey != null && widget.stageKey!.isNotEmpty) {
      return widget.stageKey!;
    }
    final active = StageConflictEngine.dominantStage(widget.activeStages ?? pc.activeLifeStages);
    return (active ??
            (pc.lifeStage ??
                _onboardingData['lifeStage'] ??
                _onboardingData['life_stage'] ??
                _onboardingData['stage'] ??
                'firstPeriodNotStarted'))
        .toString();
  }

  /// Today's check-in.
  ///
  /// It used to be seven builders of fixed selectors -- mood, energy, flow,
  /// pain, sleep, stress, water, movement, and whatever else that stage
  /// tracked. Those all live in the symptoms sheet now, reached from Today's
  /// Cycle, so there is one place to log.
  ///
  /// What is left here is what today's entries earn: the follow-up questions
  /// generated from what she logged. Log nothing and this is a prompt rather
  /// than a form.
  Widget _buildCheckIn() {
    final followUps = _buildGeneratedFollowUps();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("CHECK IN"),
        ),
        const SizedBox(height: BlushySpace.xs),
        // No panel. The check-in sits on the page like the sections around it
        // -- the white card with a border was the only thing making it look
        // like a separate surface.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shown when something just logged matched a reviewed red flag
              // rule, so the reviewed instruction replaces the usual
              // confirmation rather than sitting alongside it.
              if (_checkinSafety != null)
                _buildCheckinSafetyBanner(_checkinSafety!),
              if (_loggedSymptoms.isEmpty)
                Text(
                  'Nothing to ask yet. Log today\'s symptoms above and the '
                  'questions worth asking will appear here.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.4,
                    color: BlushyColors.secondaryText,
                  ),
                )
              else if (followUps is SizedBox)
                // She logged, but nothing she logged has a follow-up rule.
                Text(
                  'Logged for today. Nothing further to ask.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: BlushyColors.secondaryText,
                  ),
                )
              else
                followUps,
            ],
          ),
        ),
      ],
    );
  }

  /// Symptom logging, as its own section.
  ///
  /// Deliberately not part of CHECK IN. The check-in is the follow-up
  /// questions today's entries earned; this is the way in to make those
  /// entries. They were merged before, and the merge had a cost that was easy
  /// to miss: the button sat inside the check-in's *empty* state, so the only
  /// way to open the sheet vanished the moment anything was logged.
  /// Correcting a mis-tapped symptom then meant hunting for a row in RECENTLY
  /// to tap.
  ///
  /// Always present, therefore -- logging a second symptom an hour later, or
  /// fixing the first, is the ordinary case rather than the exception.
  ///
  /// Which groups the sheet offers is decided by the life stage, through
  /// [SymptomCategories.forStage] and the key from [_resolveStageKey], so this
  /// one section asks a different set of questions in each stage without
  /// needing a variant per stage.
  Widget _buildLogSymptoms() {
    final logged = _loggedLabels;
    final hasLogged = logged.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("LOG SYMPTOMS"),
        ),
        const SizedBox(height: BlushySpace.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasLogged ? 'Logged today' : 'Nothing logged yet today.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasLogged
                    ? _loggedSummaryLine(logged)
                    : 'Log what you are feeling today. What you are asked '
                        'about follows your stage.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  height: 1.4,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _openSymptomSheet,
                  style: FilledButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    hasLogged ? "Edit today's symptoms" : "Log today's symptoms",
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// What is already down for today, named rather than counted.
  ///
  /// Capped: this is a reminder of what is recorded, not the record itself --
  /// the sheet reopens with every one of them still selected.
  String _loggedSummaryLine(Set<String> logged) {
    const maxNamed = 4;
    final names = logged.toList()..sort();
    if (names.length <= maxNamed) {
      return names.join(', ');
    }
    return '${names.take(maxNamed).join(', ')} +${names.length - maxNamed} more';
  }

  /// The logging section and the check-in, in that order.
  ///
  /// Two sections with their own headings rather than one merged block:
  /// logging is what she does, the check-in is what the app asks back.
  Widget _buildLogAndCheckIn() {
    return Column(
      // Every "go and log something" control scrolls here. It used to carry
      // the reader to CHECK IN, which since the split holds no control at all;
      // on the pair, the logging button is the first thing in view.
      key: _checkInKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLogSymptoms(),
        const SizedBox(height: 32),
        _buildCheckIn(),
      ],
    );
  }

  /// The questions today's symptoms earn, if any.
  ///
  /// Empty on a day with nothing logged, so the check-in stays as short as it
  /// was. The rules are in [CheckinFollowUps] rather than here so they can be
  /// tested without building this widget.
  Widget _buildGeneratedFollowUps() {
    // Answered cards leave the deck. They used to stay, with a tick on the
    // chip, and come round again on every swipe -- which read as the app not
    // having heard the answer.
    final cards = CheckinFollowUps.forSymptoms(_loggedLabels)
        .where((card) => !_followUpAnswered(card))
        .toList();
    if (cards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.zero,
      child: CheckinCardStack(
        cards: cards,
        // Read at build rather than captured once, so answering a card shows
        // on it straight away instead of on the next rebuild.
        answerFor: _answerFor,
        onAnswer: _answerFollowUp,
      ),
    );
  }

  /// Removes today's events of the given types: from the offline queue if
  /// they never left the device, and from the server if they did.
  ///
  /// The server's delete is soft and drops the event from every listing, so
  /// the sparkline, the patterns and Docsy's context stop seeing it -- the
  /// same as if it had not been logged. With no connection the delete is
  /// queued and runs on the next flush, ahead of any queued logs.
  Future<void> _deleteLoggedEvents(Set<String> eventTypes) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    for (final type in eventTypes) {
      await OfflineEventQueue.instance.removeWhere(eventType: type, day: now);
    }

    final listed = await EventsApi.list(
      eventTypes: eventTypes.toList(),
      from: startOfDay,
      to: endOfDay,
      limit: 100,
    );
    if (!listed.isReady || listed.data == null) {
      // No connection: the removal waits in the queue and runs on the next
      // flush, against only the events stamped before now.
      for (final type in eventTypes) {
        await OfflineEventQueue.instance.enqueueDelete(
          eventType: type,
          day: now,
          before: now,
        );
      }
      return;
    }
    for (final event in listed.data!) {
      final result = await EventsApi.delete(event.eventId);
      if (!result.isReady) {
        // Lost the connection part way: queue the rest rather than leave
        // half the day deleted.
        await OfflineEventQueue.instance.enqueueDelete(
          eventType: event.eventType,
          day: now,
          before: now,
        );
      }
    }
  }

  /// What was answered on a card today, or null.
  String? _answerFor(CheckinFollowUp card) =>
      BlushyStorage.read('daily_checkin.json')[card.metric]?.toString();

  /// Records a follow-up answer as an ordinary check-in answer.
  ///
  /// It writes the same metric the check-in card for that metric writes, so
  /// there is one series per metric rather than a parallel one -- and so the
  /// pattern engine cannot tell, and must not tell, which surface produced it.
  void _answerFollowUp(CheckinFollowUp card, String value) {
    _persistCheckinAnswer(card.metric, value);
    // Remembered by the card's id, not by its metric having a value: the
    // cards write the same metrics the sheet does, so "the metric has a
    // value" meant "the sheet was used", and every card vanished.
    final checkin = Map<String, dynamic>.from(
      BlushyStorage.read('daily_checkin.json'),
    );
    final answered = <String>{
      ...((checkin['answered_followups'] as List?)?.map((e) => e.toString()) ?? const <String>[]),
      card.id,
    };
    checkin['answered_followups'] = answered.toList();
    BlushyStorage.write('daily_checkin.json', checkin);
    setState(() {});
  }

  /// Whether [card] was answered today.
  bool _followUpAnswered(CheckinFollowUp card) {
    final raw = BlushyStorage.read('daily_checkin.json')['answered_followups'];
    return raw is List && raw.contains(card.id);
  }

  /// What was logged on an earlier day, for the sheet's back arrow.
  ///
  /// Today lives on the device; an earlier day exists only as stored events,
  /// so it is fetched and turned back into the words she tapped. An empty set
  /// is a real answer -- the sheet says nothing was logged rather than showing
  /// an empty form that looks like it failed to load.
  Future<Set<String>> _loadLoggedDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final result = await EventsApi.list(
      eventTypes: const [
        'mood_logged',
        'symptom_logged',
        'energy_logged',
        'sleep_logged',
        'stress_logged',
        'hydration_logged',
        'pain_logged',
        'flow_logged',
        'activity_logged',
        'cervical_mucus_logged',
        'lh_test_logged',
        'sexual_activity_logged',
        'pregnancy_test_logged',
        'feeding_logged',
        'hot_flash_logged',
        'recovery_metric_logged',
        'medication_logged',
      ],
      from: start,
      to: end,
      limit: 200,
    );

    if (!result.isReady || result.data == null) return <String>{};

    final keys = <String>{};
    for (final event in result.data!) {
      final mapped = CheckinEventMapper.reverse(event.eventType, event.payload);
      if (mapped == null) continue;
      // Back to the group that recorded it, by metric and word together, so
      // yesterday's "Low" lands on the chip it was tapped on.
      final owner = SymptomCategories.all.cast<SymptomCategory?>().firstWhere(
        (c) => c != null && c.metric == mapped.key && c.options.contains(mapped.value),
        orElse: () => null,
      );
      keys.add(owner == null
          ? mapped.value
          : SymptomKey.qualify(owner.id, mapped.value));
    }
    return keys;
  }

  /// Today's symptoms, read back from storage.
  /// Everything logged today, as the sheet's own keys.
  ///
  /// The flat symptom list, plus each single-answer metric's stored pick --
  /// energy "Low", pain "Severe" -- each qualified with its group, so the
  /// sheet reopens with them selected and "Low" lands on the right chip.
  Set<String> get _loggedSymptoms {
    final checkin = BlushyStorage.read('daily_checkin.json');
    final out = <String>{};

    final raw = checkin['symptom'];
    if (raw is List) {
      out.addAll(raw.map((e) => SymptomKey.normalise(e.toString())));
    }

    for (final category in SymptomCategories.all) {
      if (category.multiSelect) continue;
      final pick = checkin[category.metric];
      if (pick is String && category.options.contains(pick)) {
        out.add(SymptomKey.qualify(category.id, pick));
      }
    }
    return out;
  }

  /// The same, as bare words, for the follow-up rules.
  Set<String> get _loggedLabels => _loggedSymptoms.map(SymptomKey.label).toSet();

  /// Opens the one logging surface.
  ///
  /// Reached from the "Log Today's Symptoms" button in Today's Cycle. There
  /// was briefly a second button under the check-in as well; two entry points
  /// to one sheet is one too many.
  Future<void> _openSymptomSheet() async {
    await SymptomLogSheet.show(
      context,
      initialSelection: _loggedSymptoms,
      onSave: _persistCheckinSymptoms,
      // Weight and basal temperature are rows on the same sheet, saved on the
      // same confirm rather than through a second dialog.
      initialNumeric: {
        for (final id in const ['weight', 'bbt'])
          if (_numericValue(id) != null) id: _numericValue(id)!,
      },
      onSaveNumeric: (readings) {
        readings.forEach((id, value) {
          _persistNumericMetric(
            id == 'bbt' ? NumericMetric.bbt : NumericMetric.weight,
            value,
          );
        });
      },
      // The steppers enter today's reading; this opens its history.
      onOpenTrend: (id) => _openNumericMetric(
        id == 'bbt' ? NumericMetric.bbt : NumericMetric.weight,
      ),
      // Decides which groups she is offered at all.
      stage: _resolveStageKey(BlushyOSProvider.of(context).personalContext),
      onLoadDay: _loadLoggedDay,
    );
    if (mounted) setState(() {});
  }

  /// Stores everything she picked on the symptoms sheet.
  ///
  /// The whole selection is one list, but the options in it do not share a
  /// metric: a flow level is `flow_logged`, a mucus observation is
  /// `cervical_mucus_logged`, an ovulation result is `lh_test_logged`, and a
  /// blood clot is a symptom even though it sits under the flow heading. Each
  /// option is routed by [SymptomCategory.metricFor] rather than all of them
  /// being posted as symptoms, which would have put a fertility reading and a
  /// flow level into the timeline as words.
  ///
  /// Separate from [_persistCheckinAnswer] because the selection is a list:
  /// these co-occur, and the single-value path would let each one erase the
  /// last. Symptoms used to ride the mood selector for exactly that reason,
  /// which meant "happy but cramping" could not be recorded.
  void _persistCheckinSymptoms(Set<String> incoming) {
    // A category switched off is not collected. Filtered here as well as in
    // the sheet because this is the last point before the request.
    final selected = SymptomCategoryPreference.filter(incoming);

    final checkin = Map<String, dynamic>.from(
      BlushyStorage.read('daily_checkin.json'),
    );

    // Each selection is `categoryId/label`, so the group is read from the
    // key rather than guessed from the word. Guessing was the bug: "Medium"
    // belongs to energy and to flow, and the guess always said energy, so a
    // flow of Medium was stored as an energy of Medium and the flow row
    // stayed "Not Logged Today".
    //
    // Stored under each option's own metric as well as in the flat list.
    // Today's Cycle reads `checkin['pain']`, `checkin['flow']` and the rest,
    // and so do the three restore paths.
    final byMetric = <String, List<String>>{};
    final categoryOf = <String, SymptomCategory>{};
    for (final key in selected) {
      final category = SymptomKey.category(key);
      final label = SymptomKey.label(key);
      final metric = category?.metricFor(label) ??
          (CheckinVocabulary.isUnrecorded('symptom', label) ? 'symptom' : null);
      if (metric == null) continue;
      byMetric.putIfAbsent(metric, () => <String>[]).add(label);
      if (category != null) categoryOf.putIfAbsent(metric, () => category);
    }
    byMetric.forEach((metric, labels) {
      final multi = categoryOf[metric]?.multiSelect ?? true;
      // One answer a day stores the answer; a multi-select stores the set.
      checkin[metric] = multi ? labels : labels.first;
      if (metric == 'mood') checkin['feeling'] = labels.first;
    });
    checkin['symptom'] = byMetric['symptom'] ?? const <String>[];

    // A one-answer pick she took off the sheet is cleared, not kept. Only
    // groups she was actually offered can be cleared this way: a group her
    // switches hide is not on the sheet, so its absence says nothing.
    final cleared = <String>{};
    // The stored event type for each cleared metric, so its event can go
    // with it. Read off the mapper with one of the group's own options
    // rather than kept as a second table of types.
    final clearedTypes = <String, String>{};
    for (final category in SymptomCategoryPreference.enabledFor(
      _resolveStageKey(_currentPc),
    )) {
      if (category.multiSelect || category.isNumeric) continue;
      final metric = category.metric;
      if (byMetric.containsKey(metric) || !checkin.containsKey(metric)) continue;
      checkin.remove(metric);
      if (metric == 'mood') checkin.remove('feeling');
      cleared.add(metric);
      final type = category.options.isEmpty
          ? null
          : CheckinEventMapper.map(metric, category.options.first)?.eventType;
      if (type != null) clearedTypes[metric] = type;
    }
    if (clearedTypes.isNotEmpty) {
      unawaited(_deleteLoggedEvents(clearedTypes.values.toSet()));
    }

    checkin['date'] = DateTime.now().toIso8601String();
    BlushyStorage.write('daily_checkin.json', checkin);

    // The rows read the in-memory field before storage (`_livingPain ??
    // savedPain`), and the inline check-in sets both. This path set only
    // storage, so a field restored at startup from an earlier check-in kept
    // masking whatever was just saved here: the row said "Mild" for the rest
    // of the session while storage and the server both said "Severe".
    if (mounted) {
      setState(() {
        String? single(String metric) {
          final v = checkin[metric];
          return v is String ? v : null;
        }

        bool touched(String metric) =>
            byMetric.containsKey(metric) || cleared.contains(metric);

        if (touched('mood')) _selectedFeeling = single('mood');
        if (touched('energy')) _selectedEnergy = single('energy');
        if (touched('sleep')) _livingSleep = single('sleep');
        if (touched('stress')) _livingStress = single('stress');
        if (touched('water')) _livingWater = single('water');
        if (touched('exercise')) _livingExercise = single('exercise');
        if (touched('flow')) _livingFlow = single('flow');
        if (touched('pain')) _livingPain = single('pain');
      });
    }

    for (final key in selected) {
      final category = SymptomKey.category(key);
      final label = SymptomKey.label(key);
      final metric = category?.metricFor(label);
      // "Everything is fine" is stored above but deliberately not sent; see
      // CheckinVocabulary.unrecorded.
      if (metric == null || CheckinVocabulary.isUnrecorded(metric, label)) {
        continue;
      }
      // The variant keeps one idempotency key per option per day. Without it
      // every option on the sheet would collide on its metric's key and the
      // server would keep whichever arrived first.
      _recordCheckinEvent(metric, label, variant: label);
    }

    _userEditedMetrics.add('daily_symptom');
    for (final metric in byMetric.keys) {
      _userEditedMetrics.add('daily_$metric');
    }
    for (final metric in cleared) {
      _userEditedMetrics.add('daily_$metric');
    }

    ApiAuthService()
        .saveOnboardingAnswers({
          // Sent with every save so the server's copy cannot fall behind the
          // switches, whichever device she changed them on.
          ...SymptomCategoryPreference.exclusionsForSync(),
          'daily_symptom': byMetric['symptom'] ?? const <String>[],
          for (final entry in byMetric.entries)
            'daily_${entry.key}': entry.value.length == 1
                ? entry.value.first
                : entry.value,
          // A cleared pick is sent as empty. The server merges answers by
          // key, so a key not sent keeps its old value there -- and on the
          // next start the device, having no value, would take the server's
          // and the cleared pick would come back. Empty is what the client
          // reads as "nothing to apply".
          for (final metric in cleared) 'daily_$metric': '',
          // Dated, as the inline check-in dates its saves, so the server's
          // copy can be compared with the device's rather than assumed
          // newer.
          'daily_logged_at': checkin['date'],
          // The whole day, cleared keys absent, so the server's copy of the
          // day matches the device's.
          'daily_checkin': checkin,
        })
        .catchError((_) => <String, dynamic>{});
  }

  /// Posts one check-in event. Failures are non-fatal: the local write has
  /// already happened, and the offline queue can replay from there.
  ///
  /// The bucket-to-event mapping lives in [CheckinEventMapper] so it can be
  /// tested without building this widget.
  Future<void> _recordCheckinEvent(
    String metric,
    String rawValue, {
    String? variant,
  }) async {
    final mapped = CheckinEventMapper.map(metric, rawValue);
    if (mapped == null) return;

    final clientEventId = CheckinEventMapper.idempotencyKey(
      userId: AuthStorage.getUserId() ?? 'anon',
      metric: metric,
      day: DateTime.now(),
      variant: variant,
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

    // This one got through, so the connection is back. The queue was only
    // drained on resume and on a dashboard rebuild, so a backlog built up
    // offline could sit unsent for as long as she stayed in the app.
    unawaited(OfflineEventQueue.instance.flush());

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
    // Covers the case neither app-start nor resume does: the app left open and
    // untouched across midnight, then used without ever being backgrounded.
    await DailyRollover.runIfNeeded();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final result = await EventsApi.list(
      eventTypes: const [
        'mood_logged',
        'symptom_logged',
        'energy_logged',
        'sleep_logged',
        'stress_logged',
        'hydration_logged',
        'pain_logged',
        'flow_logged',
        'activity_logged',
      ],
      from: startOfDay,
      limit: 100,
    );

    if (!mounted || !result.isReady || result.data == null) return;

    // Oldest first, so a later entry for the same metric wins.
    final events = result.data!.reversed;
    final selections = <String, String>{};
    // Symptoms are the one multi-select metric: a day has as many
    // `symptom_logged` events as she tapped chips, and last-wins would keep
    // exactly one of them.
    final symptoms = <String>{};
    for (final event in events) {
      final mapped = CheckinEventMapper.reverse(event.eventType, event.payload);
      if (mapped == null) continue;
      if (mapped.key == 'symptom') {
        symptoms.add(mapped.value);
      } else {
        selections[mapped.key] = mapped.value;
      }
    }

    if (selections.isEmpty && symptoms.isEmpty) return;

    // A metric she has changed in this session is left alone, here as in the
    // other two places that restore these fields. This request can have been
    // in flight before her tap reached the server, in which case it carries the
    // previous value and would put it back on top of her choice.
    selections.removeWhere(
      (metric, _) => _userEditedMetrics.contains('daily_$metric'),
    );
    final keepSymptoms =
        symptoms.isNotEmpty && !_userEditedMetrics.contains('daily_symptom');
    if (selections.isEmpty && !keepSymptoms) return;

    final checkin = Map<String, dynamic>.from(
      BlushyStorage.read('daily_checkin.json'),
    );
    selections.forEach((metric, label) {
      checkin[metric] = label;
      if (metric == 'mood') checkin['feeling'] = label;
    });
    if (keepSymptoms) checkin['symptom'] = symptoms.toList();
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
      if (selections['exercise'] != null) {
        _livingExercise = selections['exercise'];
      }
    });
  }

  /// Renders the reviewed red flag instruction and the location-aware
  /// resources that came with it. The wording is the clinically reviewed text
  /// from the rule, not anything generated here.
  Widget _buildCheckinSafetyBanner(SafetyFlow safety) {
    final step = safety.steps.isNotEmpty ? safety.steps.first : null;
    if (step == null) return const SizedBox.shrink();

    final bool urgent = safety.isEmergency;
    final Color accent = urgent
        ? const Color(0xFFB3261E)
        : const Color(0xFFB26A00);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                urgent ? Icons.emergency_outlined : Icons.warning_amber_rounded,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.title,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            step.instruction,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.45,
              color: BlushyColors.text,
            ),
          ),
          if (safety.emergencyNumber != null) ...[
            const SizedBox(height: 10),
            Text(
              'Emergency number: ${safety.emergencyNumber}',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
          if (step.source != null) ...[
            const SizedBox(height: 8),
            Text(
              'Source: ${step.source}',
              style: GoogleFonts.manrope(
                fontSize: 10,
                color: BlushyColors.secondaryText,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _checkinSafety = null),
              child: Text(
                'Dismiss',
                style: GoogleFonts.manrope(fontSize: 12, color: accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Patterns and the Docsy Note.
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
    await ReflectionsApi.current();
    if (!mounted) return;
    // The response is not rendered anywhere yet: this has always assigned it
    // to a local and dropped it. Kept as a fetch rather than deleted because
    // the endpoint marks the reflection as seen.
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
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (sameDay) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
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
      const SnackBar(
        content: Text('Noted. Docsy will keep showing observations like this.'),
      ),
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
    return parts.isEmpty
        ? 'Based on your recent logs'
        : 'Based on ${parts.join(', ')}';
  }

  ApiResult<CycleState> _cycleResult = const ApiResult.loading();


  /// Last successful server response, so an offline refresh can keep showing
  /// the last known real values instead of falling back to local arithmetic.
  CycleState? _lastKnownCycle;

  /// Where the last fetched cycle is kept between runs.
  static const String _cycleCacheFile = 'last_known_cycle.json';

  /// Reads the cycle this device last saw, so the first frame of a cold start
  /// has something true to show.
  ///
  /// Held only in memory before, which meant it was null on every launch:
  /// the card opened on "Loading…" (and, before that was fixed, on "Cycle Day:
  /// Not Logged") while the request went out, even for someone who has logged
  /// periods for months. Storage is namespaced per user, so this cannot show
  /// one person's cycle to another.
  void _restoreLastKnownCycle() {
    try {
      final raw = BlushyStorage.read(_cycleCacheFile);
      if (raw.isEmpty) return;
      _lastKnownCycle = CycleState.fromJson(raw);
    } catch (_) {
      // A cache that cannot be read is not worth failing a launch over; the
      // fetch already under way will replace it.
    }
  }

  Future<void> _loadCycleFromServer() async {
    final result = await CycleApi.current(
      timezone: DateTime.now().timeZoneName,
    );
    if (!mounted) return;
    setState(() {
      _cycleResult = result;
      // Any answer that carries a cycle is worth remembering, not only a
      // `ready` one. The contract also returns `insufficientData` and `stale`
      // with a real cycle attached, and someone who has logged a period or two
      // gets exactly that -- so this remembered nothing for the people whose
      // history is thinnest, which is precisely who benefits from not being
      // shown a placeholder on every launch.
      if (result.data != null) {
        _lastKnownCycle = result.data;
        // Written after the state is set, not instead of it: the cache is a
        // head start for the next launch, never the source this run reads.
        try {
          BlushyStorage.write(_cycleCacheFile, result.data!.toJson());
        } catch (_) {}
      }
    });
  }

  static String _formatDayMonth(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'Not available';
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return 'Not available';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}';
  }

  /// Projects the server cycle state into the map shape the dashboard cards
  /// already consume, so every existing card keeps working unchanged.
  ///
  /// The `state` key is new: cards that want to distinguish loading from empty
  /// from "not enough data yet" can read it, and the ones that only read
  /// `isLogged` behave exactly as before.
  Map<String, dynamic> _getDynamicCycleDates([PersonalContext? pc]) {
    Map<String, dynamic> unavailable(
      String state,
      String dayText,
      String subtitle,
    ) => {
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
        cycle.restrictedMessage ??
            'Your current stage does not use cycle tracking.',
      );
    }

    switch (_cycleResult.state) {
      case ApiState.loading:
        // A refresh must not blank a card that already has an answer.
        //
        // `_lastKnownCycle` is kept for exactly this, and the line above hands
        // it over when the request has no data yet -- but this returned before
        // reaching it. So every reload rendered "Cycle Day: Not Logged" for as
        // long as the request took and then flipped back to the real day. On a
        // cold backend that is seconds of the app saying nothing was logged
        // while the period sat in the database the whole time.
        if (cycle == null) {
          return unavailable('loading', 'Loading…', 'Fetching your cycle.');
        }
        break;

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
    final String expectedPeriod = predictionsAvailable
        ? _formatDayMonth(cycle.nextPeriodStartDate)
        : notEnough;
    final String fertileWindow =
        (cycle.fertileWindowStart != null && cycle.fertileWindowEnd != null)
        ? '${_formatDayMonth(cycle.fertileWindowStart)} - ${_formatDayMonth(cycle.fertileWindowEnd)}'
        : notEnough;

    final nextPeriod = cycle.nextPeriodStartDate == null
        ? null
        : DateTime.tryParse(cycle.nextPeriodStartDate!);
    final String recTestDay = nextPeriod == null
        ? notEnough
        : _formatDayMonth(
            nextPeriod.add(const Duration(days: 3)).toIso8601String(),
          );

    // A late period is surfaced as late, not folded into a new cycle.
    final String subtitle;
    if (cycle.isOverdue) {
      subtitle =
          cycle.lateNotice ??
          'Your period is ${cycle.daysOverdue ?? 0} day(s) later than your logged pattern suggests.';
    } else if (hasOvulation) {
      subtitle = 'Expected Ovulation: $ovulationText';
    } else {
      subtitle =
          cycle.sufficiencyMessage ??
          'Keep logging to build your cycle picture.';
    }

    return {
      'state': _cycleResult.state == ApiState.insufficientData
          ? 'insufficient_data'
          : 'ready',
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
    if (val is Iterable) {
      return val.map((e) => e.toString().toLowerCase()).toList();
    }
    if (val is String) {
      if (val.trim().isEmpty) return [];
      final cleaned = val
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .replaceAll("'", '');
      return cleaned
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();
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
      // Every other answer she gave, not just the two lists.
      //
      // The branch questions were asked, stored and never read here. TTC asks
      // which method she tracks with -- ovulation strips, basal body
      // temperature, cervical mucus -- and postpartum asks how she feeds, and
      // both went into `answers` under their own keys while the gating looked
      // only at `symptoms` and `goals`. So the cards keyed to bbt, opk and
      // bottle feeding could never switch on, however she answered.
      //
      // Taken generically rather than key by key so a new question counts as
      // soon as it is added, instead of waiting for someone to remember this
      // list exists -- minus the entries that are not answers to a question.
      // The same map carries her name, her weight and today's check-in
      // sliders, and none of those should decide which cards exist.
      if (answersObj is Map)
        ...answersObj.entries
            .where((e) => e.key != 'symptoms' && e.key != 'goals')
            .where((e) => !isNonQuestionAnswerKey(e.key.toString()))
            .expand((e) => _extractStrings(e.value)),
    ];

    if (userChoices.isEmpty) {
      // Default to showing core essentials if no granular symptoms specified
      return kw.any(
        (k) => [
          'mood',
          'energy',
          'hot flashes',
          'cramps',
          'bloating',
          'pain',
          'movement',
          'sleep',
        ].contains(k.toLowerCase()),
      );
    }

    return metricMatches(userChoices, kw);
  }

  final Map<String, bool> _periodKitChecklist = {
    "Pads": false,
    "Extra underwear": false,
    "Small pouch": false,
    "Wet wipes": false,
    "Water bottle": false,
    "Trusted teacher": false,
  };
  // Never persisted anywhere, so a seeded value claimed she had shared a
  // lesson with someone who never received it.
  final Set<String> _sharedLessons = {};

  @override
  void initState() {
    super.initState();
    // Before the first build, so the opening frame can show the last known
    // cycle rather than a placeholder that is replaced a second later.
    _restoreLastKnownCycle();
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

  void _loadOnboardingData() {
    try {
      final decoded = BlushyStorage.read('user_profile.json');
      final weightData = BlushyStorage.read('logged_weight.json');
      final savedWeight = weightData['weight'];

      // Restored from the device, and it must lose to a selection she has
      // just made.
      //
      // This runs on every tab change -- the shell syncs, the sync fires
      // `refreshNotifier`, and `_onSiaRefresh` calls this method -- so without
      // the guard the stored value replaced the tap of a second earlier. It is
      // the one that bites locally: with no backend answering, the remote
      // hydration never runs and this is the only thing writing to these
      // fields.
      final checkinData = BlushyStorage.read('daily_checkin.json');
      void restore(String key, void Function(String) assign) {
        if (_userEditedMetrics.contains('daily_$key')) return;
        final v = checkinData[key];
        final str = v?.toString().trim() ?? '';
        if (str.isEmpty) return;
        assign(str);
      }

      restore('feeling', (v) => _selectedFeeling = v);
      restore('mood', (v) => _selectedFeeling = v);
      // Each answer is restored into both the living and the wellness field.
      // They are two sets of variables over one stored answer, and only the
      // living half was ever read back -- so the same check-in survived a
      // reload on one dashboard and vanished on the other. The option lists
      // differ between stages (living sleep offers "6-8h", wellness "7-8h"),
      // so after a stage change a restored value may not match any option and
      // simply shows as unselected; it is still her answer, and still shown.
      restore('energy', (v) {
        _selectedEnergy = v;
        _checkInEnergy = v;
      });
      restore('sleep', (v) {
        _livingSleep = v;
        _wellnessSleep = v;
      });
      restore('stress', (v) {
        _livingStress = v;
        _wellnessStress = v;
      });
      restore('water', (v) {
        _livingWater = v;
        _wellnessWater = v;
      });
      restore('flow', (v) => _livingFlow = v);
      restore('pain', (v) => _livingPain = v);
      restore('exercise', (v) {
        _livingExercise = v;
        _wellnessExercise = v;
      });

      if (checkinData['ttc_bbt'] != null) {
        _ttcLoggedBBT = double.tryParse(checkinData['ttc_bbt'].toString());
      }
      if (checkinData['ttc_opk'] != null) {
        _ttcLoggedOPK = checkinData['ttc_opk'].toString();
      }
      if (checkinData['ttc_cervical_fluid'] != null) {
        _ttcLoggedCervicalFluid = checkinData['ttc_cervical_fluid'].toString();
      }
      if (checkinData['ttc_intercourse'] != null) {
        _ttcLoggedIntercourse = checkinData['ttc_intercourse'] == true || checkinData['ttc_intercourse'] == 'true';
      }

      final savedPartnerTasks = BlushyStorage.read('ttc_partner_tasks.json');
      if (savedPartnerTasks is Map && savedPartnerTasks['tasks'] is List) {
        final list = savedPartnerTasks['tasks'] as List;
        for (int i = 0; i < _ttcPartnerTaskList.length && i < list.length; i++) {
          if (list[i] is Map && list[i]['completed'] != null) {
            _ttcPartnerTaskList[i]['completed'] = list[i]['completed'] == true;
          }
        }
      }

      setState(() {
        final p = decoded['profile'];
        _onboardingData = p is Map
            ? Map<String, dynamic>.from(p)
            : Map<String, dynamic>.from(decoded);
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
    ApiAuthService()
        .getOnboardingAnswers()
        .then((remoteAnswers) {
          if (remoteAnswers.isNotEmpty && mounted) {
            setState(() {
              final currentAnswers = _onboardingData['answers'];
              _onboardingData['answers'] = {
                if (currentAnswers is Map) ...currentAnswers,
                ...remoteAnswers,
              };
              if (remoteAnswers.containsKey('preferred_name')) {
                _onboardingData['preferredName'] =
                    remoteAnswers['preferred_name'];
              }
              if (remoteAnswers.containsKey('life_stage')) {
                final active = BlushyOSProvider.of(
                  context,
                ).personalContext.activeLifeStages;
                if (active.isEmpty) {
                  _onboardingData['lifeStage'] = remoteAnswers['life_stage'];
                }
              }
              final remoteW =
                  remoteAnswers['weight_current'] ?? remoteAnswers['weight'];
              if (remoteW != null && remoteW.toString().isNotEmpty) {
                final parsedW = double.tryParse(remoteW.toString());
                if (parsedW != null && parsedW > 0) {
                  _loggedWeight = parsedW;
                }
              }

              // Hydrate live interactive state from MongoDB.
              //
              // Guarded: this runs on every tab change, and without the guard a
              // stored value -- possibly from a previous day, since these carry no
              // date -- overwrote the selection she had just made.
              // The `daily_*` answers are a partial, stale mirror.
              //
              // Only some selectors write them, nothing ever clears them, and they
              // carry no per-metric date -- so they sit at whatever was last
              // written to each key, which can be days old. Applied unconditionally
              // they overwrote the fresher state the device held: measured on a
              // real device, mood went Happy -> Cramps, energy High -> Medium,
              // sleep 6-8h -> <6h and water 3L -> 1L on every tab change, because
              // a tab change triggers the sync that runs this.
              //
              // The device copy and today's events agreed with each other and with
              // what she had actually picked; only this mirror disagreed. So it is
              // now a *fallback*: it fills in a metric the device has nothing for
              // -- a fresh install, or another device -- and otherwise defers.
              final device = BlushyStorage.read('daily_checkin.json');
              final deviceAt = DateTime.tryParse(
                device['date']?.toString() ?? '',
              );
              final remoteAt = DateTime.tryParse(
                remoteAnswers['daily_logged_at']?.toString() ?? '',
              );

              void hydrate(String key, void Function(String) assign) {
                final metric = key.replaceFirst('daily_', '');

                final str = remoteAnswers[key]?.toString().trim() ?? '';
                if (!shouldApplyRemoteCheckin(
                  remoteValue: str,
                  deviceValue: device[metric]?.toString(),
                  deviceAt: deviceAt,
                  remoteAt: remoteAt,
                  editedThisSession: _userEditedMetrics.contains(key),
                )) {
                  return;
                }
                assign(str);
              }

              final analysis = remoteAnswers['analysis_summary']
                  ?.toString()
                  .trim();
              if (analysis != null && analysis.isNotEmpty) {
                _onboardingAnalysisSummary = analysis;
              }

              // Both halves again; see the note on the local restore above.
              hydrate('daily_mood', (v) => _selectedFeeling = v);
              hydrate('daily_energy', (v) {
                _selectedEnergy = v;
                _checkInEnergy = v;
              });
              hydrate('daily_sleep', (v) {
                _livingSleep = v;
                _wellnessSleep = v;
              });
              hydrate('daily_water', (v) {
                _livingWater = v;
                _wellnessWater = v;
              });
              hydrate('daily_stress', (v) {
                _livingStress = v;
                _wellnessStress = v;
              });
              hydrate('daily_flow', (v) => _livingFlow = v);
              hydrate('daily_pain', (v) => _livingPain = v);
              hydrate('daily_exercise', (v) {
                _livingExercise = v;
                _wellnessExercise = v;
              });

              if (remoteAnswers['puberty_feeling'] != null) {
                final pf = remoteAnswers['puberty_feeling'];
                if (pf is Map && pf['feeling'] != null) {
                  _selectedFeeling = pf['feeling'].toString();
                } else if (pf is String) {
                  _selectedFeeling = pf;
                }
              }

              if (remoteAnswers['completed_lessons'] != null) {
                _completedLessons.addAll(
                  _extractStrings(remoteAnswers['completed_lessons']),
                );
              }

              if (remoteAnswers['first_period_kit'] is Map) {
                final kitMap = remoteAnswers['first_period_kit'] as Map;
                kitMap.forEach((k, v) {
                  _periodKitChecklist[k.toString()] = v == true;
                });
              }

              if (remoteAnswers['daily_checkin'] is Map) {
                final c = remoteAnswers['daily_checkin'] as Map;
                if (c['feeling'] != null) {
                  _selectedFeeling = c['feeling'].toString();
                }
                if (c['mood'] != null) _selectedFeeling = c['mood'].toString();
                // Both halves again; see the note on the local restore above.
                if (c['energy'] != null) {
                  _selectedEnergy = c['energy'].toString();
                  _checkInEnergy = c['energy'].toString();
                }
                if (c['flow'] != null) _livingFlow = c['flow'].toString();
                if (c['pain'] != null) _livingPain = c['pain'].toString();
                if (c['sleep'] != null) {
                  _livingSleep = c['sleep'].toString();
                  _wellnessSleep = c['sleep'].toString();
                }
                if (c['stress'] != null) {
                  _livingStress = c['stress'].toString();
                  _wellnessStress = c['stress'].toString();
                }
                if (c['water'] != null) {
                  _livingWater = c['water'].toString();
                  _wellnessWater = c['water'].toString();
                }
                if (c['exercise'] != null) {
                  _livingExercise = c['exercise'].toString();
                  _wellnessExercise = c['exercise'].toString();
                }
              }

              // Restored through the same function that writes them, so the two
              // sides cannot drift apart again. The previous block read
              // `remoteAnswers['peri_log']['hot_flashes']` while the writer stored
              // `{metric: ..., value: ...}` under `peri_log`, and the endpoint had
              // already turned that into a String, so none of these ever loaded.
              String? logged(String category, String label) {
                final key = trackerLogKey(category, label);
                if (_userEditedMetrics.contains(key)) return null;
                final v = remoteAnswers[key];
                final s = v?.toString().trim() ?? '';
                return s.isEmpty ? null : s;
              }

              _hormonalBloating =
                  logged('hormone', 'BLOATING') ?? _hormonalBloating;
              _hormonalAcne = logged('hormone', 'ACNE STATUS') ?? _hormonalAcne;
              _hormonalHeadache =
                  logged('hormone', 'HEADACHE') ?? _hormonalHeadache;
              _hormonalMedication =
                  logged('hormone', 'MEDICATION TAKEN') ?? _hormonalMedication;
              _hormonalHairThinning =
                  logged('hormone', 'HAIR THINNING') ?? _hormonalHairThinning;
              _hormonalFacialHair =
                  logged('hormone', 'FACIAL & BODY HAIR') ??
                  _hormonalFacialHair;
              _hormonalWeightChange =
                  logged('hormone', 'WEIGHT CHANGE') ?? _hormonalWeightChange;

              _ttcCervicalMucus =
                  logged('ttc', 'CERVICAL MUCUS') ?? _ttcCervicalMucus;
              _ttcLhTest = logged('ttc', 'OVULATION TEST (LH)') ?? _ttcLhTest;

              final ttcBbt = device['ttc_bbt'] ?? remoteAnswers['ttc_bbt'];
              if (ttcBbt != null) {
                _ttcLoggedBBT = double.tryParse(ttcBbt.toString());
              }
              final ttcOpk = device['ttc_opk'] ?? remoteAnswers['ttc_opk'];
              if (ttcOpk != null) {
                _ttcLoggedOPK = ttcOpk.toString();
              }
              final ttcCervical = device['ttc_cervical_fluid'] ?? remoteAnswers['ttc_cervical_fluid'];
              if (ttcCervical != null) {
                _ttcLoggedCervicalFluid = ttcCervical.toString();
              }
              final ttcIntercourse = device['ttc_intercourse'] ?? remoteAnswers['ttc_intercourse'];
              if (ttcIntercourse != null) {
                _ttcLoggedIntercourse = ttcIntercourse == true || ttcIntercourse == 'true';
              }

              _pregnancyBabyMovement =
                  logged('pregnancy', 'BABY MOVEMENT') ??
                  _pregnancyBabyMovement;

              _postpartumFeeding =
                  logged('postpartum', 'FEEDING METHOD') ?? _postpartumFeeding;
              _postpartumBleeding =
                  logged('postpartum', 'BLEEDING STATUS') ??
                  _postpartumBleeding;

              _periHotFlashes =
                  logged('peri', 'HOT FLASHES') ?? _periHotFlashes;
              _periNightSweats =
                  logged('peri', 'NIGHT SWEATS') ?? _periNightSweats;
              _periWeightChange =
                  logged('peri', 'WEIGHT & METABOLISM') ?? _periWeightChange;
              _periVaginalDryness =
                  logged('peri', 'VAGINAL DRYNESS') ?? _periVaginalDryness;

              _menoHotFlashes =
                  logged('menopause', 'HOT FLASHES') ?? _menoHotFlashes;
              _menoNightSweats =
                  logged('menopause', 'NIGHT SWEATS') ?? _menoNightSweats;
              _menoVaginalDryness =
                  logged('menopause', 'VAGINAL DRYNESS') ?? _menoVaginalDryness;
              _menoBoneJoint =
                  logged('menopause', 'BONE & JOINT COMFORT') ?? _menoBoneJoint;
              _menoHeartHealth =
                  logged('menopause', 'HEART & CIRCULATION') ??
                  _menoHeartHealth;
            });

            // Hydrate personal context with fetched user profile values in post frame callback
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final provider = BlushyOSProvider.of(context);
              final cur = provider.personalContext;
              final name =
                  remoteAnswers['preferred_name']?.toString() ?? cur.userName;
              final cLen =
                  int.tryParse(
                    remoteAnswers['cycle_length']?.toString() ?? '',
                  ) ??
                  cur.cycleLength;

              // `period_last_start_date` is the onboarding seed, and it fills in
              // rather than overrules.
              //
              // This ran on every refresh -- so on every tab change -- and replaced
              // whatever was current with the signup answer. Logging a period on
              // 26 Aug therefore held only until the next refresh, which put 31 Aug
              // back and then pushed it to the server through
              // `updatePersonalContext`, writing the stale date in as though she
              // had chosen it. Traced on a device as the date alternating
              // 26 -> 31 -> 26 -> 31 with each sync.
              //
              // Nothing updates this key after signup: logging a period writes
              // `last_period` / `cycle_start_date` / `last_period_date`, never
              // this one. So it is only ever a seed.
              DateTime? pStart = cur.lastPeriodStart;
              if (pStart == null &&
                  remoteAnswers.containsKey('period_last_start_date')) {
                pStart = DateTime.tryParse(
                  remoteAnswers['period_last_start_date'].toString(),
                );
              }

              provider.updatePersonalContext(
                PersonalContext(
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
                ),
              );
            });
          }
        })
        .catchError((_) {});
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

    final List<String> effectiveActiveStages =
        widget.activeStages ?? pc.activeLifeStages.toList();
    if (widget.stageKey == null && effectiveActiveStages.length > 1) {
      return _buildUnifiedMultiStageHomeOS(effectiveActiveStages, pc, state);
    }

    final String currentStage = _resolveStageKey(pc);

    final String normalized = currentStage
        .replaceAll('_', '')
        .replaceAll(' ', '')
        .toLowerCase();

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
      if (norm != 'firstperiodnotstarted' &&
          norm != 'notstarted' &&
          norm != 'puberty' &&
          norm != 'menopause') {
        return true;
      }
    }
    return false;
  }

  Widget _buildUnifiedMultiSiaInsights(List<String> stages) {
    const whenEmptyDocsy = 'Docsy has not noticed anything in your logs yet.';
    const whenInsufficientDocsy =
        'Once you have logged a few days, Docsy will start sharing what it notices.';
    const whenEmptyPatterns = 'Nothing stands out in your logs yet.';
    const whenInsufficientPatterns =
        'Keep logging for a couple of weeks and Blushy will start showing what it notices.';

    if (_patternsAreEmpty) {
      return AutoCarouselCards(
        cards: [
          DocsyInsightsCard(
            heading: AppLocalizations.of(context).dashSiaInsights,
            note: _patternsEmptyNote(whenEmptyDocsy, whenInsufficientDocsy),
            actionLabel: AppLocalizations.of(context).dashLogTodayCheckIn,
            onAction: _scrollToCheckIn,
          ),
          PatternsEmptyCard(
            heading: AppLocalizations.of(context).dashPatternsTitle,
            note: _patternsEmptyNote(whenEmptyPatterns, whenInsufficientPatterns),
            actionLabel: AppLocalizations.of(context).dashLogTodayCheckIn,
            onAction: _scrollToCheckIn,
            onRefresh: () => _loadPatterns(refresh: true),
          ),
        ],
        height: 130.0,
      );
    }
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
            style: GoogleFonts.manrope(
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
              AppLocalizations.of(context).dashFocusTopic,
              style: GoogleFonts.manrope(
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

  Widget _buildStageSpecificUniqueContent(
    String stageKey,
    PersonalContext pc,
    BlushyOSState state,
    bool isMobile, {
    bool skipJourney = false,
    bool skipPatterns = false,
  }) {
    final norm = stageKey.replaceAll('_', '').replaceAll(' ', '').toLowerCase();
    switch (norm) {
      case 'firstperiodstarted':
      case 'started':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFirstPeriodStartedHomeOS(pc, state, isMobile),
          ],
        );
      case 'firstperiodnotstarted':
      case 'notstarted':
      case 'puberty':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNotStartedHomeOS(pc, state),
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
            if (!skipJourney) ...[
              _buildLivingJourney(),
              SizedBox(height: isMobile ? 32 : 48),
            ],
          ],
        );
    }
  }

  Widget _buildUnifiedMultiStageHomeOS(
    List<String> stages,
    PersonalContext pc,
    BlushyOSState state,
  ) {
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
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ListView(
                shrinkWrap: _effectiveShrinkWrap,
                physics: _effectiveScrollPhysics,
                children: [
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

                  // 5. COMBINED INSIGHTS & PATTERNS (Auto-Carousel)
                  _buildUnifiedMultiSiaInsights(stages),
                  SizedBox(height: isMobile ? 32 : 48),

                  // 7. STAGE-SPECIFIC DISTINCT MODULES (Focus headers are placed at the start only)
                  ...stages.map((stageKey) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStageSpecificUniqueContent(
                          stageKey,
                          pc,
                          state,
                          isMobile,
                          skipJourney: true,
                          skipPatterns: true,
                        ),
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

  // --- SECTION 1: DOCSY'S DAILY LETTER (HERO) ---
  Widget _buildSiasDailyLetter(String name) {
    return _buildLivingTodayCycle();
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
              SectionHeading("CONTINUE LEARNING"),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).dashSmallLessonsDesignedStage,
                style: GoogleFonts.manrope(
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
          height: 300,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _lessons.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final lesson = _lessons[index];
              final isCompleted = _completedLessons.contains(lesson);
              final isUnlocked =
                  index == 0 || _completedLessons.contains(_lessons[index - 1]);

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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompleted
                          ? BlushyColors.primary.withValues(alpha: 0.4)
                          : BlushyColors.border,
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
                            isCompleted
                                ? Icons.check_circle
                                : (isUnlocked ? Icons.lock_open : Icons.lock),
                            color: isCompleted
                                ? BlushyColors.primary
                                : Colors.black26,
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
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BlushyColors.text,
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
                                value: isCompleted
                                    ? 1.0
                                    : (isUnlocked ? 0.3 : 0.0),
                                backgroundColor: const Color(0xFFF0F0F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  BlushyColors.primary,
                                ),
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
                              ApiAuthService()
                                  .saveOnboardingAnswers({
                                    'completed_lessons': _completedLessons
                                        .toList(),
                                  })
                                  .catchError((_) => <String, dynamic>{});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.transparent
                                    : BlushyColors.primary,
                                borderRadius: BorderRadius.circular(8),
                                border: isCompleted
                                    ? Border.all(color: BlushyColors.primary)
                                    : null,
                              ),
                              child: Text(
                                isCompleted ? "Review" : "Resume",
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted
                                      ? BlushyColors.primary
                                      : Colors.white,
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
        "ans":
            "During puberty, breasts grow at different rates. It's completely normal for one to grow faster or look slightly larger than the other. Over time, they usually even out, but minor asymmetry is totally natural and common for most girls.",
      },
      {
        "q": "Will periods hurt?",
        "ans":
            "Some girls feel mild cramps in their lower tummy before or during their period. This is because the uterus muscles tighten. It usually feels like a dull ache. Simple remedies like a warm hot water bottle, walking, or asking a trusted adult for help can make it feel much better.",
      },
      {
        "q": "What is white discharge?",
        "ans":
            "White or clear fluid on your underwear is called discharge. It is your body's natural way of cleaning the vagina and keeping it healthy. It usually starts a few months or a year before your first period begins, showing that your body is developing normally.",
      },
      {
        "q": "What if I get my period at school?",
        "ans":
            "It is a very common worry, but teachers and school nurses are prepared for this! Keeping an extra pad in your backpack or pouch will help you feel ready. If you're caught by surprise, you can always ask a school nurse or female teacher for help.",
      },
      {
        "q": "Why am I getting pimples?",
        "ans":
            "Hormones during puberty cause the skin glands to produce more natural oils, which can clog pores. Washing your face daily with a gentle cleanser helps keep your skin fresh. Pimples are a natural part of growing up that almost everyone goes through!",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("CURIOUS TODAY"),
        ),
        const SizedBox(height: 16),
        // Subsection A: Daily Discovery
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.wb_sunny_outlined,
                    color: BlushyColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).dashDailyDiscovery,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).dashSweatGlandsBecomeMore,
                style: GoogleFonts.manrope(
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
                      AppLocalizations.of(context).dashRead,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _savedArticles.contains("Sweat Glands")
                          ? Icons.bookmark
                          : Icons.bookmark_border,
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
                    icon: const Icon(
                      Icons.share_outlined,
                      size: 20,
                      color: BlushyColors.secondaryText,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(
                              context,
                            ).dashLinkCopiedShareFamily,
                          ),
                        ),
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
            AppLocalizations.of(context).dashQuestionsGirlsOftenAsk,
            style: GoogleFonts.manrope(
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BlushyColors.border, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.help_outline,
                        color: BlushyColors.primary,
                        size: 20,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item['q']!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
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
          child: SectionHeading("CONNECT"),
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
                      color: _connectTabIndex == 0
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppLocalizations.of(context).dashGirls,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _connectTabIndex == 0
                            ? BlushyColors.text
                            : BlushyColors.secondaryText,
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
                      color: _connectTabIndex == 1
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppLocalizations.of(context).dashGrowingTogether,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _connectTabIndex == 1
                            ? BlushyColors.text
                            : BlushyColors.secondaryText,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BlushyColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).dashSupportiveCommunityPreview,
            style: GoogleFonts.manrope(
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
              const Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: BlushyColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).dashHowDoITrack,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).dashCanFocusLearningDischarge,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: BlushyColors.secondaryText,
                      ),
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
              const Icon(
                Icons.favorite_border,
                size: 16,
                color: BlushyColors.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).dashReadWhatOthersAre,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).dashRealConversationsFromCommunity,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: BlushyColors.secondaryText,
                      ),
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
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(
                        context,
                      ).dashRedirectingCommunitySpace,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                AppLocalizations.of(context).dashJoinCommunity,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
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
            color: BlushyColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).dashSharedReading,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).dashShareArticlesAboutGrowing,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: BlushyColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(
                                context,
                              ).dashArticleSharedParentAccount,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: BlushyColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context).dashSendParent,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: BlushyColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(
                                context,
                              ).dashOpeningSharedLibrary,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: BlushyColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context).dashSharedLibrary,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: BlushyColors.primary,
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
        const SizedBox(height: 16),

        // Let's Talk AI Card
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).dashLetSTalkWeekly,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.warning,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "\"What is one thing you've been curious about recently?\"",
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.text,
                ),
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
                      backgroundColor: _letsTalkDiscussed
                          ? BlushyColors.success
                          : BlushyColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      _letsTalkDiscussed ? "Discussed " : "Discussed",
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _letsTalkSaved = !_letsTalkSaved;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _letsTalkSaved
                            ? BlushyColors.disabled
                            : BlushyColors.primary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      _letsTalkSaved ? "Saved" : "Save for Weekend",
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: _letsTalkSaved
                            ? BlushyColors.disabled
                            : BlushyColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BlushyColors.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).dashFirstPeriodKitChecklist,
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: BlushyColors.secondaryText,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                ..._periodKitChecklist.keys.map((item) {
                  final isChecked = _periodKitChecklist[item]!;
                  return CheckboxListTile(
                    title: Text(
                      item,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: BlushyColors.text,
                      ),
                    ),
                    value: isChecked,
                    activeColor: BlushyColors.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (val) {
                      setState(() {
                        _periodKitChecklist[item] = val ?? false;
                      });
                      ApiAuthService()
                          .saveOnboardingAnswers({
                            'first_period_kit': _periodKitChecklist,
                          })
                          .catchError((_) => <String, dynamic>{});
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
            color: BlushyColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).dashSharedJourney,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(
                  context,
                ).dashDisplayLearningProgressCompleted,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: BlushyColors.secondaryText,
                ),
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
                        isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isCompleted
                            ? BlushyColors.success
                            : BlushyColors.disabled,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lesson,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: BlushyColors.text,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
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
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isShared
                                  ? BlushyColors.success
                                  : BlushyColors.primary,
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

    final normalizedStage =
        (BlushyOSProvider.of(context).personalContext.lifeStage ?? '')
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BlushyColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading("GROWING JOURNEY"),
          const SizedBox(height: 20),
          ...timelineStages.map((stage) {
            final isActive =
                stage['status'] == "active" || stage['status'] == "done";
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
                        color: isActive
                            ? BlushyColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: isActive
                              ? BlushyColors.primary
                              : BlushyColors.border,
                          width: 2,
                        ),
                      ),
                      child: isActive
                          ? const Center(
                              child: Icon(
                                Icons.circle,
                                size: 6,
                                color: Colors.white,
                              ),
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
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? BlushyColors.text
                              : BlushyColors.secondaryText,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 4),
                        Text(
                          "\"Every little thing you learn today prepares you for tomorrow.\"",
                          style: GoogleFonts.manrope(
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
            color: BlushyColors.background,
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

  // =========================================================================
// RESTORED STAGE 1, STAGE 2 & SHARED FLO-STYLE COMPONENTS
// =========================================================================


  Widget _buildSectionTitleWithFilledIcon({
    required IconData icon,
    required String title,
    String? subtitle,
    Color iconBg = const Color(0xFFDD0D22),
    Color iconColor = Colors.white,
    Color? bgColor,
    double titleSize = 16.5,
    Widget? trailing,
  }) {
    final effectiveBg = bgColor ?? iconBg;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: effectiveBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: BlushyColors.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          color: BlushyColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  void _showArticleDialog(BuildContext context, String title, String summary) {
    showDialog(
      context: context,
      builder: (dialogContext) =>
          ArticleDetailDialog(title: title, summary: summary),
    );
  }


Widget _buildFloStyleSelfCareCategoryRow() {
    final categories = [
      {
        'id': 'Self-care & Period',
        'title': 'Self-care & Period',
        'subtitle': 'Warmth, tea & calm',
        'icon': Icons.favorite_rounded,
        'bgColor': const Color(0xFFFF3366), // Vivid Coral Pink
        'borderColor': const Color(0xFFFF6B8B),
        'iconBg': Colors.white.withValues(alpha: 0.22),
        'accentColor': const Color(0xFFE11D48),
      },
      {
        'id': 'Symptom Checker',
        'title': 'Symptom Checker',
        'subtitle': 'Cramps, flow & mood',
        'icon': Icons.health_and_safety_rounded,
        'bgColor': const Color(0xFF00B4D8), // Vivid Ocean Sky Cyan
        'borderColor': const Color(0xFF48CAE4),
        'iconBg': Colors.white.withValues(alpha: 0.22),
        'accentColor': const Color(0xFF0284C7),
      },
      {
        'id': 'Cycle Insights',
        'title': 'Cycle Insights',
        'subtitle': 'Phases & biomarkers',
        'icon': Icons.spa_rounded,
        'bgColor': const Color(0xFF8B5CF6), // Vivid Royal Purple
        'borderColor': const Color(0xFFA78BFA),
        'iconBg': Colors.white.withValues(alpha: 0.22),
        'accentColor': const Color(0xFF7C3AED),
      },
      {
        'id': 'Parent Prompts',
        'title': 'Parent Prompts',
        'subtitle': 'Safe talk starters',
        'icon': Icons.forum_rounded,
        'bgColor': const Color(0xFFFF8500), // Vivid Electric Tangerine
        'borderColor': const Color(0xFFFFAA47),
        'iconBg': Colors.white.withValues(alpha: 0.22),
        'accentColor': const Color(0xFFEA580C),
      },
    ];

    final provider = BlushyOSProvider.of(context);
    final currentStage = _resolveStageKey(provider.personalContext);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Self-care & Essentials",
              style: GoogleFonts.manrope(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: BlushyColors.text,
                letterSpacing: -0.3,
              ),
            ),
            if (_selectedSelfCareCategory != 'All')
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedSelfCareCategory = 'All';
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    "Show All",
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: categories.map((cat) {
              final id = cat['id'] as String;
              final title = cat['title'] as String;
              final bgColor = cat['bgColor'] as Color;
              final borderColor = cat['borderColor'] as Color;
              final iconBg = cat['iconBg'] as Color;
              final accentColor = cat['accentColor'] as Color;
              final icon = cat['icon'] as IconData;
              final isSelected = _selectedSelfCareCategory == id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedSelfCareCategory = isSelected ? 'All' : id;
                  });
                  _showCategoryEssentialsModal(
                    context,
                    title,
                    icon,
                    accentColor,
                    currentStage,
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 116,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor : bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.white : borderColor,
                      width: isSelected ? 2.2 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isSelected ? accentColor : bgColor).withValues(alpha: 0.35),
                        blurRadius: isSelected ? 12 : 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withValues(alpha: 0.3) : iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }


  Map<String, dynamic> _getCategoryEssentialsData(String categoryTitle, String stageKey) {
    final norm = stageKey.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    final isPreMenarche = norm.contains('notstarted') || norm.contains('puberty');

    if (categoryTitle.contains('Self-care')) {
      return {
        'tips': isPreMenarche
            ? [
                "Pack 2-3 sanitary pads & a fresh pouch in your school backpack.",
                "Drink a warm cup of herbal chamomile tea for tummy comfort.",
                "Practice gentle deep breathing to relax and stay grounded.",
              ]
            : [
                "Use a warm water bottle or heating pad on your lower tummy.",
                "Sip warm ginger or peppermint tea to soothe natural uterine contractions.",
                "Prioritize 8-9 hours of restorative sleep with an elevated pillow.",
              ],
        'guides': isPreMenarche
            ? [
                {'title': 'First Period Care & Backpack Kit', 'readTime': '4 min read', 'content': 'Everything you need in your daily kit: pads, clean underwear, wipes, and a small discreet pouch.'},
                {'title': 'Understanding Body Temperature & Rest', 'readTime': '3 min read', 'content': 'Why staying warm and cozy eases pre-menarche tummy aches.'},
              ]
            : [
                {'title': 'Soothing Period Cramps Naturally', 'readTime': '5 min read', 'content': 'Evidence-backed warmth, magnesium, and hydration remedies for cycle ease.'},
                {'title': 'Restorative Yoga for Menstrual Flow', 'readTime': '6 min read', 'content': 'Child\'s pose, reclining butterfly, and legs-up-the-wall for deep pelvis relief.'},
              ],
      };
    } else if (categoryTitle.contains('Symptom')) {
      return {
        'tips': [
          "Log your daily energy, mood, and flow right inside Blushy.",
          "Notice patterns between what you eat, your stress, and cramping.",
          "Keep an eye on discharge colors and hydration levels.",
        ],
        'guides': [
          {'title': 'Decoding Symptoms & Body Signals', 'readTime': '4 min read', 'content': 'How hormones influence sleep, mood swings, skin glow, and appetite throughout the month.'},
          {'title': 'Normal vs When to Check with a Doctor', 'readTime': '5 min read', 'content': 'Clear guidance on what is expected vs when to seek medical advice.'},
        ],
      };
    } else if (categoryTitle.contains('Cycle')) {
      return {
        'tips': [
          "Your cycle is divided into 4 natural biological phases.",
          "Track energy peaks during the follicular and ovulatory windows.",
          "Embrace the slower, reflective pace of the luteal and menstrual phases.",
        ],
        'guides': [
          {'title': 'The Four Phases of Your Menstrual Cycle', 'readTime': '6 min read', 'content': 'Menstrual (Winter), Follicular (Spring), Ovulation (Summer), and Luteal (Autumn).'},
          {'title': 'Why Irregular Cycles Happen in Youth', 'readTime': '4 min read', 'content': 'It takes 12-24 months for ovulation signals to stabilize in young women.'},
        ],
      };
    } else {
      // Parent Prompts
      return {
        'tips': [
          "Talking to mom, dad, or a guardian helps you feel supported.",
          "School nurses and teachers have spare supplies if you ever need them.",
          "There are no embarrassing questions when it comes to your health.",
        ],
        'guides': [
          {'title': 'Conversation Starters for Parents', 'readTime': '3 min read', 'content': 'Simple, stress-free scripts to ask for period care supplies or talk about symptoms.'},
          {'title': 'Emergency School Period Guide', 'readTime': '4 min read', 'content': 'What to do if your period starts during class, sports, or exams.'},
        ],
      };
    }
  }


void _showCategoryEssentialsModal(
    BuildContext context,
    String categoryTitle,
    IconData categoryIcon,
    Color categoryColor,
    String stageKey,
  ) {
    final essentials = _getCategoryEssentialsData(categoryTitle, stageKey);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(categoryIcon, color: categoryColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoryTitle,
                              style: GoogleFonts.manrope(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: BlushyColors.text,
                              ),
                            ),
                            Text(
                              "Essentials & Curated Guidance",
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: BlushyColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: BlushyColors.text),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // Quick Action Guidance Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: categoryColor.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Text(
                                "DAILY ESSENTIALS & ACTION TIPS",
                                style: GoogleFonts.manrope(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFD97706),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...(essentials['tips'] as List<String>).map((tip) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF3DA672)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tip,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: BlushyColors.text,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "RECOMMENDED GUIDES",
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: BlushyColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...(essentials['guides'] as List<Map<String, String>>).map((guide) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            _showArticleDialog(context, guide['title']!, guide['content']!);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFEAE3DC)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.menu_book_rounded, size: 16, color: categoryColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        guide['title']!,
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: BlushyColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        guide['readTime']!,
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          color: BlushyColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: BlushyColors.secondaryText),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _openAskSiaChat(context, 'Hi Docsy, can you give me personalized advice for $categoryTitle?');
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                        label: Text(
                          "Ask Docsy about $categoryTitle",
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDD0D22),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

List<Map<String, dynamic>> _getStageCuratedArticles(String stageKey, String? categoryFilter) {
    final norm = stageKey.toLowerCase().replaceAll('_', '').replaceAll(' ', '');

    List<Map<String, dynamic>> stagePool;

    if (norm.contains('notstarted') || norm.contains('puberty')) {
      // Stage 1: First Period Not Started
      stagePool = [
        {
          'title': 'Everything to Expect Before Your First Period',
          'readTime': '5 min read',
          'category': 'Self-care & Period',
          'icon': Icons.auto_awesome_rounded,
          'gradient': [const Color(0xFFFFD1D8), const Color(0xFFFFB3C1)],
          'accentColor': const Color(0xFF9F1239),
          'summary': 'Your body gives subtle cues like growth spurts, tender breasts, and white discharge 6-12 months before your first flow.'
        },
        {
          'title': 'Your Emergency School Backpack Kit',
          'readTime': '4 min read',
          'category': 'Self-care & Period',
          'icon': Icons.backpack_rounded,
          'gradient': [const Color(0xFFFFE5D9), const Color(0xFFFFCAD4)],
          'accentColor': const Color(0xFF9A3412),
          'summary': 'What to keep in your discreet pouch: 2-3 pads, clean spare underwear, wipes, and a small water bottle.'
        },
        {
          'title': 'What is Vaginal Discharge & Is It Normal?',
          'readTime': '4 min read',
          'category': 'Symptom Checker',
          'icon': Icons.water_drop_rounded,
          'gradient': [const Color(0xFFC7F9CC), const Color(0xFF80ED99)],
          'accentColor': const Color(0xFF14532D),
          'summary': 'Clear or creamy white discharge is your body\'s natural way of cleaning and protecting itself during puberty.'
        },
        {
          'title': 'Why Bodies Change: Science of Growing Up',
          'readTime': '6 min read',
          'category': 'Cycle Insights',
          'icon': Icons.spa_rounded,
          'gradient': [const Color(0xFFE0C3FC), const Color(0xFF8EC5FC)],
          'accentColor': const Color(0xFF4C1D95),
          'summary': 'Hormones like estrogen trigger height growth, wider hips, and healthy body development in unique individual timing.'
        },
        {
          'title': 'How to Talk to Mom, a Teacher or Nurse',
          'readTime': '3 min read',
          'category': 'Parent Prompts',
          'icon': Icons.forum_rounded,
          'gradient': [const Color(0xFFFED7AA), const Color(0xFFFDBA74)],
          'accentColor': const Color(0xFFC2410C),
          'summary': 'Simple conversation starters so you never feel alone or unprepared if your period starts at school.'
        },
      ];
    } else if (norm.contains('started')) {
      // Stage 2: First Period Started
      stagePool = [
        {
          'title': 'Managing Cramps & Warmth Essentials',
          'readTime': '5 min read',
          'category': 'Self-care & Period',
          'icon': Icons.favorite_rounded,
          'gradient': [const Color(0xFFFFD1D8), const Color(0xFFFFB3C1)],
          'accentColor': const Color(0xFF9F1239),
          'summary': 'Simple, soothing steps to take care of your tummy and mood with warm tea, heat pads, and gentle stretches.'
        },
        {
          'title': 'Understanding First-Year Irregular Cycles',
          'readTime': '6 min read',
          'category': 'Cycle Insights',
          'icon': Icons.auto_awesome_rounded,
          'gradient': [const Color(0xFFE0C3FC), const Color(0xFF8EC5FC)],
          'accentColor': const Color(0xFF4C1D95),
          'summary': 'Why skipped or irregular periods are 100% normal in your first year as your body discovers its own rhythm.'
        },
        {
          'title': 'Choosing Pads, Liners & Period Underwear',
          'readTime': '4 min read',
          'category': 'Self-care & Period',
          'icon': Icons.shield_rounded,
          'gradient': [const Color(0xFFFFE5D9), const Color(0xFFFFCAD4)],
          'accentColor': const Color(0xFF9A3412),
          'summary': 'Finding the most comfortable, leak-proof absorbency for your flow intensity and school day.'
        },
        {
          'title': 'Cycle Syncing for Energy & School Focus',
          'readTime': '5 min read',
          'category': 'Symptom Checker',
          'icon': Icons.bolt_rounded,
          'gradient': [const Color(0xFFFEF08A), const Color(0xFFFDE047)],
          'accentColor': const Color(0xFF854D0E),
          'summary': 'How energy shifts throughout the month and how simple nutrition boosts focus during exams.'
        },
        {
          'title': 'Talking to Your Doctor About Period Pain',
          'readTime': '4 min read',
          'category': 'Parent Prompts',
          'icon': Icons.forum_rounded,
          'gradient': [const Color(0xFFFED7AA), const Color(0xFFFDBA74)],
          'accentColor': const Color(0xFFC2410C),
          'summary': 'What to describe during a routine checkup if cramps are interfering with your school attendance.'
        },
      ];
    } else {
      // Stage 3 & General: Living With My Cycle / Reproductive Years
      stagePool = [
        {
          'title': 'Follicular Highs: Tapping Into Peak Energy',
          'readTime': '5 min read',
          'category': 'Cycle Insights',
          'icon': Icons.spa_rounded,
          'gradient': [const Color(0xFFE0C3FC), const Color(0xFF8EC5FC)],
          'accentColor': const Color(0xFF4C1D95),
          'summary': 'Estrogen rises after your bleed, boosting creative problem-solving, endurance workouts, and verbal eloquence.'
        },
        {
          'title': 'Luteal Phase Mood & Magnesium Rituals',
          'readTime': '6 min read',
          'category': 'Self-care & Period',
          'icon': Icons.favorite_rounded,
          'gradient': [const Color(0xFFFFD1D8), const Color(0xFFFFB3C1)],
          'accentColor': const Color(0xFF9F1239),
          'summary': 'How progesterone shifts body temperature, appetite, and sleep architecture before your period.'
        },
        {
          'title': 'Hormonal Skincare: Syncing Your Daily Routine',
          'readTime': '5 min read',
          'category': 'Symptom Checker',
          'icon': Icons.water_drop_rounded,
          'gradient': [const Color(0xFFC7F9CC), const Color(0xFF80ED99)],
          'accentColor': const Color(0xFF14532D),
          'summary': 'Prevent cycle breakouts by adapting hydration, gentle exfoliation, and barrier support across all 4 phases.'
        },
        {
          'title': 'Anti-Inflammatory Nutrition for Period Ease',
          'readTime': '6 min read',
          'category': 'Self-care & Period',
          'icon': Icons.restaurant_rounded,
          'gradient': [const Color(0xFFFFE5D9), const Color(0xFFFFCAD4)],
          'accentColor': const Color(0xFF9A3412),
          'summary': 'Omega-3s, leafy greens, and dark chocolate to naturally ease prostaglandins and inflammation.'
        },
        {
          'title': 'Cycle-Driven Communication & Boundaries',
          'readTime': '4 min read',
          'category': 'Parent Prompts',
          'icon': Icons.forum_rounded,
          'gradient': [const Color(0xFFFED7AA), const Color(0xFFFDBA74)],
          'accentColor': const Color(0xFFC2410C),
          'summary': 'Communicate your physical and mental needs clearly to family, partners, and colleagues.'
        },
      ];
    }

    if (categoryFilter == null || categoryFilter == 'All') {
      return stagePool;
    }

    final filtered = stagePool.where((a) => a['category'] == categoryFilter).toList();
    return filtered.isNotEmpty ? filtered : stagePool;
  }

void _showAllArticlesModal(BuildContext context, List<Map<String, dynamic>> articles) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Color(0xFFDD0D22), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Curated Wellness Library",
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: BlushyColors.text,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: BlushyColors.text),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: articles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final art = articles[index];
                    final gradient = art['gradient'] as List<Color>;
                    final accentColor = (art['accentColor'] as Color?) ?? const Color(0xFF9F1239);
                    final icon = art['icon'] as IconData;
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        _showArticleDialog(context, art['title'] as String, art['summary'] as String);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEAE3DC)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: gradient),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: accentColor, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    art['title'] as String,
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: BlushyColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        art['category'] as String,
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: accentColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "•  ${art['readTime']}",
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          color: BlushyColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BlushyColors.secondaryText),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

Widget _buildVisualArticlesCarousel() {
    final provider = BlushyOSProvider.of(context);
    final currentStage = _resolveStageKey(provider.personalContext);
    final articles = _getStageCuratedArticles(currentStage, _selectedSelfCareCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  "Curated For Your Stage",
                  style: GoogleFonts.manrope(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: BlushyColors.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.auto_awesome_rounded, size: 15, color: BlushyColors.primary),
              ],
            ),
            InkWell(
              onTap: () => _showAllArticlesModal(
                context,
                _getStageCuratedArticles(currentStage, 'All'),
              ),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  "See all →",
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: BlushyColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: articles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final art = articles[index];
              final gradient = art['gradient'] as List<Color>;
              final accentColor = (art['accentColor'] as Color?) ?? const Color(0xFF9F1239);
              final icon = art['icon'] as IconData;

              return InkWell(
                onTap: () {
                  _showArticleDialog(context, art['title'] as String, art['summary'] as String);
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 175,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEDE4DC), width: 1.1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card Cover
                      Container(
                        height: 90,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 9.5, color: accentColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      art['category'] as String,
                                      style: GoogleFonts.manrope(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(
                                Icons.bookmark_border_rounded,
                                size: 16,
                                color: accentColor.withValues(alpha: 0.75),
                              ),
                            ),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: accentColor, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                art['title'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: BlushyColors.text,
                                  height: 1.25,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    art['readTime'] as String,
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      color: BlushyColors.secondaryText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: BlushyColors.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
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

// --- STAGE 1: FIRST PERIOD NOT STARTED ---
Widget _buildNotStartedHeroHeader(String displayName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlushyColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: BlushyColors.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BlushyColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.spa_outlined, color: BlushyColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                "Welcome, $displayName 🌷",
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Your body is growing.\nAnd you're doing just fine. 🌷",
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: BlushyColors.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Learn what's happening, prepare for your first period, and ask questions whenever you're curious.",
            style: GoogleFonts.manrope(
              fontSize: 13,
              height: 1.5,
              color: BlushyColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildSiasDailyLetterNotStarted(String displayName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BlushyColors.primary.withValues(alpha: 0.08),
            const Color(0xFFFFF7F7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlushyColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: BlushyColors.primary),
              const SizedBox(width: 8),
              Text(
                "SIA'S THOUGHT FOR TODAY",
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: BlushyColors.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "“You don't have to understand everything about growing up at once. Taking it one question at a time is completely okay.”",
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: BlushyColors.text,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildFirstPeriodTransitionBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Got Your First Period?",
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Celebrate & transition your dashboard to First Year Started!",
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTransitionToStartedDialog(context),
              icon: const Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
              label: Text(
                "My Period Started Today →",
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD0D22),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showTransitionToStartedDialog(BuildContext context) {
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFECE5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: Color(0xFFDD0D22),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Welcome to a New Chapter!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Getting your first period is a natural milestone. We'll update your dashboard with the gentle First Year Started experience, cycle ring, and comforting daily guidance.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      height: 1.45,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEDE4DC)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Period Start Date",
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: BlushyColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: BlushyColors.text,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setModalState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFFDD0D22)),
                          label: Text(
                            "Change Date",
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFDD0D22),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFFDDD2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final provider = BlushyOSProvider.of(context);
                        final currentPc = provider.personalContext;
                        provider.updatePersonalContext(
                          currentPc.copyWith(
                            lifeStage: 'firstPeriodStarted',
                            activeLifeStages: {'firstPeriodStarted'},
                            lastPeriodStart: selectedDate,
                          ),
                        );
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Welcome to Stage 2: First Period Started! 🌸",
                              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                            ),
                            backgroundColor: const Color(0xFFDD0D22),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDD0D22),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Start First Year Journey ✨",
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }



  Future<void> _transitionToFirstPeriodStartedDirectly() async {
    try {
      final osState = BlushyOSProvider.of(context);
      
      // 1. Instantly set Stage 2 (First Period Started) as the active stage
      osState.setActiveLifeStages({'firstPeriodStarted'});
      osState.addLifeStageWithAnswers('firstPeriodStarted', {
        'first_period_start_time': 'Today',
        'goals': ['Tracking periods', 'Managing cramps & pain', 'Understanding my body'],
        'last_period': DateTime.now().toIso8601String().split('T').first,
      });

      // 2. Log first period date in API & local storage
      final now = DateTime.now();
      ApiPeriodService().logPeriodEntry(
        periodStartDate: now,
        flowIntensity: 'Light',
      ).catchError((_) => null);

      final checkin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
      checkin['last_period_date'] = now.toIso8601String().split('T').first;
      checkin['is_period_day'] = true;
      checkin['cramps'] = _stage2SelectedCramp;
      checkin['mood'] = _stage2SelectedMood;
      BlushyStorage.write('daily_checkin.json', checkin);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Welcome to Stage 2: First Period Started! 🌸 We're walking beside you.",
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFFDD0D22),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error auto-transitioning to Stage 2: $e");
    }
  }


void _showWhatIfItHappensGuideSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "🩷 What to do if it happens today",
                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: BlushyColors.text),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: BlushyColors.secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGuideStepRow("1", "Don't panic.", "Periods are a natural, healthy part of growing up. You are safe!"),
            const SizedBox(height: 12),
            _buildGuideStepRow("2", "Find a pad.", "Get a pad from your First Period Kit, or ask a trusted friend, teacher, or school nurse."),
            const SizedBox(height: 12),
            _buildGuideStepRow("3", "Tell a trusted adult.", "Let your mom, guardian, teacher, or school nurse know so they can help."),
            const SizedBox(height: 12),
            _buildGuideStepRow("4", "Change when needed.", "Place the pad inside your underwear and change it every 4-6 hours."),
            const SizedBox(height: 12),
            _buildGuideStepRow("5", "You're okay.", "Take a deep breath. You did great!"),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _transitionToFirstPeriodStartedDirectly();
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                label: Text(
                  "It Happened Today? Transition to Stage 2 →",
                  style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD0D22),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

Widget _buildGuideStepRow(String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: BlushyColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            num,
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: BlushyColors.text),
              ),
              Text(
                desc,
                style: GoogleFonts.manrope(fontSize: 12, height: 1.4, color: BlushyColors.secondaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }

Widget _buildMyFirstPeriodKitCard() {
    final int checkedCount = _stage1PeriodKitItems.values.where((v) => v).length;
    final int totalCount = _stage1PeriodKitItems.length;
    final bool isAllPacked = checkedCount == totalCount;
    final double progress = totalCount > 0 ? checkedCount / totalCount : 0.0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlushyColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: BlushyColors.primary.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("🎒", style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    "My First Period Kit",
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.text,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAllPacked
                      ? const Color(0xFFE8F5E9)
                      : BlushyColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isAllPacked ? "READY! 💗" : "$checkedCount / $totalCount PACKED",
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isAllPacked ? const Color(0xFF2E7D32) : BlushyColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isAllPacked
                ? "You're prepared! 💗 Your period kit is ready in your school bag."
                : "Let's make sure you're ready — just in case.",
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: BlushyColors.secondaryText,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: BlushyColors.border.withValues(alpha: 0.5),
              color: isAllPacked ? const Color(0xFF4CAF50) : BlushyColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: _stage1PeriodKitItems.entries.map((entry) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: BlushyColors.primary,
                title: Text(
                  entry.key,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: entry.value ? FontWeight.w600 : FontWeight.w400,
                    color: entry.value ? BlushyColors.text : BlushyColors.secondaryText,
                    decoration: entry.value ? TextDecoration.lineThrough : null,
                  ),
                ),
                value: entry.value,
                onChanged: (val) {
                  setState(() {
                    _stage1PeriodKitItems[entry.key] = val ?? false;
                  });
                },
              );
            }).toList(),
          ),
          if (isAllPacked) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC8E6C9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Awesome! You're prepared. Want to learn what to do if your period starts at school?",
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

Widget _buildWhatsHappeningToMyBodySection() {
    final articles = [
      {
        'title': 'Discharge',
        'subtitle': 'That clear or white stuff? It\'s completely normal.',
        'summary': 'Clear or white fluid in your underwear is called discharge. It is your body\'s natural way of keeping itself clean and healthy as you grow up.',
        'icon': '💧',
      },
      {
        'title': 'Growing & changing',
        'subtitle': 'Your body won\'t grow at the same speed as everyone else\'s.',
        'summary': 'Everyone enters puberty at their own pace. Some grow tall quickly, while others change gradually. Both are 100% normal!',
        'icon': '🌱',
      },
      {
        'title': 'Body hair',
        'subtitle': 'Hair can start appearing in new places. That\'s normal too.',
        'summary': 'During puberty, soft hair begins to grow under your arms and around your private area. It protects your skin.',
        'icon': '✨',
      },
      {
        'title': 'Mood changes',
        'subtitle': 'Some days you might feel extra emotional. You\'re not weird.',
        'summary': 'Hormones are growing inside your body, which can make you feel happy one hour and moody the next. Take deep breaths!',
        'icon': '💭',
      },
      {
        'title': 'Your first period',
        'subtitle': 'What actually happens when it comes?',
        'summary': 'A period is a small amount of blood exiting your uterus once a month. It usually lasts 3 to 7 days and means your body is mature.',
        'icon': '🩸',
      },
      {
        'title': 'Breasts & body shape',
        'subtitle': 'Bodies change differently — and that\'s okay.',
        'summary': 'Breast buds might feel tender as they start growing. Wearing a soft training bra helps you feel comfortable.',
        'icon': '🌷',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("🌱", style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              "What's happening to my body?",
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: BlushyColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Friendly guides to help you understand your changing body",
          style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: articles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final art = articles[index];
              return InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ArticleDetailDialog(
                      title: art['title']!,
                      summary: art['summary']!,
                      question: 'Can you tell me more about ${art['title']} in simple words?',
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BlushyColors.border.withValues(alpha: 0.7)),
                    boxShadow: [
                      BoxShadow(
                        color: BlushyColors.primary.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(art['icon']!, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 8),
                      Text(
                        art['title']!,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: BlushyColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        art['subtitle']!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          height: 1.35,
                          color: BlushyColors.secondaryText,
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

Widget _buildStage1FeelingReflector() {
    final moods = [
      {'emoji': '😊', 'label': 'Happy'},
      {'emoji': '😌', 'label': 'Calm'},
      {'emoji': '🤩', 'label': 'Excited'},
      {'emoji': '😬', 'label': 'Nervous'},
      {'emoji': '😴', 'label': 'Tired'},
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlushyColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("💭", style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                "How are you feeling today?",
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: moods.map((m) {
              final isSelected = _stage1SelectedMood == m['label'];
              return InkWell(
                onTap: () {
                  setState(() {
                    _stage1SelectedMood = m['label']!;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BlushyColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? BlushyColors.primary : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(m['emoji']!, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text(
                        m['label']!,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Energy level:",
                style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText),
              ),
              Text(
                _stage1EnergyLevel < 4 ? "Low / Rest" : (_stage1EnergyLevel < 7 ? "Steady" : "High Energy"),
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: BlushyColors.primary),
              ),
            ],
          ),
          Slider(
            value: _stage1EnergyLevel,
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: BlushyColors.primary,
            onChanged: (val) {
              setState(() {
                _stage1EnergyLevel = val;
              });
            },
          ),
        ],
      ),
    );
  }

Widget _buildWhatIfItHappensTodayCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB6C1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("🩷", style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                "What if I get my first period today?",
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Don't worry! Tap below for a simple, panic-free step-by-step guide.",
            style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showWhatIfItHappensGuideSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                "View 5-Step Guide →",
                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildStage1LetsTalkSection() {
    final prompts = [
      "When did you get your first period?",
      "What should I keep in my school bag?",
      "What if I get my period at school?",
      "Can you help me make my period kit?",
      "What happens when I get my first period?",
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlushyColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("💗", style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                "Let's Talk",
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Sometimes it's easier to start with a question for mom or your guardian.",
            style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 14),
          Column(
            children: prompts.map((prompt) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BlushyColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BlushyColors.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: BlushyColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        prompt,
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.text),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Prompt ready! You can share this with your guardian whenever you're ready.",
                              style: GoogleFonts.manrope(),
                            ),
                            backgroundColor: BlushyColors.primary,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: BlushyColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Share →",
                          style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  Widget _buildNotStartedHomeOS(PersonalContext pc, BlushyOSState state) {
    // Resolved centrally, so this also picks up a name that reached storage
    // before app state had it.
    final String displayName = userDisplayName(context);

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
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width < 768
                      ? 640
                      : double.infinity,
                ),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  children: [
                    _buildNotStartedHeroHeader(displayName),
                    const SizedBox(height: 20),
                    _buildSiasDailyLetterNotStarted(displayName),
                    const SizedBox(height: 24),
                    _buildFloStyleSelfCareCategoryRow(),
                    const SizedBox(height: 24),
                    _buildVisualArticlesCarousel(),
                    const SizedBox(height: 24),
                    _buildFirstPeriodTransitionBanner(),
                    const SizedBox(height: 24),
                    _buildMyFirstPeriodKitCard(),
                    const SizedBox(height: 24),
                    _buildWhatsHappeningToMyBodySection(),
                    const SizedBox(height: 24),
                    _buildStage1FeelingReflector(),
                    const SizedBox(height: 24),
                    _buildWhatIfItHappensTodayCard(),
                    const SizedBox(height: 24),
                    _buildStage1LetsTalkSection(),
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
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 8,
                    bottom: 36,
                  ),
                  children: [
                    _buildNotStartedHeroHeader(displayName),
                    const SizedBox(height: 24),
                    _buildSiasDailyLetterNotStarted(displayName),
                    const SizedBox(height: 28),
                    _buildFloStyleSelfCareCategoryRow(),
                    const SizedBox(height: 28),
                    _buildVisualArticlesCarousel(),
                    const SizedBox(height: 32),
                    _buildFirstPeriodTransitionBanner(),
                    const SizedBox(height: 32),
                    _buildMyFirstPeriodKitCard(),
                    const SizedBox(height: 32),
                    _buildWhatsHappeningToMyBodySection(),
                    const SizedBox(height: 32),
                    _buildStage1FeelingReflector(),
                    const SizedBox(height: 32),
                    _buildWhatIfItHappensTodayCard(),
                    const SizedBox(height: 32),
                    _buildStage1LetsTalkSection(),
                  ],
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (Responsive editorial multi-column)
          return _wrapDashboardLayout(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: min(1440.0, width - 64.0),
                padding: const EdgeInsets.only(
                  left: 48,
                  right: 48,
                  top: 8,
                  bottom: 40,
                ),
                child: ListView(
                  controller: widget.isNested ? null : _homeScrollController,
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  children: [
                    _buildNotStartedHeroHeader(displayName),
                    const SizedBox(height: 24),
                    _buildSiasDailyLetterNotStarted(displayName),
                    const SizedBox(height: 28),
                    _buildFloStyleSelfCareCategoryRow(),
                    const SizedBox(height: 28),
                    _buildVisualArticlesCarousel(),
                    const SizedBox(height: 32),
                    _buildFirstPeriodTransitionBanner(),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (60% width)
                        Expanded(
                          flex: 60,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMyFirstPeriodKitCard(),
                              const SizedBox(height: 32),
                              _buildWhatsHappeningToMyBodySection(),
                              const SizedBox(height: 32),
                              _buildStage1LetsTalkSection(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),

                        // Right Column (40% width)
                        Expanded(
                          flex: 40,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWhatIfItHappensTodayCard(),
                              const SizedBox(height: 32),
                              _buildStage1FeelingReflector(),
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


// --- STAGE 2: FIRST PERIOD STARTED (MY FIRST CYCLES) ---
Widget _buildStage2SchoolKitCard() {
    final activeItems = _stage2AllKitScenarios[_stage2SelectedKitScenario] ?? _stage2AllKitScenarios['School Bag']!;
    final packedCount = activeItems.values.where((v) => v).length;
    final totalCount = activeItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleWithFilledIcon(
          icon: Icons.backpack_rounded,
          iconColor: const Color(0xFFDD0D22),
          bgColor: const Color(0xFFFFF0F2),
          title: "Everyday & Emergency Period Kit",
          subtitle: "$packedCount of $totalCount items packed for $_stage2SelectedKitScenario",
        ),
        const SizedBox(height: 12),
        // Scenario Switcher Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _stage2AllKitScenarios.keys.map((scenario) {
              final isSelected = _stage2SelectedKitScenario == scenario;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: Text(scenario),
                  selected: isSelected,
                  selectedColor: const Color(0xFFDD0D22),
                  backgroundColor: Colors.white,
                  labelStyle: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : BlushyColors.text,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFDD0D22) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  onSelected: (sel) {
                    if (sel) {
                      setState(() {
                        _stage2SelectedKitScenario = scenario;
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFCF9F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0EBE6)),
          ),
          child: Column(
            children: activeItems.entries.map((entry) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: const Color(0xFFDD0D22),
                title: Text(
                  entry.key,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: entry.value ? FontWeight.w700 : FontWeight.w500,
                    color: entry.value ? BlushyColors.text : BlushyColors.secondaryText,
                  ),
                ),
                value: entry.value,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      activeItems[entry.key] = val;
                    });
                    try {
                      final p = Map<String, dynamic>.from(BlushyStorage.read('user_profile.json'));
                      p['stage2_kit_$_stage2SelectedKitScenario'] = activeItems;
                      BlushyStorage.write('user_profile.json', p);
                      ApiAuthService().saveOnboardingAnswers({
                        'stage2_kit_scenario': _stage2SelectedKitScenario,
                        'stage2_kit_packed': activeItems,
                      }).catchError((_) => <String, dynamic>{});
                    } catch (_) {}
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

Widget _buildFirstYearLessonsHub() {
    final guides = [
      {
        'title': 'How to place & change a pad smoothly',
        'readTime': '2 min read',
        'icon': Icons.dry_cleaning_rounded,
        'summary': 'Unwrap the pad, peel the backing strip, press firmly into the middle of your underwear, and secure the wings around the sides. Change every 4 to 6 hours to stay fresh and clean.'
      },
      {
        'title': 'What to do if you leak while out in public / school',
        'readTime': '2 min read',
        'icon': Icons.public_rounded,
        'summary': 'Don\'t panic! Tie a sweater or jacket around your waist, head to the nearest restroom, grab a fresh pad or liner, and rinse any fabric with cold water. Stains happen to everyone and wash out easily.'
      },
      {
        'title': 'Managing cramps during class, work or sports',
        'readTime': '2 min read',
        'icon': Icons.spa_rounded,
        'summary': 'Sit up straight, take slow deep belly breaths, sip warm water, and gently press a warm hand or heating patch over your lower tummy. Gentle stretching also helps relieve uterine tension.'
      },
      {
        'title': 'Asking for supplies or restroom breaks with ease',
        'readTime': '1 min read',
        'icon': Icons.chat_rounded,
        'summary': 'Keep it simple: "May I use the restroom?" or quietly ask a friend, coworker, or school nurse: "Do you have a spare pad?" People are always supportive and discreet.'
      },
      {
        'title': 'How to track irregular first-year cycles',
        'readTime': '2 min read',
        'icon': Icons.auto_graph_rounded,
        'summary': 'In your first 1-2 years, cycles can range between 21 to 45 days. This is 100% normal as your body balances hormones. Log each period day in Blushy to let Docsy learn your rhythm.'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleWithFilledIcon(
          icon: Icons.menu_book_rounded,
          iconColor: const Color(0xFF3DA672),
          bgColor: const Color(0xFFEBF7F0),
          title: "First-Year Survival & Everyday Guides",
          subtitle: "Quick 2-minute friendly guides for school, work, sports & home",
        ),
        const SizedBox(height: 12),
        Column(
          children: guides.map((g) {
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFF0EBE6)),
              ),
              color: const Color(0xFFFCF9F6),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEBF7F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(g['icon'] as IconData, size: 16, color: const Color(0xFF3DA672)),
                ),
                title: Text(
                  g['title'] as String,
                  style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: BlushyColors.text),
                ),
                subtitle: Text(
                  g['readTime'] as String,
                  style: GoogleFonts.manrope(fontSize: 11, color: BlushyColors.secondaryText),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: BlushyColors.primary),
                      tooltip: "Ask Docsy AI",
                      onPressed: () {
                        _openAskSiaChat(context, "Hi Docsy, tell me more advice about: ${g['title']}");
                      },
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: BlushyColors.secondaryText),
                  ],
                ),
                onTap: () {
                  _showArticleDialog(context, g['title'] as String, g['summary'] as String);
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

Widget _buildStage2LetsTalkSection() {
    final prompts = [
      "Hey Mom/Dad, can we buy a few more pads for my school bag?",
      "I'm having some cramps today, can I take a warm bath or rest?",
      "Can we track my periods together on my phone?",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleWithFilledIcon(
          icon: Icons.chat_bubble_outline_rounded,
          iconColor: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
          title: "Talk to Your Parent or Guardian",
          subtitle: "Need help asking? Tap any prompt to copy",
        ),
        const SizedBox(height: 12),
        Column(
          children: prompts.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFCF9F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0EBE6)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "“$p”",
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          elevation: 6,
                          backgroundColor: const Color(0xFF2C2228),
                          margin: const EdgeInsets.only(bottom: 84, left: 16, right: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          content: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFFFB3BA)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Prompt ready! You can share this with your guardian whenever you're ready.",
                                  style: GoogleFonts.manrope(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: BlushyColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Share →",
                        style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }


  Widget _buildFirstPeriodStartedHomeOS(
    PersonalContext pc,
    BlushyOSState state, [
    bool isMobile = false,
  ]) {
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
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width < 768
                      ? 640
                      : double.infinity,
                ),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  children: [
                    _buildLivingTodayCycle(),
                    const SizedBox(height: 24),
                    _buildFloStyleSelfCareCategoryRow(),
                    const SizedBox(height: 24),
                    _buildVisualArticlesCarousel(),
                    const SizedBox(height: 24),
                    _buildWellnessDashboard(pc),
                    const SizedBox(height: 24),
                    _buildStage2SchoolKitCard(),
                    const SizedBox(height: 24),
                    _buildFirstYearLessonsHub(),
                    const SizedBox(height: 24),
                    _buildStage2LetsTalkSection(),
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
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 8,
                    bottom: 36,
                  ),
                  children: [
                    _buildLivingTodayCycle(),
                    const SizedBox(height: 28),
                    _buildFloStyleSelfCareCategoryRow(),
                    const SizedBox(height: 28),
                    _buildVisualArticlesCarousel(),
                    const SizedBox(height: 32),
                    _buildWellnessDashboard(pc),
                    const SizedBox(height: 32),
                    _buildStage2SchoolKitCard(),
                    const SizedBox(height: 32),
                    _buildFirstYearLessonsHub(),
                    const SizedBox(height: 32),
                    _buildStage2LetsTalkSection(),
                  ],
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (Balanced Editorial multi-column)
          return _wrapDashboardLayout(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: min(1440.0, width - 64.0),
                padding: const EdgeInsets.only(
                  left: 48,
                  right: 48,
                  top: 8,
                  bottom: 40,
                ),
                child: ListView(
                  controller: widget.isNested ? null : _homeScrollController,
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  children: [
                    _buildLivingTodayCycle(),
                    const SizedBox(height: 28),
                    _buildFloStyleSelfCareCategoryRow(),
                    const SizedBox(height: 28),
                    _buildVisualArticlesCarousel(),
                    const SizedBox(height: 32),
                    _buildWellnessDashboard(pc),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (60% width)
                        Expanded(
                          flex: 60,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStage2SchoolKitCard(),
                              const SizedBox(height: 32),
                              _buildStage2LetsTalkSection(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),

                        // Right Column (40% width)
                        Expanded(
                          flex: 40,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFirstYearLessonsHub(),
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

  // --- BRANCH: LIVING WITH MY CYCLE (livingWithMyCycle) ---
  final ScrollController _livingHomeScrollController = ScrollController();

  // --- SECTION 1: DOCSY'S DAILY BRIEF (HERO) ---

  // --- SECTION 2: TODAY'S CYCLE (Featuring Ovary loop tracker BlushyCycleCard) ---
  Widget _buildLivingTodayCycle() {
    final cycleData = _getDynamicCycleDates(_currentPc);
    final bool hasPeriodLogged = cycleData['isLogged'] == true;

    final pc = _currentPc;

    // The wash begins at the top of the section, behind the heading as well as
    // the cycle, and fades into the page colour before the section ends. Only
    // this section has it.
    // How long a cycle runs for this person, defaulted the same way the rest
    // of the app defaults it. Period length is left to the painter's own
    // default, as the cycle card already does -- there is no logged figure for
    // it, and inventing one would put a wrong number on the legend.
    // From the cycle the server calculated, which is what the day and the
    // phase already come from. The profile carries its own copy of the cycle
    // length; the server's is the one everything on this card is counted
    // from. Period length was a constant 5 here before, while the logged
    // figure sat unused in the same object.
    final CycleState? heroState = _cycleResult.data ?? _lastKnownCycle;
    final int? serverCycle = heroState?.cycleLengthDays;
    final int? serverPeriod = heroState?.periodLengthDays;
    final int heroCycle = (serverCycle != null && serverCycle > 0)
        ? serverCycle
        : ((pc.cycleLength != null && pc.cycleLength! > 0) ? pc.cycleLength! : 28);
    // Five only where the server sent nothing -- a fresh account with no
    // period logged yet -- and then the legend is describing a typical
    // cycle, not hers, which the card's own wording already says.
    final int heroPeriod =
        (serverPeriod != null && serverPeriod > 0) ? serverPeriod : 5;
    final int? heroDay = cycleData['cycleDay'] as int?;

    // Greeting, cycle, recently -- then the way to add to the day, and what
    // is in it. Laid out to the home design spec: the greeting on the page
    // rather than in a box, the ring as the focal element, one surface for
    // what was logged lately.
    final t = AppLocalizations.of(context);
    final rawName = (pc.userName ?? '').trim();
    final greetName = rawName.isEmpty ? 'there' : rawName;
    final greeting = GreetingCard.greetingFor(t, greetName, DateTime.now());

    final CyclePhaseKind? phaseKind =
        hasPeriodLogged ? CyclePhaseKindLook.parse(cycleData['phaseName'] as String?) : null;
    final CycleCardState ringState = switch (cycleData['state']) {
      'loading' => CycleCardState.loading,
      'ready' || 'insufficient_data' => CycleCardState.ready,
      _ => CycleCardState.noTracking,
    };
    // The model's own caveat where predictions are limited or the cycle is
    // irregular; shown as written, so no false precision is added here.
    final String? caveat = cycleData['state'] == 'insufficient_data'
        ? (heroState?.sufficiencyMessage ?? 'Predictions are limited until a few more cycles are logged.')
        : (heroState?.confidenceLevel == 'low' ? heroState?.sufficiencyMessage : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GreetingHero(greeting: greeting, name: greetName),
        const SizedBox(height: BlushySpace.betweenSections),
        CycleRingCard(
          state: ringState,
          phase: phaseKind,
          cycleDay: heroDay,
          cycleLength: heroCycle,
          periodLength: heroPeriod,
          caveat: caveat,
          onCalendar: () => _showLogPeriodBottomSheet(context),
          onSetUp: () => _showLogPeriodBottomSheet(context),
          onInsights: phaseKind == null
              ? null
              : () => _openAskSiaChat(
                    context,
                    'What should I know about my ${phaseKind.label.toLowerCase()} phase?',
                  ),
        ),
        const SizedBox(height: BlushySpace.betweenSections),
        RecentlySurface(
          items: _recentItems(heroState),
          onEmptyAction: _openSymptomSheet,
        ),
      ],
    );
  }

  /// What was logged lately, as rows with a value. Nothing is invented for
  /// a row that has none; it is simply not in the list.
  List<RecentItem> _recentItems(CycleState? cycle) {
    final items = <RecentItem>[];
    final checkin = BlushyStorage.read('daily_checkin.json');

    final start = DateTime.tryParse(cycle?.cycleStartDate ?? '');
    if (start != null) {
      final days = (cycle?.periodLengthDays ?? 5).clamp(1, 14);
      final end = start.add(Duration(days: days - 1));
      items.add(RecentItem(
        icon: Icons.water_drop_outlined,
        title: 'Period',
        value: '${_formatDayMonth(start.toIso8601String())} \u2013 ${_formatDayMonth(end.toIso8601String())}',
        onTap: () => _showLogPeriodBottomSheet(context),
      ));
    }

    final symptoms = checkin['symptom'];
    if (symptoms is List && symptoms.isNotEmpty) {
      items.add(RecentItem(
        icon: Icons.healing_rounded,
        title: 'Symptoms',
        value: symptoms.map((e) => e.toString()).join(', '),
        onTap: _openSymptomSheet,
      ));
    }

    final mood = checkin['feeling'] ?? checkin['mood'];
    if (mood is String && mood.isNotEmpty) {
      items.add(RecentItem(
        icon: Icons.sentiment_satisfied_outlined,
        title: 'Mood',
        value: mood,
        onTap: _openSymptomSheet,
      ));
    }
    return items;
  }

  /// One row of the signals card.
  ///
  /// The dashboard words an unlogged metric as "Not Logged Today"; that string
  /// is what the row is told, rather than the row trying to recognise it, so
  /// the two cannot disagree about what counts as logged.
  LoggedSignal _signal(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return LoggedSignal(
      label: label,
      value: value,
      logged: value != 'Not Logged Today' && value != 'Loading...',
      color: color,
      icon: icon,
      onTap: _openSymptomSheet,
    );
  }

  void _showLogPeriodBottomSheet(BuildContext context) {
    DateTime selectedStart =
        _periodConfirmationState.actualStartDate ?? DateTime.now();
    DateTime? selectedEnd;

    // The starts already on file, so a mistaken one can be taken off.
    //
    // Logging a period could not be undone from anywhere in the app:
    // `CycleApi.deletePeriod` and the route behind it both existed, and no
    // screen called either. A mis-tapped start stayed, and because the cycle
    // is anchored to the *latest* start, it kept winning -- logging the real
    // earlier date again did nothing, since that only replaces entries within
    // one cycle length. Reported as a cycle stuck on Day 1 after a wrong tap,
    // with the partner's screen correctly showing the same.
    List<Map<String, dynamic>> loggedStarts = const [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            if (loggedStarts.isEmpty) {
              CycleApi.history(limit: 12).then((result) {
                if (!context.mounted || !result.isReady) return;
                final rows = result.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) return;
                setModalState(() => loggedStarts = rows);
              });
            }

            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: BlushyColors.background,
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
                    AppLocalizations.of(context).dashLogEditPeriod,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context).dashConfirmCorrectPeriodStart,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context).dashPeriodStartDate,
                    style: GoogleFonts.manrope(
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
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: BlushyColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: BlushyColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).dashPeriodEndDateOptional,
                    style: GoogleFonts.manrope(
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
                        initialDate:
                            selectedEnd ??
                            selectedStart.add(const Duration(days: 5)),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: selectedEnd == null
                                  ? BlushyColors.secondaryText
                                  : BlushyColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: BlushyColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Only for a start that is actually on file for the chosen
                  // date: this removes a record, so it must never be offered
                  // where there is nothing to remove.
                  if (_loggedEntryFor(loggedStarts, selectedStart) != null) ...[
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          final entry =
                              _loggedEntryFor(loggedStarts, selectedStart);
                          if (entry == null) return;
                          Navigator.pop(context);
                          _confirmRemovePeriod(entry, selectedStart);
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: BlushyColors.primary),
                        label: Text(
                          'Remove this period',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: BlushyColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: BlushyColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            AppLocalizations.of(context).dashCancel,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: BlushyColors.secondaryText,
                            ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            AppLocalizations.of(context).dashSave,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
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
          },
        );
      },
    );
  }

  /// The logged start matching a chosen date, or null.
  ///
  /// Matched on the calendar date only -- the rows carry a date string, the
  /// picker carries a DateTime, and comparing them as instants never matches.
  static Map<String, dynamic>? _loggedEntryFor(
    List<Map<String, dynamic>> rows,
    DateTime day,
  ) {
    final wanted = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    for (final row in rows) {
      final start = row['periodStartDate']?.toString() ??
          row['period_start_date']?.toString() ??
          row['startDate']?.toString();
      if (start == null) continue;
      if (start.length >= 10 && start.substring(0, 10) == wanted) return row;
    }
    return null;
  }

  /// Removes a logged period start, after asking.
  ///
  /// Deleting is the only way back from a mis-tap, and it is also destructive,
  /// so it is confirmed and it names the date being removed rather than
  /// saying "this one".
  Future<void> _confirmRemovePeriod(
    Map<String, dynamic> entry,
    DateTime day,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = (entry['id'] ?? entry['_id'] ?? entry['entryId'] ?? '').toString();
    if (id.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That entry cannot be removed from here.')),
      );
      return;
    }

    final label = '${day.day} ${_shortMonth(day.month)} ${day.year}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this period?'),
        content: Text(
          'The period starting $label will be removed, and your cycle will be '
          'counted from the one before it. Nothing else you have logged '
          'changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await CycleApi.deletePeriod(id);
    if (!mounted) return;

    if (result.isReady) {
      messenger.showSnackBar(
        SnackBar(content: Text('Removed the period starting $label.')),
      );
      // The same re-read the save path falls back to, so the ring, the phase
      // and everything keyed off them follow the removal immediately.
      await _loadCycleFromServer();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'That could not be removed.'),
        ),
      );
    }
  }

  static String _shortMonth(int month) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][month - 1];

  Future<void> _logPeriodRange(DateTime startDate, DateTime? endDate) async {
    // Captured before the await below.
    final messenger = ScaffoldMessenger.of(context);
    final provider = BlushyOSProvider.of(context);
    final cur = provider.personalContext;

    // Persist the event, then take the recalculated cycle from the response.
    final logged = await CycleApi.logPeriod(
      startDate: startDate,
      endDate: endDate,
    );
    if (!mounted) return;

    final CycleState? serverCycle = logged.data?.cycle;
    if (serverCycle != null) {
      setState(() {
        _lastKnownCycle = serverCycle;
        _cycleResult = ApiResult<CycleState>(
          data: serverCycle,
          state: logged.state == ApiState.loading
              ? ApiState.ready
              : logged.state,
          source: logged.source,
          version: logged.version,
          lastUpdated: logged.lastUpdated,
        );
      });
    } else {
      await _loadCycleFromServer();
      if (!mounted) return;
    }

    final int cLen = (cur.cycleLength != null && cur.cycleLength! > 0)
        ? cur.cycleLength!
        : 28;
    final int? cDay = serverCycle?.currentCycleDay;

    provider.updatePersonalContext(
      PersonalContext(
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
      ),
    );

    setState(() {
      _periodConfirmationState = _periodConfirmationState.copyWith(
        hasLoggedPeriod: true,
        actualStartDate: startDate,
        status: 'confirmed',
      );
    });

    try {
      final profileData = BlushyStorage.read('user_profile.json');
      final profileMap = Map<String, dynamic>.from(
        profileData['profile'] ?? profileData,
      );
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
          cDay == null
              ? 'Period logged.'
              : 'Period logged. You are on day $cDay.',
        ),
      ),
    );
  }

  // --- SECTION 3: CHECK IN (One-tap logging) ---
  Widget _buildLivingCheckIn() => _buildLogAndCheckIn();

  Widget _buildLivingHorizontalSelector(
    String label,
    List<String> options,
    String? selectedValue,
    ValueChanged<String> onSelected, {
    String? logCategoryKey,
    String? checkinKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: options.map((opt) {
            final isSelected =
                selectedValue != null &&
                selectedValue.toLowerCase() == opt.toLowerCase();
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () {
                    onSelected(opt);
                    try {
                      // One flat, string-valued key per metric. The old shape
                      // -- a map under the category key -- could not survive
                      // the endpoint, which stores a non-string answer as
                      // JSON.stringify(value); it came back a String, the
                      // loader's `is Map` check failed, and the value was
                      // dropped. Nothing any tracker recorded was ever
                      // restored.
                      final logKey = trackerLogKey(
                        logCategoryKey ?? 'daily_checkin',
                        label,
                      );
                      _userEditedMetrics.add(logKey);

                      // The daily metrics are also restored from the device on
                      // every tab change. Without writing here, that file kept
                      // an older value and put it straight back over this tap.
                      if (checkinKey != null) {
                        _userEditedMetrics.add('daily_$checkinKey');
                        final checkin = Map<String, dynamic>.from(
                          BlushyStorage.read('daily_checkin.json'),
                        );
                        checkin[checkinKey] = opt;
                        checkin['date'] = DateTime.now().toIso8601String();
                        BlushyStorage.write('daily_checkin.json', checkin);
                      }
                      ApiAuthService()
                          .saveOnboardingAnswers({logKey: opt})
                          .catchError((_) => <String, dynamic>{});
                    } catch (_) {}
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? BlushyColors.primary
                          : const Color(0xFFF9F6F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? BlushyColors.primary
                            : BlushyColors.border,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      opt,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
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

  // --- SECTION 4: DOCSY INSIGHTS (AI section) ---
  /// True while the patterns request has answered "nothing yet".
  ///
  /// The two states that mean that -- no logs at all, or not enough of them
  /// -- get the illustrated card. Every other state (loading, offline, error,
  /// ready) stays with ApiStateCard, which already handles each honestly.
  bool get _patternsAreEmpty =>
      _patternsResult.state == ApiState.empty ||
      _patternsResult.state == ApiState.insufficientData;

  /// The reason there is nothing yet, worded as ApiStateCard would word it.
  String _patternsEmptyNote(String whenEmpty, String whenInsufficient) =>
      _patternsResult.state == ApiState.empty ? whenEmpty : whenInsufficient;

  Widget _buildLivingSiaInsights() {
    const whenEmpty = 'Docsy has not noticed anything in your logs yet.';
    const whenInsufficient =
        'Once you have logged a few days, Docsy will start sharing what it '
        'notices.';

    if (_patternsAreEmpty) {
      return DocsyInsightsCard(
        heading: AppLocalizations.of(context).dashSiaInsights,
        note: _patternsEmptyNote(whenEmpty, whenInsufficient),
        actionLabel: AppLocalizations.of(context).dashLogTodayCheckIn,
        onAction: _scrollToCheckIn,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading(AppLocalizations.of(context).dashSiaInsights),
        ),

        // What the analysis of her onboarding answers concluded.
        //
        // Produced when she finished signing up and stored with her answers.
        // It says what the app is set up to show her -- not what anything
        // means, which is reviewed content and not the model's to write.
        if (_onboardingAnalysisSummary != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _onboardingAnalysisSummary!,
              style: GoogleFonts.manrope(
                fontSize: 12,
                height: 1.5,
                color: BlushyColors.secondaryText,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ApiStateCard<List<Insight>>(
          result: _patternsResult,
          onRetry: () => _loadPatterns(refresh: true),
          emptyMessage: whenEmpty,
          emptyActionLabel: AppLocalizations.of(context).dashLogFirstCheckIn,
          insufficientDataActionLabel: AppLocalizations.of(
            context,
          ).dashLogTodayCheckIn,
          onEmptyAction: _scrollToCheckIn,
          insufficientDataMessage: whenInsufficient,
          builder: (context, insights) {
            if (insights.isEmpty) {
              return _buildPatternsPlaceholder(whenEmpty);
            }
            // The Docsy Note surfaces the strongest current observation.
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BlushyColors.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: BlushyColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight.description,
                    style: GoogleFonts.manrope(
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
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: BlushyColors.secondaryText,
                height: 1.4,
              ),
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
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        AppLocalizations.of(context).dashHelpful,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: BlushyColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => _markInsightNotUseful(insight),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        AppLocalizations.of(context).dashNotUseful,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: BlushyColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _showArticleDialog(
                    context,
                    "How Docsy noticed this",
                    "${insight.description}\n\n${_evidenceLine(insight)}.\n\n"
                        "This describes a pattern in what you logged. It does not explain why, "
                        "and it is not a diagnosis. Blushy shows it so you can decide whether it "
                        "matches your experience.",
                  ),
                  child: Text(
                    AppLocalizations.of(context).dashExplainInsight,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.primary,
                    ),
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

  // --- SECTION 6: COMMUNITY ---

  // --- SECTION 7: MY PATTERNS (Personalized observations dynamically generated from onboarding choices) ---
  Widget _buildLivingPatterns() {
    const whenEmpty = 'Nothing stands out in your logs yet.';
    const whenInsufficient =
        'Keep logging for a couple of weeks and Blushy will start showing '
        'what it notices.';

    if (_patternsAreEmpty) {
      return PatternsEmptyCard(
        heading: AppLocalizations.of(context).dashPatternsTitle,
        note: _patternsEmptyNote(whenEmpty, whenInsufficient),
        actionLabel: AppLocalizations.of(context).dashLogTodayCheckIn,
        onAction: _scrollToCheckIn,
        onRefresh: () => _loadPatterns(refresh: true),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionHeading(AppLocalizations.of(context).dashPatternsTitle),
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
          emptyMessage: whenEmpty,
          emptyActionLabel: AppLocalizations.of(context).dashLogFirstCheckIn,
          insufficientDataActionLabel: AppLocalizations.of(
            context,
          ).dashLogTodayCheckIn,
          onEmptyAction: _scrollToCheckIn,
          insufficientDataMessage: whenInsufficient,
          builder: (context, insights) {
            if (insights.isEmpty) {
              return _buildPatternsPlaceholder(whenEmpty);
            }
            if (insights.length == 1) {
              return _buildInsightCard(insights.first);
            }
            return AutoCarouselCards(
              cards: insights.map(_buildInsightCard).toList(),
              height: 200.0,
            );
          },
        ),
      ],
    );
  }

  Widget _buildPatternsPlaceholder(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BlushySpace.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF7D8DD), width: 0.8),
      ),
      child: Text(
        message,
        style: GoogleFonts.manrope(
          fontSize: 12,
          color: const Color(0xFF7A6B72),
          height: 1.4,
        ),
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

    return Container(
      padding: const EdgeInsets.all(BlushySpace.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF7D8DD), width: 0.8),
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
                    Icon(insightIcon, size: 16, color: BlushyColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        insight.title.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: BlushyColors.primary,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F6F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEAE3DC), width: 0.6),
                ),
                child: Text(
                  _strengthLabel(insight),
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            insight.description,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: BlushyColors.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _evidenceLine(insight),
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              color: const Color(0xFF7A6B72),
              height: 1.4,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _markInsightNotUseful(insight),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  AppLocalizations.of(context).dashNotUseful,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: BlushyColors.secondaryText,
                  ),
                ),
              ),
              if (insight.generatedAt != null)
                Text(
                  _relativeTime(insight.generatedAt!),
                  style: GoogleFonts.manrope(
                    fontSize: 9.5,
                    color: BlushyColors.secondaryText.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ],
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
  /// "July 2026" from "2026-07", or null where the month is not known.
  static String? _monthLabel(String reportingMonth) {
    final parts = reportingMonth.split('-');
    if (parts.length != 2) return null;
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return null;
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    return '${names[month - 1]} ${parts[0]}';
  }

  Widget _buildLivingJourney() {
    final journeyData = SiaDashboardService().getMonthlyReflectionAndMilestones(
      pc: _currentPc,
      state: BlushyOSProvider.of(context),
    );

    // The card reports the last *completed* calendar month, so through
    // August it reports July -- and someone who installed the app in August
    // has no July here. This used to hide the whole card for her, which
    // meant it appeared before the server answered and vanished after: the
    // page changed shape on a network response. It stays, and says why it
    // has nothing yet, rather than listing things she "did not log" in a
    // month she was not here for.
    if (journeyData.dataState == 'not_yet_joined') {
      return MonthlyJourneyCard(
        heading: 'MONTHLY REFLECTION & JOURNEY',
        monthLabel: _monthLabel(journeyData.reportingMonth),
        milestones: const [],
        reflectionHeading: AppLocalizations.of(context).dashDocsySReflection,
        reflection: 'Your first monthly reflection arrives after your first '
            'full month here. Everything you log until then is what it will '
            'be written from.',
      );
    }

    return MonthlyJourneyCard(
      heading: 'MONTHLY REFLECTION & JOURNEY',
      monthLabel: _monthLabel(journeyData.reportingMonth),
      milestones: journeyData.milestoneItems,
      reflectionHeading: AppLocalizations.of(context).dashDocsySReflection,
      reflection: journeyData.reflection,
    );
  }

  // =========================================================================
// RESTORED STAGE 3: LIVING WITH MY CYCLE OS
// =========================================================================

/// Dedicated Daily Cycle-Syncing Intelligence AI Brief for 20+ Adult Women
  Widget _buildStage3UnifiedCycleOSCard(PersonalContext pc) {
    final int cycleDay = (pc.cycleDay != null && pc.cycleDay! > 0) ? pc.cycleDay! : 14;
    final int cycleLength = (pc.cycleLength != null && pc.cycleLength! > 20) ? pc.cycleLength! : 28;

    String currentPhase;
    if (cycleDay <= 5) {
      currentPhase = "Menstrual Phase";
    } else if (cycleDay <= 12) {
      currentPhase = "Follicular Phase";
    } else if (cycleDay <= 16) {
      currentPhase = "Ovulatory Phase";
    } else {
      currentPhase = "Luteal Phase";
    }

    final lifestyleTabs = [
      {'id': 'work', 'label': 'Work & Focus', 'icon': Icons.work_outline_rounded, 'color': const Color(0xFFFF7D00)},
      {'id': 'fitness', 'label': 'Fitness', 'icon': Icons.directions_run_rounded, 'color': const Color(0xFFFF006D)},
      {'id': 'nutrition', 'label': 'Nutrition & Glow', 'icon': Icons.restaurant_rounded, 'color': const Color(0xFF01BEFE)},
      {'id': 'caffeine', 'label': 'Caffeine & Water', 'icon': Icons.coffee_rounded, 'color': const Color(0xFFFF7D00)},
      {'id': 'social', 'label': 'Social & Partner', 'icon': Icons.favorite_border_rounded, 'color': const Color(0xFFFF006D)},
      {'id': 'rituals', 'label': 'Micro-Rituals', 'icon': Icons.auto_awesome_rounded, 'color': const Color(0xFF8F00FF)},
    ];

    final currentTabInfo = lifestyleTabs.firstWhere(
      (t) => t['id'] == _selectedStage3LifestyleTab,
      orElse: () => lifestyleTabs.first,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAE3DC), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Dedicated Header with Branded Identity and Docsy AI Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 15,
                            color: Color(0xFFFF006D),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Daily Cycle-Syncing Intelligence",
                            style: GoogleFonts.manrope(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: BlushyColors.text,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "AI-powered daily performance, fitness & nourishment brief",
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCCD9)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFFF006D)),
                    const SizedBox(width: 4),
                    Text(
                      "Docsy AI",
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFF006D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Interactive Lifestyle Dimension Selector Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: lifestyleTabs.map((tab) {
                final id = tab['id'] as String;
                final label = tab['label'] as String;
                final icon = tab['icon'] as IconData;
                final color = tab['color'] as Color;
                final isSelected = _selectedStage3LifestyleTab == id;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedStage3LifestyleTab = id;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? color : const Color(0xFFF7F4F0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? color : const Color(0xFFE8E2DA),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 14,
                            color: isSelected ? Colors.white : BlushyColors.secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.white : BlushyColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Dynamic AI Daily Brief & Structured Insight Body
          _buildStage3DynamicLifestyleBody(cycleDay, currentPhase),
          const SizedBox(height: 14),

          // 4. Live AI Docsy Plan Action
          InkWell(
            onTap: () {
              final tabName = currentTabInfo['label'] as String;
              _openAskSiaChat(
                context,
                "I'm on Day $cycleDay of my cycle ($currentPhase). Can you generate a personalized daily $tabName plan with actionable tips for my hormones today?",
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFDFC2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFFF006D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Ask Docsy AI to Generate Today's Custom Plan",
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFF006D),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFFFF006D)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage3DynamicLifestyleBody(int cycleDay, String currentPhase) {
    if (_selectedStage3LifestyleTab == 'work') {
      String focus;
      String biohack;
      String avoid;
      String energyVibe;

      if (cycleDay <= 5) {
        energyVibe = "Strategic & Low Meeting Load";
        focus = "Big-picture planning, systems evaluation & contract reviews.";
        biohack = "Estrogen is at baseline. Right & left brain hemispheres communicate best—great for strategic discernment.";
        avoid = "Back-to-back presentations and intense high-conflict negotiations.";
      } else if (cycleDay <= 12) {
        energyVibe = "High Creative Stamina";
        focus = "Ideation, launching projects, kickoffs & creative problem solving.";
        biohack = "Rising estrogen enhances verbal fluency, learning capacity, and risk tolerance.";
        avoid = "Repetitive administrative data entry (delegate if possible).";
      } else if (cycleDay <= 16) {
        energyVibe = "Peak Magnetic Communication";
        focus = "High-stakes pitches, public speaking & salary or contract negotiations.";
        biohack = "Estrogen and testosterone surge simultaneously, unlocking maximum verbal persuasion and presence.";
        avoid = "Isolated solitary work—leverage team interactions today.";
      } else {
        energyVibe = "Deep Focus & Detail Execution";
        focus = "Complex detail auditing, accounting, editing & wrapping up deliverables.";
        biohack = "Progesterone promotes methodical concentration and spot-checking errors.";
        avoid = "Starting major unvetted projects without clear briefs.";
      }

      return _buildAIBriefCard(
        energyTag: energyVibe,
        primaryFocus: focus,
        biohack: biohack,
        avoid: avoid,
        accentColor: const Color(0xFFFF7D00),
        icon: Icons.work_outline_rounded,
        pillarTitle: "Work & Focus Brief",
        onQuickAsk: (prompt) => _openAskSiaChat(context, prompt),
        quickPrompt: "Docsy, organize my work day around my Day $cycleDay ($currentPhase) energy levels.",
      );
    } else if (_selectedStage3LifestyleTab == 'fitness') {
      String focus;
      String biohack;
      String avoid;
      String energyVibe;

      if (cycleDay <= 5) {
        energyVibe = "Low Intensity / Recovery";
        focus = "Restorative yoga, yin stretching & gentle outdoor walks.";
        biohack = "Pelvic ligaments and joints are more lax while estrogen is low; prioritize gentle core & low back protection.";
        avoid = "Heavy maximum-effort PR lifting or intense HIIT sprints.";
      } else if (cycleDay <= 12) {
        energyVibe = "Building Power & Strength";
        focus = "Progressive resistance training, tempo runs & new workout routines.";
        biohack = "Rising estrogen accelerates muscle protein synthesis and shortens recovery time.";
        avoid = "Skipping mobility warm-ups before lifting.";
      } else if (cycleDay <= 16) {
        energyVibe = "Peak Athletic Performance";
        focus = "HIIT intervals, heavy strength lifts & bootcamps.";
        biohack = "Testosterone peaks for 3-4 days around ovulation, delivering maximum explosive power.";
        avoid = "Cold starts—warm up thoroughly due to increased joint laxity.";
      } else {
        energyVibe = "Moderate Aerobic / Steady State";
        focus = "Mat Pilates, resistance band sculpting & incline walking.";
        biohack = "Resting core body temperature rises ~0.5°C; keep workouts steady to avoid cortisol spikes.";
        avoid = "Exhausting endurance sessions without post-workout carbs.";
      }

      return _buildAIBriefCard(
        energyTag: energyVibe,
        primaryFocus: focus,
        biohack: biohack,
        avoid: avoid,
        accentColor: const Color(0xFFFF006D),
        icon: Icons.directions_run_rounded,
        pillarTitle: "Movement & Fitness Brief",
        onQuickAsk: (prompt) => _openAskSiaChat(context, prompt),
        quickPrompt: "Docsy, give me a quick 20-min workout routine suitable for Day $cycleDay ($currentPhase).",
      );
    } else if (_selectedStage3LifestyleTab == 'nutrition') {
      String focus;
      String biohack;
      String avoid;
      String energyVibe;

      if (cycleDay <= 5) {
        energyVibe = "Replenish & Restore";
        focus = "Iron-rich foods, bone broth, spinach, lentils, pumpkin seeds & dark berries.";
        biohack = "Magnesium and iron restore red blood cells and soothe uterine contractions.";
        avoid = "Excessive refined sugar and highly salty processed foods that worsen fluid retention.";
      } else if (cycleDay <= 12) {
        energyVibe = "Estrogen Support & Gut Health";
        focus = "Fermented foods (kimchi/kefir), sprouted legumes, wild salmon, avocado & zinc-rich seeds.";
        biohack = "Fiber-rich cruciferous vegetables support healthy estrogen metabolism and clear skin.";
        avoid = "Skipping healthy fats needed for optimal follicle development.";
      } else if (cycleDay <= 16) {
        energyVibe = "Antioxidant & Liver Cleansing";
        focus = "Raw veggies, leafy salads, fresh berries, smoothies & broccoli sprouts.";
        biohack = "Glutathione-boosting foods help liver enzymes clear peak estrogen smoothly.";
        avoid = "Heavy, fried carb-heavy meals that cause midday sluggishness.";
      } else {
        energyVibe = "Metabolic Fuel (+200 kcal need)";
        focus = "Complex carbs: roasted sweet potatoes, squash, quinoa, dark chocolate & sesame seeds.";
        biohack = "Basal metabolic rate jumps 100-300 kcal/day; complex carbs stabilize serotonin & prevent cravings.";
        avoid = "Crash dieting or skipping meals, which spikes stress cortisol.";
      }

      return _buildAIBriefCard(
        energyTag: energyVibe,
        primaryFocus: focus,
        biohack: biohack,
        avoid: avoid,
        accentColor: const Color(0xFF01BEFE),
        icon: Icons.restaurant_rounded,
        pillarTitle: "Nutrition & Skin Brief",
        onQuickAsk: (prompt) => _openAskSiaChat(context, prompt),
        quickPrompt: "Docsy, what should I eat today for Day $cycleDay ($currentPhase) to optimize my energy and hormones?",
      );
    } else if (_selectedStage3LifestyleTab == 'caffeine') {
      String focus;
      String biohack;
      String avoid;
      String energyVibe;

      if (cycleDay <= 14) {
        energyVibe = "Fast Caffeine Clearance";
        focus = "Morning coffee well-tolerated; 2.2 L water with daily minerals/electrolytes.";
        biohack = "Liver CYP1A2 enzyme metabolizes caffeine quickly during follicular & ovulatory stages.";
        avoid = "Drinking coffee on an empty stomach before protein.";
      } else {
        energyVibe = "Slow Caffeine Clearance";
        focus = "Switch to matcha, green tea, or golden milk after 12 PM; 2.5 L water with magnesium.";
        biohack = "Progesterone slows caffeine clearance by ~50%, increasing jitteriness and disrupting deep sleep.";
        avoid = "Afternoon espressos or energy drinks within 8 hours of bedtime.";
      }

      return _buildAIBriefCard(
        energyTag: energyVibe,
        primaryFocus: focus,
        biohack: biohack,
        avoid: avoid,
        accentColor: const Color(0xFFFF7D00),
        icon: Icons.coffee_rounded,
        pillarTitle: "Caffeine & Hydration Brief",
        onQuickAsk: (prompt) => _openAskSiaChat(context, prompt),
        quickPrompt: "Docsy, how should I time my caffeine and hydration for Day $cycleDay?",
      );
    } else if (_selectedStage3LifestyleTab == 'social') {
      String focus;
      String biohack;
      String avoid;
      String energyVibe;

      if (cycleDay <= 5) {
        energyVibe = "Cozy & Intimate Connection";
        focus = "Low-stimulation evenings, cozy tea dates, movie nights & personal journaling.";
        biohack = "Oxytocin from close, trusted relationships soothes nervous system stress.";
        avoid = "Large crowded networking mixers or forced small talk.";
      } else if (cycleDay <= 12) {
        energyVibe = "High Social Energy";
        focus = "Meeting new friends, group dinners, collaborative workshops & lively events.";
        biohack = "Rising estrogen heightens empathy, curiosity, and excitement for novelty.";
        avoid = "Over-isolating at home when social drive is primed.";
      } else if (cycleDay <= 16) {
        energyVibe = "Peak Charisma & Magnetism";
        focus = "Hosting dinner parties, romantic dates & community leadership.";
        biohack = "Peak hormone blend maximizes vocal warmth, micro-expressions, and social confidence.";
        avoid = "Canceling social commitments you were looking forward to.";
      } else {
        energyVibe = "Selective & Deep 1-on-1s";
        focus = "Meaningful deep conversations with close inner circle and quiet restorative evenings.";
        biohack = "Introversion naturally rises as progesterone climbs—protect your boundaries guilt-free.";
        avoid = "People-pleasing and saying yes to events that drain your energy.";
      }

      return _buildAIBriefCard(
        energyTag: energyVibe,
        primaryFocus: focus,
        biohack: biohack,
        avoid: avoid,
        accentColor: const Color(0xFFFF006D),
        icon: Icons.favorite_border_rounded,
        pillarTitle: "Social & Partner Brief",
        onQuickAsk: (prompt) => _openAskSiaChat(context, prompt),
        quickPrompt: "Docsy, how can I communicate my energy and social needs to my partner/friends on Day $cycleDay?",
      );
    } else {
      String focus;
      String biohack;
      String avoid;
      String energyVibe;

      if (cycleDay <= 5) {
        energyVibe = "Deep Rest & Grounding";
        focus = "Warm lemon water + 5 deep belly breaths in bed; evening warm foot soak.";
        biohack = "Heat therapy stimulates parasympathetic tone and relieves uterine muscle tension.";
        avoid = "Rushing out of bed into stressful morning notifications.";
      } else if (cycleDay <= 12) {
        energyVibe = "Circadian Awakening";
        focus = "10 minutes of direct morning sunlight + brisk walking & morning intention setting.";
        biohack = "Morning photons reset cortisol awakening response and maximize daytime alertness.";
        avoid = "Staying in dark rooms during early morning hours.";
      } else if (cycleDay <= 16) {
        energyVibe = "High Vibrance Activation";
        focus = "Invigorating cold face splash + protein green smoothie & energizing stretch.";
        biohack = "Thermal contrast boosts dopamine and complements high baseline estrogen.";
        avoid = "Sedentary stillness during peak energy windows.";
      } else {
        energyVibe = "Calming Wind-Down";
        focus = "Warm spiced oat bowl + 3 mins gratitude; evening magnesium with dim amber lighting.";
        biohack = "Amber lighting prevents melatonin suppression, ensuring deep restorative REM sleep.";
        avoid = "Late-night blue light exposure from phone screens in bed.";
      }

      return _buildAIBriefCard(
        energyTag: energyVibe,
        primaryFocus: focus,
        biohack: biohack,
        avoid: avoid,
        accentColor: const Color(0xFF8F00FF),
        icon: Icons.auto_awesome_rounded,
        pillarTitle: "Daily Micro-Rituals Brief",
        onQuickAsk: (prompt) => _openAskSiaChat(context, prompt),
        quickPrompt: "Docsy, give me 2 simple 1-minute rituals I can do today for Day $cycleDay ($currentPhase).",
      );
    }
  }

  Widget _buildAIBriefCard({
    required String energyTag,
    required String primaryFocus,
    required String biohack,
    required String avoid,
    required Color accentColor,
    required IconData icon,
    required String pillarTitle,
    required void Function(String prompt) onQuickAsk,
    required String quickPrompt,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF9F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0EBE6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar: Pillar Title & Energy State Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 14, color: accentColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pillarTitle,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: BlushyColors.text,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  energyTag,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accentColor == const Color(0xFFFFDD00) ? const Color(0xFFD97706) : accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Structured Insights
          _buildBriefInsightRow(
            emoji: "🎯",
            label: "Primary Focus",
            content: primaryFocus,
            accentColor: accentColor,
          ),
          const SizedBox(height: 10),
          _buildBriefInsightRow(
            emoji: "💡",
            label: "Hormonal Bio-Hack",
            content: biohack,
            accentColor: accentColor,
          ),
          const SizedBox(height: 10),
          _buildBriefInsightRow(
            emoji: "⚠️",
            label: "What to Ease",
            content: avoid,
            accentColor: const Color(0xFFE11D48),
          ),
          const SizedBox(height: 14),

          // Quick AI Ask Chip
          InkWell(
            onTap: () => onQuickAsk(quickPrompt),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5DECE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFFFF006D)),
                  const SizedBox(width: 6),
                  Text(
                    "Quick Ask Docsy",
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFF006D),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFFFF006D)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBriefInsightRow({
    required String emoji,
    required String label,
    required String content,
    required Color accentColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: BlushyColors.text,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    color: BlushyColors.text,
                  ),
                ),
                TextSpan(
                  text: content,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w500,
                    color: BlushyColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildLivingWithMyCycleHomeOS(
    PersonalContext pc,
    BlushyOSState state,
  ) {
    return LivingWithMyCycleDashboard(
      isNested: widget.isNested,
    );
  }

  // --- BRANCH: HORMONAL HEALTH (hormonalHealth) ---
  final ScrollController _hormonalHomeScrollController = ScrollController();

  // --- SECTION 1: DOCSY'S DAILY BRIEF (HERO) ---

  // --- SECTION 2: MY CYCLE HEALTH (Irregular tracking metrics & Ovary shape) ---
  Widget _buildHormonalCycleHealth() {
    return _buildLivingTodayCycle();
  }

  Widget _buildMetricLabel(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 9,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
      ],
    );
  }

  // --- SECTION 3: TODAY'S CHECK-IN (One-tap logging) ---
  Widget _buildHormonalCheckIn() => _buildLogAndCheckIn();

  // --- SECTION 4: DOCSY INSIGHTS (Observations) ---
  /// Condition profile (spec section 14).
  ///
  /// Shows only what the user told Blushy they were diagnosed with, the
  /// reviewed education that matches it, and observations drawn from their own
  /// logs. Nothing here infers a diagnosis, and no estimated hormone levels are
  /// displayed because Blushy ingests no validated lab or device data.
  ///
  /// This previously rendered `dummyConditionInsights`, which is an empty list,
  /// so the card showed nothing at all.
  /// The hormonal branch shows the same real Docsy observation as every other
  /// branch, rather than its own copy.
  Widget _buildHormonalSiaInsights() => _buildLivingSiaInsights();

  Widget _buildConditionProfileCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading(
            AppLocalizations.of(context).dashYourConditions,
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
                borderRadius: BorderRadius.circular(12),
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
                              const Icon(
                                Icons.medical_information_outlined,
                                size: 16,
                                color: BlushyColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  block["condition"]?.toString() ?? "",
                                  style: GoogleFonts.manrope(
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
                                AppLocalizations.of(
                                  context,
                                ).dashNoReviewedArticle,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: BlushyColors.secondaryText,
                                ),
                              ),
                            )
                          else
                            ...content.map((c) {
                              final article = Map<String, dynamic>.from(
                                c as Map,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  left: 24,
                                ),
                                child: GestureDetector(
                                  onTap: () => _showArticleDialog(
                                    context,
                                    article["title"]?.toString() ?? "",
                                    "${article["body"] ?? ""}\n\nSource: ${article["source"] ?? "not stated"}",
                                  ),
                                  child: Text(
                                    article["title"]?.toString() ?? "",
                                    style: GoogleFonts.manrope(
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
                      AppLocalizations.of(context).dashFromLogs,
                      style: GoogleFonts.manrope(
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
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: BlushyColors.text,
                            height: 1.4,
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    data["disclaimer"]?.toString() ??
                        "Blushy does not diagnose conditions or estimate hormone levels.",
                    style: GoogleFonts.manrope(
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
          child: SectionHeading("FOR YOUR NEXT APPOINTMENT"),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.assignment_ind_outlined,
                    color: BlushyColors.primary,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).dashBlushyCanPullTogether,
                style: GoogleFonts.manrope(
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DoctorSummaryScreen(),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).dashBuildMySummary,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).dashRecordWhatReportedWhat,
                style: GoogleFonts.manrope(
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
        "detail":
            "This progressive trend indicates improving ovulatory consistency, possibly due to balanced blood glucose levels.",
      },
      {
        "title": "Pain Pattern",
        "desc": "\"Cramps usually peak during the first two days.\"",
        "detail":
            "Prostaglandin concentration is highest as shedding starts, driving muscular micro-spasms.",
      },
      {
        "title": "Mood Pattern",
        "desc": "\"Stress levels increase before longer cycles.\"",
        "detail":
            "High cortisol can delay or prevent ovulation, extending follicular phase length and delaying your period.",
      },
      {
        "title": "Sleep Pattern",
        "desc": "\"You sleep longer during weeks without pain.\"",
        "detail":
            "Lower pain levels prevent nighttime waking and micro-arousals, keeping deep sleep cycles intact.",
      },
    ];

    final cards = patternCards.map((card) {
      return Container(
        padding: const EdgeInsets.all(BlushySpace.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF7D8DD), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card['title']!.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: BlushyColors.primary,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card['desc']!,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: BlushyColors.text,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card['detail']!,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                color: const Color(0xFF7A6B72),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _openAskSiaChat(
                    context,
                    "Explain this pattern: ${card['title']}",
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    AppLocalizations.of(context).dashAskDocsy,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: BlushyColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    _showArticleDialog(
                      context,
                      card['title']!,
                      "Clinical observation maps: ${card['detail']}",
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    AppLocalizations.of(context).dashWhyMatters,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();

    return AutoCarouselCards(
      categoryEyebrow: "UNDERSTANDING MY PATTERNS",
      cards: cards,
      height: 195.0,
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
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(BlushySpace.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF7D8DD), width: 0.8),
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
                  style: GoogleFonts.manrope(
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
          Icon(
            _careActionIcon(action.category),
            size: 20,
            color: BlushyColors.primary,
          ),
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
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.text,
                        ),
                      ),
                    ),
                    if (action.isHighPriority)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: BlushyColors.taupe,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          AppLocalizations.of(context).dashPriority,
                          style: GoogleFonts.manrope(
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
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: BlushyColors.secondaryText,
                    height: 1.45,
                  ),
                ),
                // Why this was suggested, so no recommendation appears without
                // a stated basis (spec section 10).
                if (action.reason != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    action.reason!,
                    style: GoogleFonts.manrope(
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
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                      ),
                      child: Text(
                        action.cta,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () => _dismissCareAction(action),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                      ),
                      child: Text(
                        AppLocalizations.of(context).dashNotNow,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: BlushyColors.secondaryText,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Clinical suggestions say where they came from.
                    if (action.source == 'clinical_content')
                      Text(
                        AppLocalizations.of(context).dashReviewedGuidance,
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          color: BlushyColors.secondaryText,
                        ),
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

  void _toggleHeatTimer() {
    if (_heatTimerActive) {
      _heatTimer?.cancel();
      setState(() {
        _heatTimerActive = false;
      });
    } else {
      setState(() {
        _heatTimerActive = true;
      });
      _heatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_heatTimerSecondsRemaining > 0) {
          setState(() {
            _heatTimerSecondsRemaining--;
          });
        } else {
          timer.cancel();
          setState(() {
            _heatTimerActive = false;
            _heatTimerSecondsRemaining = 900;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Heat therapy session complete. Remember to drink a glass of warm water!",
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
              backgroundColor: const Color(0xFFFF006D),
            ),
          );
        }
      });
    }
  }

  void _resetHeatTimer() {
    _heatTimer?.cancel();
    setState(() {
      _heatTimerActive = false;
      _heatTimerSecondsRemaining = 900;
    });
  }

  void _initStage4FromPersonalContext(PersonalContext pc) {
    if (_stage4Initialized) return;
    _stage4Initialized = true;

    // Detect diagnosed condition from onboarding
    final conds = pc.medicalConditions.map((c) => c.toLowerCase()).toSet();
    if (conds.contains('pcos') || conds.contains('pcod') || conds.contains('polycystic')) {
      _selectedHormonalCondition = 'pcos';
    } else if (conds.contains('endo') || conds.contains('endometriosis')) {
      _selectedHormonalCondition = 'endo';
    } else if (conds.contains('pmdd')) {
      _selectedHormonalCondition = 'pmdd';
    } else if (conds.contains('thyroid') || conds.contains('hashimoto')) {
      _selectedHormonalCondition = 'thyroid';
    } else if (pc.cyclePattern == CyclePattern.variable) {
      _selectedHormonalCondition = 'irregular';
    }

    // Pre-populate logged symptoms from onboarding selections
    if (pc.userSymptoms.isNotEmpty) {
      _stage4LoggedSymptoms.addAll(pc.userSymptoms);
    }
  }

  /// 1. Personalized Onboarding & Condition Intelligence Card
  Widget _buildHormonalPersonalizedDocsyCard(PersonalContext pc) {
    _initStage4FromPersonalContext(pc);

    final String name = userDisplayName(context);

    final Map<String, Map<String, dynamic>> conditionMeta = {
      'pcos': {
        'title': 'PCOS & Insulin Care Plan',
        'desc': 'Targeting ovarian insulin sensitivity, 40:1 inositol bio-timing & androgen balance.',
        'color': const Color(0xFFFF7D00),
        'bg': const Color(0xFFFFF9F5),
        'border': const Color(0xFFFFEDD5),
        'icon': Icons.spa_rounded,
      },
      'endo': {
        'title': 'Endometriosis Pain Shield',
        'desc': 'Downregulating pelvic prostaglandins, smooth muscle spasms & inflammatory cytokines.',
        'color': const Color(0xFFFF006D),
        'bg': const Color(0xFFFFF7F9),
        'border': const Color(0xFFFFE4E6),
        'icon': Icons.healing_rounded,
      },
      'pmdd': {
        'title': 'PMDD Neuro-Steroid Armor',
        'desc': 'Supporting allopregnanolone GABA sensitivity and luteal serotonin balance.',
        'color': const Color(0xFF8F00FF),
        'bg': const Color(0xFFFAF7FF),
        'border': const Color(0xFFF3E8FF),
        'icon': Icons.shield_moon_rounded,
      },
      'thyroid': {
        'title': 'Thyroid & Cellular Energy',
        'desc': 'Optimizing 5\'-deiodinase T4→T3 conversion with 60-min empty stomach bio-timing.',
        'color': const Color(0xFF01BEFE),
        'bg': const Color(0xFFF0F9FF),
        'border': const Color(0xFFE0F2FE),
        'icon': Icons.bubble_chart_rounded,
      },
      'irregular': {
        'title': 'Cycle Regularity & Ovulation',
        'desc': 'Restoring follicular signaling and HPA-axis cortisol harmony.',
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFEFCE8),
        'border': const Color(0xFFFEF08A),
        'icon': Icons.sync_problem_rounded,
      },
    };

    final meta = conditionMeta[_selectedHormonalCondition] ?? conditionMeta['pcos']!;
    final Color accentColor = meta['color'] as Color;
    final Color bgColor = meta['bg'] as Color;
    final Color borderColor = meta['border'] as Color;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(meta['icon'] as IconData, size: 20, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome, $name ✨",
                      style: GoogleFonts.manrope(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta['title'] as String,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Switch Focus Menu
              PopupMenuButton<String>(
                onSelected: (val) {
                  setState(() {
                    _selectedHormonalCondition = val;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched focus to: ${val.toUpperCase()} protocol'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: accentColor,
                    ),
                  );
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'pcos', child: Text('PCOS / PCOD Protocol')),
                  const PopupMenuItem(value: 'endo', child: Text('Endometriosis Care')),
                  const PopupMenuItem(value: 'pmdd', child: Text('PMDD Neuro Armor')),
                  const PopupMenuItem(value: 'thyroid', child: Text('Thyroid Support')),
                  const PopupMenuItem(value: 'irregular', child: Text('Cycle Regularity')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Switch Focus",
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: BlushyColors.secondaryText,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.unfold_more_rounded, size: 14, color: BlushyColors.secondaryText),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            meta['desc'] as String,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          // Direct Customizer / Settings Trigger Button
          InkWell(
            onTap: () => _showHealthProtocolSettingsModal(context, pc),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    "Customize Protocol & Targets",
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: accentColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive Settings & Protocol Configurator Modal
  void _showHealthProtocolSettingsModal(BuildContext context, PersonalContext pc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String tempCondition = _selectedHormonalCondition;
        double tempWater = _dailyHydrationGoalLiters;
        int tempSleep = _dailySleepGoalHours;
        final Set<String> tempSupplements = Set.from(_loggedSupplements);

        final allAvailableSupplements = [
          {'id': 'myo_dchiro', 'label': 'Myo & D-Chiro Inositol (40:1)', 'time': 'Morning'},
          {'id': 'vit_d3_k2', 'label': 'Vitamin D3 + K2 (MK-7)', 'time': 'Morning'},
          {'id': 'spearmint', 'label': 'Organic Spearmint Infusion', 'time': 'Midday'},
          {'id': 'mag_glycinate', 'label': 'Magnesium Bisglycinate', 'time': 'Night'},
          {'id': 'curcumin_meriva', 'label': 'Curcumin Phytosome (Meriva)', 'time': 'Morning'},
          {'id': 'nac', 'label': 'N-Acetyl Cysteine (NAC 600mg)', 'time': 'Midday'},
          {'id': 'berberine', 'label': 'Berberine Phytosome (500mg)', 'time': 'With Meals'},
          {'id': 'omega3', 'label': 'High-EPA Omega 3 Fish Oil', 'time': 'Morning'},
          {'id': 'vit_b6_p5p', 'label': 'Vitamin B6 (P-5-P active 50mg)', 'time': 'Morning'},
          {'id': 'zinc_glycinate', 'label': 'Zinc Bisglycinate (30mg)', 'time': 'With Food'},
          {'id': 'selenium_methionine', 'label': 'L-Selenomethionine (200mcg)', 'time': 'Morning'},
          {'id': 'levothyroxine', 'label': 'Levothyroxine (Prescribed)', 'time': 'Strict Empty Stomach'},
          {'id': 'ashwagandha', 'label': 'KSM-66 Ashwagandha (300mg)', 'time': 'Night'},
        ];

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Modal Top Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: BlushyColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.tune_rounded, size: 18, color: BlushyColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Protocol & Target Settings",
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: BlushyColors.text,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Modal Scroll Content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Section 1: Active Hormonal Focus
                        Text(
                          "1. PRIMARY DIAGNOSIS & HEALTH FOCUS",
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: BlushyColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            {'id': 'pcos', 'label': 'PCOS / PCOD', 'icon': Icons.spa_rounded},
                            {'id': 'endo', 'label': 'Endometriosis', 'icon': Icons.healing_rounded},
                            {'id': 'pmdd', 'label': 'PMDD', 'icon': Icons.shield_moon_rounded},
                            {'id': 'thyroid', 'label': 'Thyroid / Hashimoto', 'icon': Icons.bubble_chart_rounded},
                            {'id': 'irregular', 'label': 'Irregular Cycles', 'icon': Icons.sync_problem_rounded},
                          ].map((item) {
                            final id = item['id'] as String;
                            final label = item['label'] as String;
                            final icon = item['icon'] as IconData;
                            final isSelected = tempCondition == id;

                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  tempCondition = id;
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? BlushyColors.primary : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? BlushyColors.primary : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 14, color: isSelected ? Colors.white : BlushyColors.secondaryText),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? Colors.white : BlushyColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // Section 2: Active Bio-Timing Supplement Stack
                        Text(
                          "2. DAILY SUPPLEMENT STACK & CHRONO-TIMING",
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: BlushyColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Select the science-backed supplements you take. Docsy will auto-schedule them.",
                          style: GoogleFonts.manrope(fontSize: 11.5, color: BlushyColors.secondaryText),
                        ),
                        const SizedBox(height: 12),
                        ...allAvailableSupplements.map((supp) {
                          final id = supp['id'] as String;
                          final label = supp['label'] as String;
                          final timing = supp['time'] as String;
                          final isChecked = tempSupplements.contains(id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isChecked ? const Color(0xFFFAF5FF) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isChecked ? const Color(0xFFD8B4FE) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isChecked,
                                  activeColor: const Color(0xFF7C3AED),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        tempSupplements.add(id);
                                      } else {
                                        tempSupplements.remove(id);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: BlushyColors.text,
                                        ),
                                      ),
                                      Text(
                                        "Optimal window: $timing",
                                        style: GoogleFonts.manrope(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF7C3AED),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 24),

                        // Section 3: Daily Lifestyle Targets
                        Text(
                          "3. DAILY METABOLIC & LIFESTYLE TARGETS",
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: BlushyColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Daily Hydration Target",
                                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    "${tempWater.toStringAsFixed(1)} L",
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF01BEFE),
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: tempWater,
                                min: 1.5,
                                max: 4.0,
                                divisions: 10,
                                activeColor: const Color(0xFF01BEFE),
                                onChanged: (val) {
                                  setModalState(() {
                                    tempWater = val;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Target Sleep Duration",
                                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    "$tempSleep Hours",
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: tempSleep.toDouble(),
                                min: 6,
                                max: 10,
                                divisions: 4,
                                activeColor: const Color(0xFF7C3AED),
                                onChanged: (val) {
                                  setModalState(() {
                                    tempSleep = val.toInt();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),

                  // Bottom Save Action Bar
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedHormonalCondition = tempCondition;
                            _dailyHydrationGoalLiters = tempWater;
                            _dailySleepGoalHours = tempSleep;
                            _loggedSupplements.clear();
                            _loggedSupplements.addAll(tempSupplements);
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Protocol customized & live Docsy insights updated! ✨',
                                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                              duration: const Duration(seconds: 3),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BlushyColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          "Save & Apply Protocol Real-Time",
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 2. Real-Time Hormonal Signal & Symptom Flow (Airy, Horizontal, Zero Overload)
  Widget _buildHormonalLiveSignalTracker() {
    List<Map<String, dynamic>> symptomList;
    if (_selectedHormonalCondition == 'pcos') {
      symptomList = [
        {'id': 'Facial Hair', 'icon': Icons.face_rounded},
        {'id': 'Hair Shedding', 'icon': Icons.brush_rounded},
        {'id': 'Sugar Cravings', 'icon': Icons.cookie_rounded},
        {'id': 'Cystic Acne', 'icon': Icons.bubble_chart_rounded},
        {'id': 'Bloating', 'icon': Icons.water_drop_outlined},
        {'id': 'Fatigue', 'icon': Icons.battery_alert_rounded},
      ];
    } else if (_selectedHormonalCondition == 'endo') {
      symptomList = [
        {'id': 'Pelvic Cramps', 'icon': Icons.healing_rounded},
        {'id': 'Endo Belly', 'icon': Icons.restaurant_rounded},
        {'id': 'Lower Back Pain', 'icon': Icons.airline_seat_recline_extra_rounded},
        {'id': 'Exhaustion', 'icon': Icons.battery_alert_rounded},
        {'id': 'Nausea', 'icon': Icons.spa_rounded},
      ];
    } else if (_selectedHormonalCondition == 'pmdd') {
      symptomList = [
        {'id': 'Mood Plunge', 'icon': Icons.mood_bad_rounded},
        {'id': 'Irritability', 'icon': Icons.electric_bolt_rounded},
        {'id': 'Anxiety', 'icon': Icons.heart_broken_rounded},
        {'id': 'Brain Fog', 'icon': Icons.cloud_rounded},
        {'id': 'Insomnia', 'icon': Icons.bedtime_rounded},
      ];
    } else if (_selectedHormonalCondition == 'thyroid') {
      symptomList = [
        {'id': 'Cold Hands/Feet', 'icon': Icons.ac_unit_rounded},
        {'id': 'Morning Fatigue', 'icon': Icons.alarm_off_rounded},
        {'id': 'Dry Skin', 'icon': Icons.water_drop_outlined},
        {'id': 'Brain Fog', 'icon': Icons.psychology_rounded},
      ];
    } else {
      symptomList = [
        {'id': 'Delayed Ovulation', 'icon': Icons.hourglass_empty_rounded},
        {'id': 'Spotting', 'icon': Icons.water_drop_rounded},
        {'id': 'Stress Spike', 'icon': Icons.spa_rounded},
        {'id': 'Temperature Dip', 'icon': Icons.thermostat_rounded},
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "TODAY'S HORMONAL SIGNALS",
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: BlushyColors.text,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: _stage4LoggedSymptoms.isNotEmpty ? const Color(0xFFFF006D).withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${_stage4LoggedSymptoms.length} LOGGED",
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _stage4LoggedSymptoms.isNotEmpty ? const Color(0xFFFF006D) : BlushyColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Tap to log active signals in real-time. Docsy synthesizes root-cause guidance instantly.",
          style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 14),

        // Endometriosis Pain Intensity (if Endo is active)
        if (_selectedHormonalCondition == 'endo') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFCCD9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Pelvic Pain Intensity",
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: BlushyColors.text),
                    ),
                    Text(
                      "$_endoPainScale / 10",
                      style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFFFF006D)),
                    ),
                  ],
                ),
                Slider(
                  value: _endoPainScale.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: const Color(0xFFFF006D),
                  inactiveColor: const Color(0xFFFFCCD9),
                  onChanged: (val) {
                    setState(() {
                      _endoPainScale = val.toInt();
                    });
                  },
                ),
              ],
            ),
          ),
        ],

        // Horizontal Pill Scroll
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: symptomList.map((sym) {
              final id = sym['id'] as String;
              final icon = sym['icon'] as IconData;
              final isSelected = _stage4LoggedSymptoms.contains(id);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _stage4LoggedSymptoms.remove(id);
                        if (_lastTappedSymptom == id) {
                          _lastTappedSymptom = null;
                        }
                      } else {
                        _stage4LoggedSymptoms.add(id);
                        _lastTappedSymptom = id;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF006D) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFF006D) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF006D).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: isSelected ? Colors.white : BlushyColors.secondaryText),
                        const SizedBox(width: 6),
                        Text(
                          id,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : BlushyColors.text,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Real-Time Symptom Interventional Tip Card
        if (_lastTappedSymptom != null) ...[
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFEDD5), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEA580C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lightbulb_rounded, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Docsy Root-Cause Micro-Action",
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF9A3412),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getDocsySymptomTip(_lastTappedSymptom!),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7C2D12),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9A3412)),
                  onPressed: () {
                    setState(() {
                      _lastTappedSymptom = null;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Real-Time Root-Cause Interventions for Logged Symptoms
  String _getDocsySymptomTip(String symptom) {
    switch (symptom) {
      case 'Sugar Cravings':
        return 'Insulin spike blunter: Drink 250ml water with 1 tsp apple cider vinegar or eat 20g protein/fiber before high GI foods.';
      case 'Pelvic Cramps':
        return 'Prostaglandin downregulation: Start a 15-min pelvic heat timer and take Magnesium Bisglycinate (300mg) to calm uterine muscle contractions.';
      case 'Facial Hair':
        return 'Anti-androgen bio-timing: Organic Spearmint infusion twice daily inhibits 5α-reductase conversion of testosterone into DHT.';
      case 'Hair Shedding':
        return 'Follicle nourishment: DHT sensitivity detected. Ensure ferritin >50 ng/mL, zinc, and gentle scalp microcirculation.';
      case 'Cystic Acne':
        return 'Sebum & IGF-1 reduction: Limit dairy and ultra-processed sugars. Zinc bisglycinate helps modulate cutaneous inflammatory cascades.';
      case 'Bloating':
      case 'Endo Belly':
        return 'Gut-estrogen axis: Estrobolome dysbiosis flagged. Sip warm spearmint-ginger infusion and increase soluble prebiotic fiber.';
      case 'Mood Plunge':
      case 'Irritability':
      case 'Anxiety':
        return 'Neuro-steroid GABA support: 50mg active Vitamin B6 (P-5-P) + 300mg Magnesium supports serotonin and allopregnanolone synthesis.';
      case 'Cold Hands/Feet':
      case 'Morning Fatigue':
        return 'Cellular deiodinase activation: Ensure thyroid medication was taken 60 min before food/coffee and keep adequate selenium intake.';
      default:
        return 'Biomarker recorded. Docsy has dynamically adjusted today\'s chrono-nutrition and bio-timing schedule.';
    }
  }

  /// Real-Time Stage 4 Living Docsy Insight & Synthesis Card
  Widget _buildHormonalDocsyLiveReactionCard(PersonalContext pc) {
    final String name = userDisplayName(context);

    final Map<String, List<Map<String, dynamic>>> protocols = {
      'pcos': [
        {'id': 'myo_dchiro', 'name': 'Myo & D-Chiro Inositol (40:1)'},
        {'id': 'vit_d3_k2', 'name': 'Vitamin D3 + K2 (MK-7)'},
        {'id': 'spearmint', 'name': 'Organic Spearmint Infusion'},
        {'id': 'mag_glycinate', 'name': 'Magnesium Bisglycinate'},
      ],
      'endo': [
        {'id': 'curcumin_meriva', 'name': 'Curcumin Phytosome (Meriva)'},
        {'id': 'mag_glycinate', 'name': 'Magnesium Bisglycinate'},
      ],
      'pmdd': [
        {'id': 'vit_b6_p5p', 'name': 'Vitamin B6 (P-5-P active)'},
      ],
      'thyroid': [
        {'id': 'levothyroxine', 'name': 'Levothyroxine'},
        {'id': 'selenium_methionine', 'name': 'Selenium (L-Selenomethionine)'},
      ],
      'irregular': [
        {'id': 'myo_dchiro', 'name': 'Myo-Inositol'},
      ],
    };

    final defaultSupps = protocols[_selectedHormonalCondition] ?? protocols['pcos']!;
    final totalSupps = defaultSupps.length + _customUserSupplementsList.length;
    final int loggedSupps = _loggedSupplements.length;
    final double adherencePct = (totalSupps > 0) ? (loggedSupps / totalSupps).clamp(0.0, 1.0) : 0.0;

    // Relational, Empathetic Synthesis
    String dynamicSynthesisText;
    Color statusColor;
    IconData statusIcon;

    if (_stage4LoggedSymptoms.contains('Sugar Cravings')) {
      dynamicSynthesisText = 'I noticed you\'re feeling sugar cravings today. Let\'s buffer your insulin response — having a protein or fiber snack before your meal will gently steady your blood sugar and curb the crash.';
      statusColor = BlushyColors.accent;
      statusIcon = Icons.cookie_rounded;
    } else if (_stage4LoggedSymptoms.contains('Pelvic Cramps')) {
      dynamicSynthesisText = 'I\'m keeping close watch on your pelvic discomfort ($_endoPainScale/10). Prostaglandins can trigger smooth muscle contractions — a warm heat wrap and magnesium will bring soothing relief.';
      statusColor = BlushyColors.primary;
      statusIcon = Icons.healing_rounded;
    } else if (_stage4LoggedSymptoms.contains('Mood Plunge') || _stage4LoggedSymptoms.contains('Irritability')) {
      dynamicSynthesisText = 'Your neuro-steroid and GABA pathways are shifting today. Be extra gentle with yourself — active Vitamin B6 and magnesium support your natural serotonin balance.';
      statusColor = BlushyColors.accent;
      statusIcon = Icons.mood_bad_rounded;
    } else if (_stage4LoggedSymptoms.contains('Cold Hands/Feet') || _stage4LoggedSymptoms.contains('Morning Fatigue')) {
      dynamicSynthesisText = 'Your cellular metabolism is running a little low today. Remember to keep warm and take any thyroid support on a completely empty stomach with plenty of water.';
      statusColor = BlushyColors.primary;
      statusIcon = Icons.ac_unit_rounded;
    } else if (_stage4LoggedSymptoms.isNotEmpty) {
      dynamicSynthesisText = 'I\'ve noted your active signals: ${_stage4LoggedSymptoms.join(', ')}. Your daily nutrition and routine timings have adjusted to keep your hormones supported.';
      statusColor = BlushyColors.accent;
      statusIcon = Icons.spa_rounded;
    } else if (loggedSupps > 0) {
      dynamicSynthesisText = 'Wonderful care for your body today! You\'ve taken $loggedSupps of $totalSupps in your daily routine, keeping your hormonal signals steady and balanced.';
      statusColor = const Color(0xFF16A34A);
      statusIcon = Icons.check_circle_rounded;
    } else {
      dynamicSynthesisText = 'Hi $name, I\'m tuned to your cycle rhythm today. As you check off your daily routine or note down any signals above, I\'ll share personalized connections between your symptoms, nutrition, and energy.';
      statusColor = BlushyColors.primary;
      statusIcon = Icons.favorite_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Soft Warm Indicator (Non-overflowing layout)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BlushyColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded, size: 16, color: BlushyColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "DOCSY'S OBSERVATIONS",
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: BlushyColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BlushyColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BlushyColors.accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: BlushyColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Cycle Tuned",
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: BlushyColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dynamic Empathy Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dynamicSynthesisText,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: BlushyColors.text,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Real-Time Metrics Row (Supplements Progress & Glucose Buffer Status with Ample Spacing)
          Row(
            children: [
              // Routine Adherence Progress
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "Routine Taken",
                              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: BlushyColors.secondaryText),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${(adherencePct * 100).toInt()}%",
                            style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800, color: BlushyColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: adherencePct,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(BlushyColors.primary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$loggedSupps of $totalSupps taken",
                        style: GoogleFonts.manrope(fontSize: 10, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Glucose Buffer Shield Status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "Plate Balance",
                              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: BlushyColors.secondaryText),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${_glucosePlateItems.length * 30}%",
                            style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800, color: BlushyColors.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_glucosePlateItems.length * 0.33).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(BlushyColors.accent),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${_glucosePlateItems.length} food elements added",
                        style: GoogleFonts.manrope(fontSize: 10, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Warm Chat Trigger
          InkWell(
            onTap: () {
              _openAskSiaChat(
                context,
                "Docsy, what connections do you see in my symptoms and daily routine today for ${_selectedHormonalCondition.toUpperCase()}?",
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: BlushyColors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BlushyColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: BlushyColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Discuss today's observations with Docsy",
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: BlushyColors.primary,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: BlushyColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Focused Daily Action Modules (Airy 3-Pill Toggle + Optional SOS sheet)
  Widget _buildHormonalActionModules() {
    final modules = [
      {'index': 0, 'label': '🥗 Glucose Buffer'},
      {'index': 1, 'label': '💊 Bio-Timing Stack'},
      {'index': 2, 'label': '📊 Doctor Dossier'},
    ];

    Widget activeCard;
    if (_selectedHormonalTab == 0) {
      activeCard = _buildPCOSGlucoseBufferCard();
    } else if (_selectedHormonalTab == 1) {
      activeCard = _buildHormonalChronoSupplementCard();
    } else {
      activeCard = Column(
        children: [
          _buildHormonalLabTrackerCard(),
          const SizedBox(height: 16),
          _buildOBGYNClinicalExportCard(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clean 3-Pill Selector (Bold Red Accent Active State)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: modules.map((mod) {
              final idx = mod['index'] as int;
              final label = mod['label'] as String;
              final isSelected = _selectedHormonalTab == idx;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedHormonalTab = idx;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? BlushyColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: BlushyColors.primary.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : BlushyColors.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Active Action Module
        activeCard,
        const SizedBox(height: 16),

        // Emergency SOS Care Action Button (ONLY displayed when flare-up or severe pain is active/logged)
        if (_heatTimerActive ||
            _endoPainScale >= 6 ||
            _stage4LoggedSymptoms.contains('Pelvic Cramps') ||
            _stage4LoggedSymptoms.contains('Severe Pain')) ...[
          InkWell(
            onTap: () {
              _showSOSCareModal(context);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFCCD9)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF006D),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Acute Flare-Up SOS Care",
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF990041),
                          ),
                        ),
                        Text(
                          "1-Tap Pelvic Heat Timer & 4-7-8 Breathing protocol",
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            color: const Color(0xFFBE123C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFFF006D)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  /// 4. SOS Emergency Modal Sheet
  void _showSOSCareModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final int minutes = _heatTimerSecondsRemaining ~/ 60;
          final int seconds = _heatTimerSecondsRemaining % 60;
          final timeStr = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF006D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Acute Flare-Up SOS Care",
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: BlushyColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Heat Timer
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFCCD9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 22, color: Color(0xFFFF7D00)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "15-Min Pelvic Heat Therapy",
                              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: BlushyColors.text),
                            ),
                            Text(
                              _heatTimerActive ? "Active: $timeStr" : "Target: Lower abdomen & sacrum",
                              style: GoogleFonts.manrope(fontSize: 11, color: _heatTimerActive ? const Color(0xFFFF006D) : BlushyColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _toggleHeatTimer();
                          setModalState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF006D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(_heatTimerActive ? "Pause" : "Start"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Breathing exercise
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showArticleDialog(
                      context,
                      "Vagus Nerve 4-7-8 Reset",
                      "1. Inhale quietly through your nose for 4 seconds.\n2. Hold your breath gently for 7 seconds.\n3. Exhale completely through your mouth for 8 seconds.\n\nRepeat 4 times to downregulate pelvic nerves.",
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE0F2FE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.air_rounded, size: 18, color: Color(0xFF01BEFE)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Start 4-7-8 Vagus Nerve Breathing",
                            style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: BlushyColors.text),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF01BEFE)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 5. Hormonal Nutrition & Metabolic Meal Balance
  Widget _buildPCOSGlucoseBufferCard() {
    final Map<String, List<String>> macroOptions = {
      '🥩 Protein (25-30g)': ['Wild Salmon', 'Organic Eggs', 'Greek Yogurt', 'Tempeh', 'Grilled Chicken', 'Tofu'],
      '🥑 Healthy Fats (15g)': ['Avocado', 'Extra Virgin Olive Oil', 'Walnuts', 'Chia Seeds', 'Pumpkin Seeds'],
      '🥦 Fiber & Greens (10g+)': ['Steamed Broccoli', 'Baby Spinach', 'Asparagus', 'Zucchini', 'Chia Pudding'],
      '🍠 Complex Carbs (Low GI)': ['Quinoa', 'Sweet Potato', 'Lentils', 'Wild Berries', 'Steel-Cut Oats'],
    };

    final bool hasProtein = _glucosePlateItems.any((i) => i.contains('Protein'));
    final bool hasFat = _glucosePlateItems.any((i) => i.contains('Fats'));
    final bool hasFiber = _glucosePlateItems.any((i) => i.contains('Fiber'));
    final bool hasCarbs = _glucosePlateItems.any((i) => i.contains('Carbs'));
    final bool isBufferOptimal = hasProtein && hasFat && hasFiber;
    final int selectedCount = _glucosePlateItems.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant_menu_rounded, size: 16, color: Color(0xFFFF4D6D)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Metabolic Meal Balance",
                      style: GoogleFonts.manrope(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: BlushyColors.text,
                      ),
                    ),
                    Text(
                      "Pair protein & healthy fats with carbs to prevent insulin surges",
                      style: GoogleFonts.manrope(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
              if (selectedCount > 0)
                InkWell(
                  onTap: () {
                    setState(() {
                      _glucosePlateItems.clear();
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Reset",
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF4D6D),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Real-time Spike Score Indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isBufferOptimal
                  ? const Color(0xFFECFDF5)
                  : (selectedCount > 0 ? const Color(0xFFFFF7ED) : const Color(0xFFFFF0F5)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isBufferOptimal
                    ? const Color(0xFFA7F3D0)
                    : (selectedCount > 0 ? const Color(0xFFFFEDD5) : const Color(0xFFFFCCD9)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isBufferOptimal
                      ? Icons.verified_rounded
                      : (selectedCount > 0 ? Icons.info_outline_rounded : Icons.tips_and_updates_rounded),
                  size: 18,
                  color: isBufferOptimal
                      ? const Color(0xFF059669)
                      : (selectedCount > 0 ? const Color(0xFFEA580C) : const Color(0xFFFF4D6D)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isBufferOptimal
                        ? "✨ Optimal Buffer: Protein, healthy fats & fiber are active — post-meal glucose spike buffered by ~72%."
                        : (selectedCount > 0
                            ? "💡 Tip: Add ${hasProtein ? '' : 'Protein, '}${hasFat ? '' : 'Fats, '}${hasFiber ? '' : 'Fiber'} to steady your blood sugar."
                            : "Tap foods from your current meal below to check your hormonal glucose buffer score."),
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isBufferOptimal
                          ? const Color(0xFF065F46)
                          : (selectedCount > 0 ? const Color(0xFF9A3412) : const Color(0xFF990041)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Interactive Macro Food Chips
          ...macroOptions.entries.map((entry) {
            final category = entry.key;
            final items = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: items.map((item) {
                      final fullName = "$category: $item";
                      final isSelected = _glucosePlateItems.contains(fullName);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _glucosePlateItems.remove(fullName);
                            } else {
                              _glucosePlateItems.add(fullName);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFF4D6D) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFF4D6D) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                item,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.white : BlushyColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),

          // Ask Docsy for recipe
          InkWell(
            onTap: () {
              final foods = _glucosePlateItems.isNotEmpty
                  ? _glucosePlateItems.map((e) => e.split(': ').last).join(', ')
                  : 'healthy whole foods';
              _openAskSiaChat(
                context,
                "Docsy, can you generate an easy, delicious meal recipe tailored for ${_selectedHormonalCondition.toUpperCase()} using $foods?",
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFCCD9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, size: 14, color: Color(0xFFFF4D6D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _glucosePlateItems.isNotEmpty
                          ? "Ask Docsy for a recipe using your chosen foods"
                          : "Ask Docsy for a Glucose-Steady Recipe",
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFF4D6D),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFFFF4D6D)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 7. Chrono-Nutrition & Supplement Tracker (Empty by Default + 1-Tap Recommendations + Custom Add)
  Widget _buildHormonalChronoSupplementCard() {
    final Map<String, List<Map<String, dynamic>>> conditionSuggestions = {
      'pcos': [
        {'name': 'Myo & D-Chiro Inositol (40:1)', 'dose': '2000mg', 'time': 'Morning (With Food)', 'purpose': 'Restores ovarian insulin sensitivity'},
        {'name': 'Vitamin D3 + K2 (MK-7)', 'dose': '2000 IU', 'time': 'Morning (With Food)', 'purpose': 'Follicular maturation & androgen balance'},
        {'name': 'Organic Spearmint Infusion', 'dose': '1 cup (warm)', 'time': 'Midday / Afternoon', 'purpose': '5α-reductase anti-androgen for hirsutism'},
        {'name': 'Magnesium Bisglycinate', 'dose': '300mg', 'time': 'Night (Before Sleep)', 'purpose': 'Cortisol dampening & sleep architecture'},
      ],
      'endo': [
        {'name': 'Curcumin Phytosome (Meriva)', 'dose': '500mg', 'time': 'Morning (With Food)', 'purpose': 'Downregulates pelvic prostaglandins & inflammation'},
        {'name': 'Magnesium Bisglycinate', 'dose': '350mg', 'time': 'Night (Before Sleep)', 'purpose': 'Relaxes pelvic floor hypertonicity'},
        {'name': 'Omega-3 Fish Oil', 'dose': '1000mg', 'time': 'Midday / Afternoon', 'purpose': 'Resolves inflammatory pelvic cytokines'},
        {'name': 'NAC (N-Acetyl Cysteine)', 'dose': '600mg', 'time': 'Morning (With Food)', 'purpose': 'Supports endometrial cell apoptosis'},
      ],
      'pmdd': [
        {'name': 'Vitamin B6 (P-5-P active)', 'dose': '50mg', 'time': 'Morning (With Food)', 'purpose': 'Cofactor for serotonin & GABA neuro-synthesis'},
        {'name': 'Magnesium Bisglycinate', 'dose': '300mg', 'time': 'Night (Before Sleep)', 'purpose': 'Eases luteal mood plunge & cramps'},
        {'name': 'Ashwagandha (KSM-66)', 'dose': '300mg', 'time': 'Night (Before Sleep)', 'purpose': 'Dampens luteal HPA-axis stress response'},
        {'name': 'L-Theanine', 'dose': '200mg', 'time': 'Midday / Afternoon', 'purpose': 'Alpha brain wave calming'},
      ],
      'thyroid': [
        {'name': 'Levothyroxine', 'dose': 'Prescribed dose', 'time': 'Early Morning (Strict Empty Stomach)', 'purpose': 'Take 60 min before coffee or food for absorption'},
        {'name': 'Selenium (L-Selenomethionine)', 'dose': '200mcg', 'time': 'Midday / Afternoon', 'purpose': 'Accelerates T4 to active T3 conversion'},
        {'name': 'Zinc Picolinate', 'dose': '30mg', 'time': 'Midday / Afternoon', 'purpose': 'Thyroid receptor signaling cofactor'},
        {'name': 'Vitamin D3', 'dose': '2000 IU', 'time': 'Morning (With Food)', 'purpose': 'Immune modulation for thyroid tissue'},
      ],
      'irregular': [
        {'name': 'Myo-Inositol', 'dose': '2000mg', 'time': 'Morning (With Food)', 'purpose': 'Signals healthy follicle growth and cycle regularity'},
        {'name': 'Chasteberry (Vitex)', 'dose': '400mg', 'time': 'Morning (With Food)', 'purpose': 'Balances LH to FSH pulse frequency'},
        {'name': 'Folate (L-Methylfolate)', 'dose': '400mcg', 'time': 'Morning (With Food)', 'purpose': 'Cellular division and ovulation support'},
      ],
    };

    final suggestions = conditionSuggestions[_selectedHormonalCondition] ?? conditionSuggestions['pcos']!;

    // Group user supplements by timing
    final Map<String, List<Map<String, dynamic>>> groupedSupplements = {};
    for (final supp in _customUserSupplementsList) {
      final timing = (supp['timing'] ?? supp['time'] ?? 'Morning (With Food)').toString();
      groupedSupplements.putIfAbsent(timing, () => []).add(supp);
    }

    final totalCount = _customUserSupplementsList.length;
    final loggedCount = _loggedSupplements.length;

    // Timing display metadata
    final Map<String, Map<String, dynamic>> timingMeta = {
      'Early Morning (Strict Empty Stomach)': {'icon': Icons.alarm_rounded, 'color': const Color(0xFFDC2626)},
      'Morning (With Food)': {'icon': Icons.wb_sunny_rounded, 'color': const Color(0xFFEA580C)},
      'Midday / Afternoon': {'icon': Icons.wb_twilight_rounded, 'color': const Color(0xFFD97706)},
      'Night (Before Sleep)': {'icon': Icons.nightlight_round, 'color': const Color(0xFFFF4D6D)},
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4D6D),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medication_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Chrono-Nutrition & Supplements",
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: BlushyColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Synchronized Bio-Timing",
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF4D6D),
                      ),
                    ),
                  ],
                ),
              ),
              if (_customUserSupplementsList.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "$loggedCount / $totalCount Taken",
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFF4D6D),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _showAddCustomSupplementModal(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D6D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          "Add",
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // EMPTY STATE: If no supplements added yet
          if (_customUserSupplementsList.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFCCD9)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medication_liquid_rounded, size: 28, color: Color(0xFFFF4D6D)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "No Supplements Added Yet",
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Personalize your routine or tap quick recommendations tailored to your ${_selectedHormonalCondition.toUpperCase()} journey.",
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: BlushyColors.secondaryText,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),

                  // Quick 1-tap addition chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: suggestions.map((s) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _customUserSupplementsList.add({
                              'id': 'supp_${DateTime.now().microsecondsSinceEpoch}',
                              'name': s['name'],
                              'dose': s['dose'],
                              'timing': s['time'],
                              'purpose': s['purpose'],
                              'isCustom': true,
                            });
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("${s['name']} added to your daily stack! ✨", style: GoogleFonts.manrope()),
                              backgroundColor: const Color(0xFFFF4D6D),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFCCD9)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, size: 12, color: Color(0xFFFF4D6D)),
                              const SizedBox(width: 3),
                              Text(
                                s['name'] as String,
                                style: GoogleFonts.manrope(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFF4D6D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Single Add Button
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () => _showAddCustomSupplementModal(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D6D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        "+ Add Supplement / Medication",
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // FILLED STATE: Render groups
            ...groupedSupplements.entries.map((group) {
              final timeTitle = group.key;
              final items = group.value;
              final meta = timingMeta[timeTitle] ?? {'icon': Icons.wb_sunny_rounded, 'color': const Color(0xFFFF4D6D)};
              final icon = meta['icon'] as IconData;
              final color = meta['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 14, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              timeTitle,
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...items.map((item) {
                        final id = (item['id'] ?? item['name']).toString();
                        final name = (item['name'] ?? '').toString();
                        final dose = (item['dose'] ?? '').toString();
                        final purpose = (item['purpose'] ?? '').toString();
                        final isTaken = _loggedSupplements.contains(id);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isTaken) {
                                _loggedSupplements.remove(id);
                              } else {
                                _loggedSupplements.add(id);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    color: isTaken ? const Color(0xFF16A34A) : Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: isTaken ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                                      width: 1.3,
                                    ),
                                  ),
                                  child: isTaken
                                      ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                decoration: isTaken ? TextDecoration.lineThrough : null,
                                                color: isTaken ? const Color(0xFF94A3B8) : BlushyColors.text,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            dose,
                                            style: GoogleFonts.manrope(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                _customUserSupplementsList.removeWhere((s) => s['id'] == id);
                                                _loggedSupplements.remove(id);
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(4),
                                            child: const Padding(
                                              padding: EdgeInsets.all(2),
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 13,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        purpose,
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
          const SizedBox(height: 10),

          // Discuss with Docsy banner
          InkWell(
            onTap: () {
              final suppNames = _customUserSupplementsList.isNotEmpty
                  ? _customUserSupplementsList.map((e) => e['name']).join(', ')
                  : 'my daily routine';
              _openAskSiaChat(
                context,
                "Docsy, can you review my supplement routine ($suppNames) for ${_selectedHormonalCondition.toUpperCase()} and check for absorption timing conflicts?",
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFCCD9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFFF4D6D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Discuss your routine & bio-timing with Docsy",
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFF4D6D),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFFFF4D6D)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Add Custom Supplement / Medication Modal (Blushy Theme)
  void _showAddCustomSupplementModal(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController doseController = TextEditingController();
    final TextEditingController purposeController = TextEditingController();
    String selectedTiming = 'Morning (With Food)';

    final quickSuggestions = [
      {'name': 'Myo-Inositol', 'dose': '2000mg', 'time': 'Morning (With Food)', 'purpose': 'Ovarian insulin receptor sensitivity'},
      {'name': 'Vitamin D3 + K2', 'dose': '2000 IU', 'time': 'Morning (With Food)', 'purpose': 'Follicular maturation & androgen control'},
      {'name': 'Spearmint Infusion', 'dose': '1 cup', 'time': 'Midday / Afternoon', 'purpose': '5α-reductase reduction for hirsutism'},
      {'name': 'Magnesium Bisglycinate', 'dose': '300mg', 'time': 'Night (Before Sleep)', 'purpose': 'Cortisol calming & sleep architecture'},
      {'name': 'Berberine', 'dose': '500mg', 'time': 'Morning (With Food)', 'purpose': 'AMPK activator for glucose uptake'},
      {'name': 'Ashwagandha (KSM-66)', 'dose': '300mg', 'time': 'Night (Before Sleep)', 'purpose': 'HPA axis & stress reduction'},
      {'name': 'CoQ10 (Ubiquinol)', 'dose': '200mg', 'time': 'Morning (With Food)', 'purpose': 'Mitochondrial egg quality & energy'},
      {'name': 'NAC', 'dose': '600mg', 'time': 'Morning (With Food)', 'purpose': 'Glutathione precursor for detox'},
      {'name': 'Omega-3 Fish Oil', 'dose': '1000mg', 'time': 'Midday / Afternoon', 'purpose': 'Anti-inflammatory prostaglandin support'},
      {'name': 'Zinc Picolinate', 'dose': '30mg', 'time': 'Midday / Afternoon', 'purpose': 'Androgen regulation & skin health'},
      {'name': 'Metformin', 'dose': '500mg', 'time': 'Morning (With Food)', 'purpose': 'Prescribed insulin sensitizer'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF0F5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.medication_liquid_rounded, size: 18, color: Color(0xFFFF4D6D)),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Add Supplement / Medication",
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: BlushyColors.text,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          "Quick Suggestions",
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: quickSuggestions.map((s) {
                            return ActionChip(
                              label: Text(
                                s['name']!,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFF4D6D),
                                ),
                              ),
                              backgroundColor: const Color(0xFFFFF5F7),
                              side: const BorderSide(color: Color(0xFFFFCCD9)),
                              onPressed: () {
                                setModalState(() {
                                  nameController.text = s['name']!;
                                  doseController.text = s['dose']!;
                                  purposeController.text = s['purpose']!;
                                  selectedTiming = s['time']!;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),

                        // Form
                        Text(
                          "Supplement / Medication Name",
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: "e.g. Berberine HCL",
                            hintStyle: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFFF4D6D), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          "Dosage / Quantity",
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: doseController,
                          decoration: InputDecoration(
                            hintText: "e.g. 500mg, 1 capsule, 2000 IU",
                            hintStyle: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFFF4D6D), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          "Bio-Timing Routine",
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Column(
                          children: [
                            'Early Morning (Strict Empty Stomach)',
                            'Morning (With Food)',
                            'Midday / Afternoon',
                            'Night (Before Sleep)',
                          ].map((timingOption) {
                            final isSelected = selectedTiming == timingOption;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: () {
                                  setModalState(() {
                                    selectedTiming = timingOption;
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFFFF0F5) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFFF4D6D) : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                        size: 16,
                                        color: isSelected ? const Color(0xFFFF4D6D) : const Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          timingOption,
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? const Color(0xFFFF4D6D) : BlushyColors.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          "Health Target / Benefit / Note (Optional)",
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: purposeController,
                          decoration: InputDecoration(
                            hintText: "e.g. Glucose balance, peaceful sleep, follicle support",
                            hintStyle: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFFF4D6D), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // Save Action
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Please enter a supplement or medication name", style: GoogleFonts.manrope()),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }

                          final dose = doseController.text.trim().isEmpty ? '1 serving' : doseController.text.trim();
                          final purpose = purposeController.text.trim().isEmpty ? 'Personalized routine support' : purposeController.text.trim();

                          final newSupp = {
                            'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                            'name': name,
                            'dose': dose,
                            'timing': selectedTiming,
                            'purpose': purpose,
                            'isCustom': true,
                          };

                          setState(() {
                            _customUserSupplementsList.add(newSupp);
                          });

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$name added to your $selectedTiming stack! ✨',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                              ),
                              backgroundColor: const Color(0xFFFF4D6D),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D6D),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          "Save to My Protocol",
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 8. Functional Lab Biomarker Translator (Interactive & Real-Time)
  Widget _buildHormonalLabTrackerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: BlushyColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.biotech_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Functional Lab Biomarkers",
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: BlushyColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Docsy Biomarker Translator",
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_userLoggedLabResults.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 20, color: BlushyColors.primary),
                  tooltip: "Edit Bloodwork",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showLogBloodTestModal(context),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_userLoggedLabResults.isEmpty) ...[
            // Empty State: No Mock Data Pretending to be User Data
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.science_outlined, size: 32, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  Text(
                    "No Blood Test Results Logged Yet",
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Enter your actual blood test values (e.g. Fasting Insulin, TSH, LH, FSH, Testosterone) to get Docsy's functional root-cause analysis.",
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: BlushyColors.secondaryText,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showLogBloodTestModal(context),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            "Enter Lab Results",
                            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BlushyColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          _openAskSiaChat(
                            context,
                            "Docsy, I have a lab report PDF or photo. Can you help me interpret my blood test results?",
                          );
                        },
                        icon: const Icon(Icons.upload_file_rounded, size: 16, color: BlushyColors.primary),
                        label: Text(
                          "Upload PDF",
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BlushyColors.primary,
                          side: const BorderSide(color: BlushyColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // User's Real Entered Lab Cards
            ..._userLoggedLabResults.map((panel) {
              final name = panel['name'] as String;
              final value = panel['value'] as String;
              final optimal = panel['optimal'] as String;
              final status = panel['status'] as String;
              final statusColor = panel['statusColor'] as Color;
              final bgColor = panel['bgColor'] as Color;
              final interpretation = panel['interpretation'] as String;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: BlushyColors.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Your Value: $value • $optimal",
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        interpretation,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          color: const Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _showLogBloodTestModal(context),
                  icon: const Icon(Icons.add_rounded, size: 15, color: BlushyColors.primary),
                  label: Text(
                    "Add / Edit Tests",
                    style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: BlushyColors.primary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _userLoggedLabResults.clear();
                    });
                  },
                  child: Text(
                    "Clear Results",
                    style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Interactive Modal for User to Enter Real Blood Test Results
  void _showLogBloodTestModal(BuildContext context) {
    final TextEditingController insulinController = TextEditingController();
    final TextEditingController tshController = TextEditingController();
    final TextEditingController lhController = TextEditingController();
    final TextEditingController fshController = TextEditingController();
    final TextEditingController testController = TextEditingController();
    final TextEditingController vitDController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: BlushyColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.biotech_rounded, size: 18, color: BlushyColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Enter Blood Test Results",
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: BlushyColors.text,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Inputs list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      "Enter any values from your lab report. Docsy will translate them into functional insights in real time.",
                      style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    _buildLabInputField(
                      controller: insulinController,
                      label: "Fasting Insulin (μIU/mL)",
                      hint: "e.g. 5.2",
                      optimalInfo: "Functional Optimal: < 5.0 μIU/mL (Standard Lab: < 25)",
                    ),
                    const SizedBox(height: 14),

                    _buildLabInputField(
                      controller: tshController,
                      label: "TSH - Thyroid Stimulating Hormone (μIU/mL)",
                      hint: "e.g. 1.8",
                      optimalInfo: "Functional Optimal: 1.0 - 2.5 μIU/mL",
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: _buildLabInputField(
                            controller: lhController,
                            label: "LH (mIU/mL)",
                            hint: "e.g. 6.4",
                            optimalInfo: "Day 3 of cycle",
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildLabInputField(
                            controller: fshController,
                            label: "FSH (mIU/mL)",
                            hint: "e.g. 5.8",
                            optimalInfo: "Optimal Ratio 1:1",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildLabInputField(
                      controller: testController,
                      label: "Free Testosterone (pg/mL)",
                      hint: "e.g. 1.8",
                      optimalInfo: "Functional Optimal: 0.8 - 2.2 pg/mL",
                    ),
                    const SizedBox(height: 14),

                    _buildLabInputField(
                      controller: vitDController,
                      label: "Vitamin D3 (25-OH) (ng/mL)",
                      hint: "e.g. 45",
                      optimalInfo: "Functional Optimal: 40 - 70 ng/mL",
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Save Action Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final newLabs = <Map<String, dynamic>>[];

                      // Fasting Insulin interpretation
                      final insulinVal = double.tryParse(insulinController.text.trim());
                      if (insulinVal != null) {
                        final bool isHigh = insulinVal > 8.0;
                        final bool isBorderline = insulinVal >= 5.0 && insulinVal <= 8.0;
                        newLabs.add({
                          'name': 'Fasting Insulin',
                          'value': '$insulinVal μIU/mL',
                          'optimal': 'Optimal Functional: < 5.0 μIU/mL',
                          'status': isHigh ? 'Insulin Resistance' : (isBorderline ? 'Sub-Optimal' : 'Optimal'),
                          'statusColor': isHigh ? const Color(0xFFEA580C) : (isBorderline ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                          'bgColor': isHigh ? const Color(0xFFFFF7ED) : (isBorderline ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
                          'interpretation': isHigh
                              ? 'Elevated insulin drives theca cell androgen production. Pair all carbs with protein & inositol.'
                              : 'Cellular insulin sensitivity is well-regulated.',
                        });
                      }

                      // TSH interpretation
                      final tshVal = double.tryParse(tshController.text.trim());
                      if (tshVal != null) {
                        final bool isElevated = tshVal > 2.5;
                        final bool isLow = tshVal < 0.5;
                        newLabs.add({
                          'name': 'TSH (Thyroid)',
                          'value': '$tshVal μIU/mL',
                          'optimal': 'Functional: 1.0 - 2.5 μIU/mL',
                          'status': isElevated ? 'Sluggish Thyroid' : (isLow ? 'Hyper-active' : 'Optimal'),
                          'statusColor': (isElevated || isLow) ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                          'bgColor': (isElevated || isLow) ? const Color(0xFFFFF7ED) : const Color(0xFFDCFCE7),
                          'interpretation': isElevated
                              ? 'Sub-optimal T4→T3 cellular conversion. Support with Selenium & empty stomach bio-timing.'
                              : 'Thyroid axis operating within functional metabolic range.',
                        });
                      }

                      // LH : FSH Ratio
                      final lhVal = double.tryParse(lhController.text.trim());
                      final fshVal = double.tryParse(fshController.text.trim());
                      if (lhVal != null && fshVal != null && fshVal > 0) {
                        final ratio = lhVal / fshVal;
                        final isHighRatio = ratio >= 2.0;
                        newLabs.add({
                          'name': 'LH : FSH Ratio',
                          'value': '${ratio.toStringAsFixed(1)} : 1',
                          'optimal': 'Optimal Functional: 1 : 1',
                          'status': isHighRatio ? 'Elevated LH' : 'Balanced',
                          'statusColor': isHighRatio ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                          'bgColor': isHighRatio ? const Color(0xFFFFF7ED) : const Color(0xFFDCFCE7),
                          'interpretation': isHighRatio
                              ? 'LH dominance relative to FSH is characteristic of PCOS follicular stalling.'
                              : 'Pituitary follicular signaling is balanced.',
                        });
                      }

                      // Testosterone
                      final testVal = double.tryParse(testController.text.trim());
                      if (testVal != null) {
                        final isHigh = testVal > 2.2;
                        newLabs.add({
                          'name': 'Free Testosterone',
                          'value': '$testVal pg/mL',
                          'optimal': 'Functional: 0.8 - 2.2 pg/mL',
                          'status': isHigh ? 'Elevated Androgen' : 'Optimal',
                          'statusColor': isHigh ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                          'bgColor': isHigh ? const Color(0xFFFFF7ED) : const Color(0xFFDCFCE7),
                          'interpretation': isHigh
                              ? 'Excess free androgens trigger sebum and hirsutism. Spearmint tea and zinc help modulate 5α-reductase.'
                              : 'Androgen levels within healthy physiological limits.',
                        });
                      }

                      // Vitamin D3
                      final vitDVal = double.tryParse(vitDController.text.trim());
                      if (vitDVal != null) {
                        final isLow = vitDVal < 40.0;
                        newLabs.add({
                          'name': 'Vitamin D3 (25-OH)',
                          'value': '$vitDVal ng/mL',
                          'optimal': 'Functional: 40 - 70 ng/mL',
                          'status': isLow ? 'Insufficient' : 'Optimal',
                          'statusColor': isLow ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                          'bgColor': isLow ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                          'interpretation': isLow
                              ? 'Vitamin D acts as a secosteroid hormone required for ovarian receptor sensitivity.'
                              : 'Optimal cellular vitamin D reserves.',
                        });
                      }

                      setState(() {
                        _userLoggedLabResults.clear();
                        _userLoggedLabResults.addAll(newLabs);
                      });

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newLabs.isNotEmpty
                                ? '${newLabs.length} blood test results logged & translated by Docsy! ✨'
                                : 'No values entered. Lab tracker reset.',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                          ),
                          backgroundColor: BlushyColors.primary,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      "Save Lab Biomarkers",
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String optimalInfo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: BlushyColors.text),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: BlushyColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          optimalInfo,
          style: GoogleFonts.manrope(fontSize: 10, color: const Color(0xFF64748B)),
        ),
      ],
    );
  }

  /// 9. OB-GYN Clinical Export Card (Clean Warm Theme)
  Widget _buildOBGYNClinicalExportCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: BlushyColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Doctor Visit Summary & Export",
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: BlushyColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Equip your OB-GYN or Endocrinologist with quantified 30-day symptom curves, pain frequency & adherence logs.",
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: BlushyColors.secondaryText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DoctorSummaryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                  label: Text(
                    "Export PDF",
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _openAskSiaChat(
                      context,
                      "Docsy, I have an appointment with my OB-GYN next week for ${_selectedHormonalCondition.toUpperCase()}. What exact clinical questions and blood test requests should I bring?",
                    );
                  },
                  icon: const Icon(Icons.help_outline_rounded, size: 14, color: BlushyColors.primary),
                  label: Text(
                    "Doctor Agenda Prep",
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: BlushyColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: BlushyColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 10. Complete Responsive Stage 4 Home OS (Spacious, Elegant, Luxury Blushy Aesthetic)
  Widget _buildHormonalHealthHomeOS(PersonalContext pc, BlushyOSState state) {
    _initStage4FromPersonalContext(pc);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // MOBILE LAYOUT
          return _wrapDashboardLayout(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width < 768 ? 640 : double.infinity,
                ),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  children: [
                    // 1. HERO: Living Menstrual Cycle & Period Dial
                    _buildLivingTodayCycle(),
                    const SizedBox(height: 28),

                    // 2. Personalized Root-Cause Care Header (Onboarding-derived)
                    _buildHormonalPersonalizedDocsyCard(pc),
                    const SizedBox(height: 28),

                    // 3. Quick-Tap Real-Time Signal & Symptom Chips
                    _buildHormonalLiveSignalTracker(),
                    const SizedBox(height: 28),

                    // 4. Focused Daily Protocol Module (Glucose Buffer / Supplements / Lab Export)
                    _buildHormonalActionModules(),
                    const SizedBox(height: 28),

                    // 5. Docsy Live Real-Time Insights & Biomarker Synthesis
                    _buildHormonalDocsyLiveReactionCard(pc),
                    const SizedBox(height: 28),

                    // 6. Wellness Journey Timeline
                    _buildLivingJourney(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // TABLET LAYOUT
          return _wrapDashboardLayout(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 36,
                  ),
                  children: [
                    _buildLivingTodayCycle(),
                    const SizedBox(height: 36),
                    _buildHormonalPersonalizedDocsyCard(pc),
                    const SizedBox(height: 36),
                    _buildHormonalLiveSignalTracker(),
                    const SizedBox(height: 36),
                    _buildHormonalActionModules(),
                    const SizedBox(height: 36),
                    _buildHormonalDocsyLiveReactionCard(pc),
                    const SizedBox(height: 36),
                    _buildLivingJourney(),
                  ],
                ),
              ),
            ),
          );
        } else {
          // DESKTOP LAYOUT (Dual Column Editorial)
          return _wrapDashboardLayout(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: min(1440.0, width - 64.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 36,
                ),
                child: ListView(
                  controller: _hormonalHomeScrollController,
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Panel (60% width): Period Dial + Signals + Action Modules
                        Expanded(
                          flex: 60,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLivingTodayCycle(),
                              const SizedBox(height: 32),
                              _buildHormonalPersonalizedDocsyCard(pc),
                              const SizedBox(height: 32),
                              _buildHormonalLiveSignalTracker(),
                              const SizedBox(height: 32),
                              _buildHormonalActionModules(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 36),
                        // Right Panel (40% width): Docsy Live Insights & Journey
                        Expanded(
                          flex: 40,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHormonalDocsyLiveReactionCard(pc),
                              const SizedBox(height: 32),
                              _buildLivingJourney(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // --- BRANCH: TRYING TO CONCEIVE (TTC) COMPREHENSIVE OS ---
  final ScrollController _ttcHomeScrollController = ScrollController();

  /// LAYER 1: WHERE AM I? (Calibrated Fertility Status Compass)
  void _saveTtcDailyLog() {
    final checkin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
    if (_ttcLoggedBBT != null) checkin['ttc_bbt'] = _ttcLoggedBBT;
    if (_ttcLoggedOPK != null) checkin['ttc_opk'] = _ttcLoggedOPK;
    if (_ttcLoggedCervicalFluid != null) checkin['ttc_cervical_fluid'] = _ttcLoggedCervicalFluid;
    checkin['ttc_intercourse'] = _ttcLoggedIntercourse;
    checkin['date'] = DateTime.now().toIso8601String();
    BlushyStorage.write('daily_checkin.json', checkin);

    ApiAuthService().saveOnboardingAnswers({
      'ttc_bbt': _ttcLoggedBBT,
      'ttc_opk': _ttcLoggedOPK,
      'ttc_cervical_fluid': _ttcLoggedCervicalFluid,
      'ttc_intercourse': _ttcLoggedIntercourse,
      'daily_checkin': checkin,
    }).catchError((_) => <String, dynamic>{});
  }

  /// LAYER 1: WHERE AM I? (Calibrated Fertility Status Compass)
  Widget _buildTtcWhereAmICompass() {
    final bool hasBBT = _ttcLoggedBBT != null;
    final bool isPeakLH = _ttcLoggedOPK == 'Peak (Surge)';
    final bool isHighLH = _ttcLoggedOPK == 'High';
    final bool isEggWhite = _ttcLoggedCervicalFluid == 'Egg White (Peak)';
    final bool isWatery = _ttcLoggedCervicalFluid == 'Watery';
    final bool hasSustainedShift = hasBBT && _ttcLoggedBBT! >= 98.0;

    String fertilityStatus;
    Color statusColor;
    int activeSegmentIndex;

    if (isPeakLH || isEggWhite) {
      fertilityStatus = "PEAK CHANCE";
      statusColor = const Color(0xFFE11D48);
      activeSegmentIndex = 3;
    } else if (isHighLH || isWatery) {
      fertilityStatus = "HIGH CHANCE";
      statusColor = const Color(0xFFEA580C);
      activeSegmentIndex = 2;
    } else if (hasSustainedShift) {
      fertilityStatus = "OVULATION CONFIRMED";
      statusColor = const Color(0xFF059669);
      activeSegmentIndex = 1;
    } else {
      fertilityStatus = "BUILDING WINDOW";
      statusColor = const Color(0xFF7C3AED);
      activeSegmentIndex = 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("FERTILITY COMPASS"),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.explore_rounded, size: 18, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPeakLH || isEggWhite
                          ? "Peak Fertile Day"
                          : (isHighLH || isWatery ? "Approaching Ovulation" : (hasSustainedShift ? "Post-Ovulation (BBT Shift)" : "Follicular Phase")),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: BlushyColors.text,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      fertilityStatus,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Visual 4-Stage Segmented Bar
              Row(
                children: [
                  _buildCompassSegment("Low", 0, activeSegmentIndex, const Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  _buildCompassSegment("Building", 1, activeSegmentIndex, const Color(0xFF0284C7)),
                  const SizedBox(width: 4),
                  _buildCompassSegment("High", 2, activeSegmentIndex, const Color(0xFFEA580C)),
                  const SizedBox(width: 4),
                  _buildCompassSegment("Peak", 3, activeSegmentIndex, const Color(0xFFE11D48)),
                ],
              ),
              const SizedBox(height: 16),

              // Interactive Quick Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildMiniSignalChip(
                      icon: Icons.thermostat_rounded,
                      label: "BBT",
                      value: _ttcLoggedBBT != null ? "${_ttcLoggedBBT!.toStringAsFixed(1)}°F" : "Log",
                      color: const Color(0xFFEA580C),
                      onTap: () => _showTtcLogSignsSheet(context),
                    ),
                    const SizedBox(width: 8),
                    _buildMiniSignalChip(
                      icon: Icons.biotech_rounded,
                      label: "LH Test",
                      value: _ttcLoggedOPK ?? "Test",
                      color: const Color(0xFF7C3AED),
                      onTap: () => _showTtcLogSignsSheet(context),
                    ),
                    const SizedBox(width: 8),
                    _buildMiniSignalChip(
                      icon: Icons.water_drop_rounded,
                      label: "Fluid",
                      value: _ttcLoggedCervicalFluid ?? "Check",
                      color: const Color(0xFF0284C7),
                      onTap: () => _showTtcLogSignsSheet(context),
                    ),
                    const SizedBox(width: 8),
                    _buildMiniSignalChip(
                      icon: Icons.favorite_rounded,
                      label: "Intimacy",
                      value: _ttcLoggedIntercourse ? "Logged" : "Log",
                      color: const Color(0xFFE11D48),
                      onTap: () {
                        setState(() {
                          _ttcLoggedIntercourse = !_ttcLoggedIntercourse;
                        });
                        _saveTtcDailyLog();
                      },
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

  Widget _buildCompassSegment(String title, int index, int activeIndex, Color segmentColor) {
    final bool isActive = index == activeIndex;
    final bool isPassed = index <= activeIndex;
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: isPassed ? segmentColor : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? segmentColor : BlushyColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSignalChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isLogged = value != "Log" && value != "Test" && value != "Check";
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isLogged ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLogged ? color : const Color(0xFFE2E8F0),
            width: isLogged ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isLogged ? color : BlushyColors.secondaryText),
            const SizedBox(width: 5),
            Text(
              "$label: ",
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BlushyColors.secondaryText,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isLogged ? color : BlushyColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// LAYER 2: WHAT MATTERS TODAY? (Interactive Daily Focus)
  Widget _buildTtcWhatMattersTodayCard() {
    final bool isPeakLH = _ttcLoggedOPK == 'Peak (Surge)';
    final bool isHighLH = _ttcLoggedOPK == 'High';
    final bool isEggWhite = _ttcLoggedCervicalFluid == 'Egg White (Peak)';

    final List<Map<String, dynamic>> items = (isPeakLH || isEggWhite || isHighLH)
        ? [
            {
              "id": "action_try",
              "title": "Optimal Trying Window",
              "subtitle": "Highest sperm survival probability",
              "color": const Color(0xFFE11D48),
            },
            {
              "id": "action_lh",
              "title": "Log Afternoon LH Strip",
              "subtitle": "Test between 12 PM - 4 PM",
              "color": const Color(0xFF7C3AED),
            },
            {
              "id": "action_rest",
              "title": "Restorative Evening",
              "subtitle": "Low-cortisol routine & hydration",
              "color": const Color(0xFF059669),
            },
          ]
        : [
            {
              "id": "action_bbt",
              "title": "Morning BBT First Thing",
              "subtitle": "Take reading before getting out of bed",
              "color": const Color(0xFFEA580C),
            },
            {
              "id": "action_lh",
              "title": "Daily LH Baseline Check",
              "subtitle": "Watch for approaching surge",
              "color": const Color(0xFF7C3AED),
            },
            {
              "id": "action_water",
              "title": "Track Cervical Fluid",
              "subtitle": "Notice texture transitions today",
              "color": const Color(0xFF0284C7),
            },
          ];

    final int completed = items.where((i) => _ttcCompletedTodayActions.contains(i['id'])).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("YOUR FOCUS TODAY"),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Daily Priority Checklist",
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: BlushyColors.text,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: completed == items.length && items.isNotEmpty ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$completed of ${items.length} DONE",
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: completed == items.length && items.isNotEmpty ? Colors.white : BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...items.map((item) {
                final String id = item['id'] as String;
                final bool isDone = _ttcCompletedTodayActions.contains(id);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isDone) {
                        _ttcCompletedTodayActions.remove(id);
                      } else {
                        _ttcCompletedTodayActions.add(id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: isDone ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] as String,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: isDone ? FontWeight.w500 : FontWeight.w700,
                                  color: isDone ? BlushyColors.secondaryText : BlushyColors.text,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['subtitle'] as String,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: BlushyColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                "Tap any item to complete. Keep it relaxed and steady today.",
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: BlushyColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// LAYER 3 - MODULE 1: INLINE QUICK-LOG SIGNALS MATRIX
  Widget _buildTtcSignalsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("LOG TODAY'S SIGNALS"),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. LH Strip
              Row(
                children: [
                  const Icon(Icons.biotech_rounded, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(
                    "LH Surge Strip",
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: BlushyColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInlineLogChip(
                    "Low / Neg",
                    _ttcLoggedOPK == 'Negative / Low',
                    const Color(0xFF7C3AED),
                    () {
                      setState(() => _ttcLoggedOPK = _ttcLoggedOPK == 'Negative / Low' ? null : 'Negative / Low');
                      _saveTtcDailyLog();
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildInlineLogChip(
                    "High",
                    _ttcLoggedOPK == 'High',
                    const Color(0xFF7C3AED),
                    () {
                      setState(() => _ttcLoggedOPK = _ttcLoggedOPK == 'High' ? null : 'High');
                      _saveTtcDailyLog();
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildInlineLogChip(
                    "Peak Surge",
                    _ttcLoggedOPK == 'Peak (Surge)',
                    const Color(0xFFE11D48),
                    () {
                      setState(() => _ttcLoggedOPK = _ttcLoggedOPK == 'Peak (Surge)' ? null : 'Peak (Surge)');
                      _saveTtcDailyLog();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),

              // 2. Cervical Fluid
              Row(
                children: [
                  const Icon(Icons.water_drop_rounded, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Text(
                    "Cervical Fluid",
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: BlushyColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildInlineLogChip("Dry", _ttcLoggedCervicalFluid == 'Dry', const Color(0xFF0284C7), () {
                      setState(() => _ttcLoggedCervicalFluid = _ttcLoggedCervicalFluid == 'Dry' ? null : 'Dry');
                      _saveTtcDailyLog();
                    }),
                    const SizedBox(width: 6),
                    _buildInlineLogChip("Creamy", _ttcLoggedCervicalFluid == 'Creamy', const Color(0xFF0284C7), () {
                      setState(() => _ttcLoggedCervicalFluid = _ttcLoggedCervicalFluid == 'Creamy' ? null : 'Creamy');
                      _saveTtcDailyLog();
                    }),
                    const SizedBox(width: 6),
                    _buildInlineLogChip("Watery", _ttcLoggedCervicalFluid == 'Watery', const Color(0xFF0284C7), () {
                      setState(() => _ttcLoggedCervicalFluid = _ttcLoggedCervicalFluid == 'Watery' ? null : 'Watery');
                      _saveTtcDailyLog();
                    }),
                    const SizedBox(width: 6),
                    _buildInlineLogChip("Egg White", _ttcLoggedCervicalFluid == 'Egg White (Peak)', const Color(0xFFE11D48), () {
                      setState(() => _ttcLoggedCervicalFluid = _ttcLoggedCervicalFluid == 'Egg White (Peak)' ? null : 'Egg White (Peak)');
                      _saveTtcDailyLog();
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),

              // 3. Morning BBT
              Row(
                children: [
                  const Icon(Icons.thermostat_rounded, size: 16, color: Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  Text(
                    "Morning BBT (°F)",
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: BlushyColors.text),
                  ),
                  const Spacer(),
                  if (_ttcLoggedBBT != null)
                    Text(
                      "${_ttcLoggedBBT!.toStringAsFixed(1)}°F",
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFEA580C)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [97.2, 97.4, 97.7, 98.0, 98.3, 98.6].map((temp) {
                    final bool isSel = _ttcLoggedBBT == temp;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildInlineLogChip(
                        "${temp.toStringAsFixed(1)}°",
                        isSel,
                        const Color(0xFFEA580C),
                        () {
                          setState(() => _ttcLoggedBBT = isSel ? null : temp);
                          _saveTtcDailyLog();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),

              // 4. Intimacy Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFE11D48)),
                      const SizedBox(width: 8),
                      Text(
                        "Intimacy / Trying",
                        style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: BlushyColors.text),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      setState(() => _ttcLoggedIntercourse = !_ttcLoggedIntercourse);
                      _saveTtcDailyLog();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _ttcLoggedIntercourse ? const Color(0xFFE11D48) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _ttcLoggedIntercourse ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _ttcLoggedIntercourse ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 14,
                            color: _ttcLoggedIntercourse ? Colors.white : BlushyColors.secondaryText,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _ttcLoggedIntercourse ? "Logged" : "+ Log",
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _ttcLoggedIntercourse ? Colors.white : BlushyColors.text,
                            ),
                          ),
                        ],
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

  Widget _buildInlineLogChip(String label, bool isSelected, Color activeColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: 0.9,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : BlushyColors.text,
          ),
        ),
      ),
    );
  }

  /// Interactive Bottom Sheet for Logging Daily Fertility Signs
  void _showTtcLogSignsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Log Today's Fertility Signs",
                          style: GoogleFonts.manrope(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: BlushyColors.text,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. BBT
                    Text(
                      "Morning BBT (°F)",
                      style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [97.2, 97.4, 97.7, 98.0, 98.3, 98.6].map((temp) {
                        final bool isSelected = _ttcLoggedBBT == temp;
                        return ChoiceChip(
                          label: Text("${temp.toStringAsFixed(1)}°"),
                          selected: isSelected,
                          selectedColor: const Color(0xFFEA580C),
                          backgroundColor: const Color(0xFFF8FAFC),
                          onSelected: (selected) {
                            setState(() {
                              _ttcLoggedBBT = selected ? temp : null;
                            });
                            setSheetState(() {});
                          },
                          labelStyle: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : BlushyColors.text,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 2. OPK LH Strip
                    Text(
                      "LH Surge Strip (OPK)",
                      style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Negative / Low', 'High', 'Peak (Surge)'].map((opt) {
                        final bool isSelected = _ttcLoggedOPK == opt;
                        return ChoiceChip(
                          label: Text(opt),
                          selected: isSelected,
                          selectedColor: const Color(0xFF7C3AED),
                          backgroundColor: const Color(0xFFF8FAFC),
                          onSelected: (selected) {
                            setState(() {
                              _ttcLoggedOPK = selected ? opt : null;
                            });
                            setSheetState(() {});
                          },
                          labelStyle: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : BlushyColors.text,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 3. Cervical Fluid
                    Text(
                      "Cervical Fluid Texture",
                      style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Dry', 'Sticky', 'Creamy', 'Watery', 'Egg White (Peak)'].map((opt) {
                        final bool isSelected = _ttcLoggedCervicalFluid == opt;
                        return ChoiceChip(
                          label: Text(opt),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0284C7),
                          backgroundColor: const Color(0xFFF8FAFC),
                          onSelected: (selected) {
                            setState(() {
                              _ttcLoggedCervicalFluid = selected ? opt : null;
                            });
                            setSheetState(() {});
                          },
                          labelStyle: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : BlushyColors.text,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 4. Intercourse Checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _ttcLoggedIntercourse,
                      activeColor: const Color(0xFFE11D48),
                      title: Text(
                        "Intercourse / Insemination today",
                        style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: BlushyColors.text),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _ttcLoggedIntercourse = val ?? false;
                        });
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final checkin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
                          if (_ttcLoggedBBT != null) checkin['ttc_bbt'] = _ttcLoggedBBT;
                          if (_ttcLoggedOPK != null) checkin['ttc_opk'] = _ttcLoggedOPK;
                          if (_ttcLoggedCervicalFluid != null) checkin['ttc_cervical_fluid'] = _ttcLoggedCervicalFluid;
                          checkin['ttc_intercourse'] = _ttcLoggedIntercourse;
                          checkin['date'] = DateTime.now().toIso8601String();
                          BlushyStorage.write('daily_checkin.json', checkin);

                          ApiAuthService().saveOnboardingAnswers({
                            'ttc_bbt': _ttcLoggedBBT,
                            'ttc_opk': _ttcLoggedOPK,
                            'ttc_cervical_fluid': _ttcLoggedCervicalFluid,
                            'ttc_intercourse': _ttcLoggedIntercourse,
                            'daily_checkin': checkin,
                          }).catchError((_) => <String, dynamic>{});

                          Navigator.pop(ctx);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Fertility signs logged & calibrated successfully.",
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                              ),
                              backgroundColor: BlushyColors.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BlushyColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          "Save & Calibrate Timeline",
                          style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// LAYER 3 - MODULE 2: DOCSY NOTICED SOMETHING (Interpretation Layer)
  Widget _buildTtcDocsyInterpretationCard() {
    final bool hasBBT = _ttcLoggedBBT != null;
    final bool isPeakLH = _ttcLoggedOPK == 'Peak (Surge)';
    final bool isHighLH = _ttcLoggedOPK == 'High';
    final bool isEggWhite = _ttcLoggedCervicalFluid == 'Egg White (Peak)';
    final bool hasSustainedShift = hasBBT && _ttcLoggedBBT! >= 98.0;

    String headlineVerdict;
    Color verdictColor;
    IconData verdictIcon;

    if (isPeakLH && !hasSustainedShift) {
      headlineVerdict = "Peak LH Surge: Ovulation expected in 24–36 hrs. High conception window.";
      verdictColor = const Color(0xFFE11D48);
      verdictIcon = Icons.local_fire_department_rounded;
    } else if (isPeakLH || isEggWhite || isHighLH) {
      headlineVerdict = "Fertile window open: High estrogen & fertile fluid detected.";
      verdictColor = const Color(0xFF7C3AED);
      verdictIcon = Icons.auto_awesome_rounded;
    } else if (hasSustainedShift) {
      headlineVerdict = "Progesterone thermal shift active. Ovulation confirmed.";
      verdictColor = const Color(0xFF059669);
      verdictIcon = Icons.check_circle_rounded;
    } else {
      headlineVerdict = "Follicular phase: Baseline signals steady. Log daily changes.";
      verdictColor = const Color(0xFF0284C7);
      verdictIcon = Icons.spa_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("DOCSY NOTICED SOMETHING"),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header with AI badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 16, color: verdictColor),
                      const SizedBox(width: 8),
                      Text(
                        "Docsy AI Insights",
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: BlushyColors.text,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: verdictColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(verdictIcon, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          isPeakLH ? "Peak Surge" : (hasSustainedShift ? "Ovulated" : "Active Rhythm"),
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Punchy 1-line AI synthesis with bold accent border
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(color: verdictColor, width: 3.5),
                    top: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                    right: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                    bottom: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                  ),
                ),
                child: Text(
                  headlineVerdict,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.text,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Interactive Signal Quick-Ask Chips
              Text(
                "TAP A SIGNAL TO ASK DOCSY:",
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildTtcDocsyChip(
                      icon: Icons.biotech_rounded,
                      label: "LH: ${_ttcLoggedOPK ?? 'Not Logged'}",
                      color: const Color(0xFF7C3AED),
                      onTap: () => _openAskSiaChat(context, "What does my LH test result (${_ttcLoggedOPK ?? 'pending'}) indicate for our conception window?"),
                    ),
                    const SizedBox(width: 8),
                    _buildTtcDocsyChip(
                      icon: Icons.thermostat_rounded,
                      label: "BBT: ${hasBBT ? '${_ttcLoggedBBT!.toStringAsFixed(1)}°F' : 'Log Temp'}",
                      color: const Color(0xFFEA580C),
                      onTap: () => _openAskSiaChat(context, "How does my morning BBT curve confirm whether ovulation has occurred?"),
                    ),
                    const SizedBox(width: 8),
                    _buildTtcDocsyChip(
                      icon: Icons.water_drop_rounded,
                      label: "Fluid: ${_ttcLoggedCervicalFluid ?? 'Check'}",
                      color: const Color(0xFF0284C7),
                      onTap: () => _openAskSiaChat(context, "How fertile is my cervical fluid today and when should we prioritize intimacy?"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Quick Question Pills
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  "Best time to try today?",
                  "Did I ovulate yet?",
                  "Can I test today?",
                ].map((q) {
                  return InkWell(
                    onTap: () => _openAskSiaChat(context, q),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BlushyColors.primary, width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: BlushyColors.primary),
                          const SizedBox(width: 5),
                          Text(
                            q,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: BlushyColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTtcDocsyChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// LAYER 3 - MODULE 3: TOGETHER (Partner Participation)
  Widget _buildTtcTogetherCard() {
    final int completedCount = _ttcPartnerTaskList.where((t) => t['completed'] == true).length;
    final int totalCount = _ttcPartnerTaskList.length;
    final double progress = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("TOGETHER"),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header with alignment counter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFE11D48)),
                      const SizedBox(width: 8),
                      Text(
                        "Partner Alignment",
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: BlushyColors.text,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: completedCount == totalCount && totalCount > 0 ? const Color(0xFF059669) : const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$completedCount of $totalCount Done",
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Vibrant Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completedCount == totalCount && totalCount > 0 ? const Color(0xFF059669) : const Color(0xFFE11D48),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Interactive Partner Action List
              ..._ttcPartnerTaskList.asMap().entries.map((entry) {
                final Map<String, dynamic> task = entry.value;
                final bool isDone = task['completed'] as bool;

                return InkWell(
                  onTap: () {
                    setState(() {
                      task['completed'] = !isDone;
                    });
                    BlushyStorage.write('ttc_partner_tasks.json', {'tasks': _ttcPartnerTaskList});
                    ApiAuthService().saveOnboardingAnswers({
                      'ttc_partner_tasks': _ttcPartnerTaskList,
                    }).catchError((_) => <String, dynamic>{});
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: isDone ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            task['task'] as String,
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: isDone ? FontWeight.w500 : FontWeight.w700,
                              color: isDone ? BlushyColors.secondaryText : BlushyColors.text,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final tasksStr = _ttcPartnerTaskList.map((t) => "- [${(t['completed'] as bool) ? 'X' : ' '}] ${t['task']}").join("\n");
                    final text = "Blushy Together Plan for Today:\n$tasksStr";
                    Share.share(text, subject: "Our Daily Fertility Plan");
                  },
                  icon: const Icon(Icons.ios_share_rounded, size: 15, color: Color(0xFFE11D48)),
                  label: Text(
                    "Share Today's Plan with Partner",
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE11D48),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE11D48), width: 1.2),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// LAYER 3 - MODULE 4: YOUR FERTILITY REPORT (Clinician-Ready Summary)
  Widget _buildTtcFertilityReportCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("FOR YOUR NEXT APPOINTMENT"),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header with status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment_ind_outlined, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Text(
                        "Clinical Fertility Summary",
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: BlushyColors.text,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "OB/GYN READY",
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. 4 Clean Metric Tiles with Bold Colored Typography
              Row(
                children: [
                  Expanded(
                    child: _buildReportMetricTile(
                      icon: Icons.calendar_month_rounded,
                      title: "28d Cycle",
                      subtitle: "Regular Rhythm",
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildReportMetricTile(
                      icon: Icons.local_fire_department_rounded,
                      title: _ttcLoggedOPK == 'Peak (Surge)' ? "Day 14 Peak" : "LH Tracked",
                      subtitle: "Surge Profile",
                      color: const Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildReportMetricTile(
                      icon: Icons.thermostat_rounded,
                      title: _ttcLoggedBBT != null ? "${_ttcLoggedBBT!.toStringAsFixed(1)}°F" : "BBT Curve",
                      subtitle: "Biphasic Shift",
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildReportMetricTile(
                      icon: Icons.picture_as_pdf_rounded,
                      title: "PDF Summary",
                      subtitle: "Export Ready",
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final bbtStr = _ttcLoggedBBT != null ? "${_ttcLoggedBBT!.toStringAsFixed(1)}°F" : "Not recorded today";
                    final lhStr = _ttcLoggedOPK ?? "Not tested today";
                    final cfStr = _ttcLoggedCervicalFluid ?? "Not recorded today";
                    final intStr = _ttcLoggedIntercourse ? "Logged" : "None";
                    final dateStr = DateTime.now().toLocal().toString().split(' ')[0];
                    final summary = "Blushy Clinical Fertility Summary ($dateStr)\n\n"
                        "• Basal Body Temperature: $bbtStr\n"
                        "• LH Ovulation Test: $lhStr\n"
                        "• Cervical Fluid: $cfStr\n"
                        "• Intercourse / Insemination: $intStr\n"
                        "• Cycle Timing: Day 14 fertile window\n\n"
                        "Generated by Blushy for clinical review with doctor.";
                    Share.share(summary, subject: "Blushy Clinical Fertility Summary");
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Colors.white),
                  label: Text(
                    "Generate Clinical Report (PDF)",
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportMetricTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: BlushyColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// LAYER 3 - MODULE 5: TWO-WEEK WAIT GUIDANCE
  Widget _buildTtcTwoWeekWaitCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("TWO-WEEK WAIT GUIDANCE"),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header with DPO badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 8),
                      Text(
                        "Luteal Phase Tracker",
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: BlushyColors.text,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "4 DPO",
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Interactive 3-Stage Progress Timeline Stepper
              Row(
                children: [
                  Expanded(
                    child: _buildTtcLutealStage(
                      stage: "Days 1–5",
                      title: "Fertilization",
                      isActive: true,
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildTtcLutealStage(
                      stage: "Days 6–10",
                      title: "Implantation",
                      isActive: false,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildTtcLutealStage(
                      stage: "Days 11–14",
                      title: "Testing",
                      isActive: false,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Compact False-Negative Shield
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "False-Negative Shield: Accurate testing opens in 8 days (at 12 DPO).",
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Interactive Calming Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openAskSiaChat(context, "Guide me through a quick calming relaxation exercise for the two-week wait."),
                      icon: const Icon(Icons.spa_rounded, size: 14, color: Color(0xFF4F46E5)),
                      label: Text(
                        "Calm Reset",
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF4F46E5), width: 1.0),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openAskSiaChat(context, "What normal symptoms occur around 4 DPO during the two-week wait?"),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: BlushyColors.primary),
                      label: Text(
                        "4 DPO Signs",
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: BlushyColors.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: BlushyColors.primary, width: 1.0),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildTtcLutealStage({
    required String stage,
    required String title,
    required bool isActive,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: isActive ? color : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? color : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            stage,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white70 : BlushyColors.secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isActive ? Colors.white : BlushyColors.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Complete Responsive TTC Home OS (Low-Cortisol, 3-Layer Hierarchy)
  Widget _buildTTCHomeOS(PersonalContext pc, BlushyOSState state) {
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
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  children: [
                    // 1. HERO: Living Menstrual Cycle & Period Dial
                    _buildLivingTodayCycle(),
                    const SizedBox(height: 24),

                    // LAYER 1: WHERE AM I?
                    _buildTtcWhereAmICompass(),
                    const SizedBox(height: 24),

                    // LAYER 2: WHAT MATTERS TODAY?
                    _buildTtcWhatMattersTodayCard(),
                    const SizedBox(height: 24),

                    // LAYER 3: TODAY'S FERTILITY SIGNALS
                    _buildTtcSignalsCard(),
                    const SizedBox(height: 24),

                    // LAYER 3: DOCSY NOTICED SOMETHING
                    _buildTtcDocsyInterpretationCard(),
                    const SizedBox(height: 24),

                    // LAYER 3: TOGETHER (PARTNER)
                    _buildTtcTogetherCard(),
                    const SizedBox(height: 24),

                    // LAYER 3: YOUR FERTILITY REPORT
                    _buildTtcFertilityReportCard(),
                    const SizedBox(height: 24),

                    // LAYER 3: TWO-WEEK WAIT GUIDANCE
                    _buildTtcTwoWeekWaitCard(),
                    const SizedBox(height: 24),

                    // Daily Check-In
                    _buildLivingCheckIn(),
                    const SizedBox(height: 24),

                    // Wellness Journey
                    _buildLivingJourney(),
                    const SizedBox(height: 32),
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
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
                  controller: _ttcHomeScrollController,
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  children: [
                    _buildLivingTodayCycle(),
                    const SizedBox(height: 28),
                    _buildTtcWhereAmICompass(),
                    const SizedBox(height: 28),
                    _buildTtcWhatMattersTodayCard(),
                    const SizedBox(height: 28),
                    _buildTtcSignalsCard(),
                    const SizedBox(height: 28),
                    _buildTtcDocsyInterpretationCard(),
                    const SizedBox(height: 28),
                    _buildTtcTogetherCard(),
                    const SizedBox(height: 28),
                    _buildTtcFertilityReportCard(),
                    const SizedBox(height: 28),
                    _buildTtcTwoWeekWaitCard(),
                    const SizedBox(height: 28),
                    _buildLivingCheckIn(),
                    const SizedBox(height: 28),
                    _buildLivingJourney(),
                  ],
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (Editorial Grid)
          return _wrapDashboardLayout(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: ListView(
                  controller: _ttcHomeScrollController,
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 40,
                  ),
                  children: [
                    _buildLivingTodayCycle(),
                    const SizedBox(height: 32),
                    _buildTtcWhereAmICompass(),
                    const SizedBox(height: 32),
                    _buildTtcWhatMattersTodayCard(),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTtcSignalsCard(),
                              const SizedBox(height: 28),
                              _buildTtcTogetherCard(),
                              const SizedBox(height: 28),
                              _buildTtcFertilityReportCard(),
                              const SizedBox(height: 28),
                              _buildLivingCheckIn(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTtcDocsyInterpretationCard(),
                              const SizedBox(height: 28),
                              _buildTtcTwoWeekWaitCard(),
                              const SizedBox(height: 28),
                              _buildLivingJourney(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
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
    final DateTime? dueDate = BlushyOSProvider.of(
      context,
    ).personalContext.dueDate;
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
              SectionHeading("BABY THIS WEEK"),
              const SizedBox(height: 6),
              Text(
                // Fixed at week 24 for everyone. The due date is on the
                // personal context, the same source the hero card now reads.
                _pregnancyWeek() == null
                    ? "This week"
                    : "Week ${_pregnancyWeek()} development",
                style: GoogleFonts.manrope(
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
            borderRadius: BorderRadius.circular(12),
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
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.primary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...highlights.map((h) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: BlushyColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    h,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: BlushyColors.secondaryText,
                                    ),
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: BlushyColors.border,
                          width: 0.8,
                        ),
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
                      _showArticleDialog(
                        context,
                        "Development this week",
                        "Week by week development notes will appear here once they have been reviewed. Your midwife or doctor is the best source in the meantime.",
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BlushyColors.primary,
                      side: const BorderSide(color: BlushyColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context).dashLearnMore),
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
  Widget _buildPregnancyCheckIn() => _buildLogAndCheckIn();

  // --- SECTION 5: DOCSY INSIGHTS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildPregnancyInsights() {
    return const RealInsightsList(title: 'What your logs show');
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
          child: SectionHeading("BABY PREPARATION"),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    color: BlushyColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context).dashPregnancyPrepLists,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...checklist.map((c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_box_outline_blank,
                        size: 18,
                        color: BlushyColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c['item']!,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: BlushyColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x0F2E2623),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c['unlock']!,
                          style: GoogleFonts.manrope(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.secondaryText,
                          ),
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
      "Baby Development",
      "Mother's Body",
      "Nutrition",
      "Sleep",
      "Labour Preparation",
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
          child: SectionHeading("LEARN"),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BlushyColors.primary
                        : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.manrope(
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: BlushyColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(
                              context,
                              article['title']!,
                              article['desc']!,
                            );
                          },
                          child: Text(
                            AppLocalizations.of(context).dashRead,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: BlushyColors.primary,
                            ),
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
                                _pregnancySavedArticles.remove(
                                  article['title']!,
                                );
                              } else {
                                _pregnancySavedArticles.add(article['title']!);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () => _openAskSiaChat(
                            context,
                            "Explain this article: ${article['title']}",
                          ),
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
      {
        "task": "Incorporate iron supplements with breakfast.",
        "who": "Coordinated",
      },
      {"task": "Prepare side sleep body pillows.", "who": "Partner Task"},
      {"task": "Sync 24 Week scan calendar timings.", "who": "Coordinated"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("PARTNER & FAMILY"),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.favorite,
                    color: BlushyColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context).dashSharedPregnancyTimeline,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).dashCoordinatedChecklistsTasks,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 12),
              ...tasks.map((t) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_box_outline_blank,
                        size: 18,
                        color: BlushyColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t['task']!,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: BlushyColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x0F2E2623),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t['who']!,
                          style: GoogleFonts.manrope(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.secondaryText,
                          ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width < 768
                        ? 640
                        : double.infinity,
                  ),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    children: [
                      _buildLivingTodayCycle(),
                      const SizedBox(height: 32),
                      _buildPregnancyBabyThisWeek(),
                      const SizedBox(height: 32),
                      _buildPregnancyCheckIn(),
                      const SizedBox(height: 32),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 32),
                      _buildLivingPatterns(),
                      const SizedBox(height: 32),
                      _buildPregnancyInsights(),
                      const SizedBox(height: 32),
                      _buildPregnancyPartner(),
                      const SizedBox(height: 32),
                      _buildPregnancyJourneyTimeline(),
                      const SizedBox(height: 32),
                      _buildPregnancyCarePlan(),
                      const SizedBox(height: 32),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 32),
                      _buildPregnancyPrep(),
                      const SizedBox(height: 32),
                      _buildPregnancyLearn(),
                      const SizedBox(height: 32),
                      _buildPregnancyJourney(),
                      const SizedBox(height: 32),
                      _buildPregnancyReflection(),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    children: [
                      _buildPregnancyBabyThisWeek(),
                      const SizedBox(height: 48),
                      _buildPregnancyCheckIn(),
                      const SizedBox(height: 48),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 48),
                      _buildLivingPatterns(),
                      const SizedBox(height: 48),
                      _buildPregnancyInsights(),
                      const SizedBox(height: 48),
                      _buildPregnancyPartner(),
                      const SizedBox(height: 48),
                      _buildPregnancyJourneyTimeline(),
                      const SizedBox(height: 48),
                      _buildPregnancyCarePlan(),
                      const SizedBox(height: 48),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 48),
                      _buildPregnancyPrep(),
                      const SizedBox(height: 48),
                      _buildPregnancyLearn(),
                      const SizedBox(height: 48),
                      _buildPregnancyJourney(),
                      const SizedBox(height: 48),
                      _buildPregnancyReflection(),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 40,
                  ),
                  child: ListView(
                    controller: _pregnancyHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildPregnancyCheckIn(),
                      const SizedBox(height: 24),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 24),
                      _buildLivingPatterns(),
                      const SizedBox(height: 24),
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
                                _buildPregnancyInsights(),
                                const SizedBox(height: 48),
                                _buildPregnancyPartner(),
                                const SizedBox(height: 48),
                                _buildPregnancyCarePlan(),
                                const SizedBox(height: 48),
                                _buildAppointmentSummaryCard(),
                                const SizedBox(height: 48),
                                _buildPregnancyPrep(),
                                const SizedBox(height: 48),
                                _buildPregnancyLearn(),
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

    final List<String> feedingOptions = CheckinVocabulary.feeding;
    final List<String> bleedingOptions = CheckinVocabulary.postpartumBleeding;
    final List<String> incisionOptions = CheckinVocabulary.incisionHealing;
    final List<String> pelvicOptions = CheckinVocabulary.pelvicFloor;
    final List<String> waterOptions = CheckinVocabulary.waterHigher;
    final List<String> exerciseOptions = CheckinVocabulary.exerciseGentle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("TODAY'S WELLBEING"),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shown when something just logged matched a reviewed red flag
              // rule, so the reviewed instruction replaces the usual
              // confirmation rather than sitting alongside it.
              if (_checkinSafety != null)
                _buildCheckinSafetyBanner(_checkinSafety!),
              // Mood Selector
              Text(
                AppLocalizations.of(context).dashMood,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedFeeling =
                      checkinData['feeling'] ??
                      (BlushyStorage.read('logged_feeling.json'))['feeling'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeFeeling =
                      _selectedFeeling ??
                      savedFeeling ??
                      (wb.symptoms.isNotEmpty ? wb.symptoms.first : null);
                  final isSelected =
                      activeFeeling != null &&
                      activeFeeling.toString().toLowerCase() ==
                          (opt['label'] as String).toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      _persistCheckinAnswer('mood', opt['label'].toString());
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
                            color: isSelected
                                ? BlushyColors.primary.withValues(alpha: 0.1)
                                : const Color(0xFFF9F6F0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? BlushyColors.primary
                                  : BlushyColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _optionIcon(opt['icon']),
                              size: 20,
                              color: isSelected
                                  ? BlushyColors.primary
                                  : BlushyColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'],
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? BlushyColors.primary
                                : BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              // Feeding Method (Shown if selected in postpartum goals)
              if (_isMetricSelected(pc, [
                'feeding',
                'breastfeeding',
                'pumping',
                'bottle',
                'baby',
              ])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector(
                  "FEEDING METHOD",
                  feedingOptions,
                  _postpartumFeeding,
                  (val) {
                    setState(() => _postpartumFeeding = val);
                    _recordCheckinEvent('feeding', val.toString());
                  },
                  logCategoryKey: 'postpartum_log',
                ),
              ],

              // Bleeding (Lochia)
              if (_isMetricSelected(pc, [
                'bleeding',
                'lochia',
                'recovery',
                'flow',
              ])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector(
                  "BLEEDING STATUS",
                  bleedingOptions,
                  _postpartumBleeding,
                  (val) {
                    setState(() => _postpartumBleeding = val);
                    // Recorded as lochia, never as a symptom named
                    // "bleeding"; see lochiaBuckets.
                    _recordCheckinEvent('postpartum_bleeding', val.toString());
                  },
                  logCategoryKey: 'postpartum_log',
                ),
              ],

              // Incision Healing
              if (_isMetricSelected(pc, [
                'incision',
                'c-section',
                'stitches',
                'perineal',
                'healing',
              ])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector(
                  "INCISION HEALING",
                  incisionOptions,
                  _postpartumIncision,
                  (val) {
                    setState(() => _postpartumIncision = val);
                    // "Not Applicable" maps to nothing on purpose, so this
                    // records only when there is a wound to report on.
                    _recordCheckinEvent('incision', val.toString());
                  },
                  logCategoryKey: 'postpartum_log',
                ),
              ],

              // Pelvic Exercises
              if (_isMetricSelected(pc, [
                'pelvic',
                'pelvic floor',
                'kegel',
                'core',
              ])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector(
                  "PELVIC FLOOR EXERCISE",
                  pelvicOptions,
                  _postpartumPelvic,
                  (val) {
                    setState(() => _postpartumPelvic = val);
                    _recordCheckinEvent('pelvic_floor', val.toString());
                  },
                  logCategoryKey: 'postpartum_log',
                ),
              ],

              // Hydration
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              _buildLivingHorizontalSelector(
                "DAILY HYDRATION",
                waterOptions,
                _postpartumWater,
                (val) {
                  setState(() => _postpartumWater = val);
                },
                logCategoryKey: 'postpartum_log',
              ),

              // Gentle Movement
              if (_isMetricSelected(pc, [
                'exercise',
                'walk',
                'movement',
                'activity',
                'fitness',
              ])) ...[
                const Divider(height: 36, color: Color(0xFFF5F0EB)),
                _buildLivingHorizontalSelector(
                  "GENTLE MOVEMENT",
                  exerciseOptions,
                  _postpartumExercise,
                  (val) {
                    setState(() => _postpartumExercise = val);
                  },
                  logCategoryKey: 'postpartum_log',
                ),
              ],
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Optional Weight
              Text(
                AppLocalizations.of(context).dashWeightOptional,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(AppLocalizations.of(context).dashLogWeight),
                      content: const TextField(
                        decoration: InputDecoration(
                          hintText: "Enter weight in kg",
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppLocalizations.of(context).dashSave),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                label: Text(AppLocalizations.of(context).dashLogWeight),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BlushyColors.primary,
                  side: const BorderSide(color: BlushyColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Notes & Reflections
              Text(
                AppLocalizations.of(context).dashNotesReflections,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                ),
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
                      label: Text(AppLocalizations.of(context).dashVoiceNote),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                            title: Text(
                              AppLocalizations.of(
                                context,
                              ).dashPostpartumMStudioEntry,
                            ),
                            content: const TextField(
                              decoration: InputDecoration(
                                hintText: "Reflect on today's recovery...",
                              ),
                              maxLines: 3,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  AppLocalizations.of(context).dashSave,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(AppLocalizations.of(context).dashMStudio),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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

  // --- SECTION 4: DOCSY INSIGHTS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildPostpartumInsights() {
    return const RealInsightsList(title: 'What your logs show');
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
      {
        "item": "Skin-to-Skin Bonding Time",
        "val": "Logged 30 mins after shift",
      },
      {"item": "Pediatrician Check-up", "val": "Next Check: August 18"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("BABY & YOU"),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.child_care,
                    color: BlushyColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context).dashMotherBabyCoordinatedTasks,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...items.map((c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bookmark_outline,
                        size: 18,
                        color: BlushyColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c['item']!,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: BlushyColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        c['val']!,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: BlushyColors.secondaryText,
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

  // --- SECTION 7: LEARN ---
  Widget _buildPostpartumLearn() {
    final List<String> topics = [
      "Physical Recovery",
      "Mental Health",
      "Postpartum Depression",
      "Breastfeeding",
      "Pelvic Floor Recovery",
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
          child: SectionHeading("LEARN"),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BlushyColors.primary
                        : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.manrope(
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: BlushyColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(
                              context,
                              article['title']!,
                              article['desc']!,
                            );
                          },
                          child: Text(
                            AppLocalizations.of(context).dashRead,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: BlushyColors.primary,
                            ),
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
                                _postpartumSavedArticles.remove(
                                  article['title']!,
                                );
                              } else {
                                _postpartumSavedArticles.add(article['title']!);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () => _openAskSiaChat(
                            context,
                            "Explain this article: ${article['title']}",
                          ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width < 768
                        ? 640
                        : double.infinity,
                  ),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    children: [
                      _buildLivingTodayCycle(),
                      const SizedBox(height: 32),
                      _buildPostpartumRecoveryTimeline(),
                      const SizedBox(height: 32),
                      _buildPostpartumWellbeing(),
                      const SizedBox(height: 32),
                      _buildLogAndCheckIn(),
                      const SizedBox(height: 32),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 32),
                      _buildLivingPatterns(),
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
                      _buildPostpartumJourney(),
                      const SizedBox(height: 32),
                      _buildPostpartumReflection(),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    children: [
                      _buildPostpartumRecoveryTimeline(),
                      const SizedBox(height: 48),
                      _buildPostpartumWellbeing(),
                      const SizedBox(height: 48),
                      _buildLogAndCheckIn(),
                      const SizedBox(height: 32),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 48),
                      _buildLivingPatterns(),
                      const SizedBox(height: 48),
                      _buildPostpartumInsights(),
                      const SizedBox(height: 48),
                      _buildPostpartumCarePlan(),
                      const SizedBox(height: 48),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 48),
                      _buildPostpartumBabyAndYou(),
                      const SizedBox(height: 48),
                      _buildPostpartumLearn(),
                      const SizedBox(height: 48),
                      _buildPostpartumJourney(),
                      const SizedBox(height: 48),
                      _buildPostpartumReflection(),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 40,
                  ),
                  child: ListView(
                    controller: _postpartumHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildPostpartumRecoveryTimeline(),
                      const SizedBox(height: 24),
                      _buildPostpartumWellbeing(),
                      const SizedBox(height: 24),
                      _buildLogAndCheckIn(),
                      const SizedBox(height: 32),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 24),
                      _buildLivingPatterns(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel (65% width)
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPostpartumInsights(),
                                const SizedBox(height: 48),
                                _buildPostpartumCarePlan(),
                                _buildAppointmentSummaryCard(),
                                const SizedBox(height: 32),
                                const SizedBox(height: 48),
                                _buildPostpartumBabyAndYou(),
                                const SizedBox(height: 48),
                                _buildPostpartumLearn(),
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

  // --- SECTION 1: DOCSY'S DAILY BRIEF ---

  // --- SECTION 2: MY CHANGING CYCLE ---
  Widget _buildPeriChangingCycle(PersonalContext pc) {
    return _buildLivingTodayCycle();
  }

  // --- SECTION 3: TODAY'S CHECK-IN ---
  Widget _buildPeriWellbeing() => _buildLogAndCheckIn();

  // --- SECTION 4: DOCSY INSIGHTS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildPeriInsights() {
    return const RealInsightsList(title: 'What your logs show');
  }

  // --- SECTION 5: UNDERSTANDING MY PATTERNS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildPeriPatterns() {
    return const RealInsightsList(title: 'Patterns in your logs');
  }

  // --- SECTION 6: TODAY'S CARE PLAN ---
  Widget _buildPeriCarePlan() {
    return _buildCarePlanSection(heading: "TODAY'S CARE PLAN");
  }

  // --- SECTION 7: LEARN ---
  Widget _buildPeriLearn() {
    final List<String> topics = [
      "Understanding Perimenopause",
      "Hormonal Changes",
      "Hot Flashes",
      "Sleep",
      "Bone Health",
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
          child: SectionHeading("LEARN"),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BlushyColors.primary
                        : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.manrope(
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: BlushyColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(
                              context,
                              article['title']!,
                              article['desc']!,
                            );
                          },
                          child: Text(
                            AppLocalizations.of(context).dashRead,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: BlushyColors.primary,
                            ),
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
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () => _openAskSiaChat(
                            context,
                            "Explain this article: ${article['title']}",
                          ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width < 768
                        ? 640
                        : double.infinity,
                  ),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    children: [
                      _buildPeriChangingCycle(pc),
                      const SizedBox(height: 32),
                      _buildPeriWellbeing(),
                      const SizedBox(height: 32),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 32),
                      _buildLivingPatterns(),
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
                      _buildPeriTransition(),
                      const SizedBox(height: 32),
                      _buildPeriReflection(),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    children: [
                      _buildPeriChangingCycle(pc),
                      const SizedBox(height: 48),
                      _buildPeriWellbeing(),
                      const SizedBox(height: 48),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 48),
                      _buildLivingPatterns(),
                      const SizedBox(height: 48),
                      _buildPeriInsights(),
                      const SizedBox(height: 48),
                      _buildPeriPatterns(),
                      const SizedBox(height: 48),
                      _buildPeriCarePlan(),
                      const SizedBox(height: 48),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 48),
                      _buildPeriLearn(),
                      const SizedBox(height: 48),
                      _buildPeriTransition(),
                      const SizedBox(height: 48),
                      _buildPeriReflection(),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 40,
                  ),
                  child: ListView(
                    controller: _periHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildPeriChangingCycle(pc),
                      const SizedBox(height: 24),
                      _buildPeriWellbeing(),
                      const SizedBox(height: 24),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 24),
                      _buildLivingPatterns(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPeriInsights(),
                                const SizedBox(height: 48),
                                _buildPeriPatterns(),
                                const SizedBox(height: 48),
                                _buildPeriCarePlan(),
                                _buildAppointmentSummaryCard(),
                                const SizedBox(height: 32),
                                const SizedBox(height: 48),
                                _buildPeriLearn(),
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

  // --- SECTION 1: DOCSY'S DAILY BRIEF ---

  // --- SECTION 2: MY WELLBEING ---
  // --- SECTION 2: MY WELLBEING ---
  Widget _buildMenoWellbeing([CurrentWellbeingState? wbParam]) {
    final state = BlushyOSProvider.of(context);
    final wb = wbParam ?? state.wellbeingState;

    final String? sleepVal =
        _wellnessSleep ??
        (wb.sleepQuality != null ? "${wb.sleepQuality}h" : null);
    final String? energyVal =
        (_checkInEnergy?.isNotEmpty == true && _checkInEnergy != 'Balanced')
        ? _checkInEnergy
        : (wb.energy != null ? "Level ${wb.energy}/10" : null);
    final String? moodVal =
        _selectedFeeling ??
        (_checkInMood?.isNotEmpty == true && _checkInMood != 'Calm'
            ? _checkInMood
            : (wb.mood != null ? "Level ${wb.mood}/10" : null));
    final String? hrtVal = _hormonalMedication != 'Not Taken'
        ? _hormonalMedication
        : null;
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
        : "Log today's symptoms to generate your score";

    final String quoteText = loggedCount > 0
        ? "\"You have logged $loggedCount health marker(s) today. Continuing daily check-ins helps track long-term wellbeing and bone health consistency.\""
        : "\"No wellbeing data logged for today yet. Use Log Symptoms to record your sleep, mood, energy, and activity.\"";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading("MY WELLBEING"),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).dashLongTermWellnessOverview,
                style: GoogleFonts.manrope(
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
            borderRadius: BorderRadius.circular(12),
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
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scoreSubtitle,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricLabel(
                      "Sleep Quality",
                      sleepVal ?? "Not Logged",
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildMetricLabel(
                      "Energy level",
                      energyVal ?? "Not Logged",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricLabel(
                      "Mood State",
                      moodVal ?? "Not Logged",
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildMetricLabel(
                      "Medication/HRT",
                      hrtVal ?? "Not Logged",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricLabel(
                      "Daily Walking",
                      walkingVal ?? "Not Logged",
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildMetricLabel(
                      "Hydration",
                      hydrationVal ?? "Not Logged",
                    ),
                  ),
                ],
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF3E4DD),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  quoteText,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: BlushyColors.secondaryText,
                  ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.of(context).dashTodaySCheck,
                        style: GoogleFonts.manrope(
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
                        _showArticleDialog(
                          context,
                          "Wellness History",
                          "Your logged check-in history:\n- Sleep: ${sleepVal ?? 'Not Logged'}\n- Hydration: ${hydrationVal ?? 'Not Logged'}\n- Mood: ${moodVal ?? 'Not Logged'}",
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context).dashViewHealthHistory,
                        style: GoogleFonts.manrope(
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
  Widget _buildMenoCheckIn() => _buildLogAndCheckIn();

  // --- SECTION 4: DOCSY INSIGHTS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildMenoInsights() {
    return const RealInsightsList(title: 'What your logs show');
  }

  // --- SECTION 5: LONG-TERM WELLNESS ---
  Widget _buildMenoPatterns() {
    final List<Map<String, String>> wellnessCards = [
      {
        "title": "Bone Health",
        "desc":
            "\"You've completed strength exercises three times this week.\"",
        "detail":
            "Resistance exercise triggers osteoblast cells, vital for preserving bone mineral density levels after menopause estrogen drops.",
      },
      {
        "title": "Heart Health",
        "desc": "\"You've maintained your walking goal.\"",
        "detail":
            "Walking helps support vascular elasticity, essential for lowering cardiovascular risks in the post-menopausal transition.",
      },
      {
        "title": "Sleep",
        "desc": "\"Sleep quality has gradually improved.\"",
        "detail":
            "Consistent room coolings and screen-free routines have extended deep REM segments by 30 mins average.",
      },
      {
        "title": "Mental Wellbeing",
        "desc": "\"You've been journaling consistently.\"",
        "detail":
            "Taking 5 minutes to write reflections correlates with stable evening cortisol baselines.",
      },
      {
        "title": "Nutrition",
        "desc": "\"Protein intake has improved.\"",
        "detail":
            "Averaging 70g daily protein helps prevent natural muscle mass declines (sarcopenia) and supports cellular energy.",
      },
    ];

    final cards = wellnessCards.map((card) {
      return Container(
        padding: const EdgeInsets.all(BlushySpace.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF7D8DD), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card['title']!.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: BlushyColors.primary,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card['desc']!,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: BlushyColors.text,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card['detail']!,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                color: const Color(0xFF7A6B72),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _showArticleDialog(
                      context,
                      card['title']!,
                      card['detail']!,
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    AppLocalizations.of(context).dashLearnMore,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _openAskSiaChat(
                    context,
                    "Tell me about my ${card['title']}",
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    AppLocalizations.of(context).dashAskDocsy,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: BlushyColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();

    return AutoCarouselCards(
      categoryEyebrow: "LONG-TERM WELLNESS",
      cards: cards,
      height: 195.0,
    );
  }

  // --- SECTION 6: TODAY'S CARE PLAN ---
  Widget _buildMenoCarePlan() {
    return _buildCarePlanSection(heading: "TODAY'S CARE PLAN");
  }

  // --- SECTION 7: LEARN ---
  Widget _buildMenoLearn() {
    final List<String> topics = [
      "Understanding Menopause",
      "Bone Health",
      "Heart Health",
      "Strength Training",
      "Nutrition",
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
          child: SectionHeading("LEARN"),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BlushyColors.primary
                        : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    topic,
                    style: GoogleFonts.manrope(
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['desc']!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: BlushyColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _showArticleDialog(
                              context,
                              article['title']!,
                              article['desc']!,
                            );
                          },
                          child: Text(
                            AppLocalizations.of(context).dashRead,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: BlushyColors.primary,
                            ),
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
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () => _openAskSiaChat(
                            context,
                            "Explain this article: ${article['title']}",
                          ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width < 768
                        ? 640
                        : double.infinity,
                  ),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    children: [
                      _buildLivingTodayCycle(),
                      const SizedBox(height: 32),
                      _buildMenoCheckIn(),
                      const SizedBox(height: 32),
                      _buildMenoWellbeing(),
                      const SizedBox(height: 32),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 32),
                      _buildLivingPatterns(),
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
                      _buildMenoWellnessJourney(),
                      const SizedBox(height: 32),
                      _buildMenoReflection(),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    children: [
                      _buildMenoCheckIn(),
                      const SizedBox(height: 48),
                      _buildMenoWellbeing(),
                      const SizedBox(height: 48),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 48),
                      _buildLivingPatterns(),
                      const SizedBox(height: 48),
                      _buildMenoInsights(),
                      const SizedBox(height: 48),
                      _buildMenoPatterns(),
                      const SizedBox(height: 48),
                      _buildMenoCarePlan(),
                      const SizedBox(height: 48),
                      _buildAppointmentSummaryCard(),
                      const SizedBox(height: 48),
                      _buildMenoLearn(),
                      const SizedBox(height: 48),
                      _buildMenoWellnessJourney(),
                      const SizedBox(height: 48),
                      _buildMenoReflection(),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 40,
                  ),
                  child: ListView(
                    controller: _menoHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildMenoCheckIn(),
                      const SizedBox(height: 24),
                      _buildMenoWellbeing(),
                      const SizedBox(height: 24),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 24),
                      _buildLivingPatterns(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMenoInsights(),
                                const SizedBox(height: 48),
                                _buildMenoPatterns(),
                                const SizedBox(height: 48),
                                _buildMenoCarePlan(),
                                _buildAppointmentSummaryCard(),
                                const SizedBox(height: 32),
                                const SizedBox(height: 48),
                                _buildMenoLearn(),
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

  // --- SECTION 1: DOCSY'S DAILY BRIEF (HERO) ---

  // --- SECTION 2: MY WELLNESS ---
  // --- SECTION 2: MY WELLNESS ---
  Widget _buildWellnessDashboard([
    PersonalContext? pcParam,
    CurrentWellbeingState? wbParam,
  ]) {
    final state = BlushyOSProvider.of(context);
    final pc = pcParam ?? state.personalContext;
    final wb = wbParam ?? state.wellbeingState;

    final String? sleepVal =
        _wellnessSleep ??
        (wb.sleepQuality != null ? "${wb.sleepQuality}h" : null);
    final String? energyVal =
        (_checkInEnergy?.isNotEmpty == true && _checkInEnergy != 'Balanced')
        ? _checkInEnergy
        : (wb.energy != null ? "Level ${wb.energy}/10" : null);
    final String? hydrationVal = _wellnessWater != null
        ? "$_wellnessWater"
        : null;
    final String? moodVal =
        _selectedFeeling ??
        (_checkInMood?.isNotEmpty == true && _checkInMood != 'Calm'
            ? _checkInMood
            : (wb.mood != null ? "Level ${wb.mood}/10" : null));
    final String? movementVal = _wellnessExercise;
    final String? stressVal = _wellnessStress != null
        ? "$_wellnessStress Stress"
        : null;

    final List<String> userGoals = _extractStrings(_onboardingData['goals']);
    final List<String> userSymptoms = _extractStrings(
      _onboardingData['symptoms'],
    );
    final Set<String> activeFilters = {
      ...userGoals,
      ...userSymptoms,
      ..._extractStrings(pc.userGoals),
      ..._extractStrings(pc.userSymptoms),
    }.toSet();

    final List<Map<String, dynamic>> allMetrics = [
      {
        "label": "Sleep State",
        "val": sleepVal ?? "Not Logged",
        "keys": ["sleep", "fatigue", "rest"],
      },
      {
        "label": "Energy level",
        "val": energyVal ?? "Not Logged",
        "keys": ["energy", "fatigue", "low energy", "vitality"],
      },
      {
        "label": "Daily Hydration",
        "val": hydrationVal ?? "Not Logged",
        "keys": ["hydration", "water", "nutrition"],
      },
      {
        "label": "Mood State",
        "val": moodVal ?? "Not Logged",
        "keys": ["mood", "pms", "emotions", "anxiety", "cramps"],
      },
      {
        "label": "Movement",
        "val": movementVal ?? "Not Logged",
        "keys": ["fitness", "movement", "exercise", "walk"],
      },
      {
        "label": "Stress level",
        "val": stressVal ?? "Not Logged",
        "keys": ["stress", "anxiety", "cramps", "mindfulness"],
      },
      if (_loggedWeight != null ||
          activeFilters.any((f) => f.contains('weight')))
        {
          "label": "Weight",
          "val": _loggedWeight != null
              ? "${_loggedWeight!.toStringAsFixed(1)} kg"
              : "Not Logged",
          "keys": ["weight", "nutrition", "fitness"],
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

    int loggedCount = displayMetrics
        .where((m) => m['val'] != 'Not Logged')
        .length;
    int totalMetrics = displayMetrics.length;

    final String scoreTitle = loggedCount > 0
        ? "Wellness Score: ${((loggedCount / totalMetrics) * 100).round()}%"
        : "Wellness Score: Not Logged";
    final String scoreSubtitle = loggedCount > 0
        ? "Calculated from $loggedCount of $totalMetrics selected onboarding habit(s) today"
        : "Log today's symptoms to generate your score";

    final List<String> loggedNames = displayMetrics
        .where((m) => m['val'] != 'Not Logged')
        .map((m) => m['label'].toString().toLowerCase())
        .toList();

    final String quoteText = loggedCount > 0
        ? "\"You have logged $loggedCount selected wellness habit(s) today (${loggedNames.join(', ')}). Keep logging daily to track your long-term health pattern.\""
        : "\"No lifestyle data logged for today yet. Use Log Symptoms to record your selected sleep, mood, energy, and hydration choices.\"";

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
              SectionHeading("MY WELLNESS"),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).dashDailyLifestyleOverview,
                style: GoogleFonts.manrope(
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
            borderRadius: BorderRadius.circular(12),
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
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scoreSubtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: BlushyColors.secondaryText,
                        ),
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
                      child: _buildMetricLabel(
                        m['label'] as String,
                        m['val'] as String,
                      ),
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
                  border: Border.all(
                    color: const Color(0xFFF3E4DD),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  quoteText,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: BlushyColors.secondaryText,
                  ),
                ),
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // CYCLE OVERVIEW (COMPACT SECONDARY CARD)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: BlushyColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: BlushyColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context).dashCycleOverview,
                          style: GoogleFonts.manrope(
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
                        Expanded(
                          child: _buildMetricLabel(
                            "Last Period",
                            lastPeriodStr,
                          ),
                        ),
                        Expanded(
                          child: _buildMetricLabel("Cycle Day", cycleDayStr),
                        ),
                        Expanded(
                          child: _buildMetricLabel(
                            "Next Period",
                            nextPeriodStr,
                          ),
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.of(context).dashTodaySCheck,
                        style: GoogleFonts.manrope(
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
                        _showArticleDialog(
                          context,
                          "Wellness History",
                          "Your logged check-in history:\n- Sleep: ${sleepVal ?? 'Not Logged'}\n- Hydration: ${hydrationVal ?? 'Not Logged'}\n- Mood: ${moodVal ?? 'Not Logged'}\n- Weight: ${_loggedWeight != null ? '${_loggedWeight!.toStringAsFixed(1)} kg' : 'Not Logged'}",
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(color: BlushyColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context).dashViewWellnessHistory,
                        style: GoogleFonts.manrope(
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
  Widget _buildWellnessCheckIn() => _buildLogAndCheckIn();

  // --- SECTION 4: DOCSY INSIGHTS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildWellnessInsights() {
    return const RealInsightsList(title: 'What your logs show');
  }

  // --- SECTION 5: TODAY'S PLAN ---
  /// The real care plan, which already handles empty, restricted and
  /// safety-suppressed states. This used to be a fixed list of suggestions
  /// with a hardcoded personal target ("2.2L today").
  Widget _buildWellnessPlan() {
    return _buildCarePlanSection(heading: "TODAY'S PLAN");
  }

  // --- SECTION 6: DISCOVER ---

  // --- SECTION 7: COMMUNITY ---

  // --- SECTION 8: MY HABITS ---
  Widget _buildWellnessHabitCards() {
    final List<String> userGoals = List<String>.from(
      _onboardingData['goals'] ?? [],
    );
    final List<String> userSymptoms = List<String>.from(
      _onboardingData['symptoms'] ?? [],
    );
    final Set<String> activeFilters = {
      ...userGoals,
      ...userSymptoms,
    }.map((e) => e.toLowerCase()).toSet();

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
        "detail":
            "Consistent sleep cycles allow cells to repair, helping regulate daily cortisol and energy spikes naturally.",
      },
      {
        "title": "Hydration",
        "key": "hydration",
        "desc": hydrationDesc,
        "detail":
            "Proper hydration keeps tissues lubricated, supports kidney filterings, and buffers afternoon headaches.",
      },
      {
        "title": "Movement",
        "key": "movement",
        "desc": movementDesc,
        "detail":
            "Establishing a minimum steps target supports vascular elasticity and promotes evening sleep depth.",
      },
      {
        "title": "Mood Balance",
        "key": "mood",
        "desc": moodDesc,
        "detail":
            "Tracking daily emotional changes builds body awareness and highlights phase-based mood trends.",
      },
      if (_loggedWeight != null ||
          activeFilters.any((f) => f.contains('weight')))
        {
          "title": "Weight",
          "key": "weight",
          "desc": weightDesc,
          "detail":
              "Logging weight trends provides contextual insights into hydration shifts and metabolic rhythms.",
        },
      {
        "title": "Mindfulness",
        "key": "mindfulness",
        "desc": "\"Mindfulness and breathing routines active.\"",
        "detail":
            "Slow exhalations trigger active vagal parasympathetic states, helping calm mind stressors.",
      },
      {
        "title": "Nutrition",
        "key": "nutrition",
        "desc": "\"Maintained healthy balanced meals today.\"",
        "detail":
            "High-protein balanced breakfasts keep morning glucose spikes flat, preventing post-lunch fatigue lapses.",
      },
    ];

    List<Map<String, String>> habitCards = allHabitCards;
    if (activeFilters.isNotEmpty) {
      final filtered = allHabitCards.where((card) {
        final key = card['key']!;
        return activeFilters.any(
          (f) =>
              f.contains(key) ||
              (key == 'sleep' && f.contains('sleep')) ||
              (key == 'hydration' && f.contains('water')),
        );
      }).toList();
      if (filtered.isNotEmpty) {
        habitCards = filtered;
      }
    }

    final cards = habitCards.map((card) {
      return Container(
        padding: const EdgeInsets.all(BlushySpace.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF7D8DD), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card['title']!.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: BlushyColors.primary,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card['desc']!,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: BlushyColors.text,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card['detail']!,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                color: const Color(0xFF7A6B72),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _showArticleDialog(
                      context,
                      card['title']!,
                      card['detail']!,
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    AppLocalizations.of(context).dashLearnMore,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();

    return AutoCarouselCards(
      categoryEyebrow: "MY HABITS",
      cards: cards,
      height: 195.0,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width < 768
                        ? 640
                        : double.infinity,
                  ),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    children: [
                      _buildBranchSwitcher(state),
                      const SizedBox(height: 32),
                      _buildLivingTodayCycle(),
                      const SizedBox(height: 32),
                      _buildWellnessDashboard(),
                      const SizedBox(height: 32),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 32),
                      _buildLivingPatterns(),
                      const SizedBox(height: 32),
                      _buildWellnessInsights(),
                      const SizedBox(height: 32),
                      _buildWellnessHabitCards(),
                      const SizedBox(height: 32),
                      _buildWellnessPlan(),
                      const SizedBox(height: 32),
                      _buildWellnessJourney(),
                      const SizedBox(height: 32),
                      _buildWellnessReflection(),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Scaffold(
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    children: [
                      _buildWellnessCheckIn(),
                      const SizedBox(height: 48),
                      _buildWellnessDashboard(),
                      const SizedBox(height: 48),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 48),
                      _buildLivingPatterns(),
                      const SizedBox(height: 48),
                      _buildWellnessInsights(),
                      const SizedBox(height: 48),
                      _buildWellnessHabitCards(),
                      const SizedBox(height: 48),
                      _buildWellnessPlan(),
                      const SizedBox(height: 48),
                      _buildWellnessJourney(),
                      const SizedBox(height: 48),
                      _buildWellnessReflection(),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Scaffold(
            backgroundColor: BlushyColors.background,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 40,
                  ),
                  child: ListView(
                    controller: _wellnessHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildWellnessCheckIn(),
                      const SizedBox(height: 24),
                      _buildWellnessDashboard(),
                      const SizedBox(height: 24),
                      _buildLivingSiaInsights(),
                      const SizedBox(height: 24),
                      _buildLivingPatterns(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildWellnessInsights(),
                                const SizedBox(height: 48),
                                _buildWellnessHabitCards(),
                                const SizedBox(height: 48),
                                _buildWellnessPlan(),
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


/// The way through to the full log, at the foot of the signals card.
///
/// Quiet: a tint rather than a fill. It is a second way to somewhere the red
/// banner above already leads, so it must not compete with it.
class _ViewFullLogButton extends StatelessWidget {
  const _ViewFullLogButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Red with white text, like every button.
    return Material(
      color: BlushyColors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: BlushySpace.tapHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bar_chart_rounded,
                  size: 16, color: Colors.white),
              const SizedBox(width: BlushySpace.sm),
              Text(
                'View Full Log',
                style: BlushyType.body(
                  color: Colors.white,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
