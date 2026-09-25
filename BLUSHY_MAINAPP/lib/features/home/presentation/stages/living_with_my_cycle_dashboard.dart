import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/storage.dart';
import '../../services/home_event_bus.dart';
import '../../../sia/open_docsy.dart';
import '../../../../services/api_period_service.dart';
import '../../view_models/cycle_view_model.dart';
import '../../../../shared/live_refresh.dart';
import '../../../../services/api_sia_service.dart';
import '../../widgets/cycle_tracker_image.dart';
import '../../widgets/real_insights_list.dart';
import 'stage_shared_components.dart';
import '../../../../shared/user_display_name.dart';
import '../../widgets/log_symptoms_section.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/user_state_store.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// STAGE 3: LIVING WITH MY CYCLE — THE HUMAN-FIRST AI INTELLIGENCE LAYER
///
/// Philosophy: NOTICE → UNDERSTAND → ADAPT → LIVE
/// "Blushy understands where I am in my cycle and quietly helps me live today better."
/// The woman's actual day is the hero; the cycle is the ambient intelligence.
/// ════════════════════════════════════════════════════════════════════════════

class LivingWithMyCycleDashboard extends StatefulWidget {
  final bool isNested;
  final ScrollController? scrollController;

  const LivingWithMyCycleDashboard({
    super.key,
    this.isNested = false,
    this.scrollController,
  });

  @override
  State<LivingWithMyCycleDashboard> createState() => _LivingWithMyCycleDashboardState();
}

