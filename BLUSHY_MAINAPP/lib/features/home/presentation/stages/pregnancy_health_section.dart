import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/colors.dart';

/// One curated read in the pregnancy stage's "Pregnancy health" subsection.
///
/// Each entry pairs a full-width illustration with its title. The titles come
/// from the source image names and are rendered on the card; the images live in
/// `assets/pregnancy_health/`.
class _PregnancyHealthArticle {
  const _PregnancyHealthArticle({required this.title, required this.image});

  final String title;
  final String image;
}

const List<_PregnancyHealthArticle> _pregnancyHealthArticles = [
  _PregnancyHealthArticle(
    title: "10 Things You Can't Do While Pregnant",
    image: 'assets/pregnancy_health/10_things_to_avoid.png',
  ),
  _PregnancyHealthArticle(
    title: 'Chlamydia During Pregnancy: What Moms Need to Know',
    image: 'assets/pregnancy_health/chlamydia_pregnancy.png',
  ),
  _PregnancyHealthArticle(
    title:
        'Hair Loss During Pregnancy: How to Take Care of Hair Loss in Pregnancy',
    image: 'assets/pregnancy_health/hair_loss_pregnancy.png',
  ),
  _PregnancyHealthArticle(
    title: 'Pregnant Belly: What to Expect From Your Growing Baby Bump',
    image: 'assets/pregnancy_health/pregnant_belly.png',
  ),
  _PregnancyHealthArticle(
    title: 'Smoking and Breastfeeding: To Quit or Not to Quit',
    image: 'assets/pregnancy_health/smoking_breastfeeding.png',
  ),
];

/// "Pregnancy health" -- a subsection shown under the pregnancy Health Library.
///
/// Renders the curated illustrations as small cards in a horizontal, left-to-
/// right scrolling row, each with its title below the image. Tapping a card
/// opens [PregnancyHealthArticlePage], which shows the title, the photo and
/// (until the copy is written) a placeholder body.
class PregnancyHealthSection extends StatelessWidget {
  const PregnancyHealthSection({super.key});

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
              'Pregnancy health',
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
            itemCount: _pregnancyHealthArticles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                _PregnancyHealthCard(article: _pregnancyHealthArticles[i]),
          ),
        ),
      ],
    );
  }
}

class _PregnancyHealthCard extends StatelessWidget {
  const _PregnancyHealthCard({required this.article});

  final _PregnancyHealthArticle article;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PregnancyHealthArticlePage(
              title: article.title,
              image: article.image,
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

/// The article page opened from a "Pregnancy health" card.
///
/// Title at the top, the illustration below it, then the body. The body is a
/// deliberate placeholder until the copy is written.
class PregnancyHealthArticlePage extends StatelessWidget {
  const PregnancyHealthArticlePage({
    super.key,
    required this.title,
    required this.image,
  });

  final String title;
  final String image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        elevation: 0,
        foregroundColor: BlushyColors.text,
        title: Text(
          'Pregnancy health',
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
