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
import 'pregnancy_health_section.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/user_state_store.dart';

extension StringSliceSafe on String {
  String sliceSafe(int start, [int? end]) {
    if (start >= length) return '';
    final actualEnd = end != null ? end.clamp(start, length) : length;
    return substring(start, actualEnd);
  }
}

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
  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _internalScrollController;

  // ─── Real-Time Dynamic Pregnancy State ─────────────────────────────
  bool _isLoading = true;
  ApiState _overviewState = ApiState.loading;
  PregnancyOverviewData? _overview;
  PregnancyTodayBriefData? _todayBrief;
  Map<String, dynamic>? _baselineData;
  List<Map<String, dynamic>> _memories = [];
  List<Map<String, dynamic>> _questions = [];

  final PregnancyViewModel _vm = PregnancyViewModel();

  // ─── Interactive Controls ──────────────────────────────────────────
  String? _selectedMode;
  final TextEditingController _docsyInputController = TextEditingController();

  // ─── Daily Check-In State (Maternal Vitals) ────────────────────────
  int? _nauseaScore;
  int? _energyScore;
  int? _sleepScore;
  int? _moodScore;
  int _waterGlasses = 0;
  bool _hasLoggedToday = false;

  // ─── Trimester Checklist State ─────────────────────────────────────
  Set<String> _completedChecklist = {};

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
        if (savedCheckin['mode'] != null &&
            savedCheckin['mode'].toString().isNotEmpty &&
            savedCheckin['mode'] != 'default') {
          _selectedMode = savedCheckin['mode'].toString();
        }
      }

      final savedQ = BlushyStorage.read('pregnancy_questions.json');
      if (savedQ['items'] is List) {
        _questions = (savedQ['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final savedMem = BlushyStorage.read('pregnancy_memories.json');
      if (savedMem['items'] is List) {
        _memories = (savedMem['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final savedCheck = BlushyStorage.read('pregnancy_checklist.json');
      if (savedCheck['completed'] is List) {
        _completedChecklist = (savedCheck['completed'] as List).map((e) => e.toString()).toSet();
      }
    } catch (_) {}
  }

  Future<void> _loadAllPregnancyData() async {
    final pc = context
        .getInheritedWidgetOfExactType<BlushyOSProvider>()
        ?.notifier
        ?.personalContext;
    final dueDateStr = pc?.dueDate?.toIso8601String().sliceSafe(0, 10);
    await _vm.load(dueDate: dueDateStr, mode: _selectedMode);
  }

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

    try {
      UserStateStore.write('pregnancy_last_checkin', payload);
    } catch (_) {}

    final messenger = ScaffoldMessenger.of(context);
    await ApiPregnancyService.submitCheckIn(payload);
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

  void _toggleChecklistItem(String itemKey) {
    setState(() {
      if (_completedChecklist.contains(itemKey)) {
        _completedChecklist.remove(itemKey);
      } else {
        _completedChecklist.add(itemKey);
      }
      try {
        BlushyStorage.write('pregnancy_checklist.json', {
          'completed': _completedChecklist.toList(),
        });
      } catch (_) {}
    });
  }

  void _addDoctorQuestion(String qText) async {
    final q = {
      'text': qText,
      'isForDoctor': true,
      'createdAt': DateTime.now().toIso8601String(),
    };
    setState(() => _questions.insert(0, q));
    await ApiPregnancyService.saveQuestion(q);

    try {
      BlushyStorage.write('pregnancy_questions.json', {'items': _questions});
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added to your Doctor Questions list 📋', style: GoogleFonts.manrope(fontSize: 12)),
        backgroundColor: textMain,
        duration: const Duration(seconds: 2),
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
        title: Text(
          AppLocalizations.of(context).pregAddToPregnancyStory,
          style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain),
        ),
        content: TextField(
          controller: textController,
          decoration: InputDecoration(
            hintText: 'e.g. Felt first little flutter tonight! ❤️',
            hintStyle: GoogleFonts.manrope(fontSize: 13, color: textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 2,
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
                try {
                  BlushyStorage.write('pregnancy_memories.json', {'items': _memories});
                } catch (_) {}
                await ApiPregnancyService.saveMemory(mem);
              }
            },
            child: Text(AppLocalizations.of(context).pregSaveMemory, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ─── Modal Sheets: Peace of Mind ───────────────────────────────────
  void _openSymptomTriageSheet([String? initialQuery]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SymptomTriageSheet(
        week: _overview?.week ?? 20,
        initialQuery: initialQuery,
        onAddDoctorQuestion: _addDoctorQuestion,
      ),
    );
  }

  void _openFoodSafetySheet([String? initialQuery]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FoodSafetySheet(
        week: _overview?.week ?? 20,
        initialQuery: initialQuery,
        onAddDoctorQuestion: _addDoctorQuestion,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // UI BUILDERS
  // ───────────────────────────────────────────────────────────────────

  // 01 — Editorial Greeting
  Widget _buildEditorialGreeting(PersonalContext pc) {
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
              color: textMain,
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
              color: textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // 02 — Gestational Anchor Hero Card
  Widget _buildGestationalHero() {
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
                Text(
                  'YOUR PREGNANCY TIMELINE',
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: crimsonPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEE9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Setup needed',
                    style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'When is your baby expected?',
              style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your estimated due date so Blushy can calculate your exact week, baby\'s size milestones, and daily body guidance.',
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
              label: Text(
                'Set estimated due date',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
              ),
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
              Text(
                'YOUR PREGNANCY TIMELINE',
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
                  '${(progress * 100).toInt()}% completed',
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

  // 03 — Health Library (Position 2 — per explicit user request)
  Widget _buildHealthLibrarySecond() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HEALTH LIBRARY',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: crimsonPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Essential Guides for You & Baby',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const PregnancyHealthSection(),
        const SizedBox(height: 16),
        const PregnancyLifestyleSection(),
        const SizedBox(height: 16),
        const FetalDevelopmentSection(),
      ],
    );
  }

  // 04 — Today's Comfort & Reality
  Widget _buildTodayComfort() {
    final brief = _todayBrief;
    final oneThing = brief?.oneThingToKnow ?? 'Mild stretching sensations are normal as your ligaments gently adapt.';
    final oneAction = brief?.oneThingToDo ?? 'Drink a tall glass of water and rest your feet for 5 minutes.';

    final modes = [
      {'id': 'default', 'label': '✨ Balanced Day'},
      {'id': 'nausea', 'label': '🤢 Bad Nausea'},
      {'id': 'sleep', 'label': '🥱 Heavy Fatigue'},
      {'id': 'back_pain', 'label': '⚡ Back Ache'},
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFECEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.spa_outlined, color: crimsonPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                "TODAY'S COMFORT",
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: crimsonPrimary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "How's your day feeling?",
            style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            "Tap any feeling below to adapt Docsy's daily care tip for you.",
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 14),

          // Reality Chips
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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

          // Dynamic Comfort Note
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
                const Icon(Icons.lightbulb_outline, color: crimsonPrimary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    brief?.modeAdvice ?? 'Take things at your own comfortable, unhurried pace today.',
                    style: GoogleFonts.manrope(fontSize: 11.5, color: textMain, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Micro Action Pairing
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GOOD TO KNOW',
                      style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(oneThing, style: GoogleFonts.manrope(fontSize: 11.5, color: textMain, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GENTLE ACTION',
                      style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w800, color: crimsonPrimary, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(oneAction, style: GoogleFonts.manrope(fontSize: 11.5, color: textMain, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 05 — Peace of Mind Hub ("Is this normal?" + "Can I eat or take this?")
  Widget _buildPeaceOfMindHub() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PEACE OF MIND',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: crimsonPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Quick Answers for You',
                style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Tool 1: Is this normal?
            Expanded(
              child: InkWell(
                onTap: () => _openSymptomTriageSheet(),
                borderRadius: cardRadius,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: cardRadius,
                    border: Border.all(color: cardBorderColor, width: 1.0),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06221510), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.health_and_safety_outlined, color: Color(0xFF0D9488), size: 20),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Is this normal?',
                        style: GoogleFonts.cormorantGaramond(fontSize: 18, fontWeight: FontWeight.bold, color: textMain),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check twinges, aches, or sudden bodily shifts.',
                        style: GoogleFonts.manrope(fontSize: 11, color: textMuted, height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Check symptom',
                            style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 12, color: Color(0xFF0D9488)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Tool 2: Can I eat or take this?
            Expanded(
              child: InkWell(
                onTap: () => _openFoodSafetySheet(),
                borderRadius: cardRadius,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: cardRadius,
                    border: Border.all(color: cardBorderColor, width: 1.0),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06221510), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.restaurant_outlined, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Can I eat or take this?',
                        style: GoogleFonts.cormorantGaramond(fontSize: 18, fontWeight: FontWeight.bold, color: textMain),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check foods, teas, or everyday medicines.',
                        style: GoogleFonts.manrope(fontSize: 11, color: textMuted, height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Check food & meds',
                            style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFD97706)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 12, color: Color(0xFFD97706)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 06 — Daily Maternal Check-In (Unboxed Rhythm)
  Widget _buildDailyCheckIn() {
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

    final deltasList = (_baselineData?['deltas'] as List?) ?? [];
    final trendSynthesis = _baselineData?['trendSynthesis']?.toString() ??
        'Your daily checks calibrate your personal baseline and detect meaningful shifts.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY CHECK-IN',
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: crimsonPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your Daily Rhythm',
                    style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain),
                  ),
                ],
              ),
              InkWell(
                onTap: hasInteracted ? _submitDailyCheckIn : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

        // Unboxed Circular Badges
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
        const SizedBox(height: 16),

        // Baseline Delta Insights
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: cardRadius,
            border: Border.all(color: cardBorderColor, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (deltasList.isNotEmpty) ...[
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
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEFE8E0)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              indicator,
                              style: GoogleFonts.manrope(
                                fontSize: 10.5,
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
                const SizedBox(height: 12),
              ],
              Text(
                trendSynthesis,
                style: GoogleFonts.manrope(fontSize: 11.5, color: textMain, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Keep standard symptom logger available for deeper checks
        const LogSymptomsSection(stageKey: 'pregnancy'),
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

  // 07 — Help Her This Week (Partner Support)
  Widget _buildPartnerSupport() {
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
              Text(
                'FOR YOUR PARTNER',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: crimsonPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const Icon(Icons.favorite, color: crimsonPrimary, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'How they can support you this week',
            style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Practical, thoughtful cues you can share with your partner in one tap.',
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
                final shareText = "Hey love ❤️ Here is how you can support me this week according to Blushy:\n\n"
                    "Tonight: $tonight\n"
                    "This week: $thisWeek\n"
                    "Ask me: \"$askHer\"";
                Share.share(shareText);
              },
              icon: const Icon(Icons.share, size: 14),
              label: Text(
                'Share with partner',
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

  // 08 — Doctor Visits & Keepsakes
  Widget _buildDoctorAndMilestones() {
    final nextScan = _overview?.isDueDateConfigured == true
        ? (_overview!.week != null && _overview!.week! < 22
            ? 'Comprehensive Anatomy Scan (Level II)'
            : 'Glucose Screening & Routine Blood Panel')
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
              Text(
                'VISITS & KEEPSAKES',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: crimsonPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const Icon(Icons.calendar_month_outlined, color: crimsonPrimary, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Doctor Appointments & Moments',
            style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep your clinic questions organized and cherish milestone moments along the way.',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 16),

          // Next scan callout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEFE8E0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: Color(0xFF0D9488), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UPCOMING SCREENING',
                        style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextScan,
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: textMain),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Saved Questions preview
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
                  label: Text(
                    'Doctor Summary',
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: crimsonPrimary,
                  side: const BorderSide(color: crimsonPrimary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
                onPressed: () {
                  final textCtrl = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(
                        'Add question for doctor',
                        style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      content: TextField(
                        controller: textCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Is lower back stiffness normal?',
                          hintStyle: GoogleFonts.manrope(fontSize: 12, color: textMuted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel', style: GoogleFonts.manrope(color: textMuted)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: crimsonPrimary),
                          onPressed: () {
                            if (textCtrl.text.trim().isNotEmpty) {
                              _addDoctorQuestion(textCtrl.text.trim());
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: Text('Question', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: textMain,
                  side: const BorderSide(color: Color(0xFFEFE8E0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                ),
                onPressed: _openAddMemoryDialog,
                child: const Icon(Icons.bookmark_add_outlined, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 09 — Trimester Care & Hospital Bag Checklist
  Widget _buildTrimesterChecklist() {
    final week = _overview?.week ?? 20;
    final int currentTrimester = week <= 12 ? 1 : (week <= 27 ? 2 : 3);

    final items = currentTrimester == 1
        ? [
            {'key': 't1_prenatal', 'title': 'Daily prenatal vitamin with folic acid'},
            {'key': 't1_intake', 'title': 'First prenatal blood test & clinical intake'},
            {'key': 't1_dating', 'title': 'First trimester ultrasound & dating scan'},
            {'key': 't1_nipt', 'title': 'Optional NIPT or genetic screening check'},
          ]
        : (currentTrimester == 2
            ? [
                {'key': 't2_anatomy', 'title': 'Level II Anatomy Ultrasound (18–22 weeks)'},
                {'key': 't2_glucose', 'title': 'Glucose screening for gestational diabetes (24–28w)'},
                {'key': 't2_movement', 'title': 'Notice daily flutter & movement rhythms'},
                {'key': 't2_pillow', 'title': 'Supportive sleep pillow for hip & back comfort'},
              ]
            : [
                {'key': 't3_tdap', 'title': 'Tdap booster vaccination (27–36 weeks)'},
                {'key': 't3_gbs', 'title': 'Group B Strep (GBS) swab test (35–37 weeks)'},
                {'key': 't3_hospital_bag', 'title': 'Pack hospital delivery bag essentials'},
                {'key': 't3_car_seat', 'title': 'Install & inspect infant car seat in car'},
              ]);

    final trimesterTitle = currentTrimester == 1
        ? 'First Trimester Roadmap'
        : (currentTrimester == 2 ? 'Second Trimester Roadmap' : 'Third Trimester & Nesting');

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
              Text(
                'TRIMESTER CHECKLIST',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: crimsonPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const Icon(Icons.checklist_rounded, color: crimsonPrimary, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            trimesterTitle,
            style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Key clinical checkpoints and preparations—check them off at your own pace.',
            style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 14),

          ...items.map((item) {
            final key = item['key']!;
            final title = item['title']!;
            final isDone = _completedChecklist.contains(key);

            return InkWell(
              onTap: () => _toggleChecklistItem(key),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isDone ? const Color(0xFF0D9488) : const Color(0xFFB0A2AA),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: isDone ? FontWeight.w500 : FontWeight.w600,
                          color: isDone ? textMuted : textMain,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
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
              // 01: Greeting
              _buildEditorialGreeting(pc),
              const SizedBox(height: 18),
              StageStateNotice(
                state: _overviewState,
                hasData: hasServerData,
                emptyMessage:
                    'There is nothing recorded for your pregnancy yet, so what follows is '
                    'general guidance rather than anything based on your own entries. Add '
                    'your due date and a check-in to see it calibrated for you.',
                onRetry: () {
                  setState(() => _isLoading = true);
                  _loadAllPregnancyData();
                },
              ),

              // 01: Hero Gestational Anchor
              _buildGestationalHero(),
              const SizedBox(height: 22),

              // 02: Health Library (Placed 2nd per explicit user request)
              _buildHealthLibrarySecond(),
              const SizedBox(height: 22),

              // 03: Today's Comfort & Reality
              _buildTodayComfort(),
              const SizedBox(height: 22),

              // 04: Peace of Mind Hub ("Is this normal?" + "Can I eat or take this?")
              _buildPeaceOfMindHub(),
              const SizedBox(height: 22),

              // 05: Daily Check-In & Baseline Trends
              _buildDailyCheckIn(),
              const SizedBox(height: 22),

              // 06: Help For Your Partner (Co-Nesting)
              _buildPartnerSupport(),
              const SizedBox(height: 22),

              // 07: Doctor Visits & Keepsake Notes
              _buildDoctorAndMilestones(),
              const SizedBox(height: 22),

              // 08: Trimester Checklist Roadmap
              _buildTrimesterChecklist(),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// MODAL SHEET: "Is this normal?" Symptom Triage
// ─────────────────────────────────────────────────────────────────────
class _SymptomTriageSheet extends StatefulWidget {
  final int week;
  final String? initialQuery;
  final ValueChanged<String> onAddDoctorQuestion;

  const _SymptomTriageSheet({
    required this.week,
    this.initialQuery,
    required this.onAddDoctorQuestion,
  });

  @override
  State<_SymptomTriageSheet> createState() => _SymptomTriageSheetState();
}

class _SymptomTriageSheetState extends State<_SymptomTriageSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery ?? '');
  SymptomTriageResult? _result;
  bool _loading = false;

  final List<String> _quickSuggestions = [
    'Round ligament twinges',
    'Headache & dizziness',
    'Lower back stiffness',
    'Mild spotting',
    'Swollen ankles',
    'Urine burning or UTI',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _runTriage(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runTriage(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);

    final res = await ApiPregnancyService.classifySymptom(query: q, week: widget.week);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = res.data;
    });
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF0D9488);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
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

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.health_and_safety_outlined, color: Color(0xFF0D9488), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SYMPTOM REASSURANCE',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0D9488),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Is this normal?',
                        style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF221510)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _controller,
              style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF221510)),
              decoration: InputDecoration(
                hintText: 'Describe what you are feeling...',
                hintStyle: GoogleFonts.manrope(fontSize: 12.5, color: const Color(0xFF7A6B72)),
                filled: true,
                fillColor: const Color(0xFFFAF7F2),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7A6B72), size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Color(0xFFDD0D22), size: 18),
                  onPressed: () => _runTriage(_controller.text),
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
                  borderSide: const BorderSide(color: Color(0xFFDD0D22), width: 1.2),
                ),
              ),
              onSubmitted: _runTriage,
            ),
            const SizedBox(height: 10),

            // Quick Suggestions
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _quickSuggestions.map((s) {
                return InkWell(
                  onTap: () {
                    _controller.text = s;
                    _runTriage(s);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEFE8E0)),
                    ),
                    child: Text(
                      s,
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF221510)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFFDD0D22)),
                ),
              )
            else if (_result != null) ...[
              // Badge & Result
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _parseColor(_result!.colorHex).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _parseColor(_result!.colorHex).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _result!.badgeLabel.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _parseColor(_result!.colorHex),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _result!.summary,
                      style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF221510), height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result!.reasoning,
                      style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72), height: 1.4),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEFE8E0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.tips_and_updates_outlined, color: Color(0xFFDD0D22), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _result!.guidance,
                              style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF221510), height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_result!.questionsForDoctor.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'QUESTIONS TO ASK YOUR DOCTOR:',
                        style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF7A6B72), letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      ..._result!.questionsForDoctor.map((q) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFFDD0D22)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(q, style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF221510))),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFFDD0D22)),
                                onPressed: () {
                                  widget.onAddDoctorQuestion(q);
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// MODAL SHEET: "Can I eat or take this?" Food & Medicine Safety
// ─────────────────────────────────────────────────────────────────────
class _FoodSafetySheet extends StatefulWidget {
  final int week;
  final String? initialQuery;
  final ValueChanged<String> onAddDoctorQuestion;

  const _FoodSafetySheet({
    required this.week,
    this.initialQuery,
    required this.onAddDoctorQuestion,
  });

  @override
  State<_FoodSafetySheet> createState() => _FoodSafetySheetState();
}

class _FoodSafetySheetState extends State<_FoodSafetySheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery ?? '');
  FoodSafetyResult? _result;
  bool _loading = false;

  final List<String> _quickSuggestions = [
    'Papaya',
    'Paracetamol',
    'Coffee',
    'Herbal tea',
    'Sushi',
    'Soft cheese',
    'Eggs',
    'Ibuprofen',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _runCheck(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runCheck(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);

    final res = await ApiPregnancyService.checkFoodSafety(query: q, week: widget.week);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = res.data;
    });
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF0D9488);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
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

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_outlined, color: Color(0xFFD97706), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FOOD & MEDICINE SAFETY',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFD97706),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Can I eat or take this?',
                        style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF221510)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _controller,
              style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF221510)),
              decoration: InputDecoration(
                hintText: 'Search food, drink, or medicine...',
                hintStyle: GoogleFonts.manrope(fontSize: 12.5, color: const Color(0xFF7A6B72)),
                filled: true,
                fillColor: const Color(0xFFFAF7F2),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7A6B72), size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Color(0xFFDD0D22), size: 18),
                  onPressed: () => _runCheck(_controller.text),
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
                  borderSide: const BorderSide(color: Color(0xFFDD0D22), width: 1.2),
                ),
              ),
              onSubmitted: _runCheck,
            ),
            const SizedBox(height: 10),

            // Quick suggestions
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _quickSuggestions.map((s) {
                return InkWell(
                  onTap: () {
                    _controller.text = s;
                    _runCheck(s);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEFE8E0)),
                    ),
                    child: Text(
                      s,
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF221510)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFFDD0D22)),
                ),
              )
            else if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _parseColor(_result!.colorHex).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _parseColor(_result!.colorHex).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _result!.badge.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _parseColor(_result!.colorHex),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _result!.summary,
                      style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF221510), height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result!.reasoning,
                      style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72), height: 1.4),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEFE8E0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF0D9488), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SAFE ALTERNATIVE / TIP',
                                  style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF7A6B72), letterSpacing: 0.8),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _result!.safeAlternative,
                                  style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF221510), height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Icon(Icons.help_outline, size: 14, color: Color(0xFFDD0D22)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _result!.docQuestion,
                            style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF221510)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFFDD0D22)),
                          onPressed: () {
                            widget.onAddDoctorQuestion(_result!.docQuestion);
                          },
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
    );
  }
}
