import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/journal/journal_screen.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// The stats under Today's Memory Summary.
///
/// Each one added the open entry's live items on top of the full list of
/// today's entries, so an entry open from today was counted twice -- which is
/// why "Words" read roughly double the sentence above it. They also fell back
/// to the most recent entry when nothing had been written today, reporting
/// another day's writing under a heading that says "Today".
final _journalKey = GlobalKey<BlushyJournalScreenState>();

Future<void> _open(WidgetTester tester) async {
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

  testWidgets('an open entry is counted once, not twice', (tester) async {
    await withTestImages(() async {
      await _open(tester);

      // A Gratitude reflection places three prompts on the page.
      _journalKey.currentState!.openTemplate('Gratitude');
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      final state = _journalKey.currentState!;
      final open = state.debugWordsToday;

      // Close it: the same entry is now only in the saved list.
      await tester.tap(find.byTooltip('Save & close'));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(state.debugWordsToday, open,
          reason: 'the count must not change with the entry merely open');
      expect(open, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets('nothing written today counts as nothing', (tester) async {
    // It used to fall back to the most recent entry, so a day with no writing
    // reported another day's words under a "Today" heading.
    await withTestImages(() async {
      await _open(tester);

      expect(_journalKey.currentState!.debugWordsToday, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });
}
