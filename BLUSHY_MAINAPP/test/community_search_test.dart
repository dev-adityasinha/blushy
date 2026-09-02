import 'package:blushy_life_app/features/community/community_screen.dart';
import 'package:blushy_life_app/models/community_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the community search box actually matches.
///
/// It advertises "title, text, tags, or username", but the author was never
/// checked. Searching a name found the person under People and none of their
/// posts, which reads as only people being searched.
CommunityPost _post({
  String title = '',
  String text = '',
  String authorName = 'Someone',
  List<String> tags = const [],
}) {
  return CommunityPost(
    postId: 'p1',
    authorId: 'a1',
    authorName: authorName,
    title: title,
    text: text,
    tags: tags,
    score: 0,
    commentCount: 0,
    userVote: 0,
    createdAt: DateTime(2026, 9, 2),
    updatedAt: DateTime(2026, 9, 2),
  );
}

void main() {
  test('it matches the title', () {
    expect(communityPostMatches(_post(title: 'Follicular training'), 'follicular'),
        isTrue);
  });

  test('it matches the body text', () {
    expect(
      communityPostMatches(_post(text: 'Recommend compound lifts'), 'compound'),
      isTrue,
    );
  });

  test('it matches a tag', () {
    expect(communityPostMatches(_post(tags: ['fitness', 'tips']), 'tips'), isTrue);
  });

  test('it matches the username', () {
    // The gap: this returned false, so a name found people but no posts.
    expect(communityPostMatches(_post(authorName: 'Priya'), 'priya'), isTrue);
  });

  test('matching ignores case and surrounding spaces', () {
    expect(communityPostMatches(_post(title: 'Cramps'), '  CRAMPS '), isTrue);
  });

  test('an empty query matches everything', () {
    expect(communityPostMatches(_post(title: 'anything'), '   '), isTrue);
  });

  test('it does not match what is not there', () {
    expect(
      communityPostMatches(
        _post(title: 'Sleep', text: 'rest', authorName: 'Ana', tags: ['calm']),
        'marathon',
      ),
      isFalse,
    );
  });
}
