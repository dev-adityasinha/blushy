import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/state.dart';
import '../../../../services/api_contract_client.dart';
import '../../../../services/api_menopause_service.dart';
import '../../view_models/menopause_view_model.dart';
import '../../../../shared/live_refresh.dart';
import 'stage_shared_components.dart';
import '../../../../shared/stage_empty_notice.dart';
import '../../../../shared/user_display_name.dart';
import '../../widgets/log_symptoms_section.dart';
import '../../../../l10n/app_localizations.dart';

/// 🌸 THE MENOPAUSE OPERATING SYSTEM: UNDERSTANDING YOUR NEW CHAPTER
/// Built strictly in adherence to STAGE1_DESIGN_RULES.md:
/// - Surface canvas: #FAF7F2 (warm cream neutral)
/// - Structural cards: #FFFFFF with #EFE8E0 border and 20px radius
/// - Eyebrows: #DD0D22 in GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)
/// - Stage 1 Greeting: 2-line Cormorant Garamond 28-30px with italic crimson user name
/// - Dynamic Docsy Priority Engine (Zero hardcoding)
/// - "My Normal" personalized baselines (No fake 0-100 scores)
/// - "What Changed?" & "What Has Been Steady?" dual low-cortisol tracking
/// - "Do Nothing" as a legitimate clinical recommendation
/// - "Why Am I Seeing This?" AI transparency modal
/// - "I'm Not Sure" option everywhere
/// - "My Treatment" before vs. after 4-week response tracker
/// - Questions Inbox ("My Questions") for clinician visits
/// - "Life Mode" dynamic adaptation & Discreet Private Mode
/// - "Teach Me in 30 Seconds" micro-learning
/// - Floating "+ Tell Blushy" natural language voice/text parser with entity confirmation
class MenopauseDashboard extends StatefulWidget {
  final bool isNested;
  final ScrollController? scrollController;

  const MenopauseDashboard({
    super.key,
    this.isNested = false,
    this.scrollController,
  });

  @override
  State<MenopauseDashboard> createState() => _MenopauseDashboardState();
}

