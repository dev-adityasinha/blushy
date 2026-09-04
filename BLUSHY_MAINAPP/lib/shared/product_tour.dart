import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/storage.dart';
import '../theme/colors.dart';

/// A first-run tour that points at each tab and says what it is for.
///
/// The app opens on five tabs whose icons carry most of the meaning, and a new
/// account has no content in any of them — so the first screen is a row of
/// unfamiliar symbols over an empty page. This walks through them once.
///
/// It replaces a flag that did nothing: onboarding wrote
/// `coach_first_launch.json` with a raw `File()`, the dashboard read it, called
/// `setState` with an empty body and deleted it. The tour was scaffolded and
/// never built.
///
/// Shown once per account. Skipping counts as seeing it — a tour that returns
/// after being dismissed is worse than no tour.

/// One stop: something on screen, and what to say about it.
class TourStep {
  const TourStep({
    required this.targetKey,
    required this.title,
    required this.body,
  });

  /// The widget to point at. A step whose target is not on screen is skipped
  /// rather than pointed at nothing.
  final GlobalKey targetKey;

  final String title;
  final String body;
}

/// Whether this account has been shown the tour.
class TourPreferences {
  const TourPreferences._();

  static const String _file = 'product_tour.json';
  static const String _key = 'completed';

  static bool hasSeenTour() {
    try {
      return BlushyStorage.read(_file)[_key] == true;
    } catch (_) {
      // A storage failure must not trap someone in a tour on every launch.
      return true;
    }
  }

  static void markSeen() {
    try {
      BlushyStorage.write(_file, {
        _key: true,
        'completed_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Lets the tour be shown again, for a "replay the tour" control.
  static void reset() {
    try {
      BlushyStorage.write(_file, {_key: false});
    } catch (_) {}
  }
}

/// The overlay itself: a dimmed screen with the target cut out of it.
class ProductTour extends StatefulWidget {
  const ProductTour({
    super.key,
    required this.steps,
    required this.onFinished,
    this.skipLabel = 'Skip',
    this.nextLabel = 'Next',
    this.doneLabel = 'Got it',
  });

  final List<TourStep> steps;

  /// Called once, whether the tour was completed or skipped.
  final VoidCallback onFinished;

  final String skipLabel;
  final String nextLabel;
  final String doneLabel;

  @override
  State<ProductTour> createState() => _ProductTourState();
}

class _ProductTourState extends State<ProductTour> {
  int _index = 0;

  /// Targets have no position until they have been laid out, so the first
  /// build measures nothing. Rendering the scrim then would dim the screen
  /// around a hole that is not there yet, and giving up then would end the
  /// tour before it started.
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _measured = true);
    });
  }

  /// The steps whose targets are actually on screen, resolved once per build.
  List<TourStep> get _visibleSteps =>
      widget.steps.where((s) => _rectFor(s) != null).toList();

  Rect? _rectFor(TourStep step) {
    final context = step.targetKey.currentContext;
    if (context == null) return null;

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;

    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  void _advance(int total) {
    if (_index + 1 >= total) {
      _finish();
      return;
    }
    setState(() => _index++);
  }

  void _finish() {
    TourPreferences.markSeen();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    if (!_measured) return const SizedBox.shrink();

    final steps = _visibleSteps;

    // Nothing to point at. Finishing rather than showing an empty scrim: a
    // dimmed screen with no explanation is worse than no tour.
    if (steps.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finish();
      });
      return const SizedBox.shrink();
    }

    final step = steps[_index.clamp(0, steps.length - 1)];
    final target = _rectFor(step)!;
    final screen = MediaQuery.of(context).size;
    final isLast = _index >= steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Tapping the dimmed area advances, the way a reader expects.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _advance(steps.length),
              child: CustomPaint(
                painter: _SpotlightPainter(target: target),
                size: screen,
              ),
            ),
          ),
          _TourCard(
            step: step,
            target: target,
            screen: screen,
            position: _index + 1,
            total: steps.length,
            skipLabel: widget.skipLabel,
            actionLabel: isLast ? widget.doneLabel : widget.nextLabel,
            onSkip: _finish,
            onAction: () => _advance(steps.length),
          ),
        ],
      ),
    );
  }
}

/// Dims everything except the target.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.target});

  final Rect target;

  @override
  void paint(Canvas canvas, Size size) {
    // A little room around the target so the highlight does not clip it.
    final hole = RRect.fromRectAndRadius(
      target.inflate(8),
      const Radius.circular(18),
    );

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = BlushyColors.dark.withValues(alpha: 0.72),
    );
    canvas.drawRRect(hole, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // A ring, so the cut-out reads as deliberate rather than as a gap.
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = BlushyColors.primary,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => oldDelegate.target != target;
}

/// The explanation, placed on whichever side of the target has room.
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.target,
    required this.screen,
    required this.position,
    required this.total,
    required this.skipLabel,
    required this.actionLabel,
    required this.onSkip,
    required this.onAction,
  });

  final TourStep step;
  final Rect target;
  final Size screen;
  final int position;
  final int total;
  final String skipLabel;
  final String actionLabel;
  final VoidCallback onSkip;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    const cardHeight = 190.0;
    const margin = 20.0;

    // Above the target when it sits low on the screen — which the tab bar
    // always does — and below it otherwise.
    final placeAbove = target.top > screen.height / 2;
    final top = placeAbove
        ? (target.top - cardHeight - 16).clamp(margin, screen.height - cardHeight)
        : (target.bottom + 16).clamp(margin, screen.height - cardHeight);

    return Positioned(
      left: margin,
      right: margin,
      top: top,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: BlushyColors.dark.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.title,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: BlushyColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.body,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.5,
                color: BlushyColors.secondaryText,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  '$position / $total',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.secondaryText,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    skipLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    actionLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
