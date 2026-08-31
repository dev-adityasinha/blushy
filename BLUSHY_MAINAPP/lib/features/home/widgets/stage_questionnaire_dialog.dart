import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../core/storage.dart';
import '../../../theme/colors.dart';
import '../../../l10n/app_localizations.dart';

class StageQuestionnaireDialog extends StatefulWidget {
  final String stageKey;
  final String stageTitle;
  final bool isEditing;
  final VoidCallback? onCompleted;

  const StageQuestionnaireDialog({
    super.key,
    required this.stageKey,
    required this.stageTitle,
    this.isEditing = false,
    this.onCompleted,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String stageKey,
    required String stageTitle,
    bool isEditing = false,
    VoidCallback? onCompleted,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StageQuestionnaireDialog(
        stageKey: stageKey,
        stageTitle: stageTitle,
        isEditing: isEditing,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  State<StageQuestionnaireDialog> createState() => _StageQuestionnaireDialogState();
}

class _StageQuestionnaireDialogState extends State<StageQuestionnaireDialog> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  final Map<String, dynamic> _answers = {};
  final Set<String> _selectedGoals = {};
  final Set<String> _selectedSymptoms = {};
  final Set<String> _selectedConditions = {};
  DateTime? _selectedDate;

  List<Widget Function()> _steps = [];
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      _hasLoaded = true;
      _loadExistingAnswers();
      _initQuestionsForStage();
    }
  }

  bool _fuzzyMatches(String candidateOption, Iterable<String> savedItems) {
    if (savedItems.isEmpty) return false;
    final cleanOption = candidateOption.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();
    final optionTokens = cleanOption.split(RegExp(r'\s+')).where((t) => t.length > 2).toSet();

    for (final raw in savedItems) {
      if (raw.trim().isEmpty) continue;
      final cleanSaved = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();

      // Exact normalized match
      if (cleanOption == cleanSaved) return true;

      // Substring match
      if (cleanOption.contains(cleanSaved) || cleanSaved.contains(cleanOption)) return true;

      // Significant keyword overlap
      final savedTokens = cleanSaved.split(RegExp(r'\s+')).where((t) => t.length > 2).toSet();
      final common = optionTokens.intersection(savedTokens);
      if (common.isNotEmpty) {
        final genericTokens = {'and', 'the', 'for', 'with', 'not', 'yes', 'all', 'any', 'your', 'per'};
        final significantCommon = common.difference(genericTokens);
        if (significantCommon.isNotEmpty) {
          return true;
        }
      }

      // Specialized domain synonyms
      if (_matchesSynonyms(cleanOption, cleanSaved)) return true;
    }
    return false;
  }

