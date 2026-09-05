/// The check-in questions today's symptoms earn.
///
/// The check-in used to ask the same thing every day. This makes it respond to
/// what was actually logged: someone who reported fatigue is asked about sleep,
/// water and energy; someone who reported cramps is asked about movement.
/// Log nothing and it asks nothing extra.
///
/// Two rules this file exists to keep:
///
/// 1. **A follow-up is a prompt to log, never evidence.** The question is
///    generated from a symptom, so answering it cannot then be reported back
///    as a finding about that symptom -- that is a leading question with the
///    answer already in it. Insights are computed in the backend pattern
///    engine, which requires six paired observations across separate days
///    before it will say anything, and never sees which card produced a log.
///
/// 2. **Every question maps to an event type that already exists.** A question
///    whose answer has nowhere to go is a question not worth asking.
library;

/// One generated yes/no card.
class CheckinFollowUp {
  const CheckinFollowUp({
    required this.id,
    required this.question,
    required this.becauseOf,
    required this.metric,
    required this.yesValue,
    required this.noValue,
  });

  /// A card as stored for the day, and as Docsy sends it.
  factory CheckinFollowUp.fromJson(Map<String, dynamic> json) {
    return CheckinFollowUp(
      id: json['id'].toString(),
      question: json['question'].toString(),
      becauseOf: List.unmodifiable(
        (json['becauseOf'] as List? ?? const []).map((e) => e.toString()),
      ),
      metric: json['metric'].toString(),
      yesValue: json['yesValue'].toString(),
      noValue: json['noValue'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'becauseOf': becauseOf,
        'metric': metric,
        'yesValue': yesValue,
        'noValue': noValue,
      };

  /// Stable across a day, so an answer can be stored and read back.
  final String id;

  final String question;

  /// The symptoms that earned this card, in the order they are listed on the
  /// sheet. Shown so the card does not look arbitrary.
  ///
  /// Several symptoms can point at one question -- cramps, backache and
  /// abdominal pain all raise movement -- and naming only the first made the
  /// card look like it had ignored the rest.
  final List<String> becauseOf;

  /// The check-in metric the answer records under.
  final String metric;

  /// What a yes and a no record as. Both are real answers: "no" is data.
  final String yesValue;
  final String noValue;

  /// "cramps", "cramps and backache", "cramps, backache and abdominal pain".
  String get becauseOfLabel {
    if (becauseOf.isEmpty) return '';
    if (becauseOf.length == 1) return becauseOf.first;
    return '${becauseOf.sublist(0, becauseOf.length - 1).join(', ')} '
        'and ${becauseOf.last}';
  }

  @override
  bool operator ==(Object other) =>
      other is CheckinFollowUp && other.id == id && other.metric == metric;

  @override
  int get hashCode => Object.hash(id, metric);
}

/// A question, and the metric its answer records under.
class _Question {
  const _Question(this.metric, this.id, this.text, this.yes, this.no);

  final String metric;
  final String id;
  final String text;
  final String yes;
  final String no;
}

class CheckinFollowUps {
  const CheckinFollowUps._();

  /// The most cards shown at once.
  ///
  /// Raised from three: three questions could not cover a day with six
  /// symptoms in it, and the pattern engine needs paired observations across
  /// several metrics before it can say anything at all. The ceiling is really
  /// [_questions] -- one question per metric, so at most as many cards as
  /// there are metrics worth asking about.
  static const int maxCards = 6;

  /// One question per metric.
  ///
  /// Deliberately one: two cards writing the same metric would let the second
  /// answer overwrite the first, so a metric can only ever be asked once a day
  /// however many symptoms point at it.
  ///
  /// Pain is not here on purpose. A yes/no cannot express a severity, and the
  /// only honest mapping for "yes" is `Severe`, which stores an 8 -- above the
  /// threshold on `rf_pg_severe_abdominal_pain`. A coarse tap would then raise
  /// a reviewed clinical escalation, which is not a thing to infer from a
  /// checkbox.
  static const List<_Question> _questions = [
    _Question('sleep', 'fu_sleep', 'Did you sleep at least 7 hours?',
        '7-8h', '<6h'),
    _Question('water', 'fu_water', 'Did you drink about 2L of water?',
        '2L', '1L'),
    _Question('exercise', 'fu_movement', 'Did you move or stretch today?',
        'Light', 'None'),
    _Question('stress', 'fu_stress', 'Was today a high-stress day?',
        'High', 'Low'),
    _Question('energy', 'fu_energy', 'Did your energy hold up today?',
        'High', 'Low'),
  ];

  /// Which questions each symptom raises.
  ///
  /// Each is a plausible contributor the symptom does not already state:
  /// asking "are you tired?" after she logged fatigue tells us nothing, asking
  /// what she slept does. A symptom naming several metrics is what lets one
  /// day's logging produce enough paired observations to be worth anything.
  ///
  /// The clinical words -- blood clots, unusual discharge -- raise nothing.
  /// There is no lifestyle question that belongs after them, and inventing one
  /// would suggest they are hers to fix.
  static const Map<String, List<String>> _raises = {
    'fatigue': ['sleep', 'water', 'energy', 'stress'],
    'headache': ['water', 'sleep', 'stress'],
    'cramps': ['exercise', 'water', 'sleep'],
    'backache': ['exercise', 'sleep'],
    'abdominal pain': ['exercise', 'water'],
    'bloating': ['water', 'exercise'],
    'constipation': ['water', 'exercise'],
    'diarrhea': ['water'],
    'nausea': ['water', 'sleep'],
    'insomnia': ['stress', 'exercise', 'energy'],
    'cravings': ['sleep', 'energy', 'stress'],
    'acne': ['stress', 'water', 'sleep'],
    'tender breasts': ['stress'],
    'dry skin': ['water'],
    'dry eyes': ['water', 'sleep'],
    'swelling': ['water', 'exercise'],
    'vaginal dryness': ['water'],
    'vaginal itching': ['stress'],
    'hair thinning': ['stress', 'sleep'],
    'excess facial hair': ['stress'],
  };

  /// The cards today's symptoms earn, most informative first.
  ///
  /// [symptoms] are the labels from the sheet, in any case. Returns an empty
  /// list when nothing was logged, or when the only thing logged was the
  /// "everything is fine" opt-out -- there is nothing to follow up on.
  ///
  /// Ranked by how many of the logged symptoms raise each question. A metric
  /// three symptoms point at is more worth an answer than one only a single
  /// symptom raises, and before this the first rule in file order simply won.
  static List<CheckinFollowUp> forSymptoms(Iterable<String> symptoms) {
    final logged = <String>[];
    for (final raw in symptoms) {
      final value = raw.trim().toLowerCase();
      if (value.isEmpty || logged.contains(value)) continue;
      logged.add(value);
    }
    if (logged.isEmpty) return const [];

    // metric -> the logged symptoms that raise it, in the order she sees them.
    final raisedBy = <String, List<String>>{};
    for (final symptom in logged) {
      for (final metric in _raises[symptom] ?? const <String>[]) {
        raisedBy.putIfAbsent(metric, () => <String>[]).add(symptom);
      }
    }
    if (raisedBy.isEmpty) return const [];

    final ranked = _questions
        .where((q) => raisedBy.containsKey(q.metric))
        .toList()
      ..sort((a, b) {
        final byCount =
            raisedBy[b.metric]!.length.compareTo(raisedBy[a.metric]!.length);
        if (byCount != 0) return byCount;
        // Ties keep declaration order, so the same day's symptoms always
        // produce the same cards in the same order rather than shuffling on
        // every rebuild.
        return _questions.indexOf(a).compareTo(_questions.indexOf(b));
      });

    return [
      for (final q in ranked.take(maxCards))
        CheckinFollowUp(
          id: q.id,
          question: q.text,
          becauseOf: List.unmodifiable(raisedBy[q.metric]!),
          metric: q.metric,
          yesValue: q.yes,
          noValue: q.no,
        ),
    ];
  }

  /// Every metric a follow-up can write, for the guard test.
  /// The metrics Docsy may ask about and the answers each may carry. The
  /// same contract the server enforces, checked again here: a card whose
  /// answer has nowhere to go is not shown, whoever wrote it.
  static const Map<String, List<String>> allowedValues = {
    'sleep': ['<6h', '6-8h', '>8h', '7-8h'],
    'water': ['1L', '2L', '3L'],
    'exercise': ['Active', 'Light', 'None'],
    'stress': ['Low', 'Moderate', 'High'],
    'energy': ['High', 'Medium', 'Low'],
    'mood': ['Happy', 'Okay', 'Calm', 'Low', 'Irritable'],
    'pain': ['None', 'Mild', 'Severe'],
  };

  /// Docsy's cards, kept only where they respect the contract.
  static List<CheckinFollowUp> fromModel(dynamic raw) {
    final list = raw is List ? raw : (raw is Map ? raw['cards'] : null);
    if (list is! List) return const [];
    final seen = <String>{};
    final out = <CheckinFollowUp>[];
    for (final item in list) {
      if (item is! Map) continue;
      final metric = item['metric']?.toString().trim().toLowerCase() ?? '';
      final allowed = allowedValues[metric];
      if (allowed == null || seen.contains(metric)) continue;
      final question = item['question']?.toString().trim() ?? '';
      if (question.length < 8 || question.length > 120 || !question.endsWith('?')) continue;
      final yes = item['yesValue']?.toString().trim() ?? '';
      final no = item['noValue']?.toString().trim() ?? '';
      if (!allowed.contains(yes) || !allowed.contains(no) || yes == no) continue;
      seen.add(metric);
      out.add(CheckinFollowUp(
        id: 'ai_$metric',
        question: question,
        becauseOf: List.unmodifiable(
          (item['becauseOf'] as List? ?? const []).map((e) => e.toString()).where((e) => e.isNotEmpty),
        ),
        metric: metric,
        yesValue: yes,
        noValue: no,
      ));
      if (out.length >= maxCards) break;
    }
    return out;
  }

  static Set<String> get metrics => {for (final q in _questions) q.metric};

  /// Every value a follow-up can write, for the guard test.
  static Set<String> get values =>
      {for (final q in _questions) ...[q.yes, q.no]};

  /// Every symptom that raises at least one question, for the guard test.
  static Set<String> get symptomsWithQuestions => _raises.keys.toSet();
}
