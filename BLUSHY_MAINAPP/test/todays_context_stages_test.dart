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

/// The shared home sections have to appear whatever life stage she is in.
///
/// The home tab does not render one dashboard: it switches on the life stage
/// and calls one of ten builders, each with its own mobile, tablet and desktop
/// layout. Today's Context was first placed inside the CYCLE PATTERNS section,
/// which only `_buildLivingWithMyCycleHomeOS` renders -- so for nine stages out
/// of ten it was in the code and never on the screen.
///
/// Anything anchored to one branch of that switch fails the same way, and the
/// failure is invisible from the stage it was written against. This drives the
/// real dashboard once per stage.
void main() {
  useIsolatedStorage();

  setUp(() {
    // Taller than the 800x600 default. The dashboards are lazy scrollables,
    // so a section below the fold is never built and `find.text` cannot see
    // it -- and the three sections under test now sit one after another. The
    // width is unchanged, so the same layout branch is exercised.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(800, 6000);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    // Storage is namespaced per user and silently no-ops without a session.
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );
  });

  Widget host(String stageKey) => BlushyOSProvider(
        notifier: BlushyOSState(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: EverydayWellnessDashboard(stageKey: stageKey)),
        ),
      );

  // One key per branch of the switch in `build`, spelled the way onboarding
  // stores them.
  const everyStage = <String>[
    'firstPeriodStarted',
    'reproductiveYears',
    'livingWithMyCycle',
    'hormonalHealth',
    'tryingToConceive',
    'pregnancy',
    'postpartum',
    'perimenopause',
    'menopause',
    'everydayWellness',
    // Not a real stage: exercises the `default` arm, which any unrecognised
    // value from an older build or a new onboarding option lands on.
    'somethingUnrecognised',
  ];

  for (final stage in everyStage) {
    testWidgets("$stage shows the shared home sections", (tester) async {
      BlushyStorage.write('user_profile.json', {
        'profile': {'lifeStage': stage},
      });

      await withTestImages(() async {
        await tester.pumpWidget(host(stage));
        await tester.pump(const Duration(milliseconds: 300));

        // Two of these dashboards already overflow by ~4px at the 800x600 test
        // surface, before and after the change this file guards -- verified by
        // pumping both against the previous revision. Draining keeps that from
        // being reported as a failure of this test, which is about whether the
        // section renders at all, not about its layout.
        tester.takeException();

        expect(
          find.text("TODAY'S CONTEXT"),
          findsWidgets,
          reason: 'the $stage dashboard should render Today\'s Context',
        );
        expect(
          find.text('DOCSY INSIGHTS'),
          findsWidgets,
          reason: 'the $stage dashboard should render Docsy Insights',
        );
        expect(
          find.text('CYCLE PATTERNS & INSIGHTS'),
          findsWidgets,
          reason: 'the $stage dashboard should render Cycle Patterns',
        );
      });
    });
  }

  testWidgets("the pre-menarche stage withholds only Today's Context",
      (tester) async {
    // This one is a decision, not an oversight. That dashboard has no cycle
    // tracking and no daily check-in, and Today's Context is four cards of
    // cycle phase, sleep, energy and mood. Showing it here would offer someone
    // who has not had a period a cycle card reading "Not Logged".
    BlushyStorage.write('user_profile.json', {
      'profile': {'lifeStage': 'firstPeriodNotStarted'},
    });

    await withTestImages(() async {
      await tester.pumpWidget(host('firstPeriodNotStarted'));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException(); // Pre-existing overflow; see the note above.

      expect(find.text("TODAY'S CONTEXT"), findsNothing);
      // Docsy Insights and Cycle Patterns were asked for on all ten stages,
      // this one included, so only Today's Context is withheld here.
      expect(find.text('DOCSY INSIGHTS'), findsWidgets);
      expect(find.text('CYCLE PATTERNS & INSIGHTS'), findsWidgets);
    });
  });
}