  bool _matchesSynonyms(String opt, String saved) {
    // Cramps / Pain
    if ((opt.contains('cramp') || opt.contains('pain')) && (saved.contains('cramp') || saved.contains('pain') || saved.contains('pelvic'))) return true;
    // Hygiene
    if (opt.contains('hygiene') && saved.contains('hygiene')) return true;
    // Sports / School / Active
    if ((opt.contains('sport') || opt.contains('school') || opt.contains('active')) && 
        (saved.contains('sport') || saved.contains('school') || saved.contains('active'))) {
      return true;
    }
    // Tracking
    if (opt.contains('track') && (saved.contains('track') || saved.contains('predict') || saved.contains('period'))) return true;
    // Mood / Emotions / Anxiety / PMS
    if ((opt.contains('mood') || opt.contains('emotion') || opt.contains('pms') || opt.contains('anxiety')) && 
        (saved.contains('mood') || saved.contains('emotion') || saved.contains('pms') || saved.contains('anxiety'))) {
      return true;
    }
    // Sleep / Rest
    if (opt.contains('sleep') && (saved.contains('sleep') || saved.contains('night') || saved.contains('insomnia') || saved.contains('rest'))) return true;
    // Energy / Fatigue
    if ((opt.contains('energy') || opt.contains('fatigue') || opt.contains('stamina')) &&
        (saved.contains('energy') || saved.contains('fatigue') || saved.contains('stamina'))) {
      return true;
    }
    // Acne / Skin
    if ((opt.contains('acne') || opt.contains('skin')) && (saved.contains('acne') || saved.contains('skin'))) return true;
    // Ovulation / Fertility
    if ((opt.contains('ovulation') || opt.contains('fertile') || opt.contains('fertility')) &&
        (saved.contains('ovulation') || saved.contains('fertile') || saved.contains('fertility'))) {
      return true;
    }
    // Nutrition / Diet
    if ((opt.contains('nutrition') || opt.contains('diet') || opt.contains('food')) &&
        (saved.contains('nutrition') || saved.contains('diet') || saved.contains('food'))) {
      return true;
    }
    // Fitness / Movement / Exercise
    if ((opt.contains('fitness') || opt.contains('movement') || opt.contains('exercise') || opt.contains('sync')) &&
        (saved.contains('fitness') || saved.contains('movement') || saved.contains('exercise') || saved.contains('sync'))) {
      return true;
    }
    // PCOS
    if (opt.contains('pcos') && saved.contains('pcos')) return true;
    // Endometriosis
    if (opt.contains('endo') && saved.contains('endo')) return true;
    // Fibroids
    if (opt.contains('fibroid') && saved.contains('fibroid')) return true;
    // Adenomyosis
    if (opt.contains('adeno') && saved.contains('adeno')) return true;
    // Thyroid
    if (opt.contains('thyroid') && saved.contains('thyroid')) return true;
    // PMDD
    if (opt.contains('pmdd') && saved.contains('pmdd')) return true;
    // Undiagnosed / exploring
    if ((opt.contains('diagnos') || opt.contains('explor')) && (saved.contains('diagnos') || saved.contains('explor'))) return true;
    // Hair
    if (opt.contains('hair') && saved.contains('hair')) return true;
    // Weight
    if (opt.contains('weight') && saved.contains('weight')) return true;
    // Hot flashes / vasomotor
    if ((opt.contains('flash') || opt.contains('vasomotor') || opt.contains('temp')) &&
        (saved.contains('flash') || saved.contains('vasomotor') || saved.contains('temp'))) {
      return true;
    }
    // Regularity
    if (opt.contains('very regular') && saved.contains('very regular')) return true;
    if (opt.contains('mostly regular') && saved.contains('mostly regular')) return true;
    if (opt.contains('unpredictable') && saved.contains('unpredictable')) return true;
    if (opt.contains('irregular') && saved.contains('irregular')) return true;
    // Contraception
    if (opt.contains('pill') && saved.contains('pill')) return true;
    if (opt.contains('iud') && saved.contains('iud')) return true;
    if (opt.contains('no contraception') && (saved.contains('no') || saved.contains('none'))) return true;
    // Feeding
    if (opt.contains('breast') && saved.contains('breast')) return true;
    if (opt.contains('formula') && saved.contains('formula')) return true;
    if (opt.contains('pump') && saved.contains('pump')) return true;
    if (opt.contains('combination') && saved.contains('combination')) return true;

    return false;
  }

  String? _findMatchingSingleOption(String? currentVal, List<String> options) {
    if (currentVal == null || currentVal.toString().trim().isEmpty) return null;
    final valStr = currentVal.toString();
    for (final opt in options) {
      if (opt == valStr) return opt;
      if (_fuzzyMatches(opt, [valStr])) return opt;
    }
    return valStr;
  }

