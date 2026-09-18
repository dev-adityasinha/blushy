import '../../../core/view_model.dart';
import '../../../services/api_contract_client.dart';
import '../../../services/api_sia_service.dart';

/// The insight load behind the "first period, not started yet" dashboard.
///
/// This stage has no cycle to report on, so the only server-driven thing on
/// the screen is today's Sia thought -- and, just as importantly, whether it
/// actually came from the server or fell back to the seeded daily note. That
/// distinction (the ApiState verdict) used to be an assignment buried in the
/// widget's fetch; here it is the model's contract, testable without a widget.
///
/// The fetch is injected (defaulting to the real call) because ApiSiaService
/// is constructed inline with no seam for a fake.
class FirstPeriodNotStartedViewModel extends BlushyViewModel {
  FirstPeriodNotStartedViewModel({
    Future<ApiResult<Map<String, dynamic>>> Function()? fetchInsights,
  }) : _fetchInsights =
            fetchInsights ?? (() => ApiSiaService().getHealthInsightsResult());

  final Future<ApiResult<Map<String, dynamic>>> Function() _fetchInsights;

  ApiState insightState = ApiState.loading;
  bool isLoading = false;

  /// Today's server thought, or null to let the View show its seeded fallback.
  String? siaThought;

  Future<void> load() async {
    isLoading = true;
    safeNotify();
    try {
      final result = await _fetchInsights();
      insightState = result.state;
      final insights = result.data ?? const <String, dynamic>{};
      if (insights.isNotEmpty) {
        final thought = insights['thought'] ??
            insights['summary'] ??
            insights['insight'] ??
            insights['headline'];
        if (thought is String && thought.trim().isNotEmpty) {
          siaThought = thought;
        }
      }
    } catch (_) {
      // Fall back to the seeded daily thought, but record that the note on
      // screen is not from her own data.
      insightState = ApiState.offline;
    } finally {
      isLoading = false;
      safeNotify();
    }
  }
}
