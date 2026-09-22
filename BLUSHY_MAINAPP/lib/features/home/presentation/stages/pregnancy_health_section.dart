import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/colors.dart';

/// One curated read in a pregnancy-stage subsection.
///
/// Each entry pairs an illustration with its title. The titles come from the
/// source image names; the images live under `assets/pregnancy_health/` and
/// `assets/pregnancy_lifestyle/`.
class _PregnancyArticle {
  const _PregnancyArticle({required this.title, required this.image});

  final String title;
  final String image;
}

const List<_PregnancyArticle> _pregnancyHealthArticles = [
  _PregnancyArticle(
    title: "10 Things You Can't Do While Pregnant",
    image: 'assets/pregnancy_health/10_things_to_avoid.png',
  ),
  _PregnancyArticle(
    title: 'Chlamydia During Pregnancy: What Moms Need to Know',
    image: 'assets/pregnancy_health/chlamydia_pregnancy.png',
  ),
  _PregnancyArticle(
    title:
        'Hair Loss During Pregnancy: How to Take Care of Hair Loss in Pregnancy',
    image: 'assets/pregnancy_health/hair_loss_pregnancy.png',
  ),
  _PregnancyArticle(
    title: 'Pregnant Belly: What to Expect From Your Growing Baby Bump',
    image: 'assets/pregnancy_health/pregnant_belly.png',
  ),
  _PregnancyArticle(
    title: 'Smoking and Breastfeeding: To Quit or Not to Quit',
    image: 'assets/pregnancy_health/smoking_breastfeeding.png',
  ),
];

const List<_PregnancyArticle> _pregnancyLifestyleArticles = [
  _PregnancyArticle(
    title:
        'Drinks for Pregnant Women: What Can You Drink While Pregnant, and What Should You Avoid',
    image: 'assets/pregnancy_lifestyle/drinks_pregnancy.png',
  ),
  _PregnancyArticle(
    title:
        "Healthy Pregnancy Diet: What Food Is and Isn't Safe to Eat During Pregnancy",
    image: 'assets/pregnancy_lifestyle/healthy_diet.png',
  ),
  _PregnancyArticle(
    title: 'How to Cope With Pregnancy Insomnia',
    image: 'assets/pregnancy_lifestyle/cope_insomnia.png',
  ),
  _PregnancyArticle(
    title:
        'How to Sleep When Pregnant: Your Guide to Good Sleep for Each Trimester',
    image: 'assets/pregnancy_lifestyle/sleep_when_pregnant.png',
  ),
  _PregnancyArticle(
    title: 'Pregnancy Sex Guide: Sex Positions During Pregnancy',
    image: 'assets/pregnancy_lifestyle/sex_guide.png',
  ),
];

/// "Pregnancy health" -- a subsection shown under the pregnancy Health Library.
class PregnancyHealthSection extends StatelessWidget {
  const PregnancyHealthSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PregnancySubsection(
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
    return const _PregnancySubsection(
      title: 'Pregnancy Lifestyle',
      articles: _pregnancyLifestyleArticles,
    );
  }
}

/// A titled subsection that renders its articles as small cards in a
/// horizontal, left-to-right scrolling row, each with its title below the
/// image. Tapping a card opens [PregnancyArticlePage], which shows the title,
/// the photo and (until the copy is written) a placeholder body.
class _PregnancySubsection extends StatelessWidget {
  const _PregnancySubsection({required this.title, required this.articles});

  final String title;
  final List<_PregnancyArticle> articles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: BlushyColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: BlushyColors.text,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Small cards, scrolling left to right.
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            itemCount: articles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                _PregnancyCard(article: articles[i], sectionLabel: title),
          ),
        ),
      ],
    );
  }
}

class _PregnancyCard extends StatelessWidget {
  const _PregnancyCard({required this.article, required this.sectionLabel});

  final _PregnancyArticle article;
  final String sectionLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PregnancyArticlePage(
              title: article.title,
              image: article.image,
              sectionLabel: sectionLabel,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 144,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image on top.
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                article.image,
                width: 144,
                height: 88,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            // Title below the image.
            Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: BlushyColors.text,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The article page opened from a pregnancy subsection card.
///
/// Title at the top, the illustration below it, then the body. The body is a
/// deliberate placeholder until the copy is written.
class PregnancyArticlePage extends StatelessWidget {
  const PregnancyArticlePage({
    super.key,
    required this.title,
    required this.image,
    required this.sectionLabel,
  });

  final String title;
  final String image;
  final String sectionLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        elevation: 0,
        foregroundColor: BlushyColors.text,
        title: Text(
          sectionLabel,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title at the top.
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: BlushyColors.text,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              // Photo below the title.
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  image,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              // Content -- not written yet.
              Text(
                'Content not added',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: BlushyColors.secondaryText,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
