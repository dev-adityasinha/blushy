import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../core/theme.dart' hide BlushyColors;
import '../../core/state.dart';
import '../sia/sia_screen.dart';
import '../journal/journal_screen.dart';

import '../../services/api_auth_service.dart';

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

class BlushyMStudioScreen extends StatefulWidget {
  const BlushyMStudioScreen({super.key});

  @override
  State<BlushyMStudioScreen> createState() => _BlushyMStudioScreenState();
}

class _BlushyMStudioScreenState extends State<BlushyMStudioScreen> with TickerProviderStateMixin {
  final ApiAuthService _authService = ApiAuthService();
  final GlobalKey<BlushyJournalScreenState> _embeddedJournalKey = GlobalKey<BlushyJournalScreenState>();
  // Tab index names
  final List<String> _tabs = [
    'Reflect',
    'Creative Journal',
    'Recovery',
    'Guided Calm',
    'Time Capsules',
    'AI Reflections',
    'Journey'
  ];
  int _selectedTabIndex = 0;

  // Active view states
  bool _isEditorOpen = false;
  String _activeJournalTemplate = 'Daily Reflection';
  String _editorTheme = 'Default'; // Default, Travel, Gratitude, Pink Self-Love
  bool _isDecorated = false;

  final TextEditingController _editorController = TextEditingController(
    text: "Walked along the botanical paths today. Felt extremely introspective and calm as my luteal cycle starts to set in. Focus is high."
  );

  // Voice recording modal simulation
  bool _isRecordingVoice = false;
  String _voiceTranscription = '';

  // Simulation variables for Recovery
  bool _recoveryRunning = false;
  int _recoveryPhase = 0;

  // Time capsules state variables
  String _capsuleRecipient = 'Future Me';
  String _capsuleDate = 'Six Months';
  final List<Map<String, String>> _capsules = [
    {'title': 'Letter to Future Me', 'sub': 'Sealed: Jun 14 • Deliver in 6 Months'},
    {'title': 'Birthday note to Daughter', 'sub': 'Sealed: Jun 10 • Deliver on Birthday'},
  ];

  // Daily AI Reflection letters state
  int _selectedLetterIdx = 0;
  bool _isGeneratingLetter = false;
  List<Map<String, dynamic>> _dailyLetters = [];

  void _initDailyLettersIfNeeded(String userName, String cyclePhase, int cycleDay) {
    if (_dailyLetters.isNotEmpty) return;

    _dailyLetters = [
      {
        'id': 'letter_today',
        'dateHeader': 'A DAILY LETTER FROM SIA • TODAY (8:00 AM IST)',
        'deliveryTime': 'Delivered today at 8:00 AM IST',
        'highlights': ['Sia Chat Summary', 'Journal Reflection', 'Cycle Wellness'],
        'body': 'Dear $userName,\n\nHere is your daily reflection letter compiled from yesterday\'s check-ins:\n\n💬 Conversation Summary: Yesterday during your chat with Sia, you discussed managing fatigue and rest during your $cyclePhase transition. You asked about gentle post-lunch walks and hydration.\n\n📝 Journal Reflection: You logged: "Had a peaceful walk after lunch. Felt very introspective and calm." Writing down your daily reflections is giving your mind space to settle.\n\n🌸 Cycle & Body Insight: You are on Day $cycleDay of your $cyclePhase. Your body is gently adjusting. Prioritising rest decreased stress factors by 14% compared to last cycle.\n\nKeep listening to your body today. I\'m always here whenever you want to talk.\n\nWarmly,\nSia ✨',
        'isToday': true,
      },
      {
        'id': 'letter_yesterday',
        'dateHeader': 'A DAILY LETTER FROM SIA • YESTERDAY (8:00 AM IST)',
        'deliveryTime': 'Delivered yesterday at 8:00 AM IST',
        'highlights': ['Sia Chat Summary', 'Sleep Recovery'],
        'body': 'Dear $userName,\n\nHere is your daily reflection letter based on your previous day:\n\n💬 Conversation Summary: You asked Sia about sleep quality and evening wind-down routines. We focused on reducing screen time 30 minutes before rest.\n\n📝 Journal Reflection: You recorded gentle stretches and evening calm routines. Your sleep metrics improved by 18% overnight.\n\n🌸 Cycle & Body Insight: Day ${cycleDay > 1 ? cycleDay - 1 : 1} of $cyclePhase. Nurturing your energy with steady hydration and quiet moments helps maintain balance.\n\nWarmly,\nSia ✨',
        'isToday': false,
      },
      {
        'id': 'letter_2days_ago',
        'dateHeader': 'A DAILY LETTER FROM SIA • 2 DAYS AGO (8:00 AM IST)',
        'deliveryTime': 'Delivered July 30 at 8:00 AM IST',
        'highlights': ['Movement Focus', 'Nutrition Check-in'],
        'body': 'Dear $userName,\n\nReflecting on your previous day\'s wellness journey:\n\n💬 Conversation Summary: You explored healthy meal ideas and light morning movement with Sia.\n\n📝 Journal Reflection: You noted positive mood indicators and steady focus throughout the day.\n\n🌸 Cycle & Body Insight: Day ${cycleDay > 2 ? cycleDay - 2 : 1} of $cyclePhase. Small daily routines create lasting harmony for your cycle health.\n\nWarmly,\nSia ✨',
        'isToday': false,
      },
    ];
  }

