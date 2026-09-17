import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../theme/colors.dart';
import '../../../../core/state.dart';
import '../../../../core/storage.dart';
import '../../../../models/blushy_models.dart';
import '../../../../services/api_period_service.dart';
import '../../view_models/cycle_view_model.dart';
import '../../../../services/api_sia_service.dart';
import '../../services/home_event_bus.dart';
import '../../../sia/open_docsy.dart';
import '../../../../core/cycle_calculator.dart';
import '../../home_screen.dart';
import '../../widgets/cycle_card.dart';
import '../../widgets/cycle_tracker_image.dart';
import '../../widgets/home_hero.dart';
import '../../../../shared/user_display_name.dart';
import '../../../../services/api_contract_client.dart';
import '../../../../shared/stage_empty_notice.dart';
import '../../widgets/log_symptoms_section.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/user_state_store.dart';

class FirstPeriodStartedDashboard extends StatefulWidget {
  final bool isNested;
  final ScrollController? scrollController;

  const FirstPeriodStartedDashboard({
    super.key,
    this.isNested = false,
    this.scrollController,
  });

  @override
  State<FirstPeriodStartedDashboard> createState() => _FirstPeriodStartedDashboardState();
}

class _FirstPeriodStartedDashboardState extends State<FirstPeriodStartedDashboard> {

  /// How the last cycle-data load went, so a failed request is not drawn as an
  /// account with nothing in it.
  ApiState _cycleState = ApiState.loading;

  /// This screen is the View; the cycle read lives in the tested
  /// CycleViewModel and is mirrored back by _onCycleChanged.
  final CycleViewModel _cycleVM =
      CycleViewModel(defaultCycleLength: 28, defaultCycleDay: 1);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ScrollController _internalScrollController = ScrollController();
  ScrollController get _effectiveScrollController => widget.scrollController ?? _internalScrollController;

  // Unified Blushy Crimson Primary & Theme Constants
  static const Color blushyPrimary = Color(0xFFDD0D22);
  static const Color blushySoftPink = Color(0xFFFFECEB);
  static const Color cardBorderColor = Color(0xFFEFE8E0);

  // Dynamic real-time state
  String? _dynamicDocsyNote;
  bool _isLoadingAiInsights = false;
  int _promptIndex = 0;

  // Real-time Cycle Tracking State
  DateTime? _lastPeriodStartDate;
  int _currentCycleDay = 1;
  int _cycleLength = 28;
  int _periodLength = 5;
  bool _hasLoggedPeriod = false;
  StreamSubscription? _periodEventSub;

  String get _currentPhaseName {
    if (_currentCycleDay <= _periodLength) return 'Menstrual Phase';
    if (_currentCycleDay <= _periodLength + 9) return 'Follicular Phase';
    if (_currentCycleDay <= _periodLength + 11) return 'Ovulation Phase';
    return 'Luteal Phase';
  }

  // User logging state (Unselected for 1st time users)
  String? _loggedFlow;
  String? _selectedCramp;
  String? _selectedMood;

  // Body changes multi-select (Starts empty for 1st time users)
  final Set<String> _selectedBodyChanges = <String>{};

  // Smart Period Bag checklist (Starts false for 1st time users)
  final Map<String, bool> _schoolBagItems = {
    '2-3 daytime sanitary pads': false,
    '1 spare underwear in clean pouch': false,
    'Pocket tissue / gentle wet wipes': false,
    'Disposal bag for used items': false,
    'Water bottle & comforting mints': false,
  };

  // ════════════════════════════════════════════════════════════════
  // DYNAMIC DAILY CONTENT ENGINE (Rotates by day of year)
  // ════════════════════════════════════════════════════════════════
  int get _dayOfYear {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays;
  }

