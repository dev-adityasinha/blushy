/// The pieces of a life-stage change that do not need a screen.
///
/// The server decides whether a change is allowed, and refuses with a code:
/// `CONFIRMATION_REQUIRED` (ask her once more), `MISSING_BRANCH_CONTEXT`
/// (pregnancy needs a due date first, postpartum a birth date),
/// `TRANSITION_NOT_ALLOWED` (no direct path between the two stages) or
/// `ALREADY_IN_STAGE`. The app used to treat every one of these as the same
/// dead end -- "That change could not be saved" -- because the refusal's
/// details were dropped on the way in. These helpers read them.
library;

/// The context a stage needs before the server lets her enter it, taken
/// from the answers the stage questionnaire stored.
Map<String, dynamic> branchContextFromAnswers(String stageKey, Map<String, dynamic>? answers) {
  if (answers == null) return const {};
  String? text(String key) {
    final v = answers[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  final out = <String, dynamic>{};
  switch (stageKey) {
    case 'pregnancy':
      final due = text('due_date');
      if (due != null) out['due_date'] = due;
      final week = text('pregnancy_week');
      if (week != null) out['pregnancy_week'] = week;
      if (answers['pregnancy_date_unsure'] == true) out['pregnancy_date_unsure'] = true;
      // The questionnaire may store the date under the stage's own key.
      if (out.isEmpty && due == null) {
        final alt = text('last_period') ?? text('last_period_date');
        if (alt != null) out['pregnancy_date_unsure'] = true;
      }
      break;
    case 'postpartum':
      final born = text('baby_birth_date');
      if (born != null) out['baby_birth_date'] = born;
      break;
    default:
      break;
  }
  return out;
}

/// Reads the stage's saved answers out of the profile map.
Map<String, dynamic>? savedStageAnswers(Map<String, dynamic> profile, String stageKey) {
  final byStage = profile['stage_answers'];
  if (byStage is Map && byStage[stageKey] is Map) {
    return Map<String, dynamic>.from(byStage[stageKey] as Map);
  }
  if (profile[stageKey] is Map) {
    return Map<String, dynamic>.from(profile[stageKey] as Map);
  }
  return null;
}

const Map<String, String> _stageNames = {
  'first_period': 'First Period',
  'cycle_tracking': 'Reproductive Years',
  'hormonal_health': 'Hormonal Health',
  'ttc': 'Trying to Conceive',
  'pregnancy': 'Pregnancy',
  'postpartum': 'Postpartum',
  'perimenopause': 'Perimenopause',
  'menopause': 'Menopause',
  'everyday_wellness': 'Everyday Wellness',
  'exploring': 'Just exploring',
};

String stageName(String? key) {
  if (key == null) return 'your current stage';
  return _stageNames[key] ?? key;
}

/// What to tell her when the server refuses a change, in her words.
String transitionRefusalMessage(String? errorCode, Map<String, dynamic>? meta, String targetTitle) {
  final from = stageName(meta?['fromStage']?.toString());
  switch (errorCode) {
    case 'TRANSITION_NOT_ALLOWED':
      return "Blushy can't move you from $from straight to $targetTitle. "
          'Pick the stage that comes between, or Everyday Wellness, first.';
    case 'MISSING_BRANCH_CONTEXT':
      final missing = meta?['missingContext'];
      if (missing is List && missing.contains('baby_birth_date')) {
        return "$targetTitle needs your baby's birth date first.";
      }
      return '$targetTitle needs a due date or week first.';
    case 'CONFIRMATION_REQUIRED':
      return 'Please confirm the move to $targetTitle.';
    case 'UNKNOWN_TARGET_STAGE':
      return "The server doesn't know the stage \"$targetTitle\".";
    case 'OFFLINE':
    case 'NETWORK_UNAVAILABLE':
      return "You're offline. Stage changes are saved with your account, so try again when connected.";
    default:
      return 'That change could not be saved.';
  }
}
