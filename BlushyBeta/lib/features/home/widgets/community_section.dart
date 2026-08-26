import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';

class BlushyCommunitySection extends StatelessWidget {
  const BlushyCommunitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Recommended For You',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: BlushyColors.text,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Horizontal scroll slider
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            children: [
              _buildCommunityCard(
                context,
                'LUTEAL PHASE CONTEXT',
                'Managing Cortisol & Luteal Fatigue',
                'Recommended because you\'re entering the luteal phase.',
                'Popular among women with similar symptoms.',
                'Doctor reviewed • 5 min read',
              ),
              const SizedBox(width: 16),
              _buildCommunityCard(
                context,
                'SLEEP LEDGER',
                'Sleep Architecture & Core Temp Control',
                'Recommended due to recent 5.7h sleep logs.',
                'Targeting temperature spikes in your sleep cycle.',
                'Science backed • 4 min read',
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityCard(
    BuildContext context,
    String tag,
    String title,
    String contextWhyLabel,
    String subtitle,
    String statsLabel,
  ) {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BlushyColors.cardBg,
        borderRadius: BorderRadius.circular(24),
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
                  tag,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: BlushyColors.primary,
                    letterSpacing: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: BlushyColors.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
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
              Expanded(
                child: Text(
                  contextWhyLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                statsLabel,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: BlushyColors.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
