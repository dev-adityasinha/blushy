import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/state.dart';
import '../../../../services/api_contract_client.dart';
import '../../view_models/postpartum_view_model.dart';
import '../../../../shared/live_refresh.dart';
import '../../../../services/api_postpartum_service.dart';
import '../../../sia/open_docsy.dart';
import '../doctor_summary_screen.dart';
import 'stage_shared_components.dart';
import '../../../../shared/stage_empty_notice.dart';
import '../../../../shared/user_display_name.dart';
import 'postpartum_sections.dart';
import '../../../../l10n/app_localizations.dart';

extension StringSliceSafe on String {
  String sliceSafe(int start, [int? end]) {
    if (start >= length) return '';
    final actualEnd = end != null ? end.clamp(start, length) : length;
    return substring(start, actualEnd);
  }
}

class PostpartumDashboard extends StatefulWidget {
  final bool isNested;
  final ScrollController? scrollController;

  const PostpartumDashboard({
    super.key,
    this.isNested = false,
    this.scrollController,
  });

  @override
  State<PostpartumDashboard> createState() => _PostpartumDashboardState();
}

class _PostpartumDashboardState extends State<PostpartumDashboard>
    with WidgetsBindingObserver, LiveRefresh {
  // ─── Design Tokens (STAGE1_DESIGN_RULES.md) ─────────────────────────
  static const Color cardBg = Colors.white;
  static const Color cardBorderColor = Color(0xFFEFE8E0);
  static const Color crimsonPrimary = Color(0xFFDD0D22);
  static const Color textMain = Color(0xFF221510);
  static const Color textMuted = Color(0xFF7A6B72);
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(18));

  // ─── Scrolling & Global Keys ───────────────────────────────────────
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ScrollController _internalScrollController = ScrollController();
  ScrollController get _effectiveScrollController => widget.scrollController ?? _internalScrollController;

  // ─── Real-Time Dynamic Postpartum State ────────────────────────────
  PostpartumOverviewData? _overview;
  /// The server's own verdict on the last load (spec §4, §31).
  ApiState _overviewState = ApiState.loading;
  PostpartumTodayBriefData? _todayBrief;
  bool _isLoading = true;
  bool _isLowEnergyMode = false;

  /// This screen is the View; the data load lives in the tested
  /// PostpartumViewModel and is mirrored back by _onDataChanged.
  final PostpartumViewModel _vm = PostpartumViewModel();

  // ─── Interactive Check-In State (Maternal-First) ───────────────────
  String? _physicalComfort;
  String? _mood;
  String? _todayFeels;
  String? _energy;
  String? _needRightNow;
  int _painScore = 2;
  String _bleedingLevel = 'moderate';
  double _sleepHours = 5.0;
  bool _isSavingCheckin = false;
  bool _checkinSaved = false;
  String _activeCheckinCategory = 'physical'; // 'physical', 'mood', 'energy', 'bleeding', 'need'

  // ─── Nursing Stopwatch Timer ────────────────────────────────────────
  Timer? _nursingTimer;
  int _nursingSeconds = 0;
  String? _activeNursingSide; // 'Left' or 'Right'

  // ─── Evening "Tonight" Checklist ───────────────────────────────────
  final Set<String> _tonightCompleted = {};

  // ─── AI Transparency State ──────────────────────────────────────────
  bool _showTransparency = false;
  String _lastCheckedDate = '';

  // ─── Merged Hub Tab State ─────────────────────────────────────────
  int _essentialsTab = 0; // 0 = Mom's Check-in, 1 = Baby Care & Nursing
  int _roadmapTab = 0;    // 0 = Lochia & Stages, 1 = Can I Do This Yet?, 2 = 6-Wk Doctor Prep

  final TextEditingController _docsyInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onDataChanged);
    _loadPostpartumData();
    startLiveRefresh();
  }

  @override
  Future<void> refreshNow() => _loadPostpartumData();

  @override
  void dispose() {
    stopLiveRefresh();
    _nursingTimer?.cancel();
    _vm.removeListener(_onDataChanged);
    _vm.dispose();
    _internalScrollController.dispose();
    _docsyInputController.dispose();
    super.dispose();
  }

  Future<void> _loadPostpartumData() => _vm.load();

  /// The View reacting to its ViewModel: mirror the loaded data and seed the
  /// check-in form from today's entry.
  void _onDataChanged() {
    if (!mounted) return;
    setState(() {
      _overview = _vm.overview;
      _todayBrief = _vm.todayBrief;
      _overviewState = _vm.overviewState;
      _isLowEnergyMode = _vm.isLowEnergyMode;
      _isLoading = _vm.isLoading;

      // Seed current checkin values if present
      final chk = _vm.todayCheckin;
      if (chk != null) {
        _physicalComfort = chk['physicalComfort']?.toString();
        _mood = chk['mood']?.toString();
        _todayFeels = chk['todayFeels']?.toString();
        _energy = chk['energy']?.toString();
        _needRightNow = chk['needRightNow']?.toString();
        _painScore = (chk['painScore'] as num?)?.toInt() ?? 2;
        _bleedingLevel = chk['bleedingLevel']?.toString() ?? 'moderate';
        _sleepHours = (chk['sleepHours'] as num?)?.toDouble() ?? 5.0;
        _checkinSaved = true;
      } else {
        _checkinSaved = false;
      }
    });
  }

  // ───────────────────────────────────────────────────────────────────
  // NURSING TIMER HELPERS
  // ───────────────────────────────────────────────────────────────────
  void _toggleNursingTimer(String side) {
    if (_activeNursingSide == side) {
      // Pause/Stop
      _nursingTimer?.cancel();
      final durationMin = (_nursingSeconds / 60).ceil();
      setState(() => _activeNursingSide = null);

      if (durationMin > 0) {
        ApiPostpartumService.recordBabyEvent(
          type: 'feed',
          details: {
            'mode': 'nursing',
            'side': side,
            'durationMin': durationMin,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged $durationMin min nursing on $side side ❤️'),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadPostpartumData();
      }
    } else {
      // Start or switch side
      _nursingTimer?.cancel();
      setState(() {
        _activeNursingSide = side;
        _nursingSeconds = 0;
      });
      _nursingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _nursingSeconds++);
      });
    }
  }

  String _formatTimerSeconds(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ───────────────────────────────────────────────────────────────────
  // UI BUILDERS: 11 CORE SECTIONS
  // ───────────────────────────────────────────────────────────────────

  // 01: EDITORIAL GREETING & WHERE AM I? (Unboxed)
  Widget _buildEditorialGreeting(PersonalContext pc) {
    // The user's own name, and a neutral address when it is not known.
    //
    // This read the stored profile under `name` and `profile.name`, keys
    // onboarding has never written, and fell through to "mama" -- so the screen
    // addressed everyone the same way regardless of who they were.
    final String userName = userFirstName(context);

    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning,'
        : (hour < 17 ? 'Good afternoon,' : 'Good evening,');

    final timing = _overview?.timing;
    final isCalibrated = timing?.isConfigured == true;
    final days = timing?.daysSinceBirth ?? 0;
    final phaseName = timing?.phaseName ?? 'Early Recovery';
    final deliveryType = _overview?.profile['deliveryType'] == 'cesarean' ? 'C-Section' : 'Vaginal Birth';

    final subtitle = isCalibrated
        ? 'Postpartum Day $days • $phaseName • $deliveryType'
        : 'Welcome to your 4th Trimester • Set Delivery Date';

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
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF7A6B72),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          // Orientation Badges Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isCalibrated) ...[
                _buildStatusPill('Day $days', const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
                _buildStatusPill(phaseName, const Color(0xFF0D9488), const Color(0xFFCCFBF1)),
                _buildStatusPill(deliveryType, const Color(0xFF7209B7), const Color(0xFFF3E8FF)),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _openCalibrationDialog,
                  icon: const Icon(Icons.tune, size: 16, color: crimsonPrimary),
                  label: Text('Calibrate Delivery Path & Date', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: crimsonPrimary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: crimsonPrimary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildTabPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? crimsonPrimary : textMuted,
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // HUB 1: TODAY'S ESSENTIALS (Mom & Baby Unified Care Hub) ⭐
  // ───────────────────────────────────────────────────────────────────
  Widget _buildDailyEssentialsHub() {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODAY\'S ESSENTIALS',
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: crimsonPrimary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _essentialsTab == 0 ? 'How Are You Healing?' : 'Baby Feeding & Diapers',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEE9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabPill(
                      label: '👩 Mom',
                      isSelected: _essentialsTab == 0,
                      onTap: () => setState(() => _essentialsTab = 0),
                    ),
                    _buildTabPill(
                      label: '👶 Baby',
                      isSelected: _essentialsTab == 1,
                      onTap: () => setState(() => _essentialsTab = 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _essentialsTab == 0 ? _buildMomCheckinView() : _buildBabyCareView(),
        ],
      ),
    );
  }

  Widget _buildMomCheckinView() {
    if (_checkinSaved) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFCCFBF1).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF99F6E4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF0D9488), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Today\'s recovery check-in recorded',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F766E),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _checkinSaved = false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'Edit ✎',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: crimsonPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildStatusPill('Mood: ${_mood ?? "Okay"}', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                _buildStatusPill('Lochia: $_bleedingLevel', crimsonPrimary, const Color(0xFFFFECEB)),
                _buildStatusPill('Pain: $_painScore/10', const Color(0xFF7209B7), const Color(0xFFF3E8FF)),
                _buildStatusPill('Sleep: ${_sleepHours.toStringAsFixed(1)} hrs', const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
              ],
            ),
          ],
        ),
      );
    }

    return _buildHowAreYouCheckIn();
  }

  Widget _buildBabyCareView() {
    final babyEvents = _overview?.todayBabyEvents ?? [];
    final wetCount = babyEvents.where((e) => e['type'] == 'diaper' && e['details']?['kind'] == 'wet').length;
    final dirtyCount = babyEvents.where((e) => e['type'] == 'diaper' && e['details']?['kind'] == 'dirty').length;
    final feedCount = babyEvents.where((e) => e['type'] == 'feed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ACTIVE NURSING STOPWATCH', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 1.0)),
            if (_activeNursingSide != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFFECEB), borderRadius: BorderRadius.circular(8)),
                child: Text(_formatTimerSeconds(_nursingSeconds), style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: crimsonPrimary)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildSideStopwatchButton('Left')),
            const SizedBox(width: 10),
            Expanded(child: _buildSideStopwatchButton('Right')),
          ],
        ),
        const SizedBox(height: 14),
        Text('DIAPER LOGGING & 24H TRACKING', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 1.0)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildQuickIncrementCard('Wet Diaper', '💧', () async {
                await ApiPostpartumService.recordBabyEvent(type: 'diaper', details: {'kind': 'wet'});
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).ppLoggedWetDiaper), duration: const Duration(seconds: 1)));
                _loadPostpartumData();
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickIncrementCard('Soiled Diaper', '💩', () async {
                await ApiPostpartumService.recordBabyEvent(type: 'diaper', details: {'kind': 'dirty'});
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).ppLoggedSoiledDiaper), duration: const Duration(seconds: 1)));
                _loadPostpartumData();
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEventCounterPill('$feedCount Feeds', crimsonPrimary, const Color(0xFFFFECEB)),
              _buildEventCounterPill('$wetCount Wet', const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
              _buildEventCounterPill('$dirtyCount Soiled', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSideStopwatchButton(String side) {
    final isActive = _activeNursingSide == side;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? crimsonPrimary : Colors.white,
        foregroundColor: isActive ? Colors.white : textMain,
        elevation: 0,
        side: BorderSide(color: isActive ? crimsonPrimary : cardBorderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      ),
      onPressed: () => _toggleNursingTimer(side),
      icon: Icon(Icons.timer_outlined, size: 16, color: isActive ? Colors.white : crimsonPrimary),
      label: Text(
        isActive ? 'Pause $side' : '$side Breast',
        style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // HUB 2: AI COMPANION & PEACE OF MIND (Docsy Intelligence & Reassurance) ⭐
  // ───────────────────────────────────────────────────────────────────
  Widget _buildDocsyAndPeaceOfMindHub() {
    final brief = _todayBrief;
    final greeting = brief?.openingGreeting ?? 'Good morning. Your body has been through an extraordinary transformation.';
    final recovery = brief?.recoveryPoint ?? 'Rest and horizontal healing take priority today.';
    final baby = brief?.babyPoint ?? 'Keep newborn rhythms intuitive. Feeding and skin-to-skin are key.';
    final notice = brief?.noticePoint ?? 'Notice how your physical energy responds to rest.';
    final pills = brief?.promptPills ?? [
      'Is this bleeding normal?',
      'My stitches / incision hurt',
      'I\'m exhausted',
      'Can I exercise yet?',
    ];

    final priorities = _overview?.priorities ?? [];
    final topPriority = priorities.isNotEmpty ? priorities.first : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFECEB),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.auto_awesome, color: crimsonPrimary, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI COMPANION & REASSURANCE',
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: crimsonPrimary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'Today with Docsy',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _showTransparency ? Icons.info : Icons.info_outline,
                  color: textMuted,
                  size: 20,
                ),
                tooltip: 'Why am I seeing this?',
                onPressed: () => setState(() => _showTransparency = !_showTransparency),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            greeting,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textMain,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          // AI Transparency Expandable
          if (_showTransparency && brief?.transparency != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEAE2D8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Why is Docsy suggesting this?', style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.bold, color: textMain)),
                  const SizedBox(height: 4),
                  ...?((brief!.transparency['signals'] as List?)?.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: crimsonPrimary)),
                        Expanded(child: Text(s.toString(), style: GoogleFonts.manrope(fontSize: 11, color: textMuted))),
                      ],
                    ),
                  ))),
                  const SizedBox(height: 4),
                  Text(brief.transparency['rationale']?.toString() ?? '', style: GoogleFonts.manrope(fontSize: 11, fontStyle: FontStyle.italic, color: textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildBriefRow(Icons.spa_outlined, const Color(0xFF0D9488), 'Your Recovery', recovery),
          const SizedBox(height: 8),
          _buildBriefRow(Icons.child_care, const Color(0xFFF72585), 'Your Baby', baby),
          const SizedBox(height: 8),
          _buildBriefRow(Icons.visibility_outlined, const Color(0xFF2563EB), 'Something to Notice', notice),

          // Embedded Clinical Priority Banner (Merged from "What Matters Today")
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.star_rounded, color: Color(0xFF0D9488), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topPriority != null ? 'TODAY\'S PRIORITY: ${topPriority.headline}' : 'TODAY\'S PRIORITY: Rest & Hydration',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F766E),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topPriority != null ? topPriority.reason : 'Lying flat removes gravity pressure from pelvic floor. Keep water (2.5L+) and protein high.',
                        style: GoogleFonts.manrope(fontSize: 11, color: textMuted, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Side-by-Side Peace of Mind Reassurance Cards
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _openSymptomReassuranceSheet(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF99F6E4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.health_and_safety_outlined, color: Color(0xFF0D9488), size: 20),
                        const SizedBox(height: 6),
                        Text(
                          'Is this normal?',
                          style: GoogleFonts.cormorantGaramond(fontSize: 16, fontWeight: FontWeight.bold, color: textMain),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Lochia, cramps, sweats',
                          style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _openLactationSafetySheet(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBE0).withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCCBC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.medication_liquid_outlined, color: Color(0xFFFF4A00), size: 20),
                        const SizedBox(height: 6),
                        Text(
                          'Can I take/eat this?',
                          style: GoogleFonts.cormorantGaramond(fontSize: 16, fontWeight: FontWeight.bold, color: textMain),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Meds & nursing safety',
                          style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Quick Ask Input
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _docsyInputController,
                    decoration: InputDecoration(
                      hintText: 'Ask Docsy about recovery or baby...',
                      hintStyle: GoogleFonts.manrope(fontSize: 12, color: textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (q) {
                      if (q.trim().isNotEmpty) {
                        final text = q.trim();
                        _docsyInputController.clear();
                        openDocsyWith(context, text);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: crimsonPrimary, size: 18),
                  onPressed: () {
                    final text = _docsyInputController.text.trim();
                    if (text.isNotEmpty) {
                      _docsyInputController.clear();
                      openDocsyWith(context, text);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Dynamic Prompt Pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: pills.map((p) => ActionChip(
              label: Text(p, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: textMain)),
              backgroundColor: const Color(0xFFFAF7F2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5DDD5)),
              ),
              onPressed: () => openDocsyWith(context, p),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBriefRow(IconData icon, Color color, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$title: ', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: textMain)),
                TextSpan(text: body, style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openSymptomReassuranceSheet([String? initialQuery]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _PostpartumSymptomReassuranceSheet(
        daysSinceBirth: _overview?.timing.daysSinceBirth ?? 14,
        initialQuery: initialQuery,
      ),
    );
  }

  void _openLactationSafetySheet([String? initialQuery]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _PostpartumLactationSafetySheet(
        daysSinceBirth: _overview?.timing.daysSinceBirth ?? 14,
        feedingMethod: _overview?.profile['feedingMethod']?.toString() ?? 'breastfeeding',
        initialQuery: initialQuery,
      ),
    );
  }

  Widget _buildPostpartumHealthLibrary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitleWithFilledIcon(
          icon: Icons.menu_book_rounded,
          title: 'Postpartum Health Library',
        ),
        const SizedBox(height: 14),
        const PostpartumAdjustingSection(),
        const SizedBox(height: 18),
        const PostpartumRaisingBabySection(),
        const SizedBox(height: 18),
        const PostpartumRecoveringSection(),
      ],
    );
  }

  // 02: HOW ARE YOU TODAY? (Hero Maternal Check-in - Compact & Rule Compliant) ⭐
  Widget _buildHowAreYouCheckIn() {
    final categories = [
      {
        'id': 'physical',
        'label': 'Physical',
        'field': 'physicalComfort',
        'current': _physicalComfort ?? 'Feeling okay',
        'icon': Icons.spa_rounded,
        'color': const Color(0xFF0D9488), // Emerald Teal
        'bg': const Color(0xFFCCFBF1),
        'options': ['Feeling okay', 'Sore', 'Exhausted', 'Something feels off'],
      },
      {
        'id': 'mood',
        'label': 'Emotional',
        'field': 'mood',
        'current': _mood ?? 'Okay',
        'icon': Icons.mood_rounded,
        'color': const Color(0xFFF72585), // Vivid Magenta
        'bg': const Color(0xFFFFE5F0),
        'options': ['Okay', 'Overwhelmed', 'Tearful', 'Anxious', 'Low'],
      },
      {
        'id': 'energy',
        'label': 'Energy',
        'field': 'energy',
        'current': _energy ?? 'Low',
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFFD97706), // Warm Amber
        'bg': const Color(0xFFFEF3C7),
        'options': ['Flat out', 'Low', 'Normal'],
      },
      {
        'id': 'bleeding',
        'label': 'Lochia',
        'field': 'bleedingLevel',
        'current': _bleedingLevel,
        'icon': Icons.water_drop_rounded,
        'color': const Color(0xFFDD0D22), // Brand Crimson
        'bg': const Color(0xFFFFECEB),
        'options': ['Heavy', 'Moderate', 'Light', 'Spotting'],
      },
      {
        'id': 'need',
        'label': 'Need Now',
        'field': 'needRightNow',
        'current': _needRightNow ?? 'Rest',
        'icon': Icons.volunteer_activism_rounded,
        'color': const Color(0xFF7209B7), // Royal Purple
        'bg': const Color(0xFFF3E8FF),
        'options': ['Rest', 'Pain relief', 'Food / Hydration', 'Someone to hold baby', 'A good cry'],
      },
    ];

    final activeCat = categories.firstWhere(
      (c) => c['id'] == _activeCheckinCategory,
      orElse: () => categories.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow & Headline Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOW ARE YOU TODAY?',
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: crimsonPrimary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Your body has been through something enormous.',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_checkinSaved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 12, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context).ppSavedSynced,
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              )
            else if (_isSavingCheckin)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: crimsonPrimary)),
                  const SizedBox(width: 5),
                  Text('Syncing...', style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted)),
                ],
              )
            else
              const Icon(Icons.favorite_outline, color: crimsonPrimary, size: 20),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal row of 52px circular mood/check-in badges with labels below
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: categories.map((cat) {
              final isSelected = _activeCheckinCategory == cat['id'];
              final catColor = cat['color'] as Color;
              final catBg = cat['bg'] as Color;
              final currentVal = cat['current'] as String;

              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _activeCheckinCategory = cat['id'] as String;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isSelected ? catBg : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? catColor : cardBorderColor,
                            width: isSelected ? 2.0 : 1.2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: catColor.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          cat['icon'] as IconData,
                          size: 24,
                          color: isSelected ? catColor : const Color(0xFF7A6B72),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat['label'] as String,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? textMain : const Color(0xFF7A6B72),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 62),
                        child: Text(
                          currentVal,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 9.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? catColor : textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Compact Active Category Option Strip
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
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
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: activeCat['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SELECT ${(activeCat['label'] as String).toUpperCase()}',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: activeCat['color'] as Color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      final prompt = 'I checked in today: Physically ${_physicalComfort ?? 'okay'}, emotional mood ${_mood ?? 'okay'}, energy ${_energy ?? 'normal'}, lochia bleeding $_bleedingLevel, and need ${_needRightNow ?? 'rest'}. How should I pace my recovery today?';
                      openDocsyWith(context, prompt);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 12, color: crimsonPrimary),
                        const SizedBox(width: 4),
                        Text(AppLocalizations.of(context).ppTalkToDocsy,
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: crimsonPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: (activeCat['options'] as List<String>).map((opt) {
                    final currentVal = activeCat['current'] as String;
                    final isSel = currentVal.toLowerCase() == opt.toLowerCase();
                    final catColor = activeCat['color'] as Color;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => _selectOptionAndAdvance(activeCat['field'] as String, opt),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                          decoration: BoxDecoration(
                            color: isSel ? catColor : const Color(0xFFFAF7F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel ? catColor : cardBorderColor,
                            ),
                          ),
                          child: Text(
                            opt,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? Colors.white : textMain,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectOptionAndAdvance(String field, String val) {
    _saveCheckinField(field, val);

    final order = ['physical', 'mood', 'energy', 'bleeding', 'need'];
    final currentIndex = order.indexOf(_activeCheckinCategory);
    if (currentIndex != -1 && currentIndex < order.length - 1) {
      setState(() {
        _activeCheckinCategory = order[currentIndex + 1];
      });
    }
  }

  Future<void> _saveCheckinField(String field, String val) async {
    setState(() {
      if (field == 'physicalComfort') _physicalComfort = val;
      if (field == 'mood') _mood = val;
      if (field == 'energy') _energy = val;
      if (field == 'bleedingLevel') _bleedingLevel = val;
      if (field == 'needRightNow') _needRightNow = val;
      if (field == 'todayFeels') _todayFeels = val;
      _isSavingCheckin = true;
      _checkinSaved = false;
    });

    await _saveCompleteCheckin();
  }

  Future<void> _saveCompleteCheckin() async {
    setState(() {
      _isSavingCheckin = true;
    });

    await ApiPostpartumService.recordCheckin({
      'physicalComfort': _physicalComfort,
      'mood': _mood,
      'energy': _energy,
      'needRightNow': _needRightNow,
      'todayFeels': _todayFeels,
      'painScore': _painScore,
      'bleedingLevel': _bleedingLevel,
      'sleepHours': _sleepHours.toInt(),
    });

    // Refresh through the view model; _onDataChanged mirrors the new data.
    await _vm.load();
    if (!mounted) return;
    setState(() {
      _isSavingCheckin = false;
      _checkinSaved = true;
    });
  }

  // ───────────────────────────────────────────────────────────────────
  // HUB 3: RECOVERY & CARE ROADMAP (Stages, "Can I?", & Doctor Prep) ⭐
  // ───────────────────────────────────────────────────────────────────
  Widget _buildRecoveryAndCareRoadmapHub() {
    final timing = _overview?.timing;
    final day = timing?.daysSinceBirth ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECOVERY & CARE ROADMAP',
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: crimsonPrimary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _roadmapTab == 0
                        ? 'Stages & Lochia Progression'
                        : (_roadmapTab == 1 ? 'Activity & "Can I?" Guidance' : 'Doctor & Baseline Prep'),
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 3-Way Tab Selector
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEE9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabPill(
                    label: '🩸 Stages',
                    isSelected: _roadmapTab == 0,
                    onTap: () => setState(() => _roadmapTab = 0),
                  ),
                ),
                Expanded(
                  child: _buildTabPill(
                    label: '💡 Can I?',
                    isSelected: _roadmapTab == 1,
                    onTap: () => setState(() => _roadmapTab = 1),
                  ),
                ),
                Expanded(
                  child: _buildTabPill(
                    label: '🩺 Doctor Prep',
                    isSelected: _roadmapTab == 2,
                    onTap: () => setState(() => _roadmapTab = 2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_roadmapTab == 0) _buildRoadmapStagesView(day),
          if (_roadmapTab == 1) _buildRoadmapCanIView(),
          if (_roadmapTab == 2) _buildRoadmapDoctorPrepView(),
        ],
      ),
    );
  }

  Widget _buildRoadmapStagesView(int day) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Visual Map Steps
        Row(
          children: [
            _buildRecoveryStep('First Days\n(D1-7)', day <= 7),
            _buildRecoveryDivider(day > 7),
            _buildRecoveryStep('Early Healing\n(D8-42)', day > 7 && day <= 42),
            _buildRecoveryDivider(day > 42),
            _buildRecoveryStep('6-Wk Review\n(Day 42)', day == 42),
            _buildRecoveryDivider(day > 42),
            _buildRecoveryStep('Extended\n(M2-12)', day > 42),
          ],
        ),
        const SizedBox(height: 16),
        // Lochia stages explanation (Interactive modal trigger)
        InkWell(
          onTap: () => _openLochiaGuideModal(context, day),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop_outlined, color: crimsonPrimary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            day <= 4
                                ? 'Stage: Lochia Rubra (Dark Red)'
                                : (day <= 14 ? 'Stage: Lochia Serosa (Pink/Brown)' : 'Stage: Lochia Alba (Yellow/White)'),
                            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: textMain),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios, size: 12, color: crimsonPrimary),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Tap to view color timeline, volume expectations, and red flags.', style: GoogleFonts.manrope(fontSize: 11, color: textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('RECENT LOGGED TRENDS', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 1.0)),
        const SizedBox(height: 8),
        if ((_overview?.recentCheckins ?? []).isNotEmpty) ...[
          ...(_overview!.recentCheckins).take(3).map((c) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['date']?.toString() ?? 'Recent Day', style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.bold, color: textMain)),
                    const SizedBox(height: 2),
                    Text('Bleeding: ${c['bleedingLevel'] ?? 'Moderate'} • Pain: ${c['painScore'] ?? 2}/10', style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                  child: Text(c['mood']?.toString() ?? 'Okay', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
                ),
              ],
            ),
          )),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorderColor),
            ),
            child: Text(
              'Complete your daily check-in in Hub 1 above to track lochia, pain score, and emotional energy progression.',
              style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRoadmapCanIView() {
    final guides = _overview?.canIDoThisYet ?? [
      {
        'activity': 'drive',
        'timeline': 'Typically 2-3 weeks (vaginal) or 3-4 weeks (C-section)',
        'recommendation': 'Wait until you can slam on brakes without pain and are no longer taking prescription narcotics.',
      },
      {
        'activity': 'take a bath',
        'timeline': 'Typically 4-6 weeks postpartum',
        'recommendation': 'Wait until bleeding has subsided and perineal tear or C-section incision has fully closed to prevent uterine infection.',
      },
      {
        'activity': 'gentle exercise',
        'timeline': 'Gentle walking now; core and lifting after 6-week review',
        'recommendation': 'Gentle stroller walks and diaphragmatic breathing are safe anytime. Avoid high-impact or heavy abdominal exercises early on.',
      },
      {
        'activity': 'resume intimacy',
        'timeline': 'Typically after 6-week postnatal checkup',
        'recommendation': 'Wait until lochia has ceased, tissues have healed, and your OB/midwife gives medical clearance. Ovulation can happen before your first period!',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EVIDENCE-BASED ACTIVITY MILESTONES',
          style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 1.0),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: guides.map((g) => ActionChip(
            avatar: const Icon(Icons.check_circle_outline, size: 16, color: crimsonPrimary),
            label: Text('Can I ${g['activity']}?', style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFFFAF7F2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: cardBorderColor)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Can I ${g['activity']}?', style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context).ppTimelineGuideline, style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.bold, color: crimsonPrimary)),
                      const SizedBox(height: 4),
                      Text(g['timeline']?.toString() ?? '', style: GoogleFonts.manrope(fontSize: 12.5, color: textMain)),
                      const SizedBox(height: 12),
                      Text(AppLocalizations.of(context).ppRecommendation, style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.bold, color: crimsonPrimary)),
                      const SizedBox(height: 4),
                      Text(g['recommendation']?.toString() ?? '', style: GoogleFonts.manrope(fontSize: 12, color: textMuted)),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        openDocsyWith(context, 'Tell me more about when I can ${g['activity']} based on my recovery.');
                      },
                      child: Text(AppLocalizations.of(context).ppAskDocsyMore, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: crimsonPrimary)),
                    ),
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).ppClose)),
                  ],
                ),
              );
            },
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildRoadmapDoctorPrepView() {
    final deltas = _overview?.deltas;
    final changes = deltas?.changes ?? [];
    final steady = deltas?.steady ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('6-WEEK POSTNATAL REVIEW PREP', style: GoogleFonts.cormorantGaramond(fontSize: 18, fontWeight: FontWeight.bold, color: textMain)),
        const SizedBox(height: 4),
        Text('Blushy synthesizes your logged pain, lochia duration, sleep, and emotional recovery into a concise clinical briefing for your doctor or midwife.', style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.4)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: crimsonPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorSummaryScreen())),
            icon: const Icon(Icons.summarize_outlined, size: 18),
            label: Text(AppLocalizations.of(context).ppBuildDoctorSummary, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 12.5)),
          ),
        ),
        const SizedBox(height: 14),
        if (changes.isNotEmpty || steady.isNotEmpty) ...[
          Text('LONGITUDINAL RECOVERY PATTERNS', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 1.0)),
          const SizedBox(height: 6),
          ...changes.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.change_circle_outlined, color: Color(0xFFD97706), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('${c['detail']} — ${c['context']}', style: GoogleFonts.manrope(fontSize: 11, color: textMain))),
              ],
            ),
          )),
          ...steady.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF0D9488), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(s, style: GoogleFonts.manrope(fontSize: 11, color: textMuted))),
              ],
            ),
          )),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: _openSomethingChangedAfterDialog,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.insights, size: 16, color: crimsonPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Log a pattern: "Something changed after..."',
                    style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.bold, color: crimsonPrimary),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 12, color: crimsonPrimary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // HUB 4: SUPPORT CIRCLE, REST & SAFETY (SOS, Rest Mode & Red Flags) ⭐
  // ───────────────────────────────────────────────────────────────────
  Widget _buildSupportAndRestHub() {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUPPORT CIRCLE & REST PACING',
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: crimsonPrimary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rest, SOS & Safety Shield',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.handshake_outlined, color: crimsonPrimary, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          // 1-Tap SOS Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: crimsonPrimary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: const Size(double.infinity, 44),
            ),
            icon: const Icon(Icons.send_rounded, color: crimsonPrimary, size: 16),
            label: Text('I NEED HELP TODAY (Generate Partner Request)', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 12, color: crimsonPrimary)),
            onPressed: _openHelpSosDialog,
          ),
          const SizedBox(height: 12),
          // Low-energy mode switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).ppIMDoneForToday, style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.bold, color: textMain)),
                    Text('Pause tracking, charts, and recommendations', style: GoogleFonts.manrope(fontSize: 10, color: textMuted)),
                  ],
                ),
                Switch(
                  value: _isLowEnergyMode,
                  activeThumbColor: crimsonPrimary,
                  onChanged: (val) async {
                    setState(() => _isLowEnergyMode = val);
                    await ApiPostpartumService.calibrate(lowEnergyMode: val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Tonight checklist
          Text(AppLocalizations.of(context).ppTonightWindDown, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: textMain)),
          const SizedBox(height: 6),
          _buildChecklistItem('t1', 'Drink a large glass of water & electrolyte'),
          _buildChecklistItem('t2', 'Take prescribed vitamins / medications'),
          _buildChecklistItem('t3', 'Set up overnight feeding & diaper station'),
          _buildChecklistItem('t4', 'Hand off 1 overnight wake-up to your support circle'),

          const SizedBox(height: 16),
          // Clinical Safety Shield Banner (Integrated)
          InkWell(
            onTap: _openSafetyTriageDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: crimsonPrimary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SOMETHING DOESN\'T FEEL RIGHT?', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 0.8)),
                        Text('Tap for immediate clinical triage (bleeding, headache, fever, pain).', style: GoogleFonts.manrope(fontSize: 10.5, color: textMain)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: crimsonPrimary, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String id, String label) {
    final done = _tonightCompleted.contains(id);
    return InkWell(
      onTap: () {
        setState(() {
          if (done) {
            _tonightCompleted.remove(id);
          } else {
            _tonightCompleted.add(id);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? crimsonPrimary : textMuted, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: GoogleFonts.manrope(fontSize: 11.5, decoration: done ? TextDecoration.lineThrough : null, color: done ? textMuted : textMain))),
          ],
        ),
      ),
    );
  }


  Widget _buildEventCounterPill(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildQuickIncrementCard(String label, String emoji, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.bold, color: textMain)),
            const SizedBox(width: 6),
            const Icon(Icons.add_circle, color: crimsonPrimary, size: 16),
          ],
        ),
      ),
    );
  }



  Widget _buildRecoveryStep(String title, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? crimsonPrimary : const Color(0xFFE5DDD5),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? textMain : textMuted)),
        ],
      ),
    );
  }

  Widget _buildRecoveryDivider(bool isPassed) {
    return Container(
      width: 16,
      height: 2,
      color: isPassed ? crimsonPrimary : const Color(0xFFE5DDD5),
    );
  }


  // LOW-ENERGY REST VIEW ("Give Me a Break" Mode)
  Widget _buildLowEnergyRestView() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.spa, size: 48, color: Color(0xFF0D9488)),
          const SizedBox(height: 16),
          Text('You don\'t have to do anything else right now.', textAlign: TextAlign.center, style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.bold, color: textMain)),
          const SizedBox(height: 8),
          Text('No tracking. No charts. No goals.\nRest. ❤️', textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 14, color: textMuted, height: 1.5)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: () => openDocsyWith(context, 'I am exhausted and just want to rest.'),
                child: Text(AppLocalizations.of(context).ppTalkToDocsy2, style: GoogleFonts.manrope(color: crimsonPrimary)),
              ),
              OutlinedButton(
                onPressed: _openHelpSosDialog,
                child: Text(AppLocalizations.of(context).ppAskForHelp, style: GoogleFonts.manrope(color: crimsonPrimary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF221510)),
                onPressed: () async {
                  setState(() => _isLowEnergyMode = false);
                  await ApiPostpartumService.calibrate(lowEnergyMode: false);
                },
                child: Text(AppLocalizations.of(context).ppResumeNormalMode, style: GoogleFonts.manrope(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // MODAL DIALOGS & BOTTOM SHEETS
  // ───────────────────────────────────────────────────────────────────

  void _openLochiaGuideModal(BuildContext context, int day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          expand: false,
          builder: (c, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE5DDD5), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text('LOCHIA STAGING & HEALING GUIDE', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 1.1)),
              const SizedBox(height: 4),
              Text('Understanding Your Postpartum Bleeding', style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain)),
              const SizedBox(height: 8),
              Text('Lochia is normal vaginal discharge after birth consisting of blood, uterine lining tissue, and mucus. Its color and volume track your internal placental site healing.', style: GoogleFonts.manrope(fontSize: 12.5, color: textMuted, height: 1.45)),
              const SizedBox(height: 18),
              _buildLochiaStageCard(
                stage: 'Stage 1: Lochia Rubra',
                days: 'Days 1 – 4',
                colorDesc: 'Dark Red / Crimson',
                dotColor: const Color(0xFF991B1B),
                isCurrent: day <= 4,
                expected: 'Moderate to heavy flow with small dime-sized clots. Expected right after birth as placental wound begins contracting.',
                warning: 'Soaking >1 large maxi pad per hour for 2+ consecutive hours is a clinical emergency.',
              ),
              const SizedBox(height: 12),
              _buildLochiaStageCard(
                stage: 'Stage 2: Lochia Serosa',
                days: 'Days 5 – 10 (up to Day 14)',
                colorDesc: 'Pinkish / Brown / Watery',
                dotColor: const Color(0xFFD97706),
                isCurrent: day > 4 && day <= 14,
                expected: 'Flow lightens to pinkish-brown watery fluid. Signals steady placental site remodeling.',
                warning: 'If flow suddenly returns to bright red heavy bleeding, your body is telling you to rest horizontally.',
              ),
              const SizedBox(height: 12),
              _buildLochiaStageCard(
                stage: 'Stage 3: Lochia Alba',
                days: 'Weeks 2 – 6',
                colorDesc: 'Yellowish-white / Cream',
                dotColor: const Color(0xFF0D9488),
                isCurrent: day > 14,
                expected: 'Light mucus-like yellowish white discharge. Signals near-complete uterine lining renewal.',
                warning: 'Foul odor, pelvic burning, or fever (>100.4°F) indicates possible infection and needs medical attention.',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: crimsonPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  openDocsyWith(context, 'Explain my current lochia bleeding stage for Day $day and what I should look out for.');
                },
                child: Text('Ask Docsy About My Bleeding →', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLochiaStageCard({
    required String stage,
    required String days,
    required String colorDesc,
    required Color dotColor,
    required bool isCurrent,
    required String expected,
    required String warning,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFFFF7ED) : const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCurrent ? const Color(0xFFFED7AA) : cardBorderColor, width: isCurrent ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(stage, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold, color: textMain)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: cardBorderColor)),
                child: Text(days, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Color: $colorDesc', style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w600, color: crimsonPrimary)),
          const SizedBox(height: 4),
          Text(expected, style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.4)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Expanded(child: Text(warning, style: GoogleFonts.manrope(fontSize: 10.5, color: textMain))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCalibrationDialog() {
    DateTime selectedDate = DateTime.now().subtract(const Duration(days: 7));
    String deliveryType = _overview?.profile['deliveryType'] ?? 'vaginal';
    String feedingMethod = _overview?.profile['feedingMethod'] ?? 'breastfeeding';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(AppLocalizations.of(context).ppCalibratePostpartumPath, style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).ppBabySBirthDate, style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.bold, color: crimsonPrimary)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDlgState(() => selectedDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('${selectedDate.toLocal()}'.split(' ')[0], style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context).ppDeliveryPath, style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.bold, color: crimsonPrimary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(AppLocalizations.of(context).ppVaginalBirth),
                      selected: deliveryType == 'vaginal',
                      selectedColor: crimsonPrimary,
                      onSelected: (_) => setDlgState(() => deliveryType = 'vaginal'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(AppLocalizations.of(context).ppCSection),
                      selected: deliveryType == 'cesarean',
                      selectedColor: crimsonPrimary,
                      onSelected: (_) => setDlgState(() => deliveryType = 'cesarean'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context).ppFeedingMethod, style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.bold, color: crimsonPrimary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: ['breastfeeding', 'pumping', 'formula', 'combination'].map((m) => ChoiceChip(
                    label: Text(m),
                    selected: feedingMethod == m,
                    selectedColor: crimsonPrimary,
                    onSelected: (_) => setDlgState(() => feedingMethod = m),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).ppCancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary),
              onPressed: () async {
                Navigator.pop(ctx);
                await ApiPostpartumService.calibrate(
                  deliveryDate: selectedDate.toIso8601String().split('T')[0],
                  deliveryType: deliveryType,
                  feedingMethod: feedingMethod,
                );
                _loadPostpartumData();
              },
              child: Text(AppLocalizations.of(context).ppSaveCalibrate, style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openHelpSosDialog() {
    final selectedNeeds = <String>{'food'};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(AppLocalizations.of(context).ppINeedHelpToday, style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WHAT WOULD MAKE TODAY EASIER?', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.bold, color: crimsonPrimary)),
                const SizedBox(height: 10),
                ...[
                  {'id': 'food', 'label': '🍲 Bring me food / warm meal'},
                  {'id': 'baby_care', 'label': '👶 Watch baby for a couple of hours'},
                  {'id': 'housework', 'label': '🧺 Help with laundry or dishes'},
                  {'id': 'company', 'label': '🫂 Just come sit with me'},
                  {'id': 'appointment', 'label': '🩺 Come to my appointment with me'},
                ].map((item) {
                  final checked = selectedNeeds.contains(item['id']);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['label']!, style: GoogleFonts.manrope(fontSize: 12.5)),
                    value: checked,
                    activeColor: crimsonPrimary,
                    onChanged: (v) {
                      setDlgState(() {
                        if (v == true) {
                          selectedNeeds.add(item['id']!);
                        } else {
                          selectedNeeds.remove(item['id']);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).ppCancel)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final message = await ApiPostpartumService.generateHelpSOS(selectedNeeds.toList());
                if (message != null) {
                  Clipboard.setData(ClipboardData(text: message));
                  Share.share(message, subject: 'A quick request from postpartum mom');
                  messenger.showSnackBar(const SnackBar(content: Text('Message copied to clipboard & share opened! ❤️')));
                }
              },
              icon: const Icon(Icons.share, size: 16, color: Colors.white),
              label: Text(AppLocalizations.of(context).ppGenerateShare, style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openSafetyTriageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: crimsonPrimary),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).ppClinicalSafetyTriage, style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHAT ARE YOU NOTICING?', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.bold, color: textMuted)),
            const SizedBox(height: 10),
            ...[
              'Bleeding soaking 1+ pad/hour or large clots',
              'Severe headache or flashing lights/vision changes',
              'Fever above 100.4°F (38°C) or severe chills',
              'Incision redness spreading, opening, or pus',
              'Chest pain or sudden shortness of breath',
              'Extreme emotional panic or dark thoughts',
            ].map((s) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.report_problem_outlined, color: crimsonPrimary, size: 18),
              title: Text(s, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                openDocsyWith(context, 'URGENT SAFETY EVALUATION: I am experiencing $s. What immediate clinical actions should I take?');
              },
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).ppCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary),
            onPressed: () {
              Navigator.pop(ctx);
              openDocsyWith(context, 'I am concerned about my postpartum symptoms right now. Please help me evaluate if I need urgent medical care.');
            },
            child: Text(AppLocalizations.of(context).ppTalkToDocsyNow, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openSomethingChangedAfterDialog() {
    String selectedEvent = 'Walking / Moving';
    String selectedChange = 'Increased pain';

    final events = ['Walking / Moving', 'Nursing session', 'Starting medication', 'Active day', 'Interrupted sleep'];
    final changes = ['Increased pain', 'Bleeding surge', 'Breast tenderness', 'Emotional dip', 'Exhaustion'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Something Changed After...', style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).ppWhatHappenedEvent, style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.bold, color: crimsonPrimary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: events.map((e) {
                    final sel = selectedEvent == e;
                    return ChoiceChip(
                      label: Text(e, style: GoogleFonts.manrope(fontSize: 11.5, color: sel ? Colors.white : textMain)),
                      selected: sel,
                      selectedColor: crimsonPrimary,
                      backgroundColor: const Color(0xFFFAF7F2),
                      onSelected: (_) => setDlgState(() => selectedEvent = e),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(AppLocalizations.of(context).ppWhatChangedObservedShift, style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.bold, color: crimsonPrimary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: changes.map((c) {
                    final sel = selectedChange == c;
                    return ChoiceChip(
                      label: Text(c, style: GoogleFonts.manrope(fontSize: 11.5, color: sel ? Colors.white : textMain)),
                      selected: sel,
                      selectedColor: crimsonPrimary,
                      backgroundColor: const Color(0xFFFAF7F2),
                      onSelected: (_) => setDlgState(() => selectedChange = c),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).ppCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                final prompt = 'I noticed a pattern shift in my postpartum recovery: After $selectedEvent, I experienced $selectedChange. What might this mean for my recovery stage, and what gentle adjustments do you suggest?';
                openDocsyWith(context, prompt);
              },
              child: Text(AppLocalizations.of(context).ppUnderstandWithDocsy, style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentSafetyInterruptionBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crimsonPrimary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error, color: crimsonPrimary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(AppLocalizations.of(context).ppClinicalSafetyAlert,
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 1.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent symptoms suggest potential postpartum complications that need professional medical assessment.',
            style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.bold, color: textMain),
          ),
          const SizedBox(height: 6),
          Text(
            'Please contact your OB/GYN, midwife, or visit urgent care/ER promptly if you experience soaking 2+ pads/hour, severe headache with vision changes, or fever above 100.4°F.',
            style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary, foregroundColor: Colors.white),
            onPressed: _openSafetyTriageDialog,
            icon: const Icon(Icons.local_hospital, size: 16),
            label: Text('Review Clinical Triage & Guidance →', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // MAIN BUILD
  // ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final todayStr = DateTime.now().toIso8601String().sliceSafe(0, 10);
    if (_lastCheckedDate.isNotEmpty && _lastCheckedDate != todayStr) {
      _lastCheckedDate = todayStr;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadPostpartumData();
        }
      });
    } else if (_lastCheckedDate.isEmpty) {
      _lastCheckedDate = todayStr;
    }

    final osState = BlushyOSProvider.of(context);
    final pc = osState.personalContext;
    final shouldInterrupt = _overview?.safetyStatus['shouldInterrupt'] == true;

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator(color: crimsonPrimary))
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                controller: _effectiveScrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 18, right: 18, top: 20, bottom: 120),
                children: [
                  // 01: WHERE AM I? (Unboxed Editorial Greeting & Orientation)
                  _buildEditorialGreeting(pc),
                  const SizedBox(height: 16),

                  // Nothing came back from the server, so the sections below are
                  // the stage's general content rather than her recovery
                  // (spec §4, §31).
                  StageStateNotice(
                    state: _overviewState,
                    hasData: _overview != null || _todayBrief != null,
                    emptyMessage:
                        'There is nothing recorded for your recovery yet, so what follows '
                        'is general guidance rather than anything worked out from your own '
                        'entries. Add your birth date and a check-in to see it tailored to you.',
                    onRetry: () {
                      setState(() => _isLoading = true);
                      _loadPostpartumData();
                    },
                  ),

                  // 🚨 Context-Aware Urgent Safety Interruption if triggered
                  if (shouldInterrupt) ...[
                    _buildUrgentSafetyInterruptionBanner(),
                    const SizedBox(height: 16),
                  ],

                  if (_isLowEnergyMode) ...[
                    _buildLowEnergyRestView(),
                  ] else ...[
                    // 01: TODAY'S ESSENTIALS (Mom & Baby Unified Care Hub) ⭐
                    _buildDailyEssentialsHub(),
                    const SizedBox(height: 18),

                    // 02: AI COMPANION & PEACE OF MIND (Docsy Intelligence & Reassurance) ⭐
                    _buildDocsyAndPeaceOfMindHub(),
                    const SizedBox(height: 18),

                    // 03: RECOVERY & CARE ROADMAP (Stages, "Can I?", & Doctor Prep) ⭐
                    _buildRecoveryAndCareRoadmapHub(),
                    const SizedBox(height: 18),

                    // 04: SUPPORT CIRCLE, REST & SAFETY (SOS, Rest Mode & Red Flags) ⭐
                    _buildSupportAndRestHub(),
                    const SizedBox(height: 18),

                    // 05: CURATED POSTPARTUM HEALTH & ADJUSTING LIBRARY
                    _buildPostpartumHealthLibrary(),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );

    return wrapStageDashboardLayout(
      context: context,
      child: content,
      scaffoldKey: _scaffoldKey,
      isNested: widget.isNested,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// PEACE OF MIND: POSTPARTUM SYMPTOM REASSURANCE
// ─────────────────────────────────────────────────────────────────────
class PostpartumSymptomReassuranceResult {
  final String category; // 'normal', 'caution', 'warning'
  final String badgeLabel;
  final String colorHex;
  final String summary;
  final String reasoning;
  final String guidance;
  final String questionForDoctor;

  const PostpartumSymptomReassuranceResult({
    required this.category,
    required this.badgeLabel,
    required this.colorHex,
    required this.summary,
    required this.reasoning,
    required this.guidance,
    required this.questionForDoctor,
  });
}

class _PostpartumSymptomReassuranceSheet extends StatefulWidget {
  final int daysSinceBirth;
  final String? initialQuery;

  const _PostpartumSymptomReassuranceSheet({
    required this.daysSinceBirth,
    this.initialQuery,
  });

  @override
  State<_PostpartumSymptomReassuranceSheet> createState() => _PostpartumSymptomReassuranceSheetState();
}

class _PostpartumSymptomReassuranceSheetState extends State<_PostpartumSymptomReassuranceSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery ?? '');
  PostpartumSymptomReassuranceResult? _result;
  String? _activeQuery;
  bool _loading = false;

  final List<String> _quickSuggestions = [
    'Lochia color changes',
    'Night sweats & chills',
    'Afterpains while nursing',
    'Perineal swelling & stitches',
    'Baby blues vs PPD',
    'Breast engorgement',
    'Hair loss',
    'Pelvic heaviness',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _runTriage(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
      _result = null;
      _activeQuery = null;
      _loading = false;
    });
  }

  PostpartumSymptomReassuranceResult _localSymptomTriage(String query, int daysSinceBirth) {
    final q = query.toLowerCase();

    if (q.contains('lochia') || q.contains('bleed') || q.contains('discharge') || q.contains('blood') || q.contains('pad')) {
      return const PostpartumSymptomReassuranceResult(
        category: 'normal',
        badgeLabel: 'Normal Physiological Recovery',
        colorHex: '#0D9488',
        summary: 'Lochia transitions over 6 weeks: dark red (Rubra, days 1-4), pink/brown watery (Serosa, days 5-14), and creamy yellow/white (Alba, weeks 2-6).',
        reasoning: 'The placental wound site undergoes natural vascular sealing and endometrial remodeling as your uterus involutes.',
        guidance: 'If bleeding surges back to bright red after turning pink, your body is signaling that you need horizontal rest. If soaking 1+ pad per hour or passing clots larger than a golf ball, seek emergency care.',
        questionForDoctor: 'Is my current lochia volume and color transition consistent with my healing day?',
      );
    }

    if (q.contains('sweat') || q.contains('night sweat') || q.contains('chills') || q.contains('hot flash') || q.contains('sweating')) {
      return const PostpartumSymptomReassuranceResult(
        category: 'normal',
        badgeLabel: 'Normal Fluid Elimination',
        colorHex: '#0D9488',
        summary: 'Waking up drenched in sweat is very common during the first 2-3 weeks as your body eliminates massive gestational fluids.',
        reasoning: 'Abrupt estrogen and progesterone plunges trigger your kidneys and sweat glands to shed the 30-50% blood and tissue volume built up during pregnancy.',
        guidance: 'Keep a clean towel and change of cotton clothes by your bed. Hydrate generously with electrolyte water. Note: a true temperature >100.4°F is a fever, not a sweat, and needs clinical triage.',
        questionForDoctor: 'Are there any signs of infection that I should monitor alongside night sweats?',
      );
    }

    if (q.contains('afterpain') || q.contains('cramp') || q.contains('cramping') || q.contains('uterine')) {
      return const PostpartumSymptomReassuranceResult(
        category: 'normal',
        badgeLabel: 'Expected Uterine Contractions',
        colorHex: '#0D9488',
        summary: 'Afterpains are rhythmic uterine contractions that typically peak during breastfeeding/nursing sessions in the first 3-5 days.',
        reasoning: 'Baby suckling releases natural oxytocin, which simultaneously triggers milk letdown and clamps down uterine muscle fibers to prevent hemorrhage.',
        guidance: 'Empty your bladder before nursing, apply a gentle warm compress to your lower abdomen, and take prescribed Ibuprofen 30 minutes prior to feeds.',
        questionForDoctor: 'Can I take scheduled Ibuprofen 30 minutes before feeding sessions for afterpains?',
      );
    }

    if (q.contains('perine') || q.contains('stitch') || q.contains('tear') || q.contains('sore') || q.contains('episiotomy')) {
      return const PostpartumSymptomReassuranceResult(
        category: 'normal',
        badgeLabel: 'Active Tissue Remodeling',
        colorHex: '#0D9488',
        summary: 'Perineal soreness and swelling peak during days 2-4 and gradually improve over 2-3 weeks as dissolving stitches heal.',
        reasoning: 'Pelvic tissues endure significant stretching and micro-trauma during delivery, requiring gravity relief and clean circulation to regenerate.',
        guidance: 'Use a warm water peri bottle every time you use the bathroom (pat gently, never wipe), apply chilled witch hazel pads, sit on a contoured cushion, and lie horizontally.',
        questionForDoctor: 'Are my perineal stitches dissolving smoothly without signs of tension or separation?',
      );
    }

    if (q.contains('blue') || q.contains('cry') || q.contains('tear') || q.contains('mood') || q.contains('overwhelm') || q.contains('sad')) {
      return const PostpartumSymptomReassuranceResult(
        category: 'caution',
        badgeLabel: 'Hormonal Reset • Monitor Duration',
        colorHex: '#D97706',
        summary: 'The "Baby Blues" affect up to 80% of mothers between Days 3 and 10, bringing sudden crying spells, fragility, and emotional swings.',
        reasoning: 'The most steep hormonal drop in human biology occurs immediately after delivery, compounded by profound sleep deprivation and newborn responsibility.',
        guidance: 'You are not failing. Sleep is the most potent biological reset—hand off baby for a protected 4-hour sleep window. If sadness, numbness, or panic persists past 2 weeks, request an EPDS screening.',
        questionForDoctor: 'Can we complete an Edinburgh Postnatal Depression Scale (EPDS) screen at my 2-week check?',
      );
    }

    if (q.contains('engorg') || q.contains('hard breast') || q.contains('lump') || q.contains('clog') || q.contains('duct')) {
      return const PostpartumSymptomReassuranceResult(
        category: 'caution',
        badgeLabel: 'Milk Transition • Relieve Pressure',
        colorHex: '#D97706',
        summary: 'Breasts often become firm, warm, and tender around Days 3-5 as transitional milk increases significantly in volume.',
        reasoning: 'Rapid vascular dilation, lymphatic accumulation, and milk synthesis fill breast tissues as mature lactation establishes.',
        guidance: 'Use reverse pressure softening around your areola before latching, apply cold compresses between feedings to reduce swelling, and nurse on demand. If a hard red wedge appears with chills or fever, contact your doctor for mastitis.',
        questionForDoctor: 'Could a certified lactation consultant evaluate baby’s latch to ensure full breast drainage?',
      );
    }

    if (q.contains('hair') || q.contains('shed') || q.contains('hair loss') || q.contains('telogen')) {
      return const PostpartumSymptomReassuranceResult(
        category: 'normal',
        badgeLabel: 'Telogen Effluvium (Temporary)',
        colorHex: '#0D9488',
        summary: 'Postpartum hair shedding is completely normal and temporary, typically starting around months 2-4 postpartum.',
        reasoning: 'High pregnancy estrogen kept hairs in prolonged growth phase. The postpartum hormonal normalization causes all those hairs to shed simultaneously.',
        guidance: 'Hair density almost always recovers fully by 9-12 months. Continue prenatal/postnatal vitamins, eat protein and iron-rich foods, and avoid tight hairstyles or heat styling.',
        questionForDoctor: 'Should we check my ferritin and thyroid levels if hair shedding feels unusually heavy?',
      );
    }

    if (q.contains('heav') || q.contains('prolapse') || q.contains('bulge') || q.contains('pressure') || q.contains('pelvic floor')) {
      return const PostpartumSymptomReassuranceResult(
        category: 'caution',
        badgeLabel: 'Pelvic Floor Strain • Rest Horizontally',
        colorHex: '#D97706',
        summary: 'A heavy, dragging sensation in your pelvis is common in early postpartum due to stretched pelvic floor muscles and ligament laxity.',
        reasoning: 'Relaxin hormone remains in your tissues for months, and downward intra-abdominal pressure can cause heaviness before muscles regain tone.',
        guidance: 'Lie flat horizontally to remove gravity from your pelvis. Avoid prolonged standing, heavy lifting, or straining. Request a pelvic floor physical therapy referral at your 6-week check.',
        questionForDoctor: 'Can you refer me to a pelvic floor physical therapist for a postpartum evaluation?',
      );
    }

    return PostpartumSymptomReassuranceResult(
      category: 'normal',
      badgeLabel: 'Postpartum Recovery Shift',
      colorHex: '#0D9488',
      summary: 'Your body is navigating an intense 4th trimester transformation. Most physical sensations reflect active tissue and hormonal healing.',
      reasoning: 'Pelvic, hormonal, and muscular systems require 6 to 12 months for comprehensive physiological restoration.',
      guidance: 'Listen to your body’s signals for horizontal rest, keep hydration high, and never hesitate to contact your maternity triage line if something feels off.',
      questionForDoctor: 'Is this symptom expected for my delivery type and recovery stage?',
    );
  }

  void _runTriage(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _activeQuery = trimmed;
      _loading = true;
      _result = null;
    });

    final res = _localSymptomTriage(trimmed, widget.daysSinceBirth);
    setState(() {
      _result = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5DDD5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.health_and_safety_outlined, color: Color(0xFF0D9488), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Is this normal postpartum?',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF221510),
                          ),
                        ),
                        Text(
                          'Clinical reassurance for physical & emotional shifts',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: const Color(0xFF7A6B72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF7A6B72)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEFE8E0)),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEFE8E0)),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Search lochia, night sweats, afterpains, stitches...',
                        hintStyle: GoogleFonts.manrope(fontSize: 12.5, color: const Color(0xFF7A6B72)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFDD0D22), size: 20),
                        suffixIcon: (_controller.text.isNotEmpty || _result != null)
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF7A6B72)),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: _runTriage,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_result == null && !_loading) ...[
                    Text(
                      'COMMON RECOVERY SYMPTOMS',
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFDD0D22),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickSuggestions.map((s) => ActionChip(
                        label: Text(s, style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF221510))),
                        backgroundColor: const Color(0xFFFAF7F2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(0xFFEFE8E0)),
                        ),
                        onPressed: () {
                          _controller.text = s;
                          _runTriage(s);
                        },
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F6F0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEFE8E0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.favorite_outline, color: Color(0xFFDD0D22), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'A Reassuring Note for You',
                                style: GoogleFonts.cormorantGaramond(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF221510)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your body carried life for nearly 10 months and underwent an immense physiological delivery. Giving yourself grace, horizontal rest, and asking questions is the healthiest thing you can do for yourself and your baby.',
                            style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72), height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFFDD0D22))),
                    ),
                  if (_result != null && !_loading) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEFE8E0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06221510), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(int.parse(_result!.colorHex.replaceFirst('#', '0xFF'))).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _result!.badgeLabel.toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(int.parse(_result!.colorHex.replaceFirst('#', '0xFF'))),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _activeQuery ?? 'Recovery Check',
                            style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF221510)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _result!.summary,
                            style: GoogleFonts.manrope(fontSize: 13, height: 1.45, fontWeight: FontWeight.w600, color: const Color(0xFF221510)),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.psychology_outlined, size: 16, color: Color(0xFFDD0D22)),
                                    const SizedBox(width: 6),
                                    Text('Why This Happens', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF221510))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(_result!.reasoning, style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF7A6B72), height: 1.4)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFBF1).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.spa_outlined, size: 16, color: Color(0xFF0D9488)),
                                    const SizedBox(width: 6),
                                    Text('Gentle Actions You Can Take', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(_result!.guidance, style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF221510), height: 1.4)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFEFE8E0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: _clearSearch,
                                  child: Text('← Back to guide', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF7A6B72))),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDD0D22),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () {
                                    final q = _activeQuery ?? 'postpartum recovery';
                                    Navigator.pop(context);
                                    openDocsyWith(context, 'I want to ask about postpartum symptoms regarding $q: ${_result!.summary}');
                                  },
                                  child: Text('💬 Discuss with Docsy →', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// PEACE OF MIND: LACTATION & MEDICATION SAFETY CHECKER
// ─────────────────────────────────────────────────────────────────────
class PostpartumLactationSafetyResult {
  final String query;
  final String status; // 'safe', 'caution', 'avoid'
  final String badge;
  final String colorHex;
  final String summary;
  final String reasoning;
  final String safeAlternative;
  final String docQuestion;

  const PostpartumLactationSafetyResult({
    required this.query,
    required this.status,
    required this.badge,
    required this.colorHex,
    required this.summary,
    required this.reasoning,
    required this.safeAlternative,
    required this.docQuestion,
  });
}

class _PostpartumLactationSafetySheet extends StatefulWidget {
  final int daysSinceBirth;
  final String feedingMethod;
  final String? initialQuery;

  const _PostpartumLactationSafetySheet({
    required this.daysSinceBirth,
    required this.feedingMethod,
    this.initialQuery,
  });

  @override
  State<_PostpartumLactationSafetySheet> createState() => _PostpartumLactationSafetySheetState();
}

class _PostpartumLactationSafetySheetState extends State<_PostpartumLactationSafetySheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery ?? '');
  PostpartumLactationSafetyResult? _result;
  bool _loading = false;

  final List<String> _quickSuggestions = [
    'Ibuprofen',
    'Paracetamol / Tylenol',
    'Sudafed / Cold meds',
    'Coffee / Caffeine',
    'Fenugreek',
    'Peppermint tea',
    'Antibiotics (Amoxicillin)',
    'Wine / Alcohol',
    'Sushi & Fish',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _runCheck(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
      _result = null;
      _loading = false;
    });
  }

  PostpartumLactationSafetyResult _localLactationCheck(String query) {
    final q = query.toLowerCase();

    if (q.contains('ibuprofen') || q.contains('advil') || q.contains('motrin') || q.contains('brufen')) {
      return const PostpartumLactationSafetyResult(
        query: 'Ibuprofen',
        status: 'safe',
        badge: 'Safe While Nursing',
        colorHex: '#0D9488',
        summary: 'Ibuprofen is the preferred first-line analgesic and anti-inflammatory relief during lactation.',
        reasoning: 'Extremely low excretion into breast milk (less than 1% of maternal dose). Safe for both perineal and C-section healing.',
        safeAlternative: 'Take with food or water. Paracetamol is also a compatible alternative.',
        docQuestion: 'What is the recommended dosing interval for my postpartum recovery pain?',
      );
    }

    if (q.contains('paracetamol') || q.contains('acetaminophen') || q.contains('tylenol') || q.contains('crocin') || q.contains('panadol')) {
      return const PostpartumLactationSafetyResult(
        query: 'Paracetamol / Acetaminophen',
        status: 'safe',
        badge: 'Safe While Nursing',
        colorHex: '#0D9488',
        summary: 'Paracetamol is safe and fully compatible with breastfeeding at standard therapeutic doses.',
        reasoning: 'Only minute amounts pass into breast milk, far below therapeutic doses prescribed directly to infants.',
        safeAlternative: 'Can be alternated with Ibuprofen under medical guidance for multi-modal analgesia.',
        docQuestion: 'Can I alternate Paracetamol with Ibuprofen for post-delivery discomfort?',
      );
    }

    if (q.contains('aspirin') || q.contains('disprin') || q.contains('ecotrin')) {
      return const PostpartumLactationSafetyResult(
        query: 'Aspirin',
        status: 'avoid',
        badge: 'Avoid While Nursing',
        colorHex: '#DD0D22',
        summary: 'Standard or high-dose aspirin should be avoided while breastfeeding.',
        reasoning: 'Salicylates pass into milk and carry theoretical risks of metabolic acidosis and Reye’s syndrome in nursing infants.',
        safeAlternative: 'Use Ibuprofen or Paracetamol for postpartum aches, fever, or pain instead.',
        docQuestion: 'Is a safer alternative available for my indication while nursing?',
      );
    }

    if (q.contains('sudafed') || q.contains('pseudoephedrine') || q.contains('decongestant') || q.contains('cold')) {
      return const PostpartumLactationSafetyResult(
        query: 'Sudafed / Pseudoephedrine',
        status: 'avoid',
        badge: 'Avoid / Reduces Supply',
        colorHex: '#DD0D22',
        summary: 'Avoid oral pseudoephedrine if you wish to protect and maintain your breast milk supply.',
        reasoning: 'Pseudoephedrine suppresses prolactin release and has been shown to reduce milk supply by up to 24% after even a single dose.',
        safeAlternative: 'Use saline nasal sprays, facial steam inhalation, honey with lemon, or topical nasal sprays.',
        docQuestion: 'What non-decongestant cold remedy will not lower my milk supply?',
      );
    }

    if (q.contains('fenugreek') || q.contains('methi') || q.contains('milk tea')) {
      return const PostpartumLactationSafetyResult(
        query: 'Fenugreek',
        status: 'caution',
        badge: 'Use Caution / Monitor',
        colorHex: '#D97706',
        summary: 'Use caution with Fenugreek supplements. It can cause infant and maternal digestive upset.',
        reasoning: 'Clinical evidence is mixed; it frequently causes gas, loose stools, and cramps in infants, and can interact with thyroid medications.',
        safeAlternative: 'Prioritize frequent milk removal (skin-to-skin, demand feeds, power pumping), hydration, oats, and moringa instead.',
        docQuestion: 'Would an evaluation by an IBCLC help my milk supply before taking herbal supplements?',
      );
    }

    if (q.contains('coffee') || q.contains('caffeine') || q.contains('espresso') || q.contains('tea')) {
      return const PostpartumLactationSafetyResult(
        query: 'Coffee / Caffeine',
        status: 'caution',
        badge: 'Moderate (1-2 Cups)',
        colorHex: '#D97706',
        summary: 'Moderate caffeine (up to 200–300 mg / about 2 standard cups) is considered safe while nursing.',
        reasoning: 'Less than 1% of caffeine reaches milk, but young newborns metabolize it slowly. High intake can cause infant fussiness and wakefulness.',
        safeAlternative: 'Drink your coffee immediately after a nursing session so maternal peak blood levels drop before the next feed.',
        docQuestion: 'Does my baby show any signs of caffeine sensitivity, especially during the newborn weeks?',
      );
    }

    if (q.contains('alcohol') || q.contains('wine') || q.contains('beer') || q.contains('cocktail')) {
      return const PostpartumLactationSafetyResult(
        query: 'Alcohol / Wine / Beer',
        status: 'caution',
        badge: 'Timing Essential',
        colorHex: '#D97706',
        summary: 'Alcohol passes into milk at blood levels. Wait at least 2 hours per standard drink before nursing.',
        reasoning: 'Alcohol impairs the milk letdown reflex and alters infant sleep. Pumping and dumping does not speed elimination—only time clears alcohol.',
        safeAlternative: 'Nurse immediately before having a single standard drink, or offer previously expressed milk.',
        docQuestion: 'What is the safest guidance on social alcohol timing for my feeding routine?',
      );
    }

    if (q.contains('peppermint') || q.contains('sage') || q.contains('spearmint')) {
      return const PostpartumLactationSafetyResult(
        query: 'Peppermint & Sage',
        status: 'caution',
        badge: 'May Lower Supply',
        colorHex: '#D97706',
        summary: 'High culinary or concentrated herbal amounts of peppermint and sage can decrease breast milk production.',
        reasoning: 'Menthol and thujone compounds can inhibit lactation and are clinically used intentionally when mothers want to wean.',
        safeAlternative: 'Chamomile, ginger, rooibos, or fruit teas are gentle and supply-friendly.',
        docQuestion: 'Could my consumption of herbal teas be affecting my daily pumping output?',
      );
    }

    if (q.contains('amoxicillin') || q.contains('augmentin') || q.contains('antibiotic') || q.contains('keflex')) {
      return const PostpartumLactationSafetyResult(
        query: 'Amoxicillin / Postpartum Antibiotics',
        status: 'safe',
        badge: 'Safe With Guidance',
        colorHex: '#0D9488',
        summary: 'Standard penicillins and cephalosporins are safe and first-line for postpartum infections and mastitis.',
        reasoning: 'Negligible milk transfer. Very safe for the infant, though baby may occasionally have looser stools or temporary mild diaper rash.',
        safeAlternative: 'Take prescribed infant probiotics or maternal probiotics if your baby experiences digestive sensitivity.',
        docQuestion: 'Should I give infant probiotics while completing my prescribed antibiotic course?',
      );
    }

    if (q.contains('sushi') || q.contains('fish') || q.contains('salmon') || q.contains('tuna')) {
      return const PostpartumLactationSafetyResult(
        query: 'Sushi & Fish While Nursing',
        status: 'safe',
        badge: 'Safe (Watch Mercury)',
        colorHex: '#0D9488',
        summary: 'Fresh sushi is safe while breastfeeding! Food poisoning bacteria do not pass into breast milk.',
        reasoning: 'Unlike pregnancy, Listeria does not cross into milk. Simply avoid high-mercury apex predators (swordfish, shark, bigeye tuna). Cooked or raw salmon is rich in DHA which enriches breast milk.',
        safeAlternative: 'Salmon, shrimp, pollack, and canned light tuna are excellent low-mercury, high-DHA choices.',
        docQuestion: 'What are the best DHA-rich fish options for enriching breast milk?',
      );
    }

    return PostpartumLactationSafetyResult(
      query: query,
      status: 'caution',
      badge: 'Consult Lactation Guidance',
      colorHex: '#D97706',
      summary: 'Most medications have safe nursing-friendly alternatives. Check LactMed or ask your pediatrician before taking.',
      reasoning: 'Infant age, health status, and maternal dosage determine milk transfer and safety.',
      safeAlternative: 'Paracetamol or Ibuprofen are standard first-line medications compatible with breastfeeding.',
      docQuestion: 'Is this substance compatible with breastfeeding for my baby?',
    );
  }

  Future<void> _runCheck(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _loading = true;
      _result = null;
    });

    final local = _localLactationCheck(trimmed);
    try {
      final res = await ApiPostpartumService.checkSafety(
        trimmed,
        daysSinceBirth: widget.daysSinceBirth,
        feedingMethod: widget.feedingMethod,
      );
      if (!mounted) return;
      if (res != null && res['data'] != null) {
        final d = Map<String, dynamic>.from(res['data'] as Map);
        setState(() {
          _result = PostpartumLactationSafetyResult(
            query: d['query']?.toString() ?? trimmed,
            status: d['status']?.toString() ?? 'caution',
            badge: d['badge']?.toString() ?? 'Lactation Guidance',
            colorHex: d['colorHex']?.toString() ?? '#D97706',
            summary: d['summary']?.toString() ?? '',
            reasoning: d['reasoning']?.toString() ?? '',
            safeAlternative: d['safeAlternative']?.toString() ?? '',
            docQuestion: d['docQuestion']?.toString() ?? '',
          );
          _loading = false;
        });
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _result = local;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5DDD5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBE0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medication_liquid_outlined, color: Color(0xFFFF4A00), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Can I take or eat this while nursing?',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF221510),
                          ),
                        ),
                        Text(
                          'Lactation pharmacology & safety guide for mothers',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: const Color(0xFF7A6B72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF7A6B72)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEFE8E0)),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEFE8E0)),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Check medication, supplement, food, or herb...',
                        hintStyle: GoogleFonts.manrope(fontSize: 12.5, color: const Color(0xFF7A6B72)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFF4A00), size: 20),
                        suffixIcon: (_controller.text.isNotEmpty || _result != null)
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF7A6B72)),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: _runCheck,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_result == null && !_loading) ...[
                    Text(
                      'QUICK SAFETY LOOKUPS',
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFDD0D22),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickSuggestions.map((s) => ActionChip(
                        label: Text(s, style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF221510))),
                        backgroundColor: const Color(0xFFFAF7F2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(0xFFEFE8E0)),
                        ),
                        onPressed: () {
                          _controller.text = s;
                          _runCheck(s);
                        },
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F6F0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEFE8E0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFFF4A00), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Core Lactation Principle',
                                style: GoogleFonts.cormorantGaramond(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF221510)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Most medications transfer into breast milk in amounts far below therapeutic infant levels (relative infant dose < 10%). However, always take medicines right after nursing, and avoid oral decongestants (Sudafed) that suppress prolactin and milk supply.',
                            style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72), height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFFDD0D22))),
                    ),
                  if (_result != null && !_loading) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEFE8E0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06221510), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(int.parse(_result!.colorHex.replaceFirst('#', '0xFF'))).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _result!.badge.toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(int.parse(_result!.colorHex.replaceFirst('#', '0xFF'))),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _result!.query,
                            style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF221510)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _result!.summary,
                            style: GoogleFonts.manrope(fontSize: 13, height: 1.45, fontWeight: FontWeight.w600, color: const Color(0xFF221510)),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.science_outlined, size: 16, color: Color(0xFFFF4A00)),
                                    const SizedBox(width: 6),
                                    Text('Clinical Reasoning & Milk Transfer', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF221510))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(_result!.reasoning, style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF7A6B72), height: 1.4)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFBF1).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF0D9488)),
                                    const SizedBox(width: 6),
                                    Text('Safe Alternative or Timing Guidance', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(_result!.safeAlternative, style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF221510), height: 1.4)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.help_outline, size: 16, color: Color(0xFF7209B7)),
                                    const SizedBox(width: 6),
                                    Text('Question for Pediatrician / IBCLC', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF7209B7))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(_result!.docQuestion, style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF221510), height: 1.4)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFEFE8E0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: _clearSearch,
                                  child: Text('← Back to guide', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF7A6B72))),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDD0D22),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () {
                                    final q = _result!.query;
                                    Navigator.pop(context);
                                    openDocsyWith(context, 'I have questions about breastfeeding/lactation safety for $q: ${_result!.summary}. Can you advise?');
                                  },
                                  child: Text('💬 Discuss with Docsy →', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

