import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/features/home/widgets/home_hero.dart';

/// The ring must not report a day nobody logged.
///
/// Reported as a cycle "automatically changing to Day 1" after it had been on
/// Day 20. Nothing had reset: the screen was an account with no period logged,
/// and `_Ready` fills its gaps with `day ?? 1`, `length ?? 28` and a null phase
/// rendered as "Menstrual Phase". So it printed
///
///   Day 1 / Menstrual Phase / Next cycle begins in 27 Days
///
/// in exactly the same confident type as a real reading. Every number there is
/// a default, and none of them is about her.
///
/// `insufficient_data` maps to `ready` deliberately -- a cycle with too little
/// history for predictions still has a real day worth showing -- so the test
/// has to be the day itself, not the state.
void main() {
  Future<void> pump(WidgetTester tester, CycleRingCard card) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ));
  }

  testWidgets('with no day logged it asks, rather than asserting Day 1',
      (tester) async {
    await pump(
      tester,
      CycleRingCard(
        state: CycleCardState.ready,
        phase: null,
        cycleDay: null,
        cycleLength: null,
        onSetUp: () {},
      ),
    );

    expect(find.textContaining('Day 1', findRichText: true), findsNothing);
    expect(find.textContaining('Menstrual Phase'), findsNothing);
    expect(
      find.textContaining('Next cycle begins in', findRichText: true),
      findsNothing,
      reason: '27 days to a cycle that was never logged',
    );
  });

  testWidgets('a real day still renders, even without predictions',
      (tester) async {
    // This is the case `insufficient_data` exists for: she has logged a
    // period, there is simply not enough history to forecast the next one.
    await pump(
      tester,
      CycleRingCard(
        state: CycleCardState.ready,
        phase: CyclePhaseKind.luteal,
        cycleDay: 20,
        cycleLength: 28,
        onSetUp: () {},
      ),
    );

    expect(find.textContaining('Day 20', findRichText: true), findsOneWidget);
    expect(find.textContaining('Luteal'), findsWidgets);
  });

  testWidgets('a logged day of 1 is still shown, because it is hers',
      (tester) async {
    // The fix keys on the day being absent, not on its value -- day 1 is a
    // real day when a period actually started today.
    await pump(
      tester,
      CycleRingCard(
        state: CycleCardState.ready,
        phase: CyclePhaseKind.menstrual,
        cycleDay: 1,
        cycleLength: 28,
        onSetUp: () {},
      ),
    );

    expect(find.textContaining('Day 1', findRichText: true), findsOneWidget);
  });
}
