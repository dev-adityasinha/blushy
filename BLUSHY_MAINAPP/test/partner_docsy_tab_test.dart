import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/features/partner/presentation/partner_stage_today.dart';

/// Partner Docsy: its own tab, and its own context.
///
/// Two failures sat here. The screen posted to `/ai/chat` with
/// `context: 'partner_support'` and nothing else -- no cycle, no stage, no
/// mood -- so the "relationship coach" was a general chatbot that happened to
/// live in his app, while `/ai/relationship-advice/:connectionId`, which does
/// gather her permitted context and run the safety ruleset, went unused.
///
/// And when the network stumbled it fell back to copy written for a girl going
/// through puberty: "use a pad from your pouch or visit your school nurse",
/// "your body blossoming". Served to her partner.
///
/// These read the source. What is being pinned is which endpoint is called and
/// which words can no longer appear -- both claims about the code.

late final String _sia;
late final String _shell;
late final String _stageToday;

/// The source with its comments removed.
///
/// These files explain what was taken out of them, so a naive search
/// finds the very strings the tests are asserting are gone.
String _codeOf(String source) => source
    .split(String.fromCharCode(10))
    .where((line) => !line.trimLeft().startsWith('//'))
    .join(' ');

/// The body of `partnerStageQuestions`, which is the only part of the file
/// these assertions are about.
String _questionsBody() {
  final start = _stageToday.indexOf('List<String>? partnerStageQuestions(');
  expect(start, greaterThan(-1));
  final end = _stageToday.indexOf('};', start);
  expect(end, greaterThan(start));
  return _stageToday.substring(start, end);
}

