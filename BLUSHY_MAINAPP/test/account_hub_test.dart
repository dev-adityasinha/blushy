import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/home/widgets/my_health_screen.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// The account screen as a hub.
///
/// It used to be one long scroll of ten sections that wrote every keystroke
/// straight through to state, with "Log out" sitting directly under the
/// buttons that clear your history.
Future<void> _open(WidgetTester tester, {BlushyOSState? state}) async {
  AuthStorage.saveSession(
    token: 'test-token',
    userId: 'test-user',
    email: 'a@b.c',
    role: 'woman',
    onboardingCompleted: true,
  );

  await tester.pumpWidget(
    BlushyOSProvider(
      notifier: state ?? BlushyOSState(),
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MyHealthScreen(),
      ),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  useIsolatedStorage();

  testWidgets('every section is a card, with FAQ and sign out', (tester) async {
    await withTestImages(() async {
      await _open(tester);

      for (final section in const [
        'Personal Information',
        'Cycle Configuration',
        'Current Life Stage',
        'Diagnoses & Medical Conditions',
        'Health & Wellness Goals',
        'Primary Symptom Focus',
        'Medications & Supplements',
        'Privacy & Companion Memory',
        'Journal & Personalisation',
        'Manage My Data',
        'FAQ',
      ]) {
        await tester.scrollUntilVisible(find.text(section), 200);
        expect(find.text(section), findsOneWidget, reason: section);
      }
    });
  });

  testWidgets('sign out is the last thing on the page', (tester) async {
    await withTestImages(() async {
      await _open(tester);

      await tester.scrollUntilVisible(find.text('Sign Out'), 200);
      final signOut = tester.getRect(find.text('Sign Out'));
      final faq = tester.getRect(find.text('FAQ'));

      expect(signOut.top, greaterThan(faq.top),
          reason: 'it belongs at the end, not under the danger buttons');
      // The old placement, inside Manage My Data.
      expect(find.text('Log out'), findsNothing);
    });
  });

  testWidgets('a section is read-only until Edit, then saves', (tester) async {
    await withTestImages(() async {
      await _open(tester);

      await tester.tap(find.text('Personal Information'));
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // Opens read-only: Edit offered, Save not.
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.byType(IgnorePointer), findsWidgets);

      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Editing: Save and Cancel, and Edit is gone.
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Edit'), findsOneWidget, reason: 'back to read-only');

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets('period length is held until Save, and dropped on Cancel',
      (tester) async {
    // It used to go over the network on a 600ms debounce per keystroke, so
    // Save was not what committed it and Cancel did not undo it.
    await withTestImages(() async {
      // The cycle fields only render while tracking is on.
      final state = BlushyOSState();
      state.updatePersonalContext(state.personalContext
          .copyWith(trackingPreference: CycleTrackingPreference.enabled));
      await _open(tester, state: state);

      await tester.tap(find.text('Cycle Configuration'));
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      await tester.tap(find.text('Edit'));
      await tester.pump();

      final field = find.ancestor(
        of: find.text('Average Period Length (Days)'),
        matching: find.byType(TextField),
      );
      expect(field, findsOneWidget);

      await tester.enterText(field, '5');
      await tester.pump();

      // Nothing has left yet: the debounce that used to fire is gone.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('Edit'), findsOneWidget, reason: 'discarded');

      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    });
  });

  testWidgets('the FAQ answers real questions', (tester) async {
    await withTestImages(() async {
      await _open(tester);

      await tester.scrollUntilVisible(find.text('FAQ'), 200);
      await tester.tap(find.text('FAQ'));
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text('Is Docsy a doctor?'), findsOneWidget);
      expect(find.text('What can my partner see?'), findsOneWidget);

      await tester.tap(find.text('Is Docsy a doctor?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('never names a specific medicine'), findsOneWidget);
    });
  });
}
