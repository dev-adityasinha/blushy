import 'package:flutter/material.dart';

import 'article_subsection.dart';

/// Curated illustrated subsections shown under the first-period-started stage's
/// Health Library.
///
/// Renders through the shared [ArticleSubsection] -- small cards in a
/// horizontal, left-to-right scrolling row with the title below each image,
/// tapping one opens [ArticleDetailPage]. The titles come from the source image
/// names.

const List<ArticleEntry> _periodArticles = [
  ArticleEntry(
    title: 'Can You Make Your Period End Faster?',
    image: 'assets/period_started/period_end_faster.png',
  ),
  ArticleEntry(
    title: 'Can You Stop Your Period for a Night?',
    image: 'assets/period_started/stop_period_night.png',
  ),
  ArticleEntry(
    title: 'Period Blood Clots: What They Look Like and When to See a Doctor',
    image: 'assets/period_started/blood_clots.png',
  ),
  ArticleEntry(
    title: 'Why Am I So Tired Before My Period?',
    image: 'assets/period_started/tired_before_period.png',
  ),
  ArticleEntry(
    title: "Why Do I Have a Late Period If I'm Not Pregnant?",
    image: 'assets/period_started/late_period.png',
  ),
];

const List<ArticleEntry> _periodSymptomsArticles = [
  ArticleEntry(
    title: 'Could You Have HPV? Your Questions Answered',
    image: 'assets/period_symptoms/hpv.png',
  ),
  ArticleEntry(
    title: 'Does Endometriosis Cause Ovulation Pain?',
    image: 'assets/period_symptoms/endometriosis_ovulation_pain.png',
  ),
  ArticleEntry(
    title: 'No Discharge, Just Itchy: Causes of Vaginal & Vulval Itching',
    image: 'assets/period_symptoms/itchy.png',
  ),
  ArticleEntry(
    title: 'What Causes Spotting: The Lowdown on Bleeding Between Periods',
    image: 'assets/period_symptoms/spotting.png',
  ),
  ArticleEntry(
    title: 'Yeast Infection vs. UTI: How to Tell the Difference',
    image: 'assets/period_symptoms/yeast_vs_uti.png',
  ),
];

const List<ArticleEntry> _periodCrampArticles = [
  ArticleEntry(
    title: '6 Foods That Help with Cramps',
    image: 'assets/period_cramp/foods_for_cramps.png',
  ),
  ArticleEntry(
    title: 'Cramps After Period: What It Could Mean',
    image: 'assets/period_cramp/cramps_after_period.png',
  ),
];

/// "Health" -- a subsection shown under the first-period-started Health Library.
class FirstPeriodHealthSection extends StatelessWidget {
  const FirstPeriodHealthSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Health',
      articles: _periodArticles,
    );
  }
}

/// "Symptoms" -- a subsection shown next to Health in the first-period stage.
class FirstPeriodSymptomsSection extends StatelessWidget {
  const FirstPeriodSymptomsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Symptoms',
      articles: _periodSymptomsArticles,
    );
  }
}

/// "Cramp" -- a subsection shown next to Symptoms in the first-period stage.
class FirstPeriodCrampSection extends StatelessWidget {
  const FirstPeriodCrampSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Cramp',
      articles: _periodCrampArticles,
    );
  }
}
