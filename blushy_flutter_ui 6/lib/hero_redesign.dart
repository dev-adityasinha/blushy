import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';
import 'blushy_design_system.dart';
import 'blushy_screens.dart';

void _navigateToBeta() async {
  const url = 'https://blushy.life/betaversion';
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

const _luxuryCurve = Cubic(0.22, 1.0, 0.36, 1.0);

class RedesignedHomePage extends StatefulWidget {
  const RedesignedHomePage({super.key});
  @override
  State<RedesignedHomePage> createState() => _RedesignedHomePageState();
}

class _RedesignedHomePageState extends State<RedesignedHomePage> {
  final _sc = ScrollController();
  final _keys = List.generate(9, (_) => GlobalKey());
  bool _isPhoneInteractive = false;
  
  void _go(int i) {
    final ctx = _keys[i].currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 1200), curve: _luxuryCurve);
  }
  
  @override
  void dispose() { _sc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.cream,
    body: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_isPhoneInteractive) {
          setState(() {
            _isPhoneInteractive = false;
          });
        }
      },
      child: Stack(children: [
        SingleChildScrollView(
          controller: _sc,
          physics: _isPhoneInteractive ? const NeverScrollableScrollPhysics() : null,
          child: Column(children: [
            KeyedSubtree(key: _keys[0], child: RedesignedHeroSection(
              sc: _sc,
              isPhoneInteractive: _isPhoneInteractive,
              onInteractiveChanged: (val) {
                setState(() {
                  _isPhoneInteractive = val;
                });
              },
            )),
            SocialProofBanner(sc: _sc),
            SizedBox(height: MediaQuery.of(context).size.width > 850 ? 72 : 12),
            KeyedSubtree(key: _keys[1], child: ProblemSection(sc: _sc)),
            KeyedSubtree(key: _keys[2], child: const PhilosophySection()),
            const SizedBox(height: 72),
            KeyedSubtree(key: _keys[3], child: const PlatformSection()),
            KeyedSubtree(key: _keys[4], child: const HowItWorksSection()),
            KeyedSubtree(key: _keys[5], child: const PrivacySection()),
            KeyedSubtree(key: _keys[6], child: const CommunitySection()),
            KeyedSubtree(key: _keys[7], child: const VisionSection()),
            KeyedSubtree(key: _keys[8], child: ContactSection(onBackToTop: () => _go(0))),
          ]),
        ),
        Positioned(top: 0, left: 0, right: 0, child: RedesignedNavBar(scrollController: _sc, sectionKeys: _keys)),
      ]),
    ),
  );
}

class RedesignedNavBar extends StatefulWidget {
  final ScrollController scrollController;
  final List<GlobalKey> sectionKeys;
  const RedesignedNavBar({super.key, required this.scrollController, required this.sectionKeys});
  @override
  State<RedesignedNavBar> createState() => _RedesignedNavBarState();
}

class _RedesignedNavBarState extends State<RedesignedNavBar> {
  bool _scrolled = false, _open = false;
  static const _items = [
    ['Our Philosophy', 2],
    ['Platform', 3],
    ['How It Works', 4],
    ['Privacy', 5],
    ['Community', 6],
    ['Vision', 7],
  ];

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }
  void _onScroll() {
    final s = widget.scrollController.offset > 10;
    if (s != _scrolled) setState(() => _scrolled = s);
  }
  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _scrollTo(int index) {
    final ctx = widget.sectionKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 1200), curve: _luxuryCurve);
    }
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;

    return Container(
      height: (_open && !isDesktop) ? MediaQuery.of(context).size.height : null,
      child: Stack(children: [
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: _luxuryCurve,
              height: 52,
              decoration: BoxDecoration(
                color: _scrolled ? C.cream.withOpacity(0.7) : Colors.transparent,
                border: Border(bottom: BorderSide(color: C.ink.withOpacity(0.05), width: 1)),
              ),
              alignment: Alignment.center,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1300),
                padding: EdgeInsets.symmetric(horizontal: width > 950 ? 60 : (width >= 600 ? 40 : 24)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  GestureDetector(onTap: () => _scrollTo(0), child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text('BLUSHY', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 4, color: C.red)),
                    Text('.', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: C.orange)),
                  ])),
                  if (isDesktop) Row(children: _items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () => _scrollTo(it[1] as int),
                      child: Text(it[0] as String, style: T.b(13, c: C.ink.withOpacity(0.8), w: FontWeight.w500)),
                    ),
                  )).toList()),
                  Row(children: [
                    GestureDetector(
                      onTap: _navigateToBeta,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(999)),
                        child: Text('Join Beta', style: T.b(12, c: C.cream, w: FontWeight.w600)),
                      ),
                    ),
                    if (!isDesktop) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() => _open = true),
                        child: const Icon(Icons.menu, size: 24, color: C.ink),
                      ),
                    ],
                  ]),
                ]),
              ),
            ),
          ),
        ),
        if (_open && !isDesktop) Positioned.fill(child: Container(
          color: C.ink, padding: const EdgeInsets.all(28),
          child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text('BLUSHY', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4, color: C.red)),
                    Text('.', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: C.orange)),
                  ]),
              GestureDetector(onTap: () => setState(() => _open = false), child: const Icon(Icons.close, color: C.cream, size: 28)),
            ]),
            const SizedBox(height: 52),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: _items.map((item) =>
              GestureDetector(
                onTap: () {
                  setState(() => _open = false);
                  _scrollTo(item[1] as int);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Text(item[0] as String, style: T.d(36, c: C.cream)),
                    ],
                  ),
              ))).toList())),
          ])),
        )),
      ]),
    );
  }
}