  void _loadExistingAnswers() {
    try {
      final decoded = BlushyStorage.read('user_profile.json');
      final Map<String, dynamic> profile = (decoded['profile'] is Map)
          ? Map<String, dynamic>.from(decoded['profile'])
          : Map<String, dynamic>.from(decoded);
      final Map<String, dynamic> savedAnswers = (profile['answers'] is Map)
          ? Map<String, dynamic>.from(profile['answers'])
          : profile;

      // Check stage-specific answers map if present
      final Map<String, dynamic> stageAnswers = (profile['stage_answers'] is Map && profile['stage_answers'][widget.stageKey] is Map)
          ? Map<String, dynamic>.from(profile['stage_answers'][widget.stageKey])
          : (profile[widget.stageKey] is Map ? Map<String, dynamic>.from(profile[widget.stageKey]) : {});

      final bool isOnboardingStage = (profile['onboardingStage'] == widget.stageKey || profile['lifeStage'] == widget.stageKey);
      final bool hasSavedStageData = stageAnswers.isNotEmpty || (isOnboardingStage && savedAnswers.isNotEmpty);

      // If user is choosing this stage for the first time (no saved answers exist for this stage), start completely clean / fresh!
      if (!hasSavedStageData) {
        _answers.clear();
        _selectedGoals.clear();
        _selectedSymptoms.clear();
        _selectedConditions.clear();
        _selectedDate = null;
        return;
      }

      // Load answers specifically for this previously answered stage
      final Map<String, dynamic> mergedAnswers = {};
      if (isOnboardingStage) {
        savedAnswers.forEach((k, v) {
          if (v != null) {
            mergedAnswers[k] = v;
          }
        });
      }
      stageAnswers.forEach((k, v) {
        if (v != null) {
          mergedAnswers[k] = v;
        }
      });

      mergedAnswers.forEach((key, value) {
        if (value != null) {
          _answers[key] = value;
        }
      });

      // Goals for this stage
      final Set<String> candidateGoals = {};
      final rawStageGoals = stageAnswers['goals'] ?? (isOnboardingStage ? profile['goals'] ?? savedAnswers['goals'] : null);
      if (rawStageGoals is List) {
        candidateGoals.addAll(rawStageGoals.map((e) => e.toString()));
      }
      _selectedGoals.addAll(candidateGoals);

      // Symptoms for this stage
      final Set<String> candidateSymptoms = {};
      final rawStageSymptoms = stageAnswers['symptoms'] ?? (isOnboardingStage ? profile['symptoms'] ?? savedAnswers['symptoms'] : null);
      if (rawStageSymptoms is List) {
        candidateSymptoms.addAll(rawStageSymptoms.map((e) => e.toString()));
      }
      _selectedSymptoms.addAll(candidateSymptoms);

      // Conditions for this stage
      final Set<String> candidateConditions = {};
      final rawStageConditions = stageAnswers['conditions'] ?? stageAnswers['medical_conditions'] ?? (isOnboardingStage ? profile['conditions'] ?? profile['medical_conditions'] ?? savedAnswers['conditions'] ?? savedAnswers['medical_conditions'] : null);
      if (rawStageConditions is List) {
        candidateConditions.addAll(rawStageConditions.map((e) => e.toString()));
      }
      _selectedConditions.addAll(candidateConditions);

      // Pre-fill dates for this stage
      final rawPeriod = stageAnswers['last_period'] ?? stageAnswers['last_period_date'] ?? (isOnboardingStage ? profile['last_period'] ?? profile['lastPeriod'] ?? savedAnswers['last_period'] ?? savedAnswers['last_period_date'] : null);
      if (rawPeriod != null) {
        final parsed = BlushyOSState.parseFlexibleDate(rawPeriod);
        if (parsed != null && widget.stageKey == 'reproductiveYears') {
          _selectedDate = parsed;
        }
      }
      try {
        final pc = BlushyOSProvider.of(context).personalContext;
        if (pc.lastPeriodStart != null && widget.stageKey == 'reproductiveYears' && _selectedDate == null) {
          _selectedDate = pc.lastPeriodStart;
        }
      } catch (_) {}

      final rawDue = stageAnswers['due_date'] ?? profile['due_date'] ?? profile['dueDate'] ?? savedAnswers['due_date'];
      if (rawDue != null) {
        final parsed = BlushyOSState.parseFlexibleDate(rawDue);
        if (parsed != null && widget.stageKey == 'pregnancy') {
          _selectedDate = parsed;
        }
      }
      try {
        final pc = BlushyOSProvider.of(context).personalContext;
        if (pc.dueDate != null && widget.stageKey == 'pregnancy' && _selectedDate == null) {
          _selectedDate = pc.dueDate;
        }
      } catch (_) {}

      final rawBirth = stageAnswers['baby_birth_date'] ?? profile['baby_birth_date'] ?? profile['babyBirthDate'] ?? savedAnswers['baby_birth_date'];
      if (rawBirth != null) {
        final parsed = BlushyOSState.parseFlexibleDate(rawBirth);
        if (parsed != null && widget.stageKey == 'postpartum') {
          _selectedDate = parsed;
        }
      }
      try {
        final pc = BlushyOSProvider.of(context).personalContext;
        if (pc.babyBirthDate != null && widget.stageKey == 'postpartum' && _selectedDate == null) {
          _selectedDate = pc.babyBirthDate;
        }
      } catch (_) {}
    } catch (_) {}
  }

