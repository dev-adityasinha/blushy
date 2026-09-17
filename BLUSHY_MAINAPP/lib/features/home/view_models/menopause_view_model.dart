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
  }) : _fetchOverview = fetchOverview ?? ApiMenopauseService.getOverview;

  final Future<ApiResult<MenopauseOverviewData>> Function() _fetchOverview;

  ApiState overviewState = ApiState.loading;
  MenopauseOverviewData? overview;
  bool isLoading = true;

  /// Derived from the overview when it loads; the defaults match what the
  /// screen showed before a first successful fetch.
  String activeLifeMode = 'normal';
  bool privateMode = false;

  Future<void> load() async {
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
