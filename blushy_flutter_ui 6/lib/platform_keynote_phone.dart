import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'blushy_design_system.dart';
import 'main.dart';

class PlatformKeynotePhone extends StatelessWidget {
  final int activeIndex;

  const PlatformKeynotePhone({
    super.key,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw > Breakpoints.tablet;
    
    // Increased targetWidth to make the phone mockup larger and clearer
    final double targetWidth = isDesktop ? 315.0 : (330.0 * (sw / 380).clamp(0.65, 0.95));
    final double scale = targetWidth / 320.0;
    const double baseWidth = 320.0;
    const double baseHeight = baseWidth * 19 / 9;

    return Transform.scale(
      scale: scale,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Shadow casing
          Container(
            width: baseWidth,
            height: baseHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(48),
              boxShadow: [
                BoxShadow(
                  color: C.ink.withOpacity(0.25),
                  blurRadius: 80,
                  spreadRadius: 2,
                  offset: const Offset(0, 30),
                ),
              ],
            ),
          ),
          // Physical phone shell
          Container(
            width: baseWidth,
            height: baseHeight,
            decoration: BoxDecoration(
              color: C.ink,
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
              borderRadius: BorderRadius.circular(48),
            ),
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(38),
              child: Container(
                color: C.cream,
                child: Stack(
                  children: [
                    // Main App Shell
                    Column(
                      children: [
                        const SizedBox(height: 32),
                        const BlushyTopBar(),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.05),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                            child: KeyedSubtree(
                              key: ValueKey(activeIndex),
                              child: _getDemoScreen(activeIndex),
                            ),
                          ),
                        ),
                        BlushyBottomNav(activeIndex: activeIndex),
                      ],
                    ),
                    Positioned(
                      top: 14, left: 24,
                      child: Text("9:41", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: C.ink)),
                    ),
                    
                    // Device Top Island Notch
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 18,
                          decoration: BoxDecoration(
                            color: C.ink,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E293B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 24,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom Navigation Bar indicator
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 4,
                          decoration: BoxDecoration(
                            color: C.ink.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getDemoScreen(int index) {
    switch (index) {
      case 0:
        return const _DemoCycleIntelligence();
      case 1:
        return const _DemoCommunity();
      case 2:
        return const _DemoSiaAI();
      case 3:
        return const _DemoCreativeJournal();
      case 4:
        return const _DemoPartnerMode();
      case 5:
      default:
        return const _DemoBuiltForIndia();
    }
  }
}

// ────────────────────────────────────────────────────────
// 1. CYCLE INTELLIGENCE KEYNOTE DEMO (CINEMATIC PRESENTATION)
// ────────────────────────────────────────────────────────
class _DemoCycleIntelligence extends StatefulWidget {
  const _DemoCycleIntelligence();

  @override
  State<_DemoCycleIntelligence> createState() => _DemoCycleIntelligenceState();
}

class _DemoCycleIntelligenceState extends State<_DemoCycleIntelligence> {
  int _phaseIndex = 0;
  Timer? _timer;

  final List<Map<String, dynamic>> _phases = [
    {
      'name': 'Menstrual',
      'days': 'Day 1-5',
      'color': C.red,
      'energy': '20%',
      'mood': 'Reflective & Low Key',
      'workout': 'Gentle Recovery Yoga',
      'nutrition': 'Iron-rich Broths',
      'sleep': '9.0 Hrs (Deep Rest)',
      'aiMsg': 'Sia: Estrogen drop requires resting. Workouts should focus on recovery.',
    },
    {
      'name': 'Follicular',
      'days': 'Day 6-12',
      'color': C.pink,
      'energy': '65%',
      'mood': 'Creative & Confident',
      'workout': 'Moderate Cardio Run',
      'nutrition': 'Protein & Fresh Greens',
      'sleep': '7.5 Hrs (Fresh)',
      'aiMsg': 'Sia: Estrogen is rising. Your body is ready for higher intensity movement.',
    },
    {
      'name': 'Ovulation',
      'days': 'Day 13-16',
      'color': Color(0xFFFF4A00),
      'energy': '95%',
      'mood': 'Peak Confidence & Focus',
      'workout': 'High Intensity HIIT',
      'nutrition': 'Fiber & Hydration Boost',
      'sleep': '7.0 Hrs (Alert)',
      'aiMsg': 'Sia: LH hormone peak. You have maximum physical endurance today.',
    },
    {
      'name': 'Luteal',
      'days': 'Day 17-28',
      'color': C.orange,
      'energy': '40%',
      'mood': 'Mindful & Calming',
      'workout': 'Pilates & Stretches',
      'nutrition': 'Magnesium-rich Snacks',
      'sleep': '8.5 Hrs (Early Sleep)',
      'aiMsg': 'Sia: Progesterone is high. Calm your nervous system with mindful Pilates.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _phaseIndex = (_phaseIndex + 1) % _phases.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ph = _phases[_phaseIndex];
    final color = ph['color'] as Color;

    return Container(
      color: color.withOpacity(0.04), // Dynamic background wash
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator at the top
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              final isCurrent = index == _phaseIndex;
              final p = _phases[index];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent ? (p['color'] as Color).withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p['name'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? (p['color'] as Color) : C.ink.withOpacity(0.35),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Central Cinematic Showcase Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: color.withOpacity(0.15), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ph['days'] as String, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bolt, size: 10, color: color),
                            const SizedBox(width: 2),
                            Text("Energy ${ph['energy']}", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Phase title
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      "${ph['name']} Phase",
                      key: ValueKey(_phaseIndex),
                      style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: C.ink),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("Mood: ${ph['mood']}", style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: C.ink.withOpacity(0.6))),
                  
                  const SizedBox(height: 16),
                  Divider(color: color.withOpacity(0.1)),
                  const SizedBox(height: 12),

                  // Mini Keynote bullets (workout, nutrition, sleep)
                  _buildBulletRow(Icons.fitness_center, "WORKOUT", ph['workout'] as String, color),
                  const SizedBox(height: 10),
                  _buildBulletRow(Icons.restaurant, "NUTRITION", ph['nutrition'] as String, color),
                  const SizedBox(height: 10),
                  _buildBulletRow(Icons.hotel, "SLEEP PLAN", ph['sleep'] as String, color),

                  const Spacer(),

                  // AI Explanation block
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ph['aiMsg'] as String,
                            style: GoogleFonts.inter(fontSize: 9.5, color: C.ink, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.bold, color: C.ink.withOpacity(0.4))),
            Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: C.ink)),
          ],
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────
// 2. COMMUNITY KEYNOTE DEMO
// ────────────────────────────────────────────────────────
class _DemoCommunity extends StatefulWidget {
  const _DemoCommunity();

  @override
  State<_DemoCommunity> createState() => _DemoCommunityState();
}

class _DemoCommunityState extends State<_DemoCommunity> {
  int _animStep = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (mounted) {
        setState(() {
          if (_animStep < 3) {
            _animStep++;
          } else {
            if (timer.tick % 5 == 0) {
              _animStep = 0;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.pink.withOpacity(0.03),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("EXPERIENCE DEMO", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: C.pink)),
              const Spacer(),
              const Icon(Icons.lock, size: 8, color: C.pink),
              const SizedBox(width: 4),
              Text("Encrypted", style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: C.pink)),
            ],
          ),
          const SizedBox(height: 12),

          // Question Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.pink.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 6, backgroundColor: C.pink.withOpacity(0.2), child: const Text("T", style: TextStyle(fontSize: 7))),
                    const SizedBox(width: 6),
                    Text("Taara (Anonymous)", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: C.ink.withOpacity(0.5))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Why do I always feel exhausted before my period?",
                  style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.bold, color: C.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Populating Feed
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (_animStep >= 1)
                  _buildAnimatedItem(
                    child: _buildBubble(
                      name: "Maya S.",
                      text: "Same! Day 21-25 is always a total wipeout for me.",
                      isExpert: false,
                    ),
                  ),
                const SizedBox(height: 8),
                if (_animStep >= 2)
                  _buildAnimatedItem(
                    child: _buildBubble(
                      name: "Dr. Ananya • ObGyn",
                      text: "Pre-menstrual progesterone surge triggers melatonin drops, causing fatigue.",
                      isExpert: true,
                    ),
                  ),
                const SizedBox(height: 8),
                if (_animStep >= 3)
                  _buildAnimatedItem(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.orange, size: 12),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "AI Insight: Highlighted the medical consensus on fatigue cycles.",
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedItem({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (_, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: ch)),
      child: child,
    );
  }

  Widget _buildBubble({required String name, required String text, required bool isExpert}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isExpert ? const Color(0xFFFFF5F5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isExpert ? C.red.withOpacity(0.15) : C.ink.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.bold, color: C.ink)),
              if (isExpert) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(4)),
                  child: const Text("EXPERT OBGYN", style: TextStyle(fontSize: 6, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(text, style: GoogleFonts.inter(fontSize: 10, color: C.ink)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// 3. SIA COMPANION REASONING DEMO
// ────────────────────────────────────────────────────────
class _DemoSiaAI extends StatefulWidget {
  const _DemoSiaAI();

  @override
  State<_DemoSiaAI> createState() => _DemoSiaAIState();
}

class _DemoSiaAIState extends State<_DemoSiaAI> {
  int _state = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1600), (timer) {
      if (mounted) {
        setState(() {
          if (_state < 3) {
            _state++;
          } else {
            if (timer.tick % 6 == 0) {
              _state = 0;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.deepOrange.withOpacity(0.02),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("SIA REASONING CORE", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: C.orange)),
          const SizedBox(height: 12),

          // User message bubble
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: C.ink,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomLeft: Radius.circular(12)),
              ),
              child: Text("Why am I anxious today?", style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (_state >= 1 && _state < 3) ...[
                  Row(
                    children: [
                      const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(C.orange))),
                      const SizedBox(width: 6),
                      Text("Sia is reviewing medical inputs...", style: GoogleFonts.inter(fontSize: 9, color: C.orange, fontStyle: FontStyle.italic)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildReasonCheck("Cycle phase: Day 21 Luteal", _state >= 2),
                  _buildReasonCheck("Last night's sleep: 6.2 hours", _state >= 2),
                  _buildReasonCheck("Journal entry: Mood dip logged", _state >= 2),
                ],

                if (_state >= 3)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    builder: (_, v, ch) => Opacity(opacity: v, child: ch),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                        border: Border.all(color: C.orange.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 10, color: C.orange),
                              const SizedBox(width: 4),
                              Text("SIA COMPANION", style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: C.orange)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Progesterone rises during Luteal phase, naturally increasing sensitivity. Combined with 6.2 hrs of sleep, this triggers your cortisol spikes. Let's start a breathing timer.",
                            style: GoogleFonts.inter(fontSize: 10.5, color: C.ink, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCheck(String text, bool checked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked, size: 10, color: checked ? Colors.green : Colors.grey),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(fontSize: 9.5, color: C.ink.withOpacity(0.6))),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// 4. CREATIVE JOURNAL DEMO
// ────────────────────────────────────────────────────────
class _DemoCreativeJournal extends StatefulWidget {
  const _DemoCreativeJournal();

  @override
  State<_DemoCreativeJournal> createState() => _DemoCreativeJournalState();
}

class _DemoCreativeJournalState extends State<_DemoCreativeJournal> {
  int _state = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2400), (timer) {
      if (mounted) {
        setState(() {
          _state = (_state + 1) % 3;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.red.withOpacity(0.02),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("TRANSFORMATION LAB", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: C.red)),
              const Spacer(),
              Text(_state == 0 ? "Entry Draft" : (_state == 1 ? "Analyzing..." : "Analyzed Insights"), style: GoogleFonts.inter(fontSize: 8, color: C.red.withOpacity(0.5))),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildLayout(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayout() {
    if (_state == 0) {
      return Container(
        key: const ValueKey(0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.ink.withOpacity(0.04))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Daily Entry Logged:", style: GoogleFonts.inter(fontSize: 8, color: C.ink.withOpacity(0.4))),
            const SizedBox(height: 6),
            Text(
              "I cried during today's planning meeting. Everyone seemed so demanding. Feel so overwhelmed.",
              style: GoogleFonts.caveat(fontSize: 15, fontWeight: FontWeight.bold, color: C.ink),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.play_arrow, size: 12, color: C.red),
                const SizedBox(width: 4),
                Text("Voice memo attached (0:48)", style: GoogleFonts.inter(fontSize: 9, color: C.ink.withOpacity(0.5))),
              ],
            ),
          ],
        ),
      );
    } else if (_state == 1) {
      return Center(
        key: const ValueKey(1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(C.red))),
            const SizedBox(height: 12),
            Text("Extracting emotional & biological markers...", style: GoogleFonts.inter(fontSize: 9.5, color: C.ink.withOpacity(0.4))),
          ],
        ),
      );
    } else {
      return Container(
        key: const ValueKey(2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.red.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 10, color: C.red),
                const SizedBox(width: 4),
                Text("AI INSIGHTS REPORT", style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: C.red)),
              ],
            ),
            const SizedBox(height: 8),
            _insightRow("Emotion Match", "High Sensitivity"),
            _insightRow("Cycle Correlation", "Day 21 Luteal Phase"),
            const SizedBox(height: 8),
            Text(
              "Sia Insight: Estrogen drops reduce resilience to criticism today. Take a quick break and schedule hard calls for tomorrow.",
              style: GoogleFonts.inter(fontSize: 9, color: C.ink, height: 1.3),
            ),
          ],
        ),
      );
    }
  }

  Widget _insightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: C.ink.withOpacity(0.6))),
          Text(value, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: C.ink)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// 5. PARTNER EM PATHY DEMO
// ────────────────────────────────────────────────────────
class _DemoPartnerMode extends StatelessWidget {
  const _DemoPartnerMode();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.pink.withOpacity(0.02),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("PARTNER OVERVIEW", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: C.pink)),
              const Spacer(),
              Icon(Icons.lock, size: 9, color: Colors.green.shade400),
              const SizedBox(width: 2),
              Text("Shared Mode", style: GoogleFonts.inter(fontSize: 8, color: Colors.green.shade600, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          Text("Taara's Shared Spaces", style: GoogleFonts.playfairDisplay(fontSize: 15, fontWeight: FontWeight.bold, color: C.ink)),
          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _partnerCard("TODAY'S PACE", "She may prefer a slower pace this evening.", C.orange, Icons.spa),
                const SizedBox(height: 8),
                _partnerCard("SUGGESTED CHECK-IN", "Arrange dinner so she doesn't have to plan.", C.pink, Icons.favorite_border),
                const SizedBox(height: 8),
                _partnerCard("CARE SUGGESTION", "Bring her a warm water heating pad.", C.red, Icons.local_cafe),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnerCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.ink.withOpacity(0.03))),
      child: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 12, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.bold, color: color)),
                Text(value, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: C.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// 6. BUILT FOR INDIA KEYNOTE DEMO
// ────────────────────────────────────────────────────────
class _DemoBuiltForIndia extends StatelessWidget {
  const _DemoBuiltForIndia();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.yellow.withOpacity(0.02),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Finally, a women's health AI that speaks India.",
                  style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.bold, color: C.yellow),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: C.yellow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text("India First", style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.bold, color: C.yellow)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // User message bubble in Hinglish/Indian context
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: C.ink,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomLeft: Radius.circular(12)),
              ),
              child: Text(
                "Amma keeps saying I should avoid curd today. Is there actually any reason?",
                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // AI Response with Indian contextual advice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.yellow.withOpacity(0.25)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: C.yellow, size: 10),
                    const SizedBox(width: 4),
                    Text("SIA COMPANION", style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: C.yellow)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Your Amma isn't wrong for caring she's sharing what she's always believed. But medically, curd doesn't affect your period. If it feels comfortable for you, it's perfectly okay to have it. Tradition and evidence can coexist.",
                  style: GoogleFonts.inter(fontSize: 10.5, color: C.ink, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Language Pills
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text("Switch seamlessly:", style: GoogleFonts.inter(fontSize: 9, color: C.ink.withOpacity(0.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: C.ink.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "English • தமிழ் • हिन्दी",
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: C.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cultural chips grid
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip("Home Remedies", C.yellow),
              _chip("Indian Nutrition", C.yellow),
              _chip("Local Healthcare", C.yellow),
              _chip("Doctor-Reviewed", C.yellow),
            ],
          ),

          const Spacer(),
          // Position statement at the bottom
          Center(
            child: Text(
              "This wasn't translated for India. It was designed here.",
              style: GoogleFonts.playfairDisplay(fontSize: 11, fontWeight: FontWeight.bold, color: C.yellow, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.bold, color: C.ink),
      ),
    );
  }
}
