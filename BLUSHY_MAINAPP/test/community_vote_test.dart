import 'package:blushy_life_app/models/community_models.dart';
import 'package:blushy_life_app/features/community/community_vote.dart';
import 'package:flutter_test/flutter_test.dart';

/// The optimistic-vote math, tested directly -- it used to be reachable only by
/// pumping the whole feed, and it hides a real trap: the score is a net total.
CommunityPost _post({required int score, required int userVote}) => CommunityPost(
      postId: 'p1',
      authorName: 'A',
      title: 't',
      text: '',
      tags: const [],
      score: score,
      userVote: userVote,
      createdAt: DateTime(2026, 9, 17),
      updatedAt: DateTime(2026, 9, 17),
    );

void main() {
  group('targetVote', () {
    test('tapping a fresh upvote sets it', () {
      expect(CommunityVote.targetVote(0, 1), 1);
    });
    test('tapping the vote you already hold clears it', () {
      expect(CommunityVote.targetVote(1, 1), 0);
    });
    test('tapping the opposite switches it', () {
      expect(CommunityVote.targetVote(-1, 1), 1);
    });
  });

  group('predict', () {
    test('a fresh upvote moves the score by one', () {
      final p = CommunityVote.predict(_post(score: 10, userVote: 0), 1);
      expect(p.score, 11);
      expect(p.userVote, 1);
    });

    test('flipping a downvote to an upvote moves the score by two', () {
      final p = CommunityVote.predict(_post(score: 10, userVote: -1), 1);
      expect(p.score, 12, reason: 'net total: remove the -1, add the +1');
      expect(p.userVote, 1);
    });

    test('clearing an upvote moves the score back by one', () {
      final p = CommunityVote.predict(_post(score: 10, userVote: 1), 0);
      expect(p.score, 9);
      expect(p.userVote, 0);
    });
  });

  group('reconcile', () {
    final predicted = _post(score: 12, userVote: 1);
    final server = _post(score: 15, userVote: 1);

    test('the server number wins when it answers', () {
      final r = CommunityVote.reconcile(predicted: predicted, serverResponse: server);
      expect(r.score, 15);
    });

    test('the prediction stands when the server is silent', () {
      final r = CommunityVote.reconcile(predicted: predicted, serverResponse: null);
      expect(r.score, 12);
    });
  });
}
