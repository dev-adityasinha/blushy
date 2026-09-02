import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/stage_conflict_engine.dart';
import '../../../theme/colors.dart';
import '../../../l10n/app_localizations.dart';

class StageConflictDialog extends StatelessWidget {
  final StageConflictResult conflictResult;
  final VoidCallback onConfirmSwitch;

  const StageConflictDialog({
    super.key,
    required this.conflictResult,
    required this.onConfirmSwitch,
  });

  static Future<bool?> show(
    BuildContext context, {
    required StageConflictResult conflictResult,
    required VoidCallback onConfirmSwitch,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StageConflictDialog(
        conflictResult: conflictResult,
        onConfirmSwitch: onConfirmSwitch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetTitle = StageConflictEngine.getStageTitle(conflictResult.targetStage);
    final targetIcon = StageConflictEngine.getStageIcon(conflictResult.targetStage);
    final fromStages = conflictResult.conflictingActiveStages;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: BlushyColors.primary.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header with Clinical Icon & Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BlushyColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: BlushyColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "LIFE STAGE TRANSITION",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: BlushyColors.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context).scClinicalAlignment,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: BlushyColors.secondaryText),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Visual Track Transition Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: BlushyColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BlushyColors.border.withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  // From Stage(s)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).scCurrentTrack,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: BlushyColors.secondaryText,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fromStages.map(StageConflictEngine.getStageTitle).join(', '),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BlushyColors.text,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Arrow
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: BlushyColors.border.withValues(alpha: 0.8)),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, size: 16, color: BlushyColors.primary),
                  ),
                  const SizedBox(width: 8),

                  // To Stage
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppLocalizations.of(context).scNewTrack,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: BlushyColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(targetIcon, size: 14, color: BlushyColors.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                targetTitle,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: BlushyColors.primary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Clinical / User-Facing Explanation
            Text(
              conflictResult.userFacingMessage,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.5,
                color: BlushyColors.text,
              ),
            ),
            if (conflictResult.reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                "• ${conflictResult.reason}",
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  height: 1.4,
                  color: BlushyColors.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: BlushyColors.border.withValues(alpha: 0.8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context).scKeepCurrentTrack,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onConfirmSwitch();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppLocalizations.of(context).scSwitchTrack,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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
