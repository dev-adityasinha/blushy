import '../../../services/journal_storage.dart';

class MoodTimelineNode {
  final String dateStr;
  final String moodKey;
  final String emoji;
  final String title;

  MoodTimelineNode({
    required this.dateStr,
    required this.moodKey,
    required this.emoji,
    required this.title,
  });
}

class MoodTimelineService {
  String getEmojiForMood(String moodKey) {
    switch (moodKey) {
      case 'happy':
      case 'very_satisfied':
        return '😄';
      case 'satisfied':
        return '🙂';
      case 'neutral':
        return '😐';
      case 'sad':
        return '🙁';
      case 'very_sad':
        return '😫';
      default:
        return '🙂';
    }
  }

  List<MoodTimelineNode> buildTimeline(List<LocalJournalEntry> entries) {
    return entries.map((e) {
      return MoodTimelineNode(
        dateStr: e.date,
        moodKey: e.moodKey,
        emoji: getEmojiForMood(e.moodKey),
        title: e.title,
      );
    }).toList();
  }
}
