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
import '../../home_screen.dart';
import '../../widgets/cycle_tracker_image.dart';
import '../../widgets/real_insights_list.dart';
import '../../../../shared/docsy_avatar.dart';
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

class _LivingWithMyCycleDashboardState extends State<LivingWithMyCycleDashboard> {
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
  String? _dynamicDocsyNote;
  String? _dynamicDocsyHeadline;
  bool _isLoadingAi = false;

  // Interactive "What Are You Noticing?" & Body State
  final Set<String> _selectedNoticings = <String>{};

  // Life Mode (Dynamic Personalization)
  String? _activeLifeMode;

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

  @override
  void initState() {
    super.initState();
    _cycleVM.addListener(_onCycleChanged);
    _loadStage3Data();
    _loadPeriodData();
    _fetchDynamicAiInsights();

    _periodEventSub = HomeEventBus().onEvent.listen((event) {
      if (event is PeriodLoggedEvent && mounted) {
        final now = DateTime.now();
        final diff = now.difference(event.date).inDays;
        setState(() {
          _lastPeriodStartDate = event.date;
          _hasLoggedPeriod = true;
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

  void _loadStage3Data() {
    try {
      // 1. Noticings
      final savedNoticings = UserStateStore.read('stage3_noticings');
      if (savedNoticings is Map && savedNoticings['selected'] is List) {
        _selectedNoticings.clear();
        _selectedNoticings.addAll((savedNoticings['selected'] as List).map((e) => e.toString()));
      }

      // 2. Life Mode
      final savedMode = UserStateStore.read('stage3_life_mode');
      if (savedMode is Map && savedMode['mode'] != null) {
        _activeLifeMode = savedMode['mode'].toString();
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
    setState(() => _isLoadingAi = true);

    try {
      final insights = await ApiSiaService().getHealthInsights(
        stage: 'living_with_my_cycle',
        cycleDay: _hasLoggedPeriod ? _currentCycleDay : null,
        phase: _hasLoggedPeriod ? _currentPhaseName : null,
      );
      if (mounted && insights.isNotEmpty) {
        final thought = insights['thought'] ?? insights['narrative'] ?? insights['summary'] ?? (insights['insights'] is List && (insights['insights'] as List).isNotEmpty ? (insights['insights'] as List).first.toString() : null);
        final headline = insights['headline'];
        final note = insights['note'] ?? insights['oneThingToKeepInMind'];
        if (thought is String && thought.trim().isNotEmpty) {
          setState(() {
            _dynamicDocsyNarrative = thought.trim();
          });
        }
        if (headline is String && headline.trim().isNotEmpty) {
          setState(() {
            _dynamicDocsyHeadline = headline.trim();
          });
        }
        if (note is String && note.trim().isNotEmpty) {
          setState(() {
            _dynamicDocsyNote = note.trim();
          });
        }
      }
    } catch (_) {
      // Graceful fallback
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
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
      final newDay = ((diff % _cycleLength) + 1).clamp(1, _cycleLength);

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
        final profile = Map<String, dynamic>.from(BlushyStorage.read('user_profile.json') ?? {});
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

  void _toggleNoticing(String signal) {
    setState(() {
      if (_selectedNoticings.contains(signal)) {
        _selectedNoticings.remove(signal);
      } else {
        _selectedNoticings.add(signal);
      }
    });
    try {
      UserStateStore.write('stage3_noticings', {
        'date': DateTime.now().toIso8601String().split('T').first,
        'selected': _selectedNoticings.toList(),
      });
    } catch (_) {}
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

    String dynamicSentiment;
    if (_currentCycleDay <= _periodLength) {
      dynamicSentiment = 'Your body is asking for a little more ease and nourishment today.';
    } else if (_currentCycleDay <= _periodLength + 7) {
      dynamicSentiment = 'Your estrogen is rising. A fresh, clear stretch for starting things.';
    } else if (_currentCycleDay <= _periodLength + 11) {
      dynamicSentiment = 'You’re at peak energy and magnetic social clarity today.';
    } else {
      dynamicSentiment = 'Your body is naturally turning inward. Honor your steady pace.';
    }

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
  // 02 — THE HERO: "TODAY WITH DOCSY" ⭐ (Human-First AI Intelligence)
  // ════════════════════════════════════════════════════════════════
  Widget _buildTodayWithDocsyHero(BuildContext context) {
    String phaseHeadline;
    String phaseNarrative;
    String oneThingToKeepInMind;

    if (!_hasLoggedPeriod) {
      phaseHeadline = 'Living with your cycle.';
      phaseNarrative = 'Docsy is ready to tune into your rhythm. Log your latest period date to unlock tailored daily focus, nutrition, energy forecasts, and movement advice.';
      oneThingToKeepInMind = 'Cycle tracking helps Blushy understand your baseline energy and mood patterns.';
    } else if (_currentCycleDay <= _periodLength) {
      phaseHeadline = 'You’re in your menstrual phase.';
      phaseNarrative = 'You’re in your menstrual phase. Your body is doing real biological cleansing work. You may notice lower stamina or a desire for quiet focus.';
      oneThingToKeepInMind = 'Rest is productive. Warm fluids and slower breathing soothe uterine contractions directly.';
    } else if (_currentCycleDay <= _periodLength + 7) {
      phaseHeadline = 'You’re in your follicular phase.';
      phaseNarrative = 'You’re in your follicular phase. Estrogen is steadily climbing, opening up verbal fluency, creativity, and fresh optimism for new projects.';
      oneThingToKeepInMind = 'Use this morning energy to brainstorm or schedule key discussions.';
    } else if (_currentCycleDay <= _periodLength + 11) {
      phaseHeadline = 'You’re in your ovulatory phase.';
      phaseNarrative = 'You’re in your ovulatory phase. You may notice more energy, confidence, and social ease today. If you have a lot on your plate, this is a great day to tackle things that need your full attention.';
      oneThingToKeepInMind = 'Don’t confuse feeling good with needing to say yes to everything.';
    } else {
      phaseHeadline = 'You’re in your luteal phase.';
      phaseNarrative = 'You’re in your luteal phase. Progesterone is rising, sharpening your eye for detail while gently dialing back extraverted energy.';
      oneThingToKeepInMind = 'Protect your evening wind-down time and prioritize protein + complex carbs to steady your blood sugar.';
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
                  Text(AppLocalizations.of(context).lwmcTodayWithDocsy,
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
                'Docsy, I’m on Day $_currentCycleDay ($_currentPhaseName). Can you help me navigate my energy, nutrition, and work today?',
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: blushyPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).lwmcAskDocsy,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3 Quick Contextual AI Prompts Underneath
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildQuickDocsyChip(
                  label: 'Why am I feeling this way?',
                  onTap: () => _openDocsyWithPrompt(
                    context,
                    'Why am I feeling this way on Day $_currentCycleDay ($_currentPhaseName)? Connect this with my hormones and sleep.',
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickDocsyChip(
                  label: 'Plan my day',
                  onTap: () => _openDocsyWithPrompt(
                    context,
                    'Docsy, help me plan my work and workout for today around my Day $_currentCycleDay ($_currentPhaseName) energy.',
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickDocsyChip(
                  label: 'What should I eat today?',
                  onTap: () => _openDocsyWithPrompt(
                    context,
                    'What are the best foods and meals to nourish my body during the $_currentPhaseName?',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDocsyChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEDE4DC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 11, color: blushyPrimary),
            const SizedBox(width: 5),
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
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 03 — YOUR CYCLE (Bézier Track Context)
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
          // Top Row: Log Period Action Button aligned right
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

          // Day Count & Phase Title (Large, catchy Day in Cormorant & clean modern digit)
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
            Text(AppLocalizations.of(context).lwmcNoPeriodLoggedYet,
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
                'Log your period to track your cycle & fertile phases',
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
                ? _openDocsyWithPrompt(context, 'I am on Day $_currentCycleDay ($_currentPhaseName). What is happening in my body in this phase?')
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
          const SizedBox(height: 10),

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
          ],
          const SizedBox(height: 12),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFECE4DC)),
          const SizedBox(height: 10),

          // Insights Row
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
  // 04 — "A LITTLE NOTE FROM DOCSY" (Personal, Quiet Companion)
  // ════════════════════════════════════════════════════════════════
  Widget _buildDocsyNoteSection(BuildContext context) {
    String note = '“Your energy may feel a little more outward-facing around this part of your cycle. So if you’ve been putting off that conversation, workout, or social plan—today might feel easier than it did a few days ago.”';
    if (_dynamicDocsyNote != null && _dynamicDocsyNote!.isNotEmpty) {
      note = '“$_dynamicDocsyNote”';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('A Little Note From Docsy'),
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
              Text(
                note,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF221510),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  _openDocsyWithPrompt(
                    context,
                    'Why does energy shift during the $_currentPhaseName and how can I work with it?',
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Why does this happen?',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: blushyPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 13, color: blushyPrimary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 05 — "MAKE TODAY WORK FOR YOU" (5 Large Lifestyle Destinations)
  // ════════════════════════════════════════════════════════════════
  Widget _buildMakeTodayWorkForYou(BuildContext context) {
    final destinations = [
      {
        'id': 'work',
        'title': 'WORK',
        'subtitle': 'Focus, meetings & energy',
        'icon': Icons.work_outline_rounded,
        'color': const Color(0xFFFF7D00),
        'bg': const Color(0xFFFFF7ED),
        'suggestion': _currentCycleDay <= 5
            ? 'Big-picture planning & contract review. Keep meetings light while estrogen is low.'
            : (_currentCycleDay <= 12
                ? 'High creative stamina. Great for launching new tasks and collaborative brainstorming.'
                : (_currentCycleDay <= 16
                    ? 'Put your hardest thinking task before lunch. High verbal confidence for presentations.'
                    : 'Deep methodical focus. Great for spot-checking errors and wrapping deliverables.')),
        'prompt': 'Docsy, help me organize my workday around my Day $_currentCycleDay ($_currentPhaseName) energy levels.',
      },
      {
        'id': 'move',
        'title': 'MOVE',
        'subtitle': 'Workout & recovery',
        'icon': Icons.directions_run_rounded,
        'color': const Color(0xFFFF006D),
        'bg': const Color(0xFFFFF0F5),
        'suggestion': _currentCycleDay <= 5
            ? 'Restorative yin yoga, gentle walks, and low-back stretches.'
            : (_currentCycleDay <= 12
                ? 'Building strength: progressive weight training and tempo cardio.'
                : (_currentCycleDay <= 16
                    ? 'Peak explosive power: HIIT, heavy lifts, or high-energy workouts.'
                    : 'Steady Pilates, incline walks, and moderate sculpting.')),
        'prompt': 'Docsy, give me a quick 20-min workout routine suitable for Day $_currentCycleDay ($_currentPhaseName).',
      },
      {
        'id': 'eat',
        'title': 'EAT',
        'subtitle': 'Food, cravings & nourishment',
        'icon': Icons.restaurant_rounded,
        'color': const Color(0xFF01BEFE),
        'bg': const Color(0xFFF0F9FF),
        'suggestion': _currentCycleDay <= 5
            ? 'Iron-rich foods, bone broth, spinach, and dark chocolate to replenish red blood cells.'
            : (_currentCycleDay <= 12
                ? 'Fermented foods, sprouted grains, and healthy avocado fats for follicle development.'
                : (_currentCycleDay <= 16
                    ? 'Antioxidant greens, fresh berries, and light hydrating salads.'
                    : 'Metabolic fuel (+200 kcal need): roasted sweet potatoes, quinoa, and warm soups.')),
        'prompt': 'Docsy, what are the best meals and nutrients for me to eat today during $_currentPhaseName?',
      },
      {
        'id': 'connect',
        'title': 'CONNECT',
        'subtitle': 'Social, relationships & mood',
        'icon': Icons.favorite_border_rounded,
        'color': const Color(0xFFFF006D),
        'bg': const Color(0xFFFFF0F5),
        'suggestion': _currentCycleDay <= 5
            ? 'Cozy low-stimulation evenings and quiet conversations with trusted people.'
            : (_currentCycleDay <= 12
                ? 'High social curiosity. Perfect for group dinners and catching up with friends.'
                : (_currentCycleDay <= 16
                    ? 'Peak charisma and magnetic presence for hosting or date nights.'
                    : 'Meaningful 1-on-1s. Protect your boundaries from people-pleasing guilt-free.')),
        'prompt': 'Docsy, how can I communicate my energy and social needs to my partner and friends on Day $_currentCycleDay?',
      },
      {
        'id': 'reset',
        'title': 'RESET',
        'subtitle': 'Rest & micro-rituals',
        'icon': Icons.spa_outlined,
        'color': const Color(0xFF7C3AED),
        'bg': const Color(0xFFF5F3FF),
        'suggestion': _currentCycleDay <= 5
            ? 'Warm foot soak + 5 deep belly breaths in bed to relax the pelvic floor.'
            : (_currentCycleDay <= 12
                ? '10 minutes of direct morning sunlight to anchor your cortisol circadian rhythm.'
                : (_currentCycleDay <= 16
                    ? 'Invigorating cold face splash + morning intention setting.'
                    : 'Evening magnesium tea with dim amber lighting to prepare for deep REM sleep.')),
        'prompt': 'Docsy, give me 2 simple 1-minute rituals I can do today for Day $_currentCycleDay.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Make Today Work For You'),
        Column(
          children: destinations.map((dest) {
            final title = dest['title'] as String;
            final subtitle = dest['subtitle'] as String;
            final icon = dest['icon'] as IconData;
            final color = dest['color'] as Color;
            final bg = dest['bg'] as Color;
            final suggestion = dest['suggestion'] as String;
            final prompt = dest['prompt'] as String;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorderColor),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  title: Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF221510),
                      letterSpacing: 0.5,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF7A6B72),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.auto_awesome, size: 12, color: color),
                                    const SizedBox(width: 5),
                                    Text(AppLocalizations.of(context).lwmcDocsySSuggestion,
                                      style: GoogleFonts.manrope(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  suggestion,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF221510),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => _openDocsyWithPrompt(context, prompt),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Build my $title plan with Docsy',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 12, color: color),
                              ],
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
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 06 — "WHAT ARE YOU NOTICING?" (Interactive Signal Logger)
  // ════════════════════════════════════════════════════════════════
  Widget _buildWhatAreYouNoticingSection(BuildContext context) {
    final signals = [
      {'emoji': '😌', 'label': 'Calm'},
      {'emoji': '⚡', 'label': 'High energy'},
      {'emoji': '🥱', 'label': 'Low energy'},
      {'emoji': '😵', 'label': 'Tired'},
      {'emoji': '😤', 'label': 'Irritable'},
      {'emoji': '🤕', 'label': 'Cramps'},
      {'emoji': '🫧', 'label': 'Bloated'},
      {'emoji': '🍫', 'label': 'Cravings'},
      {'emoji': '🌸', 'label': 'Tender breasts'},
      {'emoji': '💧', 'label': 'Discharge'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('What Are You Noticing?'),
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
              Text(
                'Tap what resonates with how you feel right now:',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF7A6B72),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...signals.map((s) {
                    final label = s['label']!;
                    final emoji = s['emoji']!;
                    final isSelected = _selectedNoticings.contains(label);

                    return InkWell(
                      onTap: () => _toggleNoticing(label),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? blushySoftPink : const Color(0xFFFAF7F2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? blushyPrimary : const Color(0xFFEDE4DC),
                            width: isSelected ? 1.2 : 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? blushyPrimary : const Color(0xFF221510),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  InkWell(
                    onTap: () => _openTellDocsyNaturalSheet(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: blushyPrimary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 14, color: blushyPrimary),
                          const SizedBox(width: 4),
                          Text(
                            'Something else?',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
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
              if (_selectedNoticings.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFDFC2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You’ve logged ${_selectedNoticings.join(", ")}. Want to see if this is connected to your $_currentPhaseName?',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF7A3E10),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _openDocsyWithPrompt(
                            context,
                            'I noticed ${_selectedNoticings.join(", ")} today on Day $_currentCycleDay ($_currentPhaseName). Can you help me understand how this connects to my hormones?',
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(AppLocalizations.of(context).lwmcAskDocsy2,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: blushyPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 07 — "FOR TODAY" (Dynamic 3-Item Actionable Feed)
  // ════════════════════════════════════════════════════════════════
  Widget _buildForTodaySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('For Today'),
        Row(
          children: [
            Expanded(
              child: _buildForTodayTile(
                icon: '🧠',
                tag: 'FOCUS',
                action: 'Put demanding tasks before lunch',
                onTap: () => _openDocsyWithPrompt(
                  context,
                  'How should I structure my deep focus tasks today for Day $_currentCycleDay?',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildForTodayTile(
                icon: '🥗',
                tag: 'NOURISH',
                action: 'Add protein before second coffee',
                onTap: () => _openDocsyWithPrompt(
                  context,
                  'What protein and mineral snacks will stabilize my energy today during $_currentPhaseName?',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildForTodayTile(
                icon: '🧘',
                tag: 'MOVE',
                action: 'A strength session feels great today',
                onTap: () => _openDocsyWithPrompt(
                  context,
                  'Give me workout inspiration for Day $_currentCycleDay ($_currentPhaseName).',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForTodayTile({
    required String icon,
    required String tag,
    required String action,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                Text(
                  tag,
                  style: GoogleFonts.manrope(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: blushyPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Text(
              action,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF221510),
                height: 1.3,
              ),
            ),
            Row(
              children: [
                Text(AppLocalizations.of(context).lwmcTry,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A6B72),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 08 — "LIFE MODE" (Active Contextual Adaptation)
  // ════════════════════════════════════════════════════════════════
  Widget _buildLifeModeSection(BuildContext context) {
    final modes = [
      {'id': 'travel', 'label': '✈️ Travelling'},
      {'id': 'exams', 'label': '📚 Exams'},
      {'id': 'big_week', 'label': '💼 Big week at work'},
      {'id': 'event', 'label': '🎉 Wedding / Event'},
      {'id': 'sports', 'label': '🏃‍♀️ Sports'},
      {'id': 'surviving', 'label': '🛏️ Just surviving 😭'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Life Mode'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: modes.map((m) {
              final id = m['id']!;
              final label = m['label']!;
              final isSelected = _activeLifeMode == id;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _activeLifeMode = isSelected ? null : id;
                    });
                    try {
                      UserStateStore.write('stage3_life_mode', {'mode': _activeLifeMode});
                    } catch (_) {}
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF221510) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF221510) : cardBorderColor,
                      ),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF221510),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_activeLifeMode != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEDE4DC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: blushyPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Active Mode: ${_activeLifeMode!.toUpperCase()}. Docsy is tailoring today’s focus and recovery for you.',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF221510),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    _openDocsyWithPrompt(
                      context,
                      'I am currently in ${_activeLifeMode!} mode and on Day $_currentCycleDay of my cycle. What should I prioritize right now?',
                    );
                  },
                  child: Text(AppLocalizations.of(context).lwmcViewPlan,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: blushyPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 09 — "A PATTERN I NOTICED" (Blushy Intelligence)
  // ════════════════════════════════════════════════════════════════
  /// Patterns the server derived from this user's own logs.
  ///
  /// This card used to be a fixed literal under the heading "CYCLICAL PATTERN
  /// DETECTED": "You tend to sleep ~40 minutes less during the 3 days before
  /// your period starts. You've logged this pattern across 3 of your recent
  /// cycles." Every figure in it was invented, and it was shown to everyone,
  /// including accounts that had logged nothing at all.
  ///
  /// RealInsightsList exists for exactly this. It asks the pattern engine,
  /// which will not report anything until it has six paired observations and a
  /// correlation above its floor, and renders the insufficient-data case as
  /// such instead of filling it in (spec sections 7 and 8).
  Widget _buildPatternIntelligenceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('A Pattern I Noticed'),
        const RealInsightsList(title: 'What your logs show'),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 10 — "UNDERSTAND YOUR BODY" (Dynamic Educational Content)
  // ════════════════════════════════════════════════════════════════
  Widget _buildUnderstandYourBodySection(BuildContext context) {
    final articles = [
      {
        'title': 'Why do I feel more social & articulate around ovulation?',
        'tag': 'HORMONES & MOOD',
        'readTime': '3 min read',
        'summary': 'Simultaneous estrogen and testosterone peaks enhance verbal fluency and social connectivity.',
        'prompt': 'Tell me about the science of estrogen and testosterone during ovulation.',
      },
      {
        'title': 'Why am I suddenly craving dark chocolate in the luteal phase?',
        'tag': 'NUTRITION & METABOLISM',
        'readTime': '4 min read',
        'summary': 'Your resting metabolism jumps 100-300 kcal/day while your body requests magnesium for uterine ease.',
        'prompt': 'Why do cravings happen before periods and what does dark chocolate provide?',
      },
      {
        'title': 'What cervical fluid tells you about your fertile window',
        'tag': 'BODY SIGNALS',
        'readTime': '5 min read',
        'summary': 'Decoding changes from creamy to stretchy egg-white fluid across your cycle.',
        'prompt': 'How do I identify my fertile window through cervical fluid?',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Understand Your Body'),
        Column(
          children: articles.map((art) {
            final title = art['title']!;
            final tag = art['tag']!;
            final readTime = art['readTime']!;
            final summary = art['summary']!;
            final prompt = art['prompt']!;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tag,
                        style: GoogleFonts.manrope(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: blushyPrimary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        readTime,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF7A6B72),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF221510),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF7A6B72),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => showArticleDetailDialog(context, title, summary),
                        child: Text(AppLocalizations.of(context).lwmcRead,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF221510),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => _openDocsyWithPrompt(context, prompt),
                        child: Text(AppLocalizations.of(context).lwmcAskDocsy2,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: blushyPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
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
                      Text(AppLocalizations.of(context).lwmcPrepareMyVisitSummary,
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
      builder: (ctx) => AlertDialog(
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
            // Only figures that came from logged periods are printed. This
            // block used to print the defaults -- a 28-day cycle, a 5-day flow
            // and Day 14 -- to someone who had logged nothing, under the
            // heading "Patient Cycle Summary (Last 90 Days)". A clinician
            // reading that would be reading numbers nobody measured.
            Text(
              _hasLoggedPeriod
                  ? '• Cycle length: $_cycleLength days\n'
                      '• Flow duration: $_periodLength days\n'
                      '• Current cycle day: Day $_currentCycleDay ($_currentPhaseName)\n'
                      '• Symptoms logged today: ${_selectedNoticings.isEmpty ? "none" : _selectedNoticings.join(", ")}'
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
      ),
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
                _buildTodayWithDocsyHero(context),
                const SizedBox(height: 22),
                _buildCycleTrackerCard(context),
                const SizedBox(height: 22),
                const LogSymptomsSection(stageKey: 'livingwithmycycle'),
                const SizedBox(height: 22),
                _buildDocsyNoteSection(context),
                const SizedBox(height: 22),
                _buildMakeTodayWorkForYou(context),
                const SizedBox(height: 22),
                _buildWhatAreYouNoticingSection(context),
                const SizedBox(height: 22),
                _buildForTodaySection(context),
                const SizedBox(height: 22),
                _buildLifeModeSection(context),
                const SizedBox(height: 22),
                _buildPatternIntelligenceSection(context),
                const SizedBox(height: 22),
                _buildUnderstandYourBodySection(context),
                const SizedBox(height: 22),
                _buildDoctorReadinessSection(context),
                const SizedBox(height: 32),
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
                    _buildTodayWithDocsyHero(context),
                    const SizedBox(height: 24),
                    _buildCycleTrackerCard(context),
                    const SizedBox(height: 22),
                    const LogSymptomsSection(stageKey: 'livingwithmycycle'),
                    const SizedBox(height: 24),
                    _buildDocsyNoteSection(context),
                    const SizedBox(height: 24),
                    _buildMakeTodayWorkForYou(context),
                    const SizedBox(height: 24),
                    _buildWhatAreYouNoticingSection(context),
                    const SizedBox(height: 24),
                    _buildForTodaySection(context),
                    const SizedBox(height: 24),
                    _buildLifeModeSection(context),
                    const SizedBox(height: 24),
                    _buildPatternIntelligenceSection(context),
                    const SizedBox(height: 24),
                    _buildUnderstandYourBodySection(context),
                    const SizedBox(height: 24),
                    _buildDoctorReadinessSection(context),
                    const SizedBox(height: 40),
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
