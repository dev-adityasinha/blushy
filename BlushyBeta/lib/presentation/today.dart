import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/state.dart';

String _getTimeBasedGreetingPrefix() {
  final istNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  final hour = istNow.hour;
  if (hour < 12) {
    return "Good Morning";
  } else if (hour < 17) {
    return "Good Afternoon";
  } else {
    return "Good Evening";
  }
}

class TodayBriefingScreen extends StatefulWidget {
  const TodayBriefingScreen({super.key});

  @override
  State<TodayBriefingScreen> createState() => _TodayBriefingScreenState();
}

class _TodayBriefingScreenState extends State<TodayBriefingScreen> {
  final TextEditingController _journalInputController = TextEditingController();
  final FocusNode _journalFocus = FocusNode();

  @override
  void dispose() {
    _journalInputController.dispose();
    _journalFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Phase Ledger
          Text(
            '${_getTimeBasedGreetingPrefix()}, ${state.userName}',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 34,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, py: 4),
                decoration: BoxDecoration(
                  color: BlushyColors.lutealSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.cyclePhase} • Day ${state.cycleDay}',
                  style: const TextStyle(
                    color: BlushyColors.lutealText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sleep: ${state.sleepHours}h',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Sia's AI Briefing Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: BlushyColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: BlushyColors.border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: BlushyColors.textDark.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: BlushyColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Sia\'s Daily Edit',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: BlushyColors.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  state.aiBriefingSummary,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    height: 1.6,
                    color: BlushyColors.textDark.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Today's Action Card
          Text(
            'Recommended Action',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: state.recommendedActionCompleted 
                ? BlushyColors.background 
                : BlushyColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: state.recommendedActionCompleted 
                  ? BlushyColors.border 
                  : BlushyColors.border.withOpacity(0.8),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.recommendedActionTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: state.recommendedActionCompleted 
                            ? TextDecoration.lineThrough 
                            : null,
                          color: state.recommendedActionCompleted 
                            ? BlushyColors.textLight 
                            : BlushyColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.recommendedActionSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: state.recommendedActionCompleted 
                    ? null 
                    : () => state.completeRecommendedAction(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, py: 10),
                    decoration: BoxDecoration(
                      color: state.recommendedActionCompleted 
                        ? Colors.transparent 
                        : BlushyColors.primary,
                      borderRadius: BorderRadius.circular(30),
                      border: state.recommendedActionCompleted 
                        ? Border.all(color: BlushyColors.border) 
                        : null,
                    ),
                    child: Text(
                      state.recommendedActionCompleted ? 'Done' : 'Do',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: state.recommendedActionCompleted 
                          ? BlushyColors.textMuted 
                          : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Daily Journal Reflection Box (connected to state & briefing updates)
          Text(
            'Journal Reflection',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BlushyColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BlushyColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How is your body feeling right now?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: BlushyColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _journalInputController,
                  focusNode: _journalFocus,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14, color: BlushyColors.textDark),
                  decoration: InputDecoration(
                    hintText: "Reflect here... (e.g. 'I am feeling super tired today')",
                    hintStyle: const TextStyle(fontSize: 14, color: BlushyColors.textLight),
                    filled: true,
                    fillColor: BlushyColors.background.withOpacity(0.5),
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: BlushyColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: BlushyColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: BlushyColors.secondary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        if (_journalInputController.text.isNotEmpty) {
                          String content = _journalInputController.text;
                          String mood = "Mindful";
                          if (content.toLowerCase().contains("tired") || content.toLowerCase().contains("exhausted")) {
                            mood = "Fatigued";
                          } else if (content.toLowerCase().contains("stress") || content.toLowerCase().contains("anxious")) {
                            mood = "Anxious";
                          }
                          state.addJournal(content, mood);
                          _journalInputController.clear();
                          _journalFocus.unfocus();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Briefing adapted. Check Sia & Journey.'),
                              duration: Duration(seconds: 2),
                              backgroundColor: BlushyColors.primary,
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: BlushyColors.textDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, py: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Commit to Ledger', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Daily Insight Card
          Text(
            'Today\'s Insight',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BlushyColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BlushyColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PHYSIOLOGY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: BlushyColors.accent,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Progesterone & Sleep Temperature',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'During the luteal phase, the body temperature rises by about 0.5 degrees Celsius due to elevated progesterone. This minor shift can block deep sleep sequences, making the initial sleep onset feel restless.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
