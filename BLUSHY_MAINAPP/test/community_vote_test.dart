import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/models/community_models.dart';

/// Liking a post moved the number only after the feed was reloaded.
///
/// The request was fine — the server records the vote and returns the new
/// score — but the client turns any failure into `null`, and `null` left the
/// UI untouched. The count is now predicted on tap. `score` is a *net* total,
/// so the prediction has to handle switching sides, not just adding one.
void main() {
  CommunityPost postWith({required int score, required int userVote}) =>
      CommunityPost(
        postId: 'p1',
        authorName: 'A',
        title: 't',
        text: 'x',
        tags: const [],
        score: score,
        userVote: userVote,
        createdAt: DateTime(2026, 8, 31),
      );

  /// The arithmetic both screens apply.
  CommunityPost predict(CommunityPost before, int target) => before.withVote(
        userVote: target,
        score: before.score - before.userVote + target,
      );

  test('liking an unvoted post adds one', () {
    final r = predict(postWith(score: 4, userVote: 0), 1);
    expect(r.score, 5);
    expect(r.userVote, 1);
  });

  test('unliking a liked post removes the one she added', () {
    final r = predict(postWith(score: 5, userVote: 1), 0);
    expect(r.score, 4);
    expect(r.userVote, 0);
  });

  test('switching from dislike to like moves it by two', () {
    // The trap: her -1 comes off and a +1 goes on.
    final r = predict(postWith(score: 3, userVote: -1), 1);
    expect(r.score, 5);
    expect(r.userVote, 1);
  });

  test('switching from like to dislike moves it by two', () {
    final r = predict(postWith(score: 5, userVote: 1), -1);
    expect(r.score, 3);
    expect(r.userVote, -1);
  });

  test('the round trip returns to where it started', () {
    final start = postWith(score: 7, userVote: 0);
    final liked = predict(start, 1);
    final unliked = predict(liked, 0);
    expect(unliked.score, start.score);
    expect(unliked.userVote, start.userVote);
  });

  test('nothing else about the post is disturbed', () {
    final before = postWith(score: 2, userVote: 0);
    final after = predict(before, 1);
    expect(after.postId, before.postId);
    expect(after.title, before.title);
    expect(after.commentCount, before.commentCount);
    expect(after.createdAt, before.createdAt);
  });
}
