import 'package:blushy_life_app/features/home/checkin_event_mapper.dart';
import 'package:blushy_life_app/features/home/checkin_vocabulary.dart';
import 'package:blushy_life_app/features/home/widgets/symptom_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Symptoms, now that they are off the check-in.
///
/// The defect this replaces: 'Cramps' and 'Tired' were mood options that
/// recorded as symptoms, so choosing one recorded no mood and overwrote a mood
/// already picked. "Happy but cramping" could not be said.
void main() {
  Set<String>? saved;

  Widget host({Set<String> initial = const {}}) => MaterialApp(
        home: Scaffold(
          body: SymptomLogSheet(
            initialSelection: initial,
            onSave: (s) => saved = s,
          ),
        ),
      );

  setUp(() {
    saved = null;
    // With icons and group headers the sheet is taller than the default
    // 800x600, and it is a lazy scrollable: the lower group would never build.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(800, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('several symptoms can be picked at once', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cramps'));
    await tester.pump();
    await tester.tap(find.text('Headache'));
    await tester.pump();

    await tester.tap(find.textContaining('Save'));
    await tester.pumpAndSettle();

    // Saved as group/word: the words on the sheet are not unique across
    // groups, so a selection carries the group it was made in.
    expect(saved, {'symptom/Cramps', 'symptom/Headache'},
        reason: 'symptoms co-occur; one must not replace the other');
  });

  testWidgets('tapping a picked symptom again clears it', (tester) async {
    await tester.pumpWidget(host(initial: {'Cramps'}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cramps'));
    await tester.pump();
    await tester.tap(find.textContaining('Save'));
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
  });

  testWidgets('digestion is on the sheet, grouped but not a separate metric',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    for (final label in CheckinVocabulary.digestion) {
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }
    // One metric, so one event type reverses to one card.
    for (final label in CheckinVocabulary.digestion) {
      expect(CheckinEventMapper.map('symptom', label)!.eventType,
          'symptom_logged');
    }
  });

  group('the defect this sheet exists for', () {
    test('mood and symptoms are now separate metrics', () {
      // Every mood option records as a mood...
      for (final label in CheckinVocabulary.mood) {
        expect(CheckinEventMapper.map('mood', label)!.eventType, 'mood_logged',
            reason: '$label is offered as a mood');
      }
      // ...and no symptom is reachable through the mood selector.
      for (final label in CheckinVocabulary.symptoms) {
        expect(CheckinEventMapper.map('mood', label), isNull,
            reason: '$label is a symptom and must not record as a mood');
      }
    });

    test('each symptom gets its own idempotency key', () {
      // One key per metric per day would collapse every chip onto one id and
      // the server would keep whichever arrived first.
      final day = DateTime(2026, 9, 3);
      String key(String? variant) => CheckinEventMapper.idempotencyKey(
            userId: 'u1', metric: 'symptom', day: day, variant: variant);

      expect(key('Cramps'), isNot(key('Headache')));
      // Still idempotent per chip: the same chip twice is the same write.
      expect(key('Cramps'), key('cramps'));
      // And a single-select card is unchanged.
      expect(
        CheckinEventMapper.idempotencyKey(
            userId: 'u1', metric: 'mood', day: day),
        'checkin:u1:mood:2026-09-03',
      );
    });
  });
}
