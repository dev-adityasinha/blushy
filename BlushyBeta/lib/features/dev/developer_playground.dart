import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state.dart';
import '../../core/storage.dart';
import '../../theme/colors.dart';

class DeveloperPlaygroundScreen extends StatelessWidget {
  const DeveloperPlaygroundScreen({super.key});

  void _bypassAndLaunchHome(BuildContext context, {
    required String userName,
    required Set<String> medicalConditions,
    required Set<LifeContext> lifeContexts,
    required Set<String> userGoals,
    DateTime? dob,
  }) {
    final state = BlushyOSProvider.of(context);
    
    // Set mock profile
    state.updatePersonalContext(
      PersonalContext(
        userName: userName,
        dateOfBirth: dob ?? DateTime.now().subtract(const Duration(days: 365 * 14)), // Default young age
        trackingPreference: CycleTrackingPreference.enabled,
        cyclePattern: CyclePattern.predictable,
        confidence: DataConfidence.high,
        lifeContexts: lifeContexts,
        userGoals: userGoals,
        medicalConditions: medicalConditions,
        preferences: UserPreferences(),
        cycleLength: 28,
        cycleDay: 14,
        cyclePhase: "Follicular Phase",
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 14)),
        medications: [],
      ),
    );

    // Set auth flags
    state.setAuthenticated(true);
    state.setOnboardingCompleted(true);

    // Navigate to Home screen
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      appBar: AppBar(
        title: Text(
          "Developer Playground",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle("Onboarding Flows"),
              _buildDevButton(
                context,
                "Universal Onboarding Flow",
                onPressed: () {
                  final state = BlushyOSProvider.of(context);
                  state.setAuthenticated(false);
                  state.setOnboardingCompleted(false);
                  Navigator.of(context).pushNamedAndRemoveUntil('/onboarding/women', (route) => false);
                },
              ),
              _buildDevButton(
                context,
                "Partner Mode Onboarding",
                onPressed: () {
                  final state = BlushyOSProvider.of(context);
                  state.setAuthenticated(false);
                  state.setOnboardingCompleted(false);
                  Navigator.of(context).pushNamedAndRemoveUntil('/onboarding/partner', (route) => false);
                },
              ),
              const SizedBox(height: 24),
              
              _buildSectionTitle("Home Screen Slices (Direct Bypass)"),
              _buildDevButton(
                context,
                "First Period (Not Started) Home",
                onPressed: () {
                  BlushyStorage.write('onboarding_temp_profile.json', {
                    'profile': {
                      'lifeStage': 'firstPeriodNotStarted',
                      'answers': {'q1': 'nervous'},
                    }
                  });
                  _bypassAndLaunchHome(
                    context,
                    userName: "Maya",
                    medicalConditions: {'First Periods'},
                    lifeContexts: {LifeContext.other},
                    userGoals: {'Understand puberty'},
                    dob: DateTime.now().subtract(const Duration(days: 365 * 13)),
                  );
                },
              ),
              _buildDevButton(
                context,
                "First Period (Started) Home",
                onPressed: () {
                  BlushyStorage.write('onboarding_temp_profile.json', {
                    'profile': {
                      'lifeStage': 'firstPeriodStarted',
                      'answers': {},
                    }
                  });
                  _bypassAndLaunchHome(
                    context,
                    userName: "Maya",
                    medicalConditions: {'First Periods'},
                    lifeContexts: {LifeContext.other},
                    userGoals: {'Track my cycle'},
                    dob: DateTime.now().subtract(const Duration(days: 365 * 13)),
                  );
                },
              ),
               _buildDevButton(
                context,
                "Reproductive Home (Living With My Cycle)",
                onPressed: () {
                  BlushyStorage.write('onboarding_temp_profile.json', {
                    'profile': {
                      'lifeStage': 'reproductiveYears',
                      'answers': {},
                    }
                  });
                  _bypassAndLaunchHome(
                    context,
                    userName: "Emma",
                    medicalConditions: {},
                    lifeContexts: {LifeContext.other},
                    userGoals: {'Track my cycle'},
                    dob: DateTime.now().subtract(const Duration(days: 365 * 26)),
                  );
                },
              ),
              _buildDevButton(
                context,
                "Hormonal Health Home (PCOS)",
                onPressed: () => _bypassAndLaunchHome(
                  context,
                  userName: "Elena",
                  medicalConditions: {'PCOS'},
                  lifeContexts: {LifeContext.other},
                  userGoals: {'Manage symptoms'},
                ),
              ),
              _buildDevButton(
                context,
                "TTC (Trying to Conceive) Home",
                onPressed: () => _bypassAndLaunchHome(
                  context,
                  userName: "Rachel",
                  medicalConditions: {},
                  lifeContexts: {LifeContext.other},
                  userGoals: {'Explore fertility'},
                ),
              ),
              _buildDevButton(
                context,
                "Pregnancy Home",
                onPressed: () => _bypassAndLaunchHome(
                  context,
                  userName: "Chloe",
                  medicalConditions: {},
                  lifeContexts: {LifeContext.pregnancy},
                  userGoals: {'Healthy delivery'},
                ),
              ),
              _buildDevButton(
                context,
                "Postpartum Home",
                onPressed: () => _bypassAndLaunchHome(
                  context,
                  userName: "Jessica",
                  medicalConditions: {},
                  lifeContexts: {LifeContext.postpartum},
                  userGoals: {'Recover post baby'},
                ),
              ),
              _buildDevButton(
                context,
                "Perimenopause Home",
                onPressed: () => _bypassAndLaunchHome(
                  context,
                  userName: "Linda",
                  medicalConditions: {},
                  lifeContexts: {LifeContext.perimenopause},
                  userGoals: {'Understand transition'},
                ),
              ),
              _buildDevButton(
                context,
                "Menopause Home",
                onPressed: () => _bypassAndLaunchHome(
                  context,
                  userName: "Monica",
                  medicalConditions: {},
                  lifeContexts: {LifeContext.menopause},
                  userGoals: {'Hormone management'},
                ),
              ),
              const SizedBox(height: 24),
              
              _buildSectionTitle("Other Modules"),
              _buildDevButton(
                context,
                "Community Spotlight Slice",
                onPressed: () {
                  _bypassAndLaunchHome(context, userName: "Developer", medicalConditions: {'First Periods'}, lifeContexts: {LifeContext.other}, userGoals: {});
                },
              ),
              _buildDevButton(
                context,
                "Partner Space Garden",
                onPressed: () {
                  _bypassAndLaunchHome(context, userName: "Developer", medicalConditions: {}, lifeContexts: {LifeContext.other}, userGoals: {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildDevButton(BuildContext context, String label, {required VoidCallback onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: BlushyColors.text,
          elevation: 0,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: BlushyColors.border),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: BlushyColors.secondaryText),
          ],
        ),
      ),
    );
  }
}
