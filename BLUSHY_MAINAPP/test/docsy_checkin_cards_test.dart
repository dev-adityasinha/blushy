import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/features/home/checkin_followups.dart';
import 'package:blushy_life_app/features/home/presentation/stages/everyday_wellness_dashboard.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// Docsy writes the check-in cards from today's symptoms; the rule table
/// stands in when she has not.
void main() {
  useIsolatedStorage();

  group('cards from the model', () {
    test('keep only what respects the contract', () {
      final cards = CheckinFollowUps.fromModel([
        {'metric': 'sleep', 'question': 'Did you get at least 7 hours of sleep?', 'yesValue': '7-8h', 'noValue': '<6h', 'becauseOf': ['Fatigue']},
        {'metric': 'water', 'question': 'Did you drink about 2L?', 'yesValue': '2L', 'noValue': '2L'},
        {'metric': 'blood', 'question': 'Was it high?', 'yesValue': 'High', 'noValue': 'Low'},
        {'metric': 'stress', 'question': 'Your cramps come from stress', 'yesValue': 'High', 'noValue': 'Low'},
        {'metric': 'exercise', 'question': 'Did you move a little today?', 'yesValue': 'Light', 'noValue': 'None'},
        {'metric': 'exercise', 'question': 'Did you walk?', 'yesValue': 'Active', 'noValue': 'None'},
      ]);
      expect(cards.map((c) => c.metric), ['sleep', 'exercise']);
      expect(cards.first.id, 'ai_sleep');
      expect(cards.first.becauseOf, ['Fatigue']);
    });

    test('the server envelope is accepted too, and junk is nothing', () {
      expect(CheckinFollowUps.fromModel({'cards': [
        {'metric': 'energy', 'question': 'Did your energy hold up today?', 'yesValue': 'High', 'noValue': 'Low'},
      ]}).length, 1);
      expect(CheckinFollowUps.fromModel('nope'), isEmpty);
      expect(CheckinFollowUps.fromModel(null), isEmpty);
    });

    test('a card survives the day file', () {
      const card = CheckinFollowUp(
        id: 'ai_water', question: 'Did you drink about 2L?', becauseOf: ['Headache'],
        metric: 'water', yesValue: '2L', noValue: '1L',
      );
      final back = CheckinFollowUp.fromJson(card.toJson());
      expect(back, card);
      expect(back.question, card.question);
      expect(back.becauseOf, ['Headache']);
    });
  });

  group('on the home', () {
    String today() {
      final n = DateTime.now();
      return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    }

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
            home: const Scaffold(body: EverydayWellnessDashboard(stageKey: 'reproductiveYears')),
          ),
        );

    setUp(() {
      final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
      view.physicalSize = const Size(800, 6000);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });
      AuthStorage.saveSession(token: 't', userId: 'u', email: 'a@b.c', role: 'woman', onboardingCompleted: true);
      BlushyStorage.write('user_profile.json', {'profile': {'lifeStage': 'reproductiveYears'}});
    });

    testWidgets("Docsy's cards for today's symptoms are the ones shown", (tester) async {
      BlushyStorage.write('daily_checkin.json', {
        'date': today(),
        'symptom': ['symptom/Fatigue'],
        'docsy_followups': {
          'key': '${today()}|fatigue',
          'cards': [
            {'id': 'ai_sleep', 'question': 'Did you manage a full night of sleep?', 'becauseOf': ['Fatigue'], 'metric': 'sleep', 'yesValue': '7-8h', 'noValue': '<6h'},
          ],
        },
      });
      await tester.pumpWidget(host());
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Did you manage a full night of sleep?'), findsOneWidget);
      expect(find.text('Did you sleep at least 7 hours?'), findsNothing, reason: 'the rule card is not shown as well');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('without them, the rule table asks', (tester) async {
      BlushyStorage.write('daily_checkin.json', {
        'date': today(),
        'symptom': ['symptom/Fatigue'],
      });
      await tester.pumpWidget(host());
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Did you sleep at least 7 hours?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets("yesterday's Docsy cards are not reused for a new set of symptoms", (tester) async {
      BlushyStorage.write('daily_checkin.json', {
        'date': today(),
        'symptom': ['symptom/Cramps'],
        'docsy_followups': {
          'key': '${today()}|fatigue',
          'cards': [
            {'id': 'ai_sleep', 'question': 'Did you manage a full night of sleep?', 'becauseOf': ['Fatigue'], 'metric': 'sleep', 'yesValue': '7-8h', 'noValue': '<6h'},
          ],
        },
      });
      await tester.pumpWidget(host());
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Did you manage a full night of sleep?'), findsNothing);
      expect(find.text('Did you move or stretch today?'), findsOneWidget, reason: 'cramps: the rule card');
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
