import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';
import '../../../models/community_models.dart';
import '../../../services/api_community_service.dart';
import '../../community/post_detail_screen.dart';

class BlushyCommunitySection extends StatelessWidget {
  const BlushyCommunitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardPersonalizedCommunityPayload>(
      future: ApiCommunityService().getDashboardPersonalizedFeed(),
      builder: (context, snapshot) {
        final payload = snapshot.data;
        final isPersonalized = payload?.isPersonalized ?? false;
        final fallbackLabel = payload?.fallbackLabel ?? (isPersonalized ? "Recommended for your cycle" : "Popular in the community");

        final List<CommunityPost> posts = payload != null
            ? (payload.trending.isNotEmpty ? payload.trending : payload.questions)
            : [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Community Spotlight',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.text,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPersonalized
                          ? BlushyColors.primary.withValues(alpha: 0.1)
                          : const Color(0xFFF0EAE1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPersonalized ? "✨ AI Personalized" : "✨ $fallbackLabel",
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isPersonalized ? BlushyColors.primary : BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Horizontal scroll slider
            SizedBox(
              height: 200,
              child: snapshot.connectionState == ConnectionState.waiting && payload == null
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : posts.isEmpty
                      ? Center(
                          child: Text(
                            "No community posts yet.",
                            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          itemCount: posts.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            return _buildCommunityCard(context, post);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommunityCard(BuildContext context, CommunityPost post) {
    final tagLabel = post.tags.isNotEmpty ? post.tags.first.toUpperCase() : post.postType.toUpperCase();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: post),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 290,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BlushyColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BlushyColors.border),
          boxShadow: const [
            BoxShadow(
              color: BlushyColors.shadow,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tagLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.primary,
                      letterSpacing: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  post.authorName,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title.isNotEmpty ? post.title : post.text,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: BlushyColors.text,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              post.text,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: BlushyColors.secondaryText,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            const Divider(color: BlushyColors.border, height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 12, color: BlushyColors.secondaryText),
                    const SizedBox(width: 2),
                    Text(
                      "${post.score} votes",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.accent,
                      ),
                    ),
                  ],
                ),
                Text(
                  "${post.commentCount} comments",
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: BlushyColors.secondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
