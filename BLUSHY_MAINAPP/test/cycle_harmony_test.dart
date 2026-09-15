import 'package:blushy_life_app/features/partner/presentation/cycle_harmony_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cycle Harmony, and the sentence it must never write.
///
/// A partner who reads "her estrogen is high, so she is energetic" learns to
/// treat her as a phase rather than a person -- and is then wrong about her on
/// every day she does not match the chart. So the copy is hedged, and these
/// tests are mostly about what is absent from it.

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  test('no phase note makes a deterministic claim about her', () {
    // The words that turn a tendency into a diagnosis.
    const forbidden = [
      'estrogen',
      'progesterone',
      'hormone',
      'because',
      'will be',
      'is feeling',
      'therefore',
      'causes',
    ];

    for (final phase in ['menstrual', 'follicular', 'ovulation', 'luteal']) {
      final note = CycleHarmonyCard.noteFor(phase);
      expect(note, isNotNull, reason: phase);
      final lower = note!.toLowerCase();
      for (final word in forbidden) {
        expect(lower.contains(word), isFalse, reason: '$phase says "$word"');
      }
      // And each one hedges rather than asserts.
      expect(
        lower.contains('some') || lower.contains('often') || lower.contains('can'),
        isTrue,
        reason: '$phase reads as a fact rather than a tendency',
      );
    }
  });

  test('an unknown phase produces nothing rather than something generic', () {
    expect(CycleHarmonyCard.noteFor(null), isNull);
    expect(CycleHarmonyCard.noteFor(''), isNull);
    expect(CycleHarmonyCard.noteFor('not a phase'), isNull);
  });

  testWidgets('with a phase it shows the day, the phase and the hedge',
      (tester) async {
    await tester.pumpWidget(_host(CycleHarmonyCard(
      partnerName: 'Anaya',
      cycleInfo: const {'currentCycleDay': 22, 'phase': 'Luteal'},
      onAskDocsy: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('CYCLE HARMONY'), findsOneWidget);
    expect(find.text('What her body may be navigating today'), findsOneWidget);
    expect(find.textContaining('Day 22'), findsOneWidget);
    expect(find.textContaining('Asking beats assuming'), findsOneWidget);
  });

  testWidgets('with no cycle shared it says so, and does not invent one',
      (tester) async {
    await tester.pumpWidget(_host(CycleHarmonyCard(
      partnerName: 'Anaya',
      cycleInfo: null,
      onAskDocsy: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Building your shared rhythm'), findsOneWidget);
    expect(find.textContaining('Day '), findsNothing);
    expect(find.textContaining('asking is the best data'), findsOneWidget);
  });

  testWidgets('the Docsy bar opens the AI that already exists',
      (tester) async {
    var asked = 0;
    await tester.pumpWidget(_host(CycleHarmonyCard(
      partnerName: 'Anaya',
      cycleInfo: const {'phase': 'Follicular'},
      onAskDocsy: () => asked++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    expect(asked, 1);
  });

  testWidgets('support is one card with a count and a bar, not four cards',
      (tester) async {
    await tester.pumpWidget(_host(SupportActionsCard(
      actions: const [
        {'id': 'a', 'title': 'Make something warm', 'category': 'Physical comfort'},
        {'id': 'b', 'title': 'Take dinner off her plate', 'category': 'Acts of care'},
        {'id': 'c', 'title': 'Check in later', 'category': 'Check-in'},
      ],
      completedIds: const {'a'},
      onToggle: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text("TODAY'S SUPPORT"), findsOneWidget);
    expect(find.text('1 / 3 completed'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // A completed one is struck through rather than removed.
    final done = tester.widget<Text>(find.text('Make something warm'));
    expect(done.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('tapping an action reports which one', (tester) async {
    final toggled = <String>[];
    await tester.pumpWidget(_host(SupportActionsCard(
      actions: const [
        {'id': 'warm', 'title': 'Make something warm'},
        {'id': 'quiet', 'title': 'Give her some quiet time'},
      ],
      completedIds: const {},
      onToggle: toggled.add,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Give her some quiet time'));
    await tester.pumpAndSettle();
    expect(toggled, ['quiet']);
  });

  testWidgets('with nothing to suggest, the card is absent', (tester) async {
    // Better than a heading over an empty list.
    await tester.pumpWidget(_host(SupportActionsCard(
      actions: const [],
      completedIds: const {},
      onToggle: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text("TODAY'S SUPPORT"), findsNothing);
  });
}
