import 'package:flutter/foundation.dart';

/// Maps the daily check-in selectors onto validated health events.
///
/// The selectors offer buckets ("6-8h", "Medium", "2L") rather than exact
/// values. Each bucket maps to the value the backend scale expects, and the
/// label the user actually picked travels with it as `reportedAs`, so a
/// bucketed answer is never displayed back as a precise measurement and the
/// derivation stays reproducible from the stored event (spec section 21).
///
/// Kept out of the dashboard widget so the mapping is testable on its own.
@immutable
class CheckinEvent {
  final String eventType;
  final Map<String, dynamic> payload;

  const CheckinEvent({required this.eventType, required this.payload});

  @override
  bool operator ==(Object other) =>
      other is CheckinEvent &&
      other.eventType == eventType &&
      mapEquals(other.payload, payload);

  @override
  int get hashCode => Object.hash(eventType, payload.toString());

  @override
  String toString() => 'CheckinEvent($eventType, $payload)';
}

class CheckinEventMapper {
  const CheckinEventMapper._();

  /// The exact labels each selector renders. Reversing an event looks the
  /// label up here rather than reconstructing it, so casing like "2L" versus
  /// "6-8h" is never guessed.
  static const Map<String, List<String>> selectorOptions = {
    'mood': ['Happy', 'Okay', 'Cramps', 'Tired', 'Irritable'],
    'energy': ['High', 'Medium', 'Low'],
    'flow': ['Light', 'Medium', 'Heavy'],
    'pain': ['None', 'Mild', 'Severe'],
    'sleep': ['<6h', '6-8h', '>8h'],
    'stress': ['Low', 'Moderate', 'High'],
    'water': ['1L', '2L', '3L'],
    'exercise': ['Active', 'Light', 'None'],
  };

  /// The label for a lowercased bucket key, or the key itself if unlisted.
  static String labelFor(String metric, String bucketKey) {
    for (final option in selectorOptions[metric] ?? const <String>[]) {
      if (option.toLowerCase() == bucketKey) return option;
    }
    return bucketKey;
  }

  static const Map<String, int> energyBuckets = {'low': 1, 'medium': 3, 'high': 5};
  static const Map<String, int> stressBuckets = {'low': 1, 'moderate': 3, 'high': 5};
  static const Map<String, int> painBuckets = {'none': 0, 'mild': 3, 'severe': 8};
  static const Map<String, double> sleepBuckets = {'<6h': 5, '6-8h': 7, '>8h': 9};
  static const Map<String, int> waterBuckets = {'1l': 4, '2l': 8, '3l': 12};
  static const Map<String, int> exerciseBuckets = {'none': 0, 'light': 20, 'active': 45};
  static const Map<String, String> flowBuckets = {
    'spotting': 'spotting',
    'light': 'light',
    'medium': 'medium',
    'heavy': 'heavy',
  };

  /// The mood selector mixes moods with symptoms ("Cramps", "Tired"). Each is
  /// routed to the event type it actually is, rather than forcing all of them
  /// into `mood_logged`, which would record a symptom as an emotion.
  static const Map<String, String> moodToBackendMood = {
    'happy': 'good',
    'okay': 'okay',
    'irritable': 'irritable',
  };
  static const Map<String, String> moodToSymptom = {
    'cramps': 'cramps',
    'tired': 'tiredness',
  };

  /// Returns the event to post, or null when the value is not one this mapper
  /// recognises. Returning null is deliberate: an unmapped selector value is
  /// dropped rather than guessed at.
  static CheckinEvent? map(String metric, String rawValue) {
    final value = rawValue.trim().toLowerCase();
    if (value.isEmpty) return null;

    switch (metric) {
      case 'mood':
        final mood = moodToBackendMood[value];
        if (mood != null) {
          return CheckinEvent(eventType: 'mood_logged', payload: {'mood': mood});
        }
        final symptom = moodToSymptom[value];
        if (symptom != null) {
          return CheckinEvent(eventType: 'symptom_logged', payload: {'symptom': symptom});
        }
        return null;

      case 'energy':
        final level = energyBuckets[value];
        return level == null
            ? null
            : CheckinEvent(eventType: 'energy_logged', payload: {'level': level, 'reportedAs': rawValue});

      case 'sleep':
        final hours = sleepBuckets[value];
        return hours == null
            ? null
            : CheckinEvent(eventType: 'sleep_logged', payload: {'durationHours': hours, 'reportedAs': rawValue});

      case 'stress':
        final level = stressBuckets[value];
        return level == null
            ? null
            : CheckinEvent(eventType: 'stress_logged', payload: {'level': level, 'reportedAs': rawValue});

      case 'water':
        final glasses = waterBuckets[value];
        return glasses == null
            ? null
            : CheckinEvent(eventType: 'hydration_logged', payload: {'glasses': glasses, 'reportedAs': rawValue});

      case 'pain':
        final severity = painBuckets[value];
        return severity == null
            ? null
            : CheckinEvent(eventType: 'pain_logged', payload: {'severity': severity, 'reportedAs': rawValue});

      case 'flow':
        final flow = flowBuckets[value];
        return flow == null
            ? null
            : CheckinEvent(eventType: 'flow_logged', payload: {'flow': flow, 'reportedAs': rawValue});

      case 'exercise':
        final minutes = exerciseBuckets[value];
        return minutes == null
            ? null
            : CheckinEvent(
                eventType: 'activity_logged',
                payload: {'activity': 'exercise', 'durationMinutes': minutes, 'reportedAs': rawValue},
              );

      default:
        return null;
    }
  }

