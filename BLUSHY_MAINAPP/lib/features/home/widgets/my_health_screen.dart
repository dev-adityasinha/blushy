import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../services/api_auth_service.dart';
import '../../../services/api_blushy_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import 'life_stage_selector_card.dart';

class MyHealthScreen extends StatefulWidget {
  const MyHealthScreen({super.key});

  @override
  State<MyHealthScreen> createState() => _MyHealthScreenState();
}

class _MyHealthScreenState extends State<MyHealthScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cycleLengthController = TextEditingController();
  final TextEditingController _periodLengthController = TextEditingController();

  /// Branch context dates. These live on the life stage engine, not on
  /// PersonalContext, and the pregnancy and postpartum modules read them from
  /// there -- so correcting one has to go through the context endpoint.
  DateTime? _branchDueDate;
  DateTime? _branchBirthDate;
  
  // Medication input temp controllers
  final TextEditingController _medNameC = TextEditingController();
  final TextEditingController _medCategoryC = TextEditingController();
  final TextEditingController _medNotesC = TextEditingController();

  bool _initialized = false;

  // Autosave status tracking
  // 'idle' | 'saving' | 'saved' | 'error'
  String _saveStatus = 'idle';
  Timer? _saveStatusTimer;
  Timer? _periodLengthDebounce;
  late final AnimationController _checkAnimController;
  late final Animation<double> _checkAnim;

  @override
  void initState() {
    super.initState();
    _checkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _checkAnim = CurvedAnimation(parent: _checkAnimController, curve: Curves.easeOutBack);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final pc = BlushyOSProvider.of(context).personalContext;
      _nameController.text = pc.userName ?? '';
      _cycleLengthController.text = pc.cycleLength?.toString() ?? '';
      _loadPeriodLength();
      _loadBranchContext();
    }
  }

  @override
  void dispose() {
    _saveStatusTimer?.cancel();
    _periodLengthDebounce?.cancel();
    _checkAnimController.dispose();
    _nameController.dispose();
    _cycleLengthController.dispose();
    _periodLengthController.dispose();
    _medNameC.dispose();
    _medCategoryC.dispose();
    _medNotesC.dispose();
    super.dispose();
  }

  void _markSaving() {
    if (!mounted) return;
    _saveStatusTimer?.cancel();
    setState(() => _saveStatus = 'saving');
  }

  void _markSaved() {
    if (!mounted) return;
    _saveStatusTimer?.cancel();
    setState(() => _saveStatus = 'saved');
    _checkAnimController.forward(from: 0);
    _saveStatusTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saveStatus = 'idle');
    });
  }

  void _markSaveError() {
    if (!mounted) return;
    _saveStatusTimer?.cancel();
    setState(() => _saveStatus = 'error');
    _saveStatusTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _saveStatus = 'idle');
    });
  }

  static String _normalizeStage(String? stage) =>
      (stage ?? '').toLowerCase().replaceAll('_', '').replaceAll(' ', '');

  static bool _stageIsPregnancy(String? stage) =>
      _normalizeStage(stage).contains('pregnan');

  static bool _stageIsPostpartum(String? stage) =>
      _normalizeStage(stage).contains('postpartum');

  Future<void> _loadBranchContext() async {
    final result = await LifeStageApi.current();
    final context = result.data?.branchContext;
    if (!mounted || context == null) return;
    setState(() {
      _branchDueDate = DateTime.tryParse(context['due_date']?.toString() ?? '');
      _branchBirthDate = DateTime.tryParse(context['baby_birth_date']?.toString() ?? '');
    });
  }

  /// A transition to the stage you are already in is refused, so this is the
  /// only way to correct a date given during onboarding.
  Future<void> _saveBranchContext(Map<String, dynamic> patch) async {
    _markSaving();
    final result = await LifeStageApi.saveContext(patch);
    if (!mounted) return;
    if (result.isError) {
      _markSaveError();
    } else {
      _markSaved();
    }
  }

  /// Period duration is stored with the onboarding answers rather than on
  /// PersonalContext, so it is read straight from the server.
  Future<void> _loadPeriodLength() async {
    try {
      final answers = await ApiAuthService().getOnboardingAnswers();
      final value = answers['period_duration_days']?.toString();
      if (!mounted || value == null || value.isEmpty) return;
      setState(() => _periodLengthController.text = value);
    } catch (_) {
      // Offline or signed out: leave the field blank rather than guessing.
    }
  }

  void _savePeriodLength(String raw) {
    final days = int.tryParse(raw.trim());
    // The backend accepts 2-10; anything else is a typo in progress, so it is
    // not sent rather than being rejected noisily on every keystroke.
    if (days == null || days < 2 || days > 10) return;

    // Debounced: this writes over the network, unlike the fields above which
    // only touch local state.
    _periodLengthDebounce?.cancel();
    _markSaving();
    _periodLengthDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        await ApiAuthService().saveOnboardingAnswers({'period_duration_days': days});
        _markSaved();
      } catch (_) {
        _markSaveError();
      }
    });
  }

  void _saveField(BuildContext ctx, PersonalContext Function(PersonalContext) updateFn) {
    try {
      final state = BlushyOSProvider.of(ctx);
      final newContext = updateFn(state.personalContext);
      state.updatePersonalContext(newContext);

      // Show saving → saved animation
      if (mounted) {
        setState(() => _saveStatus = 'saving');
        _saveStatusTimer?.cancel();
        _saveStatusTimer = Timer(const Duration(milliseconds: 350), () {
          if (mounted) {
            setState(() => _saveStatus = 'saved');
            _checkAnimController.forward(from: 0);
          }
          // Reset to idle after 2 seconds
          _saveStatusTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => _saveStatus = 'idle');
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saveStatus = 'error');
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Failed to save changes. Please try again.',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            duration: const Duration(seconds: 4),
          ),
        );
        _saveStatusTimer?.cancel();
        _saveStatusTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _saveStatus = 'idle');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    final pc = state.personalContext;

    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: BlushyColors.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Health Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
            fontSize: 24,
          ),
        ),
        actions: [
          _buildSaveStatusIndicator(),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: BlushySpacing.lg, vertical: BlushySpacing.md),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeader('Personal Information'),
                  _buildCard([
                    _buildTextField(
                      controller: _nameController,
                      label: 'Preferred Name',
                      onChanged: (val) {
                        _saveField(context, (c) => c.copyWith(
                          userName: val.trim().isEmpty ? null : val.trim(),
                        ));
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDatePickerRow(
                      label: 'Date of Birth',
                      value: pc.dateOfBirth,
                      onSelected: (date) {
                        _saveField(context, (c) => c.copyWith(
                          dateOfBirth: date,
                        ));
                      },
                    ),
                  ]),
                  
                  _buildSectionHeader('Cycle Configuration'),
                  _buildCard([
                    _buildDropdownRow<CycleTrackingPreference>(
                      label: 'Cycle Tracking',
                      value: pc.trackingPreference,
                      items: CycleTrackingPreference.values,
                      onChanged: (val) {
                        if (val != null) {
                          _saveField(context, (c) => c.copyWith(
                            trackingPreference: val,
                          ));
                        }
                      },
                    ),
                    if (pc.trackingPreference == CycleTrackingPreference.enabled) ...[
                      const SizedBox(height: 16),
                      _buildDropdownRow<CyclePattern>(
                        label: 'Cycle Pattern',
                        value: pc.cyclePattern,
                        items: CyclePattern.values,
                        onChanged: (val) {
                          if (val != null) {
                            _saveField(context, (c) => c.copyWith(
                              cyclePattern: val,
                            ));
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _cycleLengthController,
                        label: 'Average Cycle Length (Days)',
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          final len = int.tryParse(val);
                          _saveField(context, (c) => c.copyWith(
                            cycleLength: len,
                          ));
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _periodLengthController,
                        label: 'Average Period Length (Days)',
                        keyboardType: TextInputType.number,
                        onChanged: _savePeriodLength,
                      ),
                      const SizedBox(height: 16),
                      _buildDatePickerRow(
                        label: 'Last Period Start Date',
                        value: pc.lastPeriodStart,
                        onSelected: (date) {
                          _saveField(context, (c) => c.copyWith(
                            lastPeriodStart: date,
                          ));
                        },
                      ),
                    ]
                  ]),

                  _buildSectionHeader('Current Life Stage'),
                  const LifeStageSelectorCard(showHeader: false),

                  // Only the branch the user is actually in gets its date, and
                  // it writes to the life stage engine rather than the profile.
                  if (_stageIsPregnancy(pc.lifeStage)) ...[
                    const SizedBox(height: 16),
                    _buildCard([
                      _buildDatePickerRow(
                        label: 'Due Date',
                        value: _branchDueDate,
                        onSelected: (date) {
                          setState(() => _branchDueDate = date);
                          _saveBranchContext({
                            'due_date': date.toIso8601String().split('T').first,
                          });
                        },
                      ),
                    ]),
                  ],
                  if (_stageIsPostpartum(pc.lifeStage)) ...[
                    const SizedBox(height: 16),
                    _buildCard([
                      _buildDatePickerRow(
                        label: "Baby's Birth Date",
                        value: _branchBirthDate,
                        onSelected: (date) {
                          setState(() => _branchBirthDate = date);
                          _saveBranchContext({
                            'baby_birth_date': date.toIso8601String().split('T').first,
                          });
                        },
                      ),
                    ]),
                  ],

                  _buildSectionHeader('Diagnoses & Medical Conditions'),
                  _buildCard([
                    ...['PCOS', 'Endometriosis', 'Adenomyosis', 'Fibroids', 'PMDD / PMS', 'Thyroid Imbalance', 'None / Exploring'].map((cond) {
                      final isSelected = pc.medicalConditions.contains(cond);
                      return CheckboxListTile(
                        activeColor: BlushyColors.primary,
                        title: Text(cond, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text)),
                        value: isSelected,
                        onChanged: (val) {
                          final newConds = Set<String>.from(pc.medicalConditions);
                          if (val == true) {
                            newConds.add(cond);
                          } else {
                            newConds.remove(cond);
                          }
                          _saveField(context, (c) => c.copyWith(medicalConditions: newConds));
                        },
                      );
                    })
                  ]),

                  _buildSectionHeader('Health & Wellness Goals'),
                  _buildCard([
                    ...[
                      'Understand cycle phases & predictions',
                      'Relieve cramps & pelvic pain',
                      'Balance hormones & mood stability',
                      'Boost energy & reduce fatigue',
                      'Track fertility window & ovulation',
                      'Improve sleep quality & rest',
                      'Postpartum recovery & healing',
                      'Healthy ageing & bone vitality',
                    ].map((goal) {
                      final isSelected = pc.userGoals.contains(goal);
                      return CheckboxListTile(
                        activeColor: BlushyColors.primary,
                        title: Text(goal, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text)),
                        value: isSelected,
                        onChanged: (val) {
                          final newGoals = Set<String>.from(pc.userGoals);
                          if (val == true) {
                            newGoals.add(goal);
                          } else {
                            newGoals.remove(goal);
                          }
                          _saveField(context, (c) => c.copyWith(userGoals: newGoals));
                        },
                      );
                    })
                  ]),

                  _buildSectionHeader('Primary Symptom Focus'),
                  _buildCard([
                    ...[
                      'Cramps & Pelvic Pain',
                      'Bloating & Digestion',
                      'Mood Swings & PMS',
                      'Headaches & Migraines',
                      'Fatigue & Low Energy',
                      'Acne & Skin Breakouts',
                      'Hot Flashes & Temperature',
                      'Sleep & Insomnia',
                    ].map((symptom) {
                      final isSelected = pc.userSymptoms.contains(symptom);
                      return CheckboxListTile(
                        activeColor: BlushyColors.primary,
                        title: Text(symptom, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text)),
                        value: isSelected,
                        onChanged: (val) {
                          final newSymptoms = Set<String>.from(pc.userSymptoms);
                          if (val == true) {
                            newSymptoms.add(symptom);
                          } else {
                            newSymptoms.remove(symptom);
                          }
                          _saveField(context, (c) => c.copyWith(userSymptoms: newSymptoms));
                        },
                      );
                    })
                  ]),

                  _buildSectionHeader('Medications & Supplements'),
                  _buildCard([
                    if (pc.medications.isNotEmpty) ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pc.medications.length,
                        separatorBuilder: (_, _) => const Divider(color: BlushyColors.border),
                        itemBuilder: (context, idx) {
                          final med = pc.medications[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(med.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: BlushyColors.text)),
                            subtitle: Text(med.notes ?? med.category ?? 'Notes not added'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: BlushyColors.primary),
                              onPressed: () {
                                final list = List<Medication>.from(pc.medications)..removeAt(idx);
                                _saveField(context, (c) => c.copyWith(medications: list));
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton.icon(
                      onPressed: () => _showAddMedicationDialog(context, pc.medications),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Medication / Supplement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary.withValues(alpha: 0.06),
                        foregroundColor: BlushyColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  ]),

                  _buildSectionHeader('Privacy & Companion Memory'),
                  _buildCard([
                    SwitchListTile(
                      activeThumbColor: BlushyColors.primary,
                      title: Text('Sia Memory Enabled', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: BlushyColors.text)),
                      subtitle: Text('Allow Sia to learn from your interactions over time.', style: GoogleFonts.poppins(fontSize: 12)),
                      value: pc.preferences.wantsSiaMemory,
                      onChanged: (val) {
                        final newPrefs = UserPreferences(
                          wantsCycleTracking: pc.preferences.wantsCycleTracking,
                          wantsVoiceFeatures: pc.preferences.wantsVoiceFeatures,
                          wantsPersonalizedRecommendations: pc.preferences.wantsPersonalizedRecommendations,
                          wantsSiaMemory: val,
                          wantsNotifications: pc.preferences.wantsNotifications,
                        );
                        _saveField(context, (c) => c.copyWith(preferences: newPrefs));
                      },
                    )
                  ]),

                  _buildSectionHeader('Manage My Data'),
                  _buildCard([
                    _buildDangerButton(
                      label: 'Restart Cycle Learning',
                      onPressed: () {
                        _saveField(context, (c) => c.copyWith(
                          confidence: DataConfidence.low,
                          cycleLength: null,
                          cycleDay: null,
                          cyclePhase: null,
                          lastPeriodStart: null,
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cycle learning model reset.')));
                      },
                    ),
                    const Divider(color: BlushyColors.border),
                    _buildDangerButton(
                      label: 'Reset AI Recommendations',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personalized recommendations reset.')));
                      },
                    ),
                    const Divider(color: BlushyColors.border),
                    _buildDangerButton(
                      label: 'Clear Symptom History',
                      onPressed: () {
                        state.updateWellbeingState(CurrentWellbeingState(
                          energy: null,
                          mood: null,
                          sleepQuality: null,
                          symptoms: const [],
                          lastCheckIn: null,
                          periodActive: false,
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Symptom logs cleared.')));
                      },
                    ),
                    const Divider(color: BlushyColors.border),
                    _buildDangerButton(
                      label: 'Log out',
                      onPressed: () async {
                        await state.logout();
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMedicationDialog(BuildContext context, List<Medication> currentList) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: BlushyColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            "Add Medication / Supplement",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _medNameC,
                  decoration: const InputDecoration(labelText: "Name *"),
                ),
                TextField(
                  controller: _medCategoryC,
                  decoration: const InputDecoration(labelText: "Category (Optional)"),
                ),
                TextField(
                  controller: _medNotesC,
                  decoration: const InputDecoration(labelText: "Notes (Optional)"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text("Cancel", style: GoogleFonts.poppins(color: BlushyColors.secondaryText)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_medNameC.text.trim().isNotEmpty) {
                  final list = List<Medication>.from(currentList)
                    ..add(Medication(
                      name: _medNameC.text.trim(),
                      category: _medCategoryC.text.trim().isEmpty ? null : _medCategoryC.text.trim(),
                      notes: _medNotesC.text.trim().isEmpty ? null : _medNotesC.text.trim(),
                    ));
                  _saveField(context, (c) => c.copyWith(medications: list));
                  _medNameC.clear();
                  _medCategoryC.clear();
                  _medNotesC.clear();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: BlushyColors.primary, foregroundColor: Colors.white),
              child: const Text("Add"),
            )
          ],
        );
      },
    );
  }

  Widget _buildSaveStatusIndicator() {
    Widget child;
    switch (_saveStatus) {
      case 'saving':
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BlushyColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Saving...',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: BlushyColors.secondaryText,
              ),
            ),
          ],
        );
        break;
      case 'saved':
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _checkAnim,
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF43A047), size: 18),
            ),
            const SizedBox(width: 6),
            Text(
              'Saved',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF43A047),
              ),
            ),
          ],
        );
        break;
      case 'error':
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 18),
            const SizedBox(width: 6),
            Text(
              'Error',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD32F2F),
              ),
            ),
          ],
        );
        break;
      default: // 'idle'
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done_outlined, color: BlushyColors.secondaryText.withValues(alpha: 0.5), size: 16),
            const SizedBox(width: 5),
            Text(
              'Autosaved',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: BlushyColors.secondaryText.withValues(alpha: 0.5),
              ),
            ),
          ],
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(animation),
            child: child,
          )),
      child: Container(
        key: ValueKey(_saveStatus),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _saveStatus == 'saved'
              ? const Color(0xFFE8F5E9)
              : _saveStatus == 'error'
                  ? const Color(0xFFFFEBEE)
                  : BlushyColors.background.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _saveStatus == 'saved'
                ? const Color(0xFF43A047).withValues(alpha: 0.3)
                : _saveStatus == 'error'
                    ? const Color(0xFFD32F2F).withValues(alpha: 0.3)
                    : BlushyColors.border.withValues(alpha: 0.3),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: BlushyColors.secondaryText,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(dynamic children) {
    return Material(
      color: BlushyColors.cardBg,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: BlushyColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x022E2623),
              blurRadius: 16,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children is List<Widget> ? children : (children as List).cast<Widget>(),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: BlushyColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: BlushyColors.secondaryText),
        filled: true,
        fillColor: BlushyColors.background.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BlushyColors.border)),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePickerRow({required String label, required DateTime? value, required ValueChanged<DateTime> onSelected}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: BlushyColors.text)),
        OutlinedButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) onSelected(picked);
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: BlushyColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            value == null ? 'Select Date' : '${value.year}-${value.month}-${value.day}',
            style: GoogleFonts.poppins(color: BlushyColors.primary, fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }

  Widget _buildDropdownRow<T>({required String label, required T value, required List<T> items, required ValueChanged<T?> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: BlushyColors.text)),
        DropdownButton<T>(
          value: value,
          underline: const SizedBox.shrink(),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toString().split('.').last.toUpperCase()))).toList(),
          onChanged: onChanged,
        )
      ],
    );
  }

  Widget _buildDangerButton({required String label, required VoidCallback onPressed}) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: BlushyColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.centerLeft,
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
