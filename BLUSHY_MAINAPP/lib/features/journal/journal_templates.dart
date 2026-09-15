/// What each journal template actually puts on the page.
///
/// Templates were names and nothing else: choosing "Gratitude" created an
/// entry titled "Gratitude" with the same blank "Tap to start writing your
/// reflection..." as every other one. The list varied by life stage, so the
/// app knew which template suited her — and then did nothing with it.
///
/// A template is now a small set of prompts, placed on the page, so the entry
/// opens already asking something worth answering.
///
/// **These are reflective prompts, not health guidance.** Nothing here tells
/// anyone what to do about a symptom or a condition. Clinical content is
/// served from the reviewed pipeline with a named reviewer, and a journal
/// prompt is not the place to smuggle advice past that. The pregnancy and
/// postpartum sets are deliberately gentle and avoid assuming how a pregnancy
/// went.
class JournalTemplates {
  const JournalTemplates._();

  /// The prompt a blank entry opens with when no template applies.
  static const List<String> fallback = [
    'What is on your mind today?',
  ];

  /// Matched on keywords rather than exact names: the stage lists carry 36
  /// variations ("Gratitude", "Gratitude Log", "Gratitude Journal") and new
  /// ones get added, so exact matching would quietly fall back to blank.
  static List<String> promptsFor(String? templateName) {
    final name = (templateName ?? '').toLowerCase();

    if (name.contains('gratitude')) {
      return const [
        'Three things you were glad of today.',
        'Who made today easier?',
        'Something small you would like to remember.',
      ];
    }

    if (name.contains('dream')) {
      return const [
        'What do you remember?',
        'How did it leave you feeling?',
      ];
    }

    if (name.contains('mood')) {
      return const [
        'How are you feeling right now?',
        'What shifted it today, if anything?',
        'What would help this evening?',
      ];
    }

    if (name.contains('symptom') || name.contains('trigger')) {
      return const [
        'What did you notice in your body today?',
        'When was it strongest?',
        'What was happening around it — sleep, food, stress, anything?',
      ];
    }

    if (name.contains('food') || name.contains('diary')) {
      return const [
        'What did you eat today?',
        'What did you have energy for afterwards?',
      ];
    }

    if (name.contains('sleep')) {
      return const [
        'How did you sleep?',
        'How did you feel on waking?',
      ];
    }

    if (name.contains('cycle') || name.contains('period')) {
      return const [
        'How does your body feel today?',
        'What is your energy like compared with yesterday?',
        'Anything you want to remember about this phase.',
      ];
    }

    if (name.contains('fertility') || name.contains('ttc')) {
      return const [
        'How are you feeling about this month?',
        'What has been hardest, and what has helped?',
        'Something you want to say to yourself later.',
      ];
    }

    // Kept deliberately open. A prompt that assumes a due date or a growing
    // bump lands badly on someone whose pregnancy has ended.
    if (name.contains('pregnan') || name.contains('prenatal')) {
      return const [
        'How are you today?',
        'What has been on your mind this week?',
        'Something you would like to remember about now.',
      ];
    }

    if (name.contains('postpartum') || name.contains('recovery')) {
      return const [
        'How are you feeling today — honestly?',
        'What did you manage, however small?',
        'What would you like help with?',
      ];
    }

    if (name.contains('baby') || name.contains('milestone') ||
        name.contains('first steps')) {
      return const [
        'What happened today worth keeping?',
        'What did you notice for the first time?',
      ];
    }

    if (name.contains('menopause') || name.contains('perimenopause') ||
        name.contains('hrt') || name.contains('hormonal')) {
      return const [
        'What did today feel like in your body?',
        'What has changed lately that you want to track?',
        'What made the day easier?',
      ];
    }

    if (name.contains('puberty')) {
      return const [
        'What is something new you noticed?',
        'What would you like to know more about?',
      ];
    }

    if (name.contains('relationship') || name.contains('partner')) {
      return const [
        'What went well between you today?',
        'What did you wish you had said?',
        'What would you like them to know?',
      ];
    }

    if (name.contains('hope') || name.contains('affirmation')) {
      return const [
        'What are you hoping for?',
        'What would you tell a friend in your position?',
      ];
    }

    if (name.contains('weekly') || name.contains('check-in') ||
        name.contains('checkin')) {
      return const [
        'What stood out this week?',
        'What drained you, and what restored you?',
        'What is one thing for next week?',
      ];
    }

    if (name.contains('support') || name.contains('steady') ||
        name.contains('wellness') || name.contains('daily') ||
        name.contains('reflection')) {
      return const [
        'How was today?',
        'What is worth remembering about it?',
      ];
    }

    return fallback;
  }
}
