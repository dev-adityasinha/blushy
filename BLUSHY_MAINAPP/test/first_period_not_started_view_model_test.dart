import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/features/home/view_models/first_period_not_started_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The insight load for the "first period, not started" stage, tested with no
/// widget. The point of the stage's view model is the distinction the screen
/// used to blur: a thought from the server versus the seeded daily fallback.
void main() {
  ApiResult<Map<String, dynamic>> _res(ApiState s, {Map<String, dynamic>? d}) =>
      ApiResult<Map<String, dynamic>>(state: s, data: d);

  test('a server thought is taken and the state is ready', () async {
    final vm = FirstPeriodNotStartedViewModel(
      fetchInsights: () async => _res(ApiState.ready, d: {'thought': 'Today you are enough.'}),
    );
    await vm.load();
    expect(vm.insightState, ApiState.ready);
    expect(vm.isLoading, isFalse);
    expect(vm.siaThought, 'Today you are enough.');
  });

  test('it falls back through summary/insight/headline keys', () async {
    final vm = FirstPeriodNotStartedViewModel(
      fetchInsights: () async => _res(ApiState.ready, d: {'headline': 'A steady day.'}),
    );
    await vm.load();
    expect(vm.siaThought, 'A steady day.');
  });

  test('an empty read leaves the thought null for the seeded fallback', () async {
    final vm = FirstPeriodNotStartedViewModel(
      fetchInsights: () async => _res(ApiState.empty, d: const {}),
    );
    await vm.load();
    expect(vm.insightState, ApiState.empty);
    expect(vm.siaThought, isNull, reason: 'the View shows its own daily note');
  });

  test('a blank thought string is not taken', () async {
    final vm = FirstPeriodNotStartedViewModel(
      fetchInsights: () async => _res(ApiState.ready, d: {'thought': '   '}),
    );
    await vm.load();
    expect(vm.siaThought, isNull);
  });

  test('a thrown read records offline, not a false empty', () async {
    final vm = FirstPeriodNotStartedViewModel(
      fetchInsights: () async => throw Exception('no network'),
    );
    await vm.load();
    expect(vm.insightState, ApiState.offline);
    expect(vm.isLoading, isFalse);
    expect(vm.siaThought, isNull);
  });

  test('notifies its listeners so the View can rebuild', () async {
    var n = 0;
    final vm = FirstPeriodNotStartedViewModel(
      fetchInsights: () async => _res(ApiState.ready, d: const {}),
    )..addListener(() => n++);
    await vm.load();
    expect(n, greaterThan(0));
  });
}
