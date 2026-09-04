/// What each life stage is asked to log.
///
/// The sheet started as one "Symptoms" group with everything in it. That is
/// wrong twice over: it buries fourteen unrelated things under one heading,
/// and it shows a menopause user an ovulation test and a pregnancy user a
/// menstrual flow selector.
///
/// So a category declares which stages it belongs to, and the sheet renders
/// only those. Gating is per category, not per option: a category a stage does
/// not need is absent entirely rather than shown empty.
///
/// Two gates that are decisions rather than relevance:
///
///  * `firstPeriodNotStarted` and `firstPeriodStarted` are the stages a child
///    or young teenager is in. Sex and pregnancy testing are withheld there.
///    That is a safeguarding choice, not an oversight, and it is written down
///    here so it cannot be undone by accident.
///  * Menstrual flow is withheld in pregnancy, postpartum and menopause.
///    Postpartum bleeding is recorded as lochia by its own card, and bleeding
///    after menopause is a reviewed red flag rather than something to track
///    casually.
library;

/// One group on the symptoms sheet.
class SymptomCategory {
  const SymptomCategory({
    required this.id,
    required this.label,
    required this.options,
    required this.stages,
    required this.metric,
    this.multiSelect = true,
    this.optionMetrics = const {},
    this.subtitle,
    this.numericId,
  });

  /// Stable key for the consent switch and for storage.
  final String id;

  final String label;
  final List<String> options;

  /// The normalised life stages that see this category.
  final Set<String> stages;

  /// The check-in metric its options record under.
  final String metric;

  /// Whether several options can be chosen at once. Flow, discharge and the
  /// two tests are one answer a day; symptoms and activity are not.
  final bool multiSelect;

  /// Options that record under a different metric from the rest of the group.
  ///
  /// Vaginal discharge is the case this exists for: a mucus observation is a
  /// fertility signal, while "unusual" or "grey" is a symptom. They sit under
  /// one heading because that is how a person thinks about them, and they are
  /// stored apart because they mean different things.
  final Map<String, String> optionMetrics;

  final String? subtitle;

  /// Set for a reading rather than a choice: 'weight' or 'bbt'.
  ///
  /// Held as an id rather than the config object so this file stays free of
  /// widget imports. The sheet resolves it.
  final String? numericId;

  bool get isNumeric => numericId != null;

  /// The metric [option] records under.
  String metricFor(String option) => optionMetrics[option] ?? metric;
}

/// A selection on the sheet: which group, and which word in it.
///
/// `categoryId/label`. The words are not unique across groups -- "Low" is
/// mood, energy and stress -- so a word on its own does not say what was
/// logged. A key with no slash is a bare word from before this existed, and
/// resolves to the first group that owns it, which is the only reading it
/// ever had.
class SymptomKey {
  const SymptomKey._();

  static const String separator = '/';

  static String qualify(String categoryId, String label) =>
      '$categoryId$separator$label';

  /// The word, with or without its group.
  static String label(String key) {
    final i = key.indexOf(separator);
    return i < 0 ? key : key.substring(i + 1);
  }

  /// The group, or null for a bare word.
  static String? categoryId(String key) {
    final i = key.indexOf(separator);
    return i < 0 ? null : key.substring(0, i);
  }

  /// The group a key belongs to, or null where none owns it.
  static SymptomCategory? category(String key) {
    final id = categoryId(key);
    if (id != null) return SymptomCategories.byId(id);
    return SymptomCategories.owning(key);
  }

  /// The same selection, qualified. A bare word takes the first group that
  /// owns it; a word no group owns is left as it is.
  static String normalise(String key) {
    if (categoryId(key) != null) return key;
    final owner = SymptomCategories.owning(key);
    return owner == null ? key : qualify(owner.id, key);
  }
}

class SymptomCategories {
  const SymptomCategories._();

  /// The first group offering [label], or null.
  static SymptomCategory? owning(String label) {
    for (final c in all) {
      if (c.options.contains(label)) return c;
    }
    return null;
  }

