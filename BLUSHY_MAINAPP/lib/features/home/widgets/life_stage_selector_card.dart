import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../core/storage.dart';
import '../../../core/stage_conflict_engine.dart';
import '../../../theme/colors.dart';
import 'stage_questionnaire_dialog.dart';
import 'stage_conflict_dialog.dart';

class LifeStageInfo {
  final String key;
  final String title;
  final String description;
  final IconData icon;

  const LifeStageInfo({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
  });
}

const List<LifeStageInfo> kAllLifeStages = [
  LifeStageInfo(
    key: 'firstPeriodNotStarted',
    title: 'First Period (Not Started)',
    description: 'Puberty changes, body readiness & cycle preparations.',
    icon: Icons.spa_outlined,
  ),
  LifeStageInfo(
    key: 'firstPeriodStarted',
    title: 'First Period (Started)',
    description: 'Cycle confidence, symptom logging & young body tracking.',
    icon: Icons.water_drop_outlined,
  ),
  LifeStageInfo(
    key: 'reproductiveYears',
    title: 'Reproductive Years',
    description: 'Living with your cycle, phase predictions & vitality.',
    icon: Icons.favorite_border_rounded,
  ),
  LifeStageInfo(
    key: 'hormonalHealth',
    title: 'Hormonal Health',
    description: 'Specialized support for PCOS, Endometriosis, PMDD & hormones.',
    icon: Icons.healing_outlined,
  ),
  LifeStageInfo(
    key: 'tryingToConceive',
    title: 'Trying to Conceive',
    description: 'Fertility window, ovulation LH tests & BBT tracking.',
    icon: Icons.egg_outlined,
  ),
  LifeStageInfo(
    key: 'pregnancy',
    title: 'Pregnancy',
    description: 'Gestational weeks, baby milestones & trimester wellness.',
    icon: Icons.child_care_rounded,
  ),
  LifeStageInfo(
    key: 'postpartum',
    title: 'Postpartum',
    description: 'Maternal recovery, baby feeding, sleep & healing.',
    icon: Icons.family_restroom_rounded,
  ),
  LifeStageInfo(
    key: 'perimenopause',
    title: 'Perimenopause',
    description: 'Cycle transitions, temperature regulation & energy care.',
    icon: Icons.nightlight_round,
  ),
  LifeStageInfo(
    key: 'menopause',
    title: 'Menopause',
    description: 'Healthy ageing, bone vitality, heart health & deep sleep.',
    icon: Icons.wb_sunny_outlined,
  ),
];

class LifeStageSelectorCard extends StatelessWidget {
  final bool showHeader;
  final VoidCallback? onStageUpdated;

  const LifeStageSelectorCard({
    super.key,
    this.showHeader = true,
    this.onStageUpdated,
  });

  String _getOnboardingStage(BuildContext context) {
    final osState = BlushyOSProvider.of(context);
    if (osState.personalContext.activeLifeStages.isNotEmpty) {
      return osState.personalContext.activeLifeStages.first;
    }
    if (osState.personalContext.lifeStage != null && osState.personalContext.lifeStage!.isNotEmpty) {
      return osState.personalContext.lifeStage!;
    }
    try {
      final data = BlushyStorage.read('user_profile.json');
      final profile = data is Map ? (data['profile'] ?? data) : null;
      if (profile is Map && profile['lifeStage'] != null && profile['lifeStage'].toString().isNotEmpty) {
        return profile['lifeStage'].toString();
      }
      if (profile is Map && profile['onboardingStage'] != null && profile['onboardingStage'].toString().isNotEmpty) {
        return profile['onboardingStage'].toString();
      }
    } catch (_) {}
    return 'firstPeriodNotStarted';
  }

