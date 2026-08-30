import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/services/auth_storage.dart';

import 'helpers/isolated_storage.dart';

/// Signing in must route on a local decision, never on a network round trip.
///
/// `setAuthenticated(true)` used to hand straight off to
/// `syncStateWithBackend()` without notifying, and that method only notifies
/// after six sequential HTTP requests -- and not at all if one of them threw.
/// So the root widget never rebuilt: verifying an account left the user
/// staring at the signup screen with no indication anything had happened, and
/// the only apparent way forward was to switch to the login tab and sign in
/// again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedStorage();

  setUp(() {
    AuthStorage.clearSession();
  });

  test('setAuthenticated notifies immediately, without waiting on the backend', () {
    final state = BlushyOSState();
    var notifications = 0;
    state.addListener(() => notifications++);

    state.setAuthenticated(true, onboardingCompleted: true);

    // Synchronously, in the same turn of the event loop: no await, no request.
    expect(notifications, greaterThan(0),
        reason: 'the root widget must be told to rebuild before any network call');
    expect(state.isAuthenticated, isTrue);

    state.dispose();
  });

  test('signing out still notifies', () {
    final state = BlushyOSState();
    state.setAuthenticated(true, onboardingCompleted: true);

    var notifications = 0;
    state.addListener(() => notifications++);
    state.setAuthenticated(false);

    expect(notifications, greaterThan(0));
    expect(state.isAuthenticated, isFalse);

    state.dispose();
  });

  test('a sync that cannot run leaves nothing stuck in a loading state', () async {
    // No token, so syncStateWithBackend returns before making any request.
    // isSyncing must not be left true -- the dashboard banner keys off it, and
    // a stranded flag would spin for ever.
    final state = BlushyOSState();
    expect(state.isSyncing, isFalse);

    await state.syncStateWithBackend();

    expect(state.isSyncing, isFalse,
        reason: 'the loading flag must always settle, including on the early return');

    state.dispose();
  });
}
