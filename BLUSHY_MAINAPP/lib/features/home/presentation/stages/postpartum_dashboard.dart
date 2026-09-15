import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/state.dart';
import '../../../../services/api_contract_client.dart';
import '../../../../services/api_postpartum_service.dart';
import '../../../sia/open_docsy.dart';
import '../doctor_summary_screen.dart';
import 'stage_shared_components.dart';
import '../../../../shared/stage_empty_notice.dart';
import '../../../../shared/user_display_name.dart';
import '../../widgets/log_symptoms_section.dart';
import '../../../../l10n/app_localizations.dart';

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

class _PostpartumDashboardState extends State<PostpartumDashboard> {
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

  final TextEditingController _docsyInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPostpartumData();
  }

  @override
  void dispose() {
    _nursingTimer?.cancel();
    _internalScrollController.dispose();
    _docsyInputController.dispose();
    super.dispose();
  }

  Future<void> _loadPostpartumData() async {
    final overviewRes = await ApiPostpartumService.getOverview();
    final briefRes = await ApiPostpartumService.getTodayBrief();

    if (!mounted) return;
    final overview = overviewRes.data;
    final brief = briefRes.data;
    setState(() {
      _overview = overview;
      _todayBrief = brief;
      _overviewState = overviewRes.state;
      _isLowEnergyMode = overview?.isLowEnergyMode ?? false;
      _isLoading = false;

      // Seed current checkin values if present
      if (overview?.todayCheckin != null) {
        final chk = overview!.todayCheckin!;
        _physicalComfort = chk['physicalComfort']?.toString();
        _mood = chk['mood']?.toString();
        _todayFeels = chk['todayFeels']?.toString();
        _energy = chk['energy']?.toString();
        _needRightNow = chk['needRightNow']?.toString();
        _painScore = (chk['painScore'] as num?)?.toInt() ?? 2;
        _bleedingLevel = chk['bleedingLevel']?.toString() ?? 'moderate';
        _sleepHours = (chk['sleepHours'] as num?)?.toDouble() ?? 5.0;
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

  // 02: TODAY WITH DOCSY ⭐ (Dynamic Real-Time AI Intelligence)
  Widget _buildTodayWithDocsyCard() {
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

    return Container(
      padding: const EdgeInsets.all(20),
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
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFECEB),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.auto_awesome, color: crimsonPrimary, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).ppTodayWithDocsy,
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: crimsonPrimary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(AppLocalizations.of(context).ppYour4thTrimesterCompanion,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
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
          const SizedBox(height: 14),
          Text(
            greeting,
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: textMain,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
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
            const SizedBox(height: 14),
          ],
          _buildBriefRow(Icons.spa_outlined, const Color(0xFF0D9488), 'Your Recovery', recovery),
          const SizedBox(height: 8),
          _buildBriefRow(Icons.child_care, const Color(0xFFF72585), 'Your Baby', baby),
          const SizedBox(height: 8),
          _buildBriefRow(Icons.visibility_outlined, const Color(0xFF2563EB), 'Something to Notice', notice),
          const SizedBox(height: 16),
          // Quick Ask Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _docsyInputController,
                    decoration: InputDecoration(
                      hintText: 'Ask Docsy about your recovery or baby...',
                      hintStyle: GoogleFonts.manrope(fontSize: 12.5, color: textMuted),
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
                  icon: const Icon(Icons.arrow_forward_rounded, color: crimsonPrimary, size: 20),
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
          const SizedBox(height: 14),
          // Dynamic Prompt Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pills.map((p) => ActionChip(
              label: Text(p, style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMain)),
              backgroundColor: const Color(0xFFFAF7F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
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

    final briefRes = await ApiPostpartumService.getTodayBrief();
    final overviewRes = await ApiPostpartumService.getOverview();

    if (!mounted) return;
    setState(() {
      _todayBrief = briefRes.data;
      _overview = overviewRes.data;
      _overviewState = overviewRes.state;
      _isSavingCheckin = false;
      _checkinSaved = true;
    });
  }

  // 04: WHAT MATTERS TODAY? (Dynamic Priorities Layer)
  Widget _buildWhatMattersToday() {
    final priorities = _overview?.priorities ?? [];
    final effectivePriorities = priorities.isNotEmpty ? priorities : [
      PostpartumPriority(
        id: 'p_rest',
        category: 'Horizontal Rest',
        icon: 'bed',
        headline: 'Prioritize Horizontal Healing',
        reason: 'Lying flat removes gravity pressure from pelvic floor and stitches. Take 15-minute horizontal breathers.',
        actionTag: 'Ask Docsy about rest pacing',
      ),
      PostpartumPriority(
        id: 'p_tissue',
        category: 'Tissue Healing',
        icon: 'spa',
        headline: 'Tissue Recovery & Hydration',
        reason: 'Hydrate generously (2.5L+) and keep protein intake high to support tissue synthesis and lactation.',
        actionTag: 'Explore hydration & meals',
      ),
    ];

    Color getPriorityColor(String id) {
      if (id.contains('rest')) return const Color(0xFF0D9488); // Emerald Teal
      if (id.contains('hydration') || id.contains('fluid')) return const Color(0xFF2563EB); // Cobalt Blue
      if (id.contains('blues') || id.contains('mood')) return const Color(0xFFD97706); // Warm Amber
      if (id.contains('tissue') || id.contains('incision')) return const Color(0xFF7209B7); // Royal Purple
      if (id.contains('feeding') || id.contains('nursing')) return const Color(0xFFF72585); // Vivid Magenta
      return crimsonPrimary;
    }

    Color getPriorityBg(String id) {
      if (id.contains('rest')) return const Color(0xFFCCFBF1);
      if (id.contains('hydration') || id.contains('fluid')) return const Color(0xFFDBEAFE);
      if (id.contains('blues') || id.contains('mood')) return const Color(0xFFFEF3C7);
      if (id.contains('tissue') || id.contains('incision')) return const Color(0xFFF3E8FF);
      if (id.contains('feeding') || id.contains('nursing')) return const Color(0xFFFFE5F0);
      return const Color(0xFFFFECEB);
    }

    IconData getPriorityIcon(String id) {
      if (id.contains('rest')) return Icons.bedtime_outlined;
      if (id.contains('hydration') || id.contains('fluid')) return Icons.water_drop_outlined;
      if (id.contains('blues') || id.contains('mood')) return Icons.self_improvement;
      if (id.contains('tissue') || id.contains('incision')) return Icons.spa_outlined;
      if (id.contains('feeding') || id.contains('nursing')) return Icons.child_care_outlined;
      return Icons.favorite_border;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(AppLocalizations.of(context).ppTodayIDPrioritize, style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 1.1)),
        ),
        const SizedBox(height: 10),
        ...effectivePriorities.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: getPriorityBg(p.id),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    getPriorityIcon(p.id),
                    color: getPriorityColor(p.id),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(p.headline, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold, color: textMain))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF5EFEB), borderRadius: BorderRadius.circular(6)),
                          child: Text(p.category, style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w700, color: textMuted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(p.reason, style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.4)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => openDocsyWith(context, 'Tell me more about why I should prioritize ${p.category} today.'),
                      child: Text(
                        '${p.actionTag} →',
                        style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.bold, color: crimsonPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // 05: WHAT CHANGED? & WHAT'S BEEN STEADY
  Widget _buildWhatChangedAndSteady() {
    final deltas = _overview?.deltas;
    final baseline = _overview?.baselineMaturity;
    final changes = deltas?.changes ?? [];
    final steady = deltas?.steady ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
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
              Text('WHAT CHANGED & WHAT\'S STEADY', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 1.1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                child: Text(baseline?['label']?.toString() ?? 'Building Baseline', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (changes.isNotEmpty) ...[
            Text(AppLocalizations.of(context).ppNoticedShifts, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: textMain)),
            const SizedBox(height: 6),
            ...changes.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.change_circle_outlined, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['detail']?.toString() ?? '', style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMain)),
                        const SizedBox(height: 2),
                        Text(c['context']?.toString() ?? '', style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (steady.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).ppWhatSBeenSteady, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: textMain)),
            const SizedBox(height: 6),
            ...steady.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF0D9488), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s, style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted))),
                ],
              ),
            )),
          ],
          if (changes.isEmpty && steady.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timeline_outlined, color: Color(0xFF0D9488), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context).ppObservingInitialBaseline,
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: textMain),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'You are in the initial recovery window. As you log check-ins, Docsy will surface your physical shifts alongside stabilizing factors here.',
                          style: GoogleFonts.manrope(fontSize: 11, color: textMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          InkWell(
            onTap: _openSomethingChangedAfterDialog,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insights, size: 18, color: crimsonPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Log a pattern: "Something changed after..."',
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: crimsonPrimary),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: crimsonPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 06: WHAT DO I NEED? ("I Need Help" SOS & Low-Energy Mode)
  Widget _buildWhatDoINeed() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Text('WHAT DO YOU NEED TODAY?', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 1.1)),
              const Icon(Icons.handshake_outlined, color: crimsonPrimary, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          // I Need Help SOS Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: crimsonPrimary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.send_rounded, color: crimsonPrimary, size: 18),
            label: Text('I NEED HELP TODAY (Generate Request)', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13, color: crimsonPrimary)),
            onPressed: _openHelpSosDialog,
          ),
          const SizedBox(height: 12),
          // Give me a break toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).ppIMDoneForToday, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: textMain)),
                    Text('Pause tracking, charts, and recommendations', style: GoogleFonts.manrope(fontSize: 10.5, color: textMuted)),
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
          const SizedBox(height: 16),
          // Evening "Tonight" checklist
          Text(AppLocalizations.of(context).ppTonightWindDown, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: textMain)),
          const SizedBox(height: 8),
          _buildChecklistItem('t1', 'Drink a large glass of water & electrolyte'),
          _buildChecklistItem('t2', 'Take prescribed vitamins / medications'),
          _buildChecklistItem('t3', 'Set up overnight feeding & diaper station'),
          _buildChecklistItem('t4', 'Hand off 1 overnight wake-up to your support circle'),
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

  // 07: HOW IS BABY? (Supportive Maternal Feeding & Sleep)
  Widget _buildHowIsBaby() {
    final babyEvents = _overview?.todayBabyEvents ?? [];
    final wetCount = babyEvents.where((e) => e['type'] == 'diaper' && e['details']?['kind'] == 'wet').length;
    final dirtyCount = babyEvents.where((e) => e['type'] == 'diaper' && e['details']?['kind'] == 'dirty').length;
    final feedCount = babyEvents.where((e) => e['type'] == 'feed').length;

    return Container(
      padding: const EdgeInsets.all(20),
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
              Text('BABY & YOU (NEWBORN RHYTHMS)', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 1.1)),
              const Icon(Icons.child_care_outlined, color: Color(0xFFF72585), size: 22),
            ],
          ),
          const SizedBox(height: 10),
          // Live Activity Summary Counters
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildEventCounterPill('💧 $wetCount Wet', const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
              _buildEventCounterPill('💩 $dirtyCount Soiled', const Color(0xFF92400E), const Color(0xFFFEF3C7)),
              _buildEventCounterPill('🍼 $feedCount Feeds', const Color(0xFF0D9488), const Color(0xFFCCFBF1)),
            ],
          ),
          const SizedBox(height: 14),
          // Live Nursing Stopwatch
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorderColor),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context).ppActiveNursingStopwatch, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: textMain)),
                    if (_activeNursingSide != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFFECEB), borderRadius: BorderRadius.circular(8)),
                        child: Text(_formatTimerSeconds(_nursingSeconds), style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: crimsonPrimary)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _activeNursingSide == 'Left' ? crimsonPrimary : Colors.white,
                          foregroundColor: _activeNursingSide == 'Left' ? Colors.white : textMain,
                          elevation: 0,
                          side: const BorderSide(color: cardBorderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _toggleNursingTimer('Left'),
                        icon: Icon(Icons.timer_outlined, size: 16, color: _activeNursingSide == 'Left' ? Colors.white : crimsonPrimary),
                        label: Text(_activeNursingSide == 'Left' ? 'Pause Left' : 'Left Breast', style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _activeNursingSide == 'Right' ? crimsonPrimary : Colors.white,
                          foregroundColor: _activeNursingSide == 'Right' ? Colors.white : textMain,
                          elevation: 0,
                          side: const BorderSide(color: cardBorderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _toggleNursingTimer('Right'),
                        icon: Icon(Icons.timer_outlined, size: 16, color: _activeNursingSide == 'Right' ? Colors.white : crimsonPrimary),
                        label: Text(_activeNursingSide == 'Right' ? 'Pause Right' : 'Right Breast', style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Diaper Count & Quick Log
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
        ],
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

  // 08: MY RECOVERY (Recovery Map & Lochia Staging)
  Widget _buildMyRecoveryMap() {
    final timing = _overview?.timing;
    final day = timing?.daysSinceBirth ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
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
              Text('WHERE AM I IN RECOVERY?', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 1.1)),
              const Icon(Icons.map_outlined, color: Color(0xFF0D9488), size: 20),
            ],
          ),
          const SizedBox(height: 14),
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
          // Lochia stages explanation (Interactive!)
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
                              day <= 4 ? 'Stage: Lochia Rubra (Dark Red)' : (day <= 14 ? 'Stage: Lochia Serosa (Pink/Brown)' : 'Stage: Lochia Alba (Yellow/White)'),
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
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context).ppDailyRecoveryProgression, style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          if ((_overview?.recentCheckins ?? []).isNotEmpty) ...[
            ...(_overview!.recentCheckins).take(4).map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
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
                      Text(c['date']?.toString() ?? 'Recent Day', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: textMain)),
                      const SizedBox(height: 2),
                      Text('Bleeding: ${c['bleedingLevel'] ?? 'Moderate'} • Pain: ${c['painScore'] ?? 2}/10', style: GoogleFonts.manrope(fontSize: 11, color: textMuted)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                    child: Text(c['mood']?.toString() ?? 'Okay', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
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
                'Complete your daily check-in above to track your lochia, pain score, and emotional energy progression day by day.',
                style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted),
              ),
            ),
          ],
        ],
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

  // 09: MY CARE JOURNEY (Appointment Intelligence & Support Circle)
  Widget _buildMyCareJourney() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Text('APPOINTMENT & CARE INTELLIGENCE', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 1.1)),
              const Icon(Icons.assignment_ind_outlined, color: crimsonPrimary, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text('Prepare for your 6-Week Postnatal Review', style: GoogleFonts.cormorantGaramond(fontSize: 18, fontWeight: FontWeight.bold, color: textMain)),
          const SizedBox(height: 4),
          Text('Blushy synthesizes your logged pain, bleeding duration, and emotional history into a structured clinical summary for your OB/GYN or midwife.', style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.4)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: crimsonPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorSummaryScreen())),
              icon: const Icon(Icons.summarize_outlined, size: 18),
              label: Text(AppLocalizations.of(context).ppBuildDoctorSummary, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // 10: LEARN WHEN RELEVANT ("Can I Do This Yet?" + Micro-Reads)
  Widget _buildLearnWhenRelevant() {
    final guides = _overview?.canIDoThisYet ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
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
              Text('CAN I DO THIS YET? (EVIDENCE GUIDANCE)', style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 1.1)),
              const Icon(Icons.help_outline, color: Color(0xFF7209B7), size: 20),
            ],
          ),
          const SizedBox(height: 12),
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
      ),
    );
  }

  // 11: 🚨 PERMANENT SAFETY INTERRUPT / ACTION ("Something Feels Wrong")
  Widget _buildSafetyShieldCard() {
    return InkWell(
      onTap: _openSafetyTriageDialog,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFECEB),
          borderRadius: BorderRadius.circular(14),
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
                  Text('SOMETHING DOESN\'T FEEL RIGHT?', style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 0.8)),
                  Text('Tap for immediate clinical triage (bleeding, headache, fever, pain).', style: GoogleFonts.manrope(fontSize: 11, color: textMain)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: crimsonPrimary, size: 14),
          ],
        ),
      ),
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
                    // 02: HOW ARE YOU TODAY? (Hero Maternal Check-in) ⭐
                    _buildHowAreYouCheckIn(),
                    const SizedBox(height: 20),

                    // 03: TODAY WITH DOCSY (AI Daily Companion Reflection) ⭐
                    _buildTodayWithDocsyCard(),
                    const SizedBox(height: 22),
                    const LogSymptomsSection(stageKey: 'postpartum'),
                    const SizedBox(height: 20),

                    // 04: WHAT MATTERS TODAY? (Dynamic Priorities)
                    _buildWhatMattersToday(),
                    const SizedBox(height: 20),

                    // 05: WHAT CHANGED? & WHAT'S BEEN STEADY (Longitudinal Intelligence)
                    _buildWhatChangedAndSteady(),
                    const SizedBox(height: 20),

                    // 06: WHAT DO I NEED? ("I Need Help" SOS & Tonight Wind-down)
                    _buildWhatDoINeed(),
                    const SizedBox(height: 20),

                    // 07: HOW IS BABY? (Supportive Maternal Tracking)
                    _buildHowIsBaby(),
                    const SizedBox(height: 20),

                    // 08: MY RECOVERY (Recovery Map, Lochia Staging & Daily Timeline)
                    _buildMyRecoveryMap(),
                    const SizedBox(height: 20),

                    // 09: MY CARE JOURNEY (Doctor Summary & 6-Wk Postnatal Review)
                    _buildMyCareJourney(),
                    const SizedBox(height: 20),

                    // 10: LEARN WHEN RELEVANT ("Can I do this yet?" Evidence Guidance)
                    _buildLearnWhenRelevant(),
                    const SizedBox(height: 20),

                    // 11: 🚨 SOMETHING DOESN'T FEEL RIGHT? (Always Available Clinical Triage)
                    _buildSafetyShieldCard(),
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
