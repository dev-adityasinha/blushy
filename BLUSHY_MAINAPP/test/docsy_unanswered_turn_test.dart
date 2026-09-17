import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A provider outage costs the reply, not the whole exchange.
///
/// `createChatReply` only saved a turn once the model had answered, so a
/// failure after the provider call discarded her question too. The live
/// database showed the shape of it: 65 `docsy_chat` attempts between 28 July
/// and 16 September, and not one saved exchange in that window.
///
/// Her message is now recorded on its own, flagged `unanswered`, and the
/// screen says so rather than leaving a gap that reads as though nothing was
/// ever sent.
void main() {
  String read(String p) => File(p).readAsStringSync();

  String stripComments(String source) => source
      .split(String.fromCharCode(10))
      .where((line) => !line.trimLeft().startsWith('//'))
      .join(String.fromCharCode(10));

  test('the server records the question when the reply fails', () {
    final controller =
        stripComments(read('backend/src/controllers/aiController.js'));
    final start = controller.indexOf('let result;');
    expect(start, greaterThan(-1), reason: 'the createReply call is no longer guarded');

    final guarded = controller.substring(start, start + 1400);
    expect(guarded, contains('appendConversation('));
    expect(guarded, contains("model: 'unanswered'"));
    expect(guarded, contains('assistantMessage: null'));
    expect(guarded, contains('throw error;'),
        reason: 'saving the question must not swallow the failure');
  });

  test('the row carries the flag the app reads', () {
    final repo =
        stripComments(read('backend/src/repositories/aiHistoryRepository.js'));
    expect(repo, contains('unanswered: !assistantMessage'));
    expect(repo, contains('unanswered: row.unanswered === true'));
  });

  test('the client carries it through', () {
    final service = read('lib/services/api_sia_service.dart');
    expect(service, contains("item['unanswered'] == true ? '1' : '0'"));
    expect(service, contains("'unanswered': unanswered,"));
  });

  test('and the screen marks the turn', () {
    final screen = read('lib/features/sia/sia_screen.dart');
    expect(screen, contains("if (msg['unanswered'] == '1')"));
    expect(screen, contains('_buildUnansweredNote()'));
    expect(screen, contains("Docsy didn't answer this one."));
  });
}
