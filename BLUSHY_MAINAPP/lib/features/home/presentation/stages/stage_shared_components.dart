import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/colors.dart';
import '../../../../core/state.dart';
import '../../../../core/storage.dart';
import '../../../../models/blushy_models.dart';
import '../../../../services/sia_dashboard_service.dart';
import '../../../../services/api_period_service.dart';
import '../../../sia/sia_screen.dart';
import '../../widgets/cycle_card.dart';
import '../../widgets/real_cycle_history.dart';
import '../../widgets/checkin_card_stack.dart';
import '../../widgets/metric_trend_chart.dart';
import '../../home_screen.dart';

// =========================================================================
// 1. DASHBOARD WRAPPER & HEADER HELPERS
// =========================================================================

Widget wrapStageDashboardLayout({
  required BuildContext context,
  required Widget child,
  GlobalKey<ScaffoldState>? scaffoldKey,
  bool isNested = false,
}) {
  if (isNested) {
    return Container(color: BlushyColors.background, child: child);
  }
  return Scaffold(
    key: scaffoldKey,
    backgroundColor: BlushyColors.background,
    body: SafeArea(
      bottom: false,
      child: child,
    ),
  );
}

Widget buildSectionTitleWithFilledIcon({
  required IconData icon,
  required String title,
  String? subtitle,
  Color iconBg = const Color(0xFFDD0D22),
  Color iconColor = Colors.white,
  Color? bgColor,
  double titleSize = 16.5,
  Widget? trailing,
}) {
  final effectiveBg = bgColor ?? iconBg;
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: effectiveBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      color: BlushyColors.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      if (trailing != null) trailing,
    ],
  );
}

void openAskSiaChat(BuildContext context, [String? initialQuestion]) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: BlushyColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BlushySiaScreen(initialQuestion: initialQuestion),
        ),
      ),
    ),
  ).then((_) {
    SiaDashboardService().triggerRefresh();
  });
}

void showArticleDetailDialog(BuildContext context, String title, String summary) {
  showDialog(
    context: context,
    builder: (dialogContext) =>
        ArticleDetailDialog(title: title, summary: summary),
  );
}

// =========================================================================
// 2. FLO-STYLE SELF-CARE CATEGORY ROW
// =========================================================================

class FloStyleSelfCareCategoryRow extends StatefulWidget {
  final String stageKey;
  final ValueChanged<String>? onCategorySelected;

  const FloStyleSelfCareCategoryRow({
    super.key,
    required this.stageKey,
    this.onCategorySelected,
  });

  @override
  State<FloStyleSelfCareCategoryRow> createState() => _FloStyleSelfCareCategoryRowState();
}

class _FloStyleSelfCareCategoryRowState extends State<FloStyleSelfCareCategoryRow> {
  String _selectedCategory = 'All';

