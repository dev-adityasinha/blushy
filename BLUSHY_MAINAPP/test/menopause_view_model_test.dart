import 'package:blushy_life_app/services/api_menopause_service.dart';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/features/home/view_models/menopause_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The menopause overview load, tested with no widget.
///
/// It used to live inside the 2,100-line dashboard's State. As a view model
/// the load-state contract -- a failed read staying distinct from an empty
/// one, and life-mode/private-mode derived from the overview -- is asserted
/// directly.
void main() {
  ApiResult<MenopauseOverviewData> _ov(ApiState s, {MenopauseOverviewData? d}) =>
      ApiResult<MenopauseOverviewData>(state: s, data: d);

  test('starts loading, before the first read resolves', () {
    final vm = MenopauseViewModel(fetchOverview: () async => _ov(ApiState.loading));
    expect(vm.isLoading, isTrue);
    expect(vm.overviewState, ApiState.loading);
    expect(vm.overview, isNull);
    expect(vm.activeLifeMode, 'normal');
    expect(vm.privateMode, isFalse);
  });

  test('a successful load exposes overview and derives life/private mode', () async {
    final overview = MenopauseOverviewData.fromJson({
      'lifeMode': 'gentle',
      'privateMode': true,
    });
    final vm = MenopauseViewModel(fetchOverview: () async => _ov(ApiState.ready, d: overview));
    await vm.load();

    expect(vm.overviewState, ApiState.ready);
    expect(vm.isLoading, isFalse);
    expect(vm.overview, same(overview));
    expect(vm.activeLifeMode, 'gentle');
    expect(vm.privateMode, isTrue);
  });

  test('an empty read is ready-but-empty, keeping the defaults', () async {
    final vm = MenopauseViewModel(fetchOverview: () async => _ov(ApiState.empty));
    await vm.load();
    expect(vm.overviewState, ApiState.empty);
    expect(vm.overview, isNull);
    expect(vm.activeLifeMode, 'normal', reason: 'no overview means no override');
    expect(vm.privateMode, isFalse);
  });

  test('notifies its listeners so the View can rebuild', () async {
    var n = 0;
    final vm = MenopauseViewModel(fetchOverview: () async => _ov(ApiState.ready))
      ..addListener(() => n++);
    await vm.load();
    expect(n, greaterThan(0));
  });
}
