import '../../../core/storage.dart';
import '../../../core/view_model.dart';
import '../../../services/api_contract_client.dart';
import '../../../services/api_period_service.dart';

/// The cycle-loading concern, lifted out of the dashboards that share it.
///
/// Every cycle dashboard (trying to conceive, hormonal health, first period
/// started, living with my cycle, everyday wellness) needs the same four
/// things: has she logged a period, when, what her cycle/period lengths are,
/// and -- crucially -- *how the read went*, so "nothing logged" and "could not
/// load" stop looking identical. That last distinction is the bug we chased
/// across those screens: a swallowed error made a slow backend read as an
/// account with no cycle.
///
/// Holding it in one tested view model means the fix lives in one place instead
/// of being re-derived, slightly differently, inside five 2,000-line widgets.
class CycleViewModel extends BlushyViewModel {
  /// The fetch is injected as a function so the view model can be unit-tested
  /// without the real service (a singleton with no test seam). Defaults to the
  /// live call.
  CycleViewModel({Future<ApiResult<PeriodPrediction>> Function()? fetchPredictions})
      : _fetch = fetchPredictions ?? (() => ApiPeriodService().getPredictionsResult());

  final Future<ApiResult<PeriodPrediction>> Function() _fetch;

  /// How the read went. `loading` until the first load resolves.
  ApiState state = ApiState.loading;

  bool hasLoggedPeriod = false;
  DateTime? lastPeriodStart;
  int cycleLength = 29;
  int periodLength = 5;
  int currentCycleDay = 14;

  /// True once a load has succeeded or failed at least once.
  bool get isResolved => state != ApiState.loading;

  /// The day count, or null when nothing is logged -- the View shows the ring
  /// only when this is present, so it can never invent a "Day 14".
  int? get cycleDayOrNull => hasLoggedPeriod ? currentCycleDay : null;

  /// Reads the local last-period cache first (instant, offline-safe), then the
  /// server. The server wins when it has data; a dropped request leaves the
  /// local read in place and records `offline`, never "no period logged".
  Future<void> load() async {
    _applyLocalCache();
    safeNotify();

    try {
      final result = await _fetch();
      state = result.state;
      final prediction = result.data;
      if (prediction != null && prediction.hasData) {
        if (prediction.cycleLengthDays > 0) cycleLength = prediction.cycleLengthDays;
        if (prediction.periodLengthDays > 0) periodLength = prediction.periodLengthDays;
        final start = prediction.lastPeriodStartDate == null
            ? null
            : DateTime.tryParse(prediction.lastPeriodStartDate!);
        if (start != null) {
          lastPeriodStart = start;
          hasLoggedPeriod = true;
          currentCycleDay = _dayFrom(start);
        }
      }
    } catch (_) {
      // A dropped request is not an account with no cycle.
      state = ApiState.offline;
    }
    safeNotify();
  }

  void _applyLocalCache() {
    try {
      final saved = BlushyStorage.read('last_period_entry.json');
      final raw = saved['periodStartDate'];
      if (raw != null) {
        final parsed = DateTime.tryParse(raw.toString());
        if (parsed != null) {
          lastPeriodStart = parsed;
          hasLoggedPeriod = true;
          currentCycleDay = _dayFrom(parsed);
        }
      }
    } catch (_) {}
  }

  int _dayFrom(DateTime start) {
    final diff = DateTime.now().difference(start).inDays;
    return ((diff % cycleLength) + 1).clamp(1, cycleLength);
  }
}
