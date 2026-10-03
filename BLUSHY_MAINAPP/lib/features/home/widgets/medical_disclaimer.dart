import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A visible reminder that Blushy is not a medical service and that users should
/// consult a qualified healthcare professional for medical advice, diagnosis, or
/// treatment. Required by the Google Play Health Content & Services policy, and
/// shown on the main surfaces (home, Docsy, onboarding).
///
/// Use `MedicalDisclaimer.bar()` for a slim persistent footer and
/// `MedicalDisclaimer.card()` for a fuller boxed note.
class MedicalDisclaimer extends StatelessWidget {
  const MedicalDisclaimer.bar({super.key}) : compact = true;
  const MedicalDisclaimer.card({super.key}) : compact = false;

  final bool compact;

  static const Color _bg = Color(0xFFF6F1EA);
  static const Color _border = Color(0xFFE6DCD0);
  static const Color _text = Color(0xFF6B5E54);
  static const Color _accent = Color(0xFF8A7A6D);

  static const String _short =
      'Not medical advice. Blushy shares general wellness information — for '
      'diagnosis or treatment, consult a qualified healthcare professional.';

  static const String _full =
      'Blushy provides general wellness and educational information only. It is '
      'not a medical device and is not a substitute for professional medical '
      'advice, diagnosis, or treatment. Always consult a qualified healthcare '
      'professional with any question about a medical condition, symptom, or '
      'decision, and never disregard or delay seeking professional advice '
      'because of something you have read in this app. If you think you may '
      'have a medical emergency, contact your doctor or local emergency services.';

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: const BoxDecoration(
          color: _bg,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline_rounded, size: 13, color: _accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _short, // i18n-ignore: medical disclaimer (reviewed English copy)
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: _text,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_outlined,
                  size: 16, color: _accent),
              const SizedBox(width: 8),
              Text(
                'A note on medical advice', // i18n-ignore: medical disclaimer (reviewed English copy)
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: _accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _full, // i18n-ignore: medical disclaimer (reviewed English copy)
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              height: 1.5,
              color: _text,
            ),
          ),
        ],
      ),
    );
  }
}
