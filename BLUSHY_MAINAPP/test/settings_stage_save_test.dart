import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/features/home/settings_draft.dart';
import 'package:blushy_life_app/features/home/widgets/stage_questionnaire_dialog.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// Two reports from the Settings page: a stage change that came back after
/// Save, and questionnaire options that would not select.
void main() {
  useIsolatedStorage();

  setUp(() {
    AuthStorage.saveSession(token: 't', userId: 'u', email: 'a@b.c', role: 'woman', onboardingCompleted: true);
    BlushyStorage.write('user_profile.json', {'profile': {'lifeStage': 'reproductiveYears'}});
  });

  group('Save on Settings keeps a stage changed meanwhile', () {
    test('the draft carries its edits, the live profile its stages', () {
      final snapshot = BlushyOSState().personalContext.copyWith(
        userName: 'Old',
        lifeStage: 'reproductiveYears',
        activeLifeStages: const {'reproductiveYears'},
      );
      final draft = snapshot.copyWith(userName: 'Zaid', weight: 58.0);
      final live = snapshot.copyWith(lifeStage: 'pregnancy', activeLifeStages: const {'pregnancy'});

      final committed = keepCurrentStages(draft, live);
      expect(committed.userName, 'Zaid');
      expect(committed.weight, 58.0);
      expect(committed.lifeStage, 'pregnancy');
      expect(committed.activeLifeStages, {'pregnancy'});
    });

    test('through the app state: a stale draft no longer reverts the stage', () {
      final state = BlushyOSState();
      final snapshot = state.personalContext; // what Edit captured
      state.setActiveLifeStages({'pregnancy'}); // the selector, meanwhile
      expect(state.personalContext.activeLifeStages, {'pregnancy'});

      // Save: the old way wrote the snapshot back.
      state.updatePersonalContext(keepCurrentStages(snapshot.copyWith(userName: 'Zaid'), state.personalContext));
      expect(state.personalContext.activeLifeStages, {'pregnancy'});
      expect(state.personalContext.lifeStage, 'pregnancy');
      expect(state.personalContext.userName, 'Zaid');
    });
  });

  group('the stage questionnaire selects', () {
    Widget host(String stage, String title) => BlushyOSProvider(
          notifier: BlushyOSState(),
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: StageQuestionnaireDialog(stageKey: stage, stageTitle: title),
            ),
          ),
        );

    ElevatedButton continueButton(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue'));

    Future<void> tall(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
    }

    testWidgets('a single-choice answer enables Continue and moves on', (tester) async {
      await tall(tester);
      await tester.pumpWidget(host('tryingToConceive', 'Trying to Conceive'));
      await tester.pumpAndSettle();

      expect(continueButton(tester).onPressed, isNull, reason: 'nothing chosen yet');
      await tester.tap(find.text('More than 12 months'));
      await tester.pumpAndSettle();
      expect(continueButton(tester).onPressed, isNotNull, reason: 'a choice was made');

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Basal Body Temperature (BBT)'), findsOneWidget, reason: 'second question is showing');
      expect(continueButton(tester).onPressed, isNull);
      await tester.tap(find.text('Basal Body Temperature (BBT)'));
      await tester.pumpAndSettle();
      expect(continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('a multi-choice answer toggles on and off', (tester) async {
      await tall(tester);
      await tester.pumpWidget(host('hormonalHealth', 'Hormonal Health'));
      await tester.pumpAndSettle();

      expect(continueButton(tester).onPressed, isNull);
      await tester.tap(find.text('Endometriosis'));
      await tester.pumpAndSettle();
      expect(continueButton(tester).onPressed, isNotNull, reason: 'one condition picked');
      await tester.tap(find.text('Endometriosis'));
      await tester.pumpAndSettle();
      expect(continueButton(tester).onPressed, isNull, reason: 'picked again clears it');
    });

    testWidgets('single then multi, through Continue', (tester) async {
      await tall(tester);
      await tester.pumpWidget(host('menopause', 'Menopause'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Under 12 months'));
      await tester.pumpAndSettle();
      expect(continueButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continueButton(tester).onPressed, isNull, reason: 'symptoms step starts empty');
      await tester.tap(find.text('Hot flashes & vasomotor symptoms'));
      await tester.pumpAndSettle();
      expect(continueButton(tester).onPressed, isNotNull);
    });
  });
}
