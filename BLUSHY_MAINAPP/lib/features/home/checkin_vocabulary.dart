/// The words every check-in selector may offer, declared once.
///
/// Each stage dashboard used to declare its own option lists inline -- 24
/// separate declarations across ten stages -- while [CheckinEventMapper] held
/// the values those words map onto. Nothing tied the two together, so a list
/// could gain a word the mapper had never heard of and the answer was dropped
/// on the floor: `map` returned null and `_recordCheckinEvent` returned
/// without a word to anyone.
///
/// That happened repeatedly and silently. The everyday wellness sleep ranges,
/// two of its three movement options, its half-litre hydration step, the
/// perimenopause 1.5L step, the pregnancy and postpartum movement wording, and
/// the perimenopause "None" flow were all logged by the person, stored on the
/// device, shown back on the dashboard -- and never became a health event. So
/// none of it reached the pattern engine, the care plan, the doctor summary,
/// the partner view or Docsy's context.
///
/// Declaring the words here does not by itself prevent that. What prevents it
/// is `checkin_vocabulary_test.dart`, which asserts every word in this file
/// maps to a value. Adding a word without a value now fails a test rather than
/// quietly losing data.
///
/// Variants exist because the stages genuinely differ: someone recovering
/// after birth is offered "Rest" where someone mid-cycle is offered "None",
/// and a pregnancy hydration target starts higher. They are variants of one
/// vocabulary, not separate ones.
library;

class CheckinVocabulary {
  const CheckinVocabulary._();

  // --- mood ---------------------------------------------------------------
  /// Moods only.
  ///
  /// This list used to carry 'Cramps' and 'Tired', which are symptoms. The
  /// mapper routed them to `symptom_logged`, so choosing one recorded no mood
  /// at all -- and because a check-in answer is a single value per metric,
  /// choosing one also overwrote a mood already picked that day. Someone who
  /// was happy and cramping could say only one of the two, and the app kept
  /// the wrong one. Symptoms now have [symptoms] and their own sheet.
  ///
  /// The replacements are moods the backend's `MOODS` enum already accepts.
  static const List<String> mood = [
    'Happy',
    'Okay',
    'Calm',
    'Low',
    'Irritable',
  ];

  // --- symptoms -------------------------------------------------------------
  /// What she can log on the symptoms sheet, which is multi-select.
  ///
  /// Deliberately excludes hot flashes, night sweats, brain fog and joint
  /// pain: those already have their own graded selectors, and offering them
  /// here as well would give one observation two ways in with two different
  /// shapes.
  ///
  /// Every word here was checked against the reviewed red-flag rules, which
  /// match by substring. 'Cramps' is a term on `rf_gyn_severe_pelvic_pain`,
  /// but that rule is gated at severity 9 and a chip carries no severity, so
  /// it cannot fire from a tap. 'Abdominal pain' is likewise gated at 7.
  /// Nothing here contains 'bleeding', 'fever', 'chills', 'chest pain' or the
  /// other terms that fire with no severity at all.
  static const List<String> symptoms = [
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
    'Vaginal itching',
    'Vaginal dryness',
    'Dry skin',
    'Dry eyes',
    'Everything is fine',
  ];

  /// Digestion.
  ///
  /// A heading on the sheet, not a metric: these record as `symptom_logged`
  /// exactly like [symptoms] do, so giving them their own metric would make
  /// one event type reverse to two different cards and the restore path could
  /// not tell which. The grouping is presentation; the data is one list.
  static const List<String> digestion = [
    'Nausea',
    'Bloating',
    'Constipation',
    'Diarrhea',
  ];

  // --- energy -------------------------------------------------------------
  static const List<String> energy = ['High', 'Medium', 'Low'];

  // --- pain ---------------------------------------------------------------
  static const List<String> pain = ['None', 'Mild', 'Severe'];

  // --- stress -------------------------------------------------------------
  static const List<String> stress = ['Low', 'Moderate', 'High'];

  // --- flow ---------------------------------------------------------------
  /// The cycle stages.
  static const List<String> flow = ['Light', 'Medium', 'Heavy'];

  /// Perimenopause, where skipped periods are the point and "None" is an
  /// answer rather than a missing one.
  static const List<String> flowWithNone = [
    'None',
    'Spotting',
    'Medium',
    'Heavy',
  ];

  // --- sleep --------------------------------------------------------------
  /// The cycle stages.
  static const List<String> sleep = ['<6h', '6-8h', '>8h'];

