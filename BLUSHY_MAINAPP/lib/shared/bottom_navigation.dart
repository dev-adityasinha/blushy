import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../l10n/app_localizations.dart';
import '../core/theme.dart' hide BlushyColors;
import 'blushy_surface.dart';
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
          color: BlushyColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BlushySurface.edge),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: BlushyTheme.getPagePadding(context),
              vertical: BlushySpace.sm,
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
  ///
  /// The colour of the label already says which tab is active, and colour
  /// alone is the one signal a red-green colourblind user cannot read. The
  /// dot is the second signal.
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
            // Laid out at 34 but painted at 52: the circle overhangs the bar's
            // top edge, as on the reference, without making the bar taller.
            SizedBox(
              height: 34,
              child: OverflowBox(
                maxHeight: 52,
                maxWidth: 52,
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              height: 52,
              // Solid red, always -- Docsy is the product's primary action,
              // and the reference keeps her circle red on every tab. A soft
              // red glow lifts it off the bar.
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BlushyColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: BlushyColors.primary.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              // A single four-point star with softly concave sides, drawn to
              // the reference. Not a Material icon: the sparkle glyphs are
              // clusters, and the nearest one is what M Studio already uses.
              child: const Center(
                child: CustomPaint(
                  size: Size(26, 26),
                  painter: DocsyStarPainter(color: Colors.white),
                ),
              ),
                ),
              ),
            ),
            const SizedBox(height: BlushySpace.xs),
            Text(
              // Was a hardcoded literal while `siaLabel` fed only the Semantics
              // label, so screen readers got the translated name and everyone
              // looking at the screen got English. The name is also longer than
              // it was, so overflow is spelled out rather than left to clip.
              siaLabel,
              style: BlushyType.micro(
                color: isActive ? BlushyColors.primary : const Color(0xFF9E9A96),
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
