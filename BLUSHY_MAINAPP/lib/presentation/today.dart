import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/state.dart';
import '../services/html_audio_helper.dart';
import '../services/api_sia_service.dart';
import '../services/sia_dashboard_service.dart';

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
  final ApiSiaService _siaService = ApiSiaService();

  HtmlAudioRecorder? _audioRecorder;
  bool _isListeningVoice = false;

  bool _recommendedActionCompleted = false;
  final String _recommendedActionTitle = "Hydration & Rest Routine";
  final String _recommendedActionSubtitle = "Drink 500ml water and take a 10-minute quiet reflection.";

  @override
  void dispose() {
    _journalInputController.dispose();
    _journalFocus.dispose();
    _audioRecorder?.cancel();
    super.dispose();
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isListeningVoice && _audioRecorder != null) {
      setState(() {
        _isListeningVoice = false;
      });

      try {
        final recordResult = await _audioRecorder!.stop();
        final audioBytes = recordResult?.bytes ?? [];
        if (audioBytes.isNotEmpty) {
          final transcribedText = await _siaService.transcribeAudioBytes(
            audioBytes,
            'today_reflection_${DateTime.now().millisecondsSinceEpoch}.webm',
          );

          if (mounted) {
            setState(() {
            });
            if (transcribedText.trim().isNotEmpty) {
              _journalInputController.text = transcribedText.trim();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Voice reflection transcribed! Review your text and tap Save.")),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No spoken audio could be recognized. Please try again.")),
              );
            }
          }
        } else {
          if (mounted) {
            setState(() {
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Voice recording error: $e")),
          );
        }
      }
    } else {
      try {
        _audioRecorder = HtmlAudioRecorder();
        await _audioRecorder!.start();
        if (mounted) {
          setState(() {
            _isListeningVoice = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isListeningVoice = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Microphone error: $e")),
          );
        }
      }
    }
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
            '${_getTimeBasedGreetingPrefix()}, ${state.personalContext.userName ?? "there"}',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 34,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BlushyColors.lutealSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.personalContext.cyclePhase ?? "Follicular"} • Day ${state.personalContext.cycleDay ?? 14}',
                  style: const TextStyle(
                    color: BlushyColors.lutealText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sleep: 7.5h',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Docsy's AI Briefing Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: BlushyColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BlushyColors.border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: BlushyColors.dark.withValues(alpha: 0.02),
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
                      'Docsy\'s Daily Edit',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: BlushyColors.dark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  SiaDashboardService().getDailyHeaderBrief(
                    pc: state.personalContext,
                    state: state,
                    stagesSummary: "your wellness rhythm",
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    height: 1.6,
                    color: BlushyColors.dark.withValues(alpha: 0.9),
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
              color: _recommendedActionCompleted 
                ? BlushyColors.background 
                : BlushyColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _recommendedActionCompleted 
                  ? BlushyColors.border 
                  : BlushyColors.border.withValues(alpha: 0.8),
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
                        _recommendedActionTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: _recommendedActionCompleted 
                            ? TextDecoration.lineThrough 
                            : null,
                          color: _recommendedActionCompleted 
                            ? BlushyColors.secondaryText 
                            : BlushyColors.dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _recommendedActionSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _recommendedActionCompleted 
                    ? null 
                    : () => setState(() => _recommendedActionCompleted = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _recommendedActionCompleted 
                        ? Colors.transparent 
                        : BlushyColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      border: _recommendedActionCompleted 
                        ? Border.all(color: BlushyColors.border) 
                        : null,
                    ),
                    child: Text(
                      _recommendedActionCompleted ? 'Done' : 'Do',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _recommendedActionCompleted 
                          ? BlushyColors.secondaryText 
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
              borderRadius: BorderRadius.circular(12),
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
                    color: BlushyColors.dark,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _journalInputController,
                  focusNode: _journalFocus,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14, color: BlushyColors.dark),
                  decoration: InputDecoration(
                    hintText: "Reflect here... (e.g. 'I am feeling super tired today')",
                    hintStyle: const TextStyle(fontSize: 14, color: BlushyColors.secondaryText),
                    filled: true,
                    fillColor: BlushyColors.background.withValues(alpha: 0.5),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _toggleVoiceRecording,
                      icon: Icon(
                        _isListeningVoice ? Icons.stop_rounded : Icons.mic_rounded,
                        color: _isListeningVoice ? Colors.white : const Color(0xFF6F42F5),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isListeningVoice ? BlushyColors.primary : const Color(0xFFF3E8FF),
                      ),
                      tooltip: "Speak reflection",
                    ),
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
                              content: Text('Briefing adapted. Check Docsy & Journey.'),
                              duration: Duration(seconds: 2),
                              backgroundColor: BlushyColors.primary,
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: BlushyColors.dark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(12),
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