  void _initQuestionsForStage() {
    switch (widget.stageKey) {
      case 'firstPeriodNotStarted':
        _steps = [
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqWhatWouldYouLike,
                subtitle: "We'll tailor helpful guidance to prepare you with confidence.",
                storageKey: "not_started_learn",
                options: [
                  "Puberty & body changes",
                  "Preparing for my first period",
                  "Hygiene & period care",
                  "Mood & emotional wellbeing",
                  "School, sports & active life",
                ],
              ),
        ];
        break;

      case 'firstPeriodStarted':
        _steps = [
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqWhenDidYourFirst,
                subtitle: "This sets baseline predictions and cycle health insights.",
                storageKey: "first_period_start_time",
                options: [
                  "Within the last month",
                  "1–6 months ago",
                  "More than 6 months ago",
                ],
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhatWouldYouLike2,
                subtitle: "Select all that apply to personalize your dashboard.",
                selectedSet: _selectedGoals,
                options: [
                  "Tracking periods",
                  "Managing cramps & pain",
                  "Mood changes",
                  "Understanding my body",
                  "Hygiene & products",
                  "School & sports balance",
                ],
              ),
        ];
        break;

      case 'reproductiveYears':
        _steps = [
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqHowWouldYouDescribe,
                subtitle: "Helps predict ovulation and fertile phases accurately.",
                storageKey: "reproductive_cycle_type",
                options: [
                  "Very regular (28-30 days)",
                  "Mostly regular (fluctuates slightly)",
                  "Sometimes irregular",
                  "Highly unpredictable",
                  "I'm not sure yet",
                ],
              ),
          () => _buildDatePickerStep(
                title: AppLocalizations.of(context).sqWhenDidYourLast,
                subtitle: "Used to forecast your cycle phase and upcoming period.",
                storageKey: "last_period",
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhatAreYourPrimary,
                subtitle: "Customize your tracking feed and daily recommendations.",
                selectedSet: _selectedGoals,
                options: [
                  "Predict periods accurately",
                  "Reduce cramps & discomfort",
                  "PMS & mood support",
                  "Sleep & energy optimization",
                  "Skin & acne health",
                  "Ovulation awareness",
                  "Fitness & cycle syncing",
                  "Nutrition guidance",
                ],
              ),
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqAreYouUsingHormonal,
                subtitle: "Contraception influences cycle symptoms and bleeding patterns.",
                storageKey: "contraception_choice",
                options: [
                  "No contraception",
                  "Birth control pill",
                  "Hormonal IUD / Implant",
                  "Non-hormonal IUD (Copper)",
                  "Prefer not to say",
                ],
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhichSymptomsAffectYou,
                subtitle: "Your home page shows the cards for what you track.",
                selectedSet: _selectedSymptoms,
                options: [
                  "Cramps & period pain",
                  "Bloating",
                  "Headaches / migraines",
                  "Mood swings & PMS",
                  "Fatigue",
                  "Hormonal acne",
                  "Heavy bleeding",
                  "Spotting between periods",
                  "Unusual discharge",
                  "Digestion issues",
                  "Anxiety",
                  "Sleep disruption / insomnia",
                  "Back pain",
                ],
              ),
        ];
        break;

      case 'hormonalHealth':
        _steps = [
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhichHormonalConditionS,
                subtitle: "Enables specialized trackers and clinical insights.",
                selectedSet: _selectedConditions,
                options: [
                  "PCOS (Polycystic Ovary Syndrome)",
                  "Endometriosis",
                  "Adenomyosis",
                  "Uterine Fibroids",
                  "Thyroid disorder (Hypo/Hyper)",
                  "PMDD (Premenstrual Dysphoric Disorder)",
                  "Currently exploring / Not diagnosed yet",
                ],
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhichSymptomsAffectYou,
                subtitle: "Dr. Docsy adapts tracking cards to prioritize these.",
                selectedSet: _selectedSymptoms,
                options: [
                  "Pelvic pain / Cramps",
                  "Irregular / Absent periods",
                  "Hormonal acne",
                  "Hair thinning / Loss",
                  "Excess facial or body hair",
                  "Weight fluctuations",
                  "Fatigue & low energy",
                  "Mood swings & anxiety",
                  "Sleep disturbances",
                  "Bloating & digestive issues",
                ],
              ),
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqAreYouCurrentlyReceiving,
                subtitle: "Helps tailor medication and protocol logs.",
                storageKey: "hormonal_treatment",
                options: [
                  "Yes, active medical care / medication",
                  "Lifestyle & dietary management only",
                  "In progress / Evaluating options",
                  "No current treatment",
                ],
              ),
        ];
        break;

      case 'tryingToConceive':
        _steps = [
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqHowLongHaveYou,
                subtitle: "Adapts fertility timelines and proactive guidance.",
                storageKey: "ttc_duration",
                options: [
                  "Just starting (0–3 months)",
                  "3–6 months",
                  "6–12 months",
                  "More than 12 months",
                ],
              ),
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqHowAreYouTracking,
                subtitle: "Select the primary biomarker you track.",
                storageKey: "ttc_tracking_method",
                options: [
                  "Ovulation test strips (LH)",
                  "Basal Body Temperature (BBT)",
                  "Cervical mucus monitoring",
                  "Standard calendar tracking",
                  "Multiple methods combined",
                  "Not tracking actively yet",
                ],
              ),
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqAreYouUndergoingFertility,
                subtitle: "Personalizes protocols and hormone support tracking.",
                storageKey: "ttc_treatment",
                options: [
                  "No medical assistance",
                  "Ovulation induction (e.g. Letrozole / Clomid)",
                  "IUI (Intrauterine Insemination)",
                  "IVF (In Vitro Fertilization)",
                  "Natural supplements & acupuncture",
                ],
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhichSymptomsAffectYou,
                subtitle: "Your home page shows the cards for what you track.",
                selectedSet: _selectedSymptoms,
                options: [
                  "Cramps & pelvic pain",
                  "Bloating",
                  "Spotting between periods",
                  "Cervical mucus changes",
                  "Fatigue",
                  "Mood swings",
                  "Headaches",
                  "Hormonal acne",
                  "Back pain",
                  "Anxiety",
                  "Sleep disruption / insomnia",
                ],
              ),
        ];
        break;

      case 'pregnancy':
        _steps = [
          () => _buildDatePickerStep(
                title: AppLocalizations.of(context).sqWhatIsYourEstimated,
                subtitle: "Calculates weekly gestational age and baby milestones.",
                storageKey: "due_date",
                isFutureDate: true,
              ),
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqIsThisYourFirst,
                subtitle: "Customizes educational pacing and milestone insights.",
                storageKey: "pregnancy_first",
                options: [
                  "Yes, my first pregnancy",
                  "No, I have had prior pregnancies",
                ],
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhatSupportWouldYou,
                subtitle: "Prioritize baby development, nutrition, and wellness.",
                selectedSet: _selectedGoals,
                options: [
                  "Weekly baby growth & milestones",
                  "Trimester symptom management",
                  "Safe prenatal nutrition & supplements",
                  "Pelvic floor & safe movement",
                  "Sleep & comfort support",
                  "Mental wellbeing & birth prep",
                  "Doctor visit reminders & questions",
                ],
              ),
        ];
        break;

      case 'postpartum':
        _steps = [
          () => _buildDatePickerStep(
                title: AppLocalizations.of(context).sqWhenWasYourBaby,
                subtitle: "Drives maternal healing recovery and infant milestones.",
                storageKey: "baby_birth_date",
              ),
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqHowAreYouFeeding,
                subtitle: "Adapts hydration targets and feeding logs.",
                storageKey: "postpartum_feeding",
                options: [
                  "Exclusive Breastfeeding / Chestfeeding",
                  "Pumping / Expressed milk",
                  "Formula feeding",
                  "Combination feeding (Formula + Breast)",
                ],
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhatAreasWouldYou,
                subtitle: "Customize maternal postpartum recovery support.",
                selectedSet: _selectedGoals,
                options: [
                  "Physical recovery & pelvic health",
                  "Feeding guidance & latch support",
                  "Sleep hygiene & night recovery",
                  "Postpartum mental health & mood",
                  "Gentle postpartum movement",
                  "Healing nutrition & lactation snacks",
                ],
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhichSymptomsAffectYou,
                subtitle: "Recovery included. Your home page shows what you track.",
                selectedSet: _selectedSymptoms,
                options: [
                  "Bleeding / lochia",
                  "Perineal soreness or stitches",
                  "C-section incision healing",
                  "Pelvic floor weakness",
                  "Swelling",
                  "Back pain",
                  "Fatigue & exhaustion",
                  "Night sweats",
                  "Mood swings / low mood",
                  "Anxiety",
                  "Sleep disruption / insomnia",
                ],
              ),
        ];
        break;

      case 'perimenopause':
        _steps = [
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqHowHaveYourPeriods,
                subtitle: "Tracks fluctuations in menstrual rhythms.",
                storageKey: "perimenopause_cycle_change",
                options: [
                  "Still regular with slight timing shifts",
                  "Becoming noticeably irregular or skipped",
                  "Rare / Months apart",
                  "Heavier or lighter flow variations",
                  "Stopped recently",
                ],
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhichSymptomsAffectYou,
                subtitle: "Dr. Docsy adapts tracking cards to prioritize these.",
                selectedSet: _selectedSymptoms,
                options: [
                  "Hot flashes & temperature shifts",
                  "Night sweats & sleep disruption",
                  "Brain fog & focus changes",
                  "Mood fluctuations & anxiety",
                  "Joint or muscle aches",
                  "Fatigue & low stamina",
                  "Weight & metabolism changes",
                  "Vaginal dryness / Discomfort",
                ],
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhatWouldYouMost,
                subtitle: "Saves priorities for proactive daily insights.",
                selectedSet: _selectedGoals,
                options: [
                  "Sleep quality & night routine",
                  "Hormonal balance & cooling",
                  "Energy & metabolism",
                  "Bone & muscle strength",
                  "Cardiovascular wellness",
                  "Nutrition & supplement guide",
                ],
              ),
        ];
        break;

      case 'menopause':
        _steps = [
          () => _buildSingleSelectStep(
                title: AppLocalizations.of(context).sqHowLongHasIt,
                subtitle: "Determines postmenopausal health focus areas.",
                storageKey: "menopause_duration",
                options: [
                  "Under 12 months",
                  "1 to 3 years",
                  "3 to 5 years",
                  "More than 5 years",
                  "I'm not sure",
                ],
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhichSymptomsAffectYour,
                subtitle: "Select all that apply to personalize your care.",
                selectedSet: _selectedSymptoms,
                options: [
                  "Hot flashes & vasomotor symptoms",
                  "Sleep disturbances / Insomnia",
                  "Mood swings & emotional shifts",
                  "Vaginal dryness & intimacy health",
                  "Bone density & joint comfort",
                  "Skin & hair vitality",
                  "Metabolism & cardiovascular health",
                ],
              ),
          () => _buildMultiSelectStep(
                title: AppLocalizations.of(context).sqWhatAreYourTop,
                subtitle: "Tailor your healthy ageing companion feed.",
                selectedSet: _selectedGoals,
                options: [
                  "Bone density & osteoporosis prevention",
                  "Heart & vascular wellness",
                  "Restful deep sleep",
                  "Mood vitality & stress relief",
                  "Energy & daily vitality",
                  "Bone-friendly nutrition & calcium",
                ],
              ),
        ];
        break;

      default:
        _steps = [
          () => _buildSingleSelectStep(
                title: "What is your main focus for ${widget.stageTitle}?",
                subtitle: "Personalizes daily companion cards.",
                storageKey: "wellness_focus",
                options: [
                  "General vitality & energy",
                  "Cycle awareness",
                  "Mood & stress balance",
                  "Healthy habits & nutrition",
                ],
              ),
        ];
    }
  }

  bool _canProceed() {
    if (_steps.isEmpty) return true;
    final stage = widget.stageKey;

    if (stage == 'firstPeriodNotStarted') {
      return _answers['not_started_learn'] != null;
    }
    if (stage == 'firstPeriodStarted') {
      if (_currentStep == 0) return _answers['first_period_start_time'] != null;
      if (_currentStep == 1) return _selectedGoals.isNotEmpty;
    }
    if (stage == 'reproductiveYears') {
      if (_currentStep == 0) return _answers['reproductive_cycle_type'] != null;
      if (_currentStep == 1) return _selectedDate != null || _answers['last_period_unknown'] == true;
      if (_currentStep == 2) return _selectedGoals.isNotEmpty;
      if (_currentStep == 3) return _answers['contraception_choice'] != null;
      if (_currentStep == 4) return _selectedSymptoms.isNotEmpty;
    }
    if (stage == 'hormonalHealth') {
      if (_currentStep == 0) return _selectedConditions.isNotEmpty;
      if (_currentStep == 1) return _selectedSymptoms.isNotEmpty;
      if (_currentStep == 2) return _answers['hormonal_treatment'] != null;
    }
    if (stage == 'tryingToConceive') {
      if (_currentStep == 0) return _answers['ttc_duration'] != null;
      if (_currentStep == 1) return _answers['ttc_tracking_method'] != null;
      if (_currentStep == 2) return _answers['ttc_treatment'] != null;
      if (_currentStep == 3) return _selectedSymptoms.isNotEmpty;
    }
    if (stage == 'pregnancy') {
      if (_currentStep == 0) return _selectedDate != null;
      if (_currentStep == 1) return _answers['pregnancy_first'] != null;
      if (_currentStep == 2) return _selectedGoals.isNotEmpty;
    }
    if (stage == 'postpartum') {
      if (_currentStep == 0) return _selectedDate != null;
      if (_currentStep == 1) return _answers['postpartum_feeding'] != null;
      if (_currentStep == 2) return _selectedGoals.isNotEmpty;
      if (_currentStep == 3) return _selectedSymptoms.isNotEmpty;
    }
    if (stage == 'perimenopause') {
      if (_currentStep == 0) return _answers['perimenopause_cycle_change'] != null;
      if (_currentStep == 1) return _selectedSymptoms.isNotEmpty;
      if (_currentStep == 2) return _selectedGoals.isNotEmpty;
    }
    if (stage == 'menopause') {
      if (_currentStep == 0) return _answers['menopause_duration'] != null;
      if (_currentStep == 1) return _selectedSymptoms.isNotEmpty;
      if (_currentStep == 2) return _selectedGoals.isNotEmpty;
    }

    return true;
  }

  Future<void> _handleNextOrSubmit() async {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      await _submitAllAnswers();
    }
  }

  Future<void> _submitAllAnswers() async {
    setState(() {
      _isSubmitting = true;
    });

    final Map<String, dynamic> finalAnswers = Map.from(_answers);

    if (_selectedGoals.isNotEmpty) {
      finalAnswers['goals'] = _selectedGoals.toList();
    }
    if (_selectedSymptoms.isNotEmpty) {
      finalAnswers['symptoms'] = _selectedSymptoms.toList();
    }
    if (_selectedConditions.isNotEmpty) {
      finalAnswers['conditions'] = _selectedConditions.toList();
      finalAnswers['medical_conditions'] = _selectedConditions.toList();
    }
    if (_selectedDate != null) {
      if (widget.stageKey == 'reproductiveYears') {
        finalAnswers['last_period'] = _selectedDate!.toIso8601String().split('T').first;
        finalAnswers['last_period_date'] = _selectedDate!.toIso8601String().split('T').first;
      } else if (widget.stageKey == 'pregnancy') {
        finalAnswers['due_date'] = _selectedDate!.toIso8601String().split('T').first;
      } else if (widget.stageKey == 'postpartum') {
        finalAnswers['baby_birth_date'] = _selectedDate!.toIso8601String().split('T').first;
      }
    }

    try {
      final currentData = BlushyStorage.read('user_profile.json');
      final profile = (currentData['profile'] is Map)
          ? Map<String, dynamic>.from(currentData['profile'])
          : Map<String, dynamic>.from(currentData);

      final Map<String, dynamic> stageAnswersMap = (profile['stage_answers'] is Map)
          ? Map<String, dynamic>.from(profile['stage_answers'])
          : {};
      stageAnswersMap[widget.stageKey] = Map<String, dynamic>.from(finalAnswers);
      profile['stage_answers'] = stageAnswersMap;
      profile[widget.stageKey] = Map<String, dynamic>.from(finalAnswers);
      profile['lifeStage'] = widget.stageKey;
      profile['onboardingStage'] = widget.stageKey;
      profile.addAll(finalAnswers);

      currentData['profile'] = profile;
      BlushyStorage.write('user_profile.json', currentData);

      final state = BlushyOSProvider.of(context);
      state.addLifeStageWithAnswers(widget.stageKey, finalAnswers);

      if (mounted) {
        widget.onCompleted?.call();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing
                ? "${widget.stageTitle} answers have been updated!"
                : "${widget.stageTitle} added to your dashboard!"),
            backgroundColor: BlushyColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save answers: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canProceed = _canProceed();
    final bool isLastStep = _currentStep == _steps.length - 1;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
        maxWidth: 650,
      ),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF6F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: BlushyColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BlushyColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.isEditing ? "EDIT TOPIC ANSWERS" : "ADD TOPIC",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.stageTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: BlushyColors.secondaryText, size: 22),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),

          // Progress Indicator
          if (_steps.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                children: List.generate(_steps.length, (idx) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: idx < _steps.length - 1 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: idx <= _currentStep ? BlushyColors.primary : BlushyColors.border.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),

          const Divider(height: 16, thickness: 0.8, color: BlushyColors.border),

          // Question Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: _steps.isNotEmpty ? _steps[_currentStep]() : const SizedBox.shrink(),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0) ...[
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _currentStep--;
                            });
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      side: const BorderSide(color: BlushyColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      "Back",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: (canProceed && !_isSubmitting) ? _handleNextOrSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      disabledBackgroundColor: BlushyColors.primary.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isLastStep
                                ? (widget.isEditing ? "Save & Update Dashboard" : "Complete & Add to Dashboard")
                                : "Continue",
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable Question Step Builders ---

  Widget _buildSingleSelectStep({
    required String title,
    required String subtitle,
    required String storageKey,
    required List<String> options,
  }) {
    final rawVal = _answers[storageKey]?.toString();
    final currentSelected = _findMatchingSingleOption(rawVal, options);
    if (currentSelected != null && _answers[storageKey] != currentSelected) {
      _answers[storageKey] = currentSelected;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 20),
        ...options.map((opt) {
          final isSelected = currentSelected == opt || _answers[storageKey] == opt;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _answers[storageKey] = opt;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? BlushyColors.primary.withValues(alpha: 0.08) : Colors.white,
                  border: Border.all(
                    color: isSelected ? BlushyColors.primary : BlushyColors.border,
                    width: isSelected ? 1.8 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? BlushyColors.primary : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? BlushyColors.primary : BlushyColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        opt,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: BlushyColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMultiSelectStep({
    required String title,
    required String subtitle,
    required Set<String> selectedSet,
    required List<String> options,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 20),
        ...options.map((opt) {
          final isSelected = selectedSet.contains(opt);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedSet.remove(opt);
                  } else {
                    selectedSet.add(opt);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? BlushyColors.primary.withValues(alpha: 0.08) : Colors.white,
                  border: Border.all(
                    color: isSelected ? BlushyColors.primary : BlushyColors.border,
                    width: isSelected ? 1.8 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: isSelected ? BlushyColors.primary : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? BlushyColors.primary : BlushyColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 15, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        opt,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: BlushyColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDatePickerStep({
    required String title,
    required String subtitle,
    required String storageKey,
    bool isFutureDate = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: BlushyColors.text),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 24),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? (isFutureDate ? now.add(const Duration(days: 120)) : now),
              firstDate: isFutureDate ? now.subtract(const Duration(days: 30)) : now.subtract(const Duration(days: 365)),
              lastDate: isFutureDate ? now.add(const Duration(days: 280)) : now,
              builder: (ctx, child) {
                return Theme(
                  data: Theme.of(ctx).copyWith(
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
                _selectedDate = picked;
                _answers[storageKey] = picked.toIso8601String().split('T').first;
                _answers['${storageKey}_unknown'] = false;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDate != null ? BlushyColors.primary : BlushyColors.border,
                width: _selectedDate != null ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 20, color: BlushyColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate == null
                          ? "Tap to select date"
                          : "${_selectedDate!.day} / ${_selectedDate!.month} / ${_selectedDate!.year}",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _selectedDate == null ? BlushyColors.secondaryText : BlushyColors.text,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BlushyColors.secondaryText),
              ],
            ),
          ),
        ),
        if (!isFutureDate) ...[
          const SizedBox(height: 16),
          CheckboxListTile(
            title: Text(
              "I don't remember the exact date",
              style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText),
            ),
            value: _answers['${storageKey}_unknown'] == true,
            activeColor: BlushyColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setState(() {
                _answers['${storageKey}_unknown'] = val;
                if (val == true) {
                  _selectedDate = null;
                }
              });
            },
          ),
        ],
      ],
    );
  }
}
