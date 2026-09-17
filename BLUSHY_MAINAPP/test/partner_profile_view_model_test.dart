import 'package:blushy_life_app/models/blushy_models.dart';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/features/partner/view_models/partner_profile_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The partner profile load, tested with no widget. It reads the session, the
/// notification preferences and the connections, and picks the active one.
void main() {
  ApiResult<NotificationPreferences> _pf(ApiState s, {NotificationPreferences? d}) =>
      ApiResult<NotificationPreferences>(state: s, data: d);

  test('derives name from the email local part', () async {
    final vm = PartnerProfileViewModel(
      readSession: () => {'email': 'sam.partner@blushy.life'},
      fetchPreferences: () async => _pf(ApiState.ready),
      fetchConnections: () async => const [],
    );
    await vm.load();
    expect(vm.userEmail, 'sam.partner@blushy.life');
    expect(vm.userName, 'sam.partner');
    expect(vm.isLoading, isFalse);
  });

  test('falls back to a default email when the session has none', () async {
    final vm = PartnerProfileViewModel(
      readSession: () => const {},
      fetchPreferences: () async => _pf(ApiState.ready),
      fetchConnections: () async => const [],
    );
    await vm.load();
    expect(vm.userEmail, 'partner@blushy.life');
    expect(vm.userName, 'partner');
  });

  test('picks the active connection and keeps the loaded prefs', () async {
    const prefs = NotificationPreferences(categories: {'partner_shared_update': true});
    final vm = PartnerProfileViewModel(
      readSession: () => {'email': 'p@x.com'},
      fetchPreferences: () async => _pf(ApiState.ready, d: prefs),
      fetchConnections: () async => [
        {'connectionId': 'c1', 'status': 'pending'},
        {'connectionId': 'c2', 'status': 'active'},
      ],
    );
    await vm.load();
    expect(vm.activeConnection?['connectionId'], 'c2');
    expect(vm.notificationPrefs, same(prefs));
  });

  test('no active connection leaves it null', () async {
    final vm = PartnerProfileViewModel(
      readSession: () => {'email': 'p@x.com'},
      fetchPreferences: () async => _pf(ApiState.ready),
      fetchConnections: () async => [
        {'connectionId': 'c1', 'status': 'pending'},
      ],
    );
    await vm.load();
    expect(vm.activeConnection, isNull);
  });

  test('a thrown read still clears the spinner', () async {
    final vm = PartnerProfileViewModel(
      readSession: () => {'email': 'p@x.com'},
      fetchPreferences: () async => throw Exception('offline'),
      fetchConnections: () async => const [],
    );
    await vm.load();
    expect(vm.isLoading, isFalse);
  });

  test('notifies its listeners so the View can rebuild', () async {
    var n = 0;
    final vm = PartnerProfileViewModel(
      readSession: () => const {},
      fetchPreferences: () async => _pf(ApiState.ready),
      fetchConnections: () async => const [],
    )..addListener(() => n++);
    await vm.load();
    expect(n, greaterThan(0));
  });
}
