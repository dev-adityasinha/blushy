import '../../../core/view_model.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';
import '../../../services/auth_storage.dart';
import '../../../services/journal_storage.dart';
import '../../journal/repository/journal_repository.dart';

/// The three independent loads behind the M Studio hub.
///
/// The screen is the View: it renders the hub, opens capsules (which needs a
/// BuildContext for the dialog and snackbar) and refreshes the open section.
/// The reads -- guided recovery sessions, memory capsules, and the most recent
/// journal entry, including the "newest first" sort -- live here, testable
/// without a widget. Each read keeps its own loading flag, exactly as the
/// screen showed them.
///
/// The reads are injected (defaulting to the real calls) so a test can drive
/// them without a server or local store.
class MStudioViewModel extends BlushyViewModel {
  MStudioViewModel({
    Future<ApiResult<List<Map<String, dynamic>>>> Function()? fetchSessions,
    Future<ApiResult<List<Map<String, dynamic>>>> Function()? fetchCapsules,
    Future<List<LocalJournalEntry>> Function()? fetchEntries,
  })  : _fetchSessions = fetchSessions ?? RecoveryApi.sessions,
        _fetchCapsules = fetchCapsules ?? CapsulesApi.list,
        _fetchEntries = fetchEntries ??
            (() =>
                JournalRepository().getAllEntries(AuthStorage.getUserId() ?? 'anon'));

  final Future<ApiResult<List<Map<String, dynamic>>>> Function() _fetchSessions;
  final Future<ApiResult<List<Map<String, dynamic>>>> Function() _fetchCapsules;
  final Future<List<LocalJournalEntry>> Function() _fetchEntries;

  /// Guided sessions from the server. Empty until a reviewer approves them.
  List<Map<String, dynamic>> sessions = [];
  bool sessionsLoading = false;

  List<Map<String, dynamic>> capsules = [];
  bool capsulesLoading = false;

  LocalJournalEntry? latestEntry;

  Future<void> loadSessions() async {
    sessionsLoading = true;
    safeNotify();
    final result = await _fetchSessions();
    sessionsLoading = false;
    sessions = result.data ?? const [];
    safeNotify();
  }

  Future<void> loadCapsules() async {
    capsulesLoading = true;
    safeNotify();
    final result = await _fetchCapsules();
    capsulesLoading = false;
    // No seeded placeholders. An empty list is what a new account has.
    capsules = result.data ?? const [];
    safeNotify();
  }

  /// The most recent thing written, for the studio's own recent list.
  ///
  /// Read from the journal's own store rather than invented: an account that
  /// has written nothing shows nothing, which is the honest empty state.
  Future<void> loadLatestEntry() async {
    final entries = await _fetchEntries();
    final sorted = entries.toList()
      ..sort((a, b) => (b.dateTime ?? b.date).compareTo(a.dateTime ?? a.date));
    latestEntry = sorted.isEmpty ? null : sorted.first;
    safeNotify();
  }
}
