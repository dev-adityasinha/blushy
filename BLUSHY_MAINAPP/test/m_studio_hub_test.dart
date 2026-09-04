import 'dart:io';

import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/m_studio/m_studio_screen.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// M Studio as a hub.
///
/// It used to open on three horizontal tabs, with the journal's other eight
/// destinations buried in a bottom sheet inside an embedded journal — and the
/// first thing on screen was a fixed "Continue Yesterday" card, two prompts
/// picked by life stage, and an "AI reflection" that was a hardcoded string.
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
        home: const BlushyMStudioScreen(),
      ),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  useIsolatedStorage();

  test('the bouquet opens without a partner, with sending disabled', () {
    // The image share works for anyone; sending needs a connection. Opened
    // from M Studio there is none, so the button is visibly disabled with the
    // reason under it rather than live and failing on tap.
    final studio = File(
      'lib/features/m_studio/m_studio_screen.dart',
    ).readAsStringSync();
    expect(studio.contains('activeConnections: const []'), isTrue,
        reason: 'no connection means no partner send');

    final builder = File(
      'lib/features/partner/digibouquet/screens/builder_screen.dart',
    ).readAsStringSync();
    expect(builder.contains('bool get _canSendToPartner'), isTrue);
    expect(
      builder.contains('onPressed: (!_canSendToPartner || _isSendingBouquet)'),
      isTrue,
      reason: 'the button must be disabled, not merely fail when tapped',
    );
    expect(builder.contains('Connect a partner to send this to them'), isTrue,
        reason: 'a disabled button needs to say why');
  });

  test('the dashboard asks the shell for a tab, it does not push one', () {
    // Four buttons pushed a second BlushyMStudioScreen on top of the shell,
    // which arrives with no bottom bar and no way back to the tabs.
    final dashboard = File(
      'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart',
    ).readAsStringSync();

    expect(dashboard.contains('const BlushyMStudioScreen()'), isFalse,
        reason: 'M Studio is a tab, not a route to stack');
    expect(dashboard.contains('BlushyShellTabs.open(BlushyShellTabs.mStudio)'),
        isTrue);
  });

  testWidgets('it opens on the hub, one card per area', (tester) async {
    await withTestImages(() async {
      await _open(tester);

      for (final section in const [
        'Journal',
        'Recovery',
        'Time Capsules',
        'Bouquet',
      ]) {
        expect(find.text(section), findsOneWidget, reason: section);
      }

      // Both moved inside Journal.
      expect(find.text('Reflection'), findsNothing);
      expect(find.text('Scrapbook'), findsNothing);

      // These four were taken off the hub. They are still in the app, reached
      // from inside Journal, which is where the writing they read lives -- so
      // the check is that the hub no longer offers them, not that they are
      // gone.
      for (final removed in const [
        'Smart Calendar & Map',
        'Smart AI Search',
        'Memory Vault',
        'Reflective Content Garden',
      ]) {
        expect(find.text(removed), findsNothing, reason: removed);
      }
    });
  });

  testWidgets('the four removed blocks are gone', (tester) async {
    await withTestImages(() async {
      await _open(tester);

      expect(find.text('Continue Yesterday'), findsNothing);
      expect(find.text('SUGGESTED PROMPTS'), findsNothing);
      expect(find.textContaining('AI REFLECTION'), findsNothing);
      expect(find.text('CREATIVE JOURNAL'), findsNothing);
    });
  });

  testWidgets('opening Journal goes straight to the writing', (tester) async {
    // It used to open a hub of two cards -- Reflection and Scrapbook -- so
    // opening the journal meant choosing between two things before writing
    // anything. Both are gone; this is the guard that they stay gone.
    await withTestImages(() async {
      await _open(tester);

      await tester.tap(find.text('Journal'));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text('Reflection'), findsNothing);
      expect(find.text('Scrapbook'), findsNothing);

      // The journal itself: what is in it, and a button to write the next one.
      expect(find.byType(FloatingActionButton), findsOneWidget,
          reason: 'the round button is how a new entry is started');

      // A pushed route, so the hub is no longer on screen behind it.
      expect(find.text('Recovery'), findsNothing);

      await tester.pageBack();
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('Recovery'), findsOneWidget, reason: 'back to the hub');

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets('the insights dashboard belongs to Journal alone', (tester) async {
    // Every section that was not Journal, Recovery or Time Capsules used to
    // fall through to the journal page -- so Smart Calendar
    // rendered the journal, and its cards appeared under all of them.
    await withTestImages(() async {
      await _open(tester);

      await tester.tap(find.text('Recovery'));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text('Journal Insights Dashboard'), findsNothing,
          reason: 'Recovery is not the journal');
      expect(find.text('Record & Transcribe'), findsNothing);
      expect(find.text('Start a Session'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });
}
