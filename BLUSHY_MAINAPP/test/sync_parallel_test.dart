import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/services/auth_storage.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/concurrency_probe_http.dart';

/// The dashboard's data fetch must overlap its independent requests.
///
/// `syncStateWithBackend` issued six requests strictly one after another, so
/// the wait before the home screen showed real figures was the sum of all of
/// them rather than the slowest. On a cold backend that is tens of seconds.
///
/// Peak concurrency is measured directly rather than inferred from elapsed
/// time, because a fast machine makes sequential code look parallel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedStorage();

  setUp(() {
    AuthStorage.clearSession();
  });

  test('independent dashboard requests are in flight at the same time', () async {
    AuthStorage.saveSession(
      token: 'probe-token',
      userId: 'probe-user',
      email: 'probe@example.test',
      role: 'woman',
      onboardingCompleted: true,
    );

    final probe = HttpConcurrencyProbe();
    final state = BlushyOSState();

    await probe.run(() => state.syncStateWithBackend());

    expect(probe.requestedPaths.length, greaterThan(1),
        reason: 'the sync should have made several requests');
    // Three, not two: the profile read alone puts two in flight, so a looser
    // bound would still pass if the four dashboard fetches went back to
    // running one at a time.
    expect(probe.peakConcurrency, greaterThanOrEqualTo(3),
        reason: 'requests that do not depend on each other must overlap, '
            'not run one at a time (peak was ${probe.peakConcurrency} '
            'across ${probe.requestedPaths.length} requests)');

    state.dispose();
  });

  test('the loading flag settles even though every request is stubbed', () async {
    AuthStorage.saveSession(
      token: 'probe-token',
      userId: 'probe-user',
      email: 'probe@example.test',
      role: 'woman',
      onboardingCompleted: true,
    );

    final probe = HttpConcurrencyProbe();
    final state = BlushyOSState();

    await probe.run(() => state.syncStateWithBackend());

    expect(state.isSyncing, isFalse,
        reason: 'the dashboard banner would otherwise spin for ever');

    state.dispose();
  });
}
