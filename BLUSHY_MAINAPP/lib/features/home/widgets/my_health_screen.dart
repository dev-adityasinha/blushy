import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../legal/consent_status_card.dart';
import '../../../core/state.dart';
import '../../../services/api_auth_service.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/auth_storage.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../shared/confirm_sign_out.dart';
import '../../../services/sia_dashboard_service.dart';
import '../settings_draft.dart';

class MyHealthScreen extends StatefulWidget {
  const MyHealthScreen({super.key});

  @override
  State<MyHealthScreen> createState() => _MyHealthScreenState();
}

class _MyHealthScreenState extends State<MyHealthScreen> {
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

  Timer? _periodLengthDebounce;

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
    _periodLengthDebounce?.cancel();
    _nameController.dispose();
    _cycleLengthController.dispose();
    _periodLengthController.dispose();
    _medNameC.dispose();
    _medCategoryC.dispose();
    _medNotesC.dispose();
    super.dispose();
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
    await LifeStageApi.saveContext(patch);
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
    } catch (e) {
      if (mounted) {
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    final pc = state.personalContext;
    final email = (AuthStorage.getSession()['email'] as String?)?.trim();
    final dobLabel = pc.dateOfBirth == null ? 'Not set' : _formatDob(pc.dateOfBirth!);
    final cycleLenLabel = pc.cycleLength != null ? '${pc.cycleLength} days' : '—';
    final periodText = _periodLengthController.text.trim();
    final periodLenLabel = periodText.isNotEmpty ? '$periodText days' : '—';
    final trackingOn = pc.trackingPreference == CycleTrackingPreference.enabled;
    final memoryOn = pc.preferences.wantsSiaMemory;
    // How many of the four medical categories she has filled in, for the
    // consolidated "Health & Medical Profile" summary.
    final medicalFilled = [pc.medicalConditions, pc.userGoals, pc.userSymptoms]
            .where((s) => s.isNotEmpty)
            .length +
        (pc.medications.isNotEmpty ? 1 : 0);

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
                  // ── ACCOUNT & PROFILE ──
                  _buildGroupHeader('Account & Profile'),
                  _settingsGroup([
                    _settingsRow(
                      label: 'Preferred Name',
                      value: (pc.userName?.trim().isNotEmpty ?? false)
                          ? pc.userName!.trim()
                          : 'Add name',
                      onTap: () => _openSection(
                          'Preferred Name', true, _sectionPreferredName),
                    ),
                    _settingsRow(
                      label: 'Date of Birth',
                      value: dobLabel,
                      onTap: () => _openSection(
                          'Date of Birth', true, _sectionDateOfBirth),
                    ),
                    _settingsRow(
                      label: 'Email',
                      value: (email != null && email.isNotEmpty) ? email : '—',
                    ),
                  ]),

                  // ── CYCLE & BODY BASELINE ──
                  _buildGroupHeader('Cycle & Body Baseline'),
                  _settingsGroup([
                    // Current life stage is display-only here: it cannot be
                    // toggled on the settings page, only viewed.
                    _settingsRow(
                      label: 'Current Life Stage',
                      value: _stageLabel(pc.lifeStage),
                      onTap: () => _openSection(
                          'Current Life Stage', true, _sectionCurrentLifeStage),
                    ),
                    _settingsToggleRow(
                      label: 'Cycle Tracking',
                      value: trackingOn,
                      onChanged: (v) {
                        _saveField(
                          context,
                          (c) => c.copyWith(
                            trackingPreference: v
                                ? CycleTrackingPreference.enabled
                                : CycleTrackingPreference.disabled,
                          ),
                        );
                        setState(() {});
                      },
                    ),
                    _settingsRow(
                      label: 'Cycle Length',
                      value: cycleLenLabel,
                      onTap: () => _openSection(
                          'Cycle Configuration', true, _sectionCycleConfiguration),
                    ),
                    _settingsRow(
                      label: 'Period Length',
                      value: periodLenLabel,
                      onTap: () => _openSection(
                          'Cycle Configuration', true, _sectionCycleConfiguration),
                    ),
                    _settingsRow(
                      label: 'Health & Medical Profile',
                      value: medicalFilled > 0 ? 'Edit $medicalFilled items' : 'Not set',
                      onTap: () => _openSection('Health & Medical Profile', true,
                          _sectionHealthMedicalProfile),
                    ),
                  ]),

                  // ── APP PREFERENCES & DOCSY AI ──
                  _buildGroupHeader('App Preferences & Docsy AI'),
                  _settingsGroup([
                    _settingsToggleRow(
                      label: 'Docsy Memory',
                      value: memoryOn,
                      onChanged: (v) {
                        final p = pc.preferences;
                        _saveField(
                          context,
                          (c) => c.copyWith(
                            preferences: UserPreferences(
                              wantsCycleTracking: p.wantsCycleTracking,
                              wantsVoiceFeatures: p.wantsVoiceFeatures,
                              wantsPersonalizedRecommendations:
                                  p.wantsPersonalizedRecommendations,
                              wantsSiaMemory: v,
                              wantsNotifications: p.wantsNotifications,
                            ),
                          ),
                        );
                        setState(() {});
                      },
                    ),
                  ]),

                  // ── SUPPORT & ACCOUNT ──
                  _buildGroupHeader('Support & Account'),
                  _settingsGroup([
                    _settingsRow(
                      label: 'Help & FAQ',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const _AccountFaqScreen()),
                      ),
                    ),
                    _settingsRow(
                      label: 'Privacy & Data Reset',
                      onTap: () => _openSection(
                          'Privacy & Data Reset', false, _sectionManageMyData),
                    ),
                    _settingsRow(
                      label: 'Log Out',
                      danger: true,
                      showChevron: false,
                      onTap: () async {
                        if (!await confirmSignOut(context)) return;
                        await state.logout();
                        if (context.mounted) {
                          Navigator.of(context)
                              .pushNamedAndRemoveUntil('/', (route) => false);
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

  // Opens one of the detail editors as a pushed screen.
  void _openSection(
    String title,
    bool editable,
    Widget Function(BuildContext, _SectionEditor) body,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AccountSectionScreen(
          title: title,
          editable: editable,
          body: body,
          onSave: _commitDraft,
          onFlush: _flushPending,
        ),
      ),
    );
  }

  static const List<String> _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDob(DateTime d) => '${_monthAbbr[d.month - 1]} ${d.day}, ${d.year}';

  // Humanises the stored life-stage key for display (read-only).
  String _stageLabel(String? s) {
    if (s == null || s.trim().isEmpty) return 'Not set';
    final cleaned = s.replaceAll('_', ' ').trim();
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _buildGroupHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: BlushyColors.secondaryText,
          ),
        ),
      );

  Widget _settingsGroup(List<Widget> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: BlushyColors.border.withValues(alpha: 0.6),
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsRow({
    required String label,
    String? value,
    VoidCallback? onTap,
    bool danger = false,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: danger ? BlushyColors.primary : BlushyColors.text,
                ),
              ),
            ),
            if (value != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                ),
              ),
            if (onTap != null && showChevron)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.chevron_right_rounded,
                    size: 18, color: BlushyColors.secondaryText),
              ),
          ],
        ),
      ),
    );
  }

  Widget _settingsToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: BlushyColors.text,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: BlushyColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // Merge #21: the four medical cards (diagnoses, goals, symptom focus,
  // medications) are consolidated into one "Health & Medical Profile" editor.
  Widget _sectionHealthMedicalProfile(BuildContext context, _SectionEditor e) {
    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            t.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: BlushyColors.secondaryText,
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label('Diagnoses & Medical Conditions'),
        _sectionDiagnosesMedicalConditions(context, e),
        const SizedBox(height: 20),
        label('Health & Wellness Goals'),
        _sectionHealthWellnessGoals(context, e),
        const SizedBox(height: 20),
        label('Primary Symptom Focus'),
        _sectionPrimarySymptomFocus(context, e),
        const SizedBox(height: 20),
        label('Medications & Supplements'),
        _sectionMedicationsSupplements(context, e),
      ],
    );
  }



  /// Writes a finished draft through to state. Called by Save, never by a
  /// field.
  void _commitDraft(BuildContext ctx, PersonalContext draft) {
    // The stages come from the live profile, never from the draft: the
    // selector on this page saves a stage change at once, and a Save after
    // it used to write the snapshot's old stages back over it.
    _saveField(ctx, (current) => keepCurrentStages(draft, current));
  }

  /// Sends the fields that live on the server rather than on PersonalContext.
  ///
  /// Period duration is stored with the onboarding answers, and the life-stage
  /// dates go to LifeStageApi. Both used to fire on every keystroke or tap;
  /// they are held until Save now, like everything else on the page.
  Future<void> _flushPending(Map<String, Object?> pending) async {
    final days = pending['period_duration_days'];
    if (days is int) {
      try {
        await ApiAuthService()
            .saveOnboardingAnswers({'period_duration_days': days});
      } catch (_) {}
    }

    final branch = <String, dynamic>{
      for (final entry in pending.entries)
        if (entry.key.startsWith('branch:'))
          entry.key.substring('branch:'.length): entry.value,
    };
    if (branch.isNotEmpty) await _saveBranchContext(branch);
  }

  Widget _sectionPreferredName(BuildContext context, _SectionEditor e) {
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
                  ]),
      ],
    );
  }

  Widget _sectionDateOfBirth(BuildContext context, _SectionEditor e) {
    final pc = e.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                  _buildCard([
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
                  // Life stage is read-only here: it cannot be toggled from the
                  // settings page, only viewed. The dates behind it (below) stay
                  // correctable.
                  _buildCard([
                    Row(
                      children: [
                        const Icon(Icons.timeline_rounded, color: BlushyColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current Life Stage',
                                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.secondaryText)),
                              const SizedBox(height: 4),
                              Text(_stageLabel(pc.lifeStage),
                                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your life stage is set from onboarding and your cycle history — it can’t be switched here. Reach out in Help & FAQ if it looks wrong.',
                      style: GoogleFonts.manrope(fontSize: 12, height: 1.4, color: BlushyColors.secondaryText),
                    ),
                  ]),

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
                  const SizedBox(height: 20),
                  // Separated from the reset actions above: those change what
                  // this device shows, this ends the account. Google Play
                  // requires an in-app deletion route, and the legal screen has
                  // always promised one.
                  _buildCard([
                    // The record of what was agreed sits with the action that
                    // ends the agreement, so a user looking for one finds the
                    // other. Withdrawing and deleting are different things and
                    // the card says so.
                    const ConsentStatusCard(),
                    const Divider(color: BlushyColors.border),
                    _buildDangerButton(
                      label: 'Delete Account Permanently',
                      onPressed: () => _deleteAccount(context, state),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Removes your profile, period history, check-ins, journal, '
                        'Docsy conversations and partner connections from our servers. '
                        'This cannot be undone.',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          height: 1.45,
                          color: BlushyColors.secondaryText,
                        ),
                      ),
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

  /// Permanent account deletion.
  ///
  /// Two steps on purpose: the first says plainly what goes, the second asks
  /// the word to be typed. Nothing is deleted until the server confirms, and
  /// only then is the local session cleared -- a failed request must leave the
  /// account reachable rather than signed out of something still there.
  Future<void> _deleteAccount(BuildContext context, BlushyOSState state) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final understood = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete your account?',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text(
          'This permanently removes your profile, period history, check-ins, '
          'symptom logs, journal entries, Docsy conversations, community posts '
          'and partner connections.\n\nIt cannot be undone, and it cannot be '
          'recovered by signing in again.',
          style: GoogleFonts.manrope(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep my account', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Continue',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold, color: BlushyColors.danger)),
          ),
        ],
      ),
    );
    if (understood != true || !context.mounted) return;

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Type DELETE to confirm',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'DELETE'),
          style: GoogleFonts.manrope(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim().toUpperCase() == 'DELETE'),
            child: Text('Delete for ever',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold, color: BlushyColors.danger)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true) return;

    final ok = await ApiAuthService().deleteAccount();
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not delete the account. Check your connection and try again.'),
      ));
      return;
    }

    // The session is already gone server-side; this clears what the app holds.
    await state.logout();
    navigator.pushNamedAndRemoveUntil('/', (route) => false);
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

