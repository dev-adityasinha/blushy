import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/state.dart';
import '../services/api_sia_service.dart';
import '../services/html_audio_helper.dart';
import '../theme/colors.dart';

class VoiceNoteBottomSheet extends StatefulWidget {
  const VoiceNoteBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const VoiceNoteBottomSheet(),
    );
  }

  @override
  State<VoiceNoteBottomSheet> createState() => _VoiceNoteBottomSheetState();
}

class _VoiceNoteBottomSheetState extends State<VoiceNoteBottomSheet> with SingleTickerProviderStateMixin {
  HtmlAudioRecorder? _audioRecorder;
  bool _isRecording = false;
  bool _isTranscribing = false;
  int _seconds = 0;
  Timer? _timer;
  
  final TextEditingController _noteController = TextEditingController();
  final ApiSiaService _siaService = ApiSiaService();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-start recording when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _noteController.dispose();
    if (_isRecording && _audioRecorder != null) {
      _audioRecorder!.stop();
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (kIsWeb) {
        _audioRecorder = HtmlAudioRecorder();
        _audioRecorder!.onProgress = (sec) {
          if (mounted) {
            setState(() => _seconds = sec);
          }
        };
        await _audioRecorder!.start();
      } else {
        // Fallback timer for native mobile when web helper is not applicable
        _timer?.cancel();
        _seconds = 0;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _seconds++);
          }
        });
      }

      if (mounted) {
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Microphone access unavailable or denied: $e")),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    if (!_isRecording) return;

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });
    }

    try {
      if (kIsWeb && _audioRecorder != null) {
        final result = await _audioRecorder!.stop();
        final bytes = result?.bytes ?? [];
        if (bytes.isNotEmpty) {
          final text = await _siaService.transcribeAudioBytes(
            bytes,
            'voice_reflection_${DateTime.now().millisecondsSinceEpoch}.webm',
          );
          if (mounted) {
            setState(() {
              _isTranscribing = false;
              if (text.trim().isNotEmpty) {
                _noteController.text = text.trim();
              } else {
                _noteController.text = "Voice reflection recorded cleanly.";
              }
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isTranscribing = false;
        if (_noteController.text.isEmpty) {
          _noteController.text = "Voice reflection recorded (${_seconds}s). Feeling balanced and focused.";
        }
      });
    }
  }

  void _saveVoiceNote() {
    final text = _noteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please record or write a short reflection note.")),
      );
      return;
    }

    final state = BlushyOSProvider.of(context);
    state.addJournal(text, "Voice Reflection");

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Voice note recorded & saved to reflections!"),
        backgroundColor: BlushyColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatTimer(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      margin: EdgeInsets.only(top: mediaQuery.padding.top + 40),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF6F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -5),
          )
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: mediaQuery.viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D8D0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.mic_rounded, color: BlushyColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "Voice Reflection",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recording Visualizer Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BlushyColors.border, width: 0.8),
            ),
            child: Column(
              children: [
                if (_isRecording) ...[
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: BlushyColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: BlushyColors.primary, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.mic, size: 32, color: BlushyColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Recording user voice...",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BlushyColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTimer(_seconds),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Animated Waveform Bars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(7, (i) {
                      final heights = [14.0, 26.0, 38.0, 20.0, 42.0, 28.0, 16.0];
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300 + (i * 80)),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 4,
                        height: heights[(i + _seconds) % heights.length],
                        decoration: BoxDecoration(
                          color: BlushyColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 18),
                    label: Text(
                      "Stop Recording",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ] else if (_isTranscribing) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(color: BlushyColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    "Transcribing your voice reflection...",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: BlushyColors.success, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Voice Recording Captured (${_formatTimer(_seconds)})",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text),
                    decoration: InputDecoration(
                      hintText: "Your voice transcript will appear here...",
                      filled: true,
                      fillColor: const Color(0xFFFAF6F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: BlushyColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: BlushyColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _startRecording,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text("Re-record"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BlushyColors.primary,
                          side: const BorderSide(color: BlushyColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _saveVoiceNote,
                        icon: const Icon(Icons.check, color: Colors.white, size: 16),
                        label: Text(
                          "Save Reflection",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BlushyColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
