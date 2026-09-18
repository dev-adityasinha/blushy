import 'package:blushy_life_app/features/partner/partner_chat.dart';
import 'package:flutter_test/flutter_test.dart';

/// The partner chat mapping and diff, tested directly. The mapping resolves the
/// server's mixed camelCase/snake_case fields; the diff decides whether a poll
/// is worth a rebuild.
void main() {
  group('mapMessages', () {
    test('reads camelCase fields and marks my own message', () {
      final out = PartnerChat.mapMessages([
        {
          'messageId': 'm1',
          'senderUserId': 'u1',
          'message': 'hi',
          'audioUrl': 'http://a',
          'audioDuration': 3,
          'createdAt': '2026-09-17T06:00:00Z',
        },
      ], 'u1');
      final m = out.single;
      expect(m['messageId'], 'm1');
      expect(m['isMe'], isTrue);
      expect(m['sender'], 'You');
      expect(m['text'], 'hi');
      expect(m['isAudio'], isTrue);
      expect(m['audioUrl'], 'http://a');
      expect(m['duration'], '3s');
    });

    test('reads the snake_case variants too', () {
      final out = PartnerChat.mapMessages([
        {
          'message_id': 'm2',
          'sender_user_id': 'u2',
          'text': 'yo',
          'audio_url': 'http://b',
          'created_at': '2026-09-17T07:00:00Z',
          'sender': {'display_name': 'Alex'},
        },
      ], 'me');
      final m = out.single;
      expect(m['messageId'], 'm2');
      expect(m['senderUserId'], 'u2');
      expect(m['isMe'], isFalse);
      expect(m['sender'], 'Alex', reason: 'a message not mine shows the sender name');
      expect(m['text'], 'yo');
      expect(m['isAudio'], isTrue);
    });

    test('a null current user makes nothing mine', () {
      final out = PartnerChat.mapMessages([
        {'senderUserId': 'u1', 'message': 'hi'},
      ], null);
      expect(out.single['isMe'], isFalse);
      expect(out.single['sender'], 'Partner');
    });

    test('a text-only message is not audio', () {
      final out = PartnerChat.mapMessages([
        {'senderUserId': 'u1', 'message': 'hi'},
      ], 'u2');
      expect(out.single['isAudio'], isFalse);
      expect(out.single['duration'], isNull);
    });
  });

  group('messagesDiffer', () {
    List<Map<String, dynamic>> row(String text, bool isMe) => [
          {'text': text, 'isMe': isMe},
        ];

    test('same content does not differ', () {
      expect(PartnerChat.messagesDiffer(row('a', true), row('a', true)), isFalse);
    });
    test('a different length differs', () {
      expect(PartnerChat.messagesDiffer(row('a', true), const []), isTrue);
    });
    test('a changed text differs', () {
      expect(PartnerChat.messagesDiffer(row('a', true), row('b', true)), isTrue);
    });
    test('a changed ownership differs', () {
      expect(PartnerChat.messagesDiffer(row('a', true), row('a', false)), isTrue);
    });
  });
}