class RedesignedHeroSection extends StatefulWidget {
  final ScrollController sc;
  final bool isPhoneInteractive;
  final ValueChanged<bool> onInteractiveChanged;
  const RedesignedHeroSection({
    super.key,
    required this.sc,
    required this.isPhoneInteractive,
    required this.onInteractiveChanged,
  });
  @override
  State<RedesignedHeroSection> createState() => _RedesignedHeroSectionState();
}

class _RedesignedHeroSectionState extends State<RedesignedHeroSection> with TickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late AnimationController _tapDemoCtrl;
  int _currentIndex = 0;
  bool _hasTappedThisLoop = false;

  final List<Map<String, dynamic>> _states = [
    {
      'head': 'More than period tracking.',
      'desc': 'A daily wellness hub designed to map your body\'s natural daily cycle.',
      'cardTitle': 'Daily Hub',
      'cardDesc': 'A complete picture\nof your health.',
    },
    {
      'head': 'A safe, anonymous space.',
      'desc': 'Share questions, stories, and guidance in a supportive, multilingual community.',
      'cardTitle': 'Community',
      'cardDesc': 'Real stories,\nshared experiences.',
    },
    {
      'head': 'Meet Sia, your wellness guide.',
      'desc': 'Ask questions, get phase aware guidance, and access doctor reviewed resources.',
      'cardTitle': 'Sia',
      'cardDesc': 'Always listening.\nAlways supportive.',
    },
    {
      'head': 'Your private digital diary.',
      'desc': 'Express yourself with voice or text journals, mood tracking, and creative scrapbook stickers.',
      'cardTitle': 'Digital Journal',
      'cardDesc': 'A beautiful space\nfor self-reflection.',
    },
    {
      'head': 'Bring your partner closer.',
      'desc': 'Foster empathy. Share letters, bouquets, and cycle status in Taara\'s shared workspace view.',
      'cardTitle': 'Partner Space',
      'cardDesc': 'Shared insights,\ncomplete privacy.',
    },
    {
      'head': 'Built for every woman in India.',
      'desc': 'Switch between 10+ regional languages. Localize wellness guidance and educational content instantly.',
      'cardTitle': 'Multilingual Support',
      'cardDesc': 'Fluency in English,\nHindi, Telugu and more.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _tapDemoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _tapDemoCtrl.addListener(() {
      if (!widget.isPhoneInteractive) {
        final double val = _tapDemoCtrl.value;
        if (val >= 0.45 && val < 0.50 && !_hasTappedThisLoop) {
          _hasTappedThisLoop = true;
          setState(() {
            _currentIndex = (_currentIndex + 1) % _states.length;
          });
        }
        if (val < 0.1) {
          _hasTappedThisLoop = false;
        }
      }
    });
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _tapDemoCtrl.dispose();
    super.dispose();
  }

  int _getActiveTab(int index) {
    if (index == 0) return 0; // Home
    if (index == 1) return 1; // Community
    if (index == 2) return 2; // Sia
    if (index == 3) return 3; // Journal
    if (index == 4) return 4; // Partner
    if (index == 5) return 0; // Settings
    return 0;
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return ScreenWelcome(
          onNavigate: (newIndex) {
            setState(() {
              _currentIndex = newIndex;
            });
          },
        );
      case 1: return const ScreenCommunity();
      case 2: return const ScreenAI(); // Sia
      case 3: return const ScreenVoice(); // Journal
      case 4: return const ScreenPartner(initialView: 0); // Partner
      case 5: return const ScreenIndia(); // Settings
      default:
        return ScreenWelcome(
          onNavigate: (newIndex) {
            setState(() {
              _currentIndex = newIndex;
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final isWide = sw >= 1024;

    return SizedBox(
      height: isWide ? sh : null,
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
              ),
            ),
            SafeArea(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1300),
                  padding: EdgeInsets.symmetric(horizontal: sw > 950 ? 60 : (sw >= 600 ? 40 : 24)),
                  child: isWide 
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _buildText(sw, isWide)),
                            SizedBox(width: sw >= 1200 ? 140 : 80),
                            _buildPhone(sw, isWide),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 84), // Spacing to avoid overlaying with the floating 52px nav bar
                              _buildText(sw, isWide),
                              const SizedBox(height: 24),
                              _buildPhone(sw, isWide),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildText(double sw, bool isWide) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero).animate(animation),
                child: child,
              ),
            );
          },
          child: Column(
            key: ValueKey<int>(_currentIndex),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_states[_currentIndex]['head'], style: T.d(isWide ? 58 : 34, c: BDColors.ink, h: 1.15)),
              const SizedBox(height: 16),
              Text(_states[_currentIndex]['desc'], style: T.d(isWide ? 22 : 17.5, c: BDColors.ink.withOpacity(0.55), h: 1.3)),
            ],
          ),
        ),
        const SizedBox(height: 36),
        Row(
          children: List.generate(_states.length, (index) {
            final bool isActive = index == _currentIndex;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _currentIndex = index;
                });
              },
              child: Container(
                width: 32, height: 12,
                margin: const EdgeInsets.only(right: 8),
                alignment: Alignment.center,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: isActive ? BDColors.red : BDColors.inkLight.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join our early access beta.', style: T.b(14.5, c: BDColors.inkLight)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _navigateToBeta,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(color: BDColors.ink, borderRadius: BorderRadius.circular(999)),
                        child: Text('Join Beta', style: T.b(12, c: BDColors.cream, w: FontWeight.w600)),
                      ),
                    ),
                  ],
                )
              ],
            )
          ],
        )
      ],
    );
  }

  Widget _buildPhone(double sw, bool isWide) {
    final double scale = isWide ? (sw >= 1200 ? 0.95 : 0.8) : (sw / 400).clamp(0.5, 0.85);

    Widget phoneBody = Padding(
      padding: EdgeInsets.only(top: isWide ? 40 : 0),
      child: AnimatedBuilder(
        animation: _floatCtrl,
        builder: (context, child) {
          final dy = math.sin(_floatCtrl.value * 2 * math.pi) * 12;
          return Transform.translate(
            offset: Offset(0, dy),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!widget.isPhoneInteractive) {
                  widget.onInteractiveChanged(true);
                }
              },
              child: IgnorePointer(
                ignoring: !widget.isPhoneInteractive,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 330, height: 330 * 19 / 9,
                      margin: EdgeInsets.only(right: isWide ? 64 : 0),
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
                      margin: EdgeInsets.only(right: isWide ? 64 : 0),
                      decoration: BoxDecoration(
                        color: BDColors.ink,
                        borderRadius: BorderRadius.circular(48),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: Navigator(
                          onGenerateRoute: (settings) => MaterialPageRoute(
                            builder: (context) => Container(
                              color: BDColors.cream,
                              child: Stack(
                                children: [
                                  Column(
                                    children: [
                                      const SizedBox(height: 32),
                                      BlushyTopBar(
                                        onTapLanguage: () {
                                          setState(() {
                                            _currentIndex = 5; // Settings / Multilingual screen
                                            widget.onInteractiveChanged(true); // make interactive if not already
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 300),
                                          child: KeyedSubtree(
                                            key: ValueKey<int>(_currentIndex),
                                            child: _getScreen(_currentIndex),
                                          ),
                                        ),
                                      ),
                                      BlushyBottomNav(
                                        activeIndex: _getActiveTab(_currentIndex),
                                        onTap: (tabIndex) {
                                          setState(() {
                                            _currentIndex = tabIndex;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  Positioned(top: 18, left: 24, child: Text('9:41', style: T.b(13, c: BDColors.ink, w: FontWeight.w600))),
                                  Positioned(top: 12, left: 0, right: 0, child: Center(child: Container(width: 110, height: 30, decoration: BoxDecoration(color: BDColors.ink, borderRadius: BorderRadius.circular(20))))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                      Positioned(
                        left: _currentIndex % 2 == 0 ? (isWide ? -120 : -20) : null,
                        right: _currentIndex % 2 != 0 ? (isWide ? -20 : -20) : null,
                        top: isWide ? (_currentIndex % 2 == 0 ? 120 : 250) : null,
                        bottom: isWide ? null : 160,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Container(
                            key: ValueKey<int>(_currentIndex),
                            child: _buildFloatingCard(_states[_currentIndex]['cardTitle'], _states[_currentIndex]['cardDesc']),
                          ),
                        ),
                      ),
                      if (!widget.isPhoneInteractive)
                        Positioned(
                          right: isWide ? 64 : 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: SizedBox(
                              width: 330,
                              height: 330 * 19 / 9,
                              child: AnimatedBuilder(
                                animation: _tapDemoCtrl,
                                builder: (context, child) {
                                  double progress = _tapDemoCtrl.value;

                                  // Target upcoming tab index
                                  int targetIndex = _currentIndex;
                                  if (progress < 0.45) {
                                    targetIndex = (_currentIndex + 1) % _states.length;
                                  }
                                  double targetX;
                                  double targetY;

                                  if (targetIndex == 5) {
                                    // Coordinates of the top bar English dropdown pill (adjusted for 12px outer bezel padding)
                                    targetX = 214.0;
                                    targetY = 76.0;
                                  } else {
                                    int targetTab = _getActiveTab(targetIndex);
                                    targetX = 36.0 + targetTab * 64.5;
                                    targetY = 660.0;
                                  }

                                  double slide = 0.0;
                                  double scale = 1.0;
                                  double opacity = 0.0;

                                  if (progress < 0.3) {
                                    double norm = progress / 0.3;
                                    slide = (1.0 - norm) * 40.0;
                                    opacity = norm * 0.55;
                                  } else if (progress >= 0.3 && progress < 0.75) {
                                    opacity = 0.55;
                                    if (progress >= 0.35 && progress < 0.45) {
                                      double norm = (progress - 0.35) / 0.10;
                                      scale = 1.0 - (norm * 0.15);
                                    } else if (progress >= 0.45 && progress < 0.55) {
                                      double norm = (progress - 0.45) / 0.10;
                                      scale = 0.85 + (norm * 0.15);
                                    }
                                  } else {
                                    double norm = (progress - 0.75) / 0.25;
                                    slide = norm * 40.0;
                                    opacity = (1.0 - norm) * 0.55;
                                  }

                                  double rippleVal = 0.0;
                                  if (progress >= 0.45 && progress < 0.75) {
                                    rippleVal = (progress - 0.45) / 0.30;
                                  }

                                  final double iconX = targetX + slide;
                                  final double iconY = targetY + slide;

                                  return Stack(
                                    children: [
                                      CustomPaint(
                                        size: Size.infinite,
                                        painter: _RipplePainter(
                                          progress: rippleVal,
                                          targetPoint: Offset(targetX, targetY),
                                        ),
                                      ),
                                      Positioned(
                                        left: iconX,
                                        top: iconY,
                                        child: Transform.scale(
                                          scale: scale,
                                          alignment: Alignment.topLeft,
                                          child: Opacity(
                                            opacity: opacity.clamp(0.0, 1.0),
                                            child: const Icon(
                                              Icons.touch_app_rounded,
                                              size: 45,
                                              color: Color(0xFF2B211C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Container(
              margin: EdgeInsets.only(right: isWide ? 64 : 0),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isPhoneInteractive) ...[
                    const Icon(
                      Icons.touch_app_rounded,
                      size: 14,
                      color: BDColors.red,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    widget.isPhoneInteractive 
                        ? "Active Mode • Click outside to exit" 
                        : "Tap anywhere to explore",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: widget.isPhoneInteractive ? BDColors.red : BDColors.ink.withOpacity(0.55),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isWide) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: 780.67 * scale,
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          child: phoneBody,
        ),
      );
    } else {
      final double phoneWidth = 330 * scale;
      final double phoneHeight = 750 * scale;
      return SizedBox(
        width: phoneWidth,
        height: phoneHeight,
        child: OverflowBox(
          maxWidth: 370,
          maxHeight: 750,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: scale,
            child: phoneBody,
          ),
        ),
      );
    }
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

class _RipplePainter extends CustomPainter {
  final double progress;
  final Offset targetPoint;
  _RipplePainter({required this.progress, required this.targetPoint});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final ripplePaint = Paint()
      ..color = const Color(0xFF2B211C).withOpacity(0.35 * (1.0 - progress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Primary circle
    canvas.drawCircle(targetPoint, progress * 30.0, ripplePaint);
    
    // Secondary concentric circle
    if (progress > 0.3) {
      double secProgress = (progress - 0.3) / 0.7;
      final secRipplePaint = Paint()
        ..color = const Color(0xFF2B211C).withOpacity(0.20 * (1.0 - secProgress))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(targetPoint, secProgress * 18.0, secRipplePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.targetPoint != targetPoint;
}
