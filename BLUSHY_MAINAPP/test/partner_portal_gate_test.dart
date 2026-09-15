import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/partner/partner_screen.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// The partner portal before there is a partner.
///
/// The card used to announce the absence ("No partner paired yet") and put a
/// small Connect button beside an icon, while every shared action below it
/// looked available and opened an empty room. Now the card centres on the one
/// thing to do, and the shared actions say why they are closed.
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
        home: const BlushyPartnerScreen(),
      ),
    ),
  );
  // The screen fires several requests on open; they are stubbed and fail, but
  // their timers still have to land before the test ends.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  useIsolatedStorage();

  testWidgets('the unpaired card says what to do, not what is missing',
      (tester) async {
    await withTestImages(() async {
      await _open(tester);

      expect(find.text('Partner Portal'), findsOneWidget);
      expect(find.text('Send an invite to begin sharing'), findsOneWidget);
      expect(find.textContaining('No partner paired yet'), findsNothing,
          reason: 'the card no longer announces the absence');
    });
  });

  testWidgets('the shared actions are shown as closed', (tester) async {
    await withTestImages(() async {
      await _open(tester);

      // Every quick action is a shared space, so with no partner they all
      // carry a lock rather than their own icon.
      expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
    });
  });

  testWidgets('every shared action is a card, the same shape as Invite',
      (tester) async {
    // They were a scrolling row of chips above the list, which meant two
    // visual languages for the same set of destinations.
    await withTestImages(() async {
      await _open(tester);

      expect(find.text('Your Timeline'), findsNothing,
          reason: 'the heading is gone; the cards speak for themselves');

      double cardWidth(String label) => tester
          .getSize(find
              .ancestor(of: find.text(label), matching: find.byType(InkWell))
              .first)
          .width;

      expect(cardWidth('Bouquet'), cardWidth('Invite Your Partner'),
          reason: 'an action renders exactly like the invite card');
      expect(cardWidth('Message'), cardWidth('Invite Your Partner'));
    });
  });

  testWidgets('a locked action is faded, not just padlocked', (tester) async {
    await withTestImages(() async {
      await _open(tester);

      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Bouquet').first,
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, lessThan(1.0));
    });
  });

  testWidgets('the shared garden is gated too', (tester) async {
    // It grows on the server for both of you, so alone it is the same empty
    // room as the tabs.
    await withTestImages(() async {
      await _open(tester);

      // It sits below the fold, so a bare tap lands on nothing.
      await tester.ensureVisible(find.text('Garden Blossoming').first);
      await tester.pump();
      await tester.tap(find.text('Garden Blossoming').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('This one needs two'), findsOneWidget);
    });
  });

  testWidgets('tapping one explains why, and offers Close or Connect',
      (tester) async {
    await withTestImages(() async {
      await _open(tester);

      // A card in the list, so it may sit below the fold.
      await tester.ensureVisible(find.text('Shared Activity').first);
      await tester.pump();
      await tester.tap(find.text('Shared Activity').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('This one needs two'), findsOneWidget);

      // Scoped to the dialog: the card behind it has a Connect button too.
      Finder inDialog(String label) => find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(label),
          );
      expect(inDialog('Close'), findsOneWidget);
      expect(inDialog('Connect'), findsOneWidget);

      // Close puts it away without going anywhere.
      await tester.tap(inDialog('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('This one needs two'), findsNothing);
    });
  });
}
