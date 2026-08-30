import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/language_preference.dart';

/// The app had no localization at all: every label was a hardcoded English
/// literal and the header's language chip was a no-op.
///
/// These check that a locale genuinely resolves to translated strings, rather
/// than that the plumbing merely compiles -- a missing translation silently
/// falls back to English, which looks like it worked.
void main() {
  Future<AppLocalizations> localizationsFor(WidgetTester tester, String code) async {
    late AppLocalizations t;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(code),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The same resolver the app uses, so this exercises real behaviour.
        localeResolutionCallback: LanguagePreference.resolveLocale,
        home: Builder(
          builder: (context) {
            t = AppLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return t;
  }

  group('AppLocalizations', () {
    testWidgets('every language the picker offers is actually supported', (tester) async {
      // Offering a language with no translations would fall back to English
      // and look broken.
      final supported = AppLocalizations.supportedLocales
          .map((l) => l.languageCode)
          .toSet();

      for (final code in LanguagePreference.supported.keys) {
        expect(supported, contains(code),
            reason: '$code is offered in the picker but has no translations');
      }
    });

    testWidgets('English reads as written', (tester) async {
      final t = await localizationsFor(tester, 'en');
      expect(t.navHome, 'Home');
      expect(t.actionSave, 'Save');
    });

    testWidgets('each locale returns its own strings, not the English fallback',
        (tester) async {
      final english = await localizationsFor(tester, 'en');

      for (final code in ['hi', 'bn', 'ta', 'te', 'mr', 'kn']) {
        final t = await localizationsFor(tester, code);
        expect(t.navHome, isNot(english.navHome),
            reason: '$code navHome fell back to English');
        expect(t.actionSave, isNot(english.actionSave),
            reason: '$code actionSave fell back to English');
        expect(t.stateOfflineNoCache, isNot(english.stateOfflineNoCache),
            reason: '$code offline copy fell back to English');
      }
    });

    testWidgets('plurals are translated, not just interpolated', (tester) async {
      final english = await localizationsFor(tester, 'en');
      expect(english.memoriesCount(0), 'No memories yet');
      expect(english.memoriesCount(1), '1 memory');
      expect(english.memoriesCount(3), '3 memories');

      final hindi = await localizationsFor(tester, 'hi');
      expect(hindi.memoriesCount(3), isNot(english.memoriesCount(3)));
      expect(hindi.memoriesCount(3), contains('3'));
    });

    testWidgets('an unsupported locale falls back to English rather than failing',
        (tester) async {
      final t = await localizationsFor(tester, 'fr');
      expect(t.navHome, 'Home');
    });
  });
}
