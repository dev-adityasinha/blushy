import 'package:flutter/material.dart';
import '../../shared/skeleton.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state.dart';
import '../../core/storage.dart';
import '../../theme/colors.dart';
import '../../services/api_auth_service.dart';
import '../../core/stage_conflict_engine.dart';
import 'presentation/stages/first_period_not_started_dashboard.dart';
import 'presentation/stages/first_period_started_dashboard.dart';
import 'presentation/stages/living_with_my_cycle_dashboard.dart';
import 'presentation/stages/hormonal_health_dashboard.dart';
import 'presentation/stages/trying_to_conceive_dashboard.dart';
import 'presentation/stages/pregnancy_dashboard.dart';
import 'presentation/stages/postpartum_dashboard.dart';
import 'presentation/stages/perimenopause_dashboard.dart';
import 'presentation/stages/menopause_dashboard.dart';
import '../../l10n/app_localizations.dart';
import '../sia/open_docsy.dart';
import '../../shared/docsy_star.dart';

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
          _onboardingData = {..._onboardingData, ...remoteAnswers};
        });
      }
    });
  }

  Widget _buildStageDashboard(String rawStage, {List<String>? activeStages}) {
    final normalized = rawStage.trim().toLowerCase();

    if (normalized == 'firstperiodnotstarted' ||
        normalized == 'puberty' ||
        normalized == 'notstarted' ||
        normalized == 'not_started') {
      return const FirstPeriodNotStartedDashboard(
        key: ValueKey('stage_firstPeriodNotStarted'),
      );
    }

    if (normalized == 'firstperiodstarted' ||
        normalized == 'started' ||
        normalized == 'cyclejuststarted' ||
        normalized == 'first_period_started') {
      return const FirstPeriodStartedDashboard(
        key: ValueKey('stage_firstPeriodStarted'),
      );
    }

    if (normalized == 'livingwithmycycle' ||
        normalized == 'living_with_my_cycle' ||
        normalized == 'cycleregular' ||
        normalized == 'regularcycle' ||
        normalized == 'regular_cycle' ||
        normalized == 'everydaywellness' ||
        normalized == 'everyday_wellness' ||
        normalized == 'wellness' ||
        normalized == 'reproductiveyears' ||
        normalized == 'reproductive_years' ||
        normalized == 'generalwellness' ||
        normalized == 'general_wellness' ||
        normalized.isEmpty) {
      return const LivingWithMyCycleDashboard(
        key: ValueKey('stage_livingWithMyCycle'),
      );
    }

    if (normalized == 'hormonalhealth' ||
        normalized == 'hormonal_health' ||
        normalized == 'understandingmybody' ||
        normalized == 'understanding_my_body' ||
        normalized == 'pcos' ||
        normalized == 'pcod' ||
        normalized == 'endo' ||
        normalized == 'endometriosis' ||
        normalized == 'pmdd' ||
        normalized == 'thyroid' ||
        normalized == 'irregular' ||
        normalized == 'irregularcycle' ||
        normalized == 'irregular_cycle') {
      return const HormonalHealthDashboard(
        key: ValueKey('stage_hormonalHealth'),
      );
    }

    if (normalized == 'tryingtoconceive' ||
        normalized == 'trying_to_conceive' ||
        normalized == 'ttc' ||
        normalized == 'conception') {
      return const TryingToConceiveDashboard(
        key: ValueKey('stage_tryingToConceive'),
      );
    }

    if (normalized == 'pregnancy' ||
        normalized == 'pregnant') {
      return const PregnancyDashboard(
        key: ValueKey('stage_pregnancy'),
      );
    }

    if (normalized == 'postpartum' ||
        normalized == 'newmom' ||
        normalized == 'afterbirth' ||
        normalized == 'post_partum') {
      return const PostpartumDashboard(
        key: ValueKey('stage_postpartum'),
      );
    }

    if (normalized == 'perimenopause' ||
        normalized == 'peri' ||
        normalized == 'peri_menopause') {
      return const PerimenopauseDashboard(
        key: ValueKey('stage_perimenopause'),
      );
    }

    if (normalized == 'menopause' ||
        normalized == 'postmenopause' ||
        normalized == 'post_menopause') {
      return const MenopauseDashboard(
        key: ValueKey('stage_menopause'),
      );
    }

    if (activeStages != null && activeStages.length > 1) {
      final dominant = StageConflictEngine.dominantStage(activeStages);
      if (dominant != null && dominant.trim().toLowerCase() != normalized) {
        return _buildStageDashboard(dominant);
      }
    }

    return const LivingWithMyCycleDashboard(
      key: ValueKey('stage_livingWithMyCycle_fallback'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final osState = BlushyOSProvider.of(context);
    final activeStages = osState.personalContext.activeLifeStages.toList();

    final String activeStage = (osState.personalContext.lifeStage != null && osState.personalContext.lifeStage!.isNotEmpty)
        ? osState.personalContext.lifeStage!
        : (activeStages.isNotEmpty
            ? activeStages.first
            : (_onboardingData['lifeStage'] ??
                    _onboardingData['life_stage'] ??
                    _onboardingData['stage'] ??
                    'firstPeriodNotStarted')
                .toString()
                .trim());

    final Widget body = _buildStageDashboard(
      activeStage,
      activeStages: (activeStages.length > 1 && osState.personalContext.lifeStage == null)
          ? activeStages
          : null,
    );

    // The Period Started stage opted out of the "Updating your dashboard…"
    // sync banner: its home stays quiet while data fills in behind the scenes.
    final bool hideSyncBanner =
        activeStage.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '') ==
            'firstperiodstarted';

    return Scaffold(
      backgroundColor: Colors.transparent,
      // The wash sits behind the whole page rather than inside the scrollable,
      // so it stays put while the content moves over it -- which is what makes
      // it read as a backdrop and not as the first card.
      // The wash lives on the Today's Cycle card rather than behind the whole
      // page: two of them, in two tints, fought each other. HomeBackdrop is
      // still there if a page-wide one is wanted instead.
      body: Column(
        children: [
          // Onboarding finishes locally, but the cards behind it are filled by
          // syncStateWithBackend(), which makes six sequential requests. On a
          // cold backend that is tens of seconds during which the dashboard
          // showed defaults and then silently rewrote itself, so it read as
          // wrong data rather than data still arriving. A banner beats an
          // unexplained pause, and it keeps whatever is already on screen
          // readable instead of blanking the page behind a spinner.
          // Only while genuinely waiting on first data (nothing cached). A
          // returning user already sees their own last-known dashboard from the
          // launch restore, so the background refresh stays silent instead of
          // flashing this banner on every open.
          if (osState.isInitialSync && !hideSyncBanner) const _DashboardSyncBanner(),
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
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            if (onLifeStageChanged != null) ...[
              const Text(
                "Simulate LifeStage / Branch",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                      {
                        'label': 'Branch A (Prep)',
                        'val': 'firstPeriodNotStarted',
                      },
                      {
                        'label': 'Branch B (Started)',
                        'val': 'firstPeriodStarted',
                      },
                      {
                        'label': 'Stage 3 (Living Cycle)',
                        'val': 'livingWithMyCycle',
                      },
                      {
                        'label': 'Hormonal Health',
                        'val': 'hormonalHealth',
                      },
                      {
                        'label': 'TTC (Trying to Conceive)',
                        'val': 'tryingToConceive',
                      },
                      {
                        'label': 'Pregnancy',
                        'val': 'pregnancy',
                      },
                      {
                        'label': 'Postpartum',
                        'val': 'postpartum',
                      },
                      {
                        'label': 'Perimenopause',
                        'val': 'perimenopause',
                      },
                      {
                        'label': 'Menopause',
                        'val': 'menopause',
                      },
                    ].map((item) {
                      return ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close drawer
                          onLifeStageChanged!(item['val'] as String);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BlushyColors.primary.withValues(
                            alpha: 0.08,
                          ),
                          foregroundColor: BlushyColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          item['label'] as String,
                          style: const TextStyle(fontSize: 11),
                        ),
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
                  label: const Text(
                    "Reset to Onboarding Step",
                    style: TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.danger.withValues(alpha: 0.1),
                    foregroundColor: BlushyColors.danger,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
            const Text(
              "Special Journeys / Stages",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              title: const Text("First Periods Journey"),
              value: state.personalContext.medicalConditions.contains(
                'First Periods',
              ),
              onChanged: (val) {
                final conds = Set<String>.from(
                  state.personalContext.medicalConditions,
                );
                if (val == true) {
                  conds.add('First Periods');
                } else {
                  conds.remove('First Periods');
                }
                state.updatePersonalContext(
                  PersonalContext(
                    userName: state.personalContext.userName,
                    dateOfBirth: state.personalContext.dateOfBirth,
                    trackingPreference:
                        state.personalContext.trackingPreference,
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
            const Text(
              "Life Contexts",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...LifeContext.values.map(
              (lc) => CheckboxListTile(
                title: Text(lc.name),
                value: state.personalContext.lifeContexts.contains(lc),
                onChanged: (val) => state.toggleLifeContext(lc),
              ),
            ),
            const Divider(),
            const Text(
              "Symptoms",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...['fatigue', 'pain', 'poor sleep', 'low energy'].map(
              (s) => CheckboxListTile(
                title: Text(s),
                value: state.wellbeingState.symptoms.contains(s),
                onChanged: (val) => state.toggleSymptom(s),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>(
    String label,
    List<T> items,
    T currentVal,
    ValueChanged<T?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          DropdownButton<T>(
            value: currentVal,
            isExpanded: true,
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.toString().split('.').last),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class ArticleDetailDialog extends StatelessWidget {
  final String title;
  final String summary;

  /// What Docsy is asked when the button is tapped. Defaults to the title.
  final String? question;

  const ArticleDetailDialog({
    super.key,
    required this.title,
    required this.summary,
    this.question,
  });

  String get _question => question ?? 'Tell me more about "$title".';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BlushyColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: BlushyColors.text,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: BlushyColors.secondaryText),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.short_text, size: 16, color: BlushyColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        "SUMMARY OVERVIEW",
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: BlushyColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    summary,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: BlushyColors.text,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // Docsy answers in her own thread, with the question shown as
                // hers first. The dialog closes so the thread is what she
                // comes back to.
                onPressed: () {
                  final question = _question;
                  Navigator.pop(context);
                  openDocsyWith(context, question);
                },
                icon: const DocsyStar(size: 18, color: Colors.white),
                label: Text(
                  "Ask Docsy",
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BlushyColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppLocalizations.of(context).hClose,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              color: BlushyColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

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
              style: GoogleFonts.manrope(
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
