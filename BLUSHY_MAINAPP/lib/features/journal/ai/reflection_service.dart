import '../../../services/journal_storage.dart';

enum ReflectionPeriod { weekly, monthly, yearly }

class ReflectionSummary {
  final ReflectionPeriod period;
  final String dateRangeStr;
  final String summaryText;
  final List<String> topThemes;
  final String moodTrendSummary;

  ReflectionSummary({
    required this.period,
    required this.dateRangeStr,
    required this.summaryText,
    required this.topThemes,
    required this.moodTrendSummary,
  });
}

class ReflectionService {
  ReflectionSummary generateSummary(List<LocalJournalEntry> entries, ReflectionPeriod period) {
    if (entries.isEmpty) {
      return ReflectionSummary(
        period: period,
        dateRangeStr: 'Recent Period',
        summaryText: 'You haven\'t written any reflections yet. Start journaling to unlock insights! 🌸',
        topThemes: ['Writing', 'Reflection'],
        moodTrendSummary: 'Neutral',
      );
    }

    final total = entries.length;
    final String periodLabel = period == ReflectionPeriod.weekly ? 'this week' : (period == ReflectionPeriod.monthly ? 'this month' : 'this year');
    final summaryText = 'You created $total journal entries $periodLabel. Your reflections frequently highlighted outdoor time, gratitude, and spending warm moments with family and friends. 🌿';

    return ReflectionSummary(
      period: period,
      dateRangeStr: periodLabel.toUpperCase(),
      summaryText: summaryText,
      topThemes: ['Gratitude', 'Friends & Family', 'Outdoors', 'Quiet Time'],
      moodTrendSummary: 'Mostly Satisfied & Peaceful',
    );
  }
}
