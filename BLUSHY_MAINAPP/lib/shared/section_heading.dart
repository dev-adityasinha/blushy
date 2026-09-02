import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/colors.dart';

/// A dashboard section heading, with an answer to "why are you asking me this?"
///
/// The home tab asks for a lot: moods, symptoms, sleep, cycle dates. None of
/// the headings said what any of it was for, and several use words -- luteal,
/// follicular, rhythm -- that mean nothing unless you already know them. The
/// info button opens the reason for that section, and the cycle sections also
/// carry a short glossary.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key});

  final String title;

  /// Why each section exists, grouped by what it asks for.
  ///
  /// Grouped rather than written per heading: the same question sits under
  /// several stage-specific titles, and one honest answer per kind is better
  /// than thirty near-identical ones that drift apart.
  static const Map<String, String> _reasons = {
    'checkin': 'Logging how today felt is what the rest of the app is built '
        'on. A single day says little; a few weeks of them is what lets '
        'patterns show up, and what Docsy reads before answering you. '
        'Nothing here is shared with anyone unless you connect a partner and '
        'choose to share it.',
    'cycle': 'Your logged period dates are the only thing cycle predictions '
        'are built from — they are never guessed from your messages. The more '
        'you log, the steadier they get. They stay estimates, and they are not '
        'reliable enough for contraception or for diagnosing anything.',
    'patterns': 'Patterns are recalculated from what you have logged, not '
        'stored as conclusions. They are described as things that tend to '
        'happen together, never as one thing causing another, because logs '
        'cannot show cause. If too little has been logged, the app says so '
        'instead of inventing a pattern.',
    'symptoms': 'Naming what you actually get means the app can stop offering '
        'cards for things you never experience, and can show the ones you do '
        'nearer the top. It also gives Docsy something specific to work '
        'from rather than generalities.',
    'learn': 'Reading is picked to match the stage you are in and what you '
        'have logged, so it is about where you are now rather than a general '
        'feed. Clinical content is reviewed before it appears here.',
    'partner': 'Nothing reaches a partner until you connect one and choose '
        'what to share, and you can pause personal insights at any time '
        'without switching off shared activities.',
    'baby': 'Dates you give — a due date, a birth date — are what the weekly '
        'guidance is counted from. Without them the app would be guessing at '
        'where you are.',
    'appointment': 'Collected so you can walk into an appointment with what '
        'you have actually logged, rather than trying to remember it. It is a '
        'record to show someone, not a diagnosis.',
    'wellbeing': 'Habits and wellbeing are tracked over weeks rather than '
        'days, because that is the only span on which they mean anything. '
        'This is the slow view, not today.',
  };

  /// The words the cycle sections use, in plain English.
  static const List<(String, String)> _glossary = [
    (
      'Menstrual phase',
      'Your period itself — the days you are bleeding. Counted as day one of a '
          'cycle.',
    ),
    (
      'Follicular phase',
      'From the end of your period until ovulation. Named after the follicles '
          'in the ovaries maturing during it. Energy often climbs through it, '
          'though that varies a lot between people.',
    ),
    (
      'Ovulation',
      'When an egg is released, roughly in the middle of a cycle. The app '
          'estimates it from your logged dates; it does not detect it.',
    ),
    (
      'Luteal phase',
      'From ovulation until your next period. This is where premenstrual '
          'symptoms usually sit — sore breasts, low mood, cramps, appetite '
          'changes.',
    ),
    (
      'Cycle rhythm',
      'How regular your cycles have been across the ones you have logged — '
          'whether their length holds steady or moves around. It is a '
          'description of your own history, not a score.',
    ),
  ];

  /// Which explanation a heading gets.
  static String _keyFor(String title) {
    final t = title.toUpperCase();
    if (t.contains('CHECK') || t.contains('HOW ARE YOU')) return 'checkin';
    if (t.contains('CYCLE') || t.contains('FERTILITY')) return 'cycle';
    if (t.contains('PATTERN') || t.contains('INSIGHT')) return 'patterns';
    if (t.contains('CONDITION') || t.contains('SYMPTOM')) return 'symptoms';
    if (t.contains('APPOINTMENT')) return 'appointment';
    if (t.contains('LEARN') || t.contains('CURIOUS')) return 'learn';
    if (t.contains('PARTNER') || t.contains('CONNECT')) return 'partner';
    if (t.contains('BABY')) return 'baby';
    return 'wellbeing';
  }

  /// True where the glossary is worth showing under the reason.
  static bool _needsGlossary(String key) => key == 'cycle' || key == 'patterns';

  void _explain(BuildContext context) {
    final key = _keyFor(title);
    final reason = _reasons[key] ?? _reasons['wellbeing']!;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: BlushyColors.primary,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Why this is here',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: BlushyColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.55,
                    color: BlushyColors.secondaryText,
                  ),
                ),
                if (_needsGlossary(key)) ...[
                  const SizedBox(height: 20),
                  Text(
                    'What the words mean',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final (term, meaning) in _glossary) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            term,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: BlushyColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meaning,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              height: 1.5,
                              color: BlushyColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.primary,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => _explain(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: BlushyColors.primary.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}
