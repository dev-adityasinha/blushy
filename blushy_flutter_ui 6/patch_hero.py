import sys

with open('/Users/niyu/Downloads/blushy_flutter_ui/lib/hero_redesign.dart', 'r') as f:
    lines = f.readlines()

new_content = []
for line in lines:
    if line.startswith("import 'main.dart';"):
        new_content.append("import 'main.dart';\nimport 'blushy_design_system.dart';\nimport 'blushy_screens.dart';\n")
    elif line.startswith("class RedesignedHeroSection extends StatefulWidget {"):
        break
    else:
        new_content.append(line)

new_content.append("""class RedesignedHeroSection extends StatefulWidget {
  final ScrollController sc;
  const RedesignedHeroSection({super.key, required this.sc});
  @override
  State<RedesignedHeroSection> createState() => _RedesignedHeroSectionState();
}

class _RedesignedHeroSectionState extends State<RedesignedHeroSection> with TickerProviderStateMixin {
  late AnimationController _timerCtrl;
  late AnimationController _floatCtrl;
  
  int _currentIndex = 0;
  int _displayIndex = 0;

  final List<Map<String, dynamic>> _states = [
    {
      'head': 'More than period tracking.',
      'desc': 'Cycle intelligence that connects your physical symptoms to your hormonal phases.',
      'cardTitle': 'Cycle Intelligence',
      'cardDesc': 'Predict patterns,\\nnot just periods.',
    },
    {
      'head': 'Built around your hormones.',
      'desc': 'Deeply integrated hormonal insights that adapt to your unique daily fluctuations.',
      'cardTitle': 'Hormonal Insights',
      'cardDesc': 'Follicular Phase\\nEnergy ↑ Focus ↑',
    },
    {
      'head': 'Understand your moods.',
      'desc': 'Track your emotions and let Blushy find the patterns you might have missed.',
      'cardTitle': 'Mood Tracking',
      'cardDesc': 'Pattern Detected\\nMood follows energy.',
    },
    {
      'head': 'Speak instead of typing.',
      'desc': 'Voice journaling processes your emotions and provides judgment-free reflections.',
      'cardTitle': 'Voice Journal',
      'cardDesc': 'Speak naturally.\\nWe\\'ll organize your thoughts.',
    },
    {
      'head': 'Your AI companion.',
      'desc': 'Always there to listen, reflect, and guide you through your cycle.',
      'cardTitle': 'AI Companion',
      'cardDesc': 'Judgment-free.\\nAlways available.',
    },
    {
      'head': 'Bring your partner closer.',
      'desc': 'Partner Mode gently guides your significant other on how to best support you.',
      'cardTitle': 'Partner Mode',
      'cardDesc': 'Helping partners\\nunderstand, not guess.',
    },
    {
      'head': 'Share meaningful moments.',
      'desc': 'Exchange handwritten notes and deepen your connection, even when apart.',
      'cardTitle': 'Shared Letters',
      'cardDesc': 'Meaningful connection.\\nShared daily.',
    },
    {
      'head': 'Celebrate the little things.',
      'desc': 'Send and receive virtual bouquets to show appreciation and love.',
      'cardTitle': 'Virtual Bouquet',
      'cardDesc': 'Little moments.\\nBig impact.',
    },
    {
      'head': 'Daily hormonal guidance.',
      'desc': 'Small, actionable recommendations to make the most of your day.',
      'cardTitle': 'Hormonal Guidance',
      'cardDesc': 'Small guidance.\\nEvery day.',
    },
    {
      'head': 'Everything begins with understanding.',
      'desc': 'Blushy is the first platform designed for your complete hormonal health.',
      'cardTitle': 'The Complete Picture',
      'cardDesc': 'Your cycle,\\nfinally understood.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    
    _timerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _timerCtrl.addListener(() {
      if (_timerCtrl.value >= 0.12 && _displayIndex != _currentIndex) {
        setState(() {
          _displayIndex = _currentIndex;
        });
      }
    });
    _timerCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentIndex = (_currentIndex + 1) % 10;
        _timerCtrl.forward(from: 0.0);
      }
    });
    _timerCtrl.forward();
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  int _getActiveTab(int index) {
    if (index == 0 || index == 1) return 0; 
    if (index == 2 || index == 3) return 1; 
    if (index == 4) return 2; 
    if (index == 5 || index == 6 || index == 7) return 3; 
    if (index == 8) return 0; 
    return 0;
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0: return const ScreenWelcome();
      case 1: return const ScreenCycle();
      case 2: return const ScreenMood();
      case 3: return const ScreenVoice();
      case 4: return const ScreenAI();
      case 5: return const ScreenPartner();
      case 6: return const ScreenLetters();
      case 7: return const ScreenBouquet();
      case 8: return const ScreenGuidance();
      case 9: return const ScreenWelcome();
      default: return const ScreenWelcome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final isDesktop = sw > 850;

    return SizedBox(
      height: sh,
      width: sw,
      child: Container(
        color: BDColors.cream,
        child: Stack(
          children: [
            Positioned(
              top: sh/2 - 400,
              right: -100,
              child: Container(
                width: 800, height: 800,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: BDColors.orange.withOpacity(0.07), blurRadius: 200, spreadRadius: 100)]
                ),
              )
            ),
            if (isDesktop) Row(
              children: [
                Expanded(flex: 58, child: _buildStoryText(isDesktop)),
                Expanded(flex: 42, child: _buildPhone(sw, isDesktop)),
              ]
            ) else Column(
              children: [
                const SizedBox(height: 100),
                _buildStoryText(isDesktop),
                Expanded(child: _buildPhone(sw, isDesktop)),
              ]
            )
          ]
        )
      )
    );
  }

  Widget _buildStoryText(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.only(left: isDesktop ? 80 : 24, right: isDesktop ? 32 : 24),
      child: AnimatedBuilder(
        animation: _timerCtrl,
        builder: (context, child) {
          final double t = _timerCtrl.value;
          final bool isFadingOut = t < 0.12;

          double headlineOpacity = 1.0;
          double descOpacity = 1.0;
          double headlineSlide = 0.0;
          double descSlide = 0.0;

          if (isFadingOut) {
            double progress = t / 0.12;
            double fade = 1.0 - progress;
            headlineOpacity = fade;
            descOpacity = fade;
            headlineSlide = progress * -10;
            descSlide = progress * -10;
          } else {
            double headP = ((t - 0.24) / 0.16).clamp(0.0, 1.0);
            headP = Cubic(0.22, 1.0, 0.36, 1.0).transform(headP);
            headlineOpacity = headP;
            headlineSlide = 20 * (1.0 - headP);

            double descP = ((t - 0.40) / 0.10).clamp(0.0, 1.0);
            descP = Cubic(0.22, 1.0, 0.36, 1.0).transform(descP);
            descOpacity = descP;
            descSlide = 20 * (1.0 - descP);
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: headlineOpacity,
                child: Transform.translate(
                  offset: Offset(0, headlineSlide),
                  child: Text(_states[_displayIndex]['head'], style: T.d(isDesktop ? 56 : 40, c: C.ink, h: 1.1)),
                )
              ),
              Opacity(
                opacity: descOpacity,
                child: Transform.translate(
                  offset: Offset(0, descSlide),
                  child: Text(_states[_displayIndex]['desc'], style: T.d(isDesktop ? 56 : 40, c: C.ink.withOpacity(0.5), h: 1.1)),
                )
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(color: BDColors.ink, borderRadius: BorderRadius.circular(999)),
                    child: Text('Join Beta', style: T.b(14, c: BDColors.cream, w: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: BDColors.ink.withOpacity(0.15)), borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_outline, size: 18, color: BDColors.ink),
                        const SizedBox(width: 8),
                        Text('Watch How It Works', style: T.b(14, c: BDColors.ink, w: FontWeight.w600)),
                      ],
                    )
                  ),
                ]
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildPhone(double sw, bool isDesktop) {
    final double scale = isDesktop ? 0.95 : (sw / 450).clamp(0.5, 0.85);

    return Center(
      child: Transform.scale(
        scale: scale,
        child: AnimatedBuilder(
          animation: _floatCtrl,
          builder: (context, child) {
            final dy = math.sin(_floatCtrl.value * 2 * math.pi) * 12;
            return Transform.translate(
              offset: Offset(0, dy),
              child: child,
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 330, height: 330 * 19 / 9,
                margin: const EdgeInsets.only(right: 64),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(48),
                  boxShadow: [
                    BoxShadow(color: BDColors.ink.withOpacity(0.15), blurRadius: 100, spreadRadius: 0, offset: const Offset(0, 40)),
                  ],
                ),
              ),
              Container(
                width: 330,
                height: 330 * 19 / 9,
                margin: const EdgeInsets.only(right: 64),
                decoration: BoxDecoration(
                  color: BDColors.ink,
                  borderRadius: BorderRadius.circular(48),
                ),
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Container(
                    color: BDColors.cream,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            const SizedBox(height: 32),
                            const BlushyTopBar(),
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _timerCtrl,
                                builder: (context, child) {
                                  final double t = _timerCtrl.value;
                                  final bool isFadingOut = t < 0.12;

                                  double phoneOpacity = 1.0;
                                  double phoneSlide = 0.0;

                                  if (isFadingOut) {
                                    double progress = t / 0.12;
                                    double fade = 1.0 - progress;
                                    phoneOpacity = fade;
                                    phoneSlide = progress * -10;
                                  } else {
                                    double phoneP = ((t - 0.12) / 0.12).clamp(0.0, 1.0);
                                    phoneP = Cubic(0.22, 1.0, 0.36, 1.0).transform(phoneP);
                                    phoneOpacity = phoneP;
                                    phoneSlide = 20 * (1.0 - phoneP);
                                  }

                                  return Opacity(
                                    opacity: phoneOpacity,
                                    child: Transform.translate(
                                      offset: Offset(0, phoneSlide),
                                      child: KeyedSubtree(
                                        key: ValueKey(_displayIndex),
                                        child: _getScreen(_displayIndex),
                                      )
                                    )
                                  );
                                }
                              )
                            ),
                            BlushyBottomNav(activeIndex: _getActiveTab(_displayIndex)),
                          ]
                        ),
                        Positioned(top: 18, left: 24, child: Text('9:41', style: T.b(13, c: BDColors.ink, w: FontWeight.w600))),
                        Positioned(top: 12, left: 0, right: 0, child: Center(child: Container(width: 110, height: 30, decoration: BoxDecoration(color: BDColors.ink, borderRadius: BorderRadius.circular(20))))),
                      ]
                    )
                  )
                )
              ),
              AnimatedBuilder(
                animation: _timerCtrl,
                builder: (context, child) {
                  final double t = _timerCtrl.value;
                  final bool isFadingOut = t < 0.12;
                  
                  double cardOpacity = 1.0;
                  double cardSlide = 0.0;
                  
                  if (isFadingOut) {
                    double progress = t / 0.12;
                    double fade = 1.0 - progress;
                    cardOpacity = fade;
                    cardSlide = progress * -10;
                  } else {
                    double cardP = ((t - 0.40) / 0.10).clamp(0.0, 1.0);
                    cardP = Cubic(0.22, 1.0, 0.36, 1.0).transform(cardP);
                    cardOpacity = cardP;
                    cardSlide = 20 * (1.0 - cardP);
                  }
                  
                  double? left = _displayIndex % 2 == 0 ? -120 : null;
                  double? right = _displayIndex % 2 != 0 ? -20 : null;
                  double top = _displayIndex % 2 == 0 ? 120 : 250;
                  
                  return Positioned(
                    left: left, right: right, top: top,
                    child: Opacity(
                      opacity: cardOpacity,
                      child: Transform.translate(
                        offset: Offset(0, cardSlide),
                        child: _buildFloatingCard(_states[_displayIndex]['cardTitle'], _states[_displayIndex]['cardDesc'])
                      )
                    )
                  );
                }
              )
            ]
          ),
        )
      )
    );
  }

  Widget _buildFloatingCard(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BDColors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BDColors.white, width: 2),
        boxShadow: [BoxShadow(color: BDColors.ink.withOpacity(0.06), blurRadius: 30, spreadRadius: -5, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: T.e(c: BDColors.red)),
          const SizedBox(height: 8),
          Text(desc, style: T.b(14, c: BDColors.ink, w: FontWeight.w500, h: 1.5)),
        ]
      )
    );
  }
}
""")

with open('/Users/niyu/Downloads/blushy_flutter_ui/lib/hero_redesign.dart', 'w') as f:
    f.writelines(new_content)

