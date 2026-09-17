import 'package:blushy_life_app/features/sia/sia_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Docsy conversation logic, tested directly -- it used to be reachable
/// only by pumping a 2,900-line screen.
Map<String, String> _msg(String sender, String text, String at) =>
    {'sender': sender, 'text': text, 'at': at};

void main() {
  group('closeEnough', () {
    test('identical stamps match', () {
      expect(SiaConversation.closeEnough('2026-09-17T06:00:00Z', '2026-09-17T06:00:00Z'), isTrue);
    });
    test('within ten minutes matches (two clocks, one moment)', () {
      expect(SiaConversation.closeEnough('2026-09-17T06:00:00Z', '2026-09-17T06:07:00Z'), isTrue);
    });
    test('far apart does not match', () {
      expect(SiaConversation.closeEnough('2026-09-17T06:00:00Z', '2026-09-17T09:00:00Z'), isFalse);
    });
    test('an undated pair falls through to sender+text', () {
      expect(SiaConversation.closeEnough(null, '2026-09-17T06:00:00Z'), isTrue);
    });
  });

  group('merge', () {
    test('a message already on the server is not duplicated', () {
      final server = [_msg('user', 'hi', '2026-09-17T06:00:00Z')];
      // Same exchange, cache stamped a few minutes off (the real bug).
      final cached = [_msg('user', 'hi', '2026-09-17T06:03:00Z')];
      final merged = SiaConversation.merge(server: server, cached: cached);
      expect(merged, hasLength(1), reason: 'the just-fetched message looked device-only before');
    });

    test('a device-only day is folded in and ordered by time', () {
      final server = [_msg('user', 'today', '2026-09-17T10:00:00Z')];
      final cached = [_msg('user', 'yesterday', '2026-09-16T10:00:00Z')];
      final merged = SiaConversation.merge(server: server, cached: cached);
      expect(merged, hasLength(2));
      expect(merged.first['text'], 'yesterday', reason: 'recovered day lands in date order');
    });

    test('empty cache returns the server list unchanged', () {
      final server = [_msg('sia', 'hello', '2026-09-17T06:00:00Z')];
      expect(SiaConversation.merge(server: server, cached: const []), same(server));
    });
  });

  group('toExchanges', () {
    test('pairs a question with the reply that follows', () {
      final msgs = [
        _msg('user', 'Q', '2026-09-17T06:00:00Z'),
        _msg('sia', 'A', '2026-09-17T06:00:05Z'),
      ];
      final ex = SiaConversation.toExchanges(msgs);
      expect(ex, hasLength(1));
      expect(ex.first['userMessage'], 'Q');
      expect(ex.first['assistantMessage'], 'A');
    });

    test('an unanswered question goes up on its own', () {
      final msgs = [_msg('user', 'Q', '2026-09-17T06:00:00Z')];
      final ex = SiaConversation.toExchanges(msgs);
      expect(ex, hasLength(1));
      expect(ex.first['assistantMessage'], '');
    });

    test('a stray sia message with no question makes no exchange', () {
      final msgs = [_msg('sia', 'orphan', '2026-09-17T06:00:00Z')];
      expect(SiaConversation.toExchanges(msgs), isEmpty);
    });
  });

  group('loggedLabels', () {
    test('collects string and list values, skips date/feeling', () {
      final labels = SiaConversation.loggedLabels({
        'date': '2026-09-17',
        'feeling': 'good',
        'mood': 'Happy',
        'symptom': ['Cramps', 'Headache'],
        'empty': '',
      });
      expect(labels, containsAll(<String>['Happy', 'Cramps', 'Headache']));
      expect(labels, isNot(contains('good')));
      expect(labels, isNot(contains('')));
    });
  });
}
