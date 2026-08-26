import 'package:flutter/material.dart';
import 'renderers/text_note_renderer.dart';
import 'renderers/sticker_renderer.dart';
import 'renderers/photo_card_renderer.dart';
import 'renderers/voice_card_renderer.dart';
import 'renderers/washi_tape_renderer.dart';

export 'renderers/text_note_renderer.dart';
export 'renderers/sticker_renderer.dart';
export 'renderers/photo_card_renderer.dart';
export 'renderers/voice_card_renderer.dart';
export 'renderers/washi_tape_renderer.dart';

class ScrapbookItemRenderers {
  static Widget renderTextCard({
    required String text,
    required String cardStyle,
    required TextStyle textStyle,
    Color? customBgColor,
  }) {
    return TextNoteRenderer(
      text: text,
      cardStyle: cardStyle,
      textStyle: textStyle,
      customBgColor: customBgColor,
    );
  }

  static Widget renderSticker(dynamic content, Color? customColor, {bool isAnimated = true}) {
    return StickerRenderer(
      content: content,
      customColor: customColor,
      isAnimated: isAnimated,
    );
  }

  static Widget renderTape(Color color, {String style = 'Classic'}) {
    return WashiTapeRenderer(color: color, style: style);
  }

  static Widget renderPhotoCard(dynamic content, {String frameStyle = 'Polaroid', bool enableDevelopingEffect = false}) {
    return PhotoCardRenderer(
      content: content,
      frameStyle: frameStyle,
      enableDevelopingEffect: enableDevelopingEffect,
    );
  }

  static Widget renderVoiceCard({
    required dynamic content,
    required bool isPlaying,
    double playbackProgress = 0.0,
    required VoidCallback onPlayToggle,
  }) {
    return VoiceCardRenderer(
      content: content,
      isPlaying: isPlaying,
      playbackProgress: playbackProgress,
      onPlayToggle: onPlayToggle,
    );
  }
}
