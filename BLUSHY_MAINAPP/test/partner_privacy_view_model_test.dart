import 'package:blushy_life_app/models/blushy_models.dart';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/features/partner/view_models/partner_privacy_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The partner privacy load, tested with no widget. Its branches used to be
/// reachable only by pumping the screen: the matrix failing, no connection
/// yet, a context read that only partly succeeded.
void main() {
  const mood = PartnerPermission(key: 'mood', label: 'Mood', grants: ['mood.read']);
  const sleep = PartnerPermission(key: 'sleep', label: 'Sleep', grants: ['sleep.read']);

  ApiResult<List<PartnerPermission>> _mx(ApiState s, {List<PartnerPermission>? d}) =>
      ApiResult<List<PartnerPermission>>(state: s, data: d);
  ApiResult<Map<String, dynamic>> _ctx(ApiState s, {Map<String, dynamic>? perms}) =>
      ApiResult<Map<String, dynamic>>(state: s, data: const {}, permissions: perms);
  ApiResult<List<Map<String, dynamic>>> _rq(ApiState s, {List<Map<String, dynamic>>? d}) =>
      ApiResult<List<Map<String, dynamic>>>(state: s, data: d);

  test('a matrix that fails to load surfaces an error, not empty categories', () async {
    final vm = PartnerPrivacyViewModel(
      connectionId: 'c1',
      fetchMatrix: () async => _mx(ApiState.offline),
      fetchContext: () async => _ctx(ApiState.ready),
      fetchRequests: () async => _rq(ApiState.ready),
    );
    await vm.load();
    expect(vm.loading, isFalse);
    expect(vm.error, isNotNull);
    expect(vm.matrix, isEmpty);
  });

  test('with no connection yet, only the categories load', () async {
    final vm = PartnerPrivacyViewModel(
      connectionId: null,
      fetchMatrix: () async => _mx(ApiState.ready, d: const [mood, sleep]),
      fetchContext: () async => throw StateError('must not be called'),
      fetchRequests: () async => throw StateError('must not be called'),
    );
    await vm.load();
    expect(vm.loading, isFalse);
    expect(vm.error, isNull);
    expect(vm.matrix, hasLength(2));
    expect(vm.allowedGrants, isEmpty);
  });

  test('a full load reads grants from the context envelope and pending keys', () async {
    final vm = PartnerPrivacyViewModel(
      connectionId: 'c1',
      fetchMatrix: () async => _mx(ApiState.ready, d: const [mood, sleep]),
      fetchContext: () async => _ctx(ApiState.ready, perms: {
        'allowedGrants': ['mood.read'],
      }),
      fetchRequests: () async => _rq(ApiState.ready, d: [
        {'permissionKey': 'sleep'},
        {'permissionKey': ''}, // dropped
      ]),
    );
    await vm.load();
    expect(vm.error, isNull);
    expect(vm.allowedGrants, {'mood.read'});
    expect(vm.pendingRequests, {'sleep'});
    expect(vm.isShared(mood), isTrue, reason: 'the partner holds its grant');
    expect(vm.isShared(sleep), isFalse);
  });

  test('a context that could not be reached shows categories with a partial note', () async {
    final vm = PartnerPrivacyViewModel(
      connectionId: 'c1',
      fetchMatrix: () async => _mx(ApiState.ready, d: const [mood]),
      fetchContext: () async => _ctx(ApiState.offline),
      fetchRequests: () async => _rq(ApiState.offline),
    );
    await vm.load();
    expect(vm.matrix, hasLength(1));
    expect(vm.error, contains('Showing categories only'));
    expect(vm.allowedGrants, isEmpty);
  });

  test('a grantless category falls back to its enabled flag', () {
    const alwaysShared = PartnerPermission(key: 'safety', label: 'Safety', enabled: true);
    final vm = PartnerPrivacyViewModel(connectionId: 'c1');
    expect(vm.isShared(alwaysShared), isTrue);
  });
}
