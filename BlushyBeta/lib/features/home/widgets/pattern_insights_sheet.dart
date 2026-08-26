import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';
import '../../../core/state.dart';

class BlushyPatternInsightsSheet extends StatelessWidget {
  const BlushyPatternInsightsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    
    return Container(
      decoration: const BoxDecoration(
        color: BlushyColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BlushyColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Pattern Insights',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.text,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Based on your data, Sia has observed the following patterns:',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              _buildInsightItem(
                icon: Icons.nightlight_round,
                title: 'Sleep Disruptions',
                description: 'Your sleep quality tends to decrease during the late Luteal phase.',
              ),
              const SizedBox(height: 16),
              _buildInsightItem(
                icon: Icons.bolt,
                title: 'Energy Peaks',
                description: 'You often report high energy during the early Follicular phase.',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightItem({required IconData icon, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BlushyColors.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: BlushyColors.border),
          ),
          child: Icon(icon, color: BlushyColors.dark, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
