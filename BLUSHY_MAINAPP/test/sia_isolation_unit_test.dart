import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/services/sia_dashboard_service.dart';
import 'helpers/isolated_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Each test process gets its own storage directory.
  useIsolatedStorage();


  group('BlushyStorage & Sia Isolation Unit Tests', () {
    setUp(() {
      AuthStorage.clearSession();
      BlushyStorage.clearMemoryCache();
      SiaDashboardService().clearUserCache();
    });

    test('Test 1: Unauthenticated session blocks private health writes', () {
      AuthStorage.clearSession();
      BlushyStorage.clearMemoryCache();
      expect(AuthStorage.getUserId(), isNull);
      BlushyStorage.write('daily_checkin.json', {'feeling': 'USER_UNAUTH_LEAK_TEST'});
      final readData = BlushyStorage.read('daily_checkin.json');
      expect(readData, isEmpty, reason: 'Private health data must not be written or read without authenticated userId');
    });

    test('Test 2: User A writes private health data under User A namespace', () {
      final uidA = 'user_a_${DateTime.now().microsecondsSinceEpoch}';
      AuthStorage.saveSession(token: 'mock_jwt_a', userId: uidA, email: 'user_a@test.com');
      expect(AuthStorage.getUserId(), equals(uidA));

      BlushyStorage.write('daily_checkin.json', {'feeling': 'USER_A_FEELING_MARKER'});
      final readA = BlushyStorage.read('daily_checkin.json');
      expect(readA['feeling'], equals('USER_A_FEELING_MARKER'));
    });

    test('Test 3: Account switch from User A to User B isolates local storage', () {
      final uidA = 'user_a_switch_${DateTime.now().microsecondsSinceEpoch}';
      final uidB = 'user_b_switch_${DateTime.now().microsecondsSinceEpoch}';

      // User A writes data
      AuthStorage.saveSession(token: 'mock_jwt_a', userId: uidA, email: 'user_a@test.com');
      BlushyStorage.write('daily_checkin.json', {'feeling': 'USER_A_FEELING_MARKER'});
      BlushyStorage.write('user_profile.json', {'name': 'Alice'});

      // Logout User A
      AuthStorage.clearSession();

      // User B logs in
      AuthStorage.saveSession(token: 'mock_jwt_b', userId: uidB, email: 'user_b@test.com');
      expect(AuthStorage.getUserId(), equals(uidB));

      // User B reads health and profile
      final readBCheckin = BlushyStorage.read('daily_checkin.json');
      final readBProfile = BlushyStorage.read('user_profile.json');

      expect(readBCheckin, isEmpty, reason: 'User B must not see User A check-in data');
      expect(readBProfile, isEmpty, reason: 'User B must not see User A profile data');

      // User B writes their own data
      BlushyStorage.write('daily_checkin.json', {'feeling': 'USER_B_FEELING_MARKER'});
      expect(BlushyStorage.read('daily_checkin.json')['feeling'], equals('USER_B_FEELING_MARKER'));

      // Switch back to User A
      AuthStorage.saveSession(token: 'mock_jwt_a', userId: uidA, email: 'user_a@test.com');
      final restoreA = BlushyStorage.read('daily_checkin.json');
      expect(restoreA['feeling'], equals('USER_A_FEELING_MARKER'), reason: 'User A data must be accurately restored');
    });

    test('Test 4: SiaDashboardService clears and isolates cache across accounts', () {
      AuthStorage.saveSession(token: 'mock_jwt_a', userId: 'user_a_123', email: 'user_a@test.com');
      SiaDashboardService().triggerRefresh();

      AuthStorage.clearSession();
      SiaDashboardService().clearUserCache();

      AuthStorage.saveSession(token: 'mock_jwt_b', userId: 'user_b_456', email: 'user_b@test.com');
      expect(AuthStorage.getUserId(), equals('user_b_456'));
    });
  });
}
