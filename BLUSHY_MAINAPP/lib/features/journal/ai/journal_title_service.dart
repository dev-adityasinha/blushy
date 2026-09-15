import 'dart:math';

class JournalTitleService {
  final List<String> _defaultTitles = const [
    'Quiet Morning',
    'Coffee & Conversations',
    'A Small Victory',
    'Rainy Reflections',
    'Gentle Progress',
    'Warm Sunshine & Tea',
    'Evening Stillness',
  ];

  List<String> generateTitles(String bodyText) {
    if (bodyText.trim().isEmpty) {
      final List<String> pool = List.from(_defaultTitles)..shuffle(Random());
      return pool.take(3).toList();
    }

    final lower = bodyText.toLowerCase();
    final List<String> suggestions = [];

    if (lower.contains('coffee') || lower.contains('tea')) {
      suggestions.add('Coffee & Conversations');
    }
    if (lower.contains('walk') || lower.contains('nature') || lower.contains('park')) {
      suggestions.add('Quiet Walks in Nature');
    }
    if (lower.contains('grateful') || lower.contains('thankful')) {
      suggestions.add('A Moment of Gratitude');
    }

    if (suggestions.length < 3) {
      final List<String> pool = List.from(_defaultTitles)..shuffle(Random());
      for (var title in pool) {
        if (!suggestions.contains(title)) {
          suggestions.add(title);
        }
        if (suggestions.length >= 3) break;
      }
    }

    return suggestions;
  }
}
