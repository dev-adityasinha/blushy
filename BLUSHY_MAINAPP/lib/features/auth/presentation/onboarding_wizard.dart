import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/storage.dart';
import '../../../core/state.dart';
import '../../../core/cycle_calculator.dart';
import '../../../theme/colors.dart';
import '../../../services/api_auth_service.dart';
import '../../legal/legal_documents_screen.dart';
import '../../../services/api_blushy_service.dart';
import '../../../l10n/app_localizations.dart';

// --- Onboarding Data Model ---
enum LifeStage {
  firstPeriodNotStarted,
  firstPeriodStarted,
  reproductiveYears,
  hormonalHealth,
  tryingToConceive,
  pregnancy,
  postpartum,
  perimenopause,
  menopause,
}

enum OnboardingPhase {
  privacy,
  questions,
  building,
  siaWelcome,
  ready,
}

class OnboardingProfile {
  String preferredName = '';
  DateTime? dateOfBirth;
  LifeStage? lifeStage;

  Map<String, dynamic> answers = {};
  List<String> goals = [];
  List<String> symptoms = [];
  List<String> conditions = [];

  DateTime? lastPeriod;
  List<DateTime> previousPeriods = [];
  DateTime? dueDate;
  DateTime? babyBirthDate;

  bool completed = false;

  OnboardingProfile();

  Map<String, dynamic> toJson() {
    return {
      'preferredName': preferredName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'lifeStage': lifeStage?.name,
      'answers': answers,
      'goals': goals,
      'symptoms': symptoms,
      'conditions': conditions,
      'lastPeriod': lastPeriod?.toIso8601String(),
      'previousPeriods': previousPeriods.map((p) => p.toIso8601String()).toList(),
      'dueDate': dueDate?.toIso8601String(),
      'babyBirthDate': babyBirthDate?.toIso8601String(),
      'completed': completed,
    };
  }

  static OnboardingProfile fromJson(Map<String, dynamic> json) {
    final profile = OnboardingProfile();
    profile.preferredName = json['preferredName'] ?? '';
    if (json['dateOfBirth'] != null) {
      profile.dateOfBirth = DateTime.tryParse(json['dateOfBirth']);
    }
    if (json['lifeStage'] != null) {
      profile.lifeStage = LifeStage.values.firstWhere(
        (e) => e.name == json['lifeStage'],
        orElse: () => LifeStage.reproductiveYears,
      );
    }
    profile.answers = Map<String, dynamic>.from(json['answers'] ?? {});
    profile.goals = List<String>.from(json['goals'] ?? []);
    profile.symptoms = List<String>.from(json['symptoms'] ?? []);
    profile.conditions = List<String>.from(json['conditions'] ?? []);
    if (json['lastPeriod'] != null) {
      profile.lastPeriod = DateTime.tryParse(json['lastPeriod']);
    }
    if (json['previousPeriods'] is List) {
      profile.previousPeriods = (json['previousPeriods'] as List)
          .map((p) => DateTime.tryParse(p.toString()))
          .whereType<DateTime>()
          .toList();
    }
    if (json['dueDate'] != null) {
      profile.dueDate = DateTime.tryParse(json['dueDate']);
    }
    if (json['babyBirthDate'] != null) {
      profile.babyBirthDate = DateTime.tryParse(json['babyBirthDate']);
    }
    profile.completed = json['completed'] ?? false;
    return profile;
  }
}