  // Daily rotating Docsy Companion Notes for First Year
  final List<Map<String, String>> _dailyDocsyNotes = [
    {
      'note': '“Your first few periods can be pretty unpredictable. That’s completely normal while your body finds its own rhythm.”',
      'action': 'Ask me anything about periods',
      'prompt': 'Why are periods irregular during the first year?',
    },
    {
      'note': '“Feeling a little more tired during your flow? Your body is doing real cellular work. Extra rest is your superpower today.”',
      'action': 'Read quick cramp & rest tips',
      'prompt': 'Why do I feel so tired on my period and how do I soothe cramps?',
    },
    {
      'note': '“Remember: spotting, light pink flow, or darker brown flow are all natural variations as your uterus cleanses.”',
      'action': 'Learn about flow colors',
      'prompt': 'What do different period flow colors mean?',
    },
    {
      'note': '“Keeping your school pouch stocked means you never have to feel surprised. You are prepared for anything.”',
      'action': 'Review your school kit',
      'prompt': 'How do I discreetly handle my period in the school bathroom?',
    },
    {
      'note': '“Cramps are just your uterus gently stretching. A warm water bottle and slow belly breaths work wonders.”',
      'action': 'Discover natural soothing tips',
      'prompt': 'What are the fastest natural ways to relieve period cramps?',
    },
    {
      'note': '“You don’t have to keep questions to yourself. Asking a trusted adult or school nurse makes everything so much easier.”',
      'action': 'See conversation starters',
      'prompt': 'How can I comfortably ask an adult for pads or medicine?',
    },
  ];

  // Things you might need (Unboxed Big Icons in Flo-inspired bold colors)
  final List<Map<String, dynamic>> _firstYearEssentials = [
    {
      'icon': Icons.water_drop_rounded,
      'title': 'Pads',
      'subtitle': 'How to use them',
      'iconBg': Color(0xFFFFECEB),
      'accent': Color(0xFFDD0D22),
      'articleTitle': 'How to Place & Change Pads Comfortably',
      'articleContent':
          '1. Peel the wrapper and remove the adhesive backing strip.\n2. Press the sticky side firmly onto the center of your underwear.\n3. Wrap the wings snugly around the sides.\n4. Change every 3 to 5 hours to stay fresh, clean, and confident.',
      'docsyPrompt': 'How often should I change my sanitary pad during school?',
    },
    {
      'icon': Icons.shield_outlined,
      'title': 'Leaks',
      'subtitle': 'What to do',
      'iconBg': Color(0xFFDBEAFE),
      'accent': Color(0xFF2563EB),
      'articleTitle': 'What to Do if You Leak in Public: No Panic Guide',
      'articleContent':
          'First: take a deep breath. Leaks happen to literally every single person who gets a period!\n\n1. Tie a sweatshirt, hoodie, or jacket around your waist.\n2. Head to the restroom and swap in a fresh pad.\n3. Rinse any fabric with cold water in the sink.\n4. Remember: teachers and friends are always ready to help.',
      'docsyPrompt': 'What should I do if I leak through my pants at school?',
    },
    {
      'icon': Icons.spa_rounded,
      'title': 'Cramps',
      'subtitle': 'Feel better',
      'iconBg': Color(0xFFCCFBF1),
      'accent': Color(0xFF0D9488),
      'articleTitle': 'Relieving First-Year Cramps Naturally',
      'articleContent':
          'Uterine cramps are caused by gentle muscle contractions.\n\nQuick Soothers:\n• Warm water bottle or heat patch on your lower tummy\n• Gentle cat-cow back stretches\n• Warm chamomile or mint tea\n• Staying well-hydrated throughout the day.',
      'docsyPrompt': 'What helps relieve period cramps quickly during class?',
    },
    {
      'icon': Icons.autorenew_rounded,
      'title': 'Irregular Cycles',
      'subtitle': 'What’s normal',
      'iconBg': Color(0xFFF3E8FF),
      'accent': Color(0xFF7209B7),
      'articleTitle': 'Why First-Year Cycles are Irregular',
      'articleContent':
          'In your first 1–2 years of menstruation, your ovaries and brain are learning to communicate. Cycles can range between 21 to 45 days, and skipping a month is 100% normal!\n\nYour body does not need rigid mathematical precision right now—it is simply exploring its unique natural rhythm.',
      'docsyPrompt': 'Is it normal to skip a period in my first year?',
    },
    {
      'icon': Icons.backpack_rounded,
      'title': 'School Bag',
      'subtitle': 'Be prepared',
      'iconBg': Color(0xFFFFEBE0),
      'accent': Color(0xFFFF4A00),
      'articleTitle': 'School Bag Emergency Kit Essentials',
      'articleContent':
          'Keep an opaque, discreet pouch in your backpack with:\n• 2-3 daytime pads with wings\n• 1 spare pair of underwear folded in a clean ziplock\n• Small pack of soothing wet wipes\n• Cozy mints or snack.',
      'docsyPrompt': 'What are the best discreet items to carry for my period in school?',
    },
    {
      'icon': Icons.school_rounded,
      'title': 'School Help',
      'subtitle': 'Who to ask',
      'iconBg': Color(0xFFFEF3C7),
      'accent': Color(0xFFD97706),
      'articleTitle': 'Asking Teachers & School Nurses for Help',
      'articleContent':
          'Need to visit the restroom or nurse? Keep it simple and direct:\n• "May I please step out to use the restroom?"\n• To the school nurse: "I have cramps / need a pad, do you have any supplies?"\nSchool nurses keep pads and heating pads specifically for this!',
      'docsyPrompt': 'How do I ask my teacher to use the bathroom during class without feeling awkward?',
    },
  ];

