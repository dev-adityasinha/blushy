import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The four keys left behind when the screen documents moved to the account.
///
/// Each was a different problem, so each got a different answer rather than
/// the same mechanical move:
///
///  * `partner_decoder_enabled` is *his* toggle, not her `allowDecoderMan`
///    permission -- two different things that look alike. It is a preference
///    and belongs to his account, so it goes through the store.
///  * `stage2_flow_<date>` is a per-day document; the store's key pattern
///    admits the date.
///  * `partner_completed_actions_<date>` was already written to the server by
///    the toggle, and `shared-data` already returns it. Adding a GET route
///    would have duplicated existing surface. The real defect was `addAll`:
///    the server's list could only ever add, so an action un-ticked on another
///    device stayed ticked here.
///  * `blushy_prefs` mirrors state the server already holds -- the profile
///    through `saveOnboardingAnswers`, wellbeing through the daily mood -- so
///    it stays as the bootstrap cache it is; without it a cold start renders
///    blank until the API answers. Only `argumentModeActive` and
///    `customAiBriefing` existed nowhere else, and only those now sync.
void main() {
  String read(String p) => File(p).readAsStringSync();

  test('his decoder toggle follows his account', () {
    final screen = read('lib/features/partner/partner_screen.dart');
    expect(screen, contains("UserStateStore.read('partner_decoder_enabled')"));
    expect(screen, contains("UserStateStore.write('partner_decoder_enabled'"));
    expect(screen.contains("BlushyStorage.read('partner_decoder_enabled')"), isFalse);
  });

  test('the per-day flow document is stored by date', () {
    final dash = read('lib/features/home/presentation/stages/first_period_started_dashboard.dart');
    expect(dash, contains(r"UserStateStore.read('stage2_flow_$todayStr')"));
    expect(dash.contains(r"BlushyStorage.write('stage2_flow_$todayStr.json'"), isFalse);

    // The key pattern has to admit the hyphens in an ISO date.
    final repo = read('backend/src/repositories/userStateRepository.js');
    expect(repo, contains(r'/^[a-z0-9_-]{1,64}$/'));
  });

  test('the server list replaces the local set rather than merging into it', () {
    final home = read('lib/features/partner/presentation/partner_home.dart');
    expect(home.contains('_completedActionIds.addAll(backendIds)'), isFalse,
        reason: 'addAll could only add, so an un-tick never propagated');
    expect(home, contains('_completedActionIds = Set<String>.from('));
    expect(home, contains("UserStateStore.write(\n                'partner_completed_actions_"));
  });

  test('no redundant route was added for something shared-data already returns', () {
    final routes = read('backend/src/routes/partnerRoutes.js');
    final getRoutes = routes
        .split(String.fromCharCode(10))
        .where((l) => l.contains("router.get('/connections/:connectionId/support-actions'"))
        .length;
    expect(getRoutes, 0, reason: 'shared-data already carries completedActionIds');
  });

  test('only the settings with no server copy were moved', () {
    final state = read('lib/core/state.dart');
    expect(state, contains("UserStateStore.write('app_preferences'"));
    expect(state, contains('argumentModeActive'));
    expect(state, contains('customAiBriefing'));

    // The bootstrap cache stays: without it a cold start has nothing to draw.
    expect(state, contains("BlushyStorage.write('blushy_prefs.json'"),
        reason: 'removing the cache would blank every cold start');
  });

  test('the account copy is applied once it arrives', () {
    final state = read('lib/core/state.dart');
    expect(state, contains('void applyAccountPreferences()'));

    final start = state.indexOf('void setAuthenticated(');
    final body = state.substring(start, start + 600);
    expect(body, contains('applyAccountPreferences()'));
  });

  test('both setters push the change up', () {
    final state = read('lib/core/state.dart');
    for (final setter in ['void setArgumentModeActive(', 'void updateDynamicAiBriefing(']) {
      final start = state.indexOf(setter);
      expect(start, greaterThan(-1), reason: setter);
      expect(state.substring(start, start + 220), contains('_savePreferencesToAccount()'),
          reason: setter);
    }
  });
}
