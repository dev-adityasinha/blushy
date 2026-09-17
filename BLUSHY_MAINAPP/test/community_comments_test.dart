import 'package:blushy_life_app/models/community_models.dart';
import 'package:blushy_life_app/features/community/community_comments.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where a posted comment lands in the tree -- tested directly, since it used
/// to be reachable only by pumping the discussion screen.
CommunityComment _c(String id, {String? parentId, List<CommunityComment> replies = const []}) =>
    CommunityComment(
      commentId: id,
      postId: 'p1',
      parentId: parentId,
      authorId: 'u',
      authorName: 'U',
      text: id,
      score: 0,
      userVote: 0,
      createdAt: DateTime(2026, 9, 17),
      updatedAt: DateTime(2026, 9, 17),
      replies: replies,
    );

void main() {
  test('a top-level comment is appended at the end', () {
    final tree = [_c('a'), _c('b')];
    final out = CommunityComments.insert(tree, _c('new'));
    expect(out.map((c) => c.commentId).toList(), ['a', 'b', 'new']);
  });

  test('a reply nests under its parent', () {
    final tree = [_c('a'), _c('b')];
    final out = CommunityComments.insert(tree, _c('r', parentId: 'a'));
    final a = out.firstWhere((c) => c.commentId == 'a');
    expect(a.replies.map((c) => c.commentId).toList(), ['r']);
    expect(out.firstWhere((c) => c.commentId == 'b').replies, isEmpty);
  });

  test('a reply nests under a deeply nested parent', () {
    final tree = [
      _c('a', replies: [_c('a1', parentId: 'a')]),
    ];
    final out = CommunityComments.insert(tree, _c('r', parentId: 'a1'));
    final a1 = out.first.replies.first;
    expect(a1.replies.map((c) => c.commentId).toList(), ['r']);
  });

  test('a reply to an unknown parent falls back to top level, never dropped', () {
    final tree = [_c('a')];
    final out = CommunityComments.insert(tree, _c('r', parentId: 'ghost'));
    expect(out.map((c) => c.commentId).toList(), ['a', 'r']);
  });

  test('the original tree is not mutated', () {
    final tree = [_c('a')];
    CommunityComments.insert(tree, _c('r', parentId: 'a'));
    expect(tree.first.replies, isEmpty, reason: 'insert must rebuild, not mutate');
    expect(tree, hasLength(1));
  });
}
