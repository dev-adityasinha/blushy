import 'package:flutter/material.dart';
import '../core/theme.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Header
          Text(
            'Explore Knowledge',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 34,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Curated medical research, anonymous stories, and guidelines compiled by Sia.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Search Bar (Notion Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: BlushyColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BlushyColors.border),
            ),
            child: Row(
              children: const [
                Icon(Icons.search_rounded, color: BlushyColors.textLight, size: 20),
                SizedBox(width: 12),
                Text(
                  'Search medical papers, stories, guides...',
                  style: TextStyle(color: BlushyColors.textLight, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Peer Stories (Anonymous Stories)
          Text(
            'Anonymous Stories',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildStoryCard(
                  context,
                  'Sleep Architecture & Luteal Fatigue',
                  '“I used to think my fatigue was just laziness. Learning about core temperature shifts during Day 15-22 completely changed how I plan my work weeks.”',
                  '— Anonymous, 29',
                ),
                const SizedBox(width: 16),
                _buildStoryCard(
                  context,
                  'Progesterone Anxiety Spikes',
                  '“Tracking hormone-related cortisol changes allowed me to explain to my partner why I needed quiet space on Day 20. It saved us so much friction.”',
                  '— Anonymous, 32',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Education & Research Articles
          Text(
            'Curated Research',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          _buildResearchItem(
            context,
            'METABOLIC FOCUS',
            'Nutritional Support for Luteal Pacing',
            'How shifting macro ratios to complex carbohydrates and zinc offsets progesterone-induced glucose fluctuations.',
            '6 min read • Verified by Dr. Aris',
          ),
          const SizedBox(height: 16),
          _buildResearchItem(
            context,
            'NEUROSCIENCE',
            'Sleep Architecture Under Elevated Progesterone',
            'A review of polysomnography findings during the mid-luteal phase showing reductions in restorative delta wave generation.',
            '9 min read • Harvard Medical Review',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStoryCard(BuildContext context, String title, String quote, String author) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BlushyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: BlushyColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              quote,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: BlushyColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            author,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: BlushyColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResearchItem(BuildContext context, String tag, String title, String excerpt, String meta) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BlushyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tag,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: BlushyColors.accent,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            excerpt,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const Divider(color: BlushyColors.border, height: 24),
          Text(
            meta,
            style: const TextStyle(
              fontSize: 11,
              color: BlushyColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
