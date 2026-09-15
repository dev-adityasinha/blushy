import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/features/home/home_screen.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// The home tab follows a stage change made elsewhere in the app, the way
/// Settings makes one: through the app state, with no restart.
void main() {
  useIsolatedStorage();

  testWidgets('changing the active stage swaps the home', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    AuthStorage.saveSession(token: 't', userId: 'u', email: 'a@b.c', role: 'woman', onboardingCompleted: true);
    BlushyStorage.write('user_profile.json', {
      'profile': {'lifeStage': 'reproductiveYears', 'activeLifeStages': ['reproductiveYears']},
    });
    final state = BlushyOSState();

    await withTestImages(() async {
      await tester.pumpWidget(BlushyOSProvider(
        notifier: state,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BlushyHomeScreen(),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('YOUR CYCLE'), findsOneWidget, reason: 'cycle home first');
      expect(find.text('BABY THIS WEEK'), findsNothing);

      // What Settings does once the server has agreed.
      state.setActiveLifeStages({'pregnancy'});
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('BABY THIS WEEK'), findsOneWidget, reason: 'pregnancy home after the change');
      expect(find.text('YOUR CYCLE'), findsNothing);

      state.setActiveLifeStages({'menopause'});
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('MY WELLBEING'), findsOneWidget, reason: 'menopause home after the change');
      expect(find.text('BABY THIS WEEK'), findsNothing);

      state.setActiveLifeStages({'reproductiveYears'});
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('YOUR CYCLE'), findsOneWidget, reason: 'and back');
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
