import 'package:blushy_life_app/core/stage_reconcile.dart';
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

/// The stage she chose last is the current one: on the home, in the account
/// list, and after a restart.
void main() {
  useIsolatedStorage();

  group('server names become app keys', () {
    test('every server id maps', () {
      expect(appStageKey('cycle_tracking'), 'reproductiveYears');
      expect(appStageKey('hormonal_health'), 'hormonalHealth');
      expect(appStageKey('ttc'), 'tryingToConceive');
      expect(appStageKey('first_period'), 'firstPeriodStarted');
      expect(appStageKey('everyday_wellness'), 'everydayWellness');
      expect(appStageKey('pregnancy'), 'pregnancy');
    });

    test('app keys pass through unchanged', () {
      for (final k in ['reproductiveYears', 'hormonalHealth', 'tryingToConceive', 'perimenopause', 'menopause']) {
        expect(appStageKey(k), k);
      }
    });
  });

  group('the current stage', () {
    test('is the one chosen last while it is active', () {
      expect(currentStageOf(['tryingToConceive', 'hormonalHealth'], 'hormonalHealth'), 'hormonalHealth');
      expect(currentStageOf(['hormonalHealth', 'tryingToConceive'], 'tryingToConceive'), 'tryingToConceive');
    });

    test('falls back to the ranking when the choice is gone or missing', () {
      expect(currentStageOf(['reproductiveYears', 'tryingToConceive'], 'pregnancy'), 'tryingToConceive');
      expect(currentStageOf(['reproductiveYears', 'tryingToConceive'], null), 'tryingToConceive');
    });

    test('wellness adds to a stage rather than replacing it', () {
      expect(currentStageOf(['reproductiveYears', 'everydayWellness'], 'everydayWellness'), 'reproductiveYears');
      expect(currentStageOf(['everydayWellness'], 'everydayWellness'), 'everydayWellness');
    });

    test('matches the server spelling of the choice', () {
      expect(currentStageOf(['reproductiveYears', 'hormonalHealth'], 'hormonal_health'), 'hormonalHealth');
    });
  });

  group('reconciling with the server after a restart', () {
    test('a stage already active leaves the list alone', () {
      expect(reconcileActiveStages({'reproductiveYears', 'hormonalHealth'}, 'hormonal_health'),
          {'reproductiveYears', 'hormonalHealth'});
    });

    test('a stage the server has but the list lacks is added as the latest', () {
      expect(reconcileActiveStages({'reproductiveYears'}, 'ttc').toList(), ['reproductiveYears', 'tryingToConceive']);
    });

    test('a stage that cannot sit beside the old ones replaces them', () {
      expect(reconcileActiveStages({'reproductiveYears', 'tryingToConceive'}, 'pregnancy'), {'pregnancy'});
    });

    test('no server stage, no change', () {
      expect(reconcileActiveStages({'menopause'}, null), {'menopause'});
    });
  });

  group('the app state', () {
    setUp(() {
      AuthStorage.saveSession(token: 't', userId: 'u', email: 'a@b.c', role: 'woman', onboardingCompleted: true);
      BlushyStorage.write('user_profile.json', {'profile': {'lifeStage': 'reproductiveYears', 'activeLifeStages': ['reproductiveYears']}});
    });

    test('the chosen stage becomes current, whatever its position', () {
      final state = BlushyOSState();
      state.setActiveLifeStages({'reproductiveYears', 'hormonalHealth'}, chosen: 'hormonalHealth');
      expect(state.personalContext.lifeStage, 'hormonalHealth');
      expect(state.personalContext.activeLifeStages, {'reproductiveYears', 'hormonalHealth'});
      final stored = BlushyStorage.read('user_profile.json')['profile'];
      expect(stored['lifeStage'], 'hormonalHealth');
    });

    test('removing a stage keeps the current one if it is still there', () {
      final state = BlushyOSState();
      state.setActiveLifeStages({'reproductiveYears', 'hormonalHealth'}, chosen: 'hormonalHealth');
      state.setActiveLifeStages({'hormonalHealth'});
      expect(state.personalContext.lifeStage, 'hormonalHealth');
    });
  });

  group('the home', () {
    Widget host(BlushyOSState state) => BlushyOSProvider(
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
        );

    testWidgets('shows the stage chosen last, not the higher-ranked one', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      AuthStorage.saveSession(token: 't', userId: 'u', email: 'a@b.c', role: 'woman', onboardingCompleted: true);
      BlushyStorage.write('user_profile.json', {'profile': {'lifeStage': 'tryingToConceive', 'activeLifeStages': ['tryingToConceive']}});
      final state = BlushyOSState();

      await withTestImages(() async {
        await tester.pumpWidget(host(state));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('FERTILITY TIMELINE'), findsOneWidget);

        // Adding Hormonal Health beside it: the page follows the choice.
        state.setActiveLifeStages({'tryingToConceive', 'hormonalHealth'}, chosen: 'hormonalHealth');
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('MY CYCLE HEALTH'), findsOneWidget, reason: 'hormonal home');
        expect(find.text('FERTILITY TIMELINE'), findsNothing);

        // Choosing Trying to Conceive again brings the fertility page back.
        state.setActiveLifeStages({'tryingToConceive', 'hormonalHealth'}, chosen: 'tryingToConceive');
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('FERTILITY TIMELINE'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      });
    });
  });
}
