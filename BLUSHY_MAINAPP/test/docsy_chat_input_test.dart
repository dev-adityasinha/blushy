import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/sia/sia_screen.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// The Dr. Docsy composer.
///
/// It was a single-line field, so a long message scrolled sideways under the
/// cursor instead of wrapping — you could not see what you had written.
void main() {
  useIsolatedStorage();

  testWidgets('a long message wraps instead of scrolling sideways',
      (tester) async {
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );

    // A phone, not the 800x600 default: this screen carries a weekly sleep
    // chart whose bars are laid out for a phone width.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await withTestImages(() async {
      await tester.pumpWidget(
        BlushyOSProvider(
          notifier: BlushyOSState(),
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const BlushySiaScreen(),
          ),
        ),
      );
      // The screen fires profile and chat-history requests on open; they are
      // stubbed and fail, but their timers still have to land.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // The weekly sleep chart used to overflow its fixed-width card here,
      // because its seven columns were sized by their own labels. They share
      // the width now, so there is nothing to swallow.
      expect(tester.takeException(), isNull);

      final field = tester.widget<TextField>(find.byType(TextField).last);

      expect(field.maxLines, isNull,
          reason: 'no line cap: a long message wraps as far as it needs');
      // The field keeps one height and scrolls inside it, by decision: a
      // long message must not grow the bar. `expands` is what fills the
      // fixed height and lets the text scroll within it.
      expect(field.expands, isTrue, reason: 'fixed height, scrolls inside');
      expect(field.keyboardType, TextInputType.multiline);

      // The screen runs a periodic placeholder timer, cancelled in dispose.
      // Tear it down inside the test, then pump past the one further sync its
      // dispose kicks off, so nothing is left pending.
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets('an empty chat opens with a greeting, dated and timed',
      (tester) async {
    // She opens rather than waiting to be spoken to first, and the exchange
    // carries when it happened the way a messaging app does.
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );

    await withTestImages(() async {
      await tester.pumpWidget(
        BlushyOSProvider(
          notifier: BlushyOSState(),
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const BlushySiaScreen(),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // One of the four openers, matched to the hour.
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data ?? '').contains("what's bringing you here today?")),
        findsOneWidget,
      );

      // Dated like a chat, and the message carries a time.
      expect(find.text('Today'), findsOneWidget);

      // The day label is bare text; it had a bordered pill behind it.
      expect(
        find.ancestor(
          of: find.text('Today'),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
        reason: 'no background behind the day separator',
      );

      // And as a tab there is no empty AppBar band above the conversation.
      expect(find.byType(AppBar), findsNothing);
      expect(
        find.byWidgetPredicate((w) =>
            w is Text && RegExp(r'^\d{1,2}:\d{2} (am|pm)$').hasMatch(w.data ?? '')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets('the mood options are equal width, with icons not emoji',
      (tester) async {
    // They were content-sized chips in a Wrap, so "Sad" was half the width of
    // "Irritated" and the rows did not line up.
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await withTestImages(() async {
      await tester.pumpWidget(
        BlushyOSProvider(
          notifier: BlushyOSState(),
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            // A Scaffold, so the section is bounded and InkWell has a Material.
            home: const Scaffold(
              body: SingleChildScrollView(child: TodaysContextSection()),
            ),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      await tester.tap(find.text('Mood').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      double widthOf(String label) => tester
          .getSize(find
              .ancestor(of: find.text(label), matching: find.byType(Container))
              .first)
          .width;

      final balanced = widthOf('Balanced');
      for (final label in const ['Tired', 'Sleepy', 'Anxious', 'Sad']) {
        expect(widthOf(label), closeTo(balanced, 0.01), reason: label);
      }

      // Icons, not emoji.
      expect(find.byIcon(Icons.balance_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bedtime_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets("Today's Context is gone from the Docsy tab", (tester) async {
    // It moved to the home tab, next to where the day is actually logged.
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );

    await withTestImages(() async {
      await tester.pumpWidget(
        BlushyOSProvider(
          notifier: BlushyOSState(),
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const BlushySiaScreen(),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text("TODAY'S CONTEXT"), findsNothing);
      expect(find.byType(TodaysContextSection), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets('the sleep chart holds up at a large system text size',
      (tester) async {
    // The card is a fixed 160px, so seven columns sized by their own labels
    // overflowed it as soon as the text was scaled. They share the width now.
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await withTestImages(() async {
      await tester.pumpWidget(
        BlushyOSProvider(
          notifier: BlushyOSState(),
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: const BlushySiaScreen(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(tester.takeException(), isNull,
          reason: 'nothing should overflow at double text size');

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets('she writes from the right, with no face and no name',
      (tester) async {
    // Docsy answers from the right. The bubbles used to be full-width blocks,
    // so which side they sat on made no visible difference at all.
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await withTestImages(() async {
      await tester.pumpWidget(
        BlushyOSProvider(
          notifier: BlushyOSState(),
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const BlushySiaScreen(),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      await tester.enterText(find.byType(TextField).last, 'my back hurts');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // No face and no name on either side, by decision: which side a
      // bubble sits on is what says who is speaking.
      expect(find.byIcon(Icons.person_rounded), findsNothing);
      expect(find.text('You'), findsNothing,
          reason: 'her own bubbles carry no name');
      expect(find.text('Docsy'), findsWidgets,
          reason: "Docsy's bubbles carry hers");

      // Her bubble sits to the right and does not span the width. Measured
      // on the bubble that holds her words, not on a label.
      final bubble = tester.getRect(find
          .ancestor(
            of: find.text('my back hurts'),
            matching: find.byType(ConstrainedBox),
          )
          .first);
      expect(bubble.right, greaterThan(350),
          reason: 'her messages run to the right edge');
      expect(bubble.left, greaterThan(30.0),
          reason: 'a full-width bubble makes left and right indistinguishable');

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });
}
