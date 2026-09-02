import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/features/home/blushy_shell.dart';
import 'package:blushy_life_app/features/home/presentation/stages/everyday_wellness_dashboard.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// "Open Discussions" has to open the discussions.
///
/// The card it sits under says "Open the community to read and reply" twice.
/// The button showed a snackbar reading "Loading Community discussions..." and
/// then did nothing -- so the two lines of copy were accurate about what the
/// app offered and the only control that would deliver it was inert.
///
/// A stub like this cannot be caught by reading the code around it: the
/// handler is present, it compiles, and it even puts something on screen.
void main() {
  useIsolatedStorage();

  setUp(() {
    // Tall enough that the section is built; the dashboard is a lazy
    // scrollable and an unbuilt button cannot be tapped.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(800, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );
    BlushyStorage.write('user_profile.json', {
      'profile': {'lifeStage': 'firstPeriodStarted'},
    });

    // Shared notifier, so a value left behind would leak into other tests.
    BlushyShellTabs.requested.value = null;
    addTearDown(() => BlushyShellTabs.requested.value = null);
  });

  testWidgets('asks the shell for the Community tab', (tester) async {
    await withTestImages(() async {
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
            home: const Scaffold(
              body: EverydayWellnessDashboard(stageKey: 'firstPeriodStarted'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final button = find.text('Open Discussions');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
      await tester.pump();

      // Layout overflows on this dashboard predate this test; see
      // todays_context_stages_test.dart.
      tester.takeException();

      expect(BlushyShellTabs.requested.value, isNull,
          reason: 'nothing should be requested before the tap');

      await tester.tap(button, warnIfMissed: false);
      await tester.pump();

      expect(
        BlushyShellTabs.requested.value,
        BlushyShellTabs.community,
        reason: 'the button must switch to the Community tab',
      );
    });
  });
}
