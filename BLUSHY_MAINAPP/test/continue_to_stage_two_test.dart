import 'dart:io';

import 'package:blushy_life_app/core/state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// "Continue to Stage 2" has to move her, not just write it down.
///
/// The button wrote `lifeStage: 'firstPeriodStarted'` into
/// `user_profile.json`, logged the first period, and showed "Welcome to Stage
/// 2!" -- and the home screen carried on showing Stage 1.
///
/// `BlushyHomeScreen` picks the dashboard from
/// `osState.personalContext.lifeStage`, which the button never touched. So the
/// change existed on disk and nowhere else, and only a restart -- which reloads
/// state from storage -- appeared to apply it.
///
/// The stage selector was never affected: it goes through
/// `setActiveLifeStages`, which is exactly what this was missing.
void main() {
  useIsolatedStorage();

  test('the button updates app state, not only storage', () {
    final source = File(
      'lib/features/home/presentation/stages/first_period_not_started_dashboard.dart',
    ).readAsStringSync();

    final start = source.indexOf("profileData['lifeStage'] = 'firstPeriodStarted'");
    expect(start, greaterThan(-1), reason: 'the handler moved');

    final handler = source.substring(start, start + 1400);
    expect(
      handler,
      contains("setActiveLifeStages({'firstPeriodStarted'})"),
      reason: 'writing storage alone leaves the screen on Stage 1',
    );
  });

  test('and it reads the state before popping the sheet', () {
    // `BlushyOSProvider.of(context)` after `Navigator.pop` is looking up a
    // context that has just been torn down.
    final source = File(
      'lib/features/home/presentation/stages/first_period_not_started_dashboard.dart',
    ).readAsStringSync();

    final capture = source.indexOf('final osState = BlushyOSProvider.of(context);');
    final pop = source.indexOf('Navigator.pop(context);', capture);
    expect(capture, greaterThan(-1));
    expect(pop, greaterThan(capture), reason: 'state captured before the pop');
  });

  test('setting the started stage actually lands', () {
    // The setter has a guard that strips other stages whenever
    // `firstPeriodNotStarted` is in the set. Moving to started must not be
    // swallowed by it.
    final state = BlushyOSState();
    state.setActiveLifeStages({'firstPeriodNotStarted'});
    expect(state.personalContext.lifeStage, 'firstPeriodNotStarted');

    state.setActiveLifeStages({'firstPeriodStarted'});
    expect(state.personalContext.lifeStage, 'firstPeriodStarted');
    expect(state.personalContext.activeLifeStages, contains('firstPeriodStarted'));
    expect(
      state.personalContext.activeLifeStages,
      isNot(contains('firstPeriodNotStarted')),
      reason: 'the stage she left must not still be active',
    );
  });

  test('the two first-period stages are declared incompatible', () {
    // Which is what makes the selector replace rather than add. If this ever
    // changed, selecting "started" would leave "not started" active and the
    // setter's guard would strip the new one instead.
    final rules = File('lib/core/stage_conflict_engine.dart').readAsStringSync();
    final started = rules.indexOf("'firstPeriodStarted': StageConflictRule(");
    expect(started, greaterThan(-1));
    final block = rules.substring(started, rules.indexOf('),', started));
    expect(block, contains("'firstPeriodNotStarted'"));
  });
}
