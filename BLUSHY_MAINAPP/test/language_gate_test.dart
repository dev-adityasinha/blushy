import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/language_preference.dart';
import 'package:blushy_life_app/shared/language_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// The language screen the app opens on.
///
/// The chip in the header could only be reached from a screen already written
/// in a language the user might not read. This asks first, and the thing worth
/// proving is not that the screen renders but that tapping a row actually
/// changes the strings the rest of the app resolves.
void main() {
  useIsolatedStorage();

  setUp(() {
    LanguagePreference.hasChosen = false;
    LanguagePreference.current.value = LanguagePreference.fallback;
  });

  /// Wired the way `main.dart` wires it: the locale comes from the same
  /// notifier the picker writes to, which is the whole mechanism under test.
  Widget harness({required Widget child}) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguagePreference.current,
      builder: (context, languageCode, _) => MaterialApp(
        locale: Locale(languageCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        localeResolutionCallback: LanguagePreference.resolveLocale,
        home: LanguageGate(child: child),
      ),
    );
  }

  testWidgets('it asks before showing the app', (tester) async {
    // Tall enough that the lazy list builds all seven rows.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(child: const Text('the app')));
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsNothing);
    // Every language is offered in its own script: that is how someone finds
    // their own row without reading the heading.
    for (final name in LanguagePreference.supported.values) {
      // Not findsOneWidget: the English row carries the same string twice,
      // once as the native name and once as the English gloss.
      expect(find.text(name), findsWidgets, reason: '$name is missing');
    }
  });

  testWidgets('tapping a language changes the strings, not just the row',
      (tester) async {
    await tester.pumpWidget(harness(child: const Text('the app')));
    await tester.pumpAndSettle();

    final english = tester
        .widget<Text>(find.byWidgetPredicate(
            (w) => w is Text && w.data == 'Choose your language'))
        .data;
    expect(english, 'Choose your language');

    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(LanguagePreference.code, 'hi');
    // The heading is resolved through AppLocalizations, so if the locale did
    // not actually move the English would still be on screen.
    expect(find.text('Choose your language'), findsNothing);
    expect(find.text('अपनी भाषा चुनें'), findsOneWidget);
  });

  testWidgets('confirming records the choice and does not ask again',
      (tester) async {
    await tester.pumpWidget(harness(child: const Text('the app')));
    await tester.pumpAndSettle();

    // Without tapping a row first: English is already selected, and a user who
    // wants English would otherwise be asked on every launch.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsOneWidget);
    expect(LanguagePreference.hasChosen, isTrue);

    // A fresh gate, as if the app were relaunched with the flag restored.
    await tester.pumpWidget(harness(child: const Text('the app')));
    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);
    expect(find.text('Choose your language'), findsNothing);
  });

  testWidgets('a returning user goes straight through', (tester) async {
    LanguagePreference.hasChosen = true;
    await tester.pumpWidget(harness(child: const Text('the app')));
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsOneWidget);
  });

  test('load() distinguishes a stored English from no choice at all', () {
    LanguagePreference.hasChosen = false;
    LanguagePreference.load();
    expect(LanguagePreference.hasChosen, isFalse,
        reason: 'nothing stored yet, so the user has not chosen');

    LanguagePreference.set('en');
    LanguagePreference.hasChosen = false;
    LanguagePreference.load();
    expect(LanguagePreference.hasChosen, isTrue,
        reason: 'English was stored, so it was chosen');
    expect(LanguagePreference.code, 'en');
  });
}
