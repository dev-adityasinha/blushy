import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colors.dart';

/// Caregiver companion card (family / co-parent connections).
///
/// A practical, dignity-first support panel for a parent or family member. When
/// the relationship is specifically a father it becomes "Dad Mode" — a
/// zero-awkwardness guide with a supply cheat-sheet and clear do/don'ts.
///
/// Deliberately education- and practical-support-scoped: it shows how to show
/// up, never the woman's raw health data (only what the permission filter
/// already permits reaches this screen). Appropriate for a parent of a teen in
/// the first-period stage — no romantic, sexual, or fertility content.
class PartnerCaregiverDashboard extends StatelessWidget {
  final String? relationshipType;
  final String partnerName;

  const PartnerCaregiverDashboard({
    super.key,
    required this.relationshipType,
    required this.partnerName,
  });

  bool get _isDad => (relationshipType ?? '').toLowerCase() == 'father';

  static const _practical = <String>[
    'Keep supplies stocked where she can reach them — pads or tampons in the bathroom.',
    'Have pain relief and a hot water bottle easy to find.',
    'Quietly take a chore off her plate on a low day.',
    'Keep some of her comfort snacks around.',
  ];

  static const _dadDos = <String>[
    'Keep the bathroom basket stocked and the bin lined with a lid.',
    'Make sure pain medicine is accessible — no need to ask.',
    'Offer warmth and food; keep the day low-stress.',
  ];

  static const _dadDonts = <String>[
    'Don\'t make it a big dramatic moment — keep it matter-of-fact.',
    'Don\'t tease about moods or cramps.',
    'Don\'t force a long conversation; let her lead.',
  ];

  @override
  Widget build(BuildContext context) {
    final name = partnerName.isNotEmpty ? partnerName : 'her';

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
                  color: Color(0xFFE0F2F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism_outlined, size: 14, color: Color(0xFF0D7A6B)),
              ),
              const SizedBox(width: 8),
              Text(
                _isDad ? 'DAD’S GUIDE' : 'CARE COMPANION', // i18n-ignore: companion mode is English-first pending a localization pass
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
            _isDad
                ? 'Supporting $name, without the awkward.' // i18n-ignore
                : 'Simple ways to care for $name.', // i18n-ignore
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF221510),
            ),
          ),
          const SizedBox(height: 14),
          _list('PRACTICAL SUPPORT', _practical, Icons.check_rounded, const Color(0xFF0D7A6B)),
          if (_isDad) ...[
            const SizedBox(height: 14),
            _list('THE DIGNIFIED BASICS', _dadDos, Icons.check_rounded, const Color(0xFF0D7A6B)),
            const SizedBox(height: 12),
            _list('BEST TO AVOID', _dadDonts, Icons.close_rounded, const Color(0xFFC62828)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUPPLY QUICK-REFERENCE', // i18n-ignore
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Regular / with wings covers most days. Overnight is for heavier '
                    'nights. If unsure at the shop, a variety pack is always a safe pick.', // i18n-ignore
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      height: 1.45,
                      color: const Color(0xFF4A3E39),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'She chooses what you see here. When unsure, just ask her.', // i18n-ignore
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
