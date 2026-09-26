import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colors.dart';

/// Relationship-aware Trying-to-Conceive companion guidance.
///
/// The same life stage means very different support depending on who you are:
/// a conception partner gets fertility-window / intimacy-timing guidance, while
/// a confidante, sister or parent gets two-week-wait emotional support and never
/// sees fertility data (the server hard-caps the fertile window for non-romantic
/// relationships anyway). Guidance only — never clinical instructions.
class PartnerTtcCompanion extends StatelessWidget {
  final String partnerName;

  /// Romantic conception partner (couple capability) vs a supportive confidante.
  final bool isRomantic;

  /// Whether a fertile window was actually shared (romantic only).
  final bool fertileWindowShared;

  const PartnerTtcCompanion({
    super.key,
    required this.partnerName,
    required this.isRomantic,
    this.fertileWindowShared = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = partnerName.isNotEmpty ? partnerName : 'She';

    final String summary = isRomantic
        ? (fertileWindowShared
            ? 'Her fertile window is open. A good time to connect — warmth over a schedule.'
            : 'You’re in this together. Keep it warm and low-pressure, not a deadline.')
        : '$name may be in the two-week wait — the anxious stretch after ovulation before she can test.';

    final List<String> dos = isRomantic
        ? const [
            'Keep intimacy relaxed and pressure-free.',
            'Absorb stress and chores so she can rest.',
            'Celebrate the effort together, whatever the month brings.',
          ]
        : const [
            'Check in gently; offer fun, low-key distractions.',
            'Listen without trying to fix or reassure too fast.',
            'Follow her lead on how much she wants to talk about it.',
          ];

    final List<String> donts = isRomantic
        ? const [
            'Don’t treat it like a task or a deadline.',
            'Don’t keep asking "did it work?"',
          ]
        : const [
            'Don’t ask "are you pregnant yet?"',
            'Don’t offer unsolicited advice or success stories.',
          ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Color(0xFFFCE7F3), shape: BoxShape.circle),
                child: const Icon(Icons.spa_outlined, size: 14, color: BlushyColors.primary),
              ),
              const SizedBox(width: 8),
              Text(
                isRomantic ? 'THE FERTILITY JOURNEY' : 'TWO-WEEK-WAIT SUPPORT', // i18n-ignore: companion mode is English-first pending a localization pass
                style: GoogleFonts.manrope(
                  fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: BlushyColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF221510)),
          ),
          const SizedBox(height: 14),
          _list('WHAT HELPS', dos, Icons.check_rounded, const Color(0xFF0D7A6B)),
          const SizedBox(height: 12),
          _list('BEST TO AVOID', donts, Icons.close_rounded, const Color(0xFFC62828)),
          const SizedBox(height: 10),
          Text(
            'A gentle guide, not a rule. When unsure, ask her.', // i18n-ignore
            style: GoogleFonts.manrope(fontSize: 10.5, fontStyle: FontStyle.italic, color: BlushyColors.secondaryText),
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
          style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: BlushyColors.secondaryText),
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
                  child: Text(item, style: GoogleFonts.manrope(fontSize: 12.5, height: 1.4, color: const Color(0xFF221510))),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
