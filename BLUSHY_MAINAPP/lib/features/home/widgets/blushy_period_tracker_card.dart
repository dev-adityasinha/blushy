import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cycle_tracker_image.dart';

/// The canonical Blushy Period & Cycle Tracker Card as defined in Stage 2 (Period Started).
/// Reusable across all stages to maintain unified brand aesthetics and behavior.
class BlushyPeriodTrackerCard extends StatelessWidget {
  final int currentCycleDay;
  final int cycleLength;
  final int periodLength;
  final bool hasLoggedPeriod;
  final String currentPhaseName;
  final VoidCallback onTapLogPeriod;

  /// What tapping the tracker drawing itself does.
  ///
  /// Null keeps the old behaviour -- the date picker -- which is right for a
  /// stage with no phase to explain. Where there is one, pass something that
  /// explains it: tapping a picture of where she is in her cycle should not
  /// ask her to log a period she has already logged.
  final VoidCallback? onTapTracker;
  final VoidCallback? onTapInsights;
  final String? customDisclaimer;
  final String? customDayLabel;
  final String? customDayValue;
  final String? customSubtitle;
  final Color? customPhaseColor;

  static const Color blushyPrimary = Color(0xFFDD0D22);
  static const Color cardBorderColor = Color(0xFFEFE8E0);

  /// The current phase's colour, matched to the tracker arc and the legend
  /// (Menstrual red, Follicular orange, Ovulation yellow, Luteal purple) using
  /// the same day thresholds the painter draws with, so the "Day N" number
  /// reads in the phase colour.
  Color get _phaseColor {
    if (customPhaseColor != null) return customPhaseColor!;
    if (currentCycleDay <= periodLength) return const Color(0xFFEF4444);
    if (currentCycleDay <= periodLength + 9) return const Color(0xFFF97316);
    if (currentCycleDay <= periodLength + 11) return const Color(0xFFFACC15);
    return const Color(0xFF7C3AED);
  }

  const BlushyPeriodTrackerCard({
    super.key,
    required this.currentCycleDay,
    required this.cycleLength,
    required this.periodLength,
    required this.hasLoggedPeriod,
    required this.currentPhaseName,
    required this.onTapLogPeriod,
    this.onTapTracker,
    this.onTapInsights,
    this.customDisclaimer,
    this.customDayLabel,
    this.customDayValue,
    this.customSubtitle,
    this.customPhaseColor,
  });

  @override
  Widget build(BuildContext context) {
    final int daysLeft = (cycleLength - currentCycleDay).clamp(0, cycleLength);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top Row: Log Period Action Button aligned right
          Align(
            alignment: Alignment.topRight,
            child: InkWell(
              onTap: onTapLogPeriod,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF3D5D8), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.water_drop_outlined,
                      size: 13,
                      color: blushyPrimary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasLoggedPeriod ? 'Log your period' : '+ Log your period',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: blushyPrimary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: blushyPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Day Count & Phase Title (Large, catchy Day in Cormorant & clean modern digit)
          if (hasLoggedPeriod) ...[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: customDayLabel ?? 'Day ',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF221510),
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: customDayValue ?? '$currentCycleDay',
                    style: GoogleFonts.manrope(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: _phaseColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              currentPhaseName,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF221510),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            if (customSubtitle != null)
              Text(
                customSubtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF7A6B72),
                ),
              )
            else
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Next cycle begins in ',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF7A6B72),
                      ),
                    ),
                    TextSpan(
                      text: '$daysLeft Days',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF221510),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Day ',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF9E9296),
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: '--',
                    style: GoogleFonts.manrope(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF9E9296),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'No period logged yet',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF7A6B72),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: onTapLogPeriod,
              child: Text(
                'Log your period to track your cycle & fertile phases',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: blushyPrimary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // The Fallopian Tube Track Custom Painter
          ExactBlushyTrackerWidget(
            currentDay: currentCycleDay,
            cycleLength: cycleLength,
            periodLength: periodLength,
            isLogged: hasLoggedPeriod,
            onTap: onTapTracker ?? onTapLogPeriod,
          ),
          const SizedBox(height: 12),

          // Medical Disclaimer
          Text(
            customDisclaimer ??
                (hasLoggedPeriod
                    ? 'Estimated ovulation based on 28-day baseline. Not medically certain.'
                    : 'Blushy cycle tracker uses your logged period dates to estimate phases.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF7A6B72),
            ),
          ),
          const SizedBox(height: 10),

          // 4-Phase Dot Legend (Canonical Stage 2: Menstrual, Follicular, Ovulation, Luteal)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPhaseDot(const Color(0xFFEF4444), 'Menstrual'),
                const SizedBox(width: 12),
                _buildPhaseDot(const Color(0xFFF97316), 'Follicular'),
                const SizedBox(width: 12),
                _buildPhaseDot(const Color(0xFFFACC15), 'Ovulation'),
                const SizedBox(width: 12),
                _buildPhaseDot(const Color(0xFF7C3AED), 'Luteal'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFECE4DC)),
          const SizedBox(height: 10),

          // Insights Row
          //
          // It offered "Insights for your phase", with the same heart icon it
          // uses when a cycle is known, to somebody the card had just told
          // "No period logged yet". One card, two answers. It says what would
          // unlock it instead, the way the other dashboards do.
          InkWell(
            onTap: hasLoggedPeriod ? onTapInsights : onTapLogPeriod,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    hasLoggedPeriod
                        ? Icons.favorite_border_rounded
                        : Icons.lock_outline_rounded,
                    size: 16,
                    color: hasLoggedPeriod
                        ? blushyPrimary
                        : const Color(0xFF9E9296),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasLoggedPeriod
                          ? 'Insights for your phase'
                          : 'Log your period to unlock phase insights',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: hasLoggedPeriod
                            ? const Color(0xFF221510)
                            : const Color(0xFF7A6B72),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF7A6B72),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPhaseDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF7A6B72),
          ),
        ),
      ],
    );
  }
}
