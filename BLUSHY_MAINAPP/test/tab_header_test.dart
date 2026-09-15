import 'dart:io';

import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/shared/header.dart';
import 'package:blushy_life_app/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tab's name is a Blushy page, and says so.
///
/// The header printed the tab name in the same face and the same size as
/// BLUSHY. itself, so a screen title competed with the product wordmark. It is
/// set in the display face now, a quarter smaller, and ends on the same accent
/// full stop the wordmark does.
///
/// Docsy is the exception: it keeps its square mark, so the two names stay
/// tellable apart at a glance.

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

/// The rich text the header lays the title out with.
RichText _titleText(WidgetTester tester, String title) => tester.widget<RichText>(
      find
          .descendant(
            of: find.byType(BlushyHeader),
            matching: find.byType(RichText),
          )
          .first,
    );

void main() {
  test('the display face is shipped and declared as a bold', () {
    // Declaring the weight is what stops Flutter synthesising a second bold
    // on a face that is already one.
    expect(File('assets/fonts/AdaHybrid-Bold.ttf').existsSync(), isTrue);

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: AdaHybrid'));
    final block = pubspec.substring(pubspec.indexOf('family: AdaHybrid'));
    expect(block.substring(0, 140), contains('weight: 700'));
  });

  testWidgets('a tab name ends on the accent stop', (tester) async {
    await tester.pumpWidget(_host(
      const BlushyHeader(title: 'Community'),
    ));
    await tester.pumpAndSettle();

    final text = _titleText(tester, 'Community');
    final plain = text.text.toPlainText();
    expect(plain, 'COMMUNITY.');

    // The stop is the accent, not the brand red the name is set in.
    // Walked rather than indexed: RichText is free to nest the spans it is
    // given, and asserting on a position would pin that arrangement instead.
    Color? stopColour;
    text.text.visitChildren((span) {
      if (span is TextSpan && span.text == '.') stopColour = span.style?.color;
      return true;
    });
    expect(stopColour, BlushyColors.accent);
  });

  testWidgets('the name is set in the display face, a quarter smaller',
      (tester) async {
    await tester.pumpWidget(_host(const BlushyHeader(title: 'Partner')));
    await tester.pumpAndSettle();

    final style = _titleText(tester, 'Partner').text.style!;
    expect(style.fontFamily, 'AdaHybrid');
    expect(style.fontSize, closeTo(16.5, 0.01),
        reason: '22 was the wordmark size; a tab name is 75% of it');
    expect(style.color, BlushyColors.primary);
  });

  testWidgets('every tab gets one, and only one', (tester) async {
    for (final name in ['Home', 'Community', 'M Studio', 'Partner']) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_host(BlushyHeader(title: name)));
      await tester.pumpAndSettle();

      final plain = _titleText(tester, name).text.toPlainText();
      expect(plain, '${name.toUpperCase()}.', reason: name);
      expect('.'.allMatches(plain).length, 1, reason: '$name has two stops');
    }
  });

  testWidgets('Docsy keeps its square mark instead', (tester) async {
    await tester.pumpWidget(_host(const BlushyHeader(title: 'Docsy')));
    await tester.pumpAndSettle();

    // The square is a Container in the accent, drawn in a WidgetSpan -- so
    // the plain text carries the placeholder rather than a full stop.
    final square = find.byWidgetPredicate((w) =>
        w is Container &&
        w.color == BlushyColors.accent &&
        w.constraints != null &&
        w.constraints!.maxWidth == w.constraints!.maxHeight);
    expect(square, findsOneWidget);

    final plain = _titleText(tester, 'Docsy').text.toPlainText();
    expect(plain.startsWith('DOCSY'), isTrue);
    expect(plain.contains('.'), isFalse,
        reason: 'the square is the mark; a stop as well would be two');
  });

  testWidgets('the untitled header still shows BLUSHY. at its own size',
      (tester) async {
    // The wordmark is the product, not a tab, and was not shrunk with them.
    await tester.pumpWidget(_host(const BlushyHeader()));
    await tester.pumpAndSettle();

    final text = tester.widget<RichText>(
      find
          .descendant(
            of: find.byType(BlushyHeader),
            matching: find.byType(RichText),
          )
          .first,
    );
    expect(text.text.toPlainText(), 'BLUSHY.');
    expect(text.text.style?.fontSize, 22);
  });
}
