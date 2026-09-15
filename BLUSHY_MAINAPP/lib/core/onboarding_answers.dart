import 'dart:convert';

/// Reads onboarding answers without assuming which flow wrote them.
///
/// More than one onboarding flow has written to this map over the app's life,
/// and they did not agree on key names. Measured against the live database:
/// 21 women have `goals`, while 32 have `selected_goals` plus a set of
/// `goal_*` booleans. The home page read only the first shape, so the goals
/// the larger group chose were collected, stored, and then ignored — which is
/// what "onboarding questions aren't used to optimise home pages" looks like
/// from the outside.
///
/// Rather than migrate the stored data, reads accept every shape. Migration
/// would have to guess at intent for rows that carry both, and a read that
/// tolerates history costs nothing.
class OnboardingAnswers {
  const OnboardingAnswers._();

  /// Collects a set of strings from the first key that holds one, then adds
  /// anything recorded as `prefix_thing: true`.
  ///
  /// Both are consulted, not just the first to match: a row can carry a list
  /// from one flow and booleans from another, and dropping either loses a
  /// choice the user actually made.
  static Set<String> stringSet(
    Map<String, dynamic>? answers, {
    required List<String> keys,
    String? booleanPrefix,
  }) {
    final out = <String>{};
    if (answers == null) return out;

    for (final key in keys) {
      final value = answers[key];
      if (value == null) continue;
      if (value is List) {
        out.addAll(value.map((e) => e.toString()).where((e) => e.isNotEmpty));
      } else if (value is String && value.isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            out.addAll(decoded.map((e) => e.toString()).where((e) => e.isNotEmpty));
          } else {
            out.addAll(_splitList(value));
          }
        } catch (_) {
          out.addAll(_splitList(value));
        }
      }
    }

    if (booleanPrefix != null) {
      for (final entry in answers.entries) {
        if (!entry.key.startsWith(booleanPrefix)) continue;
        if (isAffirmative(entry.value)) {
          final name = entry.key.substring(booleanPrefix.length);
          if (name.isNotEmpty) out.add(name);
        }
      }
    }

    return out;
  }

  /// `selected_goals` is stored as `"get_pregnant,track_period,nutrition"` —
  /// one comma-separated string rather than a list. Treating it as a single
  /// answer stores the whole line as one nonsense goal.
  static Iterable<String> _splitList(String raw) => raw
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty);

  /// True for every way this codebase has recorded "yes".
  ///
  /// The `goal_*` keys hold the strings `"yes"` and `"no"`, not booleans — of
  /// 213 such values in the live data, 53 are `"yes"`. Checking for `true`
  /// alone matches none of them, which is how a whole flow's answers went
  /// unread.
  static bool isAffirmative(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == 'yes' || v == 'y' || v == '1';
    }
    return false;
  }

  /// The goals she picked, however the flow she went through recorded them.
  static Set<String> goals(Map<String, dynamic>? answers) => stringSet(
        answers,
        keys: const ['goals', 'selected_goals'],
        booleanPrefix: 'goal_',
      );

  /// Symptoms, across the onboarding and check-in spellings.
  static Set<String> symptoms(Map<String, dynamic>? answers) => stringSet(
        answers,
        keys: const ['symptoms', 'period_pms_symptoms', 'checkin_symptoms'],
      );

  /// Diagnosed conditions.
  static Set<String> conditions(Map<String, dynamic>? answers) => stringSet(
        answers,
        keys: const ['conditions', 'medical_conditions', 'diagnosed_conditions'],
      );
}
