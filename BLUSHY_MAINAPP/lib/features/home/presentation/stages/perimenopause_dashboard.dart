import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/state.dart';
import '../../../../core/storage.dart';
import '../../../../services/api_period_service.dart';
import '../../../../services/api_contract_client.dart';
import '../../../../services/api_perimenopause_service.dart';
import '../../view_models/perimenopause_view_model.dart';
import '../../view_models/cycle_view_model.dart';
import '../../../../shared/live_refresh.dart';
import '../../widgets/blushy_period_tracker_card.dart';
import 'stage_shared_components.dart';
import '../../../../shared/stage_empty_notice.dart';
import '../../../../shared/user_display_name.dart';
import '../../widgets/log_symptoms_section.dart';
import 'health_library_section.dart';
import '../../../../l10n/app_localizations.dart';

/// 🌗 THE PERIMENOPAUSE COMMAND CENTER: MY TRANSITION
/// Built strictly in adherence to STAGE1_DESIGN_RULES.md:
/// - Surface canvas: #FAF7F2
/// - Structural cards: #FFFFFF with #EFE8E0 border and 20px radius
/// - Eyebrows: #DD0D22 in GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)
/// - Stage 1 Greeting: 2-line Cormorant Garamond 28px with italic crimson user name
/// - Period Tracker positioned directly after Today with Docsy (fully dynamic, real-time sync)
/// - Rich icon circular badges (42px with 10-12% soft tint backgrounds)
/// - 4-Tier Docsy AI Confidence Layer (WHAT YOU LOGGED -> WHAT WE'RE SEEING -> WHAT THIS MIGHT MEAN -> WHAT YOU CAN DO)
/// - Dual severity + impact tracking, non-predictive period intervals, real-time backend API & AI sync.
class PerimenopauseDashboard extends StatefulWidget {
  final bool isNested;
  final ScrollController? scrollController;

  const PerimenopauseDashboard({
    super.key,
    this.isNested = false,
    this.scrollController,
  });

  @override
  State<PerimenopauseDashboard> createState() => _PerimenopauseDashboardState();
}

