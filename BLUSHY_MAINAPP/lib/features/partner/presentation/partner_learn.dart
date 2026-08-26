import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';
import '../../../core/theme.dart' hide BlushyColors;
import '../../../services/api_partner_service.dart';

class PartnerLearnScreen extends StatefulWidget {
  const PartnerLearnScreen({super.key});

  @override
  State<PartnerLearnScreen> createState() => _PartnerLearnScreenState();
}

class _PartnerLearnScreenState extends State<PartnerLearnScreen> {
  final ApiPartnerService _partnerService = ApiPartnerService();
  bool _isLoading = true;
  bool _hasPartner = false;
  Map<String, dynamic>? _activeConnection;
  Map<String, dynamic>? _sharedData;

  Timer? _hourlyTimer;
  DateTime? _lastFetchTime;
  String? _lastStateHash;

  @override
  void initState() {
    super.initState();
    _fetchPartnerState();

    // Periodically check every 1 hour if partner state has changed
    _hourlyTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _checkAndRefreshHourly();
    });
  }

  @override
  void dispose() {
    _hourlyTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAndRefreshHourly() async {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastFetchTime == null || now.difference(_lastFetchTime!).inMinutes >= 60) {
      await _fetchPartnerState();
    }
  }

  Future<void> _fetchPartnerState() async {
    try {
      final connections = await _partnerService.getConnections();
      final active = connections.firstWhere(
        (c) => c['status'] == 'active',
        orElse: () => <String, dynamic>{},
      );

      if (active.isNotEmpty) {
        final connId = (active['connectionId'] ?? active['_id'] ?? '').toString();
        Map<String, dynamic> shared = {};
        if (connId.isNotEmpty) {
          shared = await _partnerService.getPartnerSharedData(connId);
        }

        final cycleInfo = shared['cycleInfo'];
        final moodData = shared['mood'];
        final partnerUser = shared['partnerUser'];
        final String newStateHash = "${cycleInfo?['phase']}_${cycleInfo?['currentCycleDay']}_${moodData?['mood']}_${partnerUser?['lifeStage']}";

        final now = DateTime.now();
        final bool shouldUpdate = _lastFetchTime == null ||
            now.difference(_lastFetchTime!).inMinutes >= 60 ||
            _lastStateHash != newStateHash;

        if (mounted) {
          if (shouldUpdate) {
            setState(() {
              _hasPartner = true;
              _activeConnection = active;
              _sharedData = shared;
              _isLoading = false;
              _lastStateHash = newStateHash;
              _lastFetchTime = now;
            });
          } else {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _hasPartner = false;
            _activeConnection = null;
            _sharedData = null;
            _isLoading = false;
            _lastStateHash = null;
            _lastFetchTime = DateTime.now();
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasPartner = false;
          _isLoading = false;
        });
      }
    }
  }

  void _showArticle(BuildContext context, String category, String title, String body, String action) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF6F0),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.toUpperCase(),
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.primary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    body,
                    style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.text, height: 1.6),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFEE8D6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Actionable Recommendation →",
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          action,
                          style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showConnectPartnerDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Connect with Partner', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pairing with your partner enables live AI insights, phase tracking, and support advice on the Learn page.',
              style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                hintText: "Partner's email address",
                prefixIcon: const Icon(Icons.email_outlined, color: BlushyColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: BlushyColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(context);
                final res = await _partnerService.invitePartnerByEmail(email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['error'] ?? 'Partner invite sent!'),
                      backgroundColor: res['error'] != null ? BlushyColors.primary : const Color(0xFF10B981),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BlushyColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Send Invite', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchPartnerState,
          color: BlushyColors.primary,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: BlushyColors.primary))
              : ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: BlushyTheme.getPagePadding(context),
                    vertical: 16.0,
                  ),
                  children: [
                    // Heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Learn & Discover",
                          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: BlushyColors.primary),
                          onPressed: _fetchPartnerState,
                          tooltip: 'Refresh Learn Page',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // IF NO PARTNER: Do not show partner-specific AI content or partner titles
                    if (!_hasPartner) ...[
                      _buildNoPartnerBanner(),
                      const SizedBox(height: 20),
                      _buildSectionTitle("General Health & Wellness"),
                      _buildArticleTile(
                        context: context,
                        category: "Wellness",
                        title: "Understanding Energy & Fatigue Shifts",
                        snippet: "How biological rhythms affect baseline energy.",
                        body: "Energy levels naturally fluctuate based on sleep quality, hydration, stress, and daily metabolic demands. Prioritizing consistent sleep schedules and balanced nutrition helps maintain steady focus throughout the week.",
                        action: "Maintain a steady daily sleep schedule and take micro-breaks during long work stretches.",
                      ),
                      _buildArticleTile(
                        context: context,
                        category: "Wellness",
                        title: "Mindful Communication Principles",
                        snippet: "Building empathetic conversations and active listening.",
                        body: "Empathetic communication begins with non-judgmental listening. When someone shares their day or frustration, validating their perspective before jumping to advice creates trust and psychological safety.",
                        action: "Practice reflective listening: summarize what you heard before responding.",
                      ),
                      _buildArticleTile(
                        context: context,
                        category: "Wellness",
                        title: "Daily Hydration & Metabolic Balance",
                        snippet: "Why water intake and electrolyte balance sustain daily mental focus.",
                        body: "Proper cellular hydration regulates cortisol levels, reduces afternoon brain fog, and stabilizes metabolic energy across long working hours.",
                        action: "Drink a glass of water every morning upon waking and keep a water bottle at your desk.",
                      ),

                      const SizedBox(height: 16),
                      _buildSectionTitle("Mind & Rest"),
                      _buildArticleTile(
                        context: context,
                        category: "Rest",
                        title: "Optimizing Rest & Recovery Baselines",
                        snippet: "Why passive downtime is essential for mental clarity.",
                        body: "Rest isn't just sleeping—it includes mental decompression, physical ease, and sensory calm. Incorporating quiet moments without digital screens helps lower cortisol and improves memory consolidation.",
                        action: "Set aside 15 minutes of screen-free downtime before bed each night.",
                      ),
                      _buildArticleTile(
                        context: context,
                        category: "Mind",
                        title: "Managing Stress & Daily Resilience",
                        snippet: "Practical techniques to regulate your nervous system.",
                        body: "Simple breathwork exercises, such as 4-7-8 breathing or box breathing, instantly signal safety to your central nervous system, helping de-escalate acute stress.",
                        action: "Try 3 minutes of slow box breathing whenever feeling overwhelmed.",
                      ),
                      _buildArticleTile(
                        context: context,
                        category: "Rest",
                        title: "Building Healthy Sleep Architecture",
                        snippet: "How regular sleep windows improve deep sleep cycles and morning energy.",
                        body: "Maintaining consistent sleep and wake times reinforces your circadian pacemaker, enhancing slow-wave REM sleep for cognitive recovery and mood stability.",
                        action: "Keep sleep and wake times consistent within 30 minutes every day of the week.",
                      ),
                    ]
                    // IF PARTNER IS CONNECTED: Show allowed partner AI insights and partner guidance
                    else ...[
                      _buildPartnerAiInsightsHeader(),
                      const SizedBox(height: 20),
                      ..._buildAllowedPartnerArticles(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildNoPartnerBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BlushyColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_border_rounded, size: 20, color: BlushyColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "No Partner Connected",
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    Text(
                      "Connect with your partner to unlock personalized Sia AI insights.",
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Pairing allows Sia to display partner support recommendations, phase awareness, and relationship care tips tailored to your partner.",
            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text.withOpacity(0.8), height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showConnectPartnerDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: Text(
                "Connect Partner",
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerAiInsightsHeader() {
    final permissions = _activeConnection?['permissions'] as Map<String, dynamic>? ?? {};
    final partnerUser = _sharedData?['partnerUser'];
    final cycleInfo = _sharedData?['cycleInfo'];
    final moodData = _sharedData?['mood'];

    final bool canShareCycle = permissions['shareCycle'] != false;
    final bool canShareMood = permissions['shareMood'] != false;

    String partnerName = _activeConnection?['partner']?['displayName'] ??
        _activeConnection?['partnerEmail'] ??
        (partnerUser?['display_name'] ?? partnerUser?['email'] ?? "Partner");
    if (partnerName.contains('@')) {
      partnerName = partnerName.split('@').first;
    }

    String siaHeadline = "Sia AI Partner Care Insights";
    String siaSubtext = "Live advice strictly respecting partner privacy permissions.";

    if (canShareCycle && cycleInfo != null && cycleInfo['phase'] != null) {
      final phase = cycleInfo['phase'];
      final day = cycleInfo['currentCycleDay'];
      siaHeadline = "$partnerName is on Day ${day ?? ''} ($phase Phase)";
      siaSubtext = "Hormones adjust energy levels during this phase.";
    } else if (canShareMood && moodData != null && moodData['mood'] != null) {
      siaHeadline = "$partnerName logged feeling ${moodData['mood']} today";
      siaSubtext = "Sia recommends gentle check-ins and empathetic listening.";
    }

    // Always guarantee a minimum of 3 suggestions
    final List<dynamic> suggestions = (_sharedData?['suggestions'] is List)
        ? List.from(_sharedData!['suggestions'])
        : [];

    final defaultPartnerSuggestions = [
      "Check in gently: Send a thoughtful text or ask about her day.",
      "Handle a chore: Wash the dishes or prepare dinner without being asked.",
      "Offer dedicated space: Give quiet downtime for rest and relaxation.",
    ];

    for (var fallback in defaultPartnerSuggestions) {
      if (suggestions.length >= 3) break;
      suggestions.add({'title': fallback});
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD6F1DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: BlushyColors.success, size: 18),
              const SizedBox(width: 8),
              Text(
                "✨ SIA AI PARTNER INSIGHTS",
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.success, letterSpacing: 1.1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            siaHeadline,
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: BlushyColors.text, height: 1.3),
          ),
          const SizedBox(height: 4),
          Text(
            siaSubtext,
            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFFD6F1DF)),
          const SizedBox(height: 8),
          Text(
            "Recommended for $partnerName today (minimum 3 active tips):",
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
          ),
          const SizedBox(height: 6),
          for (var item in suggestions.take(math.max(3, suggestions.length)))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 14, color: BlushyColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (item is Map ? (item['title'] ?? item['description'] ?? item.toString()) : item.toString()),
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getDynamicBodyArticles(String partnerName, Map<String, dynamic>? cycleInfo, Map<String, dynamic>? partnerUser) {
    final phase = (cycleInfo?['phase'] ?? '').toString().toLowerCase();
    final lifeStage = (partnerUser?['lifeStage'] ?? '').toString().toLowerCase();

    if (lifeStage.contains('pregnancy')) {
      return [
        {
          "category": "Body",
          "title": "Understanding Pregnancy Fatigue",
          "snippet": "Why carrying a pregnancy demands immense cardiovascular rest.",
          "body": "Progesterone surges rapidly to support fetal development, causing significant physical tiredness. Her body is working constantly to build a new life.",
          "action": "Encourage daytime naps, keep the house quiet, and help with heavy chores.",
        },
        {
          "category": "Body",
          "title": "Nutrition & Fluid Hydration in Pregnancy",
          "snippet": "Supporting blood volume expansion and fetal nutrition.",
          "body": "Blood volume expands by nearly 50% during pregnancy. Regular hydration and nutrient-dense snacks prevent dizziness and fatigue.",
          "action": "Keep fresh water and healthy snacks readily available throughout the house.",
        },
        {
          "category": "Body",
          "title": "Postural Comfort & Lower Back Relief",
          "snippet": "Relieving physical strain as center of gravity shifts.",
          "body": "Relaxin hormone loosens ligaments, putting pressure on lower back joints and pelvis.",
          "action": "Offer a foot rub or gently place supportive pillows behind her back when resting.",
        },
      ];
    }

    if (phase.contains('menstrual') || phase.contains('period')) {
      return [
        {
          "category": "Body",
          "title": "Navigating Period Energy Reset",
          "snippet": "Why low estrogen and progesterone trigger biological fatigue.",
          "body": "During the menstrual phase, progesterone and estrogen levels hit their lowest points. This is a natural biological reset. $partnerName needs quiet rest and lighter physical demands.",
          "action": "Take over practical chores (dishes, meal prep) so $partnerName can rest guilt-free.",
        },
        {
          "category": "Body",
          "title": "Relieving Physical Cramps & Muscle Tension",
          "snippet": "How uterine contractions cause pelvic discomfort.",
          "body": "Prostaglandins trigger muscular contractions that can radiate to the lower back. Heat therapy and gentle warmth relax pelvic muscles.",
          "action": "Brew a warm chamomile tea and prepare a hot water bottle or heating pack.",
        },
        {
          "category": "Body",
          "title": "Restorative Sleep & Warmth",
          "snippet": "Optimizing room temperature for period recovery.",
          "body": "Core body temperature drops slightly during bleeding. Warm blankets and early bedtimes support deep regenerative REM sleep.",
          "action": "Ensure the bedroom is warm and peaceful for an early, restful bedtime.",
        },
      ];
    } else if (phase.contains('follicular')) {
      return [
        {
          "category": "Body",
          "title": "The Estrogen Energy Surge",
          "snippet": "Why rising estrogen boosts stamina, focus, and social drive.",
          "body": "As estrogen climbs, mental sharpness and physical stamina rise rapidly. $partnerName will likely feel energetic, creative, and motivated.",
          "action": "Suggest active dates, outdoor walks, or tackling new creative projects together.",
        },
        {
          "category": "Body",
          "title": "High-Metabolic Workout Windows",
          "snippet": "Capitalizing on optimal muscle recovery and stamina.",
          "body": "Rising estrogen improves insulin sensitivity and muscle recovery. It is the best window of the month for high-energy exercise.",
          "action": "Join $partnerName for a workout, run, or energetic weekend activity.",
        },
        {
          "category": "Body",
          "title": "Social Receptivity & Communication",
          "snippet": "Why communication feels effortless during mid-follicular days.",
          "body": "Dopamine and serotonin rise alongside estrogen, enhancing social openness and optimistic outlooks.",
          "action": "Plan dinner with friends or engage in inspiring, forward-looking conversations.",
        },
      ];
    } else if (phase.contains('ovulation')) {
      return [
        {
          "category": "Body",
          "title": "Peak Estrogen & Vitality Window",
          "snippet": "Understanding the biological high-point of the cycle.",
          "body": "Estrogen hits its monthly peak alongside LH surge, boosting confidence, communication, and natural intimacy drive.",
          "action": "Plan a special date night or express authentic appreciation for her.",
        },
        {
          "category": "Body",
          "title": "Ovulation Discomfort & Hydration",
          "snippet": "Mild pelvic twinges and basal body temperature shifts.",
          "body": "Some experience mild ovulation discomfort (mittelschmerz) or sudden energy dips right after peak estrogen. Staying hydrated is key.",
          "action": "Keep fresh water handy and ask gently how her body feels today.",
        },
        {
          "category": "Body",
          "title": "Optimizing Peak Focus Hours",
          "snippet": "Making the most of high verbal fluency and confidence.",
          "body": "Verbal recall and executive focus reach their monthly maximum, equipping $partnerName for key decisions.",
          "action": "Encourage her goals and offer positive, uplifting validation.",
        },
      ];
    } else if (phase.contains('luteal') || phase.contains('pms')) {
      return [
        {
          "category": "Body",
          "title": "Progesterone & Natural Slowdown",
          "snippet": "Why rising progesterone increases thermal heat and fatigue.",
          "body": "Progesterone promotes quiet inward focus and increases body temperature by 0.5°C. $partnerName may tire more easily in the late afternoon.",
          "action": "Keep evenings relaxed and minimize late-night social commitments.",
        },
        {
          "category": "Body",
          "title": "Premenstrual Cravings & Metabolism",
          "snippet": "Why the body burns 100-300 extra calories per day.",
          "body": "Metabolic rate increases in the luteal phase. Craving complex carbs, dark chocolate, and magnesium-rich foods is biologically driven.",
          "action": "Keep healthy snacks, dark chocolate, and magnesium-rich foods available.",
        },
        {
          "category": "Body",
          "title": "Sensory Ease & Decompression",
          "snippet": "Lowering noise and stress during premenstrual days.",
          "body": "Serotonin receptivity dips right before bleeding, making loud environments or chaotic schedules feel overwhelming.",
          "action": "Create a peaceful home atmosphere and offer quiet downtime.",
        },
      ];
    }

    return [
      {
        "category": "Body",
        "title": "Navigating Period Energy Shifts",
        "snippet": "Why hormone drops trigger natural fatigue cycles.",
        "body": "During the menstrual phase, progesterone and estrogen levels hit their lowest points. This is a natural biological reset. $partnerName may need more quiet time, lighter exercise, and extra sleep.",
        "action": "Take care of practical chores so $partnerName can rest without feeling guilty.",
      },
      {
        "category": "Body",
        "title": "Understanding Physical Energy Waves",
        "snippet": "Matching activities with high and low energy days.",
        "body": "Estrogen surges increase stamina in earlier cycle weeks, while progesterone rises later promote rest. Paying attention to these patterns makes planning joint activities much easier.",
        "action": "Plan high-energy dates during week 2 and relaxing quiet evenings during week 4.",
      },
      {
        "category": "Body",
        "title": "Supporting Luteal & Follicular Recovery",
        "snippet": "How rest and nutrition balance metabolic demands during cycle shifts.",
        "body": "Metabolic rates increase slightly during the luteal phase while energy lowers. Providing nutrient-rich meals, hydration, and restful evenings supports physical recovery.",
        "action": "Prepare warm, nourishing meals and encourage restorative evening downtime.",
      },
    ];
  }

  List<Map<String, String>> _getDynamicEmotionArticles(String partnerName, Map<String, dynamic>? moodData) {
    final mood = (moodData?['mood'] ?? '').toString().toLowerCase();

    if (mood.contains('fatigu') || mood.contains('tired') || mood.contains('exhaust')) {
      return [
        {
          "category": "Emotions",
          "title": "Managing Low Emotional Bandwidth",
          "snippet": "Why physical fatigue reduces emotional patience.",
          "body": "Physical exhaustion depletes emotional reserves. What feels manageable when rested can feel overwhelming when tired.",
          "action": "Avoid bringing up complex or heavy discussions when $partnerName is physically drained.",
        },
        {
          "category": "Emotions",
          "title": "The Power of Quiet Validation",
          "snippet": "Listening without attempting immediate problem-solving.",
          "body": "When tired, $partnerName doesn't need solutions—she needs to feel heard and supported without pressure to perform.",
          "action": "Listen attentively and say: 'Rest up, I'm taking care of everything tonight.'",
        },
        {
          "category": "Emotions",
          "title": "De-escalating Decision Fatigue",
          "snippet": "Lightening mental load during exhaustion.",
          "body": "Decision fatigue compounds physical weariness. Simple choices like 'what's for dinner?' become stressful.",
          "action": "Make low-stakes decisions proactively instead of asking open questions.",
        },
      ];
    } else if (mood.contains('anxi') || mood.contains('stress') || mood.contains('overwhelm')) {
      return [
        {
          "category": "Emotions",
          "title": "Soothing Premenstrual Stress & Anxiety",
          "snippet": "How GABA receptor shifts increase stress sensitivity.",
          "body": "Hormonal shifts alter GABA receptors in the brain, lowering the threshold for stress and overthinking.",
          "action": "Offer a warm hug, brew soothing herbal tea, and reduce household noise.",
        },
        {
          "category": "Emotions",
          "title": "Emotional Receptivity & Grounding",
          "snippet": "Providing a calm anchor during emotional waves.",
          "body": "Anxiety feels like a storm inside. A steady, calm partner provides an external nervous system anchor.",
          "action": "Stay calm, use a quiet voice, and reassure $partnerName of your steady presence.",
        },
        {
          "category": "Emotions",
          "title": "De-escalating Mental Overwhelm",
          "snippet": "Breaking big challenges into single quiet steps.",
          "body": "Overwhelm occurs when too many demands compete for attention simultaneously.",
          "action": "Help break tasks down or take a task off her plate immediately.",
        },
      ];
    } else if (mood.contains('happy') || mood.contains('calm') || mood.contains('great') || mood.contains('good')) {
      return [
        {
          "category": "Emotions",
          "title": "Nurturing Shared Joy & Connection",
          "snippet": "Capitalizing on positive emotional harmony.",
          "body": "When mood is bright, positive interactions create long-lasting relationship deposits and emotional intimacy.",
          "action": "Share a fun experience, laugh together, or try a new activity.",
        },
        {
          "category": "Emotions",
          "title": "Deepening Mutual Trust & Openness",
          "snippet": "Expressing gratitude and authentic appreciation.",
          "body": "Positive emotional states offer the ideal window for open, loving conversations about future goals and dreams.",
          "action": "Tell $partnerName specifically what you love and appreciate about her.",
        },
        {
          "category": "Emotions",
          "title": "Sustaining Emotional Balance",
          "snippet": "Keeping open communication effortless.",
          "body": "Maintaining positive connection habits during good days builds a strong buffer for future high-stress weeks.",
          "action": "Plan your upcoming week together with excitement and balance.",
        },
      ];
    }

    return [
      {
        "category": "Emotions",
        "title": "Managing Stress and Premenstrual Shifts",
        "snippet": "How hormone changes affect emotional bandwidth.",
        "body": "Premenstrual hormone shifts lower the threshold for stress. What normally feels manageable might feel overwhelming. It isn't overreacting—it's a change in chemical receptors in the brain.",
        "action": "Listen patiently without offering direct advice unless asked. Validation goes a long way.",
      },
      {
        "category": "Emotions",
        "title": "Emotional Receptivity & Active Listening",
        "snippet": "Creating a safe space for open emotional sharing without judgment.",
        "body": "Active listening means giving full attention without formulating solutions immediately. Acknowledging emotional experience builds closeness and psychological safety.",
        "action": "Say: 'I hear how tough today was for you, and I am right here with you.'",
      },
      {
        "category": "Emotions",
        "title": "De-escalating Overwhelm & Anxiety",
        "snippet": "Simple ways to offer grounding support during stressful moments.",
        "body": "When stress peaks, cognitive processing becomes heavy. Offering steady presence, a quiet room, or a comforting warm drink helps soothe the nervous system.",
        "action": "Offer a gentle hug or brew a cup of tea without asking complex questions.",
      },
    ];
  }

  List<Map<String, String>> _getDynamicSupportArticles(String partnerName, List<dynamic> suggestions) {
    return [
      {
        "category": "Support",
        "title": "Comfort, Help, or Space?",
        "snippet": "How to check in without adding pressure.",
        "body": "When $partnerName is overwhelmed, asking 'what can I do?' forces decision-making, adding stress. Instead, categorize help into three pillars: Comfort (tea, heat pad), Help (laundry, dishes), or Space (quiet rest).",
        "action": "Ask directly: 'Would comfort, practical help, or space support you best right now?'",
      },
      {
        "category": "Support",
        "title": "Proactive Household Partnership",
        "snippet": "Taking initiative on daily logistics to lighten mental load.",
        "body": "Mental load encompasses planning meals, tracking errands, and managing home chores. Taking proactive responsibility for specific tasks removes decision fatigue for your partner.",
        "action": "Pick 2 daily household tasks (e.g. dishes and trash) and manage them completely.",
      },
      {
        "category": "Support",
        "title": "Quality Time vs. Quiet Presence",
        "snippet": "Understanding when shared activities vs quiet presence is needed.",
        "body": "Some days call for engaging outings and deep conversations, while other days require quiet side-by-side presence. Tuning into what is needed deepens mutual bond.",
        "action": "Check in: 'Would you like to do an activity together or just relax side-by-side quietly?'",
      },
    ];
  }

  List<Widget> _buildAllowedPartnerArticles() {
    final partnerUser = _sharedData?['partnerUser'];
    final cycleInfo = _sharedData?['cycleInfo'];
    final moodData = _sharedData?['mood'];
    final suggestions = (_sharedData?['suggestions'] is List) ? _sharedData!['suggestions'] : [];

    String partnerName = _activeConnection?['partner']?['displayName'] ??
        _activeConnection?['partnerEmail'] ??
        (partnerUser?['display_name'] ?? "Partner");
    if (partnerName.contains('@')) {
      partnerName = partnerName.split('@').first;
    }
    String sectionPartnerTitle = (partnerName.startsWith('qpfv') || partnerName.length > 15 || partnerName == 'Partner')
        ? "Her"
        : "$partnerName's";

    final List<Widget> list = [];

    // 1. Body Category -> Always minimum 3 dynamic articles
    final bodyArticles = _getDynamicBodyArticles(partnerName, cycleInfo, partnerUser);
    list.add(_buildSectionTitle("Understand $sectionPartnerTitle Body"));
    for (var article in bodyArticles) {
      list.add(_buildArticleTile(
        context: context,
        category: article['category'] ?? "Body",
        title: article['title'] ?? '',
        snippet: article['snippet'] ?? '',
        body: article['body'] ?? '',
        action: article['action'] ?? '',
      ));
    }
    list.add(const SizedBox(height: 16));

    // 2. Emotions Category -> Always minimum 3 dynamic articles
    final emotionArticles = _getDynamicEmotionArticles(partnerName, moodData);
    list.add(_buildSectionTitle("Understand $sectionPartnerTitle Emotions"));
    for (var article in emotionArticles) {
      list.add(_buildArticleTile(
        context: context,
        category: article['category'] ?? "Emotions",
        title: article['title'] ?? '',
        snippet: article['snippet'] ?? '',
        body: article['body'] ?? '',
        action: article['action'] ?? '',
      ));
    }
    list.add(const SizedBox(height: 16));

    // 3. Support Category -> Always minimum 3 dynamic articles
    final supportArticles = _getDynamicSupportArticles(partnerName, suggestions);
    list.add(_buildSectionTitle("Be Better at Supporting"));
    for (var article in supportArticles) {
      list.add(_buildArticleTile(
        context: context,
        category: article['category'] ?? "Support",
        title: article['title'] ?? '',
        snippet: article['snippet'] ?? '',
        body: article['body'] ?? '',
        action: article['action'] ?? '',
      ));
    }

    return list;
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text),
      ),
    );
  }

  Widget _buildArticleTile({
    required BuildContext context,
    required String category,
    required String title,
    required String snippet,
    required String body,
    required String action,
  }) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      borderOnForeground: true,
      child: InkWell(
        onTap: () => _showArticle(context, category, title, body, action),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snippet,
                      style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BlushyColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}


