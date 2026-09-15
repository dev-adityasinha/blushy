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
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// Every life-stage dashboard must at least render.
///
/// Ten screens, each thousands of lines, reached only by selecting the matching
/// life stage — so a fault in one is invisible until a user in that stage opens
/// the app. Nothing exercised them together.
///
/// This is deliberately a smoke test: it builds each dashboard with no server,
/// no logged data and a fresh account, which is the state a new user is in, and
/// asserts only that building it throws nothing.
void main() {
  useIsolatedStorage();

  setUp(() {
    AuthStorage.saveSession(
      token: 't',
      userId: 'stage-test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );
  });

  Widget host(Widget dashboard) => BlushyOSProvider(
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

  final dashboards = <String, Widget Function()>{
    'everyday wellness': () => const EverydayWellnessDashboard(),
    'first period not started': () => const FirstPeriodNotStartedDashboard(),
    'first period started': () => const FirstPeriodStartedDashboard(),
    'hormonal health': () => const HormonalHealthDashboard(),
    'living with my cycle': () => const LivingWithMyCycleDashboard(),
    'trying to conceive': () => const TryingToConceiveDashboard(),
    'pregnancy': () => const PregnancyDashboard(),
    'postpartum': () => const PostpartumDashboard(),
    'perimenopause': () => const PerimenopauseDashboard(),
    'menopause': () => const MenopauseDashboard(),
  };

  for (final entry in dashboards.entries) {
    testWidgets('${entry.key} dashboard renders', (tester) async {
      // Generous surface. These are long editorial pages, and a phone-sized
      // one reports overflow that a real device's scroll view never shows --
      // flutter_test surfaces only the first exception per pump, so layout
      // noise would mask the fault this test exists to catch.
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final faults = await _buildCollectingFaults(tester, host(entry.value()));

      expect(
        faults,
        isEmpty,
        reason: 'the ${entry.key} dashboard threw while building',
      );
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  }

  // ── Every dashboard must greet the user by the name she entered ──────────
  //
  // Each of these screens rolled its own lookup against keys onboarding does
  // not write (`name`, `profile.name`, `firstName`), so each fell through to a
  // literal -- "nithya", "lovely", "mama", "Ananya" -- and greeted every user
  // in the world by the same invented name.
  for (final entry in dashboards.entries) {
    testWidgets('${entry.key} dashboard shows the name the user entered', (tester) async {
      BlushyStorage.write('user_profile.json', {
        'profile': {'preferredName': 'Meera'},
      });

      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _buildCollectingFaults(tester, host(entry.value()));

      // Exact case: the name is shown as the user typed it. Seven of these
      // screens used to render `userName.toLowerCase()`, turning "Meera" into
      // "meera" while three others showed it unchanged.
      expect(
        _visibleText(tester),
        contains('Meera'),
        reason: 'the ${entry.key} dashboard never showed the stored name '
            'as it was entered',
      );
    });
  }

  testWidgets('trying to conceive claims no fertile window before a period is logged',
      (tester) async {
    // The continuum drew `Yesterday - TODAY - Tomorrow` as the fertile stretch
    // from literal booleans, ignoring cycle day, and rendered unconditionally.
    // Every user was told her fertile window was centred on today, every day.
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _buildCollectingFaults(tester, host(const TryingToConceiveDashboard()));
    final shown = _visibleText(tester);

    expect(shown, contains('FERTILE WINDOW CONTINUUM'));
    expect(
      shown,
      isNot(contains('Your Current Multi-Day Window')),
      reason: 'a fertile window was claimed with no period logged',
    );
    expect(shown, contains('Log the first day of your last period'));
  });

  testWidgets('a dashboard renders even with no name stored', (tester) async {
    // The greeting resolves a name through shared/user_display_name.dart. It
    // must never be the thing that breaks a screen.
    BlushyStorage.write('user_profile.json', <String, dynamic>{});

    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final faults = await _buildCollectingFaults(tester, host(const PregnancyDashboard()));
    expect(faults, isEmpty);
  });
}

/// Builds [app] and returns the faults it raised, minus two known, benign ones.
///
/// `FlutterError.onError` is intercepted rather than reading
/// `tester.takeException()`, because flutter_test keeps only the first
/// exception of a pump and fails the test outright on the second -- so a screen
/// raising the tolerated assertion twice could never be examined.
///
/// Tolerated:
/// * The `ListTile` / `DecoratedBox` assertion, a styling warning introduced by
///   Flutter 3.47 and raised throughout this codebase. Debug-only -- release
///   builds strip it -- and it does not stop a screen rendering. It is what the
///   pre-existing suite failures are.
/// * `RenderFlex overflowed`, a layout report against this synthetic surface
///   rather than evidence the screen is broken on a device.
///
/// Anything else is a real fault.
Future<List<String>> _buildCollectingFaults(WidgetTester tester, Widget app) async {
  const tolerated = [
    'ListTile background color or ink splashes',
    'A RenderFlex overflowed',
  ];

  final faults = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (tolerated.any(text.contains)) return;
    faults.add(text);
  };

  try {
    await tester.pumpWidget(app);
    // One frame past the initial build, so anything loaded in initState has a
    // chance to be applied.
    await tester.pump(const Duration(milliseconds: 200));
  } finally {
    FlutterError.onError = previous;
  }

  // Anything flutter_test still holds counts too.
  final pending = tester.takeException();
  if (pending != null && !tolerated.any(pending.toString().contains)) {
    faults.add(pending.toString());
  }
  return faults;
}

/// Every string the widget tree is currently drawing.
///
/// Covers both `Text` and `RichText`: several dashboards build the greeting as
/// a span rather than a plain string.
String _visibleText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    buffer.writeln(text.data ?? text.textSpan?.toPlainText() ?? '');
  }
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    buffer.writeln(rich.text.toPlainText());
  }
  return buffer.toString();
}
