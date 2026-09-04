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
    'mood': ['Happy', 'Okay', 'Calm', 'Low', 'Irritable'],
    'symptom': [
      'Cramps',
      'Headache',
      'Tender breasts',
      'Backache',
      'Abdominal pain',
      'Acne',
      'Fatigue',
      'Cravings',
      'Insomnia',
      'Swelling',
      'Hair thinning',
      'Excess facial hair',
      'Vaginal itching',
      'Vaginal dryness',
      'Dry skin',
      'Dry eyes',
      'Nausea',
      'Bloating',
      'Constipation',
      'Diarrhea',
    ],
    'energy': ['High', 'Medium', 'Low'],
    'flow': ['Light', 'Medium', 'Heavy', 'None', 'Spotting'],
    'pain': ['None', 'Mild', 'Severe'],
    // Two selectors, two vocabularies. The cycle dashboards offer the first
    // three; the everyday wellness one offers the last three. Both are real
    // labels a person can pick, so both belong here.
    'sleep': ['<6h', '6-8h', '>8h', '6-7h', '7-8h', '8h+'],
    'stress': ['Low', 'Moderate', 'High'],
    'water': ['1L', '2L', '3L', '1.5L', '2.5L'],
    'exercise': ['Active', 'Light', 'None', 'Workout', 'Walk', 'Light Walk', 'Strength Training', 'Rest'],
    'cervical_mucus': ['Dry', 'Sticky', 'Creamy', 'Eggwhite'],
    'lh_test': ['Low', 'High', 'Peak'],
    'feeding': ['Breastfeeding', 'Bottle Feeding', 'Pumping'],
    'hot_flash': ['None', 'Mild', 'Intense'],
    'night_sweat': ['None', 'Mild', 'Intense'],
    'pelvic_floor': ['Completed', 'Not Done'],
    'strength': ['Done', 'Not Done'],
    'walking': ['Done', 'Not Done'],
    'meditation': ['Completed', 'Not Done'],
    'brain_fog': ['None', 'Mild', 'Intense'],
    'joint_pain': ['None', 'Mild', 'Intense'],
    'incision': ['Healing', 'Sore', 'Not Applicable'],
    'medication': ['Taken', 'Not Taken'],
    'vitamin': ['Taken', 'Not Taken'],
    'hormone_therapy': ['Taken', 'Not Taken', 'None'],
    'fetal_movement': ['Active', 'Normal', 'Quiet'],
    'contractions': ['None', 'Mild', 'Strong'],
    'postpartum_bleeding': ['None', 'Spotting', 'Flow'],
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
  /// Hours for each sleep label a selector can render.
  ///
  /// The wellness dashboard's three labels were missing, so `map` returned
  /// null for them and `_recordCheckinEvent` dropped the answer without a
  /// word. Sleep logged there was stored and displayed but never became a
  /// `sleep_logged` event, so it reached none of what reads one: the two
  /// sleep patterns, the care plan's average, the doctor summary, the
  /// partner view, or Docsy's context.
  ///
  /// Every value here is distinct, which is what keeps the reverse lookup
  /// in `_labelForValue` unambiguous -- it matches on the number alone.
  static const Map<String, double> sleepBuckets = {
    '<6h': 5,
    '6-8h': 7,
    '>8h': 9,
    '6-7h': 6.5,
    '7-8h': 7.5,
    '8h+': 8.5,
  };
  /// Glasses for each hydration label a selector can render.
  ///
  /// The wellness dashboard offers 2L, 2.5L and 3L; only the half-litre
  /// step was missing, so picking it logged nothing while its neighbours
  /// worked -- the least visible way for this to be wrong.
  static const Map<String, int> waterBuckets = {
    '1l': 4,
    '2l': 8,
    '3l': 12,
    '1.5l': 6,
    '2.5l': 10,
  };
  /// Minutes for each movement label a selector can render.
  ///
  /// The wellness dashboard offers Workout, Walk and None, and two of those
  /// three were unmapped: only None logged anything. The care plan reads
  /// these minutes, so a person doing the most movement recorded the least.
  ///
  /// Walk and Workout sit either side of the existing pair rather than on
  /// top of them. Equal values would make the reverse lookup ambiguous --
  /// it matches on the number, so a shared one would render whichever
  /// label happened to be declared first.
  static const Map<String, int> exerciseBuckets = {
    'none': 0,
    'light': 20,
    'light walk': 15,
    'walk': 30,
    'active': 45,
    'strength training': 50,
    'workout': 60,
    // Pregnancy and postpartum offer "Rest" where the others offer
    // "None". Both mean no movement, so both are zero. Reversing a zero
    // renders "None", which only shows on rows written before
    // `reportedAs` existed -- every row since carries the label she
    // actually picked and displays that.
    'rest': 0,
  };
  /// What the fertility selectors offer, against the values the backend
  /// accepts (`CERVICAL_MUCUS` and `LH_RESULTS` in `domain/healthEvents.js`).
  ///
  /// Both event types existed on the server from the start and nothing ever
  /// sent one: the two selectors saved their answer and never called
  /// `_recordCheckinEvent`. Cervical mucus and an LH test are the two
  /// strongest signals a person trying to conceive can log, and neither
  /// reached the fertility view, the timeline or Docsy.
  ///
  /// "Eggwhite" is the one word that needs translating -- the card says it as
  /// one word, the server calls it `egg_white`, and lowercasing alone would
  /// have been rejected.
  static const Map<String, String> cervicalMucusBuckets = {
    'dry': 'dry',
    'sticky': 'sticky',
    'creamy': 'creamy',
    'watery': 'watery',
    'eggwhite': 'egg_white',
  };

  /// Fetal movement, named so the reviewed rule can act on it.
  ///
  /// `rf_pg_reduced_movements` matches the phrase "reduced movement" and cites
  /// RCOG Green-top Guideline No. 57; it is gated to 24 weeks and raises an
  /// emergency escalation telling her to contact her maternity unit the same
  /// day. That rule existed and nothing could ever trigger it, because this
  /// card recorded nothing. "Quiet" is what a person picks when movements have
  /// dropped, so it is recorded in the words the rule reads.
  ///
  /// Active and Normal are recorded too, under a name that matches no rule --
  /// checked, because the engine matches substrings and a careless name would
  /// raise an emergency alert for a normal day.
  static const Map<String, String> fetalMovementNames = {
    'active': 'fetal movements normal',
    'normal': 'fetal movements normal',
    'quiet': 'reduced movement',
  };

  /// Contractions, recorded with a severity and a name that matches no rule.
  ///
  /// Deliberate: the rules that exist are for abdominal pain and severe
  /// cramping, and preterm labour has no rule here. Naming this to fall into
  /// the pain rule would be inventing a clinical threshold in a mapper, which
  /// is the wrong place for one. The data is recorded so a reviewed rule can
  /// be written against it later.
  static const Map<String, int> contractionBuckets = {
    'none': 0,
    'mild': 3,
    'strong': 8,
  };

  /// Postpartum bleeding, recorded as lochia and deliberately not as a symptom.
  ///
  /// `rf_pp_heavy_bleeding` matches the bare word "bleeding" with no severity
  /// gate and raises an emergency escalation. Measured against the real engine:
  /// a symptom named "postpartum bleeding" fires it, and so does "bleeding
  /// none" -- someone reporting no bleeding at all would be told to contact
  /// emergency services. So this is a recovery metric, which never reaches the
  /// red-flag engine, and the word is the clinical one for it.
  ///
  /// The reviewed rule still fires the way it was written to: from what she
  /// says in her own words, where "heavy bleeding" means what it says.
  static const Map<String, int> lochiaBuckets = {
    'none': 0,
    'spotting': 1,
    'flow': 2,
  };

  /// Whether a dose was taken. "None" is absent on purpose -- on the hormone
  /// therapy card it means "I am not on it", which is not an adherence answer
  /// and is declared in `CheckinVocabulary.unrecorded`.
  static const Map<String, bool> doseBuckets = {
    'taken': true,
    'not taken': false,
  };

  /// Which kind of thing each adherence card is asking about.
  static const Map<String, String> medicationKinds = {
    'medication': 'medication',
    'vitamin': 'vitamin',
    'hormone_therapy': 'hormone_therapy',
  };

  /// Caesarean incision healing, as a recovery metric.
  ///
  /// "Not Applicable" is absent on purpose, so `map` returns null for it and
  /// nothing is recorded -- someone who did not have a caesarean is not
  /// reporting a healing state, and a reading in the timeline for a wound that
  /// does not exist would be worse than no reading. That omission is declared
  /// in `CheckinVocabulary.unrecorded`, so it reads as a decision rather than
  /// as the oversight it would otherwise look like.
  ///
  /// Higher means more discomfort reported, which is the direction every other
  /// graded metric here runs in.
  static const Map<String, int> incisionBuckets = {
    'healing': 0,
    'sore': 1,
  };

  /// Habit selectors that answer "did you" rather than "how much".
  ///
  /// `activity_logged` takes a free-text activity and an optional duration.
  /// There is no duration to give -- the card asks whether it happened -- so
  /// only the activity is sent, and "Not Done" records a zero rather than
  /// nothing. A day she was asked and said no is not the same as a day she
  /// was never asked, and only the first can tell a pattern anything.
  static const Map<String, int> habitDoneBuckets = {
    'done': 1,
    'completed': 1,
    'not done': 0,
  };

  /// The activity name each habit selector records under.
  static const Map<String, String> habitActivityNames = {
    'strength': 'strength_training',
    'walking': 'walking',
    'meditation': 'meditation',
  };

  /// Comfort symptoms graded on the card's three steps, onto the server's
  /// 0-10 severity scale.
  static const Map<String, int> comfortSeverityBuckets = {
    'none': 0,
    'mild': 3,
    'intense': 8,
  };

  /// The symptom name each of those selectors records under.
  static const Map<String, String> comfortSymptomNames = {
    'brain_fog': 'brain_fog',
    'joint_pain': 'joint_pain',
  };

  /// Postpartum feeding method, against the server's allowed list.
  ///
  /// `pumping` was added to that list rather than folded into `breast`:
  /// expressed milk is not nursing, and this event carries no `reportedAs`,
  /// so a conflation here could not be undone when reading it back.
  static const Map<String, String> feedingBuckets = {
    'breastfeeding': 'breast',
    'bottle feeding': 'bottle',
    'pumping': 'pumping',
  };

  /// Hot flashes and night sweats, on the 0-10 severity scale the server
  /// takes. Both are the same event; the sweats selector sets `nightSweat`.
  static const Map<String, int> hotFlashBuckets = {
    'none': 0,
    'mild': 3,
    'intense': 8,
  };

  /// Pelvic floor exercise, as a recovery metric. The server wants a number,
  /// and this one is genuinely binary.
  static const Map<String, int> pelvicFloorBuckets = {
    'completed': 1,
    'not done': 0,
  };

  /// Both wordings: the TTC card offers "Low"/"High"/"Peak", the symptoms
  /// sheet offers "Test: low" and so on. Two selectors, one vocabulary.
  static const Map<String, String> lhTestBuckets = {
    'negative': 'negative',
    'low': 'low',
    'high': 'high',
    'peak': 'peak',
    'test: negative': 'negative',
    'test: low': 'low',
    'test: high': 'high',
    'test: peak': 'peak',
  };

  /// Sexual activity, in the words the backend stores them under.
  static const Map<String, String> sexActivities = {
    'did not have sex': 'none',
    'protected sex': 'protected',
    'unprotected sex': 'unprotected',
    'oral sex': 'oral',
    'anal sex': 'anal',
    'masturbation': 'masturbation',
    'sensual touch': 'sensual_touch',
    'sex toys': 'toys',
  };

  /// Sex drive, which records on its own field and can be logged alone.
  static const Map<String, String> sexDrive = {
    'high sex drive': 'high',
    'neutral sex drive': 'neutral',
    'low sex drive': 'low',
  };

  static const Map<String, String> pregnancyTestResults = {
    'did not test': 'not_taken',
    'positive': 'positive',
    'negative': 'negative',
    'faint line': 'faint_line',
  };

  /// Named activities, stored as the activity string.
  ///
  /// "Did not exercise" is a real answer and is kept: a rest day is data, and
  /// dropping it would make every unlogged day look the same as a rest day.
  static const Map<String, String> namedActivities = {
    'did not exercise': 'rest',
    'yoga': 'yoga',
    'gym': 'gym',
    'aerobics and dancing': 'aerobics',
    'swimming': 'swimming',
    'team sports': 'team sports',
    'running': 'running',
    'cycling': 'cycling',
    'walking': 'walking',
    'travel': 'travel',
    'meditation': 'meditation',
    'journaling': 'journaling',
    'kegel exercises': 'kegel exercises',
    'breathing exercises': 'breathing exercises',
    'alcohol': 'alcohol',
  };

  static const Map<String, String> flowBuckets = {
    'none': 'none',
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
    'calm': 'calm',
    'low': 'low',
    'irritable': 'irritable',
  };
  /// Symptom chips, in the words the backend stores them under.
  ///
  /// Lower-cased on the way in, so the sheet can capitalise freely.
  static const Map<String, String> symptomNames = {
    'cramps': 'cramps',
    'headache': 'headache',
    'tender breasts': 'tender breasts',
    'backache': 'backache',
    'abdominal pain': 'abdominal pain',
    'acne': 'acne',
    'fatigue': 'fatigue',
    'cravings': 'cravings',
    'insomnia': 'insomnia',
    'swelling': 'swelling',
    'hair thinning': 'hair thinning',
    'excess facial hair': 'excess facial hair',
    'vaginal itching': 'vaginal itching',
    'vaginal dryness': 'vaginal dryness',
    'dry skin': 'dry skin',
    'dry eyes': 'dry eyes',
    // From the flow group: a clot is not a flow level.
    'blood clots': 'blood clots',
    // From the discharge group. These three are not mucus observations, so
    // they are symptoms rather than a fertility reading.
    'unusual': 'unusual discharge',
    'clumpy white': 'clumpy white discharge',
    'grey': 'grey discharge',
    // From the lifestyle group.
    'disease or injury': 'illness or injury',
    'nausea': 'nausea',
    'bloating': 'bloating',
    'constipation': 'constipation',
    'diarrhea': 'diarrhea',
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
        return mood == null
            ? null
            : CheckinEvent(eventType: 'mood_logged', payload: {'mood': mood});

      case 'symptom':
        final symptom = symptomNames[value];
        return symptom == null
            ? null
            : CheckinEvent(
                eventType: 'symptom_logged',
                payload: {'symptom': symptom, 'reportedAs': rawValue},
              );

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

      case 'fetal_movement':
        final movementName = fetalMovementNames[value];
        return movementName == null
            ? null
            : CheckinEvent(
                eventType: 'symptom_logged',
                payload: {'symptom': movementName, 'reportedAs': rawValue},
              );

      case 'contractions':
        final strength = contractionBuckets[value];
        return strength == null
            ? null
            : CheckinEvent(
                eventType: 'symptom_logged',
                payload: {
                  'symptom': 'contractions',
                  'severity': strength,
                  'reportedAs': rawValue,
                },
              );

      case 'postpartum_bleeding':
        final lochia = lochiaBuckets[value];
        return lochia == null
            ? null
            : CheckinEvent(
                eventType: 'recovery_metric_logged',
                payload: {
                  'metric': 'lochia',
                  'value': lochia,
                  'scale': 'self_reported',
                },
              );

      case 'medication':
      case 'vitamin':
      case 'hormone_therapy':
        final taken = doseBuckets[value];
        return taken == null
            ? null
            : CheckinEvent(
                eventType: 'medication_logged',
                payload: {
                  'kind': medicationKinds[metric]!,
                  // Recorded either way: a day she was asked and said no is
                  // not the same as a day she was never asked.
                  'taken': taken,
                  'reportedAs': rawValue,
                },
              );

      case 'incision':
        final discomfort = incisionBuckets[value];
        return discomfort == null
            ? null
            : CheckinEvent(
                eventType: 'recovery_metric_logged',
                payload: {
                  'metric': 'incision_discomfort',
                  'value': discomfort,
                  'scale': 'self_reported',
                },
              );

      case 'strength':
      case 'walking':
      case 'meditation':
        final did = habitDoneBuckets[value];
        return did == null
            ? null
            : CheckinEvent(
                eventType: 'activity_logged',
                payload: {
                  'activity': habitActivityNames[metric]!,
                  'durationMinutes': null,
                  'intensity': did == 1 ? 'done' : 'not_done',
                  'reportedAs': rawValue,
                },
              );

      case 'brain_fog':
      case 'joint_pain':
        final grade = comfortSeverityBuckets[value];
        return grade == null
            ? null
            : CheckinEvent(
                eventType: 'symptom_logged',
                payload: {
                  'symptom': comfortSymptomNames[metric]!,
                  'severity': grade,
                },
              );

      case 'feeding':
        final method = feedingBuckets[value];
        return method == null
            ? null
            : CheckinEvent(
                eventType: 'feeding_logged',
                payload: {'method': method},
              );

      case 'hot_flash':
      case 'night_sweat':
        final severity = hotFlashBuckets[value];
        return severity == null
            ? null
            : CheckinEvent(
                eventType: 'hot_flash_logged',
                payload: {
                  'severity': severity,
                  // The same event either way; this is what separates a night
                  // sweat from a hot flash when they are read back.
                  'nightSweat': metric == 'night_sweat',
                },
              );

      case 'pelvic_floor':
        final done = pelvicFloorBuckets[value];
        return done == null
            ? null
            : CheckinEvent(
                eventType: 'recovery_metric_logged',
                payload: {
                  'metric': 'pelvic_floor',
                  'value': done,
                  'scale': 'binary',
                },
              );

      case 'cervical_mucus':
        final observation = cervicalMucusBuckets[value];
        return observation == null
            ? null
            : CheckinEvent(
                eventType: 'cervical_mucus_logged',
                payload: {'observation': observation, 'reportedAs': rawValue},
              );

      case 'lh_test':
        final result = lhTestBuckets[value];
        return result == null
            ? null
            : CheckinEvent(
                eventType: 'lh_test_logged',
                payload: {'result': result, 'reportedAs': rawValue},
              );

      case 'sex':
        final activity = sexActivities[value];
        if (activity != null) {
          return CheckinEvent(
            eventType: 'sexual_activity_logged',
            payload: {'activity': activity, 'reportedAs': rawValue},
          );
        }
        final drive = sexDrive[value];
        return drive == null
            ? null
            : CheckinEvent(
                eventType: 'sexual_activity_logged',
                payload: {'drive': drive, 'reportedAs': rawValue},
              );

      case 'pregnancy_test':
        final testResult = pregnancyTestResults[value];
        return testResult == null
            ? null
            : CheckinEvent(
                eventType: 'pregnancy_test_logged',
                payload: {'result': testResult, 'reportedAs': rawValue},
              );

      case 'activity':
        final named = namedActivities[value];
        return named == null
            ? null
            : CheckinEvent(
                eventType: 'activity_logged',
                payload: {'activity': named, 'reportedAs': rawValue},
              );

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
  /// and symptoms are mapped back by name.
  ///
  /// The `symptom` metric is multi-select, so it returns one entry per event
  /// and the caller has to accumulate rather than overwrite.
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

        // A symptom chip goes back to the symptoms sheet. `reportedAs` holds
        // the exact wording she tapped, which is what the sheet re-selects on.
        for (final entry in symptomNames.entries) {
          if (entry.value == symptom) {
            return MapEntry('symptom', reportedAs() ?? entry.key);
          }
        }

        // Fetal movement: two of its three words share one recorded name, so
        // only the label she picked can say which. Older rows without it fall
        // back to the card's middle answer rather than guessing between them.
        for (final entry in fetalMovementNames.entries) {
          if (entry.value == symptom) {
            return MapEntry('fetal_movement', reportedAs() ??
                (symptom == 'reduced movement' ? 'Quiet' : 'Normal'));
          }
        }

        if (symptom == 'contractions') {
          final label = reportedAs() ??
              _labelForValue('contractions', contractionBuckets, payload['severity']);
          return label == null ? null : MapEntry('contractions', label);
        }

        // The graded comfort selectors have their own card each, so they go
        // back to it rather than to mood, and by severity rather than by name.
        for (final entry in comfortSymptomNames.entries) {
          if (entry.value == symptom) {
            final label = reportedAs() ??
                _labelForValue(entry.key, comfortSeverityBuckets, payload['severity']);
            return label == null ? null : MapEntry(entry.key, label);
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

      case 'feeding_logged':
        final methodKey = payload['method']?.toString().toLowerCase();
        final feedingLabel = reportedAs() ??
            (methodKey == null
                ? null
                : _labelForMapped('feeding', feedingBuckets, methodKey));
        return feedingLabel == null ? null : MapEntry('feeding', feedingLabel);

      case 'hot_flash_logged':
        // Back to whichever of the two selectors recorded it.
        final isNight = payload['nightSweat'] == true;
        final flashMetric = isNight ? 'night_sweat' : 'hot_flash';
        final flashLabel = reportedAs() ??
            _labelForValue(flashMetric, hotFlashBuckets, payload['severity']);
        return flashLabel == null ? null : MapEntry(flashMetric, flashLabel);

      case 'medication_logged':
        final kindKey = payload['kind']?.toString().toLowerCase();
        for (final entry in medicationKinds.entries) {
          if (entry.value == kindKey) {
            final label = reportedAs() ??
                (payload['taken'] == true ? 'Taken' : 'Not Taken');
            return MapEntry(entry.key, label);
          }
        }
        return null;

      case 'recovery_metric_logged':
        // One event type, several postpartum cards; the metric name says which.
        switch (payload['metric']?.toString()) {
          case 'pelvic_floor':
            final pelvicLabel = reportedAs() ??
                _labelForValue('pelvic_floor', pelvicFloorBuckets, payload['value']);
            return pelvicLabel == null
                ? null
                : MapEntry('pelvic_floor', pelvicLabel);
          case 'lochia':
            final lochiaLabel = reportedAs() ??
                _labelForValue('postpartum_bleeding', lochiaBuckets, payload['value']);
            return lochiaLabel == null
                ? null
                : MapEntry('postpartum_bleeding', lochiaLabel);
          case 'incision_discomfort':
            final incisionLabel = reportedAs() ??
                _labelForValue('incision', incisionBuckets, payload['value']);
            return incisionLabel == null
                ? null
                : MapEntry('incision', incisionLabel);
          default:
            return null;
        }

      case 'cervical_mucus_logged':
        final mucusKey = payload['observation']?.toString().toLowerCase();
        final mucusLabel = reportedAs() ??
            (mucusKey == null ? null : _labelForMapped('cervical_mucus', cervicalMucusBuckets, mucusKey));
        return mucusLabel == null ? null : MapEntry('cervical_mucus', mucusLabel);

      case 'sexual_activity_logged':
        // Either field may be the whole entry; see the validator's note on
        // logging drive without an activity.
        final sexActivity = payload['activity']?.toString().toLowerCase();
        final sexDriveValue = payload['drive']?.toString().toLowerCase();
        final sexLabel = reportedAs() ??
            (sexActivity == null
                ? null
                : _labelForMapped('sex', sexActivities, sexActivity)) ??
            (sexDriveValue == null
                ? null
                : _labelForMapped('sex', sexDrive, sexDriveValue));
        return sexLabel == null ? null : MapEntry('sex', sexLabel);

      case 'pregnancy_test_logged':
        final testKey = payload['result']?.toString().toLowerCase();
        final testLabel = reportedAs() ??
            (testKey == null
                ? null
                : _labelForMapped(
                    'pregnancy_test', pregnancyTestResults, testKey));
        return testLabel == null ? null : MapEntry('pregnancy_test', testLabel);

      case 'lh_test_logged':
        final lhKey = payload['result']?.toString().toLowerCase();
        final lhLabel = reportedAs() ??
            (lhKey == null ? null : _labelForMapped('lh_test', lhTestBuckets, lhKey));
        return lhLabel == null ? null : MapEntry('lh_test', lhLabel);

      case 'flow_logged':
        final flowKey = payload['flow']?.toString().toLowerCase();
        final label = reportedAs() ?? (flowKey == null ? null : labelFor('flow', flowKey));
        return label == null ? null : MapEntry('flow', label);

      case 'activity_logged':
        // The habit cards share this event type with the movement selector,
        // so the activity name decides which card it belongs to. Without this
        // a logged walk came back as an "exercise" answer and the habit card
        // it was entered on showed nothing selected.
        final activityName = payload['activity']?.toString().toLowerCase();
        for (final entry in habitActivityNames.entries) {
          if (entry.value == activityName) {
            final label = reportedAs() ??
                _labelForValue(entry.key, habitDoneBuckets,
                    payload['intensity'] == 'done' ? 1 : 0);
            return label == null ? null : MapEntry(entry.key, label);
          }
        }

        final label = reportedAs() ?? _labelForValue('exercise', exerciseBuckets, payload['durationMinutes']);
        return label == null ? null : MapEntry('exercise', label);

      default:
        return null;
    }
  }

  /// Recovers the bucket label for events written before `reportedAs` existed.
  /// Only an exact match counts: a value between buckets is left unmapped
  /// rather than snapped to the nearest label.
  /// The card's label for a stored string value.
  ///
  /// Needed where the stored word differs from the word on the card, which is
  /// only `egg_white` today -- a plain `labelFor` would render the stored form.
  static String? _labelForMapped(
      String metric, Map<String, String> buckets, String storedValue) {
    for (final entry in buckets.entries) {
      if (entry.value == storedValue) return labelFor(metric, entry.key);
    }
    return null;
  }

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
    String? variant,
  }) {
    final dayKey = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    // One key per metric per day is right for a single-select card: the second
    // answer replaces the first. A multi-select card needs one key per option
    // instead, or every chip tapped collapses onto one key and the server
    // keeps whichever arrived first. Still idempotent -- tapping the same chip
    // twice is the same key -- just per chip rather than per card.
    final suffix = variant == null ? '' : ':${variant.trim().toLowerCase()}';
    return 'checkin:$userId:$metric:$dayKey$suffix';
  }
}
