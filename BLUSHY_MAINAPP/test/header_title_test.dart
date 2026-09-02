import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/shared/bottom_navigation.dart';
import 'package:blushy_life_app/shared/header.dart';
import 'package:blushy_life_app/theme/colors.dart';

import 'helpers/isolated_storage.dart';

/// The header names where you are.
///
/// It used to show the BLUSHY. wordmark on all five tabs. The wordmark is
/// identical everywhere, so it told you nothing about which tab you were on --
/// the one place in the app with room for that answer was spending it on a
/// constant. Home keeps the wordmark; the rest name themselves.
Widget _host(Widget child, {Size? size}) => MediaQuery(
      data: MediaQueryData(size: size ?? const Size(400, 800)),
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(appBar: child as PreferredSizeWidget),
      ),
    );

/// The wordmark is a RichText, and so is every Text -- match on the content.
Finder _wordmark() => find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText() == 'BLUSHY.',
    );

void main() {
  useIsolatedStorage();

  testWidgets('home shows the wordmark', (tester) async {
    await tester.pumpWidget(_host(const BlushyHeader()));
    await tester.pumpAndSettle();

    expect(_wordmark(), findsOneWidget);
  });

  testWidgets('any other tab shows its own name instead', (tester) async {
    await tester.pumpWidget(_host(const BlushyHeader(title: 'Community')));
    await tester.pumpAndSettle();

    expect(find.text('COMMUNITY'), findsOneWidget);
    expect(_wordmark(), findsNothing,
        reason: 'the tab name replaces the wordmark rather than joining it');
  });

  testWidgets('the name is set in caps, in the wordmark red', (tester) async {
    await tester.pumpWidget(_host(const BlushyHeader(title: 'M Studio')));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('M STUDIO'));
    expect(text.style?.color, BlushyColors.primary,
        reason: 'the same red the wordmark uses, not a near miss');
  });

  testWidgets('the name is set at the same size as the wordmark',
      (tester) async {
    // Switching tabs should change the word in the header, not the size of it.
    await tester.pumpWidget(_host(const BlushyHeader()));
    await tester.pumpAndSettle();
    final mark = tester.widget<RichText>(_wordmark());
    final markSize = (mark.text as TextSpan).style?.fontSize;

    await tester.pumpWidget(_host(const BlushyHeader(title: 'Community')));
    await tester.pumpAndSettle();
    final nameSize = tester.widget<Text>(find.text('COMMUNITY')).style?.fontSize;

    expect(markSize, isNotNull);
    expect(nameSize, markSize);
  });

  testWidgets('screen readers get the name as written, not the caps',
      (tester) async {
    // Some readers spell an uppercase word out letter by letter, so the caps
    // stay a visual treatment rather than becoming the label.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const BlushyHeader(title: 'Community')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Community'), findsOneWidget);
    expect(find.bySemanticsLabel('COMMUNITY'), findsNothing);
    handle.dispose();
  });

  testWidgets('the account and language controls stay on every tab',
      (tester) async {
    // The point of moving the wordmark out was to name the tab, not to lose
    // the two controls that live up here.
    for (final title in <String?>[null, 'M Studio']) {
      await tester.pumpWidget(_host(BlushyHeader(title: title)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.language_rounded), findsOneWidget,
          reason: 'language, with title=$title');
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget,
          reason: 'account, with title=$title');
    }
  });

  testWidgets('a long name ellipsizes rather than overflowing the controls',
      (tester) async {
    // Several translations are far longer than the English, and the controls
    // are on the same row.
    await tester.pumpWidget(_host(
      const BlushyHeader(title: 'Ein sehr langer Registerkartenname hier'),
      size: const Size(320, 640),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget,
        reason: 'the controls are not pushed off the edge');

    final text = tester.widget<Text>(
      find.text('EIN SEHR LANGER REGISTERKARTENNAME HIER'),
    );
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
  });

  testWidgets('the header names the tab the bar highlights', (tester) async {
    // The header takes the name by index. If that list ever stopped matching
    // the bar's order, every tab would be labelled as its neighbour -- which
    // is exactly the kind of thing that reads as correct until you tap.
    late AppLocalizations t;
    await tester.pumpWidget(_host(
      PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Builder(builder: (context) {
          t = AppLocalizations.of(context);
          return const SizedBox.shrink();
        }),
      ),
    ));
    await tester.pumpAndSettle();

    final labels = BlushyBottomNavigation.labelsFor(t);
    expect(labels, hasLength(5));
    expect(labels[0], t.navHome);
    expect(labels[BlushyBottomNavigation.siaIndex], t.navSia);
    expect(labels[4], t.navPartner);

    // And the bar renders those same names, in those same slots.
    await tester.pumpWidget(_host(
      PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: BlushyBottomNavigation(currentIndex: 0, onTap: (_) {}),
      ),
    ));
    await tester.pumpAndSettle();

    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
