import 'package:flutter/material.dart';

import 'article_subsection.dart';

/// Curated illustrated subsections shown under the trying-to-conceive stage's
/// Health Library.
///
/// Renders through the shared [ArticleSubsection] -- small cards in a
/// horizontal, left-to-right scrolling row with the title below each image,
/// tapping one opens [ArticleDetailPage]. The subsection names and titles come
/// from the source folder and image names.

const List<ArticleEntry> _fertilityArticles = [
  ArticleEntry(
    title: 'Can You Get Pregnant Without a Period?',
    image: 'assets/ttc_fertility/pregnant_without_period.png',
  ),
  ArticleEntry(
    title: 'Female Infertility: How to Spot the Signs and What to Do Next',
    image: 'assets/ttc_fertility/female_infertility.png',
  ),
  ArticleEntry(
    title: 'How Old Is Too Old to Have a Baby?',
    image: 'assets/ttc_fertility/too_old_baby.png',
  ),
  ArticleEntry(
    title: 'How Soon Can You Get Pregnant After Giving Birth?',
    image: 'assets/ttc_fertility/pregnant_after_birth.png',
  ),
];

const List<ArticleEntry> _ovulationArticles = [
  ArticleEntry(
    title: 'Can You Get Pregnant Two Days After Ovulation?',
    image: 'assets/ttc_ovulation/two_days_after_ovulation.png',
  ),
  ArticleEntry(
    title: 'Understanding Ovulation When You Stop Taking Birth Control',
    image: 'assets/ttc_ovulation/ovulation_after_birth_control.png',
  ),
  ArticleEntry(
    title: 'What Does a Positive Ovulation Test Look Like?',
    image: 'assets/ttc_ovulation/positive_ovulation_test.png',
  ),
];

const List<ArticleEntry> _sexToConceiveArticles = [
  ArticleEntry(
    title: 'Chances of Getting Pregnant With Woman On Top: The Science',
    image: 'assets/ttc_sex/woman_on_top.png',
  ),
  ArticleEntry(
    title: 'How Often Should You Have Sex to Conceive?',
    image: 'assets/ttc_sex/how_often_sex.png',
  ),
  ArticleEntry(
    title: 'What Is Precum, and Can It Get You Pregnant?',
    image: 'assets/ttc_sex/precum.png',
  ),
];

/// "Fertility" -- a subsection under the trying-to-conceive Health Library.
class TtcFertilitySection extends StatelessWidget {
  const TtcFertilitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Fertility',
      articles: _fertilityArticles,
    );
  }
}

/// "Ovulation Tracking" -- a subsection next to Fertility.
class TtcOvulationSection extends StatelessWidget {
  const TtcOvulationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Ovulation Tracking',
      articles: _ovulationArticles,
    );
  }
}

/// "Sex to get pregnant" -- a subsection next to Ovulation Tracking.
class TtcSexToConceiveSection extends StatelessWidget {
  const TtcSexToConceiveSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Sex to get pregnant',
      articles: _sexToConceiveArticles,
    );
  }
}
