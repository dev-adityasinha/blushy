import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/blushy_models.dart';
import '../../services/api_blushy_service.dart';
import '../../shared/skeleton.dart';
import '../../theme/colors.dart';

/// What the app has told you, in one place.
///
/// The server has kept notifications from the start: it records them when a
/// partner sends something, when a bouquet arrives, when a reminder falls due.
/// `NotificationsApi.list` and `markRead` were both written. Nothing ever
/// rendered them, so none of it reached anyone.
class NotificationInbox extends StatefulWidget {
  const NotificationInbox({super.key});

  @override
  State<NotificationInbox> createState() => _NotificationInboxState();
}

class _NotificationInboxState extends State<NotificationInbox> {
  List<BlushyNotification>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final result = await NotificationsApi.list();
    if (!mounted) return;

    if (result.isError) {
      setState(() => _error = result.errorMessage);
      return;
    }

    final items = result.data ?? const <BlushyNotification>[];
    setState(() => _items = items);

    // Opening the inbox is reading it. Marked after the list is on screen so
    // the unread styling is visible for the frame it is true.
    final unread = items.where((n) => n.isUnread).map((n) => n.notificationId).toList();
    if (unread.isNotEmpty) {
      await NotificationsApi.markRead(unread);
    }
  }

  /// "Just now", "3h ago", "2 Sep" -- the shape a notification list wants.
  String _when(DateTime? at) {
    if (at == null) return '';
    final difference = DateTime.now().difference(at);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${at.day} ${months[at.month - 1]}';
  }

  IconData _iconFor(String category) {
    final c = category.toLowerCase();
    if (c.contains('partner') || c.contains('connection')) return Icons.favorite_rounded;
    if (c.contains('bouquet') || c.contains('gift')) return Icons.local_florist_rounded;
    if (c.contains('cycle') || c.contains('period')) return Icons.calendar_month_rounded;
    if (c.contains('journal') || c.contains('reflection')) return Icons.edit_note_rounded;
    if (c.contains('community')) return Icons.people_rounded;
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: BlushyColors.text),
        title: Text(
          'Notifications',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _centred(
        'Could not load your notifications.\n$_error',
        action: TextButton(onPressed: _load, child: const Text('Try again')),
      );
    }

    if (_items == null) {
      return SkeletonList(
        count: 5,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: SkeletonListRow(),
        ),
      );
    }

    if (_items!.isEmpty) {
      return _centred(
        'Nothing yet.\nThis is where reminders and anything your partner '
        'sends will appear.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: BlushyColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: _items!.length,
        itemBuilder: (context, index) {
          final item = _items![index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                // Unread carries the accent; read is left plain rather than
                // greyed, because it is still worth reading back.
                color: item.isUnread ? BlushyColors.primary : BlushyColors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconFor(item.category),
                    size: 15,
                    color: BlushyColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: item.isUnread ? FontWeight.bold : FontWeight.w600,
                          color: BlushyColors.text,
                        ),
                      ),
                      if ((item.body ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.body!.trim(),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            height: 1.45,
                            color: BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _when(item.scheduledFor),
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: BlushyColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _centred(String message, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.5,
                color: BlushyColors.secondaryText,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }
}
