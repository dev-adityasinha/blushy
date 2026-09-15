import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../partner_stage.dart';
import 'partner_home_sections.dart';
import '../../home/widgets/home_hero.dart';

/// Partner Home, told in the language of the stage she is actually in.
///
/// The same three things on every stage -- what today is like for her, what
/// would help, what to ask -- so the screen keeps one rhythm while the words
/// change. Stage 1 tokens throughout; the accent lives only on the badges.
///
/// The rule that governs this whole file: **explanations are general, values
/// are hers.** The physiology in a card body is true of the stage and is
/// written for anyone in it. Every number, phase, symptom and status is read
/// from what the permission filter actually sent, and where it sent nothing
/// the badge says so rather than showing a plausible figure.
///
/// A worked list of what that rules out, because the brief asked for them and
/// nothing in the app records them: a puberty emergency-kit count, a baby
/// size-and-weight analogy, kick counts, a PMDD flare countdown, an
/// inflammation or anxiety score, ovulation-test or basal-temperature status,
/// hot-flash counts, night-sweat intensity, incision healing, and feeding
/// logs. A partner acting on a number the app invented is worse off than a
/// partner who was told nothing.

/// One badge's worth of content, before it becomes a widget.
class PartnerBadgeSpec {
  const PartnerBadgeSpec({
    required this.icon,
    required this.colour,
    required this.tint,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color colour;
  final Color tint;
  final String label;
  final String value;
}

/// Badge palette. Every pair is a hue and its ~10% tint, as the design rules
/// name them.
const _cobalt = Color(0xFF2563EB);
const _cobaltTint = Color(0xFFDBEAFE);
const _teal = Color(0xFF0D9488);
const _tealTint = Color(0xFFCCFBF1);
const _magenta = Color(0xFFF72585);
const _magentaTint = Color(0xFFFFE5F0);
const _amber = Color(0xFFB45309);
const _amberTint = Color(0xFFFEF3C7);
const _purple = Color(0xFF7209B7);
const _purpleTint = Color(0xFFF3E8FF);
const _crimsonTint = Color(0xFFFCE4E7);

/// What is known about her today, and what that stage means.
///
/// Constructed from the permission-filtered context and nothing else. It has
/// no access to her records, so there is nothing here it could leak.
class PartnerStageToday {
  const PartnerStageToday({
    required this.stage,
    required this.permitted,
    required this.partnerName,
  });

  final PartnerStage stage;
  final Map<String, dynamic> permitted;
  final String partnerName;

  // ---------------------------------------------------------------- values

  Map<String, dynamic>? _map(String key) {
    final value = permitted[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? get phase => _text(_map('cyclePhase')?['phase']);
  int? get cycleDay {
    final day = _map('cyclePhase')?['cycleDay'];
    return day is num ? day.toInt() : int.tryParse(day?.toString() ?? '');
  }

  /// Her mood, in the word she chose.
  ///
  /// The check-in stores a token rather than the label she tapped --
  /// `checkin_event_mapper.dart` maps "Happy" to `good` on the way in -- so
  /// showing the stored value verbatim told her partner she felt "good" when
  /// what she actually pressed was "Happy". Near enough to look right, and
  /// wrong enough to be her word replaced by ours.
  ///
  /// Mapped back for display only. Nothing is rewritten in storage, and a
  /// token with no entry here is shown as it came rather than dropped.
  String? get mood {
    final raw = _text(_map('mood')?['value']);
    if (raw == null) return null;
    return _moodLabels[raw.toLowerCase()] ?? _capitalise(raw);
  }

  static const Map<String, String> _moodLabels = {
    // The current check-in vocabulary.
    'good': 'Happy',
    'okay': 'Okay',
    'calm': 'Calm',
    'low': 'Low',
    'irritable': 'Irritable',
    // Older rows, and the words the care-suggestion table still uses.
    'great': 'Happy',
    'happy': 'Happy',
    'irritated': 'Irritable',
    'sad': 'Low',
    'anxious': 'Anxious',
    'tired': 'Tired',
  };

  static String _capitalise(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  /// Logged on a 1-5 scale, which is why this is not rendered as "8/10".
  String? get energy {
    final raw = _map('energyLevel')?['value'];
    if (raw is num) {
      if (raw >= 4) return 'High';
      if (raw >= 3) return 'Steady';
      return 'Low';
    }
    return _text(raw);
  }

  double? get sleepHours {
    final raw = _map('sleep')?['durationHours'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  String? get sleepLabel {
    final hours = sleepHours;
    if (hours == null) return _text(_map('sleep')?['quality']);
    final rounded = hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1);
    return '$rounded hrs';
  }

  List<String> get symptoms {
    final raw = permitted['symptoms'];
    if (raw is! List) return const [];
    return raw
        .map((item) => item is Map ? _text(item['symptom']) : _text(item))
        .whereType<String>()
        .toList();
  }

  int? get pregnancyWeek {
    final raw = _map('pregnancyWeek')?['week'];
    return raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  }

  int? get trimester {
    final raw = _map('pregnancyWeek')?['trimester'];
    return raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  }

  /// Days between today and her due date. Derived, not invented: the due date
  /// itself is hers and arrived in the payload.
  int? get daysToDue {
    final due = DateTime.tryParse(_map('pregnancyWeek')?['dueDate']?.toString() ?? '');
    if (due == null) return null;
    final days = due.difference(DateTime.now()).inDays;
    return days < 0 ? null : days;
  }

  String? get pregnancyMilestone => _text(_map('pregnancyMilestone')?['title']);

  DateTime? get _nextPeriodEarliest =>
      DateTime.tryParse(_map('nextPeriodWindow')?['earliest']?.toString() ?? '');

  /// Her cycle length: hers where the payload carries it, otherwise inferred
  /// from the next-period window, otherwise absent.
  ///
  /// The ring needs a length to place today on it, and it is the same ring her
  /// own home screen draws -- so it has to be drawn to her cycle or not at
  /// all. `cycleLengthDays` now travels with the phase under the same grant;
  /// the window is the fallback for a payload written before that. Falling
  /// back to 28 would put a stranger's shape under her name, so the last
  /// resort is null and the ring drops its countdown instead.
  int? get cycleLength {
    final shared = _map('cyclePhase')?['cycleLengthDays'];
    final fromServer = shared is num ? shared.toInt() : null;
    if (fromServer != null && fromServer >= 18 && fromServer <= 60) {
      return fromServer;
    }

    final day = cycleDay;
    final next = _nextPeriodEarliest;
    if (day == null || next == null) return null;
    final until = next.difference(DateTime.now()).inDays;
    if (until < 0) return null;
    final length = day + until;
    return (length >= 18 && length <= 60) ? length : null;
  }

  /// How long her period runs, which is how much of the ring is shaded.
  ///
  /// Null rather than a guess: [PartnerCycleTracker] only passes it on when it
  /// is real, so the ring keeps its own default instead of this one inventing
  /// a different one.
  int? get periodLength {
    final shared = _map('cyclePhase')?['periodLengthDays'];
    final value = shared is num ? shared.toInt() : null;
    return (value != null && value >= 1 && value <= 12) ? value : null;
  }

  int? get weeksSinceBirth {
    final raw = _map('postpartumMilestone')?['weeksSinceBirth'];
    return raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  }

  String? get postpartumMilestone => _text(_map('postpartumMilestone')?['title']);

  DateTime? get _fertileStart =>
      DateTime.tryParse(_map('fertileWindow')?['start']?.toString() ?? '');
  DateTime? get _fertileEnd =>
      DateTime.tryParse(_map('fertileWindow')?['end']?.toString() ?? '');

  /// Whether today falls inside the window she shared. Null when she has not
  /// shared one -- not "false", which would read as "not fertile today".
  bool? get inFertileWindow {
    final start = _fertileStart;
    final end = _fertileEnd;
    if (start == null || end == null) return null;
    final now = DateTime.now();
    return !now.isBefore(start) && !now.isAfter(end.add(const Duration(days: 1)));
  }

  /// The next appointment she shared, as a plain date. Never a time she did
  /// not give.
  String? get nextAppointment {
    final raw = permitted['appointments'];
    if (raw is! List || raw.isEmpty) return null;
    for (final item in raw) {
      if (item is! Map) continue;
      final date = DateTime.tryParse(item['date']?.toString() ?? '');
      if (date == null) continue;
      if (date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) continue;
      final title = _text(item['title']) ?? 'Appointment';
      return '$title · ${_shortDate(date)}';
    }
    return null;
  }

  static String _shortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  /// Whether anything personal actually arrived.
  bool get sharingAnything =>
      phase != null ||
      mood != null ||
      energy != null ||
      sleepHours != null ||
      symptoms.isNotEmpty ||
      pregnancyWeek != null ||
      weeksSinceBirth != null ||
      inFertileWindow != null;

  /// For the first-period stage, which is one stage on the server but two in
  /// people's lives. Decided on evidence -- a cycle day only exists once there
  /// is a cycle -- rather than on a guess.
  bool get periodsStarted => cycleDay != null || phase != null;

  // -------------------------------------------------------------- greeting

  String get greetingEyebrow => switch (stage) {
        PartnerStage.firstPeriod => 'PARENTAL COMPANION',
        PartnerStage.cycleTracking => 'CYCLE HARMONY',
        PartnerStage.hormonalHealth => 'HORMONAL WELLNESS',
        PartnerStage.ttc => 'THE FERTILITY JOURNEY',
        PartnerStage.pregnancy => 'BABY ON BOARD',
        PartnerStage.postpartum => 'THE FOURTH TRIMESTER',
        PartnerStage.perimenopause => 'THE SHIFTING HORIZON',
        PartnerStage.menopause => 'THE SHIFTING HORIZON',
        PartnerStage.everydayWellness => 'SHARED HORIZONS',
        PartnerStage.unknown => 'SHARED HORIZONS',
      };

  /// "Supporting", "Growing with", "Guarding" -- the verb is the persona, and
  /// the persona is the one thing the stage settles on its own.
  String get greetingVerb => switch (stage) {
        PartnerStage.firstPeriod => 'Supporting',
        PartnerStage.cycleTracking => 'Connected with',
        PartnerStage.hormonalHealth => 'Standing by',
        PartnerStage.ttc => 'In this with',
        PartnerStage.pregnancy => 'Growing with',
        PartnerStage.postpartum => 'Guarding',
        PartnerStage.perimenopause => 'Standing beside',
        PartnerStage.menopause => 'Standing beside',
        PartnerStage.everydayWellness => 'Connected with',
        PartnerStage.unknown => 'Connected with',
      };

  /// The subtitle, assembled only from facts. An empty list means the line is
  /// left to the caller rather than padded out.
  List<String> get greetingFacts {
    final facts = <String>[];
    switch (stage) {
      case PartnerStage.pregnancy:
        if (pregnancyWeek != null) facts.add('Week $pregnancyWeek');
        if (trimester != null) facts.add('${_ordinal(trimester!)} trimester');
        if (daysToDue != null) facts.add('$daysToDue days to go');
      case PartnerStage.postpartum:
        if (weeksSinceBirth != null) {
          facts.add(weeksSinceBirth == 0
              ? 'First week'
              : 'Week ${weeksSinceBirth! + 1} after birth');
        }
        if (sleepLabel != null) facts.add('Slept $sleepLabel');
      case PartnerStage.ttc:
        if (inFertileWindow == true) facts.add('Fertile window open');
        if (cycleDay != null) facts.add('Day $cycleDay');
      case PartnerStage.firstPeriod:
        if (cycleDay != null) facts.add('Day $cycleDay');
        if (mood != null) facts.add('Feeling $mood');
      default:
        if (cycleDay != null) facts.add('Day $cycleDay');
        if (phase != null) facts.add(phase!);
        if (mood != null) facts.add('Feeling $mood');
    }
    return facts;
  }

  static String _ordinal(int n) => switch (n) {
        1 => 'First',
        2 => 'Second',
        3 => 'Third',
        _ => '$n',
      };

  /// Whether the stage says more about today than a cycle phase would.
  ///
  /// Being six days postpartum, or twenty-four weeks pregnant, is the fact
  /// worth leading with. Living with her cycle is not -- there the phase is
  /// the more specific thing, and [CycleHarmonyCard] already reads it.
  bool get stageLeads => switch (stage) {
        PartnerStage.firstPeriod ||
        PartnerStage.hormonalHealth ||
        PartnerStage.ttc ||
        PartnerStage.pregnancy ||
        PartnerStage.postpartum ||
        PartnerStage.perimenopause ||
        PartnerStage.menopause =>
          true,
        _ => false,
      };

  // ---------------------------------------------------------------- badges

  /// Four signals. The first three are what the stage cares about; the fourth
  /// is always the state of the sharing itself, so he can tell an empty screen
  /// from a quiet day.
  List<PartnerBadgeSpec> get badges {
    final sharing = PartnerBadgeSpec(
      icon: sharingAnything ? Icons.lock_open_rounded : Icons.lock_person_rounded,
      colour: _purple,
      tint: _purpleTint,
      label: sharingAnything ? 'SHARING' : 'PRIVATE',
      value: sharingAnything ? 'Active' : 'Paused',
    );

    final moodBadge = PartnerBadgeSpec(
      icon: Icons.favorite_rounded,
      colour: _magenta,
      tint: _magentaTint,
      label: 'MOOD',
      value: mood ?? 'Private',
    );

    final energyBadge = PartnerBadgeSpec(
      icon: Icons.bolt_rounded,
      colour: _teal,
      tint: _tealTint,
      label: 'ENERGY',
      value: energy ?? 'Not logged',
    );

    final sleepBadge = PartnerBadgeSpec(
      icon: Icons.bedtime_rounded,
      colour: _cobalt,
      tint: _cobaltTint,
      label: 'SLEEP',
      value: sleepLabel ?? 'Not logged',
    );

    final symptomBadge = PartnerBadgeSpec(
      icon: Icons.healing_rounded,
      colour: kPmCrimson,
      tint: _crimsonTint,
      label: 'LOGGED',
      value: symptoms.isEmpty ? 'Nothing' : symptoms.first,
    );

    final cycleBadge = PartnerBadgeSpec(
      icon: Icons.water_drop_rounded,
      colour: _cobalt,
      tint: _cobaltTint,
      label: cycleDay != null ? 'DAY $cycleDay' : 'CYCLE',
      value: phase ?? (cycleDay != null ? 'Shared' : 'Private'),
    );

    switch (stage) {
      case PartnerStage.pregnancy:
        return [
          PartnerBadgeSpec(
            icon: Icons.child_friendly_rounded,
            colour: _magenta,
            tint: _magentaTint,
            label: pregnancyWeek != null ? 'WEEK $pregnancyWeek' : 'PREGNANCY',
            value: trimester != null
                ? '${_ordinal(trimester!)} trimester'
                : (pregnancyWeek != null ? 'Shared' : 'Private'),
          ),
          PartnerBadgeSpec(
            icon: Icons.event_rounded,
            colour: _amber,
            tint: _amberTint,
            label: 'DUE',
            value: daysToDue != null ? 'In $daysToDue days' : 'Not shared',
          ),
          PartnerBadgeSpec(
            icon: Icons.medical_services_rounded,
            colour: _teal,
            tint: _tealTint,
            label: 'NEXT VISIT',
            value: nextAppointment == null
                ? 'Not shared'
                : nextAppointment!.split(' · ').last,
          ),
          sharing,
        ];

      case PartnerStage.postpartum:
        return [
          PartnerBadgeSpec(
            icon: Icons.nightlight_round,
            colour: kPmCrimson,
            tint: _crimsonTint,
            label: 'HER SLEEP',
            value: sleepLabel ?? 'Not logged',
          ),
          PartnerBadgeSpec(
            icon: Icons.healing_rounded,
            colour: _teal,
            tint: _tealTint,
            label: 'RECOVERY',
            value: weeksSinceBirth != null
                ? 'Week ${weeksSinceBirth! + 1}'
                : 'Not shared',
          ),
          moodBadge,
          sharing,
        ];

      case PartnerStage.ttc:
        return [
          PartnerBadgeSpec(
            icon: Icons.wb_sunny_rounded,
            colour: _amber,
            tint: _amberTint,
            label: 'WINDOW',
            value: switch (inFertileWindow) {
              true => 'Open now',
              false => 'Not today',
              null => 'Not shared',
            },
          ),
          cycleBadge,
          moodBadge,
          sharing,
        ];

      case PartnerStage.perimenopause:
      case PartnerStage.menopause:
        return [sleepBadge, symptomBadge, moodBadge, sharing];

      case PartnerStage.hormonalHealth:
        return [symptomBadge, energyBadge, moodBadge, sharing];

      case PartnerStage.firstPeriod:
        return [cycleBadge, moodBadge, symptomBadge, sharing];

      default:
        return [cycleBadge, energyBadge, moodBadge, sharing];
    }
  }

  /// The same four, as the widgets the signal row renders.
  List<PartnerSignalBadge> get signalBadges => [
        for (final badge in badges)
          PartnerSignalBadge(
            icon: badge.icon,
            colour: badge.colour,
            tint: badge.tint,
            label: badge.label,
            value: badge.value,
          ),
      ];

  // ------------------------------------------------------------- card one

  String get cardEyebrow => switch (stage) {
        PartnerStage.firstPeriod => 'BODY CONFIDENCE',
        PartnerStage.cycleTracking => 'HORMONAL HORIZON',
        PartnerStage.hormonalHealth => 'LIVING WITH A CONDITION',
        PartnerStage.ttc => 'THE TWO OF YOU',
        PartnerStage.pregnancy => 'HOW THIS WEEK MAY FEEL',
        PartnerStage.postpartum => 'RECOVERY, NOT ROUTINE',
        PartnerStage.perimenopause => 'A BODY IN TRANSITION',
        PartnerStage.menopause => 'A BODY IN TRANSITION',
        PartnerStage.everydayWellness => 'SHOWING UP',
        PartnerStage.unknown => 'SHOWING UP',
      };

  /// The headline states her situation only where the payload carries it, and
  /// otherwise describes the stage.
  String get cardHeadline {
    switch (stage) {
      case PartnerStage.firstPeriod:
        return periodsStarted
            ? 'Her cycle has started, and it is still new'
            : 'Her body is changing before her first period';
      case PartnerStage.cycleTracking:
        final p = phase;
        if (p == null) return 'Where she is in her cycle is hers to share';
        return cycleDay != null ? 'Day $cycleDay · $p' : p;
      case PartnerStage.hormonalHealth:
        return 'Symptoms that vary, on a schedule that does not';
      case PartnerStage.ttc:
        return inFertileWindow == true
            ? 'A window she is sharing with you'
            : 'Trying, together, over months rather than days';
      case PartnerStage.pregnancy:
        final week = pregnancyWeek;
        if (week == null) return 'Carrying a pregnancy, week by week';
        return trimester != null
            ? 'Week $week · ${_ordinal(trimester!).toLowerCase()} trimester'
            : 'Week $week';
      case PartnerStage.postpartum:
        final weeks = weeksSinceBirth;
        if (weeks == null) return 'Recovering from birth while caring for a newborn';
        return weeks == 0
            ? 'First week after birth'
            : 'Week ${weeks + 1} after birth';
      case PartnerStage.perimenopause:
        return 'Hormones that rise and fall without a pattern';
      case PartnerStage.menopause:
        return 'After the transition, a body still settling';
      default:
        return 'An ordinary week is still worth showing up for';
    }
  }

  /// General and true of the stage. Nothing here is a claim about her.
  String get cardBody => switch (stage) {
        PartnerStage.firstPeriod => periodsStarted
            ? 'Early cycles are often irregular, and cramps can be strong before they settle into a pattern. What helps most is that the subject is ordinary at home -- supplies where she can reach them without asking, and no fuss made when she needs a quiet day.'
            : 'Puberty brings growth, fatigue and mood shifts that arrive before anyone has explained them. She mostly needs to know that none of it is embarrassing here, and that she can ask a question without it becoming a conversation.',
        PartnerStage.cycleTracking =>
          'Hormones move across a cycle, and energy, sleep and appetite tend to move with them. A phase describes a tendency across many people rather than a fact about one -- so it is a good reason to ask her how she is, and a poor reason to assume.',
        PartnerStage.hormonalHealth =>
          'Conditions like PCOS, endometriosis and PMDD make symptoms heavier and less predictable than a textbook cycle. When a day is bad it is usually physiological rather than personal. Practical help and an unhurried presence land better than solutions.',
        PartnerStage.ttc =>
          'Trying to conceive turns something private into something scheduled, and that is the part that wears people down. Most of the support is in taking the pressure out of the day: shared decisions, no post-mortems, and the same warmth in a month that does not work.',
        PartnerStage.pregnancy =>
          'Pregnancy changes posture, sleep, digestion and temperature, and each trimester brings a different set of them. The useful help is physical and unasked: lifting, bending, driving, and taking over the small tasks that have quietly become difficult.',
        PartnerStage.postpartum =>
          'Recovery from birth takes months, and it runs at the same time as the least sleep she will ever get. Protecting unbroken sleep, food and water is the whole job. If her mood is low or frightening for more than two weeks, that is worth a doctor, not a wait.',
        PartnerStage.perimenopause =>
          'Oestrogen fluctuates rather than simply declining, which is why sleep, temperature and mood can change week to week. A cool room, an unhurried evening, and not treating a hard day as a personality shift all help more than they sound like they would.',
        PartnerStage.menopause =>
          'After twelve months without a period the fluctuations settle, but sleep, temperature and joints often take longer. Steadiness helps: routine, warmth in how you speak to her, and treating this as a stage of life rather than a problem to manage.',
        PartnerStage.everydayWellness =>
          'No stage-specific pattern to read today. Which makes the ordinary things -- asking properly, listening, taking one thing off her plate -- the whole of it.',
        PartnerStage.unknown =>
          'She has not shared a stage, so there is nothing here to interpret. Everything general still applies: ask, listen, and take something off her plate.',
      };

  /// One line of what she actually logged, or null. Never padded.
  String? get liveNote {
    final parts = <String>[];
    // Lower-cased here only: "Happy" is right on a badge and wrong in the
    // middle of a sentence.
    if (mood != null) parts.add('logged feeling ${mood!.toLowerCase()}');
    if (sleepLabel != null && stage == PartnerStage.postpartum) {
      parts.add('slept $sleepLabel');
    }
    if (symptoms.isNotEmpty) {
      parts.add('noted ${symptoms.take(2).join(' and ')}');
    }
    if (parts.isEmpty) return null;
    return '$partnerName ${parts.join(', ')}.';
  }

  // ----------------------------------------------------------- card three

  String get docsyPlaceholder => switch (stage) {
        PartnerStage.firstPeriod => 'Ask Docsy how to talk to her about this...',
        PartnerStage.pregnancy => 'Ask Docsy about this week of the pregnancy...',
        PartnerStage.postpartum => 'Ask Docsy how to help in these first weeks...',
        PartnerStage.ttc => 'Ask Docsy how to carry this together...',
        PartnerStage.hormonalHealth => 'Ask Docsy about her condition...',
        PartnerStage.perimenopause => 'Ask Docsy about the transition...',
        PartnerStage.menopause => 'Ask Docsy about the transition...',
        _ => 'Ask Docsy how to show up today...',
      };

  /// Openings rather than answers, and the same set the Docsy tab offers for
  /// this stage, so the two surfaces cannot drift apart.
  List<String> get docsyChips => partnerStageQuestions(stage) ?? const [
        'How do I ask how she is doing without prying?',
        'What is practical support, and what is emotional support?',
        'How do I show up on a hard day?',
      ];
}

/// Three questions worth asking in a given stage, or null where the cycle
/// phase answers it better.
///
/// Shared by Partner Home and the Docsy tab. It lives here rather than in
/// either screen so that adding a stage cannot update one and miss the other.
List<String>? partnerStageQuestions(PartnerStage stage) => switch (stage) {
      PartnerStage.pregnancy => const [
          'What might be hardest for her this week?',
          'What food is worth having in the house?',
          'How do I help her rest without fussing?',
        ],
      PartnerStage.postpartum => const [
          'What does she need most in these first weeks?',
          'How do I help at night without waking her more?',
          'What should I say when she is crying and I do not know why?',
        ],
      PartnerStage.ttc => const [
          'How do I keep this from feeling clinical?',
          'What do I say after a month that did not work?',
          'How do I carry some of this with her?',
        ],
      PartnerStage.perimenopause || PartnerStage.menopause => const [
          'What is changing for her that I may not see?',
          'How do I help with sleep and heat at night?',
          'What is worth not taking personally?',
        ],
      PartnerStage.firstPeriod => const [
          'How do I talk about this without embarrassing her?',
          'What should I have ready at home?',
          'What is normal to expect right now?',
        ],
      // cycleTracking and hormonalHealth fall through to the phase-keyed set,
      // which answers the same question with more to go on.
      _ => null,
    };

/// Her tracker, as he may see it: read-only, and only where she shares it.
///
/// There is no date picker, no "log period" button and no symptom control on
/// this card, because there is no version of this screen where he should be
/// writing to her cycle. That is enforced by what is passed, not by hiding a
/// button: [CycleRingCard] draws its log-period and set-up affordances only
/// when it is given the callbacks, and it is given none.
///
/// Which dial it draws follows the stage, but only as far as the data goes.
/// A pregnancy has a week out of forty; a recovery has a week out of six; a
/// cycle has a day out of a length she may or may not have shared. Menopause
/// has no dial here: "seven months without a period" is not a figure this
/// payload carries, and a dial is a poor place to start guessing.
class PartnerCycleTracker extends StatelessWidget {
  const PartnerCycleTracker({super.key, required this.today});

  final PartnerStageToday today;

  /// Whether anything real can be drawn. Nothing shared means no card at all,
  /// rather than an empty dial.
  bool get _hasDial =>
      today.pregnancyWeek != null ||
      today.weeksSinceBirth != null ||
      today.cycleDay != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasDial) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPmCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _eyebrow,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: kPmCrimson,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const _ReadOnlyPill(),
            ],
          ),
          const SizedBox(height: 12),
          _dial(),
          const SizedBox(height: 10),
          Text(
            'Only ${today.partnerName} can log or change any of this.',
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: kPmMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String get _eyebrow {
    if (today.pregnancyWeek != null) return 'PREGNANCY PROGRESS';
    if (today.weeksSinceBirth != null) return 'RECOVERY PROGRESS';
    return 'HER CYCLE';
  }

  Widget _dial() {
    final week = today.pregnancyWeek;
    if (week != null) {
      // Forty weeks is the convention a due date is set by, and her due date
      // came from the payload -- so the fraction is hers, not a default.
      return _ArcRow(
        progress: (week / 40).clamp(0.0, 1.0),
        headline: 'Week $week of 40',
        detail: today.daysToDue != null
            ? '${today.daysToDue} days to her due date'
            : 'Due date not shared',
        colour: _magenta,
      );
    }

    final weeks = today.weeksSinceBirth;
    if (weeks != null) {
      // Six weeks is the usual postnatal check, not the end of recovery --
      // which is why the detail line says so rather than implying a finish.
      return _ArcRow(
        progress: (weeks / 6).clamp(0.0, 1.0),
        headline: weeks == 0 ? 'First week' : 'Week ${weeks + 1} after birth',
        detail: weeks >= 6
            ? 'Past the six-week check. Recovery keeps going.'
            : 'Six-week check at week 6. Recovery keeps going after it.',
        colour: _teal,
      );
    }

    return CycleRingCard(
      state: CycleCardState.ready,
      phase: CyclePhaseKindLook.parse(today.phase),
      cycleDay: today.cycleDay,
      cycleLength: today.cycleLength,
      // Her period length where she shares it; the card's own default
      // otherwise, rather than a second guess made here.
      periodLength: today.periodLength ?? 5,
      // Her cycle, her app. Every write affordance the ring can draw is
      // driven by one of these, so leaving them null is what makes this
      // read-only -- not a flag somewhere that could be flipped.
      onCalendar: null,
      onSetUp: null,
      onInsights: null,
      showNextCycleCountdown: today.cycleLength != null,
      caveat: today.cycleLength == null
          ? 'She has not shared when her next period is due, so there is no countdown here.'
          : null,
    );
  }
}

/// Says what the card is, so he is not left wondering whether tapping
/// something would change her records.
class _ReadOnlyPill extends StatelessWidget {
  const _ReadOnlyPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPmCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, size: 11, color: kPmMuted),
          const SizedBox(width: 4),
          Text(
            'Read only',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: kPmMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A straight progress track for the stages that run once rather than round.
///
/// Deliberately not a ring: a pregnancy does not come back to where it
/// started, and drawing it as a circle would say it did.
class _ArcRow extends StatelessWidget {
  const _ArcRow({
    required this.progress,
    required this.headline,
    required this.detail,
    required this.colour,
  });

  final double progress;
  final String headline;
  final String detail;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: kPmCharcoal,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: kPmHairline,
            valueColor: AlwaysStoppedAnimation<Color>(colour),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: kPmMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Three questions worth asking in a given cycle phase.
///
/// Matched by substring, not equality, and that is the whole point: the phase
/// arrives as "Luteal phase" from one endpoint and "Menstrual Phase (Day 2 of
/// 5)" from the other, while the switch this replaces compared against
/// "luteal" and "menstrual". It matched neither, so every phase quietly fell
/// through to the general set and the pills never changed. Same family of bug
/// as the two life-stage spellings.
///
/// Never null: an unknown or unshared phase gets the general set, which claims
/// nothing about her.
List<String> partnerPhaseQuestions(String? phase) {
  final v = (phase ?? '').toLowerCase();

  if (v.contains('menstr') || v.contains('period')) {
    return const [
      'What helps most on a heavy day?',
      'Should I plan something, or keep today quiet?',
      'What can I take off her plate tonight?',
    ];
  }
  if (v.contains('ovulat') || v.contains('fertile')) {
    return const [
      'How do I make time together feel easy this week?',
      'What should I not read too much into?',
      'What is a good way to connect today?',
    ];
  }
  if (v.contains('follic')) {
    return const [
      'Is this a good week to plan something together?',
      'How do I match her energy without pushing?',
      'What is worth asking her about right now?',
    ];
  }
  if (v.contains('luteal')) {
    return const [
      'How do I help without hovering?',
      'What do I do if she snaps at me?',
      'What is worth letting go of today?',
    ];
  }

  // Nothing shared, or a phase this does not know -- including "Late" and
  // "Safe phase", where a confident question would be the wrong thing.
  return const [
    'How do I ask how she is doing without prying?',
    'What is practical support, and what is emotional support?',
    'How do I show up on a hard day?',
  ];
}

/// Card 01 -- what today is like for her, in this stage.
class PartnerStageCard extends StatelessWidget {
  const PartnerStageCard({super.key, required this.today});

  final PartnerStageToday today;

  @override
  Widget build(BuildContext context) {
    final note = today.liveNote;
    final appointment = today.nextAppointment;
    final milestone = today.stage == PartnerStage.pregnancy
        ? today.pregnancyMilestone
        : (today.stage == PartnerStage.postpartum
            ? today.postpartumMilestone
            : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPmCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            today.cardEyebrow,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: kPmCrimson,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            today.cardHeadline,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: kPmCharcoal,
              height: 1.2,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            today.cardBody,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: kPmMuted,
              height: 1.55,
            ),
          ),
          if (milestone != null) ...[
            const SizedBox(height: 14),
            _pill(Icons.flag_rounded, milestone),
          ],
          if (note != null) ...[
            const SizedBox(height: 10),
            _pill(Icons.edit_note_rounded, note),
          ],
          if (appointment != null) ...[
            const SizedBox(height: 10),
            _pill(Icons.event_rounded, appointment),
          ],
        ],
      ),
    );
  }

  /// A fact she shared, marked as such. Only ever built from a real value.
  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kPmHairline,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: kPmCrimson),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kPmCharcoal,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card 03 -- a way into Docsy with the stage already in mind.
///
/// The bar does not answer anything itself. Tapping it opens the Docsy tab,
/// which is where her permitted context and the safety ruleset live; a second
/// answering surface would be a second place for them to be missed.
class PartnerDocsyPrompt extends StatelessWidget {
  const PartnerDocsyPrompt({
    super.key,
    required this.today,
    required this.onAsk,
  });

  final PartnerStageToday today;

  /// Null opens Docsy with nothing prefilled.
  final void Function(String? question) onAsk;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPmCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ASK DOCSY',
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: kPmCrimson,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => onAsk(null),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: kPmHairline,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kPmCardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      today.docsyPlaceholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        color: kPmMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: kPmCrimson,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final question in today.docsyChips)
                InkWell(
                  onTap: () => onAsk(question),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kPmCardBorder),
                    ),
                    child: Text(
                      question,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: kPmCharcoal,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
