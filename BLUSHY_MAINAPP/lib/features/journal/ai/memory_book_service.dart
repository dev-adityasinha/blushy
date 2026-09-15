import '../../../services/journal_storage.dart';

class MemoryBook {
  final String title;
  final String datePeriodStr;
  final int totalEntries;
  final int totalPhotos;
  final int totalVoiceNotes;
  final String favoriteMomentSnippet;
  final List<String> topStickersUsed;

  MemoryBook({
    required this.title,
    required this.datePeriodStr,
    required this.totalEntries,
    required this.totalPhotos,
    required this.totalVoiceNotes,
    required this.favoriteMomentSnippet,
    required this.topStickersUsed,
  });
}

class MemoryBookService {
  MemoryBook generateWeeklyBook(List<LocalJournalEntry> entries) {
    int photoCount = 0;
    int voiceCount = 0;

    for (var entry in entries) {
      if (entry.rawJson != null) {
        if (entry.rawJson!.contains('"type":"photo"')) photoCount++;
        if (entry.rawJson!.contains('"type":"voice"')) voiceCount++;
      }
    }

    final snippet = entries.isNotEmpty
        ? (entries.first.body.length > 90 ? '${entries.first.body.substring(0, 90)}...' : entries.first.body)
        : 'A beautiful week of growth and reflection.';

    return MemoryBook(
      title: 'This Week\'s Memory Book 📖',
      datePeriodStr: 'Past 7 Days',
      totalEntries: entries.length,
      totalPhotos: photoCount,
      totalVoiceNotes: voiceCount,
      favoriteMomentSnippet: snippet,
      topStickersUsed: ['🌸 Flower', '⭐ Star', '🍃 Leaf'],
    );
  }
}
