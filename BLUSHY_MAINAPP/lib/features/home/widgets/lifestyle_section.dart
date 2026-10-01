import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'activity_care_card.dart';
import 'smoking_care_card.dart';

/// Groups the activity and smoking care cards under one "LOOKING AFTER YOU"
/// section header. Renders nothing (no stray header) when neither card applies.
///
/// Pass [includeActivity] = false on stages without an active cycle
/// (pregnancy, postpartum, menopause) so only the smoking card can appear.
class LifestyleSection extends StatelessWidget {
  const LifestyleSection({
    super.key,
    required this.stage,
    this.currentCycleDay,
    this.periodLength,
    this.includeActivity = true,
  });

  final String stage;
  final int? currentCycleDay;
  final int? periodLength;
  final bool includeActivity;

  @override
  Widget build(BuildContext context) {
    final activityShows = includeActivity && ActivityCareCard.hasActivities();
    final smokingShows = SmokingCareCard.willShow();
    if (!activityShows && !smokingShows) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'LOOKING AFTER YOU', // i18n-ignore: lifestyle section header (English copy)
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: const Color(0xFFDD0D22),
            ),
          ),
        ),
        if (activityShows)
          ActivityCareCard(
            currentCycleDay: currentCycleDay,
            periodLength: periodLength,
          ),
        if (smokingShows) SmokingCareCard(stage: stage),
      ],
    );
  }
}
