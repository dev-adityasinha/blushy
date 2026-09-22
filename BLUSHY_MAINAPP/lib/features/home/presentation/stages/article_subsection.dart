import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/colors.dart';

/// One curated read in a stage subsection: an illustration paired with a title.
///
/// The titles come from the source image names; the images live under
/// per-subsection folders in `assets/` (e.g. `assets/pregnancy_health/`).
class ArticleEntry {
  const ArticleEntry({required this.title, required this.image});

  final String title;
  final String image;
}

/// A titled subsection that renders its [articles] as small cards in a
/// horizontal, left-to-right scrolling row, each with its title below the
/// image.
///
/// Tapping a card opens [ArticleDetailPage], which shows the title, the photo
/// and (until the copy is written) a "Content not added" placeholder body.
/// Shared by every stage that lists curated illustrated reads.
class ArticleSubsection extends StatelessWidget {
  const ArticleSubsection({
    super.key,
    required this.title,
    required this.articles,
  });

  final String title;
  final List<ArticleEntry> articles;

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
                _ArticleCard(article: articles[i], sectionLabel: title),
          ),
        ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.sectionLabel});

  final ArticleEntry article;
  final String sectionLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArticleDetailPage(
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

/// The article page opened from a subsection card.
///
/// Title at the top, the illustration below it, then the body. The body is a
/// deliberate placeholder until the copy is written.
class ArticleDetailPage extends StatelessWidget {
  const ArticleDetailPage({
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