  // The stage keys, normalised the way the dashboard normalises them:
  // lower-cased with underscores and spaces removed.
  static const String notStarted = 'firstperiodnotstarted';
  static const String firstPeriod = 'firstperiodstarted';
  static const String cycle = 'livingwithmycycle';
  static const String hormonal = 'hormonalhealth';
  static const String ttc = 'tryingtoconceive';
  static const String pregnancy = 'pregnancy';
  static const String postpartum = 'postpartum';
  static const String perimenopause = 'perimenopause';
  static const String menopause = 'menopause';
  static const String wellness = 'everydaywellness';

  static const Set<String> everyStage = {
    notStarted, firstPeriod, cycle, hormonal, ttc,
    pregnancy, postpartum, perimenopause, menopause, wellness,
  };

  /// Stages where someone is menstruating and tracking it.
  static const Set<String> menstruating = {
    firstPeriod, cycle, hormonal, ttc, perimenopause, wellness,
  };

  /// Stages we treat as adult. See the note at the top of this file.
  static const Set<String> adult = {
    cycle, hormonal, ttc, pregnancy, postpartum,
    perimenopause, menopause, wellness,
  };

  /// Stages where conceiving is a possibility being tracked.
  static const Set<String> tryingOrCould = {
    cycle, hormonal, ttc, perimenopause, wellness,
  };

