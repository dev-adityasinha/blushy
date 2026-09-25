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
  ///
  /// Each cycle dashboard shipped its own defaults (28 or 29 or 32 days; a
  /// not-logged ring day of 1 or 14), so they are constructor parameters here
  /// rather than baked in -- a screen keeps its exact numbers.
  CycleViewModel({
    Future<ApiResult<PeriodPrediction>> Function()? fetchPredictions,
    int defaultCycleLength = 28,
    int defaultPeriodLength = 5,
    int defaultCycleDay = 14,
  }) : _fetch = fetchPredictions ?? (() => ApiPeriodService().getPredictionsResult()) {
    cycleLength = defaultCycleLength;
    periodLength = defaultPeriodLength;
    currentCycleDay = defaultCycleDay;
  }

  final Future<ApiResult<PeriodPrediction>> Function() _fetch;

  /// How the read went. `loading` until the first load resolves.
  ApiState state = ApiState.loading;

  bool hasLoggedPeriod = false;
  DateTime? lastPeriodStart;
  int cycleLength = 28;
  int periodLength = 5;
  int currentCycleDay = 14;

  /// How many complete cycles the backend has learned from. Drives the
  /// "personalised rhythm" note: below 2, the baseline is still an estimate.
  int completedCyclesCount = 0;

  /// Forward-looking predictions (ISO date strings), for a forecast bar. Null
  /// until a prediction with these has loaded (and null on hormonal
  /// contraception, where the server withholds ovulation/fertile dates).
  String? nextPeriodStartDate;
  String? estimatedOvulationDate;
  String? fertileWindowStart;
  String? fertileWindowEnd;

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
      final start = prediction?.lastPeriodStartDate == null
          ? null
          : DateTime.tryParse(prediction!.lastPeriodStartDate!);

      // A logged period is a real day even when the server flags the history
      // as too short for predictions (`hasData == false`). The day was gated
      // on `hasData`, so an account with a real last-period date but limited
      // history fell through to the screen's placeholder -- Day 1 on the
      // first-period screen, Day 14 elsewhere -- rather than her real day.
      // Apply it whenever a start date is present; only a genuinely empty
      // read (no data and no start) leaves the defaults untouched.
      if (prediction != null && (prediction.hasData || start != null)) {
        if (prediction.cycleLengthDays > 0) cycleLength = prediction.cycleLengthDays;
        if (prediction.periodLengthDays > 0) periodLength = prediction.periodLengthDays;
        completedCyclesCount = prediction.completedCyclesCount;
        nextPeriodStartDate = prediction.nextPeriodStartDate;
        estimatedOvulationDate = prediction.estimatedOvulationDate;
        fertileWindowStart = prediction.fertileWindowStart;
        fertileWindowEnd = prediction.fertileWindowEnd;
        if (start != null) {
          lastPeriodStart = start;
          hasLoggedPeriod = true;
          // Prefer the server's own current-cycle day: it is timezone-correct
          // and already counts overdue days straight past the cycle length.
          // Recompute locally only when the server did not send one (the
          // offline cache path).
          final serverDay = prediction.currentCycleDay;
          currentCycleDay =
              (serverDay != null && serverDay > 0) ? serverDay : _dayFrom(start);
        }
      }
    } catch (_) {
      // A dropped request is not an account with no cycle.
      state = ApiState.offline;
    }
    safeNotify();
  }

  void _applyLocalCache() {
    DateTime? start;
    try {
      final profile = BlushyStorage.read('user_profile.json');
      final fromProfile = profile['lastPeriodStartDate'] ??
          profile['last_period_date'] ??
          (profile['profile'] is Map ? profile['profile']['lastPeriodStartDate'] : null);
      if (fromProfile != null) start = DateTime.tryParse(fromProfile.toString());
    } catch (_) {}
    try {
      final saved = BlushyStorage.read('last_period_entry.json');
      final raw = saved['periodStartDate'];
      if (raw != null) start = DateTime.tryParse(raw.toString()) ?? start;
    } catch (_) {}

    if (start != null) {
      lastPeriodStart = start;
      hasLoggedPeriod = true;
      currentCycleDay = _dayFrom(start);
    }
  }

  int _dayFrom(DateTime start) {
    // Days since the last logged period, counted straight through, the same
    // way the backend computes currentCycleDay -- a period logged about a
    // cycle ago is an overdue "Day 30-something", not a rolled-over "Day 1".
    //
    // The old `% cycleLength` invented cycles that were never logged: a last
    // period entered ~one cycle back (e.g. 30 days, 30-day cycle) rolled to
    // `30 % 30 + 1 = 1`, so the tracker dropped to Day 1 on the next reload.
    // The upper bound only guards a corrupt far-past date.
    final diff = DateTime.now().difference(start).inDays;
    return (diff + 1).clamp(1, 999);
  }
}
