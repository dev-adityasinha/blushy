import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Placeholders shaped like the thing that is loading.
///
/// A spinner says "wait" and nothing else: the layout jumps when the data
/// lands, and a slow card is indistinguishable from a broken one. A skeleton
/// shaped like the real element reserves the space it will occupy, so the page
/// settles instead of reflowing, and the shape itself says what is coming.
///
/// The palette is the card palette -- `border` over `cardBg` -- so a loading
/// card reads as the same card unpainted, rather than a grey block borrowed
/// from somewhere else.
///
/// Motion is dropped when the platform asks for reduced motion. A shimmer is
/// decoration; for someone who has turned motion off it is a problem.

/// Drives one shimmer across a group of shapes.
///
/// One controller for the group, not one per shape: a card with eight bars
/// would otherwise run eight animations slightly out of step with each other.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      return _ShimmerScope(progress: null, child: widget.child);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          _ShimmerScope(progress: _controller.value, child: child!),
      child: widget.child,
    );
  }
}

/// Carries the shimmer position down to the shapes inside it.
class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.progress, required super.child});

  /// Null when motion is reduced, and the shapes paint flat.
  final double? progress;

  static double? maybeProgressOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.progress;

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) =>
      progress != oldWidget.progress;
}

/// One rectangle standing in for content.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.widthFactor,
  });

  final double? width;
  final double height;
  final double radius;

  /// A share of the available width, so text lines need not be uniform.
  final double? widthFactor;

  @override
  Widget build(BuildContext context) {
    final progress = _ShimmerScope.maybeProgressOf(context);
    const base = BlushyColors.border;
    final highlight = Color.lerp(base, BlushyColors.cardBg, 0.7)!;

    final Widget box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: progress == null ? base : null,
        gradient: progress == null
            ? null
            : LinearGradient(
                colors: [base, highlight, base],
                stops: const [0.1, 0.5, 0.9],
                // The band sweeps left to right; the colours stay put.
                begin: Alignment(-1.5 + 3.0 * progress, 0),
                end: Alignment(-0.5 + 3.0 * progress, 0),
              ),
      ),
    );

    if (widthFactor == null) return box;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: box,
    );
  }
}

/// A line of text that has not arrived.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.widthFactor = 1, this.height = 12});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) =>
      SkeletonBox(widthFactor: widthFactor, height: height, radius: 6);
}

/// An avatar, icon bubble or emoji slot.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) =>
      SkeletonBox(width: size, height: size, radius: size / 2);
}

/// The card chrome the shapes sit in, matching `premiumCardDecoration` so the
/// placeholder occupies the same box as the card that replaces it.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: BlushyColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BlushyColors.border),
        ),
        child: child,
      ),
    );
  }
}

/// A heading with a paragraph under it: the shape most cards take.
class SkeletonTextCard extends StatelessWidget {
  const SkeletonTextCard({super.key, this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLine(widthFactor: 0.42, height: 14),
          const SizedBox(height: 14),
          for (var i = 0; i < lines; i++) ...[
            // The last line stops short, the way a paragraph does.
            SkeletonLine(widthFactor: i == lines - 1 ? 0.55 : 1),
            if (i != lines - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// The small cards on the home page: a label, a figure, a footnote.
class SkeletonMetricCard extends StatelessWidget {
  const SkeletonMetricCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Expanded, not Spacer: a fractional width needs a bounded box,
              // and a Row's main axis is unbounded.
              Expanded(child: SkeletonLine(widthFactor: 0.55, height: 11)),
              SizedBox(width: 8),
              SkeletonBox(width: 14, height: 14, radius: 4),
            ],
          ),
          SizedBox(height: 22),
          Center(child: SkeletonBox(width: 90, height: 26, radius: 8)),
          SizedBox(height: 22),
          SkeletonLine(widthFactor: 0.5, height: 11),
        ],
      ),
    );
  }
}

/// A row with a leading circle and two lines: comments, messages, list items.
class SkeletonListRow extends StatelessWidget {
  const SkeletonListRow({super.key, this.showTrailing = false});

  final bool showTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonCircle(size: 38),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(widthFactor: 0.34, height: 12),
                SizedBox(height: 8),
                SkeletonLine(widthFactor: 0.9),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 12),
            const SkeletonBox(width: 28, height: 12, radius: 6),
          ],
        ],
      ),
    );
  }
}

/// A community post: author row, title, body, then the vote and comment footer.
class SkeletonPostCard extends StatelessWidget {
  const SkeletonPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: SkeletonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonCircle(size: 34),
                SizedBox(width: 10),
                Expanded(child: SkeletonLine(widthFactor: 0.45, height: 12)),
              ],
            ),
            SizedBox(height: 16),
            SkeletonLine(widthFactor: 0.75, height: 15),
            SizedBox(height: 12),
            SkeletonLine(),
            SizedBox(height: 8),
            SkeletonLine(widthFactor: 0.6),
            SizedBox(height: 18),
            Row(
              children: [
                SkeletonBox(width: 54, height: 22, radius: 11),
                SizedBox(width: 12),
                SkeletonBox(width: 54, height: 22, radius: 11),
                Spacer(),
                SkeletonBox(width: 22, height: 22, radius: 11),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Several of one shape, for a list that has not loaded.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, required this.itemBuilder, this.count = 3});

  final Widget Function(BuildContext context, int index) itemBuilder;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < count; i++) itemBuilder(context, i),
      ],
    );
  }
}
