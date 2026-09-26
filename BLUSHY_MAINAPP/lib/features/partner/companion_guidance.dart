/// Shared companion guidance: maps a cycle phase to supportive "what helps /
/// best to avoid" content. Pure data, no Flutter — reused by the in-app Empathy
/// Translator card and by the home-screen widget data provider so both speak
/// with one voice.
///
/// Guidance only, never clinical instructions. English-first for now.
library;

class CompanionPhaseGuidance {
  final String phaseKey; // 'menstrual' | 'follicular' | 'ovulation' | 'luteal'
  final String label;
  final String summary;
  final List<String> dos;
  final List<String> donts;

  /// One romantic-only line; null for non-romantic relationships.
  final String? affection;

  const CompanionPhaseGuidance({
    required this.phaseKey,
    required this.label,
    required this.summary,
    required this.dos,
    required this.donts,
    this.affection,
  });

  /// The single most useful "do" — the "golden rule" shown on the widget.
  String get goldenRule => dos.isNotEmpty ? dos.first : '';
}

const _menstrual = CompanionPhaseGuidance(
  phaseKey: 'menstrual',
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
);

const _follicular = CompanionPhaseGuidance(
  phaseKey: 'follicular',
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
);

const _ovulation = CompanionPhaseGuidance(
  phaseKey: 'ovulation',
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
);

const _luteal = CompanionPhaseGuidance(
  phaseKey: 'luteal',
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
);

/// Resolves a phase string (from the shared cycle context) to its guidance, or
/// null when the phase is unknown/empty.
CompanionPhaseGuidance? guidanceForPhase(String? phase) {
  final p = (phase ?? '').toLowerCase();
  if (p.isEmpty) return null;
  if (p.contains('menstru') || p.contains('period')) return _menstrual;
  if (p.contains('follicular') || p.contains('fresh')) return _follicular;
  if (p.contains('ovulat') || p.contains('mid')) return _ovulation;
  if (p.contains('luteal') || p.contains('pms') || p.contains('pre')) return _luteal;
  return null;
}