class _LivingWithMyCycleDashboardState extends State<LivingWithMyCycleDashboard>
    with WidgetsBindingObserver, LiveRefresh {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ScrollController _internalScrollController = ScrollController();
  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _internalScrollController;

  // Real-time Cycle Tracking State
  DateTime? _lastPeriodStartDate;
  int _currentCycleDay = 14;
  int _cycleLength = 28;
  int _periodLength = 5;
  // Starts false, like the other cycle dashboards. Starting true meant the
  // first frame rendered the Day 14 fallback as though a period had been
  // logged, and only corrected once the async load returned -- which against a
  // sleeping backend is tens of seconds of simulated cycle data (spec §4:
  // never show simulated cycle days to a user with no period data).
  bool _hasLoggedPeriod = false;

  /// This screen is the View; the cycle read lives in the tested
  /// CycleViewModel and is mirrored back by _onCycleChanged.
  final CycleViewModel _cycleVM =
      CycleViewModel(defaultCycleLength: 28, defaultCycleDay: 14);

  StreamSubscription? _periodEventSub;

  // Real-time AI Companion (Docsy) State
  String? _dynamicDocsyNarrative;

  // Interactive Signals & Body State
  final Set<String> _selectedNoticings = <String>{};

  // Primary life focus: reorders the Daily Cycle Sync recommendations toward
  // what she cares about most. Persisted to UserStateStore.
  String _focusMode = 'career';

  // Functional work/life impact for today (feeds the doctor summary).
  String? _workImpact;

  // Interactive Pillar in Daily Cycle Sync (Focus / Nourish / Move / Recharge)
  String? _activePillar;
  bool _isAiNarrativeExpanded = false;

  // Colors
  static const Color blushyPrimary = Color(0xFFDD0D22);
  static const Color blushySoftPink = Color(0xFFFFECEB);
  static const Color cardBorderColor = Color(0xFFEAE3DC);

  String get _currentPhaseName {
    if (_currentCycleDay <= _periodLength) return 'Menstrual Phase';
    if (_currentCycleDay <= _periodLength + 7) return 'Follicular Phase';
    if (_currentCycleDay <= _periodLength + 11) return 'Ovulatory Phase';
    return 'Luteal Phase';
  }

  bool get _isMenstrualPhase => _currentCycleDay <= _periodLength;
  bool get _isFollicularPhase =>
      _currentCycleDay > _periodLength && _currentCycleDay <= _periodLength + 7;
  bool get _isOvulatoryPhase =>
      _currentCycleDay > _periodLength + 7 && _currentCycleDay <= _periodLength + 11;
  bool get _isLutealPhase => _currentCycleDay > _periodLength + 11;

  /// The tracker's colour for the current phase, so the "Day N" number matches
  /// the arc and legend (Menstrual red, Follicular orange, Ovulatory yellow,
  /// Luteal purple).
  Color get _currentPhaseColor {
    if (_currentCycleDay <= _periodLength) return const Color(0xFFEF4444);
    if (_currentCycleDay <= _periodLength + 7) return const Color(0xFFF97316);
    if (_currentCycleDay <= _periodLength + 11) return const Color(0xFFFACC15);
    return const Color(0xFF7C3AED);
  }

  @override
  void initState() {
    super.initState();
    _cycleVM.addListener(_onCycleChanged);
    _loadStage3Data();
    _loadPeriodData();
    _fetchDynamicAiInsights();
    startLiveRefresh();

    _periodEventSub = HomeEventBus().onEvent.listen((event) {
      if (event is PeriodLoggedEvent && mounted) {
        final now = DateTime.now();
        final diff = now.difference(event.date).inDays;
        setState(() {
          _lastPeriodStartDate = event.date;
          _hasLoggedPeriod = true;
          _currentCycleDay = (diff + 1).clamp(1, _cycleLength);
        });
        _fetchDynamicAiInsights();
      }
    });
  }

  @override
  Future<void> refreshNow() => _cycleVM.load();

  @override
  void dispose() {
    stopLiveRefresh();
    _periodEventSub?.cancel();
    _cycleVM.removeListener(_onCycleChanged);
    _cycleVM.dispose();
    _internalScrollController.dispose();
    super.dispose();
  }

  void _loadStage3Data() {
    try {
      // 1. Noticings
      final savedNoticings = UserStateStore.read('stage3_noticings');
      if (savedNoticings['selected'] is List) {
        _selectedNoticings.clear();
        _selectedNoticings.addAll(
          (savedNoticings['selected'] as List).map((e) => e.toString()),
        );
      }

      // 2. Primary life focus.
      final savedFocus = UserStateStore.read('stage3_focus_mode');
      if (savedFocus['focus'] != null) {
        _focusMode = savedFocus['focus'].toString();
      }

      // 3. Today's functional work/life impact.
      final today = DateTime.now().toIso8601String().split('T').first;
      final savedImpact = UserStateStore.read('stage3_work_impact_$today');
      if (savedImpact['impact'] != null) {
        _workImpact = savedImpact['impact'].toString();
      }
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
      _hasLoggedPeriod = _cycleVM.hasLoggedPeriod;
      _lastPeriodStartDate = _cycleVM.lastPeriodStart;
      _cycleLength = _cycleVM.cycleLength;
      _periodLength = _cycleVM.periodLength;
      _currentCycleDay = _cycleVM.currentCycleDay;
    });
  }

  Future<void> _fetchDynamicAiInsights() async {
    if (!mounted) return;
    try {
      final insights = await ApiSiaService().getHealthInsights(
        stage: 'living_with_my_cycle',
        cycleDay: _hasLoggedPeriod ? _currentCycleDay : null,
        phase: _hasLoggedPeriod ? _currentPhaseName : null,
      );
      if (mounted && insights.isNotEmpty) {
        final thought = insights['thought'] ??
            insights['narrative'] ??
            insights['summary'] ??
            (insights['insights'] is List && (insights['insights'] as List).isNotEmpty
                ? (insights['insights'] as List).first.toString()
                : null);
        if (thought is String && thought.trim().isNotEmpty) {
          setState(() {
            _dynamicDocsyNarrative = thought.trim();
          });
        }
      }
    } catch (_) {
      // Graceful fallback
    }
  }

  void _openLogPeriodDialog(BuildContext context) async {
    final now = DateTime.now();
    DateTime selected = _lastPeriodStartDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected.isAfter(now) ? now : selected,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
      helpText: 'WHEN DID YOUR PERIOD START?',
      confirmText: 'SAVE PERIOD',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: blushyPrimary,
              onPrimary: Colors.white,
              surface: Color(0xFFFAF7F2),
              onSurface: Color(0xFF221510),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final diff = now.difference(picked).inDays;
      final newDay = (diff + 1).clamp(1, _cycleLength);

      setState(() {
        _lastPeriodStartDate = picked;
        _hasLoggedPeriod = true;
        _currentCycleDay = newDay;
      });

      try {
        BlushyStorage.write('last_period_entry.json', {
          'periodStartDate': picked.toIso8601String().split('T').first,
          'loggedAt': now.toIso8601String(),
        });
        final profile = Map<String, dynamic>.from(BlushyStorage.read('user_profile.json'));
        profile['lastPeriodStartDate'] = picked.toIso8601String().split('T').first;
        BlushyStorage.write('user_profile.json', profile);
      } catch (_) {}

      try {
        await ApiPeriodService().logPeriodEntry(
          periodStartDate: picked,
          flowIntensity: 'medium',
        );
      } catch (_) {}

      HomeEventBus().emit(
        PeriodLoggedEvent(
          flowIntensity: 'medium',
          date: picked,
        ),
      );
      _fetchDynamicAiInsights();
    }
  }

  void _openDocsyWithPrompt(BuildContext context, String prompt) {
    openDocsyWith(context, prompt.isNotEmpty ? prompt : null);
  }

  // Consistent Crimson Eyebrow
  Widget _buildEyebrow(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: blushyPrimary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 01 — EDITORIAL GREETING + "TODAY" IDENTITY (Unboxed & Subtle)
  // ════════════════════════════════════════════════════════════════
  Widget _buildEditorialGreeting(BuildContext context) {
    // Was: decoded['name'] ?? decoded['profile']?['name'] ?? 'nithya'.
    // Onboarding writes profile.preferredName, so neither key existed and every
    // user was greeted as "nithya".
    final String userName = userDisplayName(context);

    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning,'
        : (hour < 17 ? 'Good afternoon,' : 'Good evening,');

    // No phase prediction until a period is logged. Otherwise the day count
    // defaults to mid-cycle and this claimed an ovulatory "peak energy" for an
    // account with no data (the "ghost cycle" bug).
    String dynamicSentiment;
    if (!_hasLoggedPeriod) {
      dynamicSentiment =
          'Log your last period to unlock your personalised cycle insights.';
    } else if (_currentCycleDay <= _periodLength) {
      dynamicSentiment =
          'Menstrual phase • estrogen and progesterone are at their lowest, so energy may dip today.';
    } else if (_currentCycleDay <= _periodLength + 7) {
      dynamicSentiment =
          'Follicular phase • rising estrogen sharpens verbal memory and focus — a strong stretch for starting things.';
    } else if (_currentCycleDay <= _periodLength + 11) {
      dynamicSentiment =
          'Ovulatory phase • estrogen and a testosterone bump peak verbal fluency and confidence today.';
    } else {
      dynamicSentiment =
          'Luteal phase • rising progesterone favours detail and a steadier, more inward pace.';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
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
            dynamicSentiment,
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
  // 02 — THE HERO: CYCLE TRACKER & INTEGRATED FORECAST TIMELINE
  // ════════════════════════════════════════════════════════════════
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
          // Top Row: Aligned Action Button
          Align(
            alignment: Alignment.topRight,
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
                      _hasLoggedPeriod ? 'Update period' : '+ Log last period',
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
                      color: _currentPhaseColor,
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
            Text(
              AppLocalizations.of(context).lwmcNoPeriodLoggedYet,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF7A6B72),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _openLogPeriodDialog(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: blushyPrimary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: blushyPrimary.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 7),
                    Text(
                      'Log Your Period',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
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
            onTap: () => _hasLoggedPeriod
                ? _openDocsyWithPrompt(
                    context,
                    'I am on Day $_currentCycleDay ($_currentPhaseName). What is happening in my body in this phase?',
                  )
                : _openLogPeriodDialog(context),
          ),
          const SizedBox(height: 12),

          // Medical Disclaimer
          Text(
            _hasLoggedPeriod
                ? 'Estimated ovulation based on 28-day baseline. Not medically certain.'
                : 'Blushy cycle tracker uses your logged period dates to estimate phases.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF7A6B72),
            ),
          ),

          if (_hasLoggedPeriod) ...[
            const SizedBox(height: 10),
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

            // Integrated 2-Week Forecast Bar inside Hero
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(16),
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
                          const Icon(Icons.timeline_rounded, size: 14, color: Color(0xFF7A6B72)),
                          const SizedBox(width: 6),
                          Text(
                            'UPCOMING HORMONAL SHIFTS',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: const Color(0xFF7A6B72),
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _checkMyDates(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: blushyPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flight_takeoff_rounded, size: 12, color: blushyPrimary),
                              const SizedBox(width: 4),
                              Text(
                                'Check Dates',
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
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _buildForecastChipsList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFECE4DC)),
          const SizedBox(height: 10),

          // Quick Phase Insights Tap Row
          InkWell(
            onTap: () {
              if (_hasLoggedPeriod) {
                _openDocsyWithPrompt(
                  context,
                  'Tell me what happens in the body during the $_currentPhaseName for adult women.',
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
                    _hasLoggedPeriod ? Icons.favorite_border_rounded : Icons.lock_outline_rounded,
                    size: 16,
                    color: _hasLoggedPeriod ? blushyPrimary : const Color(0xFF9E9296),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasLoggedPeriod ? 'Insights for your phase' : 'Log your period to unlock phase insights',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _hasLoggedPeriod ? const Color(0xFF221510) : const Color(0xFF7A6B72),
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
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
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

  // ════════════════════════════════════════════════════════════════
  // 03 — TODAY'S LOG & FUNCTIONAL WORK IMPACT
  // ════════════════════════════════════════════════════════════════
  Widget _buildWorkImpactLog(BuildContext context) {
    const levels = [
      {
        'id': 'normal',
        'label': 'Normal Focus',
        'icon': Icons.bolt_rounded,
        'color': Color(0xFF0D9488),
        'tint': Color(0xFFCCFBF1),
      },
      {
        'id': 'breaks',
        'label': 'Needed Breaks',
        'icon': Icons.coffee_rounded,
        'color': Color(0xFFD97706),
        'tint': Color(0xFFFEF3C7),
      },
      {
        'id': 'fog',
        'label': 'Brain Fog',
        'icon': Icons.cloud_rounded,
        'color': Color(0xFF7209B7),
        'tint': Color(0xFFF3E8FF),
      },
      {
        'id': 'bedrest',
        'label': 'Rest Needed',
        'icon': Icons.bed_rounded,
        'color': Color(0xFFDD0D22),
        'tint': Color(0xFFFFECEB),
      },
    ];

    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3E8FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_outlined, size: 14, color: Color(0xFF7209B7)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY WORK & ENERGY IMPACT',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: const Color(0xFF221510),
                      ),
                    ),
                    Text(
                      'Single tap to log today’s functional capacity',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: const Color(0xFF7A6B72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: levels.map((lvl) {
                final id = lvl['id'] as String;
                final label = lvl['label'] as String;
                final icon = lvl['icon'] as IconData;
                final color = lvl['color'] as Color;
                final tint = lvl['tint'] as Color;
                final selected = _workImpact == id;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() => _workImpact = id);
                      final today = DateTime.now().toIso8601String().split('T').first;
                      UserStateStore.write(
                        'stage3_work_impact_$today',
                        {'impact': id, 'label': label},
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? blushySoftPink : const Color(0xFFFAF7F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? blushyPrimary : cardBorderColor,
                          width: selected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : tint,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 12, color: selected ? blushyPrimary : color),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                              color: selected ? blushyPrimary : const Color(0xFF221510),
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
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF3EEE9)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _openTellDocsyNaturalSheet(context),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: blushyPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'Tell Docsy in your own words',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: blushyPrimary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, size: 14, color: blushyPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 04 — DAILY CYCLE SYNC (FOCUS / NOURISH / MOVE + CONNECT / RESET)
  // ════════════════════════════════════════════════════════════════
  static const List<Map<String, String>> _focusOptions = [
    {'id': 'career', 'label': 'Career & Focus', 'emoji': '💼'},
    {'id': 'fitness', 'label': 'Fitness & Body', 'emoji': '💪'},
    {'id': 'pms', 'label': 'PMS & Relief', 'emoji': '🌡️'},
    {'id': 'fertility', 'label': 'Natural Fertility', 'emoji': '🌱'},
  ];

  String _focusLabel() {
    for (final f in _focusOptions) {
      if (f['id'] == _focusMode) return f['label']!;
    }
    return 'Career & Focus';
  }

  String _workImpactLabel() {
    switch (_workImpact) {
      case 'normal':
        return 'Normal focus';
      case 'breaks':
        return 'Needed breaks';
      case 'fog':
        return 'Brain fog';
      case 'bedrest':
        return 'Rest needed';
      default:
        return 'not logged';
    }
  }

  List<List<String>> _primaryOrderForFocus() {
    switch (_focusMode) {
      case 'fitness':
        return [['move', 'Move'], ['eat', 'Nourish'], ['work', 'Focus']];
      case 'pms':
        return [['eat', 'Nourish'], ['work', 'Focus'], ['move', 'Move']];
      case 'fertility':
        return [['move', 'Move'], ['eat', 'Nourish'], ['work', 'Focus']];
      default:
        return [['work', 'Focus'], ['eat', 'Nourish'], ['move', 'Move']];
    }
  }

  Widget _buildFocusModeSelector() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: _focusOptions.map((f) {
          final id = f['id']!;
          final selected = _focusMode == id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _focusMode = id;
                  _activePillar = _primaryOrderForFocus().first[0];
                });
                UserStateStore.write('stage3_focus_mode', {'focus': id});
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? blushySoftPink : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? blushyPrimary : cardBorderColor,
                    width: selected ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(f['emoji']!, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      f['label']!,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? blushyPrimary : const Color(0xFF4A3E39),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailyCycleSyncHub(BuildContext context) {
    if (!_hasLoggedPeriod) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEyebrow('Daily Cycle Sync'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cardBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAF7F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sync_rounded, size: 16, color: blushyPrimary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cycle Syncing Unlocks With Your Period',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF221510),
                            ),
                          ),
                          Text(
                            'Personalized Focus, Nourish and Move routines',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: const Color(0xFF7A6B72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Log your last period to unlock today's Focus, Nourish and "
                  'Move recommendations, tuned to your hormonal rhythm.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    height: 1.45,
                    color: const Color(0xFF7A6B72),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => _openLogPeriodDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: blushyPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.water_drop_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Log My Period',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final destinations = [
      {
        'id': 'work',
        'title': 'FOCUS',
        'label': 'Focus',
        'subtitle': 'Work pacing & mental stamina',
        'icon': Icons.lightbulb_rounded,
        'color': const Color(0xFFFF4A00),
        'bg': const Color(0xFFFFEBE0),
        'hormoneTag': _isMenstrualPhase
            ? 'Baseline Hormones'
            : (_isFollicularPhase
                ? 'Estrogen Rising'
                : (_isOvulatoryPhase
                    ? 'Estrogen & Testosterone Peak'
                    : 'Progesterone Dominant')),
        'quickCue': _isMenstrualPhase
            ? 'Quiet planning'
            : (_isFollicularPhase
                ? 'Creative momentum'
                : (_isOvulatoryPhase
                    ? 'Peak pitch clarity'
                    : 'Methodical review')),
        'highlights': [
          {
            'icon': Icons.track_changes_rounded,
            'label': 'Priority',
            'val': _isMenstrualPhase
                ? 'Big-picture strategic planning'
                : (_isFollicularPhase
                    ? 'Launching projects & team brainstorming'
                    : (_isOvulatoryPhase
                        ? 'High-stakes pitches & presentations'
                        : 'Error-checking & wrapping deliverables')),
          },
          {
            'icon': Icons.timer_outlined,
            'label': 'Pacing',
            'val': _isMenstrualPhase
                ? 'Low meeting density · protect deep hours'
                : (_isFollicularPhase
                    ? 'High cognitive stamina for collaboration'
                    : (_isOvulatoryPhase
                        ? 'Peak verbal clarity & social ease'
                        : 'Quiet, methodical work blocks')),
          },
          {
            'icon': Icons.psychology_outlined,
            'label': 'Mindset',
            'val': _isMenstrualPhase
                ? 'Reflective & inward vision'
                : (_isFollicularPhase
                    ? 'Curious, creative & fast-moving'
                    : (_isOvulatoryPhase
                        ? 'Magnetic, outward & decisive'
                        : 'Pragmatic & detail-sharp')),
          },
        ],
        'prompt': 'Docsy, help me optimize my work tasks around my Day $_currentCycleDay ($_currentPhaseName) hormones.',
      },
      {
        'id': 'eat',
        'title': 'NOURISH',
        'label': 'Nourish',
        'subtitle': 'Metabolic fuel & cravings',
        'icon': Icons.restaurant_rounded,
        'color': const Color(0xFF0D9488),
        'bg': const Color(0xFFCCFBF1),
        'hormoneTag': _isMenstrualPhase
            ? 'Iron & Blood Recovery'
            : (_isFollicularPhase
                ? 'Follicular Development'
                : (_isOvulatoryPhase
                    ? 'Liver Estrogen Clearance'
                    : '+200 kcal Metabolic Burn')),
        'quickCue': _isMenstrualPhase
            ? 'Iron & greens'
            : (_isFollicularPhase
                ? 'Plant fats & oats'
                : (_isOvulatoryPhase
                    ? 'Light fiber & berries'
                    : 'Protein & sweet potato')),
        'highlights': [
          {
            'icon': Icons.eco_rounded,
            'label': 'Plate',
            'val': _isMenstrualPhase
                ? 'Iron-rich lentils, dark leafy greens & bone broth'
                : (_isFollicularPhase
                    ? 'Sprouted grains, fermented foods & avocado fats'
                    : (_isOvulatoryPhase
                        ? 'Cruciferous greens, berries & light fiber'
                        : 'Sweet potatoes, oats & dark chocolate')),
          },
          {
            'icon': Icons.medication_liquid_rounded,
            'label': 'Key Nutrient',
            'val': _isMenstrualPhase
                ? 'Iron & magnesium for cellular recovery'
                : (_isFollicularPhase
                    ? 'B-vitamins & healthy plant fats'
                    : (_isOvulatoryPhase
                        ? 'Antioxidants & liver support'
                        : 'Magnesium & complex carbohydrates')),
          },
          {
            'icon': Icons.local_fire_department_outlined,
            'label': 'Metabolism',
            'val': !_isLutealPhase
                ? 'Steady basal insulin sensitivity'
                : '+150 to 250 kcal metabolic increase · prioritize protein',
          },
        ],
        'prompt': 'Docsy, what should I eat today on Day $_currentCycleDay ($_currentPhaseName) to balance my hormones?',
      },
      {
        'id': 'move',
        'title': 'MOVE',
        'label': 'Move',
        'subtitle': 'Workout & physical recovery',
        'icon': Icons.directions_run_rounded,
        'color': const Color(0xFF2563EB),
        'bg': const Color(0xFFDBEAFE),
        'hormoneTag': _isMenstrualPhase
            ? 'Pelvic Floor Ease'
            : (_isFollicularPhase
                ? 'High Insulin Sensitivity'
                : (_isOvulatoryPhase
                    ? 'Peak Power Output'
                    : 'Higher Core Temperature')),
        'quickCue': _isMenstrualPhase
            ? 'Yin yoga'
            : (_isFollicularPhase
                ? 'Strength training'
                : (_isOvulatoryPhase
                    ? 'HIIT & personal bests'
                    : 'Pilates & incline walks')),
        'highlights': [
          {
            'icon': Icons.self_improvement_rounded,
            'label': 'Movement',
            'val': _isMenstrualPhase
                ? 'Restorative yin yoga & gentle walks'
                : (_isFollicularPhase
                    ? 'Progressive weights & strength sets'
                    : (_isOvulatoryPhase
                        ? 'High explosive HIIT, sprints & PR lifting'
                        : 'Pilates, steady-state incline walks & sculpt')),
          },
          {
            'icon': Icons.speed_rounded,
            'label': 'Intensity',
            'val': _isMenstrualPhase
                ? 'Low (20–40%) · protect pelvic floor'
                : (_isFollicularPhase
                    ? 'Moderate-High (70–85%) · rapid adaptation'
                    : (_isOvulatoryPhase
                        ? 'Peak Output (90–100%) · personal bests'
                        : 'Moderate (50–65%) · rhythm & breath')),
          },
          {
            'icon': Icons.healing_rounded,
            'label': 'Recovery',
            'val': _isMenstrualPhase
                ? 'Gentle low-back decompression'
                : (_isFollicularPhase
                    ? 'Rapid muscle rebuilding'
                    : (_isOvulatoryPhase
                        ? 'Adequate joint warmup & hydration'
                        : 'Magnesium foam rolling & active rest')),
          },
        ],
        'prompt': 'Docsy, suggest a workout tailored to Day $_currentCycleDay ($_currentPhaseName).',
      },
      {
        'id': 'recharge',
        'title': 'RECHARGE',
        'label': 'Recharge',
        'subtitle': 'Social battery & evening reset',
        'icon': Icons.spa_rounded,
        'color': const Color(0xFF7209B7),
        'bg': const Color(0xFFF3E8FF),
        'hormoneTag': !_isLutealPhase ? 'Social Ease & Energy' : 'Magnesium & REM Ease',
        'quickCue': !_isLutealPhase ? 'Cozy evenings' : 'Epsom soak & tea',
        'highlights': [
          {
            'icon': Icons.favorite_border_rounded,
            'label': 'Social Battery',
            'val': _isMenstrualPhase
                ? 'Cozy low-stimulation with inner circle'
                : (_isFollicularPhase
                    ? 'Curious, open & social networking'
                    : (_isOvulatoryPhase
                        ? 'Magnetic presence, hosting & key dates'
                        : 'Selective 1-on-1s · protect boundaries')),
          },
          {
            'icon': Icons.nightlight_round,
            'label': 'Night Ritual',
            'val': _isMenstrualPhase
                ? 'Warm Epsom foot soak + 5 belly breaths'
                : (_isFollicularPhase
                    ? '10 mins morning sun for circadian anchor'
                    : (_isOvulatoryPhase
                        ? 'Cold face splash + short breathwork'
                        : 'Dim amber lighting after 8 PM + chamomile')),
          },
          {
            'icon': Icons.spa_outlined,
            'label': 'Rest & Recovery',
            'val': !_isLutealPhase
                ? 'Energized, outward-facing presence'
                : 'Deep restoration & early lights-out',
          },
        ],
        'prompt': 'Docsy, give me a 1-minute wind-down ritual for Day $_currentCycleDay.',
      },
    ];

    final byId = <String, Map<String, Object>>{
      for (final d in destinations) d['id'] as String: d,
    };

    // Determine current active pillar
    final primaryOrder = _primaryOrderForFocus();
    final firstId = primaryOrder.isNotEmpty ? primaryOrder.first[0] : 'work';
    final activeId = _activePillar ?? firstId;
    final activeDest = byId[activeId] ?? byId['work']!;

    final activeColor = activeDest['color'] as Color;
    final activeBg = activeDest['bg'] as Color;
    final activeTitle = activeDest['title'] as String;
    final activeSubtitle = activeDest['subtitle'] as String;
    final activeHormoneTag = activeDest['hormoneTag'] as String;
    final activePrompt = activeDest['prompt'] as String;
    final activeHighlights = activeDest['highlights'] as List<Map<String, Object>>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Daily Cycle Sync'),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Syncing for ${_focusLabel()}',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7A6B72),
            ),
          ),
        ),
        _buildFocusModeSelector(),
        const SizedBox(height: 12),

        // 1. Docsy's Hormone Cue Card (Clean, Editorial & Expandable)
        if (_dynamicDocsyNarrative != null) ...[
          _buildDocsyHormoneCueCard(context),
          const SizedBox(height: 12),
        ],

        // 2. Interactive Segmented Pillar Tab Selector
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: destinations.map((d) {
              final id = d['id'] as String;
              final label = d['label'] as String;
              final icon = d['icon'] as IconData;
              final color = d['color'] as Color;
              final bg = d['bg'] as Color;
              final isSelected = id == activeId;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _activePillar = id),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? bg : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : cardBorderColor,
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : const Color(0xFFFAF7F2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 12, color: isSelected ? color : const Color(0xFF7A6B72)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? color : const Color(0xFF4A3E39),
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
        const SizedBox(height: 10),

        // 3. The Active Pillar Card (Structured, Scannable & Icon-Driven)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pillar Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: activeBg, shape: BoxShape.circle),
                    child: Icon(activeDest['icon'] as IconData, size: 16, color: activeColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$activeTitle FOR TODAY',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF221510),
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          activeSubtitle,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF7A6B72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: activeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      activeHormoneTag,
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: activeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.8, color: Color(0xFFF3EEE9)),
              const SizedBox(height: 10),

              // Highlights List (Clean key-value items with icons)
              ...activeHighlights.map((hl) {
                final hlIcon = hl['icon'] as IconData;
                final hlLabel = hl['label'] as String;
                final hlVal = hl['val'] as String;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: activeBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(hlIcon, size: 11, color: activeColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$hlLabel: ',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF221510),
                                ),
                              ),
                              TextSpan(
                                text: hlVal,
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF5A4D53),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 0.8, color: Color(0xFFF3EEE9)),
              const SizedBox(height: 8),

              // Bottom Action Row
              InkWell(
                onTap: () => _openDocsyWithPrompt(context, activePrompt),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 13, color: activeColor),
                      const SizedBox(width: 6),
                      Text(
                        'Build Day $_currentCycleDay ${activeDest['label']} plan with Docsy',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: activeColor,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_rounded, size: 13, color: activeColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 4. Quick-Glance Pillar Chips (See what else is available at a tap)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: destinations.where((d) => d['id'] != activeId).map((d) {
              final id = d['id'] as String;
              final label = d['label'] as String;
              final icon = d['icon'] as IconData;
              final color = d['color'] as Color;
              final tint = d['bg'] as Color;
              final quickCue = d['quickCue'] as String;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _activePillar = id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                          child: Icon(icon, size: 10, color: color),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$label · $quickCue',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4A3E39),
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

  // ════════════════════════════════════════════════════════════════
  // 04B — DOCSY HORMONE CUE CARD (Editorial & Expandable)
  // ════════════════════════════════════════════════════════════════
  Widget _buildDocsyHormoneCueCard(BuildContext context) {
    if (_dynamicDocsyNarrative == null) return const SizedBox.shrink();

    final fullText = _dynamicDocsyNarrative!.trim();
    final periodIndex = fullText.indexOf('.');
    final bool hasMore = periodIndex > 0 && periodIndex < fullText.length - 2;
    final String firstSentence = hasMore ? fullText.substring(0, periodIndex + 1).trim() : fullText;
    final String remainingText = hasMore ? fullText.substring(periodIndex + 1).trim() : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFDDE4), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: blushyPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, size: 14, color: blushyPrimary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DOCSY HORMONE CUE · DAY $_currentCycleDay',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: blushyPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _openDocsyWithPrompt(
                  context,
                  'Explain what my hormones are doing today on Day $_currentCycleDay and give me personalized cycle syncing advice.',
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFDDE4), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 11, color: blushyPrimary),
                      const SizedBox(width: 4),
                      Text(
                        'Ask Docsy',
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
          const SizedBox(height: 8),
          Text(
            firstSentence,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF221510),
              height: 1.4,
            ),
          ),
          if (hasMore) ...[
            if (_isAiNarrativeExpanded) ...[
              const SizedBox(height: 6),
              Text(
                remainingText,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF5A4D53),
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _isAiNarrativeExpanded = !_isAiNarrativeExpanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isAiNarrativeExpanded ? 'Show less' : 'Read why this happens',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: blushyPrimary,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    _isAiNarrativeExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: blushyPrimary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 05 — PATTERN INTELLIGENCE (Real User Data Only)
  // ════════════════════════════════════════════════════════════════
  Widget _buildPatternIntelligenceSection(BuildContext context) {
    if (!_hasLoggedPeriod) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('A Pattern I Noticed'),
        const RealInsightsList(title: 'What your logs show'),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // FORECAST & DATE HELPERS
  // ════════════════════════════════════════════════════════════════
  String _fmtShortDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _phaseNameForCycleDay(int day) {
    if (day <= _periodLength) return 'menstrual phase';
    if (day <= _periodLength + 7) return 'follicular phase';
    if (day <= _periodLength + 11) return 'ovulatory phase';
    return 'luteal phase';
  }

  List<Widget> _buildForecastChipsList() {
    final chips = <Widget>[];
    final fertileStart = _cycleVM.fertileWindowStart;
    final fertileEnd = _cycleVM.fertileWindowEnd;
    final next = _cycleVM.nextPeriodStartDate;

    if (fertileStart != null && fertileEnd != null) {
      chips.add(_buildForecastChip(
        icon: Icons.spa_rounded,
        color: const Color(0xFF0D9488),
        tint: const Color(0xFFCCFBF1),
        label: 'Fertile · ${_fmtShortDate(fertileStart)}–${_fmtShortDate(fertileEnd)}',
      ));
    } else if (_cycleVM.estimatedOvulationDate != null) {
      chips.add(_buildForecastChip(
        icon: Icons.bolt_rounded,
        color: const Color(0xFFD97706),
        tint: const Color(0xFFFEF3C7),
        label: 'Ovulation · ${_fmtShortDate(_cycleVM.estimatedOvulationDate)}',
      ));
    }
    if (next != null) {
      final nextDate = DateTime.tryParse(next);
      if (nextDate != null) {
        final pms = nextDate.subtract(const Duration(days: 5));
        chips.add(_buildForecastChip(
          icon: Icons.cloud_rounded,
          color: const Color(0xFF7209B7),
          tint: const Color(0xFFF3E8FF),
          label: 'PMS · from ${_fmtShortDate(pms.toIso8601String())}',
        ));
      }
      chips.add(_buildForecastChip(
        icon: Icons.water_drop_rounded,
        color: const Color(0xFFDD0D22),
        tint: const Color(0xFFFFECEB),
        label: 'Next period · ${_fmtShortDate(next)}',
      ));
    }
    return chips;
  }

  Widget _buildForecastChip({
    required IconData icon,
    required Color color,
    required Color tint,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 11, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF221510),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkMyDates(BuildContext context) async {
    final start = _cycleVM.lastPeriodStart;
    final now = DateTime.now();
    if (start == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'PICK A DATE TO CHECK',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: blushyPrimary,
            onPrimary: Colors.white,
            surface: Color(0xFFFAF7F2),
            onSurface: Color(0xFF221510),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !context.mounted) return;
    final len = _cycleLength > 0 ? _cycleLength : 28;
    final days = picked.difference(DateTime(start.year, start.month, start.day)).inDays;
    final dayInCycle = (days % len) + 1;
    final phase = _phaseNameForCycleDay(dayInCycle);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${_fmtShortDate(picked.toIso8601String())} · around Day $dayInCycle',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF221510),
          ),
        ),
        content: Text(
          "You'll likely be in your $phase then. Estimated from your logged "
          'rhythm, so it can shift by a few days.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            height: 1.5,
            color: const Color(0xFF5A4E54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Got it',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: blushyPrimary),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getLoggedSymptomSummary() {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final checkin = UserStateStore.read('daily_checkin_$today');
      if (checkin['symptoms'] is List) {
        final list = (checkin['symptoms'] as List).map((e) => e.toString()).toList();
        if (list.isNotEmpty) return list;
      }
      final canonical = BlushyStorage.read('daily_checkin.json');
      if (canonical['symptoms'] is List) {
        final list = (canonical['symptoms'] as List).map((e) => e.toString()).toList();
        if (list.isNotEmpty) return list;
      }
      if (_selectedNoticings.isNotEmpty) {
        return _selectedNoticings.toList();
      }
    } catch (_) {}
    return [];
  }

  // ════════════════════════════════════════════════════════════════
  // 11 — DOCTOR VISIT READINESS & QUICK HELP
  // ════════════════════════════════════════════════════════════════
  Widget _buildDoctorReadinessSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Support & Doctor Readiness'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.medical_services_outlined,
                      size: 15,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WANT TO TALK TO A DOCTOR?',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2563EB),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Blushy can compile a clean, clinical summary of your recent cycle lengths, pain patterns, and logged symptoms for your next appointment.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4A3E45),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  InkWell(
                    onTap: () => _openDoctorSummaryModal(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_outlined, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context).lwmcPrepareMyVisitSummary,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _openSomethingFeelsDifferentSheet(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.help_outline_rounded, size: 14, color: Color(0xFF7A6B72)),
                          const SizedBox(width: 6),
                          Text(
                            'Something Unusual?',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF221510),
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

  // ════════════════════════════════════════════════════════════════
  // MODALS & INTERACTIVE SHEETS
  // ════════════════════════════════════════════════════════════════

  // "Something Feels Different" Sheet
  void _openSomethingFeelsDifferentSheet(BuildContext context) {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(22),
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
                  Text(AppLocalizations.of(context).lwmcSomethingFeelsDifferent,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF221510),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                'Describe what feels unusual. Docsy will compare it against your logged cycle patterns and guide you safely.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFF7A6B72),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. "My period is much heavier than usual" or "I’ve had a severe migraine for 2 days"',
                  hintStyle: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFFB5A9AF)),
                  filled: true,
                  fillColor: const Color(0xFFFAF7F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFEDE4DC)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blushyPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    final query = textController.text.trim();
                    Navigator.pop(ctx);
                    if (query.isNotEmpty) {
                      _openDocsyWithPrompt(
                        context,
                        'Something feels different: "$query". Based on my cycle history (currently Day $_currentCycleDay, $_currentPhaseName), what could this indicate and what should I do?',
                      );
                    }
                  },
                  child: Text(AppLocalizations.of(context).lwmcAskDocsy,
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // "Tell Docsy Naturally" Sheet
  void _openTellDocsyNaturalSheet(BuildContext context) {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(22),
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
                  Text(AppLocalizations.of(context).lwmcTellDocsyWhatHappened,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF221510),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                'No forms needed. Just type how your day felt in plain words.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFF7A6B72),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. "I got really irritable at everyone today and felt exhausted by 3 PM."',
                  hintStyle: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFFB5A9AF)),
                  filled: true,
                  fillColor: const Color(0xFFFAF7F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFEDE4DC)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blushyPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    final text = textController.text.trim();
                    Navigator.pop(ctx);
                    if (text.isNotEmpty) {
                      _openDocsyWithPrompt(
                        context,
                        'Here is what I experienced today: "$text". Turn this into my daily body & mood reflection for Day $_currentCycleDay ($_currentPhaseName).',
                      );
                    }
                  },
                  child: Text(AppLocalizations.of(context).lwmcSubmitToDocsy,
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Doctor Visit Summary Dialog
  void _openDoctorSummaryModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final loggedSymptoms = _getLoggedSymptomSummary();
        final symptomsText = loggedSymptoms.isEmpty
            ? 'none logged today'
            : loggedSymptoms.join(', ');

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppLocalizations.of(context).lwmcClinicalVisitSummary,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF221510),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hasLoggedPeriod ? 'Cycle summary (from your logs):' : 'Cycle summary:',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF221510)),
              ),
              const SizedBox(height: 8),
              Text(
                _hasLoggedPeriod
                    ? '• Cycle length: $_cycleLength days\n'
                        '• Flow duration: $_periodLength days\n'
                        '• Current cycle day: Day $_currentCycleDay ($_currentPhaseName)\n'
                        '• Symptoms logged today: $symptomsText\n'
                        '• Functional impact today: ${_workImpactLabel()}'
                    : 'No periods have been logged yet, so there is nothing to summarise. '
                        'Log a period start date and this will fill in from your own history.',
                style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF5E5057), height: 1.4),
              ),
              if (_hasLoggedPeriod) ...[
                const SizedBox(height: 6),
                Text(
                  'Self-reported. Cycle day and phase are estimates calculated from your logged dates, not clinical measurements.',
                  style: GoogleFonts.manrope(fontSize: 10, color: const Color(0xFF7A6B72), height: 1.35),
                ),
              ],
            const SizedBox(height: 14),
            Text(
              'Questions you might ask:',
              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF221510)),
            ),
            const SizedBox(height: 6),
            // Phrased as prompts rather than as her own reported symptoms.
            // These were "Are my luteal phase fatigue patterns standard?" and
            // "What relieves my cyclic bloating?" -- naming complaints she may
            // never have had.
            Text(
              '1. Is the pattern I am seeing in my cycle typical?\n'
              '2. Which of the symptoms I track are worth investigating?',
              style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF5E5057), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).lwmcClose, style: GoogleFonts.manrope(color: const Color(0xFF7A6B72), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: blushyPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _openDocsyWithPrompt(
                context,
                'Docsy, generate a complete doctor visit cheat-sheet based on my recent cycle history and logged symptoms.',
              );
            },
            child: Text(AppLocalizations.of(context).lwmcExpandWithDocsy, style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      );
    },
  );
}

  // ════════════════════════════════════════════════════════════════
  // 12 — CYCLE HEALTH GUIDE (Interactive & Docsy-Powered)
  // ════════════════════════════════════════════════════════════════
  Widget _buildCycleHealthGuide(BuildContext context) {
    final guides = [
      {
        'tag': 'HORMONES & MOOD',
        'title': 'Why do focus & confidence surge before ovulation?',
        'readTime': '3 min read',
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFFF97316),
        'bg': const Color(0xFFFFF7ED),
        'prompt': 'Docsy, explain the biology of why estrogen and testosterone peaks enhance verbal fluency and confidence around ovulation.',
      },
      {
        'tag': 'METABOLISM & CRAVINGS',
        'title': 'Why appetite shifts +200 kcal in your luteal phase',
        'readTime': '4 min read',
        'icon': Icons.restaurant_rounded,
        'color': const Color(0xFF0D9488),
        'bg': const Color(0xFFCCFBF1),
        'prompt': 'Docsy, explain why resting metabolic rate increases in the luteal phase and why we crave magnesium and carbs before periods.',
      },
      {
        'tag': 'RECOVERY & SLEEP',
        'title': 'How progesterone reshapes REM sleep & body temp',
        'readTime': '3 min read',
        'icon': Icons.nightlight_round,
        'color': const Color(0xFF7209B7),
        'bg': const Color(0xFFF3E8FF),
        'prompt': 'Docsy, why does progesterone increase basal body temperature and how should I adjust my sleep routine in the luteal phase?',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Cycle Health Guide'),
        ...guides.map((g) {
          final tag = g['tag'] as String;
          final title = g['title'] as String;
          final readTime = g['readTime'] as String;
          final icon = g['icon'] as IconData;
          final color = g['color'] as Color;
          final bg = g['bg'] as Color;
          final prompt = g['prompt'] as String;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cardBorderColor),
            ),
            child: InkWell(
              onTap: () => _openDocsyWithPrompt(context, prompt),
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              tag,
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: color,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '· $readTime',
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF9E9296),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF221510),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEFE8E0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 10, color: blushyPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'Ask',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
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
          );
        }),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // MASTER BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return wrapStageDashboardLayout(
      context: context,
      scaffoldKey: _scaffoldKey,
      isNested: widget.isNested,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;

          if (width < 768) {
            // MOBILE
            return ListView(
              controller: _effectiveScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                _buildEditorialGreeting(context),
                const SizedBox(height: 14),
                _buildCycleTrackerCard(context),
                const SizedBox(height: 22),
                _buildEyebrow("Today's Log & Impact"),
                const LogSymptomsSection(
                  stageKey: 'livingwithmycycle',
                  showHeading: false,
                ),
                const SizedBox(height: 12),
                _buildWorkImpactLog(context),
                const SizedBox(height: 22),
                _buildDailyCycleSyncHub(context),
                const SizedBox(height: 22),
                _buildPatternIntelligenceSection(context),
                const SizedBox(height: 22),
                _buildCycleHealthGuide(context),
                const SizedBox(height: 22),
                _buildDoctorReadinessSection(context),
                const SizedBox(height: 36),
              ],
            );
          } else {
            // TABLET / DESKTOP
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  controller: _effectiveScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  children: [
                    _buildEditorialGreeting(context),
                    const SizedBox(height: 16),
                    _buildCycleTrackerCard(context),
                    const SizedBox(height: 24),
                    _buildEyebrow("Today's Log & Impact"),
                    const LogSymptomsSection(
                      stageKey: 'livingwithmycycle',
                      showHeading: false,
                    ),
                    const SizedBox(height: 14),
                    _buildWorkImpactLog(context),
                    const SizedBox(height: 24),
                    _buildDailyCycleSyncHub(context),
                    const SizedBox(height: 24),
                    _buildPatternIntelligenceSection(context),
                    const SizedBox(height: 24),
                    _buildCycleHealthGuide(context),
                    const SizedBox(height: 24),
                    _buildDoctorReadinessSection(context),
                    const SizedBox(height: 44),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
