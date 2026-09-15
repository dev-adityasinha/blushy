import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/features/home/presentation/stages/everyday_wellness_dashboard.dart';
import 'package:blushy_life_app/features/home/presentation/stages/first_period_not_started_dashboard.dart';
import 'package:blushy_life_app/features/home/presentation/stages/first_period_started_dashboard.dart';
import 'package:blushy_life_app/features/home/presentation/stages/hormonal_health_dashboard.dart';
import 'package:blushy_life_app/features/home/presentation/stages/living_with_my_cycle_dashboard.dart';
import 'package:blushy_life_app/features/home/presentation/stages/menopause_dashboard.dart';
import 'package:blushy_life_app/features/home/presentation/stages/perimenopause_dashboard.dart';
import 'package:blushy_life_app/features/home/presentation/stages/postpartum_dashboard.dart';
import 'package:blushy_life_app/features/home/presentation/stages/pregnancy_dashboard.dart';
import 'package:blushy_life_app/features/home/presentation/stages/trying_to_conceive_dashboard.dart';
import 'package:blushy_life_app/features/home/symptom_categories.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// The way into the symptom sheet must not be the check-in's empty state.
///
/// It was: the button lived inside the widget shown only while nothing had been
/// logged, so logging one symptom removed the only control that could open the
/// sheet again. Adding a second symptom an hour later, or correcting a
/// mis-tapped one, meant finding a row in RECENTLY and guessing it was tappable.
///
/// These pin the two halves of that: the button is there whether or not
/// anything is logged, and logging is its own section rather than part of the
/// check-in.
void main() {
  useIsolatedStorage();

  setUp(() {
    AuthStorage.saveSession(
      token: 't',
      userId: 'log-symptoms-user',
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
          // The stage is pinned rather than inferred: without a profile the
          // dashboard resolves to a different layout, and this test is about
          // the section, not about stage resolution.
          home: const EverydayWellnessDashboard(stageKey: 'everydayWellness'),
        ),
      );

  Widget hostFor(Widget dashboard) => BlushyOSProvider(
        notifier: BlushyOSState(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: dashboard,
        ),
      );

  /// The dashboard reads storage and rebuilds, so a single pump lands before
  /// the sections exist. Not `pumpAndSettle`: the page has a looping
  /// animation, which never settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// Ignores layout complaints that these pages already had.
  ///
  /// Several of these dashboards carry long-standing layout faults in their own
  /// content -- a ListTile wrapped in a DecoratedBox, an article-card Row that
  /// overflows on a narrow surface. Building the whole page triggers them, and
  /// flutter_test fails a test on any framework error, so they would decide a
  /// test that is about whether the logging section can be reached.
  ///
  /// Scoped deliberately: only those two complaints, and only when they come
  /// from somewhere other than the section under test. An overflow inside
  /// log_symptoms_section.dart still fails the test, as does anything else.
  void tolerateHostLayoutComplaints() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final fromTheSection =
          details.toString().contains('log_symptoms_section.dart');
      final known =
          details.exceptionAsString().contains('ListTile background color') ||
              details.exceptionAsString().contains('overflowed');
      if (known && !fromTheSection) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  /// Scrolls the page until the logging section is on screen.
  ///
  /// These dashboards are one long lazily-built `ListView`, so a section below
  /// the fold is absent from the tree rather than merely off screen, and a
  /// plain finder cannot tell those two apart. Scrolling is also what a user
  /// does, so a section that cannot be reached this way is genuinely missing.
  ///
  /// The scrollable is picked by axis: several of these pages nest horizontal
  /// lists (prompt pills, day strips), and `find.byType(Scrollable).first`
  /// lands on one of those about half the time.
  Future<void> revealLogSymptoms(WidgetTester tester, String stage) async {
    final target = find.text('LOG SYMPTOMS');
    if (target.evaluate().isNotEmpty) return;

    final vertical = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    expect(vertical, findsWidgets, reason: '$stage should scroll vertically');

    try {
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: vertical.first,
        maxScrolls: 80,
      );
    } finally {
      // nothing to restore here; see tolerateHostLayoutComplaints.
    }
    expect(
      target,
      findsWidgets,
      reason: '$stage must be able to reach the symptom sheet',
    );
  }

  /// Writes a symptom for today, the way the sheet's save path does.
  void logSomething() {
    BlushyStorage.write('daily_checkin.json', {
      'symptom': ['Cramps'],
    });
  }

  testWidgets('the section is there before anything is logged', (tester) async {
    await tester.pumpWidget(host());
    await settle(tester);

    expect(find.text('LOG SYMPTOMS'), findsWidgets);
    expect(find.text("Log today's symptoms"), findsWidgets);
  });

  testWidgets('the button survives logging, as an edit', (tester) async {
    // The regression this file exists for. Before, this found nothing.
    logSomething();

    await tester.pumpWidget(host());
    await settle(tester);

    expect(find.text('LOG SYMPTOMS'), findsWidgets);
    expect(
      find.text("Edit today's symptoms"),
      findsWidgets,
      reason: 'a logged day still needs a way back into the sheet',
    );
  });

  testWidgets('the check-in no longer carries a logging button', (tester) async {
    await tester.pumpWidget(host());
    await settle(tester);

    final checkIn = find.text('CHECK IN');
    expect(checkIn, findsWidgets, reason: 'the check-in is still its own section');

    // The prompt the button used to sit in is gone; what is left points at the
    // section above rather than offering its own control.
    expect(find.textContaining('fills in with what is worth asking'), findsNothing);
  });

  test('the sheet offers different groups per stage', () {
    // What makes one section enough for every dashboard: the groups are chosen
    // by stage, so this is not ten copies of the same list.
    final menopause = SymptomCategories.forStage('menopause')
        .map((c) => c.id)
        .toSet();
    final pregnancy = SymptomCategories.forStage('pregnancy')
        .map((c) => c.id)
        .toSet();

    expect(menopause, isNotEmpty);
    expect(pregnancy, isNotEmpty);
    expect(
      menopause.difference(pregnancy).isNotEmpty ||
          pregnancy.difference(menopause).isNotEmpty,
      isTrue,
      reason: 'two stages that ask identical questions would make the gating pointless',
    );
  });
  // ── every stage, not just the fallback ────────────────────────────────────
  //
  // home_screen._buildStageDashboard sends each recognised stage to its own
  // dashboard file, and EverydayWellnessDashboard -- the only one that had the
  // sheet -- is reached only for a multi-stage or unrecognised stage. So the
  // section rendering in that one file proved almost nothing: on a real phone
  // in a real stage, none of these nine could open the sheet at all.
  final everyStage = <String, Widget Function()>{
    'first period not started': () => const FirstPeriodNotStartedDashboard(),
    'first period started': () => const FirstPeriodStartedDashboard(),
    'hormonal health': () => const HormonalHealthDashboard(),
    'living with my cycle': () => const LivingWithMyCycleDashboard(),
    'trying to conceive': () => const TryingToConceiveDashboard(),
    'pregnancy': () => const PregnancyDashboard(),
    'postpartum': () => const PostpartumDashboard(),
    'perimenopause': () => const PerimenopauseDashboard(),
    'menopause': () => const MenopauseDashboard(),
    'everyday wellness (fallback)': () =>
        const EverydayWellnessDashboard(stageKey: 'everydayWellness'),
  };

  for (final entry in everyStage.entries) {
    testWidgets('${entry.key} offers a way into the symptom sheet',
        (tester) async {
      tolerateHostLayoutComplaints();
      await tester.pumpWidget(hostFor(entry.value()));
      await settle(tester);

      await revealLogSymptoms(tester, entry.key);
    });
  }
}
