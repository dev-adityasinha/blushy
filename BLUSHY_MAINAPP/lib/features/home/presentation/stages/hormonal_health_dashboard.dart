import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/colors.dart';
import '../../../../core/state.dart';
import '../../../../core/storage.dart';
import '../../services/home_event_bus.dart';
import '../../../sia/open_docsy.dart';
import '../../../../models/blushy_models.dart';
import '../../../../services/api_period_service.dart';
import '../../view_models/cycle_view_model.dart';
import '../../../../services/api_sia_service.dart';
import '../../../../services/api_checkin_service.dart';
import '../../home_screen.dart';
import '../../widgets/cycle_tracker_image.dart';
import '../../../../shared/docsy_avatar.dart';
import 'stage_shared_components.dart';
import '../../../../shared/user_display_name.dart';
import '../../../../services/api_contract_client.dart';
import '../../../../shared/stage_empty_notice.dart';
import '../../widgets/log_symptoms_section.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/user_state_store.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// STAGE 4: UNDERSTANDING MY BODY — HEALTH INTELLIGENCE & PATTERN SYNTHESIS
///
/// Mental Model: NOTICE → UNDERSTAND → MANAGE → CONNECT → PREPARE
/// "Something about my body isn't straightforward. Help me understand what's
/// happening, notice patterns, manage my day, and know when I need help."
///
/// Architecture:
/// Baseline + Timeline → Change Detection → Signals & Correlations →
/// Docsy Transparency → Doctor Preparation
/// ════════════════════════════════════════════════════════════════════════════

class HormonalHealthDashboard extends StatefulWidget {
  final bool isNested;
  final ScrollController? scrollController;

  const HormonalHealthDashboard({
    super.key,
    this.isNested = false,
    this.scrollController,
  });

  @override
  State<HormonalHealthDashboard> createState() => _HormonalHealthDashboardState();
}

class _HormonalHealthDashboardState extends State<HormonalHealthDashboard> {

  /// How the last cycle-data load went, so a failed request is not drawn as an
  /// account with nothing in it.
  ApiState _cycleState = ApiState.loading;

  /// This screen is the View; the cycle read lives in the tested
  /// CycleViewModel and is mirrored back by _onCycleChanged.
  final CycleViewModel _cycleVM =
      CycleViewModel(defaultCycleLength: 32, defaultCycleDay: 14);

  // ─── Core Cycle & Health State ──────────────────────────────────────────────
  DateTime? _lastPeriodStartDate;
  int _currentCycleDay = 14;
  int _cycleLength = 32; // Default baseline for Stage 4 (often slightly variable)
  int _periodLength = 5;
  bool _hasLoggedPeriod = false;

  // ─── Health Context & Flare Mode ──────────────────────────────────────────
  String _userHealthContext = 'Hormonal Balance & Cycle Regularity';
  bool _isFlareModeActive = false;
  int _flarePainScale = 6;
  final Set<String> _selectedSignals = {};
  String _activeTrendTab = 'Symptoms';

  // ─── Dynamic AI & Narrative State ──────────────────────────────────────────
  String? _dynamicDocsyNarrative;
  String? _dynamicDocsyNote;
  String? _dynamicDocsyHeadline;
  bool _isLoadingAi = false;
  StreamSubscription? _periodEventSub;

  // ─── Saved Treatments & Timeline ───────────────────────────────────────────
  final List<Map<String, dynamic>> _treatments = [];

  // ─── Saved Health Records & Labs ───────────────────────────────────────────
  final List<Map<String, dynamic>> _healthRecords = [];

  // ─── Support Circle ────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _supportCircle = [];

  late final ScrollController _internalScrollController = ScrollController();
  ScrollController get _effectiveScrollController => widget.scrollController ?? _internalScrollController;

  static const Color blushyPrimary = Color(0xFFDD0D22);
  static const Color cardBorderColor = Color(0xFFEFE8E0);
  static const Color cardBgColor = Colors.white;
  static const Color textMain = Color(0xFF221510);
  static const Color textMuted = Color(0xFF7A6B72);

  String get _currentPhaseName {
    if (!_hasLoggedPeriod) return 'Baseline Tracking';
    if (_currentCycleDay <= _periodLength) return 'Menstrual Phase';
    if (_currentCycleDay <= _periodLength + 8) return 'Follicular Phase';
    if (_currentCycleDay <= _periodLength + 12) return 'Ovulatory Phase';
    return 'Luteal Phase';
  }

  @override
  void initState() {
    super.initState();
    _cycleVM.addListener(_onCycleChanged);
    _loadStage4Data();
    _loadPeriodData();
    _fetchDynamicAiInsights();

    _periodEventSub = HomeEventBus().onEvent.listen((event) {
      if (event is PeriodLoggedEvent && mounted) {
        setState(() {
          _lastPeriodStartDate = event.date;
          _hasLoggedPeriod = true;
          final diff = DateTime.now().difference(event.date).inDays;
          _currentCycleDay = ((diff % _cycleLength) + 1).clamp(1, _cycleLength);
        });
        _fetchDynamicAiInsights();
      }
    });
  }

