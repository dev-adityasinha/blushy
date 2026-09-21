import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../l10n/app_localizations.dart';
import 'docsy_avatar.dart';
import 'docsy_wordmark.dart';

/// Five destinations, with Docsy raised in the middle.
///
/// Docsy is the app's primary action rather than a peer of the other tabs, so it
/// is given the centre slot and a filled treatment instead of an outline icon.
class BlushyBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Index of the Docsy destination. Kept here so the shell and the bar cannot
  /// disagree about which slot is the raised one.
  static const int siaIndex = 1;

  /// The four destination names, in tab order.
  ///
  /// The bar labels every tab and the header names the current one. Writing
  /// that list in both places is how the two end up disagreeing, so both read
  /// it from here.
  static List<String> labelsFor(AppLocalizations t) => <String>[
        t.navHome,
        t.navSia,
        t.navStudio,
        t.navPartner,
      ];

  /// Anchors for the first-run tour, one per destination.
  ///
  /// Optional, so the bar can be used without one: a tour that forces every
  /// caller to supply keys it does not need is a tour that gets copied wrong.
  final List<GlobalKey>? itemKeys;

  const BlushyBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.itemKeys,
  });

  /// The key for one destination, when the caller supplied any.
  GlobalKey? _keyFor(int index) {
    final keys = itemKeys;
    if (keys == null || index >= keys.length) return null;
    return keys[index];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final labels = labelsFor(t);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: const Border(
            top: BorderSide(color: Color(0xFFF2ECE7), width: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(child: _buildNavItem(0, labels[0], Icons.home_rounded, Icons.home_outlined)),
                Expanded(child: _buildSiaItem(labels[siaIndex])),
                Expanded(child: _buildNavItem(2, labels[2], Icons.self_improvement_rounded, Icons.self_improvement_outlined)),
                Expanded(child: _buildNavItem(3, labels[3], Icons.favorite_rounded, Icons.favorite_border_rounded)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSiaItem(String siaLabel) {
    final isActive = currentIndex == siaIndex;
    const activeColor = Color(0xFFDD0D22);
    const activeBg = Color(0xFFFFEAEA);

    return Semantics(
      key: _keyFor(siaIndex),
      button: true,
      selected: isActive,
      label: siaLabel,
      child: InkWell(
        onTap: () => onTap(siaIndex),
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DocsyIcon(
                size: 22,
                color: isActive ? activeColor : const Color(0xFF645A60),
              ),
              const SizedBox(height: 3),
              DocsyWordmark(
                text: siaLabel,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  color: isActive ? activeColor : const Color(0xFF645A60),
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData activeIcon, IconData inactiveIcon) {
    final isActive = currentIndex == index;

    // Dedicated signature color system for visual consistency across tabs
    final Color activeColor;
    final Color activeBg;

    switch (index) {
      case 0: // Home
        activeColor = const Color(0xFFDD0D22);
        activeBg = const Color(0xFFFFEAEA);
        break;
      case 2: // M Studio
        activeColor = const Color(0xFFFF4A00);
        activeBg = const Color(0xFFFFF2E8);
        break;
      case 3: // Partner
        activeColor = const Color(0xFFE02850);
        activeBg = const Color(0xFFFFEBF0);
        break;
      default:
        activeColor = BlushyColors.primary;
        activeBg = const Color(0xFFFFEAEA);
    }

    return Semantics(
      key: _keyFor(index),
      button: true,
      selected: isActive,
      label: label,
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : inactiveIcon,
                color: isActive ? activeColor : const Color(0xFF645A60),
                size: 21,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  color: isActive ? activeColor : const Color(0xFF645A60),
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Docsy star: four points, sides curving gently inward, filled white.
