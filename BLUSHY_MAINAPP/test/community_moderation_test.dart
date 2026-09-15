import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/features/community/moderation_widgets.dart';
import 'package:blushy_life_app/models/community_models.dart';

/// The reader-facing half of community moderation. Visibility is enforced on
/// the server; these pin what a reader is told about a post.

CommunityPost _post({String? notice, String authorId = 'author_1'}) {
  return CommunityPost(
    postId: 'p1',
    authorId: authorId,
    authorName: 'Someone',
    title: 'A post',
    text: 'Body text',
    tags: const [],
    score: 0,
    commentCount: 0,
    userVote: 0,
    createdAt: DateTime(2026, 8, 29),
    updatedAt: DateTime(2026, 8, 29),
    moderationNotice: notice,
  );
}

void main() {
  group('CommunityPost moderation metadata', () {
    test('parses the notice and the never-reviewed flag from the feed', () {
      final post = CommunityPost.fromJson({
        'postId': 'p1',
        'authorId': 'a1',
        'authorName': 'Someone',
        'title': 'My PCOS journey',
        'text': 'Sharing my experience.',
        'moderationNotice': 'Shared from personal experience by a community member. '
            'This is not medical advice and has not been clinically reviewed.',
        'isClinicallyReviewed': false,
        'sensitiveTopics': ['pcos'],
      });

      expect(post.moderationNotice, contains('not medical advice'));
      expect(post.isClinicallyReviewed, isFalse);
      expect(post.sensitiveTopics, contains('pcos'));
    });

    test('an anonymous partner post arrives with no author id', () {
      final post = CommunityPost.fromJson({
        'postId': 'p2',
        'authorId': null,
        'authorName': 'Community member',
        'title': 'Supporting her',
        'text': 'How do you handle it?',
      });

      // Anonymity is applied server side; the client just renders what it got.
      expect(post.authorId, isEmpty);
      expect(post.authorName, 'Community member');
    });

    test('community content is never marked clinically reviewed', () {
      // Even if the payload claimed otherwise, the default is false and the
      // server never sends true for community posts.
      expect(CommunityPost.fromJson({'postId': 'x'}).isClinicallyReviewed, isFalse);
    });
  });

  group('ModerationNotice', () {
    testWidgets('renders the notice when one is attached', (tester) async {
      final post = _post(notice: 'This is not medical advice.');
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ModerationNotice(notice: post.moderationNotice))),
      );
      expect(find.text('This is not medical advice.'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renders nothing when a post carries no notice', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ModerationNotice(notice: _post().moderationNotice))),
      );
      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('PostModerationMenu', () {
    testWidgets('offers report and block for an identified author', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PostModerationMenu(postId: 'p1', authorId: 'a1')),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Report post'), findsOneWidget);
      expect(find.text('Block this person'), findsOneWidget);
    });

    testWidgets('offers only report when the post is anonymous', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PostModerationMenu(postId: 'p1', authorId: null)),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Report post'), findsOneWidget);
      // There is no author to block in the anonymous partner community.
      expect(find.text('Block this person'), findsNothing);
    });

    testWidgets('the report sheet offers every server-accepted reason', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PostModerationMenu(postId: 'p1', authorId: 'a1')),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report post'));
      await tester.pumpAndSettle();

      for (final label in kReportReasons.values) {
        expect(find.text(label), findsOneWidget, reason: '$label is missing from the sheet');
      }
    });
  });

  group('report reasons', () {
    test('match the keys the server accepts', () {
      // The server rejects anything outside this set, so a mismatch here would
      // surface as a rejected report rather than a silent no-op.
      expect(
        kReportReasons.keys.toSet(),
        {'misinformation', 'harmful_advice', 'harassment', 'spam', 'off_topic', 'privacy', 'other'},
      );
    });
  });
}
