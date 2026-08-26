import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../theme/colors.dart';
import '../../../services/api_auth_service.dart';
import '../../legal/legal_documents_screen.dart';

enum PartnerOnboardingPhase {
  privacy,
  questions,
  building,
  ready,
}

class PartnerOnboardingProfile {
  String partnerName = '';
  String partnerStage = 'First Periods';
  bool completed = false;

  Map<String, dynamic> toJson() {
    return {
      'partnerName': partnerName,
      'partnerStage': partnerStage,
      'completed': completed,
    };
  }
}

class PartnerOnboardingWizard extends StatefulWidget {
  const PartnerOnboardingWizard({super.key});

  @override
  State<PartnerOnboardingWizard> createState() => _PartnerOnboardingWizardState();
}

class _PartnerOnboardingWizardState extends State<PartnerOnboardingWizard> {
  PartnerOnboardingPhase _phase = PartnerOnboardingPhase.privacy;
  final PartnerOnboardingProfile _profile = PartnerOnboardingProfile();
  int _currentStepIndex = 0;
  bool _isLoading = false;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();

  // For the Building Staggered Loader
  double _buildProgress = 0.0;
  Timer? _buildTimer;
  final List<Map<String, dynamic>> _buildSteps = [
    {'title': 'Connecting with partner space...', 'done': false},
    {'title': 'Preparing health education guides...', 'done': false},
    {'title': 'Configuring notification settings...', 'done': false},
    {'title': 'Sia relationship assistant initialized...', 'done': false},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _buildTimer?.cancel();
    super.dispose();
  }

  void _startBuildingPhase() {
    setState(() {
      _phase = PartnerOnboardingPhase.building;
      _buildProgress = 0.0;
    });

    const totalDurationMs = 3500;
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

  void _finishPartnerOnboarding() {
    final state = BlushyOSProvider.of(context);

    // Save temporary partner onboarding profile
    try {
      File('partner_onboarding_profile.json').writeAsStringSync(jsonEncode(_profile.toJson()));
    } catch (_) {}

    // Send partner onboarding answers to backend API
    final Map<String, dynamic> partnerAnswers = {
      'preferred_name': _profile.partnerName.isNotEmpty ? _profile.partnerName : 'Partner User',
      'date_of_birth': '2000-01-01',
      'partner_stage': _profile.partnerStage,
      'role': 'partner',
    };
    ApiAuthService().saveOnboardingAnswers(partnerAnswers).catchError((err) {
      debugPrint('BlushyBackend: Partner onboarding sync exception: $err');
      return <String, dynamic>{};
    });

    // Complete authentication flags
    state.setAuthenticated(true);
    state.setOnboardingCompleted(true);

    // Route to home / partner screen
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF6F0),
        body: Center(child: CircularProgressIndicator(color: BlushyColors.primary)),
      );
    }

    switch (_phase) {
      case PartnerOnboardingPhase.privacy:
        return _buildPrivacyScreen();
      case PartnerOnboardingPhase.questions:
        return _buildQuestionsScreen();
      case PartnerOnboardingPhase.building:
        return _buildBuildingScreen();
      case PartnerOnboardingPhase.ready:
        return _buildReadyScreen();
    }
  }

  Widget _buildPrivacyScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Center(
                    child: Icon(Icons.favorite_outline_rounded, size: 72, color: BlushyColors.primary),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    "Support, Privately.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "You are entering Partner Mode. Everything you do helps you support your partner. Data sharing is secure, consent-based, and respects privacy at every step.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.privacyPolicy),
                        child: Text(
                          "Privacy Policy",
                          style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                        ),
                      ),
                      Text(" • ", style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText)),
                      GestureDetector(
                        onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.termsAndConditions),
                        child: Text(
                          "Terms of Service",
                          style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _phase = PartnerOnboardingPhase.questions;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      "I Agree & Continue",
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildQuestionsScreen() {
    if (_currentStepIndex == 0) {
      return _buildQuestionCard(
        title: "What is your partner's name?",
        child: TextField(
          controller: _nameController,
          style: GoogleFonts.poppins(fontSize: 16, color: BlushyColors.text),
          decoration: InputDecoration(
            hintText: "Enter preferred name",
            hintStyle: GoogleFonts.poppins(color: BlushyColors.secondaryText.withOpacity(0.5)),
            border: UnderlineInputBorder(borderSide: BorderSide(color: BlushyColors.primary)),
          ),
          onChanged: (val) {
            setState(() {
              _profile.partnerName = val.trim();
            });
          },
        ),
        onNext: _profile.partnerName.isNotEmpty
            ? () {
                setState(() {
                  _currentStepIndex = 1;
                });
              }
            : null,
      );
    } else {
      final stages = [
        'First Periods',
        'Reproductive Years',
        'Trying to Conceive',
        'Pregnancy',
        'Postpartum',
        'Menopause',
      ];
      return _buildQuestionCard(
        title: "Select your partner's current stage",
        child: Column(
          children: stages.map((stage) {
            final isSelected = _profile.partnerStage == stage;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _profile.partnerStage = stage;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? BlushyColors.primary.withOpacity(0.08) : Colors.white,
                  border: Border.all(color: isSelected ? BlushyColors.primary : BlushyColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stage,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: BlushyColors.text),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_outline, color: BlushyColors.primary, size: 18),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        onNext: () {
          _startBuildingPhase();
        },
      );
    }
  }

  Widget _buildQuestionCard({required String title, required Widget child, VoidCallback? onNext}) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: BlushyColors.text, size: 18),
          onPressed: () {
            if (_currentStepIndex > 0) {
              setState(() {
                _currentStepIndex--;
              });
            } else {
              setState(() {
                _phase = PartnerOnboardingPhase.privacy;
              });
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Step ${_currentStepIndex + 1} of 2",
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary, letterSpacing: 1.0),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: BlushyColors.text),
              ),
              const SizedBox(height: 36),
              Expanded(child: SingleChildScrollView(child: child)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BlushyColors.primary,
                  disabledBackgroundColor: BlushyColors.primary.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  "Continue",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuildingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Setting up Partner Mode...",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: BlushyColors.text),
                ),
                const SizedBox(height: 12),
                Text(
                  "${(_buildProgress * 100).toInt()}% Complete",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.primary, fontWeight: FontWeight.bold),
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
                            style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadyScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
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
                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: BlushyColors.text),
              ),
              const SizedBox(height: 12),
              Text(
                "You're ready to support ${_profile.partnerName} through her ${_profile.partnerStage} journey.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.secondaryText, height: 1.5),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _finishPartnerOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BlushyColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  "Enter Partner Mode",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
