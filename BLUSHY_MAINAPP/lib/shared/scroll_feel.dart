import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// How scrolling feels across the app.
///
/// Two things live here because they are the same decision: the physics that
/// carry a list, and the small confirmation you get when it runs out.

/// Bouncing physics everywhere, on every platform.
///
/// Android's default clamping physics stop dead at the end of a list, which
/// reads as the app locking up for a frame. The bounce says "that is all of
/// it" without anything having to be drawn.
class BlushyScrollBehavior extends MaterialScrollBehavior {
  const BlushyScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();

  // The stretch/glow overscroll indicator fights the bounce, so nothing is
  // painted over it.
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

/// A light tap when a scroll reaches its end.
///
/// Placed once above the app: scroll notifications bubble, so every list
/// inside gets this without having to opt in.
class ScrollEndHaptic extends StatefulWidget {
  const ScrollEndHaptic({super.key, required this.child});

  final Widget child;

  @override
  State<ScrollEndHaptic> createState() => _ScrollEndHapticState();
}

class _ScrollEndHapticState extends State<ScrollEndHaptic> {
  /// Which nested scrollables are currently sitting at their end, so the tap
  /// fires once on arrival rather than on every frame of an overscroll.
  final Set<int> _resting = <int>{};

  bool _onNotification(ScrollNotification notification) {
    final metrics = notification.metrics;

    // Horizontal rows -- chips, carousels -- reach their end constantly while
    // being flicked through, and buzzing there would be noise.
    if (metrics.axis != Axis.vertical) return false;
    if (!metrics.hasContentDimensions) return false;

    final max = metrics.maxScrollExtent;
    // Nothing to run out of.
    if (max <= 0) return false;

    final depth = notification.depth;
    final atEnd = metrics.pixels >= max - 1.0;

    if (atEnd) {
      if (_resting.add(depth)) {
        HapticFeedback.lightImpact();
      }
    } else if (metrics.pixels < max - 24.0) {
      // A margin before re-arming, so resting right on the boundary does not
      // fire repeatedly.
      _resting.remove(depth);
    }

    // Never absorbed: other listeners still need these.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: widget.child,
    );
  }
}
