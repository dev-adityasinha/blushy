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
}
