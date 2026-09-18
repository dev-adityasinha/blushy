import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/storage.dart';
import '../../../core/state.dart';
import '../../../core/cycle_calculator.dart';
import '../../../theme/colors.dart';
import '../../../services/api_auth_service.dart';
import '../../../services/api_consent_service.dart';
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
  bool _agreeDisclaimer = false;

  /// True while the acceptance is being recorded, so the button cannot be
  /// tapped twice into two consent rows for one decision.
  bool _recordingConsent = false;

  bool get _hasAgreedToEverything => _agreePrivacy && _agreeTerms && _agreeDisclaimer;

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

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  int? get _userAge {
    final dob = _profile.dateOfBirth;
    if (dob == null) return null;
    return _calculateAge(dob);
  }

  bool _isStageAllowedForAge(LifeStage stage, int? age) {
    if (age == null) return true;
    if (age < 9) {
      // Under 9 is clinically inappropriate for self-directed app registration
      return false;
    }
    if (age < 13) {
      // Pre-teens (9-12): strictly first period stages
      return stage == LifeStage.firstPeriodNotStarted || stage == LifeStage.firstPeriodStarted;
    }
    if (age < 18) {
      // Adolescents / Teens (13-17): puberty, adolescent cycle, and hormonal health
      return stage == LifeStage.firstPeriodNotStarted ||
          stage == LifeStage.firstPeriodStarted ||
          stage == LifeStage.reproductiveYears ||
          stage == LifeStage.hormonalHealth;
    }
    if (age < 45) {
      // Adult reproductive years (18-44)
      return stage != LifeStage.firstPeriodNotStarted && stage != LifeStage.menopause;
    }
    if (age < 52) {
      // Perimenopausal transition / late reproductive (45-51)
      return stage != LifeStage.firstPeriodNotStarted && stage != LifeStage.firstPeriodStarted;
    }
    // Post-52 (Mature adult): perimenopause, menopause, hormonal health
    return stage == LifeStage.menopause ||
        stage == LifeStage.perimenopause ||
        stage == LifeStage.hormonalHealth;
  }

  void _showStageAgeGuidance(LifeStage stage) {
    String title = "Age-Appropriate Care";
    String message = "This stage is designed for a different age range.";

    final age = _userAge;
    if (age != null && age < 13) {
      if (stage == LifeStage.pregnancy ||
          stage == LifeStage.tryingToConceive ||
          stage == LifeStage.postpartum) {
        title = "Maternity Tracking (Age 18+)";
        message =
            "Maternal and pregnancy health tools in Blushy are medically configured for users aged 18 and older.\n\n"
            "For your age, we recommend our specialized 'First Period' tracks, thoughtfully crafted with pediatric guidance to help you understand your body and puberty with confidence.";
      } else if (stage == LifeStage.perimenopause || stage == LifeStage.menopause) {
        title = "Midlife Transition Care";
        message =
            "Perimenopause and menopause tracks are clinically designed for adults navigating natural cycle cessation in midlife.\n\n"
            "We recommend choosing 'First Period (Not Started)' or 'First Period (Started)' to track puberty and early cycle milestones.";
      } else {
        title = "Adolescent Guidance";
        message =
            "For girls under 13, our dedicated First Period tracks provide gentle, safe, age-appropriate educational guidance.";
      }
    } else if (age != null && age < 18) {
      if (stage == LifeStage.pregnancy || stage == LifeStage.tryingToConceive) {
        title = "Adult Health Feature (Age 18+)";
        message =
            "Conception and pregnancy tracking tools are reserved for users aged 18 and older.\n\n"
            "If you are experiencing menstrual changes or hormonal questions, we recommend our adolescent-adapted tracks: 'Living with my cycle' or 'Hormonal Health'.";
      } else if (stage == LifeStage.perimenopause || stage == LifeStage.menopause) {
        title = "Midlife Transition Care";
        message =
            "This track is clinically designed for midlife transitions. For your age, please explore 'Living with my cycle' or 'Hormonal Health'.";
      }
    } else if (age != null && age >= 18) {
      if (stage == LifeStage.firstPeriodNotStarted) {
        title = "Primary Amenorrhea Care";
        message =
            "The 'First Period (Not Started)' track is specifically created for young girls entering puberty.\n\n"
            "If you are 18 or older and have never experienced a menstrual period (known clinically as primary amenorrhea), we strongly recommend consulting a gynecologist or endocrinologist for clinical evaluation.\n\n"
            "For tracking your hormonal wellness in Blushy, please select 'Hormonal Health' or 'Living with my cycle'.";
      } else if (age >= 52 && (stage == LifeStage.pregnancy || stage == LifeStage.tryingToConceive)) {
        title = "Fertility Timeline Guidance";
        message =
            "Conception and pregnancy algorithms in Blushy are clinically calibrated for reproductive ages up to 51.\n\n"
            "For your stage, our specialized Perimenopause and Menopause tracks offer personalized insights for bone density, cardiovascular health, and deep sleep.";
      }
    }

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Color(0xFFDD0D22), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221510),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: const Color(0xFF5A4A52),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDD0D22),
            ),
            child: Text(
              "Understood",
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

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
        steps.addAll([
          _buildNotStartedStep4(), // Learning focus
          _buildNotStartedStep5(), // Body changes noticed
          _buildNotStartedStep6(), // Goals & comfort
        ]);
        break;
      case LifeStage.firstPeriodStarted:
        steps.addAll([
          _buildStartedStep4(), // Start timing
          _buildStartedStep5(), // Predictability / regularity
          _buildStartedStep6(), // Symptoms noticed
          _buildStartedStep7(), // Goals
        ]);
        break;
      case LifeStage.reproductiveYears:
        steps.addAll([
          _buildReproductiveStep4(), // Regularity
          _buildReproductiveStep5(), // Last period date
          _buildReproductiveStep6(), // Contraception
          _buildReproductiveStep7(), // Goals
          _buildReproductiveStep8(), // Symptoms noticed
        ]);
        break;
      case LifeStage.hormonalHealth:
        steps.addAll([
          _buildHormonalStep4(), // Conditions
          _buildHormonalStep5(), // Symptoms
          _buildHormonalStep6(), // Treatment
          _buildHormonalStep7(), // Goals
        ]);
        break;
      case LifeStage.tryingToConceive:
        steps.addAll([
          _buildTtcStep4(), // Duration
          _buildTtcStep5(), // Biomarker tracking
          _buildTtcStep6(), // Treatment
          _buildTtcStep7(), // Symptoms
          _buildTtcStep8(), // Goals
        ]);
        break;
      case LifeStage.pregnancy:
        steps.addAll([
          _buildPregnancyStep4(), // Due date
          _buildPregnancyStep5(), // First pregnancy
          _buildPregnancyStep6(), // Trimester symptoms
          _buildPregnancyStep7(), // Goals
        ]);
        break;
      case LifeStage.postpartum:
        steps.addAll([
          _buildPostpartumStep4(), // Baby birth date
          _buildPostpartumStep5(), // Feeding
          _buildPostpartumStep6(), // Goals
          _buildPostpartumStep7(), // Recovery symptoms
        ]);
        break;
      case LifeStage.perimenopause:
        steps.addAll([
          _buildPerimenopauseStep4(), // Cycle changes
          _buildPerimenopauseStep5(), // Vasomotor / neuro symptoms
          _buildPerimenopauseStep6(), // Therapy
          _buildPerimenopauseStep7(), // Goals
        ]);
        break;
      case LifeStage.menopause:
        steps.addAll([
          _buildMenopauseStep4(), // Duration
          _buildMenopauseStep5(), // Symptoms
          _buildMenopauseStep6(), // Goals
        ]);
        break;
    }

    return steps;
  }

  bool _isStepInputValid() {
    if (_currentStepIndex == 0) return _profile.preferredName.trim().isNotEmpty;
    if (_currentStepIndex == 1) {
      if (_profile.dateOfBirth == null) return false;
      final age = _userAge;
      if (age != null && age < 9) return false;
      return true;
    }
    if (_currentStepIndex == 2) {
      if (_profile.lifeStage == null) return false;
      return _isStageAllowedForAge(_profile.lifeStage!, _userAge);
    }

    final stage = _profile.lifeStage;
    if (stage == null) return false;

    final branchStep = _currentStepIndex - 3;

    if (stage == LifeStage.firstPeriodNotStarted) {
      if (branchStep == 0) return _profile.answers['not_started_learn'] != null;
      if (branchStep == 1) return _profile.symptoms.isNotEmpty;
      if (branchStep == 2) return _profile.goals.isNotEmpty;
    }
    if (stage == LifeStage.firstPeriodStarted) {
      if (branchStep == 0) return _profile.answers['first_period_start_time'] != null;
      if (branchStep == 1) return _profile.answers['first_period_regularity'] != null;
      if (branchStep == 2) return _profile.symptoms.isNotEmpty;
      if (branchStep == 3) return _profile.goals.isNotEmpty;
    }
    if (stage == LifeStage.reproductiveYears) {
      if (branchStep == 0) return _profile.answers['reproductive_cycle_type'] != null;
      if (branchStep == 1) return _profile.lastPeriod != null || _profile.answers['last_period_unknown'] == true;
      if (branchStep == 2) return _profile.answers['contraception_choice'] != null;
      if (branchStep == 3) return _profile.goals.isNotEmpty;
      if (branchStep == 4) return _profile.symptoms.isNotEmpty;
    }
    if (stage == LifeStage.hormonalHealth) {
      if (branchStep == 0) return _profile.conditions.isNotEmpty;
      if (branchStep == 1) return _profile.symptoms.isNotEmpty;
      if (branchStep == 2) return _profile.answers['hormonal_treatment'] != null;
      if (branchStep == 3) return _profile.goals.isNotEmpty;
    }
    if (stage == LifeStage.tryingToConceive) {
      if (branchStep == 0) return _profile.answers['ttc_duration'] != null;
      if (branchStep == 1) return _profile.answers['ttc_tracking_method'] != null;
      if (branchStep == 2) return _profile.answers['ttc_treatment'] != null;
      if (branchStep == 3) return _profile.symptoms.isNotEmpty;
      if (branchStep == 4) return _profile.goals.isNotEmpty;
    }
    if (stage == LifeStage.pregnancy) {
      if (branchStep == 0) return _profile.dueDate != null;
      if (branchStep == 1) return _profile.answers['pregnancy_first'] != null;
      if (branchStep == 2) return _profile.symptoms.isNotEmpty;
      if (branchStep == 3) return _profile.goals.isNotEmpty;
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
      if (branchStep == 2) return _profile.answers['perimenopause_therapy'] != null;
      if (branchStep == 3) return _profile.goals.isNotEmpty;
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
    final String chosenStage = (_profile.lifeStage != null)
        ? _profile.lifeStage!.name
        : (_profile.answers.containsKey('ttc_duration') || _profile.answers.containsKey('ttc_tracking_method') || _profile.answers.containsKey('ttc_treatment')
            ? 'tryingToConceive'
            : (_profile.answers.containsKey('not_started_learn')
                ? 'firstPeriodNotStarted'
                : (_profile.answers.containsKey('first_period_start_time')
                    ? 'firstPeriodStarted'
                    : (_profile.answers.containsKey('hormonal_treatment')
                        ? 'hormonalHealth'
                        : (_profile.dueDate != null
                            ? 'pregnancy'
                            : (_profile.babyBirthDate != null || _profile.answers.containsKey('postpartum_feeding')
                                ? 'postpartum'
                                : (_profile.answers.containsKey('perimenopause_cycle_change')
                                    ? 'perimenopause'
                                    : (_profile.answers.containsKey('menopause_duration')
                                        ? 'menopause'
                                        : 'reproductiveYears'))))))));

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
    if (_profile.answers['postpartum_feeding']?.toString().toLowerCase().contains('breast') == true) {
      lifeContexts.add(LifeContext.breastfeeding);
    }
    if (_profile.answers['contraception_choice'] == 'Birth control pill' ||
        _profile.answers['contraception_choice'] == 'Hormonal IUD / Implant') {
      lifeContexts.add(LifeContext.hormonalContraception);
    }

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
        userSymptoms: Set<String>.from(_profile.symptoms),
        medicalConditions: medicalConditions,
        dueDate: _profile.dueDate,
        babyBirthDate: _profile.babyBirthDate,
        preferences: UserPreferences(),
        cycleLength: rawAnswerPeriod != null ? cycleCalc.cycleLength : userCycleLength,
        cycleDay: rawAnswerPeriod != null ? cycleCalc.currentCycleDay : null,
        cyclePhase: rawAnswerPeriod != null ? cycleCalc.currentPhase : null,
        lastPeriodStart: rawAnswerPeriod,
        medications: [],
      ),
    );

    // Complete authentication flags
    state.setAuthenticated(true);
    state.setOnboardingCompleted(true);

    // Route to main page
    Navigator.of(context).pushReplacementNamed('/home');
  }

  /// Records the chosen branch with the life stage engine, carrying the
  /// context that branch needs to render immediately.
  Future<void> _enterLifeStage(String chosenStage) async {
    final context = <String, dynamic>{
      if (_profile.lastPeriod != null)
        'last_period_start': _profile.lastPeriod!.toIso8601String().split('T').first,
      if (_profile.dueDate != null)
        'due_date': _profile.dueDate!.toIso8601String().split('T').first,
      if (_profile.babyBirthDate != null)
        'baby_birth_date': _profile.babyBirthDate!.toIso8601String().split('T').first,
      if (_profile.conditions.isNotEmpty) 'diagnosed_conditions': _profile.conditions,
      if (_profile.symptoms.isNotEmpty) 'symptoms': _profile.symptoms,
      if (_profile.goals.isNotEmpty) 'goals': _profile.goals,
      ..._profile.answers,
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
      backgroundColor: const Color(0xFFFAF7F2), // Warm Cream Neutral (STAGE1_DESIGN_RULES)
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 20, left: 20, right: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          // Brand Shield Badge
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFECEB),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFEFE8E0), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFDD0D22).withValues(alpha: 0.12),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              size: 28,
                              color: Color(0xFFDD0D22),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Category Eyebrow
                          Text(
                            "DATA SOVEREIGNTY & PRIVACY",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: const Color(0xFFDD0D22),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Editorial Headline
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: "Your health. "),
                                TextSpan(
                                  text: "Your privacy.",
                                  style: GoogleFonts.cormorantGaramond(
                                    fontStyle: FontStyle.italic,
                                    color: const Color(0xFFDD0D22),
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              color: const Color(0xFF221510),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            "Blushy is built as your private wellness sanctuary. Everything you share is protected with local device encryption and remains under your absolute control.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              height: 1.45,
                              color: const Color(0xFF7A6B72),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 3 Luxury Privacy Pillars Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFEFE8E0), width: 1.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 14,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildPrivacyPillar(
                                  icon: Icons.lock_outline_rounded,
                                  title: "On-Device Encryption",
                                  subtitle: "Sensitive health logs encrypted locally before storing.",
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(color: Color(0xFFF3EEE9), height: 1),
                                ),
                                _buildPrivacyPillar(
                                  icon: Icons.phonelink_erase_rounded,
                                  title: "Zero Data Selling",
                                  subtitle: "We never monetize, broker, or share your health records.",
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(color: Color(0xFFF3EEE9), height: 1),
                                ),
                                _buildPrivacyPillar(
                                  icon: Icons.admin_panel_settings_outlined,
                                  title: "Complete Sovereignty",
                                  subtitle: "Export or permanently erase your data whenever you choose.",
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Controls (Unified White Card with 3 Check Rows + CTA)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFEFE8E0), width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildInteractiveConsentRow(
                              titlePrefix: AppLocalizations.of(context).oIAgreeToThe,
                              linkText: AppLocalizations.of(context).oPrivacyPolicy,
                              isChecked: _agreePrivacy,
                              onTapLink: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.privacyPolicy),
                              onChanged: (val) => setState(() => _agreePrivacy = val),
                            ),
                            const Divider(color: Color(0xFFF3EEE9), height: 1),
                            _buildInteractiveConsentRow(
                              titlePrefix: AppLocalizations.of(context).oIAgreeToThe,
                              linkText: AppLocalizations.of(context).oTermsOfService,
                              isChecked: _agreeTerms,
                              onTapLink: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.termsAndConditions),
                              onChanged: (val) => setState(() => _agreeTerms = val),
                            ),
                            const Divider(color: Color(0xFFF3EEE9), height: 1),
                            _buildInteractiveConsentRow(
                              titlePrefix: AppLocalizations.of(context).oIAgreeToThe,
                              linkText: AppLocalizations.of(context).oMedicalDisclaimer,
                              isChecked: _agreeDisclaimer,
                              onTapLink: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.medicalDisclaimer),
                              onChanged: (val) => setState(() => _agreeDisclaimer = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // CTA Button: Brand Crimson 48px Pill
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (_hasAgreedToEverything && !_recordingConsent)
                              ? _recordConsentAndContinue
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDD0D22),
                            disabledBackgroundColor: const Color(0xFFEFE8E0),
                            disabledForegroundColor: const Color(0xFFAFA59E),
                            elevation: _hasAgreedToEverything ? 2 : 0,
                            shadowColor: const Color(0xFFDD0D22).withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _recordingConsent
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  "Agree & Continue",
                                  style: GoogleFonts.manrope(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                    color: _hasAgreedToEverything ? Colors.white : const Color(0xFFAFA59E),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Records the acceptance, then moves on.
  Future<void> _recordConsentAndContinue() async {
    if (!_hasAgreedToEverything || _recordingConsent) return;

    setState(() => _recordingConsent = true);

    final result = await ApiConsentService().accept(method: 'onboarding');

    if (!mounted) return;
    setState(() => _recordingConsent = false);

    if (result.failure == ConsentFailure.appOutOfDate) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Please update Blushy'),
          content: Text(
            result.message ??
                'Our privacy policy and terms have been updated since this version of the app was '
                    'released. Please update Blushy so you can read the current version before agreeing to it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _phase = OnboardingPhase.questions;
    });
    _saveProgress();
  }

  Widget _buildPrivacyPillar({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFECEB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFFDD0D22)),
        ),
        const SizedBox(width: 12),
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
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF7A6B72),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveConsentRow({
    required String titlePrefix,
    required String linkText,
    required bool isChecked,
    required VoidCallback onTapLink,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!isChecked),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked ? const Color(0xFFDD0D22) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked ? const Color(0xFFDD0D22) : const Color(0xFFD4C8BE),
                  width: 1.4,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: titlePrefix,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF221510),
                      ),
                    ),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: onTapLink,
                        child: Text(
                          linkText,
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFDD0D22),
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFFDD0D22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: BlushyColors.secondaryText,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
          height: 2,
          decoration: BoxDecoration(
            color: BlushyColors.border,
            borderRadius: BorderRadius.circular(1),
          ),
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: progress),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
            builder: (context, val, child) {
              return FractionallySizedBox(
                widthFactor: val,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: BlushyColors.primary,
                    borderRadius: BorderRadius.circular(1),
                  ),
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
          style: GoogleFonts.cormorantGaramond(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
            color: BlushyColors.text,
            height: 1.18,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: BlushyColors.secondaryText,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 20),
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
              padding: const EdgeInsets.only(left: 20, right: 20, top: 36, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  _buildPremiumProgressHeader(progress, stepLabel),
                  const SizedBox(height: 32),

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
                            style: GoogleFonts.manrope(
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

  // --- 3. BUILDING SCREEN ---
  Widget _buildBuildingScreen() {
    final listItems = [
      "Securing your privacy vault",
      "Personalizing cycle & body rhythm models",
      "Initializing Docsy AI companion context",
      "Preparing daily wellness recommendations",
      "Setting up your personal dashboard"
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ambient pulse icon badge
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F1),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF4DCD6), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: BlushyColors.primary.withValues(alpha: 0.12),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 34,
                      color: BlushyColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "Creating your wellness space...",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.normal,
                      letterSpacing: 0.3,
                      height: 1.15,
                      color: Color(0xFF2D2529),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Checklist Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDF9),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFECE4DC), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: List.generate(listItems.length, (idx) {
                        final isDone = _buildingChecks[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isDone ? BlushyColors.primary : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDone ? BlushyColors.primary : const Color(0xFFD6CBC3),
                                    width: 1.5,
                                  ),
                                ),
                                child: isDone
                                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  listItems[idx],
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 13,
                                    color: isDone ? const Color(0xFF2D2529) : const Color(0xFF8A7C83),
                                    fontWeight: isDone ? FontWeight.w700 : FontWeight.w400,
                                    letterSpacing: 0.15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Linear progress indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _buildingProgress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFECE4DC),
                      valueColor: AlwaysStoppedAnimation<Color>(BlushyColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${(_buildingProgress * 100).toInt()}%",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.primary,
                      letterSpacing: 0.3,
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

  String _toTitleCase(String input) {
    if (input.trim().isEmpty) return '';
    return input.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // --- 4. DR. DOCSY WELCOME SCREEN ---
  Widget _buildSiaWelcomeScreen() {
    final String rawName = _profile.preferredName.trim();
    final String formattedName = rawName.isNotEmpty ? _toTitleCase(rawName) : 'there';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Section: Sparkle Badge, Title, and Promise Card
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      // Soft Glowing Sparkle Badge
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4F1),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF4DCD6), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: BlushyColors.primary.withValues(alpha: 0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 30,
                          color: BlushyColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Headline: Cormorant Garamond w700 Title Case
                      Text(
                        "Hi, $formattedName.\nI'm Docsy.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.normal,
                          letterSpacing: 0.2,
                          height: 1.15,
                          color: const Color(0xFF2D2529),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Your private wellness companion",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8A7C83),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sanctuary Promises Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDF9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFECE4DC), width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildWelcomePromiseRow(
                              icon: Icons.psychology_outlined,
                              title: "Adapts To You",
                              subtitle: "Learns alongside your logs and adapts as your body's rhythm changes.",
                            ),
                            const SizedBox(height: 14),
                            _buildWelcomePromiseRow(
                              icon: Icons.favorite_border_rounded,
                              title: "Daily Wellness Care",
                              subtitle: "Helps you understand your body, symptoms, and self-care daily.",
                            ),
                            const SizedBox(height: 14),
                            _buildWelcomePromiseRow(
                              icon: Icons.sanitizer_outlined,
                              title: "Private & Confidential",
                              subtitle: "A safe space to reflect without judgment.",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Bottom Section: CTA Pill Button and Security Note
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _phase = OnboardingPhase.ready;
                            });
                            _saveProgress();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BlushyColors.primary,
                            elevation: 3,
                            shadowColor: BlushyColors.primary.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            "Start My Journey",
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.normal,
                              letterSpacing: 0.35,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF9E8A94)),
                          const SizedBox(width: 4),
                          Text(
                            "Encrypted locally on your device",
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF9E8A94),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePromiseRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4F1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: BlushyColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D2529),
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF7A6B72),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 5. YOUR BLUSHY IS READY SCREEN ---
  Widget _buildReadyScreen() {
    final readyItems = [
      {
        'icon': Icons.home_outlined,
        'title': 'Personalized Home',
        'subtitle': 'Customized layout',
      },
      {
        'icon': Icons.auto_awesome_rounded,
        'title': 'Dr. Docsy AI',
        'subtitle': 'Companion ready',
      },
      {
        'icon': Icons.insights_rounded,
        'title': 'Daily Insights',
        'subtitle': 'Rhythm tailored',
      },
      {
        'icon': Icons.book_outlined,
        'title': 'Private Journal',
        'subtitle': 'Encrypted & secure',
      },
      {
        'icon': Icons.people_outline_rounded,
        'title': 'Community Circle',
        'subtitle': 'Matched support',
      },
      {
        'icon': Icons.timeline_rounded,
        'title': 'Cycle Timeline',
        'subtitle': 'Tracking active',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Section: Check Badge, Title, and 2-Column Grid
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      // Soft Glowing Check Badge
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4F1),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF4DCD6), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: BlushyColors.primary.withValues(alpha: 0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 32,
                          color: BlushyColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        "Your Blushy is Ready",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.normal,
                          letterSpacing: 0.2,
                          height: 1.15,
                          color: const Color(0xFF2D2529),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Everything is tailored around your personal rhythm.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8A7C83),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2-Column Grid of 6 Feature Cards
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: readyItems.length,
                        itemBuilder: (context, index) {
                          final item = readyItems[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFDF9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFECE4DC), width: 1.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF4F1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    item['icon'] as IconData,
                                    size: 16,
                                    color: BlushyColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.manrope(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2D2529),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        item['subtitle'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w400,
                                          color: const Color(0xFF8A7C83),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: Color(0xFF2B7A4B),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Bottom Section CTA
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _finishOnboarding,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BlushyColors.primary,
                            elevation: 3,
                            shadowColor: BlushyColors.primary.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            "Enter Blushy",
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.normal,
                              letterSpacing: 0.35,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Tap to enter your personal wellness space",
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9E8A94),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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
    String explanation = "This clinical context ensures your home cards, predictions, and companion responses are medically aligned with your exact journey.";
    
    if (_currentStepIndex == 0) {
      explanation = "Your preferred name is used by Docsy to personalize daily wellness notes and compassionate check-ins.";
    } else if (_currentStepIndex == 1) {
      explanation = "Your date of birth ensures all biological tracking, cycle prediction ranges, and educational content are clinically appropriate for your age.";
    } else if (_currentStepIndex == 2) {
      explanation = "Selecting your life stage tailors the clinical tracking algorithms, biomarker checklists, and home dashboard layout to your current hormonal phase.";
    } else if (_profile.lifeStage != null) {
      final branchStep = _currentStepIndex - 3;
      final stage = _profile.lifeStage!;
      if (stage == LifeStage.firstPeriodNotStarted) {
        if (branchStep == 0) explanation = "Understanding your focus areas allows Docsy to tailor puberty preparation guides to what matters most to you right now.";
        if (branchStep == 1) explanation = "Tracking bodily shifts like growth spurts or discharge helps estimate readiness without anxiety or medical jargon.";
        if (branchStep == 2) explanation = "Your comfort priorities shape which practical tips and conversation guides we highlight first.";
      } else if (stage == LifeStage.firstPeriodStarted) {
        if (branchStep == 0) explanation = "Early cycles often take 1 to 2 years to mature. Knowing your start timeline calibrates the irregularity window.";
        if (branchStep == 1) explanation = "Young cycles naturally fluctuate due to anovulatory cycles. This informs our prediction algorithms.";
        if (branchStep == 2) explanation = "Logging early symptoms helps identify patterns like cramps or mood changes before flow begins.";
        if (branchStep == 3) explanation = "Your goals customize your daily dashboard so you feel confident at school, sports, and home.";
      } else if (stage == LifeStage.reproductiveYears) {
        if (branchStep == 0) explanation = "Typical cycle lengths span 21 to 35 days. Your cycle regularity tunes our baseline ovulation and phase engines.";
        if (branchStep == 1) explanation = "Your latest period start date anchors your follicular, ovulatory, and luteal phase calculations.";
        if (branchStep == 2) explanation = "Hormonal contraception alters natural ovulation patterns; knowing this ensures we provide biologically accurate advice.";
        if (branchStep == 3) explanation = "Connecting your recurrent symptoms enables proactive phase-synced relief strategies on your home cards.";
        if (branchStep == 4) explanation = "Your primary goals determine which lifestyle and wellness trackers are pinned to your home screen.";
      } else if (stage == LifeStage.hormonalHealth) {
        if (branchStep == 0) explanation = "Targeted protocols for PCOS, endometriosis, or PMDD adjust our hormonal insight models specifically for your condition.";
        if (branchStep == 1) explanation = "Monitoring key symptoms helps track treatment response, inflammatory flare-ups, and cyclic variations.";
        if (branchStep == 2) explanation = "Knowing your treatment context helps Docsy complement your physician care with lifestyle and nutrition support.";
        if (branchStep == 3) explanation = "Your focus areas determine whether pain management, metabolic balance, or mood support takes priority.";
      } else if (stage == LifeStage.tryingToConceive) {
        if (branchStep == 0) explanation = "TTC timelines guide clinically appropriate fertility tracking advice and clinical consultation markers.";
        if (branchStep == 1) explanation = "Synchronizing with your tracking method (LH strips, BBT, cervical mucus) refines fertile window predictions.";
        if (branchStep == 2) explanation = "Understanding clinical treatments ensures Docsy aligns with medical protocols and appointment tracking.";
        if (branchStep == 3) explanation = "Fertility symptoms like ovulation cramps or mucus changes offer real-time biological clues of fertile days.";
        if (branchStep == 4) explanation = "Your goals shape our preconception nutrition, partner synchronization, and stress-reduction insights.";
      } else if (stage == LifeStage.pregnancy) {
        if (branchStep == 0) explanation = "Your estimated due date calculates exact gestational weeks, fetal developmental stages, and trimester markers.";
        if (branchStep == 1) explanation = "First-time and subsequent pregnancies carry distinct physical and emotional expectations.";
        if (branchStep == 2) explanation = "Tracking trimester symptoms provides timely obstetric comfort measures and flags warning signs.";
        if (branchStep == 3) explanation = "Your goals tailor weekly baby growth cards, nutrition advice, and birth preparation checklists.";
      } else if (stage == LifeStage.postpartum) {
        if (branchStep == 0) explanation = "Your baby's birth date sets the postpartum recovery timeline (the 'fourth trimester') for healing milestones.";
        if (branchStep == 1) explanation = "Feeding methods directly impact maternal caloric requirements, hydration needs, and prolactin cycles.";
        if (branchStep == 2) explanation = "Monitoring lochia, pelvic floor sensations, and emotional wellbeing supports comprehensive maternal recovery.";
        if (branchStep == 3) explanation = "Your priorities personalize newborn logging, pelvic floor rehab, and gentle mental wellness check-ins.";
      } else if (stage == LifeStage.perimenopause) {
        if (branchStep == 0) explanation = "Perimenopause transition is marked by fluctuating cycle lengths and skipping months as ovarian reserve changes.";
        if (branchStep == 1) explanation = "Vasomotor and neuroendocrine symptoms like hot flashes and night sweats guide targeted symptom-relief strategies.";
        if (branchStep == 2) explanation = "Knowing your therapy status helps Docsy support symptom tracking for doctor reviews.";
        if (branchStep == 3) explanation = "Your goals determine whether sleep restoration, cognitive clarity, or metabolic vitality takes front stage.";
      } else if (stage == LifeStage.menopause) {
        if (branchStep == 0) explanation = "Menopause is officially reached after 12 consecutive months without a period. Timeline details guide post-menopausal care.";
        if (branchStep == 1) explanation = "Monitoring estrogen-related symptoms like hot flashes and joint stiffness helps preserve vitality and comfort.";
        if (branchStep == 2) explanation = "Longevity goals guide daily nutrition, bone-density exercises, and cardiovascular wellness metrics.";
      }
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
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
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
              style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
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
          style: GoogleFonts.cormorantGaramond(fontSize: 34, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "What name would you like Docsy to call you?",
          style: GoogleFonts.manrope(fontSize: 13.5, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nameController,
          autofocus: true,
          style: GoogleFonts.manrope(fontSize: 18, color: BlushyColors.text),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).oYourPreferredName,
            hintStyle: GoogleFonts.manrope(color: BlushyColors.secondaryText.withValues(alpha: 0.5)),
            border: const UnderlineInputBorder(borderSide: BorderSide(color: BlushyColors.border)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: BlushyColors.primary, width: 2)),
          ),
        ),
      ],
    );
  }

  // Step 2: Date of Birth
  Widget _buildDobStep() {
    final age = _userAge;
    final isUnderage = age != null && age < 9;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).oWhenIsYourBirthday,
          style: GoogleFonts.cormorantGaramond(fontSize: 34, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "Knowing your birthday helps customize age-based biology recommendations.",
          style: GoogleFonts.manrope(fontSize: 13.5, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 32),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _profile.dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 24)),
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
                // If lifeStage was previously selected and is no longer valid for new age, clear it
                if (_profile.lifeStage != null && !_isStageAllowedForAge(_profile.lifeStage!, _calculateAge(picked))) {
                  _profile.lifeStage = null;
                }
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
                      : "${_profile.dateOfBirth!.day}/${_profile.dateOfBirth!.month}/${_profile.dateOfBirth!.year}${age != null ? '  (Age $age)' : ''}",
                  style: GoogleFonts.manrope(
                    fontSize: 16, 
                    fontWeight: _profile.dateOfBirth == null ? FontWeight.w400 : FontWeight.w600,
                    color: _profile.dateOfBirth == null ? BlushyColors.secondaryText : BlushyColors.text
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18, color: BlushyColors.primary),
              ],
            ),
          ),
        ),
        if (isUnderage) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD5D2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: BlushyColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Blushy is medically calibrated for individuals aged 9 and older experiencing or preparing for menstrual and hormonal transitions. For children under 9, please consult a pediatrician or pediatric endocrinologist for developmental questions.",
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF9E1B22),
                      height: 1.45,
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

  // Step 3: Life Stage Choices
  Widget _buildStageStep() {
    final stages = [
      {
        "label": "First Period (Not Started)",
        "value": LifeStage.firstPeriodNotStarted,
        "desc": "Puberty bodily changes & preparing for your first cycle.",
        "ageRange": "Ages 9–17",
      },
      {
        "label": "First Period (Started)",
        "value": LifeStage.firstPeriodStarted,
        "desc": "Cycle tracking confidence, early flow patterns & comfort.",
        "ageRange": "Ages 9–19",
      },
      {
        "label": "Living with my cycle",
        "value": LifeStage.reproductiveYears,
        "desc": "Cycle tracking, energy syncing, PMS & phase-synced living.",
        "ageRange": "Ages 13–51",
      },
      {
        "label": "Hormonal Health",
        "value": LifeStage.hormonalHealth,
        "desc": "Targeted support for PCOS, PMDD, endometriosis & hormonal balance.",
        "ageRange": "Ages 13+",
      },
      {
        "label": "Trying to Conceive",
        "value": LifeStage.tryingToConceive,
        "desc": "Fertility analysis, ovulation timing, LH strips & conception wellness.",
        "ageRange": "Ages 18–50",
      },
      {
        "label": "Pregnancy",
        "value": LifeStage.pregnancy,
        "desc": "Weekly baby growth milestones, trimester symptoms & maternity health.",
        "ageRange": "Ages 18–50",
      },
      {
        "label": "Postpartum & New Mother",
        "value": LifeStage.postpartum,
        "desc": "Physical recovery, newborn feeding, pelvic floor & maternal healing.",
        "ageRange": "Ages 18–50",
      },
      {
        "label": "Perimenopause",
        "value": LifeStage.perimenopause,
        "desc": "Tracking cycle shifts, vasomotor flushes & hormonal transition.",
        "ageRange": "Ages 35–55",
      },
      {
        "label": "Menopause & Post-Menopause",
        "value": LifeStage.menopause,
        "desc": "Bone wellness, hot flash management & healthy longevity.",
        "ageRange": "Ages 40+",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).oWhereAreYouToday,
          style: GoogleFonts.cormorantGaramond(fontSize: 34, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "This selection defines the clinical tracking layout for your onboarding questionnaire and home dashboard.",
          style: GoogleFonts.manrope(fontSize: 13.5, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        ...stages.map((stage) {
          final stageValue = stage['value'] as LifeStage;
          final isAllowed = _isStageAllowedForAge(stageValue, _userAge);
          final isSelected = _profile.lifeStage == stageValue;
          return _buildPremiumSelectionRow(
            title: stage['label'] as String,
            desc: stage['desc'] as String,
            badge: stage['ageRange'] as String?,
            isSelected: isSelected,
            isLocked: !isAllowed,
            onTap: () {
              if (!isAllowed) {
                _showStageAgeGuidance(stageValue);
              } else {
                setState(() {
                  _profile.lifeStage = stageValue;
                });
                _saveProgress();
              }
            },
          );
        }),
      ],
    );
  }

  // --- BRANCH A: FIRST PERIOD (NOT STARTED) ---
  Widget _buildNotStartedStep4() {
    final options = [
      "Puberty & bodily changes",
      "Preparing for my first period",
      "Hygiene & period care products",
      "Mood, emotions & changes in feelings",
      "School, sports & swimming with a period"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oWhatWouldYouLike,
      subtitle: "We'll build custom guides to help you feel completely prepared.",
      options: options,
      storageKey: "not_started_learn",
    );
  }

  Widget _buildNotStartedStep5() {
    final options = [
      "Growth spurts / Getting taller",
      "Body hair changes (underarm or pubic)",
      "Skin breakouts / Acne",
      "Vaginal discharge (white or clear)",
      "Mild lower tummy aches / Cramps",
      "Mood swings / Sensitive emotions",
      "Breast budding / Chest tenderness",
      "None yet / Not sure"
    ];
    return _buildMultiSelectSymptomsStep(
      title: "What changes have you noticed?",
      subtitle: "It's normal for changes to occur in any order. Pick all that you notice.",
      options: options,
    );
  }

  Widget _buildNotStartedStep6() {
    final options = [
      "Feel prepared before it starts",
      "Understand my changing body",
      "Know what products to use",
      "Learn how to talk to a parent or adult",
      "Feel confident and calm at school"
    ];
    return _buildMultiSelectGoalsStep(
      title: "What would help you feel most confident?",
      subtitle: "Select everything you'd like Docsy to guide you through.",
      options: options,
    );
  }

  // --- BRANCH B: FIRST PERIOD (STARTED) ---
  Widget _buildStartedStep4() {
    final options = [
      "Within the last 3 months",
      "3–6 months ago",
      "6–12 months ago",
      "More than 1 year ago"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oWhenDidYourFirst,
      subtitle: "This helps Docsy calibrate early cycle irregularity ranges.",
      options: options,
      storageKey: "first_period_start_time",
    );
  }

  Widget _buildStartedStep5() {
    final options = [
      "Still irregular / Unpredictable (Normal in early years)",
      "Starting to become regular",
      "I haven't been tracking yet"
    ];
    return _buildSingleSelectBranchStep(
      title: "How predictable are your periods?",
      subtitle: "Early cycles naturally vary. We adjust predictions to match your rhythm.",
      options: options,
      storageKey: "first_period_regularity",
    );
  }

  Widget _buildStartedStep6() {
    final options = [
      "Cramps",
      "Mood swings",
      "Headache",
      "Acne",
      "Heavy flow",
      "Spotting",
      "Fatigue",
      "Back pain",
      "Bloating",
      "Digestive changes",
      "No notable symptoms"
    ];
    return _buildMultiSelectSymptomsStep(
      title: "Which of these do you notice?",
      subtitle: "Pick as many as you like. Your home page shows what you track.",
      options: options,
    );
  }

  Widget _buildStartedStep7() {
    final options = [
      "Predict when my period arrives",
      "Ease cramps and physical discomfort",
      "Track mood and energy shifts",
      "Feel secure with hygiene & flow management",
      "Confident in sports & physical activity"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatWouldYouLike2,
      subtitle: "Select all goals that apply to your journey.",
      options: options,
    );
  }

  // --- BRANCH C: REPRODUCTIVE YEARS ---
  Widget _buildReproductiveStep4() {
    final options = [
      "Regular (21–35 days)",
      "Somewhat irregular",
      "Frequently irregular",
      "I don't track yet"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowWouldYouDescribe,
      subtitle: "Typical cycles range between 21 and 35 days.",
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
          style: GoogleFonts.cormorantGaramond(fontSize: 34, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "Used to forecast your upcoming cycle length and biological phases.",
          style: GoogleFonts.manrope(fontSize: 13.5, color: BlushyColors.secondaryText),
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
                  style: GoogleFonts.manrope(
                    fontSize: 16, 
                    fontWeight: _profile.lastPeriod == null ? FontWeight.w400 : FontWeight.w600,
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
          title: Text(AppLocalizations.of(context).onbDontRemember, style: GoogleFonts.manrope(fontSize: 14)),
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
            style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            "Helps Docsy calculate your exact cycle length and pattern right away.",
            style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText),
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
                    style: GoogleFonts.manrope(fontSize: 13, color: BlushyColors.text),
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
                label: Text("+ Add earlier period date", style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.primary)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildReproductiveStep6() {
    final options = [
      "No hormonal contraception",
      "Combined pill / Patch / Ring",
      "Progestin-only (Mini-pill / Implant / Depo)",
      "Hormonal IUD",
      "Copper IUD (non-hormonal)",
      "Prefer not to say"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oAreYouCurrentlyUsing,
      subtitle: "Hormonal contraception alters natural ovulatory surges.",
      options: options,
      storageKey: "contraception_choice",
    );
  }

  Widget _buildReproductiveStep7() {
    final options = [
      "Predict periods & cycle phases",
      "Manage cramps & PMS",
      "Optimize daily energy & fitness",
      "Track ovulation & fertility windows",
      "Improve sleep & stress resilience",
      "Skin & nutrition support",
      "Medication & habit reminders"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatWouldYouLike3,
      subtitle: "Docsy prioritizes these on your home dashboard.",
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
      "Pelvic pain",
      "No notable symptoms"
    ];
    return _buildMultiSelectSymptomsStep(
      title: "Which of these do you notice?",
      subtitle: "Pick as many as you like. Your home page shows what you track.",
      options: options,
    );
  }

  // --- BRANCH D: HORMONAL HEALTH ---
  Widget _buildHormonalStep4() {
    final options = [
      "PCOS (Polycystic Ovary Syndrome)",
      "Endometriosis",
      "Fibroids",
      "Adenomyosis",
      "Thyroid disorder (Hypo/Hyper)",
      "PMDD (Premenstrual Dysphoric Disorder)",
      "Investigating / Not yet formally diagnosed"
    ];
    return _buildMultiSelectConditionsStep(
      title: AppLocalizations.of(context).oWhichConditionBestMatches,
      subtitle: "Helps tailor condition-specific tracking modules.",
      options: options,
    );
  }

  Widget _buildHormonalStep5() {
    final options = [
      "Severe pelvic pain",
      "Irregular / Missing periods",
      "Cramps",
      "Acne",
      "Hair thinning / Hair loss",
      "Hirsutism (Excess facial/body hair)",
      "Weight fluctuations",
      "Fatigue",
      "Mood swings / PMDD lows",
      "Insomnia / Sleep disruption",
      "Bloating & gut issues",
      "Headache / Migraines",
      "Heavy menstrual bleeding",
      "No notable symptoms"
    ];
    return _buildMultiSelectSymptomsStep(
      title: AppLocalizations.of(context).oWhichSymptomsAffectYou,
      subtitle: "Docsy adapts tracking cards to prioritize these.",
      options: options,
    );
  }

  Widget _buildHormonalStep6() {
    final options = [
      "Working with a doctor / On treatment",
      "Managing through lifestyle & nutrition",
      "Seeking answers / Diagnostic phase",
      "Not currently receiving treatment"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oAreYouCurrentlyReceiving,
      subtitle: "Helps Docsy complement your physician's care plan.",
      options: options,
      storageKey: "hormonal_treatment",
    );
  }

  Widget _buildHormonalStep7() {
    final options = [
      "Hormone & cycle regulation",
      "Chronic pain management",
      "Skin & hair health balance",
      "Metabolic & weight wellness",
      "Emotional balance & mental health",
      "Fertility preservation & planning",
      "Doctor visit logs & symptom summaries"
    ];
    return _buildMultiSelectGoalsStep(
      title: "What support would help most?",
      subtitle: "Tailor your hormonal health tracking workspace.",
      options: options,
    );
  }

  // --- BRANCH E: TRYING TO CONCEIVE ---
  Widget _buildTtcStep4() {
    final options = [
      "Just starting (< 3 months)",
      "3–6 months",
      "6–12 months",
      "Over 12 months"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowLongHaveYou,
      subtitle: "Helps adjust clinical fertile tracking recommendations.",
      options: options,
      storageKey: "ttc_duration",
    );
  }

  Widget _buildTtcStep5() {
    final options = [
      "Ovulation prediction kits (LH strips)",
      "Basal Body Temperature (BBT)",
      "Cervical fluid / mucus observation",
      "Calendar / Cycle math only",
      "Not tracking fertility markers yet"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowAreYouTracking,
      subtitle: "Select the primary biomarker you observe.",
      options: options,
      storageKey: "ttc_tracking_method",
    );
  }

  Widget _buildTtcStep6() {
    final options = [
      "Natural conception (No clinical assistance)",
      "Ovulation induction (e.g. Clomid/Letrozole)",
      "IUI (Intrauterine Insemination)",
      "IVF (In Vitro Fertilization)",
      "Preconception medical checkups"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oAreYouCurrentlyReceiving2,
      subtitle: "Tailors recommendations around your clinical care.",
      options: options,
      storageKey: "ttc_treatment",
    );
  }

  Widget _buildTtcStep7() {
    final options = [
      "Ovulation cramping (Mittelschmerz)",
      "Cervical mucus shifts",
      "Breast tenderness",
      "Pelvic pain",
      "Spotting",
      "Fatigue",
      "Mood fluctuations",
      "Bloating",
      "Headache",
      "Anxiety / TTC stress",
      "No notable symptoms"
    ];
    return _buildMultiSelectSymptomsStep(
      title: "Which bodily signs do you notice?",
      subtitle: "Tracks ovulation biomarkers and hormonal sensations.",
      options: options,
    );
  }

  Widget _buildTtcStep8() {
    final options = [
      "Pinpoint fertile window & ovulation peak",
      "Understand basal body temperature patterns",
      "Preconception nutrition & prenatal prep",
      "Sperm-egg friendly lifestyle guidance",
      "Stress & emotional wellness support",
      "Partner sync & fertile timing notifications"
    ];
    return _buildMultiSelectGoalsStep(
      title: "What are your conception priorities?",
      subtitle: "We'll optimize your daily fertility window analysis.",
      options: options,
    );
  }

  // --- BRANCH F: PREGNANCY ---
  Widget _buildPregnancyStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).oWhatSYourDue,
          style: GoogleFonts.cormorantGaramond(fontSize: 34, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "Calculates gestational week and baby growth size benchmarks.",
          style: GoogleFonts.manrope(fontSize: 13.5, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _profile.dueDate ?? DateTime.now().add(const Duration(days: 140)),
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
                  style: GoogleFonts.manrope(
                    fontSize: 16, 
                    fontWeight: _profile.dueDate == null ? FontWeight.w400 : FontWeight.w600,
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
    final options = ["Yes, first pregnancy", "No, have experienced pregnancy before"];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oIsThisYourFirst,
      subtitle: "Personalizes education pacing and clinical reassurance.",
      options: options,
      storageKey: "pregnancy_first",
    );
  }

  Widget _buildPregnancyStep6() {
    final options = [
      "Morning sickness / Nausea",
      "Fatigue / Exhaustion",
      "Tender breasts",
      "Heartburn / Acid reflux",
      "Back pain & pelvic pressure",
      "Food aversions & cravings",
      "Swelling (feet/hands)",
      "Mood fluctuations",
      "Pelvic pain",
      "Insomnia / Restless sleep",
      "No notable symptoms"
    ];
    return _buildMultiSelectSymptomsStep(
      title: "What symptoms are you experiencing?",
      subtitle: "Your dashboard prioritizes trimester-specific relief cards.",
      options: options,
    );
  }

  Widget _buildPregnancyStep7() {
    final options = [
      "Fetal movement & development milestones",
      "Trimester symptom relief",
      "Prenatal safe exercises & walking",
      "Pregnancy nutrition & hydration",
      "Birth plan & labor preparation",
      "Partner involvement & kick counts",
      "Doctor appointment & test reminders"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatSupportWouldYou,
      subtitle: "Customize your pregnancy journey preferences.",
      options: options,
    );
  }

  // --- BRANCH G: POSTPARTUM ---
  Widget _buildPostpartumStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).oWhenWasYourBaby,
          style: GoogleFonts.cormorantGaramond(fontSize: 34, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          "Drives maternal postpartum healing calendars and recovery tracking.",
          style: GoogleFonts.manrope(fontSize: 13.5, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _profile.babyBirthDate ?? DateTime.now(),
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
                  style: GoogleFonts.manrope(
                    fontSize: 16, 
                    fontWeight: _profile.babyBirthDate == null ? FontWeight.w400 : FontWeight.w600,
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
    final options = [
      "Exclusively breastfeeding / chestfeeding",
      "Exclusive pumping",
      "Bottle or formula feeding",
      "Combination feeding (breast & formula)"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowAreYouFeeding,
      subtitle: "Directly personalizes maternal hydration and calorie recommendations.",
      options: options,
      storageKey: "postpartum_feeding",
    );
  }

  Widget _buildPostpartumStep6() {
    final options = [
      "Maternal physical healing & recovery",
      "Pelvic floor, core & kegel rehabilitation",
      "Newborn feeding & pumping logs",
      "Sleep rhythm optimization",
      "Postpartum mental health & baby blues care",
      "Gentle postnatal nourishment",
      "Partner bonding & chore sharing"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatWouldYouLike2,
      subtitle: "Tailor your postpartum recovery workspace.",
      options: options,
    );
  }

  Widget _buildPostpartumStep7() {
    final options = [
      "Bleeding or lochia",
      "Perineal soreness / Episiotomy healing",
      "Incision or stitches recovery",
      "Uterine cramping (Afterpains)",
      "Breast engorgement / Nipple tenderness",
      "Pelvic floor weakness",
      "Extreme exhaustion / Sleep deprivation",
      "Postpartum baby blues / Mood dips",
      "Hair shedding (Postpartum telogen effluvium)",
      "Night sweats",
      "Back pain",
      "No notable symptoms"
    ];
    return _buildMultiSelectSymptomsStep(
      title: "How is your body healing?",
      subtitle: "Pick as many as you notice. Your home page supports what you track.",
      options: options,
    );
  }

  // --- BRANCH H: PERIMENOPAUSE ---
  Widget _buildPerimenopauseStep4() {
    final options = [
      "Cycles getting shorter or longer",
      "Skipping periods / Irregular intervals",
      "Heavier or lighter flow than before",
      "Cycles have nearly stopped (Past 6+ months)"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowHaveYourPeriods,
      subtitle: "Tracks fluctuations in menstrual rhythms during hormonal transition.",
      options: options,
      storageKey: "perimenopause_cycle_change",
    );
  }

  Widget _buildPerimenopauseStep5() {
    final options = [
      "Hot flashes",
      "Night sweats & chills",
      "Brain fog & focus changes",
      "Sleep disturbance / Insomnia",
      "Mood changes & irritability",
      "Fatigue & low energy",
      "Joint aches & muscle stiffness",
      "Weight & metabolic changes",
      "Heart palpitations",
      "Vaginal dryness / Discomfort",
      "Headaches / Migraines",
      "No notable symptoms"
    ];
    return _buildMultiSelectSymptomsStep(
      title: AppLocalizations.of(context).oWhichSymptomsAffectYou,
      subtitle: "Docsy adapts tracking cards to prioritize these.",
      options: options,
    );
  }

  Widget _buildPerimenopauseStep6() {
    final options = [
      "Hormone Replacement Therapy (HRT / MHT)",
      "Non-hormonal prescription therapy",
      "Herbal & nutritional supplements",
      "Lifestyle & holistic management",
      "Exploring options with my doctor"
    ];
    return _buildSingleSelectBranchStep(
      title: "Are you using any therapy or support?",
      subtitle: "Helps tailor recommendations around medical or lifestyle regimens.",
      options: options,
      storageKey: "perimenopause_therapy",
    );
  }

  Widget _buildPerimenopauseStep7() {
    final options = [
      "Track cycle pattern changes accurately",
      "Hot flash & symptom trigger logs",
      "Sleep restoration & night cooling strategies",
      "Cardiovascular & metabolic vitality",
      "Cognitive clarity & mood resilience",
      "Hormone therapy discussion checklists"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatWouldYouMost,
      subtitle: "Saves priorities for home insights and tracking.",
      options: options,
    );
  }

  // --- BRANCH I: MENOPAUSE ---
  Widget _buildMenopauseStep4() {
    final options = [
      "12 to 24 months (Early post-menopause)",
      "2 to 5 years",
      "Over 5 years",
      "Surgical menopause (Oophorectomy / Hysterectomy)"
    ];
    return _buildSingleSelectBranchStep(
      title: AppLocalizations.of(context).oHowLongHasIt,
      subtitle: "Identifies transition stage and bone/cardiovascular care timeline.",
      options: options,
      storageKey: "menopause_duration",
    );
  }

  Widget _buildMenopauseStep5() {
    final options = [
      "Hot flashes / Temperature spikes",
      "Night sweats",
      "Sleep disruption",
      "Vaginal dryness / Genitourinary discomfort",
      "Bone or joint aches",
      "Memory & focus changes",
      "Mood changes / Anxiety",
      "Skin dryness / Elasticity changes",
      "Weight distribution shifts",
      "Cardiovascular awareness",
      "No notable symptoms"
    ];
    return _buildMultiSelectSymptomsStep(
      title: AppLocalizations.of(context).oWhichSymptomsAffectYour,
      subtitle: "Select all that affect your daily comfort.",
      options: options,
    );
  }

  Widget _buildMenopauseStep6() {
    final options = [
      "Bone density & osteoporosis prevention",
      "Cardiovascular & lipid health",
      "Cognitive health & brain vitality",
      "Sleep quality & temperature balance",
      "Pelvic floor & intimacy wellness",
      "Strength training & muscle preservation",
      "Healthy active longevity"
    ];
    return _buildMultiSelectGoalsStep(
      title: AppLocalizations.of(context).oWhatWouldYouLike4,
      subtitle: "Tailors long-term healthy active longevity priorities.",
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
          style: GoogleFonts.cormorantGaramond(fontSize: 32, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.manrope(fontSize: 13.5, color: BlushyColors.secondaryText),
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
          style: GoogleFonts.cormorantGaramond(fontSize: 32, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.manrope(fontSize: 13.5, color: BlushyColors.secondaryText),
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
          style: GoogleFonts.cormorantGaramond(fontSize: 32, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.manrope(fontSize: 13.5, color: BlushyColors.secondaryText),
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
          style: GoogleFonts.cormorantGaramond(fontSize: 32, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.manrope(fontSize: 13.5, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        ...options.map((opt) {
          final isSelected = _profile.symptoms.contains(opt);
          final isNoneOption = opt.toLowerCase().contains("none") || opt.toLowerCase().contains("no notable");
          return _buildPremiumSelectionRow(
            title: opt,
            isSelected: isSelected,
            isMulti: true,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _profile.symptoms.remove(opt);
                } else {
                  if (isNoneOption) {
                    // Deselect other symptoms when selecting 'None' / 'No notable symptoms'
                    _profile.symptoms.clear();
                    _profile.symptoms.add(opt);
                  } else {
                    // Deselect 'None' when choosing a specific symptom
                    _profile.symptoms.removeWhere(
                      (s) => s.toLowerCase().contains("none") || s.toLowerCase().contains("no notable"),
                    );
                    _profile.symptoms.add(opt);
                  }
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
    String? badge,
    required bool isSelected,
    bool isLocked = false,
    required VoidCallback onTap,
    bool isMulti = false,
  }) {
    return PremiumSelectionRow(
      title: title,
      desc: desc,
      badge: badge,
      isSelected: isSelected,
      isLocked: isLocked,
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
            style: GoogleFonts.manrope(
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
  final String? badge;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;
  final bool isMulti;

  const PremiumSelectionRow({
    super.key,
    required this.title,
    this.desc,
    this.badge,
    required this.isSelected,
    this.isLocked = false,
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
              color: widget.isLocked
                  ? const Color(0xFFF7F4EF)
                  : widget.isSelected 
                      ? BlushyColors.primary.withValues(alpha: 0.04) 
                      : (_isHovered ? Colors.white.withValues(alpha: 0.4) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isLocked
                    ? const Color(0xFFE8DFD5)
                    : widget.isSelected 
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
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: widget.isLocked
                              ? const Color(0xFF8A7C83)
                              : widget.isSelected ? BlushyColors.primary : BlushyColors.text,
                        ),
                      ),
                      if (widget.desc != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.desc!,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: widget.isLocked
                                ? const Color(0xFFA5979E)
                                : BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (widget.isLocked) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFE8E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF7A6B72)),
                        if (widget.badge != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            widget.badge!,
                            style: GoogleFonts.manrope(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7A6B72),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
