import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Docsy has to be shown the conversation, or it answers every message cold.
///
/// The client sent only `{'message': ...}`, so the server fell back to
/// `messages = [{ role: 'user', content: message }]` — a single-turn
/// conversation every time. That is why replies repeated themselves almost
/// verbatim and re-asked a question that had just been answered.
void main() {
  final service =
      File('lib/services/api_sia_service.dart').readAsStringSync();
  final screen =
      File('lib/features/sia/sia_screen.dart').readAsStringSync();

  test('the request carries the conversation, not just the new message', () {
    expect(service.contains("'messages': turns"), isTrue);
    expect(service.contains("'message': userMessage"), isTrue,
        reason: 'older server builds still read the single-message field');
  });

  test('senders are mapped to the roles the model expects', () {
    // The app stores 'sia'; the API speaks 'assistant'.
    expect(
      service.contains("entry['sender'] == 'sia' ? 'assistant' : 'user'"),
      isTrue,
    );
  });

  test('history is capped so the request stays small', () {
    expect(service.contains('_historyTurns'), isTrue);
  });

  test('the screen sends what came before, without duplicating the new turn',
      () {
    expect(screen.contains('history: history'), isTrue);
    // The user's message is already appended to _messages before the call.
    expect(
      screen.contains('_messages.sublist(0, _messages.length - 1)'),
      isTrue,
      reason: 'sending it twice would have Docsy answer a doubled message',
    );
  });
}
