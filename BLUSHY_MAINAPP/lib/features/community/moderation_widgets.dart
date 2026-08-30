import 'package:flutter/material.dart';

import '../../services/api_blushy_service.dart';

/// Community moderation UI (spec sections 12 and 22).
///
/// The notice and the report/block actions are the user-facing half of the
/// server-side moderation rules. Visibility itself is enforced on the server;
/// nothing here hides content on its own.

/// Reasons a post can be reported, with the wording shown to the user.
///
/// The keys must match the server's accepted values; the server rejects
/// anything else, so this list is a convenience rather than the authority.
const Map<String, String> kReportReasons = {
  'misinformation': 'Misleading health information',
  'harmful_advice': 'Advice that could cause harm',
  'harassment': 'Harassment or abuse',
  'spam': 'Spam',
  'off_topic': 'Off topic',
  'privacy': 'Shares private information',
  'other': 'Something else',
};

/// Shown on any post touching a health topic, so a reader is never left to
/// infer that a community post carries clinical authority.
class ModerationNotice extends StatelessWidget {
  final String? notice;

  const ModerationNotice({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final text = notice;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Report and block actions for a post.
class PostModerationMenu extends StatelessWidget {
  final String postId;
  final String? authorId;

  /// Called after a block, so the feed can drop that author immediately
  /// instead of waiting for the next refresh.
  final VoidCallback? onBlocked;

  const PostModerationMenu({
    super.key,
    required this.postId,
    this.authorId,
    this.onBlocked,
  });

  Future<void> _report(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final reason = await showModalBottomSheet<String>(
      context: context,
      // The reason list is longer than a short viewport, so the sheet scrolls
      // rather than overflowing on small screens.
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Why are you reporting this?'),
              ),
              ...kReportReasons.entries.map(
                (entry) => ListTile(
                  title: Text(entry.value),
                  onTap: () => Navigator.of(sheetContext).pop(entry.key),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (reason == null) return;

    final result = await ModerationApi.report(postId, reason);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.isReady
              // Deliberately does not say what will happen to the post: the
              // outcome is a moderator decision, not an automatic one.
              ? 'Thanks. A moderator will review this.'
              : 'That report could not be sent. Please try again.',
        ),
      ),
    );
  }

  Future<void> _block(BuildContext context) async {
    final id = authorId;
    if (id == null || id.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text(
          'You will stop seeing their posts, and they will stop seeing yours. '
          'You can undo this later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Block')),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ModerationApi.block(id);
    if (result.isReady) onBlocked?.call();

    messenger.showSnackBar(
      SnackBar(
        content: Text(result.isReady ? 'Blocked.' : 'Could not block right now.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 18),
      tooltip: 'More',
      onSelected: (value) {
        if (value == 'report') _report(context);
        if (value == 'block') _block(context);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'report', child: Text('Report post')),
        // A post from the partner community is anonymous, so there is no author
        // to block.
        if (authorId != null && authorId!.isNotEmpty)
          const PopupMenuItem(value: 'block', child: Text('Block this person')),
      ],
    );
  }
}
