import '../../../services/journal_storage.dart';

class JournalRepository {
  final JournalStorage _storage = JournalStorage();

  Future<List<LocalJournalEntry>> getAllEntries(String userId) async {
    return await _storage.loadEntries(userId);
  }

  Future<void> saveEntries(String userId, List<LocalJournalEntry> entries) async {
    await _storage.saveEntries(userId, entries);
  }

  Future<void> addOrUpdateEntry(String userId, LocalJournalEntry entry) async {
    final entries = await getAllEntries(userId);
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      entries[index] = entry;
    } else {
      entries.insert(0, entry);
    }
    await saveEntries(userId, entries);
  }

  Future<void> deleteEntry(String userId, String entryId) async {
    final entries = await getAllEntries(userId);
    entries.removeWhere((e) => e.id == entryId);
    await saveEntries(userId, entries);
  }
}
