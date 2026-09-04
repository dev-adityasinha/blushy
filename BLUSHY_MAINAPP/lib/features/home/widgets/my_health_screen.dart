import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../services/api_auth_service.dart';
import '../../../services/api_blushy_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import 'life_stage_selector_card.dart';
import '../../../shared/confirm_sign_out.dart';
import '../../../services/sia_dashboard_service.dart';
import '../../journal/settings/journal_settings_screen.dart';
import '../../journal/themes/theme_marketplace.dart';

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
                    style: GoogleFonts.manrope(fontSize: 13),
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
          'Account Settings',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
            fontSize: 20,
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
                  _buildHubCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Information',
                    subtitle: 'Your name and date of birth',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _AccountSectionScreen(
                          title: 'Personal Information',
                          editable: true,
                          body: _sectionPersonalInformation,
                          onSave: _commitDraft,
                          onFlush: _flushPending,
                        ),
                      ),
                    ),
                  ),
                  _buildHubCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Cycle Configuration',
                    subtitle: 'Tracking, cycle and period length',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _AccountSectionScreen(
                          title: 'Cycle Configuration',
                          editable: true,
                          body: _sectionCycleConfiguration,
                          onSave: _commitDraft,
                          onFlush: _flushPending,
                        ),
                      ),
                    ),
                  ),
                  _buildHubCard(
                    icon: Icons.timeline_rounded,
                    title: 'Current Life Stage',
                    subtitle: 'The dates behind your stage',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _AccountSectionScreen(
                          title: 'Current Life Stage',
                          editable: true,
                          body: _sectionCurrentLifeStage,
                          onSave: _commitDraft,
                          onFlush: _flushPending,
                        ),
                      ),
                    ),
                  ),
                  _buildHubCard(
                    icon: Icons.medical_information_outlined,
                    title: 'Diagnoses & Medical Conditions',
                    subtitle: 'What you have told us you live with',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _AccountSectionScreen(
                          title: 'Diagnoses & Medical Conditions',
                          editable: true,
                          body: _sectionDiagnosesMedicalConditions,
                          onSave: _commitDraft,
                          onFlush: _flushPending,
                        ),
                      ),
                    ),
                  ),
                  _buildHubCard(
                    icon: Icons.flag_outlined,
                    title: 'Health & Wellness Goals',
                    subtitle: 'What you are working towards',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _AccountSectionScreen(
                          title: 'Health & Wellness Goals',
                          editable: true,
                          body: _sectionHealthWellnessGoals,
                          onSave: _commitDraft,
                          onFlush: _flushPending,
                        ),
                      ),
                    ),
                  ),
                  _buildHubCard(
                    icon: Icons.monitor_heart_outlined,
                    title: 'Primary Symptom Focus',
                    subtitle: 'The symptoms worth watching',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _AccountSectionScreen(
                          title: 'Primary Symptom Focus',
                          editable: true,
                          body: _sectionPrimarySymptomFocus,
                          onSave: _commitDraft,
                          onFlush: _flushPending,
                        ),
                      ),
                    ),
                  ),
                  _buildHubCard(
                    icon: Icons.medication_outlined,
                    title: 'Medications & Supplements',
                    subtitle: 'What you take, and when',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _AccountSectionScreen(
                          title: 'Medications & Supplements',
                          editable: true,
                          body: _sectionMedicationsSupplements,
                          onSave: _commitDraft,
                          onFlush: _flushPending,
                        ),
                      ),
                    ),
                  ),
                  _buildHubCard(
                    icon: Icons.shield_outlined,
                    title: 'Privacy & Companion Memory',
                    subtitle: 'What Docsy is allowed to remember',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _AccountSectionScreen(
                          title: 'Privacy & Companion Memory',
                          editable: true,
                          body: _sectionPrivacyCompanionMemory,
                          onSave: _commitDraft,
                          onFlush: _flushPending,
                        ),
                      ),
                    ),
                  ),
                  _buildHubCard(
                    icon: Icons.palette_outlined,
                    title: 'Journal & Personalisation',
                    subtitle: 'Journal settings and themes',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _AccountSectionScreen(
                          title: 'Journal & Personalisation',
                          editable: false,
                          body: _sectionJournalPersonalisation,
                          onSave: _commitDraft,
                          onFlush: _flushPending,
                        ),
                      ),
                    ),
                  ),
                  _buildHubCard(
                    icon: Icons.storage_rounded,
                    title: 'Manage My Data',
                    subtitle: 'Reset learning, clear history',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _AccountSectionScreen(
                          title: 'Manage My Data',
                          editable: false,
                          body: _sectionManageMyData,
                          onSave: _commitDraft,
                          onFlush: _flushPending,
                        ),
                      ),
                    ),
                  ),
                  _buildHubCard(
                    icon: Icons.help_outline_rounded,
                    title: 'FAQ',
                    subtitle: 'How tracking, privacy and Docsy work',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _AccountFaqScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Filled and centred rather than a left-aligned text button:
                  // it is the last thing on the page and the only one that
                  // ends the session.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (!await confirmSignOut(context)) return;
                        await state.logout();
                        if (context.mounted) {
                          Navigator.of(context)
                              .pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      },
                      child: Text(
                        'Sign Out',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  /// Writes a finished draft through to state. Called by Save, never by a
  /// field.
  void _commitDraft(BuildContext ctx, PersonalContext draft) {
    _saveField(ctx, (_) => draft);
  }

  /// Sends the fields that live on the server rather than on PersonalContext.
  ///
  /// Period duration is stored with the onboarding answers, and the life-stage
  /// dates go to LifeStageApi. Both used to fire on every keystroke or tap;
  /// they are held until Save now, like everything else on the page.
  Future<void> _flushPending(Map<String, Object?> pending) async {
    final days = pending['period_duration_days'];
    if (days is int) {
      _markSaving();
      try {
        await ApiAuthService()
            .saveOnboardingAnswers({'period_duration_days': days});
        _markSaved();
      } catch (_) {
        _markSaveError();
      }
    }

    final branch = <String, dynamic>{
      for (final entry in pending.entries)
        if (entry.key.startsWith('branch:'))
          entry.key.substring('branch:'.length): entry.value,
    };
    if (branch.isNotEmpty) await _saveBranchContext(branch);
  }

  Widget _buildHubCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDF2F2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: BlushyColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: GoogleFonts.manrope(
                            fontSize: 10, color: BlushyColors.secondaryText)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: BlushyColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionPersonalInformation(BuildContext context, _SectionEditor e) {
    final pc = e.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                  _buildCard([
                    _buildTextField(
                      controller: _nameController,
                      label: 'Preferred Name',
                      onChanged: (val) {
                        e.set((c) => c.copyWith(
                          userName: val.trim().isEmpty ? null : val.trim(),
                        ));
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDatePickerRow(
                      label: 'Date of Birth',
                      value: pc.dateOfBirth,
                      onSelected: (date) {
                        e.set((c) => c.copyWith(
                          dateOfBirth: date,
                        ));
                      },
                    ),
                  ]),
      ],
    );
  }

  Widget _sectionCycleConfiguration(BuildContext context, _SectionEditor e) {
    final pc = e.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                  _buildCard([
                    _buildDropdownRow<CycleTrackingPreference>(
                      label: 'Cycle Tracking',
                      value: pc.trackingPreference,
                      items: CycleTrackingPreference.values,
                      onChanged: (val) {
                        if (val != null) {
                          e.set((c) => c.copyWith(
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
                            e.set((c) => c.copyWith(
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
                          e.set((c) => c.copyWith(
                            cycleLength: len,
                          ));
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _periodLengthController,
                        label: 'Average Period Length (Days)',
                        keyboardType: TextInputType.number,
                        onChanged: (raw) {
                          final days = int.tryParse(raw.trim());
                          // The backend accepts 2-10; anything else is a typo
                          // in progress and is not queued.
                          if (days == null || days < 2 || days > 10) return;
                          e.queue('period_duration_days', days);
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDatePickerRow(
                        label: 'Last Period Start Date',
                        value: pc.lastPeriodStart,
                        onSelected: (date) {
                          e.set((c) => c.copyWith(
                            lastPeriodStart: date,
                          ));
                        },
                      ),
                    ]
                  ]),
      ],
    );
  }

  Widget _sectionCurrentLifeStage(BuildContext context, _SectionEditor e) {
    final pc = e.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                          e.queue('branch:due_date',
                              date.toIso8601String().split('T').first);
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
                          e.queue('branch:baby_birth_date',
                              date.toIso8601String().split('T').first);
                        },
                      ),
                    ]),
                  ],
      ],
    );
  }

  Widget _sectionDiagnosesMedicalConditions(BuildContext context, _SectionEditor e) {
    final pc = e.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                  _buildCard([
                    ...['PCOS', 'Endometriosis', 'Adenomyosis', 'Fibroids', 'PMDD / PMS', 'Thyroid Imbalance', 'None / Exploring'].map((cond) {
                      final isSelected = pc.medicalConditions.contains(cond);
                      return CheckboxListTile(
                        activeColor: BlushyColors.primary,
                        title: Text(cond, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text)),
                        value: isSelected,
                        onChanged: (val) {
                          final newConds = Set<String>.from(pc.medicalConditions);
                          if (val == true) {
                            newConds.add(cond);
                          } else {
                            newConds.remove(cond);
                          }
                          e.set((c) => c.copyWith(medicalConditions: newConds));
                        },
                      );
                    })
                  ]),
      ],
    );
  }

  Widget _sectionHealthWellnessGoals(BuildContext context, _SectionEditor e) {
    final pc = e.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                        title: Text(goal, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text)),
                        value: isSelected,
                        onChanged: (val) {
                          final newGoals = Set<String>.from(pc.userGoals);
                          if (val == true) {
                            newGoals.add(goal);
                          } else {
                            newGoals.remove(goal);
                          }
                          e.set((c) => c.copyWith(userGoals: newGoals));
                        },
                      );
                    })
                  ]),
      ],
    );
  }

  Widget _sectionPrimarySymptomFocus(BuildContext context, _SectionEditor e) {
    final pc = e.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                        title: Text(symptom, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text)),
                        value: isSelected,
                        onChanged: (val) {
                          final newSymptoms = Set<String>.from(pc.userSymptoms);
                          if (val == true) {
                            newSymptoms.add(symptom);
                          } else {
                            newSymptoms.remove(symptom);
                          }
                          e.set((c) => c.copyWith(userSymptoms: newSymptoms));
                        },
                      );
                    })
                  ]),
      ],
    );
  }

  Widget _sectionMedicationsSupplements(BuildContext context, _SectionEditor e) {
    final pc = e.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                            title: Text(med.name, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: BlushyColors.text)),
                            subtitle: Text(med.notes ?? med.category ?? 'Notes not added'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: BlushyColors.primary),
                              onPressed: () {
                                final list = List<Medication>.from(pc.medications)..removeAt(idx);
                                e.set((c) => c.copyWith(medications: list));
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
      ],
    );
  }

  Widget _sectionPrivacyCompanionMemory(BuildContext context, _SectionEditor e) {
    final pc = e.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                  _buildCard([
                    SwitchListTile(
                      activeThumbColor: BlushyColors.primary,
                      title: Text('Docsy Memory Enabled', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: BlushyColors.text)),
                      subtitle: Text('Allow Docsy to learn from your interactions over time.', style: GoogleFonts.manrope(fontSize: 12)),
                      value: pc.preferences.wantsSiaMemory,
                      onChanged: (val) {
                        final newPrefs = UserPreferences(
                          wantsCycleTracking: pc.preferences.wantsCycleTracking,
                          wantsVoiceFeatures: pc.preferences.wantsVoiceFeatures,
                          wantsPersonalizedRecommendations: pc.preferences.wantsPersonalizedRecommendations,
                          wantsSiaMemory: val,
                          wantsNotifications: pc.preferences.wantsNotifications,
                        );
                        e.set((c) => c.copyWith(preferences: newPrefs));
                      },
                    )
                  ]),

                  // Moved out of the journal's new-entry sheet: both are
                  // account-level settings, and neither had anything to do
                  // with starting an entry.
      ],
    );
  }

  Widget _sectionJournalPersonalisation(BuildContext context, _SectionEditor e) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                  _buildCard([
                    ListTile(
                      leading: const Icon(Icons.settings_rounded, color: BlushyColors.primary),
                      title: Text('Settings & Privacy Center',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: BlushyColors.text)),
                      subtitle: Text('Subsystem flags, diagnostics & accessibility',
                          style: GoogleFonts.manrope(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: BlushyColors.secondaryText),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const JournalSettingsScreen()),
                      ),
                    ),
                    const Divider(color: BlushyColors.border),
                    ListTile(
                      leading: const Icon(Icons.palette_rounded, color: BlushyColors.primary),
                      title: Text('Modular Theme Marketplace',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: BlushyColors.text)),
                      subtitle: Text('Mix & match covers, paper, fonts & audio',
                          style: GoogleFonts.manrope(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: BlushyColors.secondaryText),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ThemeMarketplaceWidget(onApplyTheme: (pack) {}),
                        ),
                      ),
                    ),
                  ]),
      ],
    );
  }

  Widget _sectionManageMyData(BuildContext context, _SectionEditor e) {
    final state = BlushyOSProvider.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                  _buildCard([
                    _buildDangerButton(
                      label: 'Restart Cycle Learning',
                      onPressed: () {
                        e.set((c) => c.copyWith(
                          confidence: DataConfidence.low,
                          cycleLength: null,
                          cycleDay: null,
                          cyclePhase: null,
                          lastPeriodStart: null,
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cycle learning reset on this device. Your logged periods are unchanged.')),
                        );
                      },
                    ),
                    const Divider(color: BlushyColors.border),
                    _buildDangerButton(
                      label: 'Reset AI Recommendations',
                      onPressed: () {
                        // This used to be a snackbar and nothing else -- it
                        // announced a reset that never happened. Clearing the
                        // cached observations, patterns and recommendations is
                        // something it can actually do, and the next load
                        // rebuilds them from current data.
                        SiaDashboardService().markDashboardDirty();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cleared. Suggestions will be worked out again from your current data.')),
                        );
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
                        // Local state only -- there is no endpoint that deletes stored logs, and
                        // the next sync brings the account's copy back. The message
                        // says what actually happened rather than claiming a deletion.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cleared from this view. Your saved logs are still on your account.')),
                        );
                      },
                    ),
                  ]),
      ],
    );
  }
  void _showAddMedicationDialog(BuildContext context, List<Medication> currentList) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: BlushyColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            "Add Medication / Supplement",
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 22),
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
              child: Text("Cancel", style: GoogleFonts.manrope(color: BlushyColors.secondaryText)),
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
              style: GoogleFonts.manrope(
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
              style: GoogleFonts.manrope(
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
              style: GoogleFonts.manrope(
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
              style: GoogleFonts.manrope(
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
          borderRadius: BorderRadius.circular(12),
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

  Widget _buildCard(dynamic children) {
    return Material(
      color: BlushyColors.cardBg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
      style: GoogleFonts.manrope(color: BlushyColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.manrope(color: BlushyColors.secondaryText),
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
        Text(label, style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: BlushyColors.text)),
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
            style: GoogleFonts.manrope(color: BlushyColors.primary, fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }

  Widget _buildDropdownRow<T>({required String label, required T value, required List<T> items, required ValueChanged<T?> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: BlushyColors.text)),
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
        style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

/// What a section screen hands its fields.
///
/// The account screen used to write every keystroke straight through to
/// state. A section is read-only until Edit is pressed; changes then go into
/// [pc], a draft, and reach state only when Save is pressed.
class _SectionEditor {
  const _SectionEditor({
    required this.pc,
    required this.editing,
    required this.set,
    required this.queue,
  });

  final PersonalContext pc;
  final bool editing;
  final void Function(PersonalContext Function(PersonalContext)) set;

  /// Holds a change that does not live on PersonalContext -- period length and
  /// the life-stage dates are stored server-side -- until Save. Without this
  /// they went over the network on every keystroke, so Save was not what
  /// committed them.
  final void Function(String field, Object? value) queue;
}

/// One section of the account, as its own screen with an Edit/Save pair.
class _AccountSectionScreen extends StatefulWidget {
  const _AccountSectionScreen({
    required this.title,
    required this.body,
    required this.editable,
    required this.onSave,
    required this.onFlush,
  });

  final String title;
  final Widget Function(BuildContext, _SectionEditor) body;

  /// False for sections that are links or one-off actions, which have no
  /// fields and so nothing to edit.
  final bool editable;

  final void Function(BuildContext, PersonalContext) onSave;

  /// Applies the queued server-side fields. Called with the same press as
  /// [onSave], and not at all if Cancel is pressed.
  final Future<void> Function(Map<String, Object?>) onFlush;

  @override
  State<_AccountSectionScreen> createState() => _AccountSectionScreenState();
}

class _AccountSectionScreenState extends State<_AccountSectionScreen> {
  bool _editing = false;
  PersonalContext? _draft;

  /// Server-side fields changed since Edit was pressed.
  final Map<String, Object?> _pending = {};

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    final pc = _draft ?? state.personalContext;

    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: BlushyColors.text),
        title: Text(
          widget.title,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
        actions: [
          if (widget.editable && !_editing)
            TextButton(
              onPressed: () => setState(() {
                _editing = true;
                _draft = state.personalContext;
              }),
              child: Text(
                'Edit',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.primary,
                ),
              ),
            ),
          if (widget.editable && _editing) ...[
            TextButton(
              onPressed: () => setState(() {
                _editing = false;
                _draft = null;
                _pending.clear();
              }),
              child: Text(
                'Cancel',
                style: GoogleFonts.manrope(color: BlushyColors.secondaryText),
              ),
            ),
            TextButton(
              onPressed: () {
                final draft = _draft;
                if (draft != null) widget.onSave(context, draft);
                if (_pending.isNotEmpty) {
                  widget.onFlush(Map<String, Object?>.from(_pending));
                }
                setState(() {
                  _editing = false;
                  _draft = null;
                  _pending.clear();
                });
              },
              child: Text(
                'Save',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.primary,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: BlushySpacing.lg,
            vertical: BlushySpacing.md,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Read-only until Edit: the fields are visible but inert, so
                  // nothing is changed by a stray tap on the way past.
                  IgnorePointer(
                    ignoring: widget.editable && !_editing,
                    child: Opacity(
                      opacity: (widget.editable && !_editing) ? 0.72 : 1,
                      child: widget.body(
                        context,
                        _SectionEditor(
                          pc: pc,
                          editing: _editing,
                          set: (update) => setState(
                            () => _draft = update(_draft ?? state.personalContext),
                          ),
                          queue: (field, value) =>
                              setState(() => _pending[field] = value),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Answers to the questions the app itself raises.
///
/// Every answer here describes something the app actually does; none of it is
/// aspirational.
class _AccountFaqScreen extends StatelessWidget {
  const _AccountFaqScreen();

  static const List<(String, String)> _faqs = [
    (
      'Is Docsy a doctor?',
      'No. Docsy is an AI companion. It never names a specific medicine or '
          'brand, and for anything to do with medication it will point you to a '
          'qualified physician. Treat it as a well-read friend, not a diagnosis.',
    ),
    (
      'How accurate are my cycle predictions?',
      'They are estimates built from the periods you have logged, and they get '
          'steadier the more you log. They are not reliable enough for '
          'contraception, and they are not a diagnosis. If too little has been '
          'logged, the app says so instead of guessing.',
    ),
    (
      'What can my partner see?',
      'Only what you allow. Nothing is shared until you connect a partner and '
          'choose what to share, in Privacy & Sharing on the Partner tab. '
          'Turning on Argument Mode pauses personal insights immediately, while '
          'shared activities keep working.',
    ),
    (
      'What does Docsy remember?',
      'Whatever you allow under Privacy & Companion Memory here. Switch memory '
          'off and it stops learning from your interactions over time.',
    ),
    (
      'Where do my journal entries live?',
      'On your device, with a copy on your account so they survive a reinstall '
          'or a move to the web. You can review what is stored under Settings & '
          'Privacy Center in Journal & Personalisation.',
    ),
    (
      'Why did my check-in options change?',
      'The home page is built from your onboarding answers, so the cards and '
          'options follow the stage and symptoms you chose. Changing your '
          'answers here changes what the home page offers.',
    ),
    (
      'Can I change my life stage later?',
      'Yes. Current Life Stage on this page holds the dates behind it, and the '
          'app re-shapes the home page around the stage you are in.',
    ),
    (
      'What happens when I reset my data?',
      'Manage My Data resets what the app has learned — cycle learning, AI '
          'recommendations, or symptom history — on this device. Your logged '
          'periods are not deleted by resetting cycle learning.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: BlushyColors.text),
        title: Text(
          'FAQ',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: BlushySpacing.lg,
            vertical: BlushySpacing.md,
          ),
          itemCount: _faqs.length,
          itemBuilder: (context, index) {
            final (question, answer) = _faqs[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              // A Material rather than a coloured box: ExpansionTile paints its
              // ink on the nearest Material, and a DecoratedBox over it hides
              // the splash entirely -- which Flutter asserts on.
              child: Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: BlushyColors.border),
                ),
                child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    question,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.text,
                    ),
                  ),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      answer,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        height: 1.55,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        ),
      ),
    );
  }
}

