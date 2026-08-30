/// One suggestion offered in the messenger's Date Ideas sheet.
///
/// The partner suggestions endpoint returns three different element shapes in
/// a single `suggestions` array:
///
///   {type: 'mood_support',       suggestion: `'<string>'`}
///   {type: 'ai_chat_suggestion', suggestion: `'<string>'`}
///   {type: 'partner_support',    suggestion: {title, description, ...}}
///
/// The sheet originally read `suggestion` as a Map unconditionally, so the
/// first string-shaped element threw a TypeError and the sheet never opened at
/// all. Normalising here keeps that handling in one testable place.
class DateIdea {
  const DateIdea({required this.title, this.description, this.type});

  final String title;
  final String? description;

  /// The server's category for this suggestion.
  ///
  /// `ai_chat_suggestion` entries are drafted *replies* for the messenger, not
  /// things to do together -- one came back as "Aww babe, let's do the sync".
  /// Offering those under "Date ideas" is simply the wrong list.
  final String? type;

  static const Set<String> _replyDraftTypes = {'ai_chat_suggestion'};

  bool get isReplyDraft => _replyDraftTypes.contains(type);

  /// Returns null for anything that carries no usable text, so the caller can
  /// filter rather than render an empty row.
  static DateIdea? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final inner = map['suggestion'];

    if (inner is Map) {
      final nested = Map<String, dynamic>.from(inner);
      final title = (nested['title'] ?? '').toString().trim();
      if (title.isEmpty) return null;
      final description = (nested['description'] ?? '').toString().trim();
      return DateIdea(
        title: title,
        description: description.isEmpty ? null : description,
        type: map['type']?.toString(),
      );
    }

    if (inner is String) {
      final text = inner.trim();
      if (text.isEmpty) return null;
      // A bare string is the whole suggestion; there is no separate detail to
      // show, and repeating it as a description would just look like a bug.
      return DateIdea(title: text, type: map['type']?.toString());
    }

    // Some callers pass the suggestion object directly rather than wrapped.
    final title = (map['title'] ?? '').toString().trim();
    if (title.isEmpty) return null;
    final description = (map['description'] ?? '').toString().trim();
    return DateIdea(
      title: title,
      description: description.isEmpty ? null : description,
      type: map['type']?.toString(),
    );
  }

  /// Parses the suggestions array.
  ///
  /// Set [includeReplyDrafts] to keep the messenger's drafted replies, which
  /// belong in the composer rather than in a list of things to do together.
  static List<DateIdea> listFrom(dynamic raw, {bool includeReplyDrafts = false}) {
    if (raw is! List) return const [];
    return raw
        .map(DateIdea.fromJson)
        .whereType<DateIdea>()
        .where((idea) => includeReplyDrafts || !idea.isReplyDraft)
        .toList();
  }
}
