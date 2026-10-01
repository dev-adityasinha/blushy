import 'dart:convert';

import '../../../core/storage.dart';

/// Reads and persists the lifestyle answers (physical activities, smoking
/// status, and the DOB-derived age) that drive the activity and smoking home
/// cards.
///
/// Why a dedicated store: `user_profile.json` is overwritten on every load by
/// `syncAllDashboardsFromBackend`, with the backend's *account* profile (which
/// does not carry onboarding answers). So the cards can't rely on it. Instead we
/// keep a small user-scoped `lifestyle_answers.json` that the sync never
/// touches:
///   - `home_screen` hydrates it from `getOnboardingAnswers()` on every open
///     (so existing / cross-device users get their saved answers),
///   - onboarding and the in-app editor write it directly (instant display),
///   - the cards read it here.
/// We still fall back to scanning `user_profile.json` for the brief moment right
/// after a fresh onboarding, before the first backend round-trip.

const String _lifestyleStore = 'lifestyle_answers.json';

Map<String, dynamic> _readLifestyle() {
  try {
    return BlushyStorage.read(_lifestyleStore);
  } catch (_) {
    return const {};
  }
}

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  // Lists sent to the backend come back JSON-encoded (see saveOnboardingAnswers).
  if (v is String && v.trim().startsWith('[')) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}
  }
  return const [];
}

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
  if (profile['stage_answers'] is Map) {
    for (final v in (profile['stage_answers'] as Map).values) {
      if (v is Map && v[key] != null) yield v[key];
    }
  }
}

/// Returns the first list-valued answer for [key] — from the lifestyle store
/// first, then the profile scan — as a clean list of non-empty strings.
List<String> profileListAnswer(String key) {
  final ls = _asStringList(_readLifestyle()[key]);
  if (ls.isNotEmpty) return ls;
  final profile = _profileMap();
  if (profile != null) {
    for (final c in _candidates(profile, key)) {
      final parsed = _asStringList(c);
      if (parsed.isNotEmpty) return parsed;
    }
  }
  return const [];
}

/// Returns the first non-empty string answer for [key] — lifestyle store first,
/// then the profile scan — or null.
String? profileStringAnswer(String key) {
  final v = _readLifestyle()[key];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  final profile = _profileMap();
  if (profile != null) {
    for (final c in _candidates(profile, key)) {
      if (c is String && c.trim().isNotEmpty) return c.trim();
    }
  }
  return null;
}

/// The user's age in whole years from their stored date of birth, or null when
/// no parseable DOB is found. Used to age-gate adult-only content (the smoking
/// card shows only at 18+).
int? profileAgeYears() {
  dynamic dobRaw = _readLifestyle()['date_of_birth'];
  if (dobRaw == null || dobRaw.toString().trim().isEmpty) {
    final profile = _profileMap();
    if (profile != null) {
      for (final key in const ['date_of_birth', 'dateOfBirth', 'dob']) {
        for (final c in _candidates(profile, key)) {
          if (c != null && c.toString().trim().isNotEmpty) {
            dobRaw = c;
            break;
          }
        }
        if (dobRaw != null && dobRaw.toString().trim().isNotEmpty) break;
      }
    }
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

/// Merges lifestyle answers into the local store (used by onboarding and the
/// in-app editor for instant display). Null arguments are left unchanged; the
/// backend copy is saved separately by the caller via saveOnboardingAnswers.
void writeLifestyleAnswers({
  List<String>? activities,
  String? smokingStatus,
  String? dateOfBirth,
}) {
  final current = Map<String, dynamic>.from(_readLifestyle());
  if (activities != null) current['physical_activities'] = activities;
  if (smokingStatus != null && smokingStatus.isNotEmpty) {
    current['smoking_status'] = smokingStatus;
  }
  if (dateOfBirth != null && dateOfBirth.isNotEmpty) {
    current['date_of_birth'] = dateOfBirth;
  }
  try {
    BlushyStorage.write(_lifestyleStore, current);
  } catch (_) {}
}

/// Pulls the lifestyle answers out of a backend onboarding-answers map (as
/// returned by getOnboardingAnswers, where lists arrive JSON-encoded) and
/// stores them locally so the cards can read them. Safe to call on every open.
void hydrateLifestyleFromAnswers(Map<String, dynamic> answers) {
  if (answers.isEmpty) return;
  final activities = _asStringList(answers['physical_activities']);
  final smoking = answers['smoking_status']?.toString();
  final dob = (answers['date_of_birth'] ?? answers['dateOfBirth'])?.toString();
  writeLifestyleAnswers(
    activities: activities.isNotEmpty ? activities : null,
    smokingStatus: (smoking != null && smoking.trim().isNotEmpty) ? smoking.trim() : null,
    dateOfBirth: (dob != null && dob.trim().isNotEmpty) ? dob.trim() : null,
  );
}
