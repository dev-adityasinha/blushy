import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../services/language_preference.dart';
import '../features/home/widgets/my_health_screen.dart';
import '../core/theme.dart' hide BlushyColors;
import '../theme/scale.dart';

import '../services/auth_storage.dart';
import '../features/partner/presentation/partner_profile_screen.dart';
import '../services/api_blushy_service.dart';
import '../features/notifications/notification_inbox.dart';

/// The size the header's leading text is set at, wordmark or tab name.
///
/// Shared so the two cannot drift: switching tabs should change the word, not
/// the size of it.
const double _headerLeadingSize = 22;

class BlushyHeader extends StatelessWidget implements PreferredSizeWidget {
  const BlushyHeader({super.key, this.title});

  /// The tab name to show in place of the wordmark.
  ///
  /// Null on home, where the wordmark is the point. Everywhere else the
  /// wordmark is the same on every tab and so says nothing about where you
  /// are -- the tab name does, and the account and language controls stay put
  /// either way.
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BlushyColors.background,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: BlushyTheme.getPagePadding(context),
              vertical: BlushySpace.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Expanded so a long tab name takes the room it needs and
              // ellipsizes rather than overflowing into the controls. Several
              // of the translated names are much longer than the English.
              Expanded(
                child: Row(
                  children: [
                    if (title == null)
                      const Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _Wordmark(),
                        ),
                      )
                    else
                      Expanded(
                        child: Semantics(
                          label: title!,
                          excludeSemantics: true,
                          child: Text(
                            title!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: _headerLeadingSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: BlushyColors.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Language selector & Profile button
              Row(
                children: [
                  // Language Selector without round card container
                  ValueListenableBuilder<String>(
                    valueListenable: LanguagePreference.current,
                    builder: (context, code, _) => GestureDetector(
                      onTap: () => _showLanguagePicker(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.language_rounded,
                                size: 16, color: BlushyColors.text),
                            const SizedBox(width: 4),
                            Text(
                              LanguagePreference.shortLabel,
                              style: BlushyType.caption(
                                color: BlushyColors.text,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16, color: BlushyColors.text),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: BlushySpace.sm),

                  const _NotificationBell(),
                  const SizedBox(width: BlushySpace.sm),

                  // Profile Button without round card container
                  GestureDetector(
                    onTap: () {
                      final role = AuthStorage.getRole();
                      if (role == 'partner' || role == 'man') {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PartnerProfileScreen()),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyHealthScreen()),
                        );
                      }
                    },
                    child: SizedBox(
                      width: BlushySpace.control,
                      height: BlushySpace.control,
                      child: const Center(
                        child: Icon(Icons.person_outline_rounded,
                            size: 20, color: BlushyColors.text),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64.0);
}

/// The BLUSHY. lockup in Ada Hybrid bold style.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.manrope(
          fontSize: _headerLeadingSize,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.normal,
          letterSpacing: 2.2,
        ),
        children: const [
          TextSpan(
            text: 'BLUSHY',
            style: TextStyle(color: BlushyColors.primary),
          ),
          TextSpan(
            text: '.',
            style: TextStyle(color: BlushyColors.accent),
          ),
        ],
      ),
    );
  }
}

/// Lets someone choose the language Docsy replies in.
///
/// Only the languages the server actually has strings for are offered; adding
/// more would silently fall back to English and look broken.
void _showLanguagePicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    // Seven languages plus the heading do not fit a half-height sheet, which
    // is what overflowed it. Scrollable and free to size itself instead.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              'App language',
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              // This drives MaterialApp.locale, so it changes the whole app,
              // not only Docsy. It used to say the opposite, which was true
              // before the app itself was localised.
              'Changes the language across the app, including how Docsy '
              'replies. Anything not translated yet stays in English.',
              style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText),
            ),
          ),
          ...LanguagePreference.supported.entries.map(
            (entry) => ListTile(
              title: Text(entry.value, style: GoogleFonts.manrope(fontSize: 14)),
              trailing: LanguagePreference.code == entry.key
                  ? const Icon(Icons.check_rounded, color: BlushyColors.primary)
                  : null,
              onTap: () async {
                await LanguagePreference.set(entry.key);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
          ),
          const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// The bell, with a dot when something is unread.
///
/// The count is fetched once when the header builds. It is deliberately not
/// polled: a wrong-by-a-minute badge is better than a request every few
/// seconds, and opening the inbox refreshes it anyway.
class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    final result = await NotificationsApi.list(unreadOnly: true, limit: 1);
    if (!mounted || result.isError) return;
    setState(() => _hasUnread = (result.data ?? const []).isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationInbox()),
        );
        // Opening the inbox marks everything read, so the dot should go.
        if (mounted) _refreshUnread();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: BlushySpace.control,
            height: BlushySpace.control,
            child: const Center(
              child: Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: BlushyColors.text,
              ),
            ),
          ),
          if (_hasUnread)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: BlushyColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
