import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/partner/partner_screen.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// The Shared Sanctuary before there is a partner.
///
/// The legacy screen showed a heart, disabled cards at 55% opacity, padlocks,
/// and blocking alerts ("This one needs two").
/// The Shared Sanctuary redesign provides an editorial, aspirational preview:
/// "YOUR SHARED SPACE", "A little space for the two of you", and an aspirational
/// preview of Blooms, Letters, Memories, and Messages with zero padlocks.
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
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  useIsolatedStorage();

  testWidgets('the unpaired sanctuary presents a warm editorial welcome',
      (tester) async {
    await withTestImages(() async {
      await _open(tester);

      expect(find.text('YOUR SHARED SPACE'), findsOneWidget);
      expect(find.text('A little space for the two of you.'), findsOneWidget);
      // The header no longer carries its own invite button (removed by request);
      // the single "Invite Your Partner" CTA lower down is the way in.
      expect(find.textContaining('No partner paired yet'), findsNothing,
          reason: 'the screen does not announce absence as an error');
    });
  });

  testWidgets('the aspirational preview showcases features without padlocks',
      (tester) async {
    await withTestImages(() async {
      await _open(tester);

      expect(find.text('WHAT YOU\'LL HAVE TOGETHER'), findsOneWidget);
      expect(find.textContaining('Blooms'), findsOneWidget);
      expect(find.textContaining('Letters'), findsOneWidget);
      expect(find.textContaining('Memory'), findsOneWidget);
      expect(find.textContaining('Sharing'), findsOneWidget);

      // No padlocks or disabled opacity on the aspirational features
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing,
          reason: 'features are presented aspirationally, not as locked gates');
    });
  });

  testWidgets('invite partner triggers the partner connection flow',
      (tester) async {
    await withTestImages(() async {
      await _open(tester);

      // Tap the primary invite CTA (lower down the aspirational preview). Scroll
      // to build it in the lazy list, then ensure it is fully on-screen so the
      // tap lands rather than hitting the viewport edge.
      final invite = find.text('Invite Your Partner');
      await tester.scrollUntilVisible(
        invite,
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(invite);
      await tester.pumpAndSettle();
      await tester.tap(invite);
      await tester.pumpAndSettle();

      // Opens the partner connections modal
      expect(find.text('Partner Connections'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);
    });
  });
}
