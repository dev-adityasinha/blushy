import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// The card every screen is built out of.
///
/// One definition of what a surface looks like: the surface colour,
/// generously rounded, with a one-pixel border in the border colour and no
/// shadow -- the home design spec's "quiet UI". Everything on every page
/// that is a card is this.
///
/// [accent] draws the coloured spine down the left edge that M Studio's rows
/// use to tell their four sections apart.
class BlushySurface extends StatelessWidget {
  const BlushySurface({
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
    this.color = BlushyColors.surface,
    this.accent,
    this.onTap,
    required this.child,
  });

  final EdgeInsets padding;
  final double radius;
  final Color color;

  /// The one-pixel edge every card has.
  static const BorderSide edge = BorderSide(color: BlushyColors.border, width: 1);

  /// The spine down the left edge, where a card has one.
  final Color? accent;

  final VoidCallback? onTap;
  final Widget child;

  /// No shadow. The spec prefers none; the name is kept so the header and
  /// nav, which shared it, still compile against one definition of "lift".
  static const List<BoxShadow> shadow = [];

  @override
  Widget build(BuildContext context) {
    final corner = BorderRadius.circular(radius);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: corner,
        border: Border.fromBorderSide(edge),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (accent != null) {
      // Painted inside the clip rather than as a border, so the spine takes
      // the card's own rounding at the two corners it touches.
      surface = ClipRRect(
        borderRadius: corner,
        child: Stack(
          children: [
            surface,
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: accent!),
            ),
          ],
        ),
      );
      surface = DecoratedBox(
        decoration: BoxDecoration(borderRadius: corner, border: Border.fromBorderSide(edge)),
        child: surface,
      );
    }

    if (onTap == null) return surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: corner,
        child: surface,
      ),
    );
  }
}

/// The round white button the header's bell and account sit in.
class BlushyCircleButton extends StatelessWidget {
  const BlushyCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badged = false,
    this.tooltip,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Draws the unread dot on the top-right of the circle.
  final bool badged;

  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: BlushyColors.surface,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(BlushySurface.edge),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: BlushyColors.text),
          ),
          if (badged)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: BlushyColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: BlushyColors.background, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: tooltip == null ? button : Tooltip(message: tooltip!, child: button),
    );
  }
}
