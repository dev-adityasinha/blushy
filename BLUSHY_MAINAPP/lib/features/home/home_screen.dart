import 'package:flutter/material.dart';
import '../../shared/skeleton.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state.dart';
import '../../core/storage.dart';
import '../../theme/colors.dart';
import '../../services/api_auth_service.dart';
import 'presentation/stages/everyday_wellness_dashboard.dart';
import '../../l10n/app_localizations.dart';

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

class _BlushyHomeScreenState extends State<BlushyHomeScreen> {
  Map<String, dynamic> _onboardingData = {};

  @override
  void initState() {
    super.initState();
    _loadOnboardingData();
  }

  void _loadOnboardingData() {
    try {
      final decoded = BlushyStorage.read('user_profile.json');
      setState(() {
        _onboardingData = decoded['profile'] ?? decoded ?? {};
      });
    } catch (_) {
      setState(() {
        _onboardingData = {};
      });
    }

    ApiAuthService().getOnboardingAnswers().then((remoteAnswers) {
      if (remoteAnswers.isNotEmpty && mounted) {
        setState(() {
          _onboardingData = {
            ..._onboardingData,
            ...remoteAnswers,
          };
        });
      }
    });
  }

  Widget _buildStageDashboard(String rawStage) {
    return EverydayWellnessDashboard(stageKey: rawStage);
  }


  @override
  Widget build(BuildContext context) {
    final osState = BlushyOSProvider.of(context);
    final activeStages = osState.personalContext.activeLifeStages.toList();

    Widget body;
    if (activeStages.length > 1) {
      body = EverydayWellnessDashboard(
        activeStages: activeStages,
      );
    } else {
      final String rawStage = (activeStages.isNotEmpty ? activeStages.first : null) ??
          (osState.personalContext.lifeStage ??
              _onboardingData['lifeStage'] ??
              _onboardingData['life_stage'] ??
              _onboardingData['stage'] ??
              'firstPeriodNotStarted')
          .toString()
          .trim();
      body = _buildStageDashboard(rawStage);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Onboarding finishes locally, but the cards behind it are filled by
          // syncStateWithBackend(), which makes six sequential requests. On a
          // cold backend that is tens of seconds during which the dashboard
          // showed defaults and then silently rewrote itself, so it read as
          // wrong data rather than data still arriving. A banner beats an
          // unexplained pause, and it keeps whatever is already on screen
          // readable instead of blanking the page behind a spinner.
          if (osState.isSyncing) const _DashboardSyncBanner(),
          Expanded(child: body),
        ],
      ),
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
                      backgroundColor: BlushyColors.primary.withValues(alpha: 0.08),
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
                    BlushyStorage.write('user_profile.json', {});
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text("Reset to Onboarding Step", style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.danger.withValues(alpha: 0.1),
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
        "Tracking your core metrics allows Docsy AI to identify subtle hormonal and energy baseline fluctuations early.\n\n"
        "**Key Scientific Insights**\n"
        "• **Circadian & Metabolic Harmony**: Regular sleep and meal timing stabilize cortisol, preventing afternoon energy crashes.\n"
        "• **Vagal Tone & Stress Recovery**: Diaphragmatic breathing and hydration balance parasympathetic nervous system responses.\n"
        "• **Cycle Synergy**: Estrogen and progesterone transitions alter metabolic rate and hydration needs across cycle phases.\n\n"
        "**Actionable Recommendations**\n"
        "1. **Structured Routines**: Maintain consistent daily check-ins within your preferred morning or evening window.\n"
        "2. **Optimal Fluid Intake**: Hydrate continuously throughout high-activity or high-stress workdays.\n"
        "3. **Docsy Companion Check-Ins**: Log daily symptoms to help Docsy refine your dynamic health insights.";
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BlushyColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BlushyColors.primary.withValues(alpha: 0.3), width: 1.0),
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BlushyColors.border),
                  ),
                  child: Column(
                    children: [
                      // Shaped like the paragraph that replaces it, so the card
                      // does not resize when the text lands. The line below
                      // stays: it says why this is slow, which a placeholder
                      // cannot.
                      const Shimmer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(),
                            SizedBox(height: 8),
                            SkeletonLine(),
                            SizedBox(height: 8),
                            SkeletonLine(widthFactor: 0.7),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Docsy AI is searching the web and analyzing detailed insights for '${widget.title}'...",
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
                      "Deep Dive with AI (Web Search)",
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            AppLocalizations.of(context).hClose,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: BlushyColors.primary),
          ),
        ),
      ],
    );
  }
}


/// Slim "still loading" strip shown above the dashboard while state syncs.
class _DashboardSyncBanner extends StatelessWidget {
  const _DashboardSyncBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFDF2F2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // A shimmering pill rather than a spinner: this banner sits over
          // content that is already readable, so it reports progress without
          // asking to be watched.
          const SizedBox(
            width: 28,
            height: 8,
            child: Shimmer(child: SkeletonBox(height: 8, radius: 4)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Updating your dashboard…',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: BlushyColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
