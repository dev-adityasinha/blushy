import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/scale.dart';

/// A dashboard section heading.
///
/// Uppercase, spaced, in the brand red, with an optional mark before it. One
/// style for every section on every tab, so a heading is recognisable as a
/// heading before it is read.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.icon});

  final String title;

  /// A mark before the heading. Chosen from the words when not given.
  final IconData? icon;

  /// The mark for a heading, from what it says.
  ///
  /// One rule here rather than an icon chosen at each of the thirty-odd call
  /// sites: the same kind of section gets the same mark on every tab and
  /// every stage, and a new heading gets one without anyone remembering to
  /// add it. Matched on the English key words; the localised headings keep
  /// those words in their keys, and anything unmatched falls to a sparkle
  /// rather than to nothing.
  static IconData iconFor(String title) {
    final t = title.toUpperCase();
    if (t.contains('CHECK')) return Icons.fact_check_rounded;
    if (t.contains('SIGNAL')) return Icons.monitor_heart_outlined;
    if (t.contains('PATTERN')) return Icons.insights_rounded;
    if (t.contains('INSIGHT')) return Icons.auto_awesome;
    if (t.contains('REFLECTION') || t.contains('JOURNEY')) return Icons.auto_awesome;
    if (t.contains('CYCLE') || t.contains('PERIOD')) return Icons.loop_rounded;
    if (t.contains('FERTILITY') || t.contains('OVULATION')) return Icons.spa_rounded;
    if (t.contains('BABY') || t.contains('PREGNAN')) return Icons.child_care_rounded;
    if (t.contains('APPOINTMENT') || t.contains('DOCTOR')) return Icons.medical_services_rounded;
    if (t.contains('CONDITION') || t.contains('SYMPTOM')) return Icons.healing_rounded;
    if (t.contains('LEARN') || t.contains('CURIOUS') || t.contains('UNDERSTAND')) return Icons.menu_book_rounded;
    if (t.contains('PARTNER') || t.contains('CONNECT') || t.contains('FAMILY')) return Icons.favorite_rounded;
    if (t.contains('HEALTH') || t.contains('WELLNESS') || t.contains('HOW ARE YOU')) return Icons.favorite_border_rounded;
    if (t.contains('GROW') || t.contains('TIMELINE') || t.contains('FIRST')) return Icons.timeline_rounded;
    return Icons.auto_awesome;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon ?? iconFor(title), size: BlushySpace.iconInline, color: BlushyColors.primary),
        const SizedBox(width: BlushySpace.sm),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BlushyType.eyebrow(),
          ),
        ),
      ],
    );
  }
}
