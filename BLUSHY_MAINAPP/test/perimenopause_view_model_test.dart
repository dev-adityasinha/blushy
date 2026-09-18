import 'dart:async';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/services/api_perimenopause_service.dart';
import 'package:blushy_life_app/features/home/view_models/perimenopause_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The perimenopause overview+brief load, tested with no widget.
///
/// It used to live inside the 2,900-line dashboard's State. As a view model
/// the load-state contract -- a failed read keeping the last data, an empty
/// read staying distinct from an error, and focus/cycle-history derived from
/// the overview -- is asserted directly.
void main() {
  ApiResult<PerimenopauseOverviewData> _ov(ApiState s, {PerimenopauseOverviewData? d}) =>
      ApiResult<PerimenopauseOverviewData>(state: s, data: d);
  ApiResult<PerimenopauseTodayBriefData> _br(ApiState s, {PerimenopauseTodayBriefData? d}) =>
      ApiResult<PerimenopauseTodayBriefData>(state: s, data: d);

  test('starts loading, before the first read resolves', () {
    final vm = PerimenopauseViewModel(
      fetchOverview: () async => _ov(ApiState.loading),
      fetchBrief: () async => _br(ApiState.loading),
    );
    expect(vm.isLoading, isTrue);
    expect(vm.overviewState, ApiState.loading);
    expect(vm.overview, isNull);
    expect(vm.activeFocus, 'sleep');
    expect(vm.cycleHistory, isEmpty);
  });

  test('a successful load derives focus and cycle history', () async {
    final overview = PerimenopauseOverviewData.fromJson({
      'profile': {'currentFocus': 'temperature'},
      'cycleHistory': [30, 40, 26],
    });
    final vm = PerimenopauseViewModel(
      fetchOverview: () async => _ov(ApiState.ready, d: overview),
      fetchBrief: () async => _br(ApiState.ready),
    );
    await vm.load();

    expect(vm.overviewState, ApiState.ready);
    expect(vm.isLoading, isFalse);
    expect(vm.activeFocus, 'temperature');
    expect(vm.cycleHistory, [30, 40, 26]);
  });

  test('an empty read is ready-but-empty, keeping the defaults', () async {
    final vm = PerimenopauseViewModel(
      fetchOverview: () async => _ov(ApiState.empty),
      fetchBrief: () async => _br(ApiState.empty),
    );
    await vm.load();
    expect(vm.overviewState, ApiState.empty);
    expect(vm.overview, isNull);
    expect(vm.activeFocus, 'sleep');
    expect(vm.cycleHistory, isEmpty);
  });

  test('a thrown read clears the spinner and keeps the last data', () async {
    var call = 0;
    final overview = PerimenopauseOverviewData.fromJson({
      'profile': {'currentFocus': 'sleep'},
      'cycleHistory': [28],
    });
    final vm = PerimenopauseViewModel(
      // First load succeeds; the second throws.
      fetchOverview: () async {
        call++;
        if (call > 1) throw Exception('offline');
        return _ov(ApiState.ready, d: overview);
      },
      fetchBrief: () async => _br(ApiState.ready),
    );
    await vm.load();
    await vm.load(silent: true);

    expect(vm.isLoading, isFalse, reason: 'the spinner must not stick on error');
    expect(vm.cycleHistory, [28], reason: 'a failed reload keeps what loaded before');
  });

  test('notifies its listeners so the View can rebuild', () async {
    var n = 0;
    final vm = PerimenopauseViewModel(
      fetchOverview: () async => _ov(ApiState.ready),
      fetchBrief: () async => _br(ApiState.ready),
    )..addListener(() => n++);
    await vm.load();
    expect(n, greaterThan(0));
  });

  group('cache-first', () {
    PerimenopauseOverviewData _ovData(String focus, List<int> hist) =>
        PerimenopauseOverviewData.fromJson({
          'profile': {'currentFocus': focus},
          'cycleHistory': hist,
        });

    test('shows the cached overview at once, then the server replaces it', () async {
      final cached = _ovData('temperature', [30, 40]);
      final server = _ovData('sleep', [28]);
      final gate = Completer<ApiResult<PerimenopauseOverviewData>>();

      final vm = PerimenopauseViewModel(
        readCachedOverview: () => cached,
        readCachedBrief: () => null,
        fetchOverview: () => gate.future,
        fetchBrief: () async => _br(ApiState.ready),
      );
      final done = vm.load();

      // Synchronous cache emission, before the network resolves.
      expect(vm.overviewState, ApiState.stale);
      expect(vm.isLoading, isFalse, reason: 'a returning user is not held on a spinner');
      expect(vm.activeFocus, 'temperature');
      expect(vm.cycleHistory, [30, 40]);

      gate.complete(_ov(ApiState.ready, d: server));
      await done;
      expect(vm.overviewState, ApiState.ready);
      expect(vm.activeFocus, 'sleep');
      expect(vm.cycleHistory, [28]);
    });

    test('with no cache it still shows the spinner until the server answers', () async {
      final gate = Completer<ApiResult<PerimenopauseOverviewData>>();
      final vm = PerimenopauseViewModel(
        readCachedOverview: () => null,
        readCachedBrief: () => null,
        fetchOverview: () => gate.future,
        fetchBrief: () async => _br(ApiState.ready),
      );
      final done = vm.load();
      expect(vm.isLoading, isTrue);
      gate.complete(_ov(ApiState.ready, d: _ovData('sleep', const [])));
      await done;
      expect(vm.isLoading, isFalse);
    });
  });
}
