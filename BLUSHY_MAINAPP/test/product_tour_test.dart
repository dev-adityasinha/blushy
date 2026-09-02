import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/shared/product_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// A first-run tour that points at each tab and says what it is for.
///
/// It replaces a flag that did nothing: onboarding wrote
/// `coach_first_launch.json` with a raw `File()`, the dashboard read it, called
/// `setState` with an empty body and deleted it.
///
/// The parts worth pinning are the ones that would annoy a user rather than
/// crash: showing again after it has been dismissed, trapping someone who wants
/// out, or dimming the screen with nothing to point at.
void main() {
  useIsolatedStorage();

  setUp(() {
    // Storage is namespaced per user; without a session, reads and writes are
    // silently dropped and the tour could never remember anything.
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'tour-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );
  });

  /// Three targets laid out like a tab bar, plus the tour over them.
  Widget host({
    required List<GlobalKey> keys,
    required VoidCallback onFinished,
    List<TourStep>? steps,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Row(
              children: [
                for (final key in keys)
                  Expanded(child: SizedBox(key: key, height: 48)),
              ],
            ),
            ProductTour(
              steps: steps ??
                  [
                    for (var i = 0; i < keys.length; i++)
                      TourStep(
                        targetKey: keys[i],
                        title: 'Tab $i',
                        body: 'What tab $i does.',
                      ),
                  ],
              onFinished: onFinished,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('it walks every step and reports the position', (tester) async {
    final keys = [GlobalKey(), GlobalKey(), GlobalKey()];
    var finished = 0;

    await tester.pumpWidget(host(keys: keys, onFinished: () => finished++));
    await tester.pump();

    expect(find.text('Tab 0'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Tab 1'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Tab 2'), findsOneWidget);
    // The last step offers a way out, not another Next.
    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(finished, 1);
  });

  testWidgets('finishing means it does not come back', (tester) async {
    final keys = [GlobalKey(), GlobalKey()];
    expect(TourPreferences.hasSeenTour(), isFalse);

    await tester.pumpWidget(host(keys: keys, onFinished: () {}));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Got it'));
    await tester.pump();

    expect(TourPreferences.hasSeenTour(), isTrue);
  });

  testWidgets('skipping counts as seeing it', (tester) async {
    // A tour that returns after being dismissed is worse than no tour.
    final keys = [GlobalKey(), GlobalKey()];
    var finished = 0;

    await tester.pumpWidget(host(keys: keys, onFinished: () => finished++));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(finished, 1);
    expect(TourPreferences.hasSeenTour(), isTrue);
  });

  testWidgets('tapping the dimmed area advances', (tester) async {
    final keys = [GlobalKey(), GlobalKey()];
    await tester.pumpWidget(host(keys: keys, onFinished: () {}));
    await tester.pump();

    // Well away from the card and the targets.
    await tester.tapAt(const Offset(20, 300));
    await tester.pump();

    expect(find.text('Tab 1'), findsOneWidget);
  });

  testWidgets('a step with nothing on screen is skipped, not pointed at',
      (tester) async {
    final present = GlobalKey();
    final absent = GlobalKey();
    var finished = 0;

    await tester.pumpWidget(host(
      keys: [present],
      onFinished: () => finished++,
      steps: [
        TourStep(targetKey: absent, title: 'Gone', body: 'Not rendered.'),
        TourStep(targetKey: present, title: 'Here', body: 'Rendered.'),
      ],
    ));
    await tester.pump();

    expect(find.text('Gone'), findsNothing);
    expect(find.text('Here'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget,
        reason: 'the count reflects what can actually be shown');
    expect(finished, 0);
  });

  testWidgets('no targets at all finishes rather than dimming the screen',
      (tester) async {
    var finished = 0;
    await tester.pumpWidget(host(
      keys: const [],
      onFinished: () => finished++,
      steps: [
        TourStep(targetKey: GlobalKey(), title: 'Gone', body: 'Not rendered.'),
      ],
    ));
    await tester.pump();
    await tester.pump();

    expect(finished, 1, reason: 'a dimmed screen with no explanation is worse '
        'than no tour');
  });

  test('reset lets it be shown again', () {
    TourPreferences.markSeen();
    expect(TourPreferences.hasSeenTour(), isTrue);

    TourPreferences.reset();
    expect(TourPreferences.hasSeenTour(), isFalse);
  });

  test('an account that has never seen it, sees it', () {
    // Nothing stored reads as not seen, which is what a new account is. The
    // tour only runs after onboarding, so a session always exists by then.
    expect(TourPreferences.hasSeenTour(), isFalse);

    TourPreferences.markSeen();
    expect(TourPreferences.hasSeenTour(), isTrue);
  });
}
