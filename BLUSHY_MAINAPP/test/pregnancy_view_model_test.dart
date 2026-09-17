import 'dart:async';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/services/api_pregnancy_service.dart';
import 'package:blushy_life_app/features/home/view_models/pregnancy_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pregnancy five-fetch load, tested with no widget.
void main() {
  PregnancyViewModel build({
    ApiState overviewState = ApiState.ready,
    PregnancyOverviewData? overview,
    List<Map<String, dynamic>>? memories,
    List<Map<String, dynamic>>? questions,
  }) =>
      PregnancyViewModel(
        fetchOverview: ({String? dueDate}) async =>
            ApiResult<PregnancyOverviewData>(state: overviewState, data: overview),
        fetchBrief: ({String? dueDate, String? mode}) async =>
            ApiResult<PregnancyTodayBriefData>(state: ApiState.ready),
        fetchBaseline: () async =>
            ApiResult<Map<String, dynamic>>(state: ApiState.ready, data: {'week': 20}),
        fetchMemories: () async =>
            ApiResult<List<Map<String, dynamic>>>(state: ApiState.ready, data: memories),
        fetchQuestions: () async =>
            ApiResult<List<Map<String, dynamic>>>(state: ApiState.ready, data: questions),
      );

  test('starts loading', () {
    final vm = build();
    expect(vm.isLoading, isTrue);
    expect(vm.overviewState, ApiState.loading);
  });

  test('a full load fills every field and clears loading', () async {
    final vm = build(
      overview: PregnancyOverviewData.fromJson({'week': 20}),
      memories: [{'id': 'm1'}],
      questions: [{'id': 'q1'}],
    );
    await vm.load(dueDate: '2027-01-01', mode: 'body');

    expect(vm.isLoading, isFalse);
    expect(vm.overviewState, ApiState.ready);
    expect(vm.baselineData?['week'], 20);
    expect(vm.memories, hasLength(1));
    expect(vm.questions, hasLength(1));
  });

  test('server nulls leave memories/questions untouched, for local rehydration', () async {
    final vm = build(memories: null, questions: null);
    await vm.load();
    // null means "server had none" -- the View keeps whatever it rehydrated.
    expect(vm.memories, isNull);
    expect(vm.questions, isNull);
  });

  test('loading always clears even if a fetch resolves oddly', () async {
    final vm = build(overviewState: ApiState.offline);
    await vm.load();
    expect(vm.isLoading, isFalse, reason: 'the screen must never strand on a spinner');
    expect(vm.overviewState, ApiState.offline);
  });

  test('refreshBaseline updates only the baseline and notifies', () async {
    final vm = build();
    await vm.load();
    var n = 0;
    vm.addListener(() => n++);
    await vm.refreshBaseline();
    expect(vm.baselineData?['week'], 20);
    expect(n, greaterThan(0));
  });

  test('cache-first: shows the cached overview at once, then the server replaces it', () async {
    final cached = PregnancyOverviewData.fromJson({'week': 18});
    final server = PregnancyOverviewData.fromJson({'week': 22});
    final gate = Completer<ApiResult<PregnancyOverviewData>>();

    final vm = PregnancyViewModel(
      readCachedOverview: () => cached,
      readCachedBrief: () => null,
      fetchOverview: ({String? dueDate}) => gate.future,
      fetchBrief: ({String? dueDate, String? mode}) async =>
          ApiResult<PregnancyTodayBriefData>(state: ApiState.ready),
      fetchBaseline: () async => ApiResult<Map<String, dynamic>>(state: ApiState.ready),
      fetchMemories: () async => ApiResult<List<Map<String, dynamic>>>(state: ApiState.ready),
      fetchQuestions: () async => ApiResult<List<Map<String, dynamic>>>(state: ApiState.ready),
    );
    final done = vm.load();

    // Synchronous cache emission, before the network resolves.
    expect(vm.overview, same(cached));
    expect(vm.overviewState, ApiState.stale);
    expect(vm.isLoading, isFalse);

    gate.complete(ApiResult<PregnancyOverviewData>(state: ApiState.ready, data: server));
    await done;
    expect(vm.overview, same(server));
    expect(vm.overviewState, ApiState.ready);
  });
}
