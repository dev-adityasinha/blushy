import 'package:blushy_life_app/core/stage_conflict_engine.dart';
import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/features/home/presentation/stages/everyday_wellness_dashboard.dart';
import 'package:blushy_life_app/features/home/symptom_categories.dart';
import 'package:blushy_life_app/features/home/widgets/home_hero.dart';
import 'package:blushy_life_app/features/home/widgets/symptom_log_sheet.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// The home and the symptom sheet follow the life stage.
///
/// A pregnant woman was asked for her menstrual flow and shown the period
/// tracker. Two things let that happen: with several stages active the home
/// took whichever was stored first, and pregnancy did not exclude the cycle
/// stages, so "reproductive years" stayed active beside it.
void main() {
  useIsolatedStorage();

  group('the stage that decides', () {
    test('pregnancy outranks a cycle stage, whatever the order', () {
      expect(StageConflictEngine.dominantStage(['reproductiveYears', 'pregnancy']), 'pregnancy');
      expect(StageConflictEngine.dominantStage(['pregnancy', 'reproductiveYears']), 'pregnancy');
    });

    test('trying to conceive outranks the plain cycle stage', () {
      expect(StageConflictEngine.dominantStage(['reproductiveYears', 'tryingToConceive']), 'tryingToConceive');
    });

    test('everyday wellness never replaces a stage', () {
      expect(StageConflictEngine.dominantStage(['everydayWellness', 'reproductiveYears']), 'reproductiveYears');
    });

    test('keys are matched loosely and a single stage is itself', () {
      expect(StageConflictEngine.dominantStage(['reproductive_years', 'Pregnancy']), 'Pregnancy');
      expect(StageConflictEngine.dominantStage(['postpartum']), 'postpartum');
      expect(StageConflictEngine.dominantStage(const []), isNull);
    });
  });

  group('no cycle stage beside pregnancy', () {
    test('choosing pregnancy removes reproductive years', () {
      final r = StageConflictEngine.checkConflict(
        currentActiveStages: {'reproductiveYears'},
        targetStage: 'pregnancy',
      );
      expect(r.hasConflict, isTrue);
      expect(r.conflictingActiveStages, contains('reproductiveYears'));
    });

    test('and the other way round', () {
      final r = StageConflictEngine.checkConflict(
        currentActiveStages: {'pregnancy'},
        targetStage: 'reproductiveYears',
      );
      expect(r.hasConflict, isTrue);
    });

    test('postpartum excludes the cycle stages too', () {
      final r = StageConflictEngine.checkConflict(
        currentActiveStages: {'hormonalHealth', 'perimenopause'},
        targetStage: 'postpartum',
      );
      expect(r.conflictingActiveStages, containsAll(['hormonalHealth', 'perimenopause']));
    });

    test('first period (started) and reproductive years never sit together', () {
      final r = StageConflictEngine.checkConflict(
        currentActiveStages: {'firstPeriodStarted'},
        targetStage: 'reproductiveYears',
      );
      expect(r.conflictingActiveStages, contains('firstPeriodStarted'));
    });

    test('trying to conceive still sits beside the cycle stage', () {
      final r = StageConflictEngine.checkConflict(
        currentActiveStages: {'reproductiveYears'},
        targetStage: 'tryingToConceive',
      );
      expect(r.hasConflict, isFalse);
    });
  });

  group('symptom groups per stage', () {
    List<String> ids(String stage) =>
        SymptomCategories.forStage(stage).map((c) => c.id).toList();

    test('pregnancy is not asked for menstrual flow', () {
      expect(ids('pregnancy'), isNot(contains('flow')));
      expect(ids('pregnancy'), containsAll(['fetal_movement', 'contractions']));
    });

    test('postpartum and menopause are not asked either', () {
      expect(ids('postpartum'), isNot(contains('flow')));
      expect(ids('menopause'), isNot(contains('flow')));
    });

    test('trying to conceive is: she still has a cycle', () {
      expect(ids('tryingToConceive'), containsAll(['flow', 'pregnancy_test', 'ovulation_test']));
    });

    testWidgets('the sheet opened for pregnancy shows no flow group', (tester) async {
      // Tall enough for every group to be built, so a group's absence means
      // it was not offered rather than not yet scrolled to.
      final view = tester.view;
      view.physicalSize = const Size(800, 6000);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SymptomLogSheet(
            stage: 'pregnancy',
            initialSelection: const {},
            onSave: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // Group titles are drawn in capitals.
      expect(find.text('MENSTRUAL FLOW'), findsNothing);
      expect(find.text('BABY MOVEMENT'), findsOneWidget);
      expect(find.text('MOOD'), findsOneWidget);
    });
  });

  group('the home with several stages active', () {
    setUp(() {
      final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
      view.physicalSize = const Size(800, 6000);
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
        'profile': {'lifeStage': 'reproductiveYears'},
      });
    });

    Widget host(List<String> stages) => BlushyOSProvider(
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
              body: EverydayWellnessDashboard(activeStages: stages),
            ),
          ),
        );

    testWidgets('pregnancy beside a cycle stage hides the period tracker', (tester) async {
      await tester.pumpWidget(host(['reproductiveYears', 'pregnancy']));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(CycleRingCard), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('trying to conceive beside a cycle stage shows the fertility home', (tester) async {
      await tester.pumpWidget(host(['reproductiveYears', 'tryingToConceive']));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('FERTILITY TIMELINE'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('two stages never render the composite with a header per stage', (tester) async {
      await tester.pumpWidget(host(['reproductiveYears', 'everydayWellness']));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('FOCUS TOPIC'), findsNothing);
      expect(find.byType(CycleRingCard), findsOneWidget, reason: 'wellness never replaces the cycle home');
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
