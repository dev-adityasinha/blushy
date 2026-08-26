import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../core/theme.dart' hide BlushyColors;

import '../../services/api_sia_service.dart';
import '../../services/html_audio_helper.dart';
import '../../core/storage.dart';
import '../../core/state.dart';
import '../../core/cycle_calculator.dart';
import '../home/widgets/cycle_card.dart';

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

class BlushySiaScreen extends StatefulWidget {
  final String? initialQuestion;
  final VoidCallback? onRedirectToMood;
  final VoidCallback? onRedirectToEnergy;
  final VoidCallback? onRedirectToCycle;
  final VoidCallback? onRedirectToSleep;

  const BlushySiaScreen({
    super.key,
    this.initialQuestion,
    this.onRedirectToMood,
    this.onRedirectToEnergy,
    this.onRedirectToCycle,
    this.onRedirectToSleep,
  });

  @override
  State<BlushySiaScreen> createState() => _BlushySiaScreenState();
}

class _BlushySiaScreenState extends State<BlushySiaScreen> with TickerProviderStateMixin {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  final ApiSiaService _siaService = ApiSiaService();

  late final AnimationController _waveController;
  bool _isListeningVoice = false;
  bool _isThinking = false;

  late final Timer _placeholderTimer;
  int _placeholderIndex = 0;
  final List<String> _placeholders = [
    "Why am I feeling emotional today?",
    "Should I work out today?",
    "Explain my cycle.",
    "Why am I so tired?",
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _placeholderTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
        });
      }
    });

    _loadChatHistory();

    if (widget.initialQuestion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendUserMessage(widget.initialQuestion!);
      });
    }
  }

  Future<void> _loadChatHistory() async {
    final history = await _siaService.getChatHistory();
    if (mounted && history.isNotEmpty) {
      setState(() {
        _messages.clear();
        _messages.addAll(history);
      });
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _waveController.dispose();
    _placeholderTimer.cancel();
    super.dispose();
  }

  HtmlAudioRecorder? _audioRecorder;
  int _recordingSeconds = 0;

  Future<void> _sendUserMessage(String query) async {
    if (query.trim().isEmpty) return;

    final state = BlushyOSProvider.of(context);
    dynamic savedWeight;
    try {
      savedWeight = BlushyStorage.read('logged_weight.json')['weight'] ?? state.personalContext.weight;
    } catch (_) {
      savedWeight = state.personalContext.weight;
    }

    final contextData = <String, dynamic>{
      'userName': state.personalContext.userName,
      'cycleDay': state.personalContext.cycleDay,
      'cyclePhase': state.personalContext.cyclePhase,
      'lastPeriodStart': state.personalContext.lastPeriodStart?.toIso8601String(),
      'energy': state.wellbeingState.energy,
      'mood': state.wellbeingState.mood,
      'symptoms': state.wellbeingState.symptoms,
      'userGoals': state.personalContext.userGoals.toList(),
      if (savedWeight != null) 'currentWeight': '$savedWeight kg',
      if (savedWeight != null) 'weight': '$savedWeight kg',
    };

    setState(() {
      _messages.add({'sender': 'user', 'text': query});
      _chatController.clear();
      _isThinking = true;
    });

    try {
      final reply = await _siaService.sendMessage(query, healthContext: contextData);
      if (mounted) {
        setState(() {
          _isThinking = false;
          _messages.add({'sender': 'sia', 'text': reply});
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isThinking = false;
          _messages.add({
            'sender': 'sia',
            'text': 'I am here for you. Take your time. 💕',
          });
        });
      }
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isListeningVoice && _audioRecorder != null) {
      setState(() {
        _isListeningVoice = false;
        _isThinking = true;
      });

      try {
        final recordResult = await _audioRecorder!.stop();
        final audioBytes = recordResult?.bytes ?? [];
        if (audioBytes.isNotEmpty) {
          final transcribedText = await _siaService.transcribeAudioBytes(
            audioBytes,
            'sia_voice_${DateTime.now().millisecondsSinceEpoch}.webm',
          );

          if (mounted) {
            setState(() {
              _isThinking = false;
            });
            if (transcribedText.trim().isNotEmpty) {
              _sendUserMessage(transcribedText.trim());
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No spoken audio could be recognized. Please try again.")),
              );
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _isThinking = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No audio recorded. Please verify microphone permissions.")),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isThinking = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Voice note error: $e")),
          );
        }
      }
    } else {
      try {
        _audioRecorder = HtmlAudioRecorder();
        _recordingSeconds = 0;
        _audioRecorder!.onProgress = (sec) {
          if (mounted) {
            setState(() {
              _recordingSeconds = sec;
            });
          }
        };
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
            SnackBar(content: Text("Microphone access denied or unsupported: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0), // Warm Cream Editorial Background
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: BlushyTheme.getPagePadding(context), vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (Navigator.canPop(context)) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: BlushyColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_back_rounded, size: 18, color: BlushyColors.text),
                                const SizedBox(width: 6),
                                Text(
                                  'Back to Home',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: BlushyColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    // 1. Animated Breathing Orb Identity Section
                    Center(child: const _SiaBreathingOrb()),
                    const SizedBox(height: 12),

                    // 2. Personalized Context Greeting
                    Center(
                      child: Text(
                        '${_getTimeBasedGreetingPrefix()}, ${state.personalContext.userName ?? "there"}.',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.text,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3. Proactive Conversational AI Insight Card (Replaces Purple CTA)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2F2), // Soft blush
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFFFD6D6)),
                        boxShadow: [
                          BoxShadow(
                            color: BlushyColors.danger.withOpacity(0.01),
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
                              const Icon(Icons.auto_awesome_rounded, color: BlushyColors.warning, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                "SIA NOTICED SOMETHING TODAY",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: BlushyColors.danger,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "I've noticed you've slept almost 90 minutes less than usual this week. Combined with your luteal phase, that could explain today's fatigue.",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: BlushyColors.danger,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => _sendUserMessage("Explain today's fatigue"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6F42F5), // Brand Accent
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  elevation: 0,
                                ),
                                child: Text(
                                  "Explain More",
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () => _sendUserMessage("Create today's recovery plan"),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: const Color(0xFF6F42F5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                child: Text(
                                  "Recovery Plan",
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6F42F5)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4. Redesigned Today's Context Cards Grid (Non-spreadsheet style)
                    Text(
                      "TODAY'S CONTEXT",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final pc = state.personalContext;
                        final wb = state.wellbeingState;

                        final String cyclePhaseText;
                        final String cycleDayText;
                        if (pc.lastPeriodStart != null) {
                          final calc = CycleCalculation.compute(
                            lastPeriodStart: pc.lastPeriodStart,
                            cycleLength: pc.cycleLength ?? 28,
                          );
                          cyclePhaseText = calc.currentPhase;
                          cycleDayText = "Day ${calc.currentCycleDay}";
                        } else {
                          cyclePhaseText = "Follicular Phase";
                          cycleDayText = "Day 12";
                        }

                        final String sleepText = (wb.sleepQuality != null) 
                            ? "${wb.sleepQuality}h logged" 
                            : "7.5h logged";

                        final String energyText = (wb.energy != null) 
                            ? "Level ${wb.energy}/10" 
                            : "Balanced";

                        final String moodText = (wb.mood != null) 
                            ? "Level ${wb.mood}/10" 
                            : (wb.symptoms.isNotEmpty ? wb.symptoms.first : "Sleepy");

                        final double progressVal = (pc.lastPeriodStart != null)
                            ? ((DateTime.now().difference(pc.lastPeriodStart!).inDays % (pc.cycleLength ?? 28)) / (pc.cycleLength ?? 28)).clamp(0.0, 1.0)
                            : 0.43;

                        String moodEmoji = "😌";
                        if (moodText.toLowerCase().contains("tired")) moodEmoji = "🥱";
                        if (moodText.toLowerCase().contains("anxious")) moodEmoji = "😰";
                        if (moodText.toLowerCase().contains("sleep")) moodEmoji = "😴";
                        if (moodText.toLowerCase().contains("irrit")) moodEmoji = "😤";

                        final double screenWidth = MediaQuery.of(context).size.width;
                        final int responsiveColumns = screenWidth > 900 ? 4 : 2;
                        final double responsiveAspectRatio = screenWidth > 900
                            ? 1.55
                            : screenWidth > 600
                                ? 1.9
                                : 1.45;

                        return GridView.count(
                          crossAxisCount: responsiveColumns,
                          shrinkWrap: true,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: responsiveAspectRatio,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            // 1. Uterus Cycle Phase Card with Uterus Painter
                            _buildEditorialContextCard(
                              title: cyclePhaseText,
                              body: SizedBox(
                                height: 42,
                                width: double.infinity,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: 160,
                                    height: 60,
                                    child: CustomPaint(
                                      painter: SignatureCyclePathPainter(
                                        progress: progressVal,
                                        activePhase: cyclePhaseText,
                                        cycleLength: pc.cycleLength ?? 28,
                                        periodLength: 5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              value: cycleDayText,
                              onTap: () {
                                if (widget.onRedirectToCycle != null) {
                                  widget.onRedirectToCycle!();
                                } else {
                                  _showCycleDetailsModal(context, state, cyclePhaseText, cycleDayText);
                                }
                              },
                            ),

                            // 2. Sleep Card with Weekly Sleep Bar Chart
                            _buildEditorialContextCard(
                              title: "Sleep",
                              body: _MiniWeeklySleepBarChart(sleepVal: sleepText),
                              value: sleepText,
                              onTap: () {
                                if (widget.onRedirectToSleep != null) {
                                  widget.onRedirectToSleep!();
                                } else {
                                  _showSleepCheckInModal(context, state, sleepText);
                                }
                              },
                            ),

                            // 3. Energy Card with Redirection
                            _buildEditorialContextCard(
                              title: "Energy",
                              body: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 22, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    energyText,
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                                  ),
                                ],
                              ),
                              value: energyText,
                              onTap: () {
                                if (widget.onRedirectToEnergy != null) {
                                  widget.onRedirectToEnergy!();
                                } else {
                                  _showEnergyCheckInModal(context, state);
                                }
                              },
                            ),

                            // 4. Mood Card with Redirection
                            _buildEditorialContextCard(
                              title: "Mood",
                              body: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    moodEmoji,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    moodText,
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                                  ),
                                ],
                              ),
                              value: moodText,
                              onTap: () {
                                if (widget.onRedirectToMood != null) {
                                  widget.onRedirectToMood!();
                                } else {
                                  _showMoodCheckInModal(context, state);
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 5. Chat timeline or suggestions
                    if (_messages.isEmpty && !_isThinking) ...[
                      Text(
                        'DYNAMIC CONVERSATION STARTERS',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildStarterChip('Explain today\'s fatigue'),
                            const SizedBox(width: 8),
                            _buildStarterChip('Create today\'s recovery plan'),
                            const SizedBox(width: 8),
                            _buildStarterChip('Compare with last month'),
                            const SizedBox(width: 8),
                            _buildStarterChip('Why am I emotional today?'),
                          ],
                        ),
                      ),
                    ] else ...[
                      Column(
                        children: [
                          ..._messages.map((msg) => _buildMessageBubble(msg)),
                          if (_isThinking) _buildThinkingBubble(),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),

                    // 6. Continuous Premium Editorial Sections
                    _buildJournalContinuousSection(
                      "Pattern You've Been Building",
                      "You usually report 20% fewer symptoms when you stay hydrated during luteal cycle transitions. Keep up the high fluid count!",
                      Icons.trending_up_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildJournalContinuousSection(
                      "Journal Prompt",
                      "How does your body feel different today compared to yesterday? Reflect and log.",
                      Icons.edit_note_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildJournalContinuousSection(
                      "Voice Reflection",
                      "Record a 1-minute voice snapshot of your thoughts to allow Sia to track emotional trends.",
                      Icons.mic_none_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildJournalContinuousSection(
                      "Community Discussion",
                      "4,281 women in the community logged luteal exhaustion today. Share suggestions and support.",
                      Icons.forum_outlined,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // 7. Redesigned alive chat input panel
            _buildInputControlPanel(),
          ],
        ),
      ),
    );
  }

  void _showMoodCheckInModal(BuildContext context, BlushyOSState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final List<Map<String, dynamic>> moods = [
          {'emoji': '😌', 'label': 'Balanced', 'level': 7},
          {'emoji': '🥱', 'label': 'Tired', 'level': 4},
          {'emoji': '😴', 'label': 'Sleepy', 'level': 3},
          {'emoji': '😰', 'label': 'Anxious', 'level': 3},
          {'emoji': '😤', 'label': 'Irritated', 'level': 2},
          {'emoji': '💖', 'label': 'Happy', 'level': 9},
          {'emoji': '🧘', 'label': 'Calm', 'level': 8},
          {'emoji': '🌧️', 'label': 'Sad', 'level': 2},
        ];

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF6F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('😌', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(
                    'How are you feeling today?',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: moods.map((m) {
                  final label = m['label'] as String;
                  final emoji = m['emoji'] as String;
                  final level = m['level'] as int;
                  return InkWell(
                    onTap: () {
                      state.updateWellbeing(mood: level, symptoms: [label]);
                      Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Logged mood: $emoji $label')),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.text)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showEnergyCheckInModal(BuildContext context, BlushyOSState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final List<Map<String, dynamic>> energies = [
          {'icon': Icons.battery_1_bar_rounded, 'label': 'Very Low', 'level': 2, 'color': Colors.red},
          {'icon': Icons.battery_3_bar_rounded, 'label': 'Low', 'level': 4, 'color': Colors.orange},
          {'icon': Icons.bolt_rounded, 'label': 'Balanced', 'level': 6, 'color': const Color(0xFFF59E0B)},
          {'icon': Icons.battery_full_rounded, 'label': 'High', 'level': 8, 'color': Colors.green},
          {'icon': Icons.rocket_launch_rounded, 'label': 'Peak', 'level': 10, 'color': Colors.purple},
        ];

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF6F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'What is your energy level?',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: energies.map((e) {
                  final label = e['label'] as String;
                  final level = e['level'] as int;
                  final icon = e['icon'] as IconData;
                  final color = e['color'] as Color;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        state.updateWellbeing(energy: level);
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logged energy: $label ($level/10)')),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: BlushyColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, color: color, size: 22),
                            const SizedBox(width: 14),
                            Text(
                              label,
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text),
                            ),
                            const Spacer(),
                            Text(
                              'Level $level/10',
                              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showSleepCheckInModal(BuildContext context, BlushyOSState state, String currentSleep) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final List<double> sleepOptions = [5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF6F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bedtime_rounded, color: Color(0xFF6F42F5), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Log Sleep Duration',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Select how many hours of rest you logged last night:',
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sleepOptions.map((hours) {
                  return InkWell(
                    onTap: () {
                      state.updateWellbeing(sleepQuality: hours.toInt());
                      Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Logged sleep: ${hours}h')),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BlushyColors.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${hours}h',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showCycleDetailsModal(BuildContext context, BlushyOSState state, String phaseText, String dayText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pc = state.personalContext;
        final cycleLen = pc.cycleLength ?? 28;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF6F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop_rounded, color: BlushyColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Cycle Phase Overview',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$phaseText • $dayText',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Average Cycle Length: $cycleLen days',
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'During the $phaseText, your progesterone levels peak. Gentle walks, hydration, and light stretching can help manage any energy dips.',
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: pc.lastPeriodStart ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 90)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      Navigator.pop(ctx);
                      state.syncStateWithBackend();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Period start date recorded.')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text('Log Period Start Date', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditorialContextCard({
    required String title,
    required Widget body,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BlushyColors.border, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: BlushyColors.primary),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(child: Center(child: body)),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: BlushyColors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalContinuousSection(String title, String desc, IconData icon) {
    return GestureDetector(
      onTap: () {
        if (title.contains("Journal")) {
          _sendUserMessage("I want to write a journal entry: $desc");
        } else if (title.contains("Voice")) {
          _toggleVoiceRecording();
        } else {
          _sendUserMessage(desc);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BlushyColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF6F42F5)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: GoogleFonts.poppins(fontSize: 10.5, color: BlushyColors.secondaryText, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarterChip(String label) {
    return GestureDetector(
      onTap: () => _sendUserMessage(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BlushyColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> msg) {
    final text = msg['text']?.trim() ?? '';
    if (text.isEmpty && msg['rich'] == null) {
      return const SizedBox.shrink();
    }
    final isSia = msg['sender'] == 'sia';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Align(
        alignment: isSia ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSia ? Colors.white : const Color(0xFFF3EFEA),
            borderRadius: BorderRadius.circular(24),
            border: isSia ? Border.all(color: BlushyColors.border) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSia ? 'Sia Companion' : 'You',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSia ? const Color(0xFF6F42F5) : BlushyColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                msg['text'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: BlushyColors.text,
                  height: 1.45,
                ),
              ),
              if (isSia && msg['rich'] != null) ...[
                const SizedBox(height: 16),
                _buildRichComponent(msg['rich']!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichComponent(String type) {
    if (type == 'checklist') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BlushyColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Luteal Recovery Action Checklist',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _buildCheckItem('Log afternoon hydration intake', true),
            _buildCheckItem('calming breathing cycle (5 minutes)', false),
            _buildCheckItem('Plan light evening stretching routine', false),
          ],
        ),
      );
    }

    if (type == 'breathe') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BlushyColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6F42F5).withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Color(0xFF6F42F5), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calm Breathing Exercise',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6F42F5)),
                  ),
                  Text(
                    'Cycle-stabilizing parasympathetic booster • 5 min',
                    style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (type == 'community') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFADCDC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: BlushyColors.primary, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Community Insights: Fatigue',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: BlushyColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '4,281 women reported similar symptoms in their late luteal cycles. 78% found relief by increasing iron-rich nutrition.',
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.4),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCheckItem(String label, bool initialChecked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(
            initialChecked ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
            color: initialChecked ? BlushyColors.success : BlushyColors.secondaryText,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: initialChecked ? BlushyColors.secondaryText : BlushyColors.text,
                decoration: initialChecked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6F42F5)),
              ),
              const SizedBox(width: 10),
              Text(
                'Sia is thinking...',
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BlushyColors.border),
        boxShadow: const [
          BoxShadow(
            color: BlushyColors.shadow,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isListeningVoice) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(8, (index) {
                final randomHeight = 5.0 + math.Random().nextDouble() * 25.0;
                return AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    final heightFactor = math.sin(_waveController.value * 2.0 * math.pi + index) * 8.0;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 3,
                      height: (randomHeight + heightFactor).clamp(4.0, 32.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'Recording voice... 00:${_recordingSeconds.toString().padLeft(2, '0')} (Tap Mic to finish)',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)),
            ),
            const SizedBox(height: 8),
          ],
          
          Row(
            children: [
              GestureDetector(
                onTap: () {},
                child: const Icon(Icons.add_circle_outline_rounded, color: BlushyColors.secondaryText, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F7F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BlushyColors.border),
                  ),
                  child: TextField(
                    controller: _chatController,
                    style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text),
                    decoration: InputDecoration(
                      hintText: _placeholders[_placeholderIndex],
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: _sendUserMessage,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (_chatController.text.isNotEmpty) {
                    _sendUserMessage(_chatController.text);
                  } else {
                    _toggleVoiceRecording();
                  }
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6F42F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _chatController.text.isNotEmpty ? Icons.send_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SiaBreathingOrb extends StatefulWidget {
  const _SiaBreathingOrb();

  @override
  State<_SiaBreathingOrb> createState() => _SiaBreathingOrbState();
}

class _SiaBreathingOrbState extends State<_SiaBreathingOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.15);
        final opacity = 0.2 + (_controller.value * 0.3);
        return Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF8B5CF6).withOpacity(opacity),
                const Color(0xFFC084FC).withOpacity(0.0),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF8B5CF6), BlushyColors.secondary],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniWeeklySleepBarChart extends StatefulWidget {
  final String? sleepVal;
  const _MiniWeeklySleepBarChart({this.sleepVal});

  @override
  State<_MiniWeeklySleepBarChart> createState() => _MiniWeeklySleepBarChartState();
}

class _MiniWeeklySleepBarChartState extends State<_MiniWeeklySleepBarChart> {
  int? _selectedBarIndex;

  @override
  Widget build(BuildContext context) {
    final double loggedHours = widget.sleepVal != null
        ? (double.tryParse(widget.sleepVal!.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 7.5)
        : 7.5;

    final List<Map<String, dynamic>> days = [
      {'day': 'M', 'hours': 7.0, 'quality': 'Restful', 'isToday': false},
      {'day': 'T', 'hours': 7.5, 'quality': 'Deep', 'isToday': false},
      {'day': 'W', 'hours': 8.0, 'quality': 'Optimal', 'isToday': false},
      {'day': 'T', 'hours': 6.5, 'quality': 'Light', 'isToday': false},
      {'day': 'F', 'hours': 7.5, 'quality': 'Restful', 'isToday': false},
      {'day': 'S', 'hours': 8.5, 'quality': 'Deep', 'isToday': false},
      {'day': 'S', 'hours': loggedHours, 'quality': 'Recorded', 'isToday': true},
    ];

    double totalHours = 0;
    for (var d in days) {
      totalHours += (d['hours'] as num).toDouble();
    }
    final double avgHours = totalHours / days.length;
    const double targetHours = 8.0;
    const double maxScale = 10.0;
    const double chartBarAreaHeight = 28.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3E4DD), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "WEEKLY SLEEP",
                style: GoogleFonts.poppins(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                "Avg ${avgHours.toStringAsFixed(1)}h",
                style: GoogleFonts.poppins(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Main Bar Graph Canvas
          SizedBox(
            height: chartBarAreaHeight + 28,
            child: Stack(
              children: [
                // Dashed 8h Target Line
                Positioned(
                  left: 0,
                  right: 0,
                  top: chartBarAreaHeight * (1.0 - (targetHours / maxScale)),
                  child: Row(
                    children: List.generate(
                      18,
                      (index) => Expanded(
                        child: Container(
                          height: 1,
                          color: (index % 2 == 0)
                              ? const Color(0xFF6F42F5).withOpacity(0.4)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bars Row
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: days.asMap().entries.map((entry) {
                      final int idx = entry.key;
                      final d = entry.value;
                      final double h = (d['hours'] as num).toDouble();
                      final bool isToday = d['isToday'] as bool;
                      final bool isSelected = _selectedBarIndex == idx;
                      final double barHeight = ((h / maxScale) * chartBarAreaHeight).clamp(10.0, chartBarAreaHeight);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedBarIndex = isSelected ? null : idx;
                          });
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Hours badge on top of bar
                            Text(
                              "${h.toStringAsFixed(1)}h",
                              style: GoogleFonts.poppins(
                                fontSize: 7.5,
                                fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.w500,
                                color: (isToday || isSelected) ? BlushyColors.primary : BlushyColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 1),

                            // Animated Bar Column
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isSelected ? 16 : 12,
                              height: barHeight,
                              decoration: BoxDecoration(
                                gradient: isToday
                                    ? const LinearGradient(
                                        colors: [Color(0xFF6F42F5), Color(0xFFF76B8A)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      )
                                    : LinearGradient(
                                        colors: isSelected
                                            ? [const Color(0xFFF76B8A), const Color(0xFFFFB3C6)]
                                            : [const Color(0xFFEADBCE), const Color(0xFFF3E4DD)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                boxShadow: isToday || isSelected
                                    ? [
                                        BoxShadow(
                                          color: BlushyColors.primary.withOpacity(0.3),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 1),

                            // Day Label below bar
                            Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: isToday
                                  ? const BoxDecoration(
                                      color: BlushyColors.primary,
                                      shape: BoxShape.circle,
                                    )
                                  : null,
                              child: Text(
                                d['day'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 7.5,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                                  color: isToday ? Colors.white : BlushyColors.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          if (_selectedBarIndex != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bedtime_rounded, size: 16, color: Color(0xFF6F42F5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${days[_selectedBarIndex!]['day']} Sleep: ${days[_selectedBarIndex!]['hours']} Hours • ${days[_selectedBarIndex!]['quality']}",
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
