/// Which answers may switch a home page card on, and what counts as a match.
///
/// The home page gates 44 card slots on what the user said at signup. Both
/// halves of that decision — which stored values are even eligible, and when a
/// value counts as matching a card's keyword — used to live inline in a 13,000
/// line widget, where neither could be tested and both were wrong.
library;

import 'tracker_log.dart';

/// Keys in the stored answers map that are not answers to a question.
///
/// The map is not just the questionnaire. `saveOnboardingAnswers` sends the
/// profile fields alongside the answers, and the home page merges the whole
/// remote response into the same map, so her name, her weight, her date of
/// birth and today's check-in sliders all sit next to `ttc_tracking_method`.
///
/// None of those should decide which cards exist. The daily ones especially:
/// they are what she logged this morning, not what she wants tracked, and
/// letting them gate the layout would rearrange her home page day to day.
///
/// The `*_log` keys are excluded for the same reason: the trackers write what
/// she logged back into this map, so a card that recorded a value would keep
/// itself switched on afterwards regardless of what she asked for.
bool isNonQuestionAnswerKey(String key) {
  const fixed = {
    'preferred_name', 'date_of_birth', 'life_stage', 'active_life_stages',
    'last_period', 'period_history', 'due_date', 'baby_birth_date',
    'weight', 'weight_current', 'height', 'completed', 'phase', 'stepindex',
  };
  final k = key.toLowerCase();
  return fixed.contains(k) ||
      k.startsWith('daily_') ||
      k.endsWith('_log') ||
      k.startsWith(kTrackerLogPrefix) ||
      // The onboarding analysis writes its conclusions back into the answers.
      // Those are a *result* of what she chose, so letting them gate cards
      // would let the analysis widen its own input on the next run.
      k.startsWith('analysis_') ||
      k.endsWith('_date') ||
      k.endsWith('_at');
}

/// Whether any of her choices matches any of a card's keywords.
///
/// Two directions, deliberately asymmetric:
///
///  * Her choice may *contain* the keyword, including inside a word:
///    "Breastfeeding" matches `feeding`, "Walking" matches `walk`.
///  * The keyword may contain her choice only at a **word boundary**:
///    "Acne" matches `hormonal acne`, but "Low" does not match `flow`.
///
/// That second rule is the whole point. Plain substring matching in this
/// direction meant a three letter value bled into unrelated keywords — an
/// energy level of "Low" put the period-flow card on a postpartum home page,
/// because "flow" contains "low".
bool metricMatches(Iterable<String> choices, Iterable<String> keywords) {
  final kws = keywords
      .map((k) => k.trim().toLowerCase())
      .where((k) => k.isNotEmpty)
      .toList();

  for (final raw in choices) {
    final choice = raw.trim().toLowerCase();
    if (choice.isEmpty) continue;

    for (final kw in kws) {
      if (choice.contains(kw)) return true;
      if (kw.split(RegExp(r'[^a-z0-9]+')).contains(choice)) return true;
    }
  }
  return false;
}
