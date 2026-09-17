import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../theme/colors.dart';
import '../../../../core/storage.dart';
import '../../../../core/state.dart';
import '../../../../services/api_period_service.dart';
import '../../view_models/first_period_not_started_view_model.dart';
import '../../../../services/sia_dashboard_service.dart';
import '../../home_screen.dart';
import '../../services/home_event_bus.dart';
import '../../../sia/open_docsy.dart';
import '../../../sia/sia_screen.dart';
import '../../../../shared/user_display_name.dart';
import '../../../../services/api_contract_client.dart';
import '../../../../shared/stage_empty_notice.dart';
import '../../widgets/log_symptoms_section.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/user_state_store.dart';

class FirstPeriodNotStartedDashboard extends StatefulWidget {
  final bool isNested;
  final ScrollController? scrollController;

  const FirstPeriodNotStartedDashboard({
    super.key,
    this.isNested = false,
    this.scrollController,
  });

  @override
  State<FirstPeriodNotStartedDashboard> createState() => _FirstPeriodNotStartedDashboardState();
}

class _FirstPeriodNotStartedDashboardState extends State<FirstPeriodNotStartedDashboard> {

  /// This screen is the View; the insight read lives in the tested
  /// FirstPeriodNotStartedViewModel and is mirrored back by _onInsightChanged.
  final FirstPeriodNotStartedViewModel _vm = FirstPeriodNotStartedViewModel();

  /// How the last insight load went. This stage has no cycle to report on, so
  /// the only thing worth saying is whether today's note actually came from
  /// the server or is the seeded fallback.
  ApiState _insightState = ApiState.loading;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ScrollController _internalScrollController = ScrollController();
  ScrollController get _effectiveScrollController => widget.scrollController ?? _internalScrollController;

  // Unified Blushy Crimson Primary
  static const Color blushyPrimary = Color(0xFFDD0D22);
  static const Color blushySoftPink = Color(0xFFFFECEB);
  static const Color cardBorderColor = Color(0xFFEFE8E0);

  // Dynamic real-time state
  String? _dynamicSiaThought;
  bool _isLoadingAiInsights = false;

  // First period kit interactive state (Defaults to false for first time users)
  final Map<String, bool> _stage1PeriodKitItems = {
    '2-3 soft sanitary pads': false,
    'Fresh pair of backup underwear': false,
    'Small discreet pouch for used items': false,
    'Gentle soothing wet wipes': false,
    'Travel-sized hand sanitizer': false,
    'Comforting mints or snack': false,
  };

  String? _selectedMood;
  int _promptIndex = 0;

  // ════════════════════════════════════════════════════════════════
  // DYNAMIC DAILY CONTENT ENGINE (Rotates dynamically by day of year)
  // ════════════════════════════════════════════════════════════════
  int get _dayOfYear {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays;
  }

  // Daily rotating Sia Thoughts (Changes every single day)
  final List<Map<String, String>> _dailySiaThoughts = [
    {
      'thought': '“You don’t have to understand everything about growing up at once. Taking it one question at a time is completely okay.”',
      'action': 'Learn about your body signs',
      'prompt': 'Why is my body changing during puberty and what should I expect?',
    },
    {
      'thought': '“Your body has its own perfect timeline. There is no such thing as being too early or too late.”',
      'action': 'Discover how growth works',
      'prompt': 'Is everyone’s puberty timeline different?',
    },
    {
      'thought': '“Notice small changes with curiosity, not worry. Every feeling you have right now is completely normal.”',
      'action': 'Explore everyday feelings',
      'prompt': 'Why do emotions feel extra intense during puberty?',
    },
    {
      'thought': '“Resting when you are tired is part of growing strong. Your body does its deepest building while you sleep.”',
      'action': 'Read about sleep & growth',
      'prompt': 'How does sleep help puberty growth spurts?',
    },
    {
      'thought': '“Being prepared gives you quiet confidence. A simple pouch in your backpack means you are ready for anything.”',
      'action': 'Review your backup kit',
      'prompt': 'How can I feel confident about getting my first period at school?',
    },
    {
      'thought': '“Discharge and skin changes are simply proof that your hormones are doing their healthy, natural job.”',
      'action': 'Understand body signs',
      'prompt': 'What does healthy discharge mean before your period?',
    },
    {
      'thought': '“Celebrate how unique you are. Your body is building a home for your future self with immense care.”',
      'action': 'Ask Docsy a question',
      'prompt': 'What are the top 5 signs of puberty in girls?',
    },
  ];

