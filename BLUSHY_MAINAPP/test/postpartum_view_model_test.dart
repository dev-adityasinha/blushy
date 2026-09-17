import 'package:blushy_life_app/services/api_postpartum_service.dart';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/features/home/view_models/postpartum_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The postpartum data load, tested with no widget.
///
/// It used to live inside the 2,200-line dashboard's State, reachable only by
/// pumping the screen. As a view model the load-state contract -- especially
/// that a failed read stays distinct from an empty one -- is asserted directly.
void main() {
  ApiResult<PostpartumOverviewData> _ov(ApiState s, {PostpartumOverviewData? d}) =>
      ApiResult<PostpartumOverviewData>(state: s, data: d);
  ApiResult<PostpartumTodayBriefData> _br(ApiState s, {PostpartumTodayBriefData? d}) =>
      ApiResult<PostpartumTodayBriefData>(state: s, data: d);

  test('starts loading, before the first read resolves', () {
    final vm = PostpartumViewModel(
      fetchOverview: () async => _ov(ApiState.loading),
      fetchBrief: () async => _br(ApiState.loading),
    );
    expect(vm.isLoading, isTrue);
    expect(vm.overviewState, ApiState.loading);
    expect(vm.overview, isNull);
  });

  test('a successful load exposes overview, brief and ready state', () async {
    final overview = PostpartumOverviewData.fromJson({
      'isLowEnergyMode': true,
      'todayCheckin': {'mood': 'low', 'painScore': 4},
    });
    final vm = PostpartumViewModel(
      fetchOverview: () async => _ov(ApiState.ready, d: overview),
      fetchBrief: () async => _br(ApiState.ready),
    );
    await vm.load();

    expect(vm.overviewState, ApiState.ready);
    expect(vm.isLoading, isFalse);
    expect(vm.isLowEnergyMode, isTrue);
    expect(vm.todayCheckin?['mood'], 'low');
  });

  test('an empty read is ready-but-empty, not an error', () async {
    final vm = PostpartumViewModel(
      fetchOverview: () async => _ov(ApiState.empty),
      fetchBrief: () async => _br(ApiState.empty),
    );
    await vm.load();
    expect(vm.overviewState, ApiState.empty);
    expect(vm.overview, isNull);
    expect(vm.isLowEnergyMode, isFalse);
  });

  test('notifies its listeners so the View can rebuild', () async {
    var n = 0;
    final vm = PostpartumViewModel(
      fetchOverview: () async => _ov(ApiState.ready),
      fetchBrief: () async => _br(ApiState.ready),
    )..addListener(() => n++);
    await vm.load();
    expect(n, greaterThan(0));
  });
}
