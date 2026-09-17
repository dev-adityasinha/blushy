import '../../../core/view_model.dart';
import '../../../models/blushy_models.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/api_partner_service.dart';
import '../../../services/auth_storage.dart';
import '../../../services/api_contract_client.dart';

/// The load behind the partner profile screen.
///
/// The screen is the View: it renders, owns the name TextEditingController and
/// the in-flight `_notificationsSaving` flag, the notification toggle and its
/// snackbars. What it used to also own -- reading the session, the notification
/// preferences and the active connection -- lives here, testable without a
/// widget. The View mirrors the loaded prefs and still updates them in place
/// after its own toggle, exactly as before.
///
/// The reads are injected (defaulting to the real calls) so a test can drive
/// the load without a server or stored session.
class PartnerProfileViewModel extends BlushyViewModel {
  PartnerProfileViewModel({
    Map<String, dynamic> Function()? readSession,
    Future<ApiResult<NotificationPreferences>> Function()? fetchPreferences,
    Future<List<Map<String, dynamic>>> Function()? fetchConnections,
  })  : _readSession = readSession ?? AuthStorage.getSession,
        _fetchPreferences = fetchPreferences ?? NotificationsApi.preferences,
        _fetchConnections =
            fetchConnections ?? (() => ApiPartnerService().getConnections());

  final Map<String, dynamic> Function() _readSession;
  final Future<ApiResult<NotificationPreferences>> Function() _fetchPreferences;
  final Future<List<Map<String, dynamic>>> Function() _fetchConnections;

  bool isLoading = true;
  Map<String, dynamic>? activeConnection;
  String userEmail = '';
  String userName = '';
  NotificationPreferences? notificationPrefs;

  Future<void> load() async {
    try {
      final session = _readSession();
      userEmail = session['email']?.toString() ?? 'partner@blushy.life';
      userName = userEmail.contains('@') ? userEmail.split('@').first : 'Partner';

      final prefsResult = await _fetchPreferences();
      if (prefsResult.data != null) {
        notificationPrefs = prefsResult.data;
      }

      final connections = await _fetchConnections();
      final active = connections.firstWhere(
        (c) => c['status'] == 'active',
        orElse: () => <String, dynamic>{},
      );
      activeConnection = active.isNotEmpty ? active : null;
    } catch (_) {
      // Leave whatever loaded in place; the finally clears the spinner.
    } finally {
      isLoading = false;
      safeNotify();
    }
  }
}
