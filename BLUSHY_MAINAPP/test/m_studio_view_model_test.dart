import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/services/journal_storage.dart';
import 'package:blushy_life_app/features/m_studio/view_models/m_studio_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three M Studio reads, tested with no widget. Each keeps its own loading
/// flag, and the latest-entry read must pick the newest by date.
void main() {
  ApiResult<List<Map<String, dynamic>>> _r(ApiState s, {List<Map<String, dynamic>>? d}) =>
      ApiResult<List<Map<String, dynamic>>>(state: s, data: d);

  LocalJournalEntry _entry(String id, String date, {String? dateTime}) =>
      LocalJournalEntry(
        id: id,
        date: date,
        title: id,
        body: '',
        moodKey: 'calm',
        dateTime: dateTime,
      );

  test('sessions load into the list and clear the flag', () async {
    final vm = MStudioViewModel(
      fetchSessions: () async => _r(ApiState.ready, d: [
        {'sessionId': 's1'},
      ]),
    );
    await vm.loadSessions();
    expect(vm.sessions, hasLength(1));
    expect(vm.sessionsLoading, isFalse);
  });

  test('an offline sessions read becomes an empty list, not a crash', () async {
    final vm = MStudioViewModel(fetchSessions: () async => _r(ApiState.offline));
    await vm.loadSessions();
    expect(vm.sessions, isEmpty);
    expect(vm.sessionsLoading, isFalse);
  });

  test('capsules load with no seeded placeholders', () async {
    final vm = MStudioViewModel(fetchCapsules: () async => _r(ApiState.empty));
    await vm.loadCapsules();
    expect(vm.capsules, isEmpty);
    expect(vm.capsulesLoading, isFalse);
  });

  test('the latest entry is the newest by date/time', () async {
    final vm = MStudioViewModel(
      fetchEntries: () async => [
        _entry('older', '2026-09-10'),
        _entry('newest', '2026-09-16', dateTime: '2026-09-16T09:00:00Z'),
        _entry('middle', '2026-09-14'),
      ],
    );
    await vm.loadLatestEntry();
    expect(vm.latestEntry?.id, 'newest');
  });

  test('no entries leaves the latest null', () async {
    final vm = MStudioViewModel(fetchEntries: () async => const []);
    await vm.loadLatestEntry();
    expect(vm.latestEntry, isNull);
  });

  test('each load notifies its listeners', () async {
    var n = 0;
    final vm = MStudioViewModel(
      fetchSessions: () async => _r(ApiState.ready),
      fetchCapsules: () async => _r(ApiState.ready),
      fetchEntries: () async => const [],
    )..addListener(() => n++);
    await vm.loadSessions();
    await vm.loadCapsules();
    await vm.loadLatestEntry();
    expect(n, greaterThanOrEqualTo(3));
  });

  test('a silent refresh does not raise the section loading flags', () async {
    final vm = MStudioViewModel(
      fetchSessions: () async => _r(ApiState.ready, d: [{'sessionId': 's1'}]),
      fetchCapsules: () async => _r(ApiState.ready, d: [{'capsuleId': 'c1'}]),
      fetchEntries: () async => const [],
    );
    final flags = <bool>[];
    vm.addListener(() => flags.add(vm.sessionsLoading || vm.capsulesLoading));
    await vm.refreshAll();
    expect(vm.sessions, hasLength(1));
    expect(vm.capsules, hasLength(1));
    expect(flags.any((f) => f), isFalse, reason: 'no skeleton flash on a background refresh');
  });
}