  /// Everyday wellness, which asks in finer steps around the middle.
  static const List<String> sleepFine = ['6-7h', '7-8h', '8h+'];

  // --- water --------------------------------------------------------------
  static const List<String> water = ['1L', '2L', '3L'];

  /// Pregnancy, postpartum and everyday wellness, where the target is higher.
  static const List<String> waterHigher = ['2L', '2.5L', '3L'];

  /// Perimenopause.
  static const List<String> waterMid = ['1.5L', '2L', '2.5L'];

  // --- movement -----------------------------------------------------------
  static const List<String> exercise = ['Active', 'Light', 'None'];

  /// Pregnancy, where the wording is gentler and resting is a real answer.
  static const List<String> exerciseGentle = ['Light Walk', 'Rest', 'None'];

  /// Postpartum.
  static const List<String> exerciseRecovery = [
    'Strength Training',
    'Walk',
    'None',
  ];

  /// Everyday wellness.
  static const List<String> exerciseWellness = ['Workout', 'Walk', 'None'];

  // --- fertility (trying to conceive) -------------------------------------
  /// Cervical mucus. "Eggwhite" is stored as `egg_white`; the mapper handles
  /// that, and this is the word the card shows.
  static const List<String> cervicalMucus = [
    'Dry',
    'Sticky',
    'Creamy',
    'Eggwhite',
  ];

  /// Ovulation (LH) test result. The backend also accepts "negative"; the card
  /// does not offer it, so it is not listed here.
  static const List<String> lhTest = ['Low', 'High', 'Peak'];

  // --- postpartum ---------------------------------------------------------
  static const List<String> feeding = [
    'Breastfeeding',
    'Bottle Feeding',
    'Pumping',
  ];

  static const List<String> pelvicFloor = ['Completed', 'Not Done'];

  // --- perimenopause and menopause ----------------------------------------
  /// Hot flashes and night sweats share one vocabulary and one event type;
  /// which selector recorded it is carried on the event itself.
  static const List<String> vasomotorSeverity = ['None', 'Mild', 'Intense'];

  // --- the Flo-style groups -------------------------------------------------
  /// Menstrual flow, as the symptoms sheet offers it. 'Blood clots' records as
  /// a symptom rather than a flow level; see SymptomCategory.optionMetrics.
  static const List<String> flowWithClots = [
    'Light',
    'Medium',
    'Heavy',
  ];

  /// Vaginal discharge. The last three are not mucus observations.
  static const List<String> discharge = [
    'Dry',
    'Sticky',
    'Creamy',
    'Watery',
    'Eggwhite',
  ];

  static const List<String> dischargeSymptoms = [
    'Unusual',
    'Clumpy white',
    'Grey',
  ];

  static const List<String> hair = [
    'Hair thinning',
    'Excess facial hair',
  ];

  static const List<String> intimate = [
    'Vaginal itching',
    'Vaginal dryness',
  ];

  static const List<String> sexActivity = [
    'Did not have sex',
    'Protected sex',
    'Unprotected sex',
    'Oral sex',
    'Masturbation',
    'Sensual touch',
    'High sex drive',
    'Neutral sex drive',
    'Low sex drive',
  ];

  static const List<String> pregnancyTest = [
    'Did not test',
    'Positive',
    'Negative',
    'Faint line',
  ];

  static const List<String> lhTestVerbose = [
    'Test: negative',
    'Test: low',
    'Test: high',
    'Test: peak',
  ];

  static const List<String> namedActivity = [
    'Did not exercise',
    'Yoga',
    'Gym',
    'Aerobics and dancing',
    'Swimming',
    'Team sports',
    'Running',
    'Cycling',
    'Walking',
  ];

  static const List<String> lifestyle = [
    'Travel',
    'Meditation',
    'Journaling',
    'Kegel exercises',
    'Breathing exercises',
    'Alcohol',
  ];

  // --- habits ---------------------------------------------------------------
  /// "Did you" selectors. Two spellings of the same yes, because the cards
  /// were written separately and both wordings are already in front of people.
  static const List<String> habitDone = ['Done', 'Not Done'];
  static const List<String> habitCompleted = ['Completed', 'Not Done'];

  /// Comfort symptoms graded on three steps.
  static const List<String> comfortSeverity = ['None', 'Mild', 'Intense'];

