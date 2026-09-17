import '../../models/community_models.dart';

/// Where a newly posted comment goes in the tree, kept pure so it can be
/// tested without the screen.
///
/// The submit flow used to re-read the entire thread (and fire a throwaway
/// vote to refresh the post) before the new comment showed, which flashed the
/// list and made a posted comment feel slow. Since `createComment` returns the
/// real server comment, it can be dropped straight into the tree instead --
/// this decides where.
class CommunityComments {
  const CommunityComments._();

  /// Returns a new tree with [comment] inserted: at the top level when it has
  /// no parent, otherwise nested under the comment whose id is its `parentId`.
  /// A reply whose parent is not found falls back to the top level rather than
  /// being dropped. Lists are rebuilt, never mutated in place.
  static List<CommunityComment> insert(
    List<CommunityComment> tree,
    CommunityComment comment,
  ) {
    final parentId = comment.parentId;
    if (parentId == null || parentId.isEmpty) {
      return [...tree, comment];
    }
    final (nested, placed) = _insertUnder(tree, parentId, comment);
    return placed ? nested : [...tree, comment];
  }

  static (List<CommunityComment>, bool) _insertUnder(
    List<CommunityComment> tree,
    String parentId,
    CommunityComment comment,
  ) {
    var placed = false;
    final out = <CommunityComment>[];
    for (final c in tree) {
      if (!placed && c.commentId == parentId) {
        out.add(c.copyWith(replies: [...c.replies, comment]));
        placed = true;
      } else if (!placed && c.replies.isNotEmpty) {
        final (newReplies, didPlace) = _insertUnder(c.replies, parentId, comment);
        if (didPlace) {
          out.add(c.copyWith(replies: newReplies));
          placed = true;
        } else {
          out.add(c);
        }
      } else {
        out.add(c);
      }
    }
    return (out, placed);
  }
}
