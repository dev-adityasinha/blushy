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
import 'trying_to_conceive_sections.dart';
import '../../../../l10n/app_localizations.dart';

/// 5-Phase Dynamic Conception Model for TTC
enum TtcPhase {
  menstrualReset, // Days 1 to periodLength (usually Days 1-5)
  fertileApproach, // Day 6 up to ovulation
  ovulationPeak, // LH Surge or Egg White or Ovulation Day
  twoWeekWait, // Post-ovulation: 1 DPO to 13 DPO
  extendedLuteal, // 14+ DPO without period
}

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
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(18));

  // ─── Biometrics & Daily Logging State ──────────────────────────────
  double? _ttcLoggedBBT;
  String? _ttcLoggedOPK; // 'Negative / Low', 'High', 'Peak (Surge)'
  String? _ttcLoggedCervicalFluid; // 'Dry', 'Creamy', 'Watery', 'Egg White (Peak)'
  bool _ttcLoggedIntercourse = false;
  String? _partnerDecision; // 'trying_today', 'not_today', 'decide_together'
  String? _selectedOutsideActivity;
  final Set<String> _selectedSupplements = <String>{};

  // ─── Cycle & Rhythm State ──────────────────────────────────────────
  int _currentCycleDay = 14;
  int _cycleLength = 29;
  int _periodLength = 5;
  DateTime? _lastPeriodStartDate;
  bool _hasLoggedPeriod = false;

  /// How the cycle read went, so "nothing logged" and "could not load" stop
  /// looking identical.
  ApiState _cycleState = ApiState.loading;

  /// The cycle-loading concern lives in a tested view model; this widget is
  /// its View. The fields above are kept as local mirrors so the rest of the
  /// screen reads unchanged, and are refreshed from the view model on change.
  final CycleViewModel _cycleVM = CycleViewModel(defaultCycleLength: 29, defaultCycleDay: 14);

  // ─── Real-Time Dynamic AI & Docsy State ─────────────────────────────
  bool _isLoadingAi = false;
  String _dynamicDocsyThought =
      'Your biological signals suggest the fertile window may be open. You don’t need to keep checking everything today; sperm viability spans several days in fertile fluid, so take things at an unhurried, collaborative pace.';
  String _dynamicDocsyNote = 'Low-cortisol evenings and unpressured connection support both hormonal balance and nervous system ease.';

  // ─── Emotional & Journey State ─────────────────────────────────────
  bool _isAnxietyModeActive = false;

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
        if (checkin['ttc_supplements'] is List) {
          _selectedSupplements.addAll(
            (checkin['ttc_supplements'] as List).map((e) => e.toString()),
          );
        }
      }
    } catch (_) {}

    _cycleVM.load();
  }

  Future<void> _fetchDynamicAiInsights() async {
    if (_isLoadingAi) return;
    setState(() => _isLoadingAi = true);
    try {
      final String phase = _estimatedCyclePhase;
      final result = await ApiSiaService().getHealthInsights(
        stage: 'ttc',
        cycleDay: _currentCycleDay,
        phase: phase,
      );

      if (mounted && result.isNotEmpty) {
        setState(() {
          _dynamicDocsyThought = result['thought'] ?? result['narrative'] ?? result['summary'] ?? _dynamicDocsyThought;
          _dynamicDocsyNote = result['note'] ?? result['oneThingToKeepInMind'] ?? _dynamicDocsyNote;
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
    checkin['ttc_supplements'] = _selectedSupplements.toList();
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
      'ttc_supplements': _selectedSupplements.toList(),
    }).catchError((_) => <String, dynamic>{});
  }

  // ─── 5-Phase Dynamic Model Helpers ─────────────────────────────────
  int get _estimatedOvulationDay => (_cycleLength - 14).clamp(10, _cycleLength - 10);

  int? get _estimatedDpo {
    if (_currentCycleDay > _estimatedOvulationDay) {
      return _currentCycleDay - _estimatedOvulationDay;
    }
    return null;
  }

  TtcPhase get _currentTtcPhase {
    if (!_hasLoggedPeriod) return TtcPhase.fertileApproach;
    if (_currentCycleDay <= _periodLength) return TtcPhase.menstrualReset;
    if (_currentCycleDay < _estimatedOvulationDay) {
      if (_ttcLoggedOPK == 'Peak (Surge)' || _ttcLoggedCervicalFluid == 'Egg White (Peak)') {
        return TtcPhase.ovulationPeak;
      }
      return TtcPhase.fertileApproach;
    }
    if (_currentCycleDay == _estimatedOvulationDay) {
      return TtcPhase.ovulationPeak;
    }
    final dpo = _estimatedDpo ?? 0;
    if (dpo >= 14 || _currentCycleDay > _cycleLength) {
      return TtcPhase.extendedLuteal;
    }
    return TtcPhase.twoWeekWait;
  }

  String get _estimatedCyclePhase {
    if (!_hasLoggedPeriod) return 'Follicular Rhythm';
    switch (_currentTtcPhase) {
      case TtcPhase.menstrualReset:
        return 'Menstrual Reset';
      case TtcPhase.fertileApproach:
        return 'Fertile Approach';
      case TtcPhase.ovulationPeak:
        return 'Peak Fertile Window';
      case TtcPhase.twoWeekWait:
        final dpo = _estimatedDpo ?? 1;
        return '$dpo DPO • Two-Week Wait';
      case TtcPhase.extendedLuteal:
        final dpo = _estimatedDpo ?? 14;
        return '$dpo DPO • Extended Luteal Pattern';
    }
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
        'sub': 'Progesterone thermal shift observed. Fertile window closed.',
        'color': const Color(0xFF059669),
        'icon': Icons.check_circle_rounded,
        'signals': ['BBT sustained shift ≥ 98.0°F'],
      };
    } else if (isPeakLH || isEggWhite) {
      return {
        'status': 'PEAK FERTILE WINDOW OPEN',
        'sub': 'LH surge or peak fluid detected. Optimal conception in next 24–36 hrs.',
        'color': const Color(0xFFE11D48),
        'icon': Icons.local_fire_department_rounded,
        'signals': [
          if (isPeakLH) 'LH Surge Peak',
          if (isEggWhite) 'Egg White Cervical Fluid',
        ],
      };
    } else if (isHighLH || isWatery) {
      return {
        'status': 'LIKELY FERTILE (APPROACHING PEAK)',
        'sub': 'Biomarkers show follicular maturation. Fertile window is open.',
        'color': const Color(0xFFEA580C),
        'icon': Icons.trending_up_rounded,
        'signals': [
          if (isHighLH) 'High LH Strip',
          if (isWatery) 'Watery Fluid Texture',
        ],
      };
    } else if (_ttcLoggedOPK != null || _ttcLoggedCervicalFluid != null || hasBBT) {
      return {
        'status': 'BASELINE FOLLICULAR RHYTHM',
        'sub': 'Continuing daily observation as your fertile window approaches.',
        'color': const Color(0xFF7C3AED),
        'icon': Icons.spa_rounded,
        'signals': ['Follicular baseline active'],
      };
    } else {
      return {
        'status': 'AWAITING TODAY\'S SIGNALS',
        'sub': 'Quick-log your LH strip, cervical fluid, or BBT below.',
        'color': const Color(0xFF64748B),
        'icon': Icons.help_outline_rounded,
        'signals': ['No biomarkers logged today'],
      };
    }
  }

  int get _loggedSignalsCount {
    int count = 0;
    if (_ttcLoggedOPK != null) count++;
    if (_ttcLoggedCervicalFluid != null) count++;
    if (_ttcLoggedBBT != null) count++;
    if (_ttcLoggedIntercourse || _partnerDecision != null) count++;
    return count;
  }

  void _openDocsyPrompt(BuildContext context, String prompt) {
    openAskSiaChat(context, prompt);
  }

  // Consistent Crimson Eyebrow
  Widget _buildEyebrow(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
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

  // ════════════════════════════════════════════════════════════════════
  // 01 — EDITORIAL GREETING (Unboxed, Cormorant Garamond, Italic Crimson)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildEditorialGreeting(BuildContext context) {
    final String userName = userFirstName(context);
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning,'
        : (hour < 17 ? 'Good afternoon,' : 'Good evening,');

    final String subGreeting;
    if (!_hasLoggedPeriod) {
      subGreeting = 'Log your last period below to activate your personalized conception rhythm.';
    } else {
      switch (_currentTtcPhase) {
        case TtcPhase.menstrualReset:
          subGreeting = 'Day $_currentCycleDay • Menstrual reset. A new cycle brings a fresh biological opportunity—take gentle care today.';
          break;
        case TtcPhase.fertileApproach:
          subGreeting = 'Day $_currentCycleDay • Follicular approach. Estrogen is building—keep an unhurried, low-stress rhythm.';
          break;
        case TtcPhase.ovulationPeak:
          subGreeting = 'Day $_currentCycleDay • Peak fertile window is open. Optimal conception timing over the next 24–36 hours.';
          break;
        case TtcPhase.twoWeekWait:
          final dpo = _estimatedDpo ?? 1;
          subGreeting = '$dpo DPO • Two-week wait. Be gentle with your body and mind; implantation is quiet, invisible work.';
          break;
        case TtcPhase.extendedLuteal:
          final dpo = _estimatedDpo ?? 14;
          subGreeting = '$dpo DPO • Extended luteal pattern. We\'re right beside you with compassionate clinical clarity.';
          break;
      }
    }

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
            subGreeting,
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
  // 02 — HERO PERIOD / CYCLE RHYTHM TRACKER (Phase-Adaptive)
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
          'Docsy, I\'m in the $_estimatedCyclePhase of my cycle. What biological signs should I be mindful of today?',
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 03 — UNIFIED DAILY FERTILITY BIOMARKERS HUB (MERGE #1)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildDailyFertilitySignalsHub(BuildContext context) {
    final conf = _computeFertileConfidence();
    final Color confColor = conf['color'] as Color;
    final String status = conf['status'] as String;
    final String sub = conf['sub'] as String;
    final IconData icon = conf['icon'] as IconData;
    final int filledSignals = _loggedSignalsCount;

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
          // Header with Section Icon & Signal Coverage Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeaderWithIcon(
                title: 'TODAY\'S FERTILITY SIGNALS',
                icon: Icons.biotech_rounded,
                badgeColor: const Color(0xFF7C3AED),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: filledSignals >= 3 ? const Color(0xFFCCFBF1) : surfaceCanvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: filledSignals >= 3 ? const Color(0xFF0D9488) : cardBorderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filledSignals >= 3 ? Icons.check_circle_rounded : Icons.radar_rounded,
                      size: 11,
                      color: filledSignals >= 3 ? const Color(0xFF0D9488) : textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$filledSignals/4 Tracked',
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: filledSignals >= 3 ? const Color(0xFF0D9488) : textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. LH Strip
          Row(
            children: [
              const Icon(Icons.biotech_rounded, size: 16, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text(
                'LH Surge Strip (OPK):',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showOpkGalleryModal(context),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera_outlined, size: 13, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 4),
                    Text(
                      'Strip Gallery',
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTtcLogChip('Low (0.2)', _ttcLoggedOPK == 'Negative / Low', const Color(0xFF7C3AED), () {
                setState(() => _ttcLoggedOPK = _ttcLoggedOPK == 'Negative / Low' ? null : 'Negative / Low');
                _saveDailyTtcLog();
              }),
              _buildTtcLogChip('High (0.6)', _ttcLoggedOPK == 'High', const Color(0xFFEA580C), () {
                setState(() => _ttcLoggedOPK = _ttcLoggedOPK == 'High' ? null : 'High');
                _saveDailyTtcLog();
              }),
              _buildTtcLogChip('Peak Surge (1.4+)', _ttcLoggedOPK == 'Peak (Surge)', crimsonPrimary, () {
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
                'Cervical Fluid Texture:',
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
              _buildTtcLogChip('Egg White (Peak)', _ttcLoggedCervicalFluid == 'Egg White (Peak)', crimsonPrimary, () {
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
              InkWell(
                onTap: () => _showBbtCurveModal(context),
                child: Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, size: 13, color: Color(0xFFEA580C)),
                    const SizedBox(width: 4),
                    Text(
                      'Biphasic Curve',
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFEA580C)),
                    ),
                  ],
                ),
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

          // 4. Intimacy & Trying Today (Consolidated Single Row)
          Row(
            children: [
              const Icon(Icons.favorite_rounded, size: 16, color: crimsonPrimary),
              const SizedBox(width: 6),
              Text(
                'Intimacy & Timing:',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTtcLogChip('Trying today ❤️', _partnerDecision == 'trying_today', crimsonPrimary, () {
                setState(() {
                  _partnerDecision = _partnerDecision == 'trying_today' ? null : 'trying_today';
                  _ttcLoggedIntercourse = _partnerDecision == 'trying_today';
                });
                _saveDailyTtcLog();
              }),
              _buildTtcLogChip('Not today 🌿', _partnerDecision == 'not_today', const Color(0xFF059669), () {
                setState(() {
                  _partnerDecision = _partnerDecision == 'not_today' ? null : 'not_today';
                  _ttcLoggedIntercourse = false;
                });
                _saveDailyTtcLog();
              }),
              _buildTtcLogChip('Decide together 🤝', _partnerDecision == 'decide_together', const Color(0xFF7C3AED), () {
                setState(() {
                  _partnerDecision = _partnerDecision == 'decide_together' ? null : 'decide_together';
                });
                _saveDailyTtcLog();
              }),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Fertility Protocols & Supplements (Feature 3 from PRD)
          Row(
            children: [
              const Icon(Icons.medication_outlined, size: 16, color: Color(0xFF0D9488)),
              const SizedBox(width: 6),
              Text(
                'Protocol & Supplements:',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              'Prenatal + Folate',
              'CoQ10',
              'Inositol',
              'Vitamin D',
              'Letrozole / Clomid',
            ].map((sup) {
              final isSel = _selectedSupplements.contains(sup);
              return _buildTtcLogChip(sup, isSel, const Color(0xFF0D9488), () {
                setState(() {
                  if (isSel) {
                    _selectedSupplements.remove(sup);
                  } else {
                    _selectedSupplements.add(sup);
                  }
                });
                _saveDailyTtcLog();
              });
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Reactive Clinical Interpretation Banner (Auto-updates with immediate meaning)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: confColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: confColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: confColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: confColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: confColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
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
          const SizedBox(height: 8),

          // Transparency Link
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => _showWhyAmISeeingThisModal(context),
              child: Text(
                'Why am I seeing this? →',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: crimsonPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 04A — PHASE 1: MENSTRUAL RESET CARD (Days 1–5)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildMenstrualResetCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderWithIcon(
            title: 'CYCLE DAY $_currentCycleDay · GENTLE RESET',
            icon: Icons.spa_outlined,
            badgeColor: const Color(0xFF059669),
          ),
          const SizedBox(height: 10),
          Text(
            'Zero Pressure. A Fresh Biological Opportunity.',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Menstruation marks the start of follicular recruitment. Your ovaries are already gently nurturing a new cohort of follicles. No ovulation testing needed right now.',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniResetPill(Icons.local_cafe_outlined, 'Warming Foods', const Color(0xFFEA580C)),
              const SizedBox(width: 8),
              _buildMiniResetPill(Icons.nightlight_outlined, 'Early Sleep', const Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              _buildMiniResetPill(Icons.favorite_border_rounded, 'Gentle Pacing', crimsonPrimary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniResetPill(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 04B — PHASE 2 & 3: FERTILE WINDOW & MALE FACTOR ("The Other 50%")
  // ════════════════════════════════════════════════════════════════════
  Widget _buildFertileWindowAndMaleFactorCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderWithIcon(
            title: 'FERTILE WINDOW TIMING & PARTNER SYNC',
            icon: Icons.favorite_rounded,
            badgeColor: crimsonPrimary,
          ),
          const SizedBox(height: 10),
          Text(
            'Conception is a Shared Biological Partnership',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Sperm can survive up to 5 days in fertile cervical fluid, while the egg is viable for 12–24 hours post-ovulation. Having intercourse every 24–48 hours across this window provides optimal fertilization chances.',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),

          // Male Factor Insights ("The Other 50%" - Feature 4 from PRD)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceCanvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Text(
                      'Partner Guidance · Male Factor Science',
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0284C7)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '• Scrotal Heat Warning: Avoid hot tubs, saunas, heated seats, and laptops directly on the lap (heat degrades sperm motility).\n'
                  '• Optimal Cadence: Intercourse every 24–48 hours is clinically superior to "saving it up", which increases sperm DNA fragmentation.',
                  style: GoogleFonts.manrope(fontSize: 11, color: textMain, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Share Gentle Update Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                const text = 'Hey love, Blushy shows our fertile window is active today. Zero pressure at all — just keeping you in the loop ❤️';
                Share.share(text, subject: 'Blushy Today Update');
              },
              icon: const Icon(Icons.ios_share_rounded, size: 15, color: crimsonPrimary),
              label: Text(
                'Share Gentle Update with Partner',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: crimsonPrimary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: crimsonPrimary, width: 1.1),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 04C — PHASE 4 & 5: POST-OVULATION & TESTING GUIDE (MERGE #3: TWW + Assistant)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildPostOvulationAndTestingGuide(BuildContext context) {
    final dpo = _estimatedDpo ?? 1;
    final String shieldTitle;
    final String shieldDesc;
    final Color shieldColor;
    final IconData shieldIcon;
    final bool isTestingUnlocked = dpo >= 12;

    if (dpo <= 7) {
      shieldTitle = 'Testing Locked · Implantation Inactive (1–7 DPO)';
      shieldDesc = 'At $dpo DPO, the blastocyst is still traveling the fallopian tube. Embryo implantation has not occurred yet. Testing now yields false negatives. Any twinges are natural luteal progesterone.';
      shieldColor = const Color(0xFF64748B);
      shieldIcon = Icons.lock_outline_rounded;
    } else if (dpo <= 10) {
      shieldTitle = 'Possible Implantation Window (8–10 DPO)';
      shieldDesc = 'Blastocyst implantation typically occurs between 8–10 DPO. Early testing carries an 85% false-negative rate because hCG takes 48+ hours to reach detectable urine levels. Save your heart and wait.';
      shieldColor = const Color(0xFFEA580C);
      shieldIcon = Icons.hourglass_top_rounded;
    } else if (dpo <= 13) {
      shieldTitle = 'Early Detection Window (11–13 DPO)';
      shieldDesc = 'hCG levels begin approaching reliable detection thresholds for early-response tests. Use your first morning urine for peak clinical accuracy.';
      shieldColor = const Color(0xFF0284C7);
      shieldIcon = Icons.science_outlined;
    } else {
      shieldTitle = 'Extended Luteal Pattern (14+ DPO)';
      shieldDesc = 'If your period hasn\'t arrived, take a first-morning pregnancy test. If negative and BBT was sustained, menses typically arrives in 24–48 hours.';
      shieldColor = const Color(0xFF059669);
      shieldIcon = Icons.event_available_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderWithIcon(
            title: 'TWO-WEEK WAIT & TESTING SHIELD',
            icon: Icons.hourglass_bottom_rounded,
            badgeColor: shieldColor,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: shieldColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$dpo DPO',
                style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: shieldColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isTestingUnlocked ? 'Clinical Testing Window Open' : 'Protecting Your Mental Wellbeing',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 10),

          // Testing Shield Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: shieldColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: shieldColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(shieldIcon, size: 18, color: shieldColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shieldTitle,
                        style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800, color: shieldColor),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        shieldDesc,
                        style: GoogleFonts.manrope(fontSize: 11, color: textMain, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Symptom Reality Check Chips ("Don't Interpret This Yet")
          Text(
            'DON\'T INTERPRET THIS YET · SYMPTOM REALITY CHECK',
            style: GoogleFonts.manrope(fontSize: 10.0, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
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
                  'Docsy, I\'m at $dpo DPO in my two-week wait and noticed $q. Can you give me a medically honest explanation of why luteal progesterone causes this, and remind me why symptom spotting isn\'t reliable right now?',
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.help_outline_rounded, size: 12, color: textMuted),
                      const SizedBox(width: 4),
                      Text(
                        q,
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: textMain),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          if (dpo >= 14)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _openDocsyPrompt(
                    context,
                    'Docsy, I got a positive pregnancy test at $dpo DPO! How should I calculate my gestational age and what are my next clinical steps?',
                  );
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: Colors.white),
                label: Text(
                  '➕ Log Positive Pregnancy Test',
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 04D — FERTILE WINDOW CONTINUUM (Timeline & Empty State)
  // ════════════════════════════════════════════════════════════════════
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
    if (!_hasLoggedPeriod) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
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
              badgeColor: crimsonPrimary,
            ),
            const SizedBox(height: 10),
            Text(
              'Log the first day of your last period and Blushy can estimate '
              'your fertile window. Until then there is nothing to place you on.',
              style: GoogleFonts.manrope(fontSize: 12, height: 1.45, color: textMuted),
            ),
          ],
        ),
      );
    }

    final today = _currentCycleDay;
    final nodes = <(String, int)>[
      ('Earlier', today - 2),
      ('Yesterday', today - 1),
      ('TODAY', today),
      ('Tomorrow', today + 1),
      ('Later', today + 2),
    ];
    final (windowStart, windowEnd) = _fertileWindowDays;
    final todayIsFertile = _isFertileCycleDay(today);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
            badgeColor: crimsonPrimary,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: todayIsFertile ? crimsonPrimary.withValues(alpha: 0.1) : surfaceCanvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: todayIsFertile ? crimsonPrimary : cardBorderColor),
              ),
              child: Text(
                todayIsFertile ? 'Window Active' : 'Outside Window',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: todayIsFertile ? crimsonPrimary : textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            todayIsFertile ? 'Your Current Multi-Day Window' : 'Estimated Cycle Continuum',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            todayIsFertile
                ? 'Sperm can survive up to 5 days in fertile fluid. Every day in this window offers conception opportunity.'
                : 'Estimated window runs from Day $windowStart to Day $windowEnd.',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: nodes.map((node) {
              final isToday = node.$1 == 'TODAY';
              final isFertile = _isFertileCycleDay(node.$2);
              return _buildContinuumNode(
                node.$1,
                dayNumber: node.$2,
                isCurrent: isToday,
                isFertile: isFertile,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContinuumNode(String label, {required int dayNumber, required bool isCurrent, required bool isFertile}) {
    final Color color = isFertile ? crimsonPrimary : const Color(0xFF64748B);
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 9.5,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
            color: isCurrent ? crimsonPrimary : textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCurrent ? color : (isFertile ? color.withValues(alpha: 0.12) : surfaceCanvas),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isCurrent ? 2.0 : 1.0),
          ),
          child: Center(
            child: Text(
              'D$dayNumber',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isCurrent ? Colors.white : color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 06 — MINDSET & DE-STRESS HUB (MERGE #2: Outside TTC + Anxiety Reset)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildMindsetAndDeStressCard(BuildContext context) {
    final activities = [
      {'id': 'walk', 'title': 'Nature Walk', 'icon': Icons.park_outlined, 'color': const Color(0xFF059669)},
      {'id': 'movie', 'title': 'Movie Night', 'icon': Icons.movie_filter_outlined, 'color': const Color(0xFF7C3AED)},
      {'id': 'cook', 'title': 'Comfort Meal', 'icon': Icons.restaurant_outlined, 'color': const Color(0xFFEA580C)},
      {'id': 'read', 'title': 'Journaling', 'icon': Icons.auto_stories_outlined, 'color': const Color(0xFF0284C7)},
      {'id': 'bath', 'title': 'Warm Bath', 'icon': Icons.bathtub_outlined, 'color': crimsonPrimary},
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
            title: 'MINDSET & LOW-CORTISOL SPACE',
            icon: Icons.spa_rounded,
            badgeColor: const Color(0xFF7C3AED),
            trailing: _isAnxietyModeActive
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Calm Mode Active',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  )
                : null,
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
          const SizedBox(height: 10),

          // 5 Restorative Activities
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activities.map((act) {
              final id = act['id'] as String;
              final title = act['title'] as String;
              final icon = act['icon'] as IconData;
              final color = act['color'] as Color;
              final isSel = _selectedOutsideActivity == id;

              return InkWell(
                onTap: () {
                  setState(() => _selectedOutsideActivity = isSel ? null : id);
                  _saveDailyTtcLog();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSel ? color.withValues(alpha: 0.12) : surfaceCanvas,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? color : cardBorderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: isSel ? color : textMuted),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
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

          // Anxiety Reset Button ("I'm spiralling a little — Calm me down")
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
  // 07 — CLINICAL CARE & DOCTOR PREPARATION
  // ════════════════════════════════════════════════════════════════════
  Widget _buildDoctorPreparationAndJourneyCard(BuildContext context) {
    final lutealDays = _cycleLength - _estimatedOvulationDay;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 10),
          Text(
            'Smart Questions for Your Doctor',
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Blushy analyzes your longitudinal rhythm to suggest clinical questions for your OB/GYN:',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 10),
          _buildDoctorQuestionItem('“My cycles average $_cycleLength days with LH surges typically around Day ${_estimatedOvulationDay - 1}.”'),
          const SizedBox(height: 6),
          _buildDoctorQuestionItem('“My BBT thermal shift establishes within 24–48 hours of positive LH strips.”'),
          const SizedBox(height: 6),
          _buildDoctorQuestionItem('“My estimated luteal phase is $lutealDays days between ovulation and menses (evaluating luteal sufficiency).”'),
          const SizedBox(height: 12),

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
                    '• Luteal Phase Duration: $lutealDays days\n'
                    '• LH Ovulation Testing: ${_ttcLoggedOPK ?? "Active"}\n'
                    '• Cervical Fluid Observations: ${_ttcLoggedCervicalFluid ?? "Observed"}\n'
                    '• Morning BBT: ${_ttcLoggedBBT != null ? "${_ttcLoggedBBT!.toStringAsFixed(1)}°F" : "Tracked"}\n'
                    '• Intercourse / Insemination: ${_ttcLoggedIntercourse ? "Logged" : "None"}\n\n'
                    'Generated by Blushy for clinical review with OB/GYN or reproductive endocrinologist.';
                Share.share(summary, subject: 'Blushy Clinical Fertility Report');
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Colors.white),
              label: Text(
                AppLocalizations.of(context).ttcGenerateClinicalReport,
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: crimsonPrimary,
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
  // MODALS & INTERACTIVE FEATURES (PRD FEATURES 1 & 2)
  // ════════════════════════════════════════════════════════════════════

  /// Feature 1: OPK Photo Scanner & Progression Gallery
  void _showOpkGalleryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
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
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'OPK Strip Progression Gallery',
                    style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: textMain),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Visual chronological strip darkening to pinpoint your exact LH surge without second-guessing faint lines.',
                style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Mock Progression Gallery Cards
              _buildOpkGalleryItem(day: 10, ratio: '0.2', status: 'Low', isPeak: false, color: const Color(0xFF7C3AED)),
              const SizedBox(height: 8),
              _buildOpkGalleryItem(day: 12, ratio: '0.6', status: 'High', isPeak: false, color: const Color(0xFFEA580C)),
              const SizedBox(height: 8),
              _buildOpkGalleryItem(day: 14, ratio: '1.4', status: 'Peak Surge! 🟢', isPeak: true, color: crimsonPrimary),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _ttcLoggedOPK = 'Peak (Surge)');
                    _saveDailyTtcLog();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Simulated OPK Strip logged: Peak Surge (1.4 ratio)!')),
                    );
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                  label: Text(
                    '📷 Snap / Log New Test Strip Photo',
                    style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crimsonPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOpkGalleryItem({required int day, required String ratio, required String status, required bool isPeak, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceCanvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPeak ? color : cardBorderColor, width: isPeak ? 1.5 : 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cardBorderColor),
            ),
            child: Text(
              'Day $day',
              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: textMain),
            ),
          ),
          const SizedBox(width: 12),
          // Strip Graphic representation
          Container(
            width: 80,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8E8),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Control line
                Container(width: 3, height: 12, color: crimsonPrimary),
                // Test line (varying opacity)
                Container(
                  width: 3,
                  height: 12,
                  color: isPeak ? crimsonPrimary : (status == 'High' ? const Color(0xFFEA580C) : const Color(0xFFFCA5A5)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ratio: $ratio · $status',
                  style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
                ),
                Text(
                  isPeak ? 'Test line darker than control' : (status == 'High' ? 'Test line darkening' : 'Faint test line'),
                  style: GoogleFonts.manrope(fontSize: 10, color: textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Feature 2: Interactive BBT Biphasic Curve Graph
  void _showBbtCurveModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
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
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BBT Biphasic Temperature Curve',
                    style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: textMain),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'A single temperature reading has no clinical meaning—the sustained thermal shift of +0.4°F–1.0°F confirms ovulation.',
                style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Visual Simulated Chart
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceCanvas,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Follicular Phase: 97.2°–97.5°F', style: GoogleFonts.manrope(fontSize: 10, color: textMuted)),
                        Text('Luteal Shift: 98.2°–98.6°F', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Visual step graph
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBbtBar(height: 30, temp: '97.3°', day: 'D10', isShift: false),
                        _buildBbtBar(height: 28, temp: '97.2°', day: 'D12', isShift: false),
                        _buildBbtBar(height: 32, temp: '97.4°', day: 'D13', isShift: false),
                        _buildBbtBar(height: 65, temp: '98.2°', day: 'D15', isShift: true),
                        _buildBbtBar(height: 70, temp: '98.4°', day: 'D16', isShift: true),
                        _buildBbtBar(height: 72, temp: '98.5°', day: 'D17', isShift: true),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Coverline visual indicator
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '--- Coverline: 97.7°F (Thermal Shift +0.7°F sustained for 3 days) ---',
                        style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFD97706)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0D9488)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF0D9488)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ovulation confirmed on Cycle Day 14. Progesterone is actively sustaining your luteal phase.',
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBbtBar({required double height, required String temp, required String day, required bool isShift}) {
    return Column(
      children: [
        Text(temp, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w600, color: isShift ? const Color(0xFF059669) : textMuted)),
        const SizedBox(height: 4),
        Container(
          width: 22,
          height: height,
          decoration: BoxDecoration(
            color: isShift ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(day, style: GoogleFonts.manrope(fontSize: 9, color: textMuted)),
      ],
    );
  }

  void _showWhyAmISeeingThisModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
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
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scientific Confidence Architecture',
                style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w700, color: textMain),
              ),
              const SizedBox(height: 6),
              Text(
                'Blushy does not guess. Our fertility engine combines the Symptothermal Method (FAM) with longitudinal cycle pattern recognition to ensure high clinical clarity.',
                style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.4),
              ),
              const SizedBox(height: 14),
              _buildConfidenceFeature('LH Surge Strips (OPK)', 'Detects the luteinizing hormone surge that triggers egg release within 24–36 hours.'),
              const SizedBox(height: 10),
              _buildConfidenceFeature('Cervical Fluid Texture', 'Peak estrogen produces clear, slippery, stretchy fluid (Egg White) that keeps sperm alive up to 5 days.'),
              const SizedBox(height: 10),
              _buildConfidenceFeature('Basal Body Temperature', 'Progesterone from the corpus luteum causes a sustained thermal shift of +0.4°F–1.0°F, proving ovulation occurred.'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crimsonPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Understood', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfidenceFeature(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 16, color: crimsonPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: textMain)),
              const SizedBox(height: 2),
              Text(desc, style: GoogleFonts.manrope(fontSize: 11, color: textMuted, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // LOG PERIOD DIALOG (Preserving Robust Save & Test Assertions)
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Save Period Date',
                        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
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

  // ════════════════════════════════════════════════════════════════════
  // REUSABLE UI HELPERS
  // ════════════════════════════════════════════════════════════════════
  Widget _buildSectionHeaderWithIcon({
    required String title,
    required IconData icon,
    required Color badgeColor,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: badgeColor, size: 15),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: crimsonPrimary,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildTtcLogChip(String label, bool isSelected, Color activeColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : surfaceCanvas,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : cardBorderColor,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : textMain,
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorQuestionItem(String question) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceCanvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right_rounded, size: 16, color: crimsonPrimary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              question,
              style: GoogleFonts.manrope(fontSize: 11.5, color: textMain, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // ASSEMBLE DASHBOARD CARDS (Clean, Phase-Aware, Non-Repetitive)
  // ════════════════════════════════════════════════════════════════════
  List<Widget> _buildDashboardCards(BuildContext context) {
    final phase = _currentTtcPhase;

    return [
      // 01. Editorial Greeting
      _buildEditorialGreeting(context),
      const SizedBox(height: 14),

      // 02. Period / Cycle Rhythm Tracker -- pinned to the top
      _buildPeriodTrackerCard(context),
      const SizedBox(height: 14),

      // Load/Empty notice
      StageStateNotice(
        state: _cycleState,
        hasData: _hasLoggedPeriod,
        emptyMessage:
            'Log the first day of your last period and this page starts '
            'working from your own cycle instead of general guidance.',
        onRetry: _rehydrateTtcState,
      ),
      const SizedBox(height: 16),

      // Fertile Window Continuum (Guides empty state when no period logged)
      if (!_hasLoggedPeriod) ...[
        _buildFertileWindowTimelineCard(context),
        const SizedBox(height: 16),
      ],

      // 03. Unified Daily Fertility Signals Hub (MERGE #1)
      _buildDailyFertilitySignalsHub(context),
      const SizedBox(height: 16),

      // 04. Phase-Specific Conception Focus Card (Cards only appear when in that phase!)
      if (phase == TtcPhase.menstrualReset)
        _buildMenstrualResetCard(context)
      else if (phase == TtcPhase.fertileApproach || phase == TtcPhase.ovulationPeak)
        _buildFertileWindowAndMaleFactorCard(context)
      else
        _buildPostOvulationAndTestingGuide(context),
      const SizedBox(height: 16),

      // 05. General Daily Symptoms Log (No double heading!)
      _buildEyebrow('LOG SYMPTOMS'),
      const LogSymptomsSection(
        stageKey: 'tryingtoconceive',
        showHeading: false,
      ),
      const SizedBox(height: 16),

      // 06. Mindset & De-Stress Hub (MERGE #2)
      _buildMindsetAndDeStressCard(context),
      const SizedBox(height: 16),

      // 07. Clinical Care & Doctor Preparation
      _buildDoctorPreparationAndJourneyCard(context),
      const SizedBox(height: 20),

      // 08. Curated TTC Health Library (Moved to the bottom!)
      _buildEyebrow("FERTILITY & CONCEPTION LIBRARY"),
      const TtcFertilitySection(),
      const SizedBox(height: 14),
      const TtcOvulationSection(),
      const SizedBox(height: 14),
      const TtcSexToConceiveSection(),
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
