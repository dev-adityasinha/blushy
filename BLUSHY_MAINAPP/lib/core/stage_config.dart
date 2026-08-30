import 'package:flutter/material.dart';

String formatConnectionDuration(dynamic rawDate) {
  if (rawDate == null) return "Connected recently";

  DateTime? connectedDate;
  if (rawDate is DateTime) {
    connectedDate = rawDate;
  } else if (rawDate is String && rawDate.isNotEmpty) {
    connectedDate = DateTime.tryParse(rawDate);
  }

  if (connectedDate == null) return "Connected recently";

  final now = DateTime.now();
  if (connectedDate.isAfter(now)) {
    return "Connected today";
  }

  int years = now.year - connectedDate.year;
  int months = now.month - connectedDate.month;
  int days = now.day - connectedDate.day;

  if (days < 0) {
    months -= 1;
    final prevMonthDate = DateTime(now.year, now.month, 0);
    days += prevMonthDate.day;
  }

  if (months < 0) {
    years -= 1;
    months += 12;
  }

  final List<String> parts = [];
  if (years > 0) {
    parts.add("$years ${years == 1 ? 'year' : 'years'}");
  }
  if (months > 0) {
    parts.add("$months ${months == 1 ? 'month' : 'months'}");
  }
  if (days > 0 || parts.isEmpty) {
    parts.add("$days ${days == 1 ? 'day' : 'days'}");
  }

  return "Connected for ${parts.join(' ')}";
}

class StageConfig {
  final String stageKey;
  final String displayName;
  final Color primaryColor;
  final List<String> siaSuggestions;
  final List<String> communityTags;
  final List<String> journalTemplates;

  // Partner screen specific configs
  final String supportFocus;
  final String partnerSubLabel;
  final String gardenQuote;

  StageConfig({
    required this.stageKey,
    required this.displayName,
    required this.primaryColor,
    required this.siaSuggestions,
    required this.communityTags,
    required this.journalTemplates,
    required this.supportFocus,
    required this.partnerSubLabel,
    required this.gardenQuote,
  });

  String formatPartnerSubLabel(dynamic connectedDate) {
    final duration = formatConnectionDuration(connectedDate);
    return "$duration • $supportFocus";
  }

