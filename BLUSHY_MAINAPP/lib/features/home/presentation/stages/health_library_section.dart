import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/colors.dart';
import 'stage_shared_components.dart';

/// A "Health Library" section for a stage's home page.
///
/// Shows a few curated reads for the current stage with a "See all" that opens
/// the full library. The content comes from [getStageCuratedArticles] -- the
/// same per-stage source the existing article modals use -- so a stage's home
/// preview and its full library never drift apart. Tapping a card opens the
/// article via [showArticleDetailDialog]; "See all" opens [showAllArticlesModal].
///
/// One shared widget so the section looks and behaves identically on every
/// stage, and adding it to a stage is a single line.
class HealthLibrarySection extends StatelessWidget {
  const HealthLibrarySection({
    super.key,
    required this.stageKey,
    this.previewCount = 3,
  });

  /// The life stage whose curated reads to show (e.g. 'hormonalHealth').
  final String stageKey;

  /// How many articles to preview before "See all".
  final int previewCount;

  @override
  Widget build(BuildContext context) {
    final all = getStageCuratedArticles(stageKey);
    if (all.isEmpty) return const SizedBox.shrink();
    final preview = all.take(previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitleWithFilledIcon(
          icon: Icons.menu_book_rounded,
          title: 'Health Library',
          subtitle: 'Curated reads for your stage',
          trailing: all.length > previewCount
              ? TextButton(
                  onPressed: () => showAllArticlesModal(context, stageKey),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'See all',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.primary,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < preview.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _ArticleCard(article: preview[i]),
        ],
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final Map<String, dynamic> article;

  @override
  Widget build(BuildContext context) {
    final accent = (article['accentColor'] as Color?) ?? BlushyColors.primary;
    final bg = (article['bgColor'] as Color?) ?? Colors.white;
    final icon = (article['icon'] as IconData?) ?? Icons.article_rounded;
    final title = (article['title'] as String?) ?? '';
    final category = (article['category'] as String?) ?? '';
    final readTime = (article['readTime'] as String?) ?? '';
    final summary = (article['summary'] as String?) ?? '';

    return InkWell(
      onTap: () => showArticleDetailDialog(context, title, summary),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEFE8E0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category.isNotEmpty)
                    Text(
                      category,
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: accent,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.text,
                      height: 1.25,
                    ),
                  ),
                  if (readTime.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      readTime,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF9E9296)),
          ],
        ),
      ),
    );
  }
}
