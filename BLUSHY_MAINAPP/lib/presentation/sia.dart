import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/state.dart';
import '../services/html_audio_helper.dart';
import '../services/api_sia_service.dart';

class SiaCompanionScreen extends StatefulWidget {
  const SiaCompanionScreen({super.key});

  @override
  State<SiaCompanionScreen> createState() => _SiaCompanionScreenState();
}

class _SiaCompanionScreenState extends State<SiaCompanionScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiSiaService _siaService = ApiSiaService();

  HtmlAudioRecorder? _audioRecorder;
  bool _isListeningVoice = false;

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _audioRecorder?.cancel();
    super.dispose();
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isListeningVoice && _audioRecorder != null) {
      setState(() {
        _isListeningVoice = false;
      });

      try {
        final recordResult = await _audioRecorder!.stop();
        final audioBytes = recordResult?.bytes ?? [];
        if (audioBytes.isNotEmpty) {
          final transcribedText = await _siaService.transcribeAudioBytes(
            audioBytes,
            'sia_presentation_voice_${DateTime.now().millisecondsSinceEpoch}.webm',
          );

          if (mounted) {
            setState(() {
            });
            if (transcribedText.trim().isNotEmpty) {
              _chatController.text = transcribedText.trim();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Voice transcribed into text field. Review and tap send!")),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No spoken audio could be recognized. Please try again.")),
              );
            }
          }
        } else {
          if (mounted) {
            setState(() {
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Voice recording error: $e")),
          );
        }
      }
    } else {
      try {
        _audioRecorder = HtmlAudioRecorder();
        await _audioRecorder!.start();
        if (mounted) {
          setState(() {
            _isListeningVoice = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isListeningVoice = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Microphone error: $e")),
          );
        }
      }
    }
  }

  void _sendMessage(BlushyOSState state) {
    if (_chatController.text.trim().isNotEmpty) {
      final text = _chatController.text.trim();
      _chatController.clear();
      state.addSiaMessage(text);
      
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);

    return Column(
      children: [
        // Immersive active header info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: BlushyColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Docsy Companion',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Docsy adapts based on your cycle logs, sleep duration, and journal reflections.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                ),
              ),
              const Divider(color: BlushyColors.border, height: 24),
            ],
          ),
        ),

        // Message timeline
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            itemCount: state.siaMessages.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final msg = state.siaMessages[index];
              return _buildMessageRow(context, msg, state);
            },
          ),
        ),

        // Text input dock
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: BlushyColors.cardBg,
              border: Border(top: BorderSide(color: BlushyColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(fontSize: 14, color: BlushyColors.textDark),
                    onSubmitted: (_) => _sendMessage(state),
                    decoration: const InputDecoration(
                      hintText: "Reflect or query Docsy...",
                      hintStyle: TextStyle(color: BlushyColors.secondaryText, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleVoiceRecording,
                  icon: Icon(
                    _isListeningVoice ? Icons.stop_rounded : Icons.mic_rounded,
                    color: _isListeningVoice ? Colors.white : const Color(0xFF6F42F5),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: _isListeningVoice ? BlushyColors.primary : const Color(0xFFF3E8FF),
                    shape: const CircleBorder(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _sendMessage(state),
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageRow(BuildContext context, SiaMessage msg, BlushyOSState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF6F42F5),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                'S',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: msg.isUser 
                      ? BlushyColors.background 
                      : BlushyColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BlushyColors.border),
                  ),
                  child: Text(
                    msg.text,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: BlushyColors.textDark,
                    ),
                  ),
                ),
                if (msg.actionSuggestions != null && msg.actionSuggestions!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: msg.actionSuggestions!.map((suggestion) {
                      return ActionChip(
                        label: Text(suggestion),
                        labelStyle: const TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.textDark,
                        ),
                        backgroundColor: BlushyColors.cardBg,
                        side: const BorderSide(color: BlushyColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onPressed: () {
                          state.addSiaMessage(suggestion);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
              if (msg.isUser) ...[
                const SizedBox(width: 12),
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: BlushyColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'T',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        );
      }
    }
