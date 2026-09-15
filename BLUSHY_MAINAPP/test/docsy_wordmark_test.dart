import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/shared/docsy_wordmark.dart';
import 'package:blushy_life_app/shared/bottom_navigation.dart';
import 'package:blushy_life_app/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Docsy carries a square orange mark, the way BLUSHY. carries a round one.
///
/// The mark belongs to the name standing alone — the tab, the header that
/// names it, the button that opens it. It is deliberately absent from prose:
/// a mark in the middle of "Changes the language Docsy replies in" reads as a
/// typo, not a wordmark, and there are 27 such strings.

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

/// The square itself: a Container painted in the accent, with equal sides.
Finder _mark() => find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final box = w.constraints;
      return w.color == BlushyColors.accent &&
          box != null &&
          box.maxWidth == box.maxHeight &&
          box.maxWidth > 0;
    });

void main() {
  testWidgets('the mark is square, and in the accent orange', (tester) async {
    await tester.pumpWidget(_host(
      const DocsyWordmark(text: 'Docsy', style: TextStyle(fontSize: 20)),
    ));

    expect(_mark(), findsOneWidget, reason: 'the wordmark should paint a mark');

    final container = tester.widget<Container>(_mark());
    final box = container.constraints!;
    expect(box.maxWidth, box.maxHeight, reason: 'square, not round');
    expect(container.color, BlushyColors.accent, reason: '#FF4A00');

    // A BoxDecoration with a radius would round the corners off again.
    expect(container.decoration, isNull);
  });

  testWidgets('the mark scales with the text it sits beside', (tester) async {
    await tester.pumpWidget(_host(
      const Column(children: [
        DocsyWordmark(text: 'Docsy', style: TextStyle(fontSize: 10.5)),
        DocsyWordmark(text: 'DOCSY', style: TextStyle(fontSize: 22)),
      ]),
    ));

    final sides = tester
        .widgetList<Container>(_mark())
        .map((c) => c.constraints!.maxWidth)
        .toList();
    expect(sides.length, 2);
    expect(sides[1], greaterThan(sides[0]),
        reason: 'a mark fixed in size looks wrong at one of the two');
  });

  testWidgets('the name is still readable as text', (tester) async {
    // The mark is a WidgetSpan inside the text, so the name must still be
    // findable and still ellipsize — several translations are much longer.
    await tester.pumpWidget(_host(
      const DocsyWordmark(
        text: 'Docsy',
        style: TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ));

    expect(find.textContaining('Docsy', findRichText: true), findsOneWidget);
  });

  testWidgets('the Docsy tab wears it and the other tabs do not',
      (tester) async {
    await tester.pumpWidget(_host(
      BlushyBottomNavigation(
        currentIndex: BlushyBottomNavigation.siaIndex,
        onTap: (_) {},
      ),
    ));
    await tester.pump();

    expect(_mark(), findsOneWidget,
        reason: 'exactly one tab is Docsy, so exactly one mark');
  });
}