  static const List<Map<String, dynamic>> categories = [
    {
      'id': 'Self-care & Period',
      'title': 'Self-care & Period',
      'subtitle': 'Kit, relief & soothe',
      'icon': Icons.spa_rounded,
      'bgColor': Color(0xFFFF006D),
    },
    {
      'id': 'Symptom Checker',
      'title': 'Symptom Checker',
      'subtitle': 'Decode body signals',
      'icon': Icons.healing_rounded,
      'bgColor': Color(0xFFFF4A00),
    },
    {
      'id': 'Cycle Insights',
      'title': 'Cycle Insights',
      'subtitle': 'Phases & biomarkers',
      'icon': Icons.spa_rounded,
      'bgColor': Color(0xFF7C3AED),
    },
    {
      'id': 'Parent Prompts',
      'title': 'Parent Prompts',
      'subtitle': 'Safe talk starters',
      'icon': Icons.forum_rounded,
      'bgColor': Color(0xFFDD0D22),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Self-care & Essentials",
              style: GoogleFonts.manrope(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: BlushyColors.text,
                letterSpacing: -0.3,
              ),
            ),
            if (_selectedCategory != 'All')
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = 'All';
                  });
                  widget.onCategorySelected?.call('All');
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    "Show All",
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: categories.map((cat) {
              final id = cat['id'] as String;
              final title = cat['title'] as String;
              final bgColor = cat['bgColor'] as Color;
              final icon = cat['icon'] as IconData;
              final isSelected = _selectedCategory == id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = isSelected ? 'All' : id;
                  });
                  widget.onCategorySelected?.call(_selectedCategory);
                  showCategoryEssentialsModal(
                    context,
                    title,
                    icon,
                    bgColor,
                    widget.stageKey,
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 118,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: isSelected ? 2.5 : 0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: bgColor.withValues(alpha: isSelected ? 0.5 : 0.3),
                        blurRadius: isSelected ? 14 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

Map<String, dynamic> getCategoryEssentialsData(String categoryTitle, String stageKey) {
  final norm = stageKey.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
  final isPreMenarche = norm.contains('notstarted') || norm.contains('puberty');

  if (categoryTitle.contains('Self-care')) {
    return {
      'tips': isPreMenarche
          ? [
              "Pack 2-3 sanitary pads & a fresh pouch in your school backpack.",
              "Drink a warm cup of herbal chamomile tea for tummy comfort.",
              "Practice gentle deep breathing to relax and stay grounded.",
            ]
          : [
              "Use a warm water bottle or heating pad on your lower tummy.",
              "Sip warm ginger or peppermint tea to soothe natural uterine contractions.",
              "Prioritize 8-9 hours of restorative sleep with an elevated pillow.",
            ],
      'guides': isPreMenarche
          ? [
              {'title': 'First Period Care & Backpack Kit', 'readTime': '4 min read', 'content': 'Everything you need in your daily kit: pads, clean underwear, wipes, and a small discreet pouch.'},
              {'title': 'Understanding Body Temperature & Rest', 'readTime': '3 min read', 'content': 'Why staying warm and cozy eases pre-menarche tummy aches.'},
            ]
          : [
              {'title': 'Soothing Period Cramps Naturally', 'readTime': '5 min read', 'content': 'Evidence-backed warmth, magnesium, and hydration remedies for cycle ease.'},
              {'title': 'Restorative Yoga for Menstrual Flow', 'readTime': '6 min read', 'content': 'Child\'s pose, reclining butterfly, and legs-up-the-wall for deep pelvis relief.'},
            ],
    };
  } else if (categoryTitle.contains('Symptom')) {
    return {
      'tips': [
        "Log your daily energy, mood, and flow right inside Blushy.",
        "Notice patterns between what you eat, your stress, and cramping.",
        "Keep an eye on discharge colors and hydration levels.",
      ],
      'guides': [
        {'title': 'Decoding Symptoms & Body Signals', 'readTime': '4 min read', 'content': 'How hormones influence sleep, mood swings, skin glow, and appetite throughout the month.'},
        {'title': 'Normal vs When to Check with a Doctor', 'readTime': '5 min read', 'content': 'Clear guidance on what is expected vs when to seek medical advice.'},
      ],
    };
  } else if (categoryTitle.contains('Cycle')) {
    return {
      'tips': [
        "Your cycle is divided into 4 natural biological phases.",
        "Track energy peaks during the follicular and ovulatory windows.",
        "Embrace the slower, reflective pace of the luteal and menstrual phases.",
      ],
      'guides': [
        {'title': 'The Four Phases of Your Menstrual Cycle', 'readTime': '6 min read', 'content': 'Menstrual (Winter), Follicular (Spring), Ovulation (Summer), and Luteal (Autumn).'},
        {'title': 'Why Irregular Cycles Happen in Youth', 'readTime': '4 min read', 'content': 'It takes 12-24 months for ovulation signals to stabilize in young women.'},
      ],
    };
  } else {
    // Parent Prompts
    return {
      'tips': [
        "Talking to mom, dad, or a guardian helps you feel supported.",
        "School nurses and teachers have spare supplies if you ever need them.",
        "There are no embarrassing questions when it comes to your health.",
      ],
      'guides': [
        {'title': 'Conversation Starters for Parents', 'readTime': '3 min read', 'content': 'Simple, stress-free scripts to ask for period care supplies or talk about symptoms.'},
        {'title': 'Emergency School Period Guide', 'readTime': '4 min read', 'content': 'What to do if your period starts during class, sports, or exams.'},
      ],
    };
  }
}

void showCategoryEssentialsModal(
  BuildContext context,
  String categoryTitle,
  IconData categoryIcon,
  Color categoryColor,
  String stageKey,
) {
  final essentials = getCategoryEssentialsData(categoryTitle, stageKey);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: Color(0xFFFAF7F2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(categoryIcon, color: categoryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryTitle,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: BlushyColors.text,
                          ),
                        ),
                        Text(
                          "Curated Care & Actionable Tips",
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEBE6E0)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    "QUICK ESSENTIAL TIPS",
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(essentials['tips'] as List<String>).map((tip) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEBE6E0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_rounded, size: 12, color: categoryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tip,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: BlushyColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 18),
                  Text(
                    "RECOMMENDED GUIDES",
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(essentials['guides'] as List<Map<String, String>>).map((guide) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEBE6E0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.menu_book_rounded, color: categoryColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  guide['title']!,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: BlushyColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  guide['readTime']!,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: categoryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              showArticleDetailDialog(
                                context,
                                guide['title']!,
                                guide['content'] ?? 'Detailed guide content curated for your wellness journey.',
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: categoryColor.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              "Read",
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: categoryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// =========================================================================
// 3. VISUAL ARTICLES CAROUSEL
// =========================================================================

List<Map<String, dynamic>> getStageCuratedArticles(String stageKey) {
  final norm = stageKey.toLowerCase().replaceAll('_', '').replaceAll(' ', '');

  if (norm.contains('notstarted') || norm.contains('puberty')) {
    return [
      {
        'title': 'Signs Your First Period Is Coming',
        'category': 'BODY CHANGES',
        'readTime': '4 min read',
        'bgColor': const Color(0xFFFFF0F2),
        'accentColor': const Color(0xFFE11D48),
        'icon': Icons.favorite_rounded,
        'summary': 'Noticeable changes like breast development, growth spurts, and clear discharge that signal your body is preparing for its first period.',
      },
      {
        'title': 'The Ultimate Backpack Kit',
        'category': 'PREPAREDNESS',
        'readTime': '3 min read',
        'bgColor': const Color(0xFFF0FDF4),
        'accentColor': const Color(0xFF16A34A),
        'icon': Icons.backpack_rounded,
        'summary': 'Discreet, practical items to keep in your school bag: pads, a zip pouch, backup underwear, and wipes so you are never caught unprepared.',
      },
      {
        'title': 'What Does a Period Actually Feel Like?',
        'category': 'REAL TALK',
        'readTime': '5 min read',
        'bgColor': const Color(0xFFFAF5FF),
        'accentColor': const Color(0xFF9333EA),
        'icon': Icons.bubble_chart_rounded,
        'summary': 'From mild tummy butterflies to spotting, learn what to realistically expect when your first cycle begins so there are no surprises.',
      },
      {
        'title': 'How to Talk to Mom or a School Nurse',
        'category': 'CONFIDENCE',
        'readTime': '3 min read',
        'bgColor': const Color(0xFFFFFBEB),
        'accentColor': const Color(0xFFD97706),
        'icon': Icons.chat_bubble_outline_rounded,
        'summary': 'Easy conversation starters and tips to comfortably ask for supplies, explain cramps, or ask questions without feeling awkward.',
      },
    ];
  } else if (norm.contains('started')) {
    return [
      {
        'title': 'Why Your First-Year Cycles Are Irregular',
        'category': 'CYCLE SCIENCE',
        'readTime': '4 min read',
        'bgColor': const Color(0xFFFAF5FF),
        'accentColor': const Color(0xFF7C3AED),
        'icon': Icons.timeline_rounded,
        'summary': 'It takes 12-24 months for ovulation signals to stabilize in young women. Irregular cycles in your first year are completely normal.',
      },
      {
        'title': 'Pads vs. Tampons vs. Period Underwear',
        'category': 'CARE CHOICES',
        'readTime': '5 min read',
        'bgColor': const Color(0xFFFFF0F2),
        'accentColor': const Color(0xFFDD0D22),
        'icon': Icons.spa_rounded,
        'summary': 'Comparing comfort, absorbency, change intervals, and school convenience across all period care options.',
      },
      {
        'title': 'Soothing Period Cramps Naturally',
        'category': 'COMFORT & RELIEF',
        'readTime': '4 min read',
        'bgColor': const Color(0xFFF0FDF4),
        'accentColor': const Color(0xFF16A34A),
        'icon': Icons.healing_rounded,
        'summary': 'Evidence-backed warmth, magnesium, herbal chamomile teas, and gentle stretching routines to calm uterine contractions.',
      },
      {
        'title': 'Period at School Survival Guide',
        'category': 'CONFIDENCE',
        'readTime': '3 min read',
        'bgColor': const Color(0xFFFFFBEB),
        'accentColor': const Color(0xFFD97706),
        'icon': Icons.school_rounded,
        'summary': 'How to discreetly handle sudden flow, stain prevention, asking the school nurse, and staying calm in class.',
      },
    ];
  } else {
    // Stage 3 & General
    return [
      {
        'title': 'The Four Phases of Cycle Syncing',
        'category': 'HORMONAL RHYTHM',
        'readTime': '6 min read',
        'bgColor': const Color(0xFFFAF5FF),
        'accentColor': const Color(0xFF7C3AED),
        'icon': Icons.auto_awesome_rounded,
        'summary': 'How Menstrual, Follicular, Ovulatory, and Luteal phases dictate your metabolism, cognitive peak, and exercise tolerance.',
      },
      {
        'title': 'Nutrition & Seed Cycling for Hormone Balance',
        'category': 'NUTRITION BIOHACK',
        'readTime': '5 min read',
        'bgColor': const Color(0xFFF0FDF4),
        'accentColor': const Color(0xFF16A34A),
        'icon': Icons.restaurant_rounded,
        'summary': 'Flax, pumpkin, sesame, and sunflower seeds to support natural estrogen and progesterone production across each phase.',
      },
      {
        'title': 'Caffeine Timing & Cortisol Peaks',
        'category': 'ENERGY BIOHACK',
        'readTime': '4 min read',
        'bgColor': const Color(0xFFFFFBEB),
        'accentColor': const Color(0xFFD97706),
        'icon': Icons.coffee_rounded,
        'summary': 'Why coffee during your luteal phase spikes anxiety, and how switching to matcha or cacao sustains clean all-day focus.',
      },
      {
        'title': 'Workouts Tailored to Your Cycle',
        'category': 'FITNESS ARCHITECTURE',
        'readTime': '5 min read',
        'bgColor': const Color(0xFFFFF0F2),
        'accentColor': const Color(0xFFDD0D22),
        'icon': Icons.fitness_center_rounded,
        'summary': 'When to hit high-intensity PRs (follicular/ovulation) vs when to focus on yin yoga and walking (luteal/menstrual).',
      },
    ];
  }
}

class VisualArticlesCarousel extends StatelessWidget {
  final String stageKey;

  const VisualArticlesCarousel({
    super.key,
    required this.stageKey,
  });

  @override
  Widget build(BuildContext context) {
    final articles = getStageCuratedArticles(stageKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Curated For Your Stage",
              style: GoogleFonts.manrope(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: BlushyColors.text,
                letterSpacing: -0.3,
              ),
            ),
            InkWell(
              onTap: () => showAllArticlesModal(context, stageKey),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  "View All",
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BlushyColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: articles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final a = articles[index];
              final bgColor = a['bgColor'] as Color;
              final accentColor = a['accentColor'] as Color;
              final icon = a['icon'] as IconData;

              return InkWell(
                onTap: () => showArticleDetailDialog(
                  context,
                  a['title'] as String,
                  a['summary'] as String,
                ),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 175,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              a['category'] as String,
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 14, color: accentColor),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        a['title'] as String,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: BlushyColors.text,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            a['readTime'] as String,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: BlushyColors.secondaryText,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: accentColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

void showAllArticlesModal(BuildContext context, String stageKey) {
  final articles = getStageCuratedArticles(stageKey);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFFFAF7F2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "All Curated Reads",
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.text,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEBE6E0)),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: articles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final a = articles[index];
                  final accentColor = a['accentColor'] as Color;

                  return InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      showArticleDetailDialog(
                        context,
                        a['title'] as String,
                        a['summary'] as String,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEBE6E0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(a['icon'] as IconData, color: accentColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['category'] as String,
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  a['title'] as String,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: BlushyColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  a['readTime'] as String,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: BlushyColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