  /// Turns a stored event back into the selector label to show as selected.
  ///
  /// For bucketed metrics this is exact: `reportedAs` holds the label the user
  /// originally picked, so nothing is guessed from the derived number. Moods
  /// and the two symptoms in the mood selector are mapped back by name.
  ///
  /// Returns `(metric, label)`, or null for an event this card does not show.
  static MapEntry<String, String>? reverse(String eventType, Map<String, dynamic> payload) {
    String? reportedAs() {
      final value = payload['reportedAs'];
      if (value is String && value.trim().isNotEmpty) return value;
      return null;
    }

    switch (eventType) {
      case 'mood_logged':
        final mood = payload['mood']?.toString().toLowerCase();
        for (final entry in moodToBackendMood.entries) {
          if (entry.value == mood) {
            return MapEntry('mood', labelFor('mood', entry.key));
          }
        }
        return null;

      case 'symptom_logged':
        final symptom = payload['symptom']?.toString().toLowerCase();
        for (final entry in moodToSymptom.entries) {
          if (entry.value == symptom) {
            return MapEntry('mood', labelFor('mood', entry.key));
          }
        }
        return null;

      case 'energy_logged':
        final label = reportedAs() ?? _labelForValue('energy', energyBuckets, payload['level']);
        return label == null ? null : MapEntry('energy', label);

      case 'sleep_logged':
        final label = reportedAs() ?? _labelForValue('sleep', sleepBuckets, payload['durationHours']);
        return label == null ? null : MapEntry('sleep', label);

      case 'stress_logged':
        final label = reportedAs() ?? _labelForValue('stress', stressBuckets, payload['level']);
        return label == null ? null : MapEntry('stress', label);

      case 'hydration_logged':
        final label = reportedAs() ?? _labelForValue('water', waterBuckets, payload['glasses']);
        return label == null ? null : MapEntry('water', label);

      case 'pain_logged':
        final label = reportedAs() ?? _labelForValue('pain', painBuckets, payload['severity']);
        return label == null ? null : MapEntry('pain', label);

      case 'flow_logged':
        final flowKey = payload['flow']?.toString().toLowerCase();
        final label = reportedAs() ?? (flowKey == null ? null : labelFor('flow', flowKey));
        return label == null ? null : MapEntry('flow', label);

      case 'activity_logged':
        final label = reportedAs() ?? _labelForValue('exercise', exerciseBuckets, payload['durationMinutes']);
        return label == null ? null : MapEntry('exercise', label);

      default:
        return null;
    }
  }

  /// Recovers the bucket label for events written before `reportedAs` existed.
  /// Only an exact match counts: a value between buckets is left unmapped
  /// rather than snapped to the nearest label.
  static String? _labelForValue(String metric, Map<String, num> buckets, dynamic value) {
    if (value == null) return null;
    final numeric = value is num ? value : num.tryParse(value.toString());
    if (numeric == null) return null;
    for (final entry in buckets.entries) {
      if (entry.value == numeric) return labelFor(metric, entry.key);
    }
    return null;
  }

  /// Stable per-metric, per-day key so replaying the same check-in is
  /// deduplicated server side instead of creating a second log.
  static String idempotencyKey({
    required String userId,
    required String metric,
    required DateTime day,
  }) {
    final dayKey = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    return 'checkin:$userId:$metric:$dayKey';
  }
}
