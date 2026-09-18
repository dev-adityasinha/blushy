import '../../../core/view_model.dart';
import '../../../models/blushy_models.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';

/// The load behind the partner privacy screen.
///
/// The load has real branching -- the matrix failing, no connection yet, and a
/// context read that only partly succeeds -- which used to live inside the
/// widget's State where it could only be exercised by pumping the screen. As a
/// view model each branch is asserted directly. The View keeps rendering and
/// the in-flight `_sendingRequests` set; it delegates the read and the
/// "is this category shared" test here.
///
/// Fetches are injected (defaulting to the real static calls) so a test can
/// drive every branch without a server.
class PartnerPrivacyViewModel extends BlushyViewModel {
  PartnerPrivacyViewModel({
    required String? connectionId,
    Future<ApiResult<List<PartnerPermission>>> Function()? fetchMatrix,
    Future<ApiResult<Map<String, dynamic>>> Function()? fetchContext,
    Future<ApiResult<List<Map<String, dynamic>>>> Function()? fetchRequests,
  })  : _connectionId = connectionId,
        _fetchMatrix = fetchMatrix ?? PartnerApi.permissionMatrix,
        _fetchContext = fetchContext ??
            ((connectionId == null || connectionId.isEmpty)
                ? (() async => const ApiResult<Map<String, dynamic>>.loading())
                : (() => PartnerApi.context(connectionId))),
        _fetchRequests = fetchRequests ??
            ((connectionId == null || connectionId.isEmpty)
                ? (() async =>
                    const ApiResult<List<Map<String, dynamic>>>.loading())
                : (() =>
                    PartnerApi.permissionRequests(connectionId, states: 'pending')));

  final String? _connectionId;
  final Future<ApiResult<List<PartnerPermission>>> Function() _fetchMatrix;
  final Future<ApiResult<Map<String, dynamic>>> Function() _fetchContext;
  final Future<ApiResult<List<Map<String, dynamic>>>> Function() _fetchRequests;

  bool loading = true;
  String? error;
  List<PartnerPermission> matrix = const [];
  Set<String> allowedGrants = const {};

  /// Permission keys with a request already waiting.
  Set<String> pendingRequests = <String>{};

  Future<void> load() async {
    loading = true;
    error = null;
    safeNotify();

    final matrixResult = await _fetchMatrix();
    if (matrixResult.data == null) {
      loading = false;
      error = matrixResult.errorMessage ?? 'Could not load the sharing categories.';
      safeNotify();
      return;
    }

    final connectionId = _connectionId;
    if (connectionId == null || connectionId.isEmpty) {
      matrix = matrixResult.data!;
      allowedGrants = const {};
      loading = false;
      safeNotify();
      return;
    }

    // The grants come back in the response envelope rather than the body: the
    // context itself is the filtered data, and `permissions` says why.
    final contextResult = await _fetchContext();
    final granted = <String>{};
    final permissions = contextResult.permissions;
    if (permissions != null && permissions['allowedGrants'] is List) {
      for (final grant in permissions['allowedGrants'] as List) {
        granted.add(grant.toString());
      }
    }

    final requests = await _fetchRequests();

    matrix = matrixResult.data!;
    allowedGrants = granted;
    pendingRequests = {
      for (final request in requests.data ?? const <Map<String, dynamic>>[])
        request['permissionKey']?.toString() ?? '',
    }..removeWhere((key) => key.isEmpty);
    loading = false;
    if (contextResult.state == ApiState.offline ||
        contextResult.state == ApiState.error) {
      error =
          'Showing categories only. Could not reach the server for what is currently shared.';
    }
    safeNotify();
  }

  /// A category counts as shared when the partner holds any of its grants.
  ///
  /// The grants come from the matrix endpoint rather than a table kept here.
  /// A local copy drifts silently: when a category's grants change server-side,
  /// it would simply start reporting itself as not shared.
  bool isShared(PartnerPermission permission) {
    if (permission.grants.isEmpty) return permission.enabled;
    return permission.grants.any(allowedGrants.contains);
  }
}
