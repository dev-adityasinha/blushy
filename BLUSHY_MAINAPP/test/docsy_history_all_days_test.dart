import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The conversation should come back whole, however many days it spans.
///
/// The server already returns every exchange it holds -- `listHistory` sorts
/// ascending with no limit, and retention is 300 per user -- and the screen
/// groups them under day separators. What was missing is the days that were
/// never saved: the turns lost while `createChatReply` discarded any chat the
/// model failed to answer. Those exist only in `recent_sia_chats.json` on the
/// device, and the screen used that file solely as a fallback for a failed
/// fetch, so an empty-but-successful server answer hid them.
///
/// They are merged now: every server row, plus anything only the device
/// remembers, ordered by timestamp. A clear wipes both, so nothing here can
/// bring back a conversation that was deliberately deleted.
void main() {
  String read(String p) => File(p).readAsStringSync();

  late final String screen;
  late final String service;

  setUpAll(() {
    screen = read('lib/features/sia/sia_screen.dart');
    service = read('lib/services/api_sia_service.dart');
  });

  test('the device copy is merged, not just used as a fallback', () {
    expect(screen, contains('_mergeConversations('));
    expect(screen, contains('final cached = _cachedConversation();'));

    final start = screen.indexOf('final restored = history == null');
    expect(start, greaterThan(-1), reason: 'the fallback-only branch is still there');

    final branch = screen.substring(start, start + 200);
    expect(branch, contains('? cached'));
    expect(branch, contains('_mergeConversations(server: history, cached: cached)'));
  });

  test('a merged conversation is ordered by time, not by source', () {
    final start = screen.indexOf('List<Map<String, String>> _mergeConversations(');
    expect(start, greaterThan(-1));

    final body = screen.substring(start, start + 1200);
    expect(body, contains('merged.sort('));
    expect(body, contains("DateTime.tryParse(a['at'] ?? '')"),
        reason: 'a recovered day has to land among the server rows');
  });

  test('duplicates are matched on content, not identity', () {
    // Two maps with equal contents are never `==` in Dart, so an identity
    // check would append the whole cache on top of the server copy.
    final start = screen.indexOf('List<Map<String, String>> _mergeConversations(');
    final body = screen.substring(start, start + 1200);
    expect(body, contains('_sameMessage(merged, m)'));
  });

  test('clearing history wipes the device copy too', () {
    final start = service.indexOf('Future<bool> clearChatHistory()');
    expect(start, greaterThan(-1));

    final body = service.substring(start, start + 900);
    // Both paths: a clear the server accepted, and one it refused.
    expect('_forgetCachedConversation();'.allMatches(body).length, greaterThan(1),
        reason: 'a failed clear must not leave the conversation visible');
    expect(service, contains("BlushyStorage.write('recent_sia_chats.json'"));
  });

  test('the server still returns every day it holds', () {
    final repo = read('backend/src/repositories/aiHistoryRepository.js');
    final start = repo.indexOf('async function listHistory');
    expect(start, greaterThan(-1));

    final body = repo.substring(start, repo.indexOf('async function clearHistory', start));
    expect(body, contains('.sort({ created_at: 1 })'));
    expect(body.contains('.limit('), isFalse,
        reason: 'a limit here would cut the oldest days off');
  });
}
