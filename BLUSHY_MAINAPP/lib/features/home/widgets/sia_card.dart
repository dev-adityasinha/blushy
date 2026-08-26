import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';

class BlushySiaCard extends StatelessWidget {
  const BlushySiaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          // Headline: Sia noticed something
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: BlushyColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sia noticed increased fatigue',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // One sentence insight
          Text(
            'Your recent sleep and hormonal changes may explain today\'s lower energy.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BlushyColors.text,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),

          // One sentence explaining why
          Text(
            'Coinciding with a 5.7h sleep deficit and entering your luteal phase, recovery is recommended.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: BlushyColors.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Two or three action buttons
          Row(
            children: [
              _buildSmallActionButton(context, 'Explain', () {}),
              const SizedBox(width: 8),
              _buildSmallActionButton(context, 'Recovery Plan', () {}, isPrimary: true),
              const SizedBox(width: 8),
              _buildSmallActionButton(context, 'Talk to Sia', () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionButton(BuildContext context, String label, VoidCallback onTap, {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? BlushyColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? BlushyColors.primary : BlushyColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isPrimary ? Colors.white : BlushyColors.text,
          ),
        ),
      ),
    );
  }
}
