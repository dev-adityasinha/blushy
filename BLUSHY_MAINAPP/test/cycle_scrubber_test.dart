import 'dart:io';

import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/home/widgets/cycle_card.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// Making the cycle drawing's scrubbing findable.
///
/// Dragging along the tube and tapping to play the cycle both worked long
/// before this: `onHorizontalDragUpdate` moved through the days and a tap ran
/// the sweep. Nothing on screen said so, so neither was ever used — the same
/// built-and-unreachable shape as the rest of this card's history.
void main() {
  useIsolatedStorage();

  final source =
      File('lib/features/home/widgets/cycle_card.dart').readAsStringSync();

  setUp(() {
    AuthStorage.saveSession(
      token: 't',
      userId: 'u',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );

    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  Widget host() => BlushyOSProvider(
        notifier: BlushyOSState(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: BlushyCycleCard()),
          ),
        ),
      );

  testWidgets('the card says the drawing can be scrubbed', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));
    tester.takeException();

    expect(find.textContaining('Drag along the tube'), findsOneWidget);
    expect(find.textContaining('tap to play'), findsOneWidget,
        reason: 'the sweep was reachable and unmentioned too');
  });

  testWidgets('a scrubber runs from day one to the end of the cycle',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));
    tester.takeException();

    expect(find.byType(Slider), findsOneWidget);

    // 'Day 1' twice is right, not a duplicate: the left end of the scrubber
    // says Day 1, and on the first day of a cycle so does the current-day
    // label above it.
    expect(find.text('Day 1'), findsWidgets);

    // Three labels: the two ends and the day being looked at.
    expect(find.textContaining('Day '), findsNWidgets(3));
  });

  testWidgets('moving the scrubber changes the day it reports', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));
    tester.takeException();

    final before = tester.widget<Slider>(find.byType(Slider)).value;

    // Tapped at a point along the track rather than dragged: a drag on a
    // Slider depends on where the thumb happens to be, and the thumb starts at
    // whichever day today is.
    final track = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(track.left + track.width * 0.8, track.center.dy));
    await tester.pump();
    tester.takeException();

    final after = tester.widget<Slider>(find.byType(Slider)).value;
    expect(after, greaterThan(before),
        reason: 'tapping further along must move to a later day');

    // And it stays there. Springing home on let-go reads as the control
    // refusing the input; a quick drag over the drawing is the gesture that
    // springs back, because that one is a glance rather than a decision.
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<Slider>(find.byType(Slider)).value, after);

    // With a way back, which only appears once it is off today.
    expect(find.text('Back to today'), findsOneWidget);
    await tester.tap(find.text('Back to today'));
    await tester.pump(const Duration(milliseconds: 600));
    tester.takeException();
    expect(find.text('Back to today'), findsNothing);
  });

  group('the drawing and the scrubber are one control', () {
    test('both write the same value', () {
      // Two copies of "which day is showing" would let the drawing and the
      // scrubber disagree about it.
      expect(source.contains('_userDragProgress = value;'), isTrue,
          reason: 'the scrubber sets the drag value');
      expect(source.contains('_userDragProgress = normalized;'), isTrue,
          reason: 'and so does the drag on the drawing');
    });

    test('one way back to today, however it was left', () {
      // The release was copied into each drag handler. One ending now, used by
      // both drags and by the button under the scrubber.
      expect(source.contains('void _releaseScrub()'), isTrue);
      final releases =
          RegExp('_releaseScrub').allMatches(source).length;
      expect(releases, greaterThanOrEqualTo(4),
          reason: 'declared, plus both drags and the button');
    });

    test('the scrubber does not spring back on its own', () {
      // The drawing's drag does, because it is a glance. The slider is a
      // decision, and a control that undoes it reads as broken.
      final at = source.indexOf('child: Slider(');
      expect(at, greaterThan(-1));
      final body = source.substring(at, at + 700);
      expect(body.contains('onChangeEnd'), isFalse,
          reason: 'letting go must not move it');
    });

    test('day one is day one, not day zero', () {
      // At progress 0 the card must read Day 1, and at the far end the last
      // day rather than one past the end of the cycle.
      expect(source.contains('.clamp(0, length - 1) + 1'), isTrue,
          reason: 'the off-by-one at both ends is what this guards');
    });
  });
}
