import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';

class MyHealthScreen extends StatefulWidget {
  const MyHealthScreen({super.key});

  @override
  State<MyHealthScreen> createState() => _MyHealthScreenState();
}

class _MyHealthScreenState extends State<MyHealthScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cycleLengthController = TextEditingController();
  
  // Medication input temp controllers
  final TextEditingController _medNameC = TextEditingController();
  final TextEditingController _medCategoryC = TextEditingController();
  final TextEditingController _medNotesC = TextEditingController();

  bool _initialized = false;

  // Autosave status tracking
  // 'idle' | 'saving' | 'saved' | 'error'
  String _saveStatus = 'idle';
  Timer? _saveStatusTimer;
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
    }
  }

  @override
  void dispose() {
    _saveStatusTimer?.cancel();
    _checkAnimController.dispose();
    _nameController.dispose();
    _cycleLengthController.dispose();
    _medNameC.dispose();
    _medCategoryC.dispose();
    _medNotesC.dispose();
    super.dispose();
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
                        _saveField(context, (c) => PersonalContext(
                          userName: val.trim().isEmpty ? null : val.trim(),
                          dateOfBirth: c.dateOfBirth,
                          trackingPreference: c.trackingPreference,
                          cyclePattern: c.cyclePattern,
                          confidence: c.confidence,
                          lifeContexts: c.lifeContexts,
                          userGoals: c.userGoals,
                          medicalConditions: c.medicalConditions,
                          preferences: c.preferences,
                          cycleLength: c.cycleLength,
                          cycleDay: c.cycleDay,
                          cyclePhase: c.cyclePhase,
                          lastPeriodStart: c.lastPeriodStart,
                          medications: c.medications,
                        ));
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDatePickerRow(
                      label: 'Date of Birth',
                      value: pc.dateOfBirth,
                      onSelected: (date) {
                        _saveField(context, (c) => PersonalContext(
                          userName: c.userName,
                          dateOfBirth: date,
                          trackingPreference: c.trackingPreference,
                          cyclePattern: c.cyclePattern,
                          confidence: c.confidence,
                          lifeContexts: c.lifeContexts,
                          userGoals: c.userGoals,
                          medicalConditions: c.medicalConditions,
                          preferences: c.preferences,
                          cycleLength: c.cycleLength,
                          cycleDay: c.cycleDay,
                          cyclePhase: c.cyclePhase,
                          lastPeriodStart: c.lastPeriodStart,
                          medications: c.medications,
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
                          _saveField(context, (c) => PersonalContext(
                            userName: c.userName,
                            dateOfBirth: c.dateOfBirth,
                            trackingPreference: val,
                            cyclePattern: c.cyclePattern,
                            confidence: c.confidence,
                            lifeContexts: c.lifeContexts,
                            userGoals: c.userGoals,
                            medicalConditions: c.medicalConditions,
                            preferences: c.preferences,
                            cycleLength: c.cycleLength,
                            cycleDay: c.cycleDay,
                            cyclePhase: c.cyclePhase,
                            lastPeriodStart: c.lastPeriodStart,
                            medications: c.medications,
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
                            _saveField(context, (c) => PersonalContext(
                              userName: c.userName,
                              dateOfBirth: c.dateOfBirth,
                              trackingPreference: c.trackingPreference,
                              cyclePattern: val,
                              confidence: c.confidence,
                              lifeContexts: c.lifeContexts,
                              userGoals: c.userGoals,
                              medicalConditions: c.medicalConditions,
                              preferences: c.preferences,
                              cycleLength: c.cycleLength,
                              cycleDay: c.cycleDay,
                              cyclePhase: c.cyclePhase,
                              lastPeriodStart: c.lastPeriodStart,
                              medications: c.medications,
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
                          _saveField(context, (c) => PersonalContext(
                            userName: c.userName,
                            dateOfBirth: c.dateOfBirth,
                            trackingPreference: c.trackingPreference,
                            cyclePattern: c.cyclePattern,
                            confidence: c.confidence,
                            lifeContexts: c.lifeContexts,
                            userGoals: c.userGoals,
                            medicalConditions: c.medicalConditions,
                            preferences: c.preferences,
                            cycleLength: len,
                            cycleDay: c.cycleDay,
                            cyclePhase: c.cyclePhase,
                            lastPeriodStart: c.lastPeriodStart,
                            medications: c.medications,
                          ));
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDatePickerRow(
                        label: 'Last Period Start Date',
                        value: pc.lastPeriodStart,
                        onSelected: (date) {
                          _saveField(context, (c) => PersonalContext(
                            userName: c.userName,
                            dateOfBirth: c.dateOfBirth,
                            trackingPreference: c.trackingPreference,
                            cyclePattern: c.cyclePattern,
                            confidence: c.confidence,
                            lifeContexts: c.lifeContexts,
                            userGoals: c.userGoals,
                            medicalConditions: c.medicalConditions,
                            preferences: c.preferences,
                            cycleLength: c.cycleLength,
                            cycleDay: c.cycleDay,
                            cyclePhase: c.cyclePhase,
                            lastPeriodStart: date,
                            medications: c.medications,
                          ));
                        },
                      ),
                    ]
                  ]),

                  _buildSectionHeader('Current Life Stage'),
                  _buildCard(
                    LifeContext.values.where((e) => e != LifeContext.none).map((stage) {
                      final isSelected = pc.lifeContexts.contains(stage);
                      return CheckboxListTile(
                        activeColor: BlushyColors.primary,
                        title: Text(
                          stage.toString().split('.').last.replaceAllMapped(
                            RegExp(r'([A-Z])'), 
                            (match) => ' ${match.group(1)}'
                          ).toUpperCase(),
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text),
                        ),
                        value: isSelected,
                        onChanged: (val) {
                          final newStages = Set<LifeContext>.from(pc.lifeContexts);
                          if (val == true) {
                            newStages.add(stage);
                            newStages.remove(LifeContext.none);
                          } else {
                            newStages.remove(stage);
                            if (newStages.isEmpty) newStages.add(LifeContext.none);
                          }
                          _saveField(context, (c) => PersonalContext(
                            userName: c.userName,
                            dateOfBirth: c.dateOfBirth,
                            trackingPreference: c.trackingPreference,
                            cyclePattern: c.cyclePattern,
                            confidence: c.confidence,
                            lifeContexts: newStages,
                            userGoals: c.userGoals,
                            medicalConditions: c.medicalConditions,
                            preferences: c.preferences,
                            cycleLength: c.cycleLength,
                            cycleDay: c.cycleDay,
                            cyclePhase: c.cyclePhase,
                            lastPeriodStart: c.lastPeriodStart,
                            medications: c.medications,
                          ));
                        },
                      );
                    }).toList(),
                  ),

                  _buildSectionHeader('Diagnoses & Medical Conditions'),
                  _buildCard([
                    ...['PCOS', 'Endometriosis', 'Adenomyosis', 'Fibroids', 'PMDD / PMS'].map((cond) {
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
                          _saveField(context, (c) => PersonalContext(
                            userName: c.userName,
                            dateOfBirth: c.dateOfBirth,
                            trackingPreference: c.trackingPreference,
                            cyclePattern: c.cyclePattern,
                            confidence: c.confidence,
                            lifeContexts: c.lifeContexts,
                            userGoals: c.userGoals,
                            medicalConditions: newConds,
                            preferences: c.preferences,
                            cycleLength: c.cycleLength,
                            cycleDay: c.cycleDay,
                            cyclePhase: c.cyclePhase,
                            lastPeriodStart: c.lastPeriodStart,
                            medications: c.medications,
                          ));
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
                        separatorBuilder: (_, __) => const Divider(color: BlushyColors.border),
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
                                _saveField(context, (c) => PersonalContext(
                                  userName: c.userName,
                                  dateOfBirth: c.dateOfBirth,
                                  trackingPreference: c.trackingPreference,
                                  cyclePattern: c.cyclePattern,
                                  confidence: c.confidence,
                                  lifeContexts: c.lifeContexts,
                                  userGoals: c.userGoals,
                                  medicalConditions: c.medicalConditions,
                                  preferences: c.preferences,
                                  cycleLength: c.cycleLength,
                                  cycleDay: c.cycleDay,
                                  cyclePhase: c.cyclePhase,
                                  lastPeriodStart: c.lastPeriodStart,
                                  medications: list,
                                ));
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
                        backgroundColor: BlushyColors.primary.withOpacity(0.06),
                        foregroundColor: BlushyColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  ]),

                  _buildSectionHeader('Privacy & Companion Memory'),
                  _buildCard([
                    SwitchListTile(
                      activeColor: BlushyColors.primary,
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
                        _saveField(context, (c) => PersonalContext(
                          userName: c.userName,
                          dateOfBirth: c.dateOfBirth,
                          trackingPreference: c.trackingPreference,
                          cyclePattern: c.cyclePattern,
                          confidence: c.confidence,
                          lifeContexts: c.lifeContexts,
                          userGoals: c.userGoals,
                          medicalConditions: c.medicalConditions,
                          preferences: newPrefs,
                          cycleLength: c.cycleLength,
                          cycleDay: c.cycleDay,
                          cyclePhase: c.cyclePhase,
                          lastPeriodStart: c.lastPeriodStart,
                          medications: c.medications,
                        ));
                      },
                    )
                  ]),

                  _buildSectionHeader('Manage My Data'),
                  _buildCard([
                    _buildDangerButton(
                      label: 'Restart Cycle Learning',
                      onPressed: () {
                        _saveField(context, (c) => PersonalContext(
                          userName: c.userName,
                          dateOfBirth: c.dateOfBirth,
                          trackingPreference: c.trackingPreference,
                          cyclePattern: c.cyclePattern,
                          confidence: DataConfidence.low,
                          lifeContexts: c.lifeContexts,
                          userGoals: c.userGoals,
                          medicalConditions: c.medicalConditions,
                          preferences: c.preferences,
                          cycleLength: null,
                          cycleDay: null,
                          cyclePhase: null,
                          lastPeriodStart: null,
                          medications: c.medications,
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
                      onPressed: () {
                        state.logout();
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
                  _saveField(context, (c) => PersonalContext(
                    userName: c.userName,
                    dateOfBirth: c.dateOfBirth,
                    trackingPreference: c.trackingPreference,
                    cyclePattern: c.cyclePattern,
                    confidence: c.confidence,
                    lifeContexts: c.lifeContexts,
                    userGoals: c.userGoals,
                    medicalConditions: c.medicalConditions,
                    preferences: c.preferences,
                    cycleLength: c.cycleLength,
                    cycleDay: c.cycleDay,
                    cyclePhase: c.cyclePhase,
                    lastPeriodStart: c.lastPeriodStart,
                    medications: list,
                  ));
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
                color: BlushyColors.primary.withOpacity(0.7),
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
            Icon(Icons.cloud_done_outlined, color: BlushyColors.secondaryText.withOpacity(0.5), size: 16),
            const SizedBox(width: 5),
            Text(
              'Autosaved',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: BlushyColors.secondaryText.withOpacity(0.5),
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
                  : BlushyColors.background.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _saveStatus == 'saved'
                ? const Color(0xFF43A047).withOpacity(0.3)
                : _saveStatus == 'error'
                    ? const Color(0xFFD32F2F).withOpacity(0.3)
                    : BlushyColors.border.withOpacity(0.3),
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
        fillColor: BlushyColors.background.withOpacity(0.5),
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
