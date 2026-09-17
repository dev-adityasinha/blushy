import '../../../core/view_model.dart';
import '../../../services/api_menopause_service.dart';
import '../../../services/api_contract_client.dart';

/// The state and load logic behind the menopause dashboard.
///
/// The screen is the View: it renders and owns the local check-in pickers.
/// What it used to also own -- the server read, the ApiState verdict, and the
/// life-mode/private-mode pulled out of the overview -- lives here, where it
/// can be tested without pumping a 2,000-line widget.
///
/// [fetchOverview] is injected (defaulting to the real singleton call) because
/// ApiMenopauseService is a static singleton with no seam for a fake.
class MenopauseViewModel extends BlushyViewModel {
  MenopauseViewModel({
    Future<ApiResult<MenopauseOverviewData>> Function()? fetchOverview,
    MenopauseOverviewData? Function()? readCache,
  })  : _fetchOverview = fetchOverview ?? ApiMenopauseService.getOverview,
        _readCache = readCache ?? ApiMenopauseService.cachedOverview;

  final Future<ApiResult<MenopauseOverviewData>> Function() _fetchOverview;
  final MenopauseOverviewData? Function() _readCache;

  ApiState overviewState = ApiState.loading;
  MenopauseOverviewData? overview;
  bool isLoading = true;

  /// Derived from the overview when it loads; the defaults match what the
  /// screen showed before a first successful fetch.
  String activeLifeMode = 'normal';
  bool privateMode = false;

  Future<void> load() async {
    // Cache-first: show the last known overview at once (labelled stale, not
    // passed off as fresh), so a returning user does not watch a spinner while
    // the network answers. Only on a first load, and only as a head start --
    // the fetch below always replaces it.
    if (overview == null) {
      final cached = _readCache();
      if (cached != null) {
        overview = cached;
        activeLifeMode = cached.lifeMode;
        privateMode = cached.privateMode;
        overviewState = ApiState.stale;
        isLoading = false;
        safeNotify();
      }
    }

    final res = await _fetchOverview();
    final data = res.data;
    overview = data;
    overviewState = res.state;
    if (data != null) {
      activeLifeMode = data.lifeMode;
      privateMode = data.privateMode;
    }
    isLoading = false;
    safeNotify();
  }
}
