import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_blushy_service.dart';
import '../../theme/colors.dart';
import '../../l10n/app_localizations.dart';

/// One step of a guided session.
class RecoveryStep {
  const RecoveryStep({required this.instruction, required this.seconds});

  final String instruction;
  final int seconds;

  static RecoveryStep? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final instruction = (raw['instruction'] ?? '').toString().trim();
    final seconds = (raw['seconds'] as num?)?.toInt() ?? 0;
    if (instruction.isEmpty || seconds <= 0) return null;
    return RecoveryStep(instruction: instruction, seconds: seconds);
  }
}

/// A guided recovery session.
///
/// The Recovery tab advertised sessions with durations and both cards were
/// `onTap: () {}`. A session is a sequence of timed instructions, which is
/// something the app can actually deliver -- no audio file, and a reviewer can
/// read every line rather than listening to a recording.
class RecoverySessionPlayer extends StatefulWidget {
  const RecoverySessionPlayer({
    super.key,
    required this.sessionId,
    required this.title,
    required this.steps,
  });

  final String sessionId;
  final String title;
  final List<RecoveryStep> steps;

  @override
  State<RecoverySessionPlayer> createState() => _RecoverySessionPlayerState();
}

class _RecoverySessionPlayerState extends State<RecoverySessionPlayer> {
  Timer? _ticker;
  int _stepIndex = 0;
  int _secondsIntoStep = 0;
  int _secondsElapsed = 0;
  bool _running = false;
  bool _finished = false;
  bool _recorded = false;

  int get _totalSeconds =>
      widget.steps.fold(0, (sum, step) => sum + step.seconds);

  RecoveryStep get _currentStep => widget.steps[_stepIndex];

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    if (_running || _finished) return;
    setState(() => _running = true);

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsIntoStep += 1;
        _secondsElapsed += 1;

        if (_secondsIntoStep >= _currentStep.seconds) {
          if (_stepIndex >= widget.steps.length - 1) {
            timer.cancel();
            _running = false;
            _finished = true;
            // Recorded once the session is actually finished, not when it is
            // opened -- otherwise the count means nothing.
            unawaited(_recordCompletion());
          } else {
            _stepIndex += 1;
            _secondsIntoStep = 0;
          }
        }
      });
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  Future<void> _recordCompletion() async {
    if (_recorded) return;
    _recorded = true;
    await RecoveryApi.complete(widget.sessionId, secondsListened: _secondsElapsed);
  }

  String get _remaining {
    final left = (_totalSeconds - _secondsElapsed).clamp(0, _totalSeconds);
    final m = (left ~/ 60).toString();
    final s = (left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds == 0 ? 0.0 : _secondsElapsed / _totalSeconds;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: BlushyColors.dark),
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: BlushyColors.border,
                valueColor: const AlwaysStoppedAnimation(BlushyColors.primary),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Step ${_stepIndex + 1} of ${widget.steps.length} • $_remaining left',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: BlushyColors.secondaryText,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      _finished ? 'Done.' : _currentStep.instruction,
                      key: ValueKey(_finished ? 'done' : _stepIndex),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: BlushyColors.text,
                      ),
                    ),
                  ),
                ),
              ),
              if (_finished)
                Text(
                  AppLocalizations.of(context).rspThatIsTheWhole,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: BlushyColors.secondaryText,
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _finished
                      ? () => Navigator.of(context).maybePop()
                      : (_running ? _pause : _start),
                  child: Text(
                    _finished ? 'Close' : (_running ? 'Pause' : 'Start'),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