  void _generateFreshDailyLetter(String userName, String cyclePhase, int cycleDay) {
    setState(() {
      _isGeneratingLetter = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isGeneratingLetter = false;
        _dailyLetters[0] = {
          'id': 'letter_today_${DateTime.now().millisecondsSinceEpoch}',
          'dateHeader': 'A DAILY LETTER FROM SIA • TODAY (8:00 AM IST)',
          'deliveryTime': 'Delivered today at 8:00 AM IST (Refreshed)',
          'highlights': ['Sia Chat Summary', 'Journal Reflection', 'Live Insights'],
          'body': 'Dear $userName,\n\nHere is your daily synthesized letter combining yesterday\'s Sia conversations and journal logs:\n\n💬 Sia Conversation Summary: You checked in regarding your body\'s natural rhythm during your $cyclePhase. You discussed light movement, stress relief, and hydration.\n\n📝 Journal Reflection: You logged: "Had a peaceful walk after lunch. Felt very introspective..." Your journal entries show steady emotional recovery and deeper self-awareness.\n\n🌸 Cycle & Body Guidance: You are currently on Day $cycleDay of your $cyclePhase. Rest factors are improving, and your body is in a gentle phase of recovery. Take time for a quiet walk or short reflection today.\n\nKeep listening to your body.\n\nWarmly,\nSia ✨',
          'isToday': true,
        };
        _selectedLetterIdx = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ Fresh Daily Reflection letter composed by Sia (Delivered at 8:00 AM IST)!"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  // Helper to determine the floating button label and icon based on selected tab
  String _getFloatingActionText() {
    switch (_tabs[_selectedTabIndex]) {
      case 'Reflect':
        return 'New Reflection';
      case 'Creative Journal':
        return 'New Journal';
      case 'Recovery':
        return 'Start Recovery';
      case 'Time Capsules':
        return 'New Capsule';
      case 'AI Reflections':
        return 'Generate Reflection';
      case 'Journey':
        return 'Add Memory';
      default:
        return 'Create';
    }
  }

  IconData _getFloatingActionIcon() {
    switch (_tabs[_selectedTabIndex]) {
      case 'Reflect':
        return Icons.mic_rounded;
      case 'Creative Journal':
        return Icons.auto_stories_rounded;
      case 'Recovery':
        return Icons.spa_rounded;
      case 'Time Capsules':
        return Icons.hourglass_empty_rounded;
      case 'AI Reflections':
        return Icons.auto_awesome_rounded;
      case 'Journey':
        return Icons.add_rounded;
      default:
        return Icons.add_rounded;
    }
  }

  void _onFloatingActionTap() {
    final currentTab = _tabs[_selectedTabIndex];
    if (currentTab == 'Reflect') {
      _startVoiceRecordingFlow();
    } else if (currentTab == 'Creative Journal') {
      _embeddedJournalKey.currentState?.openNewEntryBottomSheet();
    } else if (currentTab == 'Recovery') {
      _startRecoveryFlow();
    } else if (currentTab == 'Time Capsules') {
      _showCreateCapsuleDialog();
    } else if (currentTab == 'AI Reflections') {
      final state = BlushyOSProvider.of(context);
      final String userName = (state.personalContext.userName != null && state.personalContext.userName!.isNotEmpty)
          ? state.personalContext.userName!
          : "there";
      final String cyclePhase = state.personalContext.cyclePhase ?? "Luteal Phase";
      final int cycleDay = state.personalContext.cycleDay ?? 18;
      _generateFreshDailyLetter(userName, cyclePhase, cycleDay);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Starting ${currentTab} creation...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditorOpen) {
      return _buildJournalEditor();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0), // Handcrafted cream paper background
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. EDITORIAL HEADER & AI CONTEXT MESSAGE
                _buildHeader(),

                // 2. HORIZONTAL TAB NAVIGATION (Pill capsules list)
                _buildHorizontalTabNavigation(),

                // 3. MAIN WORKSPACE CONTAINER (Morphing view switcher)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: BlushyTheme.getPagePadding(context), vertical: 16.0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: child,
                      ),
                      child: _buildWorkspaceTabContent(),
                    ),
                  ),
                ),
              ],
            ),

            // 4. FLOATING ADAPTIVE ACTION BUTTON
            _buildAdaptiveFloatingActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final state = BlushyOSProvider.of(context);
    final String userName = (state.personalContext.userName != null && state.personalContext.userName!.isNotEmpty)
        ? state.personalContext.userName!
        : "there";

    // Dynamic context message based on selected tab
    String contextMsg = "Your next Time Capsule arrives in 12 days.";
    if (_selectedTabIndex == 0) contextMsg = "You've written four reflections this week.";
    if (_selectedTabIndex == 2) contextMsg = "You completed two recovery sessions yesterday.";
    if (_selectedTabIndex == 5) contextMsg = "Sia generated a new Weekly Review for you.";

    final bool canPop = Navigator.canPop(context);

    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
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
          Text(
            '${_getTimeBasedGreetingPrefix()}, $userName',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            contextMsg,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: BlushyColors.secondaryText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalTabNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BlushyColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final active = _selectedTabIndex == index;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              child: Container(
                margin: EdgeInsets.only(left: index == 0 ? 24 : 8, right: index == _tabs.length - 1 ? 24 : 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? BlushyColors.text : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? BlushyColors.text : BlushyColors.border,
                  ),
                ),
                child: Text(
                  _tabs[index],
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : BlushyColors.secondaryText,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildWorkspaceTabContent() {
    switch (_tabs[_selectedTabIndex]) {
      case 'Reflect':
        return _buildReflectTab();
      case 'Creative Journal':
        return _buildCreativeJournalTab();
      case 'Recovery':
        return _buildRecoveryTab();
      case 'Guided Calm':
        return _buildGuidedCalmTab();
      case 'Time Capsules':
        return _buildTimeCapsulesTab();
      case 'AI Reflections':
        return _buildAIReflectionsTab();
      case 'Journey':
        return _buildJourneyTab();
      default:
        return _buildReflectTab();
    }
  }

  // --- TAB 1: REFLECT ---
  Widget _buildReflectTab() {
    return Column(
      key: const ValueKey('reflect_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWorkspaceActionCard(
          title: 'Continue Yesterday',
          sub: '“Had a peaceful walk after lunch. Felt very introspective...”',
          icon: Icons.history_rounded,
          onTap: () {
            setState(() {
              _activeJournalTemplate = 'Daily Reflection';
              _isEditorOpen = true;
            });
          },
        ),
        const SizedBox(height: 16),
        
        Text(
          'SUGGESTED PROMPTS',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: BlushyColors.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        _buildPromptRow('What did your body need today that it didn\'t get?'),
        _buildPromptRow('Describe a moment of calm during your luteal phase today.'),
        
        const SizedBox(height: 20),
        Text(
          'TODAY\'S AI REFLECTION',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: BlushyColors.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border),
          ),
          child: Text(
            'Your logs indicate a 15% increase in rest cycles. Estrogen levels are stabilizing.',
            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: BlushyColors.warning, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: CREATIVE JOURNAL ---
  Widget _buildCreativeJournalTab() {
    return Column(
      key: const ValueKey('creative_journal_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 650,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BlushyJournalScreen(
              key: _embeddedJournalKey,
              isEmbedded: true,
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 3: RECOVERY ---
  Widget _buildRecoveryTab() {
    return Column(
      key: const ValueKey('recovery_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recovery score box
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFCEFF0),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF9D6D8)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECOVERY SCORE',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.primary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Optimal Calm State',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                '84%',
                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w600, color: BlushyColors.primary, height: 1.1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_recoveryRunning) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BlushyColors.border),
            ),
            child: Column(
              children: [
                if (_recoveryPhase == 0) ...[
                  const CircularProgressIndicator(color: BlushyColors.primary),
                  const SizedBox(height: 12),
                  Text('Enabling Do Not Disturb...', style: GoogleFonts.poppins(fontSize: 12)),
                ] else if (_recoveryPhase == 1) ...[
                  const Icon(Icons.music_note_rounded, color: BlushyColors.success, size: 28),
                  const SizedBox(height: 12),
                  Text('Connecting spotify calm loops playlist...', style: GoogleFonts.poppins(fontSize: 12)),
                ] else ...[
                  Text(
                    '“You are stronger than this temporary wave.”',
                    style: GoogleFonts.poppins(fontSize: 16, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => setState(() => _recoveryRunning = false),
                    child: const Text('Complete Session'),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          _buildWorkspaceActionCard(
            title: 'Start Recovery Mode',
            sub: 'One-tap guided breathing, DND trigger, and Spotify music sync.',
            icon: Icons.spa_rounded,
            onTap: _startRecoveryFlow,
          ),
        ],
      ],
    );
  }

  void _startRecoveryFlow() {
    setState(() {
      _recoveryRunning = true;
      _recoveryPhase = 0;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _recoveryPhase = 1);
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _recoveryPhase = 2);
    });
  }

  // --- TAB 4: GUIDED CALM ---
  Widget _buildGuidedCalmTab() {
    return Column(
      key: const ValueKey('guided_calm_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECOMMENDED FOR YOU',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: BlushyColors.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 14),
        _buildWorkspaceActionCard(
          title: 'Period Pain Relief Meditation',
          sub: 'Coping strategies & muscle relaxation logs • 12 min',
          icon: Icons.self_improvement_rounded,
          onTap: () {},
        ),
        const SizedBox(height: 12),
        _buildWorkspaceActionCard(
          title: 'Luteal Phase Anxiety Breathing',
          sub: 'Parasympathetic booster • 8 min',
          icon: Icons.air_rounded,
          onTap: () {},
        ),
      ],
    );
  }

  // --- TAB 5: TIME CAPSULES ---
  Widget _buildTimeCapsulesTab() {
    return Column(
      key: const ValueKey('time_capsules_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWorkspaceActionCard(
          title: 'Create New Capsule',
          sub: 'Seal letters, voice recordings, or photos for the future.',
          icon: Icons.hourglass_top_rounded,
          onTap: _showCreateCapsuleDialog,
        ),
        const SizedBox(height: 24),
        Text(
          'ACTIVE SEALED CAPSULES',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: BlushyColors.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: _capsules.map((cap) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: BlushyColors.primary, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cap['title'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          cap['sub'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showCreateCapsuleDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'New Time Capsule',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _capsuleRecipient,
                    decoration: const InputDecoration(labelText: 'Recipient'),
                    items: ['Future Me', 'Partner', 'Family'].map((r) {
                      return DropdownMenuItem(value: r, child: Text(r));
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        _capsuleRecipient = val ?? 'Future Me';
                      });
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: _capsuleDate,
                    decoration: const InputDecoration(labelText: 'Delivery Options'),
                    items: ['One Month', 'Six Months', 'One Year'].map((r) {
                      return DropdownMenuItem(value: r, child: Text(r));
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        _capsuleDate = val ?? 'Six Months';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _capsules.add({
                        'title': 'Letter to $_capsuleRecipient',
                        'sub': 'Sealed: Today • Deliver in $_capsuleDate'
                      });
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Time Capsule sealed! You left something for yourself.')),
                    );
                  },
                  child: const Text('Seal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- TAB 6: AI REFLECTIONS ---
  Widget _buildAIReflectionsTab() {
    final state = BlushyOSProvider.of(context);
    final String userName = (state.personalContext.userName != null && state.personalContext.userName!.isNotEmpty)
        ? state.personalContext.userName!
        : "there";
    final String cyclePhase = state.personalContext.cyclePhase ?? "Luteal Phase";
    final int cycleDay = state.personalContext.cycleDay ?? 18;

    _initDailyLettersIfNeeded(userName, cyclePhase, cycleDay);
    final activeLetter = _dailyLetters[_selectedLetterIdx];

    return Column(
      key: const ValueKey('ai_reflections_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Delivery Schedule Info Card (8:00 AM IST)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BlushyColors.border.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFECE8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_rounded, color: BlushyColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY REFLECTION LETTER • 8:00 AM IST',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Delivered every morning at 8:00 AM IST combining yesterday\'s Sia chat summaries & journal logs.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: BlushyColors.secondaryText,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Featured Daily Letter Display Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF6F0),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlushyColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isGeneratingLetter
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: BlushyColors.primary, strokeWidth: 2.5),
                      const SizedBox(height: 16),
                      Text(
                        'Sia is reading yesterday\'s chats & journal entries to compose your letter...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Tags & Delivery Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: BlushyColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              activeLetter['dateHeader'] ?? 'A LETTER FROM SIA',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: BlushyColors.primary,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: BlushyColors.border),
                          ),
                          child: Text(
                            '8:00 AM IST',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: BlushyColors.secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Highlights Pills
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (activeLetter['highlights'] as List<dynamic>? ?? []).map((h) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4ECE4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '✨ $h',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: BlushyColors.text,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Body Content
                    Text(
                      activeLetter['body'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        height: 1.6,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: BlushyColors.border, height: 1),
                    const SizedBox(height: 16),

                    // Action Buttons Row
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _generateFreshDailyLetter(userName, cyclePhase, cycleDay),
                          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: const Text('Refresh Letter'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BlushyColors.primary,
                            side: const BorderSide(color: BlushyColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BlushySiaScreen(
                                  initialQuestion: "Sia, let's talk about today's daily reflection letter and yesterday's check-ins.",
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                          label: const Text('Discuss with Sia'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BlushyColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("📌 Daily Reflection letter saved to your Scrapbook!"),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.bookmark_border_rounded, size: 16, color: BlushyColors.secondaryText),
                          label: Text(
                            'Save to Scrapbook',
                            style: GoogleFonts.poppins(color: BlushyColors.secondaryText, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),

        // 3. Previous Daily Letters Archive Timeline
        Text(
          'PREVIOUS DAILY LETTERS (8:00 AM IST)',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: BlushyColors.secondaryText,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: _dailyLetters.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isSelected = idx == _selectedLetterIdx;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedLetterIdx = idx;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFAF0EA) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? BlushyColors.primary : BlushyColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? BlushyColors.primary : const Color(0xFFF4ECE4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected ? Icons.mark_email_read_rounded : Icons.mail_outline_rounded,
                          color: isSelected ? Colors.white : BlushyColors.secondaryText,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['dateHeader'] ?? 'Daily Letter',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? BlushyColors.primary : BlushyColors.text,
                                  ),
                                ),
                                Text(
                                  '8:00 AM IST',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: BlushyColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['deliveryTime'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: BlushyColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                        color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- TAB 7: JOURNEY ---
  Widget _buildJourneyTab() {
    return Column(
      key: const ValueKey('journey_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineEvent('TODAY', 'Voice reflection entry logged. Emotional fatigue reset.', Icons.mic_rounded),
        _buildTimelineEvent('YESTERDAY', 'Completed Guided Calm pain relief cycle.', Icons.self_improvement_rounded),
        _buildTimelineEvent('JUNE 12', 'Sealed a Time Capsule to Future Me.', Icons.hourglass_top_rounded),
      ],
    );
  }

  Widget _buildTimelineEvent(String date, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: BlushyColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: BlushyColors.secondaryText),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceActionCard({
    required String title,
    required String sub,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BlushyColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BlushyColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: BlushyColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptiveFloatingActionButton() {
    return Positioned(
      bottom: 24,
      right: 24,
      child: FloatingActionButton.extended(
        heroTag: 'm_studio_fab',
        backgroundColor: BlushyColors.dark,
        onPressed: _onFloatingActionTap,
        label: Text(
          _getFloatingActionText(),
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        icon: Icon(_getFloatingActionIcon(), color: Colors.white, size: 16),
      ),
    );
  }

  // --- VOICE RECORDING SIMULATION PIPELINE ---
  void _startVoiceRecordingFlow() {
    setState(() {
      _isRecordingVoice = true;
      _voiceTranscription = 'Listening to your voice...';
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Voice Reflection', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const CircularProgressIndicator(color: BlushyColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    _voiceTranscription,
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isRecordingVoice = false;
                      _editorController.text = "“I spent some time listening to nature today and felt extremely content.”";
                      _activeJournalTemplate = 'Daily Reflection';
                      _isEditorOpen = true;
                    });
                  },
                  child: const Text('Stop & Format'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FREE-FORM JOURNAL CANVAS EDITOR ---
  Widget _buildJournalEditor() {
    Color paperColor = const Color(0xFFFAF6F0);
    if (_editorTheme == 'Gratitude') paperColor = const Color(0xFFFFFDF9);
    if (_editorTheme == 'Pink Self-Love') paperColor = const Color(0xFFFFF0F2);
    if (_editorTheme == 'Travel') paperColor = const Color(0xFFF5EFE6);

    return Scaffold(
      backgroundColor: paperColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: BlushyColors.dark),
          onPressed: () => setState(() => _isEditorOpen = false),
        ),
        title: Text(
          _activeJournalTemplate,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Journal keepsake saved!')),
              );
              setState(() => _isEditorOpen = false);
            },
            child: Text(
              'Save',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: BlushyColors.primary),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isDecorated) ...[
                    if (_editorTheme == 'Travel') _buildTravelDecorations(),
                    if (_editorTheme == 'Gratitude') _buildGratitudeDecorations(),
                    if (_editorTheme == 'Pink Self-Love') _buildSelfLoveDecorations(),
                  ],
                  TextField(
                    controller: _editorController,
                    maxLines: null,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: BlushyColors.text,
                      height: 1.6,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Start writing or speak your thoughts...',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Editor Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: BlushyColors.border)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isDecorated = true;
                      _editorTheme = _activeJournalTemplate == 'Gratitude' ? 'Gratitude' : 'Travel';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F42F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          'AI Decorate',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.text_fields_rounded, color: BlushyColors.disabled),
                const SizedBox(width: 16),
                const Icon(Icons.photo_outlined, color: BlushyColors.disabled),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelDecorations() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8DCC4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('️ Paris Stamp', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD3E4CD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(' Beach Sticker', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildGratitudeDecorations() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFBE7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BlushyColors.secondary),
            ),
            child: Text(
              ' Floral Divider',
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: BlushyColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfLoveDecorations() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(' Self Love Sticker', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: BlushyColors.primary)),
          ),
        ],
      ),
    );
  }
}
