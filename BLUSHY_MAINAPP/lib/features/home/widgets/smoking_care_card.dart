import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'profile_answers.dart';

/// A gentle, non-judgmental "looking after you" card shown only on adult stages
/// when she has told us she smokes or vapes.
///
/// It leads with women-specific facts (CDC / US Surgeon General), frames the
/// upside of quitting, and offers India's free national quitline. Every figure
/// here is sourced — nothing is invented:
///   - Fertility, early menopause, cervical-cancer risk: CDC / Surgeon General
///     "Women and Smoking" and CDC reproductive-health guidance.
///   - India National Tobacco Quitline 1800-11-2356: MoHFW / WHO India.
/// It renders nothing when she has not answered, or answered "never".
class SmokingCareCard extends StatelessWidget {
  const SmokingCareCard({super.key});

  static const Color _bg = Color(0xFFF3EEFB);
  static const Color _accent = Color(0xFF6C4AB6);
  static const Color _textMain = Color(0xFF241A33);
  static const Color _textMuted = Color(0xFF6E6478);

  /// Normalises the stored answer (a label from onboarding or the dialog) into a
  /// stable code, so minor wording differences still map correctly.
  static String _status(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('never') || s.contains("don't") || s.contains('no,')) {
      return 'never';
    }
    if (s.contains('quit')) return 'quitting';
    if (s.contains('regular') || s.contains('daily') || s.contains('yes')) {
      return 'regular';
    }
    return 'occasional';
  }

  @override
  Widget build(BuildContext context) {
    // Age-gate: never show smoking content to under-18s, even if a status
    // somehow exists. (A null age means no DOB on record — the status itself is
    // only ever set for 18+, so we don't suppress on null.)
    final age = profileAgeYears();
    if (age != null && age < 18) return const SizedBox.shrink();

    final raw = profileStringAnswer('smoking_status');
    if (raw == null) return const SizedBox.shrink();
    final status = _status(raw);
    if (status == 'never') return const SizedBox.shrink();

    final String encouragement = status == 'quitting'
        ? "You're already on the kindest path for your body. Every cigarette you skip lets it heal a little more."
        : 'Whenever you feel ready, cutting back even a little helps — and you never have to do it alone.';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bg, Colors.white],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded,
                    size: 18, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'A gentle note, just for you', // i18n-ignore: smoking care card (English copy)
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: _textMain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'A few things smoking does to a woman’s body, so you can decide with the full picture:', // i18n-ignore: smoking care card (English copy)
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.45,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 12),
          _fact('It can make it harder to get pregnant and is linked to an earlier menopause.'),
          _fact('It raises the risk of cervical cancer.'),
          _fact('The upside: quitting lowers these risks — your body genuinely starts to recover.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              encouragement,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: _textMain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _callQuitline,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.call_rounded, size: 17, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'India Tobacco Quitline', // i18n-ignore: smoking care card (English copy)
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '1800-11-2356 · free & confidential', // i18n-ignore: smoking care card (English copy)
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 15, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on CDC & WHO guidance', // i18n-ignore: smoking care card (English copy)
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: _textMuted.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.spa_rounded, size: 14, color: _accent),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                height: 1.4,
                color: _textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callQuitline() async {
    final uri = Uri(scheme: 'tel', path: '1800112356');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }
}