  @override
  Widget build(BuildContext context) {
    final osState = BlushyOSProvider.of(context);
    final pc = osState.personalContext;
    final String onboardingStage = _getOnboardingStage(context);

    // Active stages set
    final Set<String> activeStages = Set.from(pc.activeLifeStages);
    if (activeStages.isEmpty && pc.lifeStage != null) {
      activeStages.add(pc.lifeStage!);
    }
    if (activeStages.isEmpty) {
      activeStages.add(onboardingStage);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "CURRENT LIFE STAGE",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: BlushyColors.secondaryText,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BlushyColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${activeStages.length} ACTIVE",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 14),
            child: Text(
              "Select your primary life stage or combine multiple topics in your unified dashboard.",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: BlushyColors.secondaryText.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],

        // 9 Life stage options
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: BlushyColors.primary.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: kAllLifeStages.length,
              separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.8, color: BlushyColors.border),
              itemBuilder: (context, index) {
                final stage = kAllLifeStages[index];
                final bool isActive = activeStages.contains(stage.key);
                final bool isOnboardingSelected = onboardingStage == stage.key;

                return InkWell(
                  onLongPress: () async {
                    final bool? completed = await StageQuestionnaireDialog.show(
                      context,
                      stageKey: stage.key,
                      stageTitle: stage.title,
                      isEditing: true,
                    );
                    if (completed == true) {
                      onStageUpdated?.call();
                    }
                  },
                  onTap: () async {
                    if (isActive) {
                      // Allow unselecting if more than 1 stage is active
                      if (activeStages.length > 1) {
                        final newStages = Set<String>.from(activeStages)..remove(stage.key);
                        osState.setActiveLifeStages(newStages);
                        onStageUpdated?.call();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${stage.title} unselected from active stages.'),
                            backgroundColor: BlushyColors.text,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        // At least one stage must remain active
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('At least one life stage must remain active. Select another stage to switch.'),
                            backgroundColor: Color(0xFF6F42F5),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      // Check for clinical conflicts with currently active stages
                      final conflictResult = StageConflictEngine.checkConflict(
                        currentActiveStages: activeStages,
                        targetStage: stage.key,
                      );

                      if (conflictResult.hasConflict) {
                        final bool? confirmed = await StageConflictDialog.show(
                          context,
                          conflictResult: conflictResult,
                          onConfirmSwitch: () async {
                            final newStages = Set<String>.from(activeStages)
                              ..removeAll(conflictResult.conflictingActiveStages)
                              ..add(stage.key);

                            osState.setActiveLifeStages(newStages);
                            final bool? completed = await StageQuestionnaireDialog.show(
                              context,
                              stageKey: stage.key,
                              stageTitle: stage.title,
                              isEditing: false,
                            );
                            if (completed == true) {
                              onStageUpdated?.call();
                            }
                          },
                        );
                        if (confirmed == true) {
                          onStageUpdated?.call();
                        }
                      } else {
                        // Directly open stage questionnaire dialog
                        final bool? completed = await StageQuestionnaireDialog.show(
                          context,
                          stageKey: stage.key,
                          stageTitle: stage.title,
                          isEditing: false,
                        );
                        if (completed == true) {
                          onStageUpdated?.call();
                        }
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    color: isActive ? BlushyColors.primary.withValues(alpha: 0.04) : Colors.transparent,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Checkbox
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: isActive ? BlushyColors.primary : Colors.white,
                            border: Border.all(
                              color: isActive ? BlushyColors.primary : BlushyColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: isActive
                              ? const Icon(Icons.check, size: 15, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 14),

                        // Title, Subtitle, Badges
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      stage.title,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                                        color: BlushyColors.text,
                                      ),
                                    ),
                                  ),
                                  if (isOnboardingSelected) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF81C784), width: 0.8),
                                      ),
                                      child: Text(
                                        "ONBOARDING",
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2E7D32),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isActive && !isOnboardingSelected) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: BlushyColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "ACTIVE",
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: BlushyColors.primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                stage.description,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: BlushyColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action arrow or edit button
                        if (isActive)
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              final bool? completed = await StageQuestionnaireDialog.show(
                                context,
                                stageKey: stage.key,
                                stageTitle: stage.title,
                                isEditing: true,
                              );
                              if (completed == true) {
                                onStageUpdated?.call();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: BlushyColors.primary.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_outlined, size: 14, color: BlushyColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Edit",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: BlushyColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          const Icon(Icons.add_circle_outline_rounded, size: 18, color: BlushyColors.secondaryText),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
