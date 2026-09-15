import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/features/partner/widgets/breathing_sync_sheet.dart';

/// Breathing Sync was a composer button that closed the menu and did nothing.
/// Now that it runs a real exercise, the pacing is the part worth pinning: a
/// box-breathing guide that drifts off its four second cadence is worse than
/// none, because people follow it.
void main() {
  Future<void> pump(WidgetTester tester, {int totalSeconds = 120}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BreathingSyncSheet(totalSeconds: totalSeconds),
        ),
      ),
    );
  }

  group('BreathingSyncSheet', () {
    testWidgets('starts idle and does not run until asked', (tester) async {
      await pump(tester);

      expect(find.text('Ready when you are'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Breathe in'), findsNothing);
    });

    testWidgets('walks the four phases on a four second cadence', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(find.text('Breathe in'), findsOneWidget);

      // Four seconds in, the inhale gives way to the hold.
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Hold'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Breathe out'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Hold'), findsOneWidget);

      // And back round to the start of the next cycle.
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Breathe in'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('counts down and finishes on its own', (tester) async {
      await pump(tester, totalSeconds: 8);
      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(find.text('0:08'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('0:04'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('can be paused without finishing', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Pause'));
      await tester.pump();

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Done'), findsNothing);

      // The timer must actually stop: a paused exercise that keeps counting
      // would end while the pair are not breathing with it.
      final remainingWhenPaused = tester.widget<Text>(
        find.textContaining(RegExp(r'^\d:\d\d$')),
      ).data;
      await tester.pump(const Duration(seconds: 10));
      final remainingLater = tester.widget<Text>(
        find.textContaining(RegExp(r'^\d:\d\d$')),
      ).data;
      expect(remainingLater, remainingWhenPaused);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
