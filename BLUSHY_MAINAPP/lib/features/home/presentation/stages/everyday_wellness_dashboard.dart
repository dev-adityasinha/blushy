import 'dart:async';
// Dynamic dashboard generated for stage: everyday_wellness
import 'package:flutter/material.dart';

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
import '../../../../services/api_sia_service.dart';
import '../../../../shared/api_state_card.dart';
import '../doctor_summary_screen.dart';
import '../../../../models/blushy_models.dart';
import '../../../sia/open_docsy.dart';
import '../../home_screen.dart';
import '../../../../shared/section_heading.dart';
import '../../blushy_shell.dart';
import '../../widgets/home_sections.dart';
import '../../widgets/home_hero.dart';
import '../../widgets/greeting_card.dart' show GreetingCard;
import '../../widgets/home_insight_cards.dart';
import '../../widgets/monthly_journey_card.dart';
import '../../../../theme/scale.dart';
import '../../home_section_order.dart';
import '../../../../core/stage_reconcile.dart';

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

  // Symptoms the PCOS branch asks about. They were asked, stored, and had no
  // card to land on, so answering changed nothing on the home page.
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

  /// The life stage the dashboard is rendering.
  ///
  /// The precedence is the one the stage switch has always used: an explicit
  /// key from the caller, then the first active stage, then the stored profile
  /// or onboarding answers. Declared once so the symptoms sheet cannot resolve
  /// it differently and offer a set of groups that does not match the stage.

  /// A stage home's sections in the order she asked for at onboarding.
  ///
  /// The wizard's "what would you like help with" and "which of these do
  /// you notice" picks were stored and never read: every home rendered
  /// its sections in one fixed order. Sections about what she picked now
  /// come first; see [HomeSectionOrder].
  List<Widget> _orderedHome(List<HomeSection> sections, {required Widget gap}) {
    List<String> picks(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty) return [v];
      return const <String>[];
    }

    // Read live rather than from the copy taken at start-up: a stage switch
    // writes its picks to storage and this home is already on screen.
    Map<String, dynamic> profile;
    try {
      final data = BlushyStorage.read('user_profile.json');
      final p = data['profile'];
      profile = p is Map ? Map<String, dynamic>.from(p) : Map<String, dynamic>.from(data);
    } catch (_) {
      profile = _onboardingData;
    }

    // The picks made for the stage on screen come first. They are stored
    // per stage by the stage-switch questionnaire, so a woman who moved
    // from cycle tracking to pregnancy is not ordered by her cycle picks.
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

  String _resolveStageKey(PersonalContext pc) {
    if (widget.stageKey != null && widget.stageKey!.isNotEmpty) {
      return widget.stageKey!;
    }
    // The stage she chose last, while it is still active; the ranking only
    // decides when nothing was chosen or the choice is gone.
    final active = currentStageOf(widget.activeStages ?? pc.activeLifeStages, pc.lifeStage);
    return (active ??
            (pc.lifeStage ??
                _onboardingData['lifeStage'] ??
                _onboardingData['life_stage'] ??
                _onboardingData['stage'] ??
                'firstPeriodNotStarted'))
        .toString()
        .trim();
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
      key: _checkInKey,
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
                _buildCheckinPrompt()
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

  /// Shown before anything is logged, pointing at the one place to do it.
  Widget _buildCheckinPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nothing logged yet today.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Log today\'s symptoms and this fills in with what is worth asking.',
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
              "Log today's symptoms",
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The questions today's symptoms earn, if any.
  ///
  /// Empty on a day with nothing logged, so the check-in stays as short as it
  /// was. The rules are in [CheckinFollowUps] rather than here so they can be
  /// tested without building this widget.
  /// Docsy's cards for today's symptoms, when she has written them.
  ///
  /// Asked once per set of symptoms per day and kept in today's check-in
  /// file, so the cards are the same on every open and an answer given to
  /// one can be read back by id. When Docsy has nothing (offline, a reply
  /// that failed the contract), the rule table asks instead.
  List<CheckinFollowUp>? _docsyFollowUps;
  String? _docsyFollowUpsKey;
  bool _docsyFollowUpsLoading = false;

  String _docsyFollowUpsKeyFor(Iterable<String> labels) {
    final sorted = labels.map((l) => l.trim().toLowerCase()).where((l) => l.isNotEmpty).toList()..sort();
    return '${_todayKey()}|${sorted.join(',')}';
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Today's cards from the check-in file, if they were written for the
  /// same symptoms.
  List<CheckinFollowUp>? _storedDocsyFollowUps(String key) {
    try {
      final stored = BlushyStorage.read('daily_checkin.json')['docsy_followups'];
      if (stored is Map && stored['key'] == key && stored['cards'] is List) {
        return [
          for (final c in stored['cards'] as List)
            if (c is Map) CheckinFollowUp.fromJson(Map<String, dynamic>.from(c)),
        ];
      }
    } catch (_) {}
    return null;
  }

  void _refreshDocsyFollowUps() {
    final labels = _loggedLabels.toList();
    final key = _docsyFollowUpsKeyFor(labels);
    if (_docsyFollowUpsKey == key) return;
    final stored = _storedDocsyFollowUps(key);
    if (stored != null) {
      setState(() {
        _docsyFollowUpsKey = key;
        _docsyFollowUps = stored;
      });
      return;
    }
    if (labels.isEmpty || _docsyFollowUpsLoading) {
      _docsyFollowUpsKey = key;
      _docsyFollowUps = null;
      return;
    }
    _docsyFollowUpsLoading = true;
    ApiSiaService()
        .getCheckinFollowUps(symptoms: labels, date: _todayKey(), stage: _resolveStageKey(_currentPc))
        .then((result) {
      if (!mounted) return;
      final cards = CheckinFollowUps.fromModel(result['cards']);
      // Still today's symptoms? Otherwise the answer is for a set she has
      // since changed, and the next refresh asks again.
      if (_docsyFollowUpsKeyFor(_loggedLabels) != key) return;
      try {
        final checkin = BlushyStorage.read('daily_checkin.json');
        checkin['docsy_followups'] = {
          'key': key,
          'cards': [for (final c in cards) c.toJson()],
        };
        BlushyStorage.write('daily_checkin.json', checkin);
      } catch (_) {}
      setState(() {
        _docsyFollowUpsKey = key;
        _docsyFollowUps = cards.isEmpty ? null : cards;
      });
    }).whenComplete(() => _docsyFollowUpsLoading = false);
  }

  Widget _buildGeneratedFollowUps() {
    final docsy = _docsyFollowUps;
    final source = docsy != null && docsy.isNotEmpty && _docsyFollowUpsKey == _docsyFollowUpsKeyFor(_loggedLabels)
        ? docsy
        : CheckinFollowUps.forSymptoms(_loggedLabels);
    final cards = source
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
        (c) => c!.metric == mapped.key && c.options.contains(mapped.value),
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
      onSave: (picked) {
        _persistCheckinSymptoms(picked);
        _refreshDocsyFollowUps();
      },
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
    // Docsy's check-in cards for whatever is already logged today.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshDocsyFollowUps();
    });
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

    // With several stages active the home is the dominant stage's own, as
    // it is with one. It used to be a composite -- a "focus topic" header
    // per stage over a generic list -- which read as a broken page.
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

  // --- FIRST PERIODS OS REDESIGN ---

  // --- SECTION 1: DOCSY'S DAILY LETTER (HERO) ---
  Widget _buildSiasDailyLetter(String name) {
    return _buildUnifiedHeroCard(
      category: "Docsy's Daily Note",
      title: "${_getTimeBasedGreetingPrefix()}, $name",
      subtitle:
          "Growing up happens one step at a time. You don't have to know everything today. We'll learn together.",
      primaryBtnText: "Ask Docsy",
      onPrimaryTap: () => _openAskSiaChat(context, null),
      secondaryBtnText: "Continue Learning",
      onSecondaryTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).dashScrollDownContinueLearning,
            ),
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
    openDocsyWith(context, initialQuestion);
  }

  late final ScrollController _homeScrollController = ScrollController();

  Widget _buildNotStartedHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty)
        ? pc.userName!
        : "there";

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
                    ..._orderedHome([
                      HomeSection('checkin', _buildSiasDailyLetter(displayName), pinned: true),
                      HomeSection('checkin', _buildCheckIn(), pinned: true),
                      HomeSection('insights', _buildLivingSiaInsights()),
                      HomeSection('patterns', _buildLivingPatterns()),
                      HomeSection('partner', _buildConnect()),
                      HomeSection('learn', _buildContinueLearning()),
                      HomeSection('learn', _buildCuriousToday()),
                      HomeSection('journey', _buildGrowingJourney()),
                    ], gap: const SizedBox(height: 32)),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 36,
                  ),
                  children: [
                    ..._orderedHome([
                      HomeSection('checkin', _buildSiasDailyLetter(displayName), pinned: true),
                      HomeSection('checkin', _buildCheckIn(), pinned: true),
                      HomeSection('insights', _buildLivingSiaInsights()),
                      HomeSection('patterns', _buildLivingPatterns()),
                      HomeSection('partner', _buildConnect()),
                      HomeSection('learn', _buildContinueLearning()),
                      HomeSection('learn', _buildCuriousToday()),
                      HomeSection('journey', _buildGrowingJourney()),
                    ], gap: const SizedBox(height: 48)),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 40,
                ),
                child: ListView(
                  controller: widget.isNested ? null : _homeScrollController,
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  children: [
                    // Row 1: Docsy Daily Letter (12 columns)
                    _buildSiasDailyLetter(displayName),
                    const SizedBox(height: 24),
                    ..._orderedHome([
                      HomeSection('checkin', _buildCheckIn()),
                      HomeSection('insights', _buildLivingSiaInsights()),
                      HomeSection('patterns', _buildLivingPatterns()),
                    ], gap: const SizedBox(height: 32)),
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
                        Expanded(flex: 35, child: _buildGrowingJourney()),
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
                    style: GoogleFonts.manrope(
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
                style: GoogleFonts.manrope(
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
                  style: GoogleFonts.manrope(
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
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: onPrimaryTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      primaryBtnText,
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (secondaryBtnText != null && onSecondaryTap != null) ...[
                    OutlinedButton(
                      onPressed: onSecondaryTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.primary,
                        side: const BorderSide(
                          color: BlushyColors.primary,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        secondaryBtnText,
                        style: GoogleFonts.manrope(
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

  // --- SECTION 1: DOCSY'S LETTER (HERO) ---

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
              SectionHeading("MY FIRST CYCLES"),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).dashLearningCycleCompanion,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final curPc = BlushyOSProvider.of(
                          context,
                        ).personalContext;
                        final DateTime? pStart = curPc.lastPeriodStart;
                        final int cycleDay = (pStart != null)
                            ? (DateTime.now().difference(pStart).inDays + 1)
                            : (curPc.cycleDay ?? 1);
                        final int daysAgo = (pStart != null)
                            ? DateTime.now().difference(pStart).inDays
                            : (cycleDay > 0 ? cycleDay - 1 : 0);
                        final bool hasData =
                            pStart != null ||
                            (curPc.cycleDay != null && curPc.cycleDay! > 0);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasData
                                  ? "Day $cycleDay of Cycle"
                                  : "Cycle Tracking",
                              style: GoogleFonts.manrope(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: BlushyColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasData
                                  ? "$daysAgo days since last period start"
                                  : "No period logged yet",
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: BlushyColors.secondaryText,
                              ),
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
              FittedBox(fit: BoxFit.scaleDown, child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ..._orderedHome([
                    HomeSection('other', _buildStartedLegendDot("Menstrual", BlushyColors.primary)),
                    HomeSection('other', _buildStartedLegendDot("Follicular", const Color(0xFFFF9B9E))),
                    HomeSection('other', _buildStartedLegendDot("Ovulation", const Color(0xFFFFB800))),
                    HomeSection('other', _buildStartedLegendDot("Luteal", BlushyColors.accent)),
                  ], gap: const SizedBox(width: 14)),
                ],
              )),
              const SizedBox(height: 32),

              // Calendar Preview of the last 30 days
              Text(
                AppLocalizations.of(context).dashPastDays,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: 30,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final int day = index + 1;
                    final curPc = BlushyOSProvider.of(context).personalContext;
                    final int activeCycleDay = (curPc.lastPeriodStart != null)
                        ? (DateTime.now()
                                  .difference(curPc.lastPeriodStart!)
                                  .inDays +
                              1)
                        : (curPc.cycleDay ?? 1);
                    final bool isMenstrual = day <= activeCycleDay && day <= 5;
                    return Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isMenstrual
                            ? BlushyColors.primary
                            : const Color(0xFFF9F6F0),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: BlushyColors.border,
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          day.toString(),
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isMenstrual
                                ? Colors.white
                                : BlushyColors.text,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: BlushyColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).dashSCompletelyNormalFirst,
                        style: GoogleFonts.manrope(
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
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.manrope(
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
      {"icon": "😌", "label": "Calm"},
      {"icon": "😔", "label": "Low"},
      {"icon": "😤", "label": "Irritable"},
    ];

    final List<String> energyOptions = CheckinVocabulary.energy;
    final List<String> flowOptions = CheckinVocabulary.flow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading(
            AppLocalizations.of(context).dashHowAreYouToday,
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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
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
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Energy Selector
              Text(
                AppLocalizations.of(context).dashEnergyLevel,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: energyOptions.map((opt) {
                  final checkinData = BlushyStorage.read('daily_checkin.json');
                  final savedEnergy =
                      checkinData['energy'] ??
                      (BlushyStorage.read('logged_energy.json'))['energy'];
                  final wb = BlushyOSProvider.of(context).wellbeingState;
                  final String? activeEnergy =
                      _selectedEnergy ??
                      savedEnergy ??
                      (wb.energy != null
                          ? (wb.energy! >= 7
                                ? 'High'
                                : (wb.energy! >= 4 ? 'Medium' : 'Low'))
                          : null);
                  final isSelected =
                      activeEnergy != null &&
                      activeEnergy.toString().toLowerCase() ==
                          opt.toLowerCase();
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
                              color: isSelected
                                  ? Colors.white
                                  : BlushyColors.text,
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
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                ),
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
                              color: isSelected
                                  ? Colors.white
                                  : BlushyColors.text,
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
                        // The tab, not a second copy of it stacked on top.
                        BlushyShellTabs.open(BlushyShellTabs.mStudio);
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

  // --- SECTION 4: UNDERSTAND MY CYCLE (Educational carousel) ---
  Widget _buildUnderstandMyCycle() {
    final List<Map<String, String>> startedArticles = [
      {
        "q": "Why are my cycles irregular?",
        "body":
            "It takes time for the brain and ovaries to coordinate hormones after your very first period. Cycles can range from 20 to 45 days, and skipping months is very common during the first two years.",
      },
      {
        "q": "What is PMS?",
        "body":
            "Premenstrual Syndrome is the mix of physical and emotional changes that happen before your period. Feeling mood swings, mild bloating, or breast tenderness is normal as hormone levels shift.",
      },
      {
        "q": "How do cramps happen?",
        "body":
            "Cramps are caused by natural chemicals called prostaglandins that make your uterus muscles contract to shed its lining. Placing a warm pad or doing light stretches can relax the muscles.",
      },
      {
        "q": "Why am I tired?",
        "body":
            "Hormones like progesterone rise before your period, which can lower your energy levels. Sleeping 8-9 hours and staying active helps normalize your daily energy cycle.",
      },
      {
        "q": "How long should periods last?",
        "body":
            "A normal period lasts between 3 to 7 days. The flow is usually heavier on the first two days and gets much lighter toward the end. Tracking helps you learn your pattern.",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("UNDERSTAND MY CYCLE"),
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
                  borderRadius: BorderRadius.circular(12),
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
                        style: GoogleFonts.manrope(
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
                            _showArticleDialog(
                              context,
                              item['q']!,
                              item['body']!,
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
                            _startedSavedArticles.contains(item['q'])
                                ? Icons.bookmark
                                : Icons.bookmark_border,
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
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: BlushyColors.secondaryText,
                          ),
                          onPressed: () => _openAskSiaChat(
                            context,
                            "Tell me about: ${item['q']}",
                          ),
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
          child: SectionHeading("CONNECT"),
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
                      color: _connectStartedTabIndex == 0
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
                        color: _connectStartedTabIndex == 0
                            ? BlushyColors.text
                            : BlushyColors.secondaryText,
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
                      color: _connectStartedTabIndex == 1
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
                        color: _connectStartedTabIndex == 1
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
        _connectStartedTabIndex == 0
            ? _buildStartedGirlsTab()
            : _buildStartedGrowingTogetherTab(),
      ],
    );
  }

  Widget _buildStartedGirlsTab() {
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
            AppLocalizations.of(context).dashCommunityDiscussionsStories,
            style: GoogleFonts.manrope(
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
                      AppLocalizations.of(context).dashQuestionsPeopleAreAsking,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).dashOpenCommunityReadReply,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.favorite_border,
                size: 16,
                color: Colors.pinkAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).dashTipsPeopleAreSharing,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).dashOpenCommunityReadReply,
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
              // Switches to the Community tab rather than announcing that it
              // is about to. This showed a "Loading Community discussions..."
              // snackbar and then did nothing at all -- the card above it says
              // "Open the community to read and reply" twice, so the one
              // control that would do that was the only part that did not
              // work.
              onPressed: () => BlushyShellTabs.open(BlushyShellTabs.community),
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                AppLocalizations.of(context).dashOpenDiscussions,
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

  Widget _buildStartedGrowingTogetherTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shared reading & notes
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
                AppLocalizations.of(context).dashSharedReadingParentResources,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).dashSendCycleArticlesParent,
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
                              ).dashArticleSharedParent,
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
                        AppLocalizations.of(context).dashShare,
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
                              ).dashOpeningParentResourceLibrary,
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
                        AppLocalizations.of(context).dashGuides,
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

        // Conversation Prompt
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
                AppLocalizations.of(context).dashConversationPrompt,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.warning,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "\"Is there anything you wish we discussed more about body changes?\"",
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
                        _startedLetsTalkDiscussed = !_startedLetsTalkDiscussed;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _startedLetsTalkDiscussed
                          ? BlushyColors.success
                          : BlushyColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _startedLetsTalkDiscussed ? "Discussed " : "Discussed",
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
                        _startedLetsTalkSaved = !_startedLetsTalkSaved;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _startedLetsTalkSaved
                            ? BlushyColors.disabled
                            : BlushyColors.primary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _startedLetsTalkSaved ? "Saved" : "Save for Weekend",
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: _startedLetsTalkSaved
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

        // Shared checklist
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
                  AppLocalizations.of(context).dashFirstPeriodKitStatus,
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: BlushyColors.secondaryText,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                ..._startedPeriodKitChecklist.keys.map((item) {
                  final isChecked = _startedPeriodKitChecklist[item]!;
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
            AppLocalizations.of(context).dashDocsySafetyParentNever,
            style: GoogleFonts.manrope(
              fontSize: 10,
              color: BlushyColors.secondaryText,
              fontStyle: FontStyle.italic,
            ),
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

  Widget _buildFirstPeriodStartedHomeOS(
    PersonalContext pc,
    BlushyOSState state,
  ) {
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
                    ..._orderedHome([
                      HomeSection('cycle', _buildMyFirstCycles(), pinned: true),
                      HomeSection('checkin', _buildHowAreYouToday(), pinned: true),
                      HomeSection('checkin', _buildCheckIn()),
                      HomeSection('insights', _buildLivingSiaInsights()),
                      HomeSection('patterns', _buildLivingPatterns()),
                      HomeSection('partner', _buildStartedConnect()),
                      HomeSection('learn', _buildUnderstandMyCycle()),
                      HomeSection('journey', _buildStartedJourney()),
                    ], gap: const SizedBox(height: 32)),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 36,
                  ),
                  children: [
                    ..._orderedHome([
                      HomeSection('cycle', _buildMyFirstCycles(), pinned: true),
                      HomeSection('checkin', _buildHowAreYouToday(), pinned: true),
                      HomeSection('checkin', _buildCheckIn()),
                      HomeSection('insights', _buildLivingSiaInsights()),
                      HomeSection('patterns', _buildLivingPatterns()),
                      HomeSection('partner', _buildStartedConnect()),
                      HomeSection('learn', _buildUnderstandMyCycle()),
                      HomeSection('journey', _buildStartedJourney()),
                    ], gap: const SizedBox(height: 48)),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 40,
                ),
                child: ListView(
                  controller: widget.isNested
                      ? null
                      : _startedHomeScrollController,
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  children: [
                    ..._orderedHome([
                      HomeSection('cycle', _buildMyFirstCycles(), pinned: true),
                      HomeSection('checkin', _buildHowAreYouToday(), pinned: true),
                      HomeSection('checkin', _buildCheckIn()),
                      HomeSection('insights', _buildLivingSiaInsights()),
                      HomeSection('patterns', _buildLivingPatterns()),
                    ], gap: const SizedBox(height: 24)),
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
                              _buildStartedConnect(),
                              const SizedBox(height: 48),
                              _buildUnderstandMyCycle(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),

                        // Right Sidebar Panel (35% width)
                        Expanded(flex: 35, child: _buildStartedJourney()),
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

  void _showArticleDialog(BuildContext context, String title, String summary, {String? question}) {
    showDialog(
      context: context,
      builder: (dialogContext) =>
          ArticleDetailDialog(title: title, summary: summary, question: question),
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

    final String energyVal =
        _selectedEnergy ??
        savedEnergy ??
        (wb.energy != null ? "Level ${wb.energy}/10" : "Not Logged Today");
    final String moodVal =
        _selectedFeeling ??
        savedMood ??
        (wb.mood != null
            ? (wb.symptoms.isNotEmpty
                  ? wb.symptoms.first
                  : "Level ${wb.mood}/10")
            : "Not Logged Today");
    final String sleepVal = _livingSleep ?? savedSleep ?? "Not Logged Today";
    final String stressVal = _livingStress ?? savedStress ?? "Not Logged Today";
    final String hydrationVal =
        _livingWater ?? savedWater ?? "Not Logged Today";
    final String exerciseVal =
        _livingExercise ?? savedExercise ?? "Not Logged Today";
    final String flowVal = _livingFlow ?? savedFlow ?? "Not Logged Today";
    final String painVal = _livingPain ?? savedPain ?? "Not Logged Today";

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
        const SizedBox(height: BlushySpace.betweenCards),
        LogSymptomsBanner(
          title: hasPeriodLogged
              ? "Log Today's Symptoms"
              : 'Log Period Start Date',
          subtitle: hasPeriodLogged
              ? 'Track how you feel and take care'
              : 'Everything on this page is counted from it',
          onTap: () {
            if (!hasPeriodLogged) {
              _showLogPeriodBottomSheet(context);
            } else {
              _openSymptomSheet();
            }
          },
        ),
        const SizedBox(height: BlushySpace.betweenSections),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BlushySpace.xs),
          child: SectionHeading(
            AppLocalizations.of(context).dashTodaySLoggedSignals,
            icon: Icons.monitor_heart_outlined,
          ),
        ),
        const SizedBox(height: BlushySpace.md),
        LoggedSignalsCard(
          // Opens the same sheet the banner does. That sheet is where the day
          // arrows live, so it is already the full log -- a second screen
          // showing the same thing is how the two drift apart.
          footer: _ViewFullLogButton(onTap: _openSymptomSheet),
          signals: [
            _signal('Energy', energyVal, BlushyColors.primary,
                Icons.bolt_rounded),
            _signal('Mood', moodVal, BlushyColors.accent,
                Icons.sentiment_satisfied_rounded),
            if (_isMetricSelected(
                pc, ['flow', 'period', 'bleeding', 'spotting']))
              _signal('Flow', flowVal, BlushyColors.secondary,
                  Icons.water_drop_rounded),
            if (_isMetricSelected(
                pc, ['pain', 'cramps', 'headache', 'back pain']))
              _signal('Pain', painVal, BlushyColors.primary,
                  Icons.flash_on_rounded),
            if (_isMetricSelected(
                pc, ['sleep', 'insomnia', 'rest', 'fatigue']))
              _signal('Sleep', sleepVal, BlushyColors.secondary,
                  Icons.bedtime_rounded),
            if (_isMetricSelected(
                pc, ['stress', 'anxiety', 'mood swings', 'mental health']))
              _signal('Stress', stressVal, BlushyColors.accent,
                  Icons.spa_rounded),
            _signal('Hydration', hydrationVal, BlushyColors.secondary,
                Icons.local_drink_rounded),
            if (_isMetricSelected(pc,
                ['exercise', 'workout', 'fitness', 'activity', 'walk']))
              _signal('Movement', exerciseVal, BlushyColors.accent,
                  Icons.directions_run_rounded),
          ],
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
  Widget _buildLivingCheckIn() => _buildCheckIn();

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
              Expanded(child: SectionHeading(AppLocalizations.of(context).dashPatternsTitle)),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BlushyColors.border, width: 0.8),
      ),
      child: Text(
        message,
        style: GoogleFonts.manrope(
          fontSize: 13,
          color: BlushyColors.secondaryText,
          height: 1.5,
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
                          style: GoogleFonts.manrope(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: BlushyColors.taupe,
                    borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 12),
            // Observational wording produced by the pattern engine.
            Text(
              insight.description,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: BlushyColors.text,
              ),
            ),
            const SizedBox(height: 8),
            // Real evidence: how many of the logs this was derived from.
            Text(
              _evidenceLine(insight),
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: BlushyColors.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).dashPatternNotDiagnosis,
              style: GoogleFonts.manrope(
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
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
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

  Widget _buildLivingWithMyCycleHomeOS(
    PersonalContext pc,
    BlushyOSState state,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT
          return _wrapDashboardLayout(
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
                    horizontal: 20,
                    vertical: 24,
                  ),
                  children: [
                    ..._orderedHome([
                      HomeSection('cycle', _buildLivingTodayCycle(), pinned: true),
                      HomeSection('checkin', _buildLivingCheckIn(), pinned: true),
                      HomeSection('insights', _buildLivingSiaInsights()),
                      HomeSection('patterns', _buildLivingPatterns()),
                      HomeSection('journey', _buildLivingJourney()),
                    ], gap: const SizedBox(height: 32)),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 36,
                ),
                children: [
                  ..._orderedHome([
                    HomeSection('cycle', _buildLivingTodayCycle(), pinned: true),
                    HomeSection('checkin', _buildLivingCheckIn(), pinned: true),
                    HomeSection('insights', _buildLivingSiaInsights()),
                    HomeSection('patterns', _buildLivingPatterns()),
                    HomeSection('journey', _buildLivingJourney()),
                  ], gap: const SizedBox(height: 48)),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 40,
                ),
                child: ListView(
                  controller: widget.isNested
                      ? null
                      : _livingHomeScrollController,
                  shrinkWrap: _effectiveShrinkWrap,
                  physics: _effectiveScrollPhysics,
                  children: [
                    _buildLivingTodayCycle(),
                    const SizedBox(height: 48),
                    _buildLivingCheckIn(),
                    const SizedBox(height: 48),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Panel (65% width)
                        Expanded(
                          flex: 65,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [_buildLivingSiaInsights()],
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

  // --- SECTION 1: DOCSY'S DAILY BRIEF (HERO) ---

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
              SectionHeading("MY CYCLE HEALTH"),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).dashHormonalRhythmTracker,
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
                                    style: GoogleFonts.manrope(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: BlushyColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cycleData['subtitle'] as String,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: BlushyColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: BlushyColors.primary,
                                size: 20,
                              ),
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
              FittedBox(fit: BoxFit.scaleDown, child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ..._orderedHome([
                    HomeSection('other', _buildStartedLegendDot("Menstrual", BlushyColors.primary)),
                    HomeSection('other', _buildStartedLegendDot("Follicular", const Color(0xFFFF9B9E))),
                    HomeSection('other', _buildStartedLegendDot("Ovulation", const Color(0xFFFFB800))),
                    HomeSection('other', _buildStartedLegendDot("Luteal", BlushyColors.accent)),
                  ], gap: const SizedBox(width: 14)),
                ],
              )),
              const SizedBox(height: 32),

              // Recent Cycle History horizontal blocks
              Text(
                AppLocalizations.of(context).dashRecentCycleHistory,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              const RealCycleHistory(),
              const SizedBox(height: 28),

              // Educational explanation cards instead of direct prediction certainty
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: BlushyColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            // Read "between 38 and 71 days" for everyone. Both
                            // numbers were literals, shown as her own history.
                            "Cycle length varies for many people, and the history above is drawn from what you have logged.",
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: BlushyColors.secondaryText,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFE5DDD5)),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                          color: BlushyColors.warning,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).dashNextPeriodMayArrive,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: BlushyColors.secondaryText,
                              height: 1.45,
                            ),
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
  Widget _buildHormonalCheckIn() => _buildCheckIn();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading("UNDERSTANDING MY PATTERNS"),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).dashAiGeneratedTrendsAcross,
                style: GoogleFonts.manrope(
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BlushyColors.border, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card['title']!,
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card['desc']!,
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card['detail']!,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: BlushyColors.secondaryText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _openAskSiaChat(
                          context,
                          "Explain this pattern: ${card['title']}",
                        ),
                        child: Text(
                          AppLocalizations.of(context).dashAskDocsy,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
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
                  )),
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
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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

  // --- SECTION 7: LEARN ---
  Widget _buildHormonalLearn() {
    final List<String> topics = [
      "Understanding PCOS",
      "Understanding Endometriosis",
      "Understanding PMDD",
      "Understanding Irregular Cycles",
      "Hormones Explained",
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
              final isSelected = _hormonalDiscoverTopic == topic;
              return GestureDetector(
                onTap: () => setState(() => _hormonalDiscoverTopic = topic),
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
            final isSaved = _hormonalSavedArticles.contains(article['title']);
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
                                _hormonalSavedArticles.remove(
                                  article['title']!,
                                );
                              } else {
                                _hormonalSavedArticles.add(article['title']!);
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
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subheading,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: BlushyColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: ApiStateCard<Timeline>(
            result: _timelineResult,
            onRetry: _loadTimeline,
            emptyMessage: AppLocalizations.of(context).dashNothingLoggedYet,
            emptyActionLabel: AppLocalizations.of(context).dashLogFirstCheckIn,
            insufficientDataActionLabel: AppLocalizations.of(
              context,
            ).dashLogTodayCheckIn,
            onEmptyAction: _scrollToCheckIn,
            builder: (context, timeline) {
              if (_timelineEntries.isEmpty) {
                return Text(
                  AppLocalizations.of(context).dashNothingLoggedYet,
                  style: GoogleFonts.manrope(
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
                      isLast:
                          index == _timelineEntries.length - 1 &&
                          !_timelineHasMore,
                    );
                  }),
                  if (_timelineHasMore)
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _timelineLoadingMore
                            ? null
                            : () => _loadTimeline(append: true),
                        child: Text(
                          _timelineLoadingMore
                              ? "Loading..."
                              : "Load earlier entries",
                          style: GoogleFonts.manrope(
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
              style: GoogleFonts.manrope(
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
                        style: GoogleFonts.manrope(
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
                        AppLocalizations.of(context).dashDerived,
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          color: BlushyColors.secondaryText,
                        ),
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
    return _buildTimelineSection(
      heading: "PAST JOURNEY TIMELINE",
      subheading: "Chronological record of what you have logged",
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildHormonalJourney() {
    return _buildLivingJourney();
  }

  Widget _buildHormonalHealthHomeOS(PersonalContext pc, BlushyOSState state) {
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
                      ..._orderedHome([
                        HomeSection('cycle', _buildHormonalCycleHealth(), pinned: true),
                        HomeSection('checkin', _buildHormonalCheckIn(), pinned: true),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildHormonalSiaInsights()),
                        HomeSection('patterns', _buildHormonalPatterns()),
                        HomeSection('condition', _buildConditionProfileCard()),
                        HomeSection('appointments', _buildAppointmentSummaryCard()),
                        HomeSection('careplan', _buildHormonalCarePlan()),
                        HomeSection('learn', _buildHormonalLearn()),
                        HomeSection('timeline', _buildHormonalTimeline()),
                        HomeSection('journey', _buildHormonalJourney()),
                      ], gap: const SizedBox(height: 32)),
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
                      ..._orderedHome([
                        HomeSection('cycle', _buildHormonalCycleHealth(), pinned: true),
                        HomeSection('checkin', _buildHormonalCheckIn(), pinned: true),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildHormonalSiaInsights()),
                        HomeSection('patterns', _buildHormonalPatterns()),
                        HomeSection('condition', _buildConditionProfileCard()),
                        HomeSection('appointments', _buildAppointmentSummaryCard()),
                        HomeSection('careplan', _buildHormonalCarePlan()),
                        HomeSection('learn', _buildHormonalLearn()),
                        HomeSection('timeline', _buildHormonalTimeline()),
                        HomeSection('journey', _buildHormonalJourney()),
                      ], gap: const SizedBox(height: 48)),
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
                    controller: _hormonalHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ..._orderedHome([
                        HomeSection('cycle', _buildHormonalCycleHealth()),
                        HomeSection('checkin', _buildHormonalCheckIn()),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                      ], gap: const SizedBox(height: 24)),
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
                                ..._orderedHome([
                                  HomeSection('insights', _buildHormonalSiaInsights(), pinned: true),
                                  HomeSection('condition', _buildConditionProfileCard(), pinned: true),
                                  HomeSection('appointments', _buildAppointmentSummaryCard()),
                                  HomeSection('careplan', _buildHormonalCarePlan()),
                                  HomeSection('learn', _buildHormonalLearn()),
                                ], gap: const SizedBox(height: 32)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right Sidebar Panel (35% width)
                          Expanded(
                            flex: 35,
                            child: Column(
                              children: [
                                ..._orderedHome([
                                  HomeSection('patterns', _buildHormonalPatterns()),
                                  HomeSection('timeline', _buildHormonalTimeline()),
                                  HomeSection('journey', _buildHormonalJourney()),
                                ], gap: const SizedBox(height: 48)),
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

  // --- SECTION 1: DOCSY'S FERTILITY BRIEF (HERO) ---

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
              SectionHeading("FERTILITY TIMELINE"),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).dashFertilityJourney,
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
                                    style: GoogleFonts.manrope(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: BlushyColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cycleData['subtitle'] as String,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: BlushyColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: BlushyColors.primary,
                                size: 20,
                              ),
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
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                ).dashOvulationLoggedSuccessfully,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BlushyColors.primary,
                          side: const BorderSide(color: BlushyColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).dashLogOvulation,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  FittedBox(fit: BoxFit.scaleDown, child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ..._orderedHome([
                        HomeSection('other', _buildStartedLegendDot("Menstrual", BlushyColors.primary)),
                        HomeSection('other', _buildStartedLegendDot(
                        "Follicular",
                        const Color(0xFFFF9B9E),
                      )),
                        HomeSection('other', _buildStartedLegendDot(
                        "Ovulation",
                        const Color(0xFFFFB800),
                      )),
                        HomeSection('other', _buildStartedLegendDot("Luteal", BlushyColors.accent)),
                      ], gap: const SizedBox(width: 14)),
                    ],
                  )),
                  const SizedBox(height: 32),

                  // Timeline Metrics Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildMetricLabel(
                        "Fertile Window",
                        cycleData['fertileWindow'] as String,
                      )),
                      Expanded(child: _buildMetricLabel(
                        "Expected Period",
                        cycleData['expectedPeriod'] as String,
                      )),
                      Expanded(child: _buildMetricLabel(
                        "Rec. Test Day",
                        cycleData['recTestDay'] as String,
                      )),
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
  Widget _buildTtcCheckIn() => _buildCheckIn();

  // --- SECTION 4: FERTILITY INSIGHTS (AI Observations) ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildTtcInsights() {
    return const RealInsightsList(title: 'What your logs show');
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
      "Understanding Ovulation",
      "Fertile Window",
      "Egg Health",
      "Stress & Fertility",
      "Understanding BBT",
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
              final isSelected = _ttcDiscoverTopic == topic;
              return GestureDetector(
                onTap: () => setState(() => _ttcDiscoverTopic = topic),
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
            final isSaved = _ttcSavedArticles.contains(article['title']);
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
                                _ttcSavedArticles.remove(article['title']!);
                              } else {
                                _ttcSavedArticles.add(article['title']!);
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

  // --- SECTION 7: PARTNER MODE ---
  Widget _buildTtcPartner() {
    final List<Map<String, String>> tasks = [
      {
        "task": "Prepare ovulation test strips in the bathroom.",
        "who": "Partner Task",
      },
      {
        "task": "Incorporate prenatal vitamins with breakfast.",
        "who": "Coordinated Task",
      },
      {
        "task": "Schedule evening relaxing walk together.",
        "who": "Coordinated Task",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SectionHeading("PARTNER MODE"),
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
                  Expanded(child: Text(
                    AppLocalizations.of(context).dashSharedTimelineReminders,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).dashEncouragingMessage,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "\"Every step we take together brings us closer. I'm right here with you today.\"",
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: BlushyColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Divider(height: 32, color: Color(0xFFF5F0EB)),
              Text(
                AppLocalizations.of(
                  context,
                ).dashPartnerTasksConversationStarters,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 1.0,
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

  // --- SECTION 8: MY PATTERNS ---
  /// Server-derived patterns. Replaced a hardcoded list that asserted
  /// findings such as "a 30% drop in intensity" that nobody had measured.
  Widget _buildTtcPatterns() {
    return const RealInsightsList(title: 'Patterns in your logs');
  }

  // --- SECTION 9: JOURNEY TIMELINE ---
  Widget _buildTtcJourneyTimeline() {
    return _buildTimelineSection(
      heading: "YOUR JOURNEY",
      subheading: "Chronological record of what you have logged",
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildTtcMonthlyReflection() {
    return _buildLivingJourney();
  }

  Widget _buildTTCHomeOS(PersonalContext pc, BlushyOSState state) {
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
                      ..._orderedHome([
                        HomeSection('timeline', _buildTtcTimeline(), pinned: true),
                        HomeSection('checkin', _buildTtcCheckIn(), pinned: true),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildTtcInsights()),
                        HomeSection('patterns', _buildTtcPatterns()),
                        HomeSection('partner', _buildTtcPartner()),
                        HomeSection('plan', _buildTtcPlan()),
                        HomeSection('learn', _buildTtcLearn()),
                        HomeSection('timeline', _buildTtcJourneyTimeline()),
                        HomeSection('reflection', _buildTtcMonthlyReflection()),
                      ], gap: const SizedBox(height: 32)),
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
                      ..._orderedHome([
                        HomeSection('timeline', _buildTtcTimeline(), pinned: true),
                        HomeSection('checkin', _buildTtcCheckIn(), pinned: true),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildTtcInsights()),
                        HomeSection('patterns', _buildTtcPatterns()),
                        HomeSection('partner', _buildTtcPartner()),
                        HomeSection('plan', _buildTtcPlan()),
                        HomeSection('learn', _buildTtcLearn()),
                        HomeSection('timeline', _buildTtcJourneyTimeline()),
                        HomeSection('reflection', _buildTtcMonthlyReflection()),
                      ], gap: const SizedBox(height: 48)),
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
                    controller: _ttcHomeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ..._orderedHome([
                        HomeSection('timeline', _buildTtcTimeline()),
                        HomeSection('checkin', _buildTtcCheckIn()),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                      ], gap: const SizedBox(height: 24)),
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
                                ..._orderedHome([
                                  HomeSection('insights', _buildTtcInsights()),
                                  HomeSection('partner', _buildTtcPartner()),
                                  HomeSection('plan', _buildTtcPlan()),
                                  HomeSection('learn', _buildTtcLearn()),
                                ], gap: const SizedBox(height: 48)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right Sidebar Panel (35% width)
                          Expanded(
                            flex: 35,
                            child: Column(
                              children: [
                                ..._orderedHome([
                                  HomeSection('patterns', _buildTtcPatterns()),
                                  HomeSection('timeline', _buildTtcJourneyTimeline()),
                                  HomeSection('reflection', _buildTtcMonthlyReflection()),
                                ], gap: const SizedBox(height: 48)),
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
                                              question: _pregnancyWeek() == null
                            ? "What is happening in my baby's development this week?"
                            : "What is happening in week ${_pregnancyWeek()} of my pregnancy?",
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
  Widget _buildPregnancyCheckIn() => _buildCheckIn();

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
                  Expanded(child: Text(
                    AppLocalizations.of(context).dashPregnancyPrepLists,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  )),
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
                  Expanded(child: Text(
                    AppLocalizations.of(context).dashSharedPregnancyTimeline,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  )),
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
                      ..._orderedHome([
                        HomeSection('baby', _buildPregnancyBabyThisWeek(), pinned: true),
                        HomeSection('checkin', _buildPregnancyCheckIn(), pinned: true),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildPregnancyInsights()),
                        HomeSection('partner', _buildPregnancyPartner()),
                        HomeSection('timeline', _buildPregnancyJourneyTimeline()),
                        HomeSection('careplan', _buildPregnancyCarePlan()),
                        HomeSection('appointments', _buildAppointmentSummaryCard()),
                        HomeSection('prep', _buildPregnancyPrep()),
                        HomeSection('learn', _buildPregnancyLearn()),
                        HomeSection('journey', _buildPregnancyJourney()),
                        HomeSection('reflection', _buildPregnancyReflection()),
                      ], gap: const SizedBox(height: 32)),
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
                      ..._orderedHome([
                        HomeSection('baby', _buildPregnancyBabyThisWeek(), pinned: true),
                        HomeSection('checkin', _buildPregnancyCheckIn(), pinned: true),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildPregnancyInsights()),
                        HomeSection('partner', _buildPregnancyPartner()),
                        HomeSection('timeline', _buildPregnancyJourneyTimeline()),
                        HomeSection('careplan', _buildPregnancyCarePlan()),
                        HomeSection('appointments', _buildAppointmentSummaryCard()),
                        HomeSection('prep', _buildPregnancyPrep()),
                        HomeSection('learn', _buildPregnancyLearn()),
                        HomeSection('journey', _buildPregnancyJourney()),
                        HomeSection('reflection', _buildPregnancyReflection()),
                      ], gap: const SizedBox(height: 48)),
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
                      ..._orderedHome([
                        HomeSection('checkin', _buildPregnancyCheckIn()),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                      ], gap: const SizedBox(height: 24)),
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
                                ..._orderedHome([
                                  HomeSection('insights', _buildPregnancyInsights(), pinned: true),
                                  HomeSection('partner', _buildPregnancyPartner(), pinned: true),
                                  HomeSection('careplan', _buildPregnancyCarePlan()),
                                  HomeSection('appointments', _buildAppointmentSummaryCard()),
                                  HomeSection('prep', _buildPregnancyPrep()),
                                  HomeSection('learn', _buildPregnancyLearn()),
                                ], gap: const SizedBox(height: 48)),
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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
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
                  Expanded(child: Text(
                    AppLocalizations.of(context).dashMotherBabyCoordinatedTasks,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  )),
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
                      Flexible(
                        child: Text(
                          c['val']!,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
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
                      ..._orderedHome([
                        HomeSection('timeline', _buildPostpartumRecoveryTimeline(), pinned: true),
                        HomeSection('wellbeing', _buildPostpartumWellbeing(), pinned: true),
                        HomeSection('checkin', _buildCheckIn()),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildPostpartumInsights()),
                        HomeSection('careplan', _buildPostpartumCarePlan()),
                        HomeSection('appointments', _buildAppointmentSummaryCard()),
                        HomeSection('baby', _buildPostpartumBabyAndYou()),
                        HomeSection('learn', _buildPostpartumLearn()),
                        HomeSection('journey', _buildPostpartumJourney()),
                        HomeSection('reflection', _buildPostpartumReflection()),
                      ], gap: const SizedBox(height: 32)),
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
                      ..._orderedHome([
                        HomeSection('timeline', _buildPostpartumRecoveryTimeline(), pinned: true),
                        HomeSection('wellbeing', _buildPostpartumWellbeing(), pinned: true),
                        HomeSection('checkin', _buildCheckIn()),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildPostpartumInsights()),
                        HomeSection('careplan', _buildPostpartumCarePlan()),
                        HomeSection('appointments', _buildAppointmentSummaryCard()),
                        HomeSection('baby', _buildPostpartumBabyAndYou()),
                        HomeSection('learn', _buildPostpartumLearn()),
                        HomeSection('journey', _buildPostpartumJourney()),
                        HomeSection('reflection', _buildPostpartumReflection()),
                      ], gap: const SizedBox(height: 48)),
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
                      ..._orderedHome([
                        HomeSection('timeline', _buildPostpartumRecoveryTimeline(), pinned: true),
                        HomeSection('wellbeing', _buildPostpartumWellbeing(), pinned: true),
                        HomeSection('checkin', _buildCheckIn()),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                      ], gap: const SizedBox(height: 24)),
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
                                ..._orderedHome([
                                  HomeSection('insights', _buildPostpartumInsights(), pinned: true),
                                  HomeSection('careplan', _buildPostpartumCarePlan(), pinned: true),
                                  HomeSection('appointments', _buildAppointmentSummaryCard()),
                                  HomeSection('baby', _buildPostpartumBabyAndYou()),
                                  HomeSection('learn', _buildPostpartumLearn()),
                                ], gap: const SizedBox(height: 48)),
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
    // These two lines read "Cycle Day 47" and "Last Period: 47 Days Ago" for
    // everyone, regardless of what they had logged. `pc` was already in scope
    // and carries the real dates; nothing was reading it.
    final DateTime? periStart = pc.lastPeriodStart;
    final int? periDaysSince = periStart == null
        ? null
        : DateTime.now().difference(periStart).inDays;
    final List<int> recentCycles = [31, 45, 62, 39, 54];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading("MY CHANGING CYCLE"),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).dashTransitionTrackingHistory,
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
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: BlushyColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                periDaysSince == null
                                    // Saying so beats inventing a number for
                                    // someone tracking an irregular cycle.
                                    ? "Log a period start date to see this"
                                    : "Last period: $periDaysSince days ago",
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: BlushyColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: BlushyColors.primary,
                            size: 20,
                          ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: BlushyColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      // "Highly Variable" was asserted to everyone. It is a
                      // description of her cycle, and nothing had measured it.
                      periDaysSince == null ? "Tracking" : "In transition",
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.primary,
                      ),
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
                      style: GoogleFonts.manrope(
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
                      style: GoogleFonts.manrope(
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
              FittedBox(fit: BoxFit.scaleDown, child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ..._orderedHome([
                    HomeSection('other', _buildStartedLegendDot("Period", const Color(0xFFC78280))),
                    HomeSection('other', _buildStartedLegendDot("Follicular", const Color(0xFFE2B7A8))),
                    HomeSection('other', _buildStartedLegendDot(
                    "Luteal/Late",
                    const Color(0xFFE8987E),
                  )),
                  ], gap: const SizedBox(width: 12)),
                ],
              )),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              Text(
                AppLocalizations.of(context).dashRecentCycleHistory,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: recentCycles.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final cycleLen = recentCycles[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: BlushyColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: BlushyColors.border,
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "$cycleLen Days",
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
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
                  border: Border.all(
                    color: const Color(0xFFF3E4DD),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  // This claimed to have noticed a trend across her recent
                  // months. Nothing had analysed anything; it was a fixed
                  // sentence shown to everyone in this stage.
                  "Cycles often become less predictable during the perimenopause transition. What you log here builds your own picture over time.",
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
                      onPressed: () {
                        // Opens the real logging sheet. This used to show
                        // "Period Logged (Simulated)" and record nothing.
                        _showLogPeriodBottomSheet(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.of(context).dashLogPeriod,
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
                          "Full Cycle History",
                          "Detailed logs of all tracked cycles: \n- June 2026: 54 Days\n- April 2026: 39 Days\n- Feb 2026: 62 Days\n- Dec 2025: 45 Days\n- Oct 2025: 31 Days",
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
                        AppLocalizations.of(context).dashViewFullHistory,
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
  Widget _buildPeriWellbeing() => _buildCheckIn();

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
                      ..._orderedHome([
                        HomeSection('other', _buildPeriChangingCycle(pc), pinned: true),
                        HomeSection('wellbeing', _buildPeriWellbeing(), pinned: true),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildPeriInsights()),
                        HomeSection('patterns', _buildPeriPatterns()),
                        HomeSection('careplan', _buildPeriCarePlan()),
                        HomeSection('appointments', _buildAppointmentSummaryCard()),
                        HomeSection('learn', _buildPeriLearn()),
                        HomeSection('timeline', _buildPeriTransition()),
                        HomeSection('reflection', _buildPeriReflection()),
                      ], gap: const SizedBox(height: 32)),
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
                      ..._orderedHome([
                        HomeSection('other', _buildPeriChangingCycle(pc), pinned: true),
                        HomeSection('wellbeing', _buildPeriWellbeing(), pinned: true),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildPeriInsights()),
                        HomeSection('patterns', _buildPeriPatterns()),
                        HomeSection('careplan', _buildPeriCarePlan()),
                        HomeSection('appointments', _buildAppointmentSummaryCard()),
                        HomeSection('learn', _buildPeriLearn()),
                        HomeSection('timeline', _buildPeriTransition()),
                        HomeSection('reflection', _buildPeriReflection()),
                      ], gap: const SizedBox(height: 48)),
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
                      ..._orderedHome([
                        HomeSection('other', _buildPeriChangingCycle(pc)),
                        HomeSection('wellbeing', _buildPeriWellbeing()),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                      ], gap: const SizedBox(height: 24)),
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
                                ..._orderedHome([
                                  HomeSection('insights', _buildPeriInsights(), pinned: true),
                                  HomeSection('patterns', _buildPeriPatterns(), pinned: true),
                                  HomeSection('careplan', _buildPeriCarePlan()),
                                  HomeSection('appointments', _buildAppointmentSummaryCard()),
                                  HomeSection('learn', _buildPeriLearn()),
                                ], gap: const SizedBox(height: 48)),
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
  Widget _buildMenoCheckIn() => _buildCheckIn();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading("LONG-TERM WELLNESS"),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).dashEmpoweredPostMenopauseWellness,
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
          // Sized for the UI face at its current size and leading; the
          // cards' columns overflowed the old height by up to 90px.
          height: 340,
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card['title']!.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      card['desc']!,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).dashWhyMattersEncouragesSustainable,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: TextButton(
                            onPressed: () {
                              _showArticleDialog(
                                context,
                                card['title']!,
                                card['detail']!,
                              );
                            },
                            child: Text(
                              AppLocalizations.of(context).dashLearnMore,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: BlushyColors.primary,
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          child: TextButton(
                            onPressed: () => _openAskSiaChat(
                              context,
                              "Tell me about my ${card['title']}",
                            ),
                            child: Text(
                              AppLocalizations.of(context).dashAskDocsy,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: BlushyColors.primary,
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
                      ..._orderedHome([
                        HomeSection('checkin', _buildMenoCheckIn(), pinned: true),
                        HomeSection('wellbeing', _buildMenoWellbeing(), pinned: true),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildMenoInsights()),
                        HomeSection('patterns', _buildMenoPatterns()),
                        HomeSection('careplan', _buildMenoCarePlan()),
                        HomeSection('appointments', _buildAppointmentSummaryCard()),
                        HomeSection('learn', _buildMenoLearn()),
                        HomeSection('journey', _buildMenoWellnessJourney()),
                        HomeSection('reflection', _buildMenoReflection()),
                      ], gap: const SizedBox(height: 32)),
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
                      ..._orderedHome([
                        HomeSection('checkin', _buildMenoCheckIn(), pinned: true),
                        HomeSection('wellbeing', _buildMenoWellbeing(), pinned: true),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildMenoInsights()),
                        HomeSection('patterns', _buildMenoPatterns()),
                        HomeSection('careplan', _buildMenoCarePlan()),
                        HomeSection('appointments', _buildAppointmentSummaryCard()),
                        HomeSection('learn', _buildMenoLearn()),
                        HomeSection('journey', _buildMenoWellnessJourney()),
                        HomeSection('reflection', _buildMenoReflection()),
                      ], gap: const SizedBox(height: 48)),
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
                      ..._orderedHome([
                        HomeSection('checkin', _buildMenoCheckIn()),
                        HomeSection('wellbeing', _buildMenoWellbeing()),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                      ], gap: const SizedBox(height: 24)),
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
                                ..._orderedHome([
                                  HomeSection('insights', _buildMenoInsights(), pinned: true),
                                  HomeSection('patterns', _buildMenoPatterns(), pinned: true),
                                  HomeSection('careplan', _buildMenoCarePlan()),
                                  HomeSection('appointments', _buildAppointmentSummaryCard()),
                                  HomeSection('learn', _buildMenoLearn()),
                                ], gap: const SizedBox(height: 48)),
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
                  Expanded(child: Column(
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
                  )),
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
  Widget _buildWellnessCheckIn() => _buildCheckIn();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading("MY HABITS"),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).dashAiGeneratedHabitInsights,
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
            itemCount: habitCards.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final card = habitCards[index];
              return Container(
                width: 280,
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
                      card['title']!.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      card['desc']!,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).dashWhyMattersSupportsOverall,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: BlushyColors.secondaryText,
                      ),
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
                      ..._orderedHome([
                        HomeSection('checkin', _buildBranchSwitcher(state), pinned: true),
                        HomeSection('checkin', _buildWellnessCheckIn(), pinned: true),
                        HomeSection('dashboard', _buildWellnessDashboard()),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildWellnessInsights()),
                        HomeSection('habits', _buildWellnessHabitCards()),
                        HomeSection('plan', _buildWellnessPlan()),
                        HomeSection('journey', _buildWellnessJourney()),
                        HomeSection('reflection', _buildWellnessReflection()),
                      ], gap: const SizedBox(height: 32)),
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
                      ..._orderedHome([
                        HomeSection('checkin', _buildWellnessCheckIn(), pinned: true),
                        HomeSection('dashboard', _buildWellnessDashboard(), pinned: true),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                        HomeSection('insights', _buildWellnessInsights()),
                        HomeSection('habits', _buildWellnessHabitCards()),
                        HomeSection('plan', _buildWellnessPlan()),
                        HomeSection('journey', _buildWellnessJourney()),
                        HomeSection('reflection', _buildWellnessReflection()),
                      ], gap: const SizedBox(height: 48)),
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
                      ..._orderedHome([
                        HomeSection('checkin', _buildWellnessCheckIn()),
                        HomeSection('dashboard', _buildWellnessDashboard()),
                        HomeSection('insights', _buildLivingSiaInsights()),
                        HomeSection('patterns', _buildLivingPatterns()),
                      ], gap: const SizedBox(height: 24)),
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
                                ..._orderedHome([
                                  HomeSection('insights', _buildWellnessInsights()),
                                  HomeSection('habits', _buildWellnessHabitCards()),
                                  HomeSection('plan', _buildWellnessPlan()),
                                ], gap: const SizedBox(height: 48)),
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
