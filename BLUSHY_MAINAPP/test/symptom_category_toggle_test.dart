import 'package:blushy_life_app/features/home/checkin_event_mapper.dart';
import 'package:blushy_life_app/features/home/checkin_vocabulary.dart';
import 'package:blushy_life_app/features/home/symptom_categories.dart';
import 'package:blushy_life_app/features/home/symptom_category_preference.dart';
import 'package:blushy_life_app/features/home/widgets/symptom_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// The symptom groups: which stage sees which, and switching one off.
///
/// The sheet used to be one "Symptoms" heading with everything under it, shown
/// identically to everyone. That offered a pregnancy user an ovulation test
/// and a menopause user a menstrual flow selector.
void main() {
  useIsolatedStorage();

  Set<String>? saved;
  setUp(() {
    SymptomCategoryPreference.disabled.value = <String>{};
    saved = null;
  });

  Widget host({Set<String> initial = const {}, String? stage}) => MaterialApp(
        home: Scaffold(
          body: SymptomLogSheet(
            initialSelection: initial,
            onSave: (s) => saved = s,
            stage: stage,
          ),
        ),
      );

  group('stage gating', () {
    test('a cycle-tracking user gets the cycle groups', () {
      final ids = SymptomCategories.forStage('livingWithMyCycle')
          .map((c) => c.id)
          .toList();
      expect(ids, contains('flow'));
      expect(ids, contains('discharge'));
      expect(ids, contains('symptom'));
    });

    test('pregnancy is not offered flow, ovulation or pregnancy tests', () {
      final ids =
          SymptomCategories.forStage('pregnancy').map((c) => c.id).toSet();
      // Flow is withheld because postpartum bleeding and pregnancy bleeding
      // are handled by their own cards and reviewed rules.
      expect(ids, isNot(contains('flow')));
      expect(ids, isNot(contains('ovulation_test')));
      expect(ids, isNot(contains('pregnancy_test')));
      // But symptoms and digestion still matter.
      expect(ids, contains('symptom'));
      expect(ids, contains('digestion'));
    });

    test('menopause is not offered flow or either test', () {
      final ids =
          SymptomCategories.forStage('menopause').map((c) => c.id).toSet();
      expect(ids, isNot(contains('flow')));
      expect(ids, isNot(contains('ovulation_test')));
      expect(ids, isNot(contains('pregnancy_test')));
    });

    test('only fertility stages get the ovulation test', () {
      for (final stage in ['livingWithMyCycle', 'hormonalHealth', 'ttc']) {
        expect(
          SymptomCategories.forStage(stage).map((c) => c.id),
          contains('ovulation_test'),
          reason: '$stage tracks ovulation',
        );
      }
      for (final stage in ['pregnancy', 'postpartum', 'menopause']) {
        expect(
          SymptomCategories.forStage(stage).map((c) => c.id),
          isNot(contains('ovulation_test')),
          reason: '$stage does not',
        );
      }
    });

    test('the pre-menarche and first-period stages are not offered sex', () {
      // A safeguarding decision, not a relevance one: these are the stages a
      // child or young teenager is in.
      for (final stage in ['firstPeriodNotStarted', 'firstPeriodStarted']) {
        final ids = SymptomCategories.forStage(stage).map((c) => c.id).toSet();
        expect(ids, isNot(contains('sex')), reason: '$stage must not be asked');
        expect(ids, isNot(contains('pregnancy_test')));
      }
      expect(SymptomCategories.forStage('livingWithMyCycle').map((c) => c.id),
          contains('sex'));
    });

    test('an unrecognised stage falls back to everyday wellness', () {
      expect(SymptomCategories.normalise('somethingNew'),
          SymptomCategories.wellness);
      expect(SymptomCategories.forStage(null), isNotEmpty);
    });

    test('the stage aliases the dashboard accepts resolve the same way', () {
      expect(SymptomCategories.normalise('reproductive_years'),
          SymptomCategories.cycle);
      expect(SymptomCategories.normalise('TTC'), SymptomCategories.ttc);
      expect(SymptomCategories.normalise('pcos'), SymptomCategories.hormonal);
      expect(SymptomCategories.normalise('postmenopause'),
          SymptomCategories.menopause);
    });

    test('every stage is offered something', () {
      for (final stage in SymptomCategories.everyStage) {
        expect(SymptomCategories.forStage(stage), isNotEmpty,
            reason: '$stage would open an empty sheet');
      }
    });
  });

  group('every option records somewhere', () {
    test('each metric a category writes is in the registry', () {
      // A numeric category records a reading rather than a word, so it has no
      // vocabulary to register.
      final numericMetrics = {
        for (final c in SymptomCategories.all)
          if (c.isNumeric) c.metric,
      };
      for (final metric in SymptomCategories.metrics) {
        if (numericMetrics.contains(metric)) continue;
        expect(CheckinVocabulary.byMetric.containsKey(metric), isTrue,
            reason: '$metric is not a known metric');
      }
    });

    test('a numeric category offers no words to tap', () {
      for (final category in SymptomCategories.all) {
        if (!category.isNumeric) continue;
        expect(category.options, isEmpty,
            reason: '${category.id} is a reading, not a choice');
      }
    });

    test('each option maps to an event under its own metric', () {
      // An option that maps to nothing is an answer thrown away.
      for (final category in SymptomCategories.all) {
        if (category.isNumeric) continue;
        for (final option in category.options) {
          final metric = category.metricFor(option);
          if (CheckinVocabulary.isUnrecorded(metric, option)) continue;
          expect(CheckinEventMapper.map(metric, option), isNotNull,
              reason: '${category.id} "$option" under $metric does not map');
        }
      }
    });

    test('the discharge group splits mucus from symptoms', () {
      final discharge = SymptomCategories.byId('discharge')!;
      // A mucus observation is a fertility reading.
      expect(CheckinEventMapper.map(discharge.metricFor('Eggwhite'), 'Eggwhite')!
          .eventType, 'cervical_mucus_logged');
      // "Unusual" is not, and recording it as one would corrupt that signal.
      expect(CheckinEventMapper.map(discharge.metricFor('Unusual'), 'Unusual')!
          .eventType, 'symptom_logged');
    });

    test('a blood clot is a symptom, not a flow level', () {
      final flow = SymptomCategories.byId('flow')!;
      expect(CheckinEventMapper.map(flow.metricFor('Heavy'), 'Heavy')!.eventType,
          'flow_logged');
      expect(
          CheckinEventMapper.map(flow.metricFor('Blood clots'), 'Blood clots')!
              .eventType,
          'symptom_logged');
    });

    test('sex drive can be logged without an activity', () {
      final drive = CheckinEventMapper.map('sex', 'Low sex drive')!;
      expect(drive.eventType, 'sexual_activity_logged');
      expect(drive.payload['drive'], 'low');
      // Not defaulted to 'none': she has not said whether she had sex, and the
      // fertility engine reads that field.
      expect(drive.payload.containsKey('activity'), isFalse);
    });
  });

  group('the switch', () {
    test('everything is collected by default', () {
      for (final category in SymptomCategories.all) {
        expect(SymptomCategoryPreference.isEnabled(category.id), isTrue);
      }
    });

    test('switching one off drops only its own words', () {
      SymptomCategoryPreference.setEnabled('digestion', false);

      expect(SymptomCategoryPreference.allows('Bloating'), isFalse);
      expect(SymptomCategoryPreference.allows('Cramps'), isTrue);
      expect(
        SymptomCategoryPreference.filter({'Cramps', 'Bloating', 'Nausea'}),
        {'Cramps'},
      );
    });

    test('the opt-out belongs to no group and survives any switch', () {
      for (final category in SymptomCategories.all) {
        SymptomCategoryPreference.setEnabled(category.id, false);
      }
      expect(SymptomCategoryPreference.allows('Everything is fine'), isTrue);
    });

    test('a stage hiding a group does not retract the switch', () {
      // Hiding is not opting out: someone who moves to pregnancy and back
      // should not find flow silently switched off.
      SymptomCategoryPreference.setEnabled('flow', true);
      expect(SymptomCategoryPreference.enabledFor('pregnancy').map((c) => c.id),
          isNot(contains('flow')));
      expect(SymptomCategoryPreference.isEnabled('flow'), isTrue);
    });

    test('an unreadable preference collects everything', () {
      SymptomCategoryPreference.load();
      expect(SymptomCategoryPreference.disabled.value, isEmpty);
    });
  });

  group('the sheet', () {
    setUp(() {
      // It is a lazy scrollable and there are now up to ten groups, so the
      // lower ones would never build at the default 800x600.
      final view = TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .views
          .first;
      view.physicalSize = const Size(800, 6000);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });
    });

    testWidgets('a menopause user sees no flow group', (tester) async {
      await tester.pumpWidget(host(stage: 'menopause'));
      await tester.pumpAndSettle();

      expect(find.text('MENSTRUAL FLOW'), findsNothing);
      expect(find.text('SYMPTOMS'), findsOneWidget);
    });

    testWidgets('every group the stage offers is on the sheet, with no switch',
        (tester) async {
      // The per-group switch was removed. Nothing on the sheet hides a
      // group any more, and there is no toggle to find.
      await tester.pumpWidget(host(stage: 'livingWithMyCycle'));
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNothing);
      for (final label in CheckinVocabulary.digestion) {
        expect(find.text(label), findsWidgets, reason: '$label is offered');
      }
    });

    test('a stored switch-off is cleared on load, so nothing stays hidden', () {
      SymptomCategoryPreference.setEnabled('digestion', false);
      expect(SymptomCategoryPreference.isEnabled('digestion'), isFalse);
      SymptomCategoryPreference.load();
      expect(SymptomCategoryPreference.isEnabled('digestion'), isTrue,
          reason: 'with no switch to reach, a hidden group would be hidden for good');
    });

    testWidgets('a one-answer group replaces rather than accumulating',
        (tester) async {
      await tester.pumpWidget(host(stage: 'livingWithMyCycle'));
      await tester.pumpAndSettle();

      // Both labels are unique to the flow group. 'Light' would not be: it is
      // also a movement level, and the finder would match two chips.
      await tester.tap(find.text('Heavy'));
      await tester.pump();
      await tester.tap(find.text('Blood clots'));
      await tester.pump();
      await tester.tap(find.textContaining('Save'));
      await tester.pumpAndSettle();

      expect(saved, {'flow/Blood clots'}, reason: 'flow is one answer a day');
    });

    testWidgets('a multi-answer group accumulates', (tester) async {
      await tester.pumpWidget(host(stage: 'livingWithMyCycle'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cramps'));
      await tester.pump();
      await tester.tap(find.text('Headache'));
      await tester.pump();
      await tester.tap(find.textContaining('Save'));
      await tester.pumpAndSettle();

      expect(saved, {'symptom/Cramps', 'symptom/Headache'});
    });

    testWidgets('the same word in two groups is two selections',
        (tester) async {
      // "Low" is an energy and a stress. As a flat set of words the sheet
      // could hold only one of them, and the save guessed the group -- always
      // energy -- so stress "Low" was never stored and flow "Medium" landed
      // on energy. Each selection carries its group now.
      await tester.pumpWidget(host(stage: 'livingWithMyCycle'));
      await tester.pumpAndSettle();

      final lows = find.text('Low');
      expect(lows, findsWidgets, reason: 'mood, energy and stress all offer it');
      // Energy's chip and stress's chip: by their groups' order on the sheet
      // (mood, energy, ..., stress), the second and last "Low".
      await tester.tap(lows.at(1));
      await tester.pump();
      await tester.tap(lows.last);
      await tester.pump();

      await tester.tap(find.textContaining('Save'));
      await tester.pumpAndSettle();

      expect(saved, {'energy/Low', 'stress/Low'});
    });
  });

  group('what a switched-off group stops sending to Docsy', () {
    // Switching off stops collection from that moment; it does not delete what
    // is already stored. So the server is told what to leave out of Docsy's
    // context, or withdrawn categories keep shaping what it says about her.
    List<String> types() => SymptomCategoryPreference
        .exclusionsForSync()['symptom_consent_excluded_event_types']!;
    List<String> symptoms() => SymptomCategoryPreference
        .exclusionsForSync()['symptom_consent_excluded_symptoms']!;

    test('nothing switched off excludes nothing', () {
      expect(types(), isEmpty);
      expect(symptoms(), isEmpty);
    });

    test('a group with the only producer of its type excludes the type', () {
      SymptomCategoryPreference.setEnabled('sex', false);
      expect(types(), contains('sexual_activity_logged'));
    });

    test('a group sharing symptom_logged names its words instead', () {
      // Six groups record as `symptom_logged`. Excluding the type would drop
      // every symptom she has ever logged because she switched off Digestion.
      SymptomCategoryPreference.setEnabled('digestion', false);

      expect(types(), isNot(contains('symptom_logged')),
          reason: 'other groups still record as symptoms');
      expect(symptoms(), containsAll(['nausea', 'bloating', 'constipation']));
      expect(symptoms(), isNot(contains('cramps')),
          reason: 'cramps belongs to a group that is still on');
    });

    test('the type goes only once every producer is off', () {
      // Derived rather than listed: a hardcoded set would go stale the moment
      // a category gains an option that records as a symptom, and the test
      // would then pass while the exclusion silently under-covered.
      final producers = <String>{};
      for (final category in SymptomCategories.all) {
        if (category.isNumeric) continue;
        for (final option in category.options) {
          final event =
              CheckinEventMapper.map(category.metricFor(option), option);
          if (event?.eventType == 'symptom_logged') producers.add(category.id);
        }
      }
      expect(producers.length, greaterThan(1),
          reason: 'this is only interesting because the type is shared');

      for (final id in producers) {
        SymptomCategoryPreference.setEnabled(id, false);
      }
      expect(types(), contains('symptom_logged'),
          reason: 'nothing still produces it');
    });

    test('a numeric group excludes its reading', () {
      SymptomCategoryPreference.setEnabled('bbt', false);
      expect(types(), contains('bbt_logged'));
      expect(types(), isNot(contains('weight_logged')));
    });

    test('the names are the ones the server stores, not the chip labels', () {
      // The payload holds 'unusual discharge'; the chip says 'Unusual'.
      SymptomCategoryPreference.setEnabled('discharge', false);
      expect(symptoms(), contains('unusual discharge'));
      expect(symptoms(), isNot(contains('unusual')));
    });
  });

  group('icons', () {
    test('every option any category can render has one', () {
      for (final category in SymptomCategories.all) {
        for (final option in category.options) {
          expect(SymptomLogSheet.icons.containsKey('${category.id}/$option'),
              isTrue,
              reason: '${category.id} "$option" would fall back to a circle');
        }
      }
      expect(SymptomLogSheet.icons.containsKey('Everything is fine'), isTrue);
    });

    test('a label in two groups gets a glyph for each', () {
      // 'Medium' is a flow level and an energy level; a map keyed by label
      // alone gave the energy chip a water drop.
      for (final collision in ['Medium', 'Low', 'High', 'Light', 'None']) {
        final owners = SymptomCategories.all
            .where((c) => c.options.contains(collision))
            .toList();
        expect(owners.length, greaterThan(1),
            reason: '$collision is meant to appear in more than one group');
        final glyphs = {
          for (final c in owners) SymptomLogSheet.icons['${c.id}/$collision']
        };
        expect(glyphs.contains(null), isFalse,
            reason: '$collision is missing a glyph in one of its groups');
      }
    });

    test('every category has a tint', () {
      for (final category in SymptomCategories.all) {
        expect(SymptomLogSheet.tints.containsKey(category.id), isTrue,
            reason: '${category.id} has no tint');
      }
    });

    test('no icon is declared for a key no category offers', () {
      final every = {
        'Everything is fine',
        for (final c in SymptomCategories.all)
          for (final o in c.options) '${c.id}/$o',
      };
      for (final key in SymptomLogSheet.icons.keys) {
        expect(every, contains(key),
            reason: '$key has an icon but is not an option');
      }
    });
  });
}
