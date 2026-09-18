import '../../../core/view_model.dart';
import '../../../services/api_contract_client.dart';
import '../../../services/api_perimenopause_service.dart';

/// The state and load logic behind the perimenopause dashboard.
///
/// The screen is the View: it renders, keeps the local quick-ask field and the
/// period-tracker state it rehydrates from storage. What it used to also own --
/// the two server reads, the ApiState verdict, and the focus/cycle-history
/// pulled out of the overview -- lives here, testable without the widget.
///
/// The fetches are injected (defaulting to the real singleton calls) because
/// ApiPerimenopauseService is a static singleton with no seam for a fake.
class PerimenopauseViewModel extends BlushyViewModel {
  PerimenopauseViewModel({
    Future<ApiResult<PerimenopauseOverviewData>> Function()? fetchOverview,
    Future<ApiResult<PerimenopauseTodayBriefData>> Function()? fetchBrief,
    PerimenopauseOverviewData? Function()? readCachedOverview,
    PerimenopauseTodayBriefData? Function()? readCachedBrief,
  })  : _fetchOverview = fetchOverview ?? ApiPerimenopauseService.getOverview,
        _fetchBrief = fetchBrief ?? ApiPerimenopauseService.getTodayBrief,
        _readCachedOverview = readCachedOverview ?? ApiPerimenopauseService.cachedOverview,
        _readCachedBrief = readCachedBrief ?? ApiPerimenopauseService.cachedBrief;

  final Future<ApiResult<PerimenopauseOverviewData>> Function() _fetchOverview;
  final Future<ApiResult<PerimenopauseTodayBriefData>> Function() _fetchBrief;
  final PerimenopauseOverviewData? Function() _readCachedOverview;
  final PerimenopauseTodayBriefData? Function() _readCachedBrief;

  ApiState overviewState = ApiState.loading;
  PerimenopauseOverviewData? overview;
  PerimenopauseTodayBriefData? todayBrief;
  bool isLoading = true;

  /// Derived from the overview when it loads; the defaults match what the
  /// screen showed before a first successful fetch.
  String activeFocus = 'sleep';
  List<int> cycleHistory = [];

  /// [silent] mirrors the screen's refresh path: a background reload does not
  /// flip the full-screen loading state, only the data.
  Future<void> load({bool silent = false}) async {
    // Cache-first: show the last known overview/brief at once (labelled stale),
    // so a returning user is not held on a spinner while the network answers.
    // First load only, and only a head start -- the fetch below replaces it.
    var shownFromCache = false;
    if (overview == null) {
      final cachedOverview = _readCachedOverview();
      if (cachedOverview != null) {
        overview = cachedOverview;
        activeFocus = cachedOverview.profile['currentFocus']?.toString() ?? 'sleep';
        if (cachedOverview.cycleHistory.isNotEmpty) {
          cycleHistory = cachedOverview.cycleHistory;
        }
        todayBrief = _readCachedBrief() ?? todayBrief;
        overviewState = ApiState.stale;
        isLoading = false;
        shownFromCache = true;
        safeNotify();
      }
    }

    // Only show the full spinner when there was nothing to show from cache;
    // once cache is on screen the fetch refreshes it in place.
    if (!silent && !shownFromCache) {
      isLoading = true;
      safeNotify();
    }
    try {
      final results = await Future.wait([_fetchOverview(), _fetchBrief()]);
      final overviewRes = results[0] as ApiResult<PerimenopauseOverviewData>;
      final briefRes = results[1] as ApiResult<PerimenopauseTodayBriefData>;
      final overviewData = overviewRes.data;
      final briefData = briefRes.data;

      overviewState = overviewRes.state;
      if (overviewData != null) {
        overview = overviewData;
        activeFocus = overviewData.profile['currentFocus']?.toString() ?? 'sleep';
        if (overviewData.cycleHistory.isNotEmpty) {
          cycleHistory = overviewData.cycleHistory;
        }
      }
      if (briefData != null) {
        todayBrief = briefData;
      }
    } catch (_) {
      // A thrown read leaves the last-known data in place, exactly as the
      // screen's own try/catch did; only the spinner is cleared.
    } finally {
      isLoading = false;
      safeNotify();
    }
  }
}
