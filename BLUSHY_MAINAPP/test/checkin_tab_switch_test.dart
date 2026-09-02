import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/features/home/presentation/stages/everyday_wellness_dashboard.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// A check-in tap has to reach the device, not only the server.
///
/// The selector wrote the value to the backend and nowhere else, while the
/// dashboard restores these fields from `daily_checkin.json` on every reload —
/// and changing tabs causes a reload. So the file still held the previous
/// answer and put it straight back.
///
/// This drives the real dashboard rather than reading its source.
void main() {
  useIsolatedStorage();

  setUp(() {
    // A taller surface than the 800x600 default.
    //
    // The dashboard is a lazy scrollable, so only what fits is built, and
    // `find.text` cannot see the rest. Today's Context now renders above the
    // summary on every stage, which pushed "TODAY'S LOGGED SIGNALS" off a
    // 600px surface and left this test looking at a value that was never
    // built. The width is unchanged so the same tablet layout is exercised;
    // the pain cards sit far below either height and stay unbuilt, which the
    // last assertion depends on.
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(800, 1200);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    // Storage is namespaced per user and silently no-ops without a session,
    // so every fixture below would be discarded without this.
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );

    // The pain card is gated on her onboarding answers.
    BlushyStorage.write('user_profile.json', {
      'profile': {
        'lifeStage': 'reproductiveYears',
        'symptoms': ['Cramps', 'Fatigue'],
        'goals': ['Reduce cramps & discomfort'],
        'answers': {
          'symptoms': ['Cramps', 'Fatigue'],
          'goals': ['Reduce cramps & discomfort'],
        },
      },
    });
  });

  Widget host() => BlushyOSProvider(
        notifier: BlushyOSState(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: EverydayWellnessDashboard(stageKey: 'reproductiveYears'),
          ),
        ),
      );

  testWidgets('the summary shows the option she picked, not the old one',
      (tester) async {
    // What the device already holds. This is the value that kept coming back.
    BlushyStorage.write('daily_checkin.json', {
      'pain': 'Severe',
      'date': DateTime.now().toIso8601String(),
    });

    await withTestImages(() async {
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 300));

      // Top of the page: "TODAY'S LOGGED SIGNALS" reads the stored answer.
      expect(find.text('Severe'), findsWidgets,
          reason: 'the stored answer should be showing to begin with');

      // The card is below the fold, and the dashboard is a lazy scrollable.
      await tester.scrollUntilVisible(
        find.text('PAIN LEVEL'),
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
      await tester.pump();

      final painCard = find.ancestor(
        of: find.text('PAIN LEVEL'),
        matching: find.byType(Column),
      );
      await tester.tap(
        find.descendant(of: painCard.first, matching: find.text('Mild')),
        warnIfMissed: false,
      );
      await tester.pump();

      // The reload a tab change causes, in its harshest form.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 300));
    });

    // Network calls fail under the test binding; not the subject here.
    tester.takeException();

    // Scoped to the summary's own "Pain" row rather than the whole page.
    //
    // This used to search the page, on the grounds that the pain cards were
    // below the fold and unbuilt, so any Mild or Severe on screen had to be
    // the summary. The check-in now sits near the top of every dashboard, so
    // those cards are built and offer "Severe" as an unselected option -- true
    // of the page, and nothing to do with what the summary reports.
    final painRow = find.ancestor(
      of: find.text('Pain'),
      matching: find.byType(Row),
    );
    expect(painRow, findsWidgets, reason: 'the summary row should be built');
    expect(
      find.descendant(of: painRow.first, matching: find.text('Mild')),
      findsOneWidget,
      reason: 'her answer must be what the summary shows after a reload',
    );
    expect(
      find.descendant(of: painRow.first, matching: find.text('Severe')),
      findsNothing,
      reason: 'the previous answer must not come back — this is the bug',
    );
  });

  testWidgets('and the value survives the screen being rebuilt', (tester) async {
    BlushyStorage.write('daily_checkin.json', {
      'pain': 'Severe',
      'date': DateTime.now().toIso8601String(),
    });

    await withTestImages(() async {
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 300));

      await tester.scrollUntilVisible(
        find.text('PAIN LEVEL'),
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
      await tester.pump();

      final painCard = find.ancestor(
        of: find.text('PAIN LEVEL'),
        matching: find.byType(Column),
      );
      await tester.tap(
        find.descendant(of: painCard.first, matching: find.text('Mild')),
        warnIfMissed: false,
      );
      await tester.pump();

      // Worst case: the dashboard is built from nothing, as it would be after
      // navigating away and back. It must come back showing her answer.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 300));
    });

    tester.takeException();

    expect(BlushyStorage.read('daily_checkin.json')['pain'], 'Mild');
  });
}
