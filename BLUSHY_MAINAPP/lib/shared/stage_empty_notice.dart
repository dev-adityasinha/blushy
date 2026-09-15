import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_contract_client.dart';
import '../theme/colors.dart';

/// Shown on a stage dashboard when the server returned nothing for it.
///
/// The menopause, perimenopause, postpartum and pregnancy dashboards each
/// rendered their fallback content in this case with no indication that it was
/// a fallback, so "we have nothing for you yet" and "here is your personalised
/// brief" looked identical. The specification asks every card to distinguish
/// loading, populated, empty and not-enough-data (spec §4, and §31 "every
/// screen supports loading, populated, empty, error and permission states").
///
/// Deliberately quiet: nothing has gone wrong, and a new account seeing this
/// is in the normal case, not an error case. It says what is missing and what
/// would fill it, and never implies the content above it was personalised.
class StageEmptyNotice extends StatelessWidget {
  const StageEmptyNotice({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.info_outline_rounded,
  });

  /// What is not there yet, and what would fill it. Written in full sentences:
  /// this is the only explanation the user gets.
  final String message;

  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: BlushyColors.taupe,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: BlushyColors.secondaryText),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    height: 1.45,
                    color: BlushyColors.secondaryText,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BlushyColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps one [ApiState] onto the right notice for a stage dashboard.
///
/// The three midlife and postpartum dashboards previously had one behaviour for
/// every outcome: render the sections regardless. A failed request, an offline
/// device, a cached copy and a genuinely empty account all looked the same, and
/// on menopause a manufactured fallback made them look like real data.
///
/// Renders nothing when there is fresh data to show, so it can be dropped at
/// the top of a list unconditionally.
class StageStateNotice extends StatelessWidget {
  const StageStateNotice({
    super.key,
    required this.state,
    required this.hasData,
    required this.emptyMessage,
    this.onRetry,
  });

  final ApiState state;

  /// Whether the dashboard has something to render underneath. Stale and
  /// offline both carry data; empty and error may not.
  final bool hasData;

  /// What to say when the request succeeded and there was genuinely nothing.
  final String emptyMessage;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case ApiState.ready:
        if (hasData) return const SizedBox.shrink();
        return StageEmptyNotice(message: emptyMessage);

      case ApiState.empty:
      case ApiState.insufficientData:
        return StageEmptyNotice(message: emptyMessage);

      case ApiState.stale:
        return StageEmptyNotice(
          icon: Icons.history_rounded,
          message: 'Showing a saved copy. Your latest details could not be fetched just now.',
          actionLabel: onRetry == null ? null : 'Try again',
          onAction: onRetry,
        );

      case ApiState.offline:
        return StageEmptyNotice(
          icon: Icons.cloud_off_rounded,
          message: hasData
              ? 'You are offline. This is the last version saved to this device.'
              : 'You are offline, so this stage could not be loaded. What follows is general '
                  'guidance rather than anything based on your own entries.',
          actionLabel: onRetry == null ? null : 'Try again',
          onAction: onRetry,
        );

      case ApiState.restricted:
        // Correct in Partner Mode, where a person chose not to share. This
        // widget is used by both sides, which is how the sentence ended up on
        // her own dashboard -- see `unauthenticated` below.
        return const StageEmptyNotice(
          icon: Icons.lock_outline_rounded,
          message: 'This information has not been shared with you.',
        );

      case ApiState.unauthenticated:
        // Her own data, and nobody withheld it: the session simply ran out.
        // Says what happened and what fixes it.
        return StageEmptyNotice(
          icon: Icons.login_rounded,
          message: 'Sign in again to see this. Your session has expired, so '
              'your own entries could not be loaded.',
          actionLabel: onRetry == null ? null : 'Try again',
          onAction: onRetry,
        );

      case ApiState.error:
        return StageEmptyNotice(
          icon: Icons.error_outline_rounded,
          message: hasData
              ? 'Your latest details could not be loaded, so this may be out of date.'
              : 'This stage could not be loaded. What follows is general guidance rather '
                  'than anything based on your own entries.',
          actionLabel: onRetry == null ? null : 'Try again',
          onAction: onRetry,
        );

      case ApiState.loading:
        return const SizedBox.shrink();
    }
  }
}
