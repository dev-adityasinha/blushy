import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';
import '../../../core/theme.dart' hide BlushyColors;
import '../../../services/api_partner_service.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';
import '../../../models/blushy_models.dart';
import '../../../shared/api_state_card.dart';
import '../../../l10n/app_localizations.dart';

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
    // Articles come from the reviewed content library.
    _loadLearnContent();

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
        title: Text(AppLocalizations.of(context).plConnectWithPartner, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).plPairingWithYourPartner,
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
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                final res = await _partnerService.invitePartnerByEmail(email);
                if (mounted) {
                  messenger.showSnackBar(
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
            child: Text(AppLocalizations.of(context).plSendInvite, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          AppLocalizations.of(context).plLearnDiscover,
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
                        title: AppLocalizations.of(context).plUnderstandingEnergyFatigueShifts,
                        snippet: "How biological rhythms affect baseline energy.",
                        body: "Energy levels naturally fluctuate based on sleep quality, hydration, stress, and daily metabolic demands. Prioritizing consistent sleep schedules and balanced nutrition helps maintain steady focus throughout the week.",
                        action: "Maintain a steady daily sleep schedule and take micro-breaks during long work stretches.",
                      ),
                      _buildArticleTile(
                        context: context,
                        category: "Wellness",
                        title: AppLocalizations.of(context).plMindfulCommunicationPrinciples,
                        snippet: "Building empathetic conversations and active listening.",
                        body: "Empathetic communication begins with non-judgmental listening. When someone shares their day or frustration, validating their perspective before jumping to advice creates trust and psychological safety.",
                        action: "Practice reflective listening: summarize what you heard before responding.",
                      ),
                      _buildArticleTile(
                        context: context,
                        category: "Wellness",
                        title: AppLocalizations.of(context).plDailyHydrationMetabolicBalance,
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
                        title: AppLocalizations.of(context).plManagingStressDailyResilience,
                        snippet: "Practical techniques to regulate your nervous system.",
                        body: "Simple breathwork exercises, such as 4-7-8 breathing or box breathing, instantly signal safety to your central nervous system, helping de-escalate acute stress.",
                        action: "Try 3 minutes of slow box breathing whenever feeling overwhelmed.",
                      ),
                      _buildArticleTile(
                        context: context,
                        category: "Rest",
                        title: AppLocalizations.of(context).plBuildingHealthySleepArchitecture,
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
            color: Colors.black.withValues(alpha: 0.03),
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
                  color: BlushyColors.primary.withValues(alpha: 0.1),
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
                      AppLocalizations.of(context).plConnectWithYourPartner,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Pairing allows Dr. Docsy to display partner support recommendations, phase awareness, and relationship care tips tailored to your partner.",
            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text.withValues(alpha: 0.8), height: 1.4),
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

    String siaHeadline = "Dr. Docsy AI Partner Care Insights";
    String siaSubtext = "Live advice strictly respecting partner privacy permissions.";

    if (canShareCycle && cycleInfo != null && cycleInfo['phase'] != null) {
      final phase = cycleInfo['phase'];
      final day = cycleInfo['currentCycleDay'];
      siaHeadline = "$partnerName is on Day ${day ?? ''} ($phase Phase)";
      siaSubtext = "Hormones adjust energy levels during this phase.";
    } else if (canShareMood && moodData != null && moodData['mood'] != null) {
      siaHeadline = "$partnerName logged feeling ${moodData['mood']} today";
      siaSubtext = "Dr. Docsy recommends gentle check-ins and empathetic listening.";
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
                "✨ DR. DOCSY AI PARTNER INSIGHTS",
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

  // ---------------------------------------------------------------------
  // Partner Learn library (spec §13, §23).
  //
  // The three sections used to be built from ~33 articles hardcoded in this
  // file. That copy made clinical claims with no source, reviewer or version,
  // which §31 requires of clinical content. It now comes from the medical
  // content service, where every article carries provenance and has to pass
  // clinical review before it is served, and where reading progress and
  // bookmarks are tracked.
  // ---------------------------------------------------------------------

  static const List<({String topic, String heading})> _learnSections = [
    (topic: 'understand_her_body', heading: 'Understand'),
    (topic: 'understand_her_emotions', heading: 'Understand'),
    (topic: 'be_better_at_supporting', heading: 'Be better at supporting'),
  ];

  final Map<String, ApiResult<List<LibraryItem>>> _learnContent = {};

  Future<void> _loadLearnContent() async {
    for (final section in _learnSections) {
      final result = await ContentApi.browse(audience: 'partner', topic: section.topic, limit: 20);
      if (!mounted) return;
      setState(() => _learnContent[section.topic] = result);
    }
  }

  Future<void> _openLearnArticle(LibraryItem item) async {
    // Opening counts as progress; completion is recorded when they finish.
    await ContentApi.saveProgress(item.contentId, progressPercent: 100, completed: true);
    if (!mounted) return;
    await _loadLearnContent();
  }

  Future<void> _toggleLearnBookmark(LibraryItem item) async {
    await ContentApi.setBookmark(item.contentId, !item.bookmarked);
    if (!mounted) return;
    await _loadLearnContent();
  }

  List<Widget> _buildAllowedPartnerArticles() {
    final partnerUser = _sharedData?['partnerUser'];

    String partnerName = _activeConnection?['partner']?['displayName'] ??
        _activeConnection?['partnerEmail'] ??
        (partnerUser?['display_name'] ?? "Partner");
    if (partnerName.contains('@')) {
      partnerName = partnerName.split('@').first;
    }
    final String possessive =
        (partnerName.startsWith('qpfv') || partnerName.length > 15 || partnerName == 'Partner')
            ? "Her"
            : "$partnerName's";

    const headings = {
      'understand_her_body': 'Body',
      'understand_her_emotions': 'Emotions',
      'be_better_at_supporting': 'Support',
    };

    final List<Widget> list = [];

    for (final section in _learnSections) {
      final title = section.topic == 'be_better_at_supporting'
          ? 'Be better at supporting'
          : '${section.heading} $possessive ${headings[section.topic]}';

      list.add(_buildSectionTitle(title));
      list.add(
        ApiStateCard<List<LibraryItem>>(
          result: _learnContent[section.topic] ?? const ApiResult.loading(),
          onRetry: _loadLearnContent,
          emptyMessage: 'No reviewed articles here yet.',
          builder: (context, items) {
            if (items.isEmpty) {
              return _buildLearnPlaceholder('No reviewed articles here yet.');
            }
            return Column(
              children: items.map((item) => _buildLibraryTile(item, headings[section.topic] ?? '')).toList(),
            );
          },
        ),
      );
      list.add(const SizedBox(height: 16));
    }

    return list;
  }

  Widget _buildLearnPlaceholder(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlushyColors.border, width: 0.8),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(fontSize: 12.5, color: BlushyColors.secondaryText, height: 1.5),
      ),
    );
  }

  Widget _buildLibraryTile(LibraryItem item, String category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BlushyColors.border, width: 0.8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.text,
                  ),
                ),
              ),
              if (item.completed)
                const Icon(Icons.check_circle, size: 16, color: BlushyColors.primary),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                item.summary ?? '',
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (item.readingTimeMinutes != null)
                    Text(
                      '${item.readingTimeMinutes} min',
                      style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
                    ),
                  // Clinical content states where it came from (spec §31).
                  if (item.source != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.source!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              item.bookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 18,
              color: item.bookmarked ? BlushyColors.primary : BlushyColors.secondaryText,
            ),
            tooltip: item.bookmarked ? 'Remove from saved' : 'Save',
            onPressed: () => _toggleLearnBookmark(item),
          ),
          onTap: () {
            _openLearnArticle(item);
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(item.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.body, style: GoogleFonts.poppins(fontSize: 13, height: 1.5)),
                      if (item.source != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Source: ${item.source}',
                          style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
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


