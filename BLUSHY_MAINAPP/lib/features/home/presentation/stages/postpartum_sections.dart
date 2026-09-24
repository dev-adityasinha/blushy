import 'package:flutter/material.dart';

import 'article_subsection.dart';

/// Curated illustrated subsections shown under the postpartum stage's Health
/// Library.
///
/// Renders through the shared [ArticleSubsection] -- small cards in a
/// horizontal, left-to-right scrolling row with the title below each image,
/// tapping one opens [ArticleDetailPage]. The subsection names and titles come
/// from the source folder and image names.

const List<ArticleEntry> _adjustingArticles = [
  ArticleEntry(
    title: 'Birth Control While Breastfeeding: Do You Need It, and Is It Safe?',
    image: 'assets/postpartum_motherhood/birth_control_breastfeeding.png',
  ),
  ArticleEntry(
    title: 'Can You Get an IUD After Giving Birth?',
    image: 'assets/postpartum_motherhood/iud_after_birth.png',
  ),
  ArticleEntry(
    title: 'First Sex After Delivery: 5 Things You Should Be Ready For',
    image: 'assets/postpartum_motherhood/first_sex_after_delivery.png',
  ),
];

const List<ArticleEntry> _raisingBabyArticles = [
  ArticleEntry(
    title: 'What Is Co-Sleeping? Positions for Co-Sleeping',
    image: 'assets/postpartum_baby/co_sleeping.png',
  ),
  ArticleEntry(
    title: 'When Do Babies Start Crawling? Understanding a Significant Milestone',
    image: 'assets/postpartum_baby/babies_crawling.png',
  ),
];

const List<ArticleEntry> _recoveringArticles = [
  ArticleEntry(
    title: 'Baby Blues or Postpartum Depression? How to Tell the Difference',
    image: 'assets/postpartum_recovery/baby_blues_vs_ppd.png',
  ),
  ArticleEntry(
    title: 'How to Identify and Treat Delayed Postpartum Depression',
    image: 'assets/postpartum_recovery/delayed_ppd.png',
  ),
  ArticleEntry(
    title: 'Postpartum Anxiety: How to Spot the Symptoms and What to Do Next',
    image: 'assets/postpartum_recovery/postpartum_anxiety.png',
  ),
];

/// "Adjusting to Motherhood" -- a subsection under the postpartum Health Library.
class PostpartumAdjustingSection extends StatelessWidget {
  const PostpartumAdjustingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Adjusting to Motherhood',
      articles: _adjustingArticles,
    );
  }
}

/// "Raising a Baby" -- a subsection next to Adjusting to Motherhood.
class PostpartumRaisingBabySection extends StatelessWidget {
  const PostpartumRaisingBabySection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Raising a Baby',
      articles: _raisingBabyArticles,
    );
  }
}

/// "Recovering from Birth" -- a subsection next to Raising a Baby.
class PostpartumRecoveringSection extends StatelessWidget {
  const PostpartumRecoveringSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Recovering from Birth',
      articles: _recoveringArticles,
    );
  }
}
