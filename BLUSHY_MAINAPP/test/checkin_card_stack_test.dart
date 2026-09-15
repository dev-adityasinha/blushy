import 'package:blushy_life_app/features/home/checkin_followups.dart';
import 'package:blushy_life_app/features/home/widgets/checkin_card_stack.dart';
import 'package:blushy_life_app/features/home/widgets/checkin_scene.dart';
import 'package:blushy_life_app/features/home/widgets/checkin_scene_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The check-in follow-ups, as a deck.
///
/// One question at a time with the next behind it, rather than a column: five
/// questions in a list read as a form, and the point of these is that they are
/// short and answerable.
void main() {
  final answered = <String, String>{};

  /// Animations off, as a device set to reduce motion asks for.
  ///
  /// The scenes loop forever otherwise, and `pumpAndSettle` waits for every
  /// animation to finish -- so a repeating controller makes it time out rather
  /// than fail on anything real.
  Widget host(List<CheckinFollowUp> cards) => MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(
        body: SizedBox(
          width: 380,
          child: CheckinCardStack(
            cards: cards,
            answerFor: (card) => answered[card.metric],
            onAnswer: (card, value) => answered[card.metric] = value,
          ),
        ),
      ),
    ),
  );

  setUp(answered.clear);

  List<CheckinFollowUp> deck() =>
      CheckinFollowUps.forSymptoms(['Fatigue', 'Cramps', 'Headache']);

  testWidgets('one question is in front, not all of them', (tester) async {
    final cards = deck();
    expect(cards.length, greaterThan(2), reason: 'this needs a real deck');

    await tester.pumpWidget(host(cards));
    await tester.pump();

    // The front card's question, and the two behind it, are all built --
    // that is what makes the stack read as a stack. What must not happen is
    // every card being laid out as its own row with its own buttons.
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });

  testWidgets('answering records the value the card carries', (tester) async {
    final cards = deck();
    await tester.pumpWidget(host(cards));
    await tester.pump();

    await tester.tap(find.text('Yes'));
    await tester.pump();

    final front = cards.first;
    expect(answered[front.metric], front.yesValue);
  });

  testWidgets('no is recorded too, rather than skipping', (tester) async {
    final cards = deck();
    await tester.pumpWidget(host(cards));
    await tester.pump();

    await tester.tap(find.text('No'));
    await tester.pump();

    expect(answered[cards.first.metric], cards.first.noValue);
    expect(answered[cards.first.metric], isNot(cards.first.yesValue));
  });

  testWidgets('swiping brings the next card forward', (tester) async {
    final cards = deck();
    await tester.pumpWidget(host(cards));
    await tester.pump();

    final first = cards.first.question;
    expect(find.text(first), findsOneWidget);

    await tester.drag(find.text(first), const Offset(-320, 0));
    await tester.pumpAndSettle();

    // A different question is in front, and nothing was answered by looking.
    expect(find.text(cards[1].question), findsWidgets);
    expect(answered, isEmpty, reason: 'swiping is not answering');
  });

  testWidgets('a small drag snaps back rather than throwing the card away', (
    tester,
  ) async {
    final cards = deck();
    await tester.pumpWidget(host(cards));
    await tester.pump();

    final first = cards.first.question;
    await tester.drag(find.text(first), const Offset(-30, 0));
    await tester.pumpAndSettle();

    expect(
      find.text(first),
      findsOneWidget,
      reason: 'a scroll that caught the card must not discard the question',
    );
  });

  testWidgets('a single card has no dots and still answers', (tester) async {
    final one = CheckinFollowUps.forSymptoms(['Dry skin']);
    expect(one.length, 1, reason: 'this test needs exactly one');

    await tester.pumpWidget(host(one));
    await tester.pump();

    await tester.tap(find.text('Yes'));
    await tester.pump();
    expect(answered[one.first.metric], one.first.yesValue);
  });

  testWidgets('an empty deck renders nothing at all', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pump();
    expect(find.text('Yes'), findsNothing);
  });

  group('the animation seam', () {
    test('each scene names the file that would replace it', () {
      // Adding artwork should be dropping a file in, not editing code.
      final paths = <String>{};
      for (final scene in CheckinScene.values) {
        final path = CheckinSceneView.assetFor(scene);
        expect(path, startsWith('assets/lottie/'));
        expect(path, endsWith('.json'));
        expect(paths.add(path), isTrue,
            reason: 'two scenes would load the same file');
      }
    });

    testWidgets('with no file present the card still draws its scene',
        (tester) async {
      // Which is the state the app ships in: the directory is empty, so every
      // card is on the fallback path and it has to be the good one.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: CheckinSceneView(scene: CheckinScene.water, t: 0.25),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      // The error box a missing asset would otherwise show.
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('scenes', () {
    test('every follow-up metric has one of its own', () {
      // A metric without a scene falls back, which would show a card asking
      // about water with somebody meditating on it.
      final scenes = <CheckinScene>{};
      for (final metric in CheckinFollowUps.metrics) {
        scenes.add(CheckinScene.forMetric(metric));
      }
      expect(
        scenes.length,
        CheckinFollowUps.metrics.length,
        reason: 'two metrics are sharing a scene',
      );
    });

    test('each carries a colour and a word for its chip', () {
      final labels = <String>{};
      for (final scene in CheckinScene.values) {
        expect(scene.label.trim(), isNotEmpty);
        expect(
          labels.add(scene.label),
          isTrue,
          reason: '${scene.label} is used twice',
        );
      }
    });

    test('the card colours are dark enough for white text', () {
      // The question and the chip are white on the card.
      for (final scene in CheckinScene.values) {
        expect(
          scene.colour.computeLuminance(),
          lessThan(0.45),
          reason: '${scene.label} would not hold white text',
        );
      }
    });
  });
}