class _PerimenopauseDashboardState extends State<PerimenopauseDashboard>
    with WidgetsBindingObserver, LiveRefresh {
  // ─── Design Tokens (STAGE1_DESIGN_RULES.md) ─────────────────────────
  static const Color surfaceCanvas = Color(0xFFFAF7F2);
  static const Color cardBg = Colors.white;
  static const Color cardBorderColor = Color(0xFFEFE8E0);
  static const Color crimsonPrimary = Color(0xFFDD0D22);
  static const Color textMain = Color(0xFF221510);
  static const Color textMuted = Color(0xFF7A6B72);
  static const Color dividerColor = Color(0xFFF3EEE9);
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20));

  // Accent Colors & Soft Tints for circular badges
  static const Color cobaltBlue = Color(0xFF2563EB);
  static const Color cobaltBlueTint = Color(0xFFDBEAFE);
  static const Color emeraldTeal = Color(0xFF0D9488);
  static const Color emeraldTealTint = Color(0xFFCCFBF1);
  static const Color vividMagenta = Color(0xFFF72585);
  static const Color vividMagentaTint = Color(0xFFFFE5F0);
  static const Color royalPurple = Color(0xFF7209B7);
  static const Color royalPurpleTint = Color(0xFFF3E8FF);
  static const Color warmAmber = Color(0xFFD97706);
  static const Color warmAmberTint = Color(0xFFFEF3C7);
  static const Color electricCoral = Color(0xFFFF4A00);
  static const Color electricCoralTint = Color(0xFFFFEBE0);
  static const Color brandCrimsonTint = Color(0xFFFFECEB);

  // ─── Real Dynamic State ─────────────────────────────────────────────
  /// This screen is the View; the two server reads live in the tested
  /// PerimenopauseViewModel and are mirrored back by _onDataChanged.
  final PerimenopauseViewModel _vm = PerimenopauseViewModel();

  PerimenopauseOverviewData? _overview;
  /// The server's own verdict on the last load (spec §4, §31).
  ApiState _overviewState = ApiState.loading;
  PerimenopauseTodayBriefData? _todayBrief;
  bool _isLoading = true;
  bool _isRefreshingBrief = false;
  String _activeFocus = 'sleep';
  bool _isConfidenceExpanded = true;
  bool _isPrivateMode = false;
  final TextEditingController _quickAskController = TextEditingController();

  // ─── Dynamic Cycle & Period Tracker State ───────────────────────────
  // The cycle DAY is owned by the shared CycleViewModel -- the single source of
  // truth every cycle stage reads -- so the day number here cannot drift from
  // the other dashboards. This screen only adds perimenopause-specific context
  // (phase label + interval history). It used to compute the day itself from
  // getPeriodEntries().last, which picks the newest entry and so echoed any
  // stray/recent "start" straight onto the tracker.
  final CycleViewModel _cycleVM =
      CycleViewModel(defaultCycleLength: 28, defaultPeriodLength: 5, defaultCycleDay: 1);

  int _currentCycleDay = 1;
  int _cycleLength = 28;
  int _periodLength = 5;
  DateTime? _lastPeriodStartDate;
  bool _hasLoggedPeriod = false;
  String _currentPhaseName = 'Transition Rhythm';
  List<int> _cycleHistory = [];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ScrollController _internalScrollController = ScrollController();
  ScrollController get _effectiveScrollController => widget.scrollController ?? _internalScrollController;

  PersonalContext get pc => BlushyOSProvider.of(context).personalContext;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onDataChanged);
    _cycleVM.addListener(_onCycleChanged);
    _cycleVM.load();
    _loadCycleContext();
    _loadAllData();
    startLiveRefresh();
  }

  @override
  Future<void> refreshNow() async {
    await _cycleVM.load();
    await _loadCycleContext();
    await _loadAllData(silent: true);
  }

  @override
  void dispose() {
    stopLiveRefresh();
    _vm.removeListener(_onDataChanged);
    _vm.dispose();
    _cycleVM.removeListener(_onCycleChanged);
    _cycleVM.dispose();
    _quickAskController.dispose();
    _internalScrollController.dispose();
    super.dispose();
  }

  /// The View reacting to its ViewModel: mirror the loaded data back into the
  /// fields the build methods already read.
  void _onDataChanged() {
    if (!mounted) return;
    setState(() {
      _overviewState = _vm.overviewState;
      _overview = _vm.overview;
      _todayBrief = _vm.todayBrief;
      _activeFocus = _vm.activeFocus;
      _cycleHistory = _vm.cycleHistory;
      _isLoading = _vm.isLoading;
    });
  }

  /// The cycle DAY, start date and lengths come from the shared CycleViewModel,
  /// exactly as they do on the other cycle dashboards. Mirrored here so the
  /// existing build methods keep reading the same field names.
  void _onCycleChanged() {
    if (!mounted) return;
    setState(() {
      _hasLoggedPeriod = _cycleVM.hasLoggedPeriod;
      _lastPeriodStartDate = _cycleVM.lastPeriodStart;
      _cycleLength = _cycleVM.cycleLength;
      _periodLength = _cycleVM.periodLength;
      _currentCycleDay = _cycleVM.currentCycleDay;
    });
  }

  /// Perimenopause-specific cycle context: the phase label and the spread of
  /// real intervals between logged periods. The cycle DAY, start date and
  /// lengths are deliberately NOT set here -- they come from [_cycleVM] via
  /// [_onCycleChanged], so this screen reads exactly the same day as every other
  /// cycle dashboard. (This method used to derive the day from
  /// getPeriodEntries().last, which picks the newest entry and so echoed any
  /// stray recent "start" straight onto the tracker.)
  Future<void> _loadCycleContext() async {
    try {
      final prediction = await ApiPeriodService().getPredictions();
      if (prediction != null && prediction.hasData && mounted) {
        setState(() {
          if (prediction.currentPhase.isNotEmpty) {
            _currentPhaseName = prediction.currentPhase;
          }
          if (prediction.historicalIntervals.isNotEmpty) {
            _cycleHistory = prediction.historicalIntervals;
          }
        });
      }

      // The spread of real intervals between her logged periods (interval
      // variance is the number this stage cares about, not a single day).
      final entries = await ApiPeriodService().getPeriodEntries();
      if (entries.isNotEmpty) {
        final sorted = entries.map((e) => e.periodStartDate).toList()..sort();
        final List<int> realIntervals = [];
        for (int i = 0; i < sorted.length - 1; i++) {
          final diff = sorted[i + 1].difference(sorted[i]).inDays;
          if (diff >= 10 && diff <= 180) {
            realIntervals.add(diff);
          }
        }
        if (realIntervals.isNotEmpty && mounted) {
          setState(() {
            _cycleHistory = realIntervals;
          });
        }
      }
    } catch (_) {}
  }

  /// Delegated to the view model; _onDataChanged mirrors the result.
  Future<void> _loadAllData({bool silent = false}) => _vm.load(silent: silent);

  Future<void> _changeFocus(String focus) async {
    setState(() => _activeFocus = focus);
    await ApiPerimenopauseService.setFocus(focus);
    await _loadAllData(silent: true);
  }

  // ─── Helpers: Color & Icon Resolvers ────────────────────────────────
  Color _resolveColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').replaceAll('0x', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return crimsonPrimary;
    }
  }

  IconData _resolveIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'bedtime_round':
      case 'bedtime':
      case 'nightlight_round':
      case 'sleep':
        return Icons.nightlight_round;
      case 'thermostat_round':
      case 'thermostat':
      case 'hot_flash':
        return Icons.thermostat_rounded;
      case 'psychology_round':
      case 'psychology':
      case 'brain':
      case 'brain_fog':
        return Icons.psychology_rounded;
      case 'favorite_round':
      case 'favorite':
      case 'heart':
      case 'intimacy':
        return Icons.favorite_rounded;
      case 'water_drop_round':
      case 'water_drop':
      case 'cycle':
      case 'period':
        return Icons.water_drop_rounded;
      case 'wb_sunny_round':
      case 'wb_sunny':
      case 'sun':
        return Icons.wb_sunny_rounded;
      case 'spa_round':
      case 'spa':
        return Icons.spa_rounded;
      case 'medication_round':
      case 'medication':
        return Icons.medication_rounded;
      case 'bolt_round':
      case 'bolt':
        return Icons.bolt_rounded;
      case 'assignment_round':
      case 'assignment':
        return Icons.assignment_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  // ====================================================================
  // BUILD METHOD
  // ====================================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return wrapStageDashboardLayout(
        context: context,
        scaffoldKey: _scaffoldKey,
        isNested: widget.isNested,
        child: const Center(
          child: CircularProgressIndicator(color: crimsonPrimary),
        ),
      );
    }

    // Thoroughly sanitized user name
    // Falls back to a neutral address, not to a name. This defaulted to
    // "Ananya" -- greeting the user by an invented name when hers was not known.
    // App state, then stored profile, then the name the server sent with the
    // overview, then a neutral address. The overview is kept as a source
    // because this screen is the only one that receives it.
    final fromOverview = (_overview?.profile['name']?.toString() ?? '')
        .replaceAll(RegExp(r'^[,.\s]+'), '')
        .trim();
    final String userName = userDisplayName(
      context,
      fallback: fromOverview.isNotEmpty ? fromOverview : 'there',
    );

    // Order of sections: PERIOD TRACKER IS RIGHT AFTER TODAY WITH DOCSY!
    final List<String> rawOrder = _overview?.sectionOrder ?? [
      'editorial_greeting',
      'today_with_docsy',
      'my_changing_cycle',
      'what_are_you_noticing',
      'what_changed_connections',
      'what_can_i_do',
      'focus_selector',
      'baseline_good_days',
      'treatment_intelligence',
      'tell_blushy_natural_note',
      'prepare_care',
      'intimate_health',
      'my_story',
      'learn_relevant',
      'ai_transparency',
    ];

    // Enforce that my_changing_cycle is ALWAYS immediately after today_with_docsy
    final List<String> sectionOrder = [];
    for (final s in rawOrder) {
      if (s == 'my_changing_cycle') continue;
      sectionOrder.add(s);
      if (s == 'today_with_docsy') {
        sectionOrder.add('my_changing_cycle');
      }
    }
    if (!sectionOrder.contains('my_changing_cycle')) {
      final docsyIndex = sectionOrder.indexOf('today_with_docsy');
      if (docsyIndex != -1) {
        sectionOrder.insert(docsyIndex + 1, 'my_changing_cycle');
      } else {
        sectionOrder.add('my_changing_cycle');
      }
    }

    return wrapStageDashboardLayout(
      context: context,
      scaffoldKey: _scaffoldKey,
      isNested: widget.isNested,
      child: RefreshIndicator(
        color: crimsonPrimary,
        backgroundColor: Colors.white,
        onRefresh: () async {
          await _cycleVM.load();
          await _loadCycleContext();
          await _loadAllData(silent: true);
        },
        child: ListView(
          controller: _effectiveScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          children: [
            // The greeting leads the page in every other stage. It used to
            // arrive through `sectionOrder`, which is rendered after the
            // notice and the logging row, so this stage greeted her below a
            // symptom sheet. Rendered here and skipped in the loop below.
            _buildEditorialGreeting(userName),
            const SizedBox(height: 20),
            // No server data, so every section below is the stage's general
            // content rather than anything derived from her entries.
            StageStateNotice(
              state: _overviewState,
              hasData: _overview != null || _todayBrief != null,
              emptyMessage:
                  'There is nothing recorded for your transition yet, so what follows is '
                  'general guidance rather than anything worked out from your own entries. '
                  'Log a check-in to start building your baseline.',
              onRetry: () => _loadAllData(),
            ),
            // Outside sectionOrder for the same reason as menopause: the
            // order is server-supplied and need not mention logging.
            const SizedBox(height: 20),
            const LogSymptomsSection(stageKey: 'perimenopause'),
            const SizedBox(height: 20),
            const HealthLibrarySection(stageKey: 'perimenopause'),
            const SizedBox(height: 20),
            for (final section in sectionOrder)
              // Already rendered at the top, wherever the server placed it.
              if (section != 'editorial_greeting') ...[
                _buildSectionByName(section, userName),
                const SizedBox(height: 20),
              ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionByName(String section, String userName) {
    switch (section) {
      case 'editorial_greeting':
        return _buildEditorialGreeting(userName);
      case 'today_with_docsy':
        return _buildTodayWithDocsyCard();
      case 'my_changing_cycle':
        return _buildMyChangingCycleCard();
      case 'what_are_you_noticing':
        return _buildWhatAreYouNoticingSection();
      case 'what_changed_connections':
        return _buildWhatChangedAndConnections();
      case 'what_can_i_do':
        return _buildWhatCanIDoSection();
      case 'focus_selector':
        return _buildFocusSelector();
      case 'baseline_good_days':
        return _buildBaselineAndGoodDays();
      case 'treatment_intelligence':
        return _buildTreatmentIntelligence();
      case 'tell_blushy_natural_note':
        return _buildNaturalNoteBar();
      case 'prepare_care':
        return _buildPrepareCareCard();
      case 'intimate_health':
        return _buildIntimateHealthCard();
      case 'my_story':
        return _buildMyStoryCard();
      case 'learn_relevant':
        return _buildLearnRelevantSection();
      case 'ai_transparency':
        return _buildAiTransparencyCard();
      default:
        return const SizedBox.shrink();
    }
  }

  // ====================================================================
  // 01. EDITORIAL GREETING (Exact Stage 1 Guidelines - No Pills)
  // ====================================================================
  Widget _buildEditorialGreeting(String userName) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning,'
        : (hour < 17 ? 'Good afternoon,' : 'Good evening,');

    String cleanName = userName.replaceAll(RegExp(r'^[,.\s]+'), '').trim();
    if (cleanName.isEmpty) cleanName = 'ananya';

    final String patternSubtext = _overview?.profile['cycleStatus'] != null
        ? 'Your cycles have shown variable intervals over recent logs.'
        : 'Your body is changing. Let\'s make sense of it together.';

    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeGreeting,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF221510),
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            '$cleanName.',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: crimsonPrimary,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            patternSubtext,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // 02. TODAY WITH DOCSY CARD (With 4-Tier Confidence Layer)
  // ====================================================================
  Widget _buildTodayWithDocsyCard() {
    final brief = _todayBrief;
    final conf = brief?.confidence ?? _overview?.confidence;

    final String openingText = brief?.openingGreeting ??
        'Your body is moving through its midlife transition rhythm. Give yourself credit for how you are navigating it.';
    // Only the server's brief can explain why something was surfaced, because
    // only the server read anything. The fallback used to claim it was
    // "Surfaced today based on recent sleep and cycle rhythm logs" while
    // reading no logs at all, to users who may have logged none.
    final String whyToday = brief?.whyToday ?? 'General guidance for this stage, not based on your logs.';
    final List<String> pills = brief?.promptPills ?? [
      'What should I expect next in my transition?',
      'How can I protect my bone density in midlife?',
      'Should I discuss HRT with my doctor?',
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Eyebrow + Docsy Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: emeraldTealTint,
                      shape: BoxShape.circle,
                      border: Border.all(color: emeraldTeal.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 16, color: emeraldTeal),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context).periTodayWithDocsy,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: crimsonPrimary,
                        ),
                      ),
                      Text(AppLocalizations.of(context).periMidlifeCompanionIntelligence,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_isRefreshingBrief)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: crimsonPrimary),
                )
              else
                InkWell(
                  onTap: () async {
                    setState(() => _isRefreshingBrief = true);
                    final updated = await ApiPerimenopauseService.getTodayBrief();
                    if (mounted) {
                      setState(() {
                        if (updated.data != null) _todayBrief = updated.data;
                        _isRefreshingBrief = false;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.refresh_rounded, size: 16, color: textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Docsy Opening Observation
          Text(
            openingText,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 19.5,
              fontWeight: FontWeight.w600,
              color: textMain,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),

          // "Why Today?" Contextual Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: surfaceCanvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: dividerColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    whyToday,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Four-Tier Confidence Layer ─────────────────────────────
          if (conf != null) ...[
            InkWell(
              onTap: () => setState(() => _isConfidenceExpanded = !_isConfidenceExpanded),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: emeraldTealTint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: emeraldTeal.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: emeraldTeal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Confidence Layer · ${conf.confidenceLevel}',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: emeraldTeal,
                        ),
                      ),
                    ),
                    Icon(
                      _isConfidenceExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 16,
                      color: emeraldTeal,
                    ),
                  ],
                ),
              ),
            ),
            if (_isConfidenceExpanded) ...[
              const SizedBox(height: 10),
              _buildConfidenceStep(
                stepNumber: '1',
                badgeText: 'WHAT YOU LOGGED',
                color: cobaltBlue,
                bgColor: cobaltBlueTint,
                body: conf.whatYouLogged,
              ),
              const SizedBox(height: 8),
              _buildConfidenceStep(
                stepNumber: '2',
                badgeText: 'WHAT WE\'RE SEEING',
                color: warmAmber,
                bgColor: warmAmberTint,
                body: conf.whatWereSeeing,
              ),
              const SizedBox(height: 8),
              _buildConfidenceStep(
                stepNumber: '3',
                badgeText: 'WHAT THIS MIGHT MEAN',
                color: royalPurple,
                bgColor: royalPurpleTint,
                body: conf.whatThisMightMean,
              ),
              const SizedBox(height: 8),
              _buildConfidenceStep(
                stepNumber: '4',
                badgeText: 'WHAT YOU CAN DO',
                color: emeraldTeal,
                bgColor: emeraldTealTint,
                body: conf.whatYouCanDo,
              ),
            ],
            const SizedBox(height: 14),
          ],

          // Search-style Ask Docsy input bar
          Container(
            decoration: BoxDecoration(
              color: surfaceCanvas,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: crimsonPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _quickAskController,
                    decoration: InputDecoration(
                      hintText: 'Ask Docsy about symptoms, sleep, HRT...',
                      hintStyle: GoogleFonts.manrope(
                        fontSize: 12,
                        color: textMuted.withValues(alpha: 0.8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: GoogleFonts.manrope(fontSize: 12.5, color: textMain),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        final q = val.trim();
                        _quickAskController.clear();
                        openAskSiaChat(context, q);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: crimsonPrimary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    final q = _quickAskController.text.trim();
                    if (q.isNotEmpty) {
                      _quickAskController.clear();
                      openAskSiaChat(context, q);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Interactive prompt pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pills.map((p) {
              return InkWell(
                onTap: () => openAskSiaChat(context, p),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.help_outline_rounded, size: 12, color: crimsonPrimary),
                      const SizedBox(width: 6),
                      Text(
                        p,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textMain,
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
  }

  Widget _buildConfidenceStep({
    required String stepNumber,
    required String badgeText,
    required Color color,
    required Color bgColor,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surfaceCanvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              body,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: textMain,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // 03. MY CHANGING CYCLE & DYNAMIC PERIOD TRACKER (Right After Docsy!)
  // ====================================================================
  Widget _buildMyChangingCycleCard() {
    final history = _cycleHistory.isNotEmpty
        ? _cycleHistory
        : (_overview?.cycleHistory ?? <int>[]);

    // The day comes from the shared CycleViewModel (server-preferred), the same
    // value the other cycle dashboards show -- not a local recompute.
    final int displayDay = _hasLoggedPeriod ? _currentCycleDay : 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor),
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
          // Header Row: Eyebrow + Subtitle + Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: brandCrimsonTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.water_drop_rounded, size: 18, color: crimsonPrimary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context).periMyChangingCycle,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: crimsonPrimary,
                        ),
                      ),
                      Text(AppLocalizations.of(context).periNonPredictiveMidlifeRhythm,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _openRealPeriodLogSheet(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: crimsonPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.edit_calendar_rounded, size: 13),
                label: Text(AppLocalizations.of(context).periLogPeriod,
                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Canonical Blushy Period Tracker Card (Fully Dynamic, Real-time Bound)
          BlushyPeriodTrackerCard(
            currentCycleDay: _hasLoggedPeriod ? displayDay : 1,
            cycleLength: _cycleLength,
            periodLength: _periodLength,
            hasLoggedPeriod: _hasLoggedPeriod,
            currentPhaseName: _hasLoggedPeriod
                ? (displayDay > 45 ? 'Extended Interval Phase' : _currentPhaseName)
                : 'Fluctuating Cycle',
            customDisclaimer:
                'In perimenopause, periods fluctuate naturally. Blushy tracks interval spread rather than predicting rigid dates.',
            onTapLogPeriod: () => _openRealPeriodLogSheet(),
            onTapInsights: () => openAskSiaChat(context, 'Explain how cycle intervals change during perimenopause.'),
          ),
          const SizedBox(height: 16),

          // Days since last bleeding callout - Constrained to NEVER overflow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceCanvas,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasLoggedPeriod ? 'Day $displayDay' : 'Interval Variance',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: crimsonPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _hasLoggedPeriod
                            ? 'since last logged period start'
                            : 'logging periods personalizes your rhythm',
                        style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(AppLocalizations.of(context).periStatus,
                        style: GoogleFonts.manrope(fontSize: 9.5, color: textMuted, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        !_hasLoggedPeriod
                            ? 'Calibrating'
                            : (displayDay > 45 ? 'Extended' : 'Active Rhythm'),
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: textMain),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Interval Variation Visualizer (Real data only, graceful empty state)
          Text(AppLocalizations.of(context).periRecentCycleIntervals,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: textMain,
            ),
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceCanvas,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: brandCrimsonTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, size: 16, color: crimsonPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No cycle intervals logged yet. Log at least two periods to calculate your real transition variance.',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < history.length; i++) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: i == history.length - 1 ? brandCrimsonTint : surfaceCanvas,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: i == history.length - 1 ? crimsonPrimary.withValues(alpha: 0.3) : dividerColor,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${history[i]} days',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: i == history.length - 1 ? crimsonPrimary : textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            i == history.length - 1 ? 'Latest' : 'Cycle -${history.length - 1 - i}',
                            style: GoogleFonts.manrope(fontSize: 9.5, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (i < history.length - 1) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 14, color: textMuted),
                      ),
                    ],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ====================================================================
  // 04. WHAT ARE YOU NOTICING? (Dual Severity + Impact Tracking)
  // ====================================================================
  Widget _buildWhatAreYouNoticingSection() {
    // 4 Domains: Body, Mind, Cycle, Intimacy
    final domains = [
      {
        'id': 'body',
        'title': 'Body & Thermoregulation',
        'subtitle': 'Hot flashes, night sweats, energy',
        'icon': Icons.thermostat_rounded,
        'color': electricCoral,
        'bgColor': electricCoralTint,
        'symptoms': ['Hot Flashes', 'Night Sweats', 'Joint Aches', 'Palpitations'],
      },
      {
        'id': 'mind',
        'title': 'Mind & Cognitive Rest',
        'subtitle': 'Brain fog, sleep disruption, mood swings',
        'icon': Icons.psychology_rounded,
        'color': royalPurple,
        'bgColor': royalPurpleTint,
        'symptoms': ['Brain Fog', 'Waking at 3 AM', 'Mood Swings', 'Anxiety Waves'],
      },
      {
        'id': 'cycle',
        'title': 'Cycle & Bleeding Pattern',
        'subtitle': 'Variability, flow volume, spotting',
        'icon': Icons.water_drop_rounded,
        'color': crimsonPrimary,
        'bgColor': brandCrimsonTint,
        'symptoms': ['Cycle Variability', 'Heavy Flow', 'Light Spotting', 'Skipped Period'],
      },
      {
        'id': 'intimacy',
        'title': 'Intimate & Pelvic Health',
        'subtitle': 'Dryness, pelvic comfort, intimacy ease',
        'icon': Icons.favorite_rounded,
        'color': vividMagenta,
        'bgColor': vividMagentaTint,
        'symptoms': ['Vaginal Dryness', 'Pelvic Discomfort', 'Libido Shift', 'Bladder Urgency'],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Eyebrow
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context).periWhatYouVeBeenNoticing,
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: crimsonPrimary,
              ),
            ),
            InkWell(
              onTap: () => _openCheckinBottomSheet(),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 14, color: crimsonPrimary),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context).periLogCheckIn,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: crimsonPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Notice how sensations feel without judgment. Blushy tracks both intensity and how much it touches your day.',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: textMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),

        // 4 Domain Cards
        for (final domain in domains) ...[
          _buildDomainCard(
            title: domain['title'] as String,
            subtitle: domain['subtitle'] as String,
            icon: domain['icon'] as IconData,
            color: domain['color'] as Color,
            bgColor: domain['bgColor'] as Color,
            symptoms: domain['symptoms'] as List<String>,
            isPrivate: domain['id'] == 'intimacy' && _isPrivateMode,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildDomainCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required List<String> symptoms,
    bool isPrivate = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
                onPressed: () => _openCheckinBottomSheet(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Chips
          if (isPrivate)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceCanvas,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 13, color: textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Sensitive logs hidden by Private Mode',
                    style: GoogleFonts.manrope(fontSize: 11, color: textMuted, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: symptoms.map((s) {
                return InkWell(
                  onTap: () => _openQuickSymptomRater(s),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: surfaceCanvas,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: dividerColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(
                          s,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textMain,
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
  }

  // ====================================================================
  // 05. WHAT CHANGED & CONNECTIONS (Deltas & Multi-Factor Triggers)
  // ====================================================================
  Widget _buildWhatChangedAndConnections() {
    final deltas = _overview?.deltas ?? {};
    final connections = _overview?.connections ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context).periWhatChangedConnections,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: crimsonPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cobaltBlueTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(AppLocalizations.of(context).periWeeklyShift,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cobaltBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Delta Stats Row
          Row(
            children: [
              Expanded(
                child: _buildDeltaPill(
                  label: 'Night Sweats',
                  stat: deltas['nightSweatsChange']?.toString() ?? '-25%',
                  positive: true,
                  sub: 'vs last 7 days',
                  icon: Icons.thermostat_rounded,
                  color: electricCoral,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDeltaPill(
                  label: 'Sleep Duration',
                  stat: deltas['sleepDurationChange']?.toString() ?? '+45m',
                  positive: true,
                  sub: 'average nightly',
                  icon: Icons.nightlight_round,
                  color: emeraldTeal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDeltaPill(
                  label: 'Cycle Variance',
                  stat: deltas['cycleLengthDelta']?.toString() ?? '+8d',
                  positive: false,
                  sub: 'interval spread',
                  icon: Icons.water_drop_rounded,
                  color: crimsonPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: dividerColor, height: 1),
          const SizedBox(height: 12),

          // Symptom-Trigger Connections
          Text(AppLocalizations.of(context).periDiscoveredConnections,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textMain,
            ),
          ),
          const SizedBox(height: 8),

          for (final conn in connections.take(2)) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceCanvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 14, color: royalPurple),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          conn.title,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conn.description,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => openAskSiaChat(context, conn.actionPrompt),
                    child: Text(
                      'Ask Docsy about this connection →',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: crimsonPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildDeltaPill({
    required String label,
    required String stat,
    required bool positive,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            stat,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textMain,
            ),
          ),
          Text(
            sub,
            style: GoogleFonts.manrope(fontSize: 9.5, color: textMuted),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // 06. WHAT CAN I DO? (Action Pathways)
  // ====================================================================
  Widget _buildWhatCanIDoSection() {
    final pathways = _overview?.actionPathways ?? {};
    if (pathways.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT CAN I DO?',
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: crimsonPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Evidence-based, micro-steps to support comfort, sleep, and physical ease today.',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: textMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),

        for (final entry in pathways.entries) ...[
          _buildPathwayCard(entry.value),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildPathwayCard(PerimenopausePathway pathway) {
    final color = _resolveColor(pathway.colorHex);
    final bgColor = _resolveColor(pathway.bgHex);
    final icon = _resolveIcon(pathway.icon);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pathway.title,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final action in pathway.actions) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceCanvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 14, color: emeraldTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.headline,
                          style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: textMain),
                        ),
                        Text(
                          action.reason,
                          style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cardBorderColor),
                    ),
                    child: Text(
                      action.difficulty,
                      style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w600, color: textMuted),
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

  // ====================================================================
  // 07. FOCUS SELECTOR (Chips Row)
  // ====================================================================
  Widget _buildFocusSelector() {
    final focuses = [
      {'key': 'sleep', 'label': 'Sleep & Nights', 'icon': Icons.nightlight_round},
      {'key': 'hot_flashes', 'label': 'Hot Flashes & Heat', 'icon': Icons.thermostat_rounded},
      {'key': 'cycles', 'label': 'Cycle Changes', 'icon': Icons.water_drop_rounded},
      {'key': 'brain_fog', 'label': 'Brain Fog & Focus', 'icon': Icons.psychology_rounded},
      {'key': 'mood', 'label': 'Mood & Anxiety', 'icon': Icons.favorite_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).periYourCurrentFocus,
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: crimsonPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select what matters most right now. Blushy prioritizes your dashboard accordingly.',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: focuses.map((f) {
              final isSelected = _activeFocus == f['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => _changeFocus(f['key'] as String),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? crimsonPrimary : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: isSelected ? crimsonPrimary : cardBorderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          f['icon'] as IconData,
                          size: 14,
                          color: isSelected ? Colors.white : crimsonPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          f['label'] as String,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : textMain,
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
      ],
    );
  }

  // ====================================================================
  // 08. BASELINE & GOOD DAYS (Positive Correlation Detection)
  // ====================================================================
  Widget _buildBaselineAndGoodDays() {
    final goodDays = _overview?.goodDays ?? {};
    final List<String> factors = (goodDays['factors'] as List?)?.map((e) => e.toString()).toList() ?? [
      'Morning sunlight exposure (>15 mins)',
      'Evening magnesium glycinate',
      'Hydration before 7 PM',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: emeraldTealTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wb_sunny_rounded, size: 16, color: emeraldTeal),
              ),
              const SizedBox(width: 8),
              Text(
                'YOUR GOOD DAYS · POSITIVE PATTERNS',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: crimsonPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'What worked on days you reported feeling energized and calm:',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textMain,
            ),
          ),
          const SizedBox(height: 10),

          for (final factor in factors) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceCanvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: warmAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      factor,
                      style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMain),
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

  // ====================================================================
  // 09. TREATMENT INTELLIGENCE (HRT & Non-Hormonal Tracking)
  // ====================================================================
  Widget _buildTreatmentIntelligence() {
    final treatments = _overview?.treatments ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TREATMENT & SUPPORT INTELLIGENCE',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: crimsonPrimary,
                ),
              ),
              InkWell(
                onTap: () => _openAddTreatmentDialog(),
                child: Text(AppLocalizations.of(context).periAdd,
                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: crimsonPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Track HRT, botanical supplements, or non-hormonal routines without judgment.',
            style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted),
          ),
          const SizedBox(height: 12),

          if (treatments.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceCanvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No active treatments logged. Tap + Add to log HRT patches, progesterone, or supplements.',
                style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, fontStyle: FontStyle.italic),
              ),
            )
          else
            for (final t in treatments) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: surfaceCanvas,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dividerColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medication_rounded, size: 16, color: royalPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t['name']?.toString() ?? 'Treatment',
                            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: textMain),
                          ),
                          Text(
                            '${t['type'] ?? 'HRT'} · ${t['dose'] ?? ''}',
                            style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => openAskSiaChat(context, 'How does ${t['name']} interact with perimenopause?'),
                      child: const Icon(Icons.help_outline_rounded, size: 15, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  // ====================================================================
  // 10. NATURAL NOTE PARSER ("+ TELL BLUSHY")
  // ====================================================================
  Widget _buildNaturalNoteBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceCanvas,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_none_rounded, size: 22, color: crimsonPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+ Tell Blushy in Your Words',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
                Text(
                  'Say or type anything ("Woke up sweating at 3am, felt fatigued"). Docsy parses symptoms automatically.',
                  style: GoogleFonts.manrope(fontSize: 11, color: textMuted, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _openNaturalNoteSheet(),
            style: ElevatedButton.styleFrom(
              backgroundColor: crimsonPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(AppLocalizations.of(context).periTell,
              style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // 11. PREPARE CARE (1-Page Clinician Brief)
  // ====================================================================
  Widget _buildPrepareCareCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PREPARE CARE · CLINICIAN NOTEBOOK',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: crimsonPrimary,
                ),
              ),
              const Icon(Icons.assignment_turned_in_rounded, size: 16, color: emeraldTeal),
            ],
          ),
          const SizedBox(height: 10),
          Text(AppLocalizations.of(context).periYour1PageAppointmentBrief,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Synthesizes your cycle interval spread, symptom frequencies, and questions into an objective summary for your doctor.',
            style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewClinicianBriefDialog(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: crimsonPrimary,
                    side: const BorderSide(color: crimsonPrimary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: Text(AppLocalizations.of(context).periViewBrief, style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _copyClinicianBrief(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crimsonPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text(AppLocalizations.of(context).periCopyForDoctor, style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // 12. INTIMATE HEALTH (Discreet & Private Mode Supported)
  // ====================================================================
  Widget _buildIntimateHealthCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context).periIntimateSexualHealth,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: crimsonPrimary,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() => _isPrivateMode = !_isPrivateMode);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPrivateMode ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 13,
                      color: textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isPrivateMode ? 'Private Mode ON' : 'Discreet Mode',
                      style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Vaginal Tissue & Hormonal Changes',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Estrogen changes influence collagen, moisture, and sensation. Blushy provides a private space to explore solutions like local estrogen, hyaluronic moisturizers, and pelvic floor ease.',
            style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.35),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => openAskSiaChat(context, 'Tell me about vaginal estrogen and comfort options in perimenopause.'),
            child: Row(
              children: [
                Text(
                  'Explore comfort options with Docsy',
                  style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: vividMagenta),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 13, color: vividMagenta),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // 13. MY STORY (Narrative Milestones Timeline)
  // ====================================================================
  Widget _buildMyStoryCard() {
    final story = _overview?.story ?? [];
    if (story.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).periMyStoryTimeline,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: crimsonPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your milestones through midlife transition:',
            style: GoogleFonts.cormorantGaramond(fontSize: 17, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 10),

          for (int i = 0; i < story.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: crimsonPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i < story.length - 1)
                      Container(
                        width: 1.5,
                        height: 34,
                        color: cardBorderColor,
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            story[i].title,
                            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: textMain),
                          ),
                          Text(
                            story[i].date,
                            style: GoogleFonts.manrope(fontSize: 10, color: textMuted),
                          ),
                        ],
                      ),
                      Text(
                        story[i].description,
                        style: GoogleFonts.manrope(fontSize: 11, color: textMuted),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ====================================================================
  // 14. LEARN WHEN RELEVANT (Articles)
  // ====================================================================
  Widget _buildLearnRelevantSection() {
    final articles = _overview?.contextualArticles ?? [];
    if (articles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).periKeepExploring,
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: crimsonPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Evidence-based guidance matched to your active focus and logs.',
          style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
        ),
        const SizedBox(height: 10),

        for (final article in articles) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _resolveColor(article.bgHex),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 20,
                    color: _resolveColor(article.colorHex),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: surfaceCanvas,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              article.topic,
                              style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w700, color: crimsonPrimary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            article.readTime,
                            style: GoogleFonts.manrope(fontSize: 10, color: textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.title,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
                  onPressed: () => openAskSiaChat(context, 'Tell me more about: ${article.title}'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ====================================================================
  // 15. AI TRANSPARENCY
  // ====================================================================
  Widget _buildAiTransparencyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceCanvas,
        borderRadius: cardRadius,
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 14, color: emeraldTeal),
              const SizedBox(width: 6),
              Text(
                'DOCSY AI BOUNDARIES & TRANSPARENCY',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: emeraldTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• What Docsy knows: Your self-reported symptoms, cycle interval spread, and lifestyle logs.\n'
            '• What Docsy does not know: Your clinical blood panels, imaging, or physical pelvic exams.\n'
            '• Purpose: Supportive midlife pattern-recognition companion. Not a diagnostic tool.',
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // INTERACTIVE BOTTOM SHEETS & DIALOGS
  // ====================================================================

  /// Real-Time Period & Flow Log Sheet
  void _openRealPeriodLogSheet() {
    DateTime selectedDate = _lastPeriodStartDate ?? DateTime.now();
    String flow = 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(AppLocalizations.of(context).periLogPeriodStartDate,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'In perimenopause, periods fluctuate naturally. Log the date your period started to calibrate your transition rhythm.',
                    style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 14),
                  CalendarDatePicker(
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 180)),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    onDateChanged: (val) => setModalState(() => selectedDate = val),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Flow intensity:',
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: textMain),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['spotting', 'light', 'medium', 'heavy'].map((f) {
                      final isSel = flow == f;
                      return ChoiceChip(
                        label: Text(f[0].toUpperCase() + f.substring(1)),
                        selected: isSel,
                        selectedColor: brandCrimsonTint,
                        labelStyle: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? crimsonPrimary : textMain,
                        ),
                        onSelected: (val) => setModalState(() => flow = f),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);

                        final diff = DateTime.now().difference(selectedDate).inDays;
                        setState(() {
                          _lastPeriodStartDate = selectedDate;
                          _hasLoggedPeriod = true;
                          _currentCycleDay = diff + 1;
                        });

                        try {
                          BlushyStorage.write('last_period_entry.json', {
                            'periodStartDate': selectedDate.toIso8601String(),
                            'flow': flow,
                            'loggedAt': DateTime.now().toIso8601String(),
                          });
                        } catch (_) {}

                        try {
                          await ApiPeriodService().logPeriodEntry(
                            periodStartDate: selectedDate,
                            flowIntensity: flow,
                          );
                        } catch (_) {}

                        try {
                          await ApiPerimenopauseService.recordCycleInterval(diff);
                        } catch (_) {}

                        await _cycleVM.load();
                        await _loadCycleContext();
                        await _loadAllData(silent: true);

                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Period logged for ${selectedDate.day}/${selectedDate.month}! Rhythm and intervals updated.',
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crimsonPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Save Period & Calibrate Rhythm',
                        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
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

  /// Quick Symptom Rater (Severity + Impact)
  void _openQuickSymptomRater(String symptom) {
    String selectedSeverity = 'Moderate';
    String selectedImpact = 'Interrupted daytime work';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Log $symptom',
                        style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: textMain),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('1. How intense is it?', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['Mild', 'Moderate', 'Intense', 'Not sure'].map((sev) {
                      final isSel = selectedSeverity == sev;
                      return ChoiceChip(
                        label: Text(sev),
                        selected: isSel,
                        selectedColor: brandCrimsonTint,
                        onSelected: (val) => setModalState(() => selectedSeverity = sev),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text('2. Impact on your day:', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['Minimal', 'Interrupted daytime work', 'Kept me awake', 'Stole my afternoon'].map((imp) {
                      final isSel = selectedImpact == imp;
                      return ChoiceChip(
                        label: Text(imp),
                        selected: isSel,
                        selectedColor: brandCrimsonTint,
                        onSelected: (val) => setModalState(() => selectedImpact = imp),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        await ApiPerimenopauseService.recordCheckin({
                          'symptoms': [
                            {
                              'name': symptom,
                              'severity': selectedSeverity,
                              'impact': selectedImpact,
                            }
                          ]
                        });
                        await _loadAllData(silent: true);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Logged $symptom: $selectedSeverity ($selectedImpact)')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crimsonPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(AppLocalizations.of(context).periSaveObservation, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
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

  /// Full Check-In Bottom Sheet
  void _openCheckinBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        String energy = 'Balanced';
        String sleepQuality = 'Woke up 1-2 times';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context).periDailyTransitionCheckIn,
                        style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: textMain),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('How was your sleep last night?', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['Restful & continuous', 'Woke up 1-2 times', 'Night sweat awakenings', 'Restless insomnia'].map((s) {
                      final isSel = sleepQuality == s;
                      return ChoiceChip(
                        label: Text(s),
                        selected: isSel,
                        selectedColor: emeraldTealTint,
                        onSelected: (val) => setModalState(() => sleepQuality = s),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Energy level today:', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['Steady & vibrant', 'Balanced', 'Afternoon dip', 'Exhausted'].map((e) {
                      final isSel = energy == e;
                      return ChoiceChip(
                        label: Text(e),
                        selected: isSel,
                        selectedColor: warmAmberTint,
                        onSelected: (val) => setModalState(() => energy = e),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        await ApiPerimenopauseService.recordCheckin({
                          'sleepQuality': sleepQuality,
                          'energy': energy,
                        });
                        await _loadAllData(silent: true);
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Daily check-in saved! Docsy updated.')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crimsonPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(AppLocalizations.of(context).periCompleteCheckIn, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
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

  /// Natural Note Bottom Sheet (+ Tell Blushy)
  void _openNaturalNoteSheet() {
    final TextEditingController noteCtrl = TextEditingController();
    bool isParsing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tell Blushy in Your Words',
                        style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: textMain),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Docsy automatically extracts symptoms, triggers, and timing using AI.',
                    style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'e.g., "Woke up drenched twice around 3am. Felt foggy in morning presentation."',
                      hintStyle: GoogleFonts.manrope(fontSize: 12, color: textMuted),
                      filled: true,
                      fillColor: surfaceCanvas,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: cardBorderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: cardBorderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isParsing
                          ? null
                          : () async {
                              final text = noteCtrl.text.trim();
                              if (text.isEmpty) return;
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(ctx);
                              setModalState(() => isParsing = true);

                              final parsed = await ApiPerimenopauseService.parseNaturalNote(text);
                              navigator.pop();
                              await _loadAllData(silent: true);

                              if (mounted) {
                                final symptoms = (parsed?['extractedSymptoms'] as List?)?.join(', ') ?? 'note';
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Docsy logged: $symptoms')),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crimsonPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isParsing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Parse & Save with Docsy', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
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

  /// Add Treatment Dialog
  void _openAddTreatmentDialog() {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    String type = 'HRT';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(AppLocalizations.of(context).periAddTreatmentSupport, style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name (e.g., Estradiol Patch, Magnesium)'),
                  ),
                  TextField(
                    controller: doseCtrl,
                    decoration: const InputDecoration(labelText: 'Dose / Frequency (e.g., 0.05mg 2x/wk)'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    value: type,
                    isExpanded: true,
                    items: ['HRT', 'Supplement', 'Botanical', 'Lifestyle'].map((t) {
                      return DropdownMenuItem(value: t, child: Text(t));
                    }).toList(),
                    onChanged: (v) => setDialogState(() => type = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).periCancel)),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await ApiPerimenopauseService.saveTreatment({
                      'id': 't_${DateTime.now().millisecondsSinceEpoch}',
                      'name': nameCtrl.text.trim(),
                      'dose': doseCtrl.text.trim(),
                      'type': type,
                    });
                    await _loadAllData(silent: true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary, foregroundColor: Colors.white),
                  child: Text(AppLocalizations.of(context).periSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// View Clinician Brief Dialog
  Future<void> _viewClinicianBriefDialog() async {
    final brief = await ApiPerimenopauseService.getClinicianBrief();
    if (!mounted) return;

    // A clinician brief is only worth showing when the server built one from
    // her records. The fallback used to invent an entire clinical picture --
    // the patient's name ("Ananya"), a 27 to 56 day cycle interval, night
    // sweats three times a week, magnesium and cooling habits as active
    // treatments -- none of it measured, all of it shown to anyone whose
    // request had failed, in a document meant for a doctor.
    final String? summary = brief?['markdownSummary']?.toString();
    final String text = (summary != null && summary.trim().isNotEmpty)
        ? summary
        : 'No clinician brief could be produced yet.\n\n'
            'This is built from the periods, symptoms and treatments you have '
            'logged. Once there is enough recorded, it will appear here and can '
            'be shared with your doctor.';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppLocalizations.of(context).periClinicianBriefPreview,
            style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: textMain),
          ),
          content: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceCanvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                text,
                style: GoogleFonts.manrope(fontSize: 12, height: 1.4, color: textMain),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).periClose),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Clinician brief copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: Text(AppLocalizations.of(context).periCopy),
              style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary, foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );
  }

  /// Copy Clinician Brief to Clipboard & Share
  Future<void> _copyClinicianBrief() async {
    final brief = await ApiPerimenopauseService.getClinicianBrief();
    final String text = brief?['markdownSummary']?.toString() ??
        'Blushy Health Clinician Brief: Perimenopause Stage Transition Summary';

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brief copied! Ready to paste into your patient portal or print.')),
      );
      try {
        await Share.share(text, subject: 'My Blushy Midlife Health Summary');
      } catch (_) {}
    }
  }
}
