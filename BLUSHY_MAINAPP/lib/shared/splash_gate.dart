import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// The red opening screen, and the circle that opens onto the app.
///
/// The first thing the app shows is a full red field with the wordmark on it.
/// A circle then opens from the centre, and the screen underneath appears
/// through it — so the app arrives rather than replacing the splash abruptly.
///
/// The app is built and running the whole time; only its visibility is
/// animated. Nothing is delayed waiting for this, so a slow first frame
/// shortens the reveal rather than adding to it.
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.child,
    this.hold = const Duration(milliseconds: 650),
    this.reveal = const Duration(milliseconds: 900),
    this.minimumAway = const Duration(minutes: 10),
    this.now = DateTime.now,
  });

  /// What the circle opens onto.
  final Widget child;

  /// How long the red field is held before the circle starts.
  final Duration hold;

  /// How long the circle takes to cover the screen.
  final Duration reveal;

  /// How long the app must have been away before reopening it replays the
  /// splash.
  ///
  /// Without this, anything that briefly backgrounds the app -- the image
  /// picker, the recorder, the share sheet, an incoming call -- comes back
  /// through a full red screen, which reads as a glitch rather than a launch.
  final Duration minimumAway;

  /// The clock, injectable so the wait can be tested without waiting for it.
  final DateTime Function() now;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.reveal);

  late final Animation<double> _opening = CurvedAnimation(
    parent: _controller,
    // Slow to leave, quick to finish: the circle reads as opening outward
    // rather than as a wipe. The emphasized curve holds the slow start longer
    // and lands softer, which is what stops the end feeling like a snap.
    curve: Curves.easeInOutCubicEmphasized,
  );

  /// Once the circle has covered the screen there is nothing left to reveal,
  /// and the splash stops painting entirely rather than sitting behind every
  /// frame for the rest of the session.
  bool _done = false;

  /// Held so it can be cancelled. A bare `Future.delayed` leaves a timer
  /// pending when the splash goes away before the hold elapses -- on a hot
  /// restart, or any rebuild that replaces it -- and `mounted` only stops the
  /// callback acting, not the timer existing.
  Timer? _holdTimer;

  /// When the app was last sent to the background, or null if it has not been.
  ///
  /// Resuming is not on its own a reason to replay: the app passes through
  /// `inactive` for things that never leave the screen, like the app switcher
  /// being summoned and dismissed. Only a real `paused` starts this clock.
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    });

    _play();
  }

  /// Holds on the red field, then opens the circle.
  void _play() {
    _holdTimer?.cancel();
    _controller.reset();
    _holdTimer = Timer(widget.hold, () {
      if (mounted) _controller.forward();
    });
  }

  /// Plays again when the app comes back from a long enough absence, so
  /// reopening it looks like opening it. A cold start already gets this from
  /// `initState`; coming back from the background does not, because the widget
  /// tree is still there and `_done` is still true from last time.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundedAt = widget.now();
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    final left = _backgroundedAt;
    _backgroundedAt = null;
    // Never actually left, so there is nothing to come back from.
    if (left == null) return;

    // A quick trip out and back is the same session continuing.
    if (widget.now().difference(left) < widget.minimumAway) return;

    if (!mounted) return;
    setState(() => _done = false);
    _play();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;

    // Someone who has asked for less motion still gets the app, without the
    // circle and without the wait.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }

    return Stack(
      children: [
        const _SplashField(),
        AnimatedBuilder(
          animation: _opening,
          builder: (context, child) => ClipPath(
            clipper: _CircleReveal(fraction: _opening.value),
            child: child,
          ),
          child: widget.child,
        ),
      ],
    );
  }
}

/// The red field with the wordmark on it.
class _SplashField extends StatelessWidget {
  const _SplashField();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BlushyColors.primary,
      child: Center(
        child: RichText(
          text: const TextSpan(
            // The header's own wordmark, so the app opens on the mark it then
            // carries at the top of every screen.
            style: TextStyle(
              fontFamily: 'Ada Hybrid',
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: Colors.white,
            ),
            children: [
              TextSpan(text: 'BLUSHY'),
              TextSpan(
                text: '.',
                // The accent the wordmark always ends on, kept legible on red.
                style: TextStyle(color: BlushyColors.info),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circle growing from the centre until it covers the screen.
class _CircleReveal extends CustomClipper<Path> {
  const _CircleReveal({required this.fraction});

  /// 0 shows nothing through the circle, 1 shows the whole screen.
  final double fraction;

  @override
  Path getClip(Size size) {
    final centre = Offset(size.width / 2, size.height / 2);

    // To the corner, not the edge: a circle sized to the shorter side would
    // stop with the corners still red.
    final maxRadius = math.sqrt(
      math.pow(size.width / 2, 2) + math.pow(size.height / 2, 2),
    );

    return Path()
      ..addOval(Rect.fromCircle(center: centre, radius: maxRadius * fraction));
  }

  @override
  bool shouldReclip(_CircleReveal oldClipper) => oldClipper.fraction != fraction;
}
