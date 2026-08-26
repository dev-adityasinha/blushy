import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colors.dart';
import '../services/discover_service.dart';

class DiscoverSectionWidget extends StatefulWidget {
  final String? authToken;
  final Set<String>? savedArticles;
  final Function(String title)? onBookmarkToggle;

  const DiscoverSectionWidget({
    super.key,
    this.authToken,
    this.savedArticles,
    this.onBookmarkToggle,
  });

  @override
  State<DiscoverSectionWidget> createState() => _DiscoverSectionWidgetState();
}

class _DiscoverSectionWidgetState extends State<DiscoverSectionWidget> {
  bool _isLoading = true;
  DiscoverPayload? _payload;
  String _selectedTopic = "Women's Health";
  late Set<String> _localSavedArticles;

  @override
  void initState() {
    super.initState();
    _localSavedArticles = widget.savedArticles != null ? Set.from(widget.savedArticles!) : <String>{};
    _loadDailyDiscover();
  }

  Future<void> _loadDailyDiscover() async {
    final payload = await DiscoverService.fetchDailyDiscoverPayload(authToken: widget.authToken);
    if (mounted) {
      setState(() {
        _payload = payload;
        _selectedTopic = payload.featuredTopic;
        _isLoading = false;
      });
    }
  }

  void _showArticleDialog(BuildContext context, DiscoverArticle article) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Text(
            article.title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: BlushyColors.text),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: BlushyColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "✨ 24h AI Daily Insight",
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  article.desc,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.text, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  article.content ?? article.desc,
                  style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Close",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: BlushyColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topics = _payload?.topics ?? [
      "Women's Health",
      "Nutrition",
      "Exercise",
      "Mental Wellbeing",
      "Sleep",
      "Stress",
      "Productivity",
      "Cycle Health",
      "Movement",
      "Sexual Wellness",
      "Relationships"
    ];

    final articles = _payload?.topicArticles[_selectedTopic] ?? [
      DiscoverArticle(
        title: "Balancing Daily Schedules",
        desc: "How tracking non-reproductive health symptoms (mood, focus, sleep) builds body awareness.",
        content: "Consistent symptom logging helps identify hormone sensitivity across your 28-day cycle.",
      ),
      DiscoverArticle(
        title: "Hormones & Lifestyle baselines",
        desc: "Understanding minor endocrine cycles and adjusting exercise patterns accordingly.",
        content: "Dynamic rest days during luteal phases improve recovery and baseline metabolic health.",
      )
    ];

    final isPersonalized = _payload?.isPersonalized ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "DISCOVER",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: BlushyColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BlushyColors.primary.withValues(alpha: 0.2), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 11, color: BlushyColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    isPersonalized ? "AI Personalized" : "24h Topic Rotation",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Horizontally scrolling topic chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topics.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSelected = _selectedTopic == topic;
              final isFeatured = _payload?.featuredTopic == topic;

              return GestureDetector(
                onTap: () => setState(() => _selectedTopic = topic),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? BlushyColors.primary : const Color(0x0F2E2623),
                    borderRadius: BorderRadius.circular(20),
                    border: isFeatured && !isSelected
                        ? Border.all(color: BlushyColors.primary.withValues(alpha: 0.5), width: 1.2)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFeatured) ...[
                        Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: isSelected ? Colors.white : BlushyColors.primary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        topic,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : BlushyColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Articles list
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: BlushyColors.primary),
              ),
            ),
          )
        else
          Column(
            children: articles.map((article) {
              final isSaved = _localSavedArticles.contains(article.title);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BlushyColors.border, width: 0.8),
                    boxShadow: const [
                      BoxShadow(
                        color: BlushyColors.shadow,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.desc,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: BlushyColors.secondaryText,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              _showArticleDialog(context, article);
                            },
                            child: Text(
                              "Read",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: BlushyColors.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                              size: 18,
                              color: isSaved ? BlushyColors.primary : BlushyColors.secondaryText,
                            ),
                            onPressed: () {
                              setState(() {
                                if (isSaved) {
                                  _localSavedArticles.remove(article.title);
                                } else {
                                  _localSavedArticles.add(article.title);
                                }
                              });
                              if (widget.onBookmarkToggle != null) {
                                widget.onBookmarkToggle!(article.title);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, size: 18, color: BlushyColors.secondaryText),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Shared '${article.title}'!",
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