  static const List<SymptomCategory> all = [
    // --- the daily basics -----------------------------------------------
    // These were the check-in's own selectors. They live here now so there is
    // one place to log and one sheet to open, and so the check-in surface can
    // be what today's entries earn rather than a fixed form.
    SymptomCategory(
      id: 'mood',
      label: 'Mood',
      metric: 'mood',
      multiSelect: false,
      stages: everyStage,
      options: ['Happy', 'Okay', 'Calm', 'Low', 'Irritable'],
    ),
    SymptomCategory(
      id: 'energy',
      label: 'Energy',
      metric: 'energy',
      multiSelect: false,
      stages: everyStage,
      options: ['High', 'Medium', 'Low'],
    ),
    SymptomCategory(
      id: 'pain',
      label: 'Pain',
      metric: 'pain',
      multiSelect: false,
      stages: everyStage,
      options: ['None', 'Mild', 'Severe'],
    ),
    SymptomCategory(
      id: 'sleep',
      label: 'Sleep',
      metric: 'sleep',
      multiSelect: false,
      stages: everyStage,
      options: ['<6h', '6-8h', '>8h'],
    ),
    SymptomCategory(
      id: 'stress',
      label: 'Stress',
      metric: 'stress',
      multiSelect: false,
      stages: everyStage,
      options: ['Low', 'Moderate', 'High'],
    ),
    SymptomCategory(
      id: 'water',
      label: 'Water',
      metric: 'water',
      multiSelect: false,
      stages: everyStage,
      options: ['1L', '2L', '3L'],
    ),
    SymptomCategory(
      id: 'movement',
      label: 'Movement',
      metric: 'exercise',
      multiSelect: false,
      stages: everyStage,
      options: ['Active', 'Light', 'None'],
    ),

    // --- cycle and symptoms ----------------------------------------------
    SymptomCategory(
      id: 'flow',
      label: 'Menstrual flow',
      subtitle: 'Estimate your average daily flow',
      metric: 'flow',
      multiSelect: false,
      stages: menstruating,
      // 'Blood clots' is not a flow level, so it records as a symptom.
      optionMetrics: {'Blood clots': 'symptom'},
      options: ['Light', 'Medium', 'Heavy', 'Blood clots'],
    ),
    SymptomCategory(
      id: 'symptom',
      label: 'Symptoms',
      metric: 'symptom',
      stages: everyStage,
      options: [
        'Cramps',
        'Headache',
        'Tender breasts',
        'Backache',
        'Abdominal pain',
        'Acne',
        'Fatigue',
        'Cravings',
        'Insomnia',
        // Asked about at signup, and until now offered nowhere to log.
        'Swelling',
        'Dry skin',
        'Dry eyes',
      ],
    ),
    SymptomCategory(
      id: 'intimate',
      label: 'Intimate health',
      metric: 'symptom',
      // Not shown pre-menarche.
      stages: {
        firstPeriod, cycle, hormonal, ttc, pregnancy,
        postpartum, perimenopause, menopause, wellness,
      },
      options: ['Vaginal itching', 'Vaginal dryness'],
    ),
    SymptomCategory(
      id: 'discharge',
      label: 'Vaginal discharge',
      subtitle: 'Cervical mucus changes, or anything odd',
      metric: 'cervical_mucus',
      multiSelect: false,
      stages: {
        firstPeriod, cycle, hormonal, ttc,
        postpartum, perimenopause, menopause, wellness,
      },
      // The first five are mucus observations the fertility engine reads. The
      // last three are not: they describe discharge that may need looking at,
      // and recording them as a fertility reading would corrupt that signal.
      optionMetrics: {
        'Unusual': 'symptom',
        'Clumpy white': 'symptom',
        'Grey': 'symptom',
      },
      options: [
        'Dry',
        'Sticky',
        'Creamy',
        'Watery',
        'Eggwhite',
        'Unusual',
        'Clumpy white',
        'Grey',
      ],
    ),
    SymptomCategory(
      id: 'hair',
      label: 'Hair and skin',
      metric: 'symptom',
      // Asked about in the hormonal branch at signup and offered nowhere to
      // log until now. Postpartum is included because shedding after birth is
      // extremely common and people look for it.
      stages: {hormonal, postpartum, perimenopause, menopause},
      options: ['Hair thinning', 'Excess facial hair'],
    ),
    SymptomCategory(
      id: 'digestion',
      label: 'Digestion and stool',
      metric: 'symptom',
      stages: everyStage,
      options: ['Nausea', 'Bloating', 'Constipation', 'Diarrhea'],
    ),
    SymptomCategory(
      id: 'sex',
      label: 'Sex and sex drive',
      metric: 'sex',
      stages: adult,
      options: [
        'Did not have sex',
        'Protected sex',
        'Unprotected sex',
        'Oral sex',
        'Masturbation',
        'Sensual touch',
        'High sex drive',
        'Neutral sex drive',
        'Low sex drive',
      ],
    ),
    SymptomCategory(
      id: 'ovulation_test',
      label: 'Ovulation test',
      subtitle: 'Log them to know when you ovulate',
      metric: 'lh_test',
      multiSelect: false,
      // A fertility tool. Offering it in pregnancy or menopause is noise.
      stages: {cycle, hormonal, ttc},
      options: ['Test: negative', 'Test: low', 'Test: high', 'Test: peak'],
    ),
    SymptomCategory(
      id: 'pregnancy_test',
      label: 'Pregnancy test',
      metric: 'pregnancy_test',
      multiSelect: false,
      stages: tryingOrCould,
      options: ['Did not test', 'Positive', 'Negative', 'Faint line'],
    ),
    // --- pregnancy -------------------------------------------------------
    SymptomCategory(
      id: 'fetal_movement',
      label: 'Baby movement',
      metric: 'fetal_movement',
      multiSelect: false,
      stages: {pregnancy},
      // 'Quiet' records as reduced movement, which a reviewed red-flag rule
      // acts on from 24 weeks. The wording is load-bearing.
      options: ['Active', 'Normal', 'Quiet'],
    ),
    SymptomCategory(
      id: 'contractions',
      label: 'Contractions',
      metric: 'contractions',
      multiSelect: false,
      stages: {pregnancy},
      options: ['None', 'Mild', 'Strong'],
    ),

    // --- postpartum ------------------------------------------------------
    SymptomCategory(
      id: 'feeding',
      label: 'Feeding',
      metric: 'feeding',
      multiSelect: false,
      stages: {postpartum},
      options: ['Breastfeeding', 'Bottle Feeding', 'Pumping'],
    ),
    SymptomCategory(
      id: 'postpartum_bleeding',
      label: 'Bleeding',
      metric: 'postpartum_bleeding',
      multiSelect: false,
      stages: {postpartum},
      // Recorded as lochia rather than bleeding: the red-flag rules match by
      // substring, so "bleeding none" would fire a haemorrhage alert.
      options: ['None', 'Spotting', 'Flow'],
    ),
    SymptomCategory(
      id: 'incision',
      label: 'Incision healing',
      metric: 'incision',
      multiSelect: false,
      stages: {postpartum},
      options: ['Healing', 'Sore', 'Not Applicable'],
    ),
    SymptomCategory(
      id: 'pelvic_floor',
      label: 'Pelvic floor',
      metric: 'pelvic_floor',
      multiSelect: false,
      stages: {postpartum},
      options: ['Completed', 'Not Done'],
    ),

    // --- perimenopause and menopause -------------------------------------
    SymptomCategory(
      id: 'hot_flash',
      label: 'Hot flashes',
      metric: 'hot_flash',
      multiSelect: false,
      stages: {perimenopause, menopause},
      options: ['None', 'Mild', 'Intense'],
    ),
    SymptomCategory(
      id: 'night_sweat',
      label: 'Night sweats',
      metric: 'night_sweat',
      multiSelect: false,
      stages: {perimenopause, menopause},
      options: ['None', 'Mild', 'Intense'],
    ),
    SymptomCategory(
      id: 'brain_fog',
      label: 'Brain fog and memory',
      metric: 'brain_fog',
      multiSelect: false,
      stages: {perimenopause, menopause},
      options: ['None', 'Mild', 'Intense'],
    ),
    SymptomCategory(
      id: 'joint_pain',
      label: 'Joint pain and stiffness',
      metric: 'joint_pain',
      multiSelect: false,
      stages: {perimenopause, menopause},
      options: ['None', 'Mild', 'Intense'],
    ),
    SymptomCategory(
      id: 'hormone_therapy',
      label: 'Hormone therapy',
      metric: 'hormone_therapy',
      multiSelect: false,
      stages: {perimenopause, menopause},
      // 'None' is a different axis -- not "did you take it" but "I am not on
      // it" -- so it is declared unrecorded rather than stored as adherence.
      options: ['Taken', 'Not Taken', 'None'],
    ),

    // --- readings --------------------------------------------------------
    SymptomCategory(
      id: 'weight',
      label: 'Weight',
      metric: 'weight',
      numericId: 'weight',
      stages: everyStage,
      options: [],
    ),
    SymptomCategory(
      id: 'bbt',
      label: 'Basal temperature',
      subtitle: 'Taken before getting up, at the same time each morning',
      metric: 'bbt',
      numericId: 'bbt',
      // A fertility signal: detectBbtShift confirms ovulation from it.
      stages: {cycle, hormonal, ttc, perimenopause, wellness},
      options: [],
    ),

    SymptomCategory(
      id: 'activity',
      label: 'Physical activity',
      metric: 'activity',
      stages: everyStage,
      options: [
        'Did not exercise',
        'Yoga',
        'Gym',
        'Aerobics and dancing',
        'Swimming',
        'Team sports',
        'Running',
        'Cycling',
        'Walking',
      ],
    ),
    SymptomCategory(
      id: 'lifestyle',
      label: 'Other',
      metric: 'activity',
      stages: everyStage,
      // No 'Stress' chip here on purpose. The check-in already asks for
      // stress on a three-point scale, and a yes/no chip writing the same
      // metric would be a second, coarser vocabulary over one field -- which
      // is what the vocabulary registry exists to prevent. A bare "Stress"
      // would also have to be stored as some level she never chose.
      optionMetrics: {'Disease or injury': 'symptom'},
      options: [
        'Travel',
        'Meditation',
        'Journaling',
        'Kegel exercises',
        'Breathing exercises',
        'Disease or injury',
        'Alcohol',
      ],
    ),
  ];

  /// Normalises a stored stage the way the dashboard's own switch does.
  static String normalise(String? stage) {
    final raw = (stage ?? '').replaceAll('_', '').replaceAll(' ', '').toLowerCase();
    switch (raw) {
      case 'notstarted':
      case 'puberty':
        return notStarted;
      case 'started':
        return firstPeriod;
      case 'reproductiveyears':
      case 'cycle':
        return cycle;
      case 'pcos':
      case 'endometriosis':
        return hormonal;
      case 'ttc':
        return ttc;
      case 'pregnant':
        return pregnancy;
      case 'postmenopause':
        return menopause;
      case 'wellness':
      case '':
        return wellness;
      default:
        return everyStage.contains(raw) ? raw : wellness;
    }
  }

  /// The categories [stage] is asked to log, in display order.
  static List<SymptomCategory> forStage(String? stage) {
    final key = normalise(stage);
    return all.where((c) => c.stages.contains(key)).toList();
  }

  static SymptomCategory? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Every metric any category can write, for the guard test.
  static Set<String> get metrics => {
        for (final c in all) ...[c.metric, ...c.optionMetrics.values],
      };
}