  // Dynamic rotating Family conversation starters
  final List<Map<String, String>> _parentPrompts = [
    {
      'question': '“What was your first period like?”',
      'subtext': 'Ask mom, an older sister, or a trusted relative how they felt when theirs first started.',
      'tag': 'Family Story',
    },
    {
      'question': '“Can we put together a little emergency kit for my school bag?”',
      'subtext': 'A discreet and easy way to organize pads, wipes, and a pouch together.',
      'tag': 'Preparation',
    },
    {
      'question': '“What should I do if I get cramps during class?”',
      'subtext': 'Learn your school nurse’s policy and have a quiet backup plan with your teacher.',
      'tag': 'School Tips',
    },
    {
      'question': '“Did you feel nervous before your period started?”',
      'subtext': 'Hearing how older women handled it makes everything so much calmer.',
      'tag': 'Reassurance',
    },
    {
      'question': '“How did you choose between pads and other period products?”',
      'subtext': 'Get practical advice on wings, thickness, and soft cotton comfort.',
      'tag': 'Product Advice',
    },
    {
      'question': '“What were your earliest body signs before your period arrived?”',
      'subtext': 'Learn about family genetics, growth spurts, and bodily milestones.',
      'tag': 'Body Milestones',
    },
  ];

  // Puberty guides with balanced colorful icons/accents
  final List<Map<String, dynamic>> _bodyTopics = [
    {
      'icon': Icons.water_drop_outlined,
      'title': 'Discharge',
      'subtitle': 'Nature’s natural self-cleaning fluid',
      'tag': 'Very Normal',
      'iconBg': Color(0xFFDBEAFE),
      'accent': Color(0xFF2563EB),
      'articleTitle': 'Understanding Vaginal Discharge: Nature’s Cleanser',
      'articleContent':
          'Noticing clear or milky-white fluid in your underwear? That is completely normal! In fact, vaginal discharge is your body\'s natural, self-cleaning way of keeping everything healthy, balanced, and lubricated.\n\nUsually, regular vaginal discharge begins 6 months to 1.5 years before your first actual period arrives. It is a sign that your body is producing estrogen and getting closer to maturity.',
      'docsyPrompt': 'Why do I have discharge before my period and how do I manage it?',
    },
    {
      'icon': Icons.trending_up_rounded,
      'title': 'Growth Spurts',
      'subtitle': 'Growing taller & hips widening naturally',
      'tag': 'Puberty Stage',
      'iconBg': Color(0xFFCCFBF1),
      'accent': Color(0xFF0D9488),
      'articleTitle': 'Growth Spurts & Body Shape Changes in Puberty',
      'articleContent':
          'During puberty, your bones and muscles grow at their fastest rate since toddlerhood! You might notice clothes becoming shorter or hips naturally widening to create room for future adult bone structure.\n\nBe patient and kind to yourself: growing takes tons of energy, so extra sleep and nutritious food help a lot!',
      'docsyPrompt': 'Why do my legs and joints feel sore during a growth spurt?',
    },
    {
      'icon': Icons.auto_fix_high_rounded,
      'title': 'Body Hair',
      'subtitle': 'Soft peach fuzz to natural protective hair',
      'tag': 'Natural Step',
      'iconBg': Color(0xFFF3E8FF),
      'accent': Color(0xFF7209B7),
      'articleTitle': 'Pubic & Underarm Hair: Why It Appears',
      'articleContent':
          'Hair starting to appear around your pubic area and underarms is usually one of the earliest milestones of puberty. It starts as fine, soft fuzz and gradually becomes thicker and curlier over 1-3 years.\n\nThis hair acts as a natural protective barrier against friction and bacteria. Keeping clean with warm water is all you need.',
      'docsyPrompt': 'Is it normal to have pubic hair before my period starts?',
    },
    {
      'icon': Icons.spa_outlined,
      'title': 'Breast Buds',
      'subtitle': 'Tender buttons under nipples',
      'tag': 'First Sign',
      'iconBg': Color(0xFFFFE5F0),
      'accent': Color(0xFFF72585),
      'articleTitle': 'Breast Buds: Tender Under the Nipple',
      'articleContent':
          'Small, firm, marble-sized bumps (called breast buds) underneath the nipples are usually the very first physical sign of puberty. One side often starts before the other—this unevenness is 100% normal!\n\nThey may feel slightly tender or sensitive to light pressure. Soft cotton bralettes provide gentle comfort.',
      'docsyPrompt': 'Why does one breast hurt or feel harder than the other?',
    },
    {
      'icon': Icons.wb_twilight_rounded,
      'title': 'Mood Shifts',
      'subtitle': 'Big emotions & energy swings',
      'tag': 'Emotional',
      'iconBg': Color(0xFFFEF3C7),
      'accent': Color(0xFFD97706),
      'articleTitle': 'Hormones & Emotional Swings Explained',
      'articleContent':
          'Surging hormones not only change your body physically—they also interact with brain chemistry! It\'s completely normal to feel emotional or energetic in shifts.\n\nRemember: your feelings are valid. Giving yourself quiet space, listening to music, or taking deep breaths helps your nervous system recalibrate.',
      'docsyPrompt': 'Why do my moods feel so intense lately?',
    },
    {
      'icon': Icons.face_retouching_natural_rounded,
      'title': 'Skin & Glow',
      'subtitle': 'Pores, natural oils & gentle care',
      'tag': 'Skin Health',
      'iconBg': Color(0xFFFFEBE0),
      'accent': Color(0xFFFF4A00),
      'articleTitle': 'Puberty Skin Changes & Oil Glands',
      'articleContent':
          'As hormone levels rise, the oil glands in your skin produce more sebum. This is completely natural! Washing your face twice daily with a gentle, non-stripping cleanser keeps your skin balanced and glowing.',
      'docsyPrompt': 'How should I care for my skin if I get small pimples in puberty?',
    },
    {
      'icon': Icons.bedtime_outlined,
      'title': 'Sleep & Growth',
      'subtitle': 'Deep rest powers cellular growth',
      'tag': 'Daily Rest',
      'iconBg': Color(0xFFFFECEB),
      'accent': Color(0xFFDD0D22),
      'articleTitle': 'Why You Need 9-10 Hours of Sleep During Puberty',
      'articleContent':
          'Growth hormone is primarily released during deep REM and Stage 3 sleep cycles. When your body is going through growth spurts, needing extra sleep is not laziness—it is essential biology!',
      'docsyPrompt': 'Why do teenagers need more sleep than adults?',
    },
  ];

