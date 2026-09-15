import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/features/home/home_section_order.dart';
import 'package:blushy_life_app/features/home/presentation/stages/everyday_wellness_dashboard.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// The home reads the onboarding picks and puts what she asked for first.
void main() {
  useIsolatedStorage();

  HomeSection sec(String tag, {bool pinned = false}) =>
      HomeSection(tag, Text(tag), pinned: pinned);
  List<String> tags(List<HomeSection> l) => l.map((s) => s.tag).toList();

  group('ordering', () {
    final home = [
      sec('cycle', pinned: true),
      sec('checkin', pinned: true),
      sec('insights'),
      sec('patterns'),
      sec('partner'),
      sec('careplan'),
      sec('appointments'),
      sec('learn'),
      sec('journey'),
    ];

    test('nothing picked keeps the fixed order', () {
      expect(tags(HomeSectionOrder.order(home)), tags(home));
    });

    test('a pick moves its sections up, pinned ones stay put', () {
      final out = HomeSectionOrder.order(home, goals: ['Appointments']);
      expect(tags(out).sublist(0, 4), ['cycle', 'checkin', 'appointments', 'careplan']);
      // Everything else keeps its original relative order.
      expect(tags(out).sublist(4), ['insights', 'patterns', 'partner', 'learn', 'journey']);
    });

    test('picks rank in the order she chose them', () {
      final out = HomeSectionOrder.order(home, goals: ['Nutrition', 'Mood']);
      // Nutrition -> careplan first; Mood -> reflection (absent) then insights.
      expect(tags(out).sublist(2, 4), ['careplan', 'insights']);
    });

    test('goals outrank symptoms', () {
      final out = HomeSectionOrder.order(home, goals: ['Understanding my body'], symptoms: ['Cramps']);
      expect(tags(out)[2], 'learn');
      expect(tags(out)[3], 'patterns');
    });

    test('unknown picks change nothing', () {
      expect(tags(HomeSectionOrder.order(home, goals: ['Something new'])), tags(home));
    });

    test('layout puts the gap between sections only', () {
      final widgets = HomeSectionOrder.layout(home.sublist(0, 3), gap: const SizedBox(height: 1));
      expect(widgets.length, 5);
      expect(widgets[1], isA<SizedBox>());
      expect(widgets.last, isA<Text>());
    });
  });

  group('pick tags', () {
    test('cover every wizard pick family', () {
      for (final pick in [
        'Predict periods', 'Reduce cramps', 'PMS', 'Mood', 'Sleep', 'Energy', 'Acne', 'Ovulation',
        'Fitness', 'Nutrition', 'Walking', 'Yoga', 'Strength', 'Stress', 'Medication reminders',
        'Baby development', 'Symptoms', 'Exercise', 'Mental wellbeing', 'Appointments',
        'Fetal movement', 'Contractions', 'Swelling', 'Recovery', 'Feeding', 'Mental health',
        'Pelvic floor', 'Healing', 'Pumping', 'Hot flashes', 'Brain fog', 'Joint pain',
        'Weight changes', 'Night sweats', 'Irregular periods', 'Anxiety', 'Memory', 'Headache',
        'Healthy ageing', 'Heart health', 'Bone health', 'Tracking periods', 'Cramps',
        'Mood changes', 'Understanding my body', 'Hygiene', 'School & sports',
        'Puberty & body changes', 'Preparing for my first period',
        // The stage-switch questionnaire's own picks.
        'Ovulation timing', 'Fertility tracking', 'Partner support', 'Manage pain',
        'Regular periods', 'Skin and hair', 'Weight', 'Doctor visit reminders & questions',
      ]) {
        expect(HomeSectionOrder.tagsFor([pick]), isNotEmpty, reason: pick);
      }
    });
  });

  group('the pregnancy home', () {
    setUp(() {
      final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
      view.physicalSize = const Size(800, 9000);
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
              body: EverydayWellnessDashboard(activeStages: ['pregnancy']),
            ),
          ),
        );

    double top(WidgetTester t, String text) => t.getTopLeft(find.text(text).first).dy;

    testWidgets('with no picks, partner comes before the appointment card', (tester) async {
      BlushyStorage.write('user_profile.json', {
        'profile': {'lifeStage': 'pregnancy', 'activeLifeStages': ['pregnancy']},
      });
      await tester.pumpWidget(host());
      await tester.pump(const Duration(seconds: 2));
      expect(top(tester, 'PARTNER & FAMILY'), lessThan(top(tester, 'FOR YOUR NEXT APPOINTMENT')));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('picks made when switching to the stage outrank the older ones', (tester) async {
      // Onboarding picked Partner support while cycle tracking; the switch to
      // pregnancy asked again and she picked Appointments. The pregnancy
      // home follows the pregnancy answer.
      BlushyStorage.write('user_profile.json', {
        'profile': {
          'lifeStage': 'pregnancy',
          'activeLifeStages': ['pregnancy'],
          'goals': ['Partner support'],
          'stage_answers': {
            'reproductiveYears': {'goals': ['Partner support']},
            'pregnancy': {'goals': ['Appointments']},
          },
        },
      });
      await tester.pumpWidget(host());
      await tester.pump(const Duration(seconds: 2));
      expect(top(tester, 'FOR YOUR NEXT APPOINTMENT'), lessThan(top(tester, 'PARTNER & FAMILY')));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('asking for appointments moves that card above partner', (tester) async {
      BlushyStorage.write('user_profile.json', {
        'profile': {
          'lifeStage': 'pregnancy',
          'activeLifeStages': ['pregnancy'],
          'goals': ['Appointments'],
        },
      });
      await tester.pumpWidget(host());
      await tester.pump(const Duration(seconds: 2));
      expect(top(tester, 'FOR YOUR NEXT APPOINTMENT'), lessThan(top(tester, 'PARTNER & FAMILY')));
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
