import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';
import '../../../core/state.dart';

class BlushyNextPeriodCard extends StatelessWidget {
  const BlushyNextPeriodCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    final pc = state.personalContext;

    if (pc.trackingPreference == CycleTrackingPreference.disabled || pc.lifeContexts.contains(LifeContext.menopause)) {
      return const SizedBox.shrink();
    }

    String header = 'UPCOMING CYCLE';
    String title = 'Your next cycle is expected around August 2';
    String description = 'We\'ll keep updating this estimate as we learn more about your cycle.';
    String buttonText = 'Adjust Cycle Data';

    if (pc.lifeContexts.contains(LifeContext.pregnancy)) {
      header = 'PREGNANCY WELLBEING';
      title = 'Focus on your changing body & nutrition';
      description = 'Your regular cycle tracking is paused. Sia is adapting insights for your pregnancy.';
      buttonText = 'Manage Pregnancy Info';
    } else if (pc.lifeContexts.contains(LifeContext.postpartum)) {
      header = 'POSTPARTUM RECOVERY';
      title = 'Prioritize sleep, recovery & hydration';
      description = 'We are adapting content for your postpartum healing. No standard cycle assumptions are made.';
      buttonText = 'Log Wellbeing Baseline';
    } else if (pc.confidence == DataConfidence.low) {
      header = 'CYCLE LEARNING STATE';
      title = 'We\'re still learning your patterns';
      description = 'As you log more periods and symptoms over time, our confidence will increase to show predictions.';
      buttonText = 'Log Today\'s Symptoms';
    }

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
          Text(
            header,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: BlushyColors.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: BlushyColors.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: BlushyColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                buttonText,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

