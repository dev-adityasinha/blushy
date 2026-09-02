import 'package:flutter/material.dart';

class TextNoteRenderer extends StatelessWidget {
  final String text;
  final String cardStyle;
  final TextStyle textStyle;
  final Color? customBgColor;

  const TextNoteRenderer({
    super.key,
    required this.text,
    this.cardStyle = 'classic',
    required this.textStyle,
    this.customBgColor,
  });

  @override
  Widget build(BuildContext context) {
    switch (cardStyle) {
      case 'sticky_note':
        return Container(
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
          decoration: BoxDecoration(
            color: customBgColor ?? const Color(0xFFFEF08A),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(2, 4))],
          ),
          child: Text(text, style: textStyle),
        );

      case 'glassmorphism':
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
          decoration: BoxDecoration(
            color: (customBgColor ?? Colors.white).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Text(text, style: textStyle),
        );

      case 'speech_bubble':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
          decoration: BoxDecoration(
            color: customBgColor ?? const Color(0xFFE0F2FE),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(1, 2))],
          ),
          child: Text(text, style: textStyle),
        );

      default: // 'classic' notebook note
        return Container(
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minWidth: 140, maxWidth: 240),
          decoration: BoxDecoration(
            color: customBgColor ?? const Color(0xFFFFF0F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFBCFE8)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Text(text, style: textStyle),
        );
    }
  }
}
