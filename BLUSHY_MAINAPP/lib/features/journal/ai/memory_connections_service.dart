import '../../../services/journal_storage.dart';

class ConnectedMemory {
  final LocalJournalEntry targetEntry;
  final String explanation;
  final double similarityScore;

  ConnectedMemory({
    required this.targetEntry,
    required this.explanation,
    required this.similarityScore,
  });
}

class MemoryConnectionsService {
  List<ConnectedMemory> findConnections(LocalJournalEntry currentEntry, List<LocalJournalEntry> allEntries) {
    final List<ConnectedMemory> connections = [];
    final currentText = '${currentEntry.title} ${currentEntry.body}'.toLowerCase();

    for (var other in allEntries) {
      if (other.id == currentEntry.id) continue;

      final otherText = '${other.title} ${other.body}'.toLowerCase();
      
      // Keyword matching explanations
      if (currentText.contains('coffee') && otherText.contains('coffee')) {
        connections.add(ConnectedMemory(
          targetEntry: other,
          explanation: 'Related because both mention coffee shops and conversations.',
          similarityScore: 0.88,
        ));
      } else if (currentText.contains('park') && otherText.contains('park')) {
        connections.add(ConnectedMemory(
          targetEntry: other,
          explanation: 'Related because both mention walks in the park.',
          similarityScore: 0.82,
        ));
      } else if (currentText.contains('rain') && otherText.contains('rain')) {
        connections.add(ConnectedMemory(
          targetEntry: other,
          explanation: 'Related because both reflect on rainy cozy days.',
          similarityScore: 0.79,
        ));
      } else if (currentEntry.moodKey == other.moodKey && currentEntry.moodKey == 'happy') {
        connections.add(ConnectedMemory(
          targetEntry: other,
          explanation: 'Related because both were written on joyful days.',
          similarityScore: 0.75,
        ));
      }
    }

    // Sort by similarity score
    connections.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return connections.take(3).toList();
  }
}
