import '../../../core/storage.dart';

/// Reads an onboarding / profile answer that may live in several places.
///
/// The onboarding wizard nests answers under `profile['answers']`, while the
/// in-app re-questionnaire (stage_questionnaire_dialog) writes the same answers
/// to the profile top level, under `profile[stageKey]`, and under
/// `profile['stage_answers'][stageKey]`. These helpers check every location so a
/// value set by either path is found, and return a safe empty result on any
/// read/parse error.

Map? _profileMap() {
  try {
    final data = BlushyStorage.read('user_profile.json');
    if (data['profile'] is Map) return data['profile'] as Map;
    return data;
  } catch (_) {
    return null;
  }
}

Iterable<dynamic> _candidates(Map profile, String key) sync* {
  if (profile['answers'] is Map) yield (profile['answers'] as Map)[key];
  yield profile[key];
  final stageKey = profile['lifeStage'] ?? profile['onboardingStage'];
  if (stageKey is String) {
    if (profile[stageKey] is Map) yield (profile[stageKey] as Map)[key];
    if (profile['stage_answers'] is Map &&
        (profile['stage_answers'] as Map)[stageKey] is Map) {
      yield ((profile['stage_answers'] as Map)[stageKey] as Map)[key];
    }
  }
  // Last resort: any stage's stored answers.
  if (profile['stage_answers'] is Map) {
    for (final v in (profile['stage_answers'] as Map).values) {
      if (v is Map && v[key] != null) yield v[key];
    }
  }
}

/// Returns the first list-valued answer for [key] across all storage locations,
/// as a clean list of non-empty strings. Empty when absent.
List<String> profileListAnswer(String key) {
  final profile = _profileMap();
  if (profile == null) return const [];
  for (final c in _candidates(profile, key)) {
    if (c is List) {
      return c.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
  }
  return const [];
}

/// Returns the first non-empty string answer for [key] across all storage
/// locations, or null when absent.
String? profileStringAnswer(String key) {
  final profile = _profileMap();
  if (profile == null) return null;
  for (final c in _candidates(profile, key)) {
    if (c is String && c.trim().isNotEmpty) return c.trim();
  }
  return null;
}

/// The user's age in whole years from their stored date of birth, or null when
/// no parseable DOB is found. Used to age-gate adult-only content (e.g. the
/// smoking card is shown only at 18+).
int? profileAgeYears() {
  final profile = _profileMap();
  if (profile == null) return null;
  dynamic dobRaw;
  for (final key in const ['date_of_birth', 'dateOfBirth', 'dob']) {
    for (final c in _candidates(profile, key)) {
      if (c != null && c.toString().trim().isNotEmpty) {
        dobRaw = c;
        break;
      }
    }
    if (dobRaw != null) break;
  }
  if (dobRaw == null) return null;
  final dob = DateTime.tryParse(dobRaw.toString());
  if (dob == null) return null;
  final now = DateTime.now();
  var age = now.year - dob.year;
  if (now.month < dob.month ||
      (now.month == dob.month && now.day < dob.day)) {
    age--;
  }
  if (age < 0 || age > 120) return null;
  return age;
}
