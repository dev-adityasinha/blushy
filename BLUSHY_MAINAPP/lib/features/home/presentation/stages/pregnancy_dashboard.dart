import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/state.dart';
import '../../../../core/storage.dart';
import '../../../../services/api_contract_client.dart';
import '../../../../services/api_pregnancy_service.dart';
import '../../view_models/pregnancy_view_model.dart';
import '../../../../shared/live_refresh.dart';
import '../doctor_summary_screen.dart';
import 'stage_shared_components.dart';
import '../../../../shared/stage_empty_notice.dart';
import '../../../../shared/user_display_name.dart';
import '../../widgets/log_symptoms_section.dart';
import 'health_library_section.dart';
import 'pregnancy_health_section.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/user_state_store.dart';

class PregnancyDashboard extends StatefulWidget {
  final bool isNested;
  final ScrollController? scrollController;

  const PregnancyDashboard({
    super.key,
    this.isNested = false,
    this.scrollController,
  });

  @override
  State<PregnancyDashboard> createState() => _PregnancyDashboardState();
}

class _PregnancyDashboardState extends State<PregnancyDashboard>
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

  // ─── Real-Time Dynamic Pregnancy State ─────────────────────────────
  // There was no loading flag at all: the dashboard rendered its empty
  // shell immediately and the real figures appeared later, so a slow
  // response looked like a pregnancy with no data rather than one still
  // loading (spec sections 4 and 31).
  bool _isLoading = true;
  /// The server's own verdict on the last load (spec §4, §31).
  ApiState _overviewState = ApiState.loading;
  PregnancyOverviewData? _overview;
  PregnancyTodayBriefData? _todayBrief;
  Map<String, dynamic>? _baselineData;
  List<Map<String, dynamic>> _memories = [];
  List<Map<String, dynamic>> _questions = [];

  /// This screen is the View; the data load lives in the tested
  /// PregnancyViewModel and is mirrored back by _onDataChanged.
  final PregnancyViewModel _vm = PregnancyViewModel();

  // ─── Interactive Dashboard Controls ────────────────────────────────
  String? _selectedMode;
  String _maternalViewTab = 'body'; // 'body' (Maternal-First) vs 'baby'
  final TextEditingController _docsyInputController = TextEditingController();

  // ─── Daily Check-In State (Maternal Vitals & Symptoms) ──────────────
  int? _nauseaScore;
  int? _energyScore;
  int? _sleepScore;
  int? _moodScore;
  int _waterGlasses = 0;
  bool _hasLoggedToday = false;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onDataChanged);
    _rehydrateLocalState();
    _loadAllPregnancyData();
    startLiveRefresh();
  }

  @override
  Future<void> refreshNow() => _loadAllPregnancyData();

  @override
  void dispose() {
    stopLiveRefresh();
    _vm.removeListener(_onDataChanged);
    _vm.dispose();
    _docsyInputController.dispose();
    _internalScrollController.dispose();
    super.dispose();
  }

  // ─── Due Date Configuration ─────────────────────────────────────────
  Future<void> _promptSetDueDate() async {
    final now = DateTime.now();
    final initial = now.add(const Duration(days: 140));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 280)),
      lastDate: now.add(const Duration(days: 300)),
      helpText: 'Select Your Estimated Due Date',
      confirmText: 'Save Due Date',
    );

    if (picked != null) {
      if (!mounted) return;
      final osState = BlushyOSProvider.of(context);
      final currentPc = osState.personalContext;
      osState.updatePersonalContext(
        currentPc.copyWith(
          dueDate: picked,
          lifeStage: 'pregnancy',
        ),
      );
      await _loadAllPregnancyData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Estimated due date saved! Timeline calibrated ❤️',
            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          backgroundColor: textMain,
        ),
      );
    }
  }

  // ─── Rehydration & Backend Sync ─────────────────────────────────────
  void _rehydrateLocalState() {
    try {
      final todayStr = DateTime.now().toIso8601String().sliceSafe(0, 10);
      final savedCheckin = UserStateStore.read('pregnancy_last_checkin');
      if (savedCheckin.isNotEmpty && savedCheckin['date'] == todayStr) {
        _hasLoggedToday = true;
        if (savedCheckin['nausea'] != null) _nauseaScore = (savedCheckin['nausea'] as num).toInt();
        if (savedCheckin['energy'] != null) _energyScore = (savedCheckin['energy'] as num).toInt();
        if (savedCheckin['sleep'] != null) _sleepScore = (savedCheckin['sleep'] as num).toInt();
        if (savedCheckin['mood'] != null) _moodScore = (savedCheckin['mood'] as num).toInt();
        if (savedCheckin['waterGlasses'] != null) _waterGlasses = (savedCheckin['waterGlasses'] as num).toInt();
        if (savedCheckin['mode'] != null && savedCheckin['mode'].toString().isNotEmpty && savedCheckin['mode'] != 'default') {
          _selectedMode = savedCheckin['mode'].toString();
        }
      }

      final savedQ = BlushyStorage.read('pregnancy_questions.json');
      if (savedQ['items'] is List) {
        _questions = (savedQ['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }

      final savedMem = BlushyStorage.read('pregnancy_memories.json');
      if (savedMem['items'] is List) {
        _memories = (savedMem['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _loadAllPregnancyData() async {
    // `get`, not `BlushyOSProvider.of`: initState calls this and everything
    // before the first await runs inside it, so a registering lookup would
    // assert. Only the due date is read and it need not be reactive.
    final pc = context
        .getInheritedWidgetOfExactType<BlushyOSProvider>()
        ?.notifier
        ?.personalContext;
    final dueDateStr = pc?.dueDate?.toIso8601String().sliceSafe(0, 10);
    await _vm.load(dueDate: dueDateStr, mode: _selectedMode);
  }

  /// The View reacting to its ViewModel. Memories and questions are only
  /// overwritten when the server returned some, so a local rehydration is kept.
  void _onDataChanged() {
    if (!mounted) return;
    setState(() {
      _overviewState = _vm.overviewState;
      if (_vm.overview != null) _overview = _vm.overview;
      if (_vm.todayBrief != null) _todayBrief = _vm.todayBrief;
      if (_vm.baselineData != null) _baselineData = _vm.baselineData;
      if (_vm.memories != null) _memories = _vm.memories!;
      if (_vm.questions != null) _questions = _vm.questions!;
      _isLoading = _vm.isLoading;
    });
  }

  Future<void> _submitDailyCheckIn() async {
    final payload = {
      'date': DateTime.now().toIso8601String().sliceSafe(0, 10),
      'nausea': _nauseaScore ?? 2,
      'energy': _energyScore ?? 3,
      'sleep': _sleepScore ?? 3,
      'mood': _moodScore ?? 3,
      'waterGlasses': _waterGlasses,
      'mode': _selectedMode ?? 'default',
    };

    // Optimistic local update
    try {
      UserStateStore.write('pregnancy_last_checkin', payload);
    } catch (_) {}

    final messenger = ScaffoldMessenger.of(context);
    await ApiPregnancyService.submitCheckIn(payload);

    // Refresh baseline through the view model; _onDataChanged mirrors it.
    await _vm.refreshBaseline();
    if (!mounted) return;
    setState(() => _hasLoggedToday = true);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Daily check-in saved. Baseline updated ❤️',
          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        backgroundColor: textMain,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onSelectPregnancyMode(String mode) async {
    final newMode = (_selectedMode == mode) ? null : mode;
    setState(() => _selectedMode = newMode);
    final pc = BlushyOSProvider.of(context).personalContext;
    final dueDateStr = pc.dueDate?.toIso8601String().sliceSafe(0, 10);

    final res = await ApiPregnancyService.getTodayBrief(dueDate: dueDateStr, mode: newMode);
    if (!mounted) return;
    if (res.data != null) {
      setState(() => _todayBrief = res.data);
    }
  }

  // ─── Modal Openers ─────────────────────────────────────────────────

  void _openTeachMeSheet(Map<String, dynamic> topic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TeachMeIn30SecondsSheet(
        topic: topic,
        onAddToDoctorQuestions: (q) {
          _addDoctorQuestion(q);
        },
      ),
    );
  }

  void _openAddMemoryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context).pregAddToPregnancyStory,
          style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: InputDecoration(
                hintText: 'e.g. Felt first kick tonight! ❤️',
                hintStyle: GoogleFonts.manrope(fontSize: 13, color: textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).pregCancel, style: GoogleFonts.manrope(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: crimsonPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                final mem = {
                  'title': text,
                  'date': DateTime.now().toIso8601String().sliceSafe(0, 10),
                  'week': _overview?.week,
                  'category': 'personal',
                };
                setState(() => _memories.insert(0, mem));
                await ApiPregnancyService.saveMemory(mem);
              }
            },
            child: Text(AppLocalizations.of(context).pregSaveMemory, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _addDoctorQuestion(String qText) async {
    final q = {
      'text': qText,
      'isForDoctor': true,
      'createdAt': DateTime.now().toIso8601String(),
    };
    setState(() => _questions.insert(0, q));
    await ApiPregnancyService.saveQuestion(q);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added to your Doctor Questions list 📋', style: GoogleFonts.manrope(fontSize: 12)),
        backgroundColor: textMain,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // UI BUILDERS (11 Sections in strict hierarchy)
  // ───────────────────────────────────────────────────────────────────

  // 01 — Editorial Greeting & Date
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

    final hasDueDate = pc.dueDate != null && _overview?.isDueDateConfigured == true;
    final week = _overview?.week;
    final day = _overview?.day;
    final trimester = _overview?.trimesterLabel ?? 'Pregnancy Journey';

    final subtitle = hasDueDate && week != null && day != null
        ? 'Week $week, Day $day • $trimester'
        : 'Your Pregnancy Journey • Due date not set';

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
        ],
      ),
    );
  }

  // 02 — Today with Docsy (Today's Pregnancy Brief ⭐)
  Widget _buildTodaysPregnancyBrief() {
    final brief = _todayBrief;
    final yourBody = brief?.yourBody ?? 'Your body is adjusting gracefully to baby’s pace.';
    final yourBaby = brief?.yourBaby ?? 'Sensory and neuromuscular development progressing.';
    final oneThing = brief?.oneThingToKnow ?? 'Mild stretching sensations are normal as tissues relax.';
    final oneAction = brief?.oneThingToDo ?? 'Take 5 minutes for gentle stretches or deep breathing.';
    final prompts = brief?.suggestedPrompts ?? [
      'Is lower back pain normal?',
      'Safe sleeping positions',
      'What foods boost iron?',
      'How to know baby is head down'
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: cardRadius,
        border: Border.all(color: cardBorderColor, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08221510),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFECEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: crimsonPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(AppLocalizations.of(context).pregTodayWithDocsy,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: crimsonPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEE9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  brief?.gestationalDisplay ?? 'Pregnancy Brief',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Body highlight (Maternal-First)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEFE8E0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.favorite_rounded, color: Color(0xFFF72585), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context).pregYourBodyToday,
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: textMain),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        yourBody,
                        style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Baby highlight
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEFE8E0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.child_care_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context).pregBabyThisWeek,
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: textMain),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        yourBaby,
                        style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Micro actionable pairing
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).pregOneThingToKnow,
                      style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(oneThing, style: GoogleFonts.manrope(fontSize: 11.5, color: textMain, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).pregOneThingToDo,
                      style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(oneAction, style: GoogleFonts.manrope(fontSize: 11.5, color: textMain, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Search bar
          TextField(
            controller: _docsyInputController,
            style: GoogleFonts.manrope(fontSize: 13, color: textMain),
            decoration: InputDecoration(
              hintText: 'Ask Docsy about your pregnancy...',
              hintStyle: GoogleFonts.manrope(fontSize: 12, color: textMuted),
              filled: true,
              fillColor: const Color(0xFFFAF7F2),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(Icons.search, color: textMuted, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: crimsonPrimary, size: 18),
                onPressed: () {
                  final text = _docsyInputController.text.trim();
                  if (text.isNotEmpty) {
                    _docsyInputController.clear();
                    openAskSiaChat(context, text);
                  }
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEFE8E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEFE8E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: crimsonPrimary, width: 1.2),
              ),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                _docsyInputController.clear();
                openAskSiaChat(context, val.trim());
              }
            },
          ),
          const SizedBox(height: 12),

          // Quick Prompt Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prompts.map((prompt) {
              return InkWell(
                onTap: () => openAskSiaChat(context, prompt),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEFE8E0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 12, color: textMuted),
                      const SizedBox(width: 6),
                      Text(
                        prompt,
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: textMain),
                      ),
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

  // 03 — Gestational Anchor (Where am I?)
  Widget _buildGestationalAnchor() {
    final pc = BlushyOSProvider.of(context).personalContext;
    final ov = _overview;
    final isConfigured = ov?.isDueDateConfigured == true && pc.dueDate != null;

    if (!isConfigured) {
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
                Expanded(
                  child: Text(AppLocalizations.of(context).pregYourGestationalTimeline,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: crimsonPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEE9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(AppLocalizations.of(context).pregSetupRequired,
                    style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'When is your baby expected?',
              style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your estimated due date so Blushy can calculate your exact week, track baby\'s growth size, and guide your body day by day.',
              style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: crimsonPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                elevation: 0,
              ),
              onPressed: _promptSetDueDate,
              icon: const Icon(Icons.calendar_month, size: 16),
              label: Text(AppLocalizations.of(context).pregSetEstimatedDueDate, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final week = ov?.week ?? 1;
    final day = ov?.day ?? 0;
    final trimester = ov?.trimesterLabel ?? 'First Trimester';
    final fruit = ov?.babySizeName ?? 'Poppy Seed';
    final emoji = ov?.babySizeEmoji ?? '🌱';
    final lengthCm = ov?.babyLengthCm ?? 0.1;
    final weightG = ov?.babyWeightG ?? 0.1;
    final daysRemaining = ov?.daysRemaining ?? 280;
    final progress = (ov?.progressPercent ?? 0) / 100.0;
    final article = fruit.isNotEmpty && ['a', 'e', 'i', 'o', 'u'].contains(fruit.trim().toLowerCase()[0]) ? 'an' : 'a';

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
              Expanded(
                child: Text(AppLocalizations.of(context).pregYourGestationalTimeline,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: crimsonPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trimester,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D9488),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _promptSetDueDate,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.edit_calendar_outlined, size: 16, color: textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Counter + Baby Visual
          Row(
            children: [
              Expanded(
                flex: 65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                          height: 1.1,
                        ),
                        children: [
                          TextSpan(text: 'Week $week'),
                          TextSpan(
                            text: ' + $day days',
                            style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Baby is the size of $article $fruit',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Approx. $lengthCm cm • $weightG g',
                      style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 35,
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEFE8E0)),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 46),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Linear progress
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF3EEE9),
              valueColor: const AlwaysStoppedAnimation<Color>(crimsonPrimary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${(progress * 100).toInt()}% of journey completed',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w600, color: textMuted),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$daysRemaining days until due date',
                style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w700, color: crimsonPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 04 — How Are You Feeling? (Maternal Emotional & Physical Check-In)
  Widget _buildMaternalEmotionalCheckIn() {
    final hasInteracted = _nauseaScore != null || _energyScore != null || _sleepScore != null || _moodScore != null || _waterGlasses > 0;

    String actionLabel;
    Color actionColor;
    if (_hasLoggedToday) {
      actionLabel = 'Logged Today ✓';
      actionColor = const Color(0xFF0D9488);
    } else if (hasInteracted) {
      actionLabel = 'Save Log';
      actionColor = crimsonPrimary;
    } else {
      actionLabel = 'Tap circles to log';
      actionColor = textMuted;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context).pregDailyMaternalCheckIn,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: crimsonPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              InkWell(
                onTap: hasInteracted ? _submitDailyCheckIn : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    actionLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: actionColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Unboxed Circular Badges (STAGE1_DESIGN_RULES.md)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFeelingBadge(
                label: 'Nausea',
                sublabel: _scoreToLabel('nausea', _nauseaScore),
                icon: Icons.sick_outlined,
                accentColor: const Color(0xFFD97706),
                tintColor: const Color(0xFFFEF3C7),
                isSelected: _nauseaScore != null,
                onTap: () => _cycleScore('nausea'),
              ),
              const SizedBox(width: 14),
              _buildFeelingBadge(
                label: 'Energy',
                sublabel: _scoreToLabel('energy', _energyScore),
                icon: Icons.bolt_rounded,
                accentColor: const Color(0xFF0D9488),
                tintColor: const Color(0xFFCCFBF1),
                isSelected: _energyScore != null,
                onTap: () => _cycleScore('energy'),
              ),
              const SizedBox(width: 14),
              _buildFeelingBadge(
                label: 'Sleep',
                sublabel: _scoreToLabel('sleep', _sleepScore),
                icon: Icons.nightlight_round,
                accentColor: const Color(0xFF7209B7),
                tintColor: const Color(0xFFF3E8FF),
                isSelected: _sleepScore != null,
                onTap: () => _cycleScore('sleep'),
              ),
              const SizedBox(width: 14),
              _buildFeelingBadge(
                label: 'Mood',
                sublabel: _scoreToLabel('mood', _moodScore),
                icon: Icons.mood_rounded,
                accentColor: const Color(0xFFF72585),
                tintColor: const Color(0xFFFFE5F0),
                isSelected: _moodScore != null,
                onTap: () => _cycleScore('mood'),
              ),
              const SizedBox(width: 14),
              _buildFeelingBadge(
                label: 'Water',
                sublabel: _waterGlasses == 0 ? 'Tap to add' : '$_waterGlasses glasses',
                icon: Icons.water_drop_rounded,
                accentColor: const Color(0xFF2563EB),
                tintColor: const Color(0xFFDBEAFE),
                isSelected: _waterGlasses > 0,
                onTap: () {
                  setState(() {
                    _waterGlasses = (_waterGlasses >= 12) ? 0 : _waterGlasses + 1;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeelingBadge({
    required String label,
    required String sublabel,
    required IconData icon,
    required Color accentColor,
    required Color tintColor,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected ? tintColor : const Color(0xFFFAF7F2),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? accentColor.withValues(alpha: 0.5) : const Color(0xFFEFE8E0),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Icon(icon, color: isSelected ? accentColor : textMuted, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: textMain,
            ),
          ),
          Text(
            sublabel,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? accentColor : textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _scoreToLabel(String metric, int? score) {
    if (score == null) return 'Tap to log';
    final idx = (score - 1).clamp(0, 3);
    if (metric == 'nausea') {
      return ['None', 'Mild', 'Queasy', 'Strong'][idx];
    } else if (metric == 'energy') {
      return ['Exhausted', 'Low', 'Balanced', 'High'][idx];
    } else if (metric == 'sleep') {
      return ['Insomnia', 'Restless', 'Steady', 'Deep'][idx];
    } else {
      return ['Overwhelmed', 'Anxious', 'Calm', 'Excited'][idx];
    }
  }

  void _cycleScore(String metric) {
    setState(() {
      if (metric == 'nausea') _nauseaScore = (_nauseaScore == null) ? 2 : ((_nauseaScore! % 4) + 1);
      if (metric == 'energy') _energyScore = (_energyScore == null) ? 3 : ((_energyScore! % 4) + 1);
      if (metric == 'sleep') _sleepScore = (_sleepScore == null) ? 3 : ((_sleepScore! % 4) + 1);
      if (metric == 'mood') _moodScore = (_moodScore == null) ? 3 : ((_moodScore! % 4) + 1);
    });
  }

  // 05 — What Changed? & "My Normal" Baseline
  Widget _buildWhatChangedAndBaseline() {
    final isFirstTime = _baselineData?['isFirstTimeUser'] == true;
    final headline = _baselineData?['headline']?.toString() ?? 'My Normal & What Changed';
    final subtext = _baselineData?['subtext']?.toString() ?? 'Learning your unique pattern over daily check-ins.';
    final trendSynthesis = _baselineData?['trendSynthesis']?.toString() ??
        'Your daily checks calibrate your personal baseline and detect meaningful shifts.';
    final deltasList = (_baselineData?['deltas'] as List?) ?? [];

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
            children: [
              const Icon(Icons.analytics_outlined, color: crimsonPrimary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEE9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isFirstTime ? 'Calibrating Baseline' : 'Yesterday ➔ Today',
                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtext, style: GoogleFonts.manrope(fontSize: 12, color: textMuted)),
          const SizedBox(height: 16),

          // Delta pills
          if (deltasList.isNotEmpty)
            Row(
              children: deltasList.map((d) {
                final label = d['label']?.toString() ?? 'Metric';
                final indicator = d['indicator']?.toString() ?? '→ stable';
                final dir = d['direction']?.toString() ?? 'stable';
                final isHigher = dir == 'higher';
                final isLower = dir == 'lower';

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEFE8E0)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w700, color: textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          indicator,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isHigher
                                ? const Color(0xFFD97706)
                                : (isLower ? const Color(0xFF2563EB) : const Color(0xFF0D9488)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),

          // Trend synthesis
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_outlined, color: crimsonPrimary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trendSynthesis,
                    style: GoogleFonts.manrope(fontSize: 11.5, color: textMain, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => openAskSiaChat(context, "Explain my recent pregnancy symptom baseline and shifts."),
              icon: const Icon(Icons.arrow_forward, size: 14, color: crimsonPrimary),
              label: Text(AppLocalizations.of(context).pregExploreWithDocsy,
                style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800, color: crimsonPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 06 — "What's Happening to ME?" (Your Body & Baby This Week)
  Widget _buildWhatsHappeningToMe() {
    final isConfigured = _overview?.isDueDateConfigured == true;
    if (!isConfigured) {
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
            Text(AppLocalizations.of(context).pregWhatSHappeningThisWeek,
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: crimsonPrimary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Follow Your Body & Baby Week by Week',
              style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.bold, color: textMain),
            ),
            const SizedBox(height: 6),
            Text(
              'Blushy details anatomical milestones and maternal physiological shifts for each gestational week once your estimated due date is set.',
              style: GoogleFonts.manrope(fontSize: 12, color: textMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: crimsonPrimary,
                side: const BorderSide(color: crimsonPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: _promptSetDueDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 15),
              label: Text(AppLocalizations.of(context).pregSetDueDate, style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final maternalHighlights = _overview?.maternalBodyHighlights ?? [];
    final babyHighlights = _overview?.babyHighlights ?? [];

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(AppLocalizations.of(context).pregWhatSHappeningThisWeek,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: crimsonPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabToggle(
                    title: 'Your Body',
                    isActive: _maternalViewTab == 'body',
                    onTap: () => setState(() => _maternalViewTab = 'body'),
                  ),
                  const SizedBox(width: 6),
                  _buildTabToggle(
                    title: 'Baby Growth',
                    isActive: _maternalViewTab == 'baby',
                    onTap: () => setState(() => _maternalViewTab = 'baby'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content List
          Column(
            children: (_maternalViewTab == 'body' ? maternalHighlights : babyHighlights).map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _maternalViewTab == 'body' ? Icons.spa_outlined : Icons.check_circle_outline,
                      size: 16,
                      color: crimsonPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.toString(),
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          color: textMain,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: crimsonPrimary,
                side: const BorderSide(color: crimsonPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () {
                openAskSiaChat(
                  context,
                  _maternalViewTab == 'body'
                      ? "Why am I experiencing these maternal body changes this week?"
                      : "Explain baby's milestones for week ${_overview?.week ?? 1}.",
                );
              },
              child: Text(
                _maternalViewTab == 'body' ? 'Why am I feeling this? →' : 'Learn baby details →',
                style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabToggle({required String title, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? crimsonPrimary : const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? crimsonPrimary : const Color(0xFFEFE8E0)),
        ),
        child: Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : textMuted,
          ),
        ),
      ),
    );
  }

  // 07 — Pregnancy Modes ("I'm Having A...")
  Widget _buildPregnancyModes() {
    final modes = [
      {'id': 'default', 'label': '✨ Balanced Day'},
      {'id': 'nausea', 'label': '🤢 Bad Nausea'},
      {'id': 'sleep', 'label': '🥱 Rough Sleep'},
      {'id': 'back_pain', 'label': '⚡ Back Discomfort'},
      {'id': 'travel', 'label': '✈️ Travel Day'},
      {'id': 'anxious', 'label': '💭 Overwhelmed'},
    ];

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
            children: [
              const Icon(Icons.tune_rounded, color: crimsonPrimary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "I'M EXPERIENCING A...",
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Select your day's reality to adapt Docsy's care advice and comfort tips.",
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 14),

          // Mode Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: modes.map((m) {
              final id = m['id']!;
              final label = m['label']!;
              final isSelected = _selectedMode == id;

              return InkWell(
                onTap: () => _onSelectPregnancyMode(id),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? crimsonPrimary : const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? crimsonPrimary : const Color(0xFFEFE8E0)),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : textMain,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Mode Advice Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEFE8E0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.spa_rounded, color: crimsonPrimary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedMode == null
                        ? 'Tap a mode above whenever you are experiencing nausea, fatigue, travel, or discomfort to adapt your care plan.'
                        : (_todayBrief?.modeAdvice ?? 'Take things at your own comfortable pace today.'),
                    style: GoogleFonts.manrope(fontSize: 11.5, color: textMain, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 08 — Upcoming Care & Appointment Intelligence
  Widget _buildAppointmentIntelligence() {
    final nextScan = _overview?.isDueDateConfigured == true
        ? (_overview!.week != null && _overview!.week! < 22
            ? 'Comprehensive Anatomy Scan (Level II)'
            : 'Glucose Challenge Screening & Routine Panel')
        : 'Initial Prenatal Intake & Consultation';

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
              Expanded(
                child: Text(AppLocalizations.of(context).pregYourNextAppointment,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: crimsonPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_month_outlined, color: crimsonPrimary, size: 18),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            nextScan,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Keep your questions organized so you never leave the clinic wishing you had asked.',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 16),

          // Questions for Doctor preview
          if (_questions.isNotEmpty) ...[
            Text(
              'SAVED QUESTIONS FOR DOCTOR:',
              style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            ..._questions.take(3).map((q) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_box_outline_blank, size: 14, color: crimsonPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q['text']?.toString() ?? '',
                        style: GoogleFonts.manrope(fontSize: 11.5, color: textMain),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crimsonPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DoctorSummaryScreen()),
                  ),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: Text(AppLocalizations.of(context).pregBuildDoctorSummary,
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: crimsonPrimary,
                  side: const BorderSide(color: crimsonPrimary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                ),
                onPressed: () {
                  final textCtrl = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(AppLocalizations.of(context).pregAddDoctorQuestion,
                        style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      content: TextField(
                        controller: textCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Is back stiffness normal?',
                          hintStyle: GoogleFonts.manrope(fontSize: 12, color: textMuted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(AppLocalizations.of(context).pregCancel, style: GoogleFonts.manrope(color: textMuted)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary),
                          onPressed: () {
                            if (textCtrl.text.trim().isNotEmpty) {
                              _addDoctorQuestion(textCtrl.text.trim());
                              Navigator.pop(ctx);
                            }
                          },
                          child: Text(AppLocalizations.of(context).pregAdd),
                        ),
                      ],
                    ),
                  );
                },
                child: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 09 — Help Her This Week (Human Partner Co-Nesting)
  Widget _buildHumanPartnerCoNesting() {
    final partner = _overview?.partnerHelp;
    final tonight = partner?['tonight']?.toString() ?? 'Prepare a comforting, light dinner with fresh fruit.';
    final thisWeek = partner?['thisWeek']?.toString() ?? 'Take care of heavy grocery lifting and household errands.';
    final askHer = partner?['askHer']?.toString() ?? 'Do you want advice, or just a listening ear right now?';

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
              Expanded(
                child: Text(
                  'HELP HER THIS WEEK (PARTNER)',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: crimsonPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.favorite, color: crimsonPrimary, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Emotionally intelligent support cues tailored for your partner this week.',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 16),

          _buildPartnerItem('TONIGHT', tonight, Icons.bedtime_outlined),
          const SizedBox(height: 10),
          _buildPartnerItem('THIS WEEK', thisWeek, Icons.shopping_basket_outlined),
          const SizedBox(height: 10),
          _buildPartnerItem('ASK HER', askHer, Icons.forum_outlined),
          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFECEB),
                foregroundColor: crimsonPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () {
                final shareText = "Hey love ❤️ Here is how you can help me this week according to Blushy:\n\n"
                    "Tonight: $tonight\n"
                    "This week: $thisWeek\n"
                    "Ask me: \"$askHer\"";
                Share.share(shareText);
              },
              icon: const Icon(Icons.share, size: 14),
              label: Text(AppLocalizations.of(context).pregShareWithPartner,
                style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerItem(String badge, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFE8E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: crimsonPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge,
                  style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: GoogleFonts.manrope(fontSize: 11.5, color: textMain, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 10 — My Pregnancy Story (Intelligent Timeline)
  Widget _buildMyPregnancyStoryTimeline() {
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
              Expanded(
                child: Text(AppLocalizations.of(context).pregMyPregnancyStory,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: crimsonPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openAddMemoryDialog,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(AppLocalizations.of(context).pregAddMoment,
                    style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800, color: crimsonPrimary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your personal milestones and memories woven together.',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 16),

          if (_memories.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEFE8E0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.bookmark_border_rounded, color: crimsonPrimary, size: 28),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context).pregNoMomentsRecordedYet,
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: textMain),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Record special moments like ultrasound scans, hearing the heartbeat, first flutter, or sweet thoughts along your journey.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: crimsonPrimary,
                      side: const BorderSide(color: crimsonPrimary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: _openAddMemoryDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(AppLocalizations.of(context).pregAddFirstMoment, style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            )
          else
            ..._memories.map((mem) {
              final weekVal = mem['week'];
              final weekLabel = (weekVal != null && weekVal != 0) ? 'Week $weekVal' : 'Memory';
              return _buildStoryTimelineRow(
                week: weekLabel,
                title: mem['title']?.toString() ?? 'Milestone',
                subtitle: mem['date']?.toString() ?? 'Recorded memory',
                isClinical: false,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStoryTimelineRow({
    required String week,
    required String title,
    required String subtitle,
    required bool isClinical,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isClinical ? const Color(0xFFCCFBF1) : const Color(0xFFFFECEB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              week,
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: isClinical ? const Color(0xFF0D9488) : crimsonPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: textMain),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 11 — Teach Me in 30 Seconds & Discovery Feed
  Widget _buildTeachMeIn30Seconds() {
    final teachTopic = _overview?.teachMeTopic;
    final title = teachTopic?['title']?.toString() ?? 'The Glucose Screening Test';

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
              Expanded(
                child: Text(
                  'TEACH ME IN 30 SECONDS',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: crimsonPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.timer_outlined, color: crimsonPrimary, size: 16),
            ],
          ),
          const SizedBox(height: 12),

          // 30s Explainer Card
          InkWell(
            onTap: () {
              if (teachTopic != null) _openTeachMeSheet(teachTopic);
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEFE8E0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.cormorantGaramond(fontSize: 18, fontWeight: FontWeight.bold, color: textMain),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rapid, evidence-based explainer: what it is, what happens, and what to ask your doctor.',
                          style: GoogleFonts.manrope(fontSize: 11.5, color: textMuted, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: crimsonPrimary),
                ],
              ),
            ),
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

    if (_isLoading) {
      return wrapStageDashboardLayout(
        context: context,
        isNested: widget.isNested,
        scaffoldKey: _scaffoldKey,
        child: const Center(
          child: CircularProgressIndicator(color: crimsonPrimary),
        ),
      );
    }

    // Nothing came back from the server, so the sections below are the stage's
    // general content rather than anything worked out from her pregnancy.
    final bool hasServerData = _overview != null || _todayBrief != null;

    return wrapStageDashboardLayout(
      context: context,
      isNested: widget.isNested,
      scaffoldKey: _scaffoldKey,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            controller: _effectiveScrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            children: [
              // 01: Editorial Greeting
              _buildEditorialGreeting(pc),
              const SizedBox(height: 20),
              StageStateNotice(
                state: _overviewState,
                hasData: hasServerData,
                emptyMessage:
                    'There is nothing recorded for your pregnancy yet, so what follows is '
                    'general guidance rather than anything based on your own entries. Add '
                    'your due date and a check-in to see it worked out for you.',
                onRetry: () {
                  setState(() => _isLoading = true);
                  _loadAllPregnancyData();
                },
              ),

              // 02: Today with Docsy (Today's Pregnancy Brief ⭐)
              _buildTodaysPregnancyBrief(),
              const SizedBox(height: 20),

              // 03: Gestational Anchor (Where am I?)
              _buildGestationalAnchor(),
              const SizedBox(height: 20),

              // 04: How Are You Feeling? (Maternal Emotional & Physical Check-In)
              _buildMaternalEmotionalCheckIn(),
              const SizedBox(height: 22),
              const LogSymptomsSection(stageKey: 'pregnancy'),
              const SizedBox(height: 18),
              const HealthLibrarySection(stageKey: 'pregnancy'),
              const SizedBox(height: 18),
              const PregnancyHealthSection(),
              const SizedBox(height: 20),
              const PregnancyLifestyleSection(),
              const SizedBox(height: 20),
              const FetalDevelopmentSection(),
              const SizedBox(height: 24),

              // 05: What Changed? & "My Normal" Baseline
              _buildWhatChangedAndBaseline(),
              const SizedBox(height: 20),

              // 06: "What's Happening to ME?" (Your Body & Baby This Week)
              _buildWhatsHappeningToMe(),
              const SizedBox(height: 20),

              // 07: Pregnancy Modes ("I'm Having A...")
              _buildPregnancyModes(),
              const SizedBox(height: 20),

              // 08: Upcoming Care & Appointment Intelligence
              _buildAppointmentIntelligence(),
              const SizedBox(height: 20),

              // 09: Help Her This Week (Human Partner Co-Nesting)
              _buildHumanPartnerCoNesting(),
              const SizedBox(height: 20),

              // 10: My Pregnancy Story (Intelligent Timeline)
              _buildMyPregnancyStoryTimeline(),
              const SizedBox(height: 20),

              // 11: Teach Me in 30 Seconds & Discovery Feed
              _buildTeachMeIn30Seconds(),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// MODAL: "Teach Me in 30 Seconds" Explainer Sheet
// ─────────────────────────────────────────────────────────────────────
class _TeachMeIn30SecondsSheet extends StatelessWidget {
  final Map<String, dynamic> topic;
  final ValueChanged<String> onAddToDoctorQuestions;

  const _TeachMeIn30SecondsSheet({
    required this.topic,
    required this.onAddToDoctorQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final title = topic['title']?.toString() ?? 'Clinical Explainer';
    final whatItIs = topic['whatItIs']?.toString() ?? 'Evidence-based prenatal topic.';
    final whyDone = topic['whyItIsDone']?.toString() ?? 'Standard maternal healthcare assessment.';
    final whatToExpect = topic['whatToExpect']?.toString() ?? 'A safe, routine clinical evaluation.';
    final questions = (topic['questionsToAsk'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE8E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).preg30SecondExplainer,
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFDD0D22),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF221510),
              ),
            ),
            const SizedBox(height: 18),

            _buildBullet('What it is', whatItIs),
            const SizedBox(height: 14),
            _buildBullet('Why it is done', whyDone),
            const SizedBox(height: 14),
            _buildBullet('What to expect', whatToExpect),
            const SizedBox(height: 18),

            if (questions.isNotEmpty) ...[
              Text(
                'QUESTIONS TO ASK YOUR PROVIDER:',
                style: GoogleFonts.manrope(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF7A6B72),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              ...questions.map((q) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.help_outline, color: Color(0xFFDD0D22), size: 18),
                  title: Text(q, style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF221510))),
                  trailing: TextButton(
                    onPressed: () {
                      onAddToDoctorQuestions(q);
                      Navigator.pop(ctx);
                    },
                    child: Text(AppLocalizations.of(context).pregAdd2,
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFDD0D22)),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBullet(String header, String content) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFE8E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFDD0D22),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            content,
            style: GoogleFonts.manrope(fontSize: 12.5, color: const Color(0xFF221510), height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Safe substring extension
// ─────────────────────────────────────────────────────────────────────
extension StringSliceSafe on String {
  String sliceSafe(int start, int end) {
    if (length <= start) return '';
    if (length <= end) return substring(start);
    return substring(start, end);
  }
}
