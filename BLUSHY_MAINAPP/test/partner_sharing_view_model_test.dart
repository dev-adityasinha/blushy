import 'package:blushy_life_app/models/blushy_models.dart';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/features/partner/view_models/partner_sharing_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The partner sharing load, tested with no widget.
///
/// It reads two endpoints -- the sharing state and the requests still pending
/// -- and the screen renders both. As a view model that pairing is asserted
/// directly, including that a null request list becomes an empty list rather
/// than crashing the View.
void main() {
  final sharing = PartnerSharingState.fromJson({
    'connectionId': 'c1',
    'connectionState': 'active',
    'permissions': const [],
  });

  ApiResult<PartnerSharingState> _sh(ApiState s, {PartnerSharingState? d}) =>
      ApiResult<PartnerSharingState>(state: s, data: d);
  ApiResult<List<Map<String, dynamic>>> _rq(ApiState s, {List<Map<String, dynamic>>? d}) =>
      ApiResult<List<Map<String, dynamic>>>(state: s, data: d);

  test('starts in a loading result', () {
    final vm = PartnerSharingViewModel(
      connectionId: 'c1',
      fetchSharingState: () async => _sh(ApiState.loading),
      fetchPendingRequests: () async => _rq(ApiState.loading),
    );
    expect(vm.result.state, ApiState.loading);
    expect(vm.pendingRequests, isEmpty);
  });

  test('a load exposes the sharing state and the pending requests', () async {
    final vm = PartnerSharingViewModel(
      connectionId: 'c1',
      fetchSharingState: () async => _sh(ApiState.ready, d: sharing),
      fetchPendingRequests: () async => _rq(ApiState.ready, d: [
        {'requestId': 'r1', 'permissionKey': 'mood'},
      ]),
    );
    await vm.load();
    expect(vm.result.state, ApiState.ready);
    expect(vm.result.data, same(sharing));
    expect(vm.pendingRequests, hasLength(1));
    expect(vm.pendingRequests.first['requestId'], 'r1');
  });

  test('a null request list becomes an empty list', () async {
    final vm = PartnerSharingViewModel(
      connectionId: 'c1',
      fetchSharingState: () async => _sh(ApiState.ready, d: sharing),
      fetchPendingRequests: () async => _rq(ApiState.offline),
    );
    await vm.load();
    expect(vm.pendingRequests, isEmpty);
  });

  test('notifies its listeners so the View can rebuild', () async {
    var n = 0;
    final vm = PartnerSharingViewModel(
      connectionId: 'c1',
      fetchSharingState: () async => _sh(ApiState.ready, d: sharing),
      fetchPendingRequests: () async => _rq(ApiState.ready),
    )..addListener(() => n++);
    await vm.load();
    expect(n, greaterThan(0));
  });

  group('optimistic toggle', () {
    const loaded = PartnerSharingState(
      connectionId: 'c1',
      connectionState: 'accepted',
      permissions: [
        PartnerPermission(key: 'mood', label: 'Mood', enabled: false),
        PartnerPermission(key: 'sleep', label: 'Sleep', enabled: true),
      ],
    );

    PartnerSharingViewModel vmWith(PartnerSharingState s) => PartnerSharingViewModel(
          connectionId: 'c1',
          fetchSharingState: () async => _sh(ApiState.ready, d: s),
          fetchPendingRequests: () async => _rq(ApiState.ready),
        );

    test('flips one permission in place and keeps the ready state', () async {
      final vm = vmWith(loaded);
      await vm.load();

      vm.applyOptimisticToggle('mood', true);

      expect(vm.result.state, ApiState.ready,
          reason: 'the list must not collapse to a loading spinner');
      final perms = {for (final p in vm.result.data!.permissions) p.key: p.enabled};
      expect(perms['mood'], isTrue, reason: 'the tapped switch moves at once');
      expect(perms['sleep'], isTrue, reason: 'the others are untouched');
    });

    test('returns the previous state so a refused change can be reverted', () async {
      final vm = vmWith(loaded);
      await vm.load();

      final previous = vm.applyOptimisticToggle('mood', true);
      expect(vm.result.data!.permissions.firstWhere((p) => p.key == 'mood').enabled, isTrue);

      vm.revertToggle(previous);
      expect(vm.result.data!.permissions.firstWhere((p) => p.key == 'mood').enabled, isFalse,
          reason: 'the switch goes back where it was');
    });

    test('a toggle with no loaded data is a no-op', () {
      final vm = vmWith(loaded); // not loaded yet -> result is loading, data null
      final previous = vm.applyOptimisticToggle('mood', true);
      expect(previous.data, isNull);
      expect(vm.result.data, isNull);
    });

    test('the flip notifies so the View repaints without a refetch', () async {
      final vm = vmWith(loaded);
      await vm.load();
      var n = 0;
      vm.addListener(() => n++);
      vm.applyOptimisticToggle('mood', true);
      expect(n, 1, reason: 'exactly one rebuild, no loading->ready flicker');
    });
  });

  group('PartnerSharingState.withPermission', () {
    const state = PartnerSharingState(
      connectionId: 'c1',
      connectionState: 'accepted',
      permissions: [
        PartnerPermission(key: 'mood', label: 'Mood', enabled: false),
        PartnerPermission(key: 'sleep', label: 'Sleep', enabled: true),
      ],
    );

    test('flips only the named permission', () {
      final next = state.withPermission('mood', true);
      expect(next.permissions.firstWhere((p) => p.key == 'mood').enabled, isTrue);
      expect(next.permissions.firstWhere((p) => p.key == 'sleep').enabled, isTrue);
      // Original is unchanged (immutable).
      expect(state.permissions.firstWhere((p) => p.key == 'mood').enabled, isFalse);
    });

    test('an unknown key leaves every permission as it was', () {
      final next = state.withPermission('nope', true);
      expect(next.permissions.map((p) => p.enabled).toList(), [false, true]);
    });
  });
}