  // Dynamic rotating article library
  final List<Map<String, dynamic>> _exploreArticlesPool = [
    {
      'title': 'Signs Your First Period May Be Coming Soon',
      'readTime': '5 min read',
      'tag': 'Milestones',
      'tagBg': Color(0xFFFFE5F0),
      'accent': Color(0xFFF72585),
      'content':
          'From breast tenderness and pubic hair to vaginal discharge and sudden height changes, learn the classic milestones that indicate your first period (menarche) is nearing over the next 6-18 months.',
      'docsy': 'What are the main signs that mean my first period is coming soon?',
    },
    {
      'title': 'What Does a Period Actually Feel Like?',
      'readTime': '4 min read',
      'tag': 'First-Hand Guide',
      'tagBg': Color(0xFFCCFBF1),
      'accent': Color(0xFF0D9488),
      'content':
          'Does it hurt? How much flow comes out? Discover what real girls experience: mild cramping like stomach bubbles, a warm trickle sensation, and why it is much gentler than rumors make it seem.',
      'docsy': 'What does getting a period feel like physically?',
    },
    {
      'title': 'What to Keep in Your School Emergency Pouch',
      'readTime': '3 min read',
      'tag': 'Prep Checklist',
      'tagBg': Color(0xFFF3E8FF),
      'accent': Color(0xFF7209B7),
      'content':
          'A discreet, clean emergency pouch with pads, backup underwear, and wipes keeps you feeling 100% confident wherever you are throughout the school day.',
      'docsy': 'How should I pack a discreet period kit for my locker or backpack?',
    },
    {
      'title': 'How to Talk to Mom, Dad, or Teachers Easily',
      'readTime': '4 min read',
      'tag': 'Communication',
      'tagBg': Color(0xFFDBEAFE),
      'accent': Color(0xFF2563EB),
      'content':
          'Feeling shy about asking for pads or explaining cramps? Here are gentle, simple wordings you can text or say to make the conversation effortless.',
      'docsy': 'How can I ask my teacher to go to the restroom if I get my period during class?',
    },
    {
      'title': 'Cramps & Back Aches: Quick Natural Soothers',
      'readTime': '4 min read',
      'tag': 'Body Comfort',
      'tagBg': Color(0xFFFFEBE0),
      'accent': Color(0xFFFF4A00),
      'content':
          'Warm water bottles, gentle stretching, warm chamomile tea, and deep belly breathing can relieve lower tummy tension within minutes.',
      'docsy': 'What are the best natural remedies for early period cramps?',
    },
  ];

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onInsightChanged);
    _loadSavedStage1Data();
    _fetchDynamicAiInsights();
  }

  void _loadSavedStage1Data() {
    try {
      final savedKit = UserStateStore.read('stage1_period_kit');
      if (savedKit is Map) {
        for (final entry in savedKit.entries) {
          if (_stage1PeriodKitItems.containsKey(entry.key.toString())) {
            _stage1PeriodKitItems[entry.key.toString()] = entry.value == true;
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _vm.removeListener(_onInsightChanged);
    _vm.dispose();
    _internalScrollController.dispose();
    super.dispose();
  }

  /// Delegated to the view model; _onInsightChanged mirrors the result.
  Future<void> _fetchDynamicAiInsights() => _vm.load();

  /// The View reacting to its ViewModel.
  void _onInsightChanged() {
    if (!mounted) return;
    setState(() {
      _insightState = _vm.insightState;
      _isLoadingAiInsights = _vm.isLoading;
      _dynamicSiaThought = _vm.siaThought ?? _dynamicSiaThought;
    });
  }

  // Helper to open real Docsy AI companion
  void _openDocsyWithPrompt(BuildContext context, String prompt) {
    openDocsyWith(context, prompt.isNotEmpty ? prompt : null);
  }

  // Milestone transition modal
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
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F2),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: blushySoftPink,
                        shape: BoxShape.circle,
                        border: Border.all(color: blushyPrimary.withOpacity(0.2), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.favorite_rounded, color: blushyPrimary, size: 26),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You did it.',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF221510),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Let’s take this one gentle step at a time.\nBlushy is right here with you.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: const Color(0xFF7A6B72),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: blushyPrimary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'When did it start?',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF7A6B72),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF221510),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now(),
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
                                setModalState(() => selectedDate = picked);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: blushyPrimary,
                              textStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            child: Text(AppLocalizations.of(context).fpnsChange),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Captured before the pop, because the sheet's own
                          // context is gone immediately after it.
                          final osState = BlushyOSProvider.of(context);
                          Navigator.pop(context);
                          try {
                            final profileData = Map<String, dynamic>.from(BlushyStorage.read('user_profile.json'));
                            profileData['lifeStage'] = 'firstPeriodStarted';
                            if (profileData['profile'] is Map) {
                              (profileData['profile'] as Map)['lifeStage'] = 'firstPeriodStarted';
                            }
                            BlushyStorage.write('user_profile.json', profileData);

                            // The home screen reads the stage from app state,
                            // not from this file, so writing storage alone
                            // changed nothing until the app was restarted --
                            // which is exactly how this looked: you press
                            // Continue to Stage 2, and the page stays put.
                            //
                            // `setActiveLifeStages` writes the same storage,
                            // updates `personalContext.lifeStage`, and
                            // notifies, so the dashboard swaps immediately.
                            osState.setActiveLifeStages({'firstPeriodStarted'});
                            HomeEventBus().emit(
                              PeriodLoggedEvent(
                                flowIntensity: 'light',
                                date: selectedDate,
                              ),
                            );
                          } catch (_) {}
                          try {
                            ApiPeriodService().logPeriodEntry(
                              periodStartDate: selectedDate,
                              flowIntensity: 'light',
                              notes: 'First period milestone',
                            );
                          } catch (_) {}
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Welcome to Stage 2! Blushy is personalized for your cycle now.',
                                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: blushyPrimary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blushyPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Continue to Stage 2 →',
                          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700),
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

  // First period kit interactive modal
  void _showFirstPeriodKitModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final packedCount = _stage1PeriodKitItems.values.where((p) => p).length;
            final totalCount = _stage1PeriodKitItems.length;

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppLocalizations.of(context).fpnsFirstPeriodKit,
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF221510),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$packedCount of $totalCount items packed in your pouch',
                                style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: packedCount == totalCount ? const Color(0xFFEAF9F7) : blushySoftPink,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            packedCount == totalCount ? 'Ready' : '${totalCount - packedCount} left',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: packedCount == totalCount ? const Color(0xFF0F9D8F) : blushyPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalCount == 0 ? 0 : packedCount / totalCount,
                        backgroundColor: const Color(0xFFE8E0D7),
                        valueColor: const AlwaysStoppedAnimation<Color>(blushyPrimary),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: _stage1PeriodKitItems.entries.map((entry) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: entry.value
                                    ? blushyPrimary.withOpacity(0.2)
                                    : cardBorderColor,
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                entry.key,
                                style: GoogleFonts.manrope(
                                  fontSize: 12.5,
                                  fontWeight: entry.value ? FontWeight.w600 : FontWeight.w500,
                                  color: entry.value ? const Color(0xFF221510) : const Color(0xFF7A6B72),
                                ),
                              ),
                              value: entry.value,
                              activeColor: blushyPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              onChanged: (val) {
                                setModalState(() {
                                  _stage1PeriodKitItems[entry.key] = val ?? false;
                                });
                                UserStateStore.write('stage1_period_kit', _stage1PeriodKitItems);
                                setState(() {});
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blushyPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(AppLocalizations.of(context).fpnsSaveDone,
                          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700),
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

  // 5-step emergency sheet
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
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: blushySoftPink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.shield_outlined, color: blushyPrimary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'If it happens today...',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF221510),
                            ),
                          ),
                          Text(
                            'Take a deep breath. You are 100% safe.',
                            style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildEmergencyStepRow('01', 'Head to the restroom', 'Grab your backpack or kit pouch and excuse yourself to the nearest private stall.'),
                _buildEmergencyStepRow('02', 'Place a pad or fold tissue', 'Peel the adhesive backing and stick it firmly in your underwear. Folded toilet paper works great in a pinch!'),
                _buildEmergencyStepRow('03', 'Tell a trusted adult', 'Your school nurse, teacher, mom, or friend\'s mom can always provide an extra pad or clothing.'),
                _buildEmergencyStepRow('04', 'Tie a jacket around your waist', 'If there is a small spot on your clothes, wrap a hoodie or sweater. Nobody will think twice.'),
                _buildEmergencyStepRow('05', 'Celebrate your body', 'You just reached a natural, healthy milestone. You handled it with grace.'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openDocsyWithPrompt(context, 'What should I do right now if my first period started at school?');
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Colors.white),
                    label: Text(
                      'Ask Docsy for live guidance →',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blushyPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyStepRow(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: blushySoftPink,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
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
                    fontSize: 11.5,
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

  // Consistent Crimson Eyebrow matching Blushy's theme
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
  // 01 — YOUR JOURNEY CARD (Clean White Card with Red Action)
  // ════════════════════════════════════════════════════════════════
  Widget _buildYourJourneyCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Your Journey'),
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
                'Your body is growing at its own pace',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF221510),
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Learn what’s happening, prepare your emergency kit, and ask Docsy whenever you are curious.',
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  color: const Color(0xFF7A6B72),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showTransitionToStartedDialog(context),
                icon: const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white),
                label: Text(AppLocalizations.of(context).fpnsLogAPeriodStart,
                  style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blushyPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 02 — TODAY WITH DOCSY (Dynamic Real-Time AI Insight)
  // ════════════════════════════════════════════════════════════════
  Widget _buildTodayAiMoment(BuildContext context) {
    // Select daily thought based on day of year or dynamic backend AI
    final dailyThoughtObj = _dailySiaThoughts[_dayOfYear % _dailySiaThoughts.length];
    final displayThought = _dynamicSiaThought ?? dailyThoughtObj['thought']!;
    final displayAction = dailyThoughtObj['action']!;
    final displayPrompt = dailyThoughtObj['prompt']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildEyebrow('Today with Docsy'),
            if (_isLoadingAiInsights)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: blushyPrimary),
              ),
          ],
        ),
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
                displayThought,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF221510),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _openDocsyWithPrompt(context, displayPrompt),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayAction,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: blushyPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: blushyPrimary),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF3EEE9)),
              const SizedBox(height: 12),
              // Ask Docsy search-style bar
              InkWell(
                onTap: () => _openDocsyWithPrompt(context, ''),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 15, color: Color(0xFF7A6B72)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ask Docsy anything...',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            color: const Color(0xFF9E8E95),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 13, color: blushyPrimary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Quick prompt chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickDocsyChip(context, 'Why do I have discharge?'),
                    const SizedBox(width: 6),
                    _buildQuickDocsyChip(context, 'What if it happens at school?'),
                    const SizedBox(width: 6),
                    _buildQuickDocsyChip(context, 'Is this normal?'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickDocsyChip(BuildContext context, String text) {
    return InkWell(
      onTap: () => _openDocsyWithPrompt(context, text),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cardBorderColor),
        ),
        child: Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4A3E39),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 03 — PUBERTY GUIDE (Clean Unboxed Big Icons in Different Colors)
  // ════════════════════════════════════════════════════════════════
  Widget _buildYourBodyLately(BuildContext context) {
    final rotationOffset = _dayOfYear % _bodyTopics.length;
    final dynamicTopics = [
      ..._bodyTopics.sublist(rotationOffset),
      ..._bodyTopics.sublist(0, rotationOffset),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Puberty Guide'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context).fpnsYourBodyLately,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF221510),
              ),
            ),
            Text(AppLocalizations.of(context).fpnsMilestones,
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
            itemCount: dynamicTopics.length,
            itemBuilder: (context, idx) {
              final topic = dynamicTopics[idx];
              final Color accentColor = topic['accent'] as Color;
              final Color iconBg = topic['iconBg'] as Color;

              return Container(
                width: 82,
                margin: EdgeInsets.only(right: idx == dynamicTopics.length - 1 ? 0 : 12),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => ArticleDetailDialog(
                        title: topic['articleTitle'],
                        summary: topic['articleContent'],
                        question: topic['docsyPrompt'],
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
                          topic['icon'] as IconData,
                          size: 26,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        topic['title'] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF221510),
                          height: 1.2,
                        ),
                        maxLines: 2,
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
  // 04 — FEEL PREPARED (First Period Kit & Emergency Guide)
  // ════════════════════════════════════════════════════════════════
  Widget _buildPrepSection(BuildContext context, {bool isWide = false}) {
    final packedCount = _stage1PeriodKitItems.values.where((p) => p).length;
    final totalCount = _stage1PeriodKitItems.length;

    final kitCard = Container(
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
              Text(AppLocalizations.of(context).fpnsFirstPeriodKit2,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221510),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: blushySoftPink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$packedCount / $totalCount packed',
                  style: GoogleFonts.manrope(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: blushyPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Keep a discreet pouch in your backpack so you always feel safe and prepared.',
            style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF7A6B72), height: 1.35),
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
          InkWell(
            onTap: () => _showFirstPeriodKitModal(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  packedCount == totalCount ? 'Review kit items' : 'Finish packing kit (${totalCount - packedCount} left)',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: blushyPrimary,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_rounded, size: 11, color: blushyPrimary),
              ],
            ),
          ),
        ],
      ),
    );

    // Clean white emergency card
    final emergencyCard = Container(
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
            children: [
              const Icon(Icons.shield_outlined, color: blushyPrimary, size: 16),
              const SizedBox(width: 6),
              Text(AppLocalizations.of(context).fpnsIfItHappensToday,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221510),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Don’t panic. You already know what to do.',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: blushyPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '01 Find a pad  •  02 Tell a trusted adult  •  03 Take a breath',
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: const Color(0xFF7A6B72),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _showEmergency5StepsModal(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context).fpnsSeeFull5StepGuide,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: blushyPrimary,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_rounded, size: 11, color: blushyPrimary),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Feel Prepared'),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: kitCard),
              const SizedBox(width: 12),
              Expanded(child: emergencyCard),
            ],
          )
        else
          Column(
            children: [
              kitCard,
              const SizedBox(height: 10),
              emergencyCard,
            ],
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 05 — CHECK IN (Daily Mood Check-In with Big Colorful Icons)
  // ════════════════════════════════════════════════════════════════
  Widget _buildDailyFeelingCheck(BuildContext context) {
    final moods = [
      {'label': 'Good', 'id': 'Good', 'icon': Icons.sentiment_very_satisfied_rounded, 'color': Color(0xFF0D9488), 'bg': Color(0xFFCCFBF1)},
      {'label': 'Calm', 'id': 'Calm', 'icon': Icons.spa_rounded, 'color': Color(0xFF2563EB), 'bg': Color(0xFFDBEAFE)},
      {'label': 'Nervous', 'id': 'Nervous', 'icon': Icons.sentiment_neutral_rounded, 'color': Color(0xFFD97706), 'bg': Color(0xFFFEF3C7)},
      {'label': 'Tired', 'id': 'Tired', 'icon': Icons.bedtime_rounded, 'color': Color(0xFF7209B7), 'bg': Color(0xFFF3E8FF)},
      {'label': 'Mixed', 'id': 'Overwhelmed', 'icon': Icons.bubble_chart_rounded, 'color': Color(0xFFF72585), 'bg': Color(0xFFFFE5F0)},
    ];

    String feedbackText = '';
    String feedbackPrompt = '';

    if (_selectedMood == 'Nervous') {
      feedbackText = 'Nervous makes complete sense. Body changes can feel unpredictable.';
      feedbackPrompt = 'I am feeling a little nervous about my body changing and getting my first period.';
    } else if (_selectedMood == 'Overwhelmed') {
      feedbackText = 'Having lots of mixed thoughts is so normal right now. You’re doing great.';
      feedbackPrompt = 'I feel a bit overwhelmed about growing up and my body changing.';
    } else if (_selectedMood == 'Tired') {
      feedbackText = 'Growing takes tons of cellular energy. Make sure to get plenty of rest tonight!';
      feedbackPrompt = 'Why do I feel so tired during puberty growth spurts?';
    } else if (_selectedMood == 'Good' || _selectedMood == 'Calm') {
      feedbackText = 'So glad you are feeling centered today! Keep listening to your body.';
      feedbackPrompt = 'What are healthy habits to build during puberty?';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Check In'),
        Text(
          'And how are you today?',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF221510),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: moods.map((m) {
              final isSelected = _selectedMood == m['id'];
              final moodColor = m['color'] as Color;
              final moodBg = m['bg'] as Color;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMood = m['id'] as String;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isSelected ? moodBg : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? moodColor : cardBorderColor,
                            width: isSelected ? 2.0 : 1.2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: moodColor.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          m['icon'] as IconData,
                          size: 24,
                          color: isSelected ? moodColor : const Color(0xFF7A6B72),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m['label'] as String,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF221510) : const Color(0xFF7A6B72),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_selectedMood != null) ...[
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feedbackText,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF221510),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Want to talk to Docsy about it?',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          color: const Color(0xFF7A6B72),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _openDocsyWithPrompt(context, feedbackPrompt),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blushyPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(AppLocalizations.of(context).fpnsTalk,
                    style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700),
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
  // 06 — HUMAN CONNECTION ("Want to talk to someone?")
  // ════════════════════════════════════════════════════════════════
  Widget _buildHumanConnection(BuildContext context) {
    final prompt = _parentPrompts[(_dayOfYear + _promptIndex) % _parentPrompts.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Family & Friends'),
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
                  Text(
                    'Want to talk to someone?',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF221510),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F6F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      prompt['tag']!,
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8C6D38),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                prompt['question']!,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: blushyPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                prompt['subtext']!,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  color: const Color(0xFF7A6B72),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final shareText = '${prompt['question']}\n\n${prompt['subtext']}';
                      await Clipboard.setData(ClipboardData(text: shareText));
                      try {
                        await Share.share(
                          shareText,
                          subject: 'A question from Blushy',
                        );
                      } catch (_) {}
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Question copied to clipboard & sharing opened!',
                              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: blushyPrimary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.favorite_outline, size: 13, color: Colors.white),
                    label: Text(AppLocalizations.of(context).fpnsShareWithMom,
                      style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blushyPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _promptIndex++;
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF7A6B72)),
                    label: Text(AppLocalizations.of(context).fpnsNextQuestion,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7A6B72),
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
  // 07 — KEEP EXPLORING (Rotating Dynamic Pool)
  // ════════════════════════════════════════════════════════════════
  Widget _buildKeepExploring(BuildContext context) {
    final articleOffset = _dayOfYear % _exploreArticlesPool.length;
    final dynamicArticles = [
      ..._exploreArticlesPool.sublist(articleOffset),
      ..._exploreArticlesPool.sublist(0, articleOffset),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Explore'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context).fpnsKeepExploring,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF221510),
              ),
            ),
            Text(AppLocalizations.of(context).fpnsUpdatedDaily,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: const Color(0xFF7A6B72),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dynamicArticles.length,
            itemBuilder: (context, idx) {
              final art = dynamicArticles[idx];

              return Container(
                width: 200,
                margin: EdgeInsets.only(right: idx == dynamicArticles.length - 1 ? 0 : 10),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => ArticleDetailDialog(
                        title: art['title'] as String,
                        summary: art['content'] as String,
                        question: art['docsy'] as String,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: art['tagBg'] as Color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                art['tag'] as String,
                                style: GoogleFonts.manrope(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: art['accent'] as Color,
                                ),
                              ),
                            ),
                            Text(
                              art['readTime'] as String,
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                color: const Color(0xFF7A6B72),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          art['title'] as String,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF221510),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Text(AppLocalizations.of(context).fpnsReadArticle,
                              style: GoogleFonts.manrope(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4A3E39),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 10, color: Color(0xFF4A3E39)),
                          ],
                        ),
                      ],
                    ),
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
                    state: _insightState,
                    // There is no period to have logged at this stage, so the
                    // seeded note is the normal case rather than a gap.
                    hasData: true,
                    emptyMessage: '',
                    onRetry: _fetchDynamicAiInsights,
                  ),
                  _buildYourJourneyCard(context),
                  const SizedBox(height: 22),
                  const LogSymptomsSection(stageKey: 'firstperiodnotstarted'),
                  const SizedBox(height: 18),
                  _buildTodayAiMoment(context),
                  const SizedBox(height: 18),
                  _buildYourBodyLately(context),
                  const SizedBox(height: 18),
                  _buildPrepSection(context, isWide: false),
                  const SizedBox(height: 18),
                  _buildDailyFeelingCheck(context),
                  const SizedBox(height: 18),
                  _buildHumanConnection(context),
                  const SizedBox(height: 18),
                  _buildKeepExploring(context),
                  const SizedBox(height: 24),
                ],
              ),
            );
          } else {
            // Tablet / Desktop Editorial Workspace
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
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 58,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildYourJourneyCard(context),
                                const SizedBox(height: 22),
                                const LogSymptomsSection(stageKey: 'firstperiodnotstarted'),
                                const SizedBox(height: 18),
                                _buildTodayAiMoment(context),
                                const SizedBox(height: 18),
                                _buildYourBodyLately(context),
                                const SizedBox(height: 18),
                                _buildKeepExploring(context),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 42,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPrepSection(context, isWide: false),
                                const SizedBox(height: 18),
                                _buildDailyFeelingCheck(context),
                                const SizedBox(height: 18),
                                _buildHumanConnection(context),
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
