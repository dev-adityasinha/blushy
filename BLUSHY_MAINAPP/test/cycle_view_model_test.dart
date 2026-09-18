import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/services/api_period_service.dart';
import 'package:blushy_life_app/features/home/view_models/cycle_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// The point of MVVM: this logic is tested with no widget at all.
///
/// The cycle-loading concern used to live inside a 2,000-line dashboard's
/// State, reachable only by pumping the whole screen. As a view model it is a
/// plain object, so the exact behaviour behind the "sometimes it works" bug --
/// a dropped request must read as `offline`, never as an empty account -- can
/// be asserted directly.
Future<ApiResult<PeriodPrediction>> Function() _returns(ApiResult<PeriodPrediction> r) =>
    () async => r;
Future<ApiResult<PeriodPrediction>> _throws() async => throw Exception('network down');

void main() {
  useIsolatedStorage();

  test('starts in a loading state, before any read resolves', () {
    final vm = CycleViewModel(fetchPredictions: _throws);
    expect(vm.state, ApiState.loading);
    expect(vm.isResolved, isFalse);
    expect(vm.cycleDayOrNull, isNull, reason: 'no ring until a period is known');
  });

  test('a successful read fills the cycle and marks it logged', () async {
    final vm = CycleViewModel(fetchPredictions: _returns(ApiResult<PeriodPrediction>(
      state: ApiState.ready,
      data: PeriodPrediction(
        hasData: true,
        cycleLengthDays: 30,
        periodLengthDays: 6,
        lastPeriodStartDate: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      ),
    )));
    await vm.load();

    expect(vm.state, ApiState.ready);
    expect(vm.hasLoggedPeriod, isTrue);
    expect(vm.cycleLength, 30);
    expect(vm.periodLength, 6);
    expect(vm.cycleDayOrNull, isNotNull);
    expect(vm.cycleDayOrNull, inInclusiveRange(1, 30));
  });

  test('a dropped request reads as offline, not as an empty account', () async {
    final vm = CycleViewModel(fetchPredictions: _throws);
    await vm.load();

    // This is the whole bug in one assertion: a failure is not "no period".
    expect(vm.state, ApiState.offline);
    expect(vm.hasLoggedPeriod, isFalse);
    expect(vm.cycleDayOrNull, isNull);
  });

  test('an empty-but-successful read is a genuine no-period, and says so', () async {
    final vm = CycleViewModel(fetchPredictions: _returns(ApiResult<PeriodPrediction>(
      state: ApiState.ready,
      data: PeriodPrediction(hasData: false),
    )));
    await vm.load();

    expect(vm.isResolved, isTrue);
    expect(vm.state, ApiState.ready);
    expect(vm.hasLoggedPeriod, isFalse, reason: 'the server genuinely had nothing');
  });

  test('notifies its listeners so the View can rebuild', () async {
    final vm = CycleViewModel(fetchPredictions: _returns(ApiResult<PeriodPrediction>(
      state: ApiState.ready,
      data: PeriodPrediction(hasData: false),
    )));
    var notified = 0;
    vm.addListener(() => notified++);
    await vm.load();
    expect(notified, greaterThan(0));
  });
}
