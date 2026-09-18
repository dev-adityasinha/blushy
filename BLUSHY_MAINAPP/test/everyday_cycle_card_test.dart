import 'package:blushy_life_app/models/blushy_models.dart';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/features/home/presentation/stages/everyday_cycle_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// The "Today's Cycle" card state machine, tested directly -- it used to live
/// inside a 17,800-line widget. A fixed date formatter stands in for the
/// screen's own so the assertions are stable.
String _fmt(String? iso) {
  if (iso == null || iso.isEmpty) return 'Not available';
  final d = DateTime.tryParse(iso);
  if (d == null) return 'Not available';
  return '${d.month}/${d.day}';
}

Map<String, dynamic> _resolve(ApiState state, {CycleState? data, CycleState? lastKnown}) =>
    EverydayCycleCard.resolve(
      cycleResult: ApiResult<CycleState>(state: state, data: data),
      lastKnown: lastKnown,
      formatDayMonth: _fmt,
    );

void main() {
  test('a stage without cycle tracking is restricted, not empty', () {
    final r = _resolve(
      ApiState.ready,
      data: const CycleState(
        cycleTrackingAvailable: false,
        restrictedMessage: 'Paused during pregnancy.',
      ),
    );
    expect(r['state'], 'restricted');
    expect(r['subtitle'], 'Paused during pregnancy.');
  });

  test('a refresh does not blank a card that already has a day', () {
    // Loading, but we hold a previous answer -- the documented bug was showing
    // "Not Logged" here.
    final r = _resolve(
      ApiState.loading,
      lastKnown: const CycleState(currentCycleDay: 12),
    );
    expect(r['isLogged'], isTrue);
    expect(r['cycleDay'], 12);
  });

  test('loading with nothing known shows a loading state', () {
    final r = _resolve(ApiState.loading);
    expect(r['state'], 'loading');
    expect(r['isLogged'], isFalse);
  });

  test('an empty read says not logged', () {
    final r = _resolve(ApiState.empty);
    expect(r['state'], 'empty');
    expect(r['cycleDay'], isNull);
  });

  test('offline with no cached cycle is surfaced as offline', () {
    final r = _resolve(ApiState.offline);
    expect(r['state'], 'offline');
    expect(r['cycleDayText'], 'Cycle Day unavailable');
  });

  test('a ready cycle without enough history withholds predictions', () {
    final r = _resolve(
      ApiState.ready,
      data: const CycleState(currentCycleDay: 8, phase: 'Follicular'),
    );
    expect(r['isLogged'], isTrue);
    expect(r['cycleDay'], 8);
    expect(r['cycleDayText'], 'Cycle Day 8');
    expect(r['expectedPeriod'], 'Not enough data yet');
    expect(r['phaseName'], 'Follicular');
  });

  test('an overdue period is surfaced as late', () {
    final r = _resolve(
      ApiState.ready,
      data: const CycleState(currentCycleDay: 33, isOverdue: true, daysOverdue: 5),
    );
    expect(r['isOverdue'], isTrue);
    expect(r['cycleDayText'], 'Day 33 · 5 days late');
    expect(r['subtitle'], contains('5 day'));
  });

  test('predictions format through the injected formatter', () {
    final r = _resolve(
      ApiState.ready,
      data: const CycleState(
        currentCycleDay: 20,
        nextPeriodStartDate: '2026-10-01',
        estimatedOvulationDate: '2026-09-20',
      ),
    );
    expect(r['expectedPeriod'], '10/1');
    expect(r['ovulationText'], '9/20');
    expect(r['recTestDay'], '10/4', reason: 'three days after the next period');
  });
}
