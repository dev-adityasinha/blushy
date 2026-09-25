import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colors.dart';

/// One-tap "nudges" a companion can send to the woman.
///
/// The list is supplied by the server (`availableNudges`), scoped to the
/// connection's relationship category, so a family/friend companion only ever
/// sees non-romantic gestures. Tapping calls [onSend] with the nudge id; the
/// chip shows a brief sent state and blocks a double-send.
class PartnerNudgeRow extends StatefulWidget {
  final List<Map<String, dynamic>> nudges;
  final Future<bool> Function(String nudgeId) onSend;

  const PartnerNudgeRow({
    super.key,
    required this.nudges,
    required this.onSend,
  });

  @override
  State<PartnerNudgeRow> createState() => _PartnerNudgeRowState();
}

class _PartnerNudgeRowState extends State<PartnerNudgeRow> {
  final Set<String> _sending = {};
  final Set<String> _justSent = {};

  Future<void> _handle(String id) async {
    if (_sending.contains(id)) return;
    setState(() => _sending.add(id));
    final ok = await widget.onSend(id);
    if (!mounted) return;
    setState(() {
      _sending.remove(id);
      if (ok) _justSent.add(id);
    });
    if (ok) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _justSent.remove(id));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nudges.isEmpty) return const SizedBox.shrink();

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
          Text(
            'SEND A LITTLE SOMETHING', // i18n-ignore: companion mode is English-first pending a localization pass
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: BlushyColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A one-tap gesture lands right in her app.', // i18n-ignore
            style: GoogleFonts.manrope(fontSize: 11, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in widget.nudges)
                _chip(
                  (n['id'] ?? '').toString(),
                  (n['label'] ?? n['message'] ?? '').toString(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String id, String label) {
    if (id.isEmpty) return const SizedBox.shrink();
    final sending = _sending.contains(id);
    final sent = _justSent.contains(id);
    return InkWell(
      onTap: sending ? null : () => _handle(id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sent ? const Color(0xFFE0F2F1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sent ? const Color(0xFF0D7A6B) : BlushyColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sending)
              const SizedBox(
                width: 13, height: 13,
                child: CircularProgressIndicator(strokeWidth: 2, color: BlushyColors.primary),
              )
            else
              Icon(
                sent ? Icons.check_rounded : Icons.send_rounded,
                size: 13,
                color: sent ? const Color(0xFF0D7A6B) : BlushyColors.primary,
              ),
            const SizedBox(width: 6),
            Text(
              sent ? 'Sent' : label, // i18n-ignore
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sent ? const Color(0xFF0D7A6B) : BlushyColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
