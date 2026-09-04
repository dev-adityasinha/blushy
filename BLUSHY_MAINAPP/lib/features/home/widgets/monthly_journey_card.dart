import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/api_insights_service.dart';
import '../../../shared/blushy_surface.dart';
import '../../../shared/section_heading.dart';
import '../../../theme/colors.dart';
import '../../../theme/scale.dart';

/// The last completed month, as a journey.
///
/// A rail down the left with a marker per milestone -- filled green where it
/// was reached, an empty ring where it was not -- each with a tile, a title
/// and a line of description; then Docsy's reflection on the month in a
/// quote panel. The milestones and the reflection are the server's (or the
/// local fallback's while offline); this only lays them out.
class MonthlyJourneyCard extends StatelessWidget {
  const MonthlyJourneyCard({
    super.key,
    required this.heading,
    required this.monthLabel,
    required this.milestones,
    required this.reflectionHeading,
    required this.reflection,
  });

  final String heading;
  final String? monthLabel;
  final List<MilestoneItem> milestones;
  final String reflectionHeading;
  final String reflection;

  static IconData iconFor(String id) {
    switch (id) {
      case 'milestone_checkin_consistency':
        return Icons.calendar_month_rounded;
      case 'milestone_symptom_tracking':
        return Icons.assignment_rounded;
      case 'milestone_cycle_logging':
        return Icons.event_available_rounded;
      case 'milestone_sia_engagement':
        return Icons.chat_bubble_rounded;
    }
    return Icons.auto_awesome;
  }

  @override
  Widget build(BuildContext context) {
    return BlushySurface(
      padding: const EdgeInsets.all(BlushySpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(heading),
          if (monthLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              monthLabel!,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: const Color(0xFF7A6B72),
              ),
            ),
          ],
          const SizedBox(height: BlushySpace.sm),
          for (var i = 0; i < milestones.length; i++)
            _MilestoneRow(milestone: milestones[i]),
          const SizedBox(height: BlushySpace.sm),
          _ReflectionPanel(heading: reflectionHeading, text: reflection),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.milestone});

  final MilestoneItem milestone;

  @override
  Widget build(BuildContext context) {
    final done = milestone.showGreenTick;
    final iconColor = done ? BlushyColors.primary : const Color(0xFFB5A9AF);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFDFBF7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEAE3DC), width: 0.8),
            ),
            child: Icon(
              MonthlyJourneyCard.iconFor(milestone.id),
              size: 15,
              color: iconColor,
            ),
          ),
          const SizedBox(width: BlushySpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.title,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.text,
                  ),
                ),
                Text(
                  milestone.description,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: const Color(0xFF7A6B72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BlushySpace.xs),
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: done ? const Color(0xFF4A8B5D) : const Color(0xFFD9D0C7),
          ),
        ],
      ),
    );
  }
}

/// Docsy's line on the month, set as a clean quotation.
class _ReflectionPanel extends StatelessWidget {
  const _ReflectionPanel({required this.heading, required this.text});

  final String heading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BlushySpace.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAE3DC), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading.toUpperCase(),
            style: BlushyType.eyebrow(),
          ),
          const SizedBox(height: BlushySpace.xs + 2),
          Text(
            '"$text"',
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: BlushyColors.text,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

