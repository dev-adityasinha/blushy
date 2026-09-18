/// Pure conversation logic for the Docsy chat.
///
/// The merge, dedupe, timestamp and exchange-pairing rules caused real bugs --
/// duplicate uploads when a just-fetched message looked device-only, and rows
/// landing on the wrong day when two clocks disagreed. They lived inside a
/// 2,900-line widget, testable only by pumping the screen. Extracted here they
/// are plain functions with unit tests, while the screen keeps its rendering
/// and its storage I/O.
///
/// A message is a `{sender, text, at, ...}` map; a conversation is a list of
/// them, oldest first.
class SiaConversation {
  const SiaConversation._();

  /// Whether two timestamps describe the same moment, allowing for the fact
  /// that they were taken by different clocks: the server stamps a row when it
  /// saves, the cache when the screen added it, a round trip earlier.
  static bool closeEnough(String? a, String? b) {
    if (a == b) return true;
    final at = DateTime.tryParse(a ?? '');
    final bt = DateTime.tryParse(b ?? '');
    // One of them undated: sender and text already matched, nothing more to go on.
    if (at == null || bt == null) return true;
    return at.toUtc().difference(bt.toUtc()).abs() < const Duration(minutes: 10);
  }

  /// Whether [m] is already present in [list]. Two maps with equal contents are
  /// never `==` in Dart, so this compares by field instead.
  static bool sameMessage(List<Map<String, String>> list, Map<String, String> m) {
    return list.any((h) =>
        h['sender'] == m['sender'] &&
        h['text'] == m['text'] &&
        closeEnough(h['at'], m['at']));
  }

  /// Server rows plus anything only the device remembers, oldest first.
  static List<Map<String, String>> merge({
    required List<Map<String, String>> server,
    required List<Map<String, String>> cached,
  }) {
    if (cached.isEmpty) return server;

    final merged = List<Map<String, String>>.from(server);
    for (final m in cached) {
      if (!sameMessage(merged, m)) merged.add(m);
    }

    // By timestamp, so a recovered day lands among the server's rather than
    // after them. Anything undated keeps its position relative to the rest.
    merged.sort((a, b) {
      final at = DateTime.tryParse(a['at'] ?? '');
      final bt = DateTime.tryParse(b['at'] ?? '');
      if (at == null || bt == null) return 0;
      return at.compareTo(bt);
    });
    return merged;
  }

  /// Pairs a flat message list into `{userMessage, assistantMessage, at}`
  /// exchanges for upload: a user message plus the reply that follows it, and
  /// an unanswered question on its own.
  static List<Map<String, String>> toExchanges(List<Map<String, String>> messages) {
    final exchanges = <Map<String, String>>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m['sender'] != 'user') continue;
      final next = i + 1 < messages.length ? messages[i + 1] : null;
      final reply = (next != null && next['sender'] == 'sia') ? next['text'] ?? '' : '';
      exchanges.add({
        'userMessage': m['text'] ?? '',
        'assistantMessage': reply,
        'at': m['at'] ?? '',
      });
      if (reply.isNotEmpty) i++;
    }
    return exchanges;
  }

  /// The symptom labels she picked on today's check-in, as plain strings.
  /// Numeric rows (weight, temperature) and bookkeeping keys are left out.
  static List<String> loggedLabels(Map<String, dynamic> checkin) {
    final labels = <String>[];
    for (final entry in checkin.entries) {
      if (entry.key == 'date' || entry.key == 'feeling') continue;
      final value = entry.value;
      if (value is String && value.trim().isNotEmpty) {
        labels.add(value.trim());
      } else if (value is List) {
        labels.addAll(value.map((v) => v.toString().trim()).where((v) => v.isNotEmpty));
      }
    }
    return labels;
  }
}