void main() {
  setUpAll(() {
    _sia = File('lib/features/partner/presentation/partner_sia.dart')
        .readAsStringSync();
    _shell = File('lib/features/home/presentation/partner_shell.dart')
        .readAsStringSync();
    // The stage pills moved here: Partner Home offers the same three, and two
    // copies is how a stage gets added to one surface and missed on the other.
    _stageToday =
        File('lib/features/partner/presentation/partner_stage_today.dart')
            .readAsStringSync();
  });

  test('it asks the coach endpoint, not the general chat one', () {
    expect(_sia, contains('askRelationshipAi'));
    expect(
      _sia.contains("'/ai/chat'"),
      isFalse,
      reason: 'the general endpoint carries none of her context',
    );
    expect(
      _sia.contains("'context': 'partner_support'"),
      isFalse,
      reason: 'that string was the whole of what it used to send',
    );
  });

  test('the answer is grounded in her permitted context, not in guesses', () {
    // The server decides what he may see, from her switches. The screen only
    // reports what came back.
    expect(_sia, contains('usedPartnerData'));
    expect(_sia, contains('aiSuggestionsEnabled'));
  });

  test('the puberty fallbacks are gone', () {
    // Every one of these was being shown to a grown man asking how to support
    // his partner. Comments are stripped first: the file explains what was
    // removed, and quoting it there is the point rather than a relapse.
    final code = _sia
        .split(String.fromCharCode(10))
        .where((line) => !line.trimLeft().startsWith('//'))
        .join(' ');

    for (final wrong in [
      'school nurse',
      'your pouch',
      'blossoming',
      'before your first period arrives',
      'tie a sweater around your waist',
    ]) {
      expect(code.contains(wrong), isFalse, reason: wrong);
    }
  });

  test('a failure says so rather than inventing an answer', () {
    expect(_sia, contains('I could not reach Docsy just now'));
  });

  test('the banner has a state for her having switched him off', () {
    // Not an error, and not silence: she turned partner suggestions off, and
    // he is told that plainly.
    expect(_sia, contains('partner suggestions switched off'));
    expect(_sia, contains('Nothing personal is being shared right now'));
    expect(_sia, contains('Grounded in what she is sharing with you today'));
  });

  test('the banner never names a symptom or a number', () {
    // What is shared belongs in the answer, not in a badge above it.
    final start = _sia.indexOf('Widget _contextBanner()');
    expect(start, greaterThan(-1));
    final banner = _sia.substring(start, start + 1600);
    for (final leak in ['Day ', 'Luteal', 'Follicular', 'cramps', 'mood:']) {
      expect(banner.contains(leak), isFalse, reason: leak);
    }
  });

  test('Docsy is a tab in the partner shell', () {
    expect(_shell, contains("'Docsy'"));
    expect(_shell, contains('PartnerSiaScreen()'));

    // Four destinations now that Community has been removed from the bar; the
    // Community screen file is untouched, just no longer a tab here.
    final labels = RegExp(r"_labels = <String>\[(.*?)\];", dotAll: true)
        .firstMatch(_shell)
        ?.group(1);
    expect(labels, isNotNull);
    final names = RegExp(r"'([^']+)'")
        .allMatches(labels!)
        .map((m) => m[1]!)
        .toList();
    expect(names, ['Home', 'Docsy', 'Learn', 'Partner']);
  });

  test('the screens and the labels cannot drift apart', () {
    // The header reads the label by index; a list one longer than the other
    // would name every tab as its neighbour.
    final screens = RegExp(r"_screens = \[(.*?)\];", dotAll: true)
        .firstMatch(_shell)
        ?.group(1);
    expect(screens, isNotNull);
    final count = RegExp(r'const \w+\(\)').allMatches(screens!).length;
    expect(count, 4);
  });

  test('the question pills follow her phase, not his profile', () {
    // They used to read `user_profile.json`, which on a partner account is
    // *his* -- so the "stage-aware" question was keyed on the stage 'partner'.
    expect(_sia, contains('_suggestions'));
    expect(
      _sia.contains("BlushyStorage.read('user_profile.json')"),
      isFalse,
      reason: 'his own profile says nothing about where she is',
    );

    // Each phase gets its own three, and no two phases share a set.
    final sets = <String, List<String>>{
      for (final phase in ['Period phase', 'Follicular phase', 'Ovulation phase', 'Luteal phase'])
        phase: partnerPhaseQuestions(phase),
    };
    expect(sets.values.map((s) => s.join('|')).toSet().length, 4,
        reason: 'two phases are offering the same questions');
  });

  test('the phase pills match the phase the server actually sends', () {
    // The switch this replaced compared against 'luteal' and 'menstrual'.
    // One endpoint sends "Luteal phase", the other "Menstrual Phase (Day 2 of
    // 5)" -- so it matched neither, every phase fell through to the general
    // set, and the pills silently never changed. Substring matching, the way
    // CyclePhaseKindLook.parse already does it.
    expect(_sia, contains('partnerPhaseQuestions(_phase)'));

    final body = _stageToday.substring(
      _stageToday.indexOf('List<String> partnerPhaseQuestions('),
      _stageToday.indexOf('${String.fromCharCode(10)}}',
          _stageToday.indexOf('List<String> partnerPhaseQuestions(')),
    );
    for (final token in ['menstr', 'period', 'ovulat', 'fertile', 'follic', 'luteal']) {
      expect(body.contains("contains('$token')"), isTrue, reason: token);
    }
    expect(body.contains("case 'luteal'"), isFalse,
        reason: 'equality here is what stopped it matching at all');
  });

  test('every phase the two endpoints can send resolves to its own set', () {
    // Exactly the strings buildCycleInfo and periodPredictionService produce.
    const fromServer = [
      'Period phase', 'Follicular phase', 'Ovulation phase', 'Luteal phase',
      'Menstrual Phase (Day 2 of 5)', 'Estimated Ovulation Day',
      'Approximate Fertile Window', 'Follicular Phase', 'Luteal Phase',
    ];
    final general = partnerPhaseQuestions(null);
    for (final phase in fromServer) {
      expect(partnerPhaseQuestions(phase), isNot(general), reason: phase);
    }

    // And the ones that genuinely have no set stay general rather than
    // guessing.
    for (final phase in ['Safe phase', 'Late / Overdue Cycle (+3 days)', null]) {
      expect(partnerPhaseQuestions(phase), general, reason: '$phase');
    }
  });

  test('the pills are openings, not answers about her', () {
    // "What helps most on a heavy day?" leaves room for her to differ from
    // the chart. "She needs a heat pack" does not.
    final questions = <String>[
      for (final phase in [
        'Period phase', 'Follicular phase', 'Ovulation phase', 'Luteal phase', null,
      ])
        ...partnerPhaseQuestions(phase),
    ];
    expect(questions.length, greaterThanOrEqualTo(15),
        reason: 'three per phase, plus the general set');

    for (final q in questions) {
      expect(q.endsWith('?'), isTrue, reason: 'not a question: $q');
      for (final claim in ['She is', 'She needs', 'Her hormones', 'because']) {
        expect(q.contains(claim), isFalse, reason: '$q says "$claim"');
      }
    }
  });

  test('with no phase shared the pills claim nothing about her', () {
    final general = partnerPhaseQuestions(null);
    expect(general.join(' '), contains('without prying'));
    // The general set names nothing about her -- no day, no phase, no mood.
    for (final leak in ['Day ', 'phase', 'cycle', 'mood']) {
      expect(general.join(' ').contains(leak), isFalse, reason: leak);
    }
  });

  test('her stage is preferred over her phase, where she shares it', () {
    // Being pregnant, or six days postpartum, says more about what he should
    // ask than which week of a cycle it is.
    expect(_sia, contains('_stageSuggestions'));
    expect(_sia, contains("shared['lifeStage']"));
    expect(_sia, contains('partnerStageQuestions'),
        reason: 'one set of questions, shared with Partner Home');

    for (final stage in [
      'PartnerStage.pregnancy',
      'PartnerStage.postpartum',
      'PartnerStage.ttc',
      'PartnerStage.perimenopause',
      'PartnerStage.menopause',
      'PartnerStage.firstPeriod',
    ]) {
      expect(_stageToday, contains(stage), reason: stage);
    }
  });

  test('the pills match on the stage the server actually sends', () {
    // This is the bug the first version shipped with. The server normalises
    // every stage to snake_case -- `ttc`, `first_period` -- and the switch was
    // written against the client's camelCase spellings, so those two stages
    // matched nothing and silently fell through to the general questions.
    //
    // Matching now goes through one enum, which accepts either spelling.
    expect(_sia, contains('PartnerStage.from(_stage)'));
    expect(
      _stageToday.contains("case 'tryingToConceive'"),
      isFalse,
      reason: 'a raw string here is a spelling the server never sends',
    );
  });

  test('the cycle stages fall through to the phase rather than duplicating it',
      () {
    // livingWithMyCycle and hormonalHealth have no stage set of their own:
    // the phase already answers the question better.
    // Scoped to the question set: both stages appear elsewhere in the file,
    // where they do have their own card wording. It is the *questions* the
    // phase answers better.
    final body = _questionsBody();
    expect(body.contains('PartnerStage.cycleTracking'), isFalse);
    expect(body.contains('PartnerStage.hormonalHealth'), isFalse,
        reason: 'inside partnerStageQuestions they fall to the null default');
    expect(body, contains('_ => null'));
  });

  test('every stage pill is an opening too', () {
    final lines = _stageToday.split(String.fromCharCode(10));
    final from =
        lines.indexWhere((l) => l.contains('partnerStageQuestions(PartnerStage'));
    expect(from, greaterThan(-1));
    final to = lines.indexWhere((l) => l.trim() == '};', from);

    var found = 0;
    for (final line in lines.sublist(from, to)) {
      final trimmed = line.trim();
      if (trimmed.startsWith("'") && trimmed.endsWith("',")) {
        final q = trimmed.substring(1, trimmed.length - 2);
        found++;
        expect(q.endsWith('?'), isTrue, reason: 'not a question: $q');
        for (final claim in ['She is', 'She needs', 'Her hormones']) {
          expect(q.contains(claim), isFalse, reason: '$q says "$claim"');
        }
      }
    }
    expect(found, greaterThanOrEqualTo(15), reason: 'three per stage set');
  });
}
