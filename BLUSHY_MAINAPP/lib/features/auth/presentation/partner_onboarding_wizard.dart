import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../core/storage.dart';
import '../../../theme/colors.dart';
import '../../../services/api_auth_service.dart';
import '../../../l10n/app_localizations.dart';

enum PartnerOnboardingPhase {
  questions,
  privacy,
  building,
  ready,
}

class PartnerOnboardingWizard extends StatefulWidget {
  const PartnerOnboardingWizard({super.key});

  @override
  State<PartnerOnboardingWizard> createState() => _PartnerOnboardingWizardState();
}

class _PartnerOnboardingWizardState extends State<PartnerOnboardingWizard> {
  PartnerOnboardingPhase _phase = PartnerOnboardingPhase.questions;
  int _currentStepIndex = 0; // 0: Name, 1: Relationship description, 2: Goals, 3: Depth

  // User responses
  String _preferredName = '';
  String _relationshipType = 'Partner';
  final List<String> _selectedGoals = [];
  String _learningDepth = 'I\'d like to understand more';

  final TextEditingController _nameController = TextEditingController();

  // Building loader state
  double _buildProgress = 0.0;
  Timer? _buildTimer;
  final List<Map<String, dynamic>> _buildSteps = [
    {'title': 'Connecting with partner space...', 'done': false},
    {'title': 'Preparing support insights...', 'done': false},
    {'title': 'Setting up privacy controls...', 'done': false},
    {'title': 'Docsy assistant ready...', 'done': false},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _buildTimer?.cancel();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStepIndex < 3) {
      setState(() {
        _currentStepIndex++;
      });
    } else {
      setState(() {
        _phase = PartnerOnboardingPhase.privacy;
      });
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    }
  }

  void _startBuildingPhase() {
    setState(() {
      _phase = PartnerOnboardingPhase.building;
      _buildProgress = 0.0;
    });

    const totalDurationMs = 2500;
    const tickMs = 50;
    int elapsedMs = 0;

    _buildTimer = Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
      elapsedMs += tickMs;
      final ratio = elapsedMs / totalDurationMs;
      
      setState(() {
        _buildProgress = ratio.clamp(0.0, 1.0);
        if (ratio >= 0.25) _buildSteps[0]['done'] = true;
        if (ratio >= 0.50) _buildSteps[1]['done'] = true;
        if (ratio >= 0.75) _buildSteps[2]['done'] = true;
        if (ratio >= 0.95) _buildSteps[3]['done'] = true;
      });

      if (elapsedMs >= totalDurationMs) {
        timer.cancel();
        setState(() {
          _phase = PartnerOnboardingPhase.ready;
        });
      }
    });
  }

  Future<void> _finishOnboarding() async {
    final state = BlushyOSProvider.of(context);

    // Save profile to user_profile.json
    final profileData = {
      'role': 'partner',
      'profile': {
        'userName': _preferredName,
        'preferredName': _preferredName,
        'relationshipType': _relationshipType,
        'supportGoals': _selectedGoals,
        'learningDepth': _learningDepth,
        'lifeStage': 'everydayWellness', // Fallback defaults
      }
    };
    try {
      BlushyStorage.write('user_profile.json', profileData);
    } catch (_) {}

    // Sync onboarding answers to backend database so onboardingCompleted is saved in MongoDB
    final backendAnswers = {
      'preferred_name': _preferredName,
      'relationship_type': _relationshipType,
      'support_goals': _selectedGoals,
      'learning_depth': _learningDepth,
      'role': 'partner',
    };
    try {
      await ApiAuthService().saveOnboardingAnswers(backendAnswers);
    } catch (err) {
      debugPrint('BlushyBackend: Partner onboarding sync exception: $err');
    }

    // Complete authentication and role flags
    state.setSelectedRole('partner');
    state.setAuthenticated(true);
    state.setOnboardingCompleted(true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case PartnerOnboardingPhase.questions:
        return _buildQuestionsScreen();
      case PartnerOnboardingPhase.privacy:
        return _buildPrivacyScreen();
      case PartnerOnboardingPhase.building:
        return _buildBuildingScreen();
      case PartnerOnboardingPhase.ready:
        return _buildReadyScreen();
    }
  }

  Widget _buildQuestionsScreen() {
    String title = "";
    Widget content = const SizedBox.shrink();
    VoidCallback? onNextAction;

    if (_currentStepIndex == 0) {
      title = "What should we call you?";
      content = TextField(
        controller: _nameController,
        style: GoogleFonts.manrope(fontSize: 16, color: BlushyColors.text),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).poYourPreferredName,
          hintStyle: GoogleFonts.manrope(color: BlushyColors.secondaryText.withValues(alpha: 0.5)),
          border: const UnderlineInputBorder(borderSide: BorderSide(color: BlushyColors.primary)),
        ),
        onChanged: (val) {
          setState(() {
            _preferredName = val.trim();
          });
        },
      );
      onNextAction = _preferredName.isNotEmpty ? _nextStep : null;
    } else if (_currentStepIndex == 1) {
      title = "How would you describe your relationship?";
      final relations = ["Partner", "Husband", "Boyfriend", "Other"];
      content = Column(
        children: relations.map((rel) {
          final isSelected = _relationshipType == rel;
          return _buildOptionRow(
            label: rel,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _relationshipType = rel;
              });
            },
          );
        }).toList(),
      );
      onNextAction = _nextStep;
    } else if (_currentStepIndex == 2) {
      title = "What would you like help with?";
      final goals = [
        "Understanding what she's going through",
        "Knowing how to support her",
        "Communicating better",
        "Helping during difficult days",
        "Supporting pregnancy or TTC",
        "Understanding her life stage",
        "Becoming a better partner",
      ];
      content = Column(
        children: goals.map((goal) {
          final isSelected = _selectedGoals.contains(goal);
          return _buildOptionRow(
            label: goal,
            isSelected: isSelected,
            isMultiSelect: true,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedGoals.remove(goal);
                } else {
                  _selectedGoals.add(goal);
                }
              });
            },
          );
        }).toList(),
      );
      onNextAction = _selectedGoals.isNotEmpty ? _nextStep : null;
    } else if (_currentStepIndex == 3) {
      title = "How much would you like to learn?";
      final depths = [
        "Just tell me what I need to know",
        "I'd like to understand more",
        "I want to learn properly",
      ];
      content = Column(
        children: depths.map((d) {
          final isSelected = _learningDepth == d;
          return _buildOptionRow(
            label: d,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _learningDepth = d;
              });
            },
          );
        }).toList(),
      );
      onNextAction = _nextStep;
    }

    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStepIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: BlushyColors.text, size: 18),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "QUESTION ${_currentStepIndex + 1} OF 4",
                style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: BlushyColors.primary, letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.manrope(fontSize: 26, fontWeight: FontWeight.bold, color: BlushyColors.text, height: 1.25),
              ),
              const SizedBox(height: 32),
              Expanded(child: SingleChildScrollView(child: content)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onNextAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BlushyColors.primary,
                  disabledBackgroundColor: BlushyColors.primary.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  "Continue",
                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isMultiSelect = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected ? BlushyColors.primary.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(color: isSelected ? BlushyColors.primary : BlushyColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: BlushyColors.text),
              ),
            ),
            if (isSelected)
              Icon(
                isMultiSelect ? Icons.check_box_outlined : Icons.check_circle_rounded,
                color: BlushyColors.primary,
                size: 20,
              )
            else if (isMultiSelect)
              Icon(
                Icons.check_box_outline_blank,
                color: BlushyColors.secondaryText.withValues(alpha: 0.4),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.only(top: 28, bottom: 20, left: 20, right: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      // Compact Luxury Soft Ambient Shield Icon Badge
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4F1),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF4DCD6), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: BlushyColors.primary.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          size: 26,
                          color: BlushyColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Headline: Cormorant Garamond w700 (24px)
                      Text(
                        "Her privacy comes first.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.normal,
                          letterSpacing: 0.2,
                          height: 1.15,
                          color: const Color(0xFF2D2529),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle: Manrope w400 (12.5px)
                      Text(
                        "Partner mode is designed around trust and explicit consent. She stays in complete control of what she chooses to share with you.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.15,
                          height: 1.4,
                          color: const Color(0xFF7A6B72),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3 Compact Luxury Privacy Pillars Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDF9),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFECE4DC), width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildPartnerPrivacyPillar(
                              icon: Icons.mark_email_read_outlined,
                              title: "Explicit Sharing",
                              subtitle: "Only receive information she explicitly chooses to share.",
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Divider(color: Color(0xFFF2ECE4), height: 1),
                            ),
                            _buildPartnerPrivacyPillar(
                              icon: Icons.lock_person_outlined,
                              title: "Private Conversations",
                              subtitle: "Private logs and chats are never visible to partners.",
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Divider(color: Color(0xFFF2ECE4), height: 1),
                            ),
                            _buildPartnerPrivacyPillar(
                              icon: Icons.tune_rounded,
                              title: "Her Choice, Any Time",
                              subtitle: "She can adjust or pause partner sharing whenever she wants.",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Compact Luxury Button (46px Pill)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _startBuildingPhase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        elevation: 3,
                        shadowColor: BlushyColors.primary.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                      child: const Text(
                        "I Understand & Continue",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.normal,
                          letterSpacing: 0.3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerPrivacyPillar({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4F1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: BlushyColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D2529),
                  letterSpacing: 0.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF8A7C83),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuildingScreen() {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Setting up Partner Mode...",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.bold, color: BlushyColors.text),
              ),
              const SizedBox(height: 12),
              Text(
                "${(_buildProgress * 100).toInt()}% Complete",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 13, color: BlushyColors.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _buildProgress,
                  backgroundColor: BlushyColors.border,
                  color: BlushyColors.primary,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 36),
              ..._buildSteps.map((step) {
                final isDone = step['done'] as bool;
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isDone ? 1.0 : 0.4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle_outline : Icons.radio_button_off,
                          color: isDone ? BlushyColors.success : BlushyColors.secondaryText,
                          size: 16,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          step['title'] as String,
                          style: GoogleFonts.manrope(fontSize: 13, color: BlushyColors.text),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadyScreen() {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(
                child: Icon(Icons.check_circle_outline, size: 72, color: BlushyColors.success),
              ),
              const SizedBox(height: 24),
              Text(
                "Partner Space Ready",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.bold, color: BlushyColors.text),
              ),
              const SizedBox(height: 12),
              Text(
                "You're ready to show up for your partner, supported by Blushy relationship guides.",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 14, color: BlushyColors.secondaryText, height: 1.5),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _finishOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BlushyColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  "Enter Partner Mode",
                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
