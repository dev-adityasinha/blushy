import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The upload must not re-send what the server just handed back.
///
/// Seen live: two real exchanges saved at 06:25:43 and 06:25:50 with
/// `model: x-ai/grok-4.3`, and the same two stored again minutes later with
/// `model: imported`. Two faults behind it, both in the sync added for
/// device-only history.
///
/// `_sameMessage` compared `at` exactly. The server stamps a row when it
/// saves; the cache stamps a message when the screen adds it, a round trip
/// earlier. They never matched, so a message that had just come back from the
/// server still counted as device-only and went up again.
///
/// And the stamps themselves were `DateTime.now().toIso8601String()` -- local
/// time with no offset. `new Date` on a server running UTC read those as UTC,
/// putting an IST client's rows 5.5 hours in the future, which would also have
/// filed them under the wrong day.
void main() {
  String read(String p) => File(p).readAsStringSync();

  late final String screen;

  setUpAll(() {
    screen = read('lib/features/sia/sia_screen.dart');
  });

  test('timestamps leave the device in UTC', () {
    final naive = RegExp(r'DateTime\.now\(\)\.toIso8601String\(\)').allMatches(screen).length;
    expect(naive, 0,
        reason: 'a stamp with no offset is read as the server\'s local time');
    expect(screen, contains('DateTime.now().toUtc().toIso8601String()'));
  });

  test('two clocks are allowed to disagree slightly', () {
    expect(screen, contains('_closeEnough(h[' "'at'" '], m[' "'at'" '])'));

    final start = screen.indexOf('static bool _closeEnough(');
    expect(start, greaterThan(-1));
    final body = screen.substring(start, start + 700);
    expect(body, contains('Duration(minutes: 10)'));
    expect(body, contains('.toUtc()'), reason: 'compare instants, not wall clocks');
  });

  test('an undated message still matches on sender and text', () {
    final start = screen.indexOf('static bool _closeEnough(');
    final body = screen.substring(start, start + 700);
    expect(body, contains('if (at == null || bt == null) return true;'));
  });

  test('the server reads a zoneless stamp as UTC', () {
    final repo = read('backend/src/repositories/aiHistoryRepository.js');
    expect(repo, contains('const zoned = raw'));
    expect(repo, contains(r'{2}:?'), reason: 'the offset test must accept +05:30 and +0530');
  });
}
