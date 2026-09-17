import '../../../core/view_model.dart';
import '../../../models/blushy_models.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';

/// The load behind the partner sharing screen.
///
/// The screen is the View: it renders the toggles, keeps the in-flight
/// `_saving`/`_answering` sets, and shows snackbars (which need a
/// BuildContext). What it used to also own -- the two reads that build the
/// sharing state and the list of pending requests -- lives here, testable
/// without a widget. Mutations stay on the View and call [load] to refresh,
/// exactly as the screen already re-read after every change.
///
/// The fetches are injected (defaulting to the real static calls) so a test
/// can drive the load without a server.
class PartnerSharingViewModel extends BlushyViewModel {
  PartnerSharingViewModel({
    required String connectionId,
    Future<ApiResult<PartnerSharingState>> Function()? fetchSharingState,
    Future<ApiResult<List<Map<String, dynamic>>>> Function()? fetchPendingRequests,
  })  : _fetchSharingState =
            fetchSharingState ?? (() => PartnerApi.sharingState(connectionId)),
        _fetchPendingRequests = fetchPendingRequests ??
            (() => PartnerApi.permissionRequests(connectionId, states: 'pending'));

  final Future<ApiResult<PartnerSharingState>> Function() _fetchSharingState;
  final Future<ApiResult<List<Map<String, dynamic>>>> Function()
      _fetchPendingRequests;

  ApiResult<PartnerSharingState> result = const ApiResult.loading();

  /// Requests the partner has made and is waiting on.
  List<Map<String, dynamic>> pendingRequests = const [];

  Future<void> load() async {
    result = const ApiResult.loading();
    safeNotify();
    final sharing = await _fetchSharingState();
    final requests = await _fetchPendingRequests();
    result = sharing;
    pendingRequests = requests.data ?? const [];
    safeNotify();
  }
}
