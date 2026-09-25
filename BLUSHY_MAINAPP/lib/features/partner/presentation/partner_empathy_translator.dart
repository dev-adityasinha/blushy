import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colors.dart';

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

  _PhaseGuidance? get _guidance {
    final p = (phase ?? '').toLowerCase();
    if (p.isEmpty) return null;
    if (p.contains('menstru') || p.contains('period')) return _menstrual;
    if (p.contains('follicular') || p.contains('fresh')) return _follicular;
    if (p.contains('ovulat') || p.contains('mid')) return _ovulation;
    if (p.contains('luteal') || p.contains('pms') || p.contains('pre')) return _luteal;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final g = _guidance;
    if (g == null) return const SizedBox.shrink();

    final name = partnerName.isNotEmpty ? partnerName : 'She';

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
                  color: g.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.volunteer_activism_rounded, size: 14, color: g.color),
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

class _PhaseGuidance {
  final String label;
  final String summary;
  final List<String> dos;
  final List<String> donts;
  final String? affection;
  final Color color;
  final Color tint;
  const _PhaseGuidance({
    required this.label,
    required this.summary,
    required this.dos,
    required this.donts,
    required this.color,
    required this.tint,
    this.affection,
  });
}

const _menstrual = _PhaseGuidance(
  label: 'menstrual phase', // i18n-ignore: companion mode is English-first pending a localization pass
  summary: 'Energy is often at its lowest. Small comforts land far more than big gestures.',
  dos: [
    'Offer warmth and rest — a hot water bottle, her favourite food, an easy evening.',
    'Quietly take something off her plate today.',
    'Check in gently, then give her space if she wants it.',
  ],
  donts: [
    'Don\'t plan anything high-energy without asking first.',
    'Don\'t brush off cramps or tiredness as "just your period".',
  ],
  affection: 'Physical closeness may be comforting or unwanted right now — follow her lead, no pressure.',
  color: Color(0xFFEF4444),
  tint: Color(0xFFFFE4E4),
);

const _follicular = _PhaseGuidance(
  label: 'follicular phase', // i18n-ignore: companion mode is English-first pending a localization pass
  summary: 'Energy and openness are rising — a good stretch for plans and new things.',
  dos: [
    'Suggest plans or try something new together — she is more up for it now.',
    'Match her momentum; be game for spontaneity.',
  ],
  donts: [
    'Don\'t overload the calendar all at once — ramp up gradually.',
  ],
  affection: 'A warm, playful time to reconnect and make plans together.',
  color: Color(0xFFF97316),
  tint: Color(0xFFFFEDD5),
);

const _ovulation = _PhaseGuidance(
  label: 'ovulatory phase', // i18n-ignore: companion mode is English-first pending a localization pass
  summary: 'Social energy and confidence tend to peak. She may be more direct — that is the phase, not the mood.',
  dos: [
    'Great time for shared plans, people, and big conversations.',
    'Meet her higher energy with your own.',
  ],
  donts: [
    'Don\'t take heightened directness personally.',
  ],
  affection: 'Connection often feels easiest now — a good moment for quality time together.',
  color: Color(0xFFFACC15),
  tint: Color(0xFFFEF9C3),
);

const _luteal = _PhaseGuidance(
  label: 'pre-period (luteal) phase', // i18n-ignore: companion mode is English-first pending a localization pass
  summary: 'The wind-down before her period. Patience and reassurance matter most here.',
  dos: [
    'Lead with patience — handle chores proactively without being asked.',
    'Validate how she feels before trying to fix anything.',
    'Keep social plans lighter and give her easy outs.',
  ],
  donts: [
    'Never ask "are you PMSing?" — it dismisses real feelings.',
    'Don\'t start conflicts over small things.',
    'Don\'t pack the schedule with high-stimulation plans.',
  ],
  affection: 'Offer comfort without pressure; closeness on her terms means more than grand gestures.',
  color: Color(0xFF7C3AED),
  tint: Color(0xFFEDE9FE),
);