  /// Caesarean incision healing, for the postpartum card.
  static const List<String> incisionHealing = [
    'Healing',
    'Sore',
    'Not Applicable',
  ];

  // --- adherence ------------------------------------------------------------
  /// Daily medication and prenatal vitamins: did you take it today.
  static const List<String> doseTaken = ['Taken', 'Not Taken'];

  /// Hormone therapy. "None" is a third answer on a different axis -- not
  /// "did you take it today" but "I am not on it" -- so it is declared
  /// unrecorded below rather than stored as an adherence answer.
  static const List<String> doseTakenOrNone = ['Taken', 'Not Taken', 'None'];

  // --- pregnancy and postpartum monitoring ----------------------------------
  /// Fetal movement. "Quiet" is the one that matters: it records as reduced
  /// movement, which the reviewed red-flag rule acts on.
  static const List<String> fetalMovement = ['Active', 'Normal', 'Quiet'];

  static const List<String> contractions = ['None', 'Mild', 'Strong'];

  /// Postpartum bleeding, recorded as lochia rather than as bleeding. See the
  /// note on `lochiaBuckets` in the mapper for why the wording is load-bearing.
  static const List<String> postpartumBleeding = ['None', 'Spotting', 'Flow'];

  /// Words a card offers that are deliberately not recorded.
  ///
  /// Every other word here must map to a value, because a word that maps to
  /// nothing is an answer thrown away. This is the exception, and it has to be
  /// written down rather than assumed: "Not Applicable" on the incision card
  /// is not an observation about healing, it is someone saying the question
  /// does not apply to her. Recording it as a healing state would put a
  /// reading into the timeline for a wound that does not exist.
  ///
  /// The guard checks both directions -- a word listed here must not map, and
  /// a word not listed here must. So silence stays a decision somebody made on
  /// purpose, and cannot quietly become the same data loss this file exists to
  /// prevent.
  static const Map<String, Set<String>> unrecorded = {
    'incision': {'Not Applicable'},
    'hormone_therapy': {'None'},
    // "I have no symptoms today" is a real answer and not the same as not
    // having logged -- but there is no event type for it. Recording it as a
    // symptom called "everything is fine" would put a symptom she does not
    // have into her timeline, the doctor summary and Docsy's context. It is
    // kept on the device so the sheet can show it back, and left off the
    // wire until the backend has an event that can carry it honestly.
    'symptom': {'Everything is fine'},
  };

  /// Whether [label] is deliberately left unrecorded for [metric].
  static bool isUnrecorded(String metric, String label) =>
      unrecorded[metric]?.contains(label) ?? false;

  /// Every list above, keyed by the metric its words belong to.
  ///
  /// The guard test walks this to check each word maps, so a variant added
  /// above must be added here too or it is not covered.
  static const Map<String, List<List<String>>> byMetric = {
    'mood': [mood],
    'symptom': [
      symptoms,
      digestion,
      intimate,
      hair,
      dischargeSymptoms,
      ['Blood clots', 'Disease or injury'],
    ],
    'sex': [sexActivity],
    'pregnancy_test': [pregnancyTest],
    'activity': [namedActivity, lifestyle],
    'cervical_mucus': [cervicalMucus, discharge],
    'lh_test': [lhTest, lhTestVerbose],
    'energy': [energy],
    'pain': [pain],
    'stress': [stress],
    'flow': [flow, flowWithNone],
    'sleep': [sleep, sleepFine],
    'water': [water, waterHigher, waterMid],
    'exercise': [exercise, exerciseGentle, exerciseRecovery, exerciseWellness],
    'feeding': [feeding],
    'pelvic_floor': [pelvicFloor],
    'hot_flash': [vasomotorSeverity],
    'night_sweat': [vasomotorSeverity],
    'strength': [habitDone],
    'walking': [habitDone],
    'meditation': [habitCompleted],
    'brain_fog': [comfortSeverity],
    'joint_pain': [comfortSeverity],
    'incision': [incisionHealing],
    'medication': [doseTaken],
    'vitamin': [doseTaken],
    'hormone_therapy': [doseTakenOrNone],
    'fetal_movement': [fetalMovement],
    'contractions': [contractions],
    'postpartum_bleeding': [postpartumBleeding],
  };

  /// Every distinct word a selector for [metric] can render.
  static Set<String> labelsFor(String metric) =>
      {for (final variant in byMetric[metric] ?? const []) ...variant};
}
