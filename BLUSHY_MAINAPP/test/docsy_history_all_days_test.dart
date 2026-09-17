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

  test('device-only days are handed up to the server', () {
    // Otherwise they stay this installation's: invisible on the web, and gone
    // with a reinstall.
    expect(screen, contains('_uploadDeviceOnlyHistory('));
    expect(service, contains("'/ai/history/import'"));

    final start = screen.indexOf('Future<void> _uploadDeviceOnlyHistory(');
    expect(start, greaterThan(-1));
    final body = screen.substring(start, start + 1600);
    // The cache is a flat message list; the server stores exchanges.
    expect(body, contains("m['sender'] != 'user'"));
    expect(body, contains("next['sender'] == 'sia'"));
    expect(body, contains("'assistantMessage': reply"));
  });

  test('the upload stops once the server has them', () {
    // It sends only what the server did not return, so the next fetch
    // includes them and the difference is empty.
    final start = screen.indexOf('Future<void> _uploadDeviceOnlyHistory(');
    final body = screen.substring(start, start + 600);
    expect(body, contains('!_sameMessage(server, m)'));
    expect(body, contains('if (missing.isEmpty) return;'));
  });

  test('the endpoint is bounded and writes only under the caller', () {
    final controller = read('backend/src/controllers/aiController.js');
    final start = controller.indexOf('export async function importChatHistory');
    expect(start, greaterThan(-1));

    final body = controller.substring(start, start + 1800);
    expect(body, contains('raw.length > 300'), reason: 'an unbounded import');
    expect(body, contains('MAX_CHARS'));
    expect(body, contains('getUserKey(req, role)'),
        reason: 'the body must not be able to name another account');
  });

  test('re-sending the same conversation cannot duplicate it', () {
    final repo = read('backend/src/repositories/aiHistoryRepository.js');
    final start = repo.indexOf('async function importConversations(');
    expect(start, greaterThan(-1));

    final body = repo.substring(start, start + 2600);
    expect(body, contains('createHash('), reason: 'the id must be derived, not random');
    expect(body, contains('upsert: true'));
    expect(body, contains(r'$setOnInsert'),
        reason: 'a re-import must not overwrite what is already there');
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
