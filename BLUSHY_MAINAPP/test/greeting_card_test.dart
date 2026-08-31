import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/features/home/widgets/greeting_card.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';

/// The first card is a greeting and nothing more.
///
/// Every life stage used to open with its own hero carrying the cycle day, the
/// phase name and a line about energy — all of which the very next card
/// repeats. Ten copies of that, one per stage, is what made the top of the
/// home page dense and inconsistent.
Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('greets by name and asks nothing of the reader', (tester) async {
    await tester.pumpWidget(_host(
      GreetingCard(name: 'Aditi', now: DateTime(2026, 8, 31, 9)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aditi'), findsOneWidget);

    // The things the old hero carried, which the card below it already shows.
    expect(find.textContaining('CYCLE DAY'), findsNothing);
    expect(find.textContaining('PHASE'), findsNothing);
  });

  testWidgets('the greeting follows the local hour', (tester) async {
    // A health app gets opened at odd hours; "Good morning" at 11pm reads as a
    // machine talking.
    for (final entry in {9: 'morning', 14: 'afternoon', 21: 'evening'}.entries) {
      await tester.pumpWidget(_host(
        GreetingCard(name: 'Aditi', now: DateTime(2026, 8, 31, entry.key)),
      ));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(entry.value),
        findsOneWidget,
        reason: 'hour ${entry.key} should greet with "${entry.value}"',
      );
    }
  });

  testWidgets('the greeting is translated, not left in English', (tester) async {
    // The bottom navigation shipped a hardcoded English label while passing a
    // translated one to the screen reader, so this is worth pinning.
    await tester.pumpWidget(_host(
      GreetingCard(name: 'Aditi', now: DateTime(2026, 8, 31, 9)),
      locale: const Locale('hi'),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Good morning'), findsNothing,
        reason: 'the Hindi locale must not fall back to the English greeting');
    expect(find.textContaining('Aditi'), findsOneWidget);
  });
}