class _MenopauseDashboardState extends State<MenopauseDashboard>
    with WidgetsBindingObserver, LiveRefresh {
  // ─── Design Tokens (STAGE1_DESIGN_RULES.md) ─────────────────────────
  static const Color surfaceCanvas = Color(0xFFFAF7F2);
  static const Color cardBg = Colors.white;
  static const Color cardBorderColor = Color(0xFFEFE8E0);
  static const Color crimsonPrimary = Color(0xFFDD0D22);
  static const Color textMain = Color(0xFF221510);
  static const Color textMuted = Color(0xFF7A6B72);
  static const Color dividerColor = Color(0xFFF3EEE9);
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20));

  // Accent Colors & Soft Tints for circular badges
  static const Color cobaltBlue = Color(0xFF2563EB);
  static const Color cobaltBlueTint = Color(0xFFDBEAFE);
  static const Color emeraldTeal = Color(0xFF0D9488);
  static const Color emeraldTealTint = Color(0xFFCCFBF1);
  static const Color vividMagenta = Color(0xFFF72585);
  static const Color vividMagentaTint = Color(0xFFFFE5F0);
  static const Color royalPurple = Color(0xFF7209B7);
  static const Color royalPurpleTint = Color(0xFFF3E8FF);
  static const Color warmAmber = Color(0xFFD97706);
  static const Color warmAmberTint = Color(0xFFFEF3C7);
  static const Color electricCoral = Color(0xFFFF4A00);
  static const Color electricCoralTint = Color(0xFFFFEBE0);

  // ─── State ─────────────────────────────────────────────────────────
  /// This screen is the View; the server read lives in the tested
  /// MenopauseViewModel and is mirrored back by _onDataChanged.
  final MenopauseViewModel _vm = MenopauseViewModel();

  MenopauseOverviewData? _overview;
  /// The server's own verdict on the last load, so a failure, an offline
  /// device and an empty account are no longer indistinguishable.
  ApiState _overviewState = ApiState.loading;
  bool _loading = true;
  String _activeLifeMode = 'normal';
  bool _privateMode = false;

  // Local rapid checkin states
  String _selectedBody = 'comfortable';
  String _selectedSleep = 'restful';
  String _selectedEnergy = 'steady';
  String _selectedMood = 'calm';
  String _selectedHotFlash = 'none';
  String _selectedJoint = 'none';
  String _selectedVaginal = 'normal';

  late final ScrollController _internalScrollController = ScrollController();
  ScrollController get _effectiveScrollController => widget.scrollController ?? _internalScrollController;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onDataChanged);
    _loadOverview();
    startLiveRefresh();
  }

  @override
  Future<void> refreshNow() => _loadOverview();

  @override
  void dispose() {
    stopLiveRefresh();
    _vm.removeListener(_onDataChanged);
    _vm.dispose();
    _internalScrollController.dispose();
    super.dispose();
  }

  /// Delegated to the view model; _onDataChanged mirrors the result.
  Future<void> _loadOverview() => _vm.load();

  /// The View reacting to its ViewModel.
  void _onDataChanged() {
    if (!mounted) return;
    setState(() {
      _overview = _vm.overview;
      _overviewState = _vm.overviewState;
      _activeLifeMode = _vm.activeLifeMode;
      _privateMode = _vm.privateMode;
      _loading = _vm.isLoading;
    });
  }

  String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ─── Quick Check-In Submission ──────────────────────────────────────
  Future<void> _submitCheckin({bool isNothingMuch = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final payload = {
      'bodyFeeling': isNothingMuch ? 'comfortable' : _selectedBody,
      'sleepQuality': isNothingMuch ? 'restful' : _selectedSleep,
      'energyLevel': isNothingMuch ? 'steady' : _selectedEnergy,
      'moodState': isNothingMuch ? 'calm' : _selectedMood,
      'hotFlashes': isNothingMuch ? 'none' : _selectedHotFlash,
      'jointDiscomfort': isNothingMuch ? 'none' : _selectedJoint,
      'vaginalComfort': isNothingMuch ? 'normal' : _selectedVaginal,
      'bleedingLogged': false,
      'isNothingMuchToday': isNothingMuch,
    };

    final ok = await ApiMenopauseService.recordCheckin(payload);
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isNothingMuch
                ? "Checked in: Nothing much today. You're doing great! ❤️"
                : "Today's check-in saved to your baseline.",
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
          backgroundColor: emeraldTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadOverview();
    }
  }

  // ─── Helper: Category Eyebrow ───────────────────────────────────────
  Widget _buildCategoryEyebrow(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: crimsonPrimary,
        ),
      ),
    );
  }

  // ─── 01: Editorial Greeting (Stage 1 Design Standard) ───────────────
  Widget _buildEditorialGreeting(String userName) {
    final timeGreeting = '${_timeOfDayGreeting()},';

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
                    color: crimsonPrimary,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 02: Today with Docsy (The AI Command Center) ───────────────────
  Widget _buildTodayWithDocsy(MenopauseTodayBrief brief) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFECEB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, size: 18, color: crimsonPrimary),
                  ),
                  const SizedBox(width: 10),
                  Text(AppLocalizations.of(context).menoTodayWithDocsy,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: crimsonPrimary,
                    ),
                  ),
                ],
              ),
              // "Why am I seeing this?" Button
              GestureDetector(
                onTap: () => _showWhyAmISeeingThisSheet('today_with_docsy'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F2EB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.help_outline_rounded, size: 12, color: textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Why this?',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Opening Headline
          Text(
            brief.openingHeadline,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textMain,
              height: 1.25,
            ),
          ),
          // "Do Nothing" Affirmation Banner (If active)
          if (brief.doNothingAffirmation.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🌿', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      brief.doNothingAffirmation,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF166534),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // "What Matters Today" Dynamic Bullet Observations
          ...brief.whatMattersToday.map((matter) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: emeraldTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      matter,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        color: const Color(0xFF3B2F2F),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          // Why Today Transparency tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: surfaceCanvas,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    brief.whyToday,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: dividerColor, height: 1),
          const SizedBox(height: 14),
          // Prompt Pills
          Text(AppLocalizations.of(context).menoAskDocsyToday,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: brief.promptPills.map((pill) {
              return GestureDetector(
                onTap: () => openAskSiaChat(context, pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: surfaceCanvas,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pill,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 12, color: crimsonPrimary),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── 03: How Am I Today? (Unboxed Effortless Check-In) ───────────────
  Widget _buildHowAmIToday() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryEyebrow('HOW AM I TODAY?'),
        const SizedBox(height: 6),
        // Unboxed row of 48px circular icon badges
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildCheckinBadge('Sleep', Icons.nightlight_round, royalPurple, royalPurpleTint, _selectedSleep, (val) {
                setState(() => _selectedSleep = val);
              }, ['restful', 'interrupted_waking', 'night_sweats', 'insomnia', 'not_sure']),
              const SizedBox(width: 14),
              _buildCheckinBadge('Energy', Icons.bolt_rounded, warmAmber, warmAmberTint, _selectedEnergy, (val) {
                setState(() => _selectedEnergy = val);
              }, ['steady', 'fluctuating', 'exhausted', 'not_sure']),
              const SizedBox(width: 14),
              _buildCheckinBadge('Mood', Icons.sentiment_satisfied_rounded, emeraldTeal, emeraldTealTint, _selectedMood, (val) {
                setState(() => _selectedMood = val);
              }, ['calm', 'low', 'anxious', 'foggy', 'not_sure']),
              const SizedBox(width: 14),
              _buildCheckinBadge('Body', Icons.accessibility_new_rounded, cobaltBlue, cobaltBlueTint, _selectedBody, (val) {
                setState(() => _selectedBody = val);
              }, ['comfortable', 'tense', 'fatigued', 'not_sure']),
              const SizedBox(width: 14),
              _buildCheckinBadge('Hot Flash', Icons.thermostat_rounded, electricCoral, electricCoralTint, _selectedHotFlash, (val) {
                setState(() => _selectedHotFlash = val);
              }, ['none', 'mild_daytime', 'night_flushes', 'frequent', 'not_sure']),
              const SizedBox(width: 14),
              _buildCheckinBadge('Joints', Icons.fitness_center_rounded, emeraldTeal, emeraldTealTint, _selectedJoint, (val) {
                setState(() => _selectedJoint = val);
              }, ['none', 'morning_stiffness', 'aching', 'not_sure']),
              const SizedBox(width: 14),
              _buildCheckinBadge('Intimate', Icons.spa_outlined, vividMagenta, vividMagentaTint, _selectedVaginal, (val) {
                setState(() => _selectedVaginal = val);
              }, ['normal', 'dryness', 'discomfort', 'not_sure']),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Quick Action Buttons
        Row(
          children: [
            Expanded(
              flex: 6,
              child: ElevatedButton.icon(
                onPressed: () => _submitCheckin(isNothingMuch: false),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(AppLocalizations.of(context).menoSaveTodaySLog,
                  style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: crimsonPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: OutlinedButton(
                onPressed: () => _submitCheckin(isNothingMuch: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: emeraldTeal,
                  side: const BorderSide(color: emeraldTeal, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(AppLocalizations.of(context).menoNothingMuchToday,
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckinBadge(
    String label,
    IconData icon,
    Color solidColor,
    Color tintColor,
    String currentValue,
    Function(String) onSelect,
    List<String> options,
  ) {
    return GestureDetector(
      onTap: () {
        // Cycle to next option
        final nextIdx = (options.indexOf(currentValue) + 1) % options.length;
        onSelect(options[nextIdx]);
      },
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tintColor,
              shape: BoxShape.circle,
              border: Border.all(color: solidColor.withValues(alpha: 0.3), width: 1.2),
            ),
            child: Icon(icon, size: 22, color: solidColor),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: textMain),
          ),
          Text(
            currentValue == 'not_sure' ? 'Not sure' : currentValue.replaceAll('_', ' '),
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: currentValue == 'not_sure' ? crimsonPrimary : textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 04: What Changed? & What Has Been Steady? (Dual Cards) ────────
  Widget _buildWhatChangedAndSteady(List<MenopauseShiftItem> changed, List<MenopauseShiftItem> steady) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryEyebrow('LONGITUDINAL OBSERVATIONS'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card 1: What Changed?
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: cardRadius,
                  border: Border.all(color: cardBorderColor, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.change_history_rounded, size: 16, color: crimsonPrimary),
                        const SizedBox(width: 6),
                        Text(
                          'WHAT CHANGED?',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: crimsonPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...changed.take(2).map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.detail,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: textMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Card 2: What Has Been Steady?
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: cardRadius,
                  border: Border.all(color: cardBorderColor, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 16, color: emeraldTeal),
                        const SizedBox(width: 6),
                        Text(AppLocalizations.of(context).menoWhatSSteady,
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: emeraldTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...steady.take(2).map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.detail,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: textMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── 05: What Do I Need Today? (Dynamic Actions) ────────────────────
  Widget _buildWhatDoINeedActions() {
    final actions = [
      {'label': 'DO NOTHING', 'desc': 'Rest is productive', 'icon': Icons.spa_outlined, 'color': emeraldTeal},
      {'label': 'MOVE', 'desc': 'Brisk walking for bones', 'icon': Icons.directions_walk_rounded, 'color': cobaltBlue},
      {'label': 'COOL DOWN', 'desc': 'Evening room cooling', 'icon': Icons.ac_unit_rounded, 'color': royalPurple},
      {'label': 'LOG NOTE', 'desc': 'In your own words', 'icon': Icons.edit_note_rounded, 'color': electricCoral},
      {'label': 'LIFE MODE', 'desc': _activeLifeMode.toUpperCase(), 'icon': Icons.tune_rounded, 'color': warmAmber},
      {'label': 'HYDRATE', 'desc': 'Tissue hydration', 'icon': Icons.water_drop_outlined, 'color': cobaltBlue},
      {'label': 'ASK DOCSY', 'desc': 'Ask anything today', 'icon': Icons.auto_awesome, 'color': crimsonPrimary},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryEyebrow('WHAT DO I NEED TODAY?'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: actions.map((act) {
              final color = act['color'] as Color;
              return GestureDetector(
                onTap: () {
                  if (act['label'] == 'ASK DOCSY') {
                    openAskSiaChat(context, "What should I focus on for my health today?");
                  } else if (act['label'] == 'LIFE MODE') {
                    _showLifeModePicker();
                  } else if (act['label'] == 'LOG NOTE') {
                    _openTellBlushyDialog();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected focus: ${act['label']} - ${act['desc']}')),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(act['icon'] as IconData, size: 16, color: color),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            act['label'] as String,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: textMain,
                            ),
                          ),
                          Text(
                            act['desc'] as String,
                            style: GoogleFonts.manrope(fontSize: 9.5, color: textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── 06: My Health (5 Core Domains) ─────────────────────────────────
  Widget _buildMyHealthDomains(List<MenopauseDomain> domains) {
    final displayDomains = domains.isNotEmpty ? domains : MenopauseDomain.defaults();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryEyebrow('MY HEALTH · 5 PILLARS'),
        ...displayDomains.map((dom) {
          final isIntimate = dom.key == 'intimate_urinary';
          final showMasked = _privateMode && isIntimate;
          final bgColor = Color(int.tryParse(dom.bgHex) ?? 0xFFCCFBF1);
          final solidColor = Color(int.tryParse(dom.colorHex) ?? 0xFF0D9488);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: cardRadius,
              border: Border.all(color: cardBorderColor, width: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.health_and_safety_rounded,
                    size: 20,
                    color: solidColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showMasked ? 'Intimate Health (Private)' : dom.title,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        showMasked ? 'Discreet mode active. Tap to view private details.' : dom.description,
                        style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showDomainDetailSheet(dom),
                            child: Text(AppLocalizations.of(context).menoLearnGuidance,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: crimsonPrimary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            dom.shortLabel,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─── 07: My Normal (Personalized Baseline) ──────────────────────────
  Widget _buildMyNormal(MenopauseMyNormal myNormal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 18, color: royalPurple),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).menoMyNormal,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: royalPurple,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: royalPurpleTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  myNormal.confidence,
                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: royalPurple),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            myNormal.status,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            myNormal.description,
            style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.35),
          ),
          const SizedBox(height: 16),
          const Divider(color: dividerColor, height: 1),
          const SizedBox(height: 12),
          // Markers matrix
          ...myNormal.markers.map((marker) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    marker.domain,
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        marker.baseline,
                        style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: crimsonPrimary),
                      ),
                      Text(
                        marker.status,
                        style: GoogleFonts.manrope(fontSize: 9.5, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 08: My Treatment ("What Changed After Starting This?") ─────────
  Widget _buildMyTreatment(List<MenopauseTreatment> treatments, List<MenopauseTreatmentResponse> responses) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.medication_rounded, size: 18, color: crimsonPrimary),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).menoMyTreatmentJourney,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: crimsonPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showAddTreatmentSheet,
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 14, color: crimsonPrimary),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context).menoAdd,
                      style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: crimsonPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'What changed after I started this?',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tracks before vs. after patterns over time (observed correlation, not clinical proof of causality).',
            style: GoogleFonts.manrope(fontSize: 11, color: textMuted, height: 1.35),
          ),
          const SizedBox(height: 14),
          ...treatments.map((t) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceCanvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardBorderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_box_outlined, size: 16, color: emeraldTeal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: textMain),
                        ),
                        Text(
                          '${t.category} • ${t.dose}',
                          style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(AppLocalizations.of(context).menoActive,
                    style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: emeraldTeal),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 09: Questions Inbox ("My Questions") ───────────────────────────
  Widget _buildMyQuestions(List<MenopauseQuestion> questions) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_center_rounded, size: 18, color: cobaltBlue),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).menoMyQuestionsInbox,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: cobaltBlue,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showAddQuestionSheet,
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded, size: 14, color: cobaltBlue),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context).menoSaveQuestion,
                      style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: cobaltBlue),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${questions.length} questions saved for your next clinician visit.',
            style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted),
          ),
          const SizedBox(height: 12),
          ...questions.map((q) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceCanvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('○ ', style: TextStyle(fontSize: 14, color: cobaltBlue)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.text,
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          q.category,
                          style: GoogleFonts.manrope(fontSize: 9.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 10: Prepare for Care (Doctor Companion) ────────────────────────
  Widget _buildPrepareForCare() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryEyebrow('DOCTOR → BLUSHY → USER CLOSED LOOP'),
          Text(
            'Prepare for your next appointment',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 6),
          Text(
            'Blushy synthesizes your logged shifts, baseline rhythms, active treatments, and saved questions into a concise 1-page clinician brief.',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.35),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleShareClinicianBrief,
              icon: const Icon(Icons.share_rounded, size: 16),
              label: Text(
                'Share Brief with My Clinician',
                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: textMain,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 11: My Health Story (Narrative Timeline) ────────────────────────
  Widget _buildMyHealthStory(List<MenopauseHealthStoryItem> story) {
    final displayStory = story.isNotEmpty ? story : MenopauseHealthStoryItem.defaults();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryEyebrow('MY HEALTH STORY'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: cardRadius,
            border: Border.all(color: cardBorderColor, width: 1.0),
          ),
          child: Column(
            children: displayStory.map((item) {
              final color = Color(int.tryParse(item.colorHex) ?? 0xFF0D9488);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.history_edu_rounded, size: 16, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.stage} • ${item.timing}',
                            style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.title,
                            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: textMain),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.desc,
                            style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.35),
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

  // ─── 12: Teach Me in 30 Seconds ─────────────────────────────────────
  Widget _buildTeachMe30Seconds(List<MenopauseTeachMeItem> items) {
    final displayItems = items.isNotEmpty ? items : MenopauseTeachMeItem.defaults();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryEyebrow('TEACH ME IN 30 SECONDS'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: displayItems.map((item) {
              final color = Color(int.tryParse(item.colorHex) ?? 0xFFDD0D22);
              final bgColor = Color(int.tryParse(item.bgHex) ?? 0xFFFFECEB);
              return Container(
                width: 250,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: cardRadius,
                  border: Border.all(color: cardBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.badge,
                            style: GoogleFonts.manrope(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                        Text(
                          item.topic,
                          style: GoogleFonts.manrope(fontSize: 9.5, color: textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.summary,
                      style: GoogleFonts.manrope(fontSize: 11, color: textMuted, height: 1.35),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showTeachMeDetailSheet(item),
                      child: Text(AppLocalizations.of(context).menoRead30sSummary,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: crimsonPrimary,
                        ),
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

  // ─── 13: Dual Trigger Buttons (Something feels different / wrong) ───
  Widget _buildDualTriggers() {
    return Row(
      children: [
        // 🟡 Something feels different
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showIsThisNormalSheet(),
            icon: const Icon(Icons.psychology_alt_rounded, size: 15, color: warmAmber),
            label: Text(AppLocalizations.of(context).menoSomethingFeelsDifferent,
              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: warmAmber),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: warmAmber),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 🔴 Something doesn't feel right
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showSafetyCheckSheet(),
            icon: const Icon(Icons.health_and_safety_rounded, size: 15, color: crimsonPrimary),
            label: Text(
              'Doesn\'t feel right?',
              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: crimsonPrimary),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: crimsonPrimary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Postmenopausal Bleeding Emergency Red-Flag Banner ───────────────
  Widget _buildSafetyAlertBanner(MenopauseSafetyAlert alert) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEB),
        borderRadius: cardRadius,
        border: Border.all(color: crimsonPrimary.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency_rounded, size: 20, color: crimsonPrimary),
              const SizedBox(width: 8),
              Text(
                alert.eyebrow,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: crimsonPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.headline,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textMain,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            alert.explanation,
            style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF5A3030), height: 1.35),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _handleShareClinicianBrief,
            icon: const Icon(Icons.calendar_month_rounded, size: 14),
            label: Text(AppLocalizations.of(context).menoPrepareDoctorConsultation, style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: crimsonPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Floating "+ Tell Blushy" Natural Note Dialog ───────────────────
  void _openTellBlushyDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool parsing = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '＋ TELL BLUSHY IN YOUR WORDS',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: crimsonPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Speak or type naturally. Blushy will extract the health signals and ask for your confirmation before logging.',
                    style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'e.g. "Woke up twice around 3am drenched in sweat, and my knees feel stiff this morning..."',
                      hintStyle: GoogleFonts.manrope(fontSize: 12, color: textMuted),
                      filled: true,
                      fillColor: surfaceCanvas,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: cardBorderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: parsing
                          ? null
                          : () async {
                              final text = controller.text.trim();
                              if (text.isEmpty) return;
                              setSheetState(() => parsing = true);
                              final parseResult = await ApiMenopauseService.parseNaturalNote(text);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (mounted && parseResult != null) {
                                _showParseConfirmationDialog(parseResult);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crimsonPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: parsing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(AppLocalizations.of(context).menoUnderstandNote, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showParseConfirmationDialog(MenopauseNoteParseResult result) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppLocalizations.of(context).menoConfirmWhatYouLogged,
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.confirmationMessage,
                style: GoogleFonts.manrope(fontSize: 13, color: textMain, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: result.extractedEntities.map((e) {
                  return Chip(
                    label: Text(e, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600)),
                    backgroundColor: emeraldTealTint,
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).menoCancel, style: GoogleFonts.manrope(color: textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ApiMenopauseService.recordCheckin(result.parsedCheckin);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved to your health log!')),
                );
                _loadOverview();
              },
              style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary, foregroundColor: Colors.white),
              child: Text(AppLocalizations.of(context).menoConfirmSave, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  // ─── Dialogs & Sheets ───────────────────────────────────────────────
  void _showWhyAmISeeingThisSheet(String moduleKey) async {
    final info = await ApiMenopauseService.getWhyAmISeeingThis(moduleKey);
    if (!mounted || info == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryEyebrow('AI TRANSPARENCY & MEDICAL HUMILITY'),
              Text(
                'Why am I seeing this?',
                style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: textMain),
              ),
              const SizedBox(height: 14),
              _buildWhyRow('YOU LOGGED', info.youLogged, Icons.edit_note_rounded, emeraldTeal),
              _buildWhyRow('WE\'RE NOTICING', info.wereNoticing, Icons.analytics_outlined, royalPurple),
              _buildWhyRow('WHY IT MAY MATTER', info.whyItMayMatter, Icons.health_and_safety_outlined, cobaltBlue),
              _buildWhyRow('WHAT BLUSHY DOESN\'T KNOW', info.whatBlushyDoesntKnow, Icons.help_outline_rounded, warmAmber),
              _buildWhyRow('WHAT YOU CAN DO', info.whatYouCanDo, Icons.touch_app_rounded, crimsonPrimary),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWhyRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.manrope(fontSize: 12, color: textMain, height: 1.35),
                children: [
                  TextSpan(text: '$label: ', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: color)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showIsThisNormalSheet() {
    final queryController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        MenopauseIsThisNormalResult? res;
        bool querying = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryEyebrow('IS THIS NORMAL?'),
                    Text(
                      'Ask about symptoms or changes',
                      style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: queryController,
                      decoration: InputDecoration(
                        hintText: 'e.g. "I\'ve started waking at 3am every night"',
                        filled: true,
                        fillColor: surfaceCanvas,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: querying
                            ? null
                            : () async {
                                final q = queryController.text.trim();
                                if (q.isEmpty) return;
                                setSheetState(() => querying = true);
                                final result = await ApiMenopauseService.askIsThisNormal(q);
                                setSheetState(() {
                                  res = result;
                                  querying = false;
                                });
                              },
                        style: ElevatedButton.styleFrom(backgroundColor: warmAmber, foregroundColor: Colors.white),
                        child: querying
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(AppLocalizations.of(context).menoAskDocsy),
                      ),
                    ),
                    if (res != null) ...[
                      const SizedBox(height: 16),
                      const Divider(color: dividerColor),
                      const SizedBox(height: 8),
                      Text('WHAT WE KNOW:', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: textMuted)),
                      Text(res!.whatWeKnow, style: GoogleFonts.manrope(fontSize: 12, height: 1.35)),
                      const SizedBox(height: 8),
                      Text('WHAT YOU CAN TRY:', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: textMuted)),
                      Text(res!.whatYouCanTry, style: GoogleFonts.manrope(fontSize: 12, height: 1.35)),
                      const SizedBox(height: 8),
                      Text('WHEN TO CHECK WITH DOCTOR:', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: crimsonPrimary)),
                      Text(res!.whenToCheckWithDoctor, style: GoogleFonts.manrope(fontSize: 12, color: crimsonPrimary, height: 1.35)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSafetyCheckSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryEyebrow('SAFETY CHECK'),
              Text('When to seek prompt care', style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                '• Any postmenopausal bleeding or unexpected spotting (requires prompt ultrasound).\n'
                '• Sudden severe chest pressure or shortness of breath.\n'
                '• Severe unremitting bone pain or sudden fractures.\n'
                '• Severe sudden mood lows or intrusive thoughts.',
                style: GoogleFonts.manrope(fontSize: 12.5, height: 1.45, color: textMain),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleShareClinicianBrief();
                },
                style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary, foregroundColor: Colors.white),
                child: Text(AppLocalizations.of(context).menoPrepareDoctorSummary),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLifeModePicker() {
    final modes = [
      {'key': 'normal', 'label': 'Everyday Life', 'icon': Icons.spa_rounded},
      {'key': 'travelling', 'label': 'Travelling', 'icon': Icons.flight_takeoff_rounded},
      {'key': 'exhausted', 'label': 'Exhausted', 'icon': Icons.bedtime_rounded},
      {'key': 'big_presentation', 'label': 'Big Presentation', 'icon': Icons.work_outline_rounded},
      {'key': 'wedding_celebration', 'label': 'Wedding & Events', 'icon': Icons.celebration_rounded},
      {'key': 'exercise_streak', 'label': 'Exercising More', 'icon': Icons.directions_run_rounded},
      {'key': 'bad_sleep_week', 'label': 'Bad Sleep Week', 'icon': Icons.hotel_rounded},
      {'key': 'overwhelmed', 'label': 'Overwhelmed', 'icon': Icons.psychology_alt_rounded},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryEyebrow('LIFE MODE PRESETS'),
              Text('Adapt Blushy to your days', style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: modes.map((m) {
                  final isSel = _activeLifeMode == m['key'];
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(m['icon'] as IconData, size: 14, color: isSel ? Colors.white : textMain),
                        const SizedBox(width: 6),
                        Text(m['label'] as String),
                      ],
                    ),
                    selected: isSel,
                    selectedColor: emeraldTeal,
                    onSelected: (sel) async {
                      Navigator.pop(ctx);
                      final key = m['key'] as String;
                      setState(() => _activeLifeMode = key);
                      await ApiMenopauseService.setLifeMode(key);
                      _loadOverview();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddQuestionSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryEyebrow('QUESTIONS INBOX'),
              Text(AppLocalizations.of(context).menoSaveQuestionForDoctor, style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'e.g. "Should I consider a DEXA scan this year?"',
                  filled: true,
                  fillColor: surfaceCanvas,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final txt = controller.text.trim();
                    if (txt.isEmpty) return;
                    Navigator.pop(ctx);
                    await ApiMenopauseService.addQuestion(txt);
                    _loadOverview();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: cobaltBlue, foregroundColor: Colors.white),
                  child: Text(AppLocalizations.of(context).menoSaveToQuestionsInbox),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddTreatmentSheet() {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryEyebrow('MY TREATMENT'),
              Text(AppLocalizations.of(context).menoAddMedicationOrSupplement, style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Treatment name (e.g. Transdermal Estradiol)',
                  filled: true,
                  fillColor: surfaceCanvas,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: doseCtrl,
                decoration: InputDecoration(
                  hintText: 'Dose & frequency (e.g. 50 mcg twice weekly)',
                  filled: true,
                  fillColor: surfaceCanvas,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx);
                    await ApiMenopauseService.addTreatment({
                      'name': name,
                      'dose': doseCtrl.text.trim(),
                      'category': 'Therapy / Supplement',
                      'startDate': DateTime.now().toIso8601String(),
                    });
                    _loadOverview();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary, foregroundColor: Colors.white),
                  child: Text(AppLocalizations.of(context).menoSaveTreatment),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDomainDetailSheet(MenopauseDomain dom) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryEyebrow(dom.shortLabel),
              Text(dom.title, style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(dom.description, style: GoogleFonts.manrope(fontSize: 13, height: 1.4)),
              const SizedBox(height: 12),
              Text('CLINICAL FOCUS:', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: crimsonPrimary)),
              Text(dom.clinicalFocus, style: GoogleFonts.manrope(fontSize: 12, height: 1.35)),
              const SizedBox(height: 10),
              Text('SCREENING RECOMMENDATION:', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: emeraldTeal)),
              Text(dom.screening, style: GoogleFonts.manrope(fontSize: 12, height: 1.35)),
            ],
          ),
        );
      },
    );
  }

  void _showTeachMeDetailSheet(MenopauseTeachMeItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryEyebrow(item.topic),
                Text(item.title, style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(item.summary, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                const SizedBox(height: 12),
                Text('WHAT IT FEELS LIKE:', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: textMuted)),
                Text(item.whatItFeelsLike, style: GoogleFonts.manrope(fontSize: 12, height: 1.35)),
                const SizedBox(height: 10),
                Text('TREATMENTS THAT EXIST:', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: emeraldTeal)),
                Text(item.whatTreatmentsExist, style: GoogleFonts.manrope(fontSize: 12, height: 1.35)),
                const SizedBox(height: 10),
                Text('WHEN TO TALK TO YOUR DOCTOR:', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: crimsonPrimary)),
                Text(item.whenToTalkToDoctor, style: GoogleFonts.manrope(fontSize: 12, color: crimsonPrimary, height: 1.35)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleShareClinicianBrief() async {
    final brief = await ApiMenopauseService.getClinicianBrief();
    if (!mounted || brief == null) return;

    await Clipboard.setData(ClipboardData(text: brief.rawSummaryText));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Clinician summary copied to clipboard!', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        backgroundColor: emeraldTeal,
      ),
    );

    try {
      await Share.share(brief.rawSummaryText, subject: brief.title);
    } catch (_) {}
  }

  // ─── Build Master Layout ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final osState = BlushyOSProvider.of(context);
    final pc = osState.personalContext;
    // Defaulted to 'Ananya' -- an invented name shown to anyone whose own
    // was not known.
    final userName = userDisplayName(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: surfaceCanvas,
        body: const Center(
          child: CircularProgressIndicator(color: crimsonPrimary),
        ),
      );
    }

    final data = _overview;
    // The fallback shown when the server returned nothing. `whyToday` used to
    // read "Tailored to your current baseline", which claimed a personalisation
    // that had not happened and a baseline that may not exist. It now says what
    // it is: general guidance for the stage.
    final brief = data?.todayWithDocsy ??
        MenopauseTodayBrief(
          openingHeadline: 'Understanding your body. Protecting your vitality.',
          doNothingAffirmation: '',
          whatMattersToday: ['Keep moving comfortably', 'Protect bone density'],
          whyToday: 'General guidance for this stage, not based on your logs.',
          promptPills: ['Is 3 AM waking common?', 'Protecting bone health'],
        );

    final sectionOrder = data?.sectionOrder ??
        [
          'editorial_greeting',
          'today_with_docsy',
          'how_am_i_today',
          'what_changed',
          'what_been_steady',
          'what_do_i_need_actions',
          'my_health_domains',
          'my_normal',
          'my_treatment',
          'my_questions',
          'prepare_for_care',
          'my_health_story',
          'teach_me_30s',
        ];

    // Build widgets mapping for dynamic layout
    final Map<String, Widget> moduleMap = {
      'editorial_greeting': _buildEditorialGreeting(userName),
      'safety_alert_bleeding': data?.safetyAlert != null
          ? _buildSafetyAlertBanner(data!.safetyAlert!)
          : const SizedBox.shrink(),
      'today_with_docsy': _buildTodayWithDocsy(brief),
      'how_am_i_today': _buildHowAmIToday(),
      'what_changed': _buildWhatChangedAndSteady(data?.whatChanged ?? [], data?.whatBeenSteady ?? []),
      'what_been_steady': const SizedBox.shrink(), // Rendered inside dual card
      'what_do_i_need_actions': _buildWhatDoINeedActions(),
      'my_health_domains': _buildMyHealthDomains(data?.healthDomains ?? []),
      'my_normal': data != null ? _buildMyNormal(data.myNormal) : const SizedBox.shrink(),
      'my_treatment': _buildMyTreatment(data?.treatments ?? [], data?.treatmentResponse ?? []),
      'my_questions': _buildMyQuestions(data?.questions ?? []),
      'prepare_for_care': _buildPrepareForCare(),
      'my_health_story': _buildMyHealthStory(data?.healthStory ?? []),
      'teach_me_30s': _buildTeachMe30Seconds(data?.teachMeIn30Seconds ?? []),
    };

    final contentList = <Widget>[];
    // The greeting is the first thing on the page in every other stage, and it
    // has to be here too. It used to come from `sectionOrder`, which is added
    // after the notice and the logging row -- so this stage greeted her a
    // third of the way down, under a symptom sheet. Rendered explicitly here
    // and skipped in the loop below.
    contentList.add(_buildEditorialGreeting(userName));
    contentList.add(const SizedBox(height: 24));
    // Nothing came back from the server, so every section below is falling back
    // to the stage's general content. Saying so is the difference between "we
    // have nothing for you yet" and "here is your brief" (spec §4, §31).
    contentList.add(StageStateNotice(
      state: _overviewState,
      hasData: data != null,
      emptyMessage:
          'There is nothing recorded for this stage yet, so what follows is general '
          'guidance rather than anything worked out from your own entries. Complete a '
          'check-in to start building your baseline.',
      onRetry: () {
        setState(() => _loading = true);
        _loadOverview();
      },
    ));
    // Logging sits outside the server's section order on purpose: the order
    // comes from the API, and one that simply omits a logging key would
    // leave this stage with no way into the sheet at all.
    contentList.add(const LogSymptomsSection(stageKey: 'menopause'));
    contentList.add(const SizedBox(height: 24));
    for (final secKey in sectionOrder) {
      // Already rendered at the top, wherever the server placed it.
      if (secKey == 'editorial_greeting') continue;
      if (moduleMap.containsKey(secKey)) {
        final w = moduleMap[secKey]!;
        if (w is! SizedBox || w.child != null) {
          contentList.add(w);
          contentList.add(const SizedBox(height: 24));
        }
      }
    }

    // Always add dual triggers at the end
    contentList.add(_buildDualTriggers());
    contentList.add(const SizedBox(height: 24));

    final listWidget = ListView(
      controller: _effectiveScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: contentList,
    );

    return Scaffold(
      backgroundColor: surfaceCanvas,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: listWidget,
          ),
        ),
      ),
    );
  }
}
