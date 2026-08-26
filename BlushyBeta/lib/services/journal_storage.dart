import '../core/storage.dart';

class LocalJournalEntry {
  LocalJournalEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.body,
    required this.moodKey,
    this.dateTime,
    this.rawJson,
    this.aiMetadata,
  });

  final String id;
  final String date;
  final String title;
  final String body;
  final String moodKey;
  final String? dateTime;
  final String? rawJson;
  final Map<String, dynamic>? aiMetadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'body': body,
        'moodKey': moodKey,
        'dateTime': dateTime,
        'rawJson': rawJson,
        'aiMetadata': aiMetadata,
      };

  factory LocalJournalEntry.fromJson(Map<String, dynamic> json) => LocalJournalEntry(
        id: json['id'] as String? ?? 'entry_${DateTime.now().millisecondsSinceEpoch}',
        date: json['date'] as String? ?? '',
        title: json['title'] as String? ?? 'Daily Reflection',
        body: json['body'] as String? ?? '',
        moodKey: json['moodKey'] as String? ?? 'neutral',
        dateTime: json['dateTime'] as String?,
        rawJson: json['rawJson'] as String?,
        aiMetadata: json['aiMetadata'] != null ? Map<String, dynamic>.from(json['aiMetadata'] as Map) : null,
      );
}

class JournalStorage {
  JournalStorage();

  String _getUserStorageKey(String userId) => 'blushy_journal_entries_$userId.json';

  Future<List<LocalJournalEntry>> loadEntries(String userId) async {
    try {
      final key = _getUserStorageKey(userId);
      final data = BlushyStorage.read(key);
      final List<dynamic>? rawList = data['entries'] as List<dynamic>?;
      if (rawList == null || rawList.isEmpty) return [];
      return rawList.map((item) => LocalJournalEntry.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEntries(String userId, List<LocalJournalEntry> entries) async {
    try {
      final key = _getUserStorageKey(userId);
      BlushyStorage.write(key, {
        'entries': entries.map((e) => e.toJson()).toList(),
      });
    } catch (_) {}
  }
}
