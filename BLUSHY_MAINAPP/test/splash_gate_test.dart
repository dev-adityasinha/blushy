import 'dart:io';

import 'package:blushy_life_app/shared/splash_gate.dart';
import 'package:blushy_life_app/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The red opening screen, and the circle that opens onto the app.
///
/// The parts worth holding: the app is only hidden, never delayed; the circle
/// finishes rather than leaving a ring of red at the corners; and the splash
/// stops painting once it is done instead of sitting behind every later frame.
/// Whether the red field with the wordmark is currently up.
bool _wordmarkShowing(WidgetTester tester) =>
    tester.any(find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText() == 'BLUSHY.',
    ));

void main() {
  Widget host({
    bool reduceMotion = false,
    Duration? hold,
    Duration? reveal,
    DateTime Function()? now,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: SplashGate(
          hold: hold ?? const Duration(milliseconds: 100),
          reveal: reveal ?? const Duration(milliseconds: 200),
          now: now ?? DateTime.now,
          child: const Scaffold(body: Center(child: Text('the app'))),
        ),
      ),
    );
  }

  testWidgets('it opens on red, with the wordmark', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    final field = tester.widget<ColoredBox>(
      find.descendant(of: find.byType(SplashGate), matching: find.byType(ColoredBox)).first,
    );
    expect(field.color, BlushyColors.primary);

    final wordmark = tester.widget<RichText>(find.byType(RichText).first);
    expect(wordmark.text.toPlainText(), 'BLUSHY.');
  });

  testWidgets('the app is behind it the whole time, never delayed', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    // Built and running from the first frame; only its visibility is animated.
    // A splash that withholds the app is a splash that makes launch slower.
    expect(find.text('the app'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('the circle opens and then the splash stops painting', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.byType(ClipPath), findsOneWidget,
        reason: 'the app is revealed through a clip while the circle opens');

    await tester.pumpAndSettle();

    // Nothing left to reveal: no clip, no red field behind every later frame.
    expect(find.byType(ClipPath), findsNothing);
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('reduced motion goes straight to the app', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pump();

    expect(find.text('the app'), findsOneWidget);
    expect(find.byType(ClipPath), findsNothing,
        reason: 'no circle, and no wait for one');
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving early does not leave the controller running', (tester) async {
    await tester.pumpWidget(host(hold: const Duration(seconds: 5)));
    await tester.pump();

    // Gone before the reveal ever starts.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('it plays again after a long enough absence', (tester) async {
    var clock = DateTime(2026, 9, 2, 12);
    await tester.pumpWidget(host(now: () => clock));
    await tester.pumpAndSettle();
    expect(find.byType(ClipPath), findsNothing, reason: 'the first play is over');

    // Away past the ten-minute mark, then back.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = clock.add(const Duration(minutes: 11));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(_wordmarkShowing(tester), isTrue,
        reason: 'reopening the app should look like opening it');
    expect(find.byType(ClipPath), findsOneWidget);

    // And it finishes, rather than leaving the red field up.
    await tester.pumpAndSettle();
    expect(find.byType(ClipPath), findsNothing);
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('a short trip out is the same session continuing',
      (tester) async {
    // The picker, the recorder, the share sheet, a call. All of these pause
    // the app, and coming back through a full red screen reads as a glitch.
    var clock = DateTime(2026, 9, 2, 12);
    await tester.pumpWidget(host(now: () => clock));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = clock.add(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(_wordmarkShowing(tester), isFalse);
    expect(find.byType(ClipPath), findsNothing);
  });

  testWidgets('a trip through inactive is not a reopen', (tester) async {
    // The app switcher being summoned and dismissed never leaves the screen,
    // and replaying there would read as a glitch.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(_wordmarkShowing(tester), isFalse);
    expect(find.byType(ClipPath), findsNothing);
  });

  test('the native launch screen is the same red', () {
    // Android paints its own window background before Flutter draws anything.
    // Left at white, the app opened white, then red — a flash the Flutter side
    // cannot do anything about.
    final colors = File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    expect(colors.contains('#DD0D22'), isTrue,
        reason: 'and it has to be BlushyColors.primary, not a near miss');

    for (final path in const [
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ]) {
      final xml = File(path).readAsStringSync();
      expect(xml.contains('@color/blushy_splash'), isTrue, reason: path);
      expect(xml.contains('@android:color/white'), isFalse, reason: path);
    }
  });
}
