import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/state.dart';

class SiaCompanionScreen extends StatefulWidget {
  const SiaCompanionScreen({super.key});

  @override
  State<SiaCompanionScreen> createState() => _SiaCompanionScreenState();
}

class _SiaCompanionScreenState extends State<SiaCompanionScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
          padding: const EdgeInsets.symmetric(horizontal: 24, py: 16),
          color: BlushyColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sia Companion',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sia adapts based on your cycle logs, sleep duration, and journal reflections.',
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
              color: BlushyColors.surface,
              border: Border(top: BorderSide(color: BlushyColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(fontSize: 14, color: BlushyColors.textDark),
                    onSubmitted: (_) => _sendMessage(state),
                    decoration: InputDecoration(
                      hintText: "Reflect or query Sia...",
                      hintStyle: const TextStyle(color: BlushyColors.textLight, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, py: 10),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _sendMessage(state),
                  icon: const Icon(
                    Icons.arrow_upward_rounded,
                    color: BlushyColors.primary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: BlushyColors.lutealSoft,
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
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!msg.isUser) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: BlushyColors.primary,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, py: 12),
                      decoration: BoxDecoration(
                        color: msg.isUser 
                          ? BlushyColors.background 
                          : BlushyColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: msg.isUser ? null : 'Georgia',
                          height: 1.5,
                          color: BlushyColors.textDark,
                        ),
                      ),
                    ),
                    if (msg.actionSuggestions != null && msg.actionSuggestions!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: msg.actionSuggestions!.map((suggestion) {
                          return ActionChip(
                            label: Text(suggestion),
                            labelStyle: const TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.w600,
                              color: BlushyColors.textDark,
                            ),
                            backgroundColor: BlushyColors.surface,
                            side: const BorderSide(color: BlushyColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
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
        ],
      ),
    );
  }
}
