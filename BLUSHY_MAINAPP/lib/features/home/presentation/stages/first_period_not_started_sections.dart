import 'package:flutter/material.dart';

import 'article_subsection.dart';

/// Curated illustrated subsections shown under the first-period-not-started
/// stage's Health Library.
///
/// Renders through the shared [ArticleSubsection] -- small cards in a
/// horizontal, left-to-right scrolling row with the title below each image,
/// tapping one opens [ArticleDetailPage]. The titles come from the source image
/// names.

const List<ArticleEntry> _bodyChangesArticles = [
  ArticleEntry(
    title: 'Breast Shapes and Sizes: Everything You Need to Know',
    image: 'assets/body_changes/breast_shapes.png',
  ),
  ArticleEntry(
    title: 'Puberty Body Changes: 6 Common Puberty Symptoms',
    image: 'assets/body_changes/puberty_body_changes.png',
  ),
  ArticleEntry(
    title:
        'Signs Your Breasts Are Growing During Puberty: Everything You Need to Know',
    image: 'assets/body_changes/breasts_growing_puberty.png',
  ),
];

const List<ArticleEntry> _morePubertyArticles = [
  ArticleEntry(
    title: 'Body Odor: What Causes Body Odor and How Can You Prevent It?',
    image: 'assets/puberty/body_odor.png',
  ),
  ArticleEntry(
    title: 'Everything You Need to Know About the Stages of Puberty',
    image: 'assets/puberty/stages_of_puberty.png',
  ),
  ArticleEntry(
    title: 'Understanding Your Hormones: Everything You Need to Know',
    image: 'assets/puberty/hormones.png',
  ),
  ArticleEntry(
    title: 'Vulva, Vagina, and Breasts: Parts of the Female Anatomy Explained',
    image: 'assets/puberty/anatomy.png',
  ),
];

const List<ArticleEntry> _teenageLifeArticles = [
  ArticleEntry(
    title: 'Does Sex Hurt the First Time? Your Questions Answered',
    image: 'assets/teenage_life/first_time_sex.png',
  ),
  ArticleEntry(
    title: 'How Old Should You Be to Use Tampons? Tips for First-Timers',
    image: 'assets/teenage_life/tampons_age.png',
  ),
];

/// "Body Changes" -- a subsection shown under the first-period-not-started
/// Health Library.
class NotStartedBodyChangesSection extends StatelessWidget {
  const NotStartedBodyChangesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Body Changes',
      articles: _bodyChangesArticles,
    );
  }
}

/// "More on Puberty" -- a subsection shown next to Body Changes in the
/// first-period-not-started stage.
class NotStartedMorePubertySection extends StatelessWidget {
  const NotStartedMorePubertySection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'More on Puberty',
      articles: _morePubertyArticles,
    );
  }
}

/// "Teenage Life" -- a subsection shown next to More on Puberty in the
/// first-period-not-started stage.
class NotStartedTeenageLifeSection extends StatelessWidget {
  const NotStartedTeenageLifeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Teenage Life',
      articles: _teenageLifeArticles,
    );
  }
}
