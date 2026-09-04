import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/home/widgets/home_hero.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/theme/colors.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/features/home/widgets/cycle_card.dart';
import 'helpers/isolated_storage.dart';

/// The top of the home tab, to the home design spec.
///
/// What is pinned: the greeting puts the name on its own line and never
/// loses it; the ring's phases are the cycle model's, not colour-only; and
/// the card draws the states the spec names -- loading, no tracking,
/// ready -- without assuming a day or a phase where there is none.
void main() {
  useIsolatedStorage();

  setUp(() {
    // The tracker inside the cycle card reads the app state, which reads
    // the session.
    AuthStorage.saveSession(
      token: 't',
      userId: 'u',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );
  });

  group('the greeting', () {
    test('splits the name onto its own line', () {
      expect(GreetingHero.leadOf('Good morning, Zaid', 'Zaid'), 'Good morning,');
      expect(GreetingHero.leadOf('Good afternoon, there', 'there'), 'Good afternoon,');
    });

    test('keeps the whole line when the name is not in it', () {
      // A translation that phrases the greeting without the name still
      // reads as a greeting rather than as a truncated one.
      expect(GreetingHero.leadOf('Bonjour', 'Zaid'), 'Bonjour');
    });

    testWidgets('renders the greeting and the name on one line', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: GreetingHero(greeting: 'Good morning, Zaid', name: 'Zaid'),
        ),
      ));
      await tester.pump();
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      expect(rich.text.toPlainText(), 'Good morning, Zaid.');
      expect(rich.maxLines, 1, reason: 'one line, always');
      final spans = (rich.text as TextSpan).children!;
      expect((spans.last as TextSpan).style?.color, BlushyColors.primary,
          reason: 'the name carries the brand red, as on the reference');
    });
  });

  group('phases', () {
    test('are read from the server phase name, whatever its wording', () {
      expect(CyclePhaseKindLook.parse('Luteal'), CyclePhaseKind.luteal);
      expect(CyclePhaseKindLook.parse('follicular'), CyclePhaseKind.follicular);
      expect(CyclePhaseKindLook.parse('Ovulation'), CyclePhaseKind.ovulation);
      expect(CyclePhaseKindLook.parse('Menstrual'), CyclePhaseKind.menstrual);
      expect(CyclePhaseKindLook.parse('Not Logged'), isNull,
          reason: 'no phase is assumed where the model gave none');
    });

    test('the ring lays days out the way the legend does', () {
      // 28-day cycle, 5-day period: ovulation around day 14.
      expect(CycleRingPainter.phaseOfDay(1, 28, 5), CyclePhaseKind.menstrual);
      expect(CycleRingPainter.phaseOfDay(5, 28, 5), CyclePhaseKind.menstrual);
      expect(CycleRingPainter.phaseOfDay(8, 28, 5), CyclePhaseKind.follicular);
      expect(CycleRingPainter.phaseOfDay(14, 28, 5), CyclePhaseKind.ovulation);
      expect(CycleRingPainter.phaseOfDay(18, 28, 5), CyclePhaseKind.luteal);
      expect(CycleRingPainter.phaseOfDay(28, 28, 5), CyclePhaseKind.luteal);
    });

    test('luteal purple is a phase indicator only', () {
      // The spec removes purple as a UI colour and allows it for the luteal
      // phase alone. It has its own named constant so any other use is
      // visible for what it is.
      expect(CyclePhaseKind.luteal.color, BlushyColors.lutealPhase);
      expect(CyclePhaseKind.menstrual.color, BlushyColors.primary);
      expect(CyclePhaseKind.follicular.color, BlushyColors.secondary);
      expect(CyclePhaseKind.ovulation.color, BlushyColors.accent);
    });
  });

  group('the cycle card', () {
    Widget host(CycleRingCard card) => BlushyOSProvider(
          notifier: BlushyOSState(),
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SingleChildScrollView(child: card)),
          ),
        );

    /// Pumps the card, lets the tracker's opening animation settle, and
    /// drains the async errors the test binding raises for fonts and the
    /// network, which are not the subject here.
    Future<void> show(WidgetTester tester, CycleRingCard card) async {
      await tester.pumpWidget(host(card));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
    }

    /// Tears the tree down and lets its timers run out, so none is pending
    /// when the test ends.
    Future<void> teardown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      tester.takeException();
    }

    testWidgets('with no tracking, assumes no day and no phase', (tester) async {
      await show(tester, CycleRingCard(
        state: CycleCardState.noTracking,
        onSetUp: () {},
      ));
      expect(find.text('Start with your last period'), findsOneWidget);
      expect(find.textContaining('Day '), findsNothing);
      expect(find.textContaining('phase'), findsNothing);
      expect(find.text('Log a period start'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('when ready, names the phase in words as well as colour',
        (tester) async {
      await show(tester, CycleRingCard(
        state: CycleCardState.ready,
        phase: CyclePhaseKind.luteal,
        cycleDay: 18,
        cycleLength: 29,
        onCalendar: () {},
        onInsights: () {},
      ));
      expect(find.text('Luteal phase'), findsOneWidget);
      expect(find.text('Day 18 of 29'), findsOneWidget);
      expect(find.text('Insights for your phase'), findsOneWidget);
      expect(find.byType(BlushyCycleCard), findsOneWidget,
          reason: 'the tube tracker is drawn inside the card');
      await teardown(tester);
    });

    testWidgets("a caveat from the model replaces the phase line, as written",
        (tester) async {
      await show(tester, const CycleRingCard(
        state: CycleCardState.ready,
        phase: CyclePhaseKind.follicular,
        cycleDay: 6,
        cycleLength: 31,
        caveat: 'Predictions are limited until more cycles are logged.',
      ));
      expect(find.text('Predictions are limited until more cycles are logged.'),
          findsOneWidget);
      expect(find.text(CyclePhaseKind.follicular.insight), findsNothing,
          reason: 'the decorative line yields to the model\'s own words');
    });

    testWidgets('while loading, shows a skeleton and no words', (tester) async {
      await show(tester, const CycleRingCard(state: CycleCardState.loading));
      expect(find.byType(Text), findsNothing);
      await teardown(tester);
    });
  });

  group('recently', () {
    testWidgets('with nothing logged, offers a first action', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: RecentlySurface(items: const [], onEmptyAction: () {})),
      ));
      await tester.pump();
      expect(find.text('Nothing logged yet'), findsOneWidget);
      expect(find.text('Log today'), findsOneWidget);
    });
  });
}
