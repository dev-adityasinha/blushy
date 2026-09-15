import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../private_space.dart';
import 'partner_home_sections.dart' show kPmCrimson, kPmCardBorder, kPmCharcoal, kPmMuted, kPmHairline;

/// Taking some space, as a sheet rather than a dialog.
///
/// This replaced "Argument Mode" in the consumer-facing UI. The old name made
/// wanting privacy sound like a fight, and it asked her to declare one; this
/// asks how long, and offers -- does not require -- a line to send.
///
/// What it promises is what the server actually does. The paused list below is
/// generated from [PrivateSpace.pausedKeys], so the screen cannot drift from
/// the permissions it switches off.
class PrivateSpaceSheet extends StatefulWidget {
  const PrivateSpaceSheet({super.key});

  /// Returns the chosen duration and note, or null when she backs out.
  static Future<PrivateSpaceChoice?> show(BuildContext context) {
    return showModalBottomSheet<PrivateSpaceChoice>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const PrivateSpaceSheet(),
    );
  }

  @override
  State<PrivateSpaceSheet> createState() => _PrivateSpaceSheetState();
}

/// What she chose. A null [forDuration] means "until I resume".
class PrivateSpaceChoice {
  const PrivateSpaceChoice({this.forDuration, this.note});

  final Duration? forDuration;
  final String? note;
}

class _PrivateSpaceSheetState extends State<PrivateSpaceSheet> {
  /// Index into [_durations]. Defaults to "Until I resume": a timer she did
  /// not ask for would hand her sharing back without her deciding to.
  int _duration = 4;
  int _note = 0;

  static const List<({String label, Duration? span})> _durations = [
    (label: '1 hour', span: Duration(hours: 1)),
    (label: '3 hours', span: Duration(hours: 3)),
    (label: 'Tonight', span: Duration(hours: 8)),
    (label: 'Tomorrow', span: Duration(hours: 24)),
    (label: 'Until I resume', span: null),
  ];

  /// The first is deliberately "nothing": she is never made to explain.
  static const List<({String label, String? message})> _notes = [
    (label: 'Nothing for now', message: null),
    (label: 'I just need some space.', message: 'I just need some space.'),
    (label: "I'll talk when I'm ready.", message: "I'll talk when I'm ready."),
    (label: 'Be gentle with me. No solutions.',
        message: 'Be gentle with me. No solutions.'),
    (label: 'Give me some time, then ask me.',
        message: 'Give me some time, then ask me.'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: kPmHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _eyebrow('Take some space'),
            Text(
              "You don't have to explain everything.",
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: kPmCharcoal,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your personal updates can stay private for a while.',
              style: GoogleFonts.manrope(
                  fontSize: 12.5, color: kPmMuted, height: 1.45),
            ),
            const SizedBox(height: 20),

            _eyebrow('How much space do you need?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _durations.length; i++)
                  _choice(
                    label: _durations[i].label,
                    selected: _duration == i,
                    onTap: () => setState(() => _duration = i),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            _eyebrow('What should your partner know?  ·  optional'),
            Column(
              children: [
                for (var i = 0; i < _notes.length; i++)
                  _radio(
                    label: _notes[i].label,
                    selected: _note == i,
                    onTap: () => setState(() => _note = i),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            _list(
              'Private during space',
              // Generated from the keys that are actually switched off, so the
              // promise and the permissions cannot drift apart.
              const [
                'Cycle updates',
                'Mood updates',
                'Sleep and wellness insights',
                'Docsy partner observations',
              ],
              kPmCrimson,
            ),
            const SizedBox(height: 14),
            _list('Still available', PrivateSpace.stillAvailable,
                const Color(0xFF0D9488)),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  PrivateSpaceChoice(
                    forDuration: _durations[_duration].span,
                    note: _notes[_note].message,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: kPmCrimson,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'Take some space',
                  style: GoogleFonts.manrope(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Not now',
                  style: GoogleFonts.manrope(fontSize: 12.5, color: kPmMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eyebrow(String label) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: kPmCrimson,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? kPmCrimson.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? kPmCrimson : kPmCardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: kPmCharcoal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _radio({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: selected ? kPmCrimson : kPmMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: kPmCharcoal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(String title, List<String> items, Color tick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: kPmMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.check_rounded, size: 14, color: tick),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.manrope(
                        fontSize: 12.5, color: kPmCharcoal),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
