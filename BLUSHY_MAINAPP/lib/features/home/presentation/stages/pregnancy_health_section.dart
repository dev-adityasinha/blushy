import 'package:flutter/material.dart';

import 'article_subsection.dart';

/// The curated illustrated subsections shown under the pregnancy stage's
/// Health Library: Pregnancy health, Pregnancy Lifestyle and Fetal Development.
///
/// Each renders through the shared [ArticleSubsection] -- small cards in a
/// horizontal, left-to-right scrolling row with the title below each image,
/// tapping one opens [ArticleDetailPage]. The article titles come from the
/// source image names.

const List<ArticleEntry> _pregnancyHealthArticles = [
  ArticleEntry(
    title: "10 Things You Can't Do While Pregnant",
    image: 'assets/pregnancy_health/10_things_to_avoid.png',
  ),
  ArticleEntry(
    title: 'Chlamydia During Pregnancy: What Moms Need to Know',
    image: 'assets/pregnancy_health/chlamydia_pregnancy.png',
  ),
  ArticleEntry(
    title:
        'Hair Loss During Pregnancy: How to Take Care of Hair Loss in Pregnancy',
    image: 'assets/pregnancy_health/hair_loss_pregnancy.png',
  ),
  ArticleEntry(
    title: 'Pregnant Belly: What to Expect From Your Growing Baby Bump',
    image: 'assets/pregnancy_health/pregnant_belly.png',
  ),
  ArticleEntry(
    title: 'Smoking and Breastfeeding: To Quit or Not to Quit',
    image: 'assets/pregnancy_health/smoking_breastfeeding.png',
  ),
];

const List<ArticleEntry> _pregnancyLifestyleArticles = [
  ArticleEntry(
    title:
        'Drinks for Pregnant Women: What Can You Drink While Pregnant, and What Should You Avoid',
    image: 'assets/pregnancy_lifestyle/drinks_pregnancy.png',
  ),
  ArticleEntry(
    title:
        "Healthy Pregnancy Diet: What Food Is and Isn't Safe to Eat During Pregnancy",
    image: 'assets/pregnancy_lifestyle/healthy_diet.png',
  ),
  ArticleEntry(
    title: 'How to Cope With Pregnancy Insomnia',
    image: 'assets/pregnancy_lifestyle/cope_insomnia.png',
  ),
  ArticleEntry(
    title:
        'How to Sleep When Pregnant: Your Guide to Good Sleep for Each Trimester',
    image: 'assets/pregnancy_lifestyle/sleep_when_pregnant.png',
  ),
  ArticleEntry(
    title: 'Pregnancy Sex Guide: Sex Positions During Pregnancy',
    image: 'assets/pregnancy_lifestyle/sex_guide.png',
  ),
];

const List<ArticleEntry> _fetalDevelopmentArticles = [
  ArticleEntry(
    title: 'Cryptic Pregnancy: How Can You Be Pregnant and Not Know?',
    image: 'assets/fetal_development/cryptic_pregnancy.png',
  ),
  ArticleEntry(
    title: 'Fetal Brain Development Stages: When Does a Fetus Develop a Brain?',
    image: 'assets/fetal_development/fetal_brain_development.png',
  ),
  ArticleEntry(
    title:
        'How Long Is Pregnancy: The Weeks, Months, and Trimesters in Full-Term Pregnancy Explained',
    image: 'assets/fetal_development/how_long_pregnancy.png',
  ),
  ArticleEntry(
    title: "What to Expect When You're Pregnant with Triplets",
    image: 'assets/fetal_development/triplets.png',
  ),
  ArticleEntry(
    title: 'When Can a Fetus Hear? A Guide to Hearing Development in the Womb',
    image: 'assets/fetal_development/fetus_hearing.png',
  ),
];

/// "Pregnancy health" -- a subsection shown under the pregnancy Health Library.
class PregnancyHealthSection extends StatelessWidget {
  const PregnancyHealthSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Pregnancy health',
      articles: _pregnancyHealthArticles,
    );
  }
}

/// "Pregnancy Lifestyle" -- a subsection shown next to Pregnancy health.
class PregnancyLifestyleSection extends StatelessWidget {
  const PregnancyLifestyleSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Pregnancy Lifestyle',
      articles: _pregnancyLifestyleArticles,
    );
  }
}

/// "Fetal Development" -- a subsection shown next to Pregnancy Lifestyle.
class FetalDevelopmentSection extends StatelessWidget {
  const FetalDevelopmentSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleSubsection(
      title: 'Fetal Development',
      articles: _fetalDevelopmentArticles,
    );
  }
}
