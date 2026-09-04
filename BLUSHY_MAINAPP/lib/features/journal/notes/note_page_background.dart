import 'package:flutter/material.dart';

import 'note_paper.dart';
import 'note_photo.dart';
import 'note_style.dart';

/// The page behind a note: the ground, and the decoration drawn on it.
///
/// Shared by the editor and the list card so a note looks the same in both.
/// They drew it separately before this, and the photo background is the point
/// at which that stopped being harmless: a photo is a widget rather than
/// something the painter can draw, so it has to be composed the same way in
/// both places or the list would show the fallback grey.
class NotePageBackground extends StatelessWidget {
  const NotePageBackground({
    super.key,
    required this.style,
    required this.ink,
    this.lineHeight = 28,
  });

  final NoteStyle style;

  /// The colour the writing is in, so the ruling matches it.
  final Color ink;

  final double lineHeight;

  /// Whatever shows behind the sheet when there is no photograph.
  Color get groundColour => style.template.isDecorated
      ? Color(style.template.ground!)
      : style.backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bytes = style.template == NoteTemplate.photo
        ? NotePhoto.decode(style.photo)
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: groundColour),
        if (bytes != null)
          Image.memory(
            bytes,
            fit: BoxFit.cover,
            // A stored image that will not decode costs the decoration, not
            // the note. The ground underneath is already painted.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        CustomPaint(
          painter: NotePaper(
            template: style.template,
            ink: ink,
            panel: style.backgroundColor,
            lineHeight: lineHeight,
            hasPhotoBehind: bytes != null,
          ),
        ),
      ],
    );
  }
}
