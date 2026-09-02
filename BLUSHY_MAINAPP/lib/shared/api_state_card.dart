import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../services/api_contract_client.dart';
import 'skeleton.dart';

/// Renders the eight states every card must support (spec section 4
/// "FRONTEND STATES EVERY CARD MUST SUPPORT").
///
/// Wrapping a card in this keeps the distinctions the spec insists on:
/// "empty" and "not enough data" read differently, "permission restricted"
/// says the information exists but is not shared, and an error in one card
/// offers a retry without breaking the rest of the screen.
class ApiStateCard<T> extends StatelessWidget {
  final ApiResult<T> result;
  final Widget Function(BuildContext context, T data) builder;

  /// Shown when the server returns `empty`: there is genuinely nothing yet.
  final String emptyMessage;

  /// Shown when the server returns `insufficient_data`: there is some data,
  /// but not enough to say anything honestly. Deliberately distinct from empty.
  final String insufficientDataMessage;

  /// Shown when the viewer is not permitted to see something that exists.
  final String restrictedMessage;

  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final Future<void> Function()? onRetry;

  /// Optional skeleton; a compact placeholder is used when omitted.
  final Widget? loadingPlaceholder;

  /// Last known data, rendered behind a "showing saved" note when the request
  /// could not reach the server (spec section 25).
  final T? cachedData;

  const ApiStateCard({
    super.key,
    required this.result,
    required this.builder,
    this.emptyMessage = 'Nothing here yet.',
    this.insufficientDataMessage = 'Not enough data yet to show this.',
    this.restrictedMessage = 'This has not been shared with you.',
    this.emptyActionLabel,
    this.onEmptyAction,
    this.onRetry,
    this.loadingPlaceholder,
    this.cachedData,
  });

  /// `onEmptyAction` is a plain callback for callers, but the message body
  /// takes an async one so it can share a code path with retry.
  Future<void> Function()? get _wrapEmptyAction {
    final action = onEmptyAction;
    if (action == null) return null;
    return () async => action();
  }

  @override
  Widget build(BuildContext context) {
    switch (result.state) {
      case ApiState.loading:
        return loadingPlaceholder ?? const _CardSkeleton();

      case ApiState.ready:
        final data = result.data;
        if (data == null) return _MessageBody(icon: Icons.inbox_outlined, message: emptyMessage);
        return builder(context, data);

      case ApiState.stale:
        final data = result.data ?? cachedData;
        if (data == null) return _MessageBody(icon: Icons.inbox_outlined, message: emptyMessage);
        return _WithBanner(
          banner: _StatusBanner(
            icon: Icons.update,
            label: AppLocalizations.of(context).stateRefreshing,
            color: Theme.of(context).colorScheme.secondary,
          ),
          child: builder(context, data),
        );

      case ApiState.offline:
        final data = result.data ?? cachedData;
        if (data == null) {
          return _MessageBody(
            icon: Icons.cloud_off_outlined,
            message: AppLocalizations.of(context).stateOfflineNoCache,
            actionLabel: onRetry == null ? null : AppLocalizations.of(context).actionRetry,
            onAction: onRetry,
          );
        }
        // Showing the last known safe state is the designed offline behaviour.
        return _WithBanner(
          banner: _StatusBanner(
            icon: Icons.cloud_off_outlined,
            label: AppLocalizations.of(context).stateOfflineWithCache,
            color: Theme.of(context).colorScheme.outline,
          ),
          child: builder(context, data),
        );

      case ApiState.empty:
        return _MessageBody(
          icon: Icons.inbox_outlined,
          message: emptyMessage,
          actionLabel: emptyActionLabel,
          onAction: _wrapEmptyAction,
        );

      case ApiState.insufficientData:
        return _MessageBody(
          icon: Icons.timeline_outlined,
          message: insufficientDataMessage,
          actionLabel: emptyActionLabel,
          onAction: _wrapEmptyAction,
        );

      case ApiState.restricted:
        return _MessageBody(icon: Icons.lock_outline, message: restrictedMessage);

      case ApiState.error:
        return _MessageBody(
          icon: Icons.error_outline,
          message: result.errorMessage ?? 'Something went wrong loading this.',
          actionLabel: onRetry == null ? null : 'Try again',
          onAction: onRetry,
        );
    }
  }
}

/// A small label naming where a displayed value came from, so a user can always
/// tell an observation from their own log (spec section 8, section 22).
class SourceLabel extends StatelessWidget {
  final String? source;
  final String? version;

  const SourceLabel({super.key, this.source, this.version});

  String? get _label {
    switch (source) {
      case 'manual':
      case 'voice':
        return 'From what you logged';
      case 'rule':
        return 'Calculated from your logs';
      case 'ai':
        return 'Docsy observation';
      case 'medical_reference':
        return 'Reviewed health information';
      case 'device':
      case 'imported':
        return 'From a connected device';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    // Was three static grey bars. A skeleton that does not move reads as a
    // card that failed to paint; the shimmer is what says "still coming".
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonLine(widthFactor: 0.45, height: 14),
            SizedBox(height: 12),
            SkeletonLine(),
            SizedBox(height: 8),
            SkeletonLine(widthFactor: 0.8),
          ],
        ),
      ),
    );
  }
}


class _MessageBody extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _MessageBody({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: () => onAction!(), child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusBanner({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithBanner extends StatelessWidget {
  final Widget banner;
  final Widget child;

  const _WithBanner({required this.banner, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [banner, child],
    );
  }
}
