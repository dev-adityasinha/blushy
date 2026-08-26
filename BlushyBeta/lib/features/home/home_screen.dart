import 'dart:io';
import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode
import '../../core/state.dart';
import '../../core/storage.dart';
import '../../core/cycle_calculator.dart';
import '../../theme/colors.dart';
import '../../services/api_auth_service.dart';
import '../../theme/spacing.dart';
import 'widgets/my_health_screen.dart';
import 'widgets/cycle_card.dart';
import '../sia/sia_screen.dart';
import '../m_studio/m_studio_screen.dart';
import '../../core/theme.dart' hide BlushyColors;
import 'models.dart';
import 'mock_data.dart';
import '../../shared/voice_note_bottom_sheet.dart';

String _getTimeBasedGreetingPrefix() {
  // Explicitly calculate Indian Standard Time (IST: UTC + 5:30)
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

enum HomeWidgetType {
  hero,
  aiInsight,
  primaryAction,
  tracking,
  dailyChecklist,
  recommendations,
  quickActions,
  healthTimeline,
}

class BlushyHomeScreen extends StatefulWidget {
  const BlushyHomeScreen({super.key});

  @override
  State<BlushyHomeScreen> createState() => _BlushyHomeScreenState();
}

class _BlushyHomeScreenState extends State<BlushyHomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Interactive local states for daily check-in / First Periods
  final Map<String, bool> _completedDailyTasks = {};
  bool _missionCompleted = false;
  final Set<String> _backpackItems = {};
  final Set<String> _savedArticles = {};
  String? _selectedFeeling;
  String? _selectedSymptom;
  String? _selectedEnergy;
  String? _selectedStress = 'Low';
  String? _selectedWaterIntake = '1 Litre';
  String? _selectedSleepQuality = 'Restful';
  final Set<String> _selectedSymptoms = {};
  double? _loggedWeight;
  String? _siaFeelingFollowUp;
  final Map<String, bool> _expandedQuestions = {};
  String _journalSentence = '';
  bool _isDrawingMode = false;

  // Coach marks state
  bool _showCoachMarks = false;
  int _coachMarkStep = 0;

  // Onboarding answers state
  Map<String, dynamic> _onboardingData = {};
  bool _showFirstPeriodTransition = false;
  bool _isDiscoveryRevealed = false;
  bool _familyMissionCompleted = false;
  bool _prepMissionCompleted = false;
  
  // Before You Go states
  int? _beforeYouGoSelectedIndex;
  final TextEditingController _beforeYouGoController = TextEditingController();
  bool _beforeYouGoSubmitted = false;

  final List<Map<String, dynamic>> _beforeYouGoQuestions = [
    {
      "question": "Have you been thinking about your first period lately?",
      "options": ["A little", "Quite a lot", "Not really"],
      "reply": "Thank you for telling me. I'll remember that."
    },
    {
      "question": "Did anything make you curious about your body today?",
      "options": ["Yes", "Maybe", "Not today"],
      "reply": "I'm really glad you shared that with me."
    },
    {
      "question": "Was there anything that made you smile today?",
      "options": ["Family", "Friends", "Something else"],
      "reply": "That's beautiful. I'll keep this in mind."
    },
    {
      "question": "Have you noticed any changes in your body recently?",
      "options": ["A few changes", "No changes", "Not sure"],
      "reply": "That's completely normal. Your body is growing beautifully."
    },
    {
      "question": "Did anything feel confusing this week?",
      "options": ["Yes, a bit", "No, all clear", "Not sure"],
      "reply": "I'll be here whenever you're ready to talk about it."
    }
  ];

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

  // Today's Check-in state variables
  String _checkInFlow = 'No Period';
  final Set<String> _checkInSymptoms = {};
  String _checkInMood = 'Calm';
  String _checkInEnergy = 'Balanced';
  bool _checkInSaved = false;

  // livingWithMyCycle interactive states
  String _livingDiscoverTopic = 'Cycle Health';
  String _livingCommunityTab = 'Questions';
  final Set<String> _livingSavedArticles = {};
  String? _livingFlow = 'Medium';
  String? _livingPain = 'Mild';
  String? _livingSleep = '6-8h';
  String? _livingStress = 'Moderate';
  String? _livingWater = '2L';
  String? _livingExercise = 'Light';

  // hormonalHealth interactive states
  String _hormonalDiscoverTopic = 'Understanding PCOS';
  String _hormonalCommunityTab = 'PCOS';
  final Set<String> _hormonalSavedArticles = {};
  String? _hormonalBloating = 'None';
  String? _hormonalAcne = 'None';
  String? _hormonalHeadache = 'None';
  String? _hormonalMedication = 'Not Taken';
  String? _hormonalPain = 'None';
  String? _hormonalCramps = 'None';
  String? _hormonalFlow = 'Light';
  String? _hormonalEnergy = 'Medium';
  String? _hormonalSleep = '6-8h';
  String? _hormonalStress = 'Moderate';
  String? _hormonalWater = '2L';
  String? _hormonalExercise = 'Light';

  // tryingToConceive interactive states
  String _ttcDiscoverTopic = 'Understanding Ovulation';
  final Set<String> _ttcSavedArticles = {};
  String? _ttcCervicalMucus = 'Creamy';
  String? _ttcLhTest = 'Low';
  double _ttcBbt = 36.5;
  String? _ttcIntercourse = 'No';
  String? _ttcFlow = 'None';
  String? _ttcEnergy = 'Medium';
  String? _ttcSleep = '6-8h';
  String? _ttcStress = 'Moderate';
  String? _ttcWater = '2L';
  String? _ttcExercise = 'Light';
  String? _ttcVitamins = 'Taken';

  // pregnancy interactive states
  String _pregnancyDiscoverTopic = 'Baby Development';
  final Set<String> _pregnancySavedArticles = {};
  String? _pregnancyBabyMovement = 'Active';
  int _pregnancyKickCount = 10;
  String? _pregnancyContractions = 'None';
  String? _pregnancyEnergy = 'Medium';
  String? _pregnancySleep = '7-8h';
  String? _pregnancyStress = 'Low';
  String? _pregnancyWater = '2.5L';
  String? _pregnancyExercise = 'Light';
  String? _pregnancyVitamins = 'Taken';

  // postpartum interactive states
  String _postpartumDiscoverTopic = 'Physical Recovery';
  String _postpartumCommunityTab = 'Recovery';
  final Set<String> _postpartumSavedArticles = {};
  String? _postpartumFeeding = 'Breastfeeding';
  String? _postpartumBleeding = 'None';
  String? _postpartumIncision = 'Healing';
  String? _postpartumPelvic = 'Completed';
  String? _postpartumEnergy = 'Medium';
  String? _postpartumSleep = '6-7h';
  String? _postpartumStress = 'Moderate';
  String? _postpartumWater = '2.5L';
  String? _postpartumExercise = 'None';

  // perimenopause interactive states
  String _periDiscoverTopic = 'Understanding Perimenopause';
  String _periCommunityTab = 'Perimenopause';
  final Set<String> _periSavedArticles = {};
  String? _periHotFlashes = 'None';
  String? _periNightSweats = 'None';
  String? _periBrainFog = 'None';
  String? _periHormoneTherapy = 'Taken';
  String? _periFlow = 'None';
  String? _periEnergy = 'Medium';
  String? _periSleep = '6-7h';
  String? _periStress = 'Moderate';
  String? _periWater = '2L';
  String? _periExercise = 'Walk';

  late PeriodConfirmationState _periodConfirmationState;

  // menopause interactive states
  String _menoDiscoverTopic = 'Understanding Menopause';
  String _menoCommunityTab = 'Healthy Ageing';
  final Set<String> _menoSavedArticles = {};
  String? _menoHotFlashes = 'None';
  String? _menoNightSweats = 'None';
  String? _menoJointPain = 'None';
  String? _menoHormoneTherapy = 'Taken';
  String? _menoStrength = 'Done';
  String? _menoWalking = 'Done';
  String? _menoFlow = 'None';
  String? _menoEnergy = 'High';
  String? _menoSleep = '7-8h';
  String? _menoStress = 'Low';
  String? _menoWater = '2.5L';

  // everydayWellness interactive states
  String _wellnessDiscoverTopic = 'Nutrition';
  String _wellnessCommunityTab = 'Wellness';
  final Set<String> _wellnessSavedArticles = {};
  String? _wellnessHydration = '2L';
  String? _wellnessExercise = 'Walk';
  String? _wellnessMeditation = 'Done';
  String? _wellnessFlow = 'None';
  String? _wellnessEnergy = 'High';
  String? _wellnessSleep = '7-8h';
  String? _wellnessStress = 'Low';
  String? _wellnessWater = '2.5L';

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
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    _checkFirstLaunchCoach();
    _loadOnboardingData();
  }

  void _saveWeightLog(double val) {
    setState(() {
      _loggedWeight = val;
    });
    try {
      BlushyStorage.write('logged_weight.json', {'weight': val});
      final List history = List.from(BlushyStorage.read('weight_history.json')['history'] as List? ?? []);
      history.add({'weight': val, 'date': DateTime.now().toIso8601String()});
      BlushyStorage.write('weight_history.json', {'history': history});

      final profileData = BlushyStorage.read('onboarding_temp_profile.json') ?? {};
      final Map answers = Map.from(profileData['answers'] as Map? ?? profileData['profile']?['answers'] as Map? ?? {});
      answers['weight_current'] = val.toString();
      answers['weight'] = val.toString();
      profileData['answers'] = answers;
      BlushyStorage.write('onboarding_temp_profile.json', profileData);
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
      final decoded = BlushyStorage.read('onboarding_temp_profile.json');
      final savedWeight = BlushyStorage.read('logged_weight.json')['weight'];
      setState(() {
        _onboardingData = decoded['profile'] ?? {};
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
          _onboardingData['answers'] = {
            ...(_onboardingData['answers'] as Map? ?? {}),
            ...remoteAnswers,
          };
          if (remoteAnswers.containsKey('preferred_name')) {
            _onboardingData['preferredName'] = remoteAnswers['preferred_name'];
          }
          if (remoteAnswers.containsKey('life_stage')) {
            _onboardingData['lifeStage'] = remoteAnswers['life_stage'];
          }
          final remoteW = remoteAnswers['weight_current'] ?? remoteAnswers['weight'];
          if (remoteW != null && remoteW.toString().isNotEmpty) {
            final parsedW = double.tryParse(remoteW.toString());
            if (parsedW != null && parsedW > 0) {
              _loggedWeight = parsedW;
            }
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
          _showCoachMarks = true;
        });
        file.deleteSync();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    final pc = state.personalContext;

    // Detect Active Personas
    final bool isPregnancy = pc.lifeContexts.contains(LifeContext.pregnancy);
    final bool isPostpartum = pc.lifeContexts.contains(LifeContext.postpartum);
    final bool isMenopause = pc.lifeContexts.contains(LifeContext.menopause) || pc.lifeContexts.contains(LifeContext.perimenopause);
    final bool hasPCOS = pc.medicalConditions.contains('PCOS');
    final bool hasEndo = pc.medicalConditions.contains('Endometriosis');
    final bool isFirstPeriods = pc.medicalConditions.contains('First Periods') ||
        (pc.dateOfBirth != null && DateTime.now().difference(pc.dateOfBirth!).inDays < 365 * 17 && !isPregnancy && !isPostpartum);
    final bool isTTC = pc.lifeContexts.contains(LifeContext.other) || pc.userGoals.contains('Explore fertility');
    final bool trackingDisabled = pc.trackingPreference == CycleTrackingPreference.disabled;

    final String stageStr = (_onboardingData['lifeStage'] == null || _onboardingData['lifeStage'].isEmpty)
        ? 'everydayWellness'
        : _onboardingData['lifeStage'];
    final bool isNotStarted = stageStr == 'firstPeriodNotStarted';
    final bool isStarted = stageStr == 'firstPeriodStarted';
    final bool isLiving = stageStr == 'reproductiveYears' || stageStr == 'livingWithMyCycle';
    final bool isHormonal = stageStr == 'hormonalHealth';
    final bool isTTCBranch = stageStr == 'tryingToConceive';
    final bool isPregnancyBranch = stageStr == 'pregnancy';
    final bool isPostpartumBranch = stageStr == 'postpartum';
    final bool isPerimenopauseBranch = stageStr == 'perimenopause';
    final bool isMenopauseBranch = stageStr == 'menopause';
    final bool isEverydayWellnessBranch = stageStr == 'everydayWellness';

    Widget mainScreen;

    if (isNotStarted || isStarted) {
      mainScreen = _buildFirstPeriodsOS(pc, state);
    } else if (isLiving) {
      mainScreen = _buildLivingWithMyCycleHomeOS(pc, state);
    } else if (isHormonal) {
      mainScreen = _buildHormonalHealthHomeOS(pc, state);
    } else if (isTTCBranch) {
      mainScreen = _buildTTCHomeOS(pc, state);
    } else if (isPregnancyBranch) {
      mainScreen = _buildPregnancyHomeOS(pc, state);
    } else if (isPostpartumBranch) {
      mainScreen = _buildPostpartumHomeOS(pc, state);
    } else if (isPerimenopauseBranch) {
      mainScreen = _buildPerimenopauseHomeOS(pc, state);
    } else if (isMenopauseBranch) {
      mainScreen = _buildMenopauseHomeOS(pc, state);
    } else if (isEverydayWellnessBranch) {
      mainScreen = _buildEverydayWellnessHomeOS(pc, state);
    } else if (isFirstPeriods) {
      mainScreen = _buildFirstPeriodsOS(pc, state);
    } else {
      // Determine order of modules based on Active Persona
      final List<HomeWidgetType> widgetOrder = [];

      if (isPregnancy) {
        widgetOrder.addAll([
          HomeWidgetType.hero,
          HomeWidgetType.aiInsight,
          HomeWidgetType.tracking, // pregnancy progress
          HomeWidgetType.quickActions,
          HomeWidgetType.dailyChecklist,
          HomeWidgetType.recommendations,
          HomeWidgetType.healthTimeline,
        ]);
      } else if (isPostpartum) {
        widgetOrder.addAll([
          HomeWidgetType.hero,
          HomeWidgetType.aiInsight,
          HomeWidgetType.tracking, // recovery progress
          HomeWidgetType.dailyChecklist,
          HomeWidgetType.recommendations,
          HomeWidgetType.quickActions,
          HomeWidgetType.healthTimeline,
        ]);
      } else if (hasPCOS || hasEndo) {
        widgetOrder.addAll([
          HomeWidgetType.hero,
          HomeWidgetType.aiInsight,
          HomeWidgetType.tracking,
          HomeWidgetType.quickActions,
          HomeWidgetType.dailyChecklist,
          HomeWidgetType.recommendations,
          HomeWidgetType.healthTimeline,
        ]);
      } else if (isMenopause) {
        widgetOrder.addAll([
          HomeWidgetType.hero,
          HomeWidgetType.aiInsight,
          HomeWidgetType.dailyChecklist,
          HomeWidgetType.recommendations,
          HomeWidgetType.quickActions,
          HomeWidgetType.healthTimeline,
        ]);
      } else if (trackingDisabled) {
        widgetOrder.addAll([
          HomeWidgetType.hero,
          HomeWidgetType.aiInsight,
          HomeWidgetType.dailyChecklist,
          HomeWidgetType.quickActions,
          HomeWidgetType.recommendations,
          HomeWidgetType.healthTimeline,
        ]);
      } else {
        // Default Cycle Tracking Persona
        final String stageStr = _onboardingData['lifeStage'] ?? '';
        final bool isLivingWithCycle = stageStr == 'reproductiveYears';
        if (isLivingWithCycle) {
          widgetOrder.addAll([
            HomeWidgetType.tracking, // cycle journey tracker on top!
            HomeWidgetType.hero,      // AI Daily Brief
            HomeWidgetType.aiInsight, // Sia's Insight
            HomeWidgetType.primaryAction, // Wellness Focus
            HomeWidgetType.quickActions,  // Ask Sia prompts
            HomeWidgetType.recommendations, // Wellness Feed
            HomeWidgetType.healthTimeline,  // Quick Check-in
          ]);
        } else {
          widgetOrder.addAll([
            HomeWidgetType.hero,
            HomeWidgetType.aiInsight,
            HomeWidgetType.tracking, // cycle widget
            HomeWidgetType.primaryAction,
            HomeWidgetType.recommendations,
            HomeWidgetType.quickActions,
            HomeWidgetType.healthTimeline,
          ]);
        }
      }

      mainScreen = Scaffold(
        key: _scaffoldKey,
        backgroundColor: BlushyColors.background,
        endDrawer: DeveloperContextSimulator(
          onLifeStageChanged: (stage) {
            final currentData = BlushyStorage.read('onboarding_temp_profile.json');
            final profile = Map<String, dynamic>.from(currentData['profile'] ?? {});
            profile['lifeStage'] = stage;
            currentData['profile'] = profile;
            BlushyStorage.write('onboarding_temp_profile.json', currentData);
            _loadOnboardingData();
          },
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final padding = width < 1200 ? 20.0 : 48.0;
              
              if (width >= 1200) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: 40),
                  child: ListView(
                    controller: _homeScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildHeader(pc),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 50,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widgetOrder.contains(HomeWidgetType.tracking)) ...[
                                  _buildHomeWidget(HomeWidgetType.tracking, state, pc, isPregnancy, isPostpartum, isMenopause, hasPCOS, hasEndo, isTTC, trackingDisabled),
                                  const SizedBox(height: 24),
                                ],
                                if (widgetOrder.contains(HomeWidgetType.hero)) ...[
                                  _buildHomeWidget(HomeWidgetType.hero, state, pc, isPregnancy, isPostpartum, isMenopause, hasPCOS, hasEndo, isTTC, trackingDisabled),
                                  const SizedBox(height: 24),
                                ],
                                if (widgetOrder.contains(HomeWidgetType.aiInsight)) ...[
                                  _buildHomeWidget(HomeWidgetType.aiInsight, state, pc, isPregnancy, isPostpartum, isMenopause, hasPCOS, hasEndo, isTTC, trackingDisabled),
                                  const SizedBox(height: 24),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 50,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widgetOrder.contains(HomeWidgetType.primaryAction)) ...[
                                  _buildHomeWidget(HomeWidgetType.primaryAction, state, pc, isPregnancy, isPostpartum, isMenopause, hasPCOS, hasEndo, isTTC, trackingDisabled),
                                  const SizedBox(height: 24),
                                ],
                                if (widgetOrder.contains(HomeWidgetType.quickActions)) ...[
                                  _buildHomeWidget(HomeWidgetType.quickActions, state, pc, isPregnancy, isPostpartum, isMenopause, hasPCOS, hasEndo, isTTC, trackingDisabled),
                                  const SizedBox(height: 24),
                                ],
                                if (widgetOrder.contains(HomeWidgetType.recommendations)) ...[
                                  _buildHomeWidget(HomeWidgetType.recommendations, state, pc, isPregnancy, isPostpartum, isMenopause, hasPCOS, hasEndo, isTTC, trackingDisabled),
                                  const SizedBox(height: 24),
                                ],
                                if (widgetOrder.contains(HomeWidgetType.healthTimeline)) ...[
                                  _buildHomeWidget(HomeWidgetType.healthTimeline, state, pc, isPregnancy, isPostpartum, isMenopause, hasPCOS, hasEndo, isTTC, trackingDisabled),
                                  const SizedBox(height: 24),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width < 768 ? 640 : double.infinity),
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
                    itemCount: widgetOrder.length + 1,
                    separatorBuilder: (context, idx) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      return index == 0
                          ? _buildHeader(pc)
                          : _buildHomeWidget(widgetOrder[index - 1], state, pc, isPregnancy, isPostpartum, isMenopause, hasPCOS, hasEndo, isTTC, trackingDisabled);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Stack(
      children: [
        mainScreen,
        if (_showCoachMarks) _buildCoachMarksOverlay(),
      ],
    );
  }

  // --- 0. HEADER WIDGET ---
  Widget _buildHeader(PersonalContext pc) {
    final String stageStr = _onboardingData['lifeStage'] ?? '';
    final bool isLivingWithCycle = stageStr == 'reproductiveYears';
    
    String greetingText = 'Welcome, ${pc.userName ?? "there"}';
    if (isLivingWithCycle) {
      final cData = _getPersonalizedBranchCData(pc);
      greetingText = cData['greeting'] ?? greetingText;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (Navigator.canPop(context)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BlushyColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 18, color: BlushyColors.text),
                      const SizedBox(width: 6),
                      Text(
                        'Back to Home',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TODAY",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: BlushyColors.secondaryText,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    greetingText,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (kDebugMode)
                    IconButton(
                      icon: const Icon(Icons.developer_mode, color: BlushyColors.secondaryText),
                      onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: BlushyColors.text),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyHealthScreen()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- FIRST PERIODS OS REDESIGN ---

  Map<String, dynamic> _getPersonalizedBranchAData(PersonalContext pc) {
    final istNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final hour = istNow.hour;
    String timeOfDay = "day";
    if (hour < 12) {
      timeOfDay = "morning";
    } else if (hour < 17) {
      timeOfDay = "afternoon";
    } else {
      timeOfDay = "evening";
    }

    final String displayName = pc.userName ?? "there";
    final String stageStr = _onboardingData['lifeStage'] ?? 'firstPeriodNotStarted';
    final bool hasStarted = stageStr == 'firstPeriodStarted';

    if (hasStarted) {
      final bool isDataLogged = pc.lastPeriodStart != null && (pc.cycleDay ?? 0) > 0;
      final int cycleDay = pc.cycleDay ?? 0;
      final greeting = "${_getTimeBasedGreetingPrefix()}, $displayName";

      // 1. Dynamic Hero, Sia Note, and Guidance based on cycle phase
      String heroTitle = "Welcome to Your New Journey";
      String heroDesc = "Your first period is a new chapter. Every cycle teaches you something about your body.";
      String heroInsight = "Day $cycleDay of your cycle • Recovery phase • Your body is gently returning to its baseline. Rest well.";
      String siaNote = "This is only your third cycle. Your body is still learning too. You've been checking in consistently this week. We're beginning to understand your rhythm. You can ask me absolutely anything.";
      
      final Map<String, dynamic> discovery = {
        'title': "Building healthy habits",
        'readTime': "3 min read",
        'type': "GUIDE",
        'desc': "Discover how sleep, gentle movement, and proper nourishment build a strong foundation for your cycle health.",
        'imageUrl': "assets/illustrations/pad_guide.png",
        'completedRatio': 0.8,
        'usefulness': "95% helpful today",
        'saved': false,
      };

      final List<String> prompts = [];
      final List<Map<String, String>> communityPosts = [];

      String heroPhaseName = "Recovery Phase";

      if (cycleDay <= 5) {
        // Period Phase
        heroTitle = " Day $cycleDay";
        heroPhaseName = "Period Phase";
        heroDesc = "Your body is letting go of the old lining. Take things gently today. Hydrate well. A warm compress may help cramps.";
        heroInsight = "Period Phase • You may feel more tired than usual. This is completely normal.";
        siaNote = "You've been checking in consistently this week. Since you asked about cramps last week, let's see if your body follows a similar pattern this cycle. Remember, it is okay to feel tired or just want to rest during your period.";
        
        discovery['title'] = "Managing cramps";
        discovery['desc'] = "From warm compresses to gentle hydration, explore simple and comforting ways to soothe menstrual cramps at home.";
        discovery['readTime'] = "4 min read";
        discovery['type'] = "STORY";
        discovery['usefulness'] = "99% helpful today";
        discovery['completedRatio'] = 0.5;

        prompts.addAll([
          "Is this flow normal?",
          "Why is my flow changing?",
          "Why do cramps happen?",
          "Can I play sports?",
        ]);

        communityPosts.addAll([
          {"user": "Anonymous", "text": "My first day at school during my period. I was so nervous but everything went fine!"},
          {"user": "Anonymous", "text": "How I told my mum when it first happened. It was a really sweet moment."},
        ]);
      } else if (cycleDay <= 11) {
        // Follicular (Growing) Phase
        heroTitle = " Day $cycleDay";
        heroPhaseName = "Growing Phase";
        heroDesc = "Your body is rebuilding energy after your period. You may feel more energetic over the next few days.";
        heroInsight = "Follicular Phase • Energy is returning. Great day to try something new.";
        siaNote = "We're beginning to understand your rhythm, $displayName. Your body is still finding its path, and this is only your third cycle. Take this follicular phase to explore what feels good as your natural energy levels return.";
        
        discovery['title'] = "Understanding cycle phases";
        discovery['desc'] = "Learn about the four seasons of your body and how estrogen and progesterone rise and fall to create your rhythm.";
        discovery['readTime'] = "5 min read";
        discovery['type'] = "GUIDE";
        discovery['usefulness'] = "95% helpful today";
        discovery['completedRatio'] = 0.2;

        prompts.addAll([
          "Why is my flow changing?",
          "Why are my periods irregular?",
          "What causes cramps?",
          "Can stress affect my cycle?",
        ]);

        communityPosts.addAll([
          {"user": "Anonymous", "text": "Pads vs tampons - what did you start with?"},
          {"user": "Anonymous", "text": "Does swimming make cramps feel better or worse?"},
        ]);
      } else if (cycleDay <= 16) {
        // Ovulation Phase
        heroTitle = " Day $cycleDay";
        heroPhaseName = "Ovulation Phase";
        heroDesc = "Your body is releasing an egg. Your confidence may feel higher. Stay active, hydrate well, and listen to your inner rhythm.";
        heroInsight = "Ovulation Phase • You may feel more social and expressive.";
        siaNote = "You've been checking in consistently this week. We're beginning to understand your rhythm. This is only your third cycle, so your body is still learning too. Notice how your confidence levels shine during this ovulation phase.";
        
        discovery['title'] = "Understanding discharge";
        discovery['desc'] = "Observe how your body signals ovulation with clear, stretchy cervical fluid, a natural sign of fertility.";
        discovery['readTime'] = "4 min read";
        discovery['type'] = "GUIDE";
        discovery['usefulness'] = "90% helpful today";
        discovery['completedRatio'] = 0.6;

        prompts.addAll([
          "What is ovulation?",
          "Is white discharge normal?",
          "Can I swim?",
          "Why are my friends changing faster?",
        ]);

        communityPosts.addAll([
          {"user": "Anonymous", "text": "What helped my cramps during gym class? Sipping warm water really helped."},
          {"user": "Anonymous", "text": "How do you track your second cycle without feeling anxious?"},
        ]);
      } else {
        // Luteal Phase
        heroTitle = " Day $cycleDay";
        heroPhaseName = "Luteal Phase";
        heroDesc = "Your body is winding down. Be kind to yourself today. Extra sleep and nourishing meals may help.";
        heroInsight = "Luteal Phase • You might notice mood changes or feeling more emotional.";
        siaNote = "Since you asked about cramps last week, let's see if your body follows a similar pattern as we enter the luteal phase. Remember, your body is still finding its path, and taking time to rest is a beautiful part of this cycle.";
        
        discovery['title'] = "Why are early cycles irregular?";
        discovery['desc'] = "Your ovaries are still learning to communicate with your brain. Explore why irregularity is completely normal in your first few years.";
        discovery['readTime'] = "5 min read";
        discovery['type'] = "STORY";
        discovery['usefulness'] = "88% helpful today";
        discovery['completedRatio'] = 0.4;

        prompts.addAll([
          "Why are my periods irregular?",
          "What causes cramps?",
          "Can stress affect my cycle?",
          "What if my next period is late?",
        ]);

        communityPosts.addAll([
          {"user": "Anonymous", "text": "Does swimming make cramps feel better or worse?"},
          {"user": "Anonymous", "text": "What helped my cramps during gym class?"},
        ]);
      }

      final journeySteps = [
        {'title': 'Period', 'done': true},
        {'title': 'Recovery', 'done': true, 'current': cycleDay <= 15},
        {'title': 'Growing', 'done': cycleDay > 15, 'current': cycleDay > 15},
        {'title': 'Next Period', 'done': false},
      ];

      final communityStats = "${100 - cycleDay} girls are sharing stories in the circle today";
      final funFact = "The uterus is about the size of a small pear.";

      final confidenceJourney = [
        {'title': 'My First Period', 'done': true},
        {'title': 'Learning Hygiene', 'done': true},
        {'title': 'Understanding My Cycle', 'done': true},
        {'title': 'Managing Cramps', 'done': cycleDay > 4},
        {'title': 'Tracking My Second Cycle', 'done': cycleDay > 25},
        {'title': 'Building Healthy Habits', 'done': cycleDay > 15},
      ];

      // Transition attributes
      final double transitionScore = cycleDay / 28.0;

      return {
        'greeting': greeting,
        'siaNote': siaNote,
        'journeySteps': journeySteps,
        'discovery': discovery,
        'prompts': prompts,
        'communityStats': communityStats,
        'communityPosts': communityPosts,
        'funFact': funFact,
        'confidenceJourney': confidenceJourney,
        'hasStarted': true,
        'isDataLogged': isDataLogged,
        'heroTitle': heroTitle,
        'heroPhaseName': heroPhaseName,
        'heroDesc': heroDesc,
        'heroInsight': heroInsight,
        'transitionScore': transitionScore,
        'cycleCount': 1,
        'isTransitionReady': false,
      };
    } else {
      // BRANCH A: Not Started
      final greeting = "${_getTimeBasedGreetingPrefix()}, $displayName";
      String siaNote = "I know growing up can feel confusing sometimes. You don't have to figure everything out alone. I'm always here whenever you have questions. Even the small ones.";
      
      final answers = _onboardingData['answers'] ?? {};
      final bool feelsNervous = answers.values.any((val) => val.toString().toLowerCase().contains('nervous') || val.toString().toLowerCase().contains('scared'));
      final bool wantsBodyChanges = answers.values.any((val) => val.toString().toLowerCase().contains('body changes') || val.toString().toLowerCase().contains('puberty'));

      if (feelsNervous) {
        siaNote = "It's completely okay to feel nervous about growing up, $displayName. Your body is doing some beautiful, quiet growing, and we will take it one step at a time together.";
      } else if (wantsBodyChanges) {
        siaNote = "Everyone grows at their own pace, $displayName. Your story doesn't have to look like anyone else's. I'm always here to help you understand all the changes.";
      }

      final journeySteps = [
        {'title': 'Learning About My Body', 'done': true},
        {'title': 'Understanding Puberty', 'done': true},
        {'title': 'Preparing for My First Period', 'done': false},
        {'title': 'My First Period', 'done': false, 'locked': true},
      ];

      final Map<String, dynamic> discovery = {
        'title': "Why do periods happen?",
        'readTime': "4 min read",
        'type': "GUIDE",
        'desc': "Your body is preparing for a new chapter. Every month, the uterus grows a soft lining. If it's not needed, it gently leaves the body as a period. It's a natural, healthy sign of growing up.",
        'imageUrl': "assets/illustrations/period_prep.png",
        'completedRatio': 0.6,
      };

      if (wantsBodyChanges) {
        discovery['title'] = "How your body changes";
        discovery['desc'] = "From height spurts to soft changes, hormones help your body grow in many different ways. Let's explore what's normal during puberty.";
        discovery['readTime'] = "5 min read";
        discovery['type'] = "STORY";
        discovery['completedRatio'] = 0.2;
      }

      final prompts = [
        "When will I get my first period?",
        "Is white discharge normal?",
        "Why are my friends changing faster?",
        "Can I ask anything?",
      ];

      const communityStats = "142 girls are learning together this week";
      final communityPosts = [
        {"user": "Anonymous", "text": "I'm nervous about my first period. What if it happens at school?"},
        {"user": "Anonymous", "text": "Can I swim during my period? My friends say no but I want to match them."},
        {"user": "Anonymous", "text": "Why do cramps happen and how can I soothe them?"},
      ];

      const funFact = "The uterus is about the size of a small pear.";

      return {
        'greeting': greeting,
        'siaNote': siaNote,
        'journeySteps': journeySteps,
        'discovery': discovery,
        'prompts': prompts,
        'communityStats': communityStats,
        'communityPosts': communityPosts,
        'funFact': funFact,
        'hasStarted': false,
      };
    }
  }

  Map<String, dynamic> _getPersonalizedBranchCData(PersonalContext pc) {
    final istNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final int hour = istNow.hour;
    String timeOfDay = "day";
    if (hour < 12) {
      timeOfDay = "morning";
    } else if (hour < 17) {
      timeOfDay = "afternoon";
    } else {
      timeOfDay = "evening";
    }

    final String displayName = pc.userName ?? "there";
    final int cycleDay = pc.cycleDay ?? 0;

    String greeting;
    if (hour < 12) {
      greeting = "Good Morning, $displayName. Hope you slept well.";
    } else if (hour < 17) {
      greeting = "Good Afternoon, $displayName. Hope your day is going well.";
    } else {
      greeting = "Good Evening, $displayName. Hope you had a great day.";
    }

    String heroTitle = "AI Daily Brief";
    String heroSub = "Ovulation Phase";
    String heroText = "";
    String siaInsight = "";
    String dailyTheme = "Wellness Day";

    final Map<String, dynamic> focusTopic = {
      'title': "",
      'readTime': "3 min read",
      'type': "NUTRITION",
      'desc': "",
      'imageUrl': "assets/illustrations/hydration.png",
      'saved': false,
    };

    final List<String> prompts = [];
    final List<Map<String, dynamic>> wellnessFeed = [];
    final List<Map<String, String>> communityPosts = [];

    if (cycleDay <= 5) {
      dailyTheme = "Rest & Recovery Day";
      heroSub = "Period Phase";
      heroText = "You're in your Period Phase. You may notice lower energy today. Prioritise resting and stay well hydrated. A warm compress may help cramps.";
      
      siaInsight = "I remember you usually prefer walking instead of intense workouts during this phase. Let's take it gently today, $displayName. Last month, light walks and warm compresses helped reduce cramps by 30%.";
      
      focusTopic['title'] = "20-Minute Gentle Recovery Walk";
      focusTopic['desc'] = "Approaching your period with lower sleep stats increases fatigue. Today, this low-impact walk is perfect to stay active without stressing your body.";
      focusTopic['type'] = "MOVEMENT";
      focusTopic['readTime'] = "2 min read";

      prompts.addAll([
        "How to manage period cramps?",
        "Best iron-rich foods for recovery?",
        "Can stress delay my period?",
        "Why am I bloated today?",
      ]);

      wellnessFeed.addAll([
        {
          'title': "Why energy changes during the period phase",
          'desc': "Learn how hormonal drops trigger physical fatigue and why listening to your desire for rest is scientifically essential.",
          'readTime': "4 min read",
          'type': "HORMONAL HEALTH",
        },
        {
          'title': "Managing cramps naturally",
          'desc': "Simple, heat-based therapy and nutritional tips that help relax uterine muscles safely during your cycle.",
          'readTime': "5 min read",
          'type': "NUTRITION",
        }
      ]);

      communityPosts.addAll([
        {"user": "Elena", "text": "Stretching during the first two days of period changed everything. Highly recommend gentle yoga!"},
        {"user": "Chloe", "text": "Warm ginger tea is my absolute go-to for light cramps comfort."},
      ]);
    } else if (cycleDay <= 12) {
      dailyTheme = "Growth & Confidence Day";
      heroSub = "Follicular Phase";
      heroText = "You're entering your Follicular Phase. Estrogen is rising, and you slept well yesterday, making this a great time for focused work or starting new habits.";
      
      siaInsight = "I notice you usually feel your most creative and focused during this week, $displayName. Last month, you completed three lessons on Day 8. Let's make the most of this motivation.";
      
      focusTopic['title'] = "Start a Creative Project Outline";
      focusTopic['desc'] = "Your energy and focus are naturally higher over the next few days. Establishing goals today aligns with your peak mental stamina.";
      focusTopic['type'] = "PRODUCTIVITY";
      focusTopic['readTime'] = "3 min read";

      prompts.addAll([
        "Why is my energy returning?",
        "Great workouts for follicular phase?",
        "How to build healthy habits?",
        "Why do hormones affect focus?",
      ]);

      wellnessFeed.addAll([
        {
          'title': "Why physical energy returns with rising estrogen",
          'desc': "Establish strong exercise and dietary habits as your body builds up strength during the follicular phase.",
          'readTime': "5 min read",
          'type': "FITNESS",
        },
        {
          'title': "Learning through the follicular phase",
          'desc': "Discover how brain plasticity responds to rising hormonal levels to enhance memory and focus.",
          'readTime': "4 min read",
          'type': "HORMONAL HEALTH",
        }
      ]);

      communityPosts.addAll([
        {"user": "Sofia", "text": "Follicular phase is my favorite. I feel like I can learn anything and have endless energy!"},
        {"user": "Maya", "text": "Perfect time to start a new gym routine. Motivation feels so natural right now."},
      ]);
    } else if (cycleDay <= 17) {
      dailyTheme = "Peak Energy & Movement Day";
      heroSub = "Ovulation Phase";
      heroText = "You're entering Ovulation. Your energy and confidence may naturally feel higher over the next couple of days. You slept well yesterday, making this a great time for focused work or exercise.";
      
      siaInsight = "I remember you usually enjoy higher-intensity workouts or social tasks around Day 14. Your body is ready for active movement today, $displayName.";
      
      focusTopic['title'] = "25-Minute Strength Workout";
      focusTopic['desc'] = "With peak physical energy and stability, this targeted strength routine helps build consistent muscle tone safely.";
      focusTopic['type'] = "MOVEMENT";
      focusTopic['readTime'] = "4 min read";

      prompts.addAll([
        "What ovulation means?",
        "Why do I feel more social?",
        "Cervical discharge explanation?",
        "Best exercises for peak energy?",
      ]);

      wellnessFeed.addAll([
        {
          'title': "Optimizing strength during your peak ovulation",
          'desc': "Explore how peak estrogen levels support cardiovascular performance and muscle synthesis.",
          'readTime': "5 min read",
          'type': "FITNESS",
        },
        {
          'title': "Understanding cervical discharge changes",
          'desc': "Learn how healthy body awareness correlates with natural phase changes in ovulation.",
          'readTime': "3 min read",
          'type': "HORMONAL HEALTH",
        }
      ]);

      communityPosts.addAll([
        {"user": "Elena", "text": "Exercising during ovulation phase feels so much easier. My strength is peak today!"},
        {"user": "Chloe", "text": "I feel so much more talkative and outgoing this week. Hormones are wild!"},
      ]);
    } else {
      dailyTheme = "Mindfulness & Sleep Reset";
      heroSub = "Luteal Phase";
      heroText = "Period expected in 3 days. You've reported higher stress this week. You slept less than usual and you're approaching your period. Prioritise sleep tonight.";
      
      siaInsight = "I remember you usually experience mild headaches or fatigue tomorrow. Let's prepare today by staying hydrated and reducing evening screen time, $displayName.";
      
      focusTopic['title'] = "15-Minute Mindfulness Breathing";
      focusTopic['desc'] = "You slept less than usual and stress is slightly elevated. Doing this gentle breathing exercise tonight will help lower cortisol and promote sleep recovery.";
      focusTopic['type'] = "MINDFULNESS";
      focusTopic['readTime'] = "3 min read";

      prompts.addAll([
        "Why am I bloated today?",
        "Can stress delay my period?",
        "How do hormones affect sleep?",
        "Why is my skin breaking out?",
      ]);

      wellnessFeed.addAll([
        {
          'title': "How hormonal shifts affect sleep and dreams",
          'desc': "Explore why progesterone rises, how it changes sleep architecture, and tips to get restful sleep.",
          'readTime': "5 min read",
          'type': "SLEEP",
        },
        {
          'title': "Managing luteal bloating and mood shifts",
          'desc': "Simple magnesium-rich foods and evening habits that help stabilize mood and reduce pre-period headaches.",
          'readTime': "4 min read",
          'type': "NUTRITION",
        }
      ]);

      communityPosts.addAll([
        {"user": "Anna", "text": "Switching to chamomile tea and reading instead of scrolling on Day 24 helped my sleep tremendously."},
        {"user": "Sophia", "text": "The pre-period bloating is so real, but warm epsom salt baths bring immediate comfort."},
      ]);
    }

    return {
      'greeting': greeting,
      'heroTitle': heroTitle,
      'heroSub': heroSub,
      'heroText': heroText,
      'siaInsight': siaInsight,
      'focusTopic': focusTopic,
      'prompts': prompts,
      'wellnessFeed': wellnessFeed,
      'communityPosts': communityPosts,
      'cycleDay': cycleDay,
      'dailyTheme': dailyTheme,
    };
  }

  // --- SECTION 1: SIA'S DAILY LETTER (HERO) ---
  Widget _buildSiasDailyLetter(String name) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEBE6), // Soft warm blush color
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF5D6CC), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "SIA'S DAILY NOTE",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.primary,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${_getTimeBasedGreetingPrefix()}, $name",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Growing up happens one step at a time. You don't have to know everything today. We'll learn together.",
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _openAskSiaChat(context, null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    "Ask Sia",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
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
                    // Smoothly scroll or alert focus
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Scroll down to Continue Learning section"),
                        backgroundColor: BlushyColors.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BlushyColors.primary,
                    side: const BorderSide(color: BlushyColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Continue Learning",
                    style: GoogleFonts.poppins(
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
                      color: isCompleted ? BlushyColors.primary.withOpacity(0.4) : BlushyColors.border,
                      width: isCompleted ? 1.5 : 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
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
                      "My mom bought me my first pouch!",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Preparing together makes it feel exciting and not scary at all.",
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
                    },
                  );
                }).toList(),
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
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 5: GROWING JOURNEY ---
  Widget _buildGrowingJourney() {
    final List<Map<String, String>> timelineStages = [
      {"title": "Learning About My Body", "status": "active"},
      {"title": "Understanding Puberty", "status": "pending"},
      {"title": "Preparing For My First Period", "status": "pending"},
      {"title": "My First Period", "status": "pending"},
      {"title": "Living With My Cycle", "status": "pending"},
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
            final isActive = stage['status'] == "active";
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
          }).toList(),
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
    );
  }

  late final ScrollController _homeScrollController = ScrollController();

  Widget _buildNotStartedHomeOS(PersonalContext pc, BlushyOSState state) {
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        if (width < 768) {
          // 1. MOBILE LAYOUT (Exactly as before, single centered column)
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
            ),
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT (Collapse into one wide column)
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
            ),
          );
        } else {
          // 3. DESKTOP LAYOUT (Responsive multi-column editorial grid: 8 / 4 cols)
          return Scaffold(
            backgroundColor: const Color(0xFFFAF6F0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: min(1440.0, width - 64.0),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: ListView(
                    controller: _homeScrollController,
                    physics: const BouncingScrollPhysics(),
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

                          // Right Sidebar Panel (35% width) - Sticky top offset 32px
                          Expanded(
                            flex: 35,
                            child: AnimatedBuilder(
                              animation: _homeScrollController,
                              builder: (context, child) {
                                double offset = 0.0;
                                if (_homeScrollController.hasClients) {
                                  final double scrollOffset = _homeScrollController.offset;
                                  // The top header row takes approx 740px. Sticky triggers past 700px.
                                  if (scrollOffset > 700) {
                                    offset = scrollOffset - 700 + 32;
                                  }
                                }
                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                );
                              },
                              child: _buildGrowingJourney(),
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

  // --- BRANCH: FIRST PERIOD STARTED (firstPeriodStarted) ---
  final ScrollController _startedHomeScrollController = ScrollController();

  // --- SECTION 1: SIA'S LETTER (HERO) ---
  Widget _buildStartedHero(String name) {
    final pc = BlushyOSProvider.of(context).personalContext;
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEBE6), // Soft warm blush color
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF5D6CC), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "SIA'S LESSON NOTE",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.primary,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${_getTimeBasedGreetingPrefix()}, $name",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You've started an exciting new chapter. Every cycle teaches us something new, and I'll be here to help you understand yours.",
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CYCLE DAY 19",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Last Period: July 7",
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Alert scroll down to logging Section 3
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Scroll down to 'How Are You Today' logging"),
                        backgroundColor: BlushyColors.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    "Log Today's Feelings",
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
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cycle #3",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "19 days since last period",
                        style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Period logged successfully!")),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 0,
                    ),
                    child: Text(
                      "Log Period",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
                    // Mock menstruating days (July 1 to July 5, i.e. index 0 to 4)
                    final bool isMenstrual = index < 5;
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
      {"icon": "", "label": "Happy"},
      {"icon": "", "label": "Okay"},
      {"icon": "", "label": "Cramps"},
      {"icon": "", "label": "Tired"},
      {"icon": "", "label": "Irritable"},
    ];

    final List<String> energyOptions = ["High", "Medium", "Low"];
    final List<String> flowOptions = ["Light", "Medium", "Heavy"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "HOW ARE YOU TODAY?",
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
              // Mood Selector
              Text(
                "MOOD",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final isSelected = _selectedFeeling == opt['label'];
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
                            color: isSelected ? BlushyColors.primary.withOpacity(0.1) : const Color(0xFFF9F6F0),
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
                "ENERGY LEVEL",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: energyOptions.map((opt) {
                  final isSelected = _selectedEnergy == opt;
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
                "FLOW LEVEL",
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
                "NOTES & REFLECTIONS",
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
                      color: Colors.black.withOpacity(0.01),
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
                      "Has anyone skipped their second period?",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Yes, my second cycle was 52 days! It's super common for it to skip a month.",
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
                      "PMS Mood Swings tips?",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Writings helps me, and telling my sister I feel touchy today.",
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
                }).toList(),
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
  Widget _buildStartedJourney() {
    final List<Map<String, dynamic>> milestones = [
      {"title": "Logged first period", "done": true},
      {"title": "Completed first month", "done": true},
      {"title": "Learned about cramps", "done": true},
      {"title": "Tracked five cycles", "done": false},
      {"title": "Built confidence", "done": false},
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
            "MY JOURNEY MILESTONES",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 20),
          ...milestones.map((m) {
            final isDone = m['done'] as bool;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(
                    isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isDone ? BlushyColors.success : BlushyColors.disabled.withOpacity(0.5),
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      m['title'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                        color: isDone ? BlushyColors.text : BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFirstPeriodStartedHomeOS(PersonalContext pc, BlushyOSState state) {
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
                    controller: _startedHomeScrollController,
                    physics: const BouncingScrollPhysics(),
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

                          // Right Sidebar Panel (35% width) - Sticky top offset 32px
                          Expanded(
                            flex: 35,
                            child: AnimatedBuilder(
                              animation: _startedHomeScrollController,
                              builder: (context, child) {
                                double offset = 0.0;
                                if (_startedHomeScrollController.hasClients) {
                                  final double scrollOffset = _startedHomeScrollController.offset;
                                  // Under row 1 and row 2 height (approx 1350px)
                                  if (scrollOffset > 1250) {
                                    offset = scrollOffset - 1250 + 32;
                                  }
                                }
                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                );
                              },
                              child: _buildStartedJourney(),
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
    final pc = BlushyOSProvider.of(context).personalContext;
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBE5), // Soft elegant neutral warm background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5DDD5), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "SIA'S DAILY BRIEF",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: BlushyColors.primary,
                    letterSpacing: 2.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${_getTimeBasedGreetingPrefix()}, $name",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You're entering your luteal phase. Be a little kinder to yourself today.",
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CYCLE DAY 19 • LUTEAL PHASE",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Steady energy, focus starting to naturally slow down.",
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // SnackBar / Scroll guidance
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Scroll down to 'Check In' logging"),
                        backgroundColor: BlushyColors.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
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

  // --- SECTION 2: TODAY'S CYCLE (Featuring Ovary loop tracker BlushyCycleCard) ---
  Widget _buildLivingTodayCycle() {
    final bool isConfirmed = _periodConfirmationState.status == 'confirmed';
    final String phaseText = isConfirmed ? "Menstrual Phase Rhythm" : "Luteal Phase Rhythm";
    final String dayText = isConfirmed ? "Cycle Day 1" : "Cycle Day 19";
    final String subtitleText = isConfirmed 
        ? "Period logged today (Day 1)" 
        : "9 days until expected period (August 2)";

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
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
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: BlushyColors.secondaryText, size: 18),
                    onPressed: () {
                      _showLogPeriodBottomSheet(context);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                    tooltip: "Log / Edit Period",
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Opening daily check-in logs...")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BlushyColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  "Log Today's Symptoms",
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 32),

              // Today's expectations list with confidence levels
              Text(
                "CURRENT SYMPTOMS & EXPECTATIONS",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 16),
              _buildExpectationItem("Energy", "Medium-High", "85% confidence"),
              _buildExpectationItem("Mood", "Calmer & Sensitive", "75% confidence"),
              _buildExpectationItem("Sleep", "Need 8 hours", "90% confidence"),
              _buildExpectationItem("Focus", "Moderate", "60% confidence"),
              _buildExpectationItem("Exercise", "Soft yoga / light stretching recommended", "Confidence-based recommendation"),
              _buildExpectationItem("Hydration", "2.2L Target", "Standard daily optimization"),
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
                        firstDate: DateTime.now().subtract(const Duration(days: 45)),
                        lastDate: DateTime.now(),
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
                            _simulateLogPeriod(selectedStart, selectedEnd);
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

  void _simulateLogPeriod(DateTime startDate, DateTime? endDate) {
    setState(() {
      _periodConfirmationState = _periodConfirmationState.copyWith(
        hasLoggedPeriod: true,
        actualStartDate: startDate,
        status: 'confirmed',
      );
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Period logged successfully! Cycle reset to Day 1.")),
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
      {"icon": "", "label": "Happy"},
      {"icon": "", "label": "Okay"},
      {"icon": "", "label": "Cramps"},
      {"icon": "", "label": "Tired"},
      {"icon": "", "label": "Irritable"},
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
              // Mood Selector
              Text(
                "MOOD",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final isSelected = _selectedFeeling == opt['label'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      _showCheckInPopupDialog(
                        context,
                        title: "Mood Recorded! ✨",
                        message: "Logged Mood: ${opt['label']} ${opt['icon']}",
                        emoji: opt['icon'],
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withOpacity(0.1) : const Color(0xFFF9F6F0),
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
              _buildLivingHorizontalSelector("ENERGY LEVEL", energyOptions, _selectedEnergy, (val) {
                setState(() => _selectedEnergy = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Flow Selector
              _buildLivingHorizontalSelector("FLOW LEVEL", flowOptions, _livingFlow, (val) {
                setState(() => _livingFlow = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Pain Selector
              _buildLivingHorizontalSelector("PAIN LEVEL", painOptions, _livingPain, (val) {
                setState(() => _livingPain = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Sleep Selector
              _buildLivingHorizontalSelector("SLEEP TIME", sleepOptions, _livingSleep, (val) {
                setState(() => _livingSleep = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Stress Selector
              _buildLivingHorizontalSelector("STRESS LEVEL", stressOptions, _livingStress, (val) {
                setState(() => _livingStress = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Water Selector
              _buildLivingHorizontalSelector("DAILY WATER", waterOptions, _livingWater, (val) {
                setState(() => _livingWater = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Exercise Selector
              _buildLivingHorizontalSelector("EXERCISE ACTIVITY", exerciseOptions, _livingExercise, (val) {
                setState(() => _livingExercise = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Notes & Reflections
              Text(
                "NOTES & REFLECTIONS",
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

  void _showCheckInPopupDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? emoji,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (ctx.mounted && Navigator.canPop(ctx)) {
            Navigator.of(ctx).pop();
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: BlushyColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      emoji ?? '✨',
                      style: const TextStyle(
                        fontSize: 30,
                        fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: BlushyColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: BlushyColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getCategoryEmoji(String label) {
    final l = label.toUpperCase();
    if (l.contains("ENERGY")) return "⚡";
    if (l.contains("SLEEP")) return "😴";
    if (l.contains("WATER") || l.contains("HYDRATION")) return "💧";
    if (l.contains("STRESS")) return "🧘";
    if (l.contains("PAIN")) return "🩹";
    if (l.contains("FLOW")) return "🩸";
    if (l.contains("EXERCISE") || l.contains("WALKING")) return "🏃‍♀️";
    if (l.contains("VITAMIN")) return "💊";
    return "✨";
  }

  Widget _buildLivingHorizontalSelector(String label, List<String> options, String? selectedValue, ValueChanged<String> onSelected) {
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
            final isSelected = selectedValue == opt;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () {
                    onSelected(opt);
                    _showCheckInPopupDialog(
                      context,
                      title: "Check-In Recorded! ✨",
                      message: "Logged $label: $opt",
                      emoji: _getCategoryEmoji(label),
                    );
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
    final List<Map<String, String>> observations = [
      {
        "insight": "You've logged headaches before your last three periods.",
        "explanation": "Headaches or migraines right before menstruation are often triggered by the sudden drop in estrogen. Staying hydrated and lowering sodium intake can help manage the vascular shifts."
      },
      {
        "insight": "You usually sleep less during your luteal phase.",
        "explanation": "Progesterone levels peak and then fall in the luteal phase, which can disrupt sleep patterns and lower REM cycle efficiency. Try keeping your room cool and having chamomile tea."
      },
      {
        "insight": "You feel happiest around ovulation.",
        "explanation": "A peak in estrogen and testosterone around day 14 boosts dopamine and serotonin levels, commonly driving higher feelings of confidence, social energy, and optimism."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "SIA INSIGHTS",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...observations.map((item) {
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
                          item['insight']!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _showArticleDialog(context, "Sia Observation Analysis", item['explanation']!);
                        },
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
        }).toList(),
      ],
    );
  }

  // --- SECTION 5: DISCOVER (Personalized educational feed) ---
  Widget _buildLivingDiscover() {
    final List<String> topics = [
      "Cycle Health", "Nutrition", "Movement", "Sleep", "Mental Health", "Relationships", "Sexual Wellness", "Productivity"
    ];

    final Map<String, List<Map<String, String>>> topicArticles = {
      "Cycle Health": [
        {"title": "Decoding Estrogen Drop", "desc": "How sudden shifts drive premenstrual fatigue and headaches."},
        {"title": "Understanding Cycle Lengths", "desc": "Why normal cycles fluctuate between 21 and 35 days."}
      ],
      "Nutrition": [
        {"title": "Curbing Luteal Cravings", "desc": "Magnesium-rich foods to natural calm sugar spikes."},
        {"title": "Hydration During Bleeding", "desc": "How water intake balances fluid retention during menstruation."}
      ],
      "Movement": [
        {"title": "Yoga for Menstruation", "desc": "Gentle poses to relax the pelvic floor and lower back muscles."},
        {"title": "High Energy Follicular Workouts", "desc": "Capitalizing on high estrogen for strength training."}
      ],
      "Sleep": [
        {"title": "Progesterone and Insomnia", "desc": "Why falling asleep is harder in the week leading up to your period."},
        {"title": "Optimizing Luteal Sleep", "desc": "Cool bedroom strategies to counter hormone-driven heat rises."}
      ],
      "Mental Health": [
        {"title": "Managing PMS Mood Swings", "desc": "Journaling prompts to separate emotional waves from reality."},
        {"title": "The Post-Ovulation Calm", "desc": "How hormone spikes balance mood levels during the follicular peak."}
      ],
      "Relationships": [
        {"title": "Sharing Your Cycle Status", "desc": "Easy communication guides to help partners support you during PMS."},
        {"title": "Cycle Syncing Conversations", "desc": "Talking about emotional boundaries with family."}
      ],
      "Sexual Wellness": [
        {"title": "Libido Fluctuations Explained", "desc": "How hormonal peaks guide intimacy drives during ovulation."},
        {"title": "Nurturing Body Confidence", "desc": "Reconnecting with physical comfort during menstrual bloat."}
      ],
      "Productivity": [
        {"title": "The Follicular Focus Peak", "desc": "Planning complex tasks during your high-concentration days."},
        {"title": "Luteal Phase Reflection Cycles", "desc": "Slowing down output to prioritize administration and planning."}
      ]
    };

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
    final articles = [
      {"user": "Lara94", "content": "How do you all handle the luteal drop in energy at work?"},
      {"user": "Sia_Help", "content": "Our AI tips: schedule heavy admin tasks on day 20-25 and limit meetings."}
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
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            children: articles.map((post) {
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
                          "Luteal Phase feed",
                          style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post['content']!,
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

  // --- SECTION 7: MY PATTERNS (Personalized observations instead of graphs) ---
  Widget _buildLivingPatterns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "CYCLE PATTERNS & INSIGHTS",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...dummyInsights.map((insight) {
          IconData insightIcon;
          final titleLower = insight.title.toLowerCase();
          if (titleLower.contains('mood')) {
            insightIcon = Icons.bubble_chart_rounded;
          } else if (titleLower.contains('energy')) {
            insightIcon = Icons.bolt_rounded;
          } else if (titleLower.contains('sleep')) {
            insightIcon = Icons.bedtime_rounded;
          } else if (titleLower.contains('symptom')) {
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
                      Row(
                        children: [
                          Icon(insightIcon, size: 18, color: BlushyColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            insight.title.toUpperCase(),
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.primary, letterSpacing: 1.0),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: BlushyColors.taupe,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${insight.confidenceLevel} Confidence",
                          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: BlushyColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    insight.observation,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Evidence: ${insight.evidence}",
                    style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      insight.timestamp,
                      style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText.withOpacity(0.8), fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // --- SECTION 8: JOURNEY (Monthly reflections) ---
  Widget _buildLivingJourney() {
    final List<String> milestones = [
      "Your cycle became more regular.",
      "You completed 18 check-ins.",
      "You learned three new things.",
      "You logged fewer cramps.",
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
            "MONTHLY REFLECTION & JOURNEY",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 20),
          ...milestones.map((m) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: BlushyColors.success, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      m,
                      style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 36, color: Color(0xFFF5F0EB)),
          Text(
            "SIA'S REFLECTION",
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            "\"This month, your body established a very steady rhythm. By logging consistently, you're building a beautiful, intuitive relationship with your natural flow.\"",
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
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
          );
        } else if (width <= 1200) {
          // 2. TABLET LAYOUT
          return Center(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
          );
        } else {
          // 3. DESKTOP LAYOUT (8 / 4 Responsive Editorial Grid)
          return Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: min(1440.0, width - 64.0),
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: ListView(
                controller: _livingHomeScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
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

                      // Right Sidebar Panel (35% width) - Sticky top offset 32px
                      Expanded(
                        flex: 35,
                        child: AnimatedBuilder(
                          animation: _livingHomeScrollController,
                          builder: (context, child) {
                            double offset = 0.0;
                            if (_livingHomeScrollController.hasClients) {
                              final double scrollOffset = _livingHomeScrollController.offset;
                              // Under row 1 and row 2 height (approx 1350px)
                              if (scrollOffset > 1250) {
                                offset = scrollOffset - 1250 + 32;
                              }
                            }
                            return Transform.translate(
                              offset: Offset(0, offset),
                              child: child,
                            );
                          },
                          child: Column(
                            children: [
                              _buildLivingPatterns(),
                              const SizedBox(height: 48),
                              _buildLivingJourney(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
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
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF2EE), // Extremely soft pinkish warm cream background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3E4DD), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "SIA'S DAILY BRIEF",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: BlushyColors.primary,
                    letterSpacing: 2.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${_getTimeBasedGreetingPrefix()}, $name",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Your body has been through a lot recently. Today let's focus on what you can control.",
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CYCLE STATUS: WAITING FOR NEXT PERIOD",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Cycle Day 53 • Steady tracking is your best indicator.",
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
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
                    "Today's Check-in",
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

  // --- SECTION 2: MY CYCLE HEALTH (Irregular tracking metrics & Ovary shape) ---
  Widget _buildHormonalCycleHealth() {
    final List<Map<String, String>> history = [
      {"cycle": "Cycle #5", "len": "38 Days"},
      {"cycle": "Cycle #4", "len": "61 Days"},
      {"cycle": "Cycle #3", "len": "42 Days"},
      {"cycle": "Cycle #2", "len": "71 Days"},
      {"cycle": "Cycle #1", "len": "29 Days"},
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cycle Day 53",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Last Period: June 4",
                        style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Period logged successfully!")),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 0,
                    ),
                    child: Text(
                      "Log Period",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF6F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: BlushyColors.border, width: 0.8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item['len']!,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                          Text(
                            item['cycle']!,
                            style: GoogleFonts.poppins(fontSize: 8, color: BlushyColors.secondaryText),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Cycle Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricLabel("Average", "48.2 Days"),
                  _buildMetricLabel("Shortest", "29 Days"),
                  _buildMetricLabel("Longest", "71 Days"),
                  _buildMetricLabel("Regularity", "Moderate"),
                ],
              ),
              const SizedBox(height: 24),
              
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
                            "Your recent cycles have ranged between 38 and 71 days. This variation helps Sia understand your unique hormonal rhythm.",
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
      {"icon": "", "label": "Happy"},
      {"icon": "", "label": "Okay"},
      {"icon": "", "label": "Cramps"},
      {"icon": "", "label": "Tired"},
      {"icon": "", "label": "Irritable"},
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
              // Mood Selector
              Text(
                "MOOD",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final isSelected = _selectedFeeling == opt['label'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      _showCheckInPopupDialog(
                        context,
                        title: "Mood Recorded! ✨",
                        message: "Logged Mood: ${opt['label']} ${opt['icon']}",
                        emoji: opt['icon'],
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withOpacity(0.1) : const Color(0xFFF9F6F0),
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
              _buildLivingHorizontalSelector("PAIN LEVEL", painOptions, _hormonalPain, (val) {
                setState(() => _hormonalPain = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Cramps Selector
              _buildLivingHorizontalSelector("CRAMPS", crampsOptions, _hormonalCramps, (val) {
                setState(() => _hormonalCramps = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Flow Selector
              _buildLivingHorizontalSelector("FLOW LEVEL", flowOptions, _hormonalFlow, (val) {
                setState(() => _hormonalFlow = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Bloating Selector
              _buildLivingHorizontalSelector("BLOATING", bloatingOptions, _hormonalBloating, (val) {
                setState(() => _hormonalBloating = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Acne Selector
              _buildLivingHorizontalSelector("ACNE STATUS", acneOptions, _hormonalAcne, (val) {
                setState(() => _hormonalAcne = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Headache Selector
              _buildLivingHorizontalSelector("HEADACHE", headacheOptions, _hormonalHeadache, (val) {
                setState(() => _hormonalHeadache = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Medication Selector
              _buildLivingHorizontalSelector("MEDICATION TAKEN", medicationOptions, _hormonalMedication, (val) {
                setState(() => _hormonalMedication = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Exercise Selector
              _buildLivingHorizontalSelector("EXERCISE ACTIVITY", exerciseOptions, _hormonalExercise, (val) {
                setState(() => _hormonalExercise = val);
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
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Log Weight"),
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
                label: const Text("Log Weight"),
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
                "NOTES & REFLECTIONS",
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
  Widget _buildHormonalSiaInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "SIA INSIGHTS",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...dummyConditionInsights.map((item) {
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.description,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: BlushyColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "• ${item.contextLabel}",
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: BlushyColors.secondaryText,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _openAskSiaChat(context, "Tell me about: ${item.description}"),
                        child: Text("Ask Sia", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          _showArticleDialog(context, item.title, item.explanation);
                        },
                        child: Text(
                          "Learn More",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildHormonalAppointmentSummary() {
    final summary = dummyAppointmentSummary;

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
                      summary.title,
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
                summary.summary,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: BlushyColors.secondaryText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                "RECENT CHANGES",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.primary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: summary.recentChanges.map((change) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: BlushyColors.primary)),
                        Expanded(
                          child: Text(
                            change,
                            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              Text(
                "QUESTIONS TO DISCUSS",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.primary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: summary.discussionPoints.map((point) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: BlushyColors.primary)),
                        Expanded(
                          child: Text(
                            point,
                            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              const Divider(color: BlushyColors.border, height: 1),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      summary.notes,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: BlushyColors.secondaryText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  Text(
                    "Generated: ${summary.generatedAt.year}-${summary.generatedAt.month.toString().padLeft(2, '0')}-${summary.generatedAt.day.toString().padLeft(2, '0')}",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Exporting clinical summary PDF for your doctor...")),
                    );
                  },
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(
                    "Export Clinical Summary",
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 5: UNDERSTANDING MY PATTERNS (Pattern Cards) ---
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
        }).toList(),
      ],
    );
  }

  // --- SECTION 6: YOUR CARE PLAN (Daily Recommendations) ---
  Widget _buildHormonalCarePlan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "YOUR CARE PLAN",
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
            children: dummyCareRecommendations.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, size: 20, color: BlushyColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.priority == 'High' ? BlushyColors.primary.withOpacity(0.1) : const Color(0x0F2E2623),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "${item.priority} Priority",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: item.priority == 'High' ? BlushyColors.primary : BlushyColors.secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.text, height: 1.45),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Why: ${item.reason}",
                            style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 7: LEARN ---
  Widget _buildHormonalLearn() {
    final List<String> topics = [
      "Understanding PCOS", "Understanding Endometriosis", "Understanding PMDD", "Understanding Irregular Cycles", "Hormones Explained"
    ];

    final Map<String, List<Map<String, String>>> learnFeeds = {
      "Understanding PCOS": [
        {"title": "PCOS Insulin Resistance Link", "desc": "How diet tweaks and movement improve insulin signaling and restore menstrual cycle timing."},
        {"title": "Androgen Regulation Basics", "desc": "Slowing hirsutism and acne spikes through natural cortisol regulation."}
      ],
      "Understanding Endometriosis": [
        {"title": "Managing Pelvic Inflammation", "desc": "Anti-inflammatory nutrition guides to soothe pelvic cramps and uterine muscle stiffness."},
        {"title": "Adenomyosis vs Endometriosis", "desc": "Understanding tissue lining growth differences and symptom triggers."}
      ],
      "Understanding PMDD": [
        {"title": "PMDD Neurotransmitter Shifts", "desc": "Why progesterone drop spikes serotonin dips, driving heavy premenstrual dysphoria."},
        {"title": "PMS vs PMDD Indicators", "desc": "How tracking helps verify symptoms to present clearly at doctor visits."}
      ],
      "Understanding Irregular Cycles": [
        {"title": "Thyroid and Menstrual Timings", "desc": "How T3/T4 thyroid hormone variances disrupt follicular growth and delay periods."},
        {"title": "Skipping Ovulation Weeks", "desc": "Why anovulatory cycles happen and what they mean for long-term health."}
      ],
      "Hormones Explained": [
        {"title": "The Estrogen/Progesterone Balance", "desc": "A beginner's guide to how your regulatory hormones coordinate your rhythm."},
        {"title": "Cortisol: The Cycle Hijacker", "desc": "How daily chronic stress delays ovulation and extends cycle lengths."}
      ]
    };

    final articles = learnFeeds[_hormonalDiscoverTopic] ?? [];

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
    final List<String> tabs = ["PCOS", "Endometriosis", "PMDD", "Hormonal Health"];
    final filteredPosts = dummyCommunityPosts.where((post) => post.category == _hormonalCommunityTab).toList();

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
          child: Row(
            children: tabs.map((tab) {
              final isSelected = _hormonalCommunityTab == tab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _hormonalCommunityTab = tab),
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
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            children: filteredPosts.isEmpty 
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        "No discussions in this channel yet.",
                        style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                      ),
                    ),
                  )
                ]
              : filteredPosts.map((post) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              post.user,
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                            ),
                            const SizedBox(width: 6),
                            Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: BlushyColors.disabled)),
                            const SizedBox(width: 6),
                            Text(
                              "Diagnosis Forum feed",
                              style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          post.content,
                          style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (post.medicalReview)
                              Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8ECE9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Pending Review",
                                    style: GoogleFonts.poppins(fontSize: 8.5, color: const Color(0xFF6E8C78), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            if (post.misinformationWarning)
                              Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBEBE6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Under Verification",
                                    style: GoogleFonts.poppins(fontSize: 8.5, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            if (post.professionalGuidance)
                              Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6EDFB),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Clinician Guided",
                                    style: GoogleFonts.poppins(fontSize: 8.5, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
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

  // --- SECTION 9: HEALTH TIMELINE (Chronological Health Journey) ---
  Widget _buildHormonalTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PAST JOURNEY TIMELINE",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Chronological record of completed cycles and monthly summaries",
                style: GoogleFonts.poppins(
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            children: dummyTimelineSummaries.map((item) {
              final isLast = item == dummyTimelineSummaries.last;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 30,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.month,
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.cycleLength,
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: BlushyColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star_rounded, size: 14, color: BlushyColors.warning),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.keyChange,
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "AI Summary: \"${item.aiSummary}\"",
                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, fontStyle: FontStyle.italic, height: 1.4),
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
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildHormonalJourney() {
    final List<String> milestones = [
      "You completed 24 check-ins this month.",
      "You discovered three new symptom patterns.",
      "Your cycles have become more consistent than last month.",
      "You've become more aware of what affects your energy.",
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
            "MONTHLY REFLECTION",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 20),
          ...milestones.map((m) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: BlushyColors.success, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      m,
                      style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 36, color: Color(0xFFF5F0EB)),
          Text(
            "SIA'S REFLECTION SUMMARY",
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            "\"This month, you took incredible control over your care plan. By tracking consistent daily check-ins, we verified significant glucose-androgen improvements together.\"",
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
                      _buildHormonalAppointmentSummary(),
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
                      const SizedBox(height: 48),
                      _buildHormonalAppointmentSummary(),
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
                                const SizedBox(height: 48),
                                _buildHormonalAppointmentSummary(),
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

                          // Right Sidebar Panel (35% width) - Sticky top offset 32px
                          Expanded(
                            flex: 35,
                            child: AnimatedBuilder(
                              animation: _hormonalHomeScrollController,
                              builder: (context, child) {
                                double offset = 0.0;
                                if (_hormonalHomeScrollController.hasClients) {
                                  final double scrollOffset = _hormonalHomeScrollController.offset;
                                  if (scrollOffset > 1250) {
                                    offset = scrollOffset - 1250 + 32;
                                  }
                                }
                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                );
                              },
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
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF2EE), // Warm editorial background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3E4DD), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "SIA'S FERTILITY BRIEF",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.primary,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${_getTimeBasedGreetingPrefix()}, $name",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You're in your two-week wait. Be kind to yourself while we wait.",
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "FERTILITY STAGE: TWO WEEK WAIT",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Cycle Day 19 • Expected Test Day: August 9",
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cycle Day 19",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Expected Ovulation: July 23 (Completed)",
                        style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                  Row(
                    children: [
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
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Period logged successfully!")),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BlushyColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          elevation: 0,
                        ),
                        child: Text(
                          "Log Period",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
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
                  _buildMetricLabel("Fertile Window", "July 18 - 24"),
                  _buildMetricLabel("Expected Period", "August 6"),
                  _buildMetricLabel("Rec. Test Day", "August 9"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 3: TODAY'S CHECK-IN ---
  Widget _buildTtcCheckIn() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "", "label": "Hopeful"},
      {"icon": "", "label": "Calm"},
      {"icon": "", "label": "Anxious"},
      {"icon": "", "label": "Tired"},
      {"icon": "", "label": "Sensitive"},
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
              // Mood Selector
              Text(
                "MOOD",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final isSelected = _selectedFeeling == opt['label'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      _showCheckInPopupDialog(
                        context,
                        title: "Mood Recorded! ✨",
                        message: "Logged Mood: ${opt['label']} ${opt['icon']}",
                        emoji: opt['icon'],
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withOpacity(0.1) : const Color(0xFFF9F6F0),
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

              // Cervical Mucus
              _buildLivingHorizontalSelector("CERVICAL MUCUS", mucusOptions, _ttcCervicalMucus, (val) {
                setState(() => _ttcCervicalMucus = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // LH Test Result
              _buildLivingHorizontalSelector("OVULATION TEST (LH)", lhOptions, _ttcLhTest, (val) {
                setState(() => _ttcLhTest = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Intercourse
              _buildLivingHorizontalSelector("INTERCOURSE LOG", intercourseOptions, _ttcIntercourse, (val) {
                setState(() => _ttcIntercourse = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // BBT Temperature Slider
              Text(
                "BASAL BODY TEMPERATURE (BBT)",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${_ttcBbt.toStringAsFixed(1)}C",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                  Expanded(
                    child: Slider(
                      value: _ttcBbt,
                      min: 35.5,
                      max: 37.8,
                      activeColor: BlushyColors.primary,
                      inactiveColor: const Color(0xFFF5F0EB),
                      onChanged: (val) {
                        setState(() {
                          _ttcBbt = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Prenatal Vitamins
              _buildLivingHorizontalSelector("PRENATAL VITAMINS", vitaminOptions, _ttcVitamins, (val) {
                setState(() => _ttcVitamins = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Exercise Activity
              _buildLivingHorizontalSelector("EXERCISE ACTIVITY", exerciseOptions, _ttcExercise, (val) {
                setState(() => _ttcExercise = val);
              }),
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
  Widget _buildTtcInsights() {
    final List<Map<String, String>> insights = [
      {
        "insight": "You usually ovulate later than average.",
        "desc": "Based on your last 3 cycles, your LH peak consistently falls on Day 17. Identifying this timing helps optimize planning windows."
      },
      {
        "insight": "Your sleep has improved this cycle.",
        "desc": "You've logged 8 hours of sleep consistently, keeping morning stress hormones lower."
      },
      {
        "insight": "Your LH surge typically lasts one day.",
        "desc": "This short surge indicates that timing intercourse within 24 hours of a positive test is key."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "FERTILITY INSIGHTS",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...insights.map((item) {
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
                          item['insight']!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _openAskSiaChat(context, "Tell me about: ${item['insight']}"),
                        child: Text("Ask Sia", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          _showArticleDialog(context, "Fertility Analysis", item['desc']!);
                        },
                        child: Text(
                          "Learn More",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // --- SECTION 5: TODAY'S PLAN ---
  Widget _buildTtcPlan() {
    final List<Map<String, dynamic>> recommendations = [
      {"icon": Icons.water_drop_outlined, "title": "Hydration Focus", "desc": "Maintain clear fluid intake target (2.2L today) to optimize mucus thickness."},
      {"icon": Icons.restaurant, "title": "Antioxidant Rich Nutrition", "desc": "Add berries, nuts, and leafy greens to support mitochondrial cellular health."},
      {"icon": Icons.directions_run, "title": "Gentle Exercise", "desc": "30 minutes of yoga or light movement to stimulate pelvic circulation."},
      {"icon": Icons.medication_outlined, "title": "Prenatal Vitamins", "desc": "Take your folic acid and prenatal multivitamin with your morning meal."},
      {"icon": Icons.nightlight_round, "title": "Rest Priority", "desc": "Unwind 1 hour before bed to facilitate deep, recuperative sleep."},
      {"icon": Icons.favorite_border, "title": "Partner Touchpoint", "desc": "Share your fertility window timeline updates explicitly with your partner."},
      {"icon": Icons.calendar_month_outlined, "title": "Ovulation Testing", "desc": "Take your LH strip test in the afternoon when luteinizing concentration is peak."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S PLAN",
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
            children: recommendations.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item['icon'] as IconData, size: 20, color: BlushyColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['desc'] as String,
                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 6: LEARN ---
  Widget _buildTtcLearn() {
    final List<String> topics = [
      "Understanding Ovulation", "Fertile Window", "Egg Health", "Stress & Fertility", "Understanding BBT"
    ];

    final Map<String, List<Map<String, String>>> learnFeeds = {
      "Understanding Ovulation": [
        {"title": "The LH Surge Explained", "desc": "How luteinizing hormone signals follicles to release an egg and how to identify surges correctly."},
        {"title": "Anovulatory Cycle Signals", "desc": "Identifying cycles without ovulation using temperature and cervical indicators."}
      ],
      "Fertile Window": [
        {"title": "Timing Intercourse for Conception", "desc": "Optimizing timing within the 5 days leading up to ovulation and the day of."},
        {"title": "Sperm Longevity in Uterus", "desc": "Why eggwhite cervical mucus is vital for keeping sperm active for up to 5 days."}
      ],
      "Egg Health": [
        {"title": "Mitochondria and Egg Quality", "desc": "Nutritional and lifestyle factors that protect cellular division energy levels."},
        {"title": "CoQ10 and Oocyte Vitality", "desc": "Coenzyme Q10 clinical summaries on oocyte development and cellular health."}
      ],
      "Stress & Fertility": [
        {"title": "Cortisol vs Progesterone", "desc": "How high adrenal stress hormones can delay ovulation or shorten the luteal phase."},
        {"title": "Calming the Nervous System", "desc": "Simple daily mindfulness triggers to keep autonomic nervous signals balanced."}
      ],
      "Understanding BBT": [
        {"title": "The Progesterone Thermal Shift", "desc": "Why core body temperature jumps 0.3C - 0.5C immediately after ovulation occurs."},
        {"title": "Identifying Implantation Dips", "desc": "Understanding mid-luteal temperature fluctuations without countdown anxiety."}
      ]
    };

    final articles = learnFeeds[_ttcDiscoverTopic] ?? [];

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
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 8: MY PATTERNS ---
  Widget _buildTtcPatterns() {
    final List<Map<String, String>> patterns = [
      {
        "title": "Ovulation Pattern",
        "desc": "\"You usually ovulate between Days 16 and 18.\"",
        "detail": "Consistent tracking helps identify that your LH surge peaks around Day 17, giving you a precise timing window."
      },
      {
        "title": "Sleep Pattern",
        "desc": "\"You sleep more consistently before ovulation.\"",
        "detail": "Pre-ovulatory estrogen rises naturally facilitate deeper rest cycles."
      },
      {
        "title": "Lifestyle Pattern",
        "desc": "\"You've been consistent with vitamins for 28 days.\"",
        "detail": "Steady prenatal nutrient supplies protect follicular development."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "MY PATTERNS",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...patterns.map((card) {
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
                          _showArticleDialog(context, card['title']!, "Clinical pattern maps: ${card['detail']}");
                        },
                        child: Text("Learn More", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // --- SECTION 9: JOURNEY TIMELINE ---
  Widget _buildTtcJourneyTimeline() {
    final List<Map<String, String>> events = [
      {"date": "June 10", "title": "Started TTC Journey", "detail": "Configured primary wellness goals."},
      {"date": "June 25", "title": "Logged First Ovulation", "detail": "LH peak and cervical indicators recorded."},
      {"date": "July 08", "title": "Completed First Cycle", "detail": "Cycle length verified at 28 days."},
      {"date": "July 12", "title": "Started Prenatal Vitamins", "detail": "Daily capsule streak initiated."},
      {"date": "July 19", "title": "Partner Joined Mode", "detail": "Synced shared task schedules."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "JOURNEY TIMELINE",
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
            children: events.map((item) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 25,
                    child: Text(
                      item['date']!,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                  ),
                  Expanded(
                    flex: 75,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']!,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['detail']!,
                          style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                        ),
                        const Divider(height: 24, color: Color(0xFFF5F0EB)),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildTtcMonthlyReflection() {
    final List<String> items = [
      "You stayed consistent with your health goals this month.",
      "You learned more about your ovulation pattern.",
      "You completed daily check-ins throughout your fertile window.",
      "You've built a stronger understanding of your body's rhythm.",
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
            "MONTHLY REFLECTION",
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
                children: [
                  const Icon(Icons.favorite, color: BlushyColors.primary, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      m,
                      style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 36, color: Color(0xFFF5F0EB)),
          Text(
            "SIA'S MONTHLY LETTER SUMMARY",
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            "\"This cycle, you built a deeper connection to your rhythm. Your steady logging helped identify ovulation patterns and kept stress levels balanced. We are walking this hopeful path together.\"",
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

                          // Right Sidebar Panel (35% width) - Sticky top offset 32px
                          Expanded(
                            flex: 35,
                            child: AnimatedBuilder(
                              animation: _ttcHomeScrollController,
                              builder: (context, child) {
                                double offset = 0.0;
                                if (_ttcHomeScrollController.hasClients) {
                                  final double scrollOffset = _ttcHomeScrollController.offset;
                                  if (scrollOffset > 1250) {
                                    offset = scrollOffset - 1250 + 32;
                                  }
                                }
                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                );
                              },
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
  Widget _buildPregnancyHero(String name) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF2EE), // Warm background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3E4DD), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "TODAY WITH BABY",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.primary,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${_getTimeBasedGreetingPrefix()}, $name",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Your baby is growing rapidly this week. Don't forget to take moments to rest—you deserve them.",
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PREGNANCY STATUS: WEEK 24",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Second Trimester • 112 Days To Go",
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
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
                "Week 24 Development",
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
                          "Your baby is about the size of a cantaloupe melon.",
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
                        }).toList(),
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
                      _showArticleDialog(context, "Week 24 Development Details", "At 24 weeks, the baby's lungs are developing surfactant to facilitate independent breathing later. The inner ear balance senses have fully matured, allowing the baby to sense coordination, movement, and mother's position shifts.");
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
  Widget _buildPregnancyJourneyTimeline() {
    final List<Map<String, dynamic>> milestones = [
      {"title": "First Trimester Complete", "status": "Completed", "icon": Icons.check_circle, "color": BlushyColors.success},
      {"title": "20 Week Scan Done", "status": "Completed", "icon": Icons.check_circle, "color": BlushyColors.success},
      {"title": "Third Trimester Begins", "status": "Week 28", "icon": Icons.schedule, "color": BlushyColors.warning},
      {"title": "Birth Preparation", "status": "Week 32", "icon": Icons.schedule, "color": BlushyColors.disabled},
      {"title": "Hospital Bag Prep", "status": "Week 36", "icon": Icons.schedule, "color": BlushyColors.disabled},
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
                "YOUR PREGNANCY JOURNEY",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Trimester & Milestone Progress",
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
                        "Week 24 of 40",
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Expected Due Date: November 15",
                        style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: BlushyColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Trimester 2",
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Simple Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(
                  value: 24 / 40,
                  minHeight: 8,
                  backgroundColor: Color(0xFFF5F0EB),
                  valueColor: AlwaysStoppedAnimation<Color>(BlushyColors.primary),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                "JOURNEY MILESTONES",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 16),
              ...milestones.map((m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(m['icon'] as IconData, color: m['color'] as Color, size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          m['title'] as String,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.text),
                        ),
                      ),
                      Text(
                        m['status'] as String,
                        style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 4: TODAY'S CHECK-IN ---
  Widget _buildPregnancyCheckIn() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "", "label": "Joyful"},
      {"icon": "", "label": "Calm"},
      {"icon": "", "label": "Tired"},
      {"icon": "", "label": "Nauseous"},
      {"icon": "", "label": "Moody"},
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
              // Mood Selector
              Text(
                "MOOD",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final isSelected = _selectedFeeling == opt['label'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      _showCheckInPopupDialog(
                        context,
                        title: "Mood Recorded! ✨",
                        message: "Logged Mood: ${opt['label']} ${opt['icon']}",
                        emoji: opt['icon'],
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withOpacity(0.1) : const Color(0xFFF9F6F0),
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

              // Baby Movement
              _buildLivingHorizontalSelector("BABY MOVEMENT", movementOptions, _pregnancyBabyMovement, (val) {
                setState(() => _pregnancyBabyMovement = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Kick Count logger
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
                      if (_pregnancyKickCount > 0) {
                        setState(() => _pregnancyKickCount--);
                      }
                    },
                  ),
                  Text(
                    "$_pregnancyKickCount Kicks",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: BlushyColors.primary),
                    onPressed: () => setState(() => _pregnancyKickCount++),
                  ),
                ],
              ),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Contractions
              _buildLivingHorizontalSelector("CONTRACTIONS", contractionOptions, _pregnancyContractions, (val) {
                setState(() => _pregnancyContractions = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Vitamins
              _buildLivingHorizontalSelector("PRENATAL VITAMINS", vitaminOptions, _pregnancyVitamins, (val) {
                setState(() => _pregnancyVitamins = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Exercise Activity
              _buildLivingHorizontalSelector("EXERCISE ACTIVITY", exerciseOptions, _pregnancyExercise, (val) {
                setState(() => _pregnancyExercise = val);
              }),
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
                "NOTES & REFLECTIONS",
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
  Widget _buildPregnancyInsights() {
    final List<Map<String, String>> insights = [
      {
        "insight": "You've been sleeping better this week.",
        "desc": "Logging 8 hours of sleep aligns with lower evening fatigue markers reported in your second trimester."
      },
      {
        "insight": "You've consistently taken your prenatal vitamins.",
        "desc": "Great job! A 14-day vitamin streak ensures a steady supply of folate and iron for baby's neural growth."
      },
      {
        "insight": "Your hydration has improved.",
        "desc": "Averaging 2.5L has resolved the leg cramps typically experienced during Week 24."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "SIA INSIGHTS",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...insights.map((item) {
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
                          item['insight']!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _openAskSiaChat(context, "Tell me about: ${item['insight']}"),
                        child: Text("Ask Sia", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          _showArticleDialog(context, "Pregnancy Insights Analysis", item['desc']!);
                        },
                        child: Text(
                          "Learn More",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // --- SECTION 6: TODAY'S CARE PLAN ---
  Widget _buildPregnancyCarePlan() {
    final List<Map<String, dynamic>> recommendations = [
      {"icon": Icons.water_drop_outlined, "title": "Hydration Focus", "desc": "Keep fluid levels high (2.5L target) to support amniotic fluid volume."},
      {"icon": Icons.restaurant, "title": "Nutrition Focus", "desc": "Incorporate iron-rich snacks (spinach, pumpkin seeds) to prevent maternal anemia."},
      {"icon": Icons.directions_run, "title": "Prenatal Stretch", "desc": "15-minute gentle hip-opening stretches to prepare pelvis for labor."},
      {"icon": Icons.medication_outlined, "title": "Prenatal Vitamins", "desc": "Take your iron and calcium supplements with water after breakfast."},
      {"icon": Icons.calendar_month_outlined, "title": "Upcoming Appointment", "desc": "24 Week glucose screening appointment is scheduled for tomorrow at 10 AM."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S CARE PLAN",
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
            children: recommendations.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item['icon'] as IconData, size: 20, color: BlushyColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['desc'] as String,
                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
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
              }).toList(),
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

    final Map<String, List<Map<String, String>>> learnFeeds = {
      "Baby Development": [
        {"title": "Baby Sensory Milestones", "desc": "How Week 24 inner ear development improves coordination and how baby reacts to outside speech sounds."},
        {"title": "Fetal Lung Surfactant", "desc": "Understanding respiratory tissue growths and surfactant layers preparing for life outside."}
      ],
      "Mother's Body": [
        {"title": "Second Trimester Skin Changes", "desc": "Linea nigra and stretch mark facts under pregnancy melanocyte-stimulating hormone rises."},
        {"title": "Sciatic Nerve Pain Soothers", "desc": "How uterus alignment pressure affects pelvic nerves and quick stretches to relieve shooting leg pain."}
      ],
      "Nutrition": [
        {"title": "Iron Intake and Red Blood Cells", "desc": "Increasing dietary iron to support the expanded vascular system during the second trimester."},
        {"title": "Maternal Calcium Reserves", "desc": "Protecting maternal bone density while facilitating baby's skeletal bone hardening stages."}
      ],
      "Sleep": [
        {"title": "Left Side Sleep Positions", "desc": "Why sleeping on your left side optimizes blood flow through the inferior vena cava to the placenta."},
        {"title": "Managing Midnight Restlessness", "desc": "Soothe restless legs through warm baths and magnesium-rich evening protocols."}
      ],
      "Labour Preparation": [
        {"title": "Understanding Braxton Hicks", "desc": "How uterus micro-contractions act as practice exercises and how to differentiate them from real labor."},
        {"title": "Writing a Gentle Birth Plan", "desc": "A premium collaborative template detailing options for delivery positions and postpartum settings."}
      ]
    };

    final articles = learnFeeds[_pregnancyDiscoverTopic] ?? [];

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
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 10: MY JOURNEY ---
  Widget _buildPregnancyJourney() {
    final List<Map<String, String>> events = [
      {"date": "March 15", "title": "Pregnancy Confirmed", "detail": "Home test positive."},
      {"date": "April 20", "title": "Heartbeat Confirmed", "detail": "First clinic scan completed."},
      {"date": "May 25", "title": "First Ultrasound", "detail": " trimester measurements verified."},
      {"date": "June 18", "title": "Entered Second Trimester", "detail": "Slight improvement in morning nausea."},
      {"date": "July 12", "title": "Baby's First Kick", "detail": "Movement logged in evening notes."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "MY JOURNEY",
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
            children: events.map((item) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 25,
                    child: Text(
                      item['date']!,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                  ),
                  Expanded(
                    flex: 75,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']!,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['detail']!,
                          style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                        ),
                        const Divider(height: 24, color: Color(0xFFF5F0EB)),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 11: MONTHLY REFLECTION ---
  Widget _buildPregnancyReflection() {
    final List<String> reflectionItems = [
      "You've cared for yourself beautifully this month.",
      "You've completed every prenatal appointment.",
      "You've been consistent with daily hydration targets.",
      "You've reached another exciting trimester milestone.",
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
            "MONTHLY REFLECTION",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 20),
          ...reflectionItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: BlushyColors.success, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 36, color: Color(0xFFF5F0EB)),
          Text(
            "SIA'S MONTHLY PREGNANCY REFLECTION",
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            "\"This month, you took incredible care of both your changing body and your growing baby. Trimester progress timelines confirm wonderful hydration and stretch routine consistency. You are doing amazing.\"",
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

                          // Right Sidebar Panel (35% width) - Sticky top offset 32px
                          Expanded(
                            flex: 35,
                            child: AnimatedBuilder(
                              animation: _pregnancyHomeScrollController,
                              builder: (context, child) {
                                double offset = 0.0;
                                if (_pregnancyHomeScrollController.hasClients) {
                                  final double scrollOffset = _pregnancyHomeScrollController.offset;
                                  if (scrollOffset > 1350) {
                                    offset = scrollOffset - 1350 + 32;
                                  }
                                }
                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                );
                              },
                              child: Column(
                                children: [
                                  _buildPregnancyJourney(),
                                  const SizedBox(height: 48),
                                  _buildPregnancyReflection(),
                                ],
                              ),
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
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF2EE), // Warm background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3E4DD), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "TODAY'S BRIEF",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.primary,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${_getTimeBasedGreetingPrefix()}, $name",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You've already done something incredible. Today, let's take care of you too.",
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "POSTPARTUM RECOVERY: 6 WEEKS",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Recovery In Progress • Focus on healing",
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Scroll down to 'Today's Wellbeing' logging"),
                        backgroundColor: BlushyColors.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
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

  // --- SECTION 2: YOUR RECOVERY ---
  Widget _buildPostpartumRecoveryTimeline() {
    final List<Map<String, dynamic>> milestones = [
      {"week": "Birth", "desc": "Initial healing & bonding", "checked": true},
      {"week": "Week 2", "desc": "Physical resting & feeding patterns", "checked": true},
      {"week": "Week 6 Check-up", "desc": "Clinical recovery & screening", "checked": true},
      {"week": "3 Months", "desc": "Gradual routine integration", "checked": false},
      {"week": "6 Months", "desc": "Returning to physical exercise", "checked": false},
      {"week": "1 Year", "desc": "Long term tissue realignment", "checked": false},
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
                "YOUR RECOVERY",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Healing Milestone Timeline",
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
                        "6 Weeks Postpartum",
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Upcoming: Week 6 Clinical Check-up",
                        style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...milestones.map((m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        m['checked'] as bool ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: m['checked'] as bool ? BlushyColors.success : BlushyColors.disabled,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['week'] as String,
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                            ),
                            Text(
                              m['desc'] as String,
                              style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),
              Text(
                "RECOVERY SUMMARY",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricLabel("Energy Level", "Improving"),
                  _buildMetricLabel("Sleep State", "Interrupted"),
                  _buildMetricLabel("Tissues", "Healing Progressing"),
                  _buildMetricLabel("Pelvic State", "Recovering"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 3: TODAY'S WELLBEING (One-tap logging) ---
  Widget _buildPostpartumWellbeing() {
    final List<Map<String, dynamic>> moodOptions = [
      {"icon": "", "label": "Capable"},
      {"icon": "", "label": "Tired"},
      {"icon": "", "label": "Overwhelmed"},
      {"icon": "", "label": "Sleepy"},
      {"icon": "", "label": "Sensitive"},
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
              // Mood Selector
              Text(
                "MOOD",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final isSelected = _selectedFeeling == opt['label'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      _showCheckInPopupDialog(
                        context,
                        title: "Mood Recorded! ✨",
                        message: "Logged Mood: ${opt['label']} ${opt['icon']}",
                        emoji: opt['icon'],
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withOpacity(0.1) : const Color(0xFFF9F6F0),
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

              // Feeding Method
              _buildLivingHorizontalSelector("FEEDING METHOD", feedingOptions, _postpartumFeeding, (val) {
                setState(() => _postpartumFeeding = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Bleeding (Lochia)
              _buildLivingHorizontalSelector("BLEEDING STATUS", bleedingOptions, _postpartumBleeding, (val) {
                setState(() => _postpartumBleeding = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Incision Healing
              _buildLivingHorizontalSelector("INCISION HEALING", incisionOptions, _postpartumIncision, (val) {
                setState(() => _postpartumIncision = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Pelvic Exercises
              _buildLivingHorizontalSelector("PELVIC FLOOR EXERCISE", pelvicOptions, _postpartumPelvic, (val) {
                setState(() => _postpartumPelvic = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Hydration
              _buildLivingHorizontalSelector("DAILY HYDRATION", waterOptions, _postpartumWater, (val) {
                setState(() => _postpartumWater = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Gentle Movement
              _buildLivingHorizontalSelector("GENTLE MOVEMENT", exerciseOptions, _postpartumExercise, (val) {
                setState(() => _postpartumExercise = val);
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
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Log Weight"),
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
                label: const Text("Log Weight"),
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
                "NOTES & REFLECTIONS",
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
  Widget _buildPostpartumInsights() {
    final List<Map<String, String>> insights = [
      {
        "insight": "You've been getting slightly more sleep this week.",
        "desc": "Splitting feed shifts has allowed a consolidated 4-hour sleep block, improving energy recovery."
      },
      {
        "insight": "You've remembered your hydration goals more consistently.",
        "desc": "Averaging 2.5L is keeping your postpartum milk supplies steady and matching breastfeeding demands."
      },
      {
        "insight": "You report fewer pain symptoms compared with last week.",
        "desc": "Incision sore levels have dropped, aligning with week-6 skin tissue repair completions."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "SIA INSIGHTS",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...insights.map((item) {
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
                          item['insight']!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _openAskSiaChat(context, "Tell me about: ${item['insight']}"),
                        child: Text("Ask Sia", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          _showArticleDialog(context, "Postpartum Recovery Insights", item['desc']!);
                        },
                        child: Text(
                          "Learn More",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // --- SECTION 5: YOUR CARE PLAN ---
  Widget _buildPostpartumCarePlan() {
    final List<Map<String, dynamic>> recommendations = [
      {"icon": Icons.nightlight_round, "title": "Rest Focus", "desc": "Rest while baby is sleeping. Skip chores to facilitate muscle tissue repair."},
      {"icon": Icons.water_drop_outlined, "title": "Hydration Focus", "desc": "Drink 2.5L target to support lochia drainage and breastfeeding demands."},
      {"icon": Icons.restaurant, "title": "Warm Nutrition Foods", "desc": "Eat warm soups, bone broths, and cooked grains to ease digestion constraints."},
      {"icon": Icons.self_improvement, "title": "Pelvic Floor Focus", "desc": "Perform 5-minute gentle kegels and pelvic alignment breathing exercises."},
      {"icon": Icons.calendar_month_outlined, "title": "Clinical Check-up Reminder", "desc": "Your clinical Week 6 check-up appointment is scheduled for next Tuesday."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "YOUR CARE PLAN",
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
            children: recommendations.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item['icon'] as IconData, size: 20, color: BlushyColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['desc'] as String,
                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
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
              }).toList(),
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

    final Map<String, List<Map<String, String>>> learnFeeds = {
      "Physical Recovery": [
        {"title": "Healing the Incision Site", "desc": "How postpartum skin tissues recover from surgeries or tearing, and hygiene targets to check daily."},
        {"title": "Lochia Flow Stages Traced", "desc": "Differentiating bleeding types from weeks 1 to 6 and recognizing normal color shifts."}
      ],
      "Mental Health": [
        {"title": "Understanding the Baby Blues", "desc": "Why hormone drops (estrogen/progesterone) during the first 14 days spike emotional sensitivity."},
        {"title": "Prioritizing Rest Over Chores", "desc": "Mindset tools to bypass social pressure and prioritize postpartum mental recovery."}
      ],
      "Postpartum Depression": [
        {"title": "PPD Indicators & Screening", "desc": "Recognizing chronic anxiety, sleep shifts, or bonding challenges early."},
        {"title": "Support Networks Overview", "desc": "Identifying professional counselors and community postpartum resources."}
      ],
      "Breastfeeding": [
        {"title": "Achieving a Comfortable Latch", "desc": "Step-by-step guidance on positions (cradle, football) to prevent sore nipples."},
        {"title": "Managing Milk Supply Spikes", "desc": "How hydration and regular demand patterns optimize breast milk production."}
      ],
      "Pelvic Floor Recovery": [
        {"title": "Pelvic Floor Restorations", "desc": "Safe post-birth kegel routines and diaphragmatic breathing steps to stabilize deep core tissues."},
        {"title": "Checking for Diastasis Recti", "desc": "How to inspect abdominal separation at week 6 and what movements to avoid."}
      ]
    };

    final articles = learnFeeds[_postpartumDiscoverTopic] ?? [];

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
  Widget _buildPostpartumJourney() {
    final List<Map<String, String>> milestones = [
      {"date": "June 01", "title": "Baby Born!", "detail": "Welcomed little one to the world."},
      {"date": "June 15", "title": "First Gentle Walk", "detail": "10 minutes fresh air stroll around the block."},
      {"date": "July 02", "title": "First Full Night's Sleep", "detail": "Consolidated 6 hours segment logged."},
      {"date": "July 12", "title": "6 Week Check-up Completed", "detail": "Incision and tissue recovery checked."},
      {"date": "July 20", "title": "Restarted Pelvic Floor exercises", "detail": "Consistent 5 min stretch streak."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "MY JOURNEY",
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
            children: milestones.map((item) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 25,
                    child: Text(
                      item['date']!,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                  ),
                  Expanded(
                    flex: 75,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']!,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['detail']!,
                          style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                        ),
                        const Divider(height: 24, color: Color(0xFFF5F0EB)),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildPostpartumReflection() {
    final List<String> reflectionItems = [
      "You've shown incredible strength this month.",
      "You've cared for both yourself and your baby.",
      "You've become more confident in your new routine.",
      "Recovery takes time, and you're making progress every day.",
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
            "MONTHLY REFLECTION",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 20),
          ...reflectionItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: BlushyColors.success, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 36, color: Color(0xFFF5F0EB)),
          Text(
            "SIA'S MONTHLY POSTPARTUM REFLECTION",
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            "\"This month, you navigated tissue healing, pelvic recovery, and sleep disruptions with immense grace. Your recovery check-ins confirm fantastic hydration and core exercise consistency. We celebrate you today.\"",
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

                          // Right Sidebar Panel (35% width) - Sticky top offset 32px
                          Expanded(
                            flex: 35,
                            child: AnimatedBuilder(
                              animation: _postpartumHomeScrollController,
                              builder: (context, child) {
                                double offset = 0.0;
                                if (_postpartumHomeScrollController.hasClients) {
                                  final double scrollOffset = _postpartumHomeScrollController.offset;
                                  if (scrollOffset > 1350) {
                                    offset = scrollOffset - 1350 + 32;
                                  }
                                }
                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                );
                              },
                              child: Column(
                                children: [
                                  _buildPostpartumJourney(),
                                  const SizedBox(height: 48),
                                  _buildPostpartumReflection(),
                                ],
                              ),
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
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF2EE), // Warm background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3E4DD), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "SIA'S DAILY BRIEF",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: BlushyColors.primary,
                    letterSpacing: 2.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${_getTimeBasedGreetingPrefix()}, $name",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Your body is adapting to a new chapter. Every experience is unique, and we'll understand yours together.",
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CYCLE STATUS: CYCLE DAY 47",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Waiting For Next Period • Perimenopause Journey",
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
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

  // --- SECTION 2: MY CHANGING CYCLE ---
  Widget _buildPeriChangingCycle(PersonalContext pc) {
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
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cycle Day 47",
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Last Period: 47 Days Ago",
                        style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: BlushyColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Highly Variable",
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
                      "Day 47",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    Text(
                      "Late Phase",
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricLabel("Average Length", "46.2 Days"),
                  _buildMetricLabel("Shortest Cycle", "31 Days"),
                  _buildMetricLabel("Longest Cycle", "62 Days"),
                  _buildMetricLabel("Variability", "High (±14d)"),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3E4DD), width: 0.8),
                ),
                child: Text(
                  "\"Your cycles have gradually become less predictable over recent months. We're noticing longer gaps between periods, which is typical for the perimenopause transition.\"",
                  style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: BlushyColors.secondaryText),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Period Logged (Simulated)"),
                            backgroundColor: BlushyColors.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Log Period",
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
      {"icon": "", "label": "Balanced"},
      {"icon": "", "label": "Tired"},
      {"icon": "", "label": "Anxious"},
      {"icon": "", "label": "Warm"},
      {"icon": "", "label": "Irritable"},
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
              // Mood Selector
              Text(
                "MOOD",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final isSelected = _selectedFeeling == opt['label'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      _showCheckInPopupDialog(
                        context,
                        title: "Mood Recorded! ✨",
                        message: "Logged Mood: ${opt['label']} ${opt['icon']}",
                        emoji: opt['icon'],
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withOpacity(0.1) : const Color(0xFFF9F6F0),
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

              // Hot Flashes
              _buildLivingHorizontalSelector("HOT FLASHES", flashOptions, _periHotFlashes, (val) {
                setState(() => _periHotFlashes = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Night Sweats
              _buildLivingHorizontalSelector("NIGHT SWEATS", sweatOptions, _periNightSweats, (val) {
                setState(() => _periNightSweats = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Brain Fog
              _buildLivingHorizontalSelector("BRAIN FOG", fogOptions, _periBrainFog, (val) {
                setState(() => _periBrainFog = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Hormone Therapy
              _buildLivingHorizontalSelector("HORMONE THERAPY", therapyOptions, _periHormoneTherapy, (val) {
                setState(() => _periHormoneTherapy = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Flow
              _buildLivingHorizontalSelector("PERIOD FLOW (LOCHIA/SPOTTING)", flowOptions, _periFlow, (val) {
                setState(() => _periFlow = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Exercise
              _buildLivingHorizontalSelector("DAILY EXERCISE", exerciseOptions, _periExercise, (val) {
                setState(() => _periExercise = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Hydration
              _buildLivingHorizontalSelector("DAILY HYDRATION", waterOptions, _periWater, (val) {
                setState(() => _periWater = val);
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
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Log Weight"),
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
                label: const Text("Log Weight"),
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
                "NOTES & REFLECTIONS",
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
  Widget _buildPeriInsights() {
    final List<Map<String, String>> insights = [
      {
        "insight": "Your hot flashes have become less frequent over the past month.",
        "desc": "Tracking logs show a 30% drop in intensity, correlating with regular hormone therapy schedules."
      },
      {
        "insight": "You tend to sleep better on days when you exercise.",
        "desc": "Deep sleep segments extended by 40 minutes on days with walk/strength targets."
      },
      {
        "insight": "Brain fog appears to increase after poor sleep.",
        "desc": "Observations indicate a strong link between night sweat disruptions and next-day focus levels."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "SIA INSIGHTS",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...insights.map((item) {
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
                          item['insight']!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _openAskSiaChat(context, "Tell me about: ${item['insight']}"),
                        child: Text("Ask Sia", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          _showArticleDialog(context, "Perimenopause Insight Details", item['desc']!);
                        },
                        child: Text(
                          "Learn More",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // --- SECTION 5: UNDERSTANDING MY PATTERNS ---
  Widget _buildPeriPatterns() {
    final List<Map<String, String>> patterns = [
      {
        "title": "Cycle Pattern",
        "desc": "\"Your periods are becoming further apart.\"",
        "detail": "Cycles have expanded from an average of 31 days to 54 days over the last year. This is expected as ovarian reserve levels naturally shift."
      },
      {
        "title": "Sleep Pattern",
        "desc": "\"Sleep quality tends to decrease after hot flash episodes.\"",
        "detail": "Night sweat episodes trigger brief waking states, interrupting REM cycles and causing fatigue the following day."
      },
      {
        "title": "Mood Pattern",
        "desc": "\"Stress levels often increase after poor sleep.\"",
        "detail": "Cortisol baselines show sensitivity spikes on mornings following night sweats and fragmented sleep."
      },
      {
        "title": "Hot Flash Pattern",
        "desc": "\"Hot flashes are most common during the evening.\"",
        "detail": "Thermal logs suggest temperature regulation spikes are clustered between 7 PM and 10 PM."
      },
      {
        "title": "Lifestyle Pattern",
        "desc": "\"Regular walks appear to improve your energy.\"",
        "detail": "30-minute cardio walking sessions correlate with stable energy baselines and positive mood logs."
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
              const SizedBox(height: 6),
              Text(
                "AI-Generated Perimenopause Cards",
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
            itemCount: patterns.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final card = patterns[index];
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
                      "Why This Matters: Shifts reflect endocrine fluctuations during the transition.",
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
  Widget _buildPeriCarePlan() {
    final List<Map<String, dynamic>> recommendations = [
      {"icon": Icons.ac_unit, "title": "Cooling Strategy", "desc": "Keep a cold water mist or small fan nearby during the evening peak hot flash hours."},
      {"icon": Icons.nightlight_round, "title": "Sleep Support Focus", "desc": "Dim bedroom lights 1 hour before sleep; keep room temperature at 18C (65F)."},
      {"icon": Icons.fitness_center, "title": "Bone Health Strength", "desc": "Incorporate 15 minutes of resistance weights or strength training to support bone mineral densities."},
      {"icon": Icons.restaurant, "title": "Phytoestrogens Nutrition", "desc": "Add flaxseeds, tofu, or soy to meals to naturally cushion estrogen dips gently."},
      {"icon": Icons.check_circle_outline, "title": "Hormone Therapy Reminder", "desc": "Take scheduled estrogen/progesterone supplement according to clinical plan."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S CARE PLAN",
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
            children: recommendations.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item['icon'] as IconData, size: 20, color: BlushyColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['desc'] as String,
                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 7: LEARN ---
  Widget _buildPeriLearn() {
    final List<String> topics = [
      "Understanding Perimenopause", "Hormonal Changes", "Hot Flashes", "Sleep", "Bone Health"
    ];

    final Map<String, List<Map<String, String>>> learnFeeds = {
      "Understanding Perimenopause": [
        {"title": "The Perimenopause Transition", "desc": "What happens during the transition phase leading to menopause, and what to expect regarding cycle lengths."},
        {"title": "Recognizing Early Indicators", "desc": "From skipped cycles to minor mood adjustments: identifying the markers early."}
      ],
      "Hormonal Changes": [
        {"title": "Estrogen & Progesterone Fluctuations", "desc": "Why erratic swings in progesterone cause variable cycle spacing and emotional shifts."},
        {"title": "Role of FSH Levels", "desc": "How follicle-stimulating hormones spike as ovaries change their active ovulation responses."}
      ],
      "Hot Flashes": [
        {"title": "Science of Vasomotor Symptoms", "desc": "How estrogen drops trick the hypothalamus into triggering cooling flush responses."},
        {"title": "Managing Evening Flares", "desc": "Lifestyle adjustments, clothing layers, and nutrition tweaks to buffer hot flash triggers."}
      ],
      "Sleep": [
        {"title": "Tackling Sleep Fragmentation", "desc": "Why progesterone drop impairs melatonin release, and tips for deep sleep extensions."},
        {"title": "Coping with Night Sweats", "desc": "Optimal fabrics and sleeping hygiene targets to handle midnight temperature spikes."}
      ],
      "Bone Health": [
        {"title": "Maintaining Bone Mineral Density", "desc": "Why estrogen drops trigger bone density loss, and the importance of daily calcium targets."},
        {"title": "Strength Training Benefits", "desc": "How resistance exercises and weights preserve bone structure and joint health."}
      ]
    };

    final articles = learnFeeds[_periDiscoverTopic] ?? [];

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
  Widget _buildPeriTransition() {
    final List<Map<String, String>> milestones = [
      {"date": "Jan 2025", "title": "First Irregular Cycle", "detail": "Tracked a 45-day cycle length variation."},
      {"date": "Mar 2025", "title": "Hot Flashes Began", "detail": "Logged mild evening temperature flushes."},
      {"date": "May 2025", "title": "Started Strength Training", "detail": "Added 15 mins resistance weights twice a week."},
      {"date": "June 2025", "title": "Discussed Symptoms With Doctor", "detail": "Reviewed cycle variances and hormone checks."},
      {"date": "July 2025", "title": "Started Hormone Therapy", "detail": "Began custom hormonal alignment plan."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "MY TRANSITION",
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
            children: milestones.map((item) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 25,
                    child: Text(
                      item['date']!,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                  ),
                  Expanded(
                    flex: 75,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']!,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['detail']!,
                          style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                        ),
                        const Divider(height: 24, color: Color(0xFFF5F0EB)),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildPeriReflection() {
    final List<String> reflectionItems = [
      "You've learned more about how your body is changing.",
      "You've become more consistent with your sleep routine.",
      "You've recognised patterns that can help guide future decisions.",
      "You've continued showing up for yourself during a time of change.",
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
            "MONTHLY REFLECTION",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 20),
          ...reflectionItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: BlushyColors.success, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 36, color: Color(0xFFF5F0EB)),
          Text(
            "SIA'S MONTHLY TRANSITION REFLECTION",
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            "\"This month, you successfully tracked cycle length fluctuations, evening hot flashes, and hormone therapy consistency with incredible empowerment. Your patterns show positive sleep trends on exercise days. We celebrate your journey.\"",
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
                                const SizedBox(height: 48),
                                _buildPeriLearn(),
                                const SizedBox(height: 48),
                                _buildPeriCommunity(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right Sidebar Panel (35% width) - Sticky top offset
                          Expanded(
                            flex: 35,
                            child: AnimatedBuilder(
                              animation: _periHomeScrollController,
                              builder: (context, child) {
                                double offset = 0.0;
                                if (_periHomeScrollController.hasClients) {
                                  final double scrollOffset = _periHomeScrollController.offset;
                                  if (scrollOffset > 1350) {
                                    offset = scrollOffset - 1350 + 32;
                                  }
                                }
                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                );
                              },
                              child: Column(
                                children: [
                                  _buildPeriTransition(),
                                  const SizedBox(height: 48),
                                  _buildPeriReflection(),
                                ],
                              ),
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
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF2EE), // Warm background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3E4DD), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "SIA'S DAILY BRIEF",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: BlushyColors.primary,
                    letterSpacing: 2.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${_getTimeBasedGreetingPrefix()}, $name",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Your body has entered a new rhythm. Let's help you feel your best today.",
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "MENOPAUSE JOURNEY",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "2 Years Since Menopause • Healthy Vitality Focus",
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
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

  // --- SECTION 2: MY WELLBEING ---
  // --- SECTION 2: MY WELLBEING ---
  Widget _buildMenoWellbeing([PersonalContext? pcParam, CurrentWellbeingState? wbParam]) {
    final state = BlushyOSProvider.of(context);
    final pc = pcParam ?? state.personalContext;
    final wb = wbParam ?? state.wellbeingState;

    final String? sleepVal = _wellnessSleep ?? (wb.sleepQuality != null ? "${wb.sleepQuality}h" : null);
    final String? energyVal = _checkInEnergy.isNotEmpty && _checkInEnergy != 'Balanced' ? _checkInEnergy : (wb.energy != null ? "Level ${wb.energy}/10" : null);
    final String? moodVal = _selectedFeeling ?? (_checkInMood.isNotEmpty && _checkInMood != 'Calm' ? _checkInMood : (wb.mood != null ? "Level ${wb.mood}/10" : null));
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricLabel("Sleep Quality", sleepVal ?? "Not Logged"),
                  _buildMetricLabel("Energy level", energyVal ?? "Not Logged"),
                  _buildMetricLabel("Mood State", moodVal ?? "Not Logged"),
                  _buildMetricLabel("Medication/HRT", hrtVal ?? "Not Logged"),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricLabel("Daily Walking", walkingVal ?? "Not Logged"),
                  _buildMetricLabel("Hydration", hydrationVal ?? "Not Logged"),
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
      {"icon": "", "label": "Balanced"},
      {"icon": "", "label": "Tired"},
      {"icon": "", "label": "Anxious"},
      {"icon": "", "label": "Warm"},
      {"icon": "", "label": "Irritable"},
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
              // Mood Selector
              Text(
                "MOOD",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final isSelected = _selectedFeeling == opt['label'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      _showCheckInPopupDialog(
                        context,
                        title: "Mood Recorded! ✨",
                        message: "Logged Mood: ${opt['label']} ${opt['icon']}",
                        emoji: opt['icon'],
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withOpacity(0.1) : const Color(0xFFF9F6F0),
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

              // Hot Flashes
              _buildLivingHorizontalSelector("HOT FLASHES", flashOptions, _menoHotFlashes, (val) {
                setState(() => _menoHotFlashes = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Night Sweats
              _buildLivingHorizontalSelector("NIGHT SWEATS", sweatOptions, _menoNightSweats, (val) {
                setState(() => _menoNightSweats = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Joint Stiffness
              _buildLivingHorizontalSelector("JOINT STIFFNESS", jointOptions, _menoJointPain, (val) {
                setState(() => _menoJointPain = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Hormone Therapy / Medication
              _buildLivingHorizontalSelector("MEDICATION & HRT STATUS", therapyOptions, _menoHormoneTherapy, (val) {
                setState(() => _menoHormoneTherapy = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Strength Training
              _buildLivingHorizontalSelector("STRENGTH WORKOUT", strengthOptions, _menoStrength, (val) {
                setState(() => _menoStrength = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Walking
              _buildLivingHorizontalSelector("DAILY WALKING HABIT", walkingOptions, _menoWalking, (val) {
                setState(() => _menoWalking = val);
              }),
              const Divider(height: 36, color: Color(0xFFF5F0EB)),

              // Hydration
              _buildLivingHorizontalSelector("DAILY HYDRATION", waterOptions, _menoWater, (val) {
                setState(() => _menoWater = val);
              }),
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
                "NOTES & REFLECTIONS",
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
  Widget _buildMenoInsights() {
    final List<Map<String, String>> insights = [
      {
        "insight": "You've reported fewer hot flashes this month.",
        "desc": "Thermal symptom frequency decreased from 4 events/day to 1 event/day, aligned with active cooling guidelines."
      },
      {
        "insight": "Strength training days are followed by higher energy.",
        "desc": "Muscle stimulation increases baseline metabolism rates, helping buffer next-day sluggishness levels."
      },
      {
        "insight": "You tend to sleep better after evening stretching.",
        "desc": "Stretching exercises lower night cortisol levels, promoting smooth melatonin transitions."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "SIA INSIGHTS",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...insights.map((item) {
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
                          item['insight']!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _openAskSiaChat(context, "Tell me about: ${item['insight']}"),
                        child: Text("Ask Sia", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          _showArticleDialog(context, "Menopause Insight details", item['desc']!);
                        },
                        child: Text(
                          "Learn More",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
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
    final List<Map<String, dynamic>> recommendations = [
      {"icon": Icons.fitness_center, "title": "Strength training", "desc": "Perform 15-minute resistance bands workout to stimulate post-menopause bone density."},
      {"icon": Icons.directions_walk, "title": "Heart Health walk", "desc": "Take a brisk 20-minute walk outdoors to support cardiovascular elasticity targets."},
      {"icon": Icons.restaurant, "title": "Protein nutrition target", "desc": "Incorporate 25g protein (eggs, tofu, beans) into lunch to prevent muscle declines."},
      {"icon": Icons.nightlight_round, "title": "Evening stretching", "desc": "Do 10 minutes of light floor stretches before bed to support deeper sleep cycles."},
      {"icon": Icons.check_circle_outline, "title": "HRT compliance", "desc": "Take scheduled estrogen / hormone therapy supplement according to guidelines."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S CARE PLAN",
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
            children: recommendations.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item['icon'] as IconData, size: 20, color: BlushyColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['desc'] as String,
                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 7: LEARN ---
  Widget _buildMenoLearn() {
    final List<String> topics = [
      "Understanding Menopause", "Bone Health", "Heart Health", "Strength Training", "Nutrition"
    ];

    final Map<String, List<Map<String, String>>> learnFeeds = {
      "Understanding Menopause": [
        {"title": "Life After Menopause", "desc": "Adapting to stable baseline hormone levels and understanding the shifts in post-menopausal vascular parameters."},
        {"title": "The Post-Transition Phase", "desc": "Shifting the wellness perspective from cycle trackings to lifelong vitality and muscle health."}
      ],
      "Bone Health": [
        {"title": "Preserving Bone Mineral density", "desc": "Why estrogen drops trigger osteoblast cell slowdowns, and the role of daily calcium plus Vitamin D."},
        {"title": "Resistance exercises for bones", "desc": "How load-bearing routines stimulate joint tissues and prevent natural post-menopausal wear."}
      ],
      "Heart Health": [
        {"title": "Endothelial Health after Menopause", "desc": "Estrogen drop influences blood vessel elasticity. Learn how active walking preserves cardiac tone."},
        {"title": "Managing blood pressure baselines", "desc": "Practical habits, hydration routines, and sodium constraints to buffer cardiac spikes."}
      ],
      "Strength Training": [
        {"title": "Sarcopenia prevention guidelines", "desc": "Why post-menopausal bodies require active strength resistances, and simple bands routines."},
        {"title": "Joint-safe strength movements", "desc": "Low-impact modifications for squats, chest presses, and glute bridges to protect cartilage."}
      ],
      "Nutrition": [
        {"title": "Meeting daily protein targets", "desc": "Why post-menopausal users require high protein density (1.2g/kg) to maintain lean tissues."},
        {"title": "Calcium rich foods to include", "desc": "Sourcing calcium from leafy greens, fortified milks, almonds, and dairy sources."}
      ]
    };

    final articles = learnFeeds[_menoDiscoverTopic] ?? [];

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
  Widget _buildMenoWellnessJourney() {
    final List<Map<String, String>> milestones = [
      {"date": "June 2024", "title": "Reached Menopause", "detail": "Completed 12 consecutive months period-free transition."},
      {"date": "Aug 2024", "title": "Started Strength Training", "detail": "Configured resistance weights twice a week target."},
      {"date": "Dec 2024", "title": "Began daily walking habit", "detail": "Established stable 6,000 steps minimum target."},
      {"date": "Mar 2025", "title": "Reduced hot flashes", "detail": "Confirmed a 70% decrease in night sweat intensities."},
      {"date": "June 2025", "title": "One Year Of Wellness Tracking", "detail": "Celebrated daily healthy habit consistency updates."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "MY WELLNESS JOURNEY",
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
            children: milestones.map((item) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 25,
                    child: Text(
                      item['date']!,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                  ),
                  Expanded(
                    flex: 75,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']!,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['detail']!,
                          style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                        ),
                        const Divider(height: 24, color: Color(0xFFF5F0EB)),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildMenoReflection() {
    final List<String> reflectionItems = [
      "You've invested in your long-term health this month.",
      "You've become more consistent with movement.",
      "You've developed routines that support your wellbeing.",
      "You've continued showing up for yourself every day.",
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
            "MONTHLY REFLECTION",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 20),
          ...reflectionItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: BlushyColors.success, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 36, color: Color(0xFFF5F0EB)),
          Text(
            "SIA'S MONTHLY WELLNESS REFLECTION",
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            "\"This month, you completed outstanding strength routines, cardiovascular walk metrics, and HRT compliance tasks. Your post-menopause parameters show positive bone density supports. We celebrate your lifelong health journey.\"",
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
                                const SizedBox(height: 48),
                                _buildMenoLearn(),
                                const SizedBox(height: 48),
                                _buildMenoCommunity(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right Sidebar Panel (35% width) - Sticky top offset
                          Expanded(
                            flex: 35,
                            child: AnimatedBuilder(
                              animation: _menoHomeScrollController,
                              builder: (context, child) {
                                double offset = 0.0;
                                if (_menoHomeScrollController.hasClients) {
                                  final double scrollOffset = _menoHomeScrollController.offset;
                                  if (scrollOffset > 1350) {
                                    offset = scrollOffset - 1350 + 32;
                                  }
                                }
                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                );
                              },
                              child: Column(
                                children: [
                                  _buildMenoWellnessJourney(),
                                  const SizedBox(height: 48),
                                  _buildMenoReflection(),
                                ],
                              ),
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
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF2EE), // Warm background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3E4DD), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "SIA'S DAILY BRIEF",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: BlushyColors.primary,
                    letterSpacing: 2.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${_getTimeBasedGreetingPrefix()}, $name",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You've been sleeping better this week. Let's build on that today.",
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TODAY'S WELLNESS FOCUS: SLEEP & ENERGY",
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Establishing positive daily routines • Gentle movement focus",
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
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

  // --- SECTION 2: MY WELLNESS ---
  // --- SECTION 2: MY WELLNESS ---
  Widget _buildWellnessDashboard([PersonalContext? pcParam, CurrentWellbeingState? wbParam]) {
    final state = BlushyOSProvider.of(context);
    final pc = pcParam ?? state.personalContext;
    final wb = wbParam ?? state.wellbeingState;

    final String? sleepVal = _wellnessSleep ?? (wb.sleepQuality != null ? "${wb.sleepQuality}h" : null);
    final String? energyVal = _checkInEnergy.isNotEmpty && _checkInEnergy != 'Balanced' ? _checkInEnergy : (wb.energy != null ? "Level ${wb.energy}/10" : null);
    final String? hydrationVal = _wellnessWater != null ? "$_wellnessWater" : null;
    final String? moodVal = _selectedFeeling ?? (_checkInMood.isNotEmpty && _checkInMood != 'Calm' ? _checkInMood : (wb.mood != null ? "Level ${wb.mood}/10" : null));
    final String? movementVal = _wellnessExercise;
    final String? stressVal = _wellnessStress != null ? "$_wellnessStress Stress" : null;

    final List<String> userGoals = List<String>.from(_onboardingData['goals'] ?? []);
    final List<String> userSymptoms = List<String>.from(_onboardingData['symptoms'] ?? []);
    final Set<String> activeFilters = {...userGoals, ...userSymptoms}.map((e) => e.toLowerCase()).toSet();

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
              // Mood Selector
              Text(
                "MOOD",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moodOptions.map((opt) {
                  final isSelected = _selectedFeeling == opt['label'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = opt['label'];
                      });
                      _showCheckInPopupDialog(
                        context,
                        title: "Mood Recorded! ✨",
                        message: "Logged Mood: ${opt['label']} ${opt['icon']}",
                        emoji: opt['icon'],
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? BlushyColors.primary.withOpacity(0.1) : const Color(0xFFF9F6F0),
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
              _buildLivingHorizontalSelector("ENERGY LEVEL", ["Low", "Balanced", "High"], _checkInEnergy.isNotEmpty ? _checkInEnergy : null, (val) {
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
                        "Log Weight",
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
                  _loggedWeight != null ? "Logged Weight: ${_loggedWeight!.toStringAsFixed(1)} kg" : "Log Weight",
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
                "NOTES & REFLECTIONS",
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
  Widget _buildWellnessInsights() {
    final List<Map<String, String>> insights = [
      {
        "insight": "You feel more energetic after sleeping at least 7.5 hours.",
        "desc": "Observations trace a 25% energy baseline boost on mornings following 7.5+ hour sleep records."
      },
      {
        "insight": "You usually drink less water on busy workdays.",
        "desc": "Logs confirm daily hydration goals drop slightly on days with high stress/work activities."
      },
      {
        "insight": "You've been consistently happier after morning walks.",
        "desc": "Walk metrics track positive mood ratings in check-ins immediately following 20 mins movement stretches."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "SIA INSIGHTS",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...insights.map((item) {
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
                          item['insight']!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _openAskSiaChat(context, "Tell me about: ${item['insight']}"),
                        child: Text("Ask Sia", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          _showArticleDialog(context, "Wellness Insight details", item['desc']!);
                        },
                        child: Text(
                          "Learn More",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // --- SECTION 5: TODAY'S PLAN ---
  Widget _buildWellnessPlan() {
    final List<Map<String, dynamic>> recommendations = [
      {"icon": Icons.water_drop_outlined, "title": "Hydration Focus", "desc": "Keep a 2.5L water bottle on desk. Drink regularly to avoid afternoon sluggishness."},
      {"icon": Icons.directions_walk, "title": "Outdoor brisk walk", "desc": "Take a 20-minute walk during lunch to refresh posture and support heart baselines."},
      {"icon": Icons.self_improvement, "title": "Mindful stretches", "desc": "Complete 5 minutes of gentle diaphragmatic breathing stretches to relieve back tensions."},
      {"icon": Icons.nightlight_round, "title": "Sleep Wind-down", "desc": "Banish screens 45 minutes before bedtime to facilitate natural melatonin drops."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "TODAY'S PLAN",
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
            children: recommendations.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item['icon'] as IconData, size: 20, color: BlushyColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['desc'] as String,
                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 6: DISCOVER ---
  Widget _buildWellnessDiscover() {
    final List<String> topics = [
      "Nutrition", "Exercise", "Women's Health", "Mental Wellbeing", "Sleep", "Stress", "Productivity"
    ];

    final Map<String, List<Map<String, String>>> learnFeeds = {
      "Nutrition": [
        {"title": "Optimal Breakfast Protein", "desc": "How starting the day with 25-30g protein balances glucose curves and prevents mid-day fatigue spikes."},
        {"title": "Gut Health & Digestion", "desc": "Incorporate fermented foods and high fibers to maintain comfortable microbiome balances."}
      ],
      "Exercise": [
        {"title": "Low Impact Strength routines", "desc": "Simple resistance bands and bodyweight sequences to keep core muscle fibers toned safely."},
        {"title": "Walking for Vitality", "desc": "Why brisk daily walks lower vascular risks and keep joint flexibilities steady."}
      ],
      "Women's Health": [
        {"title": "Balancing Daily Schedules", "desc": "How tracking non-reproductive health symptoms (mood, focus, sleep) builds body awareness."},
        {"title": "Hormones & Lifestyle baselines", "desc": "Understanding minor endocrine cycles and adjusting exercise patterns accordingly."}
      ],
      "Mental Wellbeing": [
        {"title": "diaphragmatic breathing guidelines", "desc": "Why 5 minutes of deep nose inhalation triggers vagal nerve relaxations, lowering anxiety."},
        {"title": "Gratitude Journaling", "desc": "Simple daily prompts to anchor positive thoughts and reduce chronic morning stresses."}
      ],
      "Sleep": [
        {"title": "Managing Sleep hygiene", "desc": "Room lighting levels, optimal temperatures, and evening screens setups to optimize deep rest segments."},
        {"title": "Wind-down Stretching routines", "desc": "Floor stretches to release physical tensions and facilitate smoother sleep transitions."}
      ],
      "Stress": [
        {"title": "Lowering Morning Cortisol", "desc": "Bypassing early phone scrolls to regulate nervous systems and prevent adrenaline spikes."},
        {"title": "Managing workplace anxiety", "desc": "Mindful breathing pauses and desk alignments to handle work stresses."}
      ],
      "Productivity": [
        {"title": "The Pomodoro focus focus method", "desc": "Structuring 25-minute focus intervals with active walking breaks to maximize mental recovery."},
        {"title": "Managing digital distractions", "desc": "Setting up device notifications filters to protect daily focus blocks."}
      ]
    };

    final articles = learnFeeds[_wellnessDiscoverTopic] ?? [];

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
        : "\"Sleep check-in: 7-8h restful baseline.\"";

    final String hydrationDesc = _wellnessWater != null
        ? "\"You've logged $_wellnessWater water intake today.\""
        : "\"Hydration goal tracked: 2.5L daily target.\"";

    final String movementDesc = _wellnessExercise != null
        ? "\"You've logged $_wellnessExercise for movement today.\""
        : "\"Active movement tracked consistently.\"";

    final String moodDesc = _selectedFeeling != null
        ? "\"You've logged feeling '$_selectedFeeling' today.\""
        : "\"Mood and emotional balance checked regularly.\"";

    final String weightDesc = _loggedWeight != null
        ? "\"Current weight logged: ${_loggedWeight!.toStringAsFixed(1)} kg.\""
        : "\"Weight tracking: record your optional weight logs.\"";

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
  Widget _buildWellnessJourney() {
    final List<Map<String, String>> milestones = [
      {"date": "Day 01", "title": "Started Wellness Journey", "detail": "Configured baseline lifestyle goals and daily schedules."},
      {"date": "Day 07", "title": "Completed First Week of Logs", "detail": "Consistent mood and sleep check-ins completed."},
      {"date": "Day 15", "title": "Built Daily Hydration Habit", "detail": "Averaged 2.5L water targets for 7 days streak."},
      {"date": "Day 30", "title": "Completed One Month of Check-Ins", "detail": "Celebrated habit consistency records."},
      {"date": "Day 45", "title": "Improved Sleep Segments", "detail": "Extended deep sleep segments by 30 mins average."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "MY WELLNESS JOURNEY",
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
            children: milestones.map((item) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 25,
                    child: Text(
                      item['date']!,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                  ),
                  Expanded(
                    flex: 75,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']!,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['detail']!,
                          style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                        ),
                        const Divider(height: 24, color: Color(0xFFF5F0EB)),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- SECTION 10: MONTHLY REFLECTION ---
  Widget _buildWellnessReflection() {
    final List<String> reflectionItems = [
      "You've become more intentional with your wellbeing.",
      "You've created routines that support your energy.",
      "You've stayed consistent even on busy weeks.",
      "You've continued investing in yourself every day.",
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
            "MONTHLY REFLECTION",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 20),
          ...reflectionItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: BlushyColors.success, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 36, color: Color(0xFFF5F0EB)),
          Text(
            "SIA'S MONTHLY WELLNESS COACH REFLECTION",
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            "\"This month, you successfully tracked sleep segments, daily step walks, and breathing meditational practices with outstanding consistency. We celebrate your sustainable healthy habits journey.\"",
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

                          // Right Sidebar Panel (35% width) - Sticky top offset
                          Expanded(
                            flex: 35,
                            child: AnimatedBuilder(
                              animation: _wellnessHomeScrollController,
                              builder: (context, child) {
                                double offset = 0.0;
                                if (_wellnessHomeScrollController.hasClients) {
                                  final double scrollOffset = _wellnessHomeScrollController.offset;
                                  if (scrollOffset > 1350) {
                                    offset = scrollOffset - 1350 + 32;
                                  }
                                }
                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                );
                              },
                              child: Column(
                                children: [
                                  _buildWellnessJourney(),
                                  const SizedBox(height: 48),
                                  _buildWellnessReflection(),
                                ],
                              ),
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

  Widget _buildFirstPeriodsOS(PersonalContext pc, BlushyOSState state) {
    if (_showFirstPeriodTransition) {
      return _buildFirstPeriodMilestoneTransition(state);
    }

    final data = _getPersonalizedBranchAData(pc);
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";
    final bool hasStarted = data['hasStarted'] == true;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF6F0), // Soft cream luxury background
      endDrawer: DeveloperContextSimulator(
        onLifeStageChanged: (stage) {
          final currentData = BlushyStorage.read('onboarding_temp_profile.json');
          final profile = Map<String, dynamic>.from(currentData['profile'] ?? {});
          profile['lifeStage'] = stage;
          currentData['profile'] = profile;
          BlushyStorage.write('onboarding_temp_profile.json', currentData);
          _loadOnboardingData();
        },
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width < 768 ? 640 : double.infinity),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              children: [
                _buildBranchSwitcher(state),
                
                // 1. Redesigned Hero: Greeting & Tagline
                Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "BLUSHY PREPARATION • EDITION 01",
                        style: BlushyTypography.sectionLabel(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "${_getTimeBasedGreetingPrefix()}, $displayName",
                        style: BlushyTypography.displayXL(color: BlushyColors.text),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                if (!hasStarted) ...[
                  // --- BRANCH A REDESIGNED STORY FLOW ---

                  // Section 1: Sia's Visually Rewritten Letter
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded, color: BlushyColors.primary, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              "LATEST NOTE",
                              style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Growing up\ncan feel confusing.",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                            color: BlushyColors.text,
                            height: 1.4,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "You don't have to\nfigure everything out today.",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                            color: BlushyColors.text,
                            height: 1.4,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "I'll always be here.",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                            color: BlushyColors.text,
                            height: 1.4,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            "Love,\nSia",
                            style: GoogleFonts.poppins(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold, 
                              fontStyle: FontStyle.italic, 
                              color: BlushyColors.primary
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Section 2: Today's Tiny Mission (Single CTA)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: BlushyColors.primary.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
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
                                const Icon(Icons.spa_outlined, color: BlushyColors.primary, size: 14),
                                const SizedBox(width: 8),
                                Text(
                                  "TODAY'S TINY MISSION",
                                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: BlushyColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "2 min",
                                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Learn why discharge happens.",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: BlushyColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Understand how your body quietly cleanses and prepares itself for changes.",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: BlushyColors.secondaryText,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _missionCompleted ? BlushyColors.success : BlushyColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              setState(() {
                                _missionCompleted = !_missionCompleted;
                              });
                            },
                            child: Text(
                              _missionCompleted ? "Mission Completed! " : "Start Learning",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Section 3: Today's Discovery (Curiosity Reveal Card)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EAE0), // Warm editorial paper bag surface
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_outlined, color: BlushyColors.warning, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              "TODAY'S DISCOVERY",
                              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.warning, letterSpacing: 1.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Did you know?",
                          style: GoogleFonts.poppins(
                            fontSize: 24, 
                            fontWeight: FontWeight.bold, 
                            color: BlushyColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your body is already preparing for your first period long before it arrives.",
                          style: GoogleFonts.poppins(
                            fontSize: 16, 
                            fontStyle: FontStyle.italic,
                            color: BlushyColors.text,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_isDiscoveryRevealed)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isDiscoveryRevealed = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    "Tap to Reveal",
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 16, color: BlushyColors.primary),
                                ],
                              ),
                            ),
                          )
                        else
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 500),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "Hormones are quietly preparing your body, and white discharge is a completely natural sign of this preparation. It helps keep your reproductive system clean and healthy!",
                                    style: GoogleFonts.poppins(
                                      fontSize: 13, 
                                      color: BlushyColors.secondaryText,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Section 4: Growing Journey (Milestone Timeline)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.alt_route_outlined, color: BlushyColors.success, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            "MY GROWING JOURNEY",
                            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.success, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Milestone 1
                      _buildMilestoneRow("Learning About My Body", "Completed", true, false, true),
                      _buildTimelineLine(true),
                      // Milestone 2
                      _buildMilestoneRow("Understanding Puberty", "Completed", true, false, true),
                      _buildTimelineLine(true),
                      // Milestone 3
                      _buildMilestoneRow("Preparing For My First Period", "Current Step", false, true, false),
                      _buildTimelineLine(false),
                      // Milestone 4
                      _buildMilestoneRow("My First Period", "Locked", false, false, false),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Section 5: Ask Sia (Prompt suggestion chips)
                  _buildAskSiaPromptSection(data),
                  const SizedBox(height: 48),

                  // Section 6: Growing Together (Family activities / real-life actions)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people_outline_rounded, color: BlushyColors.info, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              "GROWING TOGETHER",
                              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.info, letterSpacing: 1.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Family Mission
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.home_outlined, color: BlushyColors.info, size: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today's Family Mission",
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Ask your mum: \"What was your first period like?\"",
                                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      side: BorderSide(color: _familyMissionCompleted ? BlushyColors.success : BlushyColors.info),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _familyMissionCompleted = !_familyMissionCompleted;
                                      });
                                    },
                                    child: Text(
                                      _familyMissionCompleted ? "Completed " : "Mark Complete",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: _familyMissionCompleted ? BlushyColors.success : BlushyColors.info,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Prep Mission
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.backpack_outlined, color: BlushyColors.info, size: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Preparation Together",
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Pack one sanitary pad inside your school bag.",
                                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      side: BorderSide(color: _prepMissionCompleted ? BlushyColors.success : BlushyColors.info),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _prepMissionCompleted = !_prepMissionCompleted;
                                      });
                                    },
                                    child: Text(
                                      _prepMissionCompleted ? "Completed " : "Mark Complete",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: _prepMissionCompleted ? BlushyColors.success : BlushyColors.info,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Section 7: Community cards (Shared anonymous experiences)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.forum_outlined, color: BlushyColors.secondary, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              "SHARED EXPERIENCES",
                              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.secondary, letterSpacing: 1.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Someone your age asked...",
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "\"I'm scared my first period will happen at school.\"",
                          style: GoogleFonts.poppins(fontSize: 16, fontStyle: FontStyle.italic, color: BlushyColors.text, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            // Link to Sia Screen conversation
                          },
                          child: Row(
                            children: [
                              Text(
                                "See how Sia answered",
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: BlushyColors.primary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.favorite_outline_rounded, size: 14, color: BlushyColors.disabled),
                            const SizedBox(width: 6),
                            Text(
                              "Helpful to 92 girls",
                              style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.disabled),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Section 8: "Before You Go..." Redesigned Check-in
                  _buildBeforeYouGoSection(),
                  const SizedBox(height: 48),

                  // Section 9: Polaroid Scrapbook Fun Facts
                  _buildPolaroidScrapbookSection(data),
                  const SizedBox(height: 72),
                ] else ...[
                  // Branch B: Started (Keeps the same dashboard but using updated Poppins typography)
                  if (pc.lastPeriodStart == null) ...[
                    _buildFirstPeriodWelcomeOnboardingCard(state),
                    const SizedBox(height: 48),
                    _buildSiaLetterSection(data),
                    const SizedBox(height: 56),
                    _buildTalkToSiaSection(data, state),
                    const SizedBox(height: 56),
                    _buildPolaroidScrapbookSection(data),
                    const SizedBox(height: 60),
                  ] else ...[
                    _buildFirstPeriodHeroCard(data, pc),
                    const SizedBox(height: 56),
                    _buildTodayCheckInComponent(),
                    const SizedBox(height: 56),
                    _buildYourGrowingJourneySection(),
                    const SizedBox(height: 56),
                    _buildForwardTimeline(pc),
                    const SizedBox(height: 56),
                    _buildSiaLetterSection(data),
                    const SizedBox(height: 56),
                    _buildYourPatternsSection(pc),
                    const SizedBox(height: 56),
                    _buildForYouMagazineSection(data),
                    const SizedBox(height: 56),
                    _buildTalkToSiaSection(data, state),
                    const SizedBox(height: 56),
                    _buildPolaroidScrapbookSection(data),
                    const SizedBox(height: 60),
                  ]
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeforeYouGoSection() {
    final int day = DateTime.now().day;
    final int questionIndex = day % dummyReflectionPrompts.length;
    final currentPrompt = dummyReflectionPrompts[questionIndex];
    final String questionText = currentPrompt.question;
    final List<String> options = currentPrompt.chips;
    final String replyText = currentPrompt.replyText;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6F0), // Cream paper background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.secondary.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mail_outline_rounded, color: BlushyColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                "BEFORE YOU GO...",
                style: GoogleFonts.poppins(
                  fontSize: 12, 
                  fontWeight: FontWeight.w600, 
                  color: BlushyColors.primary, 
                  letterSpacing: 1.2
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Sia has one little question before you head off.",
            style: GoogleFonts.poppins(
              fontSize: 14, 
              fontWeight: FontWeight.w500,
              color: BlushyColors.secondaryText,
              height: 1.5
            ),
          ),
          const SizedBox(height: 24),
          
          // Question layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BlushyColors.secondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Sia",
                  style: GoogleFonts.poppins(
                    fontSize: 11, 
                    fontWeight: FontWeight.bold, 
                    color: BlushyColors.primary
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  questionText,
                  style: GoogleFonts.poppins(
                    fontSize: 16, 
                    fontWeight: FontWeight.w600, 
                    color: BlushyColors.text,
                    height: 1.4
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (!_beforeYouGoSubmitted) ...[
            // Three option chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(options.length, (index) {
                final isSelected = _beforeYouGoSelectedIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _beforeYouGoSelectedIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? BlushyColors.secondary.withOpacity(0.15) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? BlushyColors.primary : BlushyColors.border,
                        width: 1.5
                      ),
                    ),
                    child: Text(
                      options[index],
                      style: GoogleFonts.poppins(
                        fontSize: 13, 
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? BlushyColors.primary : BlushyColors.text
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            
            // Optional diary section
            Text(
              "Want to tell me a little more?",
              style: GoogleFonts.poppins(
                fontSize: 13, 
                fontWeight: FontWeight.w600, 
                color: BlushyColors.text
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _beforeYouGoController,
              maxLines: 3,
              style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text),
              decoration: InputDecoration(
                hintText: currentPrompt.placeholder,
                hintStyle: GoogleFonts.poppins(color: BlushyColors.secondaryText.withOpacity(0.6), fontSize: 13),
                fillColor: Colors.white,
                filled: true,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: BlushyColors.border, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: BlushyColors.border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: BlushyColors.primary, width: 1.5),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic_none_rounded, color: BlushyColors.secondaryText),
                  onPressed: () {
                    // voice input simulation placeholder
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Skip & Submit Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _beforeYouGoSubmitted = true;
                    });
                  },
                  child: Text(
                    "Skip",
                    style: GoogleFonts.poppins(color: BlushyColors.secondaryText, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: _beforeYouGoSelectedIndex == null ? null : () {
                    setState(() {
                      _beforeYouGoSubmitted = true;
                    });
                  },
                  child: Text(
                    "Send",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Warm acknowledgement layout
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: BlushyColors.secondary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.favorite_rounded, color: BlushyColors.primary, size: 16),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                replyText,
                                style: GoogleFonts.poppins(
                                  fontSize: 13, 
                                  color: BlushyColors.text, 
                                  fontStyle: FontStyle.italic,
                                  height: 1.4
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _beforeYouGoSelectedIndex = null;
                            _beforeYouGoController.clear();
                            _beforeYouGoSubmitted = false;
                          });
                        },
                        child: Text(
                          "Answer again",
                          style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBranchSwitcher(BlushyOSState state) => const SizedBox.shrink();

  Widget _buildMilestoneRow(String title, String subtitle, bool isDone, bool isCurrent, bool hasConnector) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? BlushyColors.success : (isCurrent ? BlushyColors.primary : BlushyColors.disabled.withOpacity(0.3)),
          ),
          child: Icon(
            isDone ? Icons.check : (isCurrent ? Icons.play_arrow : Icons.lock_outline),
            size: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? BlushyColors.text : BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isCurrent ? BlushyColors.primary : BlushyColors.disabled,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineLine(bool isActive) {
    return Container(
      margin: const EdgeInsets.only(left: 13, top: 4, bottom: 4),
      width: 2,
      height: 24,
      color: isActive ? BlushyColors.success : BlushyColors.disabled.withOpacity(0.2),
    );
  }

  // --- EDITORIAL COMPOSTIONS ---

  Widget _buildFirstPeriodHeroCard(Map<String, dynamic> data, PersonalContext pc) {
    final int cycleDay = pc.cycleDay ?? 0;

    String phaseName = "Follicular Phase";
    String friendlyExplain = "";
    String todayFocus = "";
    int activePhaseIndex = 0; // 0: Period, 1: Follicular, 2: Ovulation, 3: Luteal
    IconData phaseIcon = Icons.spa_rounded;
    
    if (cycleDay <= 5) {
      phaseName = "Period Phase";
      friendlyExplain = "Your body is letting go of the old lining. Many people notice lower energy or cramps during this phase. That's completely normal.";
      todayFocus = "Rest • Hydration • Comfort";
      activePhaseIndex = 0;
      phaseIcon = Icons.water_drop_rounded;
    } else if (cycleDay <= 11) {
      phaseName = "Follicular Phase";
      friendlyExplain = "Your body is recovering after your period and preparing for ovulation. Some people notice more energy during this phase.";
      todayFocus = "Hydration • Movement • Energy";
      activePhaseIndex = 1;
      phaseIcon = Icons.eco_rounded;
    } else if (cycleDay <= 16) {
      phaseName = "Ovulation Phase";
      friendlyExplain = "Your body is releasing an egg. You may feel more social or energetic this week. Listen to your body's rhythm.";
      todayFocus = "Socializing • Activity • Vitality";
      activePhaseIndex = 2;
      phaseIcon = Icons.wb_sunny_rounded;
    } else {
      phaseName = "Luteal Phase";
      friendlyExplain = "Your body is winding down. Be extra gentle with yourself. You might notice mood changes or feeling more emotional.";
      todayFocus = "Extra Sleep • Warmth • Quiet Time";
      activePhaseIndex = 3;
      phaseIcon = Icons.nights_stay_rounded;
    }

    String confidenceText = "";
    if (pc.confidence == DataConfidence.low) {
      confidenceText = "We're just getting to know your cycle.";
    } else if (pc.confidence == DataConfidence.medium) {
      confidenceText = "We're beginning to recognise your body's rhythm.";
    } else {
      confidenceText = "Your predictions are now based on your personal cycle history and will continue adapting over time.";
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border),
        boxShadow: [
          BoxShadow(
            color: BlushyColors.dark.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Cycle Day $cycleDay",
                style: BlushyTypography.displayL(color: BlushyColors.text),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BlushyColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Day $cycleDay/28",
                  style: BlushyTypography.chipLabel(color: BlushyColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(phaseIcon, size: 16, color: BlushyColors.primary),
              const SizedBox(width: 6),
              Text(
                phaseName,
                style: BlushyTypography.caption(color: BlushyColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "\"$friendlyExplain\"",
            style: BlushyTypography.bodyLarge(color: BlushyColors.text).copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF6F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 16, color: BlushyColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Today's Focus: $todayFocus",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
           const SizedBox(height: 28),
           const Center(
             child: SizedBox(
               width: 260,
               height: 95,
               child: BlushyCycleCard(purePainterMode: true),
             ),
           ),
           const SizedBox(height: 12),
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               _buildStartedLegendDot("Menstrual", const Color(0xFFDD0D22)),
               const SizedBox(width: 14),
               _buildStartedLegendDot("Follicular", const Color(0xFFFF9B9E)),
               const SizedBox(width: 14),
               _buildStartedLegendDot("Ovulation", const Color(0xFFFFB800)),
               const SizedBox(width: 14),
               _buildStartedLegendDot("Luteal", const Color(0xFFFF6B6C)),
             ],
           ),
          const SizedBox(height: 20),
          const Divider(color: BlushyColors.border),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: BlushyColors.secondaryText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  confidenceText,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: BlushyColors.secondaryText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressPhaseNode(String name, bool isActive) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? BlushyColors.primary : BlushyColors.disabled.withOpacity(0.3),
            shape: BoxShape.circle,
            border: isActive ? Border.all(color: Colors.white, width: 2) : null,
            boxShadow: isActive ? [BoxShadow(color: BlushyColors.primary.withOpacity(0.4), blurRadius: 6)] : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? BlushyColors.primary : BlushyColors.secondaryText.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressArrow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Icon(Icons.chevron_right_rounded, size: 12, color: BlushyColors.disabled.withOpacity(0.3)),
    );
  }

  Widget _buildForwardTimeline(PersonalContext pc) {
    if (pc.lastPeriodStart == null) return const SizedBox.shrink();

    final prevStart = pc.lastPeriodStart!;
    final prevStartStr = "${prevStart.day}/${prevStart.month}/${prevStart.year}";
    final expectedNext = prevStart.add(const Duration(days: 28));
    final expectedNextStr = "${expectedNext.day}/${expectedNext.month}/${expectedNext.year}";

    final int cycleDay = pc.cycleDay ?? 0;

    final steps = [
      {"label": "Last Period", "desc": "Started on $prevStartStr", "icon": Icons.check_circle_rounded, "color": BlushyColors.success},
      {"label": "Today", "desc": "Cycle Day $cycleDay of your rhythm", "icon": Icons.adjust_rounded, "color": BlushyColors.primary},
      {"label": "Estimated Ovulation Window", "desc": "Approx. Day 13-15 of cycle", "icon": Icons.help_outline_rounded, "color": BlushyColors.warning},
      {"label": "Estimated Next Period", "desc": "Approx. around $expectedNextStr", "icon": Icons.calendar_month_rounded, "color": BlushyColors.primary.withOpacity(0.5)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timeline_rounded, color: BlushyColors.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              "LOOK AHEAD TIMELINE",
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Your Upcoming Cycle Path",
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "We're still learning your unique cycle. Predictions will become more personalised as you continue tracking. Never present predictions as certainty.",
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: BlushyColors.secondaryText,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: BlushyColors.dark.withOpacity(0.02),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: List.generate(steps.length, (index) {
              final step = steps[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(step['icon'] as IconData, size: 18, color: step['color'] as Color),
                      if (index < steps.length - 1)
                        Container(
                          width: 2,
                          height: 36,
                          color: BlushyColors.border,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step['label'] as String,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            step['desc'] as String,
                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  Widget _buildFirstPeriodJourneyChecklist(Map<String, dynamic> data, [PersonalContext? pc]) {
    if (pc != null && pc.lastPeriodStart != null) {
      final prevStart = pc.lastPeriodStart!;
      final prevStartStr = "${prevStart.day}/${prevStart.month}/${prevStart.year}";
      final expectedNext = prevStart.add(const Duration(days: 28));
      final expectedNextStr = "${expectedNext.day}/${expectedNext.month}/${expectedNext.year}";

      final int cycleDay = pc.cycleDay ?? 0;

      final steps = [
        {"label": "Previous Period", "desc": "Started on $prevStartStr", "icon": Icons.check_circle_rounded, "color": BlushyColors.success},
        {"label": "Today", "desc": "Cycle Day $cycleDay of your rhythm", "icon": Icons.lens, "color": BlushyColors.primary},
        {"label": "Estimated Ovulation Window", "desc": "We're still learning your cycle. These dates are gentle estimates and will become more personalised over time.", "icon": Icons.help_outline_rounded, "color": BlushyColors.warning},
        {"label": "Expected Next Period", "desc": "Approx. around $expectedNextStr", "icon": Icons.calendar_today_rounded, "color": BlushyColors.primary.withOpacity(0.5)},
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            " My Cycle Timeline",
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Here is a forward-looking view of your cycle rhythm.",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: BlushyColors.secondaryText,
            ),
          ),
          const SizedBox(height: 24),
          ...steps.map((step) {
            final isToday = step['label'] == 'Today';
            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(step['icon'] as IconData, color: step['color'] as Color, size: isToday ? 18 : 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['label'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step['desc'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: BlushyColors.secondaryText,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
          const Divider(color: Color(0x1F2E2623), thickness: 1),
        ],
      );
    }

    final List<dynamic> items = data['journeySteps'] ?? [];
    final bool hasStarted = data['hasStarted'] == true;
    final String title = hasStarted ? " My First Cycle Timeline" : " Learning About My Body";
    final String subtitle = hasStarted 
        ? "Here is a simplified view of your body's natural rhythm." 
        : "You're building confidence one step at a time.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 24),
        ...items.map((item) {
          final bool isDone = item['done'] == true;
          final bool isLocked = item['locked'] == true;
          final bool isCurrent = item['current'] == true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isDone 
                      ? Icons.check_circle_rounded 
                      : (isLocked ? Icons.lock_outline_rounded : Icons.radio_button_unchecked_rounded),
                  color: isDone 
                      ? BlushyColors.success 
                      : (isLocked ? BlushyColors.secondaryText.withOpacity(0.3) : BlushyColors.primary),
                  size: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Opacity(
                    opacity: isLocked ? 0.5 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? "",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? BlushyColors.primary : BlushyColors.text,
                            decoration: (isDone && !hasStarted) ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (isLocked)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "Locked until you start your period",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: BlushyColors.secondaryText.withOpacity(0.6),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (isCurrent && hasStarted)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "Your body is recovering and returning to its baseline state.",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: BlushyColors.secondaryText,
                              ),
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
        if (!hasStarted) ...[
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showFirstPeriodTransition = true;
                });
              },
              icon: const Icon(Icons.favorite_rounded, size: 18),
              label: const Text("Log My First Period"),
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  // 1. Sia's Letter (Handwritten letter effect, no box container)
  Widget _buildSiaLetterSection(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: BlushyColors.primary, size: 14),
            const SizedBox(width: 8),
            Text(
              "SIA'S PERSONAL NOTE",
              style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "\"${data['siaNote'] ?? 'I know growing up can feel confusing sometimes. You don\'t have to figure everything out alone.'}\"",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: BlushyColors.text,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.bottomRight,
          child: Text(
            "— Love, Sia",
            style: GoogleFonts.poppins(
              fontSize: 16, 
              fontWeight: FontWeight.bold, 
              fontStyle: FontStyle.italic, 
              color: BlushyColors.primary
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  // 2. Because You Shared (Split layout, vertical divider, no box container)
  Widget _buildRelationalSplitSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "BECAUSE YOU SHARED",
                style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.secondary, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                "PE class felt a bit awkward last week",
                style: GoogleFonts.poppins(
                  fontSize: 18, 
                  fontWeight: FontWeight.w600, 
                  color: BlushyColors.text, 
                  height: 1.2
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 50,
          width: 1,
          color: const Color(0x1F2E2623),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: () {},
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SIA'S RECOMMENDATION",
                  style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.secondaryText, letterSpacing: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  "How to manage cramps and sports at school",
                  style: GoogleFonts.poppins(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold, 
                    color: BlushyColors.primary, 
                    decoration: TextDecoration.underline
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 3. Today's Discovery (Curated learning topic card with reading metadata and progress bar)
  Widget _buildForYouMagazineSection(Map<String, dynamic> data) {
    final discovery = data['discovery'] ?? {};
    final String title = discovery['title'] ?? "Why do periods happen?";
    final String type = discovery['type'] ?? "GUIDE";
    final String readTime = discovery['readTime'] ?? "4 min read";
    final double progress = discovery['completedRatio'] ?? 0.0;
    final String? usefulness = discovery['usefulness'] as String?;
    final bool isSaved = _savedArticles.contains(title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "FOR YOU",
              style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.warning, letterSpacing: 1.2),
            ),
            Row(
              children: [
                if (usefulness != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: BlushyColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      usefulness,
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.success),
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BlushyColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "$type • $readTime",
                    style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 28, 
            fontWeight: FontWeight.bold, 
            color: BlushyColors.text, 
            height: 1.15
          ),
        ),
        const SizedBox(height: 8),
        Text(
          discovery['desc'] ?? "",
          style: GoogleFonts.poppins(
            fontSize: 13, 
            color: BlushyColors.secondaryText, 
            height: 1.5
          ),
        ),
        if (progress > 0.0) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: BlushyColors.border,
                    color: BlushyColors.primary,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "${(progress * 100).toInt()}% read",
                style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Read Guide",
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: BlushyColors.primary),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: isSaved ? BlushyColors.primary : BlushyColors.secondaryText,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  if (isSaved) {
                    _savedArticles.remove(title);
                  } else {
                    _savedArticles.add(title);
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  // 3.5. Ask Sia (Conversational suggested prompts)
  Widget _buildAskSiaPromptSection(Map<String, dynamic> data) {
    final List<dynamic> suggestions = data['prompts'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ASK SIA",
          style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Text(
          "What are you wondering today?",
          style: GoogleFonts.poppins(
            fontSize: 26, 
            fontWeight: FontWeight.bold, 
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((s) => InkWell(
            onTap: () {
              // Switch navigation tab to Sia Screen
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Text(
                s as String,
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, fontWeight: FontWeight.w500),
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 18),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  // 4. Continue Creating (Polaroid style layout, warm background band)
  // 8. Daily Fun Fact (Did you know? postcard card layout)
  Widget _buildPolaroidScrapbookSection(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "DAILY FUN FACT",
          style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.info, letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          color: const Color(0xFFF3EAE0), // Warm beige postcard surface
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Did you know?",
                style: GoogleFonts.poppins(
                  fontSize: 26, 
                  fontWeight: FontWeight.bold, 
                  color: BlushyColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data['funFact'] ?? "The uterus is about the size of a small pear.",
                style: GoogleFonts.poppins(
                  fontSize: 22, 
                  fontStyle: FontStyle.italic,
                  color: BlushyColors.text,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "As you grow up, it gently changes and prepares to support your body's unique health journey.",
                style: GoogleFonts.poppins(
                  fontSize: 12, 
                  color: BlushyColors.secondaryText,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  // 5. Community Preview (First Period Circle questions preview)
  Widget _buildSubstackQuoteSection(Map<String, dynamic> data) {
    final List<dynamic> posts = data['communityPosts'] ?? [];
    final String stats = data['communityStats'] ?? "142 girls are learning together this week";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "COMMUNITY PREVIEW",
          style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Text(
          "First Period Circle",
          style: GoogleFonts.poppins(
            fontSize: 26, 
            fontWeight: FontWeight.bold, 
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          stats,
          style: GoogleFonts.poppins(
            fontSize: 12, 
            color: BlushyColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...posts.map((post) => Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BlushyColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.forum_outlined, size: 14, color: BlushyColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  post['text'] ?? "",
                  style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        )).toList(),
        const SizedBox(height: 12),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  // 9. Explore More / Growing with Confidence (Educational recommendations or milestone progress tracker)
  Widget _buildDiscoverEditorialSection(Map<String, dynamic> data) {
    final bool hasStarted = data['hasStarted'] == true;

    if (hasStarted) {
      final List<dynamic> confidenceSteps = data['confidenceJourney'] ?? [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "GROWING WITH CONFIDENCE",
            style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            "Your Confidence Journey",
            style: GoogleFonts.poppins(
              fontSize: 26, 
              fontWeight: FontWeight.bold, 
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: confidenceSteps.length,
            itemBuilder: (context, index) {
              final step = confidenceSteps[index];
              final bool isDone = step['done'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isDone ? BlushyColors.success : BlushyColors.secondaryText.withOpacity(0.4),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      step['title'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDone ? BlushyColors.text : BlushyColors.text.withOpacity(0.6),
                        fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
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

    final topics = [
      "Preparing for Your First Period",
      "Body Confidence",
      "Hygiene Basics",
      "School & Sports",
      "Healthy Habits",
      "Growing Up",
      "Friendships",
      "Nutrition",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "EXPLORE MORE",
          style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Text(
          "Guides for growing up",
          style: GoogleFonts.poppins(
            fontSize: 26, 
            fontWeight: FontWeight.bold, 
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: topics.length,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Center(
                child: Text(
                  topics[index],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12, 
                    fontWeight: FontWeight.w600, 
                    color: BlushyColors.text,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 7. Mini Journal (Embedded M Studio prompts, no emojis, enhanced elements)
  Widget _buildGentleReflectSection(Map<String, dynamic> data) {
    final bool hasStarted = data['hasStarted'] == true;
    final feelings = hasStarted 
        ? [
            {'label': 'Happy', 'color': BlushyColors.warning},
            {'label': 'Confident', 'color': BlushyColors.success},
            {'label': 'Nervous', 'color': BlushyColors.secondary},
            {'label': 'Tired', 'color': BlushyColors.info},
            {'label': 'Crampy', 'color': BlushyColors.danger},
          ]
        : [
            {'label': 'Happy', 'color': BlushyColors.warning},
            {'label': 'Curious', 'color': BlushyColors.info},
            {'label': 'Nervous', 'color': BlushyColors.secondary},
            {'label': 'Excited', 'color': BlushyColors.info},
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "M STUDIO",
          style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.secondaryText, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Text(
          "How are you feeling today?",
          style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: feelings.map((f) {
            final isSelected = _selectedFeeling == f['label'];
            final col = f['color'] as Color;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedFeeling = f['label'] as String;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? col.withOpacity(0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? col : BlushyColors.border),
                ),
                child: Text(
                  f['label'] as String,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: BlushyColors.text),
                ),
              ),
            );
          }).toList(),
        ),
        if (hasStarted) ...[
          const SizedBox(height: 18),
          Text(
            "Any symptoms today?",
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['None', 'Cramps', 'Headache', 'Bloating', 'Backache'].map((symptom) {
              final isSel = _selectedSymptom == symptom;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedSymptom = symptom;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? BlushyColors.primary.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? BlushyColors.primary : BlushyColors.border),
                  ),
                  child: Text(
                    symptom,
                    style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.text),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Text(
            "Energy level",
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['Low', 'Medium', 'High'].map((energy) {
              final isSel = _selectedEnergy == energy;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedEnergy = energy;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? BlushyColors.primary.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? BlushyColors.primary : BlushyColors.border),
                  ),
                  child: Text(
                    energy,
                    style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.text),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 18),
        // One sentence record input
        TextField(
          style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text),
          decoration: InputDecoration(
            hintText: "Write one sentence about today...",
            hintStyle: GoogleFonts.poppins(color: BlushyColors.secondaryText.withOpacity(0.5), fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BlushyColors.border)),
          ),
          onChanged: (val) {
            _journalSentence = val.trim();
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isDrawingMode = !_isDrawingMode;
                });
              },
              icon: Icon(Icons.gesture_rounded, size: 16, color: _isDrawingMode ? BlushyColors.primary : BlushyColors.secondaryText),
              label: Text("Sketch", style: GoogleFonts.poppins(fontSize: 11, color: _isDrawingMode ? BlushyColors.primary : BlushyColors.secondaryText)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _isDrawingMode ? BlushyColors.primary : BlushyColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Voice note recording is a mock placeholder")),
                );
              },
              icon: const Icon(Icons.mic_none_outlined, size: 16, color: BlushyColors.secondaryText),
              label: Text("Voice", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: BlushyColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        if (_isDrawingMode) ...[
          const SizedBox(height: 12),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BlushyColors.primary.withOpacity(0.5)),
            ),
            child: const Center(
              child: Text(
                "Drawing Canvas (Interactive Placeholder)",
                style: TextStyle(color: BlushyColors.secondaryText, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: BlushyColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              "Write More",
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  // --- MULTI-WIDGET ADAPTIVE RENDERER ---
  Widget _buildHomeWidget(
    HomeWidgetType type,
    BlushyOSState state,
    PersonalContext pc,
    bool isPregnancy,
    bool isPostpartum,
    bool isMenopause,
    bool hasPCOS,
    bool hasEndo,
    bool isTTC,
    bool trackingDisabled,
  ) {
    switch (type) {
      case HomeWidgetType.hero:
        return _buildHeroWidget(pc, isPregnancy, isPostpartum, isMenopause, hasPCOS, trackingDisabled);
      case HomeWidgetType.aiInsight:
        return _buildAiInsightWidget(state, pc);
      case HomeWidgetType.primaryAction:
        return _buildPrimaryActionWidget(pc);
      case HomeWidgetType.tracking:
        return _buildTrackingWidget(pc, isPregnancy, isPostpartum, hasPCOS, trackingDisabled);
      case HomeWidgetType.dailyChecklist:
        return _buildDailyChecklistWidget(isPregnancy, hasPCOS, isPostpartum, trackingDisabled);
      case HomeWidgetType.recommendations:
        return _buildRecommendationsWidget(isPregnancy, hasPCOS, isMenopause, trackingDisabled, pc);
      case HomeWidgetType.quickActions:
        return _buildQuickActionsWidget(isPregnancy, isPostpartum, hasEndo, trackingDisabled, pc);
      case HomeWidgetType.healthTimeline:
        return _buildHealthTimelineWidget(pc, state);
    }
  }

  // --- 1. HERO WIDGET ---
  Widget _buildHeroWidget(PersonalContext pc, bool isPregnancy, bool isPostpartum, bool isMenopause, bool hasPCOS, bool trackingDisabled) {
    String heading = "";
    String headline = "";
    String supporting = "";
    String actionLabel = "";
    IconData icon = Icons.info_outline;

    if (isPregnancy) {
      heading = "PREGNANCY STAGE";
      headline = "Week 24 Progress";
      supporting = "Your baby's hearing is developing this week. Sounds are beginning to register.";
      actionLabel = "See Today's Progress";
      icon = Icons.child_care_outlined;
    } else if (isPostpartum) {
      heading = "RECOVERY POSTPARTUM";
      headline = "Day 24 Healing Window";
      supporting = "Sleep recovery has improved this week. Physical healing markers remain stable.";
      actionLabel = "Log recovery symptoms";
      icon = Icons.healing_outlined;
    } else if (isMenopause) {
      heading = "MENOPAUSE WELLNESS";
      headline = "Stable Hot Flash Trends";
      supporting = "Bone density priorities and sleep recovery indicators remain high today.";
      actionLabel = "Track today's trend";
      icon = Icons.nights_stay_outlined;
    } else if (hasPCOS) {
      heading = "PCOS SUPPORT";
      headline = "Sleep improved by 18% this week";
      supporting = "Sia observed longer recovery segments, which may positively influence hormonal balance.";
      actionLabel = "View Insights";
      icon = Icons.monitor_heart_outlined;
    } else if (trackingDisabled) {
      heading = "WELLBEING BALANCE";
      headline = "Everyday Vitality Overview";
      supporting = "Your priorities are centered on better sleep, self-care, and stress management today.";
      actionLabel = "Start breathing session";
      icon = Icons.spa_outlined;
    } else {
      final String stageStr = _onboardingData['lifeStage'] ?? '';
      final bool isLivingWithCycle = stageStr == 'reproductiveYears';
      if (isLivingWithCycle) {
        final cData = _getPersonalizedBranchCData(pc);
        heading = cData['heroTitle'] ?? "AI DAILY BRIEF";
        headline = "You're entering ${cData['heroSub']}";
        supporting = cData['heroText'] ?? "";
        actionLabel = "View cycle analytics";
        icon = Icons.insights_outlined;
      } else {
        final phase = pc.cyclePhase ?? 'Follicular Phase';
        final day = pc.cycleDay ?? 0;
        heading = "CYCLE STATUS";
        headline = "$phase • Day $day";
        supporting = "Sia noticed you're entering your follicular phase. Today your physical energy may feel naturally higher.";
        actionLabel = "Log today's symptoms";
        icon = Icons.calendar_month_outlined;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x022E2623),
            blurRadius: 16,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BlushyColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                heading.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: BlushyColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            headline,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            supporting,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Starting context: $headline')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BlushyColors.primary.withOpacity(0.06),
              foregroundColor: BlushyColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. AI INSIGHT WIDGET ---
  Widget _buildAiInsightWidget(BlushyOSState state, PersonalContext pc) {
    final String stageStr = _onboardingData['lifeStage'] ?? '';
    final bool isLivingWithCycle = stageStr == 'reproductiveYears';

    String insightText = state.dynamicAiBriefingSummary;
    String headerLabel = "SIA'S PROACTIVE INSIGHT";
    
    if (isLivingWithCycle) {
      final cData = _getPersonalizedBranchCData(pc);
      insightText = cData['siaInsight'] ?? insightText;
      headerLabel = "SIA'S CYCLE INSIGHT";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_outlined, color: BlushyColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: BlushyColors.secondaryText,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  insightText,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: BlushyColors.text,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- 3. PRIMARY ACTION WIDGET ---
  Widget _buildPrimaryActionWidget(PersonalContext pc) {
    final String stageStr = _onboardingData['lifeStage'] ?? '';
    final bool isLivingWithCycle = stageStr == 'reproductiveYears';

    if (isLivingWithCycle) {
      final cData = _getPersonalizedBranchCData(pc);
      final focus = cData['focusTopic'] ?? {};
      final String focusTitle = focus['title'] ?? "Wellness Balance";
      final String focusDesc = focus['desc'] ?? "";
      final String focusType = focus['type'] ?? "MINDFULNESS";
      final String readTime = focus['readTime'] ?? "3 min read";

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: BlushyColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x022E2623),
              blurRadius: 16,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "WELLNESS FOCUS • $focusType",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: BlushyColors.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  readTime,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              focusTitle,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: BlushyColors.text,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              focusDesc,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: BlushyColors.secondaryText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: BlushyColors.primary,
                    padding: EdgeInsets.zero,
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Explore guidance",
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_border_rounded, color: BlushyColors.secondaryText, size: 20),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S ACTION",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: BlushyColors.secondaryText,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Track symptoms to refine predictions",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Adding sleep, mood, or energy signals helps Sia predict cycle phase variations safely.",
            style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText, height: 1.45),
          ),
        ],
      ),
    );
  }

  // --- 4. TRACKING WIDGET ---
  Widget _buildTrackingWidget(PersonalContext pc, bool isPregnancy, bool isPostpartum, bool hasPCOS, bool trackingDisabled) {
    final String stageStr = _onboardingData['lifeStage'] ?? '';
    final bool isLivingWithCycle = stageStr == 'reproductiveYears';

    if (isLivingWithCycle) {
      final cData = _getPersonalizedBranchCData(pc);
      final int cycleDay = cData['cycleDay'] ?? 0;
      
      int activeIndex = 0;
      String phaseTitle = "Transition";
      String explanation = "";
      String bodyChanges = "";
      String emotionalChanges = "";
      String energyExpect = "";
      String wellnessSug = "";
      String trendMessage = "";
      String predictionMsg = "";
      
      if (cycleDay <= 5) {
        activeIndex = 0;
        phaseTitle = "Period";
        explanation = "Your body is shedding the uterine lining. Estrogen and progesterone are at their lowest baseline.";
        bodyChanges = "You may notice mild cramps, lower back fatigue, or breast tenderness.";
        emotionalChanges = "Some people experience mood shifts or a natural desire for quiet reflection.";
        energyExpect = "Lower physical stamina. It is completely normal to need extra rest.";
        wellnessSug = "Prioritise hydration, sleep, warm compresses, and iron-rich foods.";
        trendMessage = "This cycle is tracking similarly to last month.";
        predictionMsg = "Period expected to end in ${6 - cycleDay} days.";
      } else if (cycleDay <= 12) {
        activeIndex = 1;
        phaseTitle = "Follicular";
        explanation = "Estrogen rises to rebuild energy, thicken the uterine lining, and prepare a new egg.";
        bodyChanges = "Stamina returns, skin feels clearer, and physical agility boosts.";
        emotionalChanges = "You may feel more motivated, focused, and creative.";
        energyExpect = "Physical energy naturally climbs to its baseline.";
        wellnessSug = "Great time to build fitness habits or start complex tasks.";
        trendMessage = "Your estrogen is rising smoothly, boosting focus.";
        predictionMsg = "Follicular peak expected in ${13 - cycleDay} days.";
      } else if (cycleDay <= 17) {
        activeIndex = 2;
        phaseTitle = "Transition";
        explanation = "Estrogen and testosterone levels peak. Your stamina is naturally at its highest.";
        bodyChanges = "High physical stamina and energy level baseline.";
        emotionalChanges = "Some people notice higher confidence, sociability, and brighter mood.";
        energyExpect = "Physical stamina and energy are at their peak.";
        wellnessSug = "Stay active, listen to your body, try strength workouts.";
        trendMessage = "Your cycle is tracking with high regularity.";
        predictionMsg = "Next period expected in ${29 - cycleDay} days.";
      } else {
        activeIndex = 3;
        phaseTitle = "Luteal";
        explanation = "Progesterone peaks to wind down the cycle. Physical systems prepare for rest or renewal.";
        bodyChanges = "Mild bloating, breast tenderness, appetite changes, or acne.";
        emotionalChanges = "Some people notice sensitivity, fatigue, or mood changes.";
        energyExpect = "Energy naturally winds down; sleep needs increase.";
        wellnessSug = "Prioritise gentle movement, stress reduction, and healthy nutrition.";
        trendMessage = "Your cycle appears slightly longer than usual (+1 day).";
        predictionMsg = "Period expected in ${29 - cycleDay} days.";
      }

      final phases = [
        {"name": "Period", "icon": ""},
        {"name": "Follicular", "icon": ""},
        {"name": "Transition", "icon": ""},
        {"name": "Luteal", "icon": ""},
      ];

      final String nextPeriodDaysText = cycleDay <= 5 ? "Active" : "${29 - cycleDay} days away";
      final String phaseIcon = phases[activeIndex]['icon']!;

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: BlushyColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x022E2623),
              blurRadius: 16,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CYCLE JOURNEY HEADER BLOCK
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Day $cycleDay",
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$phaseIcon $phaseTitle Phase",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BlushyColors.primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "NEXT PERIOD",
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: BlushyColors.secondaryText, letterSpacing: 0.8),
                    ),
                    Text(
                      nextPeriodDaysText,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "CYCLE CONFIDENCE: 98%",
                      style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w800, color: BlushyColors.primary, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 2. HORIZONTAL TIMELINE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(phases.length, (idx) {
                final item = phases[idx];
                final isActive = idx == activeIndex;
                return Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 2,
                              color: idx == 0
                                  ? Colors.transparent
                                  : (idx <= activeIndex
                                      ? BlushyColors.primary
                                      : BlushyColors.border),
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? BlushyColors.primary
                                  : BlushyColors.primary.withOpacity(0.06),
                              border: Border.all(
                                color: isActive
                                    ? BlushyColors.primary
                                    : BlushyColors.border,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                item['icon']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isActive ? Colors.white : null,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: idx == phases.length - 1
                                  ? Colors.transparent
                                  : (idx < activeIndex
                                      ? BlushyColors.primary
                                      : BlushyColors.border),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['name']!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                          color: isActive ? BlushyColors.primary : BlushyColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            
            // 3. PHASE OVERVIEW & INSIGHTS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BlushyColors.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Phase Overview",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    explanation,
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
                  ),
                  const Divider(height: 24, color: BlushyColors.border),
                  _buildDetailRow("Today's Body", bodyChanges),
                  const SizedBox(height: 12),
                  _buildDetailRow("Today's Mood", emotionalChanges),
                  const SizedBox(height: 12),
                  _buildDetailRow("Today's Focus", wellnessSug),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. AI PREDICTIONS PANEL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BlushyColors.primary.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insights_rounded, color: BlushyColors.primary, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          predictionMsg,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trendMessage,
                          style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. CYCLE HISTORY PANEL
            Text(
              "CYCLE HISTORY",
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: BlushyColors.secondaryText, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF6F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHistoryStat("Average Cycle", "29 days"),
                  _buildHistoryStat("Last Period", "June 28"),
                  _buildHistoryStat("Last Cycle", "30 days"),
                  _buildHistoryStat("Cycles Logged", "18"),
                ],
              ),
            ),
          ],
        ),
      );
    }

    String title = "Health Tracking";
    String subtitle = "";
    int value = 0;
    String label = "";

    if (isPregnancy) {
      title = "Pregnancy Progress";
      subtitle = "Weeks completed";
      value = 14;
      label = "40 weeks total";
    } else if (isPostpartum) {
      title = "Postpartum Recovery";
      subtitle = "Healing phase log status";
      value = 24;
      label = "Day 24 postpartum";
    } else {
      title = "Cycle Tracker";
      subtitle = "Days since last period";
      value = pc.cycleDay ?? 8;
      label = "Expected: ${pc.cycleLength ?? 28} days total";
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 8),
              Text(
                "$value Days",
                style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: BlushyColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
              ),
            ],
          ),
          const Icon(Icons.circle_outlined, color: BlushyColors.primary, size: 48),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: BlushyColors.primary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: BlushyColors.secondaryText,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryStat(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: BlushyColors.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
      ],
    );
  }

  // --- 5. DAILY CHECKLIST WIDGET ---
  Widget _buildDailyChecklistWidget(bool isPregnancy, bool hasPCOS, bool isPostpartum, bool trackingDisabled) {
    final List<String> tasks = [];
    if (isPregnancy) {
      tasks.addAll(['Prenatal vitamin supplement', 'Drink 8 glasses of water', '15 min pelvic stretching']);
    } else if (hasPCOS) {
      tasks.addAll(['Protein-rich breakfast', 'Spearmint wellness tea', 'Daily physical walk']);
    } else if (isPostpartum) {
      tasks.addAll(['Feed log update', 'Pelvic floor physical recovery', 'Nursing fluid tracking']);
    } else {
      tasks.addAll(['Log body signs', 'Fluid intake check-in', 'Evening screen-free session']);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "DAILY CHECKLIST",
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: BlushyColors.secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: BlushyColors.border),
            ),
            child: Column(
              children: tasks.map((task) {
                final isDone = _completedDailyTasks[task] ?? false;
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: BlushyColors.primary,
                  title: Text(
                    task,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDone ? BlushyColors.secondaryText : BlushyColors.text,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  value: isDone,
                  onChanged: (val) {
                    setState(() {
                      _completedDailyTasks[task] = val ?? false;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // --- 6. RECOMMENDATIONS WIDGET ---
  Widget _buildRecommendationsWidget(bool isPregnancy, bool hasPCOS, bool isMenopause, bool trackingDisabled, PersonalContext pc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "SIA'S RECOMMENDED ACTIONS",
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: BlushyColors.secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...dummyRecommendations.map((rec) {
          IconData categoryIcon;
          Color categoryColor;
          final cat = rec.category.toLowerCase();
          if (cat == 'energy') {
            categoryIcon = Icons.bolt_rounded;
            categoryColor = const Color(0xFFFF4A00);
          } else if (cat == 'nutrition') {
            categoryIcon = Icons.restaurant_rounded;
            categoryColor = const Color(0xFF8FAE8A);
          } else if (cat == 'sleep') {
            categoryIcon = Icons.bedtime_rounded;
            categoryColor = const Color(0xFF6F42F5);
          } else if (cat == 'mind') {
            categoryIcon = Icons.spa_rounded;
            categoryColor = const Color(0xFFFF9B9E);
          } else {
            categoryIcon = Icons.star_rounded;
            categoryColor = BlushyColors.primary;
          }

          final isHigh = rec.priority.toLowerCase() == 'high';

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BlushyColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x012E2623),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  )
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
                          Icon(categoryIcon, size: 14, color: categoryColor),
                          const SizedBox(width: 6),
                          Text(
                            rec.category.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: categoryColor,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isHigh ? const Color(0xFFFFEAE6) : BlushyColors.taupe,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${rec.priority.toUpperCase()} PRIORITY",
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: isHigh ? const Color(0xFFDD0D22) : BlushyColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    rec.title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rec.description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: BlushyColors.text.withOpacity(0.9),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Reason: ${rec.reason}",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: BlushyColors.secondaryText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Starting: ${rec.title}')),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: BlushyColors.primary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                        ),
                        child: Row(
                          children: [
                            Text(
                              rec.actionLabel,
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 12),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_border_rounded, size: 18, color: BlushyColors.secondaryText),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // --- 7. QUICK ACTIONS WIDGET ---
  Widget _buildQuickActionsWidget(bool isPregnancy, bool isPostpartum, bool hasEndo, bool trackingDisabled, PersonalContext pc) {
    final String stageStr = _onboardingData['lifeStage'] ?? '';
    final bool isLivingWithCycle = stageStr == 'reproductiveYears';

    if (isLivingWithCycle) {
      final cData = _getPersonalizedBranchCData(pc);
      return _buildAskSiaPromptSection(cData);
    }

    final List<Map<String, dynamic>> actions = [];

    if (isPregnancy) {
      actions.addAll([
        {'label': 'Log Kick Count', 'icon': Icons.child_care_outlined},
        {'label': 'Doctor Appointment', 'icon': Icons.calendar_today_outlined},
        {'label': 'Water Intake', 'icon': Icons.local_drink_outlined},
        {'label': 'Sia Chat', 'icon': Icons.chat_bubble_outline},
      ]);
    } else if (isPostpartum) {
      actions.addAll([
        {'label': 'Feed Log', 'icon': Icons.restaurant_outlined},
        {'label': 'Log Sleep', 'icon': Icons.hotel_outlined},
        {'label': 'Mood Check-in', 'icon': Icons.sentiment_satisfied_alt_outlined},
        {'label': 'Sia Chat', 'icon': Icons.chat_bubble_outline},
      ]);
    } else if (hasEndo) {
      actions.addAll([
        {'label': 'Log Pain Level', 'icon': Icons.healing_outlined},
        {'label': 'Log Symptoms', 'icon': Icons.add_box_outlined},
        {'label': 'Medication Log', 'icon': Icons.alarm_outlined},
        {'label': 'Sia Chat', 'icon': Icons.chat_bubble_outline},
      ]);
    } else {
      actions.addAll([
        {'label': 'Log Cycle', 'icon': Icons.calendar_today_outlined},
        {'label': 'Log Symptoms', 'icon': Icons.add_box_outlined},
        {'label': 'Mood Check-in', 'icon': Icons.sentiment_satisfied_alt_outlined},
        {'label': 'Sia Chat', 'icon': Icons.chat_bubble_outline},
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "QUICK ACTIONS",
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: BlushyColors.secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.3,
          ),
          itemBuilder: (context, idx) {
            final action = actions[idx];
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Logging action: ${action['label']}')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border),
                ),
                child: Row(
                  children: [
                    Icon(action['icon'] as IconData, color: BlushyColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        action['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.text,
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
    );
  }

  // --- 8. HEALTH TIMELINE WIDGET ---
  Widget _buildHealthTimelineWidget(PersonalContext pc, BlushyOSState state) {
    final String stageStr = _onboardingData['lifeStage'] ?? '';
    final bool isLivingWithCycle = stageStr == 'reproductiveYears';

    if (isLivingWithCycle) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: BlushyColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x022E2623),
              blurRadius: 16,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "QUICK CHECK-IN",
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: BlushyColors.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "How is your body feeling today?",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: BlushyColors.text,
              ),
            ),
            const SizedBox(height: 16),
            
            // Mood Selector
            Text("MOOD", style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: BlushyColors.secondaryText, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Calm', 'Happy', 'Focused', 'Tired', 'Sensitive'].map((m) {
                final isSel = _selectedFeeling == m;
                return ChoiceChip(
                  label: Text(m),
                  selected: isSel,
                  onSelected: (val) {
                    setState(() { _selectedFeeling = val ? m : null; });
                  },
                  backgroundColor: Colors.transparent,
                  selectedColor: BlushyColors.primary.withOpacity(0.12),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? BlushyColors.primary : BlushyColors.text,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSel ? BlushyColors.primary : BlushyColors.border),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Energy Selector
            Text("ENERGY LEVEL", style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: BlushyColors.secondaryText, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Row(
              children: ['Low', 'Medium', 'High'].map((lvl) {
                final isSel = _selectedEnergy == lvl;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(lvl),
                    selected: isSel,
                    onSelected: (val) {
                      setState(() { _selectedEnergy = val ? lvl : null; });
                    },
                    backgroundColor: Colors.transparent,
                    selectedColor: BlushyColors.primary.withOpacity(0.12),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? BlushyColors.primary : BlushyColors.text,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSel ? BlushyColors.primary : BlushyColors.border),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Symptoms Selector
            Text("SYMPTOMS", style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: BlushyColors.secondaryText, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['None', 'Cramps', 'Headache', 'Bloating', 'Acne', 'Appetite shifts'].map((s) {
                final isSel = _selectedSymptoms.contains(s);
                return FilterChip(
                  label: Text(s),
                  selected: isSel,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedSymptoms.add(s);
                      } else {
                        _selectedSymptoms.remove(s);
                      }
                    });
                  },
                  backgroundColor: Colors.transparent,
                  selectedColor: BlushyColors.primary.withOpacity(0.12),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? BlushyColors.primary : BlushyColors.text,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSel ? BlushyColors.primary : BlushyColors.border),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Stress Selector
            Text("STRESS", style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: BlushyColors.secondaryText, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Row(
              children: ['Low', 'Moderate', 'High'].map((lvl) {
                final isSel = _selectedStress == lvl;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(lvl),
                    selected: isSel,
                    onSelected: (val) {
                      setState(() { _selectedStress = val ? lvl : null; });
                    },
                    backgroundColor: Colors.transparent,
                    selectedColor: BlushyColors.primary.withOpacity(0.12),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? BlushyColors.primary : BlushyColors.text,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSel ? BlushyColors.primary : BlushyColors.border),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Sleep & Water
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SLEEP QUALITY", style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: BlushyColors.secondaryText, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedSleepQuality,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BlushyColors.border)),
                        ),
                        items: ['Restful', 'Interrupted', 'Short'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.poppins(fontSize: 12)))).toList(),
                        onChanged: (val) {
                          setState(() { _selectedSleepQuality = val; });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("WATER INTAKE", style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: BlushyColors.secondaryText, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedWaterIntake,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BlushyColors.border)),
                        ),
                        items: ['1 Litre', '2 Litres', '3 Litres'].map((w) => DropdownMenuItem(value: w, child: Text(w, style: GoogleFonts.poppins(fontSize: 12)))).toList(),
                        onChanged: (val) {
                          setState(() { _selectedWaterIntake = val; });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Quick check-in saved. Open M Studio for full journaling.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BlushyColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  "Save Entry",
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final List<Map<String, String>> events = [
      {'title': 'Supplements Configuration', 'subtitle': 'Custom supplements log created', 'time': 'Yesterday'},
    ];

    if (state.wellbeingState.symptoms.isNotEmpty) {
      events.add({
        'title': 'Symptoms Checked',
        'subtitle': 'Recorded: ${state.wellbeingState.symptoms.join(', ')}',
        'time': 'Today'
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "HEALTH TIMELINE",
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: BlushyColors.secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            separatorBuilder: (_, __) => const Divider(color: BlushyColors.border, height: 24),
            itemBuilder: (context, idx) {
              final ev = events[idx];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Icon(Icons.check_circle_outline, color: BlushyColors.primary, size: 16),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ev['title']!, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: BlushyColors.text)),
                        const SizedBox(height: 2),
                        Text(ev['subtitle']!, style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText)),
                      ],
                    ),
                  ),
                  Text(ev['time']!, style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // --- FEATURE COACH MARKS OVERLAY ---
  Widget _buildCoachMarksOverlay() {
    final steps = [
      {
        'title': 'Meet Sia',
        'desc': 'Tap here anytime to ask Sia a question.',
        'icon': Icons.auto_awesome,
      },
      {
        'title': 'M Studio',
        'desc': 'M Studio helps Sia understand your patterns over time.',
        'icon': Icons.book_outlined,
      },
      {
        'title': 'Insights',
        'desc': 'These recommendations become smarter as Blushy learns.',
        'icon': Icons.insights_outlined,
      },
      {
        'title': 'Community',
        'desc': 'Connect with women experiencing similar journeys.',
        'icon': Icons.people_outline,
      },
    ];

    final step = steps[_coachMarkStep];

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF6F0),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(step['icon'] as IconData, color: BlushyColors.primary, size: 48),
                    const SizedBox(height: 20),
                    Text(
                      step['title'] as String,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step['desc'] as String,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showCoachMarks = false;
                            });
                          },
                          child: Text(
                            "Skip",
                            style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (_coachMarkStep < steps.length - 1) {
                                _coachMarkStep++;
                              } else {
                                _showCoachMarks = false;
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BlushyColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            _coachMarkStep == steps.length - 1 ? "Done" : "Next",
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFirstPeriodMilestoneTransition(BlushyOSState state) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "",
                    style: TextStyle(fontSize: 72),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    " Congratulations!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "You started your first period.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: BlushyColors.primary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(28.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: BlushyColors.border, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: BlushyColors.dark.withOpacity(0.02),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "\"This is a special milestone.\n\nFrom today, Blushy will help you understand your own unique cycle.\n\nWe'll learn together, one step at a time.\"",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                            color: BlushyColors.text,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "— Sia",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            color: BlushyColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () {
                      try {
                        final currentData = BlushyStorage.read('onboarding_temp_profile.json');
                        if (currentData.isNotEmpty) {
                          final profile = currentData['profile'] ?? {};
                          profile['lifeStage'] = 'firstPeriodStarted';
                          currentData['profile'] = profile;
                          BlushyStorage.write('onboarding_temp_profile.json', currentData);
                        }
                      } catch (_) {}
                      setState(() {
                        _showFirstPeriodTransition = false;
                        _loadOnboardingData();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Welcome to the next chapter of your journey!")),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "Continue My Journey",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrowingTogetherSection(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_outline_rounded, color: BlushyColors.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              "GROWING TOGETHER",
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Involve a Trusted Adult",
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "We want you to feel supported. Here are gentle, safe ways to start conversations with people you trust. Personal journals and chats stay private.",
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: BlushyColors.secondaryText,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        ...[
          {"title": "How do I tell my mum?", "desc": "\"Hey mum, I think my body is changing and I want to talk about periods.\""},
          {"title": "How do I tell my dad?", "desc": "\"Dad, could we talk about some puberty changes? I might need some help picking out pads.\""},
          {"title": "How do I tell my guardian?", "desc": "\"I feel like I'm growing up and would love to prepare together for my first period.\""},
        ].map((starter) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BlushyColors.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  starter['title']!,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                ),
                const SizedBox(height: 6),
                Text(
                  starter['desc']!,
                  style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: BlushyColors.secondaryText),
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3EDE9), width: 0.8),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: BlushyColors.primary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "First Period Shopping Checklist",
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Pick out soft pads, comforting heat packs, and underwear together.",
                      style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Shopping Checklist"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSimpleCheckItem("Soft pads (regular/overnight)"),
                          _buildSimpleCheckItem("Spare cotton underwear"),
                          _buildSimpleCheckItem("Cycle carry pouch"),
                          _buildSimpleCheckItem("Comforting heat bottle or pad"),
                          _buildSimpleCheckItem("Gentle body wipes"),
                        ],
                      ),
                      alignment: Alignment.center,
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BlushyColors.secondaryText),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3EDE9), width: 0.8),
          ),
          child: Row(
            children: [
              const Icon(Icons.share_outlined, color: BlushyColors.primary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Share Preparing Together Guide",
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Send a reassuring puberty overview to a trusted adult.",
                      style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Preparing together guide shared (simulated). Personal notes were kept completely private.")),
                  );
                },
                icon: const Icon(Icons.send_rounded, size: 14, color: BlushyColors.secondaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  Widget _buildYourGrowingJourneySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.map_outlined, color: BlushyColors.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              "YOUR GROWING JOURNEY",
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.primary, letterSpacing: 1.2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Confidence & Learning",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: BlushyColors.text,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Every step builds confidence in listening to your body. Here is how far we've come together:",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: BlushyColors.secondaryText,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildJourneyStep("Logged First Period", true),
              _buildJourneyStep("Completed First Cycle", true),
              _buildJourneyStep("Logged First Symptoms", false),
              _buildJourneyStep("Learnt About Cycle Phases", false),
              _buildJourneyStep("Recognised First Pattern", false),
              _buildJourneyStep("Built Your Cycle Rhythm", false),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  Widget _buildJourneyStep(String title, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isCompleted ? BlushyColors.success : BlushyColors.disabled.withOpacity(0.5),
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
              color: isCompleted ? BlushyColors.text : BlushyColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCheckInComponent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.favorite_outline_rounded, color: BlushyColors.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              "TODAY'S CHECK-IN",
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.primary, letterSpacing: 1.2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "How am I feeling today?",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: BlushyColors.text,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Every update helps me understand your unique cycle a little better.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: BlushyColors.secondaryText,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Flow
              Text(
                "FLOW",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ["No Period", "Spotting", "Light", "Medium", "Heavy"].map((flow) {
                  final isSelected = _checkInFlow == flow;
                  return ChoiceChip(
                    label: Text(flow),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _checkInFlow = flow;
                        });
                      }
                    },
                    selectedColor: BlushyColors.primary.withOpacity(0.12),
                    backgroundColor: const Color(0xFFF9F6F0),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? BlushyColors.primary : BlushyColors.text,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 2. Symptoms
              Text(
                "SYMPTOMS",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ["Cramps", "Headache", "Acne", "Bloating", "Breast Tenderness", "Back Pain"].map((symptom) {
                  final isSelected = _checkInSymptoms.contains(symptom);
                  return FilterChip(
                    label: Text(symptom),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _checkInSymptoms.add(symptom);
                        } else {
                          _checkInSymptoms.remove(symptom);
                        }
                      });
                    },
                    selectedColor: BlushyColors.primary.withOpacity(0.12),
                    backgroundColor: const Color(0xFFF9F6F0),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? BlushyColors.primary : BlushyColors.text,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 3. Mood
              Text(
                "MOOD",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ["Calm", "Happy", "Emotional", "Irritated", "Anxious", "Tired"].map((mood) {
                  final isSelected = _checkInMood == mood;
                  return ChoiceChip(
                    label: Text(mood),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _checkInMood = mood;
                        });
                      }
                    },
                    selectedColor: BlushyColors.primary.withOpacity(0.12),
                    backgroundColor: const Color(0xFFF9F6F0),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? BlushyColors.primary : BlushyColors.text,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 4. Energy
              Text(
                "ENERGY",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ["Very Low", "Low", "Balanced", "High", "Very High"].map((energy) {
                  final isSelected = _checkInEnergy == energy;
                  return ChoiceChip(
                    label: Text(energy),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _checkInEnergy = energy;
                        });
                      }
                    },
                    selectedColor: BlushyColors.primary.withOpacity(0.12),
                    backgroundColor: const Color(0xFFF9F6F0),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? BlushyColors.primary : BlushyColors.text,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Save CTA
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() {
                      _checkInSaved = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Today's check-in saved securely!")),
                    );
                  },
                  child: Text(
                    "Save Today's Check-in",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              if (_checkInSaved) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BlushyColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BlushyColors.success.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.favorite_rounded, color: BlushyColors.success, size: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Thanks for checking in today. Every update helps me understand your unique cycle a little better.",
                          style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  Widget _buildSimpleCheckItem(String text) {
    bool checked = false;
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return CheckboxListTile(
          value: checked,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: BlushyColors.primary,
          title: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text)),
          onChanged: (val) {
            setLocalState(() {
              checked = val ?? false;
            });
          },
        );
      }
    );
  }

  Widget _buildCommunityAndMStudioMergedSection(Map<String, dynamic> data) {
    final List<dynamic> posts = data['communityPosts'] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.spa_rounded, color: BlushyColors.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              "COMMUNITY & M STUDIO",
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Our Shared Circle",
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Reflect on your day or read reassurance stories from other girls growing up.",
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: BlushyColors.secondaryText,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        if (posts.isNotEmpty) ...[
          Text(
            "COMMUNITY WISDOM",
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          ...posts.map((post) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFBFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF3EDE9), width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['text'] ?? "",
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "— ${post['user'] ?? 'Anonymous'}",
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
        ],
        Text(
          "MY DAILY REFLECTION",
          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        Text(
          "How are you feeling today?",
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            {'label': ' Happy', 'color': BlushyColors.warning},
            {'label': ' Curious', 'color': BlushyColors.info},
            {'label': ' Nervous', 'color': BlushyColors.secondary},
            {'label': ' Excited', 'color': BlushyColors.info},
          ].map((f) {
            final isSelected = _selectedFeeling == f['label'];
            final col = f['color'] as Color;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedFeeling = f['label'] as String;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? col.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? col : BlushyColors.border),
                ),
                child: Text(
                  f['label'] as String,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: BlushyColors.text),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
          decoration: InputDecoration(
            hintText: "Jot down a quick thought or creative sketch...",
            hintStyle: GoogleFonts.poppins(color: BlushyColors.secondaryText.withOpacity(0.5), fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BlushyColors.border)),
          ),
          onChanged: (val) {
            _journalSentence = val.trim();
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isDrawingMode = !_isDrawingMode;
                });
              },
              icon: Icon(Icons.gesture_rounded, size: 14, color: _isDrawingMode ? BlushyColors.primary : BlushyColors.secondaryText),
              label: Text("Sketch", style: GoogleFonts.poppins(fontSize: 11, color: _isDrawingMode ? BlushyColors.primary : BlushyColors.secondaryText)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _isDrawingMode ? BlushyColors.primary : BlushyColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                VoiceNoteBottomSheet.show(context);
              },
              icon: const Icon(Icons.mic_none_outlined, size: 14, color: BlushyColors.secondaryText),
              label: Text("Voice Note", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: BlushyColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Quick reflection saved to M Studio.")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text("Save", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (_isDrawingMode) ...[
          const SizedBox(height: 12),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BlushyColors.primary.withOpacity(0.5)),
            ),
            child: const Center(
              child: Text(
                "Drawing Canvas (Interactive)",
                style: TextStyle(color: BlushyColors.secondaryText, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  Widget _buildFirstPeriodWelcomeOnboardingCard(BlushyOSState state) {
    return Container(
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: BlushyColors.dark.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, size: 22, color: BlushyColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Let's Start Tracking Together",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: BlushyColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "\"Every body is different.\n\nTell me when your period started and I'll help you understand your own cycle.\n\nIf you're not sure, that's completely okay.\"",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    state.updatePersonalContext(
                      PersonalContext(
                        userName: state.personalContext.userName,
                        dateOfBirth: state.personalContext.dateOfBirth,
                        trackingPreference: state.personalContext.trackingPreference,
                        cyclePattern: state.personalContext.cyclePattern,
                        confidence: state.personalContext.confidence,
                        lifeContexts: state.personalContext.lifeContexts,
                        userGoals: state.personalContext.userGoals,
                        medicalConditions: state.personalContext.medicalConditions,
                        preferences: state.personalContext.preferences,
                        cycleLength: state.personalContext.cycleLength,
                        cycleDay: state.personalContext.cycleDay,
                        cyclePhase: state.personalContext.cyclePhase,
                        lastPeriodStart: pickedDate,
                        medications: state.personalContext.medications,
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("First period logged successfully!")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BlushyColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Log My First Period",
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Not sure of the date?"),
                      content: const Text(
                        "No worries! We can start tracking from today, or you can skip for now and set it later in settings.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            state.updatePersonalContext(
                              PersonalContext(
                                userName: state.personalContext.userName,
                                dateOfBirth: state.personalContext.dateOfBirth,
                                trackingPreference: state.personalContext.trackingPreference,
                                cyclePattern: state.personalContext.cyclePattern,
                                confidence: state.personalContext.confidence,
                                lifeContexts: state.personalContext.lifeContexts,
                                userGoals: state.personalContext.userGoals,
                                medicalConditions: state.personalContext.medicalConditions,
                                preferences: state.personalContext.preferences,
                                cycleLength: state.personalContext.cycleLength,
                                cycleDay: state.personalContext.cycleDay,
                                cyclePhase: state.personalContext.cyclePhase,
                                lastPeriodStart: DateTime.now(),
                                medications: state.personalContext.medications,
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Cycle started from today.")),
                            );
                          },
                          child: const Text("Start Today"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            state.updatePersonalContext(
                              PersonalContext(
                                userName: state.personalContext.userName,
                                dateOfBirth: state.personalContext.dateOfBirth,
                                trackingPreference: state.personalContext.trackingPreference,
                                cyclePattern: state.personalContext.cyclePattern,
                                confidence: state.personalContext.confidence,
                                lifeContexts: state.personalContext.lifeContexts,
                                userGoals: state.personalContext.userGoals,
                                medicalConditions: state.personalContext.medicalConditions,
                                preferences: state.personalContext.preferences,
                                cycleLength: state.personalContext.cycleLength,
                                cycleDay: state.personalContext.cycleDay,
                                cyclePhase: state.personalContext.cyclePhase,
                                lastPeriodStart: DateTime.now().subtract(const Duration(days: 7)),
                                medications: state.personalContext.medications,
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Skip layout. Setting approximate default starting date.")),
                            );
                          },
                          child: const Text("Skip for now"),
                        ),
                      ],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: BlushyColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "I'm Not Sure",
                  style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTalkToSiaSection(Map<String, dynamic> data, BlushyOSState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: BlushyColors.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              "TALK TO SIA",
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Talk to Sia",
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Ask Sia a question about growing up, write reflections, mood check-ins, quick notes, or creative prompts.",
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: BlushyColors.secondaryText,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: BlushyColors.dark.withOpacity(0.02),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Quick Prompts for Sia:",
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  "Why do I feel this way today?",
                  "Explain my cycle.",
                  "Is this symptom normal?",
                  "What should I expect next?",
                ].map((promptText) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedFeeling = promptText;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Sia: \"Let's talk about: $promptText\"")),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.help_outline_rounded, size: 14, color: BlushyColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            promptText,
                            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
                decoration: InputDecoration(
                  hintText: "Ask Sia anything, or write a quick journal reflection...",
                  hintStyle: GoogleFonts.poppins(color: BlushyColors.secondaryText.withOpacity(0.5), fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFFDFBFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BlushyColors.border)),
                ),
                onChanged: (val) {
                  _journalSentence = val.trim();
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isDrawingMode = !_isDrawingMode;
                      });
                    },
                    icon: Icon(Icons.gesture_rounded, size: 14, color: _isDrawingMode ? BlushyColors.primary : BlushyColors.secondaryText),
                    label: Text("Sketch", style: GoogleFonts.poppins(fontSize: 11, color: _isDrawingMode ? BlushyColors.primary : BlushyColors.secondaryText)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _isDrawingMode ? BlushyColors.primary : BlushyColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      VoiceNoteBottomSheet.show(context);
                    },
                    icon: const Icon(Icons.mic_none_outlined, size: 14, color: BlushyColors.secondaryText),
                    label: Text("Voice Note", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: BlushyColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Quick Note saved to M Studio space.")),
                      );
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 14, color: BlushyColors.secondaryText),
                    label: Text("Quick Note", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: BlushyColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Creative Prompt: 'Describe three things that make you feel comfy today.'")),
                      );
                    },
                    icon: const Icon(Icons.lightbulb_outline_rounded, size: 14, color: BlushyColors.secondaryText),
                    label: Text("Creative Prompts", style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: BlushyColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    if (_journalSentence.isEmpty) return;
                    final isQuestion = _journalSentence.endsWith('?') || _journalSentence.toLowerCase().contains('why') || _journalSentence.toLowerCase().contains('how');
                    if (isQuestion) {
                      state.setViewIndex(3);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Navigating to Talk to Sia...")),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Reflection saved to M Studio.")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text("Send / Save", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              if (_isDrawingMode) ...[
                const SizedBox(height: 12),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BlushyColors.primary.withOpacity(0.5)),
                  ),
                  child: const Center(
                    child: Text(
                      "Drawing Canvas (Interactive)",
                      style: TextStyle(color: BlushyColors.secondaryText, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }

  Widget _buildYourPatternsSection(PersonalContext pc) {
    final state = BlushyOSProvider.of(context);
    final symptoms = state.wellbeingState.symptoms;

    List<String> reflections = [];
    if (symptoms.contains('pain')) {
      reflections.add("• Your cramps usually peak on Day 2.");
    }
    if (symptoms.contains('low energy') || symptoms.contains('fatigue')) {
      reflections.add("• Your energy is usually highest during the follicular phase.");
    }
    if (symptoms.contains('poor sleep')) {
      reflections.add("• You tend to sleep less before your period.");
    }

    final hasData = reflections.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics_outlined, color: BlushyColors.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              "YOUR PATTERNS",
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Personalised reflections",
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Understand how your body's rhythm influences your daily wellbeing.",
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: BlushyColors.secondaryText,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasData) ...[
                Text(
                  "We're still gathering details to spot your patterns.",
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                ),
                const SizedBox(height: 8),
                Text(
                  "Symptom logs help Sia understand your body's rhythm. Once you log symptoms (like fatigue or cramps) in the developer panel, personalised reflections will appear here!",
                  style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.45),
                ),
              ] else ...[
                Text(
                  "Based on your recent logs:",
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                ),
                const SizedBox(height: 12),
                ...reflections.map((ref) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    ref,
                    style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, height: 1.4),
                  ),
                )),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0x1F2E2623), thickness: 1),
      ],
    );
  }
}

class DeveloperContextSimulator extends StatelessWidget {
  final Function(String)? onLifeStageChanged;
  const DeveloperContextSimulator({super.key, this.onLifeStageChanged});

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Developer Context Simulator",
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (onLifeStageChanged != null) ...[
              const Text("Simulate LifeStage / Branch", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  {'label': 'Branch A (Prep)', 'val': 'firstPeriodNotStarted'},
                  {'label': 'Branch B (Started)', 'val': 'firstPeriodStarted'},
                  {'label': 'Wellness (Default)', 'val': 'everydayWellness'},
                ].map((item) {
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close drawer
                      onLifeStageChanged!(item['val'] as String);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary.withOpacity(0.08),
                      foregroundColor: BlushyColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(item['label'] as String, style: const TextStyle(fontSize: 11)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close drawer
                    state.setOnboardingCompleted(false);
                    state.setAuthenticated(false);
                    state.updatePersonalContext(
                      PersonalContext(
                        userName: null,
                        dateOfBirth: null,
                        trackingPreference: CycleTrackingPreference.enabled,
                        cyclePattern: CyclePattern.predictable,
                        confidence: DataConfidence.medium,
                        lifeContexts: {},
                        userGoals: {},
                        medicalConditions: {},
                        preferences: UserPreferences(),
                        cycleLength: 28,
                        cycleDay: 1,
                        cyclePhase: "Follicular Phase",
                        lastPeriodStart: null,
                        medications: [],
                      ),
                    );
                    // Reset onboarding file to force wizard
                    BlushyStorage.write('onboarding_temp_profile.json', {});
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text("Reset to Onboarding Step", style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.danger.withOpacity(0.1),
                    foregroundColor: BlushyColors.danger,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const Divider(),
            ],
            _buildDropdown<CycleTrackingPreference>(
              "Tracking Preference",
              CycleTrackingPreference.values,
              state.personalContext.trackingPreference,
              (val) => state.setTrackingPreference(val!),
            ),
            _buildDropdown<CyclePattern>(
              "Cycle Pattern",
              CyclePattern.values,
              state.personalContext.cyclePattern,
              (val) => state.setCyclePattern(val!),
            ),
            _buildDropdown<DataConfidence>(
              "Data Confidence",
              DataConfidence.values,
              state.personalContext.confidence,
              (val) => state.setDataConfidence(val!),
            ),
            SwitchListTile(
              title: const Text("Period Active"),
              value: state.wellbeingState.periodActive,
              onChanged: (val) => state.setPeriodActive(val),
            ),
            const Divider(),
            const Text("Special Journeys / Stages", style: TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              title: const Text("First Periods Journey"),
              value: state.personalContext.medicalConditions.contains('First Periods'),
              onChanged: (val) {
                final conds = Set<String>.from(state.personalContext.medicalConditions);
                if (val == true) {
                  conds.add('First Periods');
                } else {
                  conds.remove('First Periods');
                }
                state.updatePersonalContext(
                  PersonalContext(
                    userName: state.personalContext.userName,
                    dateOfBirth: state.personalContext.dateOfBirth,
                    trackingPreference: state.personalContext.trackingPreference,
                    cyclePattern: state.personalContext.cyclePattern,
                    confidence: state.personalContext.confidence,
                    lifeContexts: state.personalContext.lifeContexts,
                    userGoals: state.personalContext.userGoals,
                    medicalConditions: conds,
                    preferences: state.personalContext.preferences,
                    cycleLength: state.personalContext.cycleLength,
                    cycleDay: state.personalContext.cycleDay,
                    cyclePhase: state.personalContext.cyclePhase,
                    lastPeriodStart: state.personalContext.lastPeriodStart,
                    medications: state.personalContext.medications,
                  ),
                );
              },
            ),
            const Divider(),
            const Text("Life Contexts", style: TextStyle(fontWeight: FontWeight.bold)),
            ...LifeContext.values.map((lc) => CheckboxListTile(
              title: Text(lc.name),
              value: state.personalContext.lifeContexts.contains(lc),
              onChanged: (val) => state.toggleLifeContext(lc),
            )),
            const Divider(),
            const Text("Symptoms", style: TextStyle(fontWeight: FontWeight.bold)),
            ...['fatigue', 'pain', 'poor sleep', 'low energy'].map((s) => CheckboxListTile(
              title: Text(s),
              value: state.wellbeingState.symptoms.contains(s),
              onChanged: (val) => state.toggleSymptom(s),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>(String label, List<T> items, T currentVal, ValueChanged<T?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          DropdownButton<T>(
            value: currentVal,
            isExpanded: true,
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toString().split('.').last))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class ArticleDetailDialog extends StatefulWidget {
  final String title;
  final String summary;

  const ArticleDetailDialog({
    super.key,
    required this.title,
    required this.summary,
  });

  @override
  State<ArticleDetailDialog> createState() => _ArticleDetailDialogState();
}

class _ArticleDetailDialogState extends State<ArticleDetailDialog> {
  bool _isLoading = false;
  String? _detailedContent;

  Future<void> _fetchDetailedAiExplanation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await ApiAuthService().getDetailedWebExplanation(widget.title, widget.summary);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _detailedContent = res.isNotEmpty
              ? res
              : _generateFallbackDetailedExplanation(widget.title, widget.summary);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _detailedContent = _generateFallbackDetailedExplanation(widget.title, widget.summary);
        });
      }
    }
  }

  String _generateFallbackDetailedExplanation(String title, String summary) {
    return "### Comprehensive AI & Web Search Synthesis: ${widget.title}\n\n"
        "**Biological & Physiological Overview**\n"
        "${widget.summary}\n\n"
        "Clinical wellness data shows that daily lifestyle habits directly influence neuroendocrine and autonomic nervous system regulation. "
        "Tracking your core metrics allows Sia AI to identify subtle hormonal and energy baseline fluctuations early.\n\n"
        "**Key Scientific Insights**\n"
        "• **Circadian & Metabolic Harmony**: Regular sleep and meal timing stabilize cortisol, preventing afternoon energy crashes.\n"
        "• **Vagal Tone & Stress Recovery**: Diaphragmatic breathing and hydration balance parasympathetic nervous system responses.\n"
        "• **Cycle Synergy**: Estrogen and progesterone transitions alter metabolic rate and hydration needs across cycle phases.\n\n"
        "**Actionable Recommendations**\n"
        "1. **Structured Routines**: Maintain consistent daily check-ins within your preferred morning or evening window.\n"
        "2. **Optimal Fluid Intake**: Hydrate continuously throughout high-activity or high-stress workdays.\n"
        "3. **Sia Companion Check-Ins**: Log daily symptoms to help Sia refine your dynamic health insights.";
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFAF6F0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary Box (Existing 2-3 lines)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.short_text_rounded, size: 16, color: BlushyColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          "SUMMARY OVERVIEW",
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: BlushyColors.primary, letterSpacing: 1.2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.summary,
                      style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // AI Detailed Explanation Section
              if (_detailedContent != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDFBF7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BlushyColors.primary.withOpacity(0.3), width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 16, color: BlushyColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            "AI WEB SEARCH DETAILED INSIGHTS",
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: BlushyColors.primary, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _detailedContent!,
                        style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, height: 1.55),
                      ),
                    ],
                  ),
                ),
              ] else if (_isLoading) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BlushyColors.border),
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: BlushyColors.primary, strokeWidth: 2.5),
                      const SizedBox(height: 16),
                      Text(
                        "Sia AI is searching the web and analyzing detailed insights for '${widget.title}'...",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _fetchDetailedAiExplanation,
                    icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                    label: Text(
                      "✨ Deep Dive with AI (Web Search)",
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Close",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: BlushyColors.primary),
          ),
        ),
      ],
    );
  }
}
