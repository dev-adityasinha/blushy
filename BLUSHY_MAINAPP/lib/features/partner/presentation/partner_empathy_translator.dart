import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colors.dart';
import '../companion_guidance.dart';

/// The Empathy Translator.
///
/// Turns the woman's current cycle phase (the one thing she has chosen to share)
/// into concrete "do this / not that" guidance for whoever is supporting her.
/// It is the highest-leverage companion feature: it reuses data already exposed
/// through the permission filter, works for any close relationship, and needs no
/// new server field.
///
/// Tone is supportive, not clinical — it never instructs on treatment, only on
/// how to show up. A romantic connection additionally gets one affection-aware
/// line; family/friends do not.
class PartnerEmpathyTranslator extends StatelessWidget {
  /// The phase string from `permittedContext['cyclePhase']['phase']`
  /// (e.g. "menstrual", "follicular", "ovulation"/"ovulatory", "luteal").
  final String? phase;

  /// The woman's name, for the copy.
  final String partnerName;

  /// Whether this connection is a romantic partner (adds the affection line).
  final bool isRomantic;

  const PartnerEmpathyTranslator({
    super.key,
    required this.phase,
    required this.partnerName,
    this.isRomantic = false,
  });

  @override
  Widget build(BuildContext context) {
    final g = guidanceForPhase(phase);
    if (g == null) return const SizedBox.shrink();

    final name = partnerName.isNotEmpty ? partnerName : 'She';

    // Phase accent (UI only; the shared guidance module stays presentation-free).
    Color accent;
    Color tint;
    switch (g.phaseKey) {
      case 'menstrual':
        accent = const Color(0xFFEF4444);
        tint = const Color(0xFFFFE4E4);
        break;
      case 'follicular':
        accent = const Color(0xFFF97316);
        tint = const Color(0xFFFFEDD5);
        break;
      case 'ovulation':
        accent = const Color(0xFFFACC15);
        tint = const Color(0xFFFEF9C3);
        break;
      case 'luteal':
        accent = const Color(0xFF7C3AED);
        tint = const Color(0xFFEDE9FE);
        break;
      default:
        accent = BlushyColors.primary;
        tint = const Color(0xFFFCE7F3);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.volunteer_activism_rounded, size: 14, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                'EMPATHY TRANSLATOR', // i18n-ignore: companion mode is English-first pending a localization pass
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: BlushyColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$name is likely in her ${g.label}.',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF221510),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            g.summary,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.45,
              color: BlushyColors.secondaryText,
            ),
          ),
          const SizedBox(height: 14),
          _list('WHAT HELPS', g.dos, Icons.check_rounded, const Color(0xFF0D7A6B)),
          const SizedBox(height: 12),
          _list('BEST TO AVOID', g.donts, Icons.close_rounded, const Color(0xFFC62828)),
          if (isRomantic && g.affection != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite_rounded, size: 14, color: BlushyColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.affection!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        height: 1.4,
                        color: const Color(0xFF4A3E39),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'A gentle guide, not a rule. When unsure, ask her.', // i18n-ignore: companion mode is English-first pending a localization pass
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: BlushyColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(String title, List<String> items, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      height: 1.4,
                      color: const Color(0xFF221510),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
