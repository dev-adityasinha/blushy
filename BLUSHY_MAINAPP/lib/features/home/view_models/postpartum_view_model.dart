import '../../../core/view_model.dart';
import '../../../services/api_contract_client.dart';
import '../../../services/api_postpartum_service.dart';

/// The postpartum data-load concern, lifted out of the dashboard.
///
/// The screen needs three things on load: the overview, today's brief, and how
/// the read went (`ApiState`, so "nothing yet" and "could not load" stay
/// distinct -- spec Sec.4/Sec.31). That is a ViewModel, not a widget's job, and
/// pulling it out means it can be tested without pumping the 2,200-line screen.
///
/// The two fetches are injected as functions so the static service does not
/// block testing.
class PostpartumViewModel extends BlushyViewModel {
  PostpartumViewModel({
    Future<ApiResult<PostpartumOverviewData>> Function()? fetchOverview,
    Future<ApiResult<PostpartumTodayBriefData>> Function()? fetchBrief,
  })  : _fetchOverview = fetchOverview ?? ApiPostpartumService.getOverview,
        _fetchBrief = fetchBrief ?? ApiPostpartumService.getTodayBrief;

  final Future<ApiResult<PostpartumOverviewData>> Function() _fetchOverview;
  final Future<ApiResult<PostpartumTodayBriefData>> Function() _fetchBrief;

  ApiState overviewState = ApiState.loading;
  PostpartumOverviewData? overview;
  PostpartumTodayBriefData? todayBrief;
  bool isLoading = true;

  bool get isLowEnergyMode => overview?.isLowEnergyMode ?? false;

  /// Today's check-in map, or null -- the screen seeds its form from this.
  Map<String, dynamic>? get todayCheckin => overview?.todayCheckin;

  Future<void> load() async {
    final overviewRes = await _fetchOverview();
    final briefRes = await _fetchBrief();
    overview = overviewRes.data;
    todayBrief = briefRes.data;
    overviewState = overviewRes.state;
    isLoading = false;
    safeNotify();
  }
}
