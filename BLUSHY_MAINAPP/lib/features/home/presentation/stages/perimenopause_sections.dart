import 'package:flutter/material.dart';

import 'article_subsection.dart';

/// Curated illustrated subsections shown under the perimenopause stage's
/// Health Library.
///
/// Renders through the shared [ArticleSubsection] -- small cards in a
/// horizontal, left-to-right scrolling row with the title below each image,
/// tapping one opens [ArticleDetailPage]. The titles come from the source image
/// names.

const List<ArticleEntry> _perimenopauseSymptomsArticles = [
  ArticleEntry(
    title: 'Heart Palpitations in Perimenopause: When to Get Help',
    image: 'assets/perimenopause_symptoms/heart_palpitations.png',
  ),
  ArticleEntry(
    title: 'How Long Is Too Long for a Period During Perimenopause?',
    image: 'assets/perimenopause_symptoms/long_period.png',
  ),
  ArticleEntry(
    title:
        'Perimenopause Cramps: Why Do They Happen, and How Can You Ease Them?',
    image: 'assets/perimenopause_symptoms/cramps.png',
  ),
  ArticleEntry(
    title: 'Perimenopause Headaches: Why They Happen and How to Cope',
    image: 'assets/perimenopause_symptoms/headaches.png',
  ),
  ArticleEntry(
    title: "What's the Deal With Perimenopause and Body Odor?",
    image: 'assets/perimenopause_symptoms/body_odor.png',
  ),
];

const List<ArticleEntry> _perimenopauseMoreArticles = [
  ArticleEntry(
    title: 'Myths and Truths About Pregnancy During Perimenopause',
    image: 'assets/perimenopause_more/pregnancy_myths.png',
  ),
  ArticleEntry(
    title: 'Perimenopause Joint Pain: Why It Happens and How to Soothe It',
    image: 'assets/perimenopause_more/joint_pain.png',
  ),
  ArticleEntry(
    title: 'Signs You Might Be Reaching the End of Perimenopause',
    image: 'assets/perimenopause_more/end_of_perimenopause.png',
  ),
  ArticleEntry(
    title: "What Are the Signs You're Still Ovulating in Perimenopause?",
    image: 'assets/perimenopause_more/still_ovulating.png',
  ),
];

/// "Symptoms" -- a subsection shown under the perimenopause Health Library.
class PerimenopauseSymptomsSection extends StatelessWidget {
  const PerimenopauseSymptomsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Symptoms',
      articles: _perimenopauseSymptomsArticles,
    );
  }
}

/// "More on Perimenopause" -- a subsection shown next to Symptoms in the
/// perimenopause stage.
class PerimenopauseMoreSection extends StatelessWidget {
  const PerimenopauseMoreSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'More on Perimenopause',
      articles: _perimenopauseMoreArticles,
    );
  }
}
