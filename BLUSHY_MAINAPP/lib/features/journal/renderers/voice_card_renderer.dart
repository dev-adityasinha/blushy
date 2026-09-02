import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VoiceCardRenderer extends StatelessWidget {
  final dynamic content;
  final bool isPlaying;
  final double playbackProgress; // 0.0 to 1.0 audio playback progress
  final VoidCallback onPlayToggle;

  const VoiceCardRenderer({
    super.key,
    required this.content,
    required this.isPlaying,
    this.playbackProgress = 0.0,
    required this.onPlayToggle,
  });

  @override
  Widget build(BuildContext context) {
    String duration = '00:12';
    String dateStr = 'Today';
  
    if (content is Map<String, dynamic>) {
      duration = content['duration'] ?? '00:12';
      dateStr = content['date'] ?? 'Today';
    } else if (content is String) {
      duration = content;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onPlayToggle,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle),
              child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('Voice Memory', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF92400E))),
                  const SizedBox(width: 6),
                  Text('• $dateStr', style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFFB45309))),
                ],
              ),
              const SizedBox(height: 4),
              
              // Audio-synced Waveform Visualizer
              SizedBox(
                width: 100,
                height: 18,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    isPlaying: isPlaying,
                    progress: playbackProgress,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(duration, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFB45309))),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final bool isPlaying;
  final double progress;

  _WaveformPainter({required this.isPlaying, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 18;
    final barWidth = size.width / barCount;
    final activePaint = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.fill;
    final inactivePaint = Paint()
      ..color = const Color(0xFFFDE68A)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth * 0.2;
      final barNormalizedX = i / barCount;
      
      // Calculate bar height dynamically
      double barHeightFactor = (sin(i * 0.8) * 0.4 + 0.6).clamp(0.2, 1.0);
      if (isPlaying) {
        // Modulate slightly around current playback position
        final distFromProgress = (barNormalizedX - progress).abs();
        if (distFromProgress < 0.15) {
          barHeightFactor = (barHeightFactor * 1.3).clamp(0.2, 1.0);
        }
      }

      final h = size.height * barHeightFactor;
      final y = (size.height - h) / 2;

      final isPast = barNormalizedX <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth * 0.6, h),
          const Radius.circular(2),
        ),
        isPast ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.isPlaying != isPlaying || oldDelegate.progress != progress;
  }
}