  // Common "Is This Normal?" Prompts
  final List<Map<String, dynamic>> _isThisNormalQueries = [
    {
      'query': '“I got brown or dark blood”',
      'shortAnswer': '100% normal! Brown blood is just older blood that took longer to leave the uterus and oxidized.',
      'prompt': 'Why is my period blood dark brown and is it normal?',
    },
    {
      'query': '“My period came after only 20 days”',
      'shortAnswer': 'Very common in your first year. Your hormone signals are still finding their steady rhythm.',
      'prompt': 'Why did my period come early after 20 days?',
    },
    {
      'query': '“I noticed clear or white discharge”',
      'shortAnswer': 'Completely healthy. Vaginal discharge is your body’s natural self-cleaning fluid.',
      'prompt': 'What does white or clear discharge mean between periods?',
    },
    {
      'query': '“I have cramps in my lower back”',
      'shortAnswer': 'Uterine contractions can radiate to lower back muscles. Heat and gentle stretching help quickly.',
      'prompt': 'Why do period cramps hurt in my lower back?',
    },
    {
      'query': '“My period skipped a whole month”',
      'shortAnswer': 'Skipping periods in your first 1–2 years is normal as ovulation isn’t regular yet.',
      'prompt': 'Is it normal to skip a period for 1 or 2 months in the first year?',
    },
  ];

  // "Ask Mom For Me" Pre-made Requests
  final List<Map<String, dynamic>> _askMomTopics = [
    {
      'icon': Icons.water_drop_outlined,
      'title': 'Pads & Supplies',
      'script': '“Mom, can we buy a few more sanitary pads to keep in my room and school bag?”',
    },
    {
      'icon': Icons.spa_outlined,
      'title': 'Help with Cramps',
      'script': '“Mom, I’m having some cramps today. Can you help me find a heating pad or warm tea?”',
    },
    {
      'icon': Icons.backpack_outlined,
      'title': 'School Bag Kit',
      'script': '“Can we put together a little emergency pouch with spare underwear and wipes for my backpack?”',
    },
    {
      'icon': Icons.checkroom_outlined,
      'title': 'New Comfy Clothes',
      'script': '“Can we get some darker comfy cotton sweatpants and seamless underwear for period days?”',
    },
    {
      'icon': Icons.medical_services_outlined,
      'title': 'Doctor Check-In',
      'script': '“Mom, my periods have felt a bit uncomfortable lately. Could we schedule a visit with my doctor?”',
    },
    {
      'icon': Icons.chat_bubble_outline_rounded,
      'title': 'I Just Want to Talk',
      'script': '“Hey Mom, can I ask you a few questions about what your first year of periods was like?”',
    },
  ];

