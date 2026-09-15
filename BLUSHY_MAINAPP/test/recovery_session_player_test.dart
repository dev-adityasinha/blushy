import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/features/m_studio/recovery_session_player.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';

/// The Recovery tab advertised sessions with durations and both cards were
/// `onTap: () {}`. Now that a session actually runs, the pacing is what has to
/// be right: a guide that drifts off its own timings is worse than none,
/// because people follow it.
void main() {
  const steps = [
    RecoveryStep(instruction: 'Settle in.', seconds: 3),
    RecoveryStep(instruction: 'Breathe in.', seconds: 2),
    RecoveryStep(instruction: 'Breathe out.', seconds: 2),
  ];

  Future<void> pump(WidgetTester tester) async {
    // The player reads its labels from AppLocalizations now, so the harness has
    // to supply the delegates the real app does. Without them the lookup
    // returns null and the widget throws while building.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RecoverySessionPlayer(
          sessionId: 'rs_test',
          title: 'Test session',
          steps: steps,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('RecoverySessionPlayer', () {
    testWidgets('starts idle on the first instruction', (tester) async {
      await pump(tester);

      expect(find.text('Settle in.'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.textContaining('Step 1 of 3'), findsOneWidget);
    });

    testWidgets('advances through the steps on their own timings', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      // Three seconds on the first step, then the second.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Breathe in.'), findsOneWidget);
      expect(find.textContaining('Step 2 of 3'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Breathe out.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('finishes after the last step', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Done.'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('pausing actually stops the clock', (tester) async {
      // A paused session that kept counting would finish while nobody was
      // following it.
      await pump(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Pause'));
      await tester.pump();

      expect(find.text('Start'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));

      expect(find.text('Done.'), findsNothing);
      expect(find.text('Settle in.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('RecoveryStep', () {
    test('parses a well-formed step', () {
      final step = RecoveryStep.fromJson({'instruction': 'Breathe.', 'seconds': 4});
      expect(step, isNotNull);
      expect(step!.instruction, 'Breathe.');
      expect(step.seconds, 4);
    });

    test('drops steps that could not be followed', () {
      // A step with no instruction or no duration would leave someone sitting
      // in silence wondering whether it had stalled.
      expect(RecoveryStep.fromJson({'instruction': '', 'seconds': 4}), isNull);
      expect(RecoveryStep.fromJson({'instruction': 'Breathe.', 'seconds': 0}), isNull);
      expect(RecoveryStep.fromJson({'instruction': 'Breathe.'}), isNull);
      expect(RecoveryStep.fromJson('not a map'), isNull);
      expect(RecoveryStep.fromJson(null), isNull);
    });
  });
}
