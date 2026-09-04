import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../l10n/app_localizations.dart';
import '../core/theme.dart' hide BlushyColors;
import '../theme/scale.dart';
import 'docsy_star.dart';

/// Five destinations, with Docsy raised in the middle.
///
/// Docsy is the app's primary action rather than a peer of the other tabs, so it
/// is given the centre slot and a filled treatment instead of an outline icon.
class BlushyBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Index of the Docsy destination. Kept here so the shell and the bar cannot
  /// disagree about which slot is the raised one.
  static const int siaIndex = 2;

  /// The five destination names, in tab order.
  ///
  /// The bar labels every tab and the header names the current one. Writing
  /// that list in both places is how the two end up disagreeing, so both read
  /// it from here.
  static List<String> labelsFor(AppLocalizations t) => <String>[
        t.navHome,
        t.navCommunity,
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
    // Nav labels are the most-seen text in the app, so they are the first
    // thing worth translating.
    final t = AppLocalizations.of(context);
    final labels = labelsFor(t);
    // Edge to edge with large rounded top corners, as on the reference: the
    // surface rises from the bottom of the screen, and Docsy's circle sits
    // up over its edge.
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF2ECE7), width: 0.8),
          ),
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
                Expanded(child: _buildNavItem(0, labels[0], Icons.home_rounded)),
                Expanded(child: _buildNavItem(1, labels[1], Icons.people_outline_rounded)),
                Expanded(child: _buildSiaItem(labels[siaIndex])),
                Expanded(child: _buildNavItem(3, labels[3], Icons.auto_awesome_rounded)),
                Expanded(child: _buildNavItem(4, labels[4], Icons.favorite_border_rounded)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The dot under the tab you are on.
  static Widget _activeDot(bool isActive) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: isActive ? BlushyColors.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      );

  Widget _buildSiaItem(String siaLabel) {
    final isActive = currentIndex == siaIndex;

    return Semantics(
      key: _keyFor(siaIndex),
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
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? BlushyColors.primary : const Color(0xFFF9F6F2),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(14, 14),
                  painter: DocsyStarPainter(
                    color: isActive ? Colors.white : const Color(0xFF9E9A96),
                  ),
                ),
              ),
            ),
            const SizedBox(height: BlushySpace.xs),
            Text(
              siaLabel,
              style: BlushyType.micro(
                color: isActive ? BlushyColors.primary : const Color(0xFF9E9A96),
                weight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            _activeDot(isActive),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isActive = currentIndex == index;
    return Semantics(
      key: _keyFor(index),
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
              size: 20,
            ),
            const SizedBox(height: BlushySpace.xs),
            Text(
              label,
              style: BlushyType.micro(
                color: isActive ? BlushyColors.primary : const Color(0xFF9E9A96),
                weight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
            _activeDot(isActive),
          ],
        ),
      ),
    );
  }
}

/// The Docsy star: four points, sides curving gently inward, filled white.
