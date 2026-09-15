import 'package:flutter/widgets.dart';

/// One card or section of a stage home, with what it is about.
///
/// The tag is a plain word -- `careplan`, `baby`, `learn` -- that the
/// onboarding picks are matched against. A pinned section keeps its place:
/// the hero at the top of every home and today's check-in stay where they
/// are whatever was picked.
class HomeSection {
  const HomeSection(this.tag, this.child, {this.pinned = false});

  final String tag;
  final Widget child;
  final bool pinned;
}

/// Orders a stage home's sections by what she asked for at onboarding.
///
/// Every stage's wizard ends with "what would you like help with" and
/// "which of these do you notice". Those answers were stored and never
/// read back: the home rendered its sections in one fixed order for
/// everyone. Now a section about something she picked moves up, in the
/// order she picked things, and the rest keep their original order below.
/// Pinned sections do not move.
class HomeSectionOrder {
  const HomeSectionOrder._();

  /// What each onboarding pick is about, as section tags. The key is
  /// matched case-insensitively against the pick's text, as a substring,
  /// so "Reduce cramps" and "Cramps" both find `cramps`.
  static const Map<String, List<String>> _pickTags = {
    // Cycle and fertility
    'predict period': ['cycle', 'timeline'],
    'tracking period': ['cycle', 'timeline'],
    'track cycle': ['cycle', 'timeline'],
    'ovulation': ['cycle', 'timeline'],
    'fertility': ['timeline', 'cycle'],
    'irregular': ['cycle', 'patterns'],
    'regular period': ['cycle', 'patterns'],
    'heavy period': ['patterns', 'checkin'],
    'spotting': ['patterns', 'checkin'],
    // Symptoms and pain
    'cramp': ['patterns', 'checkin'],
    'pms': ['patterns', 'insights'],
    'symptom': ['checkin', 'patterns'],
    'pain': ['patterns', 'careplan'],
    'bloating': ['patterns'],
    'headache': ['patterns'],
    'acne': ['patterns', 'learn'],
    'hair': ['patterns', 'learn'],
    'digestion': ['patterns'],
    'swelling': ['checkin', 'careplan'],
    'hot flash': ['patterns', 'careplan'],
    'night sweat': ['patterns', 'careplan'],
    'brain fog': ['patterns', 'learn'],
    'memory': ['patterns', 'learn'],
    'joint': ['careplan', 'patterns'],
    'weight': ['careplan', 'habits'],
    // Mood and mind
    'mood': ['reflection', 'insights'],
    'anxiety': ['reflection', 'insights'],
    'mental': ['reflection', 'insights'],
    'stress': ['reflection', 'habits'],
    // Rest and energy
    'sleep': ['habits', 'wellbeing', 'insights'],
    'insomnia': ['habits', 'wellbeing'],
    'energy': ['habits', 'wellbeing', 'insights'],
    'fatigue': ['habits', 'wellbeing'],
    // Body and habits
    'fitness': ['careplan', 'habits', 'plan'],
    'exercise': ['careplan', 'habits', 'plan'],
    'walking': ['careplan', 'habits', 'plan'],
    'yoga': ['careplan', 'habits', 'plan'],
    'strength': ['careplan', 'habits', 'plan'],
    'nutrition': ['careplan', 'habits', 'plan'],
    'hydration': ['habits', 'careplan'],
    'medication': ['careplan', 'appointments'],
    'appointment': ['appointments', 'careplan'],
    'doctor': ['appointments', 'careplan'],
    'reminder': ['appointments', 'careplan'],
    'heart': ['careplan', 'learn'],
    'bone': ['careplan', 'learn'],
    'ageing': ['careplan', 'learn'],
    'aging': ['careplan', 'learn'],
    // Baby
    'baby': ['baby', 'timeline'],
    'fetal': ['baby', 'checkin'],
    'contraction': ['baby', 'checkin'],
    'feeding': ['baby', 'careplan'],
    'pumping': ['baby', 'careplan'],
    'milestone': ['baby', 'timeline'],
    // Recovery
    'recovery': ['timeline', 'careplan'],
    'healing': ['timeline', 'careplan'],
    'pelvic': ['careplan', 'timeline'],
    'incision': ['timeline', 'careplan'],
    'bleeding': ['checkin', 'timeline'],
    // Understanding
    'understanding': ['learn'],
    'hygiene': ['learn'],
    'puberty': ['learn'],
    'school': ['learn', 'partner'],
    'body changes': ['learn'],
    'preparing': ['learn', 'prep'],
    'education': ['learn'],
    // People
    'partner': ['partner'],
    'support': ['partner', 'careplan'],
  };

  /// The tags a list of picks asks for, most wanted first.
  static List<String> tagsFor(Iterable<String> picks) {
    final out = <String>[];
    for (final pick in picks) {
      final p = pick.toLowerCase();
      for (final entry in _pickTags.entries) {
        if (p.contains(entry.key)) {
          for (final t in entry.value) {
            if (!out.contains(t)) out.add(t);
          }
        }
      }
    }
    return out;
  }

  /// The sections in the order she asked for.
  ///
  /// [goals] rank first (what she wants help with), then [symptoms] (what
  /// she notices); a section's rank is the first tag of hers it carries.
  /// Unmatched sections follow in their original order, and pinned ones
  /// never move from their index.
  static List<HomeSection> order(
    List<HomeSection> sections, {
    Iterable<String> goals = const [],
    Iterable<String> symptoms = const [],
  }) {
    final wanted = tagsFor([...goals, ...symptoms]);
    if (wanted.isEmpty) return sections;

    final movable = <MapEntry<int, HomeSection>>[];
    for (var i = 0; i < sections.length; i++) {
      if (!sections[i].pinned) movable.add(MapEntry(i, sections[i]));
    }
    int rank(HomeSection s) {
      final r = wanted.indexOf(s.tag);
      return r == -1 ? wanted.length : r;
    }
    final sorted = List<MapEntry<int, HomeSection>>.from(movable)
      ..sort((a, b) {
        final byRank = rank(a.value).compareTo(rank(b.value));
        return byRank != 0 ? byRank : a.key.compareTo(b.key);
      });

    // Pinned sections keep their slots; the sorted movable ones fill the
    // others in order.
    final out = List<HomeSection?>.filled(sections.length, null);
    for (var i = 0; i < sections.length; i++) {
      if (sections[i].pinned) out[i] = sections[i];
    }
    var next = 0;
    for (var i = 0; i < sections.length; i++) {
      if (out[i] == null) out[i] = sorted[next++].value;
    }
    return out.cast<HomeSection>();
  }

  /// [order], laid out with [gap] between sections, for a ListView.
  static List<Widget> layout(
    List<HomeSection> sections, {
    required Widget gap,
    Iterable<String> goals = const [],
    Iterable<String> symptoms = const [],
  }) {
    final ordered = order(sections, goals: goals, symptoms: symptoms);
    final out = <Widget>[];
    for (var i = 0; i < ordered.length; i++) {
      if (i > 0) out.add(gap);
      out.add(ordered[i].child);
    }
    return out;
  }
}
