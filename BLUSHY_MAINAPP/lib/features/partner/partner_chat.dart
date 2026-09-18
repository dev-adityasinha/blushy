/// Pure helpers for the partner chat, kept out of the 5,500-line screen so
/// they can be tested directly.
///
/// The mapping is a known bug surface: the server sends some fields camelCase
/// and some snake_case (`senderUserId` vs `sender_user_id`, `audioUrl` vs
/// `audio_url`, and so on), and a message counts as mine only when its sender
/// matches the signed-in user. The diff decides whether a re-fetch is worth a
/// rebuild, so an over-eager version repaints the chat on every poll.
class PartnerChat {
  const PartnerChat._();

  /// Normalises the server's mixed-case message rows into the flat shape the
  /// chat list renders, resolving each dual-named field once.
  static List<Map<String, dynamic>> mapMessages(
    List<Map<String, dynamic>> apiMsgs,
    String? currentUserId,
  ) {
    return apiMsgs.map((m) {
      final senderId = m['senderUserId'] ?? m['sender_user_id'];
      final isMe = currentUserId != null &&
          currentUserId.isNotEmpty &&
          senderId == currentUserId;
      return <String, dynamic>{
        'messageId': m['messageId'] ?? m['message_id'],
        'senderUserId': senderId,
        'senderRole': m['sender_role'] ?? m['senderRole'],
        'sender': isMe
            ? 'You'
            : (m['sender']?['displayName'] ??
                m['sender']?['display_name'] ??
                'Partner'),
        'text': m['message'] ?? m['text'] ?? '',
        'isAudio': m['audioUrl'] != null || m['audio_url'] != null,
        'audioUrl': m['audioUrl'] ?? m['audio_url'],
        'duration': m['audioDuration'] != null ? '${m['audioDuration']}s' : null,
        'createdAt': m['createdAt'] ?? m['created_at'],
        'isCard': false,
        'isMe': isMe,
      };
    }).toList();
  }

  /// Whether a freshly mapped conversation differs from what is on screen, by
  /// length and then by each row's text and ownership. This is what stops a
  /// poll that returned the same thing from rebuilding the chat.
  static bool messagesDiffer(
    List<Map<String, dynamic>> mapped,
    List<Map<String, dynamic>> current,
  ) {
    if (mapped.length != current.length) return true;
    for (var i = 0; i < mapped.length; i++) {
      if (mapped[i]['text'] != current[i]['text'] ||
          mapped[i]['isMe'] != current[i]['isMe']) {
        return true;
      }
    }
    return false;
  }
}