  @override
  void initState() {
    super.initState();
    _cycleVM.addListener(_onCycleChanged);
    _loadSavedStage2Data();
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
          if (event.flowIntensity.isNotEmpty) {
            _loggedFlow = event.flowIntensity;
          }
        });
      }
    });
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
          flowIntensity: _loggedFlow ?? 'light',
        );
      } catch (_) {}

      HomeEventBus().emit(
        PeriodLoggedEvent(
          flowIntensity: _loggedFlow ?? 'light',
          date: picked,
        ),
      );
    }
  }

  void _loadSavedStage2Data() {
    try {
      // 1. School bag kit
      final savedBag = UserStateStore.read('stage2_school_bag');
      if (savedBag is Map) {
        for (final entry in savedBag.entries) {
          if (_schoolBagItems.containsKey(entry.key.toString())) {
            _schoolBagItems[entry.key.toString()] = entry.value == true;
          }
        }
      }

      // 2. Body changes journal
      final savedChanges = UserStateStore.read('stage2_body_changes');
      if (savedChanges is Map && savedChanges['selected'] is List) {
        _selectedBodyChanges.clear();
        _selectedBodyChanges.addAll((savedChanges['selected'] as List).map((e) => e.toString()));
      }

      // 3. Today's flow log
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final savedFlow = UserStateStore.read('stage2_flow_$todayStr');
      if (savedFlow is Map && savedFlow['flow'] is String) {
        _loggedFlow = savedFlow['flow'];
      }
      if (savedFlow is Map && savedFlow['cramp'] is String) {
        _selectedCramp = savedFlow['cramp'];
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _periodEventSub?.cancel();
    _cycleVM.removeListener(_onCycleChanged);
    _cycleVM.dispose();
    _internalScrollController.dispose();
    super.dispose();
  }

  // Fetch real-time AI companion insights
  Future<void> _fetchDynamicAiInsights() async {
    if (!mounted) return;
    setState(() => _isLoadingAiInsights = true);

    try {
      final insights = await ApiSiaService().getHealthInsights();
      if (mounted && insights.isNotEmpty) {
        final thought = insights['thought'] ?? insights['summary'] ?? insights['insight'] ?? insights['headline'];
        if (thought is String && thought.trim().isNotEmpty) {
          setState(() {
            _dynamicDocsyNote = thought;
          });
        }
      }
    } catch (_) {
      // Graceful fallback to daily rotating note
    } finally {
      if (mounted) setState(() => _isLoadingAiInsights = false);
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
  // 00 — EDITORIAL GREETING (UNBOXED, Cormorant & Manrope)
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

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 20),
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
            '$userName.',
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
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 01 — PERIOD TRACKER CARD (Exact Blushy Fallopian Tracker)
  // ════════════════════════════════════════════════════════════════
  Widget _buildPeriodTrackerCard(BuildContext context) {
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
            Text(AppLocalizations.of(context).fpsNoPeriodLoggedYet,
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
                ? _openDocsyWithPrompt(context, 'What happens in my body during the $_currentPhaseName, and what is normal to expect?')
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
          const SizedBox(height: 12),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFECE4DC)),
          const SizedBox(height: 10),

          // Insights Row
          InkWell(
            onTap: () {
              _openDocsyWithPrompt(
                context,
                'Tell me what happens in the body during the $_currentPhaseName of the first year.',
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite_border_rounded,
                    size: 16,
                    color: blushyPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(AppLocalizations.of(context).fpsInsightsForYourPhase,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF221510),
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF7A6B72),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 02 — NOTE FROM DOCSY CARD
  // ════════════════════════════════════════════════════════════════
  Widget _buildNoteFromDocsy(BuildContext context) {
    final noteItem = _dailyDocsyNotes[_dayOfYear % _dailyDocsyNotes.length];
    final noteText = _dynamicDocsyNote ?? noteItem['note']!;
    final actionText = noteItem['action']!;
    final promptText = noteItem['prompt']!;

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
              Text(
                noteText,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF221510),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openDocsyWithPrompt(context, promptText),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$actionText →',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: blushyPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 0.8, color: Color(0xFFECE4DC)),
              const SizedBox(height: 14),

              // Search-bar style ask container
              InkWell(
                onTap: () => _openDocsyWithPrompt(context, ''),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFECE4DC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: Color(0xFF7A6B72),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ask Docsy anything about your first year...',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF7A6B72),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: blushyPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick prompt chips in a clean horizontal scroll list
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildPromptChip(context, 'Why are periods irregular?'),
                    const SizedBox(width: 8),
                    _buildPromptChip(context, 'What if I leak at school?'),
                    const SizedBox(width: 8),
                    _buildPromptChip(context, 'How often to change pads?'),
                    const SizedBox(width: 8),
                    _buildPromptChip(context, 'How to soothe cramps?'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromptChip(BuildContext context, String text) {
    return InkWell(
      onTap: () => _openDocsyWithPrompt(context, text),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEFE8E0)),
        ),
        child: Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4A3E3D),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 03 — THINGS YOU MIGHT NEED (Unboxed Big Icons in Flo-Colors)
  // ════════════════════════════════════════════════════════════════
  Widget _buildThingsYouMightNeed(BuildContext context) {
    final rotationOffset = _dayOfYear % _firstYearEssentials.length;
    final dynamicEssentials = [
      ..._firstYearEssentials.sublist(rotationOffset),
      ..._firstYearEssentials.sublist(0, rotationOffset),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Things You Might Need'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Things you’ll want to know',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF221510),
              ),
            ),
            Text(AppLocalizations.of(context).fpsQuickGuides,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7A6B72),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 114,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dynamicEssentials.length,
            itemBuilder: (context, idx) {
              final item = dynamicEssentials[idx];
              final Color accentColor = item['accent'] as Color;
              final Color iconBg = item['iconBg'] as Color;

              return Container(
                width: 84,
                margin: EdgeInsets.only(right: idx == dynamicEssentials.length - 1 ? 0 : 12),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => ArticleDetailDialog(
                        title: item['articleTitle'],
                        summary: item['articleContent'],
                        question: item['docsyPrompt'],
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withOpacity(0.25),
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          item['icon'] as IconData,
                          size: 26,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title'] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF221510),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item['subtitle'] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 9.5,
                          color: const Color(0xFF7A6B72),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  // ════════════════════════════════════════════════════════════════
  // 03 — PERIOD MODE / LOG TODAY (Adaptive Day 1–4 Experience)
  // ════════════════════════════════════════════════════════════════
  Widget _buildPeriodModeLoggerCard(BuildContext context) {
    final flows = [
      {'label': 'Light', 'icon': '💧', 'intensity': 'light'},
      {'label': 'Medium', 'icon': '💧💧', 'intensity': 'medium'},
      {'label': 'Heavy', 'icon': '💧💧💧', 'intensity': 'heavy'},
      {'label': 'Ended', 'icon': '✨', 'intensity': 'ended'},
    ];

    final cramps = ['None', 'Mild', 'Moderate', 'Strong'];

    PersonalContext? pc;
    try {
      pc = BlushyOSProvider.of(context).personalContext;
    } catch (_) {}

    DateTime? lastPeriod = pc?.lastPeriodStart;
    if (lastPeriod == null) {
      try {
        final prof = BlushyStorage.read('user_profile.json');
        final raw = prof['last_period_date'] ?? prof['last_period'] ?? prof['period_last_start_date'];
        if (raw != null) {
          lastPeriod = BlushyOSState.parseFlexibleDate(raw);
        }
      } catch (_) {}
    }

    int? cycleDay;
    String headerTitle = 'Log Today’s Flow';
    String statusTag = _loggedFlow != null ? 'Logged' : 'Daily Log';
    String subtitleText = 'Tap your flow intensity if your period is active today.';

    if (lastPeriod != null) {
      final diff = DateTime.now().difference(lastPeriod).inDays + 1;
      if (diff > 0 && diff <= 45) {
        cycleDay = diff;
        if (cycleDay <= 6) {
          headerTitle = 'Day $cycleDay · Period Flow';
          statusTag = cycleDay <= 2 ? 'Heavy / Medium' : 'Winding Down';
          subtitleText = 'Your flow is changing. Take it easy and stay comfortable.';
        } else {
          headerTitle = 'Day $cycleDay of Cycle';
          statusTag = 'Cycle Active';
          subtitleText = 'Track any symptoms or spotting to keep your cycle history updated.';
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Your Period Today'),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    headerTitle,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF221510),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: blushySoftPink,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusTag,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: blushyPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitleText,
                style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72)),
              ),
              const SizedBox(height: 14),
              Text(
                'Log Flow for Today:',
                style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF7A6B72)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: flows.map((f) {
                  final isSelected = _loggedFlow == f['intensity'];
                  return InkWell(
                    onTap: () async {
                      setState(() {
                        _loggedFlow = f['intensity']!;
                      });
                      final todayStr = DateTime.now().toIso8601String().split('T').first;
                      UserStateStore.write('stage2_flow_$todayStr', {
                        'flow': _loggedFlow,
                        'cramp': _selectedCramp,
                      });
                      if (f['intensity'] != 'ended') {
                        ApiPeriodService().logPeriodEntry(
                          periodStartDate: DateTime.now(),
                          flowIntensity: f['intensity'],
                          notes: 'Logged from Stage 2 Home',
                        );
                      }
                      HomeEventBus().emit(
                        PeriodLoggedEvent(
                          flowIntensity: f['intensity']!,
                          date: DateTime.now(),
                        ),
                      );
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: blushyPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          content: Text(
                            'Period flow logged for today (${f['label']})',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? blushySoftPink : const Color(0xFFFAF7F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? blushyPrimary : cardBorderColor,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(f['icon']!, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(
                            f['label']!,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? blushyPrimary : const Color(0xFF4A3E39),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cramps Level:',
                    style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF7A6B72)),
                  ),
                  InkWell(
                    onTap: () => _showCrampRescueModal(context),
                    child: Text(AppLocalizations.of(context).fpsCrampRescue,
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: blushyPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: cramps.map((c) {
                  final isSelected = _selectedCramp == c;
                  return ChoiceChip(
                    label: Text(c),
                    selected: isSelected,
                    selectedColor: const Color(0xFFCCFBF1),
                    backgroundColor: const Color(0xFFFAF7F2),
                    labelStyle: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF4A3E39),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSelected ? const Color(0xFF0D9488) : cardBorderColor),
                    ),
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _selectedCramp = c);
                        final todayStr = DateTime.now().toIso8601String().split('T').first;
                        UserStateStore.write('stage2_flow_$todayStr', {
                          'flow': _loggedFlow,
                          'cramp': _selectedCramp,
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 04 — “IS THIS NORMAL?” (Interactive Query Hub)
  // ════════════════════════════════════════════════════════════════
  Widget _buildIsThisNormalCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Is This Normal?'),
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
                'Got a question you’re wondering about?',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221510),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap any situation to get an immediate, non-scary explanation.',
                style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72)),
              ),
              const SizedBox(height: 12),
              Column(
                children: _isThisNormalQueries.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => ArticleDetailDialog(
                            title: item['query'] as String,
                            summary: item['shortAnswer'] as String,
                            question: item['prompt'] as String,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.help_outline_rounded, size: 16, color: blushyPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['query'] as String,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF221510),
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFF7A6B72)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openDocsyWithPrompt(context, 'Docsy, is this normal? '),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: blushyPrimary),
                  label: Text(
                    'Ask Docsy your own question →',
                    style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: blushyPrimary),
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
  // 05 — SCHOOL MODE (First-Class Destination)
  // ════════════════════════════════════════════════════════════════
  Widget _buildSchoolModeCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('School Mode'),
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
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEBE0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_rounded, color: Color(0xFFFF4A00), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'I’m at School Right Now',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF221510),
                          ),
                        ),
                        Text(
                          'Quick help for restrooms, supplies, or speaking to teachers.',
                          style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF7A6B72)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // What do I say script box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.record_voice_over_outlined, size: 14, color: blushyPrimary),
                        const SizedBox(width: 6),
                        Text(
                          '“What do I say to my teacher?”',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: blushyPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '“Ma\'am/Sir, I’m feeling unwell / need to use the washroom. May I please step out?”',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF221510),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _showEmergency5StepsModal(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blushyPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Leak Rescue (5 Steps) →',
                      style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _openDocsyWithPrompt(context, 'What should I do if I get my period at school?'),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 13, color: blushyPrimary),
                    label: Text(AppLocalizations.of(context).fpsSchoolTips,
                      style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: blushyPrimary),
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
  // 06 — SMART PERIOD BAG (Contextual Checklist)
  // ════════════════════════════════════════════════════════════════
  Widget _buildSmartPeriodBagCard(BuildContext context) {
    final packedCount = _schoolBagItems.values.where((v) => v).length;
    final totalCount = _schoolBagItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Smart Period Bag'),
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context).fpsMySchoolBagKit,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF221510),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: packedCount == totalCount ? const Color(0xFFCCFBF1) : blushySoftPink,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$packedCount / $totalCount ready',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: packedCount == totalCount ? const Color(0xFF0D9488) : blushyPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalCount == 0 ? 0 : packedCount / totalCount,
                  backgroundColor: const Color(0xFFFAF2ED),
                  valueColor: const AlwaysStoppedAnimation<Color>(blushyPrimary),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: _schoolBagItems.entries.map((entry) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: blushyPrimary,
                    title: Text(
                      entry.key,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: entry.value ? FontWeight.w700 : FontWeight.w500,
                        color: entry.value ? const Color(0xFF221510) : const Color(0xFF7A6B72),
                      ),
                    ),
                    value: entry.value,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _schoolBagItems[entry.key] = val);
                        UserStateStore.write('stage2_school_bag', _schoolBagItems);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 07 — BODY CHANGES JOURNAL ("Things I'm Noticing")
  // ════════════════════════════════════════════════════════════════
  Widget _buildBodyChangesCard(BuildContext context) {
    final changesList = [
      'Discharge',
      'Body hair',
      'Breast changes',
      'Acne',
      'Body odor',
      'Mood swings',
      'Cramps',
      'Feeling tired',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Body Changes Journal'),
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
              Text(AppLocalizations.of(context).fpsThingsIMNoticingLately,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221510),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select what you’ve experienced recently to explore with Docsy.',
                style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: changesList.map((item) {
                  final isSelected = _selectedBodyChanges.contains(item);
                  return FilterChip(
                    label: Text(item),
                    selected: isSelected,
                    selectedColor: blushySoftPink,
                    backgroundColor: const Color(0xFFFAF7F2),
                    labelStyle: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? blushyPrimary : const Color(0xFF4A3E39),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSelected ? blushyPrimary : cardBorderColor),
                    ),
                    onSelected: (sel) {
                      setState(() {
                        if (sel) {
                          _selectedBodyChanges.add(item);
                        } else {
                          _selectedBodyChanges.remove(item);
                        }
                      });
                      UserStateStore.write('stage2_body_changes', {'selected': _selectedBodyChanges.toList()});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              if (_selectedBodyChanges.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final listStr = _selectedBodyChanges.join(', ');
                      _openDocsyWithPrompt(context, 'Can you explain why I am noticing $listStr during puberty and my first year of periods?');
                    },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                    label: Text(AppLocalizations.of(context).fpsUnderstandWithDocsy,
                      style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blushyPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  // 08 — ASK MOM FOR ME ("I don't know how to ask")
  // ════════════════════════════════════════════════════════════════
  Widget _buildAskMomForMeCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Ask Mom For Me'),
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
                '“I don’t know how to ask”',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221510),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap any topic to generate a gentle, easy message you can send Mom or Dad.',
                style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _askMomTopics.map((topic) {
                  return InkWell(
                    onTap: () => _showAskMomModal(context, topic['title'] as String, topic['script'] as String),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(topic['icon'] as IconData, size: 14, color: blushyPrimary),
                          const SizedBox(width: 6),
                          Text(
                            topic['title'] as String,
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
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 09 — SAFETY & WHEN TO GET HELP (Decision Helper)
  // ════════════════════════════════════════════════════════════════
  Widget _buildSafetyHelperCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('When to Tell an Adult'),
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
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.health_and_safety_outlined, color: Color(0xFFD97706), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'When should I tell a trusted adult?',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF221510),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Most first-year symptoms are normal, but let an adult or doctor know if you have:',
                style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF7A6B72)),
              ),
              const SizedBox(height: 8),
              _buildSafetyBullet('Soaking through a pad every 1–2 hours for several hours in a row'),
              _buildSafetyBullet('Severe tummy pain that doesn’t get better with rest or warm heat'),
              _buildSafetyBullet('Bleeding that lasts longer than 7 days continuously'),
              _buildSafetyBullet('Feeling very dizzy, faint, or lightheaded'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: blushyPrimary, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF4A3E39)),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // MODALS: Cramp Rescue & Ask Mom Generator
  // ════════════════════════════════════════════════════════════════
  void _showCrampRescueModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(AppLocalizations.of(context).fpsCrampRescue2,
                  style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF221510)),
                ),
                const SizedBox(height: 4),
                Text('Gentle comfort measures for your lower tummy and back.', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72))),
                const SizedBox(height: 16),
                _buildRescueTip('1. Warmth', 'Place a warm water bottle or heating pad on your lower belly.'),
                _buildRescueTip('2. Slow Breathing', 'Inhale for 4 seconds, hold for 2, exhale for 6 to relax tummy muscles.'),
                _buildRescueTip('3. Gentle Stretch', 'Try child\'s pose or cat-cow to relieve lower back pressure.'),
                _buildRescueTip('4. Tell an Adult', 'If cramps make it hard to focus, ask a parent or nurse for comfort advice.'),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: blushyPrimary, foregroundColor: Colors.white),
                    child: Text(AppLocalizations.of(context).fpsIFeelBetter, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRescueTip(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF221510))),
          Text(desc, style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF7A6B72))),
        ],
      ),
    );
  }

  void _showAskMomModal(BuildContext context, String title, String script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Message for Mom / Guardian',
                  style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF221510)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Text(
                    script,
                    style: GoogleFonts.cormorantGaramond(fontSize: 17, fontStyle: FontStyle.italic, color: blushyPrimary),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: script));
                      try {
                        await Share.share(script, subject: 'Message from Blushy');
                      } catch (_) {}
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Message copied to clipboard & sharing opened! 🌸', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                            backgroundColor: blushyPrimary,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                    label: Text(AppLocalizations.of(context).fpsShareWithMom, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(backgroundColor: blushyPrimary, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 5-Step Emergency Modal
  void _showEmergency5StepsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '5 Steps If You Leak at School',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF221510),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Remember: This happens to every girl. Take it one gentle step at a time.',
                  style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72)),
                ),
                const SizedBox(height: 18),
                _buildEmergencyStepItem('1', 'Stay calm & tie a jacket around your waist', 'A sweater, hoodie, or jacket provides instant coverage.'),
                _buildEmergencyStepItem('2', 'Walk quietly to the nearest restroom', 'Excusing yourself with "May I use the restroom?" is all you need.'),
                _buildEmergencyStepItem('3', 'Put in a fresh pad or fold toilet paper', 'If you don\'t have a pad, 4-5 layers of toilet paper work as a temporary fix.'),
                _buildEmergencyStepItem('4', 'Visit the school nurse for backup supplies', 'School nurses have free pads, heating pads, and clean spare clothes.'),
                _buildEmergencyStepItem('5', 'Rinse fabric with cold water', 'Cold water prevents blood from setting into fabric.'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blushyPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Got it! I feel ready', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyStepItem(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: blushySoftPink,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: blushyPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF221510),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: const Color(0xFF7A6B72),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // MAIN BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F2),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          if (!isWide) {
            // Mobile Stacked Experience
            return SingleChildScrollView(
              controller: _effectiveScrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEditorialGreeting(context),
                  StageStateNotice(
                    state: _cycleState,
                    hasData: _hasLoggedPeriod,
                    emptyMessage: 'Once you log your first period, this page '
                        'works from your own cycle rather than general guidance.',
                    onRetry: _loadPeriodData,
                  ),
                  _buildPeriodTrackerCard(context),
                  const SizedBox(height: 22),
                  const LogSymptomsSection(stageKey: 'firstperiodstarted'),
                  const SizedBox(height: 18),
                  _buildNoteFromDocsy(context),
                  const SizedBox(height: 18),
                  _buildThingsYouMightNeed(context),
                  const SizedBox(height: 18),
                  _buildPeriodModeLoggerCard(context),
                  const SizedBox(height: 18),
                  _buildIsThisNormalCard(context),
                  const SizedBox(height: 18),
                  _buildSchoolModeCard(context),
                  const SizedBox(height: 18),
                  _buildSmartPeriodBagCard(context),
                  const SizedBox(height: 18),
                  _buildBodyChangesCard(context),
                  const SizedBox(height: 18),
                  _buildAskMomForMeCard(context),
                  const SizedBox(height: 18),
                  _buildSafetyHelperCard(context),
                  const SizedBox(height: 24),
                ],
              ),
            );
          } else {
            // Tablet / Desktop Layout
            return SingleChildScrollView(
              controller: _effectiveScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEditorialGreeting(context),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 58,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPeriodTrackerCard(context),
                                const SizedBox(height: 22),
                                const LogSymptomsSection(stageKey: 'firstperiodstarted'),
                                const SizedBox(height: 18),
                                _buildNoteFromDocsy(context),
                                const SizedBox(height: 18),
                                _buildThingsYouMightNeed(context),
                                const SizedBox(height: 18),
                                _buildPeriodModeLoggerCard(context),
                                const SizedBox(height: 18),
                                _buildIsThisNormalCard(context),
                                const SizedBox(height: 18),
                                _buildBodyChangesCard(context),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 42,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSchoolModeCard(context),
                                const SizedBox(height: 18),
                                _buildSmartPeriodBagCard(context),
                                const SizedBox(height: 18),
                                _buildAskMomForMeCard(context),
                                const SizedBox(height: 18),
                                _buildSafetyHelperCard(context),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
