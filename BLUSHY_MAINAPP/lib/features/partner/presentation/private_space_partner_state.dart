import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'partner_home_sections.dart'
    show kPmCrimson, kPmCardBorder, kPmCharcoal, kPmMuted;

/// What the partner sees when her personal updates are not reaching him.
///
/// The failure this replaces is the important part: with nothing permitted,
/// the home filled with empty cards, "no data" and a loading state that never
/// resolved -- which reads as something broken, and sends him looking for why.
///
/// It is deliberately the same screen whether she paused her sharing or simply
/// never turned it on. The app does not tell him which, because the difference
/// is hers and telling him would turn a boundary into a notification. What it
/// says is true either way: some of her personal updates are private.
///
/// [note] is shown only when she chose to send one. It is her words, on their
/// own -- never beside cycle, mood or anything else about her body.
class PrivateSpacePartnerState extends StatelessWidget {
  const PrivateSpacePartnerState({
    super.key,
    required this.partnerName,
    this.note,
    this.onMessage,
    this.onBloom,
    this.onGift,
  });

  final String partnerName;
  final String? note;
  final VoidCallback? onMessage;
  final VoidCallback? onBloom;
  final VoidCallback? onGift;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            // White and quiet. A warning banner here would make a private
            // moment look like an incident.
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kPmCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A LITTLE SPACE',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: kPmCrimson,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$partnerName is taking some time for herself.',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: kPmCharcoal,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Some of her personal updates are private right now. '
                "You don't need to do anything.",
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  color: kPmMuted,
                  height: 1.5,
                ),
              ),
              if (note != null && note!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        height: 34,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: kPmCrimson.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        // Her words, and nothing about her body beside them.
                        child: Text(
                          '“${note!.trim()}”',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 17,
                            fontStyle: FontStyle.italic,
                            color: kPmCharcoal,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            "IF YOU'D LIKE TO SHOW UP",
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: kPmCrimson,
              letterSpacing: 1.1,
            ),
          ),
        ),
        // Only the actions that still work while sharing is paused. Nothing
        // here invites him to find out what happened.
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (onMessage != null)
              _CalmAction(
                icon: Icons.mail_outline_rounded,
                label: 'Leave a message',
                onTap: onMessage!,
              ),
            if (onBloom != null)
              _CalmAction(
                icon: Icons.local_florist_rounded,
                label: 'Send a Bloom',
                onTap: onBloom!,
              ),
            if (onGift != null)
              _CalmAction(
                icon: Icons.card_giftcard_rounded,
                label: 'Send something thoughtful',
                onTap: onGift!,
              ),
            const _CalmAction(
              icon: Icons.favorite_border_rounded,
              label: 'Give her space',
              onTap: null,
            ),
          ],
        ),
      ],
    );
  }
}

/// One quiet way to show up. A null [onTap] is the do-nothing option, which is
/// a real choice here rather than a disabled button.
class _CalmAction extends StatelessWidget {
  const _CalmAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final quiet = onTap == null;

    return Semantics(
      button: !quiet,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: quiet ? const Color(0xFFFAF7F2) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPmCardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: quiet ? kPmMuted : kPmCrimson),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: quiet ? kPmMuted : kPmCharcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
