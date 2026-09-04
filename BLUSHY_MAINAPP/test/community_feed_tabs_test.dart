import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/features/community/community_screen.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/theme/colors.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// The four feed filters at the top of Community.
///
/// They were text labels with a two-pixel rule under the active one: a small
/// target, and a quiet signal for the control that decides what the entire
/// feed shows. They are chips now -- the one in use fills red.
Widget _host() => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BlushyCommunityScreen(),
    );

/// The chip body behind one label.
BoxDecoration _chipFor(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.text(label),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  return container.decoration! as BoxDecoration;
}

Color _labelColour(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

/// Opens the screen and lets the feed request from `initState` finish.
///
/// It is stubbed and fails immediately, but its timer is still outstanding --
/// a test that ends before it fires fails on the pending timer rather than on
/// anything it was checking.
Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Whether the create-post button is showing its label or just the plus.
bool _fabExtended(WidgetTester tester) =>
    tester.widget<FloatingActionButton>(find.byType(FloatingActionButton))
        .isExtended;

void main() {
  useIsolatedStorage();

  testWidgets('every filter is a chip with its name',
      (tester) async {
    await withTestImages(() async {
      await _open(tester);

      for (final label in const ['Home', 'Trending', 'Latest', 'Following', 'My Posts']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      // The icon sits inside the chip, to the left of the name.
      // No icons: five names fill the row on their own.
      expect(find.byIcon(Icons.home_rounded), findsNothing);
    });
  });

  testWidgets('the filter in use is filled red, with white on it',
      (tester) async {
    await withTestImages(() async {
      await _open(tester);

      // Home is the one the screen opens on.
      expect(_chipFor(tester, 'Home').color, BlushyColors.primary);
      expect(_labelColour(tester, 'Home'), Colors.white);

      // And the others are not.
      expect(_chipFor(tester, 'Trending').color, isNot(BlushyColors.primary));
      expect(_labelColour(tester, 'Trending'), isNot(Colors.white));
    });
  });

  testWidgets('tapping one moves the fill to it', (tester) async {
    await withTestImages(() async {
      await _open(tester);

      await tester.tap(find.text('Trending'));
      await tester.pump();
      // Past the fill animation.
      await tester.pump(const Duration(milliseconds: 300));

      expect(_chipFor(tester, 'Trending').color, BlushyColors.primary);
      expect(_labelColour(tester, 'Trending'), Colors.white);
      expect(_chipFor(tester, 'Home').color, isNot(BlushyColors.primary));
    });
  });

  testWidgets('five filters share the width, and nothing scrolls',
      (tester) async {
    // Five names in one row, each scaled to its share rather than cut or
    // pushed past the edge -- so every filter is on screen at once.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await withTestImages(() async {
      await _open(tester);
      expect(tester.takeException(), isNull, reason: 'nothing overflows');

      for (final label in const ['Home', 'Trending', 'Latest', 'Following', 'My Posts']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0.0), reason: label);
        expect(rect.right, lessThanOrEqualTo(320.0),
            reason: '$label runs past the right edge');
      }

      final widths = <double>[
        for (final label in const ['Home', 'Trending', 'Latest', 'Following', 'My Posts'])
          tester
              .getSize(find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(AnimatedContainer),
                  )
                  .first)
              .width,
      ];
      for (final w in widths) {
        expect(w, closeTo(widths.first, 0.01), reason: 'chips: $widths');
      }
    });
  });

  test('My Posts asks the server for its own feed type', () {
    // Four filters are their own lowercased label. This one is not, and
    // lowercasing it would request a feed the server does not have.
    expect(BlushyCommunityScreen.feedTypeFor('My Posts'), 'mine');
    expect(BlushyCommunityScreen.feedTypeFor('Home'), 'home');
    expect(BlushyCommunityScreen.feedTypeFor('Following'), 'following');
  });

  testWidgets('selecting a filter does not resize or embolden it',
      (tester) async {
    // The fill is the whole signal. The label used to go from w500 to w600 on
    // selection, which changed its width and made the row jump.
    await withTestImages(() async {
      await _open(tester);

      final sizeBefore = tester.getSize(find.text('Trending'));
      final weightBefore =
          tester.widget<Text>(find.text('Trending')).style?.fontWeight;

      await tester.tap(find.text('Trending'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.getSize(find.text('Trending')), sizeBefore);
      expect(tester.widget<Text>(find.text('Trending')).style?.fontWeight,
          weightBefore);
    });
  });

  testWidgets('the create button sits collapsed as a plus', (tester) async {
    // It used to read "Create Post" for the whole session, over the feed.
    await withTestImages(() async {
      await _open(tester);

      expect(_fabExtended(tester), isFalse);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });

  testWidgets('changing filter names the button, then it collapses again',
      (tester) async {
    await withTestImages(() async {
      await _open(tester);

      await tester.tap(find.text('Trending'));
      await tester.pump();
      expect(_fabExtended(tester), isTrue);
      expect(find.text('Create Post'), findsOneWidget);

      // Still named just before the two seconds are up.
      await tester.pump(const Duration(milliseconds: 1900));
      expect(_fabExtended(tester), isTrue);

      // And collapsed after.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_fabExtended(tester), isFalse);

      // Let the collapse animation finish so no timer outlives the test.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('changing filter again restarts the window rather than cutting '
      'it short', (tester) async {
    await withTestImages(() async {
      await _open(tester);

      await tester.tap(find.text('Trending'));
      await tester.pump();

      // Most of the way through the first window, switch again.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.tap(find.text('Latest'));
      await tester.pump();

      // The first timer would have fired by now; the second one has not.
      await tester.pump(const Duration(milliseconds: 900));
      expect(_fabExtended(tester), isTrue,
          reason: 'the second change restarts the two seconds');

      await tester.pump(const Duration(milliseconds: 1200));
      expect(_fabExtended(tester), isFalse);

      await tester.pump(const Duration(seconds: 1));
    });
  });
}
