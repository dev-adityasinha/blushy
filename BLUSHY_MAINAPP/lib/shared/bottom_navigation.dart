import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../l10n/app_localizations.dart';
import '../core/theme.dart' hide BlushyColors;

/// Five destinations, with Dr. Docsy raised in the middle.
///
/// Dr. Docsy is the app's primary action rather than a peer of the other tabs, so it
/// is given the centre slot and a filled treatment instead of an outline icon.
class BlushyBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Index of the Dr. Docsy destination. Kept here so the shell and the bar cannot
  /// disagree about which slot is the raised one.
  static const int siaIndex = 2;

  const BlushyBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Nav labels are the most-seen text in the app, so they are the first
    // thing worth translating.
    final t = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: BlushyColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: BlushyTheme.getPagePadding(context),
            vertical: 8.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildNavItem(0, t.navHome, Icons.home_rounded)),
              Expanded(child: _buildNavItem(1, t.navCommunity, Icons.people_outline_rounded)),
              Expanded(child: _buildSiaItem(t.navSia)),
              Expanded(child: _buildNavItem(3, t.navStudio, Icons.auto_awesome_rounded)),
              Expanded(child: _buildNavItem(4, t.navPartner, Icons.favorite_border_rounded)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiaItem(String siaLabel) {
    final isActive = currentIndex == siaIndex;

    return Semantics(
      button: true,
      selected: isActive,
      label: siaLabel,
      child: InkWell(
        onTap: () => onTap(siaIndex),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? BlushyColors.primary : BlushyColors.lutealSoft,
                border: Border.all(
                  color: isActive ? BlushyColors.primary : BlushyColors.secondary,
                  width: 1.4,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: BlushyColors.primary.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : const [],
              ),
              child: Icon(
                Icons.auto_awesome_motion_rounded,
                size: 20,
                color: isActive ? Colors.white : BlushyColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              // Was a hardcoded literal while `siaLabel` fed only the Semantics
              // label, so screen readers got the translated name and everyone
              // looking at the screen got English. The name is also longer than
              // it was, so overflow is spelled out rather than left to clip.
              siaLabel,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive ? BlushyColors.primary : const Color(0xFF9E9A96),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isActive = currentIndex == index;
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? BlushyColors.primary : const Color(0xFF9E9A96),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive ? BlushyColors.primary : const Color(0xFF9E9A96),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
