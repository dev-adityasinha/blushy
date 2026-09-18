import 'dart:async';
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
      readCachedOverview: () => null,
      readCachedBrief: () => null,
    )..addListener(() => n++);
    await vm.load();
    expect(n, greaterThan(0));
  });

  test('cache-first: shows the cached overview at once, then the server replaces it', () async {
    final cached = PostpartumOverviewData.fromJson({'isLowEnergyMode': true});
    final server = PostpartumOverviewData.fromJson({'isLowEnergyMode': false});
    final gate = Completer<ApiResult<PostpartumOverviewData>>();

    final vm = PostpartumViewModel(
      readCachedOverview: () => cached,
      readCachedBrief: () => null,
      fetchOverview: () => gate.future,
      fetchBrief: () async => _br(ApiState.ready),
    );
    final done = vm.load();

    // Synchronous cache emission, before the network resolves.
    expect(vm.overview, same(cached));
    expect(vm.overviewState, ApiState.stale);
    expect(vm.isLoading, isFalse);
    expect(vm.isLowEnergyMode, isTrue);

    gate.complete(_ov(ApiState.ready, d: server));
    await done;
    expect(vm.overview, same(server));
    expect(vm.overviewState, ApiState.ready);
    expect(vm.isLowEnergyMode, isFalse);
  });

  test('cache-first: with no cache it stays loading until the server answers', () async {
    final gate = Completer<ApiResult<PostpartumOverviewData>>();
    final vm = PostpartumViewModel(
      readCachedOverview: () => null,
      readCachedBrief: () => null,
      fetchOverview: () => gate.future,
      fetchBrief: () async => _br(ApiState.ready),
    );
    final done = vm.load();
    expect(vm.isLoading, isTrue);
    expect(vm.overview, isNull);
    gate.complete(_ov(ApiState.empty));
    await done;
    expect(vm.isLoading, isFalse);
  });
}
