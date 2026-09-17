import '../../models/community_models.dart';

/// The optimistic-vote logic for the community feed, kept pure so it can be
/// tested without the screen.
///
/// This is where a real bug lived: the score is a net total, so switching a
/// downvote to an upvote must move it by two, not one, and a tap that the
/// server never answers must keep the predicted result rather than snapping
/// back. Both were only reachable by pumping the feed before; here they are
/// plain functions.
class CommunityVote {
  const CommunityVote._();

  /// Tapping the vote you already hold clears it; any other tap sets it.
  static int targetVote(int currentVote, int tappedVote) =>
      currentVote == tappedVote ? 0 : tappedVote;

  /// What the post should look like the instant she taps, before the server
  /// answers. The score moves by the difference between the old and new vote,
  /// which is two when flipping down to up.
  static CommunityPost predict(CommunityPost before, int target) => before.withVote(
        userVote: target,
        score: before.score - before.userVote + target,
      );

  /// The server's number wins when it answers; when it does not, the
  /// prediction stands -- the vote was almost certainly recorded, and reverting
  /// a tap she just made would be the more confusing of the two.
  static CommunityPost reconcile({
    required CommunityPost predicted,
    CommunityPost? serverResponse,
  }) =>
      serverResponse ?? predicted;
}
