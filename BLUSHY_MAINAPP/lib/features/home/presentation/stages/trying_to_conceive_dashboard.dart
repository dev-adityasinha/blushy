import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/storage.dart';
import '../../../../services/api_auth_service.dart';
import '../../../../services/api_period_service.dart';
import '../../view_models/cycle_view_model.dart';
import '../../../../shared/live_refresh.dart';
import '../../../../services/api_contract_client.dart';
import '../../../../shared/stage_empty_notice.dart';
import '../../../../services/api_checkin_service.dart';
import '../../../../services/api_sia_service.dart';
import '../../widgets/blushy_period_tracker_card.dart';
import 'stage_shared_components.dart';
import '../../../../shared/user_display_name.dart';
import '../../widgets/log_symptoms_section.dart';
import 'health_library_section.dart';
import 'trying_to_conceive_sections.dart';
import '../../../../l10n/app_localizations.dart';

class TryingToConceiveDashboard extends StatefulWidget {
  final bool isNested;
  final ScrollController? scrollController;

  const TryingToConceiveDashboard({
    super.key,
    this.isNested = false,
    this.scrollController,
  });

  @override
  State<TryingToConceiveDashboard> createState() => _TryingToConceiveDashboardState();
}

class _TryingToConceiveDashboardState extends State<TryingToConceiveDashboard>
    with WidgetsBindingObserver, LiveRefresh {
  // ─── Design Tokens (STAGE1_DESIGN_RULES.md) ─────────────────────────
  static const Color surfaceCanvas = Color(0xFFFAF7F2);
  static const Color cardBg = Colors.white;
  static const Color cardBorderColor = Color(0xFFEFE8E0);
  static const Color crimsonPrimary = Color(0xFFDD0D22);
  static const Color textMain = Color(0xFF221510);
  static const Color textMuted = Color(0xFF7A6B72);
  static const Color dividerColor = Color(0xFFF3EEE9);
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(18));

  // ─── Biometrics & Daily Logging State ──────────────────────────────
  double? _ttcLoggedBBT;
  String? _ttcLoggedOPK; // 'Negative / Low', 'High', 'Peak (Surge)'
  String? _ttcLoggedCervicalFluid; // 'Dry', 'Creamy', 'Watery', 'Egg White (Peak)'
  bool _ttcLoggedIntercourse = false;
  String? _partnerDecision; // 'trying_today', 'not_today', 'decide_together'
  String? _selectedOutsideActivity;

  // ─── Cycle & Rhythm State ──────────────────────────────────────────
  int _currentCycleDay = 14;
  int _cycleLength = 29;
  int _periodLength = 5;
  DateTime? _lastPeriodStartDate;
  bool _hasLoggedPeriod = false;

  /// How the cycle read went, so "nothing logged" and "could not load" stop
  /// looking identical.
  ///
  /// This screen alone used `getPredictions()`, whose errors were swallowed by
  /// a bare `.catchError((_) {})`. A slow or refused request therefore left
  /// the card asserting "No period logged yet" about an account that had one
  /// -- and a warm backend a minute later showed the day. Same data, two
  /// answers, which is exactly how it looked: sometimes working, sometimes
  /// not. The other cycle dashboards have tracked this all along.
  ApiState _cycleState = ApiState.loading;

  /// The cycle-loading concern now lives in a tested view model; this widget is
  /// its View. The fields above are kept as local mirrors so the rest of the
  /// screen reads unchanged, and are refreshed from the view model on change.
  final CycleViewModel _cycleVM = CycleViewModel(defaultCycleLength: 29, defaultCycleDay: 14);

  // ─── Real-Time Dynamic AI & Docsy State ─────────────────────────────
  bool _isLoadingAi = false;
  String _dynamicDocsyThought =
      'Your biological signals suggest the fertile window may be open. You don’t need to keep checking everything today; sperm viability spans several days in fertile fluid, so take things at an unhurried, collaborative pace.';
  String _dynamicDocsyNote = 'Low-cortisol evenings and unpressured connection support both hormonal balance and nervous system ease.';
  List<String> _dynamicDocsyActions = [
    'When is my fertile window?',
    'How to read LH strips?',
    'Explain BBT shift',
    'Can we take a break today?',
  ];

  // ─── Emotional & Journey State ─────────────────────────────────────
  bool _isAnxietyModeActive = false;
  bool _isTtcPaused = false;
  String? _emotionalCheckInStatus;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ScrollController _internalScrollController = ScrollController();
  ScrollController get _effectiveScrollController => widget.scrollController ?? _internalScrollController;

  @override
  void initState() {
    super.initState();
    _cycleVM.addListener(_onCycleChanged);
    _rehydrateTtcState();
    _fetchDynamicAiInsights();
    startLiveRefresh();
  }

  @override
  Future<void> refreshNow() => _cycleVM.load();

  /// The View reacting to its ViewModel: mirror the resolved cycle read into
  /// the local fields the rest of the screen already uses.
  void _onCycleChanged() {
    if (!mounted) return;
    setState(() {
      _cycleState = _cycleVM.state;
      if (_cycleVM.hasLoggedPeriod) {
        _hasLoggedPeriod = true;
        _lastPeriodStartDate = _cycleVM.lastPeriodStart;
        _cycleLength = _cycleVM.cycleLength;
        _periodLength = _cycleVM.periodLength;
        _currentCycleDay = _cycleVM.currentCycleDay;
      }
    });
  }

  @override
  void dispose() {
    stopLiveRefresh();
    _cycleVM.removeListener(_onCycleChanged);
    _cycleVM.dispose();
    _internalScrollController.dispose();
    super.dispose();
  }

  // ─── Rehydrate State from Storage & Backend ────────────────────────
  void _rehydrateTtcState() {
    try {
      final checkin = BlushyStorage.read('daily_checkin.json');
      if (checkin.isNotEmpty) {
        if (checkin['ttc_bbt'] != null) {
          _ttcLoggedBBT = double.tryParse(checkin['ttc_bbt'].toString());
        }
        if (checkin['ttc_opk'] != null) {
          _ttcLoggedOPK = checkin['ttc_opk'].toString();
        }
        if (checkin['ttc_cervical_fluid'] != null) {
          _ttcLoggedCervicalFluid = checkin['ttc_cervical_fluid'].toString();
        }
        if (checkin['ttc_intercourse'] != null) {
          _ttcLoggedIntercourse = checkin['ttc_intercourse'] == true;
        }
        if (checkin['partner_decision'] != null) {
          _partnerDecision = checkin['partner_decision'].toString();
        }
        if (checkin['outside_activity'] != null) {
          _selectedOutsideActivity = checkin['outside_activity'].toString();
        }
      }

      final ttcState = BlushyStorage.read('ttc_state.json');
      if (ttcState.isNotEmpty) {
        _isTtcPaused = ttcState['is_paused'] == true;
        _emotionalCheckInStatus = ttcState['emotional_status']?.toString();
      }

      final savedPeriod = BlushyStorage.read('last_period_entry.json');
      if (savedPeriod.isNotEmpty && savedPeriod['periodStartDate'] != null) {
        final parsed = DateTime.tryParse(savedPeriod['periodStartDate'].toString());
        if (parsed != null) {
          _lastPeriodStartDate = parsed;
          _hasLoggedPeriod = true;
          final diff = DateTime.now().difference(parsed).inDays;
          _currentCycleDay = (diff + 1).clamp(1, _cycleLength);
        }
      }

      // The cycle read is the view model's job now; _onCycleChanged mirrors
      // its result back. All the fetch/error/day logic that used to sit here
      // lives in CycleViewModel, where it is unit-tested.
      _cycleVM.load();
    } catch (_) {}
  }

  Future<void> _fetchDynamicAiInsights() async {
    if (!mounted) return;
    setState(() => _isLoadingAi = true);
    try {
      final String phase = _estimatedCyclePhase;
      final List<String> signals = [];
      if (_ttcLoggedOPK != null) signals.add('LH ${_ttcLoggedOPK!}');
      if (_ttcLoggedCervicalFluid != null) signals.add('Cervical fluid ${_ttcLoggedCervicalFluid!}');
      if (_ttcLoggedBBT != null) signals.add('BBT ${_ttcLoggedBBT!.toStringAsFixed(1)}°F');
      if (_ttcLoggedIntercourse) signals.add('Intimacy logged');

      final result = await ApiSiaService().getHealthInsights(
        stage: 'ttc',
        cycleDay: _currentCycleDay,
        phase: phase,
      );

      if (mounted && result.isNotEmpty) {
        setState(() {
          _dynamicDocsyThought = result['thought'] ?? result['narrative'] ?? result['summary'] ?? _dynamicDocsyThought;
          _dynamicDocsyNote = result['note'] ?? result['oneThingToKeepInMind'] ?? _dynamicDocsyNote;
          if (result['suggestions'] is List && (result['suggestions'] as List).isNotEmpty) {
            _dynamicDocsyActions = (result['suggestions'] as List).map((e) => e.toString()).toList();
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  void _saveDailyTtcLog() {
    final checkin = Map<String, dynamic>.from(BlushyStorage.read('daily_checkin.json'));
    if (_ttcLoggedBBT != null) checkin['ttc_bbt'] = _ttcLoggedBBT;
    if (_ttcLoggedOPK != null) checkin['ttc_opk'] = _ttcLoggedOPK;
    if (_ttcLoggedCervicalFluid != null) checkin['ttc_cervical_fluid'] = _ttcLoggedCervicalFluid;
    checkin['ttc_intercourse'] = _ttcLoggedIntercourse;
    checkin['partner_decision'] = _partnerDecision;
    checkin['outside_activity'] = _selectedOutsideActivity;
    checkin['date'] = DateTime.now().toIso8601String();
    BlushyStorage.write('daily_checkin.json', checkin);

    final List<String> symptoms = [];
    if (_ttcLoggedOPK != null) symptoms.add('OPK: $_ttcLoggedOPK');
    if (_ttcLoggedCervicalFluid != null) symptoms.add('Fluid: $_ttcLoggedCervicalFluid');
    if (_ttcLoggedIntercourse) symptoms.add('Trying / Intimacy');

    ApiCheckinService().submitDailyCheckin(
      logDate: DateTime.now().toIso8601String().substring(0, 10),
      symptoms: symptoms,
    );

    ApiAuthService().saveOnboardingAnswers({
      'ttc_bbt': _ttcLoggedBBT,
      'ttc_opk': _ttcLoggedOPK,
      'ttc_cervical_fluid': _ttcLoggedCervicalFluid,
      'ttc_intercourse': _ttcLoggedIntercourse,
      'partner_decision': _partnerDecision,
      'outside_activity': _selectedOutsideActivity,
    }).catchError((_) => <String, dynamic>{});
  }

  // ─── Scientific Fertility Confidence Calculator ────────────────────
  int get _estimatedOvulationDay => (_cycleLength - 14).clamp(10, _cycleLength - 10);

  String get _estimatedCyclePhase {
    if (_currentCycleDay <= _periodLength) return 'Menstrual Phase';
    final fertileStart = (_estimatedOvulationDay - 5).clamp(_periodLength + 1, _estimatedOvulationDay);
    if (_currentCycleDay < fertileStart) return 'Follicular Phase';
    if (_currentCycleDay <= _estimatedOvulationDay) return 'Fertile Window';
    return 'Luteal Phase (Two-Week Wait)';
  }

  int? get _estimatedDpo {
    if (_currentCycleDay > _estimatedOvulationDay) {
      return _currentCycleDay - _estimatedOvulationDay;
    }
    return null;
  }

  /// Calculates transparent confidence level from biomarker alignment
  Map<String, dynamic> _computeFertileConfidence() {
    final bool hasBBT = _ttcLoggedBBT != null;
    final bool isPeakLH = _ttcLoggedOPK == 'Peak (Surge)';
    final bool isHighLH = _ttcLoggedOPK == 'High';
    final bool isEggWhite = _ttcLoggedCervicalFluid == 'Egg White (Peak)';
    final bool isWatery = _ttcLoggedCervicalFluid == 'Watery';
    final bool hasSustainedShift = hasBBT && _ttcLoggedBBT! >= 98.0;

    if (hasSustainedShift) {
      return {
        'status': 'POST-OVULATION PATTERN',
        'sub': 'Progesterone thermal shift observed. Fertile window likely closed.',
        'color': const Color(0xFF059669),
        'icon': Icons.check_circle_rounded,
        'signals': ['BBT sustained shift ≥ 98.0°F'],
      };
    } else if (isPeakLH || isEggWhite) {
      return {
        'status': 'STRONG FERTILITY SIGNALS',
        'sub': 'Strong estrogenic fluid or LH surge detected. Peak conception timing.',
        'color': const Color(0xFFE11D48),
        'icon': Icons.local_fire_department_rounded,
        'signals': [
          if (isPeakLH) 'LH Surge Peak',
          if (isEggWhite) 'Egg White Cervical Fluid',
        ],
      };
    } else if (isHighLH || isWatery) {
      return {
        'status': 'LIKELY FERTILE',
        'sub': 'Biomarkers indicate follicular maturation. Approaching peak.',
        'color': const Color(0xFFEA580C),
        'icon': Icons.trending_up_rounded,
        'signals': [
          if (isHighLH) 'High LH Strip',
          if (isWatery) 'Watery Fluid Texture',
        ],
      };
    } else if (_ttcLoggedOPK != null || _ttcLoggedCervicalFluid != null || hasBBT) {
      return {
        'status': 'BUILDING WINDOW',
        'sub': 'Baseline follicular rhythm. Continuing daily observation.',
        'color': const Color(0xFF7C3AED),
        'icon': Icons.spa_rounded,
        'signals': ['Follicular baseline active'],
      };
    } else {
      return {
        'status': 'NOT ENOUGH DATA',
        'sub': 'Log today’s LH strip, cervical fluid, or BBT to uncover your window.',
        'color': const Color(0xFF64748B),
        'icon': Icons.help_outline_rounded,
        'signals': ['No biomarkers logged today'],
      };
    }
  }

  void _openDocsyPrompt(BuildContext context, String prompt) {
    openAskSiaChat(context, prompt);
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
          color: crimsonPrimary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // Quick Docsy Prompt Chip Helper
  Widget _buildQuickDocsyChip(BuildContext context, String text) {
    return InkWell(
      onTap: () => _openDocsyPrompt(context, text),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: surfaceCanvas,
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

  // ════════════════════════════════════════════════════════════════════
  // 01 — EDITORIAL GREETING (Unboxed, 2-Line Cormorant Garamond, Italic Crimson)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildEditorialGreeting(BuildContext context) {
    // Read `name`, a key onboarding never writes, so this always fell through
    // to the literal 'lovely'.
    final String userName = userFirstName(context);

    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning,'
        : (hour < 17 ? 'Good afternoon,' : 'Good evening,');

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
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
              color: crimsonPrimary,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Take today at your own pace. Blushy is right here with you.',
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF7A6B72),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 02 — TODAY WITH DOCSY (Dynamic Real-Time AI Intelligence)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildTodayWithDocsyCard(BuildContext context) {
    final bool isPeak = _ttcLoggedOPK == 'Peak (Surge)' || _ttcLoggedCervicalFluid == 'Egg White (Peak)';
    final bool hasBBTShift = _ttcLoggedBBT != null && _ttcLoggedBBT! >= 98.0;

    final String docsyDisplayThought = hasBBTShift
        ? 'Your sustained temperature shift suggests ovulation has likely passed. Time to rest and settle into your two-week wait.'
        : (isPeak
            ? 'Your biological signals point to peak fertility today. Conception is a shared partnership, not solitary homework.'
            : _dynamicDocsyThought);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildEyebrow('TODAY WITH DOCSY'),
            if (_isLoadingAi)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: crimsonPrimary),
              ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: cardRadius,
            border: Border.all(color: cardBorderColor, width: 1.0),
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
                docsyDisplayThought,
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
                onTap: () => _openDocsyPrompt(
                  context,
                  'Docsy, I\'m on Cycle Day $_currentCycleDay in my $_estimatedCyclePhase. What should we focus on today for our fertility window?',
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'What to focus on today',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: crimsonPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: crimsonPrimary),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: dividerColor),
              const SizedBox(height: 12),
              // Ask Docsy search-style bar
              InkWell(
                onTap: () => _openDocsyPrompt(context, ''),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: surfaceCanvas,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 15, color: Color(0xFF7A6B72)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ask Docsy anything about your fertility signals...',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            color: const Color(0xFF9E8E95),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 13, color: crimsonPrimary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Quick prompt chips (Dynamic from AI)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (_dynamicDocsyActions.isNotEmpty
                        ? _dynamicDocsyActions
                        : [
                            'When is my fertile window?',
                            'How to read LH strips?',
                            'Explain BBT shift',
                            'Can we take a break today?',
                          ])
                    .map((action) => _buildQuickDocsyChip(context, action))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 03 — PERIOD TRACKER (Canonical Stage 2 Reusable Tracker)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildPeriodTrackerCard(BuildContext context) {
    return BlushyPeriodTrackerCard(
      currentCycleDay: _currentCycleDay,
      cycleLength: _cycleLength,
      periodLength: _periodLength,
      hasLoggedPeriod: _hasLoggedPeriod,
      currentPhaseName: _estimatedCyclePhase,
      onTapLogPeriod: () => _openLogPeriodDialog(context),
      onTapInsights: () {
        _openDocsyPrompt(
          context,
          'Docsy, tell me what happens in the body during the $_estimatedCyclePhase and what signs to look out for.',
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 04 — FERTILITY SIGNAL CONFIDENCE & COMPASS
  // ════════════════════════════════════════════════════════════════════
  Widget _buildFertilityCompassCard(BuildContext context) {
    final conf = _computeFertileConfidence();
    final Color confColor = conf['color'] as Color;
    final String status = conf['status'] as String;
    final String sub = conf['sub'] as String;
    final IconData icon = conf['icon'] as IconData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('FERTILE SIGNAL CONFIDENCE'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: cardRadius,
            border: Border.all(color: cardBorderColor, width: 1.0),
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
              // Status Banner with 48px circular icon badge
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: confColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: confColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: confColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon(icon, color: confColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status,
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: confColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: textMain,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // "Why am I seeing this?" Transparency Link
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => _showWhyAmISeeingThisModal(context),
                  child: Text(
                    'Why am I seeing this? →',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: crimsonPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Quick-Log Biomarkers Matrix (Soft & Elegant)
              Text(AppLocalizations.of(context).ttcTodaySBiomarkerLog,
                style: GoogleFonts.manrope(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w800,
                  color: textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // 1. LH Strip
              Row(
                children: [
                  const Icon(Icons.biotech_rounded, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Text(
                    'LH Surge Strip:',
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTtcLogChip('Low / Neg', _ttcLoggedOPK == 'Negative / Low', const Color(0xFF7C3AED), () {
                    setState(() => _ttcLoggedOPK = _ttcLoggedOPK == 'Negative / Low' ? null : 'Negative / Low');
                    _saveDailyTtcLog();
                  }),
                  _buildTtcLogChip('High', _ttcLoggedOPK == 'High', const Color(0xFF7C3AED), () {
                    setState(() => _ttcLoggedOPK = _ttcLoggedOPK == 'High' ? null : 'High');
                    _saveDailyTtcLog();
                  }),
                  _buildTtcLogChip('Peak (Surge)', _ttcLoggedOPK == 'Peak (Surge)', const Color(0xFFE11D48), () {
                    setState(() => _ttcLoggedOPK = _ttcLoggedOPK == 'Peak (Surge)' ? null : 'Peak (Surge)');
                    _saveDailyTtcLog();
                  }),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Cervical Fluid
              Row(
                children: [
                  const Icon(Icons.water_drop_rounded, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Text(
                    'Cervical Fluid:',
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildTtcLogChip('Dry', _ttcLoggedCervicalFluid == 'Dry', const Color(0xFF0284C7), () {
                    setState(() => _ttcLoggedCervicalFluid = _ttcLoggedCervicalFluid == 'Dry' ? null : 'Dry');
                    _saveDailyTtcLog();
                  }),
                  _buildTtcLogChip('Creamy', _ttcLoggedCervicalFluid == 'Creamy', const Color(0xFF0284C7), () {
                    setState(() => _ttcLoggedCervicalFluid = _ttcLoggedCervicalFluid == 'Creamy' ? null : 'Creamy');
                    _saveDailyTtcLog();
                  }),
                  _buildTtcLogChip('Watery', _ttcLoggedCervicalFluid == 'Watery', const Color(0xFF0284C7), () {
                    setState(() => _ttcLoggedCervicalFluid = _ttcLoggedCervicalFluid == 'Watery' ? null : 'Watery');
                    _saveDailyTtcLog();
                  }),
                  _buildTtcLogChip('Egg White (Peak)', _ttcLoggedCervicalFluid == 'Egg White (Peak)', const Color(0xFFE11D48), () {
                    setState(() => _ttcLoggedCervicalFluid = _ttcLoggedCervicalFluid == 'Egg White (Peak)' ? null : 'Egg White (Peak)');
                    _saveDailyTtcLog();
                  }),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Morning BBT
              Row(
                children: [
                  const Icon(Icons.thermostat_rounded, size: 16, color: Color(0xFFEA580C)),
                  const SizedBox(width: 6),
                  Text(
                    'Morning BBT (°F):',
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                  ),
                  const Spacer(),
                  if (_ttcLoggedBBT != null)
                    Text(
                      '${_ttcLoggedBBT!.toStringAsFixed(1)}°F',
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFEA580C)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [97.2, 97.4, 97.7, 98.0, 98.3, 98.6].map((temp) {
                  final isSel = _ttcLoggedBBT == temp;
                  return _buildTtcLogChip('${temp.toStringAsFixed(1)}°', isSel, const Color(0xFFEA580C), () {
                    setState(() => _ttcLoggedBBT = isSel ? null : temp);
                    _saveDailyTtcLog();
                  });
                }).toList(),
              ),
              const SizedBox(height: 12),

              // 4. Intimacy Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, size: 16, color: crimsonPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'Intimacy / Trying:',
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      setState(() => _ttcLoggedIntercourse = !_ttcLoggedIntercourse);
                      _saveDailyTtcLog();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                      decoration: BoxDecoration(
                        color: _ttcLoggedIntercourse ? crimsonPrimary.withValues(alpha: 0.12) : surfaceCanvas,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _ttcLoggedIntercourse ? crimsonPrimary : cardBorderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _ttcLoggedIntercourse ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 13,
                            color: crimsonPrimary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _ttcLoggedIntercourse ? 'Logged ❤️' : '+ Log Today',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: crimsonPrimary,
                            ),
                          ),
                        ],
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

  // ════════════════════════════════════════════════════════════════════
  // 05 — MY FERTILITY PICTURE (Synthesized View: Raw -> Meaning)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildMyFertilityPictureCard(BuildContext context) {
    final bool isPeakLH = _ttcLoggedOPK == 'Peak (Surge)';
    final bool isHighLH = _ttcLoggedOPK == 'High';
    final bool isLowLH = _ttcLoggedOPK == 'Negative / Low';

    final bool isPeakFluid = _ttcLoggedCervicalFluid == 'Egg White (Peak)';
    final bool isWateryFluid = _ttcLoggedCervicalFluid == 'Watery';
    final bool isFertileFluid = isPeakFluid || isWateryFluid;
    final bool hasFluid = _ttcLoggedCervicalFluid != null;

    final bool hasBBTShift = _ttcLoggedBBT != null && _ttcLoggedBBT! >= 98.0;
    final bool hasBBT = _ttcLoggedBBT != null;

    final String synthesisNarrative;
    if (hasBBTShift) {
      synthesisNarrative = 'Your sustained temperature shift suggests ovulation has likely occurred. The luteal window has commenced.';
    } else if (isPeakLH || isPeakFluid) {
      synthesisNarrative = 'Active peak fertile signals detected. Optimal conception timing over the next 24–36 hours.';
    } else if (isHighLH || isWateryFluid) {
      synthesisNarrative = 'Estrogenic signals are building nicely. Follicular maturation is progressing toward your surge.';
    } else if (isLowLH || (_ttcLoggedCervicalFluid == 'Dry' || _ttcLoggedCervicalFluid == 'Creamy')) {
      synthesisNarrative = 'Signals reflect baseline follicular rhythm. Continue gentle daily observation as your fertile window approaches.';
    } else {
      synthesisNarrative = 'Keep logging daily signs to help Blushy synthesize a high-confidence fertility picture.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('MY FERTILITY PICTURE'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: cardRadius,
            border: Border.all(color: cardBorderColor, width: 1.0),
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
                'Raw Signals → Clinical Meaning',
                style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
              ),
              const SizedBox(height: 10),

              // Signal Checklist with 36px circular badges and overflow-safe layout
              _buildSignalCheckRow(
                'LH surge pattern',
                isPeakLH
                    ? 'Peak surge active'
                    : (isHighLH
                        ? 'Elevated (Approaching peak)'
                        : (isLowLH ? 'Baseline (No surge yet)' : 'Pending test')),
                isPeakLH || isHighLH,
                isPeakLH ? const Color(0xFFE11D48) : const Color(0xFF7C3AED),
                Icons.biotech_rounded,
              ),
              const SizedBox(height: 8),
              _buildSignalCheckRow(
                'Cervical fluid texture',
                isPeakFluid
                    ? 'Peak fertile (Egg white)'
                    : (isWateryFluid
                        ? 'Fertile (Watery texture)'
                        : (hasFluid ? 'Non-fertile ($_ttcLoggedCervicalFluid)' : 'Pending check')),
                isFertileFluid,
                const Color(0xFF0284C7),
                Icons.water_drop_rounded,
              ),
              const SizedBox(height: 8),
              _buildSignalCheckRow(
                'Sustained BBT thermal shift',
                hasBBTShift
                    ? 'Biphasic shift confirmed'
                    : (hasBBT ? 'Pre-shift (${_ttcLoggedBBT!.toStringAsFixed(1)}°F)' : 'Pending morning reading'),
                hasBBTShift,
                const Color(0xFF059669),
                Icons.device_thermostat_rounded,
              ),
              const SizedBox(height: 12),

              // Synthesis Narrative
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceCanvas,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Text(
                  synthesisNarrative,
                  style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.4),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openDocsyPrompt(
                  context,
                  'Docsy, explain the relationship between my current LH ($_ttcLoggedOPK), cervical fluid ($_ttcLoggedCervicalFluid), and BBT ($_ttcLoggedBBT). What is our current fertility picture?',
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 14, color: crimsonPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Ask Docsy to explain this picture →',
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: crimsonPrimary),
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

  // ════════════════════════════════════════════════════════════════════
  // 06 — FERTILE WINDOW TIMELINE (Continuum + "Couldn't try today?")
  // ════════════════════════════════════════════════════════════════════
  /// The first and last cycle day of the estimated fertile window.
  ///
  /// Five days before the estimated ovulation day through ovulation itself,
  /// which is the same span `_estimatedCyclePhase` uses to decide whether today
  /// is in the window. Both derive from the cycle length the server returned.
  (int, int) get _fertileWindowDays {
    final ovulation = _estimatedOvulationDay;
    final start = (ovulation - 5).clamp(_periodLength + 1, ovulation);
    return (start, ovulation);
  }

  bool _isFertileCycleDay(int day) {
    final (start, end) = _fertileWindowDays;
    return day >= start && day <= end;
  }

  Widget _buildFertileWindowTimelineCard(BuildContext context) {
    // Nothing is known about this cycle until a period has been logged, and a
    // fertile window drawn from a default cycle length is a guess presented as
    // a finding. Say so instead.
    if (!_hasLoggedPeriod) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: cardRadius,
          border: Border.all(color: cardBorderColor, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeaderWithIcon(
              title: 'FERTILE WINDOW CONTINUUM',
              icon: Icons.timeline_rounded,
              badgeColor: const Color(0xFFE11D48),
            ),
            const SizedBox(height: 12),
            Text(
              'Log the first day of your last period and Blushy can estimate '
              'your fertile window. Until then there is nothing to place you on.',
              style: GoogleFonts.manrope(fontSize: 12, height: 1.45, color: textMuted),
            ),
          ],
        ),
      );
    }

    // Each node is a real cycle day either side of today.
    final today = _currentCycleDay;
    final nodes = <(String, int)>[
      ('Earlier', today - 2),
      ('Yesterday', today - 1),
      ('TODAY', today),
      ('Tomorrow', today + 1),
      ('Later', today + 2),
    ];
    final fertile = [for (final (_, day) in nodes) _isFertileCycleDay(day)];
    final (windowStart, windowEnd) = _fertileWindowDays;
    final todayIsFertile = fertile[2];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderWithIcon(
            title: 'FERTILE WINDOW CONTINUUM',
            icon: Icons.timeline_rounded,
            badgeColor: const Color(0xFFE11D48),
          ),
          const SizedBox(height: 12),
          Text(
            todayIsFertile
                ? 'Your Current Multi-Day Window'
                : 'Your Estimated Window: Day $windowStart to Day $windowEnd',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Today is Cycle Day $today. Estimated from your cycle length, not measured.',
            style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
          ),
          const SizedBox(height: 14),

          // Visual continuum. Each dot is a real cycle day, and a segment is
          // only marked fertile when both days it joins fall in the window.
          Row(
            children: [
              for (var i = 0; i < nodes.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: (fertile[i - 1] && fertile[i]) ? crimsonPrimary : cardBorderColor,
                    ),
                  ),
                _buildContinuumNode(
                  nodes[i].$1,
                  isCurrent: i == 2,
                  isFertile: fertile[i],
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Low-cortisol reassurance. Only while the window is still open --
          // telling someone they have not missed their chance after ovulation
          // has passed is not reassurance, it is wrong.
          if (todayIsFertile)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCCD5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.spa_rounded, size: 16, color: crimsonPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Couldn\'t try today? That\'s completely okay.',
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: crimsonPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sperm can survive for up to 5 days in fertile cervical fluid. You have not missed your opportunity; consistency across the multi-day window is what counts.',
                        style: GoogleFonts.manrope(fontSize: 11, color: textMain, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 07 — SOMETHING CHANGED 🚨 (AI Anomaly Detector)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildSomethingChangedCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderWithIcon(
            title: 'CYCLE VARIATION DETECTOR',
            icon: Icons.change_circle_outlined,
            badgeColor: const Color(0xFFD97706),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).ttcNaturalCycleToCycleRhythm,
                      style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: textMain),
                    ),
                    Text(
                      'Variations of 2–4 days in ovulation timing are biologically normal.',
                      style: GoogleFonts.manrope(fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your biological rhythm is unique. Blushy continuously compares your LH and temperature patterns against your historical baseline to highlight subtle shifts without clinical panic.',
            style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.4),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _openDocsyPrompt(
              context,
              'Docsy, how does normal cycle variation affect my fertile window timing, and how can I distinguish healthy shifts from irregularities?',
            ),
            child: Text(
              'Explore cycle variation with Docsy →',
              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFD97706)),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 08 — TTC DATA QUALITY (Signal Coverage)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildDataQualityCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderWithIcon(
            title: 'DATA QUALITY & SIGNAL COVERAGE',
            icon: Icons.signal_cellular_alt_rounded,
            badgeColor: const Color(0xFF0D9488),
          ),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).ttcHonestSignalCoverage,
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 12),
          _buildCoverageRow('LH Strip Tracking', 4, 5, const Color(0xFF7C3AED)),
          const SizedBox(height: 8),
          _buildCoverageRow('Basal Body Temperature', 3, 5, const Color(0xFFEA580C)),
          const SizedBox(height: 8),
          _buildCoverageRow('Cervical Fluid Observations', 4, 5, const Color(0xFF0284C7)),
          const SizedBox(height: 12),
          Text(
            'Blushy will never fabricate high-confidence predictions on incomplete data. Consistent logging provides true clinical clarity.',
            style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 09 — TOGETHER ❤️ (Partner Coordination Without Chores)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildTogetherPartnerCard(BuildContext context) {
    final decisions = [
      {'id': 'trying_today', 'label': 'Trying today ❤️', 'icon': Icons.favorite_rounded, 'color': crimsonPrimary},
      {'id': 'not_today', 'label': 'Not today', 'icon': Icons.spa_rounded, 'color': const Color(0xFF059669)},
      {'id': 'decide_together', 'label': 'Decide together', 'icon': Icons.people_outline_rounded, 'color': const Color(0xFF7C3AED)},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
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
          _buildSectionHeaderWithIcon(
            title: 'TOGETHER · PARTNER CONNECTION',
            icon: Icons.favorite_rounded,
            badgeColor: crimsonPrimary,
          ),
          const SizedBox(height: 10),
          Text(
            'Keeping You Both in the Loop',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Your fertile window looks active today. Conception is a shared partnership, not solitary homework.',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 14),

          // 3 Choice Tags with icons and Wrap to prevent overflow
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: decisions.map((d) {
              final id = d['id'] as String;
              final label = d['label'] as String;
              final icon = d['icon'] as IconData;
              final color = d['color'] as Color;
              final isSel = _partnerDecision == id;

              return InkWell(
                onTap: () {
                  setState(() => _partnerDecision = isSel ? null : id);
                  _saveDailyTtcLog();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSel ? color.withValues(alpha: 0.12) : surfaceCanvas,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSel ? color : cardBorderColor, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: isSel ? color : textMuted),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                          color: isSel ? color : textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Share Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                const text = 'Hey love, Blushy shows our fertile window may be active today. Zero pressure at all — just keeping you in the loop ❤️';
                Share.share(text, subject: 'Blushy Today Update');
              },
              icon: const Icon(Icons.ios_share_rounded, size: 15, color: crimsonPrimary),
              label: Text(
                'Share Gentle Update with Partner',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: crimsonPrimary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: crimsonPrimary, width: 1.1),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 10 — TODAY, OUTSIDE TTC ("Don't Let TTC Take Over")
  // ════════════════════════════════════════════════════════════════════
  Widget _buildOutsideTtcCard(BuildContext context) {
    final activities = [
      {'id': 'walk', 'title': 'Nature\nWalk', 'icon': Icons.park_outlined, 'color': const Color(0xFF059669)},
      {'id': 'movie', 'title': 'Movie\nNight', 'icon': Icons.movie_filter_outlined, 'color': const Color(0xFF7C3AED)},
      {'id': 'cook', 'title': 'Comfort\nMeal', 'icon': Icons.restaurant_outlined, 'color': const Color(0xFFEA580C)},
      {'id': 'read', 'title': 'Read &\nJournal', 'icon': Icons.auto_stories_outlined, 'color': const Color(0xFF0284C7)},
      {'id': 'bath', 'title': 'Warm\nBath', 'icon': Icons.bathtub_outlined, 'color': const Color(0xFFE11D48)},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
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
          _buildSectionHeaderWithIcon(
            title: 'TODAY, OUTSIDE TTC',
            icon: Icons.spa_outlined,
            badgeColor: const Color(0xFF059669),
          ),
          const SizedBox(height: 10),
          Text(
            'You Are More Than Your Fertility Journey',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Conception doesn\'t define your day. Pick one restorative moment just for you:',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 12,
            runSpacing: 12,
            children: activities.map((act) {
              final String title = act['title'] as String;
              final String id = act['id'] as String;
              final IconData icon = act['icon'] as IconData;
              final Color color = act['color'] as Color;
              final bool isSel = _selectedOutsideActivity == id;

              return InkWell(
                onTap: () {
                  setState(() => _selectedOutsideActivity = isSel ? null : id);
                  _saveDailyTtcLog();
                },
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSel ? color.withValues(alpha: 0.15) : surfaceCanvas,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? color : cardBorderColor,
                          width: isSel ? 1.5 : 1.0,
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: isSel ? color : const Color(0xFF5A4D46),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? color : textMain,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (_selectedOutsideActivity != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceCanvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dedicated to your peace today. Step away whenever you need.',
                      style: GoogleFonts.manrope(fontSize: 11, color: textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 11 — TTC ANXIETY MODE ("I'm Spiralling a Little")
  // ════════════════════════════════════════════════════════════════════
  Widget _buildAnxietyModeCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isAnxietyModeActive ? const Color(0xFFF3E8FF) : cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: _isAnxietyModeActive ? const Color(0xFF7C3AED) : cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderWithIcon(
            title: 'TTC ANXIETY RESET',
            icon: Icons.spa_rounded,
            badgeColor: const Color(0xFF7C3AED),
            trailing: InkWell(
              onTap: () {
                setState(() => _isAnxietyModeActive = !_isAnxietyModeActive);
              },
              child: Text(
                _isAnxietyModeActive ? 'Exit Calm Mode' : 'Activate',
                style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF7C3AED)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isAnxietyModeActive
                ? 'Don\'t Google. Don\'t Symptom-Spot. Let\'s Slow Down.'
                : 'Feeling Overwhelmed or Obsessively Checking?',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 8),
          Text(
            _isAnxietyModeActive
                ? 'Right now, your body is doing what it knows how to do. You cannot think your way into a result today. Breathe in for 4 seconds, hold for 4, and release for 6.'
                : 'Tap below to step into a low-cortisol headspace. Docsy will filter known facts from unknowables and guide you through a calm reset.',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _isAnxietyModeActive = true);
                _openDocsyPrompt(
                  context,
                  'Docsy, I\'m spiralling a little with fertility tracking today. Can you help me distinguish what is known from what cannot be known right now, and help me stop obsessing?',
                );
              },
              icon: const Icon(Icons.spa_rounded, size: 16, color: Colors.white),
              label: Text(
                'I\'m spiralling a little — Calm me down',
                style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 12 — TWO-WEEK WAIT & "DON'T INTERPRET THIS YET"
  // ════════════════════════════════════════════════════════════════════
  Widget _buildTwoWeekWaitCard(BuildContext context) {
    final dpo = _estimatedDpo;
    final String badgeText;
    final String modeTitle;
    final String modeDesc;
    final Color modeColor;
    final String shieldText;

    if (dpo == null) {
      badgeText = 'Pre-Ovulation';
      modeTitle = 'Two-Week Wait (Activates Post-Ovulation)';
      modeDesc = 'You are currently on Cycle Day $_currentCycleDay in your $_estimatedCyclePhase. The Two-Week Wait begins after ovulation occurs (estimated Day $_estimatedOvulationDay). Once confirmed by sustained BBT rise or LH surge, this tracker counts down your DPO timeline.';
      modeColor = const Color(0xFF64748B);
      shieldText = 'Pre-Ovulation Shield: Implantation cannot occur before ovulation. Focus on your fertile window rhythm without early testing stress.';
    } else if (dpo <= 5) {
      badgeText = '$dpo DPO';
      modeTitle = 'Early Wait (Days 1–5)';
      modeDesc = 'Too early to read into symptoms. Progesterone is just beginning to rise naturally from the corpus luteum.';
      modeColor = const Color(0xFF059669);
      shieldText = 'False-Negative Shield: At $dpo DPO, the blastocyst is still traveling the fallopian tube. Testing now yields false negatives. Save your heart and wait.';
    } else if (dpo <= 10) {
      badgeText = '$dpo DPO';
      modeTitle = 'Implantation Phase (Days 6–10)';
      modeDesc = 'Blastocyst implantation typically occurs between Days 8–10 DPO. Natural luteal progesterone mimics pregnancy sensations (tender breasts, mild fatigue, twinges). Symptoms cannot confirm pregnancy yet.';
      modeColor = const Color(0xFFEA580C);
      shieldText = 'False-Negative Shield: Implantation is just completing. hCG takes 48+ hours to reach detectable urine levels. Save your heart and test at 12+ DPO.';
    } else {
      badgeText = '$dpo DPO';
      modeTitle = 'Testing Window (Days 11–14)';
      modeDesc = 'Urine hCG concentrations are approaching reliable detection thresholds for first morning tests (10–25 mIU/mL).';
      modeColor = const Color(0xFF4F46E5);
      shieldText = 'Optimal Timing: If testing at $dpo DPO, use your first morning urine for the highest concentration of hCG.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderWithIcon(
            title: 'TWO-WEEK WAIT GUIDANCE',
            icon: Icons.hourglass_top_rounded,
            badgeColor: modeColor,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: modeColor.withValues(alpha: 0.25)),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w700, color: modeColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            modeTitle,
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 6),
          Text(modeDesc, style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.35)),
          const SizedBox(height: 14),

          // False-Negative Shield Callout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceCanvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, size: 18, color: Color(0xFF4F46E5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    shieldText,
                    style: GoogleFonts.manrope(fontSize: 11, color: textMain, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Symptom Check Chips: Don't Interpret This Yet
          Text(
            'DON\'T INTERPRET THIS YET — SYMPTOM REALITY CHECK',
            style: GoogleFonts.manrope(fontSize: 10.0, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              '“I\'m having cramps”',
              '“Feeling unusually tired”',
              '“Breast tenderness”',
            ].map((q) {
              return InkWell(
                onTap: () => _openDocsyPrompt(
                  context,
                  dpo != null
                      ? 'Docsy, I\'m at $dpo DPO in my two-week wait and noticed $q. Can you give me a medically honest explanation of why luteal progesterone causes this, and remind me why symptom spotting isn\'t reliable right now?'
                      : 'Docsy, I\'m on Cycle Day $_currentCycleDay ($_estimatedCyclePhase) and noticed $q. Can you give me a medically honest explanation of what this symptom indicates at this cycle phase?',
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: crimsonPrimary),
                  ),
                  child: Text(
                    q,
                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: crimsonPrimary),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 13 — PREGNANCY TEST ASSISTANT ("Should I Test?")
  // ════════════════════════════════════════════════════════════════════
  Widget _buildPregnancyTestAssistantCard(BuildContext context) {
    final dpo = _estimatedDpo;
    final bool canTestReliably = dpo != null && dpo >= 12;

    final String explainerText = dpo == null
        ? 'You are currently on Cycle Day $_currentCycleDay (prior to ovulation). Home pregnancy tests detect hCG, which is secreted by trophoblast cells only after an embryo implants (typically 8–10 days post-ovulation). Testing prior to ovulation is biologically incapable of detecting pregnancy.'
        : (canTestReliably
            ? 'You are at $dpo DPO. If you choose to test, use your first morning urine for the highest hCG concentration, or wait for the day of your expected period for peak clinical accuracy.'
            : 'You are currently at $dpo DPO. Testing today carries a high probability of a false negative even if conception occurred, because hCG concentration is still doubling toward test sensitivity.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderWithIcon(
            title: 'PREGNANCY TEST ASSISTANT',
            icon: Icons.science_outlined,
            badgeColor: const Color(0xFF0284C7),
          ),
          const SizedBox(height: 12),
          Text(
            'Should I Test Today?',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 6),
          Text(
            explainerText,
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openDocsyPrompt(
                context,
                dpo == null
                    ? 'Docsy, explain when is the earliest scientifically reliable day for me to take a pregnancy test based on my $_cycleLength-day cycle.'
                    : 'Docsy, I\'m at $dpo DPO. Should I take a pregnancy test today? Explain the physiology of implantation, hCG doubling time, and urine test sensitivity.',
              ),
              icon: const Icon(Icons.help_outline_rounded, size: 15, color: Color(0xFF0284C7)),
              label: Text(
                'Ask Docsy: Should I Test Today?',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF0284C7)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0284C7)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 14 — TTC JOURNEY HEALTH CHECK & DOCTOR PREPARATION
  // ════════════════════════════════════════════════════════════════════
  Widget _buildDoctorPreparationAndJourneyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderWithIcon(
            title: 'FOR YOUR NEXT APPOINTMENT',
            icon: Icons.assignment_ind_outlined,
            badgeColor: const Color(0xFF059669),
          ),
          const SizedBox(height: 12),
          Text(
            'Smart Questions for Your Doctor',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 6),
          Text(
            'Blushy analyzes your longitudinal cycle rhythm to suggest concrete clinical questions for your OB/GYN:',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 12),
          _buildDoctorQuestionItem('“My cycles average $_cycleLength days with LH surges typically around Day ${_estimatedOvulationDay - 1}.”'),
          const SizedBox(height: 6),
          _buildDoctorQuestionItem('“My BBT thermal shift establishes within 24–48 hours of positive LH strips.”'),
          const SizedBox(height: 6),
          _buildDoctorQuestionItem('“My estimated luteal phase is ${_cycleLength - _estimatedOvulationDay} days between ovulation and menses (evaluating luteal sufficiency).”'),
          const SizedBox(height: 14),

          // Clinical Summary Export Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final dateStr = DateTime.now().toIso8601String().substring(0, 10);
                final summary = 'Blushy Clinical Fertility Summary ($dateStr)\n\n'
                    '• Cycle Baseline: $_cycleLength days (Period: $_periodLength days)\n'
                    '• Current Cycle Day: $_currentCycleDay ($_estimatedCyclePhase)\n'
                    '• Estimated Ovulation Window: Day $_estimatedOvulationDay\n'
                    '• Luteal Phase Duration: ${_cycleLength - _estimatedOvulationDay} days\n'
                    '• LH Ovulation Testing: ${_ttcLoggedOPK ?? "Active"}\n'
                    '• Cervical Fluid Observations: ${_ttcLoggedCervicalFluid ?? "Observed"}\n'
                    '• Morning BBT: ${_ttcLoggedBBT != null ? "${_ttcLoggedBBT!.toStringAsFixed(1)}°F" : "Tracked"}\n'
                    '• Intercourse / Insemination: ${_ttcLoggedIntercourse ? "Logged" : "None"}\n\n'
                    'Generated by Blushy for clinical review with OB/GYN or reproductive endocrinologist.';
                Share.share(summary, subject: 'Blushy Clinical Fertility Report');
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Colors.white),
              label: Text(AppLocalizations.of(context).ttcGenerateClinicalReport,
                style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: crimsonPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: dividerColor),
          const SizedBox(height: 16),

          // Emotional Journey Health Check
          Text(
            'HOW ARE YOU DOING WITH ALL OF THIS?',
            style: GoogleFonts.manrope(fontSize: 10.0, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceTag('I\'m okay', _emotionalCheckInStatus == 'okay', () {
                setState(() => _emotionalCheckInStatus = 'okay');
              }),
              _buildChoiceTag('I\'m getting stressed', _emotionalCheckInStatus == 'stressed', () {
                setState(() => _emotionalCheckInStatus = 'stressed');
                _openDocsyPrompt(context, 'Docsy, I\'m feeling stressed by the TTC process. Can you help me find peace today?');
              }),
              _buildChoiceTag('I need a break', _isTtcPaused, () {
                _showPauseTtcDialog(context);
              }),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // MODALS & DIALOGS
  // ════════════════════════════════════════════════════════════════════
  void _openLogPeriodDialog(BuildContext context) {
    DateTime selectedDate = _lastPeriodStartDate ?? DateTime.now();
    String flow = 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 18),
                  Text(AppLocalizations.of(context).ttcLogPeriodDate, style: GoogleFonts.cormorantGaramond(fontSize: 26, fontWeight: FontWeight.w700, color: textMain)),
                  const SizedBox(height: 8),
                  Text(
                    'Be gentle with yourself today. When your cycle restarts, Blushy calibrates your next fertile rhythm smoothly.',
                    style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 18),
                  CalendarDatePicker(
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 120)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    onDateChanged: (val) => setModalState(() => selectedDate = val),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);

                        // What the card showed before, so a refused save can
                        // be put back rather than left looking recorded.
                        final previousDate = _lastPeriodStartDate;
                        final previousHasLogged = _hasLoggedPeriod;
                        final previousDay = _currentCycleDay;

                        setState(() {
                          _lastPeriodStartDate = selectedDate;
                          _hasLoggedPeriod = true;
                          final diff = DateTime.now().difference(selectedDate).inDays;
                          _currentCycleDay = (diff + 1).clamp(1, _cycleLength);
                        });
                        try {
                          BlushyStorage.write('last_period_entry.json', {
                            'periodStartDate': selectedDate.toIso8601String(),
                            'flow': flow,
                            'loggedAt': DateTime.now().toIso8601String(),
                          });
                        } catch (_) {}

                        // `logPeriodEntry` returns null when the write was
                        // refused -- an expired session, a rejected date --
                        // and the result used to be thrown away inside a bare
                        // catch. So the card flipped to "Day N", nothing was
                        // stored, and the next load showed "No period logged
                        // yet" again. Reported as the tracker not rendering
                        // after logging.
                        PeriodEntry? saved;
                        try {
                          saved = await ApiPeriodService()
                              .logPeriodEntry(periodStartDate: selectedDate, flowIntensity: flow);
                        } catch (_) {
                          saved = null;
                        }
                        if (!mounted) return;

                        if (saved == null) {
                          setState(() {
                            _lastPeriodStartDate = previousDate;
                            _hasLoggedPeriod = previousHasLogged;
                            _currentCycleDay = previousDay;
                          });
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'That period could not be saved, so nothing has '
                                'changed. Check you are signed in and try again.',
                              ),
                            ),
                          );
                          return;
                        }

                        _fetchDynamicAiInsights();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crimsonPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Save Period & Reset Rhythm', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
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

  void _showWhyAmISeeingThisModal(BuildContext context) {
    final conf = _computeFertileConfidence();
    final List<String> signals = conf['signals'] as List<String>;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Why Am I Seeing This Confidence Level?', style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: textMain)),
              const SizedBox(height: 12),
              Text(
                'Blushy calculates fertile window confidence by evaluating agreement between biological indicators. Here is what contributed to today’s reading:',
                style: GoogleFonts.manrope(fontSize: 12.5, color: textMuted, height: 1.4),
              ),
              const SizedBox(height: 14),
              ...signals.map((sig) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: crimsonPrimary),
                        const SizedBox(width: 8),
                        Text(sig, style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: textMain)),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              Text(
                'Scientific Note: Blushy intentionally never calculates conception probabilities or percentage chances. We provide transparent indicator agreement so you remain informed without anxiety.',
                style: GoogleFonts.manrope(fontSize: 11, fontStyle: FontStyle.italic, color: textMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPauseTtcDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).ttcPauseFertilityTracking, style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: textMain)),
              const SizedBox(height: 8),
              Text(
                'Taking a break is completely healthy and normal. Your historical timeline stays safe. Choose how you’d like to pause:',
                style: GoogleFonts.manrope(fontSize: 12.5, color: textMuted),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(AppLocalizations.of(context).ttcPauseFor1Week, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700)),
                onTap: () {
                  setState(() => _isTtcPaused = true);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text(AppLocalizations.of(context).ttcPauseUntilNextPeriod, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700)),
                onTap: () {
                  setState(() => _isTtcPaused = true);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ════════════════════════════════════════════════════════════════════
  Widget _buildSectionHeaderWithIcon({
    required String title,
    required IconData icon,
    required Color badgeColor,
    Widget? trailing,
  }) {
    final titleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: badgeColor),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: crimsonPrimary,
              letterSpacing: 1.0,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (trailing == null) {
      return titleWidget;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: titleWidget),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }

  Widget _buildTtcLogChip(String label, bool isSelected, Color activeColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : surfaceCanvas,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : cardBorderColor,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? activeColor : textMain,
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceTag(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? crimsonPrimary.withValues(alpha: 0.12) : surfaceCanvas,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? crimsonPrimary : cardBorderColor, width: 1.0),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? crimsonPrimary : textMain,
          ),
        ),
      ),
    );
  }

  Widget _buildSignalCheckRow(String title, String status, bool isConfirmed, Color color, [IconData? icon]) {
    final IconData effectiveIcon = icon ?? (isConfirmed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceCanvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(effectiveIcon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMain),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  status,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isConfirmed ? color : textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isConfirmed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isConfirmed ? color : const Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }

  /// One day on the fertile-window continuum.
  ///
  /// [isCurrent] marks today, [isFertile] whether that day falls inside the
  /// estimated window. They were previously the same thing, which is how the
  /// bar came to show today as fertile regardless of the cycle.
  Widget _buildContinuumNode(String label, {required bool isCurrent, required bool isFertile}) {
    final colour = isFertile ? crimsonPrimary : const Color(0xFFCBD5E1);
    return Column(
      children: [
        Container(
          width: isCurrent ? 14 : 10,
          height: isCurrent ? 14 : 10,
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 9.5,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
            color: isFertile ? crimsonPrimary : textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildCoverageRow(String title, int filled, int total, Color color) {
    return Row(
      children: [
        Expanded(child: Text(title, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: textMain))),
        Row(
          children: List.generate(total, (idx) {
            final isFilled = idx < filled;
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isFilled ? color : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDoctorQuestionItem(String question) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: crimsonPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(question, style: GoogleFonts.manrope(fontSize: 12, color: textMain, fontStyle: FontStyle.italic)),
        ),
      ],
    );
  }

  List<Widget> _buildDashboardCards(BuildContext context) {
    return [
      // 01. Editorial Greeting
      _buildEditorialGreeting(context),
      const SizedBox(height: 18),

      // 02. Period / Cycle Rhythm Tracker -- kept at the top, right after the
      // greeting, so the cycle is the first thing she sees.
      _buildPeriodTrackerCard(context),
      const SizedBox(height: 18),

      // 03. Today with Docsy
      _buildTodayWithDocsyCard(context),
      const SizedBox(height: 18),

      // Says which kind of nothing this is before the card asserts one.
      StageStateNotice(
        state: _cycleState,
        hasData: _hasLoggedPeriod,
        emptyMessage:
            'Log the first day of your last period and this page starts '
            'working from your own cycle instead of general guidance.',
        onRetry: _rehydrateTtcState,
      ),
      const SizedBox(height: 22),
      const LogSymptomsSection(stageKey: 'tryingtoconceive'),
      const SizedBox(height: 18),
      const HealthLibrarySection(stageKey: 'tryingtoconceive'),
      const SizedBox(height: 18),
      const TtcFertilitySection(),
      const SizedBox(height: 20),
      const TtcOvulationSection(),
      const SizedBox(height: 20),
      const TtcSexToConceiveSection(),
      const SizedBox(height: 18),

      // 04. Fertility Signal Confidence & Compass
      _buildFertilityCompassCard(context),
      const SizedBox(height: 18),

      // 05. My Fertility Picture (BBT, OPK, Cervical Fluid, Intimacy)
      _buildMyFertilityPictureCard(context),
      const SizedBox(height: 18),

      // 06. Fertile Window Timeline
      _buildFertileWindowTimelineCard(context),
      const SizedBox(height: 18),

      // 07. Something Changed (Anomaly Detector)
      _buildSomethingChangedCard(context),
      const SizedBox(height: 18),

      // 08. TTC Data Quality
      _buildDataQualityCard(context),
      const SizedBox(height: 18),

      // 09. Together (Partner Connection)
      _buildTogetherPartnerCard(context),
      const SizedBox(height: 18),

      // 10. Today, Outside TTC
      _buildOutsideTtcCard(context),
      const SizedBox(height: 18),

      // 11. TTC Anxiety Mode
      _buildAnxietyModeCard(context),
      const SizedBox(height: 18),

      // 12. Two-Week Wait Guidance
      _buildTwoWeekWaitCard(context),
      const SizedBox(height: 18),

      // 13. Pregnancy Test Assistant
      _buildPregnancyTestAssistantCard(context),
      const SizedBox(height: 18),

      // 14. Doctor Preparation & Journey Health Check
      _buildDoctorPreparationAndJourneyCard(context),
      const SizedBox(height: 36),
    ];
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD ROOT & RESPONSIVE LAYOUT
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return wrapStageDashboardLayout(
      context: context,
      scaffoldKey: _scaffoldKey,
      isNested: widget.isNested,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          final cards = _buildDashboardCards(context);

          if (width < 768) {
            // ─── MOBILE VIEWPORT ──────────────────────────────────────────
            return ListView(
              controller: _effectiveScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: cards,
            );
          } else {
            // ─── TABLET / DESKTOP VIEWPORT (Centered Single Feed) ─────────
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  controller: _effectiveScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  children: cards,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
