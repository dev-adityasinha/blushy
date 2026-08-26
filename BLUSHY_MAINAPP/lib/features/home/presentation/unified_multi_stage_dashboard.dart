import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../core/storage.dart';
import '../../../core/cycle_calculator.dart';
import '../../../theme/colors.dart';
import '../widgets/life_stage_selector_card.dart';
import '../../../services/api_auth_service.dart';

class UnifiedMultiStageDashboard extends StatefulWidget {
  final Set<String> activeStages;

  const UnifiedMultiStageDashboard({
    super.key,
    required this.activeStages,
  });

  @override
  State<UnifiedMultiStageDashboard> createState() => _UnifiedMultiStageDashboardState();
}

class _UnifiedMultiStageDashboardState extends State<UnifiedMultiStageDashboard> {
  Map<String, dynamic> _liveUserData = {};
  bool _isLoadingLive = true;

  // Interactive local states for daily check-in
  String _selectedLogMood = 'Calm';
  String _selectedEnergy = 'Balanced';
  int _sleepHours = 8;
  final Set<String> _loggedSymptoms = {};
  bool _symptomLoggedToday = false;

  @override
  void initState() {
    super.initState();
    _loadLiveProfileData();
  }

  @override
  void didUpdateWidget(covariant UnifiedMultiStageDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeStages != widget.activeStages) {
      _loadLiveProfileData();
    }
  }

  Future<void> _loadLiveProfileData() async {
    // 1. Load local cache first
    try {
      final decoded = BlushyStorage.read('user_profile.json');
      if (mounted) {
        setState(() {
          _liveUserData = (decoded['profile'] is Map)
              ? Map<String, dynamic>.from(decoded['profile'])
              : Map<String, dynamic>.from(decoded);
        });
      }
    } catch (_) {}

    // 2. Fetch live data from MongoDB
    try {
      final remoteAnswers = await ApiAuthService().getOnboardingAnswers();
      if (remoteAnswers.isNotEmpty && mounted) {
        setState(() {
          _liveUserData = {
            ..._liveUserData,
            ...remoteAnswers,
          };
          _isLoadingLive = false;
        });

        // Sync live answers into state if period start or goals are present
        final osState = BlushyOSProvider.of(context);
        final rawPeriod = remoteAnswers['last_period'] ?? remoteAnswers['last_period_date'] ?? remoteAnswers['period_last_start_date'];
        if (rawPeriod != null) {
          final parsed = BlushyOSState.parseFlexibleDate(rawPeriod);
          if (parsed != null && osState.personalContext.lastPeriodStart != parsed) {
            osState.updatePersonalContext(PersonalContext(
              userName: osState.personalContext.userName,
              dateOfBirth: osState.personalContext.dateOfBirth,
              weight: osState.personalContext.weight,
              lifeStage: osState.personalContext.lifeStage,
              activeLifeStages: osState.personalContext.activeLifeStages,
              dueDate: osState.personalContext.dueDate,
              babyBirthDate: osState.personalContext.babyBirthDate,
              trackingPreference: osState.personalContext.trackingPreference,
              cyclePattern: osState.personalContext.cyclePattern,
              confidence: osState.personalContext.confidence,
              lifeContexts: osState.personalContext.lifeContexts,
              userGoals: osState.personalContext.userGoals,
              userSymptoms: osState.personalContext.userSymptoms,
              medicalConditions: osState.personalContext.medicalConditions,
              preferences: osState.personalContext.preferences,
              cycleLength: osState.personalContext.cycleLength,
              cycleDay: osState.personalContext.cycleDay,
              cyclePhase: osState.personalContext.cyclePhase,
              lastPeriodStart: parsed,
              medications: osState.personalContext.medications,
            ));
          }
        }
      } else if (mounted) {
        setState(() {
          _isLoadingLive = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingLive = false;
        });
      }
    }
  }

  String _getStageTitle(String key) {
    switch (key) {
      case 'firstPeriodNotStarted':
        return 'First Period (Not Started)';
      case 'firstPeriodStarted':
        return 'First Period (Started)';
      case 'reproductiveYears':
        return 'Living With My Cycle';
      case 'hormonalHealth':
        return 'Hormonal Health';
      case 'tryingToConceive':
        return 'Trying to Conceive';
      case 'pregnancy':
        return 'Pregnancy';
      case 'postpartum':
        return 'Postpartum';
      case 'perimenopause':
        return 'Perimenopause';
      case 'menopause':
        return 'Menopause';
      default:
        return 'Everyday Wellness';
    }
  }

  IconData _getStageIcon(String key) {
    switch (key) {
      case 'firstPeriodNotStarted':
        return Icons.spa_outlined;
      case 'firstPeriodStarted':
        return Icons.water_drop_outlined;
      case 'reproductiveYears':
        return Icons.favorite_border_rounded;
      case 'hormonalHealth':
        return Icons.healing_outlined;
      case 'tryingToConceive':
        return Icons.egg_outlined;
      case 'pregnancy':
        return Icons.child_care_rounded;
      case 'postpartum':
        return Icons.family_restroom_rounded;
      case 'perimenopause':
        return Icons.nightlight_round;
      case 'menopause':
        return Icons.wb_sunny_outlined;
      default:
        return Icons.eco_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final osState = BlushyOSProvider.of(context);
    final pc = osState.personalContext;
    final String displayName = (pc.userName != null && pc.userName!.isNotEmpty) ? pc.userName! : "there";

    // Live period date & cycle computation
    DateTime? pStart = pc.lastPeriodStart;
    if (pStart == null) {
      final rawP = _liveUserData['last_period'] ?? _liveUserData['last_period_date'] ?? _liveUserData['period_last_start_date'];
      if (rawP != null) {
        pStart = BlushyOSState.parseFlexibleDate(rawP);
      }
    }

    final int cycleLength = pc.cycleLength ?? 28;
    final cycleCalc = pStart != null
        ? CycleCalculation.compute(lastPeriodStart: pStart, cycleLength: cycleLength)
        : null;

    final int currentDay = cycleCalc?.currentCycleDay ?? pc.cycleDay ?? 1;
    final String currentPhase = cycleCalc?.currentPhase ?? pc.cyclePhase ?? 'Active Cycle';
    final double cycleProgress = ((currentDay - 1) / cycleLength).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: RefreshIndicator(
              color: BlushyColors.primary,
              onRefresh: _loadLiveProfileData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
                  // 1. Unified Hero Greeting
                  _buildCombinedHero(displayName),
                  const SizedBox(height: 16),

                  // 2. Active Focus Topics Pills
                  _buildActiveTopicChips(),
                  const SizedBox(height: 20),

                  // 3. Live Unified Cycle & Health Monitor Card
                  _buildLiveCycleMonitorCard(
                    pc: pc,
                    currentDay: currentDay,
                    cycleLength: cycleLength,
                    currentPhase: currentPhase,
                    cycleProgress: cycleProgress,
                    hasPeriodStart: pStart != null,
                  ),
                  const SizedBox(height: 20),

                  // 4. Combined Sia AI Intelligence Briefing
                  _buildSiaCombinedInsightCard(pc),
                  const SizedBox(height: 20),

                  // 5. Unified Daily Check-in & Live Symptoms Logger
                  _buildDailyWellbeingLogger(osState),
                  const SizedBox(height: 20),

                  // 6. Synthesized Topic Action Hub
                  _buildSynthesizedTopicGuides(pc),
                  const SizedBox(height: 20),

                  // 7. Life Stages Management
                  LifeStageSelectorCard(
                    showHeader: false,
                    onStageUpdated: () {
                      _loadLiveProfileData();
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCombinedHero(String displayName) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: BlushyColors.primary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
                "Good day, $displayName ✨",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BlushyColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hub_rounded, size: 14, color: BlushyColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      "UNIFIED FEED",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: BlushyColors.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Synthesizing live data across your ${widget.activeStages.length} active focus topics.",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: BlushyColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTopicChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.activeStages.map((stageKey) {
        final title = _getStageTitle(stageKey);
        final icon = _getStageIcon(stageKey);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BlushyColors.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: BlushyColors.primary.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: BlushyColors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.text,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, size: 14, color: Color(0xFF4CAF50)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLiveCycleMonitorCard({
    required PersonalContext pc,
    required int currentDay,
    required int cycleLength,
    required String currentPhase,
    required double cycleProgress,
    required bool hasPeriodStart,
  }) {
    final bool isFertile = currentDay >= (cycleLength / 2 - 4) && currentDay <= (cycleLength / 2 + 1);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BlushyColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: BlushyColors.primary.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
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
                  const Icon(Icons.favorite_border_rounded, size: 18, color: BlushyColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Unified Cycle & Body Monitor",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.text,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BlushyColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isLoadingLive ? "SYNCING..." : "LIVE MONGODB SYNC",
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: BlushyColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPeriodStart ? "Day $currentDay of $cycleLength" : "Cycle Tracking",
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: BlushyColors.text),
                  ),
                  Text(
                    currentPhase,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.primary),
                  ),
                ],
              ),
              if (isFertile)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: Text(
                    "Fertile Window Open",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE65100)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: cycleProgress,
              minHeight: 8,
              backgroundColor: BlushyColors.border.withValues(alpha: 0.5),
              color: BlushyColors.primary,
            ),
          ),
          if (widget.activeStages.contains('pregnancy') && pc.dueDate != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: BlushyColors.border),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.child_care_rounded, size: 18, color: BlushyColors.primary),
                const SizedBox(width: 8),
                Text(
                  "Gestational Week ${((280 - pc.dueDate!.difference(DateTime.now()).inDays) / 7).clamp(1, 40).toInt()} • Maternity Track Active",
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.text),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSiaCombinedInsightCard(PersonalContext pc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BlushyColors.primary.withValues(alpha: 0.08),
            const Color(0xFFFAF0E6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: BlushyColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                "Sia's Cross-Topic Synthesis",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _generateCombinedInsightText(),
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              color: BlushyColors.text,
            ),
          ),
        ],
      ),
    );
  }

  String _generateCombinedInsightText() {
    final stages = widget.activeStages;
    if (stages.contains('firstPeriodStarted') && stages.contains('hormonalHealth')) {
      return "Adolescent Hormone Care: Combining early cycle tracking with hormonal balance support helps identify teenage cycle patterns, manage heavy flow, and relieve hormonal skin breakouts.";
    }
    if (stages.contains('reproductiveYears') && stages.contains('hormonalHealth')) {
      return "Cycle & Endocrine Balance: During this cycle phase, supporting insulin sensitivity and reducing inflammation with magnesium and restorative movement helps optimize energy.";
    }
    if (stages.contains('tryingToConceive') && stages.contains('hormonalHealth')) {
      return "Fertility & Hormone Sync: Tracking ovulation biomarkers alongside hormonal health markers gives Sia high precision for identifying your optimal conception window.";
    }
    if (stages.contains('perimenopause') && stages.contains('hormonalHealth')) {
      return "Transition & Endocrine Care: Cross-referencing cycle rhythm shifts with hormonal symptom logs helps manage hot flashes, mood transitions, and sleep vitality.";
    }
    if (stages.contains('menopause') && stages.contains('hormonalHealth')) {
      return "Healthy Longevity & Hormone Balance: Supporting bone vitality, heart health, and restorative rest while tracking daily endocrine wellness.";
    }
    if (stages.contains('postpartum') && stages.contains('hormonalHealth')) {
      return "Postpartum Endocrine Healing: Monitoring maternal recovery, lactation hormones, and mood balance with gentle, restorative daily care.";
    }
    if (stages.contains('postpartum') && stages.contains('reproductiveYears')) {
      return "Postpartum Cycle Return: Logging early postpartum cycle patterns alongside newborn care and restorative maternal recovery.";
    }
    return "All active modules are synchronized with your personal MongoDB health logs. Your daily metrics dynamically power Sia's guidance.";
  }

  Widget _buildDailyWellbeingLogger(BlushyOSState state) {
    final symptomsList = [
      'Cramps',
      'Bloating',
      'Acne',
      'Headache',
      'Fatigue',
      'Mood Swing',
      'Backache',
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BlushyColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Daily Unified Check-in",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: BlushyColors.text),
              ),
              if (_symptomLoggedToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "LOGGED TODAY",
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF2E7D32)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Mood & Energy State:",
            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: "Today's Mood",
                  value: _selectedLogMood,
                  onTap: () {
                    final moods = ['Calm', 'Joyful', 'Reflective', 'Tired', 'Sensitive'];
                    final curIdx = moods.indexOf(_selectedLogMood);
                    setState(() {
                      _selectedLogMood = moods[(curIdx + 1) % moods.length];
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: "Energy Level",
                  value: _selectedEnergy,
                  onTap: () {
                    final energies = ['Balanced', 'High Energy', 'Steady', 'Low / Rest Needed'];
                    final curIdx = energies.indexOf(_selectedEnergy);
                    setState(() {
                      _selectedEnergy = energies[(curIdx + 1) % energies.length];
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Log symptoms across all active topics:",
            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: symptomsList.map((symptom) {
              final isSelected = _loggedSymptoms.contains(symptom);
              return FilterChip(
                label: Text(symptom),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : BlushyColors.text,
                ),
                selected: isSelected,
                selectedColor: BlushyColors.primary,
                backgroundColor: const Color(0xFFFAF6F0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? BlushyColors.primary : BlushyColors.border.withValues(alpha: 0.6),
                  ),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _loggedSymptoms.add(symptom);
                    } else {
                      _loggedSymptoms.remove(symptom);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final int moodScore = _selectedLogMood == 'Joyful' ? 9 : (_selectedLogMood == 'Calm' ? 8 : 6);
                final int energyScore = _selectedEnergy == 'High Energy' ? 9 : (_selectedEnergy == 'Balanced' ? 7 : 4);

                state.updateWellbeingState(
                  CurrentWellbeingState(
                    mood: moodScore,
                    energy: energyScore,
                    sleepQuality: _sleepHours,
                    symptoms: _loggedSymptoms.toList(),
                  ),
                );

                // Save live to MongoDB
                ApiAuthService().saveOnboardingAnswers({
                  'daily_mood': _selectedLogMood,
                  'daily_energy': _selectedEnergy,
                  'daily_symptoms': _loggedSymptoms.toList(),
                  'daily_logged_at': DateTime.now().toIso8601String(),
                }).catchError((_) => <String, dynamic>{});

                setState(() {
                  _symptomLoggedToday = true;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Check-in saved and synced to your live MongoDB profile! ✨",
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: BlushyColors.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                "Save Today's Check-in",
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSynthesizedTopicGuides(PersonalContext pc) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BlushyColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 18, color: BlushyColors.primary),
              const SizedBox(width: 8),
              Text(
                "Integrated Guidance & Protocols",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: BlushyColors.text),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...widget.activeStages.map((stageKey) {
            final title = _getStageTitle(stageKey);
            final icon = _getStageIcon(stageKey);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF6F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
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
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: BlushyColors.text),
                          ),
                          Text(
                            _getStageShortSummary(stageKey),
                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BlushyColors.secondaryText),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getStageShortSummary(String key) {
    switch (key) {
      case 'firstPeriodNotStarted':
        return 'Puberty body changes & first period preparation guides.';
      case 'firstPeriodStarted':
        return 'Early cycle confidence, hygiene routines & cramps care.';
      case 'reproductiveYears':
        return 'Living with your cycle, phase predictions & daily energy syncing.';
      case 'hormonalHealth':
        return 'PCOS, PMDD & condition support with personalized protocols.';
      case 'tryingToConceive':
        return 'Fertility window tracking, BBT & LH surge markers.';
      case 'pregnancy':
        return 'Gestational growth milestones, trimester care & nutrition.';
      case 'postpartum':
        return 'Maternal recovery, pelvic healing & newborn feeding support.';
      case 'perimenopause':
        return 'Cycle rhythm changes, cooling routines & sleep support.';
      case 'menopause':
        return 'Healthy longevity, bone vitality & cardiovascular wellness.';
      default:
        return 'Daily wellness tracking and AI companion guidance.';
    }
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF6F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BlushyColors.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: BlushyColors.text),
            ),
          ],
        ),
      ),
    );
  }
}