class OnboardingWizard extends StatefulWidget {
  const OnboardingWizard({super.key});

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> with TickerProviderStateMixin {
  final OnboardingProfile _profile = OnboardingProfile();
  OnboardingPhase _phase = OnboardingPhase.privacy;
  int _currentStepIndex = 0; // 0-indexed step representation for the questionnaire phase
  bool _isLoading = true;

  // Privacy Policy Acceptance Checkbox States
  bool _agreePrivacy = false;
  bool _agreeTerms = false;

  // Expansion state for "Why we're asking this"
  bool _whyAskingExpanded = false;

  // Name controller
  final TextEditingController _nameController = TextEditingController();

  // Question transitions state
  double _questionOpacity = 1.0;
  double _questionOffset = 0.0;
  bool _isTransitioning = false;

  // Animations for building phase
  double _buildingProgress = 0.0;
  final List<bool> _buildingChecks = [false, false, false, false, false, false];
  Timer? _buildingTimer;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _nameController.addListener(() {
      setState(() {
        _profile.preferredName = _nameController.text;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _buildingTimer?.cancel();
    super.dispose();
  }

  // Save and Load onboarding progress
  Future<void> _saveProgress() async {
    try {
      final data = {
        'profile': _profile.toJson(),
        'phase': _phase.name,
        'stepIndex': _currentStepIndex,
      };
      BlushyStorage.write('user_profile.json', data);
    } catch (_) {}
  }

  Future<void> _loadProgress() async {
    try {
      final decoded = BlushyStorage.read('user_profile.json');
      if (decoded.isNotEmpty) {
        final loadedProfile = OnboardingProfile.fromJson(decoded['profile'] ?? {});
        setState(() {
          _profile.preferredName = loadedProfile.preferredName;
          _profile.dateOfBirth = loadedProfile.dateOfBirth;
          _profile.lifeStage = loadedProfile.lifeStage;
          _profile.answers = loadedProfile.answers;
          _profile.goals = loadedProfile.goals;
          _profile.symptoms = loadedProfile.symptoms;
          _profile.conditions = loadedProfile.conditions;
          _profile.lastPeriod = loadedProfile.lastPeriod;
          _profile.previousPeriods = loadedProfile.previousPeriods;
          _profile.dueDate = loadedProfile.dueDate;
          _profile.babyBirthDate = loadedProfile.babyBirthDate;
          _profile.completed = loadedProfile.completed;
          
          _nameController.text = _profile.preferredName;
          _currentStepIndex = decoded['stepIndex'] ?? 0;
          if (decoded['phase'] != null) {
            _phase = OnboardingPhase.values.firstWhere((e) => e.name == decoded['phase'], orElse: () => OnboardingPhase.privacy);
          }
        });
      }
    } catch (_) {
    } finally {
      // Sync active onboarding questions schema from backend MongoDB
      ApiAuthService().getOnboardingQuestions(role: 'woman').then((remoteQuestions) {
        if (remoteQuestions.isNotEmpty && mounted) {
          debugPrint('BlushyBackend: Loaded ${remoteQuestions.length} onboarding questions from backend.');
        }
      }).catchError((_) {});

      setState(() {
        _isLoading = false;
      });
    }
  }

  // Staggered builder loader simulation
  void _startBuildingSimulation() {
    _buildingProgress = 0.0;
    for (int i = 0; i < _buildingChecks.length; i++) {
      _buildingChecks[i] = false;
    }
    
    const interval = Duration(milliseconds: 50);
    int elapsedMs = 0;
    const totalDurationMs = 3500;

    _buildingTimer = Timer.periodic(interval, (timer) {
      elapsedMs += 50;
      setState(() {
        _buildingProgress = (elapsedMs / totalDurationMs).clamp(0.0, 1.0);
        
        // Stagger checks completion
        if (elapsedMs >= 500) _buildingChecks[0] = true;
        if (elapsedMs >= 1000) _buildingChecks[1] = true;
        if (elapsedMs >= 1500) _buildingChecks[2] = true;
        if (elapsedMs >= 2000) _buildingChecks[3] = true;
        if (elapsedMs >= 2500) _buildingChecks[4] = true;
        if (elapsedMs >= 3000) _buildingChecks[5] = true;
      });

      if (elapsedMs >= totalDurationMs) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            _phase = OnboardingPhase.siaWelcome;
          });
          _saveProgress();
        });
      }
    });
  }

  // Dynamic step list builders
  List<Widget> _buildQuestionsSteps() {
    final List<Widget> steps = [
      _buildNameStep(), // Universal Step 1
      _buildDobStep(),  // Universal Step 2
      _buildStageStep(), // Universal Step 3
    ];

    if (_profile.lifeStage == null) return steps;

    switch (_profile.lifeStage!) {
      case LifeStage.firstPeriodNotStarted:
        steps.add(_buildNotStartedStep4());
        break;
      case LifeStage.firstPeriodStarted:
        steps.addAll([_buildStartedStep4(), _buildStartedStep5()]);
        break;
      case LifeStage.reproductiveYears:
        steps.addAll([
          _buildReproductiveStep4(),
          _buildReproductiveStep5(),
          _buildReproductiveStep6(),
          _buildReproductiveStep7(),
          _buildReproductiveStep8()
        ]);
        break;
      case LifeStage.hormonalHealth:
        steps.addAll([
          _buildHormonalStep4(),
          _buildHormonalStep5(),
          _buildHormonalStep6()
        ]);
        break;
      case LifeStage.tryingToConceive:
        steps.addAll([
          _buildTtcStep4(),
          _buildTtcStep5(),
          _buildTtcStep6(),
          _buildTtcStep7()
        ]);
        break;
      case LifeStage.pregnancy:
        steps.addAll([
          _buildPregnancyStep4(),
          _buildPregnancyStep5(),
          _buildPregnancyStep6()
        ]);
        break;
      case LifeStage.postpartum:
        steps.addAll([
          _buildPostpartumStep4(),
          _buildPostpartumStep5(),
          _buildPostpartumStep6(),
          _buildPostpartumStep7()
        ]);
        break;
      case LifeStage.perimenopause:
        steps.addAll([
          _buildPerimenopauseStep4(),
          _buildPerimenopauseStep5(),
          _buildPerimenopauseStep6()
        ]);
        break;
      case LifeStage.menopause:
        steps.addAll([
          _buildMenopauseStep4(),
          _buildMenopauseStep5(),
          _buildMenopauseStep6()
        ]);
        break;
    }

    return steps;
  }

  bool _isStepInputValid() {
    if (_currentStepIndex == 0) return _profile.preferredName.trim().isNotEmpty;
    if (_currentStepIndex == 1) return _profile.dateOfBirth != null;
    if (_currentStepIndex == 2) return _profile.lifeStage != null;

    final stage = _profile.lifeStage;
    if (stage == null) return false;

    final branchStep = _currentStepIndex - 3;

    if (stage == LifeStage.firstPeriodNotStarted) {
      if (branchStep == 0) return _profile.answers['not_started_learn'] != null;
    }
    if (stage == LifeStage.firstPeriodStarted) {
      if (branchStep == 0) return _profile.answers['first_period_start_time'] != null;
      if (branchStep == 1) return _profile.goals.isNotEmpty;
    }
    if (stage == LifeStage.reproductiveYears) {
      if (branchStep == 0) return _profile.answers['reproductive_cycle_type'] != null;
      if (branchStep == 1) return _profile.lastPeriod != null || _profile.answers['last_period_unknown'] == true;
      if (branchStep == 2) return _profile.goals.isNotEmpty;
      if (branchStep == 3) return _profile.answers['contraception_choice'] != null;
      if (branchStep == 4) return _profile.symptoms.isNotEmpty;
    }
    if (stage == LifeStage.hormonalHealth) {
      if (branchStep == 0) return _profile.conditions.isNotEmpty;
      if (branchStep == 1) return _profile.symptoms.isNotEmpty;
      if (branchStep == 2) return _profile.answers['hormonal_treatment'] != null;
    }
    if (stage == LifeStage.tryingToConceive) {
      if (branchStep == 0) return _profile.answers['ttc_duration'] != null;
      if (branchStep == 1) return _profile.answers['ttc_tracking_method'] != null;
      if (branchStep == 2) return _profile.answers['ttc_treatment'] != null;
      if (branchStep == 3) return _profile.symptoms.isNotEmpty;
    }
    if (stage == LifeStage.pregnancy) {
      if (branchStep == 0) return _profile.dueDate != null;
      if (branchStep == 1) return _profile.answers['pregnancy_first'] != null;
      if (branchStep == 2) return _profile.goals.isNotEmpty;
    }
    if (stage == LifeStage.postpartum) {
      if (branchStep == 0) return _profile.babyBirthDate != null;
      if (branchStep == 1) return _profile.answers['postpartum_feeding'] != null;
      if (branchStep == 2) return _profile.goals.isNotEmpty;
      if (branchStep == 3) return _profile.symptoms.isNotEmpty;
    }
    if (stage == LifeStage.perimenopause) {
      if (branchStep == 0) return _profile.answers['perimenopause_cycle_change'] != null;
      if (branchStep == 1) return _profile.symptoms.isNotEmpty;
      if (branchStep == 2) return _profile.goals.isNotEmpty;
    }
    if (stage == LifeStage.menopause) {
      if (branchStep == 0) return _profile.answers['menopause_duration'] != null;
      if (branchStep == 1) return _profile.symptoms.isNotEmpty;
      if (branchStep == 2) return _profile.goals.isNotEmpty;
    }

    return true;
  }

  void _nextQuestion() {
    if (_isTransitioning) return;
    final questions = _buildQuestionsSteps();
    
    if (_currentStepIndex < questions.length - 1) {
      setState(() {
        _isTransitioning = true;
        _questionOpacity = 0.0;
        _questionOffset = -15.0;
      });
      
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _currentStepIndex++;
          _whyAskingExpanded = false;
          _questionOffset = 15.0;
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _questionOpacity = 1.0;
            _questionOffset = 0.0;
            _isTransitioning = false;
          });
        });
        _saveProgress();
      });
    } else {
      setState(() {
        _phase = OnboardingPhase.building;
      });
      _startBuildingSimulation();
      _saveProgress();
    }
  }

  void _backQuestion() {
    if (_isTransitioning) return;
    if (_currentStepIndex > 0) {
      setState(() {
        _isTransitioning = true;
        _questionOpacity = 0.0;
        _questionOffset = 15.0;
      });
      
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _currentStepIndex--;
          _whyAskingExpanded = false;
          _questionOffset = -15.0;
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _questionOpacity = 1.0;
            _questionOffset = 0.0;
            _isTransitioning = false;
          });
        });
        _saveProgress();
      });
    } else {
      setState(() {
        _phase = OnboardingPhase.privacy;
      });
      _saveProgress();
    }
  }

  void _finishOnboarding() {
    setState(() {
      _profile.completed = true;
    });
    
    // Save locally
    try {
      final data = {
        'profile': _profile.toJson(),
        'phase': _phase.name,
        'stepIndex': _currentStepIndex,
      };
      BlushyStorage.write('user_profile.json', data);
    } catch (_) {}

    // Send onboarding questions & answers directly to BLUSHY_MAINAPP/backend
    final String chosenStage = _profile.lifeStage?.name ?? 'reproductiveYears';

    final Map<String, dynamic> backendAnswers = {
      'preferred_name': _profile.preferredName.trim(),
      'date_of_birth': _profile.dateOfBirth != null
          ? _profile.dateOfBirth!.toIso8601String().split('T').first
          : '2000-01-01',
      'life_stage': chosenStage,
      'active_life_stages': [chosenStage],
      'goals': _profile.goals,
      'symptoms': _profile.symptoms,
      'conditions': _profile.conditions,
      if (_profile.lastPeriod != null)
        'last_period': _profile.lastPeriod!.toIso8601String().split('T').first,
      if (_profile.lastPeriod != null || _profile.previousPeriods.isNotEmpty)
        'period_history': [
          if (_profile.lastPeriod != null)
            _profile.lastPeriod!.toIso8601String().split('T').first,
          ..._profile.previousPeriods.map((p) => p.toIso8601String().split('T').first),
        ],
      if (_profile.dueDate != null)
        'due_date': _profile.dueDate!.toIso8601String().split('T').first,
      if (_profile.babyBirthDate != null)
        'baby_birth_date': _profile.babyBirthDate!.toIso8601String().split('T').first,
      ..._profile.answers,
    };
    ApiAuthService().saveOnboardingAnswers(backendAnswers).catchError((err) {
      debugPrint('BlushyBackend: Onboarding sync exception: $err');
      return <String, dynamic>{};
    });

    // Enter the life stage engine, not just the onboarding answers.
    //
    // Without this the engine has no branch context, so a user who gave a due
    // date during onboarding still saw "add a due date" on the pregnancy
    // module, which reads branchContext rather than onboarding answers.
    _enterLifeStage(chosenStage);

    try {
      final stageInitialAnswers = {
        'goals': _profile.goals,
        'symptoms': _profile.symptoms,
        'conditions': _profile.conditions,
        ..._profile.answers,
        if (_profile.lastPeriod != null)
          'last_period': _profile.lastPeriod!.toIso8601String().split('T').first,
        if (_profile.dueDate != null)
          'due_date': _profile.dueDate!.toIso8601String().split('T').first,
        if (_profile.babyBirthDate != null)
          'baby_birth_date': _profile.babyBirthDate!.toIso8601String().split('T').first,
      };

      final profileData = {
        'profile': {
          'preferredName': _profile.preferredName,
          'lifeStage': chosenStage,
          'onboardingStage': chosenStage,
          'activeLifeStages': [chosenStage],
          'answers': _profile.answers,
          'goals': _profile.goals,
          'symptoms': _profile.symptoms,
          'conditions': _profile.conditions,
          'stage_answers': {
            chosenStage: stageInitialAnswers,
          },
          chosenStage: stageInitialAnswers,
        }
      };
      BlushyStorage.write('user_profile.json', profileData);
    } catch (_) {}

    // Map onboarding answers to standard state properties
    final state = BlushyOSProvider.of(context);
    final Set<String> medicalConditions = {};
    if (_profile.lifeStage == LifeStage.firstPeriodNotStarted || _profile.lifeStage == LifeStage.firstPeriodStarted) {
      medicalConditions.add('First Periods');
    }
    for (final c in _profile.conditions) {
      medicalConditions.add(c);
    }

    final Set<LifeContext> lifeContexts = {};
    if (_profile.lifeStage == LifeStage.pregnancy) lifeContexts.add(LifeContext.pregnancy);
    if (_profile.lifeStage == LifeStage.postpartum) lifeContexts.add(LifeContext.postpartum);
    if (_profile.lifeStage == LifeStage.menopause) lifeContexts.add(LifeContext.menopause);
    if (_profile.lifeStage == LifeStage.perimenopause) lifeContexts.add(LifeContext.perimenopause);

    int userCycleLength = 28;
    if (_profile.answers['cycle_length'] != null) {
      final parsed = int.tryParse(_profile.answers['cycle_length'].toString().replaceAll(RegExp(r'[^\d]'), ''));
      if (parsed != null && parsed >= 18 && parsed <= 60) {
        userCycleLength = parsed;
      }
    }

    final rawAnswerPeriod = _profile.lastPeriod ??
        BlushyOSState.parseFlexibleDate(_profile.answers['last_period_date'] ??
            _profile.answers['last_period'] ??
            _profile.answers['cycle_start_date'] ??
            _profile.answers['cycle_last_period_start'] ??
            _profile.answers['last_period_start'] ??
            _profile.answers['period_start']);

    final cycleCalc = CycleCalculation.compute(
      lastPeriodStart: rawAnswerPeriod,
      cycleLength: userCycleLength,
    );

    state.updatePersonalContext(
      PersonalContext(
        userName: _profile.preferredName,
        dateOfBirth: _profile.dateOfBirth,
        lifeStage: chosenStage,
        activeLifeStages: {chosenStage},
        trackingPreference: (_profile.lifeStage == LifeStage.firstPeriodNotStarted) 
            ? CycleTrackingPreference.disabled 
            : CycleTrackingPreference.enabled,
        cyclePattern: (_profile.answers['reproductive_cycle_type'] == 'Highly unpredictable') 
            ? CyclePattern.variable 
            : CyclePattern.predictable,
        confidence: DataConfidence.medium,
        lifeContexts: lifeContexts,
        userGoals: Set<String>.from(_profile.goals),
        medicalConditions: medicalConditions,
        preferences: UserPreferences(),
        cycleLength: rawAnswerPeriod != null ? cycleCalc.cycleLength : userCycleLength,
        cycleDay: rawAnswerPeriod != null ? cycleCalc.currentCycleDay : null,
        cyclePhase: rawAnswerPeriod != null ? cycleCalc.currentPhase : null,
        lastPeriodStart: rawAnswerPeriod,
        medications: [],
      ),
    );

    // The first-run tour decides for itself whether it has been shown, from
    // `product_tour.json` in BlushyStorage. This used to write a flag here with
    // a raw File() at a relative path -- unwritable on Android -- which the
    // dashboard then read, acted on with an empty setState, and deleted.

    // Complete authentication flags
    state.setAuthenticated(true);
    state.setOnboardingCompleted(true);

    // Route to main page
    Navigator.of(context).pushReplacementNamed('/home');
  }

  /// Records the chosen branch with the life stage engine, carrying the
  /// context that branch needs to render immediately.
  ///
  /// `confirmed: true` is correct here: this is the user's own explicit
  /// selection during onboarding, which is exactly the confirmation the
  /// sensitive transitions require (spec section 23).
  Future<void> _enterLifeStage(String chosenStage) async {
    final context = <String, dynamic>{
      if (_profile.lastPeriod != null)
        'last_period_start': _profile.lastPeriod!.toIso8601String().split('T').first,
      if (_profile.dueDate != null)
        'due_date': _profile.dueDate!.toIso8601String().split('T').first,
      if (_profile.babyBirthDate != null)
        'baby_birth_date': _profile.babyBirthDate!.toIso8601String().split('T').first,
      if (_profile.conditions.isNotEmpty) 'diagnosed_conditions': _profile.conditions,
    };

    final result = await LifeStageApi.transition(
      toStage: chosenStage,
      confirmed: true,
      context: context,
    );

    if (!result.isReady) {
      // Non-fatal: the legacy profile answers still carry the stage, so Home
      // renders. The branch context is what would be missing.
      debugPrint('BlushyBackend: life stage transition failed: ${result.errorCode}');
    }

    // Conditions the user selected are theirs, explicitly reported - never
    // inferred (spec section 14).
    if (_profile.conditions.isNotEmpty) {
      await BranchApi.saveConditions(_profile.conditions, diagnosedBy: 'self_reported');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: BlushyColors.background,
        body: Center(child: CircularProgressIndicator(color: BlushyColors.primary)),
      );
    }

    // Phase Switcher rendering
    switch (_phase) {
      case OnboardingPhase.privacy:
        return _buildPrivacyScreen();
      case OnboardingPhase.questions:
        return _buildQuestionsScreen();
      case OnboardingPhase.building:
        return _buildBuildingScreen();
      case OnboardingPhase.siaWelcome:
        return _buildSiaWelcomeScreen();
      case OnboardingPhase.ready:
        return _buildReadyScreen();
    }
  }

  // --- 1. PRIVACY & CONSENT SCREEN ---
  Widget _buildPrivacyScreen() {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Center(
                    child: Icon(Icons.lock_person_outlined, size: 72, color: BlushyColors.primary),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    "Your health. Your privacy.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Everything you share helps Blushy personalize your wellness companion experience. We use local encryption, we never sell your personal health records, and you are always in complete control.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText, height: 1.5),
                  ),
                  const Spacer(),
                  CheckboxListTile(
                    title: Row(
                      children: [
                        Text(AppLocalizations.of(context).oIAgreeToThe, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        GestureDetector(
                          onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.privacyPolicy),
                          child: Text(
                            AppLocalizations.of(context).oPrivacyPolicy,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: BlushyColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    value: _agreePrivacy,
                    activeColor: BlushyColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _agreePrivacy = val ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: Row(
                      children: [
                        Text(AppLocalizations.of(context).oIAgreeToThe, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        GestureDetector(
                          onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.termsAndConditions),
                          child: Text(
                            AppLocalizations.of(context).oTermsOfService,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: BlushyColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    value: _agreeTerms,
                    activeColor: BlushyColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _agreeTerms = val ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (_agreePrivacy && _agreeTerms)
                        ? () {
                            setState(() {
                              _phase = OnboardingPhase.questions;
                            });
                            _saveProgress();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      disabledBackgroundColor: const Color(0x1F2E2623),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      "Continue to Onboarding",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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

  // --- 2. QUESTIONS CONTAINER SCREEN ---
  Widget _buildPremiumProgressHeader(double progress, String stepLabel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          stepLabel.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: BlushyColors.secondaryText,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 240,
          height: 1,
          color: BlushyColors.border,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: progress),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
            builder: (context, val, child) {
              return FractionallySizedBox(
                widthFactor: val,
                child: Container(
                  height: 1,
                  color: BlushyColors.primary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionHeader(String title, String description) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 42,
            fontWeight: FontWeight.w500,
            color: BlushyColors.text,
            height: 1.15,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: BlushyColors.secondaryText,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildQuestionsScreen() {
    final questions = _buildQuestionsSteps();
    final total = questions.length;
    final currentView = questions[_currentStepIndex];
    final double progress = (total > 0) ? (_currentStepIndex + 1) / total : 0.0;

    String chapterText = "CHAPTER I • GETTING INTRODUCED";
    if (_currentStepIndex >= 3) {
      chapterText = "CHAPTER II • UNDERSTANDING YOUR RHYTHM";
    }
    if (_currentStepIndex >= 5) {
      chapterText = "CHAPTER III • CUSTOMIZING INSIGHTS";
    }

    // Padded rather than prefixed with a literal "0": the branches vary in
    // length and adding a step to one is routine, so a hardcoded zero would
    // read "010" the first time a branch reached ten.
    final String stepLabel = '$chapterText • '
        '${'${_currentStepIndex + 1}'.padLeft(2, '0')}'
        ' / ${'$total'.padLeft(2, '0')}';

    // Dynamic header and content interceptor to convert flat lists to centered compositions
    Widget processedView = currentView;
    if (currentView is Column) {
      final List<Widget> originalChildren = currentView.children;
      List<String> texts = [];
      List<Widget> remaining = [];
      for (var child in originalChildren) {
        if (child is Text && texts.length < 2) {
          texts.add(child.data ?? "");
        } else if (child is SizedBox && texts.length < 2) {
          // skip
        } else {
          remaining.add(child);
        }
      }
      final String title = texts.isNotEmpty ? texts[0] : "";
      final String description = texts.length > 1 ? texts[1] : "";

      processedView = Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildQuestionHeader(title, description),
          ...remaining,
        ],
      );
    }

    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  _buildPremiumProgressHeader(progress, stepLabel),
                  const SizedBox(height: 56),

                  // 2. MAIN INPUT VIEW WITH FADE/SLIDE TRANSITIONS
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: AnimatedOpacity(
                          opacity: _questionOpacity,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutCubic,
                          child: AnimatedSlide(
                            offset: Offset(0, _questionOffset / 15.0),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: processedView,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  _buildWhyAskingExpandable(),
                  const SizedBox(height: 24),

                  // BUTTONS ROW
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _backQuestion,
                          child: Text(
                            AppLocalizations.of(context).onbBack,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: BlushyColors.secondaryText,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        _buildContinueButton(),
                      ],
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

  // --- 3. BUILDING YOUR BLUSHY SCREEN ---
  Widget _buildBuildingScreen() {
    final listItems = [
      "Understanding your health journey",
      "Personalizing your dashboard",
      AppLocalizations.of(context).onbPreparingDocsy,
      AppLocalizations.of(context).onbCreatingInsights,
      AppLocalizations.of(context).onbCuratingContent,
      AppLocalizations.of(context).onbCreatingSafeSpace
    ];

    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Creating your wellness space...",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: BlushyColors.text),
                ),
                const SizedBox(height: 36),
                
                // Checklist items with staggering checks
                ...List.generate(listItems.length, (idx) {
                  final isDone = _buildingChecks[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle : Icons.radio_button_off,
                          color: isDone ? BlushyColors.primary : BlushyColors.secondaryText.withValues(alpha: 0.4),
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          listItems[idx],
                          style: GoogleFonts.poppins(
                            fontSize: 13, 
                            color: isDone ? BlushyColors.text : BlushyColors.secondaryText.withValues(alpha: 0.6),
                            fontWeight: isDone ? FontWeight.w600 : FontWeight.normal
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 48),

                // Linear progress indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _buildingProgress,
                    minHeight: 6,
                    backgroundColor: const Color(0x1F2E2623),
                    valueColor: AlwaysStoppedAnimation<Color>(BlushyColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "${(_buildingProgress * 100).toInt()}%",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 4. DR. DOCSY WELCOME SCREEN ---
  Widget _buildSiaWelcomeScreen() {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 36.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Icon(Icons.auto_awesome, size: 72, color: BlushyColors.primary),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    "Hi, ${_profile.preferredName}.\nI'm Docsy.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 42, fontWeight: FontWeight.w300, color: BlushyColors.text, height: 1.1),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "I'll learn alongside you and adapt as your needs change.\n\nSome days I'll help you understand your body. Some days I'll remind you to care for yourself. Some days I'll simply listen.\n\nWelcome to Blushy.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText, height: 1.6),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _phase = OnboardingPhase.ready;
                      });
                      _saveProgress();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      "Start My Journey",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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

  // --- 5. YOUR BLUSHY IS READY SCREEN ---
  Widget _buildReadyScreen() {
    final readyCards = [
      "Personalized Home",
      "AI Companion Ready",
      "Daily Insights Prepared",
      "Journal Ready",
      "Community Matched",
      "Wellness Timeline Created"
    ];

    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 36.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    "Your Blushy is Ready",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 38, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We've prepared your personal wellness space.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
                  ),
                  const SizedBox(height: 36),
                  
                  // Setup highlights grid
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: readyCards.map((card) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x1F2E2623)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, size: 14, color: BlushyColors.success),
                            const SizedBox(width: 8),
                            Text(
                              card,
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: BlushyColors.text),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _finishOnboarding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      "Enter Blushy",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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

  // --- "Why we're asking this" Widget ---
  Widget _buildWhyAskingExpandable() {
    String explanation = "This information helps customize your daily insights and companion interactions.";
    
    if (_currentStepIndex == 0) {
      explanation = "Your preferred name is used by Docsy to personalize letters, notes, and wellness greetings.";
    } else if (_currentStepIndex == 1) {
      explanation = "Your age dictates key physiological milestones, health warnings, and maturity checkins.";
    } else if (_currentStepIndex == 2) {
      explanation = "Choosing your current life stage selects the correct medical condition track and cycle calculations.";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _whyAskingExpanded = !_whyAskingExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Why we're asking this",
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
                ),
                Icon(
                  _whyAskingExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: BlushyColors.secondaryText,
                ),
              ],
            ),
          ),
        ),
        if (_whyAskingExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
            child: Text(
              explanation,
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
            ),
          ),
      ],
    );
  }

  // --- UNIVERSAL STEPS WIDGETS ---

  // Step 1: Preferred Name
  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).onbLetsGetIntroduced,
          style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "What name would you like Docsy to call you?",
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nameController,
          autofocus: true,
          style: GoogleFonts.poppins(fontSize: 18, color: BlushyColors.text),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).oYourPreferredName,
            hintStyle: GoogleFonts.poppins(color: BlushyColors.secondaryText.withValues(alpha: 0.5)),
            border: const UnderlineInputBorder(borderSide: BorderSide(color: BlushyColors.border)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: BlushyColors.primary, width: 2)),
          ),
        ),
      ],
    );
  }

  // Step 2: Date of Birth
  Widget _buildDobStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).oWhenIsYourBirthday,
          style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "Knowing your birthday helps customize age-based biology recommendations.",
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 32),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: BlushyColors.primary,
                      onPrimary: Colors.white,
                      onSurface: BlushyColors.text,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _profile.dateOfBirth = picked;
              });
              _saveProgress();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: BlushyColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _profile.dateOfBirth == null 
                      ? "Select your date of birth" 
                      : "${_profile.dateOfBirth!.day}/${_profile.dateOfBirth!.month}/${_profile.dateOfBirth!.year}",
                  style: GoogleFonts.poppins(
                    fontSize: 16, 
                    color: _profile.dateOfBirth == null ? BlushyColors.secondaryText : BlushyColors.text
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18, color: BlushyColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Step 3: Life Stage Choices
  Widget _buildStageStep() {
    final stages = [
      {"label": "First Period (Not Started)", "value": LifeStage.firstPeriodNotStarted, "desc": "Puberty changes & first cycle preparations."},
      {"label": "First Period (Started)", "value": LifeStage.firstPeriodStarted, "desc": "Cycle tracking confidence for young girls."},
      {"label": "Reproductive Years", "value": LifeStage.reproductiveYears, "desc": "Standard cycle tracking and wellness logs."},
      {"label": "Hormonal Health", "value": LifeStage.hormonalHealth, "desc": "Support for PCOS, PMDD, and condition management."},
      {"label": "Trying to Conceive", "value": LifeStage.tryingToConceive, "desc": "Fertility analysis, markers, and checklists."},
      {"label": "Pregnancy", "value": LifeStage.pregnancy, "desc": "Weekly baby growth logs and maternity tracking."},
      {"label": "Postpartum", "value": LifeStage.postpartum, "desc": "Newborn check-ins, feeds, and maternal healing."},
      {"label": "Perimenopause", "value": LifeStage.perimenopause, "desc": "Tracking changes in your cycle rhythm."},
      {"label": "Menopause", "value": LifeStage.menopause, "desc": "Supports bone wellness and hot flash tracking."},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).oWhereAreYouToday,
          style: GoogleFonts.poppins(fontSize: 38, fontWeight: FontWeight.w400, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "This selection defines the entire branching layout for your onboarding questionnaire.",
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        ...stages.map((stage) {
          final isSelected = _profile.lifeStage == stage['value'];
          return _buildPremiumSelectionRow(
            title: stage['label'] as String,
            desc: stage['desc'] as String,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _profile.lifeStage = stage['value'] as LifeStage;
              });
              _saveProgress();
            },
          );
        }),
      ],
    );
  }

  // --- BRANCH A: FIRST PERIOD (NOT STARTED) ---
  Widget _buildNotStartedStep4() {
    final options = [
      "Puberty & body changes",
      "Preparing for my first period",
      "Hygiene",
      "Mood & emotions",
      "School & sports"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oWhatWouldYouLike,
      subtitle: "We'll build custom guides to help you feel ready.",
      options: options,
      storageKey: "not_started_learn",
    );
  }

  /// What she actually notices, for the branch most women take.
  ///
  /// The hormonal health, perimenopause and menopause branches each asked about
  /// symptoms; reproductive years — the most common route — asked about cycle
  /// type, last period, goals and contraception, and never about symptoms at
  /// all. So the dashboard had nothing to work with and fell back to a fixed
  /// set of cards for most people.
  ///
  /// Every option here maps to a card the dashboard can already show. Before
  /// this, 67 of its 100 keywords were unreachable from onboarding: the
  /// personalisation was built and could not be switched on.
  /// What she is noticing while trying to conceive.
  ///
  /// Only the reproductive-years branch asked this, so anyone who came through
  /// TTC or postpartum finished onboarding with an empty symptom list and got a
  /// home page with every symptom-keyed card switched off -- not because she
  /// tracks nothing, but because she was never asked.
  ///
  /// Deliberately about symptoms, not method: step 5 already asks how she
  /// tracks.
  Widget _buildTtcStep7() {
    final options = [
      "Cramps",
      "Bloating",
      "Spotting",
      "Discharge",
      "Fatigue",
      "Mood swings",
      "Headache",
      "Acne",
      "Back pain",
      "Pelvic pain",
      "Anxiety",
      "Insomnia",
    ];
    return _buildMultiSelectSymptomsStep(
      title: "Which of these do you notice?",
      subtitle: "Pick as many as you like. Your home page shows what you track.",
      options: options,
    );
  }

  /// What she is noticing while recovering.
  ///
  /// The branch asked how she feeds and what she wants help with, and never
  /// what her body is actually doing -- so recovery was the one thing the
  /// postpartum onboarding could not hear about.
  ///
  /// The clinical words are paired with plain ones ("Bleeding (lochia)")
  /// because she may know either. These ask what she notices; they do not tell
  /// her what any of it means, which stays with the reviewed content.
  Widget _buildPostpartumStep7() {
    final options = [
      "Bleeding (lochia)",
      "Perineal soreness",
      "C-section incision",
      "Stitches",
      "Pelvic floor",
      "Swelling",
      "Back pain",
      "Fatigue",
      "Insomnia",
      "Mood swings",
      "Anxiety",
      "Night sweats",
    ];
    return _buildMultiSelectSymptomsStep(
      title: "How is your body doing?",
      subtitle: "Pick as many as you like. Your home page shows what you track.",
      options: options,
    );
  }

  Widget _buildReproductiveStep8() {
    final options = [
      "Cramps",
      "Bloating",
      "Headache",
      "Mood swings",
      "Fatigue",
      "Acne",
      "Heavy period",
      "Spotting",
      "Discharge",
      "Digestion",
      "Anxiety",
      "Insomnia",
      "Back pain",
      // Breast tenderness was here and removed: the dashboard has no card
      // keyed to it, so selecting it changed nothing. Asking a question whose
      // answer is discarded is how this feature got into trouble in the first
      // place. Worth adding back alongside a card that responds to it.
    ];
    return _buildMultiSelectSymptomsStep(
      title: "Which of these do you notice?",
      subtitle: "Pick as many as you like. Your home page shows what you track.",
      options: options,
    );
  }

  // --- BRANCH B: FIRST PERIOD (STARTED) ---
  Widget _buildStartedStep4() {
    final options = [
      "Within the last month",
      "1–6 months ago",
      "More than 6 months ago"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oWhenDidYourFirst,
      subtitle: "This sets cycle prediction baseline metrics.",
      options: options,
      storageKey: "first_period_start_time",
    );
  }

  Widget _buildStartedStep5() {
    final options = [
      "Tracking periods",
      "Cramps",
      "Mood changes",
      "Understanding my body",
      "Hygiene",
      "School & sports"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatWouldYouLike2,
      subtitle: "Select all parameters that apply to you.",
      options: options,
    );
  }

  // --- BRANCH C: REPRODUCTIVE YEARS ---
  Widget _buildReproductiveStep4() {
    final options = [
      "Very regular",
      "Mostly regular",
      "Sometimes irregular",
      "Highly unpredictable",
      "I don't know"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowWouldYouDescribe,
      subtitle: "Cycles fluctuate dynamically based on hormonal states.",
      options: options,
      storageKey: "reproductive_cycle_type",
    );
  }

  Widget _buildReproductiveStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).oWhenDidYourLast,
          style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "Used to forecast your upcoming cycle length.",
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _profile.lastPeriod ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _profile.lastPeriod = picked;
                _profile.answers['last_period_unknown'] = false;
              });
              _saveProgress();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: BlushyColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _profile.lastPeriod == null 
                      ? "Select date" 
                      : "${_profile.lastPeriod!.day}/${_profile.lastPeriod!.month}/${_profile.lastPeriod!.year}",
                  style: GoogleFonts.poppins(
                    fontSize: 16, 
                    color: _profile.lastPeriod == null ? BlushyColors.secondaryText : BlushyColors.text
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18, color: BlushyColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        CheckboxListTile(
          title: Text(AppLocalizations.of(context).onbDontRemember, style: GoogleFonts.poppins(fontSize: 14)),
          value: _profile.answers['last_period_unknown'] == true,
          activeColor: BlushyColors.primary,
          onChanged: (val) {
            setState(() {
              _profile.answers['last_period_unknown'] = val;
              if (val == true) {
                _profile.lastPeriod = null;
                _profile.previousPeriods.clear();
              }
            });
            _saveProgress();
          },
        ),
        if (_profile.answers['last_period_unknown'] != true && _profile.lastPeriod != null) ...[
          const SizedBox(height: 24),
          const Divider(color: BlushyColors.border),
          const SizedBox(height: 12),
          Text(
            "Earlier period start dates (Optional, up to 3)",
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            "Helps Docsy calculate your exact cycle length and pattern right away.",
            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _profile.previousPeriods.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Cycle -${i + 1}: ${_profile.previousPeriods[i].day}/${_profile.previousPeriods[i].month}/${_profile.previousPeriods[i].year}",
                    style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: BlushyColors.primary),
                    onPressed: () {
                      setState(() {
                        _profile.previousPeriods.removeAt(i);
                      });
                      _saveProgress();
                    },
                  ),
                ],
              ),
            ),
          if (_profile.previousPeriods.length < 3)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final latestCutoff = _profile.previousPeriods.isNotEmpty
                      ? _profile.previousPeriods.last.subtract(const Duration(days: 1))
                      : (_profile.lastPeriod ?? DateTime.now()).subtract(const Duration(days: 1));
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: latestCutoff.isAfter(DateTime.now().subtract(const Duration(days: 365)))
                        ? latestCutoff
                        : DateTime.now().subtract(const Duration(days: 30)),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: latestCutoff,
                  );
                  if (picked != null) {
                    setState(() {
                      _profile.previousPeriods.add(picked);
                      _profile.previousPeriods.sort((a, b) => b.compareTo(a));
                    });
                    _saveProgress();
                  }
                },
                icon: const Icon(Icons.add, size: 16, color: BlushyColors.primary),
                label: Text("+ Add earlier period date", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.primary)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildReproductiveStep6() {
    final options = [
      "Predict periods",
      "Reduce cramps",
      "PMS",
      "Mood",
      "Sleep",
      "Energy",
      "Acne",
      "Ovulation",
      "Fitness",
      "Nutrition",
      "Walking",
      "Yoga",
      "Strength",
      "Stress",
      "Medication reminders"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatWouldYouLike3,
      subtitle: "Customize your companion track.",
      options: options,
    );
  }

  Widget _buildReproductiveStep7() {
    final options = ["Yes", "No", "Prefer not to say"];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oAreYouCurrentlyUsing,
      subtitle: "This shifts cycle predictability and calculations.",
      options: options,
      storageKey: "contraception_choice",
    );
  }

  // --- BRANCH D: HORMONAL HEALTH ---
  Widget _buildHormonalStep4() {
    final options = [
      "PCOS",
      "Endometriosis",
      "Fibroids",
      "Adenomyosis",
      "Thyroid disorder",
      "PMDD",
      "I'm not diagnosed yet"
    ];
    return _buildMultiSelectConditionsStep(
      title: AppLocalizations.of(context).oWhichConditionBestMatches,
      subtitle: "Helps reorder custom home layout trackers.",
      options: options,
    );
  }

  Widget _buildHormonalStep5() {
    final options = [
      "Pain",
      "Irregular periods",
      "Acne",
      "Hair fall",
      "Facial hair",
      "Weight gain",
      "Fatigue",
      "Mood",
      "Sleep",
      "Bloating",
      "Headache",
      "Digestion",
      "Anxiety",
      "Heavy period"
    ];
    return _buildMultiSelectSymptomsStep(
      title: AppLocalizations.of(context).oWhichSymptomsAffectYou,
      subtitle: "Docsy adapts tracking cards to prioritize these.",
      options: options,
    );
  }

  Widget _buildHormonalStep6() {
    final options = ["Yes", "No", "In progress"];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oAreYouCurrentlyReceiving,
      subtitle: "We prioritize wellness metrics rather than diagnosis.",
      options: options,
      storageKey: "hormonal_treatment",
    );
  }

  // --- BRANCH E: TRYING TO CONCEIVE ---
  Widget _buildTtcStep4() {
    final options = [
      "Just starting",
      "Under 6 months",
      "6–12 months",
      "More than 12 months"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowLongHaveYou,
      subtitle: "Provides tracking and testing timeline metrics.",
      options: options,
      storageKey: "ttc_duration",
    );
  }

  Widget _buildTtcStep5() {
    final options = [
      "Ovulation strips",
      "Basal body temperature",
      "Cervical mucus",
      "Cycle tracking",
      "I'm not tracking yet"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowAreYouTracking,
      subtitle: "Select the method you use most frequently.",
      options: options,
      storageKey: "ttc_tracking_method",
    );
  }

  Widget _buildTtcStep6() {
    final options = ["No", "IUI", "IVF", "Other"];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oAreYouCurrentlyReceiving2,
      subtitle: "Tailors recommendations around your cycles.",
      options: options,
      storageKey: "ttc_treatment",
    );
  }

  // --- BRANCH E: PREGNANCY ---
  Widget _buildPregnancyStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).oWhatSYourDue,
          style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "Calculates gestational week and baby growth size benchmarks.",
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 120)),
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 280)),
            );
            if (picked != null) {
              setState(() {
                _profile.dueDate = picked;
              });
              _saveProgress();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: BlushyColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _profile.dueDate == null 
                      ? "Select estimated due date" 
                      : "${_profile.dueDate!.day}/${_profile.dueDate!.month}/${_profile.dueDate!.year}",
                  style: GoogleFonts.poppins(
                    fontSize: 16, 
                    color: _profile.dueDate == null ? BlushyColors.secondaryText : BlushyColors.text
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18, color: BlushyColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPregnancyStep5() {
    final options = ["Yes", "No"];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oIsThisYourFirst,
      subtitle: "Personalizes education content pacing.",
      options: options,
      storageKey: "pregnancy_first",
    );
  }

  Widget _buildPregnancyStep6() {
    final options = [
      "Baby development",
      "Symptoms",
      "Nutrition",
      "Exercise",
      "Sleep",
      "Mental wellbeing",
      "Appointments",
      "Fetal movement",
      "Contractions",
      "Swelling",
      "Walking"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatSupportWouldYou,
      subtitle: "Customize your pregnancy journey preferences.",
      options: options,
    );
  }

  // --- BRANCH F: POSTPARTUM ---
  Widget _buildPostpartumStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).oWhenWasYourBaby,
          style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "Drives maternal postpartum healing calendars and recovery tracking.",
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _profile.babyBirthDate = picked;
              });
              _saveProgress();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: BlushyColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _profile.babyBirthDate == null 
                      ? "Select baby birth date" 
                      : "${_profile.babyBirthDate!.day}/${_profile.babyBirthDate!.month}/${_profile.babyBirthDate!.year}",
                  style: GoogleFonts.poppins(
                    fontSize: 16, 
                    color: _profile.babyBirthDate == null ? BlushyColors.secondaryText : BlushyColors.text
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18, color: BlushyColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostpartumStep5() {
    final options = ["Breastfeeding", "Formula", "Combination"];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowAreYouFeeding,
      subtitle: "Dynamically tracks hydration recommendations.",
      options: options,
      storageKey: "postpartum_feeding",
    );
  }

  Widget _buildPostpartumStep6() {
    final options = [
      "Recovery",
      "Feeding",
      "Sleep",
      "Mental health",
      "Exercise",
      "Nutrition",
      "Pelvic floor",
      "Healing",
      "Pumping",
      "Walking"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatWouldYouLike2,
      subtitle: "Tailor postpartum workspace settings.",
      options: options,
    );
  }

  // --- BRANCH G: PERIMENOPAUSE ---
  Widget _buildPerimenopauseStep4() {
    final options = [
      "Still regular",
      "Becoming irregular",
      "Rare",
      "Stopped recently"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowHaveYourPeriods,
      subtitle: "Tracks fluctuations in menstrual metrics.",
      options: options,
      storageKey: "perimenopause_cycle_change",
    );
  }

  Widget _buildPerimenopauseStep5() {
    final options = [
      "Hot flashes",
      "Brain fog",
      "Mood",
      "Sleep",
      "Joint pain",
      "Weight changes",
      "Night sweats",
      "Irregular periods",
      "Anxiety",
      "Memory",
      "Headache"
    ];
    return _buildMultiSelectSymptomsStep(
      title: AppLocalizations.of(context).oWhichSymptomsAffectYou,
      subtitle: "Docsy adapts tracking cards to prioritize these.",
      options: options,
    );
  }

  Widget _buildPerimenopauseStep6() {
    final options = [
      "Sleep",
      "Energy",
      "Exercise",
      "Nutrition",
      "Mood"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatWouldYouMost,
      subtitle: "Saves priorities for home insights.",
      options: options,
    );
  }

  // --- BRANCH H: MENOPAUSE ---
  Widget _buildMenopauseStep4() {
    final options = [
      "Less than 12 months",
      "More than 12 months",
      "I'm not sure"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowLongHasIt,
      subtitle: "Identifies transition status indicators.",
      options: options,
      storageKey: "menopause_duration",
    );
  }

  Widget _buildMenopauseStep5() {
    final options = [
      "Hot flashes",
      "Night sweats",
      "Sleep",
      "Mood",
      "Vaginal dryness",
      "Bone health",
      "Joint stiffness",
      "Memory",
      "Anxiety",
      "Heart health"
    ];
    return _buildMultiSelectSymptomsStep(
      title: AppLocalizations.of(context).oWhichSymptomsAffectYour,
      subtitle: "Select all that apply to you.",
      options: options,
    );
  }

  Widget _buildMenopauseStep6() {
    final options = [
      "Healthy ageing",
      "Exercise",
      "Heart health",
      "Bone health",
      "Nutrition",
      "Mental wellbeing"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatWouldYouLike4,
      subtitle: "Tailors long-term healthy wellness priorities.",
      options: options,
    );
  }

  Widget _buildSingleSelectBranchStep({
    required String title,
    required String subtitle,
    required List<String> options,
    required String storageKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 38, fontWeight: FontWeight.w400, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        ...options.map((opt) {
          final isSelected = _profile.answers[storageKey] == opt;
          return _buildPremiumSelectionRow(
            title: opt,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _profile.answers[storageKey] = opt;
              });
              _saveProgress();
            },
          );
        }),
      ],
    );
  }

  Widget _buildMultiSelectGoalsStep({
    required String title,
    required String subtitle,
    required List<String> options,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 38, fontWeight: FontWeight.w400, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        ...options.map((opt) {
          final isSelected = _profile.goals.contains(opt);
          return _buildPremiumSelectionRow(
            title: opt,
            isSelected: isSelected,
            isMulti: true,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _profile.goals.remove(opt);
                } else {
                  _profile.goals.add(opt);
                }
              });
              _saveProgress();
            },
          );
        }),
      ],
    );
  }

  Widget _buildMultiSelectConditionsStep({
    required String title,
    required String subtitle,
    required List<String> options,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 38, fontWeight: FontWeight.w400, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        ...options.map((opt) {
          final isSelected = _profile.conditions.contains(opt);
          return _buildPremiumSelectionRow(
            title: opt,
            isSelected: isSelected,
            isMulti: true,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _profile.conditions.remove(opt);
                } else {
                  _profile.conditions.add(opt);
                }
              });
              _saveProgress();
            },
          );
        }),
      ],
    );
  }

  Widget _buildMultiSelectSymptomsStep({
    required String title,
    required String subtitle,
    required List<String> options,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 38, fontWeight: FontWeight.w400, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        ...options.map((opt) {
          final isSelected = _profile.symptoms.contains(opt);
          return _buildPremiumSelectionRow(
            title: opt,
            isSelected: isSelected,
            isMulti: true,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _profile.symptoms.remove(opt);
                } else {
                  _profile.symptoms.add(opt);
                }
              });
              _saveProgress();
            },
          );
        }),
      ],
    );
  }

  Widget _buildPremiumSelectionRow({
    required String title,
    String? desc,
    required bool isSelected,
    required VoidCallback onTap,
    bool isMulti = false,
  }) {
    return PremiumSelectionRow(
      title: title,
      desc: desc,
      isSelected: isSelected,
      onTap: onTap,
      isMulti: isMulti,
    );
  }

  Widget _buildContinueButton() {
    return _ContinueButton(
      onPressed: _isStepInputValid() ? _nextQuestion : null,
    );
  }
}

