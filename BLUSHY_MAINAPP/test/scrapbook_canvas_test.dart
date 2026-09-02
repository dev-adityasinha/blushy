import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/journal/journal_screen.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// A scrapbook page is a blank canvas; a reflection is a page of prompts.
///
/// Create Scrapbook used to open a decorative cover whose only action was to
/// reveal the same journal Reflection opens, and whose cover, ribbon and desk
/// choices were never saved anywhere. The two options did the same thing.
final _journalKey = GlobalKey<BlushyJournalScreenState>();

Future<void> _openJournal(WidgetTester tester) async {
  AuthStorage.saveSession(
    token: 'test-token',
    userId: 'test-user',
    email: 'a@b.c',
    role: 'woman',
    onboardingCompleted: true,
  );

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
        home: BlushyJournalScreen(key: _journalKey),
      ),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  useIsolatedStorage();

  testWidgets('the journal list lays out without overflowing', (tester) async {
    // Two rows here sized their children to their own text with no flex: the
    // greeting beside three icon buttons, and the summary title beside the
    // emotion chip. Both ran past the screen on a phone.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await withTestImages(() async {
      await _openJournal(tester);

      expect(tester.takeException(), isNull);

      // And the hardcoded quote card is gone.
      expect(find.textContaining('smallest memories'), findsNothing);
      expect(find.text("TODAY'S INSPIRATION"), findsNothing);

      // As is the back button, on every page.
      expect(find.text('Back to home'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets('a scrapbook page opens blank, with the making toolbar',
      (tester) async {
    await withTestImages(() async {
      await _openJournal(tester);

      _journalKey.currentState!.openScrapbookCanvas();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // The toolbar you build a page with.
      expect(find.text('Stickers'), findsOneWidget);
      expect(find.text('Washi Tape'), findsOneWidget);
      expect(find.text('Photo Frames'), findsOneWidget);

      // And nothing written on it: the prompts belong to a reflection.
      expect(find.text('What is on your mind today?'), findsNothing);
      expect(find.text('How was today?'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets('the header names what you opened', (tester) async {
    // The editor's header is the entry title, so the title is what names it.
    await withTestImages(() async {
      await _openJournal(tester);

      _journalKey.currentState!.openScrapbookCanvas();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        'Scrapbook',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets('a reflection opens with its template prompts', (tester) async {
    await withTestImages(() async {
      await _openJournal(tester);

      _journalKey.currentState!.openTemplate('Gratitude');
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // The Gratitude template's own questions, so the two options differ.
      expect(find.text('Three things you were glad of today.'), findsOneWidget);

      // ...and the header says what kind of thing this is.
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        'Reflection',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });
}
