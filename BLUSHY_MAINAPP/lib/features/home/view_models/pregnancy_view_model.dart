import '../../../core/view_model.dart';
import '../../../services/api_contract_client.dart';
import '../../../services/api_pregnancy_service.dart';

/// The pregnancy data-load concern, lifted out of the dashboard.
///
/// The screen loads five things in parallel on open -- overview, today's
/// brief, the baseline, memories and questions -- and needs to know how the
/// read went (`ApiState`). That is the ViewModel's job. Memories and questions
/// stay null when the server returns nothing so the View can keep whatever it
/// rehydrated locally, exactly as the widget did.
///
/// The fetches are injected as functions (defaulting to the static service) so
/// this can be unit-tested without the network.
class PregnancyViewModel extends BlushyViewModel {
  PregnancyViewModel({
    Future<ApiResult<PregnancyOverviewData>> Function({String? dueDate})? fetchOverview,
    Future<ApiResult<PregnancyTodayBriefData>> Function({String? dueDate, String? mode})? fetchBrief,
    Future<ApiResult<Map<String, dynamic>>> Function()? fetchBaseline,
    Future<ApiResult<List<Map<String, dynamic>>>> Function()? fetchMemories,
    Future<ApiResult<List<Map<String, dynamic>>>> Function()? fetchQuestions,
    PregnancyOverviewData? Function()? readCachedOverview,
    PregnancyTodayBriefData? Function()? readCachedBrief,
  })  : _fetchOverview = fetchOverview ?? ApiPregnancyService.getOverview,
        _fetchBrief = fetchBrief ?? ApiPregnancyService.getTodayBrief,
        _fetchBaseline = fetchBaseline ?? ApiPregnancyService.getBaseline,
        _fetchMemories = fetchMemories ?? ApiPregnancyService.getMemories,
        _fetchQuestions = fetchQuestions ?? ApiPregnancyService.getQuestions,
        _readCachedOverview = readCachedOverview ?? ApiPregnancyService.cachedOverview,
        _readCachedBrief = readCachedBrief ?? ApiPregnancyService.cachedBrief;

  final PregnancyOverviewData? Function() _readCachedOverview;
  final PregnancyTodayBriefData? Function() _readCachedBrief;

  final Future<ApiResult<PregnancyOverviewData>> Function({String? dueDate}) _fetchOverview;
  final Future<ApiResult<PregnancyTodayBriefData>> Function({String? dueDate, String? mode}) _fetchBrief;
  final Future<ApiResult<Map<String, dynamic>>> Function() _fetchBaseline;
  final Future<ApiResult<List<Map<String, dynamic>>>> Function() _fetchMemories;
  final Future<ApiResult<List<Map<String, dynamic>>>> Function() _fetchQuestions;

  ApiState overviewState = ApiState.loading;
  PregnancyOverviewData? overview;
  PregnancyTodayBriefData? todayBrief;
  Map<String, dynamic>? baselineData;
  List<Map<String, dynamic>>? memories;
  List<Map<String, dynamic>>? questions;
  bool isLoading = true;

  Future<void> load({String? dueDate, String? mode}) async {
    // Cache-first: show the last known overview/brief at once (labelled stale),
    // so a returning user is not held on a spinner while the network answers.
    // First load only, and only a head start -- the fetch below replaces it.
    if (overview == null) {
      final cached = _readCachedOverview();
      if (cached != null) {
        overview = cached;
        todayBrief = _readCachedBrief() ?? todayBrief;
        overviewState = ApiState.stale;
        isLoading = false;
        safeNotify();
      }
    }

    final results = await Future.wait([
      _fetchOverview(dueDate: dueDate),
      _fetchBrief(dueDate: dueDate, mode: mode),
      _fetchBaseline(),
      _fetchMemories(),
      _fetchQuestions(),
    ]);

    // try/finally so the loading flag always clears -- a throwing cast must not
    // strand the screen on its spinner for ever.
    try {
      final ovRes = results[0] as ApiResult<PregnancyOverviewData>;
      final brRes = results[1] as ApiResult<PregnancyTodayBriefData>;
      final baseRes = results[2] as ApiResult<Map<String, dynamic>>;
      final memRes = results[3] as ApiResult<List<Map<String, dynamic>>>;
      final qRes = results[4] as ApiResult<List<Map<String, dynamic>>>;

      overviewState = ovRes.state;
      if (ovRes.data != null) overview = ovRes.data;
      if (brRes.data != null) todayBrief = brRes.data;
      if (baseRes.data != null) baselineData = baseRes.data;
      if (memRes.data != null) memories = memRes.data;
      if (qRes.data != null) questions = qRes.data;
    } finally {
      isLoading = false;
      safeNotify();
    }
  }

  /// The targeted baseline refresh used after a daily check-in.
  Future<void> refreshBaseline() async {
    final res = await _fetchBaseline();
    if (res.data != null) baselineData = res.data;
    safeNotify();
  }
}
