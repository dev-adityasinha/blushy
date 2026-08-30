import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colors.dart';

/// A paced breathing exercise both partners can run at the same time.
///
/// Box breathing: four seconds in, hold four, out four, hold four. The circle
/// is driven by a real animation on that cadence rather than a decorative
/// loop, so following it actually paces the breath.
class BreathingSyncSheet extends StatefulWidget {
  const BreathingSyncSheet({super.key, this.totalSeconds = 120});

  /// Two minutes by default, which is four full box cycles plus a little.
  final int totalSeconds;

  @override
  State<BreathingSyncSheet> createState() => _BreathingSyncSheetState();
}

enum _BreathPhase { inhale, holdIn, exhale, holdOut }

class _BreathingSyncSheetState extends State<BreathingSyncSheet>
    with SingleTickerProviderStateMixin {
  static const int _phaseSeconds = 4;

  late final AnimationController _controller;
  late final Animation<double> _scale;

  Timer? _ticker;
  int _elapsed = 0;
  _BreathPhase _phase = _BreathPhase.inhale;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _phaseSeconds),
    );
    // Eased rather than linear: a real breath does not change volume at a
    // constant rate, and a linear circle is noticeably harder to follow.
    _scale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    if (_running) return;
    setState(() {
      _running = true;
      _elapsed = 0;
      _phase = _BreathPhase.inhale;
    });
    _controller.forward(from: 0);

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final next = _elapsed + 1;
      if (next >= widget.totalSeconds) {
        timer.cancel();
        _controller.stop();
        setState(() {
          _elapsed = widget.totalSeconds;
          _running = false;
        });
        return;
      }

      setState(() {
        _elapsed = next;
        if (next % _phaseSeconds == 0) {
          _phase = _nextPhase(_phase);
          // Only the two moving phases drive the circle; the holds keep it
          // where it is, which is what makes a hold feel like a hold.
          if (_phase == _BreathPhase.inhale) {
            _controller.forward(from: 0);
          } else if (_phase == _BreathPhase.exhale) {
            _controller.reverse(from: 1);
          }
        }
      });
    });
  }

  void _stop() {
    _ticker?.cancel();
    _controller.stop();
    setState(() => _running = false);
  }

  static _BreathPhase _nextPhase(_BreathPhase phase) {
    switch (phase) {
      case _BreathPhase.inhale:
        return _BreathPhase.holdIn;
      case _BreathPhase.holdIn:
        return _BreathPhase.exhale;
      case _BreathPhase.exhale:
        return _BreathPhase.holdOut;
      case _BreathPhase.holdOut:
        return _BreathPhase.inhale;
    }
  }

  String get _phaseLabel {
    switch (_phase) {
      case _BreathPhase.inhale:
        return 'Breathe in';
      case _BreathPhase.holdIn:
        return 'Hold';
      case _BreathPhase.exhale:
        return 'Breathe out';
      case _BreathPhase.holdOut:
        return 'Hold';
    }
  }

  String get _remaining {
    final left = widget.totalSeconds - _elapsed;
    final m = (left ~/ 60).toString();
    final s = (left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _finished => _elapsed >= widget.totalSeconds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Breathing sync',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Four seconds in, hold, four out, hold. Follow the circle together.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 200,
            child: Center(
              child: AnimatedBuilder(
                animation: _scale,
                builder: (context, child) => Transform.scale(
                  scale: _running || _finished ? _scale.value : 0.55,
                  child: child,
                ),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: BlushyColors.primary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: BlushyColors.primary.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _finished ? 'Done' : (_running ? _phaseLabel : 'Ready when you are'),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _finished ? 'Two minutes together.' : _remaining,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: BlushyColors.secondaryText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _finished
                  ? () => Navigator.of(context).maybePop()
                  : (_running ? _stop : _start),
              child: Text(
                _finished ? 'Close' : (_running ? 'Pause' : 'Start'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