// --- NEW COMPRESSED BUTTONS AND SELECTIONS WIDGETS ---

class _ContinueButton extends StatefulWidget {
  final VoidCallback? onPressed;
  const _ContinueButton({this.onPressed});

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        if (widget.onPressed != null) setState(() => _isPressed = false);
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
          decoration: BoxDecoration(
            color: widget.onPressed != null ? BlushyColors.primary : const Color(0x1F2E2623),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            AppLocalizations.of(context).onbContinue,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumSelectionRow extends StatefulWidget {
  final String title;
  final String? desc;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isMulti;

  const PremiumSelectionRow({
    super.key,
    required this.title,
    this.desc,
    required this.isSelected,
    required this.onTap,
    this.isMulti = false,
  });

  @override
  State<PremiumSelectionRow> createState() => _PremiumSelectionRowState();
}

class _PremiumSelectionRowState extends State<PremiumSelectionRow> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double scale = _isPressed ? 0.98 : (_isHovered ? 1.01 : 1.0);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected 
                  ? BlushyColors.primary.withValues(alpha: 0.04) 
                  : (_isHovered ? Colors.white.withValues(alpha: 0.4) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isSelected 
                    ? BlushyColors.primary.withValues(alpha: 0.3) 
                    : (_isHovered ? BlushyColors.border : Colors.transparent),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: widget.isSelected ? BlushyColors.primary : BlushyColors.text,
                        ),
                      ),
                      if (widget.desc != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.desc!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: widget.isMulti ? BorderRadius.circular(4) : BorderRadius.circular(100),
                    border: Border.all(
                      color: widget.isSelected ? BlushyColors.primary : BlushyColors.border,
                      width: widget.isSelected ? 5.0 : 1.2,
                    ),
                    color: Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
