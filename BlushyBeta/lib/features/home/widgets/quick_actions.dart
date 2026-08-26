import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';
import '../../../core/state.dart';

class BlushyQuickActions extends StatelessWidget {
  const BlushyQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    final rankedActions = AdaptiveActionRanker.rankActions(
      state.personalContext,
      state.wellbeingState,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'SUGGESTED ACTIONS',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rankedActions.map((act) {
              return _buildActionButton(context, act.label, act.icon);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon) {
    return GestureDetector(
      onTap: () {},
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: BlushyColors.cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: BlushyColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: BlushyColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: BlushyColors.dark,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: BlushyColors.text,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