  factory StageConfig.forStage(String stageKey) {
    switch (stageKey) {
      case 'firstPeriodNotStarted':
        return StageConfig(
          stageKey: stageKey,
          displayName: 'First Period (Not Started)',
          primaryColor: const Color(0xFFC71585),
          siaSuggestions: [
            'What is a period?',
            'When will my first period start?',
            'What symptoms should I look for?',
          ],
          communityTags: ['First Period', 'Puberty', 'School Life', 'Body Changes'],
          journalTemplates: ['Daily Reflection', 'Mood Journal', 'First Steps'],
          supportFocus: 'Puberty Support',
          partnerSubLabel: 'Puberty Support',
          gardenQuote: '“Tending to your relationship garden builds healthy, open conversations about growing up.”',
          );

      case 'firstPeriodStarted':
        return StageConfig(
          stageKey: stageKey,
          displayName: 'First Period (Started)',
          primaryColor: const Color(0xFFFF69B4),
          siaSuggestions: [
            'How do I track my period?',
            'Managing period cramps',
            'How long does a cycle last?',
          ],
          communityTags: ['My Cycle', 'Coping Tips', 'School Life', 'Self-Care'],
          journalTemplates: ['Daily Reflection', 'Symptom Logger', 'Cycle Note'],
          supportFocus: 'Cycle Support',
          partnerSubLabel: 'Cycle Support',
          gardenQuote: '“Open conversations and mutual understanding tend the cycle support garden.”',
          );

      case 'reproductiveYears':
      case 'livingWithMyCycle':
        return StageConfig(
          stageKey: stageKey,
          displayName: 'Living with My Cycle',
          primaryColor: const Color(0xFFFF9B9E),
          siaSuggestions: [
            'Explain my cycle phases.',
            'Best workouts for my follicular phase?',
            'Why am I feeling emotional today?',
          ],
          communityTags: ['PMS', 'Hormones', 'Cycle Check-in', 'Productivity', 'Nutrition'],
          journalTemplates: ['Daily Reflection', 'Cycle Reflection', 'Gratitude', 'Dream Journal'],
          supportFocus: 'Living Steady',
          partnerSubLabel: 'Living Steady',
          gardenQuote: '“Partner completed his check-in. Tending to your relationship garden builds healthy mutual rhythms.”',
          );

      case 'hormonalHealth':
        return StageConfig(
          stageKey: stageKey,
          displayName: 'Hormonal Health',
          primaryColor: const Color(0xFFBA55D3),
          siaSuggestions: [
            'How can I manage hormonal bloating?',
            'What causes irregular periods?',
            'Natural tips for balancing hormones',
          ],
          communityTags: ['PCOS', 'Endometriosis', 'Thyroid', 'Hormone Healing', 'Nutrition'],
          journalTemplates: ['Daily Reflection', 'Symptom & Trigger Log', 'Food Diary', 'Weekly Check-in'],
          supportFocus: 'Hormonal Support',
          partnerSubLabel: 'Hormonal Support',
          gardenQuote: '“Navigating hormonal shifts together keeps the relationship garden strong and supportive.”',
          );

      case 'tryingToConceive':
        return StageConfig(
          stageKey: stageKey,
          displayName: 'Trying to Conceive',
          primaryColor: const Color(0xFFFFA07A),
          siaSuggestions: [
            'When is my fertile window?',
            'Explain ovulation tracking',
            'Healthy foods to boost fertility',
          ],
          communityTags: ['Fertility Window', 'TTC Journey', 'Ovulation', 'Nutrition', 'Mental Wellness'],
          journalTemplates: ['Daily Reflection', 'Fertility Log', 'Symptom Logger', 'Hope & Affirmations'],
          supportFocus: 'Fertility Focus',
          partnerSubLabel: 'Fertility Focus',
          gardenQuote: '“Tending to your relationship garden during fertility tracking builds collaborative support.”',
          );

      case 'pregnancy':
        return StageConfig(
          stageKey: stageKey,
          displayName: 'Pregnancy',
          primaryColor: const Color(0xFFFFB6C1),
          siaSuggestions: [
            'Safe exercises for second trimester',
            'What size is the baby this week?',
            'How to manage morning sickness?',
          ],
          communityTags: ['Trimesters', 'Baby Prep', 'Pregnancy Symptoms', 'Prenatal Care', 'Birth Plan'],
          journalTemplates: ['Pregnancy Journal', 'Weekly Milestones', 'Baby Prep Checklist', 'Daily Reflection'],
          supportFocus: 'Prenatal Support',
          partnerSubLabel: 'Prenatal Support',
          gardenQuote: '“Tending to your pregnancy garden together builds strong prenatal connection.”',
          );

      case 'postpartum':
        return StageConfig(
          stageKey: stageKey,
          displayName: 'Postpartum',
          primaryColor: const Color(0xFFFFD700),
          siaSuggestions: [
            'Managing postpartum fatigue',
            'Safe pelvic floor exercises',
            'How to support newborn sleep?',
          ],
          communityTags: ['Newborn Care', 'Recovery Tips', 'Postpartum Mood', 'Breastfeeding', 'Self-Care'],
          journalTemplates: ['Postpartum Recovery Log', 'Baby Log', 'Gratitude Journal', 'Daily Reflection'],
          supportFocus: 'Postpartum Recovery',
          partnerSubLabel: 'Postpartum Recovery',
          gardenQuote: '“Caring for each other during postpartum recovery tends your relationship garden.”',
          );

      case 'perimenopause':
        return StageConfig(
          stageKey: stageKey,
          displayName: 'Perimenopause',
          primaryColor: const Color(0xFF4682B4),
          siaSuggestions: [
            'What are signs of perimenopause?',
            'How to sleep better with night sweats?',
            'Explain cycle length changes',
          ],
          communityTags: ['Perimenopause', 'Cycle Changes', 'Sleep', 'Hormone Shifts', 'Vascular Health'],
          journalTemplates: ['Daily Reflection', 'Symptom & Sleep Log', 'Gratitude', 'Weekly Check-in'],
          supportFocus: 'Perimenopause Shift',
          partnerSubLabel: 'Perimenopause Shift',
          gardenQuote: '“Navigating perimenopause shifts together builds deep relationship strength.”',
          );

      case 'menopause':
        return StageConfig(
          stageKey: stageKey,
          displayName: 'Menopause',
          primaryColor: const Color(0xFF5F9EA0),
          siaSuggestions: [
            'How to manage hot flashes?',
            'Explain how estrogen drop affects my bones',
            'What exercises support joint health?',
          ],
          communityTags: ['Hot Flashes', 'Bone Density', 'HRT', 'Cardiovascular Health', 'Nutrition'],
          journalTemplates: ['Daily Reflection', 'Symptom & HRT Log', 'Gratitude', 'Weekly Check-in'],
          supportFocus: 'Menopause Support',
          partnerSubLabel: 'Menopause Support',
          gardenQuote: '“Tending to your relationship garden during menopause shifts builds healthy mutual rhythms.”',
          );

      case 'partner':
        return StageConfig(
          stageKey: stageKey,
          displayName: 'Partner Support',
          primaryColor: const Color(0xFF8FAE8A),
          siaSuggestions: [
            'How can I support my partner during PMS?',
            'What should I know about her follicular phase?',
            'Healthy meal ideas for luteal phase?',
            'How to help her track ovulation?',
          ],
          communityTags: ['Partner Support', 'Communication', 'Partner Q&A', 'Shared Journey', 'Self-Care'],
          journalTemplates: ['Daily Support Log', 'Relationship Reflection', 'Milestone Journal', 'Gratitude Log'],
          supportFocus: 'Partner Mode',
          partnerSubLabel: 'Partner Mode',
          gardenQuote: '“Tending to your relationship garden in Partner Mode builds healthy mutual rhythms.”',
          );

      default:
        return StageConfig(
          stageKey: 'everydayWellness',
          displayName: 'Everyday Wellness',
          primaryColor: const Color(0xFFFF9B9E),
          siaSuggestions: [
            'Why am I feeling tired today?',
            'Should I work out today?',
            'Healthy habits recommendations',
          ],
          communityTags: ['General Health', 'Mental Health', 'Productivity', 'Nutrition', 'Fitness'],
          journalTemplates: ['Daily Reflection', 'Gratitude', 'Weekly Check-in', 'Dream Journal'],
          supportFocus: 'Everyday Wellness',
          partnerSubLabel: 'Everyday Wellness',
          gardenQuote: '“Tending to your wellness garden together builds daily healthy habits.”',
          );
    }
  }
}
