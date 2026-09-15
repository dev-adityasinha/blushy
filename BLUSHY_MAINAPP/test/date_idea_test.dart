import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/features/partner/date_idea.dart';

/// Date Ideas read `suggestion` as a Map unconditionally. The endpoint mixes
/// string-shaped and object-shaped suggestions in one array, so the first
/// string threw a TypeError -- uncaught, so the sheet never opened at all.
void main() {
  group('DateIdea', () {
    test('a string suggestion is the title, not a crash', () {
      final idea = DateIdea.fromJson({
        'type': 'mood_support',
        'suggestion': 'Consider connecting with someone you trust.',
      });

      expect(idea, isNotNull);
      expect(idea!.title, 'Consider connecting with someone you trust.');
      // Repeating the same text as a description would read as a bug.
      expect(idea.description, isNull);
    });

    test('an object suggestion keeps its title and description', () {
      final idea = DateIdea.fromJson({
        'type': 'partner_support',
        'suggestion': {
          'id': 'period_heat_pad',
          'title': 'Bring a heating pad or warm tea',
          'description': 'Gentle warmth soothes cramps effectively.',
        },
      });

      expect(idea!.title, 'Bring a heating pad or warm tea');
      expect(idea.description, contains('Gentle warmth'));
    });

    test('a bare suggestion object without the wrapper still works', () {
      final idea = DateIdea.fromJson({
        'title': 'Plan a slow evening',
        'description': 'No screens.',
      });

      expect(idea!.title, 'Plan a slow evening');
      expect(idea.description, 'No screens.');
    });

    test('entries with no usable text are dropped rather than rendered blank', () {
      expect(DateIdea.fromJson({'type': 'x', 'suggestion': '   '}), isNull);
      expect(DateIdea.fromJson({'type': 'x', 'suggestion': {'title': ''}}), isNull);
      expect(DateIdea.fromJson({'type': 'x'}), isNull);
      expect(DateIdea.fromJson('not a map'), isNull);
      expect(DateIdea.fromJson(null), isNull);
    });

    test('drafted chat replies are not offered as date ideas', () {
      // One real response opened with "Aww babe, let's do the sync" -- a reply
      // for the composer, not something to do together.
      final ideas = DateIdea.listFrom([
        {'type': 'ai_chat_suggestion', 'suggestion': "Aww babe, let's do the sync"},
        {'type': 'partner_support', 'suggestion': {'title': 'Cook something together'}},
      ]);

      expect(ideas, hasLength(1));
      expect(ideas.single.title, 'Cook something together');

      // The composer can still ask for them explicitly.
      final withDrafts = DateIdea.listFrom([
        {'type': 'ai_chat_suggestion', 'suggestion': "Aww babe, let's do the sync"},
      ], includeReplyDrafts: true);
      expect(withDrafts, hasLength(1));
    });

    test('a mixed list parses every shape without throwing', () {
      // This is exactly what the endpoint returns: strings and objects
      // together. The old code died on the first string.
      final ideas = DateIdea.listFrom([
        {'type': 'ai_chat_suggestion', 'suggestion': 'Ask how her day went.'},
        {
          'type': 'partner_support',
          'suggestion': {'title': 'Keep the evening cosy', 'description': 'Avoid busy plans.'},
        },
        {'type': 'mood_support', 'suggestion': 'Offer to handle dinner.'},
        {'type': 'broken'},
      ]);

      // The reply draft is filtered out; the other two survive.
      expect(ideas, hasLength(2));
      expect(ideas[0].title, 'Keep the evening cosy');
      expect(ideas[1].title, 'Offer to handle dinner.');
    });

    test('a non-list is an empty list, not an exception', () {
      expect(DateIdea.listFrom(null), isEmpty);
      expect(DateIdea.listFrom({'suggestions': []}), isEmpty);
    });
  });
}
