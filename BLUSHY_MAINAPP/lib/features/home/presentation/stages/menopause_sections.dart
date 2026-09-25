import 'package:flutter/material.dart';

import 'article_subsection.dart';

/// Curated illustrated subsections shown under the menopause stage's Health
/// Library.
///
/// Renders through the shared [ArticleSubsection] -- small cards in a
/// horizontal, left-to-right scrolling row with the title below each image,
/// tapping one opens [ArticleDetailPage]. The titles come from the source image
/// names.

const List<ArticleEntry> _menopauseChangesArticles = [
  ArticleEntry(
    title: 'Can Menopause Cause Nausea?',
    image: 'assets/menopause_changes/nausea.png',
  ),
  ArticleEntry(
    title:
        "Can Your Sex Drive Return After Menopause? Here's What You Should Know",
    image: 'assets/menopause_changes/sex_drive.png',
  ),
  ArticleEntry(
    title: "Genitourinary Syndrome of Menopause: Let's Break It Down",
    image: 'assets/menopause_changes/gsm.png',
  ),
];

const List<ArticleEntry> _menopauseMoreArticles = [
  ArticleEntry(
    title: 'Can Menopause Cause a Burning Sensation in Your Body?',
    image: 'assets/menopause_more/burning_sensation.png',
  ),
  ArticleEntry(
    title: "Perimenopause vs Menopause: What's the Difference?",
    image: 'assets/menopause_more/peri_vs_meno.png',
  ),
];

/// "Changes" -- a subsection shown under the menopause Health Library.
class MenopauseChangesSection extends StatelessWidget {
  const MenopauseChangesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Changes',
      articles: _menopauseChangesArticles,
    );
  }
}

/// "More on Menopause" -- a subsection shown next to Changes in the menopause
/// stage.
class MenopauseMoreSection extends StatelessWidget {
  const MenopauseMoreSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'More on Menopause',
      articles: _menopauseMoreArticles,
    );
  }
}
