import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/colors.dart';

/// The first card on the home page: a greeting, and nothing else.
///
/// Each life stage previously opened with its own hero card carrying the cycle
/// day, the phase name and a line of guidance about energy — all of which the
/// very next card repeats. So the first thing anyone saw was a dense block of
/// text duplicating the block underneath it.
///
/// One card for every stage, rather than ten: there is nothing stage-specific
/// about saying hello, and ten copies is how the old heroes drifted apart from
/// each other in tone and layout.
class GreetingCard extends StatelessWidget {
  const GreetingCard({super.key, required this.name, this.now});

  final String name;

  /// Injectable so the greeting can be tested at a fixed hour.
  final DateTime? now;

  /// Local time decides the greeting — a health app is used at odd hours, and
  /// "Good morning" at 11pm reads as a machine talking.
  static String greetingFor(AppLocalizations t, String name, DateTime at) {
    final hour = at.hour;
    if (hour < 12) return t.homeGreetingMorning(name);
    if (hour < 17) return t.homeGreetingAfternoon(name);
    return t.homeGreetingEvening(name);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final greeting = greetingFor(t, name, now ?? DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: GoogleFonts.instrumentSerif(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.homeGreetingSubtitle,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: BlushyColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
