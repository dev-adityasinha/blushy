import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colors.dart';

/// Peer support card (friend connections).
///
/// A warm, low-key "cycle buddy" panel for a friend. Intentionally does NOT
/// claim menstrual "syncing" — that is a debunked myth, and a health product
/// should not assert it. Instead it offers honest peer-support ideas and, when a
/// phase is shared, a gentle nudge to reach out.
class PartnerPeerHub extends StatelessWidget {
  final String partnerName;

  /// Optional shared phase, only to soften the copy — never a "you're synced" claim.
  final String? phase;

  const PartnerPeerHub({
    super.key,
    required this.partnerName,
    this.phase,
  });

  static const _ideas = <String>[
    'Send a "thinking of you" text on a rough day.',
    'Offer a spare pad or tampon if you\'re together — no big deal.',
    'Suggest a low-key hang: snacks, a movie, or a study session.',
    'Just listen — you don\'t have to fix anything.',
  ];

  bool get _onPeriod {
    final p = (phase ?? '').toLowerCase();
    return p.contains('menstru') || p.contains('period');
  }

  @override
  Widget build(BuildContext context) {
    final name = partnerName.isNotEmpty ? partnerName : 'your friend';

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
                decoration: const BoxDecoration(
                  color: Color(0xFFFCE7F3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.diversity_1_outlined, size: 14, color: Color(0xFFC2185B)),
              ),
              const SizedBox(width: 8),
              Text(
                'CYCLE BUDDY', // i18n-ignore: companion mode is English-first pending a localization pass
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
            _onPeriod
                ? '$name may be on her period. A small check-in goes a long way.' // i18n-ignore
                : 'Small ways to show up for $name.', // i18n-ignore
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF221510),
            ),
          ),
          const SizedBox(height: 14),
          for (final item in _ideas)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite_border_rounded, size: 15, color: Color(0xFFC2185B)),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF7A6B72)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Everyone’s cycle is their own — you don’t need to be "in sync" '
                    'to support each other.', // i18n-ignore
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      height: 1.4,
                      color: const Color(0xFF4A3E39),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'She chooses what you see. Ask her what she needs.', // i18n-ignore
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
}