  @override
  void dispose() {
    _periodEventSub?.cancel();
    _cycleVM.removeListener(_onCycleChanged);
    _cycleVM.dispose();
    _internalScrollController.dispose();
    super.dispose();
  }

  void _loadStage4Data() {
    try {
      final profile = BlushyStorage.read('user_profile.json');
      if (profile is Map) {
        final conditions = profile['medical_conditions'] ?? profile['conditions'] ?? profile['profile']?['medical_conditions'];
        if (conditions is List && conditions.isNotEmpty) {
          _userHealthContext = conditions.join(' & ');
        }
      }

      final savedSignals = UserStateStore.read('stage4_logged_signals');
      if (savedSignals is Map && savedSignals['signals'] is List) {
        _selectedSignals.clear();
        _selectedSignals.addAll((savedSignals['signals'] as List).map((e) => e.toString()));
      }

      final savedTreatments = UserStateStore.read('stage4_treatments');
      if (savedTreatments is Map && savedTreatments['items'] is List && (savedTreatments['items'] as List).isNotEmpty) {
        _treatments.clear();
        _treatments.addAll((savedTreatments['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final savedRecords = UserStateStore.read('stage4_health_records');
      if (savedRecords is Map && savedRecords['items'] is List && (savedRecords['items'] as List).isNotEmpty) {
        _healthRecords.clear();
        _healthRecords.addAll((savedRecords['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final savedCircle = UserStateStore.read('stage4_support_circle');
      if (savedCircle is Map && savedCircle['items'] is List && (savedCircle['items'] as List).isNotEmpty) {
        _supportCircle.clear();
        _supportCircle.addAll((savedCircle['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}
  }

  void _saveTreatmentsToStorage() {
    try {
      UserStateStore.write('stage4_treatments', {'items': _treatments});
    } catch (_) {}
  }

  void _saveHealthRecordsToStorage() {
    try {
      UserStateStore.write('stage4_health_records', {'items': _healthRecords});
    } catch (_) {}
  }

  void _saveSupportCircleToStorage() {
    try {
      UserStateStore.write('stage4_support_circle', {'items': _supportCircle});
    } catch (_) {}
  }

  void _toggleSignal(String signal) {
    setState(() {
      if (_selectedSignals.contains(signal)) {
        _selectedSignals.remove(signal);
      } else {
        _selectedSignals.add(signal);
      }
    });

    try {
      UserStateStore.write('stage4_logged_signals', {
        'signals': _selectedSignals.toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      ApiCheckinService().submitDailyCheckin(
        logDate: DateTime.now().toIso8601String().substring(0, 10),
        symptoms: _selectedSignals.toList(),
      );
    } catch (_) {}
  }

  void _loadPeriodData() {
    // Delegated to the view model; _onCycleChanged mirrors the result.
    _cycleVM.load();
  }

  /// The View reacting to its ViewModel.
  void _onCycleChanged() {
    if (!mounted) return;
    setState(() {
      _cycleState = _cycleVM.state;
      _hasLoggedPeriod = _cycleVM.hasLoggedPeriod;
      _lastPeriodStartDate = _cycleVM.lastPeriodStart;
      _cycleLength = _cycleVM.cycleLength;
      _periodLength = _cycleVM.periodLength;
      _currentCycleDay = _cycleVM.currentCycleDay;
    });
  }

  Future<void> _fetchDynamicAiInsights() async {
    if (!mounted) return;
    setState(() => _isLoadingAi = true);
    try {
      final insights = await ApiSiaService().getHealthInsights(
        stage: 'hormonal_health',
        cycleDay: _hasLoggedPeriod ? _currentCycleDay : null,
      );
      if (mounted && insights.isNotEmpty) {
        setState(() {
          _dynamicDocsyNarrative = insights['thought'] ?? insights['narrative'] ?? insights['summary'] ?? (insights['insights'] is List && (insights['insights'] as List).isNotEmpty ? (insights['insights'] as List).first.toString() : null);
          _dynamicDocsyNote = insights['note'] ?? insights['oneThingToKeepInMind'] ?? insights['headline'];
          if (insights['headline'] is String && (insights['headline'] as String).trim().isNotEmpty) {
            _dynamicDocsyHeadline = (insights['headline'] as String).trim();
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  void _openLogPeriodDialog(BuildContext context) {
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
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 18),
                  Text(AppLocalizations.of(context).hhLogPeriodDate, style: GoogleFonts.cormorantGaramond(fontSize: 26, fontWeight: FontWeight.w700, color: textMain)),
                  const SizedBox(height: 18),
                  CalendarDatePicker(
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 120)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    onDateChanged: (val) => setModalState(() => selectedDate = val),
                  ),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context).hhFlowIntensity, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: textMain)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['light', 'medium', 'heavy'].map((f) {
                      final isSel = flow == f;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => flow = f),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSel ? blushyPrimary : cardBgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSel ? blushyPrimary : const Color(0xFFEDE4DC)),
                            ),
                            child: Text(
                              f[0].toUpperCase() + f.substring(1),
                              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: isSel ? Colors.white : textMain),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        setState(() {
                          _lastPeriodStartDate = selectedDate;
                          _hasLoggedPeriod = true;
                          final diff = DateTime.now().difference(selectedDate).inDays;
                          _currentCycleDay = ((diff % _cycleLength) + 1).clamp(1, _cycleLength);
                        });
                        try {
                          BlushyStorage.write('last_period_entry.json', {
                            'periodStartDate': selectedDate.toIso8601String(),
                            'flow': flow,
                            'loggedAt': DateTime.now().toIso8601String(),
                          });
                        } catch (_) {}
                        try {
                          await ApiPeriodService().logPeriodEntry(periodStartDate: selectedDate, flowIntensity: flow);
                        } catch (_) {}
                        HomeEventBus().emit(PeriodLoggedEvent(flowIntensity: flow, date: selectedDate));
                        _fetchDynamicAiInsights();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blushyPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(AppLocalizations.of(context).hhSavePeriodDate, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
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

  void _openDocsyWithPrompt(BuildContext context, String prompt) {
    openDocsyWith(context, prompt);
  }

  // ════════════════════════════════════════════════════════════════
  // 01 — EDITORIAL GREETING + "TODAY" IDENTITY (Unboxed & Subtle)
  // ════════════════════════════════════════════════════════════════
  Widget _buildEditorialGreeting(BuildContext context) {
    // Read `name`, `firstName` and `profile.name` -- none of which onboarding
    // writes -- and so always fell through to the literal 'nithya'.
    final String userName = userDisplayName(context);

    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning,'
        : (hour < 17 ? 'Good afternoon,' : 'Good evening,');

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$timeGreeting\n',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF221510),
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
                TextSpan(
                  text: '$userName.',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: blushyPrimary,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Navigating hormonal rhythm and whole-body balance with you today.',
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF7A6B72),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 02 — THE HERO: "TODAY WITH DOCSY" ⭐ (Human-First AI Intelligence)
  // ════════════════════════════════════════════════════════════════
  Widget _buildTodayWithDocsyHero(BuildContext context) {
    String phaseHeadline;
    String phaseNarrative;
    String oneThingToKeepInMind;

    if (!_hasLoggedPeriod) {
      phaseHeadline = 'Understanding your body.';
      phaseNarrative = 'Docsy is ready to tune into your rhythm. Log your latest cycle date and daily signals to unlock tailored hormone insights, comfort guidance, and baseline pattern tracking.';
      oneThingToKeepInMind = 'Tracking your daily signals helps Blushy discover what is normal for your unique body.';
    } else {
      phaseHeadline = 'Cycle Day $_currentCycleDay · $_currentPhaseName';
      phaseNarrative = 'Your body is navigating hormonal balance. Track how your pelvic ease, stamina, and digestion feel today so Docsy can personalize your rhythm.';
      oneThingToKeepInMind = 'Restorative hydration and gentle movement help support steady hormonal transitions.';
    }

    if (_dynamicDocsyHeadline != null && _dynamicDocsyHeadline!.isNotEmpty) {
      phaseHeadline = _dynamicDocsyHeadline!;
    }

    if (_dynamicDocsyNarrative != null && _dynamicDocsyNarrative!.isNotEmpty) {
      phaseNarrative = _dynamicDocsyNarrative!;
    }

    if (_dynamicDocsyNote != null && _dynamicDocsyNote!.isNotEmpty) {
      oneThingToKeepInMind = _dynamicDocsyNote!;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorderColor),
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
          // Top identity badge - responsive Wrap prevents any right overflow
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DocsyAvatar(
                    size: 22,
                    color: blushyPrimary,
                    hasBackground: true,
                  ),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).hhTodayWithDocsy,
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: blushyPrimary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _openSomethingFeelsDifferentSheet(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFDFC2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.help_outline_rounded, size: 12, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        'Something feels off?',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dynamic Phase Headline
          Text(
            phaseHeadline,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF221510),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Human narrative
          Text(
            phaseNarrative,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4A3E45),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // One Thing to Keep in Mind
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEDE4DC)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: const Color(0xFF221510),
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: 'One thing I’d keep in mind: ',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF221510),
                          ),
                        ),
                        TextSpan(
                          text: oneThingToKeepInMind,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF5E5057),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Primary Action: Ask Docsy
          InkWell(
            onTap: () {
              _openDocsyWithPrompt(
                context,
                'Docsy, I\'m exploring my hormonal health and cycle rhythm. What should I keep in mind today?',
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: blushyPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).hhExploreWithDocsy,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleTrackerCard(BuildContext context) {
    final int daysLeft = (_cycleLength - _currentCycleDay).clamp(0, _cycleLength);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top Row: YOUR CYCLE on left + Log Period Action Button on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: blushyPrimary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_month_outlined,
                      size: 14,
                      color: blushyPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).hhYourCycle,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: blushyPrimary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: InkWell(
                  onTap: () => _openLogPeriodDialog(context),
                  borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF3D5D8), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.water_drop_outlined,
                        size: 13,
                        color: blushyPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _hasLoggedPeriod ? 'Log your period' : '+ Log your period',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: blushyPrimary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: blushyPrimary,
                      ),
                    ],
                  ),
              ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Day Count & Phase Title
          if (_hasLoggedPeriod) ...[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Day ',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF221510),
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: '$_currentCycleDay',
                    style: GoogleFonts.manrope(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: blushyPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _currentPhaseName,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF221510),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Next cycle begins in ',
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF7A6B72),
                    ),
                  ),
                  TextSpan(
                    text: '$daysLeft Days',
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF221510),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Day ',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF9E9296),
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: '--',
                    style: GoogleFonts.manrope(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF9E9296),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(AppLocalizations.of(context).hhNoPeriodLoggedYet,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF7A6B72),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _openLogPeriodDialog(context),
              child: Text(
                'Log your period to track your cycle & hormonal phases',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: blushyPrimary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // The Fallopian Tube Track Custom Painter
          ExactBlushyTrackerWidget(
            currentDay: _currentCycleDay,
            cycleLength: _cycleLength,
            periodLength: _periodLength,
            isLogged: _hasLoggedPeriod,
            // Tapping the tracker explains where she is, rather than
            // reopening the date picker she just used. With nothing
            // logged there is no phase to explain, so the tap still
            // offers to log -- which is the only useful thing then.
            onTap: () => _hasLoggedPeriod
                ? _openDocsyWithPrompt(context, 'I am on Day $_currentCycleDay of my cycle, in the $_currentPhaseName. What is happening in my body right now?')
                : _openLogPeriodDialog(context),
          ),
          const SizedBox(height: 12),

          // Medical Disclaimer
          Text(
            _hasLoggedPeriod
                ? 'Estimated hormonal phase based on your cycle rhythm. Not medically certain.'
                : 'Blushy cycle tracker uses your logged period dates to estimate phases.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF7A6B72),
            ),
          ),
          const SizedBox(height: 10),

          if (_hasLoggedPeriod) ...[
            const SizedBox(height: 6),
            // 4-Phase Dot Legend
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPhaseDot(const Color(0xFFEF4444), 'Menstrual'),
                  const SizedBox(width: 12),
                  _buildPhaseDot(const Color(0xFFF97316), 'Follicular'),
                  const SizedBox(width: 12),
                  _buildPhaseDot(const Color(0xFFFACC15), 'Ovulation'),
                  const SizedBox(width: 12),
                  _buildPhaseDot(const Color(0xFF7C3AED), 'Luteal'),
                ],
              ),
            ),
          ],

          // Insights Row
          //
          // Living with my cycle and First period have carried one since they
          // were written; this card never did, so the one stage whose whole
          // point is that hormones behave unusually was the one that could not
          // ask about them. Same shape and same wording as the others.
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.8, color: Color(0xFFECE4DC)),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              if (_hasLoggedPeriod) {
                _openDocsyWithPrompt(
                  context,
                  'I am on Day $_currentCycleDay of my cycle, in the '
                  '$_currentPhaseName. What is happening in my body right now?',
                );
              } else {
                _openLogPeriodDialog(context);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    _hasLoggedPeriod
                        ? Icons.favorite_border_rounded
                        : Icons.lock_outline_rounded,
                    size: 16,
                    color: _hasLoggedPeriod
                        ? blushyPrimary
                        : const Color(0xFF9E9296),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasLoggedPeriod
                          ? 'Insights for your phase'
                          : 'Log your period to unlock phase insights',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _hasLoggedPeriod
                            ? const Color(0xFF221510)
                            : const Color(0xFF7A6B72),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF7A6B72),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5E5057),
          ),
        ),
      ],
    );
  }

  Widget _buildFlareModeBanner(BuildContext context) {
    if (_isFlareModeActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorderColor, width: 1.0),
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
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFECEB),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(child: Text('🫶', style: TextStyle(fontSize: 18))),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(AppLocalizations.of(context).hhFlareComfortModeActive,
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: blushyPrimary,
                            letterSpacing: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _isFlareModeActive = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(AppLocalizations.of(context).hhExitFlareMode,
                          style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w700, color: blushyPrimary),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.close_rounded, size: 13, color: blushyPrimary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Okay. Let’s make today easier.', style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: textMain)),
            const SizedBox(height: 4),
            Text(
              'Comfort tools are active. When you\'re feeling better, tap "Exit Flare Mode" above.',
              style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF7A6B72)),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => setState(() => _isFlareModeActive = true),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorderColor, width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFFFECEB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_rounded, size: 16, color: blushyPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('I’m having a flare / bad day', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: textMain)),
                  const SizedBox(height: 2),
                  Text('Simplify today’s view into immediate comfort and relief', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF7A6B72))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: blushyPrimary),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 05 — WHAT'S DIFFERENT LATELY? (AI Change Detection)
  // ════════════════════════════════════════════════════════════════
  Widget _buildWhatsDifferentLatelySection(BuildContext context) {
    final bool isFirstTime = !_hasLoggedPeriod && _selectedSignals.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderWithIcon(
          title: 'WHAT’S DIFFERENT LATELY?',
          icon: Icons.auto_graph_rounded,
          badgeColor: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 10),
        if (isFirstTime)
          _buildChangeCard(
            icon: Icons.track_changes_rounded,
            title: 'Establishing Your Baseline',
            desc: 'Log today’s signals to allow Docsy to detect shifts from your normal rhythm.',
            badge: 'Day 1 Baseline',
            badgeColor: const Color(0xFF0284C7),
            onTap: () => _openDocsyWithPrompt(
              context,
              'Docsy, I am starting my hormonal health journey. How do you track my personal baseline?',
            ),
          )
        else ...[
          if (_selectedSignals.isNotEmpty)
            _buildChangeCard(
              icon: Icons.bolt_rounded,
              title: '${_selectedSignals.first} Noted Today',
              desc: 'Recorded ${_selectedSignals.length} active signal${_selectedSignals.length > 1 ? "s" : ""} in today\'s log',
              badge: 'Real-time',
              badgeColor: const Color(0xFF059669),
              onTap: () => _openDocsyWithPrompt(
                context,
                'Docsy, I logged ${_selectedSignals.join(", ")} today. What does this mean for my hormonal rhythm?',
              ),
            ),
          if (_hasLoggedPeriod) ...[
            const SizedBox(height: 8),
            _buildChangeCard(
              icon: Icons.calendar_today_rounded,
              title: 'Cycle Day $_currentCycleDay',
              desc: 'Current phase: $_currentPhaseName',
              badge: 'Tracked',
              badgeColor: const Color(0xFFD97706),
              onTap: () => _openDocsyWithPrompt(
                context,
                'Docsy, tell me what hormones are active on Day $_currentCycleDay ($_currentPhaseName) for $_userHealthContext.',
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildChangeCard({
    required IconData icon,
    required String title,
    required String desc,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: badgeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.manrope(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: const Color(0xFF6B5E65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFB0A2A8)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 06 — HOW ARE YOU FEELING IN YOUR BODY? (Visual Icon Grid)
  // ════════════════════════════════════════════════════════════════
  Widget _buildHowAreYouFeelingSection(BuildContext context) {
    final primarySignals = [
      {'name': 'Pelvic ache', 'emoji': '🌸', 'icon': Icons.spa_outlined},
      {'name': 'Bloating', 'emoji': '🫖', 'icon': Icons.water_drop_outlined},
      {'name': 'Fatigue / Low energy', 'emoji': '⚡', 'icon': Icons.bolt_rounded},
      {'name': 'Brain fog', 'emoji': '💭', 'icon': Icons.psychology_outlined},
      {'name': 'Mood shifts', 'emoji': '🕊️', 'icon': Icons.mood_outlined},
      {'name': 'Spotting / Flow', 'emoji': '🩸', 'icon': Icons.grain_rounded},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: blushyPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_outline_rounded, size: 15, color: blushyPrimary),
                  ),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).hhDailySignals,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: blushyPrimary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _openTellDocsyVoiceSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEDE4DC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mic_none_rounded, size: 13, color: blushyPrimary),
                      const SizedBox(width: 4),
                      Text(AppLocalizations.of(context).hhVoiceNotes,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: blushyPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3x2 Clean Icon Grid (visual, low-text)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: primarySignals.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, idx) {
              final item = primarySignals[idx];
              final name = item['name'] as String;
              final emoji = item['emoji'] as String;
              final isSelected = _selectedSignals.contains(name);

              return InkWell(
                onTap: () => _toggleSignal(name),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFF1F2) : cardBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? blushyPrimary : const Color(0xFFEDE4DC),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 10.0,
                            height: 1.15,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF9F1239) : textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openTellDocsyVoiceSheet(BuildContext context) {
    final TextEditingController textCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Tell Docsy in your own words',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Example: "My cycle is late and I’ve been feeling low energy with mild pelvic tension."',
                style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                autofocus: true,
                style: GoogleFonts.manrope(fontSize: 13, color: textMain),
                decoration: InputDecoration(
                  hintText: 'Share how your body is feeling today...',
                  filled: true,
                  fillColor: cardBgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEDE4DC))),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    final text = textCtrl.text.trim();
                    if (text.isNotEmpty) {
                      Navigator.pop(ctx);
                      _openDocsyWithPrompt(
                        context,
                        'Here is what I am experiencing: "$text". Extract key symptoms and connect with my health context ($_userHealthContext).',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blushyPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(AppLocalizations.of(context).hhAnalyzeWithDocsy, style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 07 — SYMPTOM RELATIONSHIPS (Responsive & Zero Overflow)
  // ════════════════════════════════════════════════════════════════
  Widget _buildSymptomRelationshipsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderWithIcon(
          title: 'OBSERVED RELATIONSHIPS',
          icon: Icons.hub_outlined,
          badgeColor: const Color(0xFF7C3AED),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedSignals.length < 2) ...[
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.hub_outlined, size: 18, color: Color(0xFF7C3AED)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context).hhPatternMemoryBuilding,
                            style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: textMain),
                          ),
                          Text(
                            _selectedSignals.isEmpty
                                ? 'Log 2 or more daily signals above to see real connections emerge.'
                                : '1 signal logged. Select 1 more to observe connections.',
                            style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _buildResponsivePatternCard(
                  context,
                  icon1: _getIconForSignal(_selectedSignals.elementAt(0)),
                  label1: _selectedSignals.elementAt(0),
                  icon2: _getIconForSignal(_selectedSignals.elementAt(1)),
                  label2: _selectedSignals.elementAt(1),
                  timing: 'Observed co-occurring in today\'s log · $_currentPhaseName',
                ),
                if (_selectedSignals.length >= 4) ...[
                  const Divider(height: 18, color: Color(0xFFF2EBE5)),
                  _buildResponsivePatternCard(
                    context,
                    icon1: _getIconForSignal(_selectedSignals.elementAt(2)),
                    label1: _selectedSignals.elementAt(2),
                    icon2: _getIconForSignal(_selectedSignals.elementAt(3)),
                    label2: _selectedSignals.elementAt(3),
                    timing: 'Observed in today\'s health signals',
                  ),
                ],
              ],
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _openDocsyWithPrompt(
                  context,
                  _selectedSignals.isEmpty
                      ? 'Docsy, how does pattern memory uncover symptom relationships across my cycle?'
                      : 'Docsy, explain the connection between ${_selectedSignals.join(" and ")} without making causal medical claims.',
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insights_rounded, size: 14, color: blushyPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Explore connections with Docsy →',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: blushyPrimary,
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

  String _getIconForSignal(String signal) {
    if (signal.contains('Pelvic')) return '🌸';
    if (signal.contains('Bloat')) return '🫖';
    if (signal.contains('Fatigue') || signal.contains('energy')) return '⚡';
    if (signal.contains('fog')) return '💭';
    if (signal.contains('Mood')) return '🕊️';
    if (signal.contains('Spot') || signal.contains('Flow')) return '🩸';
    return '✨';
  }

  Widget _buildResponsivePatternCard(
    BuildContext context, {
    required String icon1,
    required String label1,
    required String icon2,
    required String label2,
    required String timing,
  }) {
    return InkWell(
      onTap: () => _openDocsyWithPrompt(
        context,
        'Docsy, explain the connection between $label1 and $label2 observed in today\'s log without making causal medical claims.',
      ),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEDE4DC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(icon1, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          label1,
                          style: GoogleFonts.manrope(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.sync_alt_rounded, size: 14, color: Color(0xFF9E9296)),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEDE4DC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(icon2, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          label2,
                          style: GoogleFonts.manrope(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  timing,
                  style: GoogleFonts.manrope(fontSize: 10.0, fontStyle: FontStyle.italic, color: textMuted),
                ),
              ),
              const SizedBox(width: 4),
              Text(AppLocalizations.of(context).hhAskDocsy,
                style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w700, color: blushyPrimary),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 8, color: blushyPrimary),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 08 — WHAT CHANGED AFTER TREATMENT? (Clean & Visual)
  // ════════════════════════════════════════════════════════════════
  // ════════════════════════════════════════════════════════════════
  // 08 — WHAT CHANGED AFTER TREATMENT? (Clean & Visual)
  // ════════════════════════════════════════════════════════════════
  Widget _buildTreatmentTimelineSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderWithIcon(
          title: 'TREATMENTS & PROTOCOLS',
          icon: Icons.medication_rounded,
          badgeColor: const Color(0xFF059669),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_treatments.isEmpty) ...[
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.vaccines_rounded, color: Color(0xFF0284C7), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context).hhNoTreatmentsRecordedYet,
                            style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: textMain),
                          ),
                          Text(
                            'Record supplements or medications to track how your body responds over time.',
                            style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ] else ...[
                ..._treatments.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final t = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEDE4DC)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.vaccines_rounded, color: Color(0xFF0284C7), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['name'] as String? ?? 'Treatment',
                                style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: textMain),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${t['dosage'] ?? ""} · ${t['startDate'] ?? "Active"}',
                                style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() => _treatments.removeAt(idx));
                            _saveTreatmentsToStorage();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF9E9296)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
              InkWell(
                onTap: () => _openAddTreatmentModal(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 14, color: blushyPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Record new medication / protocol',
                      style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: blushyPrimary),
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

  void _openAddTreatmentModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    final docCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context).hhAddTreatmentProtocol, style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.w700, color: textMain)),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Treatment Name (e.g. Inositol, Magnesium, Progesterone)')),
              TextField(controller: doseCtrl, decoration: const InputDecoration(labelText: 'Dosage / Timing (e.g. 2000mg with breakfast)')),
              TextField(controller: docCtrl, decoration: const InputDecoration(labelText: 'Prescribed by (e.g. OB/GYN, Self-care)')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _treatments.add({
                          'name': nameCtrl.text.trim(),
                          'dosage': doseCtrl.text.trim().isNotEmpty ? doseCtrl.text.trim() : 'As prescribed',
                          'startDate': 'Just now',
                          'prescribedBy': docCtrl.text.trim().isNotEmpty ? docCtrl.text.trim() : 'Clinician',
                          'notes': 'Added to health journey timeline.',
                        });
                      });
                      _saveTreatmentsToStorage();
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: blushyPrimary),
                  child: Text(AppLocalizations.of(context).hhSaveTreatment, style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 09 — MY HEALTH RECORDS (Compact & Visual)
  // ════════════════════════════════════════════════════════════════
  Widget _buildHealthRecordsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderWithIcon(
          title: 'MY HEALTH RECORDS',
          icon: Icons.folder_shared_outlined,
          badgeColor: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 10),
        if (_healthRecords.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.science_outlined, color: Color(0xFF16A34A), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No health records uploaded yet',
                            style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: textMain),
                          ),
                          Text(
                            'Upload ultrasound reports or hormone panels for Docsy to organize.',
                            style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _openAddHealthRecordModal(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, size: 14, color: blushyPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'Upload lab report / scan',
                        style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: blushyPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          ..._healthRecords.asMap().entries.map((entry) {
            final idx = entry.key;
            final rec = entry.value;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.science_outlined, color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec['title'] as String? ?? 'Record',
                          style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: textMain),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${rec['date'] ?? "Recent"} · ${rec['clinic'] ?? "Lab"}',
                          style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _openDocsyWithPrompt(context, 'Explain results for: ${rec['title']}'),
                    child: Text(AppLocalizations.of(context).hhAskDocsy2,
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: blushyPrimary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      setState(() => _healthRecords.removeAt(idx));
                      _saveHealthRecordsToStorage();
                    },
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9E9296)),
                  ),
                ],
              ),
            );
          }),
          InkWell(
            onTap: () => _openAddHealthRecordModal(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 14, color: blushyPrimary),
                  const SizedBox(width: 6),
                  Text(AppLocalizations.of(context).hhUploadAnotherRecord,
                    style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: blushyPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openAddHealthRecordModal(BuildContext context) {
    final titleCtrl = TextEditingController();
    final clinicCtrl = TextEditingController();
    final summaryCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Health Record / Lab', style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.w700, color: textMain)),
              const SizedBox(height: 12),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Record Title (e.g. Hormone Panel, Pelvic Ultrasound)')),
              TextField(controller: clinicCtrl, decoration: const InputDecoration(labelText: 'Clinic / Lab Name')),
              TextField(controller: summaryCtrl, decoration: const InputDecoration(labelText: 'Key Findings / Notes')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _healthRecords.add({
                          'title': titleCtrl.text.trim(),
                          'clinic': clinicCtrl.text.trim().isNotEmpty ? clinicCtrl.text.trim() : 'Clinic / Lab',
                          'date': '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
                          'summary': summaryCtrl.text.trim().isNotEmpty ? summaryCtrl.text.trim() : 'Uploaded report',
                        });
                      });
                      _saveHealthRecordsToStorage();
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: blushyPrimary),
                  child: Text(AppLocalizations.of(context).hhSaveRecord, style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 10 — GET READY FOR YOUR APPOINTMENT (Visual Card)
  // ════════════════════════════════════════════════════════════════
  Widget _buildDoctorReadinessSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medical_services_outlined, size: 17, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Text(AppLocalizations.of(context).hhDoctorVisitBrief,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: blushyPrimary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Turn your logs into a 1-page medical brief.',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Export your symptom trends, treatments, and cycle history formatted for your doctor appointment.',
            style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF7A6B72), height: 1.4),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => _openDoctorSummarySheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: blushyPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 15, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).hhCreateDoctorSummary, style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDoctorSummarySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).hhClinicalBrief, style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.w700, color: textMain)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    Text('• Focus: $_userHealthContext', style: GoogleFonts.manrope(fontSize: 12)),
                    Text('• Logged Signals: ${_selectedSignals.isEmpty ? "None logged today" : _selectedSignals.join(", ")}', style: GoogleFonts.manrope(fontSize: 12)),
                    Text('• Active Treatments: ${_treatments.isEmpty ? "None recorded" : _treatments.map((t) => t["name"]).join(", ")}', style: GoogleFonts.manrope(fontSize: 12)),
                    // Printed only when it came from logged periods. This line
                    // used to show the 32-day default to someone who had
                    // logged nothing, in a brief headed "Clinical Brief".
                    Text(
                      _hasLoggedPeriod
                          ? '• Baseline Cycle: $_cycleLength days (from your logged periods)'
                          : '• Baseline Cycle: not established yet, no periods logged',
                      style: GoogleFonts.manrope(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'All entries are self-reported.',
                      style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).hhClose),
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 11 — MY SUPPORT CIRCLE & SAFETY ESCALATION
  // ════════════════════════════════════════════════════════════════
  Widget _buildSupportCircleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderWithIcon(
          title: 'MY SUPPORT CIRCLE',
          icon: Icons.groups_outlined,
          badgeColor: const Color(0xFFD97706),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_supportCircle.isEmpty) ...[
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEDE4DC)),
                      ),
                      child: const Icon(Icons.person_add_alt_1_outlined, size: 16, color: textMain),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Add trusted clinicians, family, or partner for 1-tap support updates during flare-ups.',
                        style: GoogleFonts.manrope(fontSize: 11, color: textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ] else ...[
                ..._supportCircle.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final member = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFEDE4DC)),
                              ),
                              child: const Icon(Icons.person_outline_rounded, size: 16, color: textMain),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member['name'] as String? ?? 'Contact', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: textMain)),
                                Text(member['role'] as String? ?? 'Support', style: GoogleFonts.manrope(fontSize: 10, color: textMuted)),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update sent to ${member['name']}')));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFEDE4DC)),
                                ),
                                child: Text(AppLocalizations.of(context).hhUpdate, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: blushyPrimary)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() => _supportCircle.removeAt(idx));
                                _saveSupportCircleToStorage();
                              },
                              child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9E9296)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
              InkWell(
                onTap: () => _openAddContactModal(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 14, color: blushyPrimary),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context).hhAddTrustedContact,
                      style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: blushyPrimary),
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

  void _openAddContactModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context).hhAddSupportContact, style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.w700, color: textMain)),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Contact Name')),
              TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Role (e.g. Doctor, Partner, Mom)')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone / Details')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _supportCircle.add({
                          'name': nameCtrl.text.trim(),
                          'role': roleCtrl.text.trim().isNotEmpty ? roleCtrl.text.trim() : 'Support',
                          'phone': phoneCtrl.text.trim(),
                        });
                      });
                      _saveSupportCircleToStorage();
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: blushyPrimary),
                  child: Text(AppLocalizations.of(context).hhSaveContact, style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClinicalSafetySection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, size: 15, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              Text(
                'SOMETHING DOESN’T FEEL RIGHT?',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: blushyPrimary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'If you experience severe sudden pain, soaking >2 pads/hr, or dizziness, please seek immediate clinical care.',
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              color: const Color(0xFF7A6B72),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeaderWithIcon({required String title, required IconData icon, required Color badgeColor}) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 13, color: badgeColor),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: blushyPrimary, letterSpacing: 0.8),
        ),
      ],
    );
  }

  void _openSomethingFeelsDifferentSheet(BuildContext context) {
    final textCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Something feels off?', style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.w700, color: textMain)),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe what you are noticing...',
                  filled: true,
                  fillColor: cardBgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  final text = textCtrl.text.trim();
                  Navigator.pop(ctx);
                  if (text.isNotEmpty) {
                    _openDocsyWithPrompt(
                      context,
                      'Something feels different: "$text". Based on my hormonal health profile, what could this indicate and what should I do?',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: blushyPrimary),
                child: Text(AppLocalizations.of(context).hhCheckWithDocsy, style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return wrapStageDashboardLayout(
      context: context,
      isNested: widget.isNested,
      child: ListView(
        controller: _effectiveScrollController,
        shrinkWrap: widget.isNested,
        physics: widget.isNested ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _buildEditorialGreeting(context),
          const SizedBox(height: 8),
          StageStateNotice(
            state: _cycleState,
            hasData: _hasLoggedPeriod,
            emptyMessage: 'Log the first day of your last period and this page '
                'starts working from your own cycle instead of general guidance.',
            onRetry: _loadPeriodData,
          ),

          _buildTodayWithDocsyHero(context),
          const SizedBox(height: 14),
          _buildCycleTrackerCard(context),
          const SizedBox(height: 22),
          const LogSymptomsSection(stageKey: 'hormonalhealth'),
          const SizedBox(height: 14),
          _buildFlareModeBanner(context),
          const SizedBox(height: 16),
          _buildWhatsDifferentLatelySection(context),
          const SizedBox(height: 16),
          _buildHowAreYouFeelingSection(context),
          const SizedBox(height: 16),
          _buildSymptomRelationshipsSection(context),
          const SizedBox(height: 16),
          _buildTreatmentTimelineSection(context),
          const SizedBox(height: 16),
          _buildHealthRecordsSection(context),
          const SizedBox(height: 16),
          _buildDoctorReadinessSection(context),
          const SizedBox(height: 16),
          _buildSupportCircleSection(context),
          const SizedBox(height: 14),
          _buildClinicalSafetySection(context),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}
