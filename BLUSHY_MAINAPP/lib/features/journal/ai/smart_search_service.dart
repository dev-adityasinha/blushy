import '../../../services/journal_storage.dart';

class SmartSearchResult {
  final LocalJournalEntry entry;
  final double confidenceScore;
  final String matchedConcept;

  SmartSearchResult({
    required this.entry,
    required this.confidenceScore,
    required this.matchedConcept,
  });
}

class SmartSearchService {
  static const Map<String, List<String>> _conceptSynonyms = {
    'beach': ['ocean', 'waves', 'sand', 'coast', 'sea', 'water'],
    'happy': ['joy', 'smiles', 'cheerful', 'grateful', 'wonderful', 'bright'],
    'birthday': ['party', 'celebration', 'cake', 'candles', 'wishes'],
    'exams': ['study', 'test', 'exam', 'college', 'grades', 'revision'],
    'rain': ['storm', 'drizzle', 'cozy', 'tea', 'drops'],
    'vacation': ['trip', 'travel', 'flight', 'hotel', 'explore'],
  };

  /// Searches entries using conceptual keyword expansions and requires >0.6 (60%) confidence match
  List<SmartSearchResult> search(String query, List<LocalJournalEntry> entries) {
    if (query.trim().isEmpty) return [];

    final q = query.trim().toLowerCase();
    final List<SmartSearchResult> results = [];
    final synonyms = _conceptSynonyms[q] ?? [];

    for (var entry in entries) {
      final text = '${entry.title} ${entry.body}'.toLowerCase();
      double score = 0.0;
      String concept = 'Keyword Match';

      if (text.contains(q)) {
        score = 0.95;
        concept = 'Direct Match';
      } else {
        for (var syn in synonyms) {
          if (text.contains(syn)) {
            score = 0.78;
            concept = 'Contextual Concept: $syn';
            break;
          }
        }
      }

      // Apply confidence threshold > 60%
      if (score >= 0.60) {
        results.add(SmartSearchResult(
          entry: entry,
          confidenceScore: score,
          matchedConcept: concept,
        ));
      }
    }

    results.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    return results;
  }

  /// Automatically categorizes entries into Memory Collections
  Map<String, List<LocalJournalEntry>> categorizeCollections(List<LocalJournalEntry> entries) {
    final Map<String, List<LocalJournalEntry>> collections = {
      'Travel': [],
      'Friends': [],
      'Family': [],
      'Work': [],
      'Food': [],
      'Achievements': [],
    };

    for (var entry in entries) {
      final text = '${entry.title} ${entry.body}'.toLowerCase();
      if (text.contains('travel') || text.contains('trip') || text.contains('flight') || text.contains('hotel')) {
        collections['Travel']!.add(entry);
      }
      if (text.contains('friend') || text.contains('gathering') || text.contains('party')) {
        collections['Friends']!.add(entry);
      }
      if (text.contains('family') || text.contains('mom') || text.contains('dad') || text.contains('sister')) {
        collections['Family']!.add(entry);
      }
      if (text.contains('work') || text.contains('office') || text.contains('project') || text.contains('meeting')) {
        collections['Work']!.add(entry);
      }
      if (text.contains('coffee') || text.contains('tea') || text.contains('dinner') || text.contains('food')) {
        collections['Food']!.add(entry);
      }
      if (text.contains('won') || text.contains('achieved') || text.contains('passed') || text.contains('victory')) {
        collections['Achievements']!.add(entry);
      }
    }

    return collections;
  }
}
