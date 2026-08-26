import '../../../services/journal_storage.dart';

class MemoryHighlight {
  final String id;
  final String title;
  final String category; // 'Happiest memory', 'Biggest achievement', 'Most grateful moment', 'Most emotional day', 'Funniest journal'
  final String snippet;
  final String dateStr;
  final String moodKey;

  MemoryHighlight({
    required this.id,
    required this.title,
    required this.category,
    required this.snippet,
    required this.dateStr,
    required this.moodKey,
  });
}

class MemoryHighlightsService {
  List<MemoryHighlight> generateHighlights(List<LocalJournalEntry> entries) {
    if (entries.isEmpty) return [];

    final List<MemoryHighlight> highlights = [];

    for (var entry in entries) {
      if (entry.moodKey == 'happy' || entry.moodKey == 'very_satisfied') {
        highlights.add(MemoryHighlight(
          id: entry.id,
          title: entry.title,
          category: 'Happiest Memory',
          snippet: entry.body.length > 80 ? '${entry.body.substring(0, 80)}...' : entry.body,
          dateStr: entry.date,
          moodKey: entry.moodKey,
        ));
      } else if (entry.body.toLowerCase().contains('grateful') || entry.body.toLowerCase().contains('thankful')) {
        highlights.add(MemoryHighlight(
          id: entry.id,
          title: entry.title,
          category: 'Most Grateful Moment',
          snippet: entry.body.length > 80 ? '${entry.body.substring(0, 80)}...' : entry.body,
          dateStr: entry.date,
          moodKey: entry.moodKey,
        ));
      } else if (entry.body.toLowerCase().contains('won') || entry.body.toLowerCase().contains('achieved') || entry.body.toLowerCase().contains('passed')) {
        highlights.add(MemoryHighlight(
          id: entry.id,
          title: entry.title,
          category: 'Biggest Achievement',
          snippet: entry.body.length > 80 ? '${entry.body.substring(0, 80)}...' : entry.body,
          dateStr: entry.date,
          moodKey: entry.moodKey,
        ));
      }
    }

    if (highlights.isEmpty && entries.isNotEmpty) {
      final first = entries.first;
      highlights.add(MemoryHighlight(
        id: first.id,
        title: first.title,
        category: 'Featured Memory',
        snippet: first.body.length > 80 ? '${first.body.substring(0, 80)}...' : first.body,
        dateStr: first.date,
        moodKey: first.moodKey,
      ));
    }

    return highlights;
  }
}
