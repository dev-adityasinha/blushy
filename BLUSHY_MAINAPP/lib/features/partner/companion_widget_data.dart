import 'companion_guidance.dart';

/// The payload a home-screen / lock-screen widget shows a companion: the woman's
/// name + phase, today's "vibe", and one "golden rule". Pure and dependency-free
/// so it can be unit-tested; the native bridge (home_widget) writes these three
/// strings into the platform widget store and triggers a refresh.
class CompanionWidgetData {
  /// e.g. "Nithya · Luteal phase"
  final String title;

  /// Today's vibe — the phase summary.
  final String vibe;

  /// The single most useful thing to do today.
  final String goldenRule;

  const CompanionWidgetData({
    required this.title,
    required this.vibe,
    required this.goldenRule,
  });

  /// The keys the native widget reads from the shared store.
  Map<String, String> toStore() => {
        'companion_widget_title': title,
        'companion_widget_vibe': vibe,
        'companion_widget_golden_rule': goldenRule,
      };
}

String _titleCasePhase(String phaseKey) {
  switch (phaseKey) {
    case 'menstrual':
      return 'Menstrual phase';
    case 'follicular':
      return 'Follicular phase';
    case 'ovulation':
      return 'Ovulatory phase';
    case 'luteal':
      return 'Pre-period phase';
    default:
      return 'Her cycle';
  }
}

/// Builds the widget payload from the woman's shared phase, or null when there
/// is no phase to show (nothing shared) — in which case the widget shows its
/// own neutral empty state rather than stale data.
CompanionWidgetData? buildCompanionWidgetData({
  required String partnerName,
  required String? phase,
}) {
  final g = guidanceForPhase(phase);
  if (g == null) return null;
  final name = partnerName.trim().isEmpty ? 'She' : partnerName.trim();
  return CompanionWidgetData(
    title: '$name · ${_titleCasePhase(g.phaseKey)}',
    vibe: g.summary,
    goldenRule: g.goldenRule,
  );
}
